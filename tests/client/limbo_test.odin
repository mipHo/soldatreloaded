package client_test

import "core:testing"

import "../../apps/client/match"
import "../../core/game"
import res "../../core/resources"

// Joined while the game is paused, and placed: the weapons menu comes up for my first
// life, as it does while the round is played, and not only once the game goes on (it
// never did, and I went on with my fists). Once the round is over it waits for the next.
@(test)
weapons_menu_while_paused :: proc(t: ^testing.T) {
	g := new(game.Game)
	defer free(g)
	testing.expect(t, game.game_init(g, game.DEFAULT_GAME_SETTINGS, authority = true))
	defer game.game_destroy(g)
	testing.expect(t, game.game_start_round(g, "ctf_Ash", seed = 1))
	g.world.soldiers[0].loadout = {.Punch, .Knife}
	game.soldier_place(g, 0, .Alpha, remote = false)
	config := res.DEFAULT_CLIENT_CONFIG
	m := new(match.Match)
	defer free(m)
	m.mode = .Online
	m.game = g
	m.config = &config
	m.limbo.team_asked = true

	g.round.phase = game.Ended{countdown = game.ROUND_END_TICKS}
	match.limbo_tick(m)
	testing.expect(t, .Weapons not_in m.hud.menus.open, "not over the round's scores")

	g.round.phase = game.Paused{}
	match.limbo_tick(m)
	testing.expect(t, .Weapons in m.hud.menus.open, "up while paused, for my first life")
}
