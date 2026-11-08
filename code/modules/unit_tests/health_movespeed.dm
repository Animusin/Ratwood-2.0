/// Observe the real speed recalculation, sorting request and emitted signal.
/mob/health_movespeed_probe
	var/speed_signals = 0
	var/list/resort_requests = list()

/mob/health_movespeed_probe/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_MOB_MOVESPEED_UPDATED, PROC_REF(on_speed_updated))

/mob/health_movespeed_probe/proc/on_speed_updated()
	SIGNAL_HANDLER
	speed_signals++

/mob/health_movespeed_probe/update_movespeed(resort = TRUE)
	resort_requests += resort
	return ..()

/mob/health_movespeed_probe/proc/reset_probe()
	movespeed_modification = null
	cached_multiplicative_slowdown = 0
	movement_type = GROUND
	speed_signals = 0
	resort_requests.Cut()

/mob/health_movespeed_probe/proc/add_test_modifier(list/data, update = TRUE, override = TRUE)
	return add_movespeed_modifier("test", update, data[1], data[2], override, data[3], data[4], data[5], data[6])

/// Identical data must remain the same list and must not publish another speed refresh.
/datum/unit_test/health_movespeed_identical/Run()
	var/mob/health_movespeed_probe/subject = allocate(/mob/health_movespeed_probe)
	subject.reset_probe()
	var/list/data = list(10, NONE, 2, ALL, NONE, FALSE)
	TEST_ASSERT(subject.add_test_modifier(data), "Adding the first speed modifier must report a change.")
	var/list/stored = subject.movespeed_modification["test"]
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "Adding a modifier must still change real movement speed.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "Adding a modifier must emit its speed signal.")
	for(var/override in list(FALSE, TRUE))
		TEST_ASSERT_EQUAL(subject.add_test_modifier(data, override = override), FALSE, "Identical data must remain a no-op with either override setting.")
		TEST_ASSERT_EQUAL(subject.movespeed_modification["test"], stored, "An identical update must retain the existing modifier list.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "Identical updates must not emit another speed signal.")
	TEST_ASSERT_EQUAL(length(subject.resort_requests), 1, "Identical updates must not rebuild or sort movement modifiers.")

	data[3] = 99
	TEST_ASSERT_EQUAL(subject.add_test_modifier(data, override = FALSE), FALSE, "A conflicting value without override must still be rejected.")
	TEST_ASSERT_EQUAL(subject.movespeed_modification["test"], stored, "Rejecting an override must preserve the original list.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "Rejecting an override must preserve movement speed.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "Rejecting an override must not emit a signal.")
	TEST_ASSERT_EQUAL(subject.remove_movespeed_modifier("absent"), FALSE, "Removing an absent modifier must remain a no-op.")

/// Every stored field affects modifier identity, including flags and movement masks.
/datum/unit_test/health_movespeed_changed_fields/Run()
	var/list/replacements = list(20, IGNORE_NOSLOW, 3, FLOATING, GROUND, "conflict_group")
	for(var/changed_index in 1 to MOVESPEED_DATA_INDEX_MAX)
		var/mob/health_movespeed_probe/subject = allocate(/mob/health_movespeed_probe)
		subject.reset_probe()
		var/list/data = list(10, NONE, 2, ALL, NONE, FALSE)
		subject.add_test_modifier(data)
		var/list/previous = subject.movespeed_modification["test"]
		data[changed_index] = replacements[changed_index]
		TEST_ASSERT(subject.add_test_modifier(data), "Changing field [changed_index] must replace the modifier.")
		var/list/stored = subject.movespeed_modification["test"]
		TEST_ASSERT_NOTEQUAL(stored, previous, "Changed data must be stored in a replacement list.")
		for(var/index in 1 to MOVESPEED_DATA_INDEX_MAX)
			TEST_ASSERT_EQUAL(stored[index], data[index], "Replacement must retain every field (changed [changed_index], field [index]).")
		TEST_ASSERT_EQUAL(subject.speed_signals, 2, "A real field change must still emit a signal even if its effective speed is unchanged.")
		TEST_ASSERT_EQUAL(length(subject.resort_requests), 2, "A real field change must still recalculate speed.")
		TEST_ASSERT_EQUAL(subject.resort_requests[2], changed_index == MOVESPEED_DATA_INDEX_PRIORITY, "Only a priority change should request a new sort for an existing modifier.")
		var/expected_slowdown = 2
		if(changed_index == MOVESPEED_DATA_INDEX_MULTIPLICATIVE_SLOWDOWN)
			expected_slowdown = 3
		else if(changed_index == MOVESPEED_DATA_INDEX_MOVETYPE || changed_index == MOVESPEED_DATA_INDEX_BL_MOVETYPE)
			expected_slowdown = 0
		TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, expected_slowdown, "Movement masks and slowdown values must retain their real effect.")

