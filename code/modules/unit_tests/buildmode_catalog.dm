GLOBAL_VAR_INIT(buildmode_test_constructions, 0)

/obj/item/rogueweapon/sword/buildmode_catalog_test/New()
	GLOB.buildmode_test_constructions++
	return ..()

// Test the catalogue without a real client, in an isolated savefile.
/datum/buildmode/catalog_test
	var/test_authorized = FALSE

/datum/buildmode/catalog_test/New()
	catalog_state = new
	mode = new /datum/buildmode_mode/catalog(src)
	buttons = list()

/datum/buildmode/catalog_test/can_build(client/actor)
	return test_authorized || ..()

/datum/buildmode/catalog_test/catalog_preferences_path()
	return "tmp/buildmode_catalog_unit_test.sav"

/datum/unit_test/buildmode_catalog/Run()
	check_browsing()
	check_configuration()
	check_indexed_results()
	check_cached_changes()
	check_saved_paths()
	check_filters()
	check_navigation()
	check_toggle()
	check_placement()
	check_deletion()
	check_turf_deletion()

/datum/unit_test/buildmode_catalog/proc/new_builder()
	var/datum/buildmode/catalog_test/builder = new()
	allocated += builder
	return builder

/datum/unit_test/buildmode_catalog/proc/check_browsing()
	var/constructions_before = GLOB.buildmode_test_constructions
	var/list/entries = buildmode_catalog_entries()
	TEST_ASSERT(/obj/item/rogueweapon/sword in entries, "Swords must be available.")
	TEST_ASSERT(!(/atom/movable/screen/buildmode in entries), "HUD atoms must never be spawned from the catalogue.")
	TEST_ASSERT(!(/mob/dead/observer in entries), "Ghosts must never be offered as spawnable creatures.")
	TEST_ASSERT(!buildmode_catalog_allowed(/datum/buildmode), "Non-world datums must be rejected.")
	TEST_ASSERT_EQUAL(buildmode_catalog_category(/obj/item/rogueweapon/shield/wood), "weapons", "Shields belong with weapons.")
	TEST_ASSERT_EQUAL(buildmode_catalog_category(/obj/item/clothing/suit/roguetown/armor/brigandine/light), "clothing", "Armor belongs with clothing.")
	var/datum/buildmode/catalog_test/builder = new_builder()
	TEST_ASSERT_EQUAL(builder.catalog_card(/obj/item/rogueweapon/sword)["favorite"], FALSE, "An unsaved card must send a false favorite flag, not its path.")
	builder.catalog_favorites = list("/obj/item/rogueweapon/sword")
	TEST_ASSERT_EQUAL(builder.catalog_card(/obj/item/rogueweapon/sword)["favorite"], TRUE, "A saved card must send a true favorite flag.")
	TEST_ASSERT(!builder.can_build(null), "Real access check must reject a missing client.")
	TEST_ASSERT_EQUAL(builder.catalog_state.can_use_topic(builder, null), UI_CLOSE, "UI must close without an authorized owner.")
	builder.catalog_search = "ROGUEWEAPON sword"
	var/list/results = builder.filtered_catalog()
	TEST_ASSERT(/obj/item/rogueweapon/sword in results, "Search must match all words, case insensitively, by path.")
	builder.catalog_search = "no_such_catalog_object_123456"
	builder.catalog_results = null
	var/list/data = builder.ui_data(null)
	TEST_ASSERT_EQUAL(length(data["items"]), 0, "Empty searches must return an empty page, without an indexing runtime.")
	TEST_ASSERT_EQUAL(data["pages"], 1, "An empty catalogue must still have valid pagination.")
	builder.catalog_search = ""
	builder.catalog_results = null
	builder.catalog_page = 1
	var/list/first_page = builder.ui_data(null)["items"]
	builder.catalog_page = 2
	data = builder.ui_data(null)
	TEST_ASSERT_EQUAL(data["page"], 2, "The next page must remain selected.")
	var/list/second_page = data["items"]
	var/list/first_paths = list()
	for(var/list/card as anything in first_page)
		first_paths += card["path"]
	for(var/list/card as anything in second_page)
		TEST_ASSERT(!(card["path"] in first_paths), "The next page must contain a different slice of results.")
	builder.catalog_page = 1
	data = builder.ui_data(null)
	var/list/returned_page = data["items"]
	TEST_ASSERT_EQUAL(returned_page[1]["path"], first_page[1]["path"], "Returning to the previous page must restore its first result.")
	builder.catalog_page = 999999
	data = builder.ui_data(null)
	TEST_ASSERT_EQUAL(data["page"], data["pages"], "Out-of-range pages must be clamped.")
	TEST_ASSERT(length(data["items"]) <= BUILDMODE_PAGE_SIZE, "Only one page of icons should be sent to the client.")
	TEST_ASSERT(buildmode_catalog_icon(/obj/item/rogueweapon/sword), "A visible object must have a valid thumbnail.")
	builder.catalog_card(/obj/item/rogueweapon/sword/buildmode_catalog_test)
	TEST_ASSERT_EQUAL(GLOB.buildmode_test_constructions, constructions_before, "Browsing and generating thumbnails must never invoke object constructors.")
	TEST_ASSERT_NULL(builder.selected_path, "Browsing must never arm a placement.")

