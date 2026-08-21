/datum/unit_test/ratwood_antag_cap/Run()
	TEST_ASSERT_EQUAL(calculate_ratwood_antag_cap(0, 15), 2, "Ratwood should retain the flat two-point allowance.")
	TEST_ASSERT_EQUAL(calculate_ratwood_antag_cap(14, 15), 2, "Population below the divisor should retain the flat allowance.")
	TEST_ASSERT_EQUAL(calculate_ratwood_antag_cap(30, 15), 4, "Low Chaos should divide online population by 15 and add two.")
	TEST_ASSERT_EQUAL(calculate_ratwood_antag_cap(30, 10), 5, "High Chaos should divide online population by 10 and add two.")
	TEST_ASSERT_EQUAL(calculate_ratwood_antag_cap(30, 0), 0, "An invalid divisor should fail closed.")

/datum/unit_test/ratwood_major_planning/Run()
	var/datum/round_modifier/ratwood/major/masquerade/masquerade = new
	var/datum/round_event_control/antagonist/solo/masquerade/ratwood/masquerade_event = new
	masquerade.prepared_event = masquerade_event
	TEST_ASSERT(masquerade.plan_for_budget(5, 30), "Masquerade should produce a plan when one vampire fits.")
	TEST_ASSERT_EQUAL(masquerade.planned_antag_count, 2, "Masquerade should fill a five-point cap with two vampires.")
	TEST_ASSERT_EQUAL(masquerade.planned_antag_weight, 4, "Masquerade should leave only unusable capacity.")

	var/datum/round_modifier/ratwood/major/vampire_lord/vampire_lord = new
	var/datum/round_event_control/antagonist/solo/vampires/ratwood/vampire_lord_event = new
	vampire_lord.prepared_event = vampire_lord_event
	TEST_ASSERT(vampire_lord.plan_for_budget(9, 30), "Vampire Lord should produce a plan when the lord fits.")
	TEST_ASSERT_EQUAL(vampire_lord.planned_antag_count, 4, "Vampire Lord mode should have one lord and three followers at nine points.")
	TEST_ASSERT_EQUAL(vampire_lord.planned_antag_weight, 9, "Vampire Lord mode should fill compatible capacity.")

	var/datum/round_modifier/ratwood/major/assassins/assassins = new
	var/datum/round_event_control/antagonist/solo/assassins/ratwood/assassins_event = new
	assassins.prepared_event = assassins_event
	TEST_ASSERT(assassins.plan_for_budget(10, 100), "Assassins should produce their fixed pair.")
	TEST_ASSERT_EQUAL(assassins.planned_antag_count, 2, "Assassins should remain a two-person mode.")
	TEST_ASSERT_EQUAL(assassins.planned_antag_weight, 1, "The assassin pair should reserve one point.")

	var/datum/round_modifier/ratwood/major/lich/lich = new
	var/datum/round_event_control/antagonist/solo/lich/ratwood/lich_event = new
	lich.prepared_event = lich_event
	TEST_ASSERT(lich.plan_for_budget(8, 30), "Lich should produce a plan when one lich fits.")
	TEST_ASSERT_EQUAL(lich.planned_antag_count, 1, "Lich should retain its population-derived planned limit.")
	TEST_ASSERT_EQUAL(lich.planned_antag_weight, 3, "A planned Ratwood lich should cost three points.")

	qdel(masquerade)
	qdel(masquerade_event)
	qdel(vampire_lord)
	qdel(vampire_lord_event)
	qdel(assassins)
	qdel(assassins_event)
	qdel(lich)
	qdel(lich_event)
