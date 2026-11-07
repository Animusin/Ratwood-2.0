/// Exercise reads actual head-slot items, including flower crowns that are not clothing.
/datum/unit_test/runtime_nov07_pushup_equipment/Run()
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	// The generic fixture species is abstract and excluded by ordinary clothing's race check.
	subject.set_species(/datum/species/human/northern)
	subject.gender = MALE
	var/base_cost = subject.calculate_stamina_loss_per_pushup()
	var/obj/item/flowercrown/calendula/crown = allocate(/obj/item/flowercrown/calendula)
	TEST_ASSERT(subject.equip_to_slot_if_possible(crown, SLOT_HEAD, bypass_equip_delay_self = TRUE), "The reported flower crown must occupy the real head slot.")
	TEST_ASSERT_EQUAL(subject.head, crown, "The flower crown must actually occupy the slot read by pushups.")
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(), base_cost, "A flower crown must not be treated as armor or read a nonexistent armor_class.")
	TEST_ASSERT(subject.dropItemToGround(crown, TRUE), "The flower crown must be removable before equipping a helmet.")
	TEST_ASSERT_NULL(subject.head, "Removing the crown must free the head slot.")
	var/obj/item/clothing/head/roguetown/helmet/helmet = allocate(/obj/item/clothing/head/roguetown/helmet)
	TEST_ASSERT(subject.equip_to_slot_if_possible(helmet, SLOT_HEAD, bypass_equip_delay_self = TRUE), "An ordinary helmet must still equip in the head slot.")
	TEST_ASSERT_EQUAL(subject.head, helmet, "The helmet must actually occupy the slot read by pushups.")
	helmet.armor_class = ARMOR_CLASS_MEDIUM
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(), base_cost + 1, "Medium head armor must retain its stamina penalty.")
	helmet.armor_class = ARMOR_CLASS_HEAVY
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(), base_cost + 3, "Heavy head armor must retain its stamina penalty.")
	var/obj/item/clothing/suit/armor = allocate(/obj/item/clothing/suit, subject)
	subject.wear_armor = armor
	armor.armor_class = ARMOR_CLASS_MEDIUM
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(), base_cost + 5, "Body armor and helmet penalties must still add together.")
	armor.armor_class = ARMOR_CLASS_HEAVY
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(), base_cost + 8, "Heavy body armor must retain its full stamina penalty.")
	TEST_ASSERT_EQUAL(subject.calculate_stamina_loss_per_pushup(TRUE), max(base_cost + 3, 1), "Kneeling pushups must retain their normal discount.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Head-slot accessories must not break exercise calculations.")

/// The test owns this otherwise ordinary special intent and releases its borrowed references.
/datum/special_intent/runtime_nov07_test/Destroy()
	howner = null
	iparent = null
	return ..()

/datum/unit_test/runtime_nov07_special_missing_limb/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/sword/weapon = allocate(/obj/item/rogueweapon/sword)
	var/datum/special_intent/runtime_nov07_test/special = new
	allocated += special
	special.howner = attacker
	special.iparent = weapon
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(leg, "The fixture must start with the limb hit by Shin Prod.")
	allocated += leg
	var/runtimes_before = GLOB.total_runtimes
	var/damage_before = leg.brute_dam
	special.apply_generic_weapon_damage(victim, 1, "stab", BODY_ZONE_R_LEG, BCLASS_CUT, full_pen = TRUE)
	TEST_ASSERT(leg.brute_dam > damage_before, "An intact targeted limb must still take special-attack damage.")
	leg.drop_limb(TRUE)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_LEG), "The reported limb must be absent before the delayed hit.")
	damage_before = victim.getBruteLoss()
	special.apply_generic_weapon_damage(victim, 10, "stab", BODY_ZONE_R_LEG, BCLASS_CUT)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), damage_before, "A missing limb must not redirect special damage to an unrelated bodypart.")
	special.apply_generic_weapon_damage(null, 10, "stab", BODY_ZONE_R_LEG, BCLASS_CUT)
	qdel(weapon)
	special.apply_generic_weapon_damage(victim, 10, "stab", BODY_ZONE_CHEST, BCLASS_CUT)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Missing limbs, targets and deleted weapons must not produce delayed special-attack runtimes.")

