/// An inventory movement callback may destroy an item before its slot is assigned.
/obj/item/clothing/mask/rogue/unit_test_consumed_on_equip_move/forceMove(atom/destination)
	. = ..()
	if(ismob(destination))
		qdel(src)

/obj/item/clothing/mask/rogue/unit_test_consumed_on_equip_check/mob_can_equip(mob/living/wearer, mob/living/equipper, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE)
	qdel(src)
	return TRUE

/datum/unit_test/runtime_equipment_callback_deletion/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	// The generic test human uses an abstract species excluded by clothing's race check.
	wearer.set_species(/datum/species/human/northern)
	wearer.gender = MALE
	var/runtimes_before = GLOB.total_runtimes
	var/obj/item/clothing/mask/rogue/check_consumed = allocate(/obj/item/clothing/mask/rogue/unit_test_consumed_on_equip_check)
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(check_consumed, SLOT_WEAR_MASK), "A validation callback that consumes its item must cancel equipping.")
	TEST_ASSERT_NULL(wearer.wear_mask, "Validation must not leave a deleted mask equipped.")
	var/obj/item/clothing/mask/rogue/move_consumed = allocate(/obj/item/clothing/mask/rogue/unit_test_consumed_on_equip_move)
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(move_consumed, SLOT_WEAR_MASK, bypass_equip_delay_self = TRUE), "A movement callback that consumes its item must cancel equipping.")
	TEST_ASSERT(QDELETED(move_consumed), "The movement fixture must actually delete the mask.")
	TEST_ASSERT_NULL(wearer.wear_mask, "A mask deleted during forceMove must not be written back into wear_mask.")
	var/obj/item/clothing/mask/rogue/live_mask = allocate(/obj/item/clothing/mask/rogue)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(live_mask, SLOT_WEAR_MASK, bypass_equip_delay_self = TRUE), "An ordinary live mask must still equip successfully.")
	TEST_ASSERT_EQUAL(wearer.wear_mask, live_mask, "Successful equipment must still assign the mask slot.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Equipment callbacks must not move a deleted item.")

