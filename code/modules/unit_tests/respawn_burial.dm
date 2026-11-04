/// Physical burial must release the dead player's account even without a connected ghost.
/datum/unit_test/respawn_burial_containers/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	for(var/container_kind in list("bare", "coffin", "shroud", "nested"))
		var/account_key = accounts.track("unitrespawnburial[container_kind]")
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		var/datum/respawn_state/state = body.register_respawn_body(account_key)
		body.stat = DEAD
		body.record_respawn_death()
		var/obj/structure/closet/dirthole/grave = allocate(/obj/structure/closet/dirthole/grave)
		grave.stage = 4
		var/obj/structure/closet/crate/coffin/coffin
		var/obj/structure/closet/burial_shroud/shroud
		if(container_kind == "coffin" || container_kind == "nested")
			coffin = allocate(/obj/structure/closet/crate/coffin, grave)
		if(container_kind == "shroud" || container_kind == "nested")
			shroud = allocate(/obj/structure/closet/burial_shroud, coffin || grave)
		body.forceMove(shroud || coffin || grave)
		TEST_ASSERT(body in grave.get_interred_mobs(), "The grave must find the body in the [container_kind] burial.")
		TEST_ASSERT(state.get_time_left() > 0, "The [container_kind] body must have a pending cooldown before burial.")
		TEST_ASSERT(grave.close(), "The [container_kind] grave must close successfully.")
		TEST_ASSERT_EQUAL(get_respawn_time_left_for_ckey(account_key), 0, "Closing the [container_kind] grave must release the cooldown.")
		qdel(body)
		qdel(shroud)
		qdel(coffin)
		qdel(grave)

/// Funeral rites also work after the player has disconnected or already left for the lobby.
/datum/unit_test/respawn_burial_without_ghost/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitrespawnburialoffline")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	body.mind.key = account_key
	var/datum/respawn_state/state = body.register_respawn_body(account_key)
	body.stat = DEAD
	body.record_respawn_death()
	TEST_ASSERT(pacify_corpse(body, null, 0), "Rites must release a current corpse without a connected client or ghost.")
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Offline funeral rites must waive the cooldown.")
	var/released_revision = state.revision
	TEST_ASSERT(pacify_corpse(body, null, 0), "Repeating rites for the same corpse must remain safe.")
	TEST_ASSERT_EQUAL(state.revision, released_revision, "Repeated burial must not create another lifecycle transition.")
	body.returntolobby()
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "A lobby attempt after burial must not restart the cooldown.")

/mob/living/carbon/human/consistent/respawn_burial_stale
	var/spirit_lookup_count = 0

/mob/living/carbon/human/consistent/respawn_burial_stale/get_spirit()
	spirit_lookup_count++
	return null

/// A previous body's rites must neither release the new life nor look up its spirit by ckey.
/datum/unit_test/respawn_burial_stale_corpse/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitrespawnburialstale")
	var/mob/living/carbon/human/consistent/respawn_burial_stale/old_body = allocate(/mob/living/carbon/human/consistent/respawn_burial_stale)
	old_body.mind_initialize()
	old_body.mind.key = account_key
	var/datum/respawn_state/old_state = old_body.register_respawn_body(account_key)
	allocated += old_state
	old_body.stat = DEAD
	old_body.record_respawn_death()
	var/mob/living/carbon/human/consistent/new_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/new_state = new_body.register_respawn_body(account_key)
	new_body.stat = DEAD
	new_body.record_respawn_death()
	TEST_ASSERT(!pacify_corpse(old_body, null, 0), "Rites for a previous body's corpse must not release the new life.")
	TEST_ASSERT_EQUAL(old_body.spirit_lookup_count, 0, "A stale corpse must not search for a newer life's spirit by ckey.")
	TEST_ASSERT(new_state.get_time_left() > 0, "A newer life's cooldown must survive rites for the old body.")
	var/obj/structure/closet/dirthole/grave = allocate(/obj/structure/closet/dirthole/grave)
	old_body.forceMove(grave)
	new_body.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(grave.close(), "The old corpse's grave must close.")
	TEST_ASSERT(new_state.get_time_left() > 0, "Physically burying the old body must not release the newer life.")

/// Being buried while alive cannot turn abandoning a living body into immediate respawn.
/datum/unit_test/respawn_burial_living_body/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitrespawnburialalive")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/state = body.register_respawn_body(account_key)
	var/obj/structure/closet/dirthole/grave = allocate(/obj/structure/closet/dirthole/grave)
	body.forceMove(grave)
	TEST_ASSERT(grave.close(), "The grave must close around a living body.")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "Burying a living body must keep respawn blocked until death.")
	TEST_ASSERT(!pacify_corpse(body, null, 0), "Funeral rites must reject a living body.")
	grave.open()
	body.stat = DEAD
	body.record_respawn_death()
	body.forceMove(grave)
	TEST_ASSERT(grave.close(), "The grave must close after the body's death.")
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "A new burial after death must waive the cooldown.")

/// Admin lobby returns release the life, including the death recorded by deleting its body.
/datum/unit_test/respawn_admin_lobby_return/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	for(var/delete_character in list(FALSE, TRUE))
		var/account_key = accounts.track("unitrespawnadminreturn[delete_character]")
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.mind_initialize()
		body.mind.key = account_key
		var/datum/respawn_state/state = body.register_respawn_body(account_key)
		var/list/previous_lobbies = GLOB.new_player_list.Copy()
		var/returned = body.admin_send_back_to_lobby(null, delete_character)
		for(var/mob/dead/new_player/lobby as anything in GLOB.new_player_list - previous_lobbies)
			allocated += lobby
		TEST_ASSERT(returned, "The admin must be able to return an offline account to the lobby.")
		TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Returning to the lobby must release the current life even when its body is deleted.")
		if(delete_character)
			TEST_ASSERT(!isnull(state.death_time), "The test must exercise the death recorded during body deletion.")
		else
			TEST_ASSERT(!QDELETED(body), "The non-deleting admin return must preserve the body.")

/// Admin cleanup of an old character must not waive a later character's cooldown.
/datum/unit_test/respawn_admin_lobby_stale_corpse/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitrespawnadminstale")
	var/mob/living/carbon/human/consistent/old_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	old_body.mind.key = account_key
	old_body.register_respawn_body(account_key)
	old_body.stat = DEAD
	old_body.record_respawn_death()
	var/mob/living/carbon/human/consistent/new_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/new_state = new_body.register_respawn_body(account_key)
	new_body.stat = DEAD
	new_body.record_respawn_death()
	var/current_revision = new_state.revision
	var/list/previous_lobbies = GLOB.new_player_list.Copy()
	var/returned = old_body.admin_send_back_to_lobby(null, TRUE)
	for(var/mob/dead/new_player/lobby as anything in GLOB.new_player_list - previous_lobbies)
		allocated += lobby
	TEST_ASSERT(returned, "The old corpse cleanup must complete.")
	TEST_ASSERT_EQUAL(new_state.revision, current_revision, "Admin cleanup of an old corpse must not modify a newer life.")
	TEST_ASSERT(new_state.get_time_left() > 0, "The newer body's death must still require its own cooldown.")
