/datum/supporter_home
	var/datum/supporter_housing/manager
	var/owner_ckey
	var/tier
	var/x
	var/y
	var/z
	var/width
	var/height
	var/decor_limit
	var/revision = 0
	var/list/archive = list()
	var/last_save_attempt = -INFINITY
	var/saving = FALSE
	var/snapshot_error
	var/list/saved_layout
	var/last_saved_age
	var/last_saved_seen = 0
	var/owner_welcomed = FALSE
	var/datum/housing_test_session/test_session
	var/transferring = FALSE
	var/obj/structure/mineral_door/exterior
	var/obj/structure/mineral_door/wood/housing/interior
	var/obj/structure/fluff/traveltile/housing/entrance
	var/obj/structure/fluff/traveltile/housing/exit
	var/obj/structure/bell_common/housing/bell
	var/turf/outside
	var/outside_x
	var/outside_y
	var/outside_z

/datum/supporter_home/New(datum/supporter_housing/new_manager, new_owner, new_tier, new_x, new_y, new_z)
	manager = new_manager
	owner_ckey = new_owner
	tier = new_tier
	x = new_x
	y = new_y
	z = new_z
	var/list/profile = manager.profiles[tier]
	width = profile["width"]
	height = profile["height"]
	decor_limit = profile["limit"]
	return ..()

/datum/supporter_home/proc/contains(turf/tile)
	return tile && tile.z == z && tile.x >= x && tile.x < x + width && tile.y >= y && tile.y < y + height

/datum/supporter_home/proc/decor_tile(turf/tile)
	// Keep both the bell and the approach to the inner door unobstructed.
	return contains(tile) && tile.x >= x + 3 && tile.x <= x + width - 4 && tile.y >= y + 6 && tile.y <= y + height - 4 && !(tile.x == x + FLOOR(width / 2, 1) && tile.y <= y + 8)

/datum/supporter_home/proc/protected_tile(turf/tile)
	return contains(tile) && !decor_tile(tile)

/datum/supporter_home/proc/setup(list/records, found, saved_revision)
	revision = saved_revision
	capture_base_turfs()
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		for(var/obj/structure/fluff/traveltile/housing/portal in tile)
			exit = portal
			portal.home = src
		for(var/obj/structure/mineral_door/wood/housing/door in tile)
			interior = door
		for(var/obj/structure/bell_common/housing/save_bell in tile)
			bell = save_bell
			save_bell.home = src
		if(found)
			for(var/obj/decor in tile)
				if(manager.decor_types["[decor.type]"])
					qdel(decor)
	if(!exit || !interior || !bell)
		return FALSE
	var/list/ordered_records = list()
	for(var/list/record as anything in records)
		if(!record["archived"])
			ordered_records += list(record)
	for(var/list/record as anything in records)
		if(record["archived"])
			ordered_records += list(record)
	records = ordered_records
	restore_walls(records)
	var/restored = 0
	var/stations = 0
	var/lights = 0
	for(var/list/record as anything in records)
		if(record["kind"] == "wall")
			continue
		var/turf/destination = locate(x + record["x"] - 1, y + record["y"] - 1, z)
		var/path = manager.decor_types[record["type"]]
		var/workstation = manager.record_category_count(record, "station")
		var/is_light = manager.record_category_count(record, "light")
		var/record_size = manager.record_size(record)
		if(!placement_fits(path, destination) || !restore_slot_available(path, destination) || restored + record_size > decor_limit || manager.record_required_tier(record) > tier || stations + workstation > tier * 2 || lights + is_light > tier * 4 + 4)
			archive += list(record.Copy())
			continue
		var/obj/decor = new path(destination)
		manager.prepare_restored(decor)
		unpack_contents(decor, record)
		decor.dir = record["dir"]
		if(istype(decor, /obj/structure/roguewindow/openclose))
			var/obj/structure/roguewindow/openclose/window = decor
			window.lockdir = window.dir
		if(record["color"])
			decor.color = record["color"]
		restored += record_size
		stations += workstation
		lights += is_light
	if(!found)
		for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
			for(var/obj/decor in tile)
				if(manager.decor_types["[decor.type]"])
					manager.prepare_restored(decor)
	if(found)
		saved_layout = snapshot()
	return TRUE

