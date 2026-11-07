/// Exercise invalidation between ChangeTurf's snapshot and restoration through its real signal.
/datum/component/runtime_nov07_turf_light_removal/Initialize()
	if(!isturf(parent))
		return COMPONENT_INCOMPATIBLE
	RegisterSignal(parent, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))

/datum/component/runtime_nov07_turf_light_removal/proc/on_turf_change(turf/source)
	SIGNAL_HANDLER
	qdel(source.lighting_object, TRUE)

/datum/runtime_nov07_lighting_fixture
	var/turf/changed_turf
	var/original_type
	var/original_baseturfs
	var/area/lighting_area
	var/original_area_lighting
	var/list/saved_sources
	var/list/saved_corners
	var/list/saved_objects
	var/isolated_queues = FALSE

/datum/runtime_nov07_lighting_fixture/Destroy()
	if(isolated_queues)
		SSlighting.sources_queue = saved_sources
		SSlighting.corners_queue = saved_corners
		SSlighting.objects_queue = saved_objects
	if(changed_turf)
		qdel(changed_turf.GetComponent(/datum/component/runtime_nov07_turf_light_removal))
		if(QDELETED(changed_turf.lighting_object))
			SSlighting.objects_queue -= changed_turf.lighting_object
			changed_turf.lighting_object = null
		changed_turf.ChangeTurf(original_type, original_baseturfs, CHANGETURF_FORCEOP)
	lighting_area.set_dynamic_lighting(original_area_lighting)
	return ..()

/datum/runtime_nov07_lighting_fixture/New(turf/target)
	changed_turf = target
	original_type = changed_turf.type
	original_baseturfs = islist(changed_turf.baseturfs) ? changed_turf.baseturfs.Copy() : changed_turf.baseturfs
	lighting_area = get_area(changed_turf)
	original_area_lighting = lighting_area.dynamic_lighting
	// The shared test room is normally fullbright. Exercise the dynamic-lighting
	// lifecycle used by the oasis, including the area's ordinary overlay setup.
	lighting_area.set_dynamic_lighting(DYNAMIC_LIGHTING_ENABLED)
	changed_turf.lighting_build_overlay()

/datum/runtime_nov07_lighting_fixture/proc/ready()
	return SSlighting.initialized && IS_DYNAMIC_LIGHTING(lighting_area) && IS_DYNAMIC_LIGHTING(changed_turf) && !QDELETED(changed_turf.lighting_object)

/datum/runtime_nov07_lighting_fixture/proc/isolate_queues()
	saved_sources = SSlighting.sources_queue
	saved_corners = SSlighting.corners_queue
	saved_objects = SSlighting.objects_queue
	SSlighting.sources_queue = list()
	SSlighting.corners_queue = list()
	SSlighting.objects_queue = list()
	isolated_queues = TRUE

/// Same-type LoadOnTop is the path used when the moving oasis loads its map template.
/datum/unit_test/runtime_nov07_loaded_turf_lighting/Run()
	var/datum/runtime_nov07_lighting_fixture/fixture = allocate(/datum/runtime_nov07_lighting_fixture)
	TEST_ASSERT(fixture.ready(), "The fixture must have initialized dynamic lighting in both its turf and area.")
	var/datum/lighting_object/old_light = fixture.changed_turf.lighting_object
	old_light.update()
	old_light.needs_update = FALSE
	SSlighting.objects_queue -= old_light
	fixture.changed_turf.AddComponent(/datum/component/runtime_nov07_turf_light_removal)
	var/runtimes_before = GLOB.total_runtimes
	fixture.changed_turf = fixture.changed_turf.LoadOnTop(fixture.changed_turf.type, CHANGETURF_DEFER_CHANGE | CHANGETURF_FORCEOP)
	TEST_ASSERT(QDELETED(old_light), "The turf-change callback must invalidate the original lighting snapshot.")
	TEST_ASSERT(!QDELETED(fixture.changed_turf.lighting_object), "A lit turf must receive a live replacement overlay.")
	TEST_ASSERT(fixture.changed_turf.lighting_object != old_light, "LoadOnTop must not restore its deleted lighting snapshot.")
	TEST_ASSERT(fixture.changed_turf.lighting_object.affected_turf == fixture.changed_turf, "The replacement overlay must belong to the loaded turf.")
	TEST_ASSERT(!(old_light in SSlighting.objects_queue), "The invalid snapshot must stay out of the lighting queue.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Loading a turf must not call update on a deleted overlay.")

