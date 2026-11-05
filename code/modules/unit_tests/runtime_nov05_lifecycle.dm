/// Exercise both callback rejection and a callback that deletes itself but returns success.
/datum/status_effect/unit_test_nov05_cancelled
	id = "unit_test_nov05_cancelled"
	alert_type = null
	var/removal_count = 0

/datum/status_effect/unit_test_nov05_cancelled/on_apply()
	qdel(src)
	return TRUE

/datum/status_effect/unit_test_nov05_cancelled/on_remove()
	removal_count++

/datum/status_effect/unit_test_nov05_cancelled/rejected/on_apply()
	return FALSE

/datum/unit_test/runtime_nov05_status_creation/Run()
	var/mob/living/owner = allocate(/mob/living)
	var/runtimes_before = GLOB.total_runtimes
	for(var/effect_type in list(/datum/status_effect/unit_test_nov05_cancelled, /datum/status_effect/unit_test_nov05_cancelled/rejected))
		var/datum/status_effect/unit_test_nov05_cancelled/effect = owner.apply_status_effect(effect_type)
		TEST_ASSERT(QDELETED(effect), "A rejected or self-deleted effect must finish deleted.")
		TEST_ASSERT_EQUAL(effect.removal_count, 1, "Creation must not call on_remove twice.")
		TEST_ASSERT(!(effect in SSfastprocess.processing), "A deleted effect must not be registered for processing after on_apply returns.")
		TEST_ASSERT_NULL(owner.has_status_effect(effect_type), "A cancelled effect must leave its owner's registry.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Cancelled status creation must not runtime.")

/datum/status_effect/buff/healing/unit_test_nov05
	var/removal_count = 0

/datum/status_effect/buff/healing/unit_test_nov05/on_remove()
	removal_count++
	return ..()

/// Immolation's partner component removes healing inside the real on_apply signal.
/datum/unit_test/runtime_nov05_healing_immolation/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	var/datum/status_effect/buff/healing/unit_test_nov05/normal = patient.apply_status_effect(/datum/status_effect/buff/healing/unit_test_nov05, 1)
	TEST_ASSERT(!QDELETED(normal), "An ordinary miracle must still apply.")
	TEST_ASSERT(patient.get_filter("miracle_heal_glow"), "An ordinary miracle must retain its healing outline.")
	TEST_ASSERT(normal in SSfastprocess.processing, "An ordinary miracle must still process.")
	patient.remove_status_effect(/datum/status_effect/buff/healing)
	TEST_ASSERT_EQUAL(normal.removal_count, 1, "Normal removal must run once.")
	TEST_ASSERT_NULL(patient.get_filter("miracle_heal_glow"), "Normal removal must clear its outline.")
	var/datum/component/immolation/partner/immolation = patient.AddComponent(/datum/component/immolation/partner, patient, caster, 0, TRUE)
	TEST_ASSERT(immolation, "The target must receive the real immolation component.")
	var/datum/status_effect/buff/healing/unit_test_nov05/blocked = patient.apply_status_effect(/datum/status_effect/buff/healing/unit_test_nov05, 1)
	TEST_ASSERT(QDELETED(blocked), "Immolation must continue to block the target's healing.")
	TEST_ASSERT_EQUAL(blocked.removal_count, 1, "Healing removed during the signal must not be removed again.")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/buff/healing), "Blocked healing must leave the status registry.")
	TEST_ASSERT_NULL(patient.get_filter("miracle_heal_glow"), "Blocked healing must not recreate its outline after deletion.")
	TEST_ASSERT(!(blocked in SSfastprocess.processing), "Blocked healing must not re-enter processing.")
	immolation.remove_immolation()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The real healing/immolation interaction must not runtime.")

