/// Exercise the real visibility updater without AI or unrelated icon work.
/mob/living/mobs_sneak_probe
	notransform = TRUE
	var/skill_reads = 0
	var/icon_refreshes = 0

/mob/living/mobs_sneak_probe/get_skill_level(skill)
	skill_reads++
	return ..()

/mob/living/mobs_sneak_probe/regenerate_icons()
	icon_refreshes++

/// Make light-dependent tests deterministic without changing any map lighting.
/mob/living/mobs_sneak_probe/proc/prepare_sneak(pressed = FALSE)
	stat = CONSCIOUS
	m_intent = MOVE_INTENT_SNEAK
	rogue_sneaking = FALSE
	sneak_faded = FALSE
	wallpressed = pressed
	lying = FALSE
	alpha = initial(alpha)
	invisibility = initial(invisibility)
	rogue_sneaking_light_threshhold = 2
	mob_timers[MT_INVISIBILITY] = world.time - 1
	mob_timers[MT_FOUNDSNEAK] = world.time - 31 SECONDS
	mob_timers[MT_SNEAKATTACK] = world.time - 5 SECONDS
	mob_timers[MT_SNEAKBUMP] = world.time - 1 SECONDS

/// Walking and running without a sneak transition must leave unrelated visibility alone.
/datum/unit_test/mobs_sneak_noop/Run()
	var/mob/living/mobs_sneak_probe/subject = allocate(/mob/living/mobs_sneak_probe)
	subject.skill_reads = 0
	for(var/with_mind in list(FALSE, TRUE))
		if(with_mind)
			subject.mind = allocate(/datum/mind, "sneak_noop_test")
			subject.mind.current = subject
		for(var/intent in list(MOVE_INTENT_WALK, MOVE_INTENT_RUN))
			subject.prepare_sneak()
			subject.m_intent = intent
			subject.alpha = 117
			subject.invisibility = 7
			subject.update_sneak_invis()
			TEST_ASSERT_EQUAL(subject.alpha, 117, "An unrelated transparency must survive a no-op visibility update.")
			TEST_ASSERT_EQUAL(subject.invisibility, 7, "An unrelated invisibility must survive a no-op visibility update.")
			TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "A non-sneaking movement intent must remain visible.")
	TEST_ASSERT_EQUAL(subject.skill_reads, 0, "Walking and running without a visibility transition must not query sneaking skill.")
	TEST_ASSERT_EQUAL(subject.icon_refreshes, 0, "A no-op update must not regenerate icons.")

/// Entry, fading exit and forced reveals must retain the existing state transitions.
/datum/unit_test/mobs_sneak_transitions/Run()
	var/mob/living/mobs_sneak_probe/subject = allocate(/mob/living/mobs_sneak_probe)
	subject.mind = allocate(/datum/mind, "sneak_transition_test")
	subject.mind.current = subject
	subject.prepare_sneak()
	subject.update_sneak_invis()
	TEST_ASSERT(subject.rogue_sneaking && subject.sneak_faded, "Sneak intent must still hide an eligible mob in darkness.")
	TEST_ASSERT_EQUAL(subject.invisibility, SEE_INVISIBLE_LIVING + 1, "An unskilled sneak must retain its usual invisibility.")

	subject.m_intent = MOVE_INTENT_WALK
	subject.update_sneak_invis()
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "Leaving sneak intent must reveal a faded mob.")
	TEST_ASSERT_EQUAL(subject.invisibility, initial(subject.invisibility), "Leaving sneak intent must restore normal visibility.")

	subject.prepare_sneak()
	subject.update_sneak_invis()
	subject.rogue_sneaking_light_threshhold = -1
	subject.update_sneak_invis()
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "Moving into light must still reveal a hidden mob.")
	TEST_ASSERT_EQUAL(subject.invisibility, initial(subject.invisibility), "Light must remove sneak invisibility.")

	subject.prepare_sneak()
	subject.m_intent = MOVE_INTENT_WALK
	subject.alpha = 90
	subject.invisibility = 7
	subject.update_sneak_invis(reset = TRUE)
	TEST_ASSERT_EQUAL(subject.invisibility, initial(subject.invisibility), "A forced reveal must work even without active sneak flags.")
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "A forced reveal must leave both sneak flags clear.")

	// A wallpressed fade still takes the distinct wallpress exit branch.
	subject.prepare_sneak(pressed = TRUE)
	subject.m_intent = MOVE_INTENT_RUN
	subject.rogue_sneaking = TRUE
	subject.sneak_faded = TRUE
	subject.invisibility = 7
	subject.update_sneak_invis()
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "Leaving sneak while wallpressed must clear both flags.")
	TEST_ASSERT_EQUAL(subject.invisibility, initial(subject.invisibility), "Wallpress exit must still remove sneak invisibility.")

	// Reusing the skill within one update must not cache it across later skill changes.
	subject.adjust_skillrank_up_to(/datum/skill/misc/sneaking, SKILL_LEVEL_LEGENDARY, silent = TRUE)
	subject.prepare_sneak()
	subject.update_sneak_invis()
	TEST_ASSERT(subject.rogue_sneaking && subject.sneak_faded, "A trained mob must still enter sneak mode.")
	TEST_ASSERT(subject.invisibility > SEE_INVISIBLE_LIVING + 1, "A later skill increase must still improve sneak invisibility.")

/// Spell precedence, corpse cleanup and null locations must not depend on normal sneak intent.
/datum/unit_test/mobs_sneak_special_states/Run()
	var/mob/living/mobs_sneak_probe/subject = allocate(/mob/living/mobs_sneak_probe)
	subject.prepare_sneak()
	subject.m_intent = MOVE_INTENT_WALK
	subject.mob_timers[MT_INVISIBILITY] = world.time + 1 MINUTES
	subject.alpha = 90
	subject.invisibility = 7
	subject.update_sneak_invis()
	TEST_ASSERT(subject.rogue_sneaking, "An active invisibility spell must keep precedence over normal movement intent.")
	TEST_ASSERT_EQUAL(subject.invisibility, 7, "The ordinary updater must preserve spell visibility.")
	subject.update_sneak_invis(reset = TRUE)
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "Forced revealing must still override an invisibility spell.")
	TEST_ASSERT_EQUAL(subject.invisibility, initial(subject.invisibility), "A forced reveal must remove spell invisibility.")

	subject.prepare_sneak()
	subject.stat = DEAD
	subject.rogue_sneaking = TRUE
	subject.sneak_faded = TRUE
	subject.update_sneak_invis()
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "DeadLife must still clear a corpse's sneak fade.")

	subject.prepare_sneak()
	subject.moveToNullspace()
	subject.invisibility = 7
	subject.update_sneak_invis(reset = TRUE)
	TEST_ASSERT_EQUAL(subject.invisibility, 7, "The existing null-location early return must remain intact.")
	TEST_ASSERT(!subject.rogue_sneaking && !subject.sneak_faded, "A null-location update must not enter sneak mode.")
