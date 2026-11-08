/// Observe the real base AI without random combat, idle wandering or resistance actions.
/mob/living/carbon/human/consistent/npc_processing_probe
	var/incap_checks = 0
	var/cone_updates = 0
	var/combat_calls = 0
	var/resist_calls = 0
	var/stand_calls = 0
	npc_jump_chance = 0
	wander = FALSE

/mob/living/carbon/human/consistent/npc_processing_probe/IsDeadOrIncap(checkDead = TRUE)
	incap_checks++
	return ..()

/mob/living/carbon/human/consistent/npc_processing_probe/update_cone_show()
	cone_updates++

/mob/living/carbon/human/consistent/npc_processing_probe/handle_combat()
	combat_calls++
	return TRUE

/mob/living/carbon/human/consistent/npc_processing_probe/resist()
	resist_calls++

/mob/living/carbon/human/consistent/npc_processing_probe/npc_stand()
	stand_calls++

/// A distant idle NPC keeps its registration, but no longer runs the costly base behavior.
/datum/unit_test/npc_sleep_fastpath/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()
	for(var/i in 1 to 20)
		SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.incap_checks, 0, "Twenty sleeping turns must not run incapacitation checks.")
	TEST_ASSERT_EQUAL(npc.cone_updates, 0, "A sleeping idle NPC must not repeatedly update its cone.")
	TEST_ASSERT_EQUAL(npc.combat_calls, 0, "A sleeping idle NPC must not run combat selection.")
	TEST_ASSERT(npc in SShumannpc.processing, "Sleep optimization must preserve registration for direct state changes.")
	TEST_ASSERT(!npc.ai_currently_active, "A skipped turn must release the asynchronous processing guard.")

	npc.on_client_enter(null, null)
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.mode, NPC_AI_IDLE, "A nearby client must still wake the NPC.")
	TEST_ASSERT_EQUAL(npc.incap_checks, 1, "An awake targetless turn needs its initial state check only.")
	TEST_ASSERT_EQUAL(npc.cone_updates, 1, "Awakening must restore normal cone updates.")
	TEST_ASSERT_EQUAL(npc.combat_calls, 1, "Awakening must restore combat selection.")

/// Direct targets, path requests and item work must not require a new scheduler registration.
/datum/unit_test/npc_sleep_pending_work/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/item = allocate(/obj/item)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()

	npc.target = target
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.combat_calls, 1, "A target assigned directly must bypass the sleeping fast path.")
	npc.target = null
	npc.pathfinding_target = run_loc_floor_top_right
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.combat_calls, 2, "A pending path target must remain active.")
	npc.pathfinding_target = null
	npc.is_currently_pathing = TRUE
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.combat_calls, 3, "An outstanding path calculation must remain active.")
	npc.is_currently_pathing = FALSE
	npc.pickupTarget = item
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.combat_calls, 4, "Pending item work must remain active.")
	npc.pickupTarget = null
	npc.mode = NPC_AI_HUNT
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.combat_calls, 5, "A direct mode change must take effect on the next scheduled turn.")
	TEST_ASSERT(npc in SShumannpc.processing, "All pending-work transitions must keep the NPC scheduled.")

/// Sleep must not suppress escaping fire, restraints or buckles, standing up, or dead-NPC removal.
/datum/unit_test/npc_sleep_danger_and_death/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	var/obj/item/cuffs = allocate(/obj/item)
	var/obj/structure/chair/seat = allocate(/obj/structure/chair)
	var/mob/living/carbon/human/consistent/puller = allocate(/mob/living/carbon/human/consistent)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()
	npc.on_fire = TRUE
	SShumannpc.try_process_ai(npc)
	npc.on_fire = FALSE
	TEST_ASSERT_EQUAL(npc.resist_calls, 1, "A burning sleeping NPC must still try to resist.")
	npc.handcuffed = cuffs
	SShumannpc.try_process_ai(npc)
	npc.handcuffed = null
	TEST_ASSERT_EQUAL(npc.resist_calls, 2, "A restrained sleeping NPC must still try to escape.")
	npc.buckled = seat
	SShumannpc.try_process_ai(npc)
	npc.buckled = null
	TEST_ASSERT_EQUAL(npc.resist_calls, 3, "A buckled sleeping NPC must still try to escape.")
	npc.pulledby = puller
	SShumannpc.try_process_ai(npc)
	npc.pulledby = null
	TEST_ASSERT_EQUAL(npc.resist_calls, 4, "A grabbed sleeping NPC must retain its resistance behavior.")
	var/original_mobility = npc.mobility_flags
	npc.mobility_flags = (original_mobility | MOBILITY_CANSTAND) & ~MOBILITY_STAND
	SShumannpc.try_process_ai(npc)
	npc.mobility_flags = original_mobility
	TEST_ASSERT_EQUAL(npc.stand_calls, 1, "A prone sleeping NPC must still attempt to stand.")
	var/original_health = npc.health
	var/original_stat = npc.stat
	npc.health = 0
	npc.stat = DEAD
	SShumannpc.try_process_ai(npc)
	npc.health = original_health
	npc.stat = original_stat
	TEST_ASSERT(!(npc in SShumannpc.processing), "A dead sleeping NPC must still leave AI processing.")