/datum/unit_test/buildmode_catalog/proc/check_saved_paths()
	var/list/cleaned = buildmode_sanitize_paths(list("/obj/item/rogueweapon/sword", "/datum/buildmode", "/obsolete/type", 42, "/obj/item/rogueweapon/sword", "/obj/item/rogueweapon/shield/wood"), 1)
	TEST_ASSERT_EQUAL(length(cleaned), 1, "Loading must discard invalid/duplicate paths and enforce the limit.")
	TEST_ASSERT_EQUAL(cleaned[1], "/obj/item/rogueweapon/sword", "Valid saved paths must survive.")
	var/datum/buildmode/catalog_test/builder = new_builder()
	fdel(builder.catalog_preferences_path())
	builder.catalog_favorites = list("/obj/item/rogueweapon/sword")
	builder.catalog_recent = list("/obj/item/rogueweapon/shield/wood")
	builder.write_catalog_preferences()
	builder.catalog_favorites = list()
	builder.catalog_recent = list()
	builder.read_catalog_preferences()
	TEST_ASSERT_EQUAL(builder.catalog_favorites[1], "/obj/item/rogueweapon/sword", "Favorites must survive saving and loading.")
	TEST_ASSERT_EQUAL(builder.catalog_recent[1], "/obj/item/rogueweapon/shield/wood", "Recent choices must survive saving and loading.")
	TEST_ASSERT(!builder.select_catalog_path(/datum/buildmode), "Forged paths must never arm placement.")
	builder.select_catalog_path(/obj/item/rogueweapon/sword)
	builder.select_catalog_path(/obj/item/rogueweapon/shield/wood)
	builder.select_catalog_path(/obj/item/rogueweapon/sword)
	TEST_ASSERT_EQUAL(builder.catalog_recent[1], "/obj/item/rogueweapon/sword", "Recent selection must move to the front.")
	TEST_ASSERT_EQUAL(length(builder.catalog_recent), 2, "Recent entries must not duplicate.")
	builder.clear_catalog_selection()
	TEST_ASSERT_NULL(builder.selected_path, "Cancel must clear placement.")
	TEST_ASSERT_NULL(builder.spawn_preview, "Cancel must remove the cursor preview.")
	fdel(builder.catalog_preferences_path())

