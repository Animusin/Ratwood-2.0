/// Removing a toggle's visual must also cancel its hours-long expiry callback.
/datum/unit_test/performance_flick_visual_early_removal/Run()
	var/obj/holder = allocate(/obj)
	var/atom/movable/flick_visual/visual = holder.flick_overlay_view(mutable_appearance('icons/mob/mob_effects.dmi', "eff_guard"), 9999 SECONDS)
	var/timer_id = visual.deletion_timer
	TEST_ASSERT_NOTNULL(timeleft(timer_id), "The visual must have a live expiry timer.")
	TEST_ASSERT(visual in holder.vis_contents, "The visual must be displayed until it is removed.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(visual)
	TEST_ASSERT_NULL(timeleft(timer_id), "Early removal must cancel the expiry callback instead of holding the visual for hours.")
	TEST_ASSERT_NULL(visual.deletion_timer, "The deleted visual must release its timer ID.")
	TEST_ASSERT_NULL(visual.container, "The deleted visual must release its former owner.")
	TEST_ASSERT(!(visual in holder.vis_contents), "Early removal must detach the visual from its owner.")
	TEST_ASSERT_EQUAL(refcount(visual), baseline_refs(), "The timer must no longer keep the deleted visual alive.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Cancelling a pending expiry must not recurse into destruction.")

/// Retaining a stoppable timer ID must preserve normal client-time expiry.
/datum/unit_test/performance_flick_visual_expiry/Run()
	var/obj/holder = allocate(/obj)
	var/atom/movable/flick_visual/visual = holder.flick_overlay_view(mutable_appearance('icons/mob/mob_effects.dmi', "eff_guard"), 1)
	var/timer_id = visual.deletion_timer
	var/datum/timedevent/timer = SStimer.timer_id_dict[timer_id]
	TEST_ASSERT(timer?.flags & TIMER_CLIENT_TIME, "Visual expiry must continue to use client time.")
	TEST_ASSERT(!QDELETED(visual), "Creating a short visual must not delete it immediately.")
	var/runtimes_before = GLOB.total_runtimes
	sleep(1 SECONDS)
	TEST_ASSERT(QDELETED(visual), "The expiry callback must still delete the visual.")
	TEST_ASSERT_NULL(timeleft(timer_id), "An elapsed expiry must release its timer ID.")
	TEST_ASSERT_NULL(visual.container, "An expired visual must release its former owner.")
	TEST_ASSERT(!(visual in holder.vis_contents), "An expired visual must disappear from its owner.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Natural expiry must not recursively delete its timer or visual.")

/// A retained projectile must not retain its already-deleted geometry.
/datum/unit_test/performance_projectile_geometry_cleanup/proc/set_beam_segment(obj/projectile/projectile, datum/point/beam_start, datum/point/beam_end)
	// Keep the associative-assignment key temporary outside Run's refcount measurements.
	projectile.beam_segments = list()
	projectile.beam_segments[beam_start] = beam_end

/datum/unit_test/performance_projectile_geometry_cleanup/Run()
	var/obj/projectile/projectile = allocate(/obj/projectile)
	var/datum/point/vector/trajectory = new(run_loc_floor_bottom_left)
	var/datum/point/beam_start = new(run_loc_floor_bottom_left)
	var/datum/point/beam_end = new(run_loc_floor_top_right)
	projectile.trajectory = trajectory
	projectile.beam_index = beam_start
	set_beam_segment(projectile, beam_start, beam_end)
	qdel(projectile)
	TEST_ASSERT_NULL(projectile.trajectory, "A destroyed projectile must release its trajectory.")
	TEST_ASSERT_NULL(projectile.beam_index, "A destroyed projectile must release its beam cursor.")
	TEST_ASSERT_EQUAL(length(projectile.beam_segments), 0, "A destroyed projectile must clear every beam segment.")
	TEST_ASSERT(QDELETED(trajectory) && QDELETED(beam_start) && QDELETED(beam_end), "All owned geometry must still be deleted.")
	TEST_ASSERT_EQUAL(refcount(trajectory), baseline_refs(), "The destroyed projectile must not pin its vector.")
	TEST_ASSERT_EQUAL(refcount(beam_start), baseline_refs(), "The destroyed projectile must not pin a beam's starting point.")
	TEST_ASSERT_EQUAL(refcount(beam_end), baseline_refs(), "The destroyed projectile must not pin a beam's ending point.")

/// Removing one seeker must not delete or detach the rest of its shared volley.
/datum/unit_test/performance_seeker_volley_cleanup/Run()
	var/obj/projectile/magic/seeker_orb/greater/spent = new(run_loc_floor_bottom_left)
	var/obj/projectile/magic/seeker_orb/greater/live = allocate(/obj/projectile/magic/seeker_orb/greater)
	var/list/volley = list(spent, live)
	spent.volley = volley
	live.volley = volley
	qdel(spent)
	TEST_ASSERT_NULL(spent.volley, "A spent orb must release the shared volley.")
	TEST_ASSERT_EQUAL(length(volley), 1, "Deleting one orb must remove only that orb from the volley.")
	TEST_ASSERT(live in volley, "The live sibling must remain in the volley.")
	TEST_ASSERT_EQUAL(live.volley, volley, "The live sibling must retain the shared list for future deflections.")
	TEST_ASSERT(!QDELETED(live), "Deleting one orb must not delete its siblings.")
	TEST_ASSERT_EQUAL(refcount(spent), baseline_refs(), "The shared volley must no longer pin the spent orb.")
	qdel(live)
	TEST_ASSERT_EQUAL(length(volley), 0, "Deleting the final orb must empty the shared volley.")

/// Even if the deflected orb is consumed, the surviving volley must still retarget together.
/datum/unit_test/performance_seeker_volley_deflection/Run()
	var/mob/living/caster = allocate(/mob/living)
	var/mob/living/defender = allocate(/mob/living)
	var/obj/projectile/magic/seeker_orb/greater/deflected = allocate(/obj/projectile/magic/seeker_orb/greater)
	var/obj/projectile/magic/seeker_orb/greater/sibling = allocate(/obj/projectile/magic/seeker_orb/greater)
	var/list/volley = list(deflected, sibling)
	deflected.volley = volley
	sibling.volley = volley
	deflected.firer = caster
	sibling.firer = caster
	// No starting turf: the parent consumes this orb instead of reflecting it.
	deflected.starting = null
	var/runtimes_before = GLOB.total_runtimes
	deflected.on_guard_deflect(defender, TRUE)
	TEST_ASSERT(QDELETED(deflected), "The fixture must consume the deflected orb.")
	TEST_ASSERT(!QDELETED(sibling), "Retargeting must preserve the surviving sibling.")
	TEST_ASSERT_EQUAL(sibling.firer, defender, "The surviving volley must credit its reflector.")
	TEST_ASSERT_EQUAL(sibling.homing_target, caster, "The surviving volley must still home back toward the caster.")
	TEST_ASSERT_EQUAL(length(volley), 1, "The consumed orb must not remain in the retargeted volley.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Cleaning up the consumed orb must not interrupt volley deflection.")
