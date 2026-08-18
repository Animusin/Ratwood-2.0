/datum/unit_test/grab_oiled_failure/Run()
	var/turf/grabber_turf = run_loc_bottom_left
	var/turf/target_turf = get_step(grabber_turf, EAST)
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent, grabber_turf)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, target_turf)
	target.apply_status_effect(/datum/status_effect/buff/oiled)

	for(var/attempt in 1 to 100)
		if(grabber.start_pulling(target))
			grabber.stop_pulling()
			continue
		TEST_ASSERT_NULL(grabber.pulling, "A failed oily grab must not leave the attacker pulling the target.")
		TEST_ASSERT_NULL(target.pulledby, "A failed oily grab must not leave the target assigned to the attacker.")
		return

	TEST_FAIL("The oily grab did not fail in 100 attempts.")

/datum/unit_test/grab_cancelled/proc/cancel_grab(mob/living/source, mob/living/target, zone)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_GRAB_ATTACK

/datum/unit_test/grab_cancelled/Run()
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent, run_loc_bottom_left)
	RegisterSignal(grabber, COMSIG_LIVING_GRAB_SELF_ATTEMPT, PROC_REF(cancel_grab))

	TEST_ASSERT(!grabber.start_pulling(grabber), "The signal handler should cancel the self-grab.")
	TEST_ASSERT_NULL(grabber.r_grab, "A cancelled grab must not leave a grab item in the right hand.")
	TEST_ASSERT_NULL(grabber.l_grab, "A cancelled grab must not leave a grab item in the left hand.")

/datum/unit_test/grab_forced_stop_mouth/Run()
	var/turf/grabber_turf = run_loc_bottom_left
	var/turf/target_turf = get_step(grabber_turf, EAST)
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent, grabber_turf)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, target_turf)

	grabber.start_pulling(target)
	var/obj/item/grabbing/bite/bite = allocate(/obj/item/grabbing/bite, grabber_turf)
	grabber.equip_to_slot_or_del(bite, SLOT_MOUTH)
	TEST_ASSERT_EQUAL(grabber.mouth, bite, "The bite grab should be equipped in the mouth for the test.")
	bite.grabbed = target
	bite.grabbee = grabber
	LAZYADD(target.grabbedby, bite)

	grabber.stop_pulling(TRUE)
	TEST_ASSERT_NULL(grabber.pulling, "A forced stop must clear the pull.")
	TEST_ASSERT_NULL(target.pulledby, "A forced stop must clear the target's puller.")
	TEST_ASSERT_NULL(grabber.mouth, "A forced stop must remove a mouth grab on the same target.")

/datum/unit_test/grab_garrote_target_switch/Run()
	var/turf/grabber_turf = get_step(get_step(run_loc_bottom_left, EAST), NORTH)
	var/turf/first_target_turf = get_step(grabber_turf, EAST)
	var/turf/second_target_turf = get_step(grabber_turf, NORTH)
	var/turf/third_target_turf = get_step(grabber_turf, WEST)
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent, grabber_turf)
	var/mob/living/carbon/human/first_target = allocate(/mob/living/carbon/human/consistent, first_target_turf)
	var/mob/living/carbon/human/second_target = allocate(/mob/living/carbon/human/consistent, second_target_turf)
	var/mob/living/carbon/human/third_target = allocate(/mob/living/carbon/human/consistent, third_target_turf)

	grabber.start_pulling(first_target)
	var/obj/item/grabbing/first_grab = grabber.r_grab
	var/obj/item/inqarticles/garrote/garrote = allocate(/obj/item/inqarticles/garrote, grabber_turf)
	TEST_ASSERT(grabber.put_in_hand(garrote, 2), "The garrote should fit in the inactive hand.")
	grabber.active_hand_index = 2
	qdel(grabber.used_intent)
	grabber.used_intent = new /datum/intent/garrote/grab
	grabber.zone_selected = BODY_ZONE_PRECISE_NECK

	garrote.afterattack(second_target, grabber, TRUE, null)
	TEST_ASSERT(QDELETED(first_grab), "Switching to a garrote target must destroy the old grab.")
	TEST_ASSERT_NULL(first_target.pulledby, "Switching to a garrote target must release the old target.")
	TEST_ASSERT_EQUAL(grabber.pulling, second_target, "The garrote should pull its new target.")
	TEST_ASSERT_EQUAL(second_target.pulledby, grabber, "The garrote's new target should reference its puller.")
	TEST_ASSERT_EQUAL(garrote.currentgrab, grabber.r_grab, "The garrote should track the grab created for its new target.")
	TEST_ASSERT_EQUAL(garrote.victim, second_target, "The garrote should track the first garroted target before switching.")

	qdel(grabber.used_intent)
	grabber.used_intent = new /datum/intent/garrote/grab
	garrote.afterattack(third_target, grabber, TRUE, null)
	TEST_ASSERT_EQUAL(garrote.victim, third_target, "The garrote should track the replacement victim after switching.")
	TEST_ASSERT(!HAS_TRAIT(second_target, TRAIT_GARROTED), "Switching garrote targets must remove the old target's garroted trait.")
	TEST_ASSERT_EQUAL(grabber.pulling, third_target, "The garrote should pull the replacement target.")
	TEST_ASSERT_EQUAL(third_target.pulledby, grabber, "The replacement target should reference the garrote user.")
	TEST_ASSERT_EQUAL(garrote.currentgrab, grabber.r_grab, "The garrote should track the replacement grab.")
