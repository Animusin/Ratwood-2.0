// Opt-in prototype. Interiors persist for the round; only the bell writes decor.
#define HOUSING_CELL_SIZE 28
#define HOUSING_MAX_HOMES 60
#define HOUSING_MAX_RECORDS 224 // 160 furnishings including archived items, plus 64 geometry deltas.
#define HOUSING_MAX_JSON 60000
#define HOUSING_SAVE_COOLDOWN (1 MINUTES)

/datum/config_entry/flag/supporter_housing

GLOBAL_DATUM_INIT(supporter_housing, /datum/supporter_housing, new)

/datum/supporter_housing
	var/datum/housing_storage/storage = new
	var/datum/space_level/level
	var/list/homes = list()
	var/list/pending_owners = list()
	var/list/pending_doors = list()
	var/loading = FALSE
	var/slots_used = 0
	// Ordinary town homes and mercenary rooms. Civic/workshop doors stay local.
	var/list/entrance_maps = list("rockhill.dmm", "deserttown.dmm", "dun_world.dmm")
	var/list/entrance_types = list(/obj/structure/mineral_door/wood/towner/generic, /obj/structure/mineral_door/wood/towner/generic/two_keys, /obj/structure/mineral_door/wood/mercenary)
	var/list/decor_types = list()
	var/list/decor_tiers = list()
	var/list/wall_types = list()
	var/list/profiles = list(
		list("template" = "_maps/supporter_housing/cottage.dmm", "width" = 13, "height" = 15, "limit" = 40),
		list("template" = "_maps/supporter_housing/house.dmm", "width" = 17, "height" = 19, "limit" = 80),
		list("template" = "_maps/supporter_housing/manor.dmm", "width" = 21, "height" = 23, "limit" = 120),
	)

/datum/supporter_housing/New()
	. = ..()
	for(var/path in list(/obj/structure/chair/wood/rogue, /obj/structure/chair/wood/rogue/chair3, /obj/structure/table/wood, /obj/structure/table/wood/crafted, /obj/structure/bed/rogue/shit, /obj/structure/curtain, /obj/structure/curtain/red, /obj/structure/curtain/blue, /obj/structure/curtain/green, /obj/structure/curtain/brown, /obj/structure/curtain/purple, /obj/structure/curtain/magenta, /obj/structure/curtain/black, /obj/structure/curtain/drab, /obj/structure/curtain/orange, /obj/structure/curtain/yellow))
		decor_types["[path]"] = path
		decor_tiers["[path]"] = 1
	register_craftable_structures()
	register_furnishings()
	register_wall_types()
	for(var/type_key in decor_types)
		var/path = decor_types[type_key]
		var/household_light = ispath(path, /obj/machinery/light/rogue/torchholder) || ispath(path, /obj/machinery/light/rogue/candle) || ispath(path, /obj/machinery/light/rogue/campfire) || ispath(path, /obj/machinery/light/rogue/firebowl)
		if((ispath(path, /obj/machinery) && !household_light && decor_tiers[type_key] == 1) || ispath(path, /obj/structure/autosmither) || ispath(path, /obj/structure/autogrinder) || ispath(path, /obj/structure/windmill))
			decor_tiers[type_key] = 3

/datum/supporter_housing/proc/capacity(map_width = world.maxx, map_height = world.maxy)
	return min(HOUSING_MAX_HOMES, max(0, FLOOR((map_width - 2) / HOUSING_CELL_SIZE, 1)) * max(0, FLOOR((map_height - 2) / HOUSING_CELL_SIZE, 1)))

/datum/supporter_housing/proc/is_entrance(obj/structure/mineral_door/door)
	return !QDELETED(door) && is_supported_map(SSmapping.current_map) && (door.type in entrance_types)

/datum/supporter_housing/proc/is_supported_map(datum/map_config/map)
	if(!map)
		return FALSE
	// Map configs accept both a filename and a list (Desert Town uses the latter).
	var/list/map_files = islist(map.map_file) ? map.map_file : list(map.map_file)
	for(var/filename in map_files)
		if(filename in entrance_maps)
			return TRUE
	return FALSE

