/// A descriptor outside the name's slots must remain available to full descriptions.
/datum/mob_descriptor/unit_test_name_unused
	name = "Unneeded name detail"
	slot = MOB_DESCRIPTOR_SLOT_HEIGHT

/datum/mob_descriptor/unit_test_name_unused/can_describe(mob/living/described)
	if(istype(described, /mob/living/carbon/human/consistent/name_descriptor_probe))
		var/mob/living/carbon/human/consistent/name_descriptor_probe/human = described
		human.unneeded_descriptor_checks++
	return TRUE

/mob/living/carbon/human/consistent/name_descriptor_probe
	var/unneeded_descriptor_checks = 0

/datum/unit_test/mobs_visible_name_work/Run()
	var/mob/living/carbon/human/consistent/name_descriptor_probe/human = allocate(/mob/living/carbon/human/consistent/name_descriptor_probe)
	var/obj/item/clothing/head/cover = allocate(/obj/item/clothing/head)
	cover.flags_inv |= HIDEFACE
	human.head = cover
	human.pronouns = HE_HIM
	human.mob_descriptors = list(/datum/mob_descriptor/unit_test_name_unused, /datum/mob_descriptor/trait/tall, /datum/mob_descriptor/stature/man)
	human.unneeded_descriptor_checks = 0
	for(var/iteration in 1 to 100)
		TEST_ASSERT_EQUAL(human.get_visible_name(), "Tall Man", "The masked name must retain its trait and stature descriptors.")
	TEST_ASSERT_EQUAL(human.unneeded_descriptor_checks, 0, "Repeated name refreshes must not evaluate unrelated descriptor slots.")

/// Read current state each time: name optimization must not introduce a stale identity cache.
/datum/unit_test/mobs_visible_name_identity/Run()
	var/mob/living/carbon/human/consistent/name_descriptor_probe/human = allocate(/mob/living/carbon/human/consistent/name_descriptor_probe)
	var/obj/item/clothing/head/cover = allocate(/obj/item/clothing/head)
	cover.flags_inv |= HIDEFACE
	human.real_name = "Known Name"
	human.pronouns = HE_HIM
	human.mob_descriptors = list(/datum/mob_descriptor/unit_test_name_unused, /datum/mob_descriptor/trait/tall, /datum/mob_descriptor/stature/man)
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Known Name", "An uncovered face must retain its real name.")
	human.head = cover
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Tall Man", "Covering the face must immediately use the descriptor name.")
	human.remove_mob_descriptor(/datum/mob_descriptor/trait/tall)
	human.add_mob_descriptor(/datum/mob_descriptor/trait/short)
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Short Man", "Changing descriptors must immediately change a masked name.")
	human.pronouns = SHE_HER
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Short Woman", "Stature must still respond to current pronouns.")
	ADD_TRAIT(human, TRAIT_ANONYMOUS, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Unknown", "Anonymous masked characters must remain anonymous.")
	human.name_override = "Override Name"
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Override Name", "Explicit name overrides must retain priority.")
	human.name_override = null
	REMOVE_TRAIT(human, TRAIT_ANONYMOUS, TRAIT_SOURCE_UNIT_TESTS)
	human.head = null
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Known Name", "Removing the covering must restore the real name.")
	ADD_TRAIT(human, TRAIT_DISFIGURED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Short Woman", "Disfigurement must still hide the face name.")
	ADD_TRAIT(human, TRAIT_SCARRED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(human.get_visible_name(), "Known Name", "Recognizable scars must retain the existing disfigurement exception.")
	human.unneeded_descriptor_checks = 0
	var/list/full_description = human.get_mob_descriptors()
	TEST_ASSERT(/datum/mob_descriptor/unit_test_name_unused in full_description, "Full descriptions must still include unrelated name slots.")
	TEST_ASSERT_EQUAL(human.unneeded_descriptor_checks, 1, "Unfiltered descriptions must still evaluate their descriptors.")
