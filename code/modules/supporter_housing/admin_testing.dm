GLOBAL_LIST_EMPTY(housing_test_sessions)

// One bounded, round-local snapshot per admin. This subtype never connects to SQL.
/datum/housing_storage/housing_test
	var/list/saved_records = list()
	var/saved_revision = 0
	var/saved_time = 0
	var/unavailable = FALSE

/datum/housing_storage/housing_test/read_home(owner_ckey)
	if(unavailable)
		return null
	return list("found" = !!saved_revision, "revision" = saved_revision, "records" = json_decode(json_encode(saved_records)), "saved_age" = (world.time - saved_time) / 10)

/datum/housing_storage/housing_test/write_home(owner_ckey, list/records, expected_revision)
	if(unavailable || expected_revision != saved_revision || isnull(GLOB.supporter_housing.validate_records(records)))
		return FALSE
	saved_records = json_decode(json_encode(records))
	saved_revision++
	saved_time = world.time
	return TRUE

/datum/housing_test_session
	var/owner_ckey
	var/tier = 1 // null simulates an unavailable subscription service; 0 simulates expiry.
	var/datum/housing_storage/housing_test/storage = new
	var/datum/supporter_home/home
	var/turf/return_turf
	var/return_x
	var/return_y
	var/return_z
	var/plot_x
	var/plot_y
	var/busy = FALSE

/datum/housing_test_session/proc/authorized(mob/user)
	return user?.ckey == owner_ckey && check_rights_for(user.client, R_ADMIN)

/datum/housing_test_session/proc/subscription_profile(mob/user)
	return authorized(user) ? tier : null

/datum/housing_test_session/proc/return_destination()
	var/turf/origin = locate(return_x, return_y, return_z)
	var/list/candidates = list(origin)
	for(var/direction in GLOB.cardinals)
		candidates += get_step(origin, direction)
	for(var/turf/tile as anything in candidates)
		if(tile && isfloorturf(tile) && !tile.density)
			var/blocked = FALSE
			for(var/obj/object in tile)
				if(object.density)
					blocked = TRUE
					break
			if(!blocked)
				return tile
	return null

/datum/housing_test_session/proc/load_home(mob/user)
	if(!authorized(user) || !ishuman(user) || busy || home?.saving)
		return FALSE
	if(!(tier in list(1, 2, 3)))
		to_chat(user, span_warning("ADMIN TEST: creation/reload requires a simulated Wizard, Cultist or Assistant subscription. The existing home and saved test snapshot are kept."))
		return FALSE
	var/datum/supporter_housing/manager = GLOB.supporter_housing
	if(manager.loading)
		to_chat(user, span_warning("Another home is loading. Try again shortly."))
		return FALSE
	var/list/saved = storage.read_home(owner_ckey)
	if(!saved)
		to_chat(user, span_warning("ADMIN TEST: simulated storage is unavailable; the current home and save are unchanged."))
		return FALSE
	return_turf = return_destination()
	if(!return_turf)
		to_chat(user, span_warning("The test home's return location is blocked. Restore its floor before reloading."))
		return FALSE
	busy = TRUE
	var/test_key = "admin-test:[owner_ckey]"
	if(!plot_x)
		home = manager.create_home(test_key, tier, saved)
		if(home)
			plot_x = home.x
			plot_y = home.y
	else
		manager.loading = TRUE
		// Evacuate even occupants hidden inside containers before clearing the test plot.
		for(var/mob/occupant as anything in GLOB.mob_list)
			var/turf/tile = get_turf(occupant)
			if(tile?.z == manager.level.z_value && tile.x >= plot_x && tile.x < plot_x + 21 && tile.y >= plot_y && tile.y < plot_y + 23)
				occupant.forceMove(return_turf)
		if(home?.entrance)
			qdel(home.entrance)
		manager.homes -= test_key
		for(var/turf/tile in block(locate(plot_x, plot_y, manager.level.z_value), locate(plot_x + 20, plot_y + 22, manager.level.z_value)))
			// Delete nested objects before containers can dump them into an already-cleared tile.
			for(var/obj/object in tile.GetAllContents())
				qdel(object)
			if(istype(tile, /turf/open/floor/rogue/housing_foyer))
				var/turf/open/floor/rogue/housing_foyer/landing = tile
				landing.allow_test_reset = TRUE
			tile.ChangeTurf(/turf/closed/indestructible/housing_void)
		if(home)
			qdel(home)
		home = manager.load_home_at(test_key, tier, saved, plot_x, plot_y)
		if(home)
			manager.homes[test_key] = home
		manager.loading = FALSE
	if(home)
		home.owner_ckey = owner_ckey
		home.test_session = src
		home.outside = return_turf
		home.outside_x = return_turf.x
		home.outside_y = return_turf.y
		home.outside_z = return_turf.z
		home.interior.locked = FALSE
		home.entrance = new /obj/structure/fluff/traveltile/housing(return_turf)
		home.entrance.home = home
		home.entrance.is_exterior = TRUE
		home.entrance.name = "admin test home passage"
	busy = FALSE
	if(!home)
		to_chat(user, span_warning("The test home could not load. Its in-memory save is kept."))
		return FALSE
	if(authorized(user))
		user.forceMove(get_turf(home.exit))
		to_chat(user, span_notice("ADMIN TEST: [home.tier_name()] home ready. Use its bell to preview/save without the normal save cooldown. Reload through Admin > Test Supporter Home. No Patreon or database connection is used; test saves last only this round."))
	log_admin("[key_name(user)] loaded supporter housing test tier [tier].")
	return TRUE

