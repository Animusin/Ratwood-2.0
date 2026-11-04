/// Restore account-global state even if a test assertion returns early.
/datum/respawn_test_accounts
	var/list/previous_states = list()
	var/list/tracked_accounts = list()
	var/list/existing_accounts = list()

/datum/respawn_test_accounts/New(turf/unused_location)
	return

/datum/respawn_test_accounts/proc/track(account_key)
	var/player_ckey = ckey(account_key)
	if(!(player_ckey in tracked_accounts))
		tracked_accounts += player_ckey
		if(player_ckey in GLOB.respawn_states)
			existing_accounts += player_ckey
		previous_states[player_ckey] = GLOB.respawn_states[player_ckey]
	return player_ckey

/datum/respawn_test_accounts/Destroy()
	for(var/player_ckey in tracked_accounts)
		if(player_ckey in existing_accounts)
			GLOB.respawn_states[player_ckey] = previous_states[player_ckey]
		else
			GLOB.respawn_states -= player_ckey
	previous_states = null
	tracked_accounts = null
	existing_accounts = null
	return ..()

/// Exercise the updatehealth callback inside become_alive, including its ordering with death().
/mob/living/respawn_test_redies
	var/die_on_health_update = FALSE

/mob/living/respawn_test_redies/updatehealth()
	. = ..()
	if(die_on_health_update && stat != DEAD)
		die_on_health_update = FALSE
		death(FALSE, TRUE)

/datum/unit_test/respawn_body_death/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_body_death")
	var/mob/living/body = allocate(/mob/living)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	TEST_ASSERT_EQUAL(get_respawn_time_left_for_ckey(account), -1, "A living body must not start a cooldown")

	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.death_time, world.time, "Death must start the account's timer without a client or ghost")
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "A new death must require thirty minutes")

	state.death_time = world.time - 5 MINUTES
	var/first_death = state.death_time
	var/first_revision = state.revision
	body.death(FALSE, TRUE)
	body.register_respawn_body(account)
	TEST_ASSERT_EQUAL(state.death_time, first_death, "Repeated death and reconnect must preserve the original death time")
	TEST_ASSERT_EQUAL(state.revision, first_revision, "An unchanged dead body must not become a different life")
	TEST_ASSERT_EQUAL(get_respawn_time_left_for_ckey(account), 25 MINUTES, "Opening respawn later must count the time already spent dead")

/datum/unit_test/respawn_revival_second_life/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_revival")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.death(FALSE, TRUE)
	state.death_time = world.time - 20 MINUTES
	body.clear_respawn_cooldown_for_burial()
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Burial must clear the first death's cooldown")

	TEST_ASSERT(body.revive(full_heal = TRUE, admin_revive = TRUE), "The corpse should successfully revive")
	TEST_ASSERT_NULL(state.death_time, "Revival must end the previous death")
	TEST_ASSERT(!state.waived, "The previous burial must not waive the new life")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "A revived body must block respawn while alive")
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.death_time, world.time, "A revived body's next death starts a new timer")
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "The second death must not inherit the first death's elapsed time")

/datum/unit_test/respawn_immediate_redeath/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_immediate_redeath")
	var/mob/living/respawn_test_redies/body = allocate(/mob/living/respawn_test_redies)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.death(FALSE, TRUE)
	state.death_time = world.time - 20 MINUTES
	body.die_on_health_update = TRUE
	body.become_alive()

	TEST_ASSERT_EQUAL(body.stat, DEAD, "The fixture must die during become_alive's health update")
	TEST_ASSERT_EQUAL(state.death_time, world.time, "Immediate re-death must overwrite the previous life's timestamp")
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "The post-revival death must not leave the account marked alive")

/datum/unit_test/respawn_zombie_second_life/Run()
	var/runtimes_before = GLOB.total_runtimes
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_zombie")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.death(FALSE, TRUE)
	state.death_time = world.time - 20 MINUTES
	body.mind_initialize()
	body.mind.add_antag_datum(/datum/antagonist/zombie)
	body.infected = TRUE
	wake_zombie(body)
	TEST_ASSERT(body.stat != DEAD, "The infected corpse must rise through the real deadite wake path")
	TEST_ASSERT_NULL(state.death_time, "Rising as a zombie must end the first death")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "A risen zombie must block respawn while alive")

	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "The zombie's death must start a fresh thirty minutes")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The complete deadite rise/death scenario must not produce runtimes")

