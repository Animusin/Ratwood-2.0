/// Moving held armour into a cart must not re-equip it from its dropped callback.
/datum/unit_test/cart_armour_drop_lifecycle/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/handcart/cart = allocate(/obj/structure/handcart)
	var/obj/item/clothing/first = allocate(/obj/item/clothing)
	var/obj/item/clothing/second = allocate(/obj/item/clothing)
	ADD_TRAIT(user, TRAIT_MAGEDEXTERITY, TRAIT_SOURCE_UNIT_TESTS)
	first.AddComponent(/datum/component/armour_filtering/negative, TRAIT_MAGEDEXTERITY, "first")
	second.AddComponent(/datum/component/armour_filtering/negative, TRAIT_MAGEDEXTERITY, "second")
	TEST_ASSERT(user.put_in_hands(first), "The first piece must start in a hand.")
	TEST_ASSERT(user.put_in_hands(second), "The second piece must start in a hand.")
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(cart.put_in(first, user), "Held armour must transfer into the cart without recursive drops.")
	TEST_ASSERT_EQUAL(first.loc, cart, "The transferred piece must remain in the cart.")
	TEST_ASSERT(user.is_holding(second), "Held clothing must not be treated as worn armour by another item's drop callback.")
	TEST_ASSERT(!HAS_TRAIT(user, TRAIT_ARMOUR_DISLIKED), "Held clothing must not apply the worn-armour penalty.")
	TEST_ASSERT_EQUAL(cart.current_capacity, first.w_class, "A transfer must count the item exactly once.")
	TEST_ASSERT(!cart.put_in(first, user), "An item already in the cart must not be inserted twice.")
	TEST_ASSERT_EQUAL(cart.current_capacity, first.w_class, "Rejecting a duplicate must preserve capacity.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The cart/armour drop chain must not runtime.")

/// Count which component receives restoration; a removed piece must not regain its own boon.
/datum/component/armour_filtering/positive/unit_test_lifecycle
	var/equip_calls = 0

/datum/component/armour_filtering/positive/unit_test_lifecycle/trait_boon_equip(mob/living/carbon/human/user, id)
	equip_calls++

