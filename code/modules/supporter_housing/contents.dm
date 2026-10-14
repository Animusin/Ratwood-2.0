// Only approved furniture storage may own saved items. No recursive bags or machine inputs.
/datum/supporter_housing/proc/is_home_storage(path)
	return decor_types["[path]"] && ispath(path, /obj/structure/closet)

/datum/supporter_housing/proc/is_home_small_item(path)
	return decor_types["[path]"] && ispath(path, /obj/item) && !ispath(path, /obj/item/storage)

/datum/supporter_housing/proc/valid_stored_item(list/record)
	if(!islist(record) || length(record) > 3 || !istext(record["type"]) || !is_home_small_item(decor_types[record["type"]]))
		return FALSE
	for(var/key in record)
		if(!(key in list("type", "dir", "color")))
			return FALSE
	var/list/placed = record.Copy()
	placed["x"] = 4
	placed["y"] = 7
	return valid_record(placed)

/datum/supporter_housing/proc/record_size(list/record)
	return 1 + length(record["contents"])

/datum/supporter_housing/proc/record_category_count(list/record, category)
	var/path = decor_types[record["type"]]
	. = category == "station" ? is_workstation(path) : is_light(path)
	for(var/list/child as anything in record["contents"])
		path = decor_types[child["type"]]
		. += category == "station" ? is_workstation(path) : is_light(path)

/datum/supporter_housing/proc/record_required_tier(list/record)
	. = decor_tiers[record["type"]]
	for(var/list/child as anything in record["contents"])
		. = max(., decor_tiers[child["type"]])

/datum/supporter_housing/proc/flatten_furnishings(list/records)
	. = list()
	for(var/list/record as anything in records)
		if(record["kind"] == "wall")
			continue
		. += list(record)
		for(var/list/child as anything in record["contents"])
			. += list(child)

/datum/supporter_home/proc/pack_contents(obj/container, list/record)
	if(!manager.is_home_storage(container.type))
		return TRUE
	var/list/items = list()
	var/obj/structure/closet/storage = container
	for(var/obj/item/item in storage.contents)
		if(!manager.is_home_small_item(item.type))
			continue
		var/list/child = list("type" = "[item.type]", "dir" = item.dir, "color" = istext(item.color) ? item.color : null)
		if(!manager.valid_stored_item(child))
			snapshot_error = "[initial(item.name)] inside [initial(container.name)] has an unsupported facing or paint colour."
			return FALSE
		items += list(child)
		if(length(items) > min(30, initial(storage.storage_capacity)))
			snapshot_error = "[initial(container.name)] contains too many approved items to save (maximum [min(30, initial(storage.storage_capacity))])."
			return FALSE
	if(length(items))
		record["contents"] = items
	return TRUE

/datum/supporter_home/proc/unpack_contents(obj/container, list/record)
	for(var/list/child as anything in record["contents"])
		var/path = manager.decor_types[child["type"]]
		var/obj/item/item = new path(container)
		manager.prepare_restored(item)
		item.dir = child["dir"]
		if(child["color"])
			item.color = child["color"]

/datum/supporter_home/proc/contained_item_count(obj/container, category)
	if(!manager.is_home_storage(container.type))
		return 0
	. = 0
	for(var/obj/item/item in container.contents)
		if(manager.is_home_small_item(item.type))
			. += !category ? 1 : (category == "station" ? manager.is_workstation(item.type) : manager.is_light(item.type))
