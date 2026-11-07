/// Climbable obstacles pass the spells' precheck but still enter the real Bump path.
/obj/structure/runtime_nov07_leap_obstacle
	density = TRUE
	climbable = TRUE

/datum/unit_test/runtime_nov07_spell_leaps
	var/datum/action/cooldown/spell/current_spell
	var/mob/living/current_target
	var/scenario
	var/leap_source
	var/movement_events
	var/bump_events
	var/invalid_throwing
	var/missing_fall_protection
	var/missing_mob_pass

/datum/unit_test/runtime_nov07_spell_leaps/proc/observe_leap(mob/living/carbon/human/source)
	invalid_throwing = invalid_throwing || !isnull(source.throwing)
	missing_fall_protection = missing_fall_protection || !HAS_TRAIT_FROM(source, TRAIT_PREVENT_Z_FALL, leap_source)
	missing_mob_pass = missing_mob_pass || !(source.pass_flags & PASSMOB)

/datum/unit_test/runtime_nov07_spell_leaps/proc/on_move(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	movement_events++
	observe_leap(source)
	if(movement_events != 1)
		return
	switch(scenario)
		if("stunned")
			INVOKE_ASYNC(source, TYPE_PROC_REF(/mob/living, Stun), 2 SECONDS)
		if("removed_spell")
			qdel(current_spell)
		if("removed_target")
			current_target.moveToNullspace()

/datum/unit_test/runtime_nov07_spell_leaps/proc/on_bump(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	bump_events++
	observe_leap(source)

/datum/unit_test/runtime_nov07_spell_leaps/Run()
	var/turf/first_step = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/destination = get_step(get_step(get_step(first_step, EAST), EAST), EAST)
	TEST_ASSERT(destination.x <= run_loc_floor_top_right.x, "The leap fixture needs four open tiles east of the caster.")
	for(var/spell_type in list(/datum/action/cooldown/spell/advance, /datum/action/cooldown/spell/storm_of_psydon))
		for(var/test_scenario in list("ordinary", "blocked", "stunned", "removed_spell", "removed_target"))
			scenario = test_scenario
			var/is_storm = ispath(spell_type, /datum/action/cooldown/spell/storm_of_psydon)
			if(scenario == "removed_target" && !is_storm)
				continue
			var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
			var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, first_step)
			var/obj/item/rogueweapon/sword/weapon = allocate(/obj/item/rogueweapon/sword)
			TEST_ASSERT(caster.put_in_hands(weapon), "Advance's bound sword must actually be held.")
			var/datum/status_effect/buff/arcyne_momentum/momentum = caster.apply_status_effect(/datum/status_effect/buff/arcyne_momentum)
			momentum.bound_weapon = weapon
			momentum.add_stacks(7)
			current_spell = new spell_type
			allocated += current_spell
			current_spell.Grant(caster)
			leap_source = REF(current_spell)
			current_target = null
			if(is_storm)
				current_target = allocate(/mob/living/carbon/human/consistent, destination)
				ADD_TRAIT(current_target, TRAIT_ANTIMAGIC, "runtime_nov07_test")
			var/obj/structure/obstacle
			if(scenario == "blocked")
				obstacle = allocate(/obj/structure/runtime_nov07_leap_obstacle, first_step)
			var/old_pass = caster.pass_flags
			// Another source must survive both successful and interrupted leaps.
			ADD_TRAIT(caster, TRAIT_PREVENT_Z_FALL, "runtime_nov07_other_source")
			movement_events = 0
			bump_events = 0
			invalid_throwing = FALSE
			missing_fall_protection = FALSE
			missing_mob_pass = FALSE
			RegisterSignal(caster, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
			RegisterSignal(caster, COMSIG_MOVABLE_BUMP, PROC_REF(on_bump))
			var/runtimes_before = GLOB.total_runtimes
			current_spell.cast(is_storm ? current_target : destination)
			UnregisterSignal(caster, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_BUMP))
			TEST_ASSERT(!invalid_throwing, "[spell_type] ([scenario]) must never put a boolean in the thrownthing field during movement or collision.")
			TEST_ASSERT(!missing_fall_protection, "[spell_type] ([scenario]) must own its fall protection throughout the leap.")
			TEST_ASSERT(!missing_mob_pass, "[spell_type] ([scenario]) must still pass through mobs during the leap.")
			if(scenario == "blocked")
				TEST_ASSERT(bump_events > 0, "A climbable obstacle must exercise the real collision callback.")
				TEST_ASSERT_EQUAL(get_turf(caster), run_loc_floor_bottom_left, "A blocked leap must not move through dense structures.")
			else
				TEST_ASSERT(movement_events > 0, "The actual spell must move its caster through the bystander.")
				if(scenario == "ordinary")
					TEST_ASSERT_EQUAL(get_turf(caster), is_storm ? get_step(destination, WEST) : destination, "An uninterrupted leap must keep its range and targeting behavior.")
				else
					TEST_ASSERT_EQUAL(get_turf(caster), first_step, "An interrupted leap must stop after its first step.")
			TEST_ASSERT_EQUAL(caster.pass_flags, old_pass, "Landing must restore the caster's original pass flags.")
			TEST_ASSERT_NULL(caster.throwing, "Landing must not create or retain a fake throw.")
			TEST_ASSERT(!HAS_TRAIT_FROM(caster, TRAIT_PREVENT_Z_FALL, leap_source), "Landing or interruption must release the spell's fall protection.")
			TEST_ASSERT(HAS_TRAIT_FROM(caster, TRAIT_PREVENT_Z_FALL, "runtime_nov07_other_source"), "A leap must not remove another effect's fall protection.")
			REMOVE_TRAIT(caster, TRAIT_PREVENT_Z_FALL, "runtime_nov07_other_source")
			TEST_ASSERT(caster.can_zFall(get_turf(caster), 1, first_step, DOWN), "After landing the caster must be eligible for ordinary falling again.")
			TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "[spell_type] ([scenario]) must not crash in movement, Bump or interruption cleanup.")
			qdel(current_spell)
			qdel(current_target)
			qdel(obstacle)
			qdel(bystander)
			qdel(caster)
			qdel(weapon)
	current_spell = null
	current_target = null