/datum/supporter_home/proc/bind_entrance(obj/structure/mineral_door/door)
	exterior = door
	outside = get_turf(door)
	outside_x = outside.x
	outside_y = outside.y
	outside_z = outside.z
	door.supporter_home = src
	interior.lockhash = door.lockhash
	interior.lockid = door.lockid
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		for(var/obj/structure/mineral_door/restored_door in tile)
			if(restored_door.housing_decoration)
				restored_door.lockhash = door.lockhash
				restored_door.lockid = door.lockid
	entrance = new(outside)
	entrance.home = src
	entrance.is_exterior = TRUE
	RegisterSignal(door, COMSIG_QDELETING, PROC_REF(exterior_deleted))
	update_entrance()

/datum/supporter_home/proc/exterior_deleted(datum/source)
	SIGNAL_HANDLER
	exterior = null
	update_entrance()

/datum/supporter_home/proc/update_entrance()
	if(entrance)
		entrance.alpha = !exterior || !exterior.density ? 255 : 0

/datum/supporter_home/proc/open_with_key(obj/item/roguekey/key, mob/living/carbon/human/user, prepared = FALSE)
	if(!exterior || key.lockhash != exterior.lockhash || user.get_active_held_item() != key)
		return TRUE
	if(exterior.door_opened)
		return FALSE // Normal door handling remains available.
	var/datum/housing_action_guard/guard = new(user, outside)
	if(!guard.check())
		qdel(guard)
		return TRUE
	if(!prepared)
		to_chat(user, span_notice("I begin opening the entrance to the home..."))
		if(!do_after(user, 5 SECONDS, target = exterior, extra_checks = CALLBACK(guard, TYPE_PROC_REF(/datum/housing_action_guard, check))))
			qdel(guard)
			return TRUE
	if(guard.check() && exterior && key.lockhash == exterior.lockhash && user.get_active_held_item() == key)
		exterior.locked = FALSE
		exterior.force_open()
		update_entrance()
		to_chat(user, span_notice("The entrance is open. Passing through takes a little time; others can follow."))
	qdel(guard)
	return TRUE

/datum/supporter_home/proc/return_destination()
	// Resolve coordinates afresh after turf replacement. The exterior lock governs entry,
	// never return travel: arriving in its doorway must not imprison guests inside.
	var/turf/origin = locate(outside_x, outside_y, outside_z)
	var/list/candidates = list(origin)
	for(var/direction in GLOB.cardinals)
		candidates += get_step(origin, direction)
	for(var/turf/candidate as anything in candidates)
		if(!candidate || candidate.density || !isfloorturf(candidate))
			continue
		var/blocked = FALSE
		for(var/obj/obstruction in candidate)
			if(obstruction.density && obstruction != exterior)
				blocked = TRUE
				break
		if(!blocked)
			return candidate
	return null

/datum/supporter_home/proc/has_fire_or_combat()
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		if(locate(/obj/effect/hotspot) in tile)
			return TRUE
		for(var/obj/burning_object in tile)
			if(burning_object.resistance_flags & ON_FIRE)
				return TRUE
		for(var/mob/living/occupant in tile)
			if(occupant.on_fire || occupant.cmode || world.time < occupant.housing_last_attack + 15 SECONDS)
				return TRUE
	return FALSE

