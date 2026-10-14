// Feedback is computed on interaction, never by polling every home each tick.
/datum/supporter_home/proc/confirm_save(mob/user, list/records)
	return alert(user, "[status_text(records)]\n\n[preview_text(records)]\n\nSave this layout for future rounds? Only approved small items directly inside approved furniture storage are kept; liquids, nested bags and machine inputs are not saved. The entrance landing is always restored.", "Save home", "Save", "Cancel")

/datum/supporter_home/proc/tier_name(profile = tier)
	switch(profile)
		if(1)
			return "Wizard"
		if(2)
			return "Cultist"
		if(3)
			return "Assistant"
	return "no housing subscription"

/datum/supporter_home/proc/layout_signature(list/records)
	if(isnull(records))
		return null
	var/list/rows = list()
	for(var/list/record as anything in records)
		// Field and iteration order must not turn an unchanged layout into a dirty one.
		var/list/children = list()
		for(var/list/child as anything in record["contents"])
			children += json_encode(list(child["type"], child["dir"], child["color"]))
		rows += json_encode(list(record["kind"], record["type"], record["x"], record["y"], record["dir"], record["color"], !!record["archived"], sortList(children)))
	return json_encode(sortList(rows))

/datum/supporter_home/proc/last_save_text()
	if(!revision)
		return "Never saved."
	if(isnull(last_saved_age))
		return "Loaded from an earlier save (time unavailable)."
	var/seconds = max(0, last_saved_age + (world.time - last_saved_seen) / 10)
	if(seconds < 60)
		return "Less than a minute ago."
	if(seconds < 3600)
		return "[FLOOR(seconds / 60, 1)] minute(s) ago."
	if(seconds < 86400)
		return "[FLOOR(seconds / 3600, 1)] hour(s) ago."
	return "[FLOOR(seconds / 86400, 1)] day(s) ago."

/datum/supporter_home/proc/status_text(list/records)
	var/state = "Unsaved changes."
	if(!revision)
		state = "Not saved yet."
	else if(!isnull(records) && layout_signature(records) == layout_signature(saved_layout))
		state = "No unsaved layout changes."
	var/items = 0
	var/inside = 0
	var/archived_items = length(manager.flatten_furnishings(archive))
	for(var/list/record as anything in records)
		if(record["kind"] != "wall" && !record["archived"])
			items += manager.record_size(record)
			inside += length(record["contents"])
	var/count_text = isnull(records) ? "Recognized items: [live_decor_count()]/[decor_limit]; saving blocked." : "Will save [items]/[decor_limit] items in this home, including [inside] inside containers."
	if(isnull(records))
		items = live_decor_count()
	return "[test_session ? "ADMIN TEST - saved only in memory until round end.\n" : ""]Home: [tier_name()] (this round).\n[count_text] Each container and each item inside counts separately.\nWorkstations: [live_category_count("station")]/[tier * 2]; lights: [live_category_count("light")]/[tier * 4 + 4].\nArchive: [archived_items] items; storage including archive: [items + archived_items]/160 items. Walls/floors have a separate 64-change limit.\nLast save: [last_save_text()] [state][snapshot_error ? "\nCannot save: [snapshot_error]" : ""]"

/datum/supporter_home/proc/removed_furnishings(list/records)
	var/list/before = list()
	var/list/after = list()
	for(var/list/record as anything in manager.flatten_furnishings(saved_layout))
		if(record["kind"] != "wall")
			before[record["type"]]++
	for(var/list/record as anything in manager.flatten_furnishings(records))
		if(record["kind"] != "wall")
			after[record["type"]]++
	var/removed = 0
	for(var/path in before)
		removed += max(0, before[path] - after[path])
	return removed

/datum/supporter_home/proc/omitted_furnishings_text()
	var/list/omitted = list()
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		for(var/obj/object in tile)
			if(object == bell || object == interior || istype(object, /obj/structure/fluff/traveltile/housing) || istype(object, /obj/effect))
				continue
			if(!decor_tile(tile) || !manager.decor_types["[object.type]"])
				omitted[initial(object.name)]++
			else if(manager.is_home_storage(object.type))
				for(var/obj/item/item in object.contents)
					if(!manager.is_home_small_item(item.type))
						omitted["[initial(item.name)] inside [initial(object.name)]"]++
	if(!length(omitted))
		return ""
	var/list/names = list()
	for(var/object_name in omitted)
		if(length(names) >= 6)
			break
		names += "[object_name] ([omitted[object_name]])"
	return "Not saved (unapproved objects or outside the furnishing area): [jointext(names, ", ")][length(omitted) > 6 ? "; and [length(omitted) - 6] more kinds" : ""]."

