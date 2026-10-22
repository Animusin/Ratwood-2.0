/// A rolled Assassin option must open jobs without reserving the same cap twice.
/datum/unit_test/assassin_slots
	var/saved_policy
	var/list/saved_mode_state
	var/list/saved_job_state
	var/datum/job/roguetown/assassin/assassin_job

/datum/unit_test/assassin_slots/New()
	. = ..()
	saved_policy = CONFIG_GET(string/round_modifier_policy)
	saved_mode_state = list()
	for(var/field in list("active_modifiers", "rolled_villain_events", "round_modifier_policy_name", "roundstart_reserved_antag_weight", "planned_villain_counts", "planned_villain_weights", "queued_villains", "roundstart_antag_allocation_complete", "admin_antag_cap", "antagonists_disabled", "halted_storyteller", "current_storyteller"))
		saved_mode_state[field] = SSgamemode.vars[field]
	assassin_job = SSjob.GetJobType(/datum/job/roguetown/assassin)
	saved_job_state = list()
	if(assassin_job)
		for(var/field in list("total_positions", "spawn_positions", "current_positions", "admin_position_limit", "admin_slot_antag_type", "admin_antag_slots"))
			saved_job_state[field] = assassin_job.vars[field]

/datum/unit_test/assassin_slots/Destroy()
	CONFIG_SET(string/round_modifier_policy, saved_policy)
	for(var/field in saved_mode_state)
		SSgamemode.vars[field] = saved_mode_state[field]
	if(assassin_job)
		for(var/field in saved_job_state)
			assassin_job.vars[field] = saved_job_state[field]
	return ..()

