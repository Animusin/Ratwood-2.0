/// Throw out of the real damage wrapper before it can run end_forcing().
/obj/structure/upstream_nov07_forcing_probe
	var/interrupt_damage = TRUE

/obj/structure/upstream_nov07_forcing_probe/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armor_penetration = 0)
	if(interrupt_damage)
		throw "Interrupted forcing test attack"
	on_forced_break(damage_flag)
	return TRUE

/// Finish the catch's proc frame before checking the attacker's references.
/obj/structure/upstream_nov07_forcing_probe/proc/interrupt_attack(mob/living/attacker)
	try
		take_damage_from(attacker, 10, cause = "with an interrupted attack")
	catch(var/error)
		return error == "Interrupted forcing test attack"
	return FALSE

/// An interrupted damage call must not retain its attacker through the surviving structure.
/datum/unit_test/upstream_nov07_forcing_interrupted_cleanup/Run()
	var/obj/structure/upstream_nov07_forcing_probe/target = allocate(/obj/structure/upstream_nov07_forcing_probe)
	var/mob/living/attacker = new(run_loc_floor_bottom_left)
	var/interrupted = target.interrupt_attack(attacker)
	qdel(attacker)
	TEST_ASSERT(interrupted, "The fixture must interrupt take_damage_from before its cleanup.")
	// Settle BYOND's expression temporaries before sampling; QDELETED(attacker) can retain its operand.
	var/expected_refs = baseline_refs()
	var/actual_refs = refcount(attacker)
	TEST_ASSERT(actual_refs <= expected_refs, "A structure must not keep its interrupted attacker alive until another attack (refs: [actual_refs], baseline: [expected_refs]).")
	TEST_ASSERT(QDELETED(attacker), "The interrupted attacker's mob must be destroyed.")

/// A later fire must not inherit either the mob or the cause from an interrupted attack.
/datum/unit_test/upstream_nov07_forcing_stale_attribution/Run()
	var/obj/structure/upstream_nov07_forcing_probe/target = allocate(/obj/structure/upstream_nov07_forcing_probe)
	var/mob/living/attacker = allocate(/mob/living)
	var/interrupted = target.interrupt_attack(attacker)
	TEST_ASSERT(interrupted, "The fixture must leave an interrupted attack's attribution behind.")
	sleep(1)
	target.on_forced_break("fire")
	var/datum/component/forensics/evidence = target.GetComponent(/datum/component/forensics)
	TEST_ASSERT_NOTNULL(evidence, "A later fire must still leave forensic evidence.")
	TEST_ASSERT_EQUAL(length(evidence.actions), 1, "Only the later break must have been recorded.")
	var/datum/forensic_action/entry = evidence.actions[1]
	TEST_ASSERT_EQUAL(entry.action, "broke with fire", "An old attacker or cause must not be blamed for a later fire.")

/// Nested damage keeps the outer attribution, and an ordinary completed wrapper clears it immediately.
/datum/unit_test/upstream_nov07_forcing_nested_attribution/Run()
	var/obj/structure/upstream_nov07_forcing_probe/target = allocate(/obj/structure/upstream_nov07_forcing_probe)
	var/mob/living/outer = allocate(/mob/living)
	var/mob/living/inner = allocate(/mob/living)
	outer.name = "outer attacker"
	inner.name = "inner attacker"
	TEST_ASSERT(target.begin_forcing(outer, "with the outer strike"), "An outer attacker must acquire the attribution context.")
	TEST_ASSERT(!target.begin_forcing(inner, "with the inner strike"), "Nested damage must not replace the outer attacker.")
	target.on_forced_break("fire")
	var/datum/component/forensics/evidence = target.GetComponent(/datum/component/forensics)
	TEST_ASSERT_NOTNULL(evidence, "A forced break must create forensic evidence.")
	var/datum/forensic_action/entry = evidence.actions[1]
	TEST_ASSERT_EQUAL(entry.action, "broke with the outer strike by outer attacker (no player)", "The outer attack must retain its attacker and cause.")
	target.end_forcing()
	target.interrupt_damage = FALSE
	target.take_damage_from(inner, 10, cause = "with a completed attack")
	entry = evidence.actions[2]
	TEST_ASSERT_EQUAL(entry.action, "broke with a completed attack by inner attacker (no player)", "The ordinary damage wrapper must preserve current attribution.")
	target.on_forced_break("fire")
	entry = evidence.actions[3]
	TEST_ASSERT_EQUAL(entry.action, "broke with fire", "A completed attack must release attribution even within the same tick.")
	TEST_ASSERT(target.begin_forcing(null, "with an explosion"), "An unattributed explosion must still acquire the outer context.")
	TEST_ASSERT(!target.begin_forcing(inner), "Nested player damage must not take over an outer explosion.")
	target.on_forced_break("fire")
	entry = evidence.actions[4]
	TEST_ASSERT_EQUAL(entry.action, "broke with an explosion", "An outer explosion must retain its unattributed cause.")
	target.end_forcing()
