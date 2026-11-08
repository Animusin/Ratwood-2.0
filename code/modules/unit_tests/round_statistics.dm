/// Check every configured choice, including factors that were not rolled this round.
/datum/unit_test/storyteller_influence_counters/Run()
	for(var/storyteller_type in subtypesof(/datum/storyteller))
		var/datum/storyteller/storyteller = new storyteller_type()
		allocated += storyteller
		for(var/set_name in storyteller.influence_sets)
			var/list/factors = storyteller.influence_sets[set_name]
			for(var/statistic in factors)
				TEST_ASSERT(isnum(GLOB.azure_round_stats[statistic]), "[storyteller.name]'s [statistic] must have a round counter.")

/// A successful Burial Rites cast must contribute to Necra's actual storyteller score.
/datum/unit_test/necra_grave_influence
	var/original_grave_count
	var/datum/storyteller/original_necra
	var/installed_necra = FALSE

/datum/unit_test/necra_grave_influence/Destroy()
	if(!isnull(original_grave_count))
		GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED] = original_grave_count
	if(installed_necra)
		if(original_necra)
			SSgamemode.storytellers[/datum/storyteller/necra] = original_necra
		else
			SSgamemode.storytellers -= /datum/storyteller/necra
	return ..()

/datum/unit_test/necra_grave_influence/Run()
	original_grave_count = GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED]
	force_set_round_statistic(STATS_GRAVES_CONSECRATED, 0)
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
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
	TEST_ASSERT(isturf(caster.loc) && (grave in view(1, caster)), "The caster must be outside and able to see the sealed grave.")

	// The unit test runner skips the gamemode's normal population of storytellers.
	original_necra = SSgamemode.storytellers[/datum/storyteller/necra]
	var/datum/storyteller/necra/necra = new
	allocated += necra
	SSgamemode.storytellers[/datum/storyteller/necra] = necra
	installed_necra = TRUE
	var/influence_before = SSgamemode.calculate_storyteller_influence(/datum/storyteller/necra)
	usr = caster
	rite.cast(list(), caster)
	usr = previous_usr
	TEST_ASSERT_EQUAL(GLOB.azure_round_stats[STATS_GRAVES_CONSECRATED], 1, "A successful grave consecration must increment the round counter.")
	TEST_ASSERT_EQUAL(SSgamemode.calculate_specific_influence(/datum/storyteller/necra, STATS_GRAVES_CONSECRATED), 3.75, "The grave must contribute 3.75 influence.")
	TEST_ASSERT_EQUAL(SSgamemode.calculate_storyteller_influence(/datum/storyteller/necra), influence_before + 3.75, "Necra's total influence must include the grave.")
	force_set_round_statistic(STATS_GRAVES_CONSECRATED, 30)
	TEST_ASSERT_EQUAL(SSgamemode.calculate_specific_influence(/datum/storyteller/necra, STATS_GRAVES_CONSECRATED), 80, "Grave influence must still respect its cap.")

/datum/stressevent/bathwater/test_application
	var/applications = 0

/datum/stressevent/bathwater/test_application/on_apply(mob/living/user)
	. = ..()
	applications++

/datum/unit_test/stress_bath_registration/Run()
	var/mob/living/carbon/human/bather = allocate(/mob/living/carbon/human/consistent)
	var/datum/stressevent/bathwater/test_application/event = bather.add_stress(/datum/stressevent/bathwater/test_application)
	TEST_ASSERT_EQUAL(event.applications, 1, "The bath statistic hook must run when the stress event is first applied.")
	bather.add_stress(/datum/stressevent/bathwater/test_application)
	TEST_ASSERT_EQUAL(event.applications, 1, "Refreshing bath stress must not count as another bath.")
	bather.remove_stress(/datum/stressevent/bathwater/test_application)
	qdel(event)

/datum/unit_test/bath_and_sewer_stress
	var/turf/water_tile
	var/original_turf_type
	var/original_baseturfs

/datum/unit_test/bath_and_sewer_stress/Destroy()
	if(water_tile)
		water_tile.ChangeTurf(original_turf_type, original_baseturfs, CHANGETURF_FORCEOP)
	return ..()

/datum/unit_test/bath_and_sewer_stress/Run()
	var/mob/living/carbon/human/bather = allocate(/mob/living/carbon/human/consistent)
	water_tile = get_step(run_loc_floor_bottom_left, EAST)
	original_turf_type = water_tile.type
	original_baseturfs = islist(water_tile.baseturfs) ? water_tile.baseturfs.Copy() : water_tile.baseturfs
	water_tile = water_tile.ChangeTurf(/turf/open/water/bath, original_baseturfs, CHANGETURF_FORCEOP)
	bather.handle_inwater(water_tile)
	TEST_ASSERT(bather.has_stress_event(/datum/stressevent/bathwater), "A bath must apply its relaxation effect.")
	water_tile = water_tile.ChangeTurf(/turf/open/water/sewer, original_baseturfs, CHANGETURF_FORCEOP)
	bather.handle_inwater(water_tile)
	TEST_ASSERT(bather.has_stress_event(/datum/stressevent/sewertouched), "Sewage must still apply its stress effect.")
