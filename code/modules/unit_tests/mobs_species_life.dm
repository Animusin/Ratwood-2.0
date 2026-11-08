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

/// Death's Precipice grants blood-loss immunity without changing oxygen damage.
/// A Revenant already unconscious from blood loss must wake on the next real Life tick.
/datum/unit_test/mobs_species_deathdoor_health/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.set_species(/datum/species/dullahan)
	human.mode = NPC_AI_OFF
	human.set_blood_volume(BLOOD_VOLUME_SURVIVE - 30)
	human.setOxyLoss(0)
	TEST_ASSERT_EQUAL(human.stat, UNCONSCIOUS, "The Revenant must start unconscious from blood loss.")
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 0, "The blood-loss fixture must have no oxygen damage to heal.")

	var/area/rogue/indoors/deathsedge/death_area = new
	allocated += death_area
	death_area.Entered(human)
	TEST_ASSERT(human.has_status_effect(/datum/status_effect/debuff/deathdoorwilloss), "Entering Death's Precipice must apply its real status effect.")
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_BLOODLOSS_IMMUNE), "The area must grant blood-loss immunity before the Life tick.")
	human.Life(1, 1)
	TEST_ASSERT_EQUAL(human.stat, CONSCIOUS, "Blood-loss immunity must let a Revenant wake even when oxygen damage was already zero.")
	// Collapsing sets resting=TRUE; waking restores control but does not stand up automatically.
	TEST_ASSERT(human.mobility_flags & MOBILITY_MOVE, "Waking from blood loss must restore movement control.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_CANSTAND, "Waking from blood loss must restore the ability to choose to stand up.")
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 0, "The wakeup must not require unrelated oxygen damage.")

/// Astrata's Favor changes damage-slowdown immunity without changing health.
/// Applying and removing it must both update the real movement modifiers.
/datum/unit_test/mobs_species_astrata_health/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.set_species(/datum/species/dullahan)
	human.mode = NPC_AI_OFF
	human.setToxLoss(90)
	TEST_ASSERT(human.has_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN), "The damaged Revenant must start with a damage-slowdown modifier.")
	TEST_ASSERT_EQUAL(human.getOxyLoss(), 0, "The slowdown fixture must have no oxygen damage to heal.")

	human.apply_status_effect(/datum/status_effect/astrata_favor)
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_IGNOREDAMAGESLOWDOWN), "Astrata's Favor must grant its actual damage-slowdown immunity.")
	human.Life(1, 1)
	TEST_ASSERT(!human.has_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN), "Astrata's Favor must remove ground damage slowdown on the next Life tick.")
	TEST_ASSERT(!human.has_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN_FLYING), "Astrata's Favor must remove floating damage slowdown too.")

	// A further hit while the buff is active must retain its immunity. The buff's
	// removal must then restore the slowdown without waiting for another hit.
	human.adjustToxLoss(1)
	human.remove_status_effect(/datum/status_effect/astrata_favor)
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_IGNOREDAMAGESLOWDOWN), "Removing Astrata's Favor must remove its immunity trait.")
	human.Life(1, 1)
	TEST_ASSERT(human.has_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN), "Removing Astrata's Favor must restore ground damage slowdown on the next Life tick.")
	TEST_ASSERT(human.has_movespeed_modifier(MOVESPEED_ID_DAMAGE_SLOWDOWN_FLYING), "Removing Astrata's Favor must restore floating damage slowdown too.")

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

/// Species ticks must process critical damage, its exemption, and species flight.
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
