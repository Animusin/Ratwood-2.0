/// Damage must retain the investigation clue and upstream action history on the same component.
/datum/unit_test/upstream_nov07_structure_breaks/Run()
	var/mob/living/carbon/human/consistent/first_attacker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/mob/living/carbon/human/consistent/later_attacker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	first_attacker.name = "first structure attacker"
	later_attacker.name = "later structure attacker"
	var/runtimes_before = GLOB.total_runtimes
	for(var/structure_type in list(/obj/structure/mineral_door/wood, /obj/structure/roguewindow))
		for(var/damage_method in list("generic", "thrown"))
			var/obj/structure/target = allocate(structure_type)
			var/obj/item/tool = allocate(/obj/item/rogueweapon/huntingknife)
			tool.name = "structure test knife"
			target.record_forensic_event(FORENSIC_EVENT_LOCKPICK_ATTEMPT, first_attacker, tool)
			var/datum/component/forensics/evidence = target.GetComponent(/datum/component/forensics)
			var/attempt_timer = evidence.forensic_event_timer
			var/break_damage = target.max_integrity * (1 - target.integrity_failure) + 1
			var/datum/thrownthing/flight
			var/expected_action = "broke by [first_attacker.name] (no player)"
			if(damage_method == "thrown")
				tool.add_blood_DNA(list("structure_test_donor" = "O+"))
				// Object hitby applies one tenth of the incoming throw force.
				tool.throwforce = break_damage * 10
				flight = new(tool, target, get_turf(target), NORTH, 1, 1, first_attacker, FALSE, MOVE_FORCE_DEFAULT)
				allocated += flight
				target.hitby(tool, hitpush = FALSE, throwingdatum = flight, damage_flag = 0)
				expected_action = "broke with thrown [format_text(tool.name)] by [first_attacker.name] (no player)"
			else
				target.attack_generic(first_attacker, break_damage, BRUTE, 0, FALSE)

			TEST_ASSERT(!QDELETED(target) && target.obj_broken, "[structure_type] must break without being destroyed by [damage_method] damage.")
			TEST_ASSERT_EQUAL(target.GetComponent(/datum/component/forensics), evidence, "Breaking must retain the existing evidence component.")
			var/list/clue = target.read_forensic_event()
			TEST_ASSERT_NOTNULL(clue, "A real [damage_method] break must leave a mechanical clue.")
			TEST_ASSERT_EQUAL(clue["type"], FORENSIC_EVENT_FORCED_BREAK, "Breaking must replace the earlier lockpick clue.")
			TEST_ASSERT_EQUAL(evidence.forensic_event_culprit?.resolve(), first_attacker, "The first attacker must own the mechanical clue.")
			TEST_ASSERT_NULL(timeleft(attempt_timer), "Replacing the attempted lockpick must cancel its expiry timer.")
			TEST_ASSERT(md5(first_attacker.dna.uni_identity) in target.return_fingerprints(), "Recording the break must retain its culprit's fingerprint.")
			// NPC attacks use the real unattributed-action path, including the actor's name, without a client fixture.
			TEST_ASSERT_EQUAL(length(evidence.actions), 1, "A first break must also create exactly one upstream forensic action.")
			var/datum/forensic_action/break_action = evidence.actions[1]
			TEST_ASSERT_EQUAL(break_action.action, expected_action, "The action must preserve the damage source even when the culprit has no client.")
			if(damage_method == "thrown")
				TEST_ASSERT_EQUAL(clue["tool"], tool.name, "The thrown weapon must remain attached to the mechanical clue.")
				TEST_ASSERT_EQUAL(target.return_blood_DNA()["structure_test_donor"], "O+", "Thrown contact must still transfer blood evidence.")

			var/break_timer = evidence.forensic_event_timer
			if(damage_method == "thrown")
				flight.thrower = later_attacker
				tool.throwforce = 20
				target.hitby(tool, hitpush = FALSE, throwingdatum = flight, damage_flag = 0)
			else
				target.attack_generic(later_attacker, 2, BRUTE, 0, FALSE)
			TEST_ASSERT_EQUAL(evidence.forensic_event_culprit?.resolve(), first_attacker, "Later damage to an already broken structure must not replace its culprit.")
			TEST_ASSERT_EQUAL(evidence.forensic_event_timer, break_timer, "Later damage must not extend the original break clue's lifetime.")
			TEST_ASSERT_EQUAL(length(evidence.actions), 1, "Later damage must not invent a second break action.")
			TEST_ASSERT_EQUAL(break_action.count, 1, "An already broken structure must not count another break.")
			qdel(flight)
			qdel(target)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Combining break clues and forensic actions must not runtime.")

