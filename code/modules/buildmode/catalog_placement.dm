/datum/buildmode/proc/select_catalog_path(target_type, toggle = FALSE)
	if(!(target_type in buildmode_catalog_entries()))
		return FALSE
	if(toggle && selected_path == target_type && istype(mode, /datum/buildmode_mode/catalog))
		clear_catalog_selection()
		return TRUE
	selected_path = target_type
	if(!istype(mode, /datum/buildmode_mode/catalog))
		change_mode(/datum/buildmode_mode/catalog)
	remember_catalog_path(target_type)
	refresh_spawn_preview()
	return TRUE

/datum/buildmode/proc/clear_catalog_selection()
	catalog_status = null
	selected_path = null
	clear_spawn_preview()
	SStgui.update_uis(src)

/datum/buildmode/proc/clear_spawn_preview()
	if(spawn_preview)
		holder?.images -= spawn_preview
		spawn_preview.loc = null
		spawn_preview = null

/datum/buildmode/proc/refresh_spawn_preview()
	var/turf/previous_turf = spawn_preview?.loc
	clear_spawn_preview()
	if(!selected_path || !istype(mode, /datum/buildmode_mode/catalog))
		return
	var/atom/target_type = selected_path
	var/state = buildmode_catalog_icon_state(target_type)
	if(isnull(state))
		// Invisible/helper types still need a visible placement cursor.
		spawn_preview = image('icons/turf/overlays.dmi', previous_turf, "greenOverlay")
	else
		spawn_preview = image(initial(target_type.icon), previous_turf, state, dir = build_dir)
	spawn_preview.alpha = 160
	spawn_preview.color = "#7de6d5"
	spawn_preview.plane = ABOVE_LIGHTING_PLANE
	spawn_preview.layer = ABOVE_ALL_MOB_LAYER
	spawn_preview.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	spawn_preview.pixel_x = ispath(target_type, /turf) ? 0 : initial(target_type.pixel_x) + spawn_pixel_x
	spawn_preview.pixel_y = ispath(target_type, /turf) ? 0 : initial(target_type.pixel_y) + spawn_pixel_y
	holder?.images += spawn_preview

/datum/buildmode/proc/update_spawn_preview(atom/hovered)
	if(!can_build(holder) || !istype(mode, /datum/buildmode_mode/catalog))
		clear_spawn_preview()
		return
	if(spawn_preview)
		spawn_preview.loc = istype(hovered, /atom/movable/screen) ? null : get_turf(hovered)

/// All entry points recheck ownership and permissions before modifying the world.
/datum/buildmode/proc/place_catalog(client/actor, turf/target, in_hands = FALSE)
	if(!can_build(actor) || !target || !(selected_path in buildmode_catalog_entries()) || placing || world.time < next_spawn)
		return FALSE
	if(in_hands && (!isliving(actor.mob) || !ispath(selected_path, /obj/item)))
		return FALSE
	var/atom/target_type = selected_path
	var/amount = ispath(target_type, /turf) ? 1 : clamp(round(spawn_amount), 1, ADMIN_SPAWN_CAP)
	var/target_location = AREACOORD(target)
	placing = TRUE
	next_spawn = world.time + 2
	var/created = 0
	var/held = 0
	try
		if(ispath(target_type, /turf))
			var/turf/replacement = target.ChangeTurf(target_type)
			if(replacement)
				replacement.setDir(build_dir)
				replacement.flags_1 |= ADMIN_SPAWNED_1
				created = 1
		else
			for(var/i in 1 to amount)
				if(!can_build(actor) || QDELETED(target))
					break
				var/atom/movable/spawned = new target_type(target)
				if(QDELETED(spawned))
					continue
				spawned.flags_1 |= ADMIN_SPAWNED_1
				spawned.setDir(build_dir)
				spawned.pixel_x = initial(spawned.pixel_x) + spawn_pixel_x
				spawned.pixel_y = initial(spawned.pixel_y) + spawn_pixel_y
				created++
				if(in_hands)
					var/mob/living/recipient = actor.mob
					if(recipient.put_in_hands(spawned, merge_stacks = FALSE))
						held++
	catch(var/exception/error)
		log_runtime("Buildmode catalog: [error] at [error.file]:[error.line]")
		catalog_status = "Спавн прерван ошибкой объекта; создано [created]. Подробности в журнале сервера."
	placing = FALSE
	log_admin("Build Mode catalog: [key_name(actor)] spawned [created]/[amount] of [target_type] at [target_location], dir [build_dir], offset [spawn_pixel_x],[spawn_pixel_y], in hands [held].")
	if(!catalog_status)
		catalog_status = in_hands ? "Создано: [created]. В руках: [held], на земле: [created - held]." : "Создано: [created] · [initial(target_type.name)]"
	SStgui.update_uis(src)
	return created > 0

/// Use basic buildmode's layer removal for turfs; delete world objects directly.
/datum/buildmode/proc/delete_catalog_object(client/actor, atom/object)
	if(!can_build(actor) || QDELETED(object) || istype(object, /atom/movable/screen))
		return FALSE
	if(!isturf(object) && (!isobj(object) || !isturf(object.loc)))
		return FALSE
	log_admin("Build Mode catalog: [key_name(actor)] deleted [object] ([object.type]) at [AREACOORD(object)].")
	catalog_status = "Удалено: [object.name]"
	if(isturf(object))
		var/turf/target = object
		target.ScrapeAway(flags = CHANGETURF_INHERIT_AIR)
	else
		qdel(object)
	SStgui.update_uis(src)
	return TRUE

/datum/buildmode/proc/set_catalog_placement_option(action, raw_value)
	var/value = text2num("[raw_value]")
	if(!isnum(value))
		return FALSE
	switch(action)
		if("amount")
			spawn_amount = clamp(round(value), 1, ADMIN_SPAWN_CAP)
			// Quantity does not change the cursor image.
			return TRUE
		if("pixel_x")
			spawn_pixel_x = clamp(round(value), -BUILDMODE_MAX_OFFSET, BUILDMODE_MAX_OFFSET)
		if("pixel_y")
			spawn_pixel_y = clamp(round(value), -BUILDMODE_MAX_OFFSET, BUILDMODE_MAX_OFFSET)
		else
			return FALSE
	refresh_spawn_preview()
	return TRUE
