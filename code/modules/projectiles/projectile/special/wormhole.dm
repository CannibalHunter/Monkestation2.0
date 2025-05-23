/obj/projectile/beam/wormhole
	name = "bluespace beam"
	icon_state = "spark"
	hitsound = SFX_SPARKS
	damage = 0
	pass_flags = PASSGLASS | PASSTABLE | PASSGRILLE | PASSMOB
	//Weakref to the thing that shot us
	var/datum/weakref/gun
	color = "#33CCFF"
	tracer_type = /obj/effect/projectile/tracer/wormhole
	impact_type = /obj/effect/projectile/impact/wormhole
	muzzle_type = /obj/effect/projectile/muzzle/wormhole
	hitscan = TRUE

/obj/projectile/beam/wormhole/orange
	name = "orange bluespace beam"
	color = "#FF6600"

/obj/projectile/beam/wormhole/Initialize(mapload, obj/item/ammo_casing/energy/wormhole/casing)
	. = ..()
	if(casing)
		gun = casing.gun


/obj/projectile/beam/wormhole/on_hit(atom/target, blocked = 0, pierce_hit)
	var/obj/item/gun/energy/wormhole_projector/projector = gun.resolve()
	if(!projector)
		qdel(src)
		return BULLET_ACT_BLOCK

	. = ..()
	playsound(loc, pick('sound/effects/portal_open_1.ogg' , 'sound/effects/portal_open_2.ogg' , 'sound/effects/portal_open_3.ogg'), 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	projector.create_portal(src, get_turf(src))
