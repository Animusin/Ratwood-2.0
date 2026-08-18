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
