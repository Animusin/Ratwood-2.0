/// The fixture owns its hierarchy; release its reciprocal links during test cleanup.
/datum/clan_hierarchy_node/unit_test_nov06_cleanup/Destroy()
	if(assigned_member?.clan_position == src)
		assigned_member.clan_position = null
	assigned_member = null
	superior = null
	subordinates.Cut()
	return ..()

/// A bare hierarchy is enough to exercise the real action without embracing either human.
/datum/unit_test/proc/prepare_nov06_locate(mob/living/carbon/human/leader, mob/living/carbon/human/subordinate)
	// Bare datums have no argument-taking New(); allocate() always supplies a turf.
	var/datum/clan/clan = new
	allocated += clan
	var/datum/clan_hierarchy_node/leader_position = allocate(/datum/clan_hierarchy_node/unit_test_nov06_cleanup, "Leader", "Test leader", 0)
	var/datum/clan_hierarchy_node/subordinate_position = allocate(/datum/clan_hierarchy_node/unit_test_nov06_cleanup, "Subordinate", "Test subordinate", 1)
	leader.clan = clan
	leader.clan_position = leader_position
	leader_position.assigned_member = leader
	leader_position.add_subordinate(subordinate_position)
	subordinate_position.assigned_member = subordinate
	var/datum/action/clan_hierarchy/locate_subordinate/action = allocate(/datum/action/clan_hierarchy/locate_subordinate)
	action.Grant(leader)
	return action

/datum/unit_test/runtime_nov06_locate_nullspace_subordinate/Run()
	var/mob/living/carbon/human/leader = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/subordinate = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/clan_hierarchy/locate_subordinate/action = prepare_nov06_locate(leader, subordinate)
	subordinate.moveToNullspace()
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(!action.Trigger(), "A subordinate without a turf cannot be located.")
	TEST_ASSERT_EQUAL(action.cooldown, 0, "An empty search must not consume the locate cooldown.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Locating a nullspace subordinate must not read null.z.")

	// Containment is valid when the containing object itself is on the map.
	var/obj/container = allocate(/obj, run_loc_floor_top_right)
	subordinate.forceMove(container)
	TEST_ASSERT(action.IsAvailable(), "A placed subordinate must still make the action available.")
	TEST_ASSERT(action.Trigger(), "A subordinate inside a placed container must still be located.")
	TEST_ASSERT_EQUAL(action.cooldown, world.time + action.cooldown_time, "A successful search must keep its normal cooldown.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A valid located subordinate must not cause runtimes.")

/datum/unit_test/runtime_nov06_locate_stale_subordinate/Run()
	var/mob/living/carbon/human/leader = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/subordinate = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/clan_hierarchy/locate_subordinate/action = prepare_nov06_locate(leader, subordinate)
	qdel(subordinate)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(!action.IsAvailable(), "A deleted member in a hierarchy must not make Locate Subordinate available.")
	TEST_ASSERT(!action.Trigger(), "A stale action click must reject a deleted subordinate.")
	TEST_ASSERT_EQUAL(action.cooldown, 0, "A deleted subordinate must not consume the cooldown.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A stale assigned member must not cause a locate runtime.")

/datum/unit_test/runtime_nov06_locate_unavailable_owner/Run()
	var/mob/living/carbon/human/leader = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/subordinate = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/clan_hierarchy/locate_subordinate/action = prepare_nov06_locate(leader, subordinate)
	var/runtimes_before = GLOB.total_runtimes
	action.cooldown = world.time + 500
	var/original_cooldown = action.cooldown
	TEST_ASSERT(!action.Trigger(), "An unavailable action must respect its parent's failed Trigger result.")
	TEST_ASSERT_EQUAL(action.cooldown, original_cooldown, "Clicking during cooldown must not perform another search or replace the cooldown.")
	action.cooldown = 0
	leader.moveToNullspace()
	TEST_ASSERT(!action.Trigger(), "A leader without a turf must not attempt a distance calculation.")
	TEST_ASSERT_EQUAL(action.cooldown, 0, "A leader outside the map must not consume the cooldown.")
	qdel(leader)
	TEST_ASSERT_NULL(action.owner, "The real action must detach from its deleted owner.")
	TEST_ASSERT(!action.Trigger(), "A detached action must reject late clicks.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A stale owner must not cause clan or distance runtimes.")
