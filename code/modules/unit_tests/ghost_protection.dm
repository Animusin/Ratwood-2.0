/// A ghost leaving must not remove another mob's appearance for the remaining ghosts.
/datum/unit_test/ghost_protection_observer_deletion/Run()
	var/mob/living/protected_mob = allocate(/mob/living)
	var/mob/dead/observer/leaving = allocate(/mob/dead/observer)
	var/mob/dead/observer/remaining = allocate(/mob/dead/observer)
	var/image/hidden_appearance = image('icons/blanks/32x32.dmi', protected_mob, "nothing")
	hidden_appearance.override = TRUE
	hidden_appearance.alpha = 0
	var/datum/atom_hud/alternate_appearance/basic/ghost_protection/protection = new("ghost_protection", hidden_appearance, NONE)
	allocated += protection
	// Headless tests have no clients. Register viewers directly to exercise deletion.
	protection.add_hud_to(leaving)
	protection.add_hud_to(remaining)
	qdel(leaving)
	TEST_ASSERT(!QDELETED(protection), "Deleting a viewer must not delete the protected mob's appearance.")
	TEST_ASSERT_EQUAL(protected_mob.alternate_appearances["ghost_protection"], protection, "The protected mob must retain its appearance.")
	TEST_ASSERT_EQUAL(protected_mob.hud_list["ghost_protection"], hidden_appearance, "The masking image must remain attached.")
	TEST_ASSERT(protection.hudusers[remaining], "Other ghosts must retain their protection HUD.")
	TEST_ASSERT(!(leaving in protection.next_time_allowed), "Deleted viewers must be removed from cooldowns.")
	TEST_ASSERT(!(leaving in protection.hudusers), "Deleted viewers must be removed from membership.")

	// The deletion signal also persists after membership ends, during the cooldown.
	protection.remove_hud_from(remaining)
	qdel(remaining)
	TEST_ASSERT(!QDELETED(protection), "Deleting a former viewer must not remove the protected appearance either.")
	TEST_ASSERT(!length(protection.next_time_allowed), "Former viewers must be removed from cooldowns.")

	// If the deleted mob really is the target, normal appearance cleanup must still run.
	protection.add_hud_to(protected_mob)
	qdel(protected_mob)
	TEST_ASSERT(QDELETED(protection), "Deleting the protected target must still delete its appearance.")
	TEST_ASSERT(!(protection in GLOB.active_alternate_appearances), "Deleted appearances must leave the active registry.")