/datum/unit_test/buildmode_catalog/proc/check_placement()
	var/datum/buildmode/catalog_test/builder = new_builder()
	var/turf/target = run_loc_floor_bottom_left
	builder.selected_path = /obj/item/rogueweapon/sword
	builder.spawn_amount = 3
	var/list/before = target.contents.Copy()
	TEST_ASSERT(!builder.place_catalog(null, target), "Placement must reject a revoked or missing permission.")
	TEST_ASSERT_EQUAL(length(target.contents), length(before), "Denied placement must not create anything.")
	builder.test_authorized = TRUE
	builder.build_dir = EAST
	builder.spawn_pixel_x = 4
	builder.spawn_pixel_y = -3
	TEST_ASSERT(builder.place_catalog(null, target), "Authorized placement must succeed.")
	var/list/created = target.contents - before
	allocated += created
	TEST_ASSERT_EQUAL(length(created), 3, "Quantity must create exactly one batch.")
	for(var/obj/item/item as anything in created)
		TEST_ASSERT_EQUAL(item.dir, EAST, "Placement direction must be applied.")
		TEST_ASSERT_EQUAL(item.pixel_x, initial(item.pixel_x) + 4, "Horizontal offset must be applied.")
		TEST_ASSERT_EQUAL(item.pixel_y, initial(item.pixel_y) - 3, "Vertical offset must be applied.")
		TEST_ASSERT(item.flags_1 & ADMIN_SPAWNED_1, "Objects must be marked as spawned by administration.")
	TEST_ASSERT(!builder.place_catalog(null, target), "Rapid repeated requests must not create duplicate batches.")
	builder.next_spawn = 0
	builder.spawn_amount = ADMIN_SPAWN_CAP + 10
	before = target.contents.Copy()
	TEST_ASSERT(builder.place_catalog(null, target), "A bounded large batch must succeed.")
	created = target.contents - before
	allocated += created
	TEST_ASSERT_EQUAL(length(created), ADMIN_SPAWN_CAP, "Quantity must be clamped again on the server.")
	builder.next_spawn = 0
	builder.selected_path = /datum/buildmode
	TEST_ASSERT(!builder.place_catalog(null, target), "Forged paths must also be rejected at placement time.")
	builder.selected_path = /obj/item/rogueweapon/sword
	TEST_ASSERT(!builder.place_catalog(null, null), "Placement needs a valid map tile.")

