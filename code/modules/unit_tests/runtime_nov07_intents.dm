/// Rat Form needs owned intent instances before any click copies a_intent into used_intent.
/datum/unit_test/runtime_nov07_rat_intent_lifecycle/Run()
	var/mob/living/simple_animal/hostile/retaliate/smallrat/rat = allocate(/mob/living/simple_animal/hostile/retaliate/smallrat)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(istype(rat.a_intent, /datum/intent/unarmed/help), "Rat Form must initialize its help intent as a datum rather than leave the type path in a_intent.")
	TEST_ASSERT(istype(rat.o_intent, /datum/intent/unarmed/help), "The rat's other hand must also receive an initialized intent.")
	TEST_ASSERT(rat.a_intent != rat.o_intent, "Both hands must retain independently owned intent instances.")
	var/datum/intent/active = rat.a_intent
	var/datum/intent/offhand = rat.o_intent
	TEST_ASSERT(active.mastermob == rat && offhand.mastermob == rat, "Both intents must belong to the rat.")
	TEST_ASSERT(active in rat.possible_a_intents, "The selected intent must be in the list responsible for its deletion.")
	TEST_ASSERT(offhand in rat.possible_offhand_intents, "The offhand intent must be in the list responsible for its deletion.")
	TEST_ASSERT_EQUAL(rat.used_intent, active, "Combat must start with the initialized active-hand intent.")
	TEST_ASSERT_EQUAL(rat.used_intent.get_chargetime(), 0, "The rat's touch action must remain uncharged.")
	rat.used_intent.rmb_ranged(rat, rat)
	rat.atkswinging = TRUE
	rat.stop_attack()
	TEST_ASSERT(!rat.atkswinging, "Stopping a rat's attack must run the intent callback normally.")
	rat.update_a_intents()
	TEST_ASSERT(rat.a_intent == active && rat.o_intent == offhand, "Refreshing Rat Form must reuse its normal bare-hand intents.")
	qdel(rat)
	TEST_ASSERT(QDELETED(active) && QDELETED(offhand), "Deleting the rat must delete both owned intent datums.")
	TEST_ASSERT_NULL(active.mastermob, "The active intent must release its deleted rat.")
	TEST_ASSERT_NULL(offhand.mastermob, "The offhand intent must release its deleted rat.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Rat interaction, refresh and deletion must not call procs or qdel on a type path.")

/// Exercise the actual vampire spell and holder restore path reported in the round log.
/datum/unit_test/runtime_nov07_rat_form_restore
	var/datum/mind/player

/datum/unit_test/runtime_nov07_rat_form_restore/Destroy()
	player?.RemoveAllSpells()
	player = null
	return ..()

/datum/unit_test/runtime_nov07_rat_form_restore/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	caster.mind_initialize()
	player = caster.mind
	var/obj/effect/proc_holder/spell/targeted/shapeshift/rat/spell = allocate(/obj/effect/proc_holder/spell/targeted/shapeshift/rat)
	player.AddSpell(spell)
	var/runtimes_before = GLOB.total_runtimes
	for(var/iteration in 1 to 2)
		spell.Shapeshift(caster)
		var/mob/living/simple_animal/hostile/retaliate/smallrat/shape = player.current
		TEST_ASSERT(istype(shape), "Rat Form must still transfer the caster into a small rat.")
		TEST_ASSERT(istype(shape.a_intent, /datum/intent), "Each new rat body must initialize an actionable intent before the first click.")
		// MouseDown selects this intent, and restoring the human then calls stop_attack during deletion.
		shape.used_intent = shape.a_intent
		TEST_ASSERT_EQUAL(shape.used_intent.get_chargetime(), 0, "A rat's first left click must have a valid uncharged intent.")
		shape.atkswinging = TRUE
		var/datum/intent/shape_intent = shape.used_intent
		TEST_ASSERT(spell.Restore(shape), "Rat Form must still restore the original body.")
		TEST_ASSERT(player.current == caster && !caster.notransform, "Restoration must return control to the untransformed caster.")
		TEST_ASSERT(QDELETED(shape), "Restoration must delete the temporary rat body.")
		TEST_ASSERT(QDELETED(shape_intent), "Restoration must clean up the rat's selected intent.")
		TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Repeated Rat Form casts and restores must not fail during intent cleanup.")
