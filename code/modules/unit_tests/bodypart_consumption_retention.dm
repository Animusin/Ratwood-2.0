/mob/living/carbon/human/consistent/bodypart_consumer
	var/consumption_heals = 0

/// Keep the real interruptible action, using a short fixture-only duration.
/mob/living/carbon/human/consistent/bodypart_consumer/do_after_coefficent()
	return 0.01

/mob/living/carbon/human/consistent/bodypart_consumer/fully_heal(admin_revive = FALSE, break_restraints = FALSE)
	consumption_heals++
	return ..()

/datum/unit_test/proc/create_bodypart_consumer(kind)
	var/mob/living/carbon/human/consistent/bodypart_consumer/consumer = allocate(/mob/living/carbon/human/consistent/bodypart_consumer)
	if(kind == "zombie")
		consumer.mind_initialize()
		consumer.mind.add_antag_datum(/datum/antagonist/zombie)
	else
		consumer.set_species(/datum/species/werewolf)
	return consumer

/// Eating a combat-severed limb must still work after its donor is destroyed and owner is cleared.
/datum/unit_test/bodypart_consumption_deleted_owner/Run()
	for(var/kind in list("zombie", "werewolf"))
		var/mob/living/carbon/human/consistent/bodypart_consumer/consumer = create_bodypart_consumer(kind)
		var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
		var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
		arm.admin_dismember()
		// The throwing animation is unrelated to eating; keep the fixture's target stationary.
		QDEL_NULL(arm.throwing)
		arm.forceMove(run_loc_floor_bottom_left)
		qdel(donor)
		TEST_ASSERT_NULL(arm.owner, "The consumed limb must reproduce its destroyed donor's cleared ownership.")
		consumer.adjustBruteLoss(15)
		var/heals_before = consumer.consumption_heals
		var/runtimes_before = GLOB.total_runtimes
		arm.onbite(consumer)
		TEST_ASSERT(QDELETED(arm), "The [kind] must finish consuming the bodyless limb.")
		TEST_ASSERT_EQUAL(consumer.consumption_heals, heals_before + 1, "Consuming bodyless flesh must still invoke the [kind]'s normal healing.")
		TEST_ASSERT_EQUAL(consumer.getBruteLoss(), 0, "Consumption must still heal the [kind]'s actual damage.")
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A [kind] must not access a missing donor when consuming flesh.")
		QDEL_NULL(consumer.mind)

/// Null-safe donor access must preserve both sunder variants' existing consumption restriction.
/datum/unit_test/bodypart_consumption_sunder_protection/Run()
	for(var/kind in list("zombie", "werewolf"))
		var/mob/living/carbon/human/consistent/bodypart_consumer/consumer = create_bodypart_consumer(kind)
		var/mob/living/carbon/human/consistent/donor = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
		var/heals_before = consumer.consumption_heals
		var/runtimes_before = GLOB.total_runtimes
		for(var/protection in list(/datum/status_effect/fire_handler/fire_stacks/sunder, /datum/status_effect/fire_handler/fire_stacks/sunder/blessed))
			donor.apply_status_effect(protection, 5, TRUE)
			TEST_ASSERT(donor.has_status_effect(protection), "The fixture must apply [protection] before testing consumption.")
			arm.onbite(consumer)
			TEST_ASSERT(!QDELETED(arm), "[protection] must still prevent a [kind] consuming the protected limb.")
			TEST_ASSERT_EQUAL(consumer.consumption_heals, heals_before, "Protected flesh must not heal the [kind].")
			donor.remove_status_effect(protection)
		arm.onbite(consumer)
		TEST_ASSERT(QDELETED(arm), "Without sunder protection, the [kind] must still consume an attached limb.")
		TEST_ASSERT_EQUAL(consumer.consumption_heals, heals_before + 1, "Unprotected flesh must still heal the [kind].")
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Donor protection and consumption must remain runtime-free.")
		QDEL_NULL(consumer.mind)
