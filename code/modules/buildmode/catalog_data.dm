/// Only concrete world atoms are accepted, including when loading old favorites.
/proc/buildmode_catalog_allowed(atom/target_type)
	if(!ispath(target_type, /obj) && !ispath(target_type, /turf) && !ispath(target_type, /mob/living))
		return FALSE
	if(ispath(target_type, /atom/movable/screen) || !initial(target_type.name))
		return FALSE
	if(ispath(target_type, /obj/item))
		var/obj/item/item_type = target_type
		if(initial(item_type.item_flags) & ABSTRACT)
			return FALSE
	return TRUE

/proc/cmp_buildmode_catalog(atom/a, atom/b)
	return sorttext("[initial(b.name)]", "[initial(a.name)]") || sorttext("[b]", "[a]")

/// No constructors run while browsing. Many game types have side effects in New/Initialize.
/proc/buildmode_catalog_entries()
	var/static/list/entries
	if(entries)
		return entries
	entries = list()
	var/list/paths = subtypesof(/obj) + subtypesof(/turf) + subtypesof(/mob/living)
	sortTim(paths, GLOBAL_PROC_REF(cmp_buildmode_catalog))
	for(var/atom/target_type as anything in paths)
		if(!buildmode_catalog_allowed(target_type))
			continue
		var/category = buildmode_catalog_category(target_type)
		var/armor_class = "all"
		if(category == "clothing")
			var/obj/item/clothing/clothing_type = target_type
			armor_class = "[initial(clothing_type.armor_class)]"
		entries[target_type] = list(
			"path" = "[target_type]",
			"name" = initial(target_type.name),
			"desc" = initial(target_type.desc) || "",
			"category" = category,
			"subcategory" = buildmode_catalog_subcategory(target_type, category),
			"armor_class" = armor_class,
			"coverage" = buildmode_catalog_coverage(target_type),
			"is_item" = ispath(target_type, /obj/item),
			"is_turf" = ispath(target_type, /turf),
		)
	return entries

/proc/buildmode_catalog_icon_state(atom/target_type)
	var/icon_file = initial(target_type.icon)
	if(!icon_file)
		return null
	var/static/list/states_by_file = list()
	var/list/states = states_by_file[icon_file]
	if(!states)
		states = icon_states(icon_file)
		states_by_file[icon_file] = states
	if(ispath(target_type, /obj/item))
		var/obj/item/item_type = target_type
		var/preview_state = initial(item_type.icon_state_preview)
		if(preview_state && (preview_state in states))
			return preview_state
	var/state = initial(target_type.icon_state)
	return (state in states) ? state : null

/// Generate only the current page, caching by icon/state/direction instead of typepath.
/proc/buildmode_catalog_icon(atom/target_type, direction = SOUTH)
	var/state = buildmode_catalog_icon_state(target_type)
	if(isnull(state))
		return null
	var/icon_file = initial(target_type.icon)
	var/static/list/cache = list()
	var/cache_key = "[icon_file]|[state]|[direction]"
	if(!cache[cache_key])
		var/icon/sprite = icon(icon_file, state, direction, 1)
		cache[cache_key] = "data:image/png;base64,[icon2base64(sprite)]"
	return cache[cache_key]

/proc/buildmode_sanitize_paths(list/raw_paths, limit)
	var/list/result = list()
	if(!islist(raw_paths))
		return result
	var/list/entries = buildmode_catalog_entries()
	for(var/path in raw_paths)
		if(length(result) >= limit)
			break
		if(!istext(path) || !(text2path(path) in entries))
			continue
		result |= path
	return result

/// Shared, read-only lookup tables. Lists retain the catalogue's name/path order.
/proc/buildmode_catalog_index()
	var/static/list/index
	if(index)
		return index
	var/list/categories = list()
	var/list/subcategories = list()
	var/list/counts = list()
	var/list/search_text = list()
	var/list/entries = buildmode_catalog_entries()
	for(var/path in entries)
		var/list/entry = entries[path]
		var/category = entry["category"]
		var/subcategory = entry["subcategory"]
		if(!categories[category])
			categories[category] = list()
			subcategories[category] = list()
		var/list/category_paths = categories[category]
		category_paths += path
		var/list/groups = subcategories[category]
		if(!groups[subcategory])
			groups[subcategory] = list()
		var/list/group_paths = groups[subcategory]
		group_paths += path
		counts[category]++
		search_text[path] = "[entry["name"]] [path]"
	index = list("categories" = categories, "subcategories" = subcategories, "counts" = counts, "search_text" = search_text)
	return index