/client/proc/test_supporter_home()
	set name = "Test Supporter Home"
	set category = "Admin"
	if(!check_rights(R_ADMIN))
		return
	var/datum/housing_test_session/session = GLOB.housing_test_sessions[ckey]
	if(!session)
		var/turf/origin = get_turf(mob)
		if(!ishuman(mob) || !isfloorturf(origin) || origin.density || GLOB.supporter_housing.home_at(origin))
			to_chat(src, span_warning("Take control of a human and stand on an ordinary floor outside a supporter home first."))
			return
		session = new
		session.owner_ckey = ckey
		session.return_turf = origin
		session.return_x = origin.x
		session.return_y = origin.y
		session.return_z = origin.z
		GLOB.housing_test_sessions[ckey] = session
	var/action = input(src, "Private test home. Saves are kept in memory only until round end; real house saves and subscriptions are untouched.", "Housing tests") as null|anything in list("Create / enter", "Reload saved test home", "Set test subscription", "Toggle storage outage", "Return outside")
	if(!action || !session.authorized(mob) || session.busy || session.home?.saving)
		return
	switch(action)
		if("Set test subscription")
			var/choice = input(src, "A new size takes effect on the next reload. Expiry/outage prevents new saves and reloads while retaining the current test home.", "Test subscription") as null|anything in list("Wizard", "Cultist", "Assistant", "Expired", "Service unavailable")
			if(!choice || !session.authorized(mob) || session.busy || session.home?.saving)
				return
			switch(choice)
				if("Wizard")
					session.tier = 1
				if("Cultist")
					session.tier = 2
				if("Assistant")
					session.tier = 3
				if("Expired")
					session.tier = 0
				if("Service unavailable")
					session.tier = null
			to_chat(src, span_notice("ADMIN TEST subscription: [choice]. Reload to apply a different home size."))
		if("Toggle storage outage")
			session.storage.unavailable = !session.storage.unavailable
			to_chat(src, span_notice("ADMIN TEST storage: [session.storage.unavailable ? "unavailable" : "available"]. The saved snapshot is kept."))
		if("Return outside")
			var/turf/outside = session.return_destination()
			if(outside)
				mob.forceMove(outside)
		if("Create / enter")
			if(session.home)
				mob.forceMove(get_turf(session.home.exit))
			else
				session.load_home(mob)
		if("Reload saved test home")
			if(alert(src, "Discard the unsaved test layout and reload your test snapshot? Occupants are returned outside; objects left in the test plot are removed. Your real home is untouched.", "Reload test home", "Reload", "Cancel") == "Reload" && session.authorized(mob))
				session.load_home(mob)
