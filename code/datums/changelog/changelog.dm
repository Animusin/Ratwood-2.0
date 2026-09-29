/datum/changelog
	var/static/list/changelog_items = list()

/datum/changelog/ui_state()
	return GLOB.always_state

/datum/changelog/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "Changelog")
		ui.open()

/datum/changelog/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "get_month")
		var/list/sources = changelog_sources()
		if(!istext(params["date"]) || !sources[params["date"]])
			return FALSE
		var/datum/asset/changelog_item/changelog_item = changelog_items[params["date"]]
		if (!changelog_item)
			changelog_item = new /datum/asset/changelog_item(params["date"])
			changelog_items[params["date"]] = changelog_item
		return ui.send_asset(changelog_item)

/datum/changelog/ui_static_data()
	var/list/sources = changelog_sources()
	var/list/dates = list()
	var/list/month_files = list()
	for(var/month in sort_list(sources))
		dates.Insert(1, month)
		var/list/filenames = list()
		for(var/filename in sources[month])
			filenames += filename
		month_files[month] = filenames
	return list("dates" = dates, "month_files" = month_files)

/// Persistent local months supplement the upstream archive without rewriting it.
/proc/changelog_sources(root = "html/changelogs/")
	var/list/sources = list()
	var/list/directories = list("archive/" = "", "local/" = "local-")
	var/static/regex/month_file = regex(@"^\d{4}-(0[1-9]|1[0-2])\.yml$")
	for(var/directory in directories)
		for(var/filename in flist("[root][directory]"))
			if(!month_file.Find(filename))
				continue
			var/month = copytext(filename, 1, -4)
			if(!sources[month])
				sources[month] = list()
			var/list/month_sources = sources[month]
			month_sources["[directories[directory]][filename]"] = "[root][directory][filename]"
	return sources

/proc/changelog_month_hash(root, month)
	var/archive_file = file("[root]archive/[month].yml")
	var/archive_hash = fexists(archive_file) ? md5(archive_file) : 0
	var/local_file = file("[root]local/[month].yml")
	if(fexists(local_file))
		return md5("[archive_hash]:[md5(local_file)]")
	return archive_hash
