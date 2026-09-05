/// Global migrant roles must receive the loaded policy before players can use them.
/datum/unit_test/migrant_config/Run()
	var/datum/migrant_role/assassin/role = MIGRANT_ROLE(/datum/migrant_role/assassin)
	TEST_ASSERT_NOTNULL(role, "The Assassin migrant role was not constructed")
	var/ratwood_policy = CONFIG_GET(string/round_modifier_policy) == "ratwood"
	TEST_ASSERT_EQUAL(role.antag_cap_weight, ratwood_policy ? 0.5 : 0, "The global role did not receive the loaded policy")
	TEST_ASSERT_EQUAL(role.antag_datum, ratwood_policy ? /datum/antagonist/assassin/ratwood : /datum/antagonist/assassin, "The global role has the wrong antagonist type")

/// Applying a policy repeatedly must not retain values from the previous policy.
/datum/unit_test/migrant_config_reload/Run()
	var/original_policy = CONFIG_GET(string/round_modifier_policy)
	var/datum/migrant_role/assassin/role = new
	CONFIG_SET(string/round_modifier_policy, "ratwood")
	role.apply_config()
	var/ratwood_antag = role.antag_datum
	var/ratwood_weight = role.antag_cap_weight
	CONFIG_SET(string/round_modifier_policy, "upstream")
	role.apply_config()
	var/upstream_antag = role.antag_datum
	var/upstream_weight = role.antag_cap_weight
	CONFIG_SET(string/round_modifier_policy, original_policy)
	qdel(role)

	TEST_ASSERT_EQUAL(ratwood_antag, /datum/antagonist/assassin/ratwood, "Ratwood antagonist type")
	TEST_ASSERT_EQUAL(ratwood_weight, 0.5, "Ratwood capacity weight")
	TEST_ASSERT_EQUAL(upstream_antag, /datum/antagonist/assassin, "Upstream antagonist type")
	TEST_ASSERT_EQUAL(upstream_weight, 0, "Upstream capacity weight")
