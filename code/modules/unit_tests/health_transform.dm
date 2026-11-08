/// Observe transform side effects while retaining the real production updater.
/mob/living/carbon/human/consistent/health_transform_probe
	var/transform_vision_updates = 0
	var/transform_armor_updates = 0
	var/matrix/armor_callback_transform

/mob/living/carbon/human/consistent/health_transform_probe/update_vision_cone()
	transform_vision_updates++
	return ..()

/mob/living/carbon/human/consistent/health_transform_probe/update_inv_armor_special()
	transform_armor_updates++
	if(armor_callback_transform)
		transform = armor_callback_transform
	return ..()

/mob/living/carbon/human/consistent/health_transform_probe/proc/prepare_transform(old_lying = 0)
	mode = NPC_AI_OFF
	dna.species.custom_rotation_icon = FALSE
	armor_callback_transform = null
	lying = old_lying
	lying_prev = old_lying
	rotate_on_lying = TRUE
	resize = RESIZE_DEFAULT_SIZE
	is_shifted = FALSE
	mob_offsets = list("unit_test" = list("x" = 3, "y" = 5))
	pixel_x = 17
	pixel_y = 19
	dir = EAST
	movement_type = GROUND | FLOATING
	var/matrix/initial_transform = matrix(1.25, 0, 3, 0, 0.75, 4)
	initial_transform.Turn(old_lying)
	transform = initial_transform
	transform_vision_updates = 0
	transform_armor_updates = 0

/proc/health_transform_matrices_equal(matrix/actual, matrix/expected)
	return actual.a == expected.a && actual.b == expected.b && actual.c == expected.c && actual.d == expected.d && actual.e == expected.e && actual.f == expected.f

/// A skipped matrix allocation must not skip the existing pixel-offset repairs.
/datum/unit_test/health_transform_unchanged/Run()
	var/mob/living/carbon/human/consistent/health_transform_probe/subject = allocate(/mob/living/carbon/human/consistent/health_transform_probe)
	for(var/posture in list(0, 90))
		subject.prepare_transform(posture)
		var/matrix/expected = matrix(subject.transform)
		subject.update_transform(TRUE)
		TEST_ASSERT(health_transform_matrices_equal(subject.transform, expected), "An unchanged posture must preserve the existing transform.")
		TEST_ASSERT_EQUAL(subject.pixel_x, subject.get_standard_pixel_x_offset(), "Unchanged posture must still repair the horizontal offset.")
		TEST_ASSERT_EQUAL(subject.pixel_y, subject.get_standard_pixel_y_offset(posture), "Unchanged posture must still repair the appropriate vertical offset.")
		TEST_ASSERT_EQUAL(subject.dir, EAST, "Offset repair must not turn an unchanged mob.")
		TEST_ASSERT(subject.movement_type & FLOATING, "Offset repair must not clear FLOATING.")
		TEST_ASSERT_EQUAL(subject.transform_vision_updates, 0, "An unchanged transform must not refresh the vision cone.")

		subject.is_shifted = TRUE
		subject.pixel_x = 23
		subject.pixel_y = 29
		subject.update_transform()
		TEST_ASSERT_EQUAL(subject.pixel_x, 23, "An unchanged custom horizontal shift must survive.")
		TEST_ASSERT_EQUAL(subject.pixel_y, 29, "An unchanged custom vertical shift must survive.")

	subject.prepare_transform()
	subject.rotate_on_lying = FALSE
	subject.lying = 90
	var/matrix/expected = matrix(subject.transform)
	subject.update_transform()
	TEST_ASSERT(health_transform_matrices_equal(subject.transform, expected), "A mob that does not rotate on lying must retain its transform.")
	TEST_ASSERT_EQUAL(subject.lying_prev, 0, "A disabled lying rotation must not advance the previous posture.")
	TEST_ASSERT_EQUAL(subject.pixel_y, subject.get_standard_pixel_y_offset(90), "A disabled rotation must still repair the lying pixel offset.")
	TEST_ASSERT(subject.movement_type & FLOATING, "A disabled rotation must not clear FLOATING.")
	TEST_ASSERT_EQUAL(subject.transform_vision_updates, 0, "A disabled rotation must not refresh vision.")

