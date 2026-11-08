/// Combat wounds must not retain animals after their bodies are deleted.
/datum/unit_test/animal_wound_cleanup
	var/list/applied_wounds

/datum/unit_test/animal_wound_cleanup/Run()
	for(var/path in list(/mob/living/simple_animal/hostile/retaliate/rogue/wolf, /mob/living/simple_animal/hostile/retaliate/rogue/bigrat, /mob/living/simple_animal/hostile/retaliate/rogue/spider/rock))
		for(var/body_state in list("living", "corpse", "healed corpse"))
			var/mob/living/simple_animal/animal = create_wounded_animal(path, body_state)
			qdel(animal)
			// Capture before property assertions: BYOND retains the last field receiver in a temporary.
			var/remaining_refs = refcount(animal)
			TEST_ASSERT(remaining_refs <= baseline_refs(), "Wounds must not retain deleted [path] ([body_state], [remaining_refs] references; baseline [baseline_refs()]).")
			TEST_ASSERT_NULL(animal.simple_wounds, "Deleting [path] must release its simple wound list.")
			TEST_ASSERT_EQUAL(animal.simple_bleeding, 0, "Wound removal must clear cached bleeding.")
			for(var/datum/wound/wound as anything in applied_wounds)
				// Ordinary healing detaches wounds for native GC; this test deliberately retains them.
				if(body_state != "healed corpse")
					TEST_ASSERT(QDELETED(wound), "Every attached wound must be destroyed with [path] ([body_state]).")
				TEST_ASSERT_NULL(wound.owner, "Removed wounds must release [path] ([body_state]).")
			applied_wounds = null

/// End the setup frame before refcount() so list operations and assertions cannot retain the animal.
/datum/unit_test/animal_wound_cleanup/proc/create_wounded_animal(path, body_state)
	var/mob/living/simple_animal/animal = new path(run_loc_floor_bottom_left)
	applied_wounds = list(
		animal.simple_add_wound(/datum/wound/slash, silent = TRUE),
		animal.simple_add_wound(/datum/wound/bruise, silent = TRUE),
	)
	if(length(animal.simple_wounds) != 2)
		TEST_FAIL("[path] must receive both combat wounds for this regression test.")
	if(body_state == "healed corpse")
		animal.heal_all_wounds(10000)
		if(length(animal.simple_wounds))
			TEST_FAIL("Ordinary healing must still remove all healed wounds.")
	if(body_state != "living")
		animal.death()
		if(animal.stat != DEAD)
			TEST_FAIL("The test animal must leave a corpse before deletion.")
	if(body_state != "healed corpse")
		if(length(animal.simple_wounds) != 2)
			TEST_FAIL("Living animals and intact corpses must keep their wounds until deletion.")
		for(var/datum/wound/wound as anything in applied_wounds)
			if(QDELETED(wound) || wound.owner != animal)
				TEST_FAIL("Living animals and intact corpses must retain their active wound ownership.")
	return animal

/// Verify real collection, rather than weakref.resolve() which hides objects as soon as qdel starts.
/datum/unit_test/animal_wound_native_gc/Run()
	var/list/references = list()
	for(var/path in list(/mob/living/simple_animal/hostile/retaliate/rogue/wolf, /mob/living/simple_animal/hostile/retaliate/rogue/bigrat, /mob/living/simple_animal/hostile/retaliate/rogue/spider/rock))
		references["[path]"] = create_deleted_animal(path)
	// Leave the ordinary garbage queue and its timeout unchanged; retain only reference strings.
	sleep(10 SECONDS)
	for(var/path in references)
		var/datum/remaining = locate(references[path])
		TEST_ASSERT_NULL(remaining, "Wounded [path] must be collected by the ordinary garbage queue without a hard delete.")

/datum/unit_test/animal_wound_native_gc/proc/create_deleted_animal(path)
	var/mob/living/simple_animal/animal = new path(run_loc_floor_bottom_left)
	animal.simple_add_wound(/datum/wound/slash, silent = TRUE)
	animal.simple_add_wound(/datum/wound/bruise, silent = TRUE)
	if(length(animal.simple_wounds) != 2)
		TEST_FAIL("[path] must receive both wounds before collection is tested.")
	animal.death()
	var/reference = text_ref(animal)
	qdel(animal)
	return reference
