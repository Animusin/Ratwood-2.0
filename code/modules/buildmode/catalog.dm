/datum/ui_state/buildmode/can_use_topic(datum/buildmode/source, mob/user)
	return istype(source) && source.can_build(user?.client) ? UI_INTERACTIVE : UI_CLOSE

/datum/buildmode
	var/datum/ui_state/buildmode/catalog_state
	var/selected_path
	var/catalog_category = "all"
	var/catalog_subcategory = "all"
	var/catalog_armor_class = "all"
	var/catalog_coverage = "all"
	var/catalog_search = ""
	var/catalog_page = 1
	var/list/catalog_results
	var/list/catalog_favorites = list()
	var/list/catalog_recent = list()
	var/catalog_saved_preferences
	var/spawn_amount = 1
	var/spawn_pixel_x = 0
	var/spawn_pixel_y = 0
	var/image/spawn_preview
	var/catalog_status
	var/placing = FALSE
	var/next_spawn = 0

/datum/buildmode/proc/can_build(client/actor)
	return actor && actor == holder && actor.click_intercept == src && check_rights_for(actor, R_BUILD)

/datum/buildmode/ui_state(mob/user)
	return catalog_state

/datum/buildmode/ui_interact(mob/user, datum/tgui/ui)
	if(!can_build(user?.client))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BuildMode", "F7 · Каталог спавна", 1100, 760)
		ui.window_key = "buildmode-catalog-[user.ckey]"
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/buildmode/ui_close(mob/user)
	. = ..()
	write_catalog_preferences()

/datum/buildmode/ui_static_data(mob/user)
	return list(
		"counts" = buildmode_catalog_index()["counts"],
		"total" = length(buildmode_catalog_entries()),
		"max_amount" = ADMIN_SPAWN_CAP,
		"max_favorites" = BUILDMODE_MAX_FAVORITES,
		"max_search_length" = BUILDMODE_MAX_SEARCH_LENGTH,
		"max_offset" = BUILDMODE_MAX_OFFSET,
		"categories" = buildmode_catalog_options(buildmode_catalog_categories()),
		"armor_classes" = buildmode_catalog_options(buildmode_catalog_armor_classes()),
		"coverage_zones" = buildmode_catalog_coverage_options(),
	)

/datum/buildmode/proc/catalog_card(target_type, direction = SOUTH)
	var/list/entries = buildmode_catalog_entries()
	var/list/entry = entries[target_type]
	if(!entry)
		return null
	var/list/card = entry.Copy()
	card["icon"] = buildmode_catalog_icon(target_type, direction)
	card["favorite"] = ("[target_type]" in catalog_favorites)
	return card

/datum/buildmode/ui_data(mob/user)
	var/list/results = filtered_catalog()
	var/pages = catalog_page_count()
	catalog_page = clamp(catalog_page, 1, pages)
	var/list/cards = list()
	var/start = (catalog_page - 1) * BUILDMODE_PAGE_SIZE + 1
	for(var/i in start to min(start + BUILDMODE_PAGE_SIZE - 1, length(results)))
		cards += list(catalog_card(results[i]))
	return list(
		"items" = cards, "matches" = length(results), "page" = catalog_page, "pages" = pages,
		"category" = catalog_category, "search" = catalog_search,
		"subcategory" = catalog_subcategory, "subcategories" = buildmode_catalog_subcategory_options(catalog_category),
		"armor_class" = catalog_armor_class, "coverage" = catalog_coverage,
		"favorites_count" = length(catalog_favorites), "recent_count" = length(catalog_recent),
		"selected" = selected_path ? catalog_card(selected_path, build_dir) : null,
		"amount" = spawn_amount, "direction" = build_dir, "pixel_x" = spawn_pixel_x, "pixel_y" = spawn_pixel_y,
		"armed" = selected_path && istype(mode, /datum/buildmode_mode/catalog),
		"mode" = mode?.key, "status" = catalog_status,
		"can_hands" = isliving(user) && ispath(selected_path, /obj/item),
	)

/datum/buildmode/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	if(!can_build(ui.user?.client))
		return
	catalog_status = null
	switch(action)
		if("search", "category", "subcategory", "armor_class", "coverage", "page")
			return set_catalog_navigation(action, params["value"])
		if("select")
			if(istext(params["path"]))
				return select_catalog_path(text2path(params["path"]), toggle = TRUE)
		if("favorite")
			return toggle_catalog_favorite(params["path"])
		if("amount", "pixel_x", "pixel_y")
			return set_catalog_placement_option(action, params["value"])
		if("direction")
			var/value = text2num("[params["value"]]")
			if(value in GLOB.alldirs)
				change_dir(value)
		if("reset")
			spawn_amount = 1
			spawn_pixel_x = 0
			spawn_pixel_y = 0
			change_dir(SOUTH)
		if("cancel")
			clear_catalog_selection()
		if("arm")
			change_mode(/datum/buildmode_mode/catalog)
		if("spawn_here", "spawn_hands")
			place_catalog(ui.user.client, get_turf(ui.user), action == "spawn_hands")
		if("quit")
			quit()
		else
			return FALSE
	return TRUE