/datum/supporter_home/proc/snapshot()
	snapshot_error = null
	var/list/records = list()
	if(!snapshot_walls(records))
		return null
	var/active_count = 0
	var/stations = 0
	var/lights = 0
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		if(!decor_tile(tile))
			continue
		var/tile_count = 0
		var/dense_count = 0
		for(var/obj/decor in tile)
			if(!manager.decor_types["[decor.type]"])
				continue
			if(!placement_fits(decor.type, tile))
				snapshot_error = "[initial(decor.name)] does not fit here. Move it away from walls and the entrance."
				return null
			tile_count++
			dense_count += initial(decor.density) ? 1 : 0
			if(tile_count > 3 || dense_count > 1)
				snapshot_error = "Too many furnishings share the space around [initial(decor.name)]. Separate them (at most 3 small objects or 1 solid furnishing per tile)."
				return null
			// Only approved small items in furniture storage may add bounded contents.
			var/list/record = list("type" = "[decor.type]", "x" = tile.x - x + 1, "y" = tile.y - y + 1, "dir" = decor.dir, "color" = istext(decor.color) ? decor.color : null)
			if(!pack_contents(decor, record))
				return null
			active_count += manager.record_size(record)
			stations += manager.record_category_count(record, "station")
			lights += manager.record_category_count(record, "light")
			if(!manager.valid_record(record))
				snapshot_error = "[initial(decor.name)] has an unsupported facing or paint colour. Rotate it to a cardinal direction or remove its paint."
				return null
			records += list(record)
	if(active_count > decor_limit || stations > tier * 2 || lights > tier * 4 + 4)
		snapshot_error = "Over the limit: furnishings [active_count]/[decor_limit], workstations [stations]/[tier * 2], lights [lights]/[tier * 4 + 4]. Remove the excess from the home before saving."
		return null
	for(var/list/archived_record as anything in archive)
		var/list/inactive_record = archived_record.Copy()
		inactive_record["archived"] = TRUE
		records += list(inactive_record)
	var/wall_count = 0
	var/stored_items = 0
	for(var/list/record as anything in records)
		wall_count += record["kind"] == "wall" ? 1 : 0
		stored_items += record["kind"] == "wall" ? 0 : manager.record_size(record)
	if(wall_count > 64 || stored_items > 160)
		snapshot_error = "Saved storage is full, including the archive: items [stored_items]/160, wall and floor changes [wall_count]/64. Remove furnishings or undo structural changes before saving."
		return null
	if(length(json_encode(records)) > 60000)
		snapshot_error = "This layout is too large to save. Reduce the furnishings or wall changes."
		return null
	snapshot_error = "The layout contains an unsupported position, facing or paint colour. Check the furnishings and walls."
	var/list/validated = manager.validate_records(records)
	if(!isnull(validated))
		snapshot_error = null
	return validated

/datum/supporter_home/proc/save_decor(mob/living/carbon/human/user)
	if(!user || user.ckey != owner_ckey)
		to_chat(user, span_warning("Only the homeowner can save this home."))
		return FALSE
	if(!save_role_allowed(user))
		to_chat(user, span_warning("Saving requires a city, Mercenary or Adventurer profession. Your saved home is kept."))
		return FALSE
	if(!user.Adjacent(bell) || user.incapacitated() || saving)
		return FALSE
	if(!test_session && world.time < last_save_attempt + HOUSING_SAVE_COOLDOWN)
		to_chat(user, span_warning("Try saving again in [ceil((last_save_attempt + HOUSING_SAVE_COOLDOWN - world.time) / 10)] seconds."))
		return FALSE
	if(has_fire_or_combat())
		to_chat(user, span_warning("I cannot save the home during a fire or a fight."))
		return FALSE
	saving = TRUE
	var/list/preview = snapshot()
	if(isnull(preview))
		to_chat(user, span_warning("[snapshot_error] Your previous save is unchanged."))
		saving = FALSE
		return FALSE
	var/choice = confirm_save(user, preview)
	var/success = FALSE
	if(choice == "Save" && user?.ckey == owner_ckey && save_role_allowed(user) && user.Adjacent(bell) && !user.incapacitated())
		last_save_attempt = world.time
		var/profile = test_session ? test_session.subscription_profile(user) : manager.subscription_profile(user)
		if(isnull(profile))
			to_chat(user, span_warning("The subscription service is unavailable. Try again later; your saved home and archive are kept."))
		else if(!profile)
			to_chat(user, span_warning("Saving requires a verified active Wizard subscription or higher. Your previous save is unchanged."))
		else if(user.ckey == owner_ckey && save_role_allowed(user) && user.Adjacent(bell) && !user.incapacitated() && !has_fire_or_combat())
			var/list/records = snapshot()
			if(isnull(records))
				to_chat(user, span_warning("[snapshot_error] Your previous save is unchanged."))
			else if(layout_signature(records) != layout_signature(preview))
				to_chat(user, span_warning("The furnishings changed while you were confirming. Ring again to review the new layout; your previous save is unchanged."))
			else
				var/datum/housing_storage/save_storage = test_session ? test_session.storage : manager.storage
				success = save_storage.write_home(owner_ckey, records, revision)
				if(success)
					revision++
					saved_layout = records
					last_saved_age = 0
					last_saved_seen = world.time
					var/success_message = test_session ? "ADMIN TEST: layout saved in memory for test reloads only. It will disappear at round end; your real house save is untouched." : "Your home's furnishings have been saved for future rounds."
					to_chat(user, span_notice(success_message))
					if(profile != tier)
						to_chat(user, span_notice("[test_session ? "Your simulated subscription" : "Your verified subscription"] is [tier_name(profile)]; this round's home stays [tier_name()]. On the next load, furnishings that need more space or a higher tier will be kept in the archive, not deleted."))
				else
					to_chat(user, span_warning("The save failed or another server changed it. Your previous save has not been overwritten."))
	saving = FALSE
	return success

