/// Check every configured choice, including factors that were not rolled this round.
/datum/unit_test/storyteller_influence_counters/Run()
	for(var/storyteller_type in SSgamemode.storytellers)
		var/datum/storyteller/storyteller = SSgamemode.storytellers[storyteller_type]
		for(var/set_name in storyteller.influence_sets)
			var/list/factors = storyteller.influence_sets[set_name]
			for(var/statistic in factors)
				TEST_ASSERT(isnum(GLOB.azure_round_stats[statistic]), "[storyteller.name]'s [statistic] must have a round counter.")

/// A successful Burial Rites cast must contribute to Necra's actual storyteller score.
/datum/unit_test/necra_grave_influence
	var/original_grave_count

/datum/unit_test/necra_grave_influence/Destroy()
	if(!isnull(original_grave_count))
		GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED] = original_grave_count
	return ..()

/datum/unit_test/necra_grave_influence/Run()
	original_grave_count = GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED]
	force_set_round_statistic(STATS_GRAVES_CONSECRATED, 0)
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/closet/dirthole/grave/grave = allocate(/obj/structure/closet/dirthole/grave)
	var/obj/effect/proc_holder/spell/targeted/burialrite/rite = allocate(/obj/effect/proc_holder/spell/targeted/burialrite)
	var/mob/previous_usr = usr
	usr = caster
	rite.cast(list(), caster)
	usr = previous_usr
	TEST_ASSERT(!GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED], "An empty grave must not count as a consecration.")

	var/datum/respawn_test_accounts/accounts = allocate(/datum/respawn_test_accounts)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.register_respawn_body(accounts.track("unitnecragrave"))
	body.stat = DEAD
	body.record_respawn_death()
	body.forceMove(grave)
	grave.stage = 4
	TEST_ASSERT(grave.close(), "The corpse must be interred before performing Burial Rites.")

	var/influence_before = SSgamemode.calculate_storyteller_influence(/datum/storyteller/necra)
	usr = caster
	rite.cast(list(), caster)
	usr = previous_usr
	TEST_ASSERT_EQUAL(GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED], 1, "A successful grave consecration must increment the round counter.")
	TEST_ASSERT_EQUAL(SSgamemode.calculate_specific_influence(/datum/storyteller/necra, STATS_GRAVES_CONSECRATED), 3.75, "The grave must contribute 3.75 influence.")
	TEST_ASSERT_EQUAL(SSgamemode.calculate_storyteller_influence(/datum/storyteller/necra), influence_before + 3.75, "Necra's total influence must include the grave.")
	force_set_round_statistic(STATS_GRAVES_CONSECRATED, 30)
	TEST_ASSERT_EQUAL(SSgamemode.calculate_specific_influence(/datum/storyteller/necra, STATS_GRAVES_CONSECRATED), 80, "Grave influence must still respect its cap.")