/datum/supporter_housing/proc/subscription_profile(mob/living/carbon/human/user)
	// Failure is distinct from an expired subscription. Neither destroys existing homes.
	if(!user.client?.sync_donation_info())
		return null
	return profile_for_subscription(user.client.donation_tier)

/datum/supporter_housing/proc/role_allowed(datum/job/role)
	if(!istype(role, /datum/job/roguetown) || role.faction != "Station" || role.antag_job)
		return FALSE
	if(role.type in list(/datum/job/roguetown/adventurer, /datum/job/roguetown/mercenary, /datum/job/roguetown/adventurer/courtagent))
		return TRUE
	return !!(role.department_flag & (NOBLEMEN | GARRISON | CHURCHMEN | COURTIERS | YEOMEN | PEASANTS | YOUNGFOLK | INQUISITION | GUILDSMEN))

/datum/supporter_housing/proc/eligible_resident(mob/living/carbon/human/user)
	return !QDELETED(user) && role_allowed(SSjob.name_occupations[user.job])

/datum/supporter_housing/proc/can_claim_entrance(mob/living/carbon/human/user, obj/structure/mineral_door/door)
	// Only verified supporters may bypass the original Towner/Mercenary role lock.
	if(!CONFIG_GET(flag/supporter_housing) || !user?.ckey || !eligible_resident(user) || !is_entrance(door) || door.supporter_home || homes[user.ckey])
		return FALSE
	var/tier = subscription_profile(user)
	// Subscription queries can yield: recheck the character and entrance afterwards.
	return tier > 0 && eligible_resident(user) && is_entrance(door) && !door.supporter_home && !homes[user.ckey]

/datum/supporter_housing/proc/profile_for_subscription(subscription_tier)
	switch(subscription_tier)
		if("wizard")
			return 1
		if("cultist")
			return 2
		if("assistant")
			return 3
	return 0

/datum/supporter_housing/proc/try_open(obj/item/roguekey/key, obj/structure/mineral_door/door, mob/living/carbon/human/user)
	if(!CONFIG_GET(flag/supporter_housing) || !is_entrance(door) || key.lockhash != door.lockhash)
		return FALSE
	if(door.supporter_home)
		// Existing homes remain ordinary places, even after expiry. Keys can be stolen/shared.
		return door.supporter_home.open_with_key(key, user)
	if(!eligible_resident(user) || door.housing_resident_ckey != user.ckey)
		return FALSE
	if(pending_owners[user.ckey] || pending_doors[door])
		to_chat(user, span_warning("This home's entrance is already being prepared."))
		return TRUE
	var/datum/supporter_home/home = homes[user.ckey]
	if(home?.entrance)
		to_chat(user, span_warning("Your home already has an entrance this round."))
		return TRUE
	var/owner_ckey = user.ckey
	pending_owners[owner_ckey] = TRUE
	pending_doors[door] = TRUE
	var/datum/housing_action_guard/guard = new(user, get_turf(door))
	var/tier = subscription_profile(user)
	if(isnull(tier))
		to_chat(user, span_warning("The subscription service is unavailable. Your saved home is unchanged."))
	else if(tier && eligible_resident(user) && guard.check() && user.get_active_held_item() == key)
		to_chat(user, span_notice("I begin to prepare the entrance to my home..."))
		if(do_after(user, 5 SECONDS, target = door, extra_checks = CALLBACK(guard, TYPE_PROC_REF(/datum/housing_action_guard, check))))
			// A cancelled template load can leave a complete home awaiting its entrance.
			// Reuse it without reading storage or allocating another plot.
			var/list/saved
			if(!home)
				saved = storage.read_home(owner_ckey)
			if(!home && !saved)
				to_chat(user, span_warning("The housing record could not be read. Your saved home is unchanged."))
			else if(!QDELETED(door) && !door.supporter_home && guard.check() && user.get_active_held_item() == key && key.lockhash == door.lockhash && user.ckey == owner_ckey && eligible_resident(user))
				if(!home)
					home = create_home(owner_ckey, tier, saved)
				if(home && eligible_resident(user) && user.ckey == owner_ckey && !QDELETED(door) && !door.supporter_home && guard.check() && user.get_active_held_item() == key && key.lockhash == door.lockhash)
					home.bind_entrance(door)
					home.open_with_key(key, user, prepared = TRUE)
				else if(home)
					to_chat(user, span_warning("Preparing the entrance was interrupted. Use your key again to finish."))
				else
					to_chat(user, span_warning("No housing plot is available. Your saved home is unchanged."))
	qdel(guard)
	pending_owners -= owner_ckey
	pending_doors -= door
	// Non-subscribers can still use their original town house and key.
	return tier > 0

