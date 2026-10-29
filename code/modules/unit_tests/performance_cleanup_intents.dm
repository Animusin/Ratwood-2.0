/// Bare-hand refreshes must preserve selections and ownership without adding garbage.
/datum/unit_test/bare_hand_intent_reuse/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.update_a_intents()
	var/list/active_before = user.possible_a_intents.Copy()
	var/list/offhand_before = user.possible_offhand_intents.Copy()
	TEST_ASSERT_EQUAL(length(active_before), 4, "The benchmark requires the four normal bare-hand actions.")
	TEST_ASSERT_EQUAL(length(offhand_before), 4, "Both empty hands must have their own actions.")
	user.rog_intent_change(4)
	TEST_ASSERT(user.swap_hand(), "The other empty hand must become active.")
	user.rog_intent_change(3)
	TEST_ASSERT(user.swap_hand(), "The first empty hand must become active again.")
	TEST_ASSERT_EQUAL(user.active_hand_index, 1, "The benchmark must start on the original hand.")
	TEST_ASSERT_EQUAL(user.l_ua_index, 4, "The first hand must remember punch before refreshing.")
	TEST_ASSERT_EQUAL(user.r_ua_index, 3, "The second hand must remember grab before refreshing.")
	TEST_ASSERT_EQUAL(user.o_intent.type, INTENT_GRAB, "Swapping back must restore the stored off-hand action.")
	user.atkswinging = TRUE
	var/qdels_before = count_bare_hand_qdels()
	for(var/iteration in 1 to 1000)
		user.update_a_intents()
	var/qdels_added = count_bare_hand_qdels() - qdels_before
	TEST_NOTICE(src, "1000 unchanged bare-hand updates: [qdels_added] intent qdel calls (old implementation: 8000).")
	TEST_ASSERT_EQUAL(qdels_added, 0, "Refreshing unchanged empty hands must not create deletion work.")
	TEST_ASSERT(!user.atkswinging, "Refreshing intents must still interrupt an attack.")
	TEST_ASSERT_EQUAL(user.a_intent, active_before[4], "The chosen active-hand action must be preserved.")
	TEST_ASSERT_EQUAL(user.o_intent, offhand_before[3], "The chosen off-hand action must be preserved.")
	TEST_ASSERT_EQUAL(user.used_intent, user.a_intent, "The active intent must still be installed for combat.")
	for(var/index in 1 to 4)
		var/datum/intent/active_intent = user.possible_a_intents[index]
		var/datum/intent/offhand_intent = user.possible_offhand_intents[index]
		TEST_ASSERT_EQUAL(active_intent, active_before[index], "An unchanged active-hand action must be reused.")
		TEST_ASSERT_EQUAL(offhand_intent, offhand_before[index], "An unchanged off-hand action must be reused.")
		TEST_ASSERT_NOTEQUAL(active_intent, offhand_intent, "The two hands must not share mutable intent datums.")
		TEST_ASSERT_EQUAL(active_intent.mastermob, user, "Reused actions must remain owned by their mob.")
		TEST_ASSERT_NULL(active_intent.masteritem, "A bare-hand action must not reference an item.")
	var/mob/living/carbon/human/consistent/other = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTEQUAL(user.possible_a_intents[1], other.possible_a_intents[1], "Different mobs must not share cached actions of the same type.")

/datum/unit_test/bare_hand_intent_reuse/proc/count_bare_hand_qdels()
	. = 0
	for(var/intent_type in list(INTENT_HELP, INTENT_DISARM, INTENT_GRAB, INTENT_HARM))
		var/datum/qdel_item/statistics = SSgarbage.items[intent_type]
		if(statistics)
			. += statistics.qdels

/// Exercise each item-intent source without a weapon's unrelated skills or combat rules.
/obj/item/unit_test_intent_weapon
	possible_item_intents = list(/datum/intent/sword/cut)
	gripped_intents = list(/datum/intent/sword/thrust)

/obj/item/unit_test_intent_weapon/get_altgrip_intents()
	return list(/datum/intent/use)

