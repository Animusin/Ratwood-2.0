/// Cancelling an in-progress attack can destroy the item being unequipped.
/mob/living/carbon/human/consistent/unit_test_nov05_inventory
	var/obj/item/consume_on_stop

/mob/living/carbon/human/consistent/unit_test_nov05_inventory/stop_attack(message = FALSE)
	var/obj/item/consumed = consume_on_stop
	consume_on_stop = null
	atkswinging = FALSE
	qdel(consumed)
	return ..()

/obj/item/unit_test_nov05_inventory
	var/drop_calls = 0

/obj/item/unit_test_nov05_inventory/dropped(mob/user, silent = FALSE)
	drop_calls++
	return ..()

/datum/unit_test/runtime_nov05_consumed_unequip/Run()
	var/mob/living/carbon/human/consistent/unit_test_nov05_inventory/user = allocate(/mob/living/carbon/human/consistent/unit_test_nov05_inventory)
	var/obj/item/unit_test_nov05_inventory/item = allocate(/obj/item/unit_test_nov05_inventory)
	TEST_ASSERT(user.put_in_hands(item), "The fixture must start in the user's hand.")
	user.consume_on_stop = item
	user.atkswinging = TRUE
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(user.dropItemToGround(item), "An item consumed during unequip must still free the hand.")
	TEST_ASSERT(QDELETED(item), "Cancelling the attack must consume the item.")
	TEST_ASSERT(!user.is_holding(item), "The consumed item must not remain in a hand.")
	TEST_ASSERT_EQUAL(item.drop_calls, 1, "Destroy must remove inventory effects once, without a second dropped callback.")
	user.dropItemToGround(item)
	TEST_ASSERT_EQUAL(item.drop_calls, 1, "A stale inventory snapshot must not drop the deleted item again.")
	user.temporarilyRemoveItemFromInventory(item, TRUE)
	TEST_ASSERT_EQUAL(item.drop_calls, 1, "A stale no-move removal must not repeat destruction cleanup.")
	var/obj/item/unit_test_nov05_inventory/transfer_item = allocate(/obj/item/unit_test_nov05_inventory)
	TEST_ASSERT(user.put_in_hands(transfer_item), "The transfer fixture must start held.")
	user.consume_on_stop = transfer_item
	user.atkswinging = TRUE
	user.temporarilyRemoveItemFromInventory(transfer_item, TRUE)
	TEST_ASSERT(QDELETED(transfer_item), "The transfer must consume the item while cancelling its attack.")
	TEST_ASSERT_EQUAL(transfer_item.drop_calls, 1, "An outer no-move removal must not repeat nested Destroy cleanup.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Unequip must not move an already deleted item.")

	var/obj/item/unit_test_nov05_inventory/ordinary = allocate(/obj/item/unit_test_nov05_inventory)
	TEST_ASSERT(user.put_in_hands(ordinary), "An ordinary item must remain usable.")
	ADD_TRAIT(ordinary, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!user.dropItemToGround(ordinary), "The lifecycle guard must preserve NODROP.")
	TEST_ASSERT(user.is_holding(ordinary), "A blocked drop must keep the item held.")
	TEST_ASSERT(user.dropItemToGround(ordinary, TRUE), "A forced ordinary drop must still succeed.")
	TEST_ASSERT_EQUAL(ordinary.loc, get_turf(user), "A live item must reach the ground.")
	TEST_ASSERT_EQUAL(ordinary.drop_calls, 1, "An ordinary drop must run its callback exactly once.")

/datum/unit_test/runtime_nov05_zad_payload/Run()
	var/obj/item/zadcage/cage = allocate(/obj/item/zadcage)
	var/datum/zad_flight/flight = new
	allocated += flight
	var/obj/item/deleted_payload = allocate(/obj/item)
	var/obj/item/live_payload = allocate(/obj/item)
	flight.payload_items = list(deleted_payload, live_payload)
	qdel(deleted_payload)
	var/runtimes_before = GLOB.total_runtimes
	cage.complete_arrival(flight)
	TEST_ASSERT_EQUAL(live_payload.loc, cage, "The surviving payload must arrive normally.")
	TEST_ASSERT_EQUAL(length(cage.held_payload), 1, "A destroyed parcel must not enter cage inventory.")
	TEST_ASSERT_EQUAL(length(flight.payload_items), 0, "Arrival must release the flight's item references.")
	cage.held_payload += deleted_payload
	cage.retrieve_payload(null)
	TEST_ASSERT_EQUAL(live_payload.loc, get_turf(cage), "Retrieving without hands must drop the live parcel.")
	TEST_ASSERT_EQUAL(length(cage.held_payload), 0, "Retrieval must clear stale references too.")
	flight.payload_items = list(deleted_payload, live_payload)
	flight.drop_payload(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(live_payload.loc, run_loc_floor_top_right, "A returned flight must still drop its surviving payload.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Expired cargo must not be forceMoved.")

/obj/structure/mineral_door/wood/unit_test_nov05
	close_delay = 25
	var/updates_after_delete = 0

/obj/structure/mineral_door/wood/unit_test_nov05/update_icon()
	if(QDELETED(src))
		updates_after_delete++
	return ..()

/datum/unit_test/runtime_nov05_door_animation/proc/delete_during_animation(obj/structure/mineral_door/door)
	sleep(1)
	qdel(door)

/datum/unit_test/runtime_nov05_door_animation/Run()
	var/obj/structure/mineral_door/wood/unit_test_nov05/door = allocate(/obj/structure/mineral_door/wood/unit_test_nov05)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	// A path permits an NPC to open a door without a client.
	user.myPath = list(get_turf(door))
	var/runtimes_before = GLOB.total_runtimes
	INVOKE_ASYNC(src, PROC_REF(delete_during_animation), door)
	door.Bumped(user)
	TEST_ASSERT(door.isSwitchingStates, "Bumping must enter the real opening animation before deletion.")
	// Bumped inherits waitfor=FALSE, so wait for the opening continuation too.
	sleep(3)
	TEST_ASSERT(QDELETED(door), "The door must be deleted during its opening animation.")
	TEST_ASSERT_EQUAL(door.updates_after_delete, 0, "Opening must stop before updating or scheduling a deleted door.")
	TEST_ASSERT(!length(door.active_timers), "Bumping a deleted door must not schedule auto-close.")

	var/obj/structure/mineral_door/wood/unit_test_nov05/closing = allocate(/obj/structure/mineral_door/wood/unit_test_nov05)
	closing.close_delay = -1
	closing.Open(TRUE)
	TEST_ASSERT(closing.door_opened, "Normal opening must still work.")
	INVOKE_ASYNC(src, PROC_REF(delete_during_animation), closing)
	closing.Close(TRUE)
	TEST_ASSERT(QDELETED(closing), "The second fixture must be deleted during closing.")
	TEST_ASSERT_EQUAL(closing.updates_after_delete, 0, "Closing must stop after deletion.")
	var/obj/structure/mineral_door/wood/unit_test_nov05/ordinary = allocate(/obj/structure/mineral_door/wood/unit_test_nov05)
	ordinary.close_delay = -1
	ordinary.Open(TRUE)
	TEST_ASSERT(ordinary.door_opened && !ordinary.density, "An uninterrupted opening must make the door passable.")
	ordinary.Close(TRUE)
	TEST_ASSERT(!ordinary.door_opened && ordinary.density, "An uninterrupted closing must restore the door's collision.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Interrupted door animations must not runtime.")
