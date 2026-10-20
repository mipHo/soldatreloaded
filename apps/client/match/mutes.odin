package match

import "core:mem/virtual"
import "core:strconv"
import "core:strings"

import sim "../../../core/game"
import res "../../../core/resources"
import "../hud"

// My own mutes, on my screen alone (the original's /mute, which the server knows nothing
// of; an admin's, for everyone, is /servermute): players muted by name, kept in the
// config's `mutes` so a mute holds past a rejoin until it is lifted; and whole kinds of
// chat, by who says it. A muted player's taunts and radio calls, said by a key and not
// typed, still come through; a spectator's, while the spectators are muted, don't. From
// the C client's ui/mutes.c and main.c's mute commands.

MUTES_MAX :: 64

// Whether a player's line is kept off my screen: said by `name` on `team`, by a key
// (`taunt`) or typed.
mute_hides :: proc(match: ^Match, slot: sim.Soldier_Id, name: string, team: res.Team, taunt: bool, radio := false) -> bool {
	m := &match.config.mutes
	if m.spectators && team == .Spectator do return true // a spectator's all, keys too
	// whether the player's chat is muted at all, the taunt bypass aside: by their slot (the
	// scoreboard's, this player alone) or by name or kind (the commands', across a rejoin)
	base := match.scoreboard_muted[slot] || m.everyone || muted(m, name)
	if !base && team != .Spectator {
		mate := team == match.game.world.soldiers[match.me].team
		base = m.team if mate else m.enemies
	}
	if !base do return false
	// a muted player's taunt or radio call still comes through unless its allowance is off
	if taunt do return !m.allow_radio if radio else !m.allow_taunts
	return true
}

// mute <player>, unmute <player>: their chat kept off my screen, or let back; a player
// not here is taken by the name as said. `mute all` is muteall, as the original's;
// `unmute all` lifts every mute.
mute_command :: proc(match: ^Match, mute: bool, said: string) {
	m := &match.config.mutes
	if said == "all" {
		if mute {
			mute_kind(match, "muteall")
			return
		}
		m^ = {}
		client_say(match, "Everyone is unmuted")
		return
	}
	name := said
	if slot, here := player_called(match, said).?; here do name = soldier_names(match)[slot]
	changed := mutes_add(match.config, name) if mute else mutes_remove(match.config, name)
	switch {
	case mute && changed:  client_say(match, "%s is muted", name)
	case mute:             client_say(match, "%s was muted already", name)
	case changed:          client_say(match, "%s is unmuted", name)
	case:                  client_say(match, "%s wasn't muted", name)
	}
}

// muteall, muteteam, muteenemies, mutespecs: a kind of chat kept off my screen, or let
// back. Taunts and radio calls come through but a spectator's.
mute_kind :: proc(match: ^Match, command: string) {
	m := &match.config.mutes
	kind: ^bool
	who: string
	switch command {
	case "muteall":     kind, who = &m.everyone, "Everyone's chat"
	case "muteteam":    kind, who = &m.team, "Your team's chat"
	case "muteenemies": kind, who = &m.enemies, "The enemies' chat"
	case "mutespecs":   kind, who = &m.spectators, "The spectators' chat"
	case:               return
	}
	kind^ = !kind^
	but := " (but for taunts)" if kind^ && command != "mutespecs" else ""
	client_say(match, "%s is %s%s", who, "muted" if kind^ else "unmuted", but)
}

// A mute a click on the open scoreboard asked for (hud.mute): a player by their name, or
// a team by its relation to me, each toggled as the chat commands do it, and cleared.
scoreboard_mute_take :: proc(match: ^Match) {
	target, asked := match.hud.mute.?
	if !asked do return
	match.hud.mute = nil
	switch t in target {
	case hud.Mute_Player:
		// by slot, so this one player is muted even if another shares its name; it holds for
		// the session, the /mute command is the one that keeps a name across a rejoin
		muted := !match.scoreboard_muted[t.id]
		match.scoreboard_muted[t.id] = muted
		name := soldier_names(match)[t.id]
		client_say(match, "%s is %s", name if name != "" else "That player", "muted" if muted else "unmuted")
	case hud.Mute_Team:
		scoreboard_mute_team(match, t.team)
	}
}

