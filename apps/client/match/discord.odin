package match

import "core:fmt"
import "core:hash"

import sim "../../../core/game"
import res "../../../core/resources"
import "../../../core/utils"
import "../online"

// What Discord is told of a match (online/discord.odin): the map and the score first,
// then where: the server's name and my team, Offline Play and its bots, or whose demo;
// the players in a server's game, "(5 of 32)"; and while a round is played the time it
// has left, counting down, else the time since `since`. The server's address is never
// said here: a profile is seen by more than the game's players, and a server may be
// private. Main adds it, as a Join game button, for one on the lobby's list that asks
// no password, which anyone may see and join anyway.
// `now` is the Unix second, `version` the game's.
discord_activity :: proc(match: ^Match, now, since: i64, version: string) -> (a: online.Discord_Activity) {
	game := match.game
	round := &game.round
	world := &game.world
	me := &world.soldiers[match.me]
	map_name := match.map_name if match.mode == .Offline else utils.short_string_text(&match.line.map_name)
	utils.short_string_set(&a.icon_text, fmt.tprintf("Soldat Reloaded %s", version))
	a.since = since

	score := fmt.tprintf("Alpha %d – %d Bravo", round.captures[.Alpha], round.captures[.Bravo])
	switch phase in round.phase {
	case sim.Playing:
		utils.short_string_set(&a.details, fmt.tprintf("%s · %s", map_name, score))
		if round.time_left > 0 do a.ends = now + i64(round.time_left / sim.TICK_RATE)
	case sim.Paused:
		utils.short_string_set(&a.details, fmt.tprintf("%s · %s · Paused", map_name, score))
	case sim.Ended:
		over := "a tie" if phase.winner == .None else fmt.tprintf("%s wins", team_word(phase.winner))
		utils.short_string_set(&a.details, fmt.tprintf("%s · %s · %s", map_name, score, over))
	}

	team := "Spectating"
	if me.active && (me.team == .Alpha || me.team == .Bravo) do team = fmt.tprintf("%s team", team_word(me.team))
	switch match.mode {
	case .Online:
		hostname := utils.short_string_text(&match.line.hostname)
		utils.short_string_set(&a.state, fmt.tprintf("%s · %s", hostname if hostname != "" else "Online", team))
		// the party is the server's, all in it alike, by a hash of its address and not the
		// address itself
		address := utils.short_string_text(&match.line.address)
		utils.short_string_set(&a.party, fmt.tprintf("server-%08x", hash.fnv32a(transmute([]u8)address)))
		for &soldier in world.soldiers do a.party_size += i32(soldier.active)
		a.party_max = sim.MAX_PLAYERS
	case .Offline:
		bots := 0
		for team in match.bot_teams do bots += int(team != .None)
		utils.short_string_set(&a.state, fmt.tprintf("Offline Play · %s · %d bot%s", team, bots, "" if bots == 1 else "s"))
	case .Demo:
		a.ends = 0 // the round's clock of then, not now's
		recorder := utils.short_string_text(&match.playback.player.header.name) if match.playback.player != nil else ""
		utils.short_string_set(&a.state, fmt.tprintf("Watching %s's demo", recorder) if recorder != "" else "Watching a demo")
		utils.short_string_set(&a.details, map_name)
	}
	return
}

@(private = "file")
team_word :: proc(team: res.Team) -> string {
	#partial switch team {
	case .Alpha: return "Alpha"
	case .Bravo: return "Bravo"
	}
	return "Spectators"
}