/// A self-hit must cancel one's shield guard without turning it into a counterattack against oneself.
/datum/unit_test/runtime_nov07_limbguard_self_hit/Run()
	var/mob/living/carbon/human/consistent/defender = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/shield/tower/metal/shield = allocate(/obj/item/rogueweapon/shield/tower/metal)
	var/obj/item/rogueweapon/sword/weapon = allocate(/obj/item/rogueweapon/sword)
	defender.cmode = TRUE
	attacker.cmode = TRUE
	defender.put_in_hands(shield)
	attacker.put_in_hands(weapon)
	var/datum/status_effect/buff/clash/limbguard/guard = defender.apply_status_effect(/datum/status_effect/buff/clash/limbguard, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(guard, "The fixture must grant the real Limb Guard effect.")
	guard.is_active = TRUE
	var/runtimes_before = GLOB.total_runtimes
	var/block = SEND_SIGNAL(defender, COMSIG_MOB_ITEM_BEING_ATTACKED, defender, defender, shield, BODY_ZONE_L_ARM)
	TEST_ASSERT(!(block & COMPONENT_NO_ATTACK), "A self-hit must not be intercepted as an enemy strike.")
	TEST_ASSERT(!defender.has_status_effect(/datum/status_effect/buff/clash/limbguard), "Attacking with the guarded shield must still cancel the stance.")
	TEST_ASSERT(!defender.has_status_effect(/datum/status_effect/debuff/exposed), "A self-hit must not apply the enemy's counterattack debuff to the defender.")
	TEST_ASSERT(defender.is_holding(shield), "A self-hit must not disarm its own guard.")
	guard = defender.apply_status_effect(/datum/status_effect/buff/clash/limbguard, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(guard, "The stance must be available for the enemy-hit scenario.")
	guard.is_active = TRUE
	block = SEND_SIGNAL(defender, COMSIG_MOB_ITEM_BEING_ATTACKED, defender, attacker, weapon, BODY_ZONE_L_ARM)
	TEST_ASSERT(block & COMPONENT_NO_ATTACK, "An enemy hit on the protected limb must still be blocked.")
	TEST_ASSERT(attacker.has_status_effect(/datum/status_effect/debuff/exposed), "A blocked enemy must still receive the guard counterattack debuff.")
	TEST_ASSERT(!attacker.is_holding(weapon), "A blocked enemy must still be disarmed.")
	TEST_ASSERT(!defender.has_status_effect(/datum/status_effect/buff/clash/limbguard), "A successful counterattack must still consume the stance.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Self-hits and enemy hits must not access a guard owner after the status is removed.")

/// Mutate the pit when the actual do_after begins, while its original rescue is suspended.
/datum/unit_test/runtime_nov07_quicksand_rescue
	var/obj/structure/quicksand/pit
	var/mob/living/carbon/human/trapped
	var/mob/living/carbon/human/replacement
	var/rescue_action

/datum/unit_test/runtime_nov07_quicksand_rescue/proc/on_rescue_begin()
	SIGNAL_HANDLER
	if(rescue_action == "deleted")
		qdel(pit)
		return
	pit.unbuckle_mob(trapped, TRUE)
	if(rescue_action == "replacement")
		pit.buckle_mob(replacement, TRUE)

/datum/unit_test/runtime_nov07_quicksand_rescue/Run()
	var/mob/living/carbon/human/consistent/rescuer = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	var/runtimes_before = GLOB.total_runtimes
	for(var/scenario in list("normal", "rescued", "replacement", "deleted"))
		trapped = allocate(/mob/living/carbon/human/consistent)
		pit = allocate(/obj/structure/quicksand)
		TEST_ASSERT(pit.buckle_mob(trapped, TRUE), "The rescue fixture must start with a trapped victim.")
		replacement = allocate(/mob/living/carbon/human/consistent)
		rescue_action = scenario
		if(scenario != "normal")
			RegisterSignal(rescuer, COMSIG_DO_AFTER_BEGAN, PROC_REF(on_rescue_begin))
		pit.attack_hand(rescuer)
		UnregisterSignal(rescuer, COMSIG_DO_AFTER_BEGAN)
		if(scenario == "replacement")
			TEST_ASSERT_EQUAL(replacement.buckled, pit, "A stale rescue must not pull a newly trapped person out instead.")
		else if(scenario == "deleted")
			TEST_ASSERT(QDELETED(pit), "The race fixture must delete the pit during the rescue.")
		else
			TEST_ASSERT_NULL(trapped.buckled, "Ordinary or already-completed rescues must leave the original victim free.")
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Changing or deleting the pit during the wait must not index an empty victim list.")
		qdel(pit)
		qdel(trapped)
		qdel(replacement)
