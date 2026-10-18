package menu

import res "../../../core/resources"
import "../ui"

// The Settings page's Sound tab: the volume and the sound's effects, then each kind of
// sound's own volume over it (Sound_Settings' levels), every gun's, then the game's
// events. From 0, none, to 200 percent; 100 as the game has it.

@(private = "file", rodata)
GROUP_NAMES := [res.Sound_Group]string {
	.Desert_Eagles  = "Desert Eagles",
	.MP5            = "HK MP5",
	.AK74           = "AK-74",
	.Steyr_AUG      = "Steyr AUG",
	.Spas12         = "Spas-12",
	.Ruger77        = "Ruger 77",
	.M79            = "M79",
	.Barrett        = "Barrett M82A1",
	.Minimi         = "FN Minimi",
	.Minigun        = "Minigun",
	.USSOCOM        = "USSOCOM",
	.Knife          = "Combat Knife",
	.Chainsaw       = "Chainsaw",
	.LAW            = "LAW",
	.Grenades       = "Grenades",
	.Explosions     = "Explosions",
	.Distant_Battle = "Distant battle",
	.Hits           = "Hits",
	.Headshots      = "Headshots",
	.Deaths         = "Deaths",
	.Ricochets      = "Ricochets and whizzes",
	.Spawns         = "Spawns",
	.Flags          = "Flags",
	.Pickups        = "Pickups",
	.Gun_Handling   = "Changing guns, shells",
	.Movement       = "Steps and moves",
	.Jets           = "Jets",
	.World          = "The map: wind, lava, fire",
	.Antics         = "Idle antics",
	.Radio          = "Radio",
	.Clock          = "Clock",
	.Menus          = "Menu clicks",
}

tab_sound :: proc(menu: ^Menu) {
	k := &menu.kit
	config := menu.config
	ui.section(k, "SOUND")
	ui.slider(k, "Volume", &config.sound.volume, 0, 100, 5, "%d%%")
	ui.toggle(k, "Distant battle sounds", &config.sound.battle_effects)
	ui.toggle(k, "Deafening blasts", &config.sound.explosion_effects)
	levels := res.sound_levels(&config.sound.levels)
	ui.section(k, "EACH SOUND'S OWN VOLUME")
	reset_row(menu)
	ui.section(k, "WEAPONS")
	for group in res.Sound_Group.Desert_Eagles ..= res.Sound_Group.Grenades do ui.slider(k, GROUP_NAMES[group], &levels[group], 0, 200, 10, "%d%%")
	ui.section(k, "EVENTS")
	for group in res.Sound_Group.Explosions ..= res.Sound_Group.Menus do ui.slider(k, GROUP_NAMES[group], &levels[group], 0, 200, 10, "%d%%")
}

// Every level back to 100 percent.
@(private = "file")
reset_row :: proc(menu: ^Menu) {
	k := &menu.kit
	r := ui.row(k, ui.ROW_H, true)
	if !r.shown do return
	ui.row_label(k, r, "Every sound as the game has it")
	bw := ui.button_w(k, "Reset")
	if ui.button_at(k, ui.ctrl_x(r) + ui.ctrl_w(r) - bw, ui.ctrl_y(r), bw, ui.CTRL_H, "Reset", false, false) {
		menu.config.sound.levels = res.SOUND_LEVELS_DEFAULT
	}
}
