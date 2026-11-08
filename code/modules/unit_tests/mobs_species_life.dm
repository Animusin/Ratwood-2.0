/// Count real health refreshes without replacing their gameplay effects.
/mob/living/carbon/human/consistent/species_life_probe
	var/health_refreshes = 0

/mob/living/carbon/human/consistent/species_life_probe/updatehealth()
	health_refreshes++
	return ..()

/datum/species/species_life_probe
	var/flight_checks = 0

/datum/species/species_life_probe/HandleFlight(mob/living/carbon/human/human)
	flight_checks++
	return ..()

/// Repeated species ticks must not recalculate unchanged health for a mob that does not breathe.
/datum/unit_test/mobs_species_noop_health/Run()
	var/mob/living/carbon/human/consistent/species_life_probe/human = allocate(/mob/living/carbon/human/consistent/species_life_probe)
	ADD_TRAIT(human, TRAIT_NOBREATH, "unit_test")
	human.setOxyLoss(0)
	human.health_refreshes = 0
	human.losebreath = 5
	repeat_species_life(human, 100)
	TEST_ASSERT_EQUAL(human.health_refreshes, 0, "Healthy non-breathing mobs must not refresh health on every species tick.")
	TEST_ASSERT_EQUAL(human.losebreath, 0, "Skipping an unchanged health refresh must still clear breath loss.")

/// A fixed workload also allows the local profiler to compare the same path before and after the fix.
/datum/unit_test/mobs_species_noop_health/proc/repeat_species_life(mob/living/carbon/human/human, iterations)
	for(var/iteration in 1 to iterations)
		human.dna.species.spec_life(human)

/// Actual oxygen recovery must still refresh health; ordinary breathing mobs remain unaffected.
/datum/unit_test/mobs_species_oxygen_recovery/Run()
	var/mob/living/carbon/human/consistent/species_life_probe/human = allocate(/mob/living/carbon/human/consistent/species_life_probe)
	ADD_TRAIT(human, TRAIT_NOBREATH, "unit_test")
	human.setOxyLoss(30)
	human.health_refreshes = 0
	human.losebreath = 5
	human.dna.species.spec_life(human)
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 0, "Non-breathing mobs must still recover existing oxygen damage.")
	TEST_ASSERT_EQUAL(human.health, human.maxHealth, "Oxygen recovery must immediately update the mob's health.")
	TEST_ASSERT(human.health_refreshes > 0, "Actual oxygen recovery must run the real health refresh.")
	TEST_ASSERT_EQUAL(human.losebreath, 0, "Oxygen recovery must also clear accumulated breath loss.")

	REMOVE_TRAIT(human, TRAIT_NOBREATH, "unit_test")
	human.setOxyLoss(30)
	human.health_refreshes = 0
	human.losebreath = 5
	human.dna.species.spec_life(human)
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 30, "Ordinary breathing mobs must not receive the non-breathing oxygen recovery.")
	TEST_ASSERT_EQUAL(human.losebreath, 5, "Ordinary breathing mobs must retain their breath loss.")
	TEST_ASSERT_EQUAL(human.health_refreshes, 0, "Ordinary species ticks must not gain an extra health refresh.")

	ADD_TRAIT(human, TRAIT_NOBREATH, "unit_test")
	human.status_flags |= GODMODE
	human.dna.species.spec_life(human)
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 30, "The oxygen setter's existing GODMODE behavior must remain unchanged.")
	TEST_ASSERT_EQUAL(human.losebreath, 0, "GODMODE must not prevent the existing breath-loss reset.")

/// The no-op guard must not bypass critical damage, its exemption, or species flight processing.
/datum/unit_test/mobs_species_critical_and_flight/Run()
	var/mob/living/carbon/human/consistent/species_life_probe/human = allocate(/mob/living/carbon/human/consistent/species_life_probe)
	ADD_TRAIT(human, TRAIT_NOBREATH, "unit_test")
	human.setToxLoss(human.maxHealth - human.crit_threshold + 1)
	TEST_ASSERT(human.health < human.crit_threshold, "The test mob must be below its critical-health threshold.")
	var/brute_before = human.getBruteLoss()
	human.dna.species.spec_life(human)
	TEST_ASSERT(human.getBruteLoss() > brute_before, "A non-breathing mob in critical condition must still take critical brute damage.")

	ADD_TRAIT(human, TRAIT_NOCRITDAMAGE, "unit_test")
	brute_before = human.getBruteLoss()
	human.dna.species.spec_life(human)
	TEST_ASSERT_EQUAL(human.getBruteLoss(), brute_before, "The no-critical-damage trait must still suppress critical brute damage.")

	var/datum/species/species_life_probe/species = allocate(/datum/species/species_life_probe)
	species.spec_life(human)
	TEST_ASSERT_EQUAL(species.flight_checks, 0, "Non-flying species must not gain flight processing.")
	species.flying_species = TRUE
	species.spec_life(human)
	TEST_ASSERT_EQUAL(species.flight_checks, 1, "Flying species must still process flight when oxygen damage is already zero.")
