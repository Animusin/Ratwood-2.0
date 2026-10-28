/// Keep armor selection deterministic while exercising the real penetration calculation.
/mob/living/runtime_armor_target/getarmor(def_zone, type, damage, armor_penetration, blade_dulling, intdamfactor, used_weapon)
	return 1

/datum/unit_test/runtime_projectile_armor/Run()
	var/mob/living/target = allocate(/mob/living/runtime_armor_target)
	var/obj/projectile/magic/arcyne_lance/lance = allocate(/obj/projectile/magic/arcyne_lance)
	var/runtimes_before = GLOB.total_runtimes
	var/blocked = target.run_armor_check(BODY_ZONE_CHEST, lance.flag, armor_penetration = lance.armor_penetration, damage = lance.damage, used_weapon = lance)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A stab projectile must not be read as an item with blade durability.")
	TEST_ASSERT_EQUAL(blocked, lance.damage * (1 - (PEN_PASSTHROUGH_MINIMUM + lance.armor_penetration * PEN_PASSTHROUGH_RATIO)), "Arcyne Lance must retain the penetration calculation for its damage flag.")

	var/obj/item/blade = allocate(/obj/item)
	blade.sharpness = IS_SHARP
	blade.max_blade_int = 100
	blade.blade_int = 10
	blocked = target.run_armor_check(BODY_ZONE_CHEST, "stab", armor_penetration = PEN_LIGHT, damage = 20, used_weapon = blade)
	TEST_ASSERT_EQUAL(blocked, 200, "A worn-out physical blade must still be fully blocked by armor.")
	blade.blade_int = 100
	blocked = target.run_armor_check(BODY_ZONE_CHEST, "stab", armor_penetration = PEN_LIGHT, damage = 20, used_weapon = blade)
	TEST_ASSERT_EQUAL(blocked, 10, "A sound physical blade must retain normal penetration.")
	blade.max_blade_int = 0
	blocked = target.run_armor_check(BODY_ZONE_CHEST, "stab", armor_penetration = PEN_LIGHT, damage = 20, used_weapon = blade)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "An item without blade durability must not divide by zero.")
	TEST_ASSERT_EQUAL(blocked, 10, "Items without blade durability must not be treated as worn-out blades.")

/// Some death handlers remove or replace bodyparts while a fatal wound is being applied.
/mob/living/carbon/human/consistent/runtime_critical_death
	var/wound_triggered_death = FALSE

/mob/living/carbon/human/consistent/runtime_critical_death/death(gibbed, nocutscene = FALSE)
	wound_triggered_death = TRUE
	var/obj/item/bodypart/chest/chest = get_bodypart(BODY_ZONE_CHEST)
	chest?.drop_limb(TRUE)
	return TRUE

/datum/unit_test/runtime_critical_owner_loss/Run()
	var/mob/living/carbon/human/consistent/runtime_critical_death/victim = allocate(/mob/living/carbon/human/consistent/runtime_critical_death)
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(chest, "The fixture must begin with an attached chest.")
	allocated += chest
	ADD_TRAIT(victim, TRAIT_SHATTER_WEAKNESS, TRAIT_SOURCE_UNIT_TESTS)
	var/runtimes_before = GLOB.total_runtimes
	var/datum/wound/wound = chest.try_crit(BCLASS_BLUNT, 1000, null, BODY_ZONE_CHEST, silent = TRUE)
	TEST_ASSERT(victim.wound_triggered_death, "The real fracture callback must trigger the death handler.")
	TEST_ASSERT_NULL(chest.owner, "The death handler must detach the bodypart before try_crit finishes.")
	TEST_ASSERT(wound, "An applied critical wound must still be returned after its owner is lost.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Losing the owner during wound application must not abort critical-hit bookkeeping.")
