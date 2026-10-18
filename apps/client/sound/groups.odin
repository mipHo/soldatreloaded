package sound

import "core:strings"

import res "../../../core/resources"

// Which of the player's sound levels (Sound_Settings' levels) each sample plays at: a
// gun's shots, reload and draw are the gun's, the rest the event's. A sample not named
// here, a mod's own, plays as it is.

@(private = "file", rodata)
GROUPS := [?]struct {
	name:  string,
	group: res.Sound_Group,
} {
	{"deserteagle-fire.wav", .Desert_Eagles}, {"deserteagle-reload.wav", .Desert_Eagles},
	{"mp5-fire.wav", .MP5}, {"mp5-reload.wav", .MP5},
	{"ak74-fire.wav", .AK74}, {"ak74-reload.wav", .AK74},
	{"steyraug-fire.wav", .Steyr_AUG}, {"steyraug-reload.wav", .Steyr_AUG},
	{"spas12-fire.wav", .Spas12}, {"spas12-reload.wav", .Spas12},
	{"ruger77-fire.wav", .Ruger77}, {"ruger77-reload.wav", .Ruger77},
	{"m79-fire.wav", .M79}, {"m79-reload.wav", .M79},
	{"barretm82-fire.wav", .Barrett}, {"barretm82-reload.wav", .Barrett},
	{"m249-fire.wav", .Minimi}, {"m249-reload.wav", .Minimi},
	{"minigun-fire.wav", .Minigun}, {"minigun-reload.wav", .Minigun}, {"minigun-start.wav", .Minigun}, {"minigun-end.wav", .Minigun},
	{"colt1911-fire.wav", .USSOCOM}, {"colt1911-reload.wav", .USSOCOM}, {"changespin.wav", .USSOCOM},
	{"knife.wav", .Knife}, {"slash.wav", .Knife},
	{"chainsaw-d.wav", .Chainsaw}, {"chainsaw-m.wav", .Chainsaw}, {"chainsaw-o.wav", .Chainsaw}, {"chainsaw-r.wav", .Chainsaw},
	{"law.wav", .LAW}, {"law-start.wav", .LAW}, {"law-end.wav", .LAW},
	{"grenade-throw.wav", .Grenades}, {"grenade-pullout.wav", .Grenades}, {"grenade-bounce.wav", .Grenades},
	{"grenade-explosion.wav", .Explosions}, {"m79-explosion.wav", .Explosions}, {"explosion-erg.wav", .Explosions}, {"hum.wav", .Explosions},
	{"dist-gun1.wav", .Distant_Battle}, {"dist-gun2.wav", .Distant_Battle}, {"dist-gun3.wav", .Distant_Battle},
	{"dist-gun4.wav", .Distant_Battle}, {"dist-grenade.wav", .Distant_Battle}, {"dist-m79.wav", .Distant_Battle},
	{"hit-arg.wav", .Hits}, {"hit-arg2.wav", .Hits}, {"hit-arg3.wav", .Hits}, {"dead-hit.wav", .Hits}, {"bryzg.wav", .Hits},
	{"boomheadshot.wav", .Headshots}, {"headchop.wav", .Headshots},
	{"death.wav", .Deaths}, {"death2.wav", .Deaths}, {"death3.wav", .Deaths}, {"playerdeath.wav", .Deaths},
	{"bodyfall.wav", .Deaths}, {"bonecrack.wav", .Deaths},
	{"ric.wav", .Ricochets}, {"ric2.wav", .Ricochets}, {"ric3.wav", .Ricochets}, {"ric4.wav", .Ricochets},
	{"ric5.wav", .Ricochets}, {"ric6.wav", .Ricochets}, {"ric7.wav", .Ricochets}, {"bulletby.wav", .Ricochets},
	{"bulletby2.wav", .Ricochets}, {"bulletby3.wav", .Ricochets}, {"bulletby4.wav", .Ricochets}, {"bulletby5.wav", .Ricochets},
	{"colliderhit.wav", .Ricochets}, {"weaponhit.wav", .Ricochets}, {"bounce.wav", .Ricochets},
	{"spawn.wav", .Spawns}, {"wermusic.wav", .Spawns},
	{"capture.wav", .Flags}, {"ctf.wav", .Flags}, {"infilt-point.wav", .Flags}, {"flag.wav", .Flags}, {"flag2.wav", .Flags},
	{"takegun.wav", .Pickups}, {"takemedikit.wav", .Pickups}, {"pickupgun.wav", .Pickups}, {"kit-fall.wav", .Pickups}, {"kit-fall2.wav", .Pickups},
	{"changeweapon.wav", .Gun_Handling}, {"throwgun.wav", .Gun_Handling}, {"shell.wav", .Gun_Handling}, {"shell2.wav", .Gun_Handling},
	{"gaugeshell.wav", .Gun_Handling}, {"clipfall.wav", .Gun_Handling}, {"scope.wav", .Gun_Handling},
	{"scopeback.wav", .Gun_Handling}, {"scoperun.wav", .Gun_Handling},
	{"step.wav", .Movement}, {"step2.wav", .Movement}, {"step3.wav", .Movement}, {"step4.wav", .Movement},
	{"step5.wav", .Movement}, {"step6.wav", .Movement}, {"step7.wav", .Movement}, {"step8.wav", .Movement},
	{"water-step.wav", .Movement}, {"jump.wav", .Movement}, {"crouch.wav", .Movement}, {"crouch-move.wav", .Movement},
	{"crouch-movel.wav", .Movement}, {"prone-move.wav", .Movement}, {"goprone.wav", .Movement}, {"standup.wav", .Movement},
	{"roll.wav", .Movement}, {"fall.wav", .Movement}, {"fall-hard.wav", .Movement}, {"stop.wav", .Movement},
	{"rocketz.wav", .Jets},
	{"sfx_wind.wav", .World}, {"lava.wav", .World}, {"arg.wav", .World}, {"regenerate.wav", .World},
	{"onfire.wav", .World}, {"firecrack.wav", .World}, {"ts.wav", .World},
	{"match.wav", .Antics}, {"roar.wav", .Antics}, {"piss.wav", .Antics}, {"mercy.wav", .Antics},
	{"stuff.wav", .Antics}, {"spit.wav", .Antics}, {"smoke.wav", .Antics},
	{"signal.wav", .Clock},
	{"menuclick.wav", .Menus},
}

// The group `name` plays in; none for a sample not named.
sound_group :: proc(name: string) -> (group: res.Sound_Group, ok: bool) {
	if strings.has_prefix(name, "radio/") do return .Radio, true
	for entry in GROUPS {
		if entry.name == name do return entry.group, true
	}
	return
}
