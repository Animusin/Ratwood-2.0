/// Substitute only the connected client, subscription service and modal response.
/mob/dead/new_player/respawn_bypass_test
	var/datum/respawn_bypass_fixture/fixture
	var/connected = TRUE
	var/answer = TRUE
	var/prompt_calls = 0
	var/price_checks = 0
	var/unavailable_price_check = 0
	var/subscription = "none"
	var/confirmation_action
	var/reentry_result

/mob/dead/new_player/respawn_bypass_test/get_respawn_account_ckey()
	return fixture?.account_key

/mob/dead/new_player/respawn_bypass_test/has_respawn_bypass_connection(client/player, account_ckey)
	return !QDELETED(src) && connected && fixture?.account_key == account_ckey

/mob/dead/new_player/respawn_bypass_test/get_respawn_bypass_cost(client/player, refresh = FALSE)
	price_checks++
	if(price_checks == unavailable_price_check)
		return null
	return donation_tier_grants_respawn_bypass(subscription) ? 0 : RESPAWN_BYPASS_COST

/mob/dead/new_player/respawn_bypass_test/confirm_respawn_bypass(cost)
	prompt_calls++
	switch(confirmation_action)
		if("burial")
			fixture.body.clear_respawn_cooldown_for_burial()
		if("expiry")
			fixture.state.death_time = world.time - RESPAWNTIME
		if("revive", "new_death")
			fixture.body.player_present = TRUE
			fixture.body.stat = CONSCIOUS
			fixture.body.record_respawn_revival()
			if(confirmation_action == "new_death")
				fixture.body.stat = DEAD
				fixture.body.record_respawn_death()
		if("npc_revive")
			fixture.body.become_alive()
		if("new_body")
			var/mob/living/carbon/human/consistent/new_body = new(get_turf(fixture.body))
			fixture.extra_bodies += new_body
			var/datum/respawn_state/new_state = new_body.register_respawn_body(fixture.account_key)
			fixture.extra_states += new_state
			new_body.stat = DEAD
			new_state.start_death(world.time)
		if("disconnect")
			connected = FALSE
		if("reenter")
			reentry_result = fixture.other_lobby.check_respawn_cooldown()
		if("balance_spent")
			SStriumphs.triumph_amount_cache[fixture.account_key] = RESPAWN_BYPASS_COST - 1
		if("downgrade")
			subscription = "scientist"
		if("upgrade")
			subscription = "hos"
	return answer

/// Use the real Triumph debit, restoring both its account cache and save files afterwards.
/datum/respawn_bypass_fixture
	var/account_key
	var/mob/living/carbon/human/consistent/respawn_test_player/body
	var/mob/dead/new_player/respawn_bypass_test/lobby
	var/mob/dead/new_player/respawn_bypass_test/other_lobby
	var/datum/respawn_state/state
	var/list/extra_bodies = list()
	var/list/extra_states = list()
	var/datum/respawn_state/saved_state
	var/had_balance
	var/saved_balance
	var/save_path
	var/backup_path
	var/save_existed
	var/backup_existed
	var/saved_file
	var/saved_backup

/datum/respawn_bypass_fixture/New(turf/location)
	account_key = ckey("unitrespawnbypass[REF(src)]")
	saved_state = GLOB.respawn_states[account_key]
	had_balance = (account_key in SStriumphs.triumph_amount_cache)
	saved_balance = SStriumphs.triumph_amount_cache[account_key]
	save_path = "data/player_saves/[account_key[1]]/[account_key]/triumphs.json"
	backup_path = "data/player_saves/[account_key[1]]/[account_key]/triumphs.backup.json"
	save_existed = fexists(save_path)
	backup_existed = fexists(backup_path)
	if(save_existed)
		saved_file = file2text(save_path)
	if(backup_existed)
		saved_backup = file2text(backup_path)
	SStriumphs.triumph_amount_cache[account_key] = 100
	body = new(location)
	state = body.register_respawn_body(account_key)
	body.stat = DEAD
	state.start_death(world.time)
	lobby = new
	lobby.fixture = src
	other_lobby = new
	other_lobby.fixture = src