// A whole team muted or unmuted from the scoreboard, mapped to the kind mutes relative to
// me: my own team's caption to the team mute, another's to the enemies', the spectators'
// to theirs (a spectator, with no team of my own, takes any playing team for the enemy).
@(private = "file")
scoreboard_mute_team :: proc(match: ^Match, team: res.Team) {
	m := &match.config.mutes
	mine := match.game.world.soldiers[match.me].team
	kind: ^bool
	who: string
	switch {
	case team == .Spectator:
		kind, who = &m.spectators, "The spectators' chat"
	case mine != .None && mine != .Spectator && team == mine:
		kind, who = &m.team, "Your team's chat"
	case:
		kind, who = &m.enemies, "The enemies' chat"
	}
	kind^ = !kind^
	but := " (but for taunts)" if kind^ && team != .Spectator else ""
	client_say(match, "%s is %s%s", who, "muted" if kind^ else "unmuted", but)
}

// mutes: what I have muted.
mutes_list :: proc(match: ^Match) {
	m := &match.config.mutes
	kinds := [?]struct {
		on:   bool,
		name: string,
	}{{m.everyone, "everyone"}, {m.team, "your team"}, {m.enemies, "the enemies"}, {m.spectators, "the spectators"}}
	for kind in kinds {
		if kind.on do client_say(match, "muted: %s", kind.name)
	}
	for name in m.players do client_say(match, "muted: %s", name)
	if len(m.players) == 0 do client_say(match, "No players muted")
}

// The player a mute names: by slot number, by name in any case, or by the start of one
// name alone. Nil for nobody here.
@(private = "file")
player_called :: proc(match: ^Match, said: string) -> Maybe(sim.Soldier_Id) {
	soldiers := &match.game.world.soldiers
	if n, is_number := strconv.parse_int(said, 10); is_number {
		if n >= 0 && n < sim.MAX_PLAYERS && soldiers[n].active do return sim.Soldier_Id(n)
		return nil
	}
	names := soldier_names(match)
	lower := strings.to_lower(said, context.temp_allocator)
	found: Maybe(sim.Soldier_Id)
	starts := 0
	for &soldier, i in soldiers {
		if !soldier.active || names[i] == "" do continue
		name := strings.to_lower(names[i], context.temp_allocator)
		if name == lower do return sim.Soldier_Id(i) // the whole name
		if strings.has_prefix(name, lower) {
			found = sim.Soldier_Id(i)
			starts += 1
		}
	}
	return found if starts == 1 else nil
}

@(private = "file")
muted :: proc(m: ^res.Mute_Settings, name: string) -> bool {
	for muted in m.players {
		if strings.equal_fold(muted, name) do return true
	}
	return false
}

// A name onto the config's list, in the config's own arena. False if it was there
// already, or the list is full.
@(private = "file")
mutes_add :: proc(config: ^res.Client_Config, name: string) -> bool {
	m := &config.mutes
	if name == "" || muted(m, name) || len(m.players) >= MUTES_MAX do return false
	allocator := virtual.arena_allocator(&config.arena)
	players := make([]string, len(m.players) + 1, allocator)
	copy(players, m.players)
	players[len(m.players)] = strings.clone(name, allocator)
	m.players = players // the old list stays in the arena until the config goes, a few bytes
	return true
}

// False if it wasn't there.
@(private = "file")
mutes_remove :: proc(config: ^res.Client_Config, name: string) -> bool {
	m := &config.mutes
	for muted, i in m.players {
		if !strings.equal_fold(muted, name) do continue
		copy(m.players[i:], m.players[i + 1:])
		m.players = m.players[:len(m.players) - 1]
		return true
	}
	return false
}
