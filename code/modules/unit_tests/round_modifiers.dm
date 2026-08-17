/datum/unit_test/ratwood_round_modifier_contracts

/datum/unit_test/ratwood_round_modifier_contracts/Run()
	TEST_ASSERT_EQUAL(calculate_roundstart_cap(40, 15), 4, "Low Chaos snapshot must ignore jobs and use ready population only.")
	TEST_ASSERT_EQUAL(calculate_roundstart_cap(40, 10), 6, "High Chaos snapshot must ignore jobs and use ready population only.")
	TEST_ASSERT_EQUAL(calculate_antag_cap_from_population(45 - 5, 15), 4, "Low dynamic cap must apply bonuses/exclusions before its divisor.")
	TEST_ASSERT_EQUAL(calculate_antag_cap_from_population(45 - 5, 10), 6, "High dynamic cap must apply bonuses/exclusions before its divisor.")

	var/list/upstream_modifiers = get_ratwood_upstream_round_modifier_manifest()
	var/list/local_modifier_types = list(
		/datum/round_modifier/ratwood/weather/clear,
		/datum/round_modifier/ratwood/weather/fog,
		/datum/round_modifier/ratwood/weather/stormy,
	)
	for(var/modifier_type in subtypesof(/datum/round_modifier))
		if(ispath(modifier_type, /datum/round_modifier/ratwood) || modifier_type in local_modifier_types)
			continue
		if(!(modifier_type in upstream_modifiers))
			Fail("Unclassified upstream round modifier: [modifier_type]")
	for(var/modifier_type in upstream_modifiers)
		if(!(modifier_type in subtypesof(/datum/round_modifier)))
			Fail("Removed or renamed upstream round modifier remains in manifest: [modifier_type]")

	var/list/upstream_events = get_ratwood_upstream_solo_event_manifest()
	for(var/event_type in subtypesof(/datum/round_event_control/antagonist/solo))
		var/datum/round_event_control/antagonist/solo/discovered_event = new event_type
		if(discovered_event.round_modifier_only)
			qdel(discovered_event)
			continue
		qdel(discovered_event)
		if(!(event_type in upstream_events))
			Fail("Unclassified upstream solo-antagonist event: [event_type]")
	for(var/event_type in upstream_events)
		if(!(event_type in subtypesof(/datum/round_event_control/antagonist/solo)))
			Fail("Removed or renamed upstream solo-antagonist event remains in manifest: [event_type]")

	for(var/event_type in get_ratwood_solo_event_contracts())
		var/list/contract = get_ratwood_solo_event_contracts()[event_type]
		var/datum/round_event_control/antagonist/solo/event = new event_type
		TEST_ASSERT_EQUAL(event.base_antags, contract["base"], "[event_type] base formula changed upstream.")
		TEST_ASSERT_EQUAL(event.maximum_antags, contract["maximum"], "[event_type] maximum formula changed upstream.")
		TEST_ASSERT_EQUAL(event.denominator, contract["denominator"], "[event_type] denominator changed upstream.")
		TEST_ASSERT_EQUAL(event.min_players, contract["minimum"], "[event_type] minimum population changed upstream.")
		TEST_ASSERT_EQUAL(event.antag_datum, contract["datum"], "[event_type] antagonist datum changed upstream.")
		TEST_ASSERT_EQUAL(event.roundstart, contract["roundstart"], "[event_type] start/midround status changed upstream.")
		TEST_ASSERT_EQUAL(event.get_antag_cap_weight(1), contract["weight"], "[event_type] cap weight changed.")
		TEST_ASSERT_EQUAL(event.get_desired_antag_amount(40), min(event.base_antags + FLOOR(40 / event.denominator, 1), event.maximum_antags), "[event_type] population formula changed.")
		qdel(event)

	var/datum/round_event_control/antagonist/solo/vampires/ratwood/vampire_lord = new
	TEST_ASSERT_EQUAL(vampire_lord.get_antag_cap_weight(1), 3, "Vampire Lord must reserve three.")
	TEST_ASSERT_EQUAL(vampire_lord.get_antag_cap_weight(2), 2, "Vampire Lord's additional vampire must reserve two.")
	qdel(vampire_lord)

	var/datum/round_modifier_policy/ratwood/ratwood_policy = new
	var/list/low_pool = ratwood_policy.get_modifier_pool("Low Chaos")
	var/list/high_pool = ratwood_policy.get_modifier_pool("High Chaos")
	TEST_ASSERT_EQUAL(length(low_pool), 7, "Low Chaos pool changed without review.")
	TEST_ASSERT_EQUAL(length(high_pool), 10, "High Chaos pool changed without review.")
	var/list/low_pool_types = list()
	for(var/datum/round_modifier/ratwood/modifier in low_pool)
		low_pool_types += modifier.type
	TEST_ASSERT(!(/datum/round_modifier/ratwood/major/vampire_lord in low_pool_types), "Low Chaos cannot contain Vampire Lord.")
	TEST_ASSERT(!(/datum/round_modifier/ratwood/major/werewolf in low_pool_types), "Low Chaos cannot contain Werewolf.")
	TEST_ASSERT(!(/datum/round_modifier/ratwood/major/lich in low_pool_types), "Low Chaos cannot contain Lich.")
	QDEL_LIST(low_pool)
	QDEL_LIST(high_pool)
	qdel(ratwood_policy)

	var/datum/job/roguetown/wretch/wretch_job = new
	TEST_ASSERT_EQUAL(wretch_job.total_positions, 0, "Wretch must be unavailable without a Ratwood modifier.")
	TEST_ASSERT_EQUAL(wretch_job.spawn_positions, 0, "Wretch must have no default roundstart slots.")
	qdel(wretch_job)
	var/datum/antagonist/assassin/assassin = new
	TEST_ASSERT_EQUAL(assassin.get_antag_cap_weight(), 0.5, "Each assassin must consume half a cap point.")
	TEST_ASSERT(!(assassin.antag_flags & FLAG_FAKE_ANTAG), "Assassins must no longer bypass antagonist cap accounting.")
	qdel(assassin)

	var/datum/round_modifier_policy/upstream/fallback = new
	TEST_ASSERT_EQUAL(fallback.id, "upstream", "Upstream fallback policy must remain constructible.")
	qdel(fallback)
