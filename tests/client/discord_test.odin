package client_test

import "core:encoding/json"
import "core:strings"
import "core:testing"

import "../../apps/client/match"
import "../../apps/client/online"
import "../../core/game"
import res "../../core/resources"
import "../../core/utils"

// What Discord is told of a server's game: the map and the score, the server's name and
// my team, the players of the 32, the round's time left; never the server's address. And
// the frame it is told in is JSON, with the game's icon by its address and the button.
@(test)
discord_shows_the_game :: proc(t: ^testing.T) {
	g := new(game.Game)
	defer free(g)
	testing.expect(t, game.game_init(g, game.DEFAULT_GAME_SETTINGS, authority = true))
	defer game.game_destroy(g)
	testing.expect(t, game.game_start_round(g, "ctf_Ash", seed = 1))
	g.world.soldiers[0].loadout = {.AK74, .Knife}
	game.soldier_place(g, 0, .Alpha, remote = false)
	game.soldier_place(g, 1, .Bravo, remote = false)
	game.soldier_place(g, 2, .Spectator, remote = false)
	g.round.captures[.Alpha], g.round.captures[.Bravo] = 3, 2
	g.round.time_left = 90 * game.TICK_RATE

	n := new(online.Line)
	defer free(n)
	utils.short_string_set(&n.map_name, "ctf_Ash")
	utils.short_string_set(&n.hostname, "Soldat Reloaded EU")
	utils.short_string_set(&n.address, "149.248.193.40:23073")
	config := res.DEFAULT_CLIENT_CONFIG
	m := new(match.Match)
	defer free(m)
	m.mode, m.game, m.line, m.config, m.me = .Online, g, n, &config, 0

	a := match.discord_activity(m, 1000, 500, "v0.24.0")
	testing.expect_value(t, utils.short_string_text(&a.details), "ctf_Ash · Alpha 3 – 2 Bravo")
	testing.expect_value(t, utils.short_string_text(&a.state), "Soldat Reloaded EU · Alpha team")
	testing.expect(t, a.party_size == 3 && a.party_max == game.MAX_PLAYERS, "the players in it, of the server's 32")
	testing.expect_value(t, a.ends, i64(1090))
	testing.expect_value(t, utils.short_string_text(&a.icon_text), "Soldat Reloaded v0.24.0")
	party := utils.short_string_text(&a.party)
	testing.expect(t, party != "" && !strings.contains(party, "149.248"), "the party is the server's, not its address")

	text := online.discord_activity_json(&a, 7, 1234)
	testing.expect(t, !strings.contains(text, "149.248"), "the address is never said")
	parsed, err := json.parse_string(text, allocator = context.temp_allocator)
	testing.expectf(t, err == nil, "the frame is JSON: %v\n%s", err, text)
	activity := parsed.(json.Object)["args"].(json.Object)["activity"].(json.Object)
	testing.expect_value(t, activity["assets"].(json.Object)["large_image"].(json.String), online.DISCORD_ICON)
	testing.expect_value(t, activity["timestamps"].(json.Object)["end"].(json.Float), 1090)
	testing.expect_value(t, len(activity["party"].(json.Object)["size"].(json.Array)), 2)
	testing.expect_value(t, len(activity["buttons"].(json.Array)), 1)

	g.round.phase = game.Paused{}
	paused := match.discord_activity(m, 1000, 500, "v0.24.0")
	testing.expect(t, paused.ends == 0 && strings.has_suffix(utils.short_string_text(&paused.details), "· Paused"), "paused: no clock, and said")
	g.round.phase = game.Ended{winner = .Alpha}
	ended := match.discord_activity(m, 1000, 500, "v0.24.0")
	testing.expect(t, strings.has_suffix(utils.short_string_text(&ended.details), "Alpha wins"), "over: who won")
}

// A server anyone may join (on the lobby's list, asking no password) gets a Join game
// button, by the join page's https link, first; anything else, the one button alone.
@(test)
discord_join_button :: proc(t: ^testing.T) {
	b := new(online.Browser)
	defer free(b)
	b.count = 2
	utils.short_string_set(&b.servers[0].address.ip, "149.248.193.40")
	b.servers[0].address.port, b.servers[0].answered = 23073, true
	utils.short_string_set(&b.servers[1].address.ip, "10.0.0.2")
	b.servers[1].address.port, b.servers[1].answered = 23073, true
	b.servers[1].info.password = true
	testing.expect(t, online.browser_open_to_all(b, "149.248.193.40:23073"), "listed, open")
	testing.expect(t, !online.browser_open_to_all(b, "10.0.0.2:23073"), "listed, but it asks a password")
	testing.expect(t, !online.browser_open_to_all(b, "149.248.193.40:23074"), "not listed")

	buttons :: proc(a: ^online.Discord_Activity) -> json.Array {
		parsed, err := json.parse_string(online.discord_activity_json(a, 1, 1), allocator = context.temp_allocator)
		assert(err == nil)
		return parsed.(json.Object)["args"].(json.Object)["activity"].(json.Object)["buttons"].(json.Array)
	}
	a: online.Discord_Activity
	utils.short_string_set(&a.join, "149.248.193.40:23073")
	two := buttons(&a)
	testing.expect_value(t, len(two), 2)
	testing.expect_value(t, two[0].(json.Object)["url"].(json.String), "https://soldatreloaded.github.io/join/?s=149.248.193.40:23073")
	utils.short_string_set(&a.join, `1.2.3.4:23073"},{"x":"`)
	testing.expect_value(t, len(buttons(&a)), 1) // no address the game wouldn't take
}
