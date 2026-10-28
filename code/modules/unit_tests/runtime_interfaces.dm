/datum/unit_test/client_grid_cleanup/Run()
	var/mob/dead/new_player/lobby_mob = allocate(/mob/dead/new_player)
	lobby_mob.forceMove(run_loc_floor_bottom_left)
	var/runtimes_before = GLOB.total_runtimes
	lobby_mob.clear_important_client_contents()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "An interrupted login must not remove grid membership that was never registered.")
	lobby_mob.enable_client_mobs_in_contents()
	TEST_ASSERT(lobby_mob in lobby_mob.important_recursive_contents?[RECURSIVE_CONTENTS_CLIENT_MOBS], "The fixture must register actual client grid membership.")
	lobby_mob.clear_important_client_contents()
	TEST_ASSERT(!(lobby_mob in lobby_mob.important_recursive_contents?[RECURSIVE_CONTENTS_CLIENT_MOBS]), "Logout must remove the registered membership.")
	lobby_mob.clear_important_client_contents()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Repeating cleanup from client destruction must be harmless.")

/// A copied verb or a deleted body must not leave a live fellowship interface behind.
/datum/unit_test/fellowship_ui_lifetime/Run()
	var/runtimes_before = GLOB.total_runtimes
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer)
	var/datum/fellowship_ui/invalid_ui = new(ghost)
	allocated += invalid_ui
	TEST_ASSERT(QDELETED(invalid_ui), "Observers must not create a fellowship UI with an invalid living holder.")
	var/mob/living/holder = allocate(/mob/living)
	var/datum/fellowship_ui/ui = new(holder)
	allocated += ui
	var/list/data = ui.ui_static_data(holder)
	TEST_ASSERT_EQUAL(data["user_name"], holder.real_name, "A living holder must retain the normal fellowship data.")
	TEST_ASSERT_EQUAL(ui.ui_status(ghost, GLOB.always_state), UI_CLOSE, "An interface must not transfer its old body's authority to a ghost.")
	GLOB.fellowship_uis_by_mob[holder] = ui
	qdel(holder)
	TEST_ASSERT(QDELETED(ui), "Deleting the holder must dispose of the interface and its subscriptions.")
	TEST_ASSERT(!(holder in GLOB.fellowship_uis_by_mob), "Deleting the holder must remove the fellowship UI registry entry.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Rejected or deleted fellowship holders must not produce runtimes.")

/// Window polling must terminate before querying a client that no longer exists.
/datum/unit_test/browser_disconnected_user/Run()
	var/mob/living/user = allocate(/mob/living)
	var/datum/browser/browser = new(user, "runtime_disconnected_browser")
	allocated += browser
	var/runtimes_before = GLOB.total_runtimes
	browser.setup_onclose()
	onclose(user, "runtime_disconnected_browser")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A disconnected window owner must not reach winexists or winset.")
	qdel(user)
	TEST_ASSERT_NULL(browser.user, "A deleted browser owner must be released by its deletion signal.")
	browser.setup_onclose()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Already queued window setup must safely stop after deletion.")

/// The handbook must invoke grip methods on instances, including non-gripping results.
/datum/unit_test/anvil_handbook_grips/Run()
	var/mob/living/reader = allocate(/mob/living)
	for(var/recipe_type in list(/datum/anvil_recipe/weapons/steel/katar, /datum/anvil_recipe/weapons/steel/punchdagger))
		var/datum/anvil_recipe/recipe = allocate(recipe_type)
		var/runtimes_before = GLOB.total_runtimes
		var/html = recipe.generate_html(reader)
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Generating [recipe_type] must not call has_altgrip_modes on a type path.")
		TEST_ASSERT(findtext(html, "Requirements"), "The weapon handbook must finish rendering the recipe after its grip section.")