/// Rotation, resizing and their combined path must retain all existing side effects.
/datum/unit_test/health_transform_changes/Run()
	var/mob/living/carbon/human/consistent/health_transform_probe/subject = allocate(/mob/living/carbon/human/consistent/health_transform_probe)
	var/list/scenarios = list(
		list("lie down", 0, 90, TRUE, 1),
		list("stand up", 90, 0, TRUE, 1),
		list("turn while lying", 90, 270, TRUE, 1),
		list("resize only", 0, 0, TRUE, 2),
		list("lying resize", 90, 90, TRUE, 0.5),
		list("rotate and resize", 0, 90, TRUE, 2),
		list("resize without rotation", 0, 90, FALSE, 2),
	)
	for(var/list/scenario as anything in scenarios)
		for(var/shifted in list(FALSE, TRUE))
			var/label = "[scenario[1]], shifted=[shifted]"
			var/old_lying = scenario[2]
			var/new_lying = scenario[3]
			var/should_rotate = scenario[4] && old_lying != new_lying
			subject.prepare_transform(old_lying)
			subject.lying = new_lying
			subject.rotate_on_lying = scenario[4]
			subject.resize = scenario[5]
			subject.is_shifted = shifted
			var/matrix/expected = matrix(subject.transform)
			if(should_rotate)
				expected.Turn(new_lying - old_lying)
			expected.Scale(scenario[5])
			var/expected_y = 19
			if(should_rotate && !old_lying && new_lying)
				// The existing standing-to-lying path resets pixel_y even while shifted.
				expected_y = subject.get_standard_pixel_y_offset(shifted ? 0 : new_lying)
			else if(should_rotate && !new_lying && !shifted)
				expected_y = subject.get_standard_pixel_y_offset()
			subject.update_transform()
			TEST_ASSERT(health_transform_matrices_equal(subject.transform, expected), "[label]: the transformed matrix must match rotation and scaling.")
			TEST_ASSERT_EQUAL(subject.lying_prev, should_rotate ? new_lying : old_lying, "[label]: the previous posture must update only for a real rotation.")
			TEST_ASSERT_EQUAL(subject.resize, RESIZE_DEFAULT_SIZE, "[label]: a resize must be consumed exactly once.")
			TEST_ASSERT_EQUAL(subject.pixel_x, shifted ? 17 : subject.get_standard_pixel_x_offset(), "[label]: horizontal shifts must retain their existing behavior.")
			TEST_ASSERT_EQUAL(subject.pixel_y, expected_y, "[label]: vertical shifts must retain their existing behavior.")
			TEST_ASSERT_EQUAL(subject.dir, should_rotate && !old_lying && new_lying ? SOUTH : EAST, "[label]: only falling sideways must change direction.")
			TEST_ASSERT(!(subject.movement_type & FLOATING), "[label]: a changed transform must clear FLOATING.")
			TEST_ASSERT(subject.movement_type & GROUND, "[label]: clearing FLOATING must retain the other movement flags.")
			TEST_ASSERT_EQUAL(subject.transform_vision_updates, 1, "[label]: a changed transform must refresh vision once.")

/// Custom-body armor callbacks must run after the original transform is copied.
/datum/unit_test/health_transform_custom_rotation/Run()
	var/mob/living/carbon/human/consistent/health_transform_probe/subject = allocate(/mob/living/carbon/human/consistent/health_transform_probe)
	for(var/standing in list(FALSE, TRUE))
		subject.prepare_transform(standing ? 90 : 0)
		subject.dna.species.custom_rotation_icon = TRUE
		subject.dna.species.custom_base_icon = "unit_test_body"
		subject.lying = standing ? 0 : 90
		if(standing)
			subject.mobility_flags |= MOBILITY_STAND
		else
			subject.mobility_flags &= ~MOBILITY_STAND
		subject.resize = 2
		var/matrix/expected = matrix(subject.transform)
		expected.Scale(2)
		var/matrix/callback_transform = matrix()
		callback_transform.Scale(4)
		subject.armor_callback_transform = callback_transform
		subject.update_transform()
		TEST_ASSERT_EQUAL(subject.transform_armor_updates, 1, "Custom-body posture changes must still refresh armor.")
		TEST_ASSERT_EQUAL(subject.icon_state, standing ? "unit_test_body" : "unit_test_body_down", "Custom-body posture changes must retain their sprite selection.")
		TEST_ASSERT(health_transform_matrices_equal(subject.transform, expected), "A custom-body callback must not replace the transform snapshot taken before it.")
		TEST_ASSERT_EQUAL(subject.lying_prev, subject.lying, "Custom-body posture changes must advance the previous posture.")
		TEST_ASSERT_EQUAL(subject.resize, RESIZE_DEFAULT_SIZE, "Custom-body posture changes must still consume resizing.")