/datum/respawn_bypass_fixture/Destroy()
	GLOB.respawn_states -= account_key
	QDEL_NULL(lobby)
	QDEL_NULL(other_lobby)
	QDEL_NULL(body)
	QDEL_LIST(extra_bodies)
	QDEL_NULL(state)
	QDEL_LIST(extra_states)
	if(saved_state)
		GLOB.respawn_states[account_key] = saved_state
	if(had_balance)
		SStriumphs.triumph_amount_cache[account_key] = saved_balance
	else
		SStriumphs.triumph_amount_cache -= account_key
	fdel(save_path)
	fdel(backup_path)
	if(save_existed)
		text2file(saved_file, save_path)
	if(backup_existed)
		text2file(saved_backup, backup_path)
	return ..()

/datum/unit_test/respawn_bypass_paid_once/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	fixture.lobby.confirmation_action = "reenter"
	TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "Accepting a paid bypass must release the current cooldown.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 80, "The real debit must charge exactly 20 Triumphs.")
	TEST_ASSERT(!fixture.lobby.reentry_result, "Another lobby request must not enter an already open account confirmation.")
	TEST_ASSERT_EQUAL(fixture.other_lobby.prompt_calls, 0, "Concurrent requests must not open a second payment prompt.")
	TEST_ASSERT(fixture.state.waived, "The payment must waive this life rather than only the current spawn attempt.")
	TEST_ASSERT(!fixture.state.bypass_in_progress, "A completed purchase must release its confirmation lock.")
	TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "Retrying entry after payment must remain allowed.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 80, "Retrying entry must never charge a second time.")
	TEST_ASSERT_EQUAL(fixture.lobby.prompt_calls, 1, "An already waived cooldown must not ask for payment again.")

/datum/unit_test/respawn_wait_display/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	fixture.state.death_time = world.time - 5 MINUTES
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "25 minutes remaining.", "The display must use time since the body's death.")
	for(var/cost in list(0, RESPAWN_BYPASS_COST))
		var/message = fixture.lobby.get_respawn_bypass_message(cost)
		TEST_ASSERT(findtext(message, "25 minutes remaining."), "Both free and paid confirmations must show the remaining wait.")
		TEST_ASSERT(findtext(message, cost ? "20 Triumphs" : "for free"), "The countdown must preserve the bypass price explanation.")
	fixture.state.death_time -= 1 MINUTES
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "24 minutes remaining.", "Refreshing the display must not reuse the previous countdown.")
	fixture.state.death_time = world.time - RESPAWNTIME + 1
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "1 second remaining.", "A positive fraction of a second must not claim respawn is ready.")
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(FALSE), "Reading the countdown must not waive the remaining cooldown.")
	fixture.state.death_time = world.time - RESPAWNTIME
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "Ready.", "An expired wait must display readiness.")
	fixture.state.death_time = world.time
	fixture.body.clear_respawn_cooldown_for_burial()
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "Ready.", "Burial must immediately update the displayed state.")
	fixture.body.stat = CONSCIOUS
	fixture.body.player_present = TRUE
	fixture.body.record_respawn_revival()
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "Previous body is still alive; waiting starts when it dies.", "A revived body must not display an old death's countdown.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "Reading status and confirmation text must not spend Triumphs.")

/datum/unit_test/respawn_bypass_refusal_and_eligibility/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(FALSE), "Background eligibility must respect an active cooldown.")
	TEST_ASSERT_EQUAL(fixture.lobby.prompt_calls, 0, "Background eligibility must never show a payment dialog.")
	fixture.lobby.answer = FALSE
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "Declining or closing the confirmation must preserve the cooldown.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "Declining must spend no Triumphs.")
	TEST_ASSERT(!fixture.state.waived && !fixture.state.bypass_in_progress, "Declining must leave the cooldown active and release the prompt lock.")
	fixture.body.stat = CONSCIOUS
	fixture.body.player_present = TRUE
	fixture.body.record_respawn_revival()
	fixture.lobby.answer = TRUE
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "A living body must not be abandoned by purchasing a timed-cooldown bypass.")
	TEST_ASSERT_EQUAL(fixture.lobby.prompt_calls, 1, "A living body must not receive another payment dialog.")

/datum/unit_test/respawn_bypass_funds/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	SStriumphs.triumph_amount_cache[fixture.account_key] = 19
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "19 Triumphs must be insufficient for a 20-Triumph bypass.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 19, "An insufficient balance must remain unchanged.")
	SStriumphs.triumph_amount_cache[fixture.account_key] = 100
	fixture.lobby.confirmation_action = "balance_spent"
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "The balance must be checked again after the modal confirmation.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 19, "A concurrent purchase must not cause an overdraft or partial payment.")
	fixture.lobby.confirmation_action = null
	SStriumphs.triumph_amount_cache[fixture.account_key] = 20
	TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "An exact balance of 20 Triumphs must buy the bypass.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 0, "An exact payment must leave zero Triumphs.")