/datum/supporter_housing/proc/create_home(owner_ckey, tier, list/saved)
	if(loading || homes[owner_ckey] || slots_used >= capacity() || !(tier in list(1, 2, 3)))
		return
	var/list/records = validate_records(saved["records"])
	if(isnull(records))
		return
	loading = TRUE
	if(!level)
		level = SSmapping.add_new_zlevel("Supporter homes", list(ZTRAIT_AWAY = TRUE, ZTRAIT_IGNORE_WEATHER_TRAIT = TRUE))
	var/columns = FLOOR((world.maxx - 2) / HOUSING_CELL_SIZE, 1)
	var/x = 2 + (slots_used % columns) * HOUSING_CELL_SIZE
	var/y = 2 + FLOOR(slots_used / columns, 1) * HOUSING_CELL_SIZE
	var/datum/supporter_home/home = load_home_at(owner_ckey, tier, saved, x, y)
	// A failed load may have placed part of a map: never allocate over that plot.
	slots_used++
	if(home)
		homes[owner_ckey] = home
	loading = FALSE
	return home

// Caller holds loading and owns the plot. Admin reloads reuse their reserved plot.
/datum/supporter_housing/proc/load_home_at(owner_ckey, tier, list/saved, x, y)
	var/list/records = validate_records(saved["records"])
	if(isnull(records))
		return null
	var/list/profile = profiles[tier]
	var/datum/map_template/template = new(profile["template"])
	var/list/bounds = template.load(locate(x, y, level.z_value))
	qdel(template)
	if(!bounds)
		return
	var/datum/supporter_home/home = new(src, owner_ckey, tier, x, y, level.z_value)
	if(!home.setup(records, saved["found"], saved["revision"]))
		qdel(home)
		return
	home.last_saved_age = saved["saved_age"]
	home.last_saved_seen = world.time
	return home

/datum/supporter_housing/proc/valid_record(list/record)
	if(!islist(record) || length(record) > 8 || !istext(record["type"]))
		return FALSE
	if(!isnull(record["archived"]) && record["archived"] != TRUE)
		return FALSE
	var/is_wall = record["kind"] == "wall"
	if(is_wall ? !wall_types[record["type"]] : (!isnull(record["kind"]) || !decor_types[record["type"]]))
		return FALSE
	for(var/field in record)
		if(!(field in list("type", "x", "y", "dir", "color", "kind", "archived", "contents")))
			return FALSE
	var/x = record["x"]
	var/y = record["y"]
	// Coordinates are relative to the plot, bounded by the largest interior.
	if(!isnum(x) || x != round(x) || x < 3 || x > 19 || !isnum(y) || y != round(y) || y < (is_wall ? 6 : 7) || y > 21)
		return FALSE
	if(!(record["dir"] in GLOB.cardinals))
		return FALSE
	var/decor_color = record["color"]
	var/static/regex/color_pattern = regex("^#\[0-9a-fA-F\]{6}$")
	if(!isnull(decor_color) && (!istext(decor_color) || length(decor_color) != 7 || !color_pattern.Find(decor_color)))
		return FALSE
	if("contents" in record)
		if(is_wall || !is_home_storage(decor_types[record["type"]]) || !islist(record["contents"]))
			return FALSE
		var/obj/structure/closet/container_type = decor_types[record["type"]]
		if(length(record["contents"]) > min(30, initial(container_type.storage_capacity)))
			return FALSE
		for(var/list/child as anything in record["contents"])
			if(!valid_stored_item(child))
				return FALSE
	return TRUE