/datum/unit_test/runtime_goblin_worn_deletion/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/mask/rogue/goblin_mask/goblin = allocate(/obj/item/clothing/mask/rogue/goblin_mask)
	wearer.equip_to_slot(goblin, SLOT_WEAR_MASK)
	TEST_ASSERT_EQUAL(wearer.wear_mask, goblin, "The goblin must begin equipped.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(goblin)
	TEST_ASSERT_NULL(wearer.wear_mask, "Deleting a worn goblin must clear the mask slot.")
	TEST_ASSERT(!(goblin in wearer.get_equipped_items()), "Deleted goblins must not remain in worn armour lists.")
	TEST_ASSERT(!goblin.canStrip(wearer, wearer), "A deleted mask must not be strippable.")
	wearer.stripPanelUnequip(goblin, wearer, SLOT_WEAR_MASK)
	wearer.checkarmor(BODY_ZONE_HEAD, "blunt", 5)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Armour checks and a stale strip-panel click must tolerate the deleted mask.")

/datum/unit_test/runtime_goblin_displaced_headgear/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_species(/datum/species/human/northern)
	wearer.gender = MALE
	var/obj/item/clothing/mask/rogue/original_mask = allocate(/obj/item/clothing/mask/rogue)
	wearer.equip_to_slot(original_mask, SLOT_WEAR_MASK)
	var/obj/item/clothing/mask/rogue/goblin_mask/goblin = allocate(/obj/item/clothing/mask/rogue/goblin_mask)
	TEST_ASSERT(goblin.Leap(wearer), "A goblin must still replace removable headgear.")
	TEST_ASSERT_EQUAL(wearer.wear_mask, goblin, "The goblin must occupy the mask slot after leaping.")
	TEST_ASSERT_EQUAL(original_mask.loc, goblin, "Displaced headgear must be held safely inside the goblin.")
	qdel(goblin)
	TEST_ASSERT(!QDELETED(original_mask), "Deleting a goblin must not delete the victim's original mask.")
	TEST_ASSERT_EQUAL(wearer.wear_mask, original_mask, "The original mask must be restored before goblin contents are deleted.")
	TEST_ASSERT_EQUAL(original_mask.loc, wearer, "Restored headgear must be located on its wearer.")
	TEST_ASSERT_NULL(goblin.headgear, "The discarded goblin must release its headgear reference.")

/datum/unit_test/runtime_goblin_nodrop_headgear/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_species(/datum/species/human/northern)
	wearer.gender = MALE
	var/obj/item/clothing/mask/rogue/original_mask = allocate(/obj/item/clothing/mask/rogue)
	wearer.equip_to_slot(original_mask, SLOT_WEAR_MASK)
	ADD_TRAIT(original_mask, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/clothing/mask/rogue/goblin_mask/goblin = allocate(/obj/item/clothing/mask/rogue/goblin_mask)
	TEST_ASSERT(!goblin.Leap(wearer), "A goblin must stop when the existing mask cannot be removed.")
	qdel(goblin)
	TEST_ASSERT(!QDELETED(original_mask), "Failed attachment must not make the goblin own and delete irremovable headgear.")
	TEST_ASSERT_EQUAL(wearer.wear_mask, original_mask, "Failed attachment must preserve the original mask slot.")

/datum/unit_test/runtime_goblin_lethal_damage/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/mask/rogue/goblin_mask/goblin = allocate(/obj/item/clothing/mask/rogue/goblin_mask)
	wearer.equip_to_slot(goblin, SLOT_WEAR_MASK)
	var/runtimes_before = GLOB.total_runtimes
	// Blunt damage kills the creature but leaves its clothing item for removal.
	goblin.take_damage(1000, BRUTE, "blunt", FALSE, armor_penetration = 100)
	TEST_ASSERT_EQUAL(goblin.stat, DEAD, "Lethal blunt damage must kill the goblin.")
	TEST_ASSERT(!QDELETED(goblin), "Blunt damage must preserve the goblin's existing dead-mask behavior.")
	TEST_ASSERT_EQUAL(wearer.wear_mask, goblin, "The dead goblin must remain removable from its wearer's face.")
	// Acid goes through the real item-destruction path, unlike ordinary clothing damage.
	goblin.take_damage(1000, BURN, "acid", FALSE, armor_penetration = 100)
	TEST_ASSERT(QDELETED(goblin), "Acid destruction must delete the worn goblin.")
	TEST_ASSERT_NULL(wearer.wear_mask, "Destroying a goblin through damage must release its equipment slot.")
	wearer.checkarmor(BODY_ZONE_HEAD, "blunt", 5)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Damage must stop using the goblin after parent destruction.")

/// Parent impact processing may consume the thrown item before the goblin's leap.
/mob/living/carbon/human/consistent/unit_test_consumes_goblin/hitby(atom/movable/thrown, skipcatch, hitpush = TRUE, blocked, datum/thrownthing/throwingdatum, damage_flag = "blunt")
	qdel(thrown)
	return TRUE

/datum/unit_test/runtime_goblin_consumed_impact/Run()
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent/unit_test_consumes_goblin)
	var/obj/item/clothing/mask/rogue/goblin_mask/goblin = allocate(/obj/item/clothing/mask/rogue/goblin_mask)
	var/runtimes_before = GLOB.total_runtimes
	goblin.throw_impact(target)
	TEST_ASSERT(QDELETED(goblin), "The impact fixture must consume the goblin.")
	TEST_ASSERT_NULL(target.wear_mask, "Impact must not attach a goblin deleted by the target's hitby callback.")
	TEST_ASSERT(!goblin.Leap(target), "A pending leap must refuse an already deleted goblin.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A consumed goblin must not continue into equipment or timer callbacks.")
