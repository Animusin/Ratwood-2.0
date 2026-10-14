/obj/structure/mineral_door
	var/housing_resident_ckey
	var/datum/supporter_home/supporter_home

/obj/item/roguekey/townie/pre_attack(atom/target, mob/living/user, params)
	if(ishuman(user) && istype(target, /obj/structure/mineral_door))
		if(GLOB.supporter_housing.try_open(src, target, user))
			return TRUE
	return ..()

/obj/structure/mineral_door/wood/housing
	name = "home door"
	locked = TRUE
	keylock = TRUE
	// Ordinary wooden door: the lock can be picked and the door can burn or break.

/obj/structure/bell_common/housing
	name = "furnishings bell"
	light_outer_range = 4
	light_color = "#ffe5bd"
	desc = "Ring to preview and save your home. Examine for status; right-click for your archive and help. Only the homeowner may save."
	resistance_flags = INDESTRUCTIBLE | FIRE_PROOF | LAVA_PROOF | UNACIDABLE | ACID_PROOF
	var/datum/supporter_home/home

/obj/structure/bell_common/housing/attack_hand(mob/user)
	if(ishuman(user))
		home?.save_decor(user)

/obj/structure/bell_common/housing/examine(mob/user)
	. = ..()
	if(home && user?.ckey == home.owner_ckey && user.Adjacent(src))
		var/list/records = home.snapshot()
		. += span_notice(replacetext(html_encode(home.status_text(records)), "\n", "<br>"))

/obj/structure/bell_common/housing/attack_right(mob/user)
	if(!home || user?.ckey != home.owner_ckey || !user.Adjacent(src) || user.incapacitated())
		return
	to_chat(user, span_notice(replacetext(html_encode("[home.help_text()]\n\n[home.archive_text()]"), "\n", "<br>")))

/obj/structure/bell_common/housing/deconstruct(disassembled = TRUE)
	return

/turf/closed/indestructible/housing_hedge
	name = "dense boundary hedge"
	desc = "A dense green hedge marks the edge of the property."
	icon = 'icons/turf/roguewall.dmi'
	icon_state = "shroud1"
	color = "#47743b"
	baseturfs = /turf/closed/indestructible/housing_hedge
	CanAtmosPass = ATMOS_PASS_NO

/turf/closed/indestructible/housing_void
	name = "darkness"
	icon = 'icons/turf/roguewall.dmi'
	icon_state = "shroud1"
	color = "#000000"
	baseturfs = /turf/closed/indestructible/housing_void
	CanAtmosPass = ATMOS_PASS_NO

/turf/open/floor/rogue/housing_foyer
	parent_type = /turf/open/floor/rogue/ruinedwood
	name = "entrance landing"
	baseturfs = /turf/open/floor/rogue/housing_foyer

/turf/open/floor/rogue/housing_foyer/Enter(atom/movable/mover)
	if(isobj(mover) && (mover.density || isstructure(mover)))
		return FALSE
	return ..()

/turf/open/floor/rogue/housing_foyer/ChangeTurf(path, list/new_baseturfs, flags)
	SHOULD_CALL_PARENT(FALSE)
	return src // Building, digging and explosions cannot erase the round's return route.

/turf/open/floor/rogue/housing_foyer/Entered(atom/movable/mover, atom/old_location)
	. = ..()
	// forceMove/storage dumping bypasses Enter. Move obstructions away; never delete belongings.
	if(!isobj(mover) || (!mover.density && !isstructure(mover)) || istype(mover, /obj/structure/fluff/traveltile/housing))
		return
	var/datum/supporter_home/home = GLOB.supporter_housing.home_at(src)
	if(home)
		var/turf/destination
		for(var/turf/candidate in block(locate(home.x + 3, home.y + 6, home.z), locate(home.x + home.width - 4, home.y + home.height - 4, home.z)))
			if(home.decor_tile(candidate) && !candidate.density)
				destination = candidate
				break
		mover.forceMove(destination || home.outside)
	else if(isturf(old_location) && old_location != src)
		mover.forceMove(old_location)

/area/rogue/indoors/supporter_housing
	name = "Private home"
	no_special_item_retrieval = TRUE
	ceiling_protected = TRUE

/area/rogue/indoors/supporter_housing/Entered(atom/movable/occupant)
	. = ..()
	if(isliving(occupant))
		occupant.AddComponent(/datum/component/housing_activity)

#undef HOUSING_SAVE_COOLDOWN