/// Stun leaves a human standing, but must still reach the incapacitation cleanup branch.
/datum/unit_test/npc_sleep_incapacitated/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()
	npc.Stun(10 SECONDS, ignore_canstun = TRUE)
	TEST_ASSERT(npc.IsStun() && (npc.mobility_flags & MOBILITY_STAND), "The regression fixture must be stunned while still standing.")
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.incap_checks, 1, "A standing stunned sleeper must reach its incapacitation cleanup.")
	TEST_ASSERT_EQUAL(npc.cone_updates, 0, "An incapacitated NPC must not continue its active turn.")
	TEST_ASSERT(npc in SShumannpc.processing, "A stunned NPC must remain scheduled for recovery.")
	npc.SetStun(0, ignore_canstun = TRUE)
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.incap_checks, 1, "After recovery, a sleeping idle NPC may skip base behavior again.")
	var/original_mobility = npc.mobility_flags
	npc.mobility_flags &= ~MOBILITY_FLAGS_INTERACTION
	SShumannpc.try_process_ai(npc)
	npc.mobility_flags = original_mobility
	TEST_ASSERT_EQUAL(npc.incap_checks, 2, "Missing interaction mobility must retain the original incapacitation branch.")

/// Types with meaningful offscreen base-turn behavior can opt out of idle skipping.
/datum/unit_test/npc_sleep_behavior_optout/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	npc.mode = NPC_AI_SLEEP
	npc.ai_process_while_sleeping = TRUE
	npc.handle_ai()
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.incap_checks, 1, "An opted-out sleeping NPC must retain its normal state check.")
	TEST_ASSERT_EQUAL(npc.cone_updates, 1, "An opted-out sleeping NPC must retain its normal base turn.")
	TEST_ASSERT_EQUAL(npc.combat_calls, 1, "Offscreen custom behavior must still run when opted out.")

/// A hit must retain the real retaliation transition and a sleeping NPC's existing route must advance.
/datum/unit_test/npc_sleep_retaliation_and_movement/Run()
	var/mob/living/carbon/human/consistent/npc_processing_probe/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()
	npc.retaliate(attacker)
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.target, attacker, "Retaliation must retain the attacker.")
	TEST_ASSERT_EQUAL(npc.mode, NPC_AI_HUNT, "Retaliation must wake pursuit.")
	TEST_ASSERT_EQUAL(npc.combat_calls, 1, "A hit must restore base AI processing.")
	npc.target = null
	npc.mode = NPC_AI_SLEEP
	npc.maxStepsTick = 1
	var/turf/destination = get_step(run_loc_floor_bottom_left, NORTH)
	npc.myPath = list(destination)
	npc.pathfinding_target = destination
	// The real movement proc yields after its step; invoke directly to await its completion.
	npc.process_ai()
	TEST_ASSERT_EQUAL(npc.loc, destination, "An existing route must still move a sleeping NPC.")
	TEST_ASSERT(!length(npc.myPath), "The completed route step must be consumed.")

/// Keep the real async scheduler but deterministically hold one turn across a wakeup.
/mob/living/carbon/human/consistent/npc_processing_probe/delayed
	var/entered_turns = 0
	var/completed_turns = 0

/mob/living/carbon/human/consistent/npc_processing_probe/delayed/process_ai()
	entered_turns++
	sleep(2)
	. = ..()
	completed_turns++

/datum/npc_processing_test_context
	var/old_can_fire

/datum/npc_processing_test_context/New()
	old_can_fire = SShumannpc.can_fire
	SShumannpc.can_fire = FALSE

/datum/npc_processing_test_context/Destroy()
	SShumannpc.can_fire = old_can_fire
	return ..()

/datum/unit_test/npc_sleep_async_wakeup/Run()
	var/datum/npc_processing_test_context/context = allocate(/datum/npc_processing_test_context)
	var/mob/living/carbon/human/consistent/npc_processing_probe/delayed/npc = allocate(/mob/living/carbon/human/consistent/npc_processing_probe/delayed)
	npc.mode = NPC_AI_SLEEP
	npc.handle_ai()
	SShumannpc.try_process_ai(npc)
	var/active_while_sleeping = npc.ai_currently_active
	npc.on_client_enter(null, null)
	SShumannpc.try_process_ai(npc)
	var/entered_during_wakeup = npc.entered_turns
	sleep(3)
	var/first_completed = npc.completed_turns
	var/active_after_completion = npc.ai_currently_active
	var/still_registered = (npc in SShumannpc.processing)
	SShumannpc.try_process_ai(npc)
	sleep(3)
	var/second_completed = npc.completed_turns
	qdel(context)
	TEST_ASSERT(active_while_sleeping, "The pending AI call must hold its asynchronous guard.")
	TEST_ASSERT_EQUAL(entered_during_wakeup, 1, "Waking during a yielded turn must not start overlapping AI.")
	TEST_ASSERT_EQUAL(first_completed, 1, "The interrupted sleeping turn must finish normally after wakeup.")
	TEST_ASSERT(!active_after_completion && still_registered, "Wakeup must neither strand the async guard nor remove the registration.")
	TEST_ASSERT_EQUAL(second_completed, 2, "The next awake turn must remain schedulable.")

/// Summoned skeletons have command state separate from the base NPC target/path fields.
/datum/unit_test/npc_sleep_summoned_command/Run()
	var/mob/living/carbon/human/species/skeleton/npc/summoned/npc = allocate(/mob/living/carbon/human/species/skeleton/npc/summoned)
	npc.mode = NPC_AI_SLEEP
	npc.set_command("move", run_loc_floor_bottom_left)
	npc.handle_ai()
	SShumannpc.try_process_ai(npc)
	TEST_ASSERT_EQUAL(npc.command_mode, "idle", "A summoned skeleton must still finish a command while base AI is asleep.")
	TEST_ASSERT_NULL(npc.command_target, "Finishing the summon command must clear its destination.")
