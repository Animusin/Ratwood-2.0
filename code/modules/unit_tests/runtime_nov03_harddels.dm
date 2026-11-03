/// A body may remember its former occupant for revival, but not after that mind is destroyed.
/datum/unit_test/runtime_former_body_mind_cleanup/Run()
	var/mob/living/carbon/human/consistent/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/new_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	var/datum/mind/character = old_body.mind
	character.transfer_to(new_body)
	// TEST_ASSERT_EQUAL retains lhs/rhs locals until Run returns, skewing the later refcount check.
	TEST_ASSERT(old_body.last_mind == character, "A former body must remember its living mind for revival.")
	TEST_ASSERT(new_body.last_mind == character, "The new body must remember its current mind.")

	qdel(character)

	TEST_ASSERT_NULL(old_body.last_mind, "A previous body must release a mind deleted after it transferred away.")
	TEST_ASSERT_NULL(new_body.last_mind, "The current body must release its deleted mind.")
	TEST_ASSERT_NULL(new_body.mind, "Deleting the mind must detach it from the active body.")
	TEST_ASSERT(refcount(character) <= baseline_refs(), "Former bodies must not force the deleted mind into a hard delete ([refcount(character)] references; baseline [baseline_refs()]).")

/// A replacement occupant must not be cleared when the former mind later disappears.
/datum/unit_test/runtime_last_mind_reassignment/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/mind/first = new
	var/datum/mind/second = allocate(/datum/mind, "runtime_last_mind_replacement")
	body.set_last_mind(first)
	body.set_last_mind(second)

	qdel(first)

	TEST_ASSERT_EQUAL(body.last_mind, second, "Deleting the old mind must preserve the replacement occupant.")
	TEST_ASSERT(refcount(first) <= baseline_refs(), "Reassigning a remembered mind must release the earlier subscription and reference.")
	body.set_last_mind(null)
	TEST_ASSERT(!QDELETED(second), "Forgetting a mind must not delete it.")

/// Hidden antag targets never become HUD viewers, so viewer-only cleanup misses their bodies.
/datum/unit_test/runtime_hud_target_cleanup/Run()
	var/datum/atom_hud/antag/hidden/hud = allocate(/datum/atom_hud/antag/hidden)
	var/mob/living/carbon/human/consistent/target = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent)
	hud.add_to_hud(target)
	hud.add_hud_to(viewer)
	hud.hide_single_atomhud_from(viewer, target)
	TEST_ASSERT(target in hud.hudatoms, "The hidden HUD must contain its target.")
	TEST_ASSERT(!(target in hud.hudusers), "The target must not also be a viewer in this scenario.")

	qdel(target)

	TEST_ASSERT(!(target in hud.hudatoms), "A target-only HUD must release a deleted body.")
	TEST_ASSERT(!(target in hud.hud_exceptions[viewer]), "Hidden-target exceptions must release the deleted body too.")
	TEST_ASSERT(viewer in hud.hudusers, "Deleting a target must preserve the remaining viewer.")
	TEST_ASSERT(refcount(target) <= baseline_refs(), "A HUD target must not require hard deletion ([refcount(target)] references; baseline [baseline_refs()]).")

/// Removing a target role must not detach the deletion listener still needed by its viewer cooldown.
/datum/unit_test/runtime_hud_target_viewer_cleanup/Run()
	var/datum/atom_hud/antag/hud = allocate(/datum/atom_hud/antag)
	var/mob/living/carbon/human/consistent/subject = new(run_loc_floor_bottom_left)
	hud.add_to_hud(subject)
	hud.add_hud_to(subject)
	hud.remove_from_hud(subject)
	hud.remove_hud_from(subject)
	TEST_ASSERT(subject in hud.next_time_allowed, "Leaving the HUD must retain its normal rejoin cooldown.")
	hud.add_to_hud(subject)

	qdel(subject)

	TEST_ASSERT(!(subject in hud.hudatoms), "Target membership must be cleared after removal and readdition.")
	TEST_ASSERT(!(subject in hud.next_time_allowed), "The viewer cooldown must release its deleted mob.")
	TEST_ASSERT(!(subject in hud.queued_to_see), "A deleted mob must not remain queued to view the HUD.")
	TEST_ASSERT(refcount(subject) <= baseline_refs(), "Shared target/viewer membership must not retain the deleted mob.")