/datum/unit_test/armour_restores_remaining_component/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/removed = allocate(/obj/item/clothing)
	var/obj/item/clothing/remaining = allocate(/obj/item/clothing, user)
	ADD_TRAIT(user, TRAIT_PSYDONIAN_GRIT, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/component/armour_filtering/positive/unit_test_lifecycle/removed_filter = removed.AddComponent(/datum/component/armour_filtering/positive/unit_test_lifecycle, TRAIT_PSYDONIAN_GRIT, "removed")
	var/datum/component/armour_filtering/positive/unit_test_lifecycle/remaining_filter = remaining.AddComponent(/datum/component/armour_filtering/positive/unit_test_lifecycle, TRAIT_PSYDONIAN_GRIT, "remaining")
	remaining.item_flags |= IN_INVENTORY
	removed_filter.on_drop(removed, user)
	TEST_ASSERT_EQUAL(removed_filter.equip_calls, 0, "Dropping armour must never reapply that piece's boon.")
	TEST_ASSERT_EQUAL(remaining_filter.equip_calls, 1, "The surviving piece must restore its own boon.")

/datum/unit_test/flare_preview_cleanup/Run()
	var/obj/item/signal_flare_gun/loaded/preview_gun = allocate(/obj/item/signal_flare_gun/loaded)
	preview_gun.moveToNullspace()
	var/obj/item/signal_flare/preview_canister = preview_gun.canister
	TEST_ASSERT(preview_canister, "The preview gun must start loaded.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(preview_gun)
	TEST_ASSERT(QDELETED(preview_canister), "A canister with no world destination must be deleted with its preview gun.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Nullspace preview teardown must not call forceMove(null).")

	var/obj/item/signal_flare_gun/loaded/world_gun = allocate(/obj/item/signal_flare_gun/loaded)
	var/obj/item/signal_flare/world_canister = world_gun.canister
	allocated += world_canister
	qdel(world_gun)
	TEST_ASSERT(!QDELETED(world_canister), "Deleting a real gun must still drop its canister.")
	TEST_ASSERT_EQUAL(world_canister.loc, run_loc_floor_bottom_left, "The canister must be left on the gun's turf.")

/// An equip signal may consume a temporary item while put_in_hands is still running.
/obj/item/unit_test_equip_consumed/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	qdel(src)

/datum/unit_test/consumed_item_pickup/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/item = allocate(/obj/item/unit_test_equip_consumed)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(!user.put_in_hands(item), "An item consumed by equipped must report unsuccessful pickup.")
	TEST_ASSERT(QDELETED(item), "The fixture must be consumed by the equip callback.")
	TEST_ASSERT(!user.is_holding(item), "A consumed item must not remain in either hand.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Pickup must stop before retrying another hand or forceMove on the consumed item.")

/datum/unit_test/temporary_items_cannot_be_wrapped/Run()
	var/obj/item/melee/new_touch_attack/touch = allocate(/obj/item/melee/new_touch_attack)
	var/obj/item/melee/touch_attack/legacy_touch = allocate(/obj/item/melee/touch_attack)
	var/obj/item/ordinary = allocate(/obj/item)
	TEST_ASSERT(!touch.can_be_package_wrapped(), "A summoned touch must not enter the paper wrapping/drop chain.")
	TEST_ASSERT(!legacy_touch.can_be_package_wrapped(), "Legacy DROPDEL hands must not enter the wrapping/drop chain.")
	TEST_ASSERT(ordinary.can_be_package_wrapped(), "Ordinary physical items must remain wrappable.")

/// Observe accidental combat fallback without relying on random damage/skill calculations.
/obj/item/grown/log/tree/small/unit_test_lifecycle
	var/weapon_hits = 0

/obj/item/grown/log/tree/small/unit_test_lifecycle/attacked_by(obj/item/I, mob/living/user)
	weapon_hits++
	return TRUE

/datum/unit_test/cancelled_sawing_stops_attack/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/handsaw/saw = allocate(/obj/item/rogueweapon/handsaw)
	var/obj/item/grown/log/tree/small/unit_test_lifecycle/log = allocate(/obj/item/grown/log/tree/small/unit_test_lifecycle)
	// An action already in progress makes do_after refuse this operation immediately.
	user.doing = TRUE
	var/result = log.attackby(saw, user)
	user.doing = FALSE
	TEST_ASSERT(result, "A cancelled saw interaction must stop the attack chain.")
	TEST_ASSERT_EQUAL(log.weapon_hits, 0, "Cancelling plank production must not turn into a weapon hit on the log.")

/// Simulate an Exit/Bump callback breaking the seat while its occupant tries to move.
/mob/living/unit_test_breaking_seat/Move(atom/newloc, direct, glide_size_override)
	qdel(buckled)
	return FALSE

/datum/unit_test/broken_seat_movement/Run()
	var/obj/structure/chair/chair = allocate(/obj/structure/chair)
	var/mob/living/occupant = allocate(/mob/living/unit_test_breaking_seat)
	TEST_ASSERT(chair.buckle_mob(occupant, TRUE, FALSE), "The fixture must begin buckled to the chair.")
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(!chair.handle_buckled_mob_movement(get_step(run_loc_floor_bottom_left, NORTH), NORTH), "Breaking the seat must cancel its move.")
	TEST_ASSERT(QDELETED(chair), "The occupant's Move callback must break the chair.")
	TEST_ASSERT_NULL(occupant.buckled, "Breaking the chair must release its occupant.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The failed occupant move must not roll back a deleted chair with forceMove.")

/obj/projectile/unit_test_consumed_on_move
	var/range_calls = 0

/obj/projectile/unit_test_consumed_on_move/Move(atom/newloc, direct = NONE)
	qdel(src)
	return FALSE

/obj/projectile/unit_test_consumed_on_move/Range()
	range_calls++

/datum/unit_test/projectile_movement_lifecycle/Run()
	var/obj/projectile/unit_test_consumed_on_move/projectile = allocate(/obj/projectile/unit_test_consumed_on_move)
	projectile.trajectory = new /datum/point/vector(projectile.x, projectile.y, projectile.z, 0, 0, 90, world.icon_size)
	var/runtimes_before = GLOB.total_runtimes
	// Start on the final iteration, so a deleted projectile cannot be caught only by the next iteration's guard.
	var/old_iterations = SSprojectiles.global_iterations_per_move
	SSprojectiles.global_iterations_per_move = 1
	projectile.pixel_move(1, TRUE)
	SSprojectiles.global_iterations_per_move = old_iterations
	TEST_ASSERT(QDELETED(projectile), "The movement callback must consume the projectile.")
	TEST_ASSERT_EQUAL(projectile.range_calls, 0, "A consumed projectile must stop within the same pixel-movement iteration.")
	movable_travel_z_level(projectile, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A stale stair movement must not move a deleted projectile.")

/// Verify the supported mind lifecycle without replacing a missing sleep datum and losing banked XP.
/datum/unit_test/sleep_adv_mind_transfer/Run()
	var/mob/living/carbon/human/consistent/original_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/new_body = allocate(/mob/living/carbon/human/consistent)
	original_body.mind_initialize()
	var/datum/mind/player = original_body.mind
	allocated += player
	var/datum/sleep_adv/sleep = player.sleep_adv
	TEST_ASSERT(sleep, "Every newly initialized mind must own its sleep advancement datum.")
	original_body.adjust_skillrank_up_to(/datum/skill/misc/reading, SKILL_LEVEL_APPRENTICE, TRUE)
	sleep.sleep_exp[/datum/skill/misc/reading] = 125
	var/runtimes_before = GLOB.total_runtimes
	player.transfer_to(new_body)
	new_body.mind_initialize()
	TEST_ASSERT_EQUAL(player.sleep_adv, sleep, "Body transfer and resynchronization must preserve the original sleep datum.")
	TEST_ASSERT_EQUAL(sleep.mind, player, "Sleep advancement must continue to belong to the transferred mind.")
	TEST_ASSERT_EQUAL(sleep.get_sleep_xp(/datum/skill/misc/reading), 125, "Body transfer must preserve banked sleep XP.")
	player.add_sleep_experience(/datum/skill/misc/reading, 10, TRUE, FALSE)
	TEST_ASSERT(sleep.get_sleep_xp(/datum/skill/misc/reading) > 125, "The transferred mind must continue to earn sleep XP.")
	sleep.add_stress_cycle(0)
	new_body.print_levels()
	TEST_ASSERT_NULL(original_body.mind, "The former body must not keep using the transferred mind.")
	qdel(player)
	TEST_ASSERT(QDELETED(sleep), "Deleting the mind must clean up its sleep datum.")
	TEST_ASSERT_NULL(new_body.mind, "Mind deletion must detach the body from its deleted sleep state.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The supported mind lifecycle must not runtime.")