/datum/unit_test/buildmode_catalog/proc/check_deletion()
	var/datum/buildmode/catalog_test/builder = new_builder()
	var/obj/item/rogueweapon/sword/item = new(run_loc_floor_bottom_left)
	allocated += item
	builder.selected_path = /obj/item/rogueweapon/sword
	TEST_ASSERT(!builder.delete_catalog_object(null, item), "Deleting also requires build permission.")
	TEST_ASSERT(!QDELETED(item), "Denied deletion must leave the object intact.")
	builder.test_authorized = TRUE
	var/atom/movable/screen/buildmode/catalog/button = new(builder)
	allocated += button
	TEST_ASSERT(!builder.delete_catalog_object(null, button), "Right-click must not delete HUD controls.")
	builder.refresh_spawn_preview()
	builder.catalog_status = "Previous placement status"
	builder.mode.handle_click(null, "right=1", item)
	TEST_ASSERT_NULL(builder.selected_path, "Right-click during placement must cancel the selected spawn type.")
	TEST_ASSERT_NULL(builder.spawn_preview, "Right-click cancellation must remove the placement preview.")
	TEST_ASSERT_NULL(builder.catalog_status, "Cancellation must clear the old placement status.")
	TEST_ASSERT(!QDELETED(item), "The click that cancels placement must not also delete the clicked object.")
	TEST_ASSERT(!builder.ui_data(null)["armed"], "The catalogue must show deletion mode after right-click cancellation.")
	builder.mode.handle_click(null, "right=1", item)
	TEST_ASSERT(QDELETED(item), "The next right-click must delete the clicked world object.")
	TEST_ASSERT_NULL(builder.selected_path, "Deletion must keep placement canceled.")
	builder.selected_path = /obj/item/rogueweapon/sword
	builder.refresh_spawn_preview()
	builder.mode.handle_click(null, "right=1", run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(builder.selected_path, "Right-click on an empty map tile must also cancel placement.")
	TEST_ASSERT_NULL(builder.spawn_preview, "Canceling on a map tile must remove the preview.")
	var/before = length(run_loc_floor_bottom_left.contents)
	builder.mode.handle_click(null, "left=1", run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(run_loc_floor_bottom_left.contents), before, "Left-click after right-click cancellation must not spawn anything.")

/datum/unit_test/buildmode_catalog/proc/check_turf_deletion()
	var/datum/buildmode/catalog_test/builder = new_builder()
	var/turf/target = run_loc_floor_bottom_left
	var/original_type = target.type
	var/original_baseturfs = islist(target.baseturfs) ? target.baseturfs.Copy() : target.baseturfs
	var/obj/item/rogueweapon/sword/item = new(target)
	allocated += item
	for(var/turf_type in list(/turf/closed/wall/mineral/rogue/stone, /turf/open/floor/rogue/blocks))
		target = target.ChangeTurf(/turf/open/floor/rogue/naturalstone, /turf/open/floor/rogue/naturalstone)
		builder.test_authorized = TRUE
		builder.selected_path = turf_type
		builder.next_spawn = 0
		TEST_ASSERT(builder.place_catalog(null, target), "The catalogue must place the test wall or floor.")
		TEST_ASSERT_EQUAL(target.type, turf_type, "The selected turf must replace the test tile.")
		builder.test_authorized = FALSE
		TEST_ASSERT(!builder.delete_catalog_object(null, target), "Removing a wall or floor requires build permission.")
		TEST_ASSERT_EQUAL(target.type, turf_type, "Denied deletion must leave the turf intact.")
		builder.test_authorized = TRUE
		builder.mode.handle_click(null, "right=1", target)
		TEST_ASSERT_NULL(builder.selected_path, "The first right-click on a placed turf must cancel spawning.")
		TEST_ASSERT_EQUAL(target.type, turf_type, "Canceling placement must not also remove the wall or floor.")
		builder.mode.handle_click(null, "right=1", target)
		TEST_ASSERT_EQUAL(target.type, /turf/open/floor/rogue/naturalstone, "The next right-click must expose the underlying turf.")
		TEST_ASSERT(!QDELETED(item) && item.loc == target, "Removing a turf must retain objects standing on the tile.")
	// A mapped wall may have several underlying layers: remove only one per click.
	target = target.ChangeTurf(/turf/closed/wall/mineral/rogue/stone, list(/turf/open/floor/rogue/naturalstone, /turf/open/floor/rogue/blocks))
	builder.mode.handle_click(null, "right=1", target)
	TEST_ASSERT_EQUAL(target.type, /turf/open/floor/rogue/blocks, "Removing a wall must preserve the floor beneath it.")
	builder.mode.handle_click(null, "right=1", target)
	TEST_ASSERT_EQUAL(target.type, /turf/open/floor/rogue/naturalstone, "Removing the exposed floor must reveal the next layer.")
	builder.mode.handle_click(null, "right=1", target)
	TEST_ASSERT_EQUAL(target.type, /turf/open/floor/rogue/naturalstone, "The bottommost map layer must remain intact.")
	target.ChangeTurf(original_type, original_baseturfs)

/datum/unit_test/buildmode_catalog/proc/check_filters()
	var/constructions_before = GLOB.buildmode_test_constructions
	TEST_ASSERT_EQUAL(buildmode_catalog_subcategory(/obj/item/rogueweapon/greatsword, "weapons"), "greatswords", "Greatswords must have their own group.")
	TEST_ASSERT_EQUAL(buildmode_catalog_subcategory(/obj/item/rogueweapon/shield/wood, "weapons"), "shields", "Shields must not be mixed with swords.")
	TEST_ASSERT_EQUAL(buildmode_catalog_subcategory(/obj/structure/table, "objects"), "furniture", "Tables belong with furniture.")
	TEST_ASSERT_EQUAL(buildmode_catalog_subcategory(/obj/structure/closet, "objects"), "storage", "Closets belong with storage.")
	TEST_ASSERT_EQUAL(buildmode_catalog_subcategory(/obj/machinery/light/rogue/forge, "objects"), "workshops", "Forges belong with workshop equipment, before general lighting.")
	var/datum/buildmode/catalog_test/builder = new_builder()
	builder.restore_catalog_navigation(list("category" = "weapons", "subcategory" = "swords", "search" = "ROGUEWEAPON sword"))
	var/list/results = builder.filtered_catalog()
	TEST_ASSERT(/obj/item/rogueweapon/sword in results, "Weapon subgroups must combine with text search.")
	TEST_ASSERT(!(/obj/item/rogueweapon/greatsword in results), "Sword filtering must exclude other weapon families.")
	TEST_ASSERT(!(/obj/item/rogueweapon/shield/wood in results), "Sword filtering must exclude shields.")
	builder.restore_catalog_navigation(list("category" = "clothing", "armor_class" = "1", "coverage" = "chest", "search" = "brigandine"))
	results = builder.filtered_catalog()
	TEST_ASSERT(/obj/item/clothing/suit/roguetown/armor/brigandine/light in results, "Class, body coverage and search must combine for armor.")
	TEST_ASSERT(!(/obj/item/clothing/suit/roguetown/armor/brigandine in results), "Medium brigandine must not appear in light armor.")
	builder.catalog_coverage = "feet"
	builder.catalog_results = null
	TEST_ASSERT(!(/obj/item/clothing/suit/roguetown/armor/brigandine/light in builder.filtered_catalog()), "Torso armor must not appear in foot coverage.")
	TEST_ASSERT_EQUAL(GLOB.buildmode_test_constructions, constructions_before, "Grouping and filtering must not construct game objects.")

/datum/unit_test/buildmode_catalog/proc/check_navigation()
	var/datum/buildmode/catalog_test/builder = new_builder()
	fdel(builder.catalog_preferences_path())
	var/datum/tgui/ui = new(null, builder, "BuildMode")
	allocated += ui
	ui.status = UI_INTERACTIVE
	builder.ui_act("category", list("value" = "weapons"), ui)
	TEST_ASSERT_EQUAL(builder.catalog_category, "all", "Navigation actions also require build permission.")
	builder.test_authorized = TRUE
	builder.ui_act("category", list("value" = "weapons"), ui)
	builder.ui_act("page", list("value" = 2), ui)
	var/list/second_page = builder.ui_data(null)["items"]
	TEST_ASSERT_EQUAL(builder.catalog_page, 2, "The page fixture must have multiple pages.")
	var/datum/buildmode/catalog_test/reopened = new_builder()
	reopened.read_catalog_preferences()
	TEST_ASSERT_EQUAL(reopened.catalog_category, "weapons", "A new F7 session must restore the category.")
	TEST_ASSERT_EQUAL(reopened.catalog_page, 2, "A new F7 session must restore the page.")
	var/list/restored_page = reopened.ui_data(null)["items"]
	TEST_ASSERT_EQUAL(restored_page[1]["path"], second_page[1]["path"], "Reopening must restore the same result slice.")
	TEST_ASSERT_NULL(reopened.selected_path, "Restoring navigation must not arm spawning.")
	builder.ui_act("subcategory", list("value" = "swords"), ui)
	TEST_ASSERT_EQUAL(builder.catalog_page, 1, "Changing a subgroup must reset the page.")
	builder.ui_act("search", list("value" = "sword"), ui)
	builder.ui_act("page", list("value" = 2), ui)
	reopened.read_catalog_preferences()
	TEST_ASSERT_EQUAL(reopened.catalog_page, 2, "The page inside a subgroup must survive reopening.")
	TEST_ASSERT_EQUAL(reopened.catalog_subcategory, "swords", "The selected subgroup must survive reopening.")
	TEST_ASSERT_EQUAL(reopened.catalog_search, "sword", "Search must survive reopening with its filters.")
	builder.ui_act("subcategory", list("value" = "furniture"), ui)
	TEST_ASSERT_EQUAL(builder.catalog_subcategory, "swords", "Subgroups from a different category must be rejected.")
	builder.ui_act("category", list("value" = "clothing"), ui)
	TEST_ASSERT_EQUAL(builder.catalog_subcategory, "all", "Changing category must clear the old subgroup.")
	builder.ui_act("search", list("value" = "brigandine"), ui)
	builder.ui_act("armor_class", list("value" = "1"), ui)
	builder.ui_act("coverage", list("value" = "chest"), ui)
	reopened.read_catalog_preferences()
	TEST_ASSERT_EQUAL(reopened.catalog_armor_class, "1", "Armor class must survive reopening.")
	TEST_ASSERT_EQUAL(reopened.catalog_coverage, "chest", "Body coverage must survive reopening.")
	TEST_ASSERT(/obj/item/clothing/suit/roguetown/armor/brigandine/light in reopened.filtered_catalog(), "Restored armor filters must produce the same matching objects.")
	builder.ui_act("category", list("value" = "objects"), ui)
	TEST_ASSERT_EQUAL(builder.catalog_armor_class, "all", "Leaving clothing must clear its class filter.")
	TEST_ASSERT_EQUAL(builder.catalog_coverage, "all", "Leaving clothing must clear its coverage filter.")
	builder.restore_catalog_navigation(list("category" = "weapons", "subcategory" = "obsolete", "armor_class" = "3", "coverage" = "head", "page" = 999999))
	TEST_ASSERT_EQUAL(builder.catalog_subcategory, "all", "Obsolete subgroup ids must fall back to all types.")
	TEST_ASSERT_EQUAL(builder.catalog_armor_class, "all", "Saved armor filters must not leak into weapons.")
	TEST_ASSERT_EQUAL(builder.catalog_page, builder.catalog_page_count(), "Saved pages must be clamped after the catalogue changes.")
	builder.restore_catalog_navigation(list("category" = "weapons", "search" = "no_such_catalog_object_123456", "page" = 9))
	TEST_ASSERT_EQUAL(builder.catalog_page, 1, "An empty restored search must stay on a valid page.")
	builder.restore_catalog_navigation(list("category" = "obsolete", "page" = 2))
	TEST_ASSERT_EQUAL(builder.catalog_category, "all", "Obsolete category ids must fall back to the default.")
	var/list/cleaned = buildmode_sanitize_navigation(list("category" = "clothing", "armor_class" = "invalid", "coverage" = "invalid", "page" = "invalid", "search" = 42))
	TEST_ASSERT_EQUAL(cleaned["armor_class"], "all", "Invalid saved armor class must be ignored.")
	TEST_ASSERT_EQUAL(cleaned["coverage"], "all", "Invalid saved coverage must be ignored.")
	TEST_ASSERT_EQUAL(cleaned["page"], 1, "Invalid saved page types must be ignored.")
	TEST_ASSERT_EQUAL(cleaned["search"], "", "Invalid saved search types must be ignored.")
	fdel(builder.catalog_preferences_path())
	write_legacy_preferences(builder.catalog_preferences_path())
	reopened.read_catalog_preferences()
	TEST_ASSERT_EQUAL(reopened.catalog_category, "all", "Older saves without navigation must use the default category.")
	TEST_ASSERT_EQUAL(reopened.catalog_page, 1, "Older saves without navigation must use the first page.")
	TEST_ASSERT_EQUAL(reopened.catalog_favorites[1], "/obj/item/rogueweapon/sword", "Older saves must retain favorites.")
	fdel(builder.catalog_preferences_path())

/datum/unit_test/buildmode_catalog/proc/check_toggle()
	var/datum/buildmode/catalog_test/builder = new_builder()
	builder.test_authorized = TRUE
	var/datum/tgui/ui = new(null, builder, "BuildMode")
	allocated += ui
	ui.status = UI_INTERACTIVE
	builder.ui_act("select", list("path" = "/obj/item/rogueweapon/sword"), ui)
	TEST_ASSERT(builder.spawn_preview, "Selecting a card must create its placement preview.")
	builder.ui_act("select", list("path" = "/obj/item/rogueweapon/sword"), ui)
	TEST_ASSERT_NULL(builder.selected_path, "Clicking the same card again must cancel spawning.")
	TEST_ASSERT_NULL(builder.spawn_preview, "Clicking the same card again must clear the preview.")
	TEST_ASSERT(istype(builder.mode, /datum/buildmode_mode/catalog), "Canceling selection must keep the mode for right-click deletion.")
	var/turf/target = run_loc_floor_bottom_left
	var/before = length(target.contents)
	builder.mode.handle_click(null, "left=1", target)
	TEST_ASSERT_EQUAL(length(target.contents), before, "Left-click after canceling must not create anything.")
	TEST_ASSERT(!builder.place_catalog(null, target), "Direct placement after canceling must also be rejected.")
	var/obj/item/rogueweapon/sword/item = new(target)
	allocated += item
	builder.mode.handle_click(null, "right=1", item)
	TEST_ASSERT(QDELETED(item), "Right-click deletion must remain available after canceling selection.")
	builder.ui_act("select", list("path" = "/obj/item/rogueweapon/sword"), ui)
	builder.ui_act("select", list("path" = "/obj/item/rogueweapon/shield/wood"), ui)
	TEST_ASSERT_EQUAL(builder.selected_path, /obj/item/rogueweapon/shield/wood, "Selecting a different card must switch the spawned type.")
	var/obj/item/rogueweapon/sword/picked = new(target)
	allocated += picked
	builder.mode.handle_click(null, "left=1;alt=1", picked)
	builder.mode.handle_click(null, "left=1;alt=1", picked)
	TEST_ASSERT_EQUAL(builder.selected_path, /obj/item/rogueweapon/sword, "Repeated eyedropper clicks must select rather than toggle.")
	fdel(builder.catalog_preferences_path())

/datum/unit_test/buildmode_catalog/proc/write_legacy_preferences(path)
	var/savefile/legacy = new(path)
	WRITE_FILE(legacy["favorites"], list("/obj/item/rogueweapon/sword"))

/datum/unit_test/buildmode_catalog/proc/check_indexed_results()
	var/datum/buildmode/catalog_test/builder = new_builder()
	var/list/entries = buildmode_catalog_entries()
	var/list/queries = list(list("category" = "all"))
	for(var/category in buildmode_catalog_categories())
		if(category in list("all", "favorites", "recent"))
			continue
		queries += list(list("category" = category))
		for(var/subcategory in buildmode_catalog_groups()[category])
			queries += list(list("category" = category, "subcategory" = subcategory))
	for(var/list/query as anything in queries)
		var/list/expected = list()
		for(var/path in entries)
			var/list/entry = entries[path]
			if(query["category"] != "all" && query["category"] != entry["category"])
				continue
			if(query["subcategory"] && query["subcategory"] != entry["subcategory"])
				continue
			expected += path
		builder.restore_catalog_navigation(query)
		TEST_ASSERT(json_encode(builder.filtered_catalog()) == json_encode(expected), "Indexed results must preserve every path and its order for [json_encode(query)].")
		if(query["category"] != "all")
			TEST_ASSERT_EQUAL(length(builder.catalog_candidates()), length(expected), "A category query must not scan unrelated catalogue types.")

/datum/unit_test/buildmode_catalog/proc/check_cached_changes()
	var/datum/buildmode/catalog_test/builder = new_builder()
	fdel(builder.catalog_preferences_path())
	builder.restore_catalog_navigation(list("category" = "weapons", "subcategory" = "swords", "page" = 2))
	var/list/cached_results = builder.filtered_catalog()
	builder.select_catalog_path(/obj/item/rogueweapon/sword)
	TEST_ASSERT_EQUAL(builder.filtered_catalog(), cached_results, "Selecting a spawn type must reuse an unaffected search result.")
	TEST_ASSERT_EQUAL(builder.catalog_page, 2, "Selecting a spawn type must retain the current page.")
	builder.toggle_catalog_favorite("/obj/item/rogueweapon/sword")
	TEST_ASSERT_EQUAL(builder.filtered_catalog(), cached_results, "Favorites must not invalidate a normal category search.")
	TEST_ASSERT(builder.catalog_card(/obj/item/rogueweapon/sword)["favorite"], "A reused search must still update the favorite badge.")
	TEST_ASSERT(!builder.write_catalog_preferences(), "Unchanged settings must not be written again.")
	var/image/preview = builder.spawn_preview
	builder.set_catalog_placement_option("amount", 4)
	TEST_ASSERT_EQUAL(builder.spawn_preview, preview, "Quantity changes must retain the same placement preview.")
	builder.restore_catalog_navigation(list("category" = "favorites"))
	TEST_ASSERT(/obj/item/rogueweapon/sword in builder.filtered_catalog(), "The favorites view must include a newly saved path.")
	builder.toggle_catalog_favorite("/obj/item/rogueweapon/sword")
	TEST_ASSERT(!(/obj/item/rogueweapon/sword in builder.filtered_catalog()), "Removing a favorite must refresh the favorites view immediately.")
	builder.restore_catalog_navigation(list("category" = "recent"))
	builder.select_catalog_path(/obj/item/rogueweapon/shield/wood)
	TEST_ASSERT_EQUAL(builder.filtered_catalog()[1], /obj/item/rogueweapon/shield/wood, "A new selection must update the recent view immediately.")
	builder.select_catalog_path(/obj/item/rogueweapon/sword)
	TEST_ASSERT_EQUAL(builder.filtered_catalog()[1], /obj/item/rogueweapon/sword, "Picking an older type must reorder the recent view.")
	var/datum/buildmode/catalog_test/reopened = new_builder()
	reopened.read_catalog_preferences()
	TEST_ASSERT_EQUAL(reopened.catalog_recent[1], "/obj/item/rogueweapon/sword", "Changes to recent paths must still be saved immediately.")
	TEST_ASSERT_EQUAL(length(reopened.catalog_favorites), 0, "Removing favorites must still be persisted.")
	builder.catalog_search = "shield"
	builder.invalidate_catalog_results()
	TEST_ASSERT(builder.write_catalog_preferences(), "Changing saved values must trigger a write.")
	TEST_ASSERT(!builder.write_catalog_preferences(), "Repeated writes of the same navigation must be skipped.")
	fdel(builder.catalog_preferences_path())
	TEST_ASSERT(builder.write_catalog_preferences(), "A missing preferences file must be recreated even if values are unchanged.")
	fdel(builder.catalog_preferences_path())

/datum/unit_test/buildmode_catalog/proc/check_configuration()
	var/list/categories = buildmode_catalog_categories()
	var/list/groups = buildmode_catalog_groups()
	for(var/category in categories)
		TEST_ASSERT(istext(categories[category]) && length(categories[category]), "Every category needs a display name: [category].")
	for(var/category in groups)
		TEST_ASSERT(category in categories, "A subgroup must belong to a declared category: [category].")
		var/list/category_groups = groups[category]
		TEST_ASSERT("other" in category_groups, "A grouped category needs its fallback 'other' group: [category].")
		for(var/id in category_groups)
			var/list/group = category_groups[id]
			TEST_ASSERT(istext(group["name"]) && length(group["name"]), "Every subgroup needs a display name: [category]/[id].")
			for(var/root_type in group["roots"])
				TEST_ASSERT(ispath(root_type, /atom), "Subgroup roots must be compiled atom paths: [category]/[id].")
				TEST_ASSERT_EQUAL(buildmode_catalog_category(root_type), category, "A subgroup root must belong to its parent category: [root_type].")
	var/list/entries = buildmode_catalog_entries()
	for(var/path in entries)
		TEST_ASSERT(entries[path]["category"] in categories, "Classification must return a declared category: [path].")
	var/datum/buildmode/catalog_test/builder = new_builder()
	var/list/data = builder.ui_static_data(null)
	TEST_ASSERT_EQUAL(length(data["categories"]), length(categories), "The UI must receive every configured category.")
	for(var/list/option as anything in data["categories"])
		TEST_ASSERT_EQUAL(option["name"], categories[option["id"]], "Displayed category names must come from configuration.")
	for(var/list/option as anything in data["armor_classes"])
		TEST_ASSERT_EQUAL(option["name"], buildmode_catalog_armor_classes()[option["id"]], "Armor class labels must come from configuration.")
	for(var/list/option as anything in data["coverage_zones"])
		TEST_ASSERT(buildmode_catalog_valid_coverage(option["id"]), "Every displayed coverage choice must be accepted by the server.")
		TEST_ASSERT_EQUAL(option["name"], buildmode_catalog_coverage_zones()[option["id"]]["name"], "Coverage names and masks must share configuration.")
	TEST_ASSERT_EQUAL(data["max_offset"], BUILDMODE_MAX_OFFSET, "UI and server must share the offset limit.")
	TEST_ASSERT_EQUAL(data["max_search_length"], BUILDMODE_MAX_SEARCH_LENGTH, "UI and server must share the search limit.")
