package draw

import sim "../../../core/game"
import res "../../../core/resources"
import "../../../core/utils"

// The world drawn between its last two ticks, so it moves smoothly at any frame rate. A
// frame is `alpha` of the way from the tick before (a Snapshot the match keeps) to the
// latest (the world as it is): the soldiers' bodies and poses blend, and the corpses'
// points; online, the others are drawn where the line's corrections are still easing to
// (the stream's blend), so a correction glides in rather than snapping; the bullets and the things blend between their own last two positions, which
// the simulation keeps; the sparks between theirs. Everything else a frame draws is the
// latest tick's. I am drawn as everyone is, and the camera follows where I am drawn.
// From the C client's render/render_state.c.

// The part of a tick the next frames blend from.
Snapshot :: struct {
	soldiers: [sim.MAX_PLAYERS]sim.Soldier,
	corpses:  [sim.MAX_PLAYERS]sim.Corpse,
}

// The gostek's 24 points: the pose's 20, then the neck (21) with the chain's pendant
// swinging below it (22), and the head's top (23) with the dreadlocks' end below it (24).
Points :: [sim.CORPSE_POINTS]utils.Vec2

// A soldier where a frame shows it.
Figure :: struct {
	pos:    utils.Vec2, // its body
	points: Points,
	corpse: bool,       // dead with its body started: the points are the corpse's
}

Frame :: struct {
	alpha:      f32, // how far the world is drawn from the tick before to the latest, 0 to 1
	tick_alpha: f32, // how far the clock is into the next tick: alpha but while the round stands
	figures:    [sim.MAX_PLAYERS]Figure,
}

// Before each tick: the world as the frames after it blend from.
snapshot_take :: proc(snapshot: ^Snapshot, world: ^sim.World) {
	snapshot.soldiers = world.soldiers
	snapshot.corpses = world.corpses
}

// The frame `alpha` of the way from `before` to the game as it is now, each soldier moved
// by its `offsets`, if any: what a correction still has to show of it. While the round
// stands (paused, or over) the world is drawn as its latest tick, as the original's
// InterpolateState does when paused: the bullets and the things keep the last positions
// of the step that froze, which would otherwise be run through again every tick.
frame_build :: proc(frame: ^Frame, before: ^Snapshot, game: ^sim.Game, alpha: f32, offsets: ^[sim.MAX_PLAYERS]utils.Vec2 = nil, art: ^Art = nil) {
	frame.tick_alpha = clamp(alpha, 0, 1)
	frame.alpha = 1 if sim.round_standing(&game.round) else frame.tick_alpha
	world := &game.world
	ended, is_ended := game.round.phase.(sim.Ended)
	celebrate := is_ended && ended.winner != .None // the winners dab and yeah, in step
	for id in 0 ..< sim.MAX_PLAYERS {
		to := &world.soldiers[id]
		offset := offsets[id] if offsets != nil else {}
		if celebrate && to.active && !to.vitals.dead && to.team == ended.winner {
			// the frozen round would hold them still, so the client plays the cheer itself
			winner := to^
			celebration_pose(game.resources.animations, &winner, world.tick)
			frame.figures[id] = figure_between(game.resources.animations, &winner, &winner, &before.corpses[id], &world.corpses[id], 1, offset, art, world.tick, id)
		} else {
			frame.figures[id] = figure_between(game.resources.animations, &before.soldiers[id], to, &before.corpses[id], &world.corpses[id], frame.alpha, offset, art, world.tick, id)
		}
	}
}

// A winner's pose this frame: dab, then yeah, cycled by the world's tick so every winner
// is in step. The body plays the cheer; yeah moves the legs with it.
@(private = "file")
celebration_pose :: proc(animations: ^res.Animations, soldier: ^sim.Soldier, tick: u32) {
	dab, yeah := animations[.Dab].frame_count, animations[.Yeah].frame_count
	pos := i32(tick % u32(max(dab + yeah, 1)))
	if pos < dab {
		soldier.pose.body.id, soldier.pose.body.frame = .Dab, pos + 1
		soldier.pose.legs.id, soldier.pose.legs.frame = .Stand, 1
	} else {
		f := pos - dab + 1
		soldier.pose.body.id, soldier.pose.body.frame = .Yeah, f
		soldier.pose.legs.id, soldier.pose.legs.frame = .Yeah, f
	}
}

// `t` of the way from `a` to `b`.
@(private = "package")
between :: proc(a, b: utils.Vec2, t: f32) -> utils.Vec2 {
	return a + (b - a) * t
}

// The pose blends whatever the animations did between the two ticks, as the original
// lerps every skeleton point from its last each frame; but a new life is a jump, not a
// journey, and the step from living to dead shows the latest tick's alone. A dead
// soldier is its corpse once that has started; until then it holds its last pose.
@(private = "file")
figure_between :: proc(animations: ^res.Animations, from, to: ^sim.Soldier, corpse_from, corpse_to: ^sim.Corpse, alpha: f32, offset: utils.Vec2, art: ^Art, tick: u32, id: int) -> (figure: Figure) {
	if !to.active do return
	continuous := from.active && from.vitals.life == to.vitals.life
	figure.pos = (between(from.body.pos, to.body.pos, alpha) if continuous else to.body.pos) + offset

	figure.corpse = to.vitals.dead && corpse_to.active
	if figure.corpse {
		for &point, k in figure.points {
			point = between(corpse_from.points[k], corpse_to.points[k], alpha) if corpse_from.active else corpse_to.points[k]
		}
		return
	}

	// the airborne clips over the game's pose, where there is art to have them; without,
	// the game's pose alone
	clips: ^res.Air_Animations
	transition: ^Air_Transition
	tuning: ^res.Air_Tuning
	styles: res.Air_Styles
	if art != nil do clips, transition, tuning, styles = art.air_animations, &art.air_transitions[id], &art.air_tuning, art.air_styles
	base := sim.soldier_pose(animations, to, figure.pos)
	joints := visual_soldier_pose(animations, clips, to, figure.pos, tick, transition, tuning, styles)
	if continuous && from.vitals.dead == to.vitals.dead {
		last := visual_soldier_pose(animations, clips, from, figure.pos, tick-1 if tick>0 else 0, transition, tuning, styles)
		last_base := sim.soldier_pose(animations, from, figure.pos)
		for &point, i in base do point = between(last_base[i], point, alpha)
		for &joint, i in joints {
			joint = between(last[i], joint, alpha)
		}
	}
	copy(figure.points[:], joints[:])
	for k in 0 ..< len(to.pose.swing) {
		swing := between(from.pose.swing[k], to.pose.swing[k], alpha) if continuous else to.pose.swing[k]
		figure.points[len(joints) + k] = swing + offset
		figure.points[len(joints) + k] += joints[8]-base[8]
	}
	return
}
