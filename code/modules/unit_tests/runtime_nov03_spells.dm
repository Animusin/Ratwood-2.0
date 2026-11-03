/mob/living/carbon/human/consistent/spell_particle_test/proc/count_spell_particles()
	var/count = 0
	for(var/obj/effect/temp_visual/particle_up/particle in vis_contents)
		if(!QDELETED(particle))
			count++
	return count

/// A previous charge's delayed callback must not attach a second stream to the next charge.
/datum/unit_test/runtime_spell_particles_recharge/Run()
	var/mob/living/carbon/human/consistent/spell_particle_test/caster = allocate(/mob/living/carbon/human/consistent/spell_particle_test)
	caster.start_spell_visual_effects("#FF0000")
	sleep(1 SECONDS)
	caster.cancel_spell_visual_effects()
	caster.start_spell_visual_effects("#00FF00")
	var/obj/effect/temp_visual/particle_up/initial_particle = locate(/obj/effect/temp_visual/particle_up) in caster.vis_contents
	sleep(4 SECONDS)
	TEST_ASSERT(QDELETED(initial_particle), "A held charge must replace expired particles with a fresh emission.")
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 1, "Restarting a charge must leave one particle stream, not the old and new timer chains.")
	for(var/obj/effect/temp_visual/particle_up/particle in caster.vis_contents)
		TEST_ASSERT_EQUAL(lowertext(particle.color), "#00ff00", "A new charge must not emit particles using the previous spell's color.")
	caster.cancel_spell_visual_effects()
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 0, "Cancelling a held charge must remove its current particles immediately.")

/// A successful cast keeps its finishing wave but cannot leave its charging loop running.
/datum/unit_test/runtime_spell_particles_finish/Run()
	var/mob/living/carbon/human/consistent/spell_particle_test/caster = allocate(/mob/living/carbon/human/consistent/spell_particle_test)
	caster.start_spell_visual_effects()
	var/obj/effect/spell_rune_under/rune = caster.spell_rune
	caster.finish_spell_visual_effects()
	TEST_ASSERT(QDELETED(rune), "Finishing a cast must delete its charging rune.")
	TEST_ASSERT_NULL(caster.spell_rune, "Finishing a cast must release the rune reference.")
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 0, "Finishing a cast must remove the charging particles.")
	var/obj/effect/temp_visual/wave_up/wave = locate(/obj/effect/temp_visual/wave_up) in caster.vis_contents
	TEST_ASSERT(!QDELETED(wave), "A successful cast must still display its finishing wave.")
	sleep(4 SECONDS)
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 0, "A completed charge must not restart when its former timer would have fired.")
	TEST_ASSERT(QDELETED(wave), "The finishing wave must retain its normal finite lifetime.")

/// Deleting the caster also owns cleanup of a rune created outside a surviving spell action.
/datum/unit_test/runtime_spell_particles_caster_deleted/Run()
	var/mob/living/carbon/human/consistent/spell_particle_test/caster = allocate(/mob/living/carbon/human/consistent/spell_particle_test)
	caster.start_spell_visual_effects()
	var/obj/effect/spell_rune_under/rune = caster.spell_rune
	var/obj/effect/temp_visual/particle_up/particle = locate(/obj/effect/temp_visual/particle_up) in caster.vis_contents
	qdel(caster)
	TEST_ASSERT(QDELETED(rune), "Deleting a caster must delete its owned charging rune.")
	TEST_ASSERT(QDELETED(particle), "Deleting a caster must delete the rune's current particles.")
	TEST_ASSERT_NULL(rune.active_timers, "A deleted rune must not retain a particle timer.")

/// qdel marks the action deleted before Destroy, so the normal cancel guard cannot clean it up.
/datum/unit_test/runtime_spell_particles_action_deleted/Run()
	var/mob/living/carbon/human/consistent/spell_particle_test/caster = allocate(/mob/living/carbon/human/consistent/spell_particle_test)
	var/datum/action/cooldown/spell/projectile/basic_offensive/spell = allocate(/datum/action/cooldown/spell/projectile/basic_offensive)
	spell.Grant(caster)
	spell.on_start_charge()
	var/obj/effect/spell_rune_under/rune = caster.spell_rune
	TEST_ASSERT(!QDELETED(rune), "The spell must actually start charging before deletion.")
	TEST_ASSERT(caster.channeling_spell == spell, "The charged action must own the caster's channel.")
	qdel(spell)
	TEST_ASSERT(QDELETED(rune), "Deleting the active spell must delete its charging rune on the surviving caster.")
	TEST_ASSERT_NULL(caster.channeling_spell, "The caster must not retain a deleted charging action.")
	TEST_ASSERT_NULL(caster.spell_rune, "Deleting the active spell must release its rune.")
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 0, "Deleting the active spell must remove its particles.")
	TEST_ASSERT(!caster.tempfixeye && !caster.nodirchange, "Deleting the active spell must restore the caster's normal facing controls.")
	TEST_ASSERT(!(spell in SSmousecharge.processing), "A deleted charge must leave the charge subsystem.")

/// Removing another learned spell must preserve the current spell's rune and charge state.
/datum/unit_test/runtime_spell_particles_other_action_deleted/Run()
	var/mob/living/carbon/human/consistent/spell_particle_test/caster = allocate(/mob/living/carbon/human/consistent/spell_particle_test)
	var/datum/action/cooldown/spell/projectile/basic_offensive/active_spell = allocate(/datum/action/cooldown/spell/projectile/basic_offensive)
	var/datum/action/cooldown/spell/projectile/basic_offensive/other_spell = allocate(/datum/action/cooldown/spell/projectile/basic_offensive)
	active_spell.Grant(caster)
	other_spell.Grant(caster)
	active_spell.on_start_charge()
	var/obj/effect/spell_rune_under/rune = caster.spell_rune
	qdel(other_spell)
	TEST_ASSERT(!QDELETED(rune) && caster.spell_rune == rune, "Deleting an unrelated spell must preserve the active rune.")
	TEST_ASSERT(caster.channeling_spell == active_spell, "Deleting an unrelated spell must preserve the current channel.")
	TEST_ASSERT_EQUAL(caster.count_spell_particles(), 1, "Deleting an unrelated spell must preserve the current particles.")
	active_spell.cancel_casting()
