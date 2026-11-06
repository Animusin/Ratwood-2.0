/// Model the persistent callback registry after its original client has gone away.
/datum/player_details/runtime_nov06_login/New()
	return

/datum/buildmode/runtime_nov06_disconnected/New(datum/player_details/details)
	buttons = list()
	mode = new /datum/buildmode_mode/catalog(src)
	login_callback_owner = details
	li_cb = CALLBACK(src, PROC_REF(post_login))
	details.post_login_callbacks += li_cb

/datum/unit_test/runtime_nov06_buildmode_relogin/Run()
	var/datum/player_details/details = new /datum/player_details/runtime_nov06_login
	allocated += details
	var/runtimes_before = GLOB.total_runtimes
	for(var/switch_state in list(0, 1, 2))
		var/datum/buildmode/builder = new /datum/buildmode/runtime_nov06_disconnected(details)
		allocated += builder
		builder.switch_state = switch_state
		var/datum/callback/old_callback = builder.li_cb
		old_callback.Invoke()
		TEST_ASSERT(QDELETED(builder), "A reconnect must retire the buildmode belonging to the disconnected client.")
		TEST_ASSERT(!length(details.post_login_callbacks), "Retiring disconnected buildmode must remove its callback from the persistent login registry.")
		TEST_ASSERT(QDELETED(old_callback), "Retiring buildmode must release its login callback.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Disconnected buildmode cleanup must work with either switch menu open.")

/datum/unit_test/runtime_nov06_buildmode_preview_cleanup/Run()
	var/datum/player_details/details = new /datum/player_details/runtime_nov06_login
	allocated += details
	var/datum/buildmode/builder = new /datum/buildmode/runtime_nov06_disconnected(details)
	allocated += builder
	qdel(builder.mode)
	var/datum/buildmode_mode/area_edit/area_mode = new(builder)
	builder.mode = area_mode
	area_mode.storedarea = get_area(run_loc_floor_bottom_left)
	area_mode.areaimage.loc = area_mode.storedarea
	var/image/area_image = area_mode.areaimage
	var/image/preview_image = image('icons/turf/overlays.dmi', run_loc_floor_bottom_left, "greenOverlay")
	area_mode.preview += preview_image
	var/datum/callback/old_callback = builder.li_cb
	var/runtimes_before = GLOB.total_runtimes
	old_callback.Invoke()
	TEST_ASSERT(QDELETED(builder), "A disconnected area editor must also be retired.")
	TEST_ASSERT(QDELETED(area_mode), "Buildmode cleanup must delete the area editor datum.")
	TEST_ASSERT_NULL(area_mode.areaimage, "Area editor cleanup must release its display image.")
	TEST_ASSERT_NULL(area_mode.preview, "Area editor cleanup must release its selected-region images.")
	TEST_ASSERT_NULL(area_mode.BM, "Mode cleanup must release its owning buildmode.")
	TEST_ASSERT(!QDELETED(area_image) && !QDELETED(preview_image), "Buildmode images must never be passed to qdel.")
	TEST_ASSERT(!length(details.post_login_callbacks), "Area editor cleanup must also detach the persistent login callback.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Area editor cleanup after disconnect must not access the missing client or qdel an image.")

/datum/unit_test/runtime_nov06_ghost_noise/Run()
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer)
	var/runtimes_before = GLOB.total_runtimes
	for(var/verb_path in list(/mob/living/carbon/human/verb/emote_peep, /mob/living/carbon/human/verb/emote_hiss))
		world.PushUsr(ghost, CALLBACK(src, PROC_REF(invoke_noise), ghost, verb_path))
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Human noise verbs copied to a ghost must reject its absent tongue without calling a missing helper.")

/datum/unit_test/runtime_nov06_ghost_noise/proc/invoke_noise(mob/user, verb_path)
	call(user, verb_path)()

/obj/effect/proc_holder/spell/invoked/refocusstudies/runtime_nov06
	var/refunds = 0

/obj/effect/proc_holder/spell/invoked/refocusstudies/runtime_nov06/revert_cast(mob/user)
	refunds++

/datum/unit_test/runtime_nov06_refocus_invalid_target/Run()
	var/mob/living/carbon/human/consistent/teacher = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/invoked/refocusstudies/runtime_nov06/spell = allocate(/obj/effect/proc_holder/spell/invoked/refocusstudies/runtime_nov06)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(spell.cast(list(run_loc_floor_bottom_left), teacher), FALSE, "Clicking the floor must reject Refocus Studies before reading skills.")
	TEST_ASSERT_EQUAL(spell.cast(list(), teacher), FALSE, "An empty target list must reject Refocus Studies.")
	var/mob/living/carbon/human/consistent/mindless = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NULL(mindless.mind, "The target fixture must have no mind or sleep advancement.")
	TEST_ASSERT_EQUAL(spell.cast(list(mindless), teacher), FALSE, "A mindless student must not reach lesson selection.")
	TEST_ASSERT_EQUAL(spell.refunds, 3, "Invalid targets must refund the cast exactly once.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Invalid Refocus Studies targets must not read mob or mind fields.")

/// Use a logical owner only until the fake asset clears it; no native client API is called.
/datum/tgui_window/runtime_nov06_disconnect/New()
	id = "runtime-nov06-disconnect"

/datum/asset/runtime_nov06_disconnect
	var/datum/tgui_window/window
	var/disconnect_on_mapping = FALSE
	var/disconnect_on_send = FALSE
	var/send_count = 0

/datum/asset/runtime_nov06_disconnect/New(datum/tgui_window/new_window)
	window = new_window

/datum/asset/runtime_nov06_disconnect/get_url_mappings()
	if(disconnect_on_mapping)
		window.client = null
	return list()

/datum/asset/runtime_nov06_disconnect/send(client)
	send_count++
	if(disconnect_on_send)
		window.client = null

/datum/asset/runtime_nov06_disconnect/Destroy()
	window = null
	return ..()

/datum/unit_test/runtime_nov06_tgui_disconnected_assets/Run()
	var/mob/logical_owner = allocate(/mob)
	var/runtimes_before = GLOB.total_runtimes
	for(var/disconnect_on_mapping in list(FALSE, TRUE))
		var/datum/tgui_window/window = new /datum/tgui_window/runtime_nov06_disconnect
		allocated += window
		// A real client cannot be constructed headlessly. The asset always removes this placeholder before browse/winexists.
		window.vars["client"] = logical_owner
		var/datum/asset/runtime_nov06_disconnect/first_asset = new(window)
		allocated += first_asset
		first_asset.disconnect_on_mapping = disconnect_on_mapping
		first_asset.disconnect_on_send = !disconnect_on_mapping
		var/datum/asset/runtime_nov06_disconnect/second_asset = new(window)
		allocated += second_asset
		window.initialize(assets = list(first_asset, second_asset))
		TEST_ASSERT_NULL(window.client, "The fixture must disconnect during asset preparation.")
		TEST_ASSERT_EQUAL(window.status, TGUI_WINDOW_CLOSED, "A disconnected window must leave the loading state.")
		TEST_ASSERT_EQUAL(first_asset.send_count, disconnect_on_mapping ? 0 : 1, "Losing the client while preparing mappings must prevent the asset send.")
		TEST_ASSERT_EQUAL(second_asset.send_count, 0, "A later asset must not be sent after the first one disconnects the client.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Losing the client during asset preparation must not reach winexists with a null client.")