/// A queued snapshot used to escape the immediate update and poison a later lighting tick instead.
/datum/unit_test/runtime_nov07_queued_turf_lighting/Run()
	var/datum/runtime_nov07_lighting_fixture/fixture = allocate(/datum/runtime_nov07_lighting_fixture)
	TEST_ASSERT(fixture.ready(), "The fixture must have initialized dynamic lighting in both its turf and area.")
	var/datum/lighting_object/old_light = fixture.changed_turf.lighting_object
	fixture.changed_turf.AddComponent(/datum/component/runtime_nov07_turf_light_removal)
	var/runtimes_before = GLOB.total_runtimes
	fixture.changed_turf = fixture.changed_turf.LoadOnTop(fixture.changed_turf.type, CHANGETURF_DEFER_CHANGE | CHANGETURF_FORCEOP)
	TEST_ASSERT(QDELETED(old_light), "The queued lighting snapshot must be deleted by the turf-change callback.")
	TEST_ASSERT(!QDELETED(fixture.changed_turf.lighting_object), "A queued snapshot must also be replaced after invalidation.")
	TEST_ASSERT(fixture.changed_turf.lighting_object != old_light, "A queued deleted overlay must never be restored to the turf.")
	TEST_ASSERT(!(old_light in SSlighting.objects_queue), "Deletion must remove the obsolete queued overlay.")
	TEST_ASSERT(fixture.changed_turf.lighting_object in SSlighting.objects_queue, "The replacement must still receive its ordinary lighting update.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Queued lighting invalidation must not cause runtimes.")

/// Recover a turf already left with the stale reference produced by the old LoadOnTop path.
/datum/unit_test/runtime_nov07_stale_lighting_corner/Run()
	var/datum/runtime_nov07_lighting_fixture/fixture = allocate(/datum/runtime_nov07_lighting_fixture)
	TEST_ASSERT(fixture.ready(), "The fixture must have initialized dynamic lighting in both its turf and area.")
	var/datum/lighting_object/old_light = fixture.changed_turf.lighting_object
	qdel(old_light, TRUE)
	fixture.changed_turf.lighting_object = old_light
	var/list/corners = fixture.changed_turf.get_corners()
	TEST_ASSERT(length(corners), "The fixture must have real lighting corners.")
	var/datum/lighting_corner/corner = corners[1]
	var/runtimes_before = GLOB.total_runtimes
	corner.update_objects()
	TEST_ASSERT(!QDELETED(fixture.changed_turf.lighting_object), "A corner update must repair an invalid turf overlay.")
	TEST_ASSERT(fixture.changed_turf.lighting_object != old_light, "Corner updates must replace rather than requeue the deleted object.")
	TEST_ASSERT(!(old_light in SSlighting.objects_queue), "A dead overlay must never reenter the object queue.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Recovering a stale turf overlay must not cause runtimes.")

/// A bad queue entry must not prevent live overlays later in the same queue from being updated.
/datum/unit_test/runtime_nov07_stale_lighting_queue/Run()
	var/datum/runtime_nov07_lighting_fixture/fixture = allocate(/datum/runtime_nov07_lighting_fixture)
	TEST_ASSERT(fixture.ready(), "The fixture must have initialized dynamic lighting in both its turf and area.")
	var/datum/lighting_object/deleted_light = fixture.changed_turf.lighting_object
	qdel(deleted_light, TRUE)
	fixture.isolate_queues()
	SSlighting.objects_queue += deleted_light
	SSlighting.objects_queue += null
	fixture.changed_turf.lighting_build_overlay()
	var/datum/lighting_object/live_light = fixture.changed_turf.lighting_object
	var/runtimes_before = GLOB.total_runtimes
	SSlighting.fire(FALSE, TRUE)
	TEST_ASSERT(!length(SSlighting.objects_queue), "The lighting tick must drain invalid entries and the live overlay behind them.")
	TEST_ASSERT(!live_light.needs_update, "A stale entry must not starve later live lighting updates.")
	TEST_ASSERT(!QDELETED(live_light), "Recovering the queue must preserve valid lighting objects.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The lighting queue must recover without an assertion loop.")