/datum/unit_test/intent_reuse_weapon_transitions/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/unit_test_intent_weapon/weapon = allocate(/obj/item/unit_test_intent_weapon)
	TEST_ASSERT(user.put_in_active_hand(weapon), "The fixture must be held in the active hand.")
	user.rog_intent_change(1)
	var/datum/intent/weapon_intent = user.a_intent
	var/datum/intent/empty_hand_intent = user.possible_offhand_intents[1]
	TEST_ASSERT_EQUAL(weapon_intent.masteritem, weapon, "Weapon actions must reference the held item.")
	TEST_ASSERT_EQUAL(weapon_intent.mastermob, user, "Weapon actions must reference the wielder.")
	TEST_ASSERT_EQUAL(weapon.d_type, "slash", "afterchange must apply the selected weapon damage type.")
	user.update_a_intents()
	TEST_ASSERT(QDELETED(weapon_intent), "Weapon actions must still be rebuilt, including their charge resources.")
	TEST_ASSERT_EQUAL(user.possible_offhand_intents[1], empty_hand_intent, "Updating a weapon must not rebuild the empty hand.")
	TEST_ASSERT(user.swap_hand(), "Swapping a one-handed weapon must succeed.")
	TEST_ASSERT_EQUAL(user.possible_a_intents[1], empty_hand_intent, "The empty-hand actions must survive moving to the active hand.")
	var/datum/intent/swapped_weapon_intent = user.possible_offhand_intents[1]
	TEST_ASSERT_EQUAL(swapped_weapon_intent.masteritem, weapon, "A swapped weapon must retain the correct item owner.")
	TEST_ASSERT_EQUAL(swapped_weapon_intent.mastermob, user, "A swapped weapon must retain the correct mob owner.")
	TEST_ASSERT(user.swap_hand(), "The weapon must return to the active hand.")
	weapon.wielded = TRUE
	user.update_a_intents()
	user.rog_intent_change(1)
	TEST_ASSERT_EQUAL(user.a_intent.type, /datum/intent/sword/thrust, "Wielding must switch to gripped intents.")
	TEST_ASSERT_EQUAL(weapon.d_type, "stab", "afterchange must still run for a new grip.")
	weapon.altgripped = TRUE
	user.update_a_intents()
	user.rog_intent_change(1)
	TEST_ASSERT_EQUAL(user.a_intent.type, /datum/intent/use, "Alternate grips must take precedence over regular wielded intents.")
	TEST_ASSERT_EQUAL(user.a_intent.masteritem, weapon, "Alternate-grip intents must retain the weapon reference.")
	weapon.wielded = FALSE
	weapon.altgripped = FALSE
	user.dropItemToGround(weapon)
	TEST_ASSERT_EQUAL(length(user.possible_a_intents), 4, "Dropping the weapon must restore all bare-hand actions.")
	for(var/datum/intent/intent as anything in user.possible_a_intents + user.possible_offhand_intents)
		TEST_ASSERT_NULL(intent.masteritem, "Dropping an item must leave no item-bound actions in either hand.")

/// Inheriting from a reusable type must not opt custom state into reuse automatically.
/datum/intent/unarmed/punch/unit_test_uncached
	name = "custom punch"

/datum/unit_test/intent_reuse_invalidation/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.update_a_intents()
	var/datum/intent/original_help = user.possible_a_intents[1]
	var/datum/intent/original_punch = user.possible_a_intents[4]
	var/datum/intent/original_offhand_punch = user.possible_offhand_intents[4]
	user.base_intents = list(INTENT_HELP, INTENT_DISARM, INTENT_GRAB, /datum/intent/unarmed/punch/unit_test_uncached)
	user.update_a_intents()
	TEST_ASSERT(QDELETED(original_punch) && QDELETED(original_offhand_punch), "Changing species/actions must release removed intent types in both hands.")
	TEST_ASSERT_EQUAL(user.possible_a_intents[1], original_help, "Changing one action must not recreate unaffected actions.")
	var/datum/intent/custom_intent = user.possible_a_intents[4]
	user.update_a_intents()
	TEST_ASSERT(QDELETED(custom_intent), "Custom intent subtypes must keep their original recreation lifecycle.")
	TEST_ASSERT_EQUAL(user.possible_a_intents[1], original_help, "Audited actions can be reused alongside a custom action.")
	qdel(original_help)
	user.update_a_intents()
	var/datum/intent/replacement_help = user.possible_a_intents[1]
	TEST_ASSERT(!QDELETED(replacement_help), "An already deleted action must never be reused.")
	TEST_ASSERT_EQUAL(replacement_help.mastermob, user, "A replacement action must have a valid owner.")
	user.base_intents = list(INTENT_GRAB, INTENT_HELP)
	user.update_a_intents()
	var/datum/intent/first_action = user.possible_a_intents[1]
	var/datum/intent/second_action = user.possible_a_intents[2]
	TEST_ASSERT_EQUAL(first_action.type, INTENT_GRAB, "Reuse must honor the new action order.")
	TEST_ASSERT_EQUAL(second_action.type, INTENT_HELP, "Reuse must honor the new action order.")
	var/list/final_intents = user.possible_a_intents + user.possible_offhand_intents
	qdel(user)
	for(var/datum/intent/intent as anything in final_intents)
		TEST_ASSERT(QDELETED(intent), "Mob destruction must still delete every reused action.")
		TEST_ASSERT_NULL(intent.mastermob, "Reused actions must release their deleted mob owner.")
