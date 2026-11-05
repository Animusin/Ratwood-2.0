/// Keep impact selection deterministic while exercising the real Crossed -> Bump chain.
/obj/projectile/runtime_nov05_collision
	var/hit_calls = 0
	var/atom/last_hit

/obj/projectile/runtime_nov05_collision/can_hit_target(atom/target, list/passthrough, direct_target = FALSE, ignore_loc = FALSE)
	return TRUE

/obj/projectile/runtime_nov05_collision/process_hit(turf/location, atom/target, qdel_self, hit_something = FALSE)
	hit_calls++
	last_hit = target
	return TRUE

/datum/unit_test/runtime_nov05_projectile_collision/Run()
	var/obj/projectile/runtime_nov05_collision/projectile = allocate(/obj/projectile/runtime_nov05_collision)
	var/mob/living/target = allocate(/mob/living)
	var/runtimes_before = GLOB.total_runtimes
	projectile.Crossed(target)
	projectile.Bump(target)
	TEST_ASSERT_EQUAL(projectile.hit_calls, 0, "An unfired projectile must not collide with a passerby.")
	projectile.fired = TRUE
	projectile.Crossed(target)
	projectile.Bump(target)
	TEST_ASSERT_EQUAL(projectile.hit_calls, 0, "A projectile without a trajectory must not process an impact.")
	projectile.trajectory = new /datum/point/vector(projectile.x, projectile.y, projectile.z, 0, 0, 90, world.icon_size)
	projectile.Crossed(target)
	TEST_ASSERT_EQUAL(projectile.hit_calls, 1, "Crossing a live flying projectile must still deliver its impact.")
	TEST_ASSERT_EQUAL(projectile.last_hit, target, "The impact must select the crossing mob.")
	qdel(projectile)
	projectile.Crossed(target)
	projectile.Bump(target)
	TEST_ASSERT_EQUAL(projectile.hit_calls, 1, "A callback arriving after projectile deletion must not deliver another impact.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Unfired, trajectory-less and deleted collision callbacks must not runtime.")

/mob/living/carbon/human/consistent/runtime_nov05_thief
	var/steal_calls = 0

/mob/living/carbon/human/consistent/runtime_nov05_thief/attempt_steal(mob/living/carbon/human/thief, mob/living/carbon/human/victim)
	steal_calls++