/datum/unit_test/respawn_bypass_subscription_tiers/Run()
	for(var/tier in list("none", "cargo", "engineer", "scientist"))
		TEST_ASSERT(!donation_tier_grants_respawn_bypass(tier), "[tier] must not receive the HoS benefit.")
	for(var/tier in list("hos", "captain", "wizard", "cultist", "assistant"))
		var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
		fixture.lobby.subscription = tier
		SStriumphs.triumph_amount_cache[fixture.account_key] = 0
		TEST_ASSERT(donation_tier_grants_respawn_bypass(tier), "[tier] must retain the HoS-or-higher benefit.")
		TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "[tier] must be able to confirm a free bypass without Triumphs.")
		TEST_ASSERT_EQUAL(fixture.lobby.prompt_calls, 1, "A free bypass must still respect the confirmation menu.")
		TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 0, "A subscriber must not be charged.")
		qdel(fixture)

/datum/unit_test/respawn_bypass_subscription_changes/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	fixture.lobby.subscription = "hos"
	fixture.lobby.confirmation_action = "downgrade"
	TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "A free confirmation cannot authorize a paid bypass after a downgrade.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "Changing from free to paid must not silently debit Triumphs.")
	fixture.lobby.confirmation_action = "upgrade"
	TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "An upgrade during a paid confirmation may grant the now-free benefit.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "An upgraded subscriber must not pay the originally quoted price.")
	for(var/failed_check in list(1, 2))
		var/datum/respawn_bypass_fixture/unavailable = allocate(/datum/respawn_bypass_fixture)
		unavailable.lobby.unavailable_price_check = failed_check
		TEST_ASSERT(!unavailable.lobby.check_respawn_cooldown(), "Subscription failure before or after the dialog must not authorize payment.")
		TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(unavailable.account_key), 100, "Subscription lookup failure must not charge a possible subscriber.")
		TEST_ASSERT(!unavailable.state.bypass_in_progress, "A failed subscription lookup must release the prompt lock.")
		qdel(unavailable)

/datum/unit_test/respawn_bypass_cleared_during_confirmation/Run()
	for(var/action in list("burial", "expiry"))
		var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
		fixture.lobby.confirmation_action = action
		TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "[action] during the dialog must release entry without needing a purchase.")
		TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "[action] during the dialog must spend no Triumphs.")
		qdel(fixture)

/datum/unit_test/respawn_bypass_stale_confirmation/Run()
	for(var/action in list("revive", "new_death", "new_body", "disconnect"))
		var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
		fixture.lobby.confirmation_action = action
		TEST_ASSERT(!fixture.lobby.check_respawn_cooldown(), "[action] must invalidate the old confirmation.")
		TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 100, "[action] during the dialog must spend no Triumphs.")
		TEST_ASSERT(!fixture.state.bypass_in_progress, "Rejecting a stale confirmation must release the old prompt lock.")
		qdel(fixture)

/// An NPC rise during the payment dialog must keep the same death and permit the quoted bypass.
/datum/unit_test/respawn_bypass_unplayed_revival/Run()
	var/datum/respawn_bypass_fixture/fixture = allocate(/datum/respawn_bypass_fixture)
	fixture.state.death_time = world.time - 10 MINUTES
	var/first_death = fixture.state.death_time
	fixture.lobby.confirmation_action = "npc_revive"
	TEST_ASSERT(fixture.lobby.check_respawn_cooldown(), "An NPC revival must not invalidate the player's existing timed cooldown.")
	TEST_ASSERT(fixture.body.stat != DEAD, "The original body must actually rise during confirmation.")
	TEST_ASSERT_EQUAL(fixture.state.death_time, first_death, "Paying after an NPC revival must still refer to the first death.")
	TEST_ASSERT_EQUAL(SStriumphs.get_triumphs(fixture.account_key), 80, "The confirmed bypass must still cost exactly 20 Triumphs.")
	TEST_ASSERT_EQUAL(get_respawn_status_text(fixture.account_key), "Ready.", "An unplayed revived body must not block a waived cooldown.")
	fixture.body.player_present = TRUE
	fixture.body.register_respawn_body(fixture.account_key)
	TEST_ASSERT_EQUAL(fixture.state.get_time_left(), -1, "Actually returning to the revived body must begin a new life, even after a paid waiver.")
