/obj/item/ammo_box/magazine/mm712x82
	name = "box magazine (7.12x82mm)"
	icon_state = "a762-50"
	ammo_type = /obj/item/ammo_casing/mm712x82
	caliber = CALIBER_712X82MM
	max_ammo = 50

/obj/item/ammo_box/magazine/mm712x82/hollow
	name = "box magazine (Hollow-Point 7.12x82mm)"
	ammo_type = /obj/item/ammo_casing/mm712x82/hollow

/obj/item/ammo_box/magazine/mm712x82/ap
	name = "box magazine (Armor Penetrating 7.12x82mm)"
	ammo_type = /obj/item/ammo_casing/mm712x82/ap

/obj/item/ammo_box/magazine/mm712x82/incen
	name = "box magazine (Incendiary 7.12x82mm)"
	ammo_type = /obj/item/ammo_casing/mm712x82/incen

/obj/item/ammo_box/magazine/mm712x82/match
	name = "box magazine (Match 7.12x82mm)"
	ammo_type = /obj/item/ammo_casing/mm712x82/match

/obj/item/ammo_box/magazine/mm712x82/bouncy
	name = "box magazine (Rubber 7.12x82mm)"
	ammo_type = /obj/item/ammo_casing/mm712x82/bouncy

/obj/item/ammo_box/magazine/mm712x82/bouncy/hicap
	name = "hi-cap box magazine (Rubber 7.12x82mm)"
	max_ammo = 150

/obj/item/ammo_box/magazine/mm712x82/update_icon_state()
	. = ..()
	icon_state = "a762-[min(round(ammo_count(), 10), 50)]" //Min is used to prevent high capacity magazines from attempting to get sprites with larger capacities

/obj/item/ammo_box/magazine/minigun22
	name = "Minigun drum (.22 LR)"
	icon = 'icons/obj/weapons/guns/ammo.dmi'
	icon_state = "22minigun_drum"
	ammo_type = /obj/item/ammo_casing/minigun22
	w_class = WEIGHT_CLASS_NORMAL
	caliber = CALIBER_22LR
	max_ammo = 300