/// Keep the real delayed cast, including the code after its first reagent transfer.
/datum/unit_test/runtime_nov05_woundlick_mindless/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/woundlick/spell = allocate(/obj/effect/proc_holder/spell/targeted/woundlick)
	TEST_ASSERT_NULL(patient.mind, "The patient must have no mind.")
	var/runtimes_before = GLOB.total_runtimes
	spell.cast(list(patient), caster)
	TEST_ASSERT(patient.reagents.get_reagent_amount(/datum/reagent/medicine/healthpot) > 0, "A mindless patient must still receive the healing reagent.")
	TEST_ASSERT(patient.reagents.get_reagent_amount(/datum/reagent/water) > 0, "The mindless patient's cast must finish beyond the werewolf check.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Licking a mindless patient's wounds must not runtime.")

/// Supply only the setup needed by clear_fire without starting the asynchronous hallucination.
/datum/hallucination/fire/unit_test_nov05/New(mob/living/carbon/patient)
	target = patient
	fire_overlay = image('icons/mob/OnFire.dmi', patient, "Standing", ABOVE_MOB_LAYER)

/datum/unit_test/runtime_nov05_fire_image_cleanup/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/hallucination/fire/hallucination = new /datum/hallucination/fire/unit_test_nov05(patient)
	allocated += hallucination
	var/runtimes_before = GLOB.total_runtimes
	hallucination.clear_fire()
	TEST_ASSERT_NULL(hallucination.fire_overlay, "Clearing fire must release its image reference.")
	TEST_ASSERT(QDELETED(hallucination), "Clearing fire must finish the hallucination's cleanup.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Fire images must be released without qdel(/image).")

