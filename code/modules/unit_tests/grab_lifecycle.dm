/datum/unit_test/grab_lifecycle/Run()
	var/turf/first_turf = run_loc_bottom_left
	var/turf/second_turf = get_step(first_turf, EAST)
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent, first_turf)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, second_turf)

	grabber.active_hand_index = 1
	var/grab_intent_index = grabber.base_intents.Find(INTENT_GRAB)
	TEST_ASSERT(grab_intent_index, "The test mob should have an unarmed grab intent.")
	grabber.rog_intent_change(grab_intent_index)
	var/obj/item/offhand_item = allocate(/obj/item, first_turf)
	TEST_ASSERT(grabber.put_in_hand(offhand_item, 2), "The setup item should fit in the inactive hand.")
	grabber.start_pulling(target)
	var/obj/item/grabbing/intent_grab = grabber.r_grab
	TEST_ASSERT_NOTNULL(intent_grab, "Starting a pull should create a grab in the active hand.")
	TEST_ASSERT(grabber.dropItemToGround(intent_grab), "The grab should be droppable.")
	TEST_ASSERT_EQUAL(grabber.a_intent.type, INTENT_GRAB, "Dropping a grab should restore the active hand's unarmed intent.")

	grabber.dropItemToGround(offhand_item)
	grabber.start_pulling(target)
	var/obj/item/grabbing/first_grab = grabber.r_grab
	grabber.start_pulling(target)
	var/obj/item/grabbing/second_grab = grabber.l_grab
	TEST_ASSERT_NOTNULL(first_grab, "Starting a pull should create the first grab.")
	TEST_ASSERT_NOTNULL(second_grab, "Grabbing the same target again should create a second grab.")

	qdel(first_grab)
	TEST_ASSERT_EQUAL(grabber.pulling, target, "Destroying one of two grabs should preserve the pull.")
	TEST_ASSERT_EQUAL(target.pulledby, grabber, "Destroying one of two grabs should preserve the target's puller.")

	qdel(second_grab)
	TEST_ASSERT_NULL(grabber.pulling, "Destroying the last grab should stop the pull.")
	TEST_ASSERT_NULL(target.pulledby, "Destroying the last grab should clear the target's puller.")

	var/turf/contested_target_turf = get_step(first_turf, NORTH)
	var/turf/primary_grabber_turf = get_step(contested_target_turf, EAST)
	var/turf/pinning_grabber_turf = get_step(contested_target_turf, NORTH)
	var/mob/living/carbon/human/primary_grabber = allocate(/mob/living/carbon/human/consistent, primary_grabber_turf)
	var/mob/living/carbon/human/pinning_grabber = allocate(/mob/living/carbon/human/consistent, pinning_grabber_turf)
	var/mob/living/carbon/human/contested_target = allocate(/mob/living/carbon/human/consistent, contested_target_turf)

	primary_grabber.start_pulling(contested_target)
	pinning_grabber.start_pulling(contested_target)
	var/obj/item/grabbing/pinning_grab = pinning_grabber.r_grab
	TEST_ASSERT_NOTNULL(pinning_grab, "The pinning player should have a grab on the contested target.")
	TEST_ASSERT_EQUAL(contested_target.pulledby, primary_grabber, "A second grabber should not replace the active puller.")

	qdel(pinning_grab)
	TEST_ASSERT_NULL(pinning_grabber.pulling, "Interrupting the pin should clear the pinning player's pull.")
	TEST_ASSERT_EQUAL(primary_grabber.pulling, contested_target, "Interrupting the pin should preserve the other player's pull.")
	TEST_ASSERT_EQUAL(contested_target.pulledby, primary_grabber, "Interrupting the pin should preserve the contested target's active puller.")

	primary_grabber.cmode = TRUE
	pinning_grabber.start_pulling(contested_target)
	var/challenger_stamina_before = pinning_grabber.stamina
	var/defender_stamina_before = primary_grabber.stamina
	pinning_grabber.contest_target_grabbers(contested_target, get_turf(pinning_grabber), force_contest = TRUE)
	TEST_ASSERT(pinning_grabber.stamina > challenger_stamina_before, "Contesting a combat-mode grip should cost the challenger stamina.")
	TEST_ASSERT(primary_grabber.stamina > defender_stamina_before, "Contesting a combat-mode grip should cost the defender stamina.")
	TEST_ASSERT(pinning_grabber.next_move >= world.time + CLICK_CD_RESIST, "Contesting a combat-mode grip should apply click cooldown to the challenger.")
	TEST_ASSERT(primary_grabber.next_move >= world.time + CLICK_CD_RESIST, "Contesting a combat-mode grip should apply click cooldown to the defender.")
	var/mutable_appearance/challenger_indicator = pinning_grabber.overlays_standing[OBJ_LAYER]
	var/mutable_appearance/defender_indicator = primary_grabber.overlays_standing[OBJ_LAYER]
	TEST_ASSERT_EQUAL(challenger_indicator?.icon_state, "clashtwo", "Contesting a combat-mode grip should show a struggle indicator over the challenger.")
	TEST_ASSERT_EQUAL(defender_indicator?.icon_state, "clashtwo", "Contesting a combat-mode grip should show a struggle indicator over the defender.")
