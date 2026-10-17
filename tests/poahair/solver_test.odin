package poahair_test

// The hair solver by what it must do, not by another solver's numbers: the pinned nodes
// ride the head exactly, a chain keeps its links, gravity pulls by weight, elasticity
// pulls back to the shape, hair comes to rest under a still head, and a long run on a
// jittering head stays finite and plays the same every time.

import "core:math"
import "core:testing"

import hair "../../core/poahair"

// The head moving about, as a soldier's does: the same at every tick for every run.
head_at :: proc(tick: int) -> hair.Attachment {
	f := f64(tick)
	return {
		x     = 0.13 * math.sin(f / 8) + 0.004 * f,
		z     = 0.07 * math.cos(f / 11) - 0.002 * f,
		angle = 0.31 * math.sin(f / 13) + 0.0015 * f,
	}
}

CHAIN_NODES := [4]hair.Node{{0, 0}, {0.22, 0.43}, {0.51, 0.62}, {0.82, 0.48}}
RIBBON_NODES := [4]hair.Node{{-0.31, -0.12}, {0.18, 0.04}, {0.63, 0.31}, {0.91, 0.76}}
MESH_NODES := [4]hair.Node{{-0.35, -0.18}, {0.16, 0.02}, {0.55, 0.37}, {0.94, 0.79}}
MESH_TRIANGLES := [2][3]int{{0, 1, 2}, {1, 3, 2}}

// A chain pinned at its root; a ribbon pinned along it (the mesh solver's path); a mesh.
strands :: proc() -> [3]hair.Strand {
	return {
		{name = "chain", nodes = CHAIN_NODES[:], rigidity = 0.37, damping = 0.23, gravity = 0.81, weight = 1},
		{name = "ribbon", nodes = RIBBON_NODES[:], anchor_index = 2, rigidity = 0.29, damping = 0.41, gravity = 0.73, weight = 1},
		{name = "mesh", kind = "mesh", nodes = MESH_NODES[:], anchor_index = 1, mesh = {triangles = MESH_TRIANGLES[:]}, rigidity = 0.34, damping = 0.19, gravity = 0.92, weight = 1},
	}
}

// `ticks` of the head moving, from a reset at tick 0.
run :: proc(strand: ^hair.Strand, ticks: int, head: proc(tick: int) -> hair.Attachment = head_at) -> hair.State {
	state: hair.State
	hair.reset(&state, strand, head(0))
	for tick in 1 ..= ticks do hair.step(&state, strand, head(tick))
	return state
}

distance :: proc(a, b: hair.Node) -> f64 {
	return math.hypot(a.x - b.x, a.z - b.z)
}

@(test)
pins_ride_the_head :: proc(t: ^testing.T) {
	all := strands()
	for &strand in all {
		state: hair.State
		hair.reset(&state, &strand, head_at(0))
		for tick in 1 ..= 120 {
			hair.step(&state, &strand, head_at(tick))
			pin := hair.world(strand.nodes[strand.anchor_index], head_at(tick))
			got := state.pos[strand.anchor_index]
			testing.expectf(t, distance(got, pin) < 1e-12, "%s tick %d: the pin at %v, not on the head at %v", strand.name, tick, got, pin)
		}
	}
}

@(test)
chain_keeps_its_links :: proc(t: ^testing.T) {
	strand := strands()[0]
	state: hair.State
	hair.reset(&state, &strand, head_at(0))
	for tick in 1 ..= 120 {
		hair.step(&state, &strand, head_at(tick))
		for i in 1 ..< len(strand.nodes) {
			rest := distance(strand.nodes[i], strand.nodes[i - 1])
			got := distance(state.pos[i], state.pos[i - 1])
			testing.expectf(t, math.abs(got - rest) < 1e-9, "tick %d link %d: %.12f long, not %.12f", tick, i, got, rest)
		}
	}
}

still :: proc(tick: int) -> hair.Attachment { return {} }

// The tip's height after a second under a still head, gravity pulling toward -z.
tip_after_a_second :: proc(strand: hair.Strand) -> f64 {
	strand := strand
	state := run(&strand, 60, still)
	return state.pos[len(strand.nodes) - 1].z
}

@(test)
gravity_pulls_by_weight :: proc(t: ^testing.T) {
	for strand in strands() {
		rest := strand.nodes[len(strand.nodes) - 1].z
		weightless := strand
		weightless.gravity = 0
		light, heavy := strand, strand
		light.weight, heavy.weight = 0.5, 2
		testing.expectf(t, math.abs(tip_after_a_second(weightless) - rest) < 1e-9, "%s: with no gravity the tip keeps its place", strand.name)
		testing.expectf(t, tip_after_a_second(strand) < rest, "%s: gravity pulls the tip down", strand.name)
		testing.expectf(t, tip_after_a_second(heavy) < tip_after_a_second(light), "%s: a heavier strand hangs lower", strand.name)
	}
}

@(test)
elasticity_pulls_back_to_the_shape :: proc(t: ^testing.T) {
	for strand in strands() {
		rest := strand.nodes[len(strand.nodes) - 1].z
		limp, springy := strand, strand
		limp.elasticity, springy.elasticity = 0, 1
		sag_limp := rest - tip_after_a_second(limp)
		sag_springy := rest - tip_after_a_second(springy)
		testing.expectf(t, sag_springy < sag_limp, "%s: elastic hair sags %.6f, less than limp hair's %.6f", strand.name, sag_springy, sag_limp)
	}
}

@(test)
comes_to_rest_under_a_still_head :: proc(t: ^testing.T) {
	all := strands()
	for &strand in all {
		state := run(&strand, 600, still)
		for i in 0 ..< len(strand.nodes) {
			speed := distance(state.pos[i], state.prev[i])
			testing.expectf(t, speed < 1e-6, "%s node %d still moves %.9f a tick after ten seconds", strand.name, i, speed)
		}
	}
}

// A head thrown about hard: a soldier rolling, jetting, flipping direction.
jitter :: proc(tick: int) -> hair.Attachment {
	f := f64(tick)
	return {x = 3 * math.sin(f * 1.7), z = 2 * math.cos(f * 2.3), angle = 4 * math.sin(f * 0.9)}
}

@(test)
stays_finite_and_plays_the_same :: proc(t: ^testing.T) {
	all := strands()
	for &strand in all {
		a := run(&strand, 3600, jitter)
		b := run(&strand, 3600, jitter)
		reach: f64 // no node strays further from the pin than the whole strand is long, and some
		for i in 1 ..< len(strand.nodes) do reach += distance(strand.nodes[i], strand.nodes[i - 1])
		pin := a.pos[strand.anchor_index]
		for i in 0 ..< len(strand.nodes) {
			p := a.pos[i]
			testing.expectf(t, !math.is_nan(p.x) && !math.is_nan(p.z) && !math.is_inf(p.x, 0) && !math.is_inf(p.z, 0), "%s node %d went to %v", strand.name, i, p)
			testing.expectf(t, distance(p, pin) <= 2 * reach, "%s node %d is %.3f from the pin, past twice the strand's %.3f", strand.name, i, distance(p, pin), reach)
			testing.expectf(t, p == b.pos[i], "%s node %d: two runs of the same ticks part, %v and %v", strand.name, i, p, b.pos[i])
		}
	}
}