/datum/unit_test/assassin_slots/Run()
	TEST_ASSERT_NOTNULL(assassin_job, "The Assassin job must exist.")
	SSgamemode.active_modifiers = list()
	SSgamemode.rolled_villain_events = list()
	SSgamemode.round_modifier_policy_name = "ratwood"
	SSgamemode.roundstart_reserved_antag_weight = 0
	SSgamemode.planned_villain_counts = list()
	SSgamemode.planned_villain_weights = list()
	SSgamemode.queued_villains = list()
	SSgamemode.roundstart_antag_allocation_complete = FALSE
	SSgamemode.admin_antag_cap = 2
	SSgamemode.antagonists_disabled = FALSE
	SSgamemode.halted_storyteller = FALSE
	SSgamemode.current_storyteller = allocate(/datum/storyteller)
	assassin_job.total_positions = 0
	assassin_job.spawn_positions = 0
	assassin_job.current_positions = 0
	assassin_job.admin_position_limit = null
	assassin_job.admin_slot_antag_type = null
	assassin_job.admin_antag_slots = 0

	SSgamemode.apply_round_modifiers()
	TEST_ASSERT_EQUAL(assassin_job.total_positions, 0, "No Assassin roll must leave latejoin slots closed.")
	TEST_ASSERT_EQUAL(assassin_job.spawn_positions, 0, "No Assassin roll must leave roundstart slots closed.")

	var/datum/round_modifier_policy/ratwood/policy = allocate(/datum/round_modifier_policy/ratwood)
	for(var/chaos_mode in list("Low Chaos", "High Chaos", "Zero Chaos"))
		var/list/pool = policy.get_major_modifier_pool(chaos_mode)
		allocated += pool
		var/datum/round_modifier/ratwood/major/assassins/pooled_assassin = locate(/datum/round_modifier/ratwood/major/assassins) in pool
		if(chaos_mode == "Zero Chaos")
			TEST_ASSERT(!length(pool), "Zero Chaos must not roll any major.")
		else
			TEST_ASSERT_NOTNULL(pooled_assassin, "[chaos_mode] must allow the Assassin job option.")

	var/datum/round_modifier/ratwood/major/assassins/modifier = allocate(/datum/round_modifier/ratwood/major/assassins)
	TEST_ASSERT_EQUAL(modifier.minimum_cost, 2, "The pool must require room for two full-weight Assassins.")
	TEST_ASSERT_EQUAL(modifier.cost, 2, "The Assassin job option must cost two points.")
	TEST_ASSERT(!modifier.prepare(SSgamemode, 1), "One point must not fund two Assassin slots.")
	TEST_ASSERT(modifier.prepare(SSgamemode, 2), "Two points must fund both Assassin slots.")
	TEST_ASSERT_EQUAL(modifier.job_slots["Assassin"], 2, "A funded roll must offer two Assassin jobs.")
	TEST_ASSERT(!length(modifier.villain_events), "The job option must not schedule a conversion event.")
	modifier.reserve(SSgamemode)
	TEST_ASSERT_EQUAL(SSgamemode.roundstart_reserved_antag_weight, 0, "Job slots must not also reserve event capacity.")
	TEST_ASSERT(!length(SSgamemode.planned_villain_counts), "Job slots must not create an event count.")
	TEST_ASSERT(!length(SSgamemode.planned_villain_weights), "Job slots must not create an event weight.")
	SSgamemode.active_modifiers += modifier
	SSgamemode.apply_round_modifiers()
	TEST_ASSERT_EQUAL(assassin_job.total_positions, 2, "The roll must open two latejoin slots.")
	TEST_ASSERT_EQUAL(assassin_job.spawn_positions, 2, "The roll must allow two Villains job preferences.")
	TEST_ASSERT(!length(SSgamemode.rolled_villain_events), "Opening jobs must not queue a conversion event.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(assassin_job, 1), 1, "One free cap point must expose only one Assassin slot.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(assassin_job, 0), 0, "A full cap must close ordinary Assassin slots.")

	SSgamemode.queued_villains["assassin_slots_first"] = "Assassin"
	TEST_ASSERT_EQUAL(SSgamemode.get_queued_villain_weight(), 1, "The first queued Assassin must use one cap point.")
	TEST_ASSERT(SSgamemode.can_add_antag_weight(1, SSgamemode.get_queued_villain_weight()), "The second Assassin must fit without a second event reserve.")
	SSgamemode.queued_villains["assassin_slots_second"] = "Assassin"
	TEST_ASSERT_EQUAL(SSgamemode.get_queued_villain_weight(), 2, "Two queued Assassins must fill a cap of two.")
	TEST_ASSERT(!SSgamemode.can_add_antag_weight(1, SSgamemode.get_queued_villain_weight()), "A third full-weight antagonist must not fit.")
	SSgamemode.queued_villains = list()

	var/datum/round_modifier/assassin/upstream_modifier = allocate(/datum/round_modifier/assassin)
	TEST_ASSERT_EQUAL(upstream_modifier.cost, 2, "The upstream option must also pay for two full-weight Assassins.")
	TEST_ASSERT(!length(upstream_modifier.villain_events), "The upstream option must not schedule a conversion event.")
	assassin_job.total_positions = 0
	assassin_job.spawn_positions = 0
	SSgamemode.active_modifiers = list(upstream_modifier)
	SSgamemode.apply_round_modifiers()
	TEST_ASSERT_EQUAL(assassin_job.total_positions, 2, "The upstream option must open two latejoin jobs.")
	TEST_ASSERT_EQUAL(assassin_job.spawn_positions, 2, "The upstream option must open two roundstart jobs.")
	TEST_ASSERT(!length(SSgamemode.rolled_villain_events), "The upstream option must not queue a conversion event.")

	var/datum/round_event_control/antagonist/solo/assassins/assassin_slot_test/event = allocate(/datum/round_event_control/antagonist/solo/assassins/assassin_slot_test)
	event.name = "Assassin conversion test"
	event.wizardevent = SSevents.wizardmode
	for(var/policy_name in list("ratwood", "upstream"))
		CONFIG_SET(string/round_modifier_policy, policy_name)
		TEST_ASSERT(!event.canSpawnEvent(100), "Assassin conversion must stay off under [policy_name].")
		var/datum/job/roguetown/assassin/job = allocate(/datum/job/roguetown/assassin)
		TEST_ASSERT_EQUAL(job.antag_cap_weight, 1, "The [policy_name] Assassin job must use one cap point.")
		TEST_ASSERT_EQUAL(job.total_positions, 0, "The job must not open without a roll or migration under [policy_name].")
		TEST_ASSERT_EQUAL(job.spawn_positions, 0, "The job must not open roundstart slots on its own under [policy_name].")
		var/datum/migrant_role/assassin/role = allocate(/datum/migrant_role/assassin)
		role.apply_config()
		TEST_ASSERT_EQUAL(role.antag_cap_weight, 1, "The [policy_name] Assassin migrant must use one cap point.")
	var/datum/antagonist/assassin/base_antag = allocate(/datum/antagonist/assassin)
	var/datum/antagonist/assassin/ratwood/ratwood_antag = allocate(/datum/antagonist/assassin/ratwood)
	TEST_ASSERT(!(base_antag.antag_flags & FLAG_FAKE_ANTAG), "The base Assassin must count toward the cap.")
	TEST_ASSERT_EQUAL(base_antag.get_antag_cap_weight(), 1, "The base Assassin datum must use one cap point.")
	TEST_ASSERT_EQUAL(ratwood_antag.get_antag_cap_weight(), 1, "The Ratwood Assassin datum must use one cap point.")

/// Keep all other spawn checks satisfied so a missing conversion ban fails the test.
/datum/round_event_control/antagonist/solo/assassins/assassin_slot_test
	name = null
	roundstart = FALSE
	earliest_start = -INFINITY
	max_occurrences = 20

/datum/round_event_control/antagonist/solo/assassins/assassin_slot_test/get_antag_amount()
	return 1

/datum/round_event_control/antagonist/solo/assassins/assassin_slot_test/get_candidates()
	return list(src)
