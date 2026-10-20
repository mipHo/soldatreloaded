package draw

import sim "../../../core/game"
import "../../../core/utils"

// The soldiers, living and dead, each its gostek where the frame shows it; with
// `original`, each but `me` as Soldat 1's, whatever its style (draw_gostek): the player
// still sees themselves in the style they picked. From the C client's render/render.c.

@(private = "package")
draw_soldiers :: proc(art: ^Art, game: ^sim.Game, frame: ^Frame, grenade_color: Maybe(utils.Rgba), original := false, me: sim.Soldier_Id = 0) {
	standing := sim.round_standing(&game.round) // the round standing, no jets burn, though their buttons stay held
	for &soldier, id in game.world.soldiers {
		if !soldier.active || soldier.team == .Spectator do continue
		hair_player: ^Poa_Hair_Player
		if id < len(art.gostek.poa.players) do hair_player = &art.gostek.poa.players[id]
		draw_gostek(&art.gostek, &soldier, &frame.figures[id], shirt_worn(&soldier), grenade_color, standing, original && sim.Soldier_Id(id) != me, hair_player, frame.alpha)
	}
}