/datum/unit_test/respawn_old_corpse_isolation/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_old_corpse")
	var/mob/living/old_body = allocate(/mob/living)
	old_body.register_respawn_body(account)
	old_body.death(FALSE, TRUE)
	old_body.clear_respawn_cooldown_for_burial()
	var/mob/living/new_body = allocate(/mob/living)
	var/datum/respawn_state/new_state = new_body.register_respawn_body(account)
	new_body.death(FALSE, TRUE)
	new_state.death_time = world.time - 7 MINUTES
	var/current_death = new_state.death_time
	var/current_revision = new_state.revision

	old_body.become_alive()
	old_body.death(FALSE, TRUE)
	old_body.clear_respawn_cooldown_for_burial()
	qdel(old_body)
	TEST_ASSERT(GLOB.respawn_states[account] == new_state, "Events on an old corpse must not replace the new character")
	TEST_ASSERT_EQUAL(new_state.death_time, current_death, "Old corpse revival, death and burial must not change the new death time")
	TEST_ASSERT_EQUAL(new_state.revision, current_revision, "An old corpse must not invalidate the new character's state")
	TEST_ASSERT(!new_state.waived, "Burying an old corpse must not grant the new character free respawn")

/datum/unit_test/respawn_mind_transfer/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_mind_transfer")
	var/mob/living/body = allocate(/mob/living)
	var/mob/living/new_body = allocate(/mob/living)
	body.mind_initialize()
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.mind.transfer_to(new_body)

	TEST_ASSERT(state.is_current_body(new_body), "An offline mind transfer must move the respawn association before Login")
	TEST_ASSERT(!state.is_current_body(body), "The discarded shell must lose authority")
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "Death of a discarded shell must not start the new body's timer")
	new_body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "Death of the transformed body must start the timer")

/datum/unit_test/respawn_shapeshift_restore/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_shapeshift")
	var/mob/living/body = allocate(/mob/living)
	var/mob/living/form = allocate(/mob/living)
	body.mind_initialize()
	var/datum/respawn_state/state = body.register_respawn_body(account)
	var/obj/shapeshift_holder/holder = allocate(/obj/shapeshift_holder, form, null, body)
	TEST_ASSERT(state.is_current_body(form), "Entering a shapeshift must follow the controlled form")

	holder.restore()
	TEST_ASSERT(state.is_current_body(body), "Reverting must restore the original body's authority")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "Deleting the replaced form during restoration must not count as death")
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "The restored body must still start a cooldown on death")

/datum/unit_test/respawn_underworld_spirit/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_spirit")
	var/mob/living/body = allocate(/mob/living)
	var/mob/living/carbon/spirit/spirit = allocate(/mob/living/carbon/spirit)
	body.mind_initialize()
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.mind.transfer_to(spirit)
	TEST_ASSERT_NULL(body.mind, "The test must leave the original body without its mind")
	TEST_ASSERT_NULL(spirit.register_respawn_body(account), "An underworld spirit must not become the tracked physical body")
	spirit.death(FALSE, TRUE)
	TEST_ASSERT(state.is_current_body(body), "The original body must remain authoritative after entering the underworld")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "A spirit's death must not start the physical body's timer")

	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "The mindless, disconnected original body must still record its death")