/datum/supporter_home/proc/preview_text(list/records)
	var/furnishings = 0
	var/walls = 0
	var/archived = 0
	var/higher_tier = 0
	var/inside = 0
	for(var/list/record as anything in records)
		if(record["archived"])
			archived += manager.record_size(record)
		else if(record["kind"] == "wall")
			walls++
		else
			furnishings += manager.record_size(record)
			inside += length(record["contents"])
			higher_tier += manager.record_required_tier(record) > tier ? manager.record_size(record) : 0
	var/text = "Will save: [furnishings]/[decor_limit] items ([inside] inside containers), [walls] wall/floor changes; [archived] archived objects/changes kept.\n[removed_furnishings(records)] missing furnishings will be removed from your previous save. Moving, storing or repainting an item does not count as removing it."
	if(higher_tier)
		text += "\n[higher_tier] furnishings require a higher subscription and will be archived on reload at this home's tier."
	var/omitted = omitted_furnishings_text()
	if(omitted)
		text += "\n[omitted]"
	return text

/datum/supporter_home/proc/record_minimum_tier(list/record)
	var/is_wall = record["kind"] == "wall"
	var/obj/shape = manager.decor_types[record["type"]]
	var/left = record["x"] + (is_wall ? 0 : FLOOR(initial(shape.bound_x) / 32, 1))
	var/bottom = record["y"] + (is_wall ? 0 : FLOOR(initial(shape.bound_y) / 32, 1))
	var/right = record["x"] + (is_wall ? 0 : FLOOR((initial(shape.bound_x) + max(initial(shape.bound_width), 32) - 1) / 32, 1))
	var/top = record["y"] + (is_wall ? 0 : FLOOR((initial(shape.bound_y) + max(initial(shape.bound_height), 32) - 1) / 32, 1))
	for(var/candidate in 1 to 3)
		if(!is_wall && manager.record_required_tier(record) > candidate)
			continue
		var/list/profile = manager.profiles[candidate]
		var/margin = is_wall ? 2 : 3
		if(left < margin + 1 || right > profile["width"] - margin || bottom < margin + 4 || top > profile["height"] - margin)
			continue
		var/approach_x = FLOOR(profile["width"] / 2, 1) + 1
		if(left <= approach_x && right >= approach_x && bottom <= 9)
			continue
		return candidate
	return 0

/datum/supporter_home/proc/archive_text()
	if(!length(archive))
		return "The archive is empty."
	var/list/groups = list()
	for(var/list/record as anything in archive)
		var/atom/shape = record["kind"] == "wall" ? manager.wall_types[record["type"]] : manager.decor_types[record["type"]]
		var/minimum_tier = record_minimum_tier(record)
		var/reason = "Needs free space and capacity; check for overlapping furniture or walls."
		if(!minimum_tier)
			reason = "This saved position does not fit any available layout."
		else if(minimum_tier > tier)
			reason = "Needs at least [tier_name(minimum_tier)], with free space and capacity."
		var/label = "[initial(shape.name)][length(record["contents"]) ? " with [length(record["contents"])] stored items" : ""] - [reason]"
		groups[label]++
	var/list/lines = list("[length(archive)] archived entries are kept, not deleted. Restoration is attempted when your home loads next round; it never replaces occupied spaces.")
	for(var/label in groups)
		lines += "[groups[label]] x [label]"
	return jointext(lines, "\n")

/datum/supporter_home/proc/help_text()
	return "Ring the bell to preview and explicitly save. Examine it for limits and unsaved changes; right-click it for this guide and your archive. There is no automatic saving. Only approved furnishings and wall/floor changes are kept; approved small items directly inside approved chests, drawers and cupboards also count toward the same item limit. Liquids, nested bags, fuel and machine workpieces are not saved.\nThis is an ordinary home: locks can be picked, doors broken, furnishings burned, and others can follow through an open entrance.\nSubscription changes affect the next round's home size. Belongings that no longer fit or need a higher tier are archived, not deleted. Expiry keeps your saved home and archive but prevents new home creation and saving; your existing home stays accessible for this round."

/datum/supporter_home/proc/welcome_owner(mob/living/user)
	if(owner_welcomed || user?.ckey != owner_ckey || user.stat != CONSCIOUS)
		return FALSE
	owner_welcomed = TRUE
	to_chat(user, span_notice("Welcome home. Ring the furnishings bell to preview and save; examine it for status, or right-click for your archive and help. Saving is manual; approved items inside furniture storage count toward the same limit; liquids and nested bags are not saved. Others can follow you inside, pick locks and break doors. [length(archive)] archived entries are safely kept for later rounds."))
	return TRUE
