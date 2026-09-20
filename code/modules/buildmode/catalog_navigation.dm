/// Restrict the search before applying text and clothing filters. Never mutate shared candidates.
/datum/buildmode/proc/catalog_candidates()
	var/list/entries = buildmode_catalog_entries()
	if(catalog_category == "all")
		return entries
	if(catalog_category == "favorites" || catalog_category == "recent")
		var/list/candidates = list()
		var/list/saved = catalog_category == "favorites" ? catalog_favorites : catalog_recent
		for(var/path in saved)
			var/target_type = text2path(path)
			if(target_type in entries)
				candidates += target_type
		return candidates
	var/list/index = buildmode_catalog_index()
	if(catalog_subcategory != "all")
		var/list/groups = index["subcategories"][catalog_category]
		return groups?[catalog_subcategory] || list()
	return index["categories"][catalog_category] || list()

/datum/buildmode/proc/filtered_catalog()
	if(!isnull(catalog_results))
		return catalog_results
	catalog_results = list()
	var/list/entries = buildmode_catalog_entries()
	var/list/search_text = buildmode_catalog_index()["search_text"]
	var/list/words = splittext(lowertext(trim(catalog_search)), " ")
	for(var/path in catalog_candidates())
		var/list/entry = entries[path]
		if(catalog_subcategory != "all" && entry["subcategory"] != catalog_subcategory)
			continue
		if(catalog_category == "clothing")
			if(catalog_armor_class != "all" && entry["armor_class"] != catalog_armor_class)
				continue
			if(catalog_coverage != "all" && !(catalog_coverage in entry["coverage"]))
				continue
		var/matched = TRUE
		for(var/word in words)
			if(length(word) && !findtext(search_text[path], word))
				matched = FALSE
				break
		if(matched)
			catalog_results += path
	return catalog_results

/datum/buildmode/proc/invalidate_catalog_results(reset_page = FALSE)
	catalog_results = null
	if(reset_page)
		catalog_page = 1

/datum/buildmode/proc/catalog_page_count()
	return max(1, CEILING(length(filtered_catalog()) / BUILDMODE_PAGE_SIZE, 1))

/// All navigation actions share validation, result invalidation and persistence.
/datum/buildmode/proc/set_catalog_navigation(action, value)
	switch(action)
		if("search")
			if(!istext(value))
				return FALSE
			catalog_search = copytext_char(value, 1, BUILDMODE_MAX_SEARCH_LENGTH + 1)
		if("category")
			if(!(value in buildmode_catalog_categories()))
				return FALSE
			catalog_category = value
			catalog_subcategory = "all"
			catalog_armor_class = "all"
			catalog_coverage = "all"
		if("subcategory")
			if(!buildmode_catalog_valid_subcategory(catalog_category, value))
				return FALSE
			catalog_subcategory = value
		if("armor_class")
			if(catalog_category != "clothing" || !(value in buildmode_catalog_armor_classes()))
				return FALSE
			catalog_armor_class = value
		if("coverage")
			if(catalog_category != "clothing" || !buildmode_catalog_valid_coverage(value))
				return FALSE
			catalog_coverage = value
		if("page")
			var/page = text2num("[value]")
			if(!isnum(page))
				return FALSE
			catalog_page = round(page)
		else
			return FALSE
	if(action != "page")
		invalidate_catalog_results(reset_page = TRUE)
	write_catalog_preferences()
	return TRUE

/datum/buildmode/proc/restore_catalog_navigation(list/raw_navigation)
	var/list/navigation = buildmode_sanitize_navigation(raw_navigation)
	catalog_category = navigation["category"]
	catalog_subcategory = navigation["subcategory"]
	catalog_armor_class = navigation["armor_class"]
	catalog_coverage = navigation["coverage"]
	catalog_search = navigation["search"]
	invalidate_catalog_results()
	catalog_page = clamp(navigation["page"], 1, catalog_page_count())

/datum/buildmode/proc/catalog_navigation()
	catalog_page = clamp(catalog_page, 1, catalog_page_count())
	return list("category" = catalog_category, "subcategory" = catalog_subcategory, "armor_class" = catalog_armor_class, "coverage" = catalog_coverage, "search" = catalog_search, "page" = catalog_page)
