package air_animation_test

import "core:testing"
import res "../../core/resources"
import sim "../../core/game"
import draw "../../apps/client/draw"

// Fluid recoil (#15): a short kick of the elbows and hands over the pose being drawn, in
// every stance and in the air, the torso, the shoulders and the head left where they are;
// none at the recoil's first and last frames.
@(test)
recoil_follows_current_pose_in_every_movement_state :: proc(t: ^testing.T) {
	clips := res.air_animations_load("assets/data"); defer free(clips)
	animations, ok := res.animations_load("assets/data"); defer free(animations)
	testing.expect(t,ok)
	if !ok do return
	soldier := sim.Soldier{active=true,body={direction=1,jet_fuel=100,on_ground=true},controls={aim={100,0},stance=.Stand},pose={legs={id=.Stand,frame=1},body={id=.Small_Recoil,frame=3}}}
	for mode in 0..<8 {
		subject := soldier
		switch mode {
		case 1: subject.body.on_ground=false; subject.pose.legs.id=.Fall; subject.controls.buttons={.Jet,.Right}; subject.body.velocity={2,0}
		case 2: subject.body.on_ground=false; subject.pose.legs.id=.Fall; subject.body.velocity={0,-1}
		case 3: subject.controls.stance=.Crouch; subject.pose.legs.id=.Crouch
		case 4: subject.controls.stance=.Prone; subject.pose.legs.id=.Prone
		case 5: subject.body.on_ground=false; subject.pose.legs.id=.Run; subject.controls.buttons={.Right}; subject.body.velocity={2,0}
		case 6: subject.body.on_ground=false; subject.pose.legs.id=.Run_Back; subject.controls.buttons={.Left}; subject.body.velocity={-2,0}
		case 7: subject.body.on_ground=false; subject.pose.legs.id=.Fall; subject.controls.buttons={.Jet,.Left}; subject.body.velocity={-2,0}
		case:
		}
		base := subject
		base.pose.body={id=.Stand if subject.controls.stance == .Stand else .Aim,frame=6 if subject.controls.stance == .Crouch else 1}
		target := draw.visual_soldier_pose(animations,clips,&base,{},0)
		subject.pose.body.frame=1
		testing.expect(t,draw.visual_soldier_pose(animations,clips,&subject,{},0)==target)
		subject.pose.body.frame=3
		recoiled := draw.visual_soldier_pose(animations,clips,&subject,{},0)
		testing.expectf(t,recoiled[8]==target[8] && recoiled[9]==target[9] && recoiled[11]==target[11],"recoil leaves torso, shoulder and head intact in mode %d",mode)
		testing.expectf(t,recoiled[14]!=target[14],"recoil moves the hand in mode %d",mode)
		subject.pose.body.frame=animations[.Small_Recoil].frame_count
		testing.expect(t,draw.visual_soldier_pose(animations,clips,&subject,{},0)==target)
	}
}

// Crouched, the kick is over the aiming frame the crouch goes back to after a shot, so
// the arms don't jump at every shot of a burst.
@(test)
crouch_recoil_matches_return_aim_frame :: proc(t: ^testing.T) {
	clips := res.air_animations_load("assets/data"); defer free(clips)
	animations, ok := res.animations_load("assets/data"); defer free(animations)
	testing.expect(t,ok)
	if !ok do return
	for legs in ([3]res.Animation_Id{.Crouch,.Crouch_Run,.Crouch_Run_Back}) {
		for recoil_id in ([2]res.Animation_Id{.Aim_Recoil,.Hands_Up_Recoil}) {
			target_id: res.Animation_Id = .Aim if recoil_id == .Aim_Recoil else .Hands_Up_Aim
			target_frame: i32 = 6 if recoil_id == .Aim_Recoil else 11
			soldier := sim.Soldier{active=true,body={direction=1,on_ground=true},controls={aim={100,0},stance=.Crouch},pose={legs={id=legs,frame=1},body={id=recoil_id,frame=1}}}
			target := soldier
			target.pose.body={id=target_id,frame=target_frame}
			expected := draw.visual_soldier_pose(animations,clips,&target,{},0)
			testing.expect(t,draw.visual_soldier_pose(animations,clips,&soldier,{},0)==expected)
			soldier.pose.body.frame=3
			actual := draw.visual_soldier_pose(animations,clips,&soldier,{},0)
			testing.expect(t,actual[8]==expected[8] && actual[9]==expected[9] && actual[11]==expected[11])
			testing.expect(t,actual[14]!=expected[14])
			soldier.pose.body.frame=animations[recoil_id].frame_count
			testing.expect(t,draw.visual_soldier_pose(animations,clips,&soldier,{},0)==expected)
		}
	}
}

// Prone has no recoil clip: a shot gives a smaller kick that eases off, and a death takes
// what was left of it, and of the airborne blend, with it.
@(test)
prone_shot_has_smaller_decaying_recoil_without_recoil_clip :: proc(t: ^testing.T) {
	clips := res.air_animations_load("assets/data"); defer free(clips)
	animations, ok := res.animations_load("assets/data"); defer free(animations)
	testing.expect(t,ok)
	if !ok do return
	soldier := sim.Soldier{active=true,body={direction=1,on_ground=true},controls={aim={100,0},stance=.Prone},pose={legs={id=.Prone,frame=26},body={id=.Prone,frame=26}}}
	baseline := draw.visual_soldier_pose(animations,clips,&soldier,{},0)
	state: draw.Air_Transition
	soldier.arsenal.fired=true
	draw.air_transition_step(&state,&soldier,res.AIR_TUNING,1.0/60)
	testing.expect(t,state.prone_recoil > 0 && state.prone_recoil < 0.8)
	recoiled := draw.visual_soldier_pose(animations,clips,&soldier,{},0,&state)
	testing.expect(t,recoiled[14]!=baseline[14] && recoiled[8]==baseline[8] && recoiled[9]==baseline[9])
	soldier.arsenal.fired=false
	for _ in 0..<20 do draw.air_transition_step(&state,&soldier,res.AIR_TUNING,1.0/60)
	testing.expect(t,state.prone_recoil < 0.001)
	soldier.vitals.dead=true
	draw.air_transition_step(&state,&soldier,res.AIR_TUNING,1.0/60)
	testing.expect(t,state.prone_recoil==0)
}

// Recoil set to Soldat 1's: the recoil clips as the game plays them, and no prone kick.
@(test)
classic_recoil_is_soldat_1s :: proc(t: ^testing.T) {
	clips := res.air_animations_load("assets/data"); defer free(clips)
	animations, ok := res.animations_load("assets/data"); defer free(animations)
	testing.expect(t,ok)
	if !ok do return
	classic := res.Air_Styles{recoil=.Classic}
	soldier := sim.Soldier{active=true,body={direction=1,on_ground=true},controls={aim={100,0},stance=.Stand},pose={legs={id=.Stand,frame=1},body={id=.Recoil,frame=3}}}
	testing.expect(t,draw.visual_soldier_pose(animations,clips,&soldier,{},0,styles=classic)==sim.soldier_pose(animations,&soldier,{}))
	prone := sim.Soldier{active=true,body={direction=1,on_ground=true},controls={aim={100,0},stance=.Prone},pose={legs={id=.Prone,frame=26},body={id=.Prone,frame=26}},arsenal={fired=true}}
	state: draw.Air_Transition
	draw.air_transition_step(&state,&prone,res.AIR_TUNING,1.0/60)
	testing.expect(t,draw.visual_soldier_pose(animations,clips,&prone,{},0,&state,styles=classic)==sim.soldier_pose(animations,&prone,{}))
}