/datum/supporter_home/proc/save_role_allowed(mob/living/carbon/human/user)
	return test_session ? test_session.authorized(user) : manager.eligible_resident(user)

/datum/supporter_home/proc/live_decor_count()
	var/count = 0
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		for(var/obj/decor in tile)
			if(manager.decor_types["[decor.type]"])
				count += 1 + contained_item_count(decor)
	return count

// Called at the destination, both before work and immediately before consuming materials.
/proc/housing_allows_construction(turf/destination, datum/crafting_recipe/recipe, mob/user)
	var/reason = housing_construction_error(destination, recipe)
	if(reason && user)
		to_chat(user, span_warning(reason))
	return !reason

/proc/housing_construction_error(turf/destination, datum/crafting_recipe/recipe)
	var/datum/supporter_home/home = GLOB.supporter_housing.home_at(destination)
	if(!home)
		return null
	var/structural_result = ispath(recipe.result, /turf)
	if(structural_result && !GLOB.supporter_housing.wall_types["[recipe.result]"])
		return "This wall or floor cannot be saved in a home. Choose another building material."
	if(structural_result ? !home.structural_tile(destination) : home.protected_tile(destination))
		return "Keep the entrance landing and approach clear. Build inside the furnishing area."
	var/list/results = islist(recipe.result) ? recipe.result : list(recipe.result)
	var/additions = 0
	var/new_stations = 0
	var/new_lights = 0
	for(var/path in results)
		if(GLOB.supporter_housing.decor_types["[path]"])
			if(!home.placement_fits(path, destination))
				return "This furnishing does not fit here. Move the building site away from walls and the entrance."
			additions++
			new_stations += GLOB.supporter_housing.is_workstation(path)
			new_lights += GLOB.supporter_housing.is_light(path)
	if(additions && home.live_decor_count() + additions > home.decor_limit)
		return "This would exceed the furnishings limit: [home.live_decor_count() + additions]/[home.decor_limit]."
	if(new_stations && home.live_category_count("station") + new_stations > home.tier * 2)
		return "This would exceed the workstation limit: [home.live_category_count("station") + new_stations]/[home.tier * 2]."
	if(new_lights && home.live_category_count("light") + new_lights > home.tier * 4 + 4)
		return "This would exceed the light limit: [home.live_category_count("light") + new_lights]/[home.tier * 4 + 4]."
	return null

/datum/supporter_home/proc/live_category_count(category)
	var/count = 0
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		for(var/obj/decor in tile)
			if(!manager.decor_types["[decor.type]"])
				continue
			count += category == "station" ? manager.is_workstation(decor.type) : manager.is_light(decor.type)
			count += contained_item_count(decor, category)
	return count

/proc/housing_allows_blueprint(turf/destination, path)
	if(!GLOB.supporter_housing.home_at(destination))
		return TRUE
	var/datum/crafting_recipe/recipe = new
	recipe.result = path
	. = housing_allows_construction(destination, recipe)
	qdel(recipe)
