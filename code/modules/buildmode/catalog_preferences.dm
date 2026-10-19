/datum/buildmode/proc/catalog_preferences_path()
	var/owner = holder?.ckey
	if(!owner)
		return null
	return "data/player_saves/[copytext(owner, 1, 2)]/[owner]/buildmode.sav"

/datum/buildmode/proc/read_catalog_preferences()
	var/path = catalog_preferences_path()
	if(!path || !fexists(path))
		return
	var/savefile/file = new(path)
	var/list/raw_favorites
	var/list/raw_recent
	var/list/raw_navigation
	file["favorites"] >> raw_favorites
	file["recent"] >> raw_recent
	file["navigation"] >> raw_navigation
	catalog_favorites = buildmode_sanitize_paths(raw_favorites, BUILDMODE_MAX_FAVORITES)
	catalog_recent = buildmode_sanitize_paths(raw_recent, BUILDMODE_MAX_RECENT)
	restore_catalog_navigation(raw_navigation)
	catalog_saved_preferences = null

/datum/buildmode/proc/write_catalog_preferences()
	var/path = catalog_preferences_path()
	if(!path)
		return FALSE
	var/list/navigation = catalog_navigation()
	// Compare values: the favorites and recent lists are edited in place.
	var/snapshot = json_encode(list("favorites" = catalog_favorites, "recent" = catalog_recent, "navigation" = navigation))
	if(snapshot == catalog_saved_preferences && fexists(path))
		return FALSE
	var/savefile/file = new(path)
	WRITE_FILE(file["favorites"], catalog_favorites)
	WRITE_FILE(file["recent"], catalog_recent)
	WRITE_FILE(file["navigation"], navigation)
	catalog_saved_preferences = snapshot
	return TRUE

/datum/buildmode/proc/toggle_catalog_favorite(path)
	if(!istext(path) || !(text2path(path) in buildmode_catalog_entries()))
		return FALSE
	if(path in catalog_favorites)
		catalog_favorites -= path
	else if(length(catalog_favorites) < BUILDMODE_MAX_FAVORITES)
		catalog_favorites += path
	else
		catalog_status = "В избранном уже [BUILDMODE_MAX_FAVORITES] объектов. Удалите ненужные."
		return TRUE
	if(catalog_category == "favorites")
		invalidate_catalog_results()
	write_catalog_preferences()
	return TRUE

/datum/buildmode/proc/remember_catalog_path(target_type)
	var/path = "[target_type]"
	if(length(catalog_recent) && catalog_recent[1] == path)
		return
	catalog_recent -= path
	catalog_recent.Insert(1, path)
	if(length(catalog_recent) > BUILDMODE_MAX_RECENT)
		catalog_recent.Cut(BUILDMODE_MAX_RECENT + 1)
	if(catalog_category == "recent")
		invalidate_catalog_results()
	write_catalog_preferences()