/datum/unit_test/runtime_nov05_alchemical_icon/Run()
	var/obj/item/reagent_containers/glass/bottle/alchemical/bottle = allocate(/obj/item/reagent_containers/glass/bottle/alchemical)
	bottle.reagents.add_reagent(/datum/reagent/water, 10)
	bottle.update_icon()
	TEST_ASSERT(length(bottle.underlays), "A filled vial must retain its visible liquid.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(bottle.reagents)
	TEST_ASSERT_NULL(bottle.reagents, "Destroying the reagent holder must clear its container link.")
	bottle.update_icon()
	TEST_ASSERT(!length(bottle.underlays), "A vial without a reagent holder must clear its old liquid appearance.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Updating a vial after holder destruction must not runtime.")

/datum/unit_test/runtime_nov05_autogrinder_examine/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/autogrinder/grinder = allocate(/obj/structure/autogrinder)
	var/runtimes_before = GLOB.total_runtimes
	for(var/is_working in list(FALSE, TRUE))
		grinder.working = is_working
		var/list/description = grinder.examine(user)
		var/expected_state = is_working ? "on" : "off"
		TEST_ASSERT(findtext(description.Join("\n"), "switched <b>[expected_state]</b>"), "Examine must describe both running and stopped grinders.")
	grinder.working = FALSE
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Examine must not concatenate the numeric working flag into HTML.")

/datum/unit_test/runtime_nov05_blueprint_stairs
	var/craft_signals = 0

/datum/unit_test/runtime_nov05_blueprint_stairs/proc/on_crafted(datum/source)
	SIGNAL_HANDLER
	craft_signals++

/datum/unit_test/runtime_nov05_blueprint_stairs/Run()
	var/obj/structure/blueprint_site/site = allocate(/obj/structure/blueprint_site)
	var/obj/effect/blueprint_ghost/ghost = allocate(/obj/effect/blueprint_ghost)
	ghost.entry_data = list("type" = "stairs_stone_down", "dir" = SOUTH)
	site.active_ghosts += ghost
	var/runtimes_before = GLOB.total_runtimes
	site.solidify_ghost()
	TEST_ASSERT_EQUAL(site.built_tiles_count, 1, "Automatic stair construction must complete its bookkeeping.")
	var/obj/structure/stairs/stone/d/stairs = locate() in run_loc_floor_bottom_left
	TEST_ASSERT(stairs, "The blueprint must produce a stone staircase.")
	TEST_ASSERT_EQUAL(stairs.dir, NORTH, "The staircase must retain the selected construction orientation.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	RegisterSignal(user, COMSIG_ITEM_CRAFTED, PROC_REF(on_crafted))
	stairs.OnCrafted(SOUTH, user)
	UnregisterSignal(user, COMSIG_ITEM_CRAFTED)
	TEST_ASSERT_EQUAL(craft_signals, 1, "Ordinary player construction must still send its crafting signal.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Automated and player stair construction must not runtime.")

/datum/unit_test/runtime_nov05_headstake_parts/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/fluff/headstake/empty = allocate(/obj/structure/fluff/headstake)
	var/runtimes_before = GLOB.total_runtimes
	empty.attack_hand(user)
	TEST_ASSERT(QDELETED(empty), "A headstake without retained parts must still be removable.")
	var/obj/structure/fluff/headstake/assembled = allocate(/obj/structure/fluff/headstake)
	var/obj/item/bodypart/head/head = allocate(/obj/item/bodypart/head)
	var/obj/item/grown/log/tree/stake/stake = allocate(/obj/item/grown/log/tree/stake)
	assembled.CheckParts(list(head, stake))
	assembled.attack_hand(user)
	TEST_ASSERT(QDELETED(assembled), "Taking down a normal headstake must remove the structure.")
	TEST_ASSERT_EQUAL(head.loc, run_loc_floor_bottom_left, "Taking down the stake must preserve its head.")
	TEST_ASSERT_EQUAL(stake.loc, run_loc_floor_bottom_left, "Taking down the stake must preserve its wood.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Missing and present headstake parts must both dismantle without runtimes.")

/datum/unit_test/runtime_nov05_floordoor_item/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/greatsword/grenz/sword = allocate(/obj/item/rogueweapon/greatsword/grenz)
	var/obj/structure/floordoor/hatch = allocate(/obj/structure/floordoor)
	var/runtimes_before = GLOB.total_runtimes
	hatch.attackby(sword, user)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A sword used on a hatch must remain the item argument, not become the user.")

/// A delivered item can disappear in its equipped callback while put_in_hands returns.
/obj/item/unit_test_nov05_parcel_consumed/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	qdel(src)

/datum/unit_test/runtime_nov05_parcel_contents/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	for(var/parcel_type in list(/obj/item/parcel, /obj/item/parcel/towner_caravan))
		var/obj/item/parcel/parcel = allocate(parcel_type)
		if(istype(parcel, /obj/item/parcel/towner_caravan))
			var/obj/item/parcel/towner_caravan/caravan = parcel
			caravan.unlocked_by_owner_ref = WEAKREF(user)
		var/obj/item/item = allocate(/obj/item/unit_test_nov05_parcel_consumed, parcel)
		parcel.contained_items += item
		parcel.attack_self(user)
		TEST_ASSERT(QDELETED(item), "The item's equip callback must consume it during unwrapping.")
		TEST_ASSERT(QDELETED(parcel), "Unwrapping must finish even when its item is consumed during pickup.")
	var/obj/item/parcel/normal = allocate(/obj/item/parcel)
	var/obj/item/first = allocate(/obj/item, normal)
	var/obj/item/second = allocate(/obj/item, normal)
	normal.contained_items += list(first, second)
	normal.attack_self(user)
	TEST_ASSERT_EQUAL(first.loc, run_loc_floor_bottom_left, "A multi-item parcel must release its first item.")
	TEST_ASSERT_EQUAL(second.loc, run_loc_floor_bottom_left, "Updating the contents list must not skip the second item.")
	TEST_ASSERT(QDELETED(normal), "An ordinary multi-item parcel must finish unwrapping.")
	var/obj/item/parcel/emptied = allocate(/obj/item/parcel)
	var/obj/item/removed = allocate(/obj/item, emptied)
	emptied.contained_items += removed
	removed.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!length(emptied.contained_items), "An item leaving its parcel must not leave a stale contents entry.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Parcel unpacking and item deletion must not produce runtimes.")
