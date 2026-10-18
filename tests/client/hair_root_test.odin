package client_test

import "core:math"
import "core:testing"
import sim "../../core/game"
import draw "../../apps/client/draw"

// The custom hair hangs from the head of a dead soldier too: a corpse's head point is a
// ragdoll point 3 units from the neck, not the live skeleton's 0.1-unit marker, and taken
// as one the hair's root was thirty times too far out, swinging round the body as it fell.
@(test)
hair_stays_on_a_corpses_head :: proc(t: ^testing.T) {
	g := new(sim.Game); defer free(g)
	testing.expect(t, sim.game_init(g, sim.DEFAULT_GAME_SETTINGS, authority = true))
	defer sim.game_destroy(g)
	testing.expect(t, sim.game_start_round(g, "ctf_Ash", seed = 1))
	sim.soldier_place(g, 0, .Alpha, remote = false)
	commands: [sim.MAX_PLAYERS]sim.Command
	for _ in 0 ..< 30 do sim.game_tick(g, &commands)
	s := &g.world.soldiers[0]
	live := sim.soldier_pose(g.resources.animations, s, s.body.pos)
	dir := i32(s.body.direction)
	alive := draw.poa_attachment(live[11], live[8], dir)

	// the same head, its marker where a corpse's would be: the same root
	marker := live[8] + (live[11] - live[8]) * 30
	as_corpse := draw.poa_attachment(marker, live[8], dir)
	testing.expectf(t, math.abs(alive.x - as_corpse.x) < 1e-3 && math.abs(alive.z - as_corpse.z) < 1e-3 && math.abs(alive.angle - as_corpse.angle) < 1e-3,
		"a head 3 units out roots the hair where the marker does: %v and %v", alive, as_corpse)

	sim.world_ask_kill(&g.world, 0, false)
	farthest: f64
	for _ in 0 ..< 120 {
		sim.game_tick(g, &commands)
		corpse := &g.world.corpses[0]
		if !corpse.active do continue
		a := draw.poa_attachment(corpse.points[11], corpse.points[8], dir)
		neck := corpse.points[8] // in the POA editor's space, as poa_attachment has it
		farthest = max(farthest, math.hypot(a.x - (-f64(neck.x) * 1.1 / 3 / f64(dir)), a.z - (-f64(neck.y) / 3)))
	}
	testing.expectf(t, farthest > 0 && farthest < 1.5, "the root stays a head's height from the corpse's neck (%.2f at most)", farthest)
}