/datum/unit_test/runtime_nov05_weak_target/Run()
	var/mob/living/carbon/human/consistent/runtime_nov05_thief/thief = allocate(/mob/living/carbon/human/consistent/runtime_nov05_thief)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/rmb_intent/weak/intent = new
	allocated += intent
	var/runtimes_before = GLOB.total_runtimes
	intent.special_attack(thief, null)
	intent.special_attack(thief, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(thief.steal_calls, 0, "Missing and non-human targets must not reach stealing.")
	intent.special_attack(thief, victim)
	TEST_ASSERT_EQUAL(thief.steal_calls, 1, "A nearby human must retain the weak-RMB stealing action.")
	qdel(victim)
	intent.special_attack(thief, victim)
	TEST_ASSERT_EQUAL(thief.steal_calls, 1, "A deleted target must not start a new steal attempt.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Weak RMB must validate the target before checking adjacency.")

/mob/living/runtime_nov05_kick_target
	var/defense_calls = 0
	var/kick_calls = 0

/mob/living/runtime_nov05_kick_target/checkmiss(mob/living/user)
	return FALSE

/mob/living/runtime_nov05_kick_target/checkdefense(datum/intent/intent, mob/living/attacker)
	defense_calls++
	return FALSE

/mob/living/runtime_nov05_kick_target/onkick(mob/user)
	kick_calls++

/datum/unit_test/runtime_nov05_kick_lifecycle
	var/mob/living/kicker

/datum/unit_test/runtime_nov05_kick_lifecycle/proc/interrupt_kick(datum/source)
	SIGNAL_HANDLER
	kicker.mmb_intent = null

/datum/unit_test/runtime_nov05_kick_lifecycle/Run()
	kicker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/runtime_nov05_kick_target/target = allocate(/mob/living/runtime_nov05_kick_target)
	var/datum/intent/kick/intent = allocate(/datum/intent/kick, kicker)
	kicker.mmb_intent = intent
	intent.swingdelay = 2
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(!kicker.try_kick(null), "Kicking a missing target must be rejected before adjacency checks.")
	addtimer(CALLBACK(src, PROC_REF(interrupt_kick)), 1)
	TEST_ASSERT(!kicker.try_kick(target), "Losing the selected intent during wind-up must cancel a kick.")
	TEST_ASSERT_EQUAL(target.defense_calls, 0, "An interrupted wind-up must never pass a missing intent to defense.")
	kicker.mmb_intent = intent
	intent.swingdelay = 0
	RegisterSignal(target, COMSIG_MOB_KICKED, PROC_REF(interrupt_kick))
	TEST_ASSERT(!kicker.try_kick(target), "A kick reaction that removes the intent must cancel the pending attack.")
	TEST_ASSERT_EQUAL(target.defense_calls, 0, "A kick reaction must be revalidated before defense.")
	UnregisterSignal(target, COMSIG_MOB_KICKED)
	kicker.mmb_intent = intent
	TEST_ASSERT(kicker.try_kick(target), "An uninterrupted kick must still succeed.")
	TEST_ASSERT_EQUAL(target.defense_calls, 1, "A normal kick must still run defense exactly once.")
	TEST_ASSERT_EQUAL(target.kick_calls, 1, "A normal kick must still reach the target callback.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Kick intent changes must not produce missing-intent runtimes.")

/// Remove the attacker's intent inside the real damage application callback.
/mob/living/simple_animal/runtime_nov05_animal_target
	var/mob/living/simple_animal/attacker_to_interrupt
	var/last_wound_class
	var/wound_calls = 0

/mob/living/simple_animal/runtime_nov05_animal_target/checkmiss(mob/living/user)
	return FALSE

/mob/living/simple_animal/runtime_nov05_animal_target/checkdefense(datum/intent/intent, mob/living/attacker)
	return FALSE

/mob/living/simple_animal/runtime_nov05_animal_target/attack_threshold_check(damage, bodypart = null, damagetype = BRUTE, armorcheck = 0)
	. = ..()
	if(attacker_to_interrupt)
		attacker_to_interrupt.a_intent = null

/mob/living/simple_animal/runtime_nov05_animal_target/simple_woundcritroll(bclass = BCLASS_BLUNT, dam, mob/living/user, zone_precise = BODY_ZONE_CHEST, silent = FALSE, crit_message = FALSE, obj/item/weapon, ranged, penfactor, part_mult)
	last_wound_class = bclass
	wound_calls++
	return FALSE

/datum/unit_test/runtime_nov05_animal_intent/Run()
	var/mob/living/simple_animal/attacker = allocate(/mob/living/simple_animal)
	var/mob/living/simple_animal/runtime_nov05_animal_target/target = allocate(/mob/living/simple_animal/runtime_nov05_animal_target)
	var/datum/intent/simple/headbutt/intent = allocate(/datum/intent/simple/headbutt, attacker)
	attacker.a_intent = intent
	attacker.used_intent = intent
	attacker.melee_damage_lower = 5
	attacker.melee_damage_upper = 5
	target.attacker_to_interrupt = attacker
	var/health_before = target.health
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(target.attack_animal(attacker), "The hit must complete even if its damage callback removes the attacker's intent.")
	TEST_ASSERT_NULL(attacker.a_intent, "The fixture must remove the intent during damage application.")
	TEST_ASSERT(target.health < health_before, "The completed attack must still apply damage.")
	TEST_ASSERT_EQUAL(target.last_wound_class, BCLASS_BLUNT, "Wounds must use the intent selected for this attack.")
	TEST_ASSERT_EQUAL(target.wound_calls, 1, "The completed attack must roll wounds once.")
	target.attacker_to_interrupt = null
	attacker.a_intent = intent
	TEST_ASSERT(target.attack_animal(attacker), "A normal animal attack must remain functional.")
	TEST_ASSERT_EQUAL(target.wound_calls, 2, "A normal hit must still reach wound processing.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Damage callbacks must not cause a null blade_class access.")

/datum/unit_test/runtime_nov05_falling_powder/Run()
	var/obj/item/reagent_containers/powder/ozium/falling = allocate(/obj/item/reagent_containers/powder/ozium)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	falling.throw_impact(run_loc_floor_bottom_left)
	TEST_ASSERT(!QDELETED(falling), "A fall without an aimed throw must not count as a nose hit.")
	var/obj/item/reagent_containers/powder/ozium/aimed = allocate(/obj/item/reagent_containers/powder/ozium)
	var/datum/thrownthing/throw_data = new(aimed, target, get_turf(target), NORTH, 1, 1, null, FALSE, MOVE_FORCE_DEFAULT, null, BODY_ZONE_PRECISE_NOSE)
	allocated += throw_data
	aimed.throw_impact(target, throw_data)
	TEST_ASSERT(QDELETED(aimed), "A deliberate nose hit must still consume the thrown powder.")
	TEST_ASSERT(target.reagents.has_reagent(/datum/reagent/ozium), "A deliberate nose hit must still transfer its reagent.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Falling and deliberately thrown powders must both complete without runtimes.")

/mob/living/simple_animal/hostile/rogue/dreamfiend/runtime_nov05_finish
	var/mob/blink_target
	var/return_calls = 0

/mob/living/simple_animal/hostile/rogue/dreamfiend/runtime_nov05_finish/blink_to_target(mob/target)
	blink_target = target
	return TRUE

/mob/living/simple_animal/hostile/rogue/dreamfiend/runtime_nov05_finish/return_to_abyssor()
	return_calls++

/datum/unit_test/runtime_nov05_abyssal_finish/Run()
	var/mob/living/simple_animal/hostile/rogue/dreamfiend/runtime_nov05_finish/fiend = allocate(/mob/living/simple_animal/hostile/rogue/dreamfiend/runtime_nov05_finish)
	var/datum/ai_controller/controller = fiend.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/main_target = allocate(/mob/living)
	var/mob/living/retaliation_target = allocate(/mob/living)
	var/runtimes_before = GLOB.total_runtimes
	for(var/behavior_type in list(/datum/ai_behavior/basic_melee_attack/abyssal, /datum/ai_behavior/kick))
		var/datum/ai_behavior/behavior = new behavior_type()
		allocated += behavior
		controller.set_blackboard_key(BB_MAIN_TARGET, main_target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, retaliation_target)
		fiend.blink_target = null
		behavior.finish_action(controller, FALSE, BB_BASIC_MOB_CURRENT_TARGET)
		TEST_ASSERT_EQUAL(fiend.blink_target, main_target, "Finishing retaliation must blink to the living main target, not the expired temporary target.")
		TEST_ASSERT_EQUAL(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], main_target, "Finishing retaliation must restore the main target.")
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, retaliation_target)
		controller.UnpossessPawn(FALSE)
		behavior.finish_action(controller, FALSE, BB_BASIC_MOB_CURRENT_TARGET)
		// Restore ownership for fixture cleanup without registering a second set of movement signals.
		controller.pawn = fiend
		fiend.ai_controller = controller
		TEST_ASSERT_NULL(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "Detached-pawn cancellation must still clear its obsolete target.")
		controller.clear_blackboard_key(BB_MAIN_TARGET)
		var/returns_before = fiend.return_calls
		behavior.finish_action(controller, FALSE, BB_BASIC_MOB_CURRENT_TARGET)
		TEST_ASSERT_EQUAL(fiend.return_calls, returns_before + 1, "A possessed fiend without a main target must still return to Abyssor.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Finishing melee and kick actions after unpossession must not dereference a missing pawn.")