/datum/unit_test/respawn_removed_brain/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_brain")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/respawn_state/state = body.register_respawn_body(account)
	body.death(FALSE, TRUE)
	state.death_time = world.time - 5 MINUTES
	var/first_death = state.death_time
	var/obj/item/organ/brain/brain = body.getorganslot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT_NOTNULL(brain, "The fixture needs its original brain")
	allocated += brain
	brain.Remove(body)
	TEST_ASSERT(brain.brainmob?.mind, "Brain removal must really move the character's mind out of its body")
	TEST_ASSERT_NULL(brain.brainmob.register_respawn_body(account), "A removed brain must not replace the dead physical body")
	TEST_ASSERT(state.is_current_body(body), "The corpse must remain the respawn authority after brain removal")
	TEST_ASSERT_EQUAL(state.death_time, first_death, "The brain's default death time must not replace the real death time")
	TEST_ASSERT(pacify_corpse(brain.brainmob, null, 0), "Funeral rites for the extracted brain must release the original body's cooldown")
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Funeral rites for the brain must reach the physical body's state")
	TEST_ASSERT(body.clear_respawn_cooldown_for_burial(), "The brainless corpse must still qualify for burial")

	brain.Insert(body)
	TEST_ASSERT_NOTNULL(body.mind, "Reinserting the original brain must return the mind")
	TEST_ASSERT(state.is_current_body(body), "Reinsertion must retain the original body's association")
	TEST_ASSERT_EQUAL(state.death_time, first_death, "Brain reinsertion must not restart the corpse's timer")
	TEST_ASSERT_EQUAL(state.get_time_left(), 0, "Brain reinsertion must preserve a burial waiver")
	TEST_ASSERT(body.revive(full_heal = TRUE, admin_revive = TRUE), "The original body should revive after brain reinsertion")
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "Death after revival must start a new timer and clear the old burial waiver")

	// Admin healing regenerates organs, so retrieve the replacement instead of removing the deleted original.
	brain = body.getorganslot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT_NOTNULL(brain, "Revival must leave a current brain to extract")
	TEST_ASSERT(!QDELETED(brain) && brain.owner == body, "The second extraction must use the body's current, intact brain")
	allocated |= brain
	brain.Remove(body)
	TEST_ASSERT(brain.brainmob?.mind, "The brain must again carry the previous character's mind")
	var/mob/living/new_body = allocate(/mob/living)
	var/datum/respawn_state/new_state = new_body.register_respawn_body(account)
	new_body.death(FALSE, TRUE)
	new_state.death_time = world.time - 2 MINUTES
	TEST_ASSERT(!pacify_corpse(brain.brainmob, null, 0), "Funeral rites for an old brain must not release a newer character")
	TEST_ASSERT_EQUAL(new_state.get_time_left(), 28 MINUTES, "The new character's timer must survive funeral rites for an old brain")

/datum/unit_test/respawn_projected_vessel/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_projection")
	var/mob/living/body = allocate(/mob/living)
	var/mob/living/vessel = allocate(/mob/living)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	var/datum/action/cooldown/spell/conjure_projection/projection = allocate(/datum/action/cooldown/spell/conjure_projection)
	projection.begin_projection(body, vessel)
	TEST_ASSERT(vessel.respawn_body_override?.resolve() == body, "Projection must mark the temporary vessel before its Login")
	TEST_ASSERT_NULL(vessel.register_respawn_body(account), "The projection vessel must not replace the true body")
	vessel.death(FALSE, TRUE)
	TEST_ASSERT(state.is_current_body(body), "A slain vessel must leave the original body tracked")
	TEST_ASSERT_EQUAL(state.get_time_left(), -1, "A slain projected vessel must not start respawn")
	projection.return_to_body("vessel_slain")
	TEST_ASSERT_NULL(vessel.respawn_body_override, "Returning must remove the temporary projection association")

	var/mob/living/second_vessel = allocate(/mob/living)
	projection.begin_projection(body, second_vessel)
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "Death of the true body during projection must start the cooldown")
	projection.return_to_body("body_slain")

/datum/unit_test/respawn_deleted_body/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_deleted_body")
	// Do not allocate(): its tracking list would itself keep the destroyed body referenced.
	var/mob/living/body = new(run_loc_floor_bottom_left)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	qdel(body)
	TEST_ASSERT_EQUAL(state.death_time, world.time, "Deleting a live body without death() must still start the cooldown")
	TEST_ASSERT_EQUAL(state.get_time_left(), 30 MINUTES, "A deleted body must not permanently block respawn")
	TEST_ASSERT_NULL(state.body_ref.resolve(), "The authoritative body reference must not resolve a destroyed body")
	TEST_ASSERT(refcount(body) <= baseline_refs(), "Keeping an account's respawn state must not keep its destroyed body alive")

/datum/unit_test/respawn_death_at_zero/Run()
	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/account = accounts.track("respawn_test_zero_time")
	var/mob/living/body = allocate(/mob/living)
	var/datum/respawn_state/state = body.register_respawn_body(account)
	state.start_death(0)
	body.death(FALSE, TRUE)
	TEST_ASSERT_EQUAL(state.death_time, 0, "A valid zero timestamp must not be mistaken for an unrecorded death")
	TEST_ASSERT_EQUAL(state.get_time_left(), max(30 MINUTES - world.time, 0), "A death at world time zero must count down normally")