/// update=FALSE must keep both cached speed and signal timing under the caller's control.
/datum/unit_test/health_movespeed_deferred/Run()
	var/mob/health_movespeed_probe/subject = allocate(/mob/health_movespeed_probe)
	subject.reset_probe()
	var/list/data = list(10, NONE, 2, ALL, NONE, FALSE)
	TEST_ASSERT(subject.add_test_modifier(data, update = FALSE), "A deferred insertion must still store the modifier.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 0, "A deferred insertion must not refresh cached speed.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 0, "A deferred insertion must not emit a speed signal.")
	TEST_ASSERT_EQUAL(length(subject.resort_requests), 0, "A deferred insertion must not call update_movespeed.")
	subject.update_movespeed()
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "An explicit refresh must apply the deferred modifier.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "An explicit refresh must publish the new speed.")
	TEST_ASSERT_EQUAL(subject.add_test_modifier(data), FALSE, "An identical update must not become a forced refresh.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "An identical update after a deferred insertion must remain silent.")

	data[3] = 3
	TEST_ASSERT(subject.add_test_modifier(data, update = FALSE), "A deferred replacement must still update the stored data.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "A deferred replacement must retain cached speed until explicitly refreshed.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 1, "A deferred replacement must remain silent.")
	subject.update_movespeed(FALSE)
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 3, "An explicit refresh must apply a deferred replacement.")
	TEST_ASSERT(subject.remove_movespeed_modifier("test", update = FALSE), "A deferred removal must remove the stored modifier.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 3, "A deferred removal must not refresh cached speed.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 2, "A deferred removal must remain silent.")
	subject.update_movespeed(FALSE)
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 0, "An explicit refresh must apply the deferred removal.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 3, "Explicit refreshes must keep publishing speed updates.")

/// Short legacy data must be replaceable; priority changes must retain real sorting behavior.
/datum/unit_test/health_movespeed_legacy_and_sort/Run()
	var/mob/health_movespeed_probe/subject = allocate(/mob/health_movespeed_probe)
	subject.reset_probe()
	var/runtimes_before = GLOB.total_runtimes
	subject.movespeed_modification = list("test" = list(10))
	var/list/data = list(10, NONE, 2, ALL, NONE, FALSE)
	TEST_ASSERT(subject.add_test_modifier(data), "A short legacy list must not be mistaken for identical complete data.")
	TEST_ASSERT_EQUAL(length(subject.movespeed_modification["test"]), MOVESPEED_DATA_INDEX_MAX, "Replacing short data must store all six fields.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "Replacing short data must restore a usable modifier.")
	TEST_ASSERT_EQUAL(subject.resort_requests[1], FALSE, "Replacing short data with the same priority must preserve the existing sort decision.")
	subject.movespeed_modification["test"] = "legacy_invalid_data"
	TEST_ASSERT_EQUAL(subject.add_test_modifier(data, override = FALSE), FALSE, "A non-list existing value without override must still be rejected safely.")
	TEST_ASSERT_EQUAL(subject.movespeed_modification["test"], "legacy_invalid_data", "Rejecting malformed data without override must not mutate it.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Legacy-data checks must not read missing list fields.")

	subject.reset_probe()
	subject.add_movespeed_modifier("first", priority = 10, multiplicative_slowdown = 1)
	subject.add_movespeed_modifier("second", priority = 20, multiplicative_slowdown = 2)
	TEST_ASSERT_EQUAL(subject.movespeed_modification[1], "second", "Higher-priority modifiers must be sorted first.")
	subject.add_movespeed_modifier("first", priority = 30, override = TRUE, multiplicative_slowdown = 1)
	TEST_ASSERT_EQUAL(subject.movespeed_modification[1], "first", "Changing priority must reorder existing modifiers.")
	TEST_ASSERT_EQUAL(subject.resort_requests[3], TRUE, "Changing priority must request a real sort.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 3, "Sorting must retain the combined slowdown.")
	TEST_ASSERT(subject.remove_movespeed_modifier("first"), "Removing an existing modifier must report a change.")
	TEST_ASSERT_EQUAL(subject.cached_multiplicative_slowdown, 2, "Removing a modifier must immediately update speed by default.")
	TEST_ASSERT_EQUAL(subject.speed_signals, 4, "Each insertion, priority change and removal must publish its update.")
