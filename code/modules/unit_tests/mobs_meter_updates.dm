/// Count real animation requests without replacing the production filter implementation.
/atom/movable/screen/stamina/unit_test_meter
	var/transition_count = 0

/atom/movable/screen/stamina/unit_test_meter/transition_filter(name, list/new_params, time, easing, loop)
	transition_count++
	return ..()

/atom/movable/screen/energy/unit_test_meter
	var/transition_count = 0

/atom/movable/screen/energy/unit_test_meter/transition_filter(name, list/new_params, time, easing, loop)
	transition_count++
	return ..()

/// A clientless owner still exercises the real human HUD update methods with both meters present.
/datum/hud/unit_test_meters/New(mob/owner)
	mymob = owner
	human_owner = owner
	stamina = new /atom/movable/screen/stamina/unit_test_meter
	energy = new /atom/movable/screen/energy/unit_test_meter
	infodisplay += stamina
	infodisplay += energy

/datum/unit_test/mobs_meter_noop_updates/Run()
	var/atom/movable/screen/stamina/unit_test_meter/meter = allocate(/atom/movable/screen/stamina/unit_test_meter)
	meter.set_meter_fill(1, "stam100", "stam20", "stam10")
	TEST_ASSERT_NOTNULL(meter.get_filter("meter_fill"), "The initial meter must create its fill filter.")
	for(var/index in 1 to 10)
		meter.set_meter_fill(1, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.transition_count, 0, "An unchanged full meter must not restart its animation or rebuild its filters.")

	meter.set_meter_fill(0.5, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.transition_count, 1, "A different pixel offset must still animate.")
	meter.set_meter_fill(0.5001, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.transition_count, 1, "A different ratio with the same rounded pixel offset must keep the current animation.")

	meter.set_meter_fill(0.201, "stam100", "stam20", "stam10")
	var/transitions_before_warning = meter.transition_count
	meter.set_meter_fill(0.2, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.icon_state, "stam20", "Crossing the mid warning threshold must change the sprite even at the same pixel offset.")
	TEST_ASSERT_EQUAL(meter.transition_count, transitions_before_warning, "A warning-only sprite change must not restart the fill animation.")
	meter.set_meter_fill(0.101, "stam100", "stam20", "stam10")
	transitions_before_warning = meter.transition_count
	meter.set_meter_fill(0.1, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.icon_state, "stam10", "Crossing the low warning threshold must change the sprite even at the same pixel offset.")
	TEST_ASSERT_EQUAL(meter.transition_count, transitions_before_warning, "A low-warning-only change must not restart the fill animation.")

	meter.remove_filter("meter_fill")
	meter.set_meter_fill(0.1, "stam100", "stam20", "stam10")
	TEST_ASSERT_NOTNULL(meter.get_filter("meter_fill"), "A removed filter must be recreated even when the requested fill is unchanged.")
	TEST_ASSERT_EQUAL(meter.filter_data["meter_fill"]["y"], -round(0.9 * 47), "A recreated filter must use the requested offset.")
	meter.set_meter_fill(-1, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.filter_data["meter_fill"]["y"], -47, "Ratios below zero must still clamp to an empty bar.")
	meter.set_meter_fill(2, "stam100", "stam20", "stam10")
	TEST_ASSERT_EQUAL(meter.filter_data["meter_fill"]["y"], 0, "Ratios above one must still clamp to a full bar.")
	TEST_ASSERT_EQUAL(meter.icon_state, "stam100", "Refilling the bar must restore the normal sprite.")

/datum/unit_test/mobs_meter_human_updates/Run()
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	var/datum/hud/unit_test_meters/hud = allocate(/datum/hud/unit_test_meters, subject)
	subject.hud_used = hud
	var/atom/movable/screen/stamina/unit_test_meter/stamina_meter = hud.stamina
	var/atom/movable/screen/energy/unit_test_meter/energy_meter = hud.energy
	subject.stamina = 0
	subject.max_stamina = 100
	subject.energy = 1000
	subject.max_energy = 1000
	subject.update_stamina_hud()
	subject.update_energy_hud()
	for(var/index in 1 to 10)
		subject.update_stamina_hud()
		subject.update_energy_hud()
	TEST_ASSERT_EQUAL(stamina_meter.transition_count + energy_meter.transition_count, 0, "Repeated human HUD refreshes at full resources must not animate unchanged meters.")

	subject.stamina = 25
	subject.last_fatigued = world.time
	subject.update_stamina()
	TEST_ASSERT_EQUAL(subject.stamina, 25, "The normal post-exertion regeneration delay must remain intact.")
	var/transitions_before_regen = stamina_meter.transition_count
	subject.last_fatigued = world.time - 100
	subject.update_stamina()
	TEST_ASSERT_EQUAL(subject.stamina, 0, "Stamina must still regenerate after its existing delay.")
	TEST_ASSERT_EQUAL(stamina_meter.transition_count, transitions_before_regen + 1, "Regeneration's nested and outer HUD refreshes must animate the new value only once.")
	TEST_ASSERT_EQUAL(subject.energy_add(500), FALSE, "Adding energy beyond capacity must retain the existing return value.")
	TEST_ASSERT_EQUAL(subject.energy, 1000, "Energy must retain its existing capacity clamp.")
	TEST_ASSERT_EQUAL(energy_meter.transition_count, 0, "An energy gain clamped to the existing full value must not animate.")

	subject.max_stamina = 0
	subject.max_energy = 0
	subject.update_stamina_hud()
	subject.update_energy_hud()
	TEST_ASSERT_EQUAL(stamina_meter.filter_data["meter_fill"]["y"], -47, "A zero stamina capacity must keep the existing empty-bar fallback.")
	TEST_ASSERT_EQUAL(energy_meter.filter_data["meter_fill"]["y"], -47, "A zero energy capacity must keep the existing empty-bar fallback.")
