/// Fartravel removes an abandoned body without pulling the mind's player back into the lobby.
/datum/unit_test/upstream_nov07_fartravel_abandoned/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitsyncfartravel")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	body.mind.key = account_key
	var/datum/respawn_state/state = body.register_respawn_body(account_key)
	var/list/lobbies_before = GLOB.new_player_list.Copy()
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(body.admin_fartravel(null), "The upstream fartravel action must remove an abandoned character.")
	TEST_ASSERT(QDELETED(body), "Fartravel must delete the body.")
	TEST_ASSERT(!length(GLOB.new_player_list - lobbies_before), "only_if_present must not create a lobby from a departed mind's key.")
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Explicit admin removal must preserve the custom respawn waiver.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Fartravel must finish cleanup without runtimes.")

/// Removing an old body must not release a more recent death on the same account.
/datum/unit_test/upstream_nov07_fartravel_stale_body/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitsyncfartravelstale")
	var/mob/living/carbon/human/consistent/old_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	old_body.mind.key = account_key
	old_body.register_respawn_body(account_key)
	var/mob/living/carbon/human/consistent/current_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/current_life = current_body.register_respawn_body(account_key)
	current_body.stat = DEAD
	current_body.record_respawn_death()
	var/revision_before = current_life.revision
	var/list/lobbies_before = GLOB.new_player_list.Copy()
	TEST_ASSERT(old_body.admin_fartravel(null), "Fartravel must still remove the old abandoned body.")
	TEST_ASSERT(!QDELETED(current_body), "Removing an old character must preserve the current body.")
	TEST_ASSERT_EQUAL(current_life.revision, revision_before, "Cleanup must not change the newer life.")
	TEST_ASSERT(current_life.get_time_left() > 0, "The newer death must retain its cooldown.")
	TEST_ASSERT(!length(GLOB.new_player_list - lobbies_before), "An old mind key must not be pulled into a new lobby.")

/// Human transformations carry the original body; fartravel must dispose of both safely.
/datum/unit_test/upstream_nov07_fartravel_stored_body/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account_key = accounts.track("unitsyncfartravelstored")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/form = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/life = body.register_respawn_body(account_key)
	body.forceMove(form)
	form.stored_mob = body
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(form.get_real_body(), body, "The fixture must expose the original body through the real transformation API.")
	TEST_ASSERT(form.admin_fartravel(null), "Fartravel must accept a transformed human.")
	TEST_ASSERT(QDELETED(body) && QDELETED(form), "Both the original body and its form must be removed.")
	TEST_ASSERT_NULL(form.stored_mob, "The deleted form must release its stored body.")
	TEST_ASSERT_EQUAL(life.get_time_left(), 0, "Admin departure must waive the original body's life when it still owns the respawn state.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Stored-body cleanup must not produce runtimes.")

/datum/unit_test/upstream_nov07_disconnected_slots
	var/datum/job/previous_job

/datum/unit_test/upstream_nov07_disconnected_slots/Destroy()
	SSjob.name_occupations["Mercenary"] = previous_job
	return ..()

/// The imported SSD panel must display the same dynamic slot limit as latejoin.
/datum/unit_test/upstream_nov07_disconnected_slots/Run()
	previous_job = SSjob.GetJob("Mercenary")
	var/datum/job/roguetown/mercenary/job = new
	allocated += job
	job.total_positions = 80
	job.current_positions = 1
	SSjob.name_occupations["Mercenary"] = job
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.job = "Mercenary"
	body.key = "unitsyncssd[REF(src)]"
	body.last_logout_time = world.time - 1
	TEST_ASSERT(body.is_disconnected_player(), "The fixture must represent an offline player still assigned to a body.")
	var/list/data = GLOB.disconnected_players_panel.ui_data(null)
	var/list/row
	for(var/list/candidate as anything in data["players"])
		if(candidate["ref"] == REF(body))
			row = candidate
			break
	TEST_ASSERT_NOTNULL(row, "The disconnected player must appear in the imported admin panel.")
	TEST_ASSERT_EQUAL(row["slots_total"], job.get_position_limit(TRUE), "The panel must show the effective latejoin limit, including population scaling.")
	TEST_ASSERT_EQUAL(row["slots_open"], job.get_position_limit(TRUE) - 1, "The panel must subtract occupancy from that same limit.")
