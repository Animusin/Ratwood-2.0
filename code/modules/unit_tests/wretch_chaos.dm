/datum/unit_test/wretch_chaos
	var/original_chaos_mode
	var/original_chaos_level

/datum/unit_test/wretch_chaos/New()
	. = ..()
	original_chaos_mode = SSgamemode.chaos_mode_name
	original_chaos_level = SSgamemode.level

/datum/unit_test/wretch_chaos/Destroy()
	SSgamemode.chaos_mode_name = original_chaos_mode
	SSgamemode.level = original_chaos_level
	return ..()

/datum/unit_test/wretch_chaos/Run()
	var/datum/job/wretch = new /datum/job/roguetown/wretch
	allocated += wretch
	var/datum/job/unrestricted_job = new /datum/job
	allocated += unrestricted_job
	var/datum/job/bandit = new /datum/job/roguetown/bandit
	allocated += bandit
	var/list/patrons = list()
	for(var/patron_type in list(/datum/patron/inhumen/zizo, /datum/patron/inhumen/matthios, /datum/patron/inhumen/graggar, /datum/patron/divine/astrata, /datum/patron/old_god))
		var/datum/patron/patron = new patron_type
		allocated += patron
		patrons += patron

	// Reuse the same job datums across mode changes: access must not be cached at construction.
	var/list/chaos_modes = list("Zero Chaos" = 0, "Low Chaos" = 1, "High Chaos" = 3)
	for(var/chaos_mode in chaos_modes)
		SSgamemode.chaos_mode_name = chaos_mode
		SSgamemode.level = chaos_modes[chaos_mode]
		for(var/datum/patron/patron as anything in patrons)
			var/allowed = !istype(patron, /datum/patron/inhumen/zizo) || chaos_mode == "High Chaos"
			TEST_ASSERT_EQUAL(wretch.is_patron_allowed(patron), allowed, "Wretch admission for [patron.type] at [chaos_mode].")
			TEST_ASSERT(unrestricted_job.is_patron_allowed(patron), "Unrestricted jobs must retain every patron at [chaos_mode].")
			TEST_ASSERT_EQUAL(bandit.is_patron_allowed(patron), istype(patron, /datum/patron/inhumen/matthios), "Existing job patron lists must remain enforced at [chaos_mode].")

	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.set_patron(/datum/patron/divine/astrata)
	var/list/converting_classes = list(
		/datum/advclass/wretch/ancientchampion,
		/datum/advclass/wretch/herald_of_progress,
		/datum/advclass/wretch/necromancer,
		/datum/advclass/wretch/antipope,
	)
	for(var/class_type in converting_classes)
		var/datum/advclass/choice = new class_type
		allocated += choice
		// Isolate chaos from unrelated race, population, capacity and account requirements.
		choice.allowed_races = null
		choice.minimum_town_strength = 0
		choice.maximum_possible_slots = -1
		choice.min_pq = -100
		for(var/chaos_mode in chaos_modes)
			SSgamemode.chaos_mode_name = chaos_mode
			SSgamemode.level = chaos_modes[chaos_mode]
			TEST_ASSERT_EQUAL(choice.check_requirements(character), chaos_mode == "High Chaos", "[class_type] must not convert an ordinary applicant to Zizo below High Chaos.")

	SSgamemode.chaos_mode_name = "Low Chaos"
	SSgamemode.level = 1
	TEST_ASSERT(!wretch.is_patron_allowed(patrons[1]), "Returning from High to Low Chaos must restore the restriction.")

	// Filling another player's slot must not reroll a locked converting class into this menu.
	var/datum/class_select_handler/handler = new /datum/class_select_handler
	allocated += handler
	handler.character_ref = WEAKREF(character)
	var/datum/advclass/filled_class = new /datum/advclass
	allocated += filled_class
	filled_class.category_tags = list(CTAG_WRETCH)
	var/datum/advclass/locked_class = new /datum/advclass/wretch/herald_of_progress
	allocated += locked_class
	locked_class.min_pq = -100
	handler.rolled_classes[filled_class] = 0
	handler.local_sorted_class_cache[CTAG_WRETCH] = list(locked_class)
	handler.rolled_class_is_full(filled_class)
	TEST_ASSERT(!(locked_class in handler.rolled_classes), "A full slot replacement must still enforce the High Chaos requirement.")

	var/datum/advclass/available_class = new /datum/advclass
	allocated += available_class
	available_class.category_tags = list(CTAG_WRETCH)
	handler.local_sorted_class_cache[CTAG_WRETCH] += available_class
	handler.rolled_classes[filled_class] = 0
	handler.rolled_class_is_full(filled_class)
	TEST_ASSERT(available_class in handler.rolled_classes, "Eligible replacements must remain available at Low Chaos.")

	SSgamemode.chaos_mode_name = "High Chaos"
	SSgamemode.level = 3
	handler.rolled_classes = list()
	handler.rolled_classes[filled_class] = 0
	handler.local_sorted_class_cache[CTAG_WRETCH] = list(locked_class)
	handler.rolled_class_is_full(filled_class)
	TEST_ASSERT(locked_class in handler.rolled_classes, "High Chaos must allow converting classes as replacements.")
