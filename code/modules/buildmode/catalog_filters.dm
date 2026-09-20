/proc/buildmode_catalog_subcategory(target_type, category)
	var/list/groups = buildmode_catalog_groups()[category]
	if(!groups)
		return "all"
	for(var/group_id in groups)
		var/list/group = groups[group_id]
		for(var/root_type in group["roots"])
			if(ispath(target_type, root_type))
				return group_id
	return "other"

/proc/buildmode_catalog_coverage_masks()
	var/static/list/masks
	if(!masks)
		masks = list()
		var/list/zones = buildmode_catalog_coverage_zones()
		for(var/id in zones)
			var/list/zone = zones[id]
			if(zone["mask"])
				masks[id] = zone["mask"]
	return masks

/proc/buildmode_catalog_coverage(obj/item/clothing/clothing_type)
	var/list/zones = list()
	if(!ispath(clothing_type, /obj/item/clothing))
		return zones
	var/covered = initial(clothing_type.body_parts_covered)
	var/list/masks = buildmode_catalog_coverage_masks()
	for(var/zone in masks)
		if(covered & masks[zone])
			zones += zone
	return zones

/proc/buildmode_sanitize_navigation(list/raw)
	var/list/result = list("category" = "all", "subcategory" = "all", "armor_class" = "all", "coverage" = "all", "search" = "", "page" = 1)
	if(!islist(raw))
		return result
	var/category = raw["category"]
	if(!(category in buildmode_catalog_categories()))
		return result
	result["category"] = category
	if(buildmode_catalog_valid_subcategory(category, raw["subcategory"]))
		result["subcategory"] = raw["subcategory"]
	if(category == "clothing")
		if(raw["armor_class"] in buildmode_catalog_armor_classes())
			result["armor_class"] = raw["armor_class"]
		if(buildmode_catalog_valid_coverage(raw["coverage"]))
			result["coverage"] = raw["coverage"]
	if(istext(raw["search"]))
		result["search"] = copytext_char(raw["search"], 1, BUILDMODE_MAX_SEARCH_LENGTH + 1)
	if(isnum(raw["page"]))
		result["page"] = clamp(round(raw["page"]), 1, 100000)
	return result

/proc/buildmode_catalog_valid_subcategory(category, subcategory)
	var/list/groups = buildmode_catalog_groups()[category]
	return subcategory == "all" || (groups && (subcategory in groups))

/proc/buildmode_catalog_valid_coverage(coverage)
	return coverage == "all" || (coverage in buildmode_catalog_coverage_masks())

/// Shared display options; only the selected id is personal to each builder.
/proc/buildmode_catalog_subcategory_options(category)
	var/static/list/cache = list()
	if(cache[category])
		return cache[category]
	var/list/options = list(list("id" = "all", "name" = "Все виды"))
	var/list/groups = buildmode_catalog_groups()[category]
	for(var/group_id in groups)
		var/list/group = groups[group_id]
		options += list(list("id" = group_id, "name" = group["name"]))
	cache[category] = options
	return options

/proc/buildmode_catalog_options(list/labels)
	var/list/options = list()
	for(var/id in labels)
		options += list(list("id" = id, "name" = labels[id]))
	return options

/proc/buildmode_catalog_coverage_options()
	var/list/labels = list()
	var/list/zones = buildmode_catalog_coverage_zones()
	for(var/id in zones)
		labels[id] = zones[id]["name"]
	return buildmode_catalog_options(labels)