/datum/supporter_housing/proc/validate_records(list/records)
	if(!islist(records) || length(records) > HOUSING_MAX_RECORDS || length(json_encode(records)) > HOUSING_MAX_JSON)
		return null
	var/list/tile_counts = list()
	var/list/dense_tiles = list()
	var/list/wall_tiles = list()
	var/decor_count = 0
	var/wall_count = 0
	for(var/list/record as anything in records)
		if(!valid_record(record))
			return null
		var/tile_id = "[record["x"]],[record["y"]]"
		if(record["kind"] == "wall")
			wall_count++
			if(wall_count > 64 || (!record["archived"] && wall_tiles[tile_id]))
				return null
			if(!record["archived"])
				wall_tiles[tile_id] = TRUE
			continue
		decor_count += record_size(record)
		if(decor_count > 160)
			return null
		if(record["archived"])
			continue // Inactive rows count toward storage, without occupying the current layout.
		tile_counts[tile_id]++
		if(tile_counts[tile_id] > 3)
			return null
		var/obj/decor_type = decor_types[record["type"]]
		if(initial(decor_type.density))
			if(dense_tiles[tile_id])
				return null
			dense_tiles[tile_id] = TRUE
	return records

/datum/supporter_housing/proc/home_at(turf/tile)
	if(!tile || tile.z != level?.z_value)
		return null
	for(var/owner_ckey in homes)
		var/datum/supporter_home/home = homes[owner_ckey]
		if(home.contains(tile))
			return home

// Kept separate so the temporary smoke harness can simulate unavailable DBs and CAS conflicts.
/datum/housing_storage

/datum/housing_storage/proc/read_home(owner_ckey)
	if(!SSdbcore.Connect())
		return null
	var/datum/DBQuery/query = SSdbcore.NewQuery("SELECT revision, decor, TIMESTAMPDIFF(SECOND, updated_at, NOW()) FROM [format_table_name("supporter_housing")] WHERE ckey = :ckey", list("ckey" = owner_ckey))
	if(!query.Execute())
		qdel(query)
		return null
	var/list/result = list("found" = FALSE, "revision" = 0, "records" = list())
	if(query.NextRow())
		result["found"] = TRUE
		result["revision"] = text2num("[query.item[1]]")
		result["saved_age"] = max(0, text2num("[query.item[3]]"))
		var/raw = query.item[2]
		if(!istext(raw) || length(raw) > HOUSING_MAX_JSON)
			qdel(query)
			return null
		try
			result["records"] = json_decode(raw)
		catch
			qdel(query)
			return null
	qdel(query)
	return result

/datum/housing_storage/proc/write_home(owner_ckey, list/records, expected_revision)
	if(!SSdbcore.Connect())
		return FALSE
	var/list/arguments = list("ckey" = owner_ckey, "decor" = json_encode(records), "revision" = expected_revision)
	var/sql
	if(expected_revision)
		sql = "UPDATE [format_table_name("supporter_housing")] SET decor = :decor, revision = revision + 1, updated_at = NOW() WHERE ckey = :ckey AND revision = :revision"
	else
		sql = "INSERT IGNORE INTO [format_table_name("supporter_housing")] (ckey, revision, decor) VALUES (:ckey, 1, :decor)"
	var/datum/DBQuery/query = SSdbcore.NewQuery(sql, arguments)
	var/success = query.Execute() && query.affected == 1
	qdel(query)
	return success

#undef HOUSING_CELL_SIZE
#undef HOUSING_MAX_HOMES
#undef HOUSING_MAX_RECORDS
#undef HOUSING_MAX_JSON