/// Observe the real animation and logging calls without replacing either implementation.
/obj/structure/mineral_door/wood/unit_test_nov07
	close_delay = -1
	var/updates_after_delete = 0
	var/opened_action_calls = 0

/obj/structure/mineral_door/wood/unit_test_nov07/update_icon()
	if(QDELETED(src))
		updates_after_delete++
	return ..()

/obj/structure/mineral_door/wood/unit_test_nov07/add_forensic_action(mob/user, action, routine = FALSE, only_if_tracked = FALSE)
	if(action == "opened")
		opened_action_calls++
	return ..()

/datum/unit_test/upstream_nov07_key_door_animation/proc/delete_during_animation(datum/target)
	sleep(1)
	qdel(target)

/// Both key branches resume after Open sleeps; neither may log or schedule work for a deleted participant.
/datum/unit_test/upstream_nov07_key_door_animation/Run()
	var/runtimes_before = GLOB.total_runtimes
	for(var/use_keyring in list(FALSE, TRUE))
		for(var/deleted_participant in list("door", "user", "none"))
			var/obj/structure/mineral_door/wood/unit_test_nov07/door = allocate(/obj/structure/mineral_door/wood/unit_test_nov07)
			var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
			var/obj/item/roguekey/key = allocate(/obj/item/roguekey)
			key.lockhash = door.lockhash
			door.locked = TRUE
			door.last_bump = world.time - 20
			user.cmode = FALSE
			var/obj/item/held_key = key
			if(use_keyring)
				var/obj/item/storage/keyring/ring = allocate(/obj/item/storage/keyring)
				// Set up matching contents directly; this test exercises door handling, not storage insertion.
				key.forceMove(ring)
				held_key = ring
			TEST_ASSERT(user.put_in_hands(held_key), "The key fixture must be held before bumping the locked door.")
			TEST_ASSERT_EQUAL(user.get_active_held_item(), held_key, "Bumped must find the matching key or keyring in the active hand.")
			if(deleted_participant != "none")
				INVOKE_ASYNC(src, PROC_REF(delete_during_animation), deleted_participant == "door" ? door : user)
			door.Bumped(user)
			TEST_ASSERT(door.isSwitchingStates, "Key/autobump must enter the real opening animation.")
			// Bumped inherits waitfor=FALSE, so wait for the sleeping key-handler continuation too.
			sleep(3)
			TEST_ASSERT_EQUAL(door.updates_after_delete, 0, "The real animation must not update a deleted door.")
			if(deleted_participant == "none")
				TEST_ASSERT(door.door_opened && !door.density, "An uninterrupted matching key must still open the door.")
				TEST_ASSERT_EQUAL(door.opened_action_calls, 1, "A successful key opening must still reach upstream forensic logging.")
				TEST_ASSERT_EQUAL(door.last_bumper, user, "A successful key opening must retain its auto-close participant.")
				TEST_ASSERT(length(door.active_timers), "A successful key opening must still schedule auto-close.")
			else
				TEST_ASSERT(QDELETED(deleted_participant == "door" ? door : user), "The selected participant must be deleted during Open.")
				TEST_ASSERT_EQUAL(door.opened_action_calls, 0, "An interrupted key opening must stop before forensic logging.")
				TEST_ASSERT_NULL(door.last_bumper, "An interrupted key opening must not retain a deleted participant.")
				TEST_ASSERT(!length(door.active_timers), "An interrupted key opening must not schedule auto-close.")
			qdel(door)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Key and keyring animation continuations must not runtime after deletion.")