/// A vanished summon is alive in nullspace; checking QDELETED alone cannot reject it.
/datum/unit_test/runtime_nov07_hybrid_nullspace/Run()
	var/mob/living/carbon/human/pawn = allocate(/mob/living/carbon/human/consistent)
	var/obj/target = allocate(/obj, run_loc_floor_top_right)
	var/datum/ai_controller/controller = new(pawn)
	allocated += controller
	controller.set_ai_status(AI_STATUS_OFF)
	controller.max_target_distance = 0
	var/datum/ai_movement/hybrid_pathing/movement = new
	allocated += movement
	controller.ai_movement = movement
	var/runtimes_before = GLOB.total_runtimes
	for(var/scenario in list("target", "pawn", "deleted_target"))
		pawn.forceMove(run_loc_floor_bottom_left)
		if(QDELETED(target))
			target = allocate(/obj, run_loc_floor_top_right)
		else
			target.forceMove(run_loc_floor_top_right)
		controller.set_movement_target(type, target)
		movement.start_moving_towards(controller, target, 0)
		controller.movement_path = list(get_step(run_loc_floor_bottom_left, EAST))
		controller.set_blackboard_key(BB_FUTURE_MOVEMENT_PATH, list(run_loc_floor_top_right))
		movement.fallbacking_by_controller[controller] = TRUE
		movement.fallback_failures_by_controller[controller] = 1
		if(scenario == "target")
			target.moveToNullspace()
		else if(scenario == "pawn")
			pawn.moveToNullspace()
		else
			qdel(target)
		// Invalid endpoints must be cleared even while the next movement is on cooldown.
		COOLDOWN_START(controller, movement_cooldown, 1 SECONDS)
		movement.process(1)
		TEST_ASSERT_NULL(controller.current_movement_target, "A [scenario] without a turf must cancel the pursuit.")
		TEST_ASSERT(!length(controller.movement_path), "Cancelling an invalid pursuit must clear its current path.")
		TEST_ASSERT(!controller.blackboard[BB_FUTURE_MOVEMENT_PATH], "Cancelling an invalid pursuit must clear its future path.")
		TEST_ASSERT(!(controller in movement.moving_controllers), "The invalid controller must leave movement processing.")
		TEST_ASSERT(!(controller in movement.fallbacking_by_controller), "Cancelling pursuit must clear fallback state.")
		TEST_ASSERT(!(controller in movement.fallback_failures_by_controller), "Cancelling pursuit must clear fallback failures.")
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Nullspace endpoints must not reach AStar's invalid-start/destination error.")
	pawn.forceMove(run_loc_floor_bottom_left)
	// A cardinal target makes one legitimate step reduce Chebyshev distance.
	// With the diagonal corner target, either cardinal first step can leave get_dist unchanged.
	target = allocate(/obj, get_step(get_step(run_loc_floor_bottom_left, EAST), EAST))
	controller.set_movement_target(type, target)
	movement.start_moving_towards(controller, target, 0)
	COOLDOWN_RESET(controller, movement_cooldown)
	TEST_ASSERT(controller.can_move(), "The valid-path fixture must be able to move after returning from nullspace.")
	var/turf/start_turf = get_turf(pawn)
	var/distance_before = get_dist(pawn, target)
	movement.process(1)
	TEST_ASSERT_EQUAL(controller.current_movement_target, target, "A valid target must remain selected.")
	TEST_ASSERT(controller in movement.moving_controllers, "Valid pursuits must remain registered for movement.")
	TEST_ASSERT(get_turf(pawn) != start_turf, "Hybrid pathing must take an actual step toward a valid target.")
	TEST_ASSERT(get_dist(pawn, target) < distance_before, "Hybrid pathing must still advance toward a cardinal target.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Normal hybrid movement must remain free of runtime errors.")
	movement.stop_moving_towards(controller)
	qdel(controller)