/mob/living/carbon/human/consistent/runtime_nov05_path
	var/list/replacement_path
	var/clear_during_jump = FALSE

/mob/living/carbon/human/consistent/runtime_nov05_path/npc_try_jump()
	if(clear_during_jump)
		myPath.Cut()
	if(replacement_path)
		myPath = replacement_path
	return FALSE

/datum/unit_test/runtime_nov05_npc_path_reentry/Run()
	var/mob/living/carbon/human/consistent/runtime_nov05_path/npc = allocate(/mob/living/carbon/human/consistent/runtime_nov05_path)
	var/turf/next_turf = get_step(run_loc_floor_bottom_left, NORTH)
	var/turf/other_turf = get_step(run_loc_floor_bottom_left, EAST)
	npc.maxStepsTick = 1
	npc.steps_moved_this_turn = 0
	npc.myPath = list(next_turf)
	npc.pathfinding_target = next_turf
	npc.clear_during_jump = TRUE
	var/runtimes_before = GLOB.total_runtimes
	npc.move_along_path()
	TEST_ASSERT_EQUAL(length(npc.myPath), 0, "A route cleared by a jump callback must remain cleared.")
	TEST_ASSERT_EQUAL(npc.loc, run_loc_floor_bottom_left, "Clearing the route must stop movement before reading its first entry.")
	npc.clear_during_jump = FALSE
	npc.myPath = list(next_turf)
	npc.replacement_path = list(other_turf)
	npc.move_along_path()
	TEST_ASSERT_EQUAL(npc.loc, run_loc_floor_bottom_left, "Replacing a route during a callback must end the old movement operation.")
	TEST_ASSERT_EQUAL(npc.myPath[1], other_turf, "The old movement operation must not consume the replacement route.")
	npc.replacement_path = null
	npc.myPath = list(next_turf)
	TEST_ASSERT_EQUAL(npc.move_along_path(), 1, "An unchanged valid path must still advance one step.")
	TEST_ASSERT_EQUAL(npc.loc, next_turf, "Normal path movement must reach the requested tile.")
	TEST_ASSERT_EQUAL(length(npc.myPath), 0, "A completed normal step must remove its waypoint.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Clearing or replacing a path inside movement must not index an empty list.")
