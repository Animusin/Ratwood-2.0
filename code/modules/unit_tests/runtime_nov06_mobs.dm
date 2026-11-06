/// An environmental hit must not replace a valid enemy with a missing attacker.
/datum/unit_test/runtime_nov06_retaliation_target/Run()
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	npc.mode = NPC_AI_IDLE
	var/runtimes_before = GLOB.total_runtimes
	npc.retaliate(null)
	TEST_ASSERT_EQUAL(npc.mode, NPC_AI_IDLE, "An ownerless projectile must not start hunting a missing enemy.")
	TEST_ASSERT_NULL(npc.target, "An ownerless hit must leave the NPC without a target.")
	npc.retaliate(attacker)
	TEST_ASSERT_EQUAL(npc.target, attacker, "A living attacker must still become the retaliation target.")
	TEST_ASSERT_EQUAL(npc.mode, NPC_AI_HUNT, "A valid attacker must still start pursuit.")
	TEST_ASSERT(attacker in npc.enemies, "Retaliation must still register hostility.")
	npc.retaliate(null)
	npc.retaliate(npc)
	TEST_ASSERT_EQUAL(npc.target, attacker, "A missing attacker or self-hit must not replace the current target.")
	var/mob/living/deleted_attacker = allocate(/mob/living)
	qdel(deleted_attacker)
	npc.retaliate(deleted_attacker)
	TEST_ASSERT_EQUAL(npc.target, attacker, "A deleted attacker must not become a new pursuit target.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Retaliation must reject absent and deleted attackers before accessing them.")

/// Simulate a ride whose vertical transit finishes on a closed turf, as in the server log.
/datum/component/riding/runtime_nov06_destination
	var/atom/next_destination

/datum/component/riding/runtime_nov06_destination/handle_ride(mob/user, direction)
	var/atom/movable/mount = parent
	mount.forceMove(next_destination)
	return TRUE

/datum/unit_test/runtime_nov06_mount_closed_turf
	var/turf/changed_turf
	var/original_type
	var/original_baseturfs

/datum/unit_test/runtime_nov06_mount_closed_turf/Destroy()
	if(changed_turf)
		changed_turf.ChangeTurf(original_type, original_baseturfs)
	return ..()

/datum/unit_test/runtime_nov06_mount_closed_turf/Run()
	var/mob/living/simple_animal/hostile/mount = allocate(/mob/living/simple_animal/hostile)
	mount.tame = TRUE
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/riding/runtime_nov06_destination/riding = mount.AddComponent(/datum/component/riding/runtime_nov06_destination)
	changed_turf = run_loc_floor_top_right
	original_type = changed_turf.type
	original_baseturfs = islist(changed_turf.baseturfs) ? changed_turf.baseturfs.Copy() : changed_turf.baseturfs
	changed_turf = changed_turf.ChangeTurf(/turf/closed/wall/mineral/rogue/wooddark)
	var/runtimes_before = GLOB.total_runtimes
	for(var/movement_intent in list(MOVE_INTENT_RUN, MOVE_INTENT_WALK))
		mount.forceMove(run_loc_floor_bottom_left)
		mount.do_footstep = FALSE
		rider.m_intent = movement_intent
		riding.vehicle_move_delay = 999
		riding.next_destination = changed_turf
		mount.relaymove(rider, EAST)
		TEST_ASSERT_EQUAL(mount.loc, changed_turf, "The fixture must finish its ride on a closed turf.")
		TEST_ASSERT(!mount.do_footstep, "A wall has no floor footstep to play.")
		TEST_ASSERT(riding.vehicle_move_delay < 999, "A closed destination must not abort mounted movement delay updates.")
		riding.next_destination = run_loc_floor_bottom_left
		mount.relaymove(rider, WEST)
		TEST_ASSERT_EQUAL(mount.loc, run_loc_floor_bottom_left, "A normal ride must still reach the floor.")
		TEST_ASSERT(mount.do_footstep, "A normal floor must still play its alternating hoofstep.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Walking and running must not access open-floor fields on a wall.")

/// Keep matchmaking observable without generating an unrelated heritage tree.
/mob/living/carbon/human/consistent/runtime_nov06_newlywed/MarryTo(mob/living/carbon/human/spouse)
	spouse_mob = spouse
	spouse.spouse_mob = src

/datum/unit_test/runtime_nov06_newlywed_stale_candidate
	var/list/saved_viable_spouses

/datum/unit_test/runtime_nov06_newlywed_stale_candidate/Destroy()
	SSfamilytree.viable_spouses = saved_viable_spouses
	return ..()

/datum/unit_test/runtime_nov06_newlywed_stale_candidate/Run()
	saved_viable_spouses = SSfamilytree.viable_spouses
	SSfamilytree.viable_spouses = list()
	var/mob/living/carbon/human/consistent/runtime_nov06_newlywed/newcomer = allocate(/mob/living/carbon/human/consistent/runtime_nov06_newlywed)
	var/mob/living/carbon/human/consistent/runtime_nov06_newlywed/candidate = allocate(/mob/living/carbon/human/consistent/runtime_nov06_newlywed)
	var/mob/living/carbon/human/consistent/stale = allocate(/mob/living/carbon/human/consistent)
	newcomer.xenophobe = 1
	newcomer.gender_choice_pref = ANY_GENDER
	candidate.gender_choice_pref = ANY_GENDER
	stale.gender_choice_pref = ANY_GENDER
	SSfamilytree.viable_spouses += stale
	qdel(stale)
	// Deleted humans may retain an alive stat while their DNA is already cleared.
	TEST_ASSERT_NULL(stale.dna, "The stale candidate must reproduce the missing-DNA queue entry.")
	var/runtimes_before = GLOB.total_runtimes
	SSfamilytree.AssignNewlyWed(newcomer)
	TEST_ASSERT_NULL(newcomer.spouse_mob, "A deleted candidate must not become the newcomer's spouse.")
	TEST_ASSERT(!(stale in SSfamilytree.viable_spouses), "The spouse queue must release deleted candidates.")
	TEST_ASSERT(newcomer in SSfamilytree.viable_spouses, "A valid unmatched newcomer must remain available.")
	SSfamilytree.AssignNewlyWed(candidate)
	TEST_ASSERT_EQUAL(candidate.spouse_mob, newcomer, "Compatible living candidates must still be paired.")
	TEST_ASSERT_EQUAL(newcomer.spouse_mob, candidate, "The paired relationship must remain reciprocal.")
	TEST_ASSERT_EQUAL(length(SSfamilytree.viable_spouses), 0, "Both matched candidates must leave the queue.")
	SSfamilytree.AssignNewlyWed(stale)
	TEST_ASSERT_EQUAL(length(SSfamilytree.viable_spouses), 0, "A late callback for a deleted entrant must not repopulate the queue.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Matchmaking must not access DNA cleared during deletion.")
