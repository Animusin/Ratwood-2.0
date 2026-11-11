/datum/gc_failure_probe

/datum/gc_failure_probe/hinted/Destroy(force)
	..()
	return QDEL_HINT_HARDDEL

/// A collection failure must not turn into a world-wide reference sweep unless the operator asks for it.
/datum/unit_test/gc_failure_policy/Run()
	var/previous_setting = !!CONFIG_GET(flag/gc_failure_hard_deletes)
	var/datum/gc_failure_probe/probe = new
	allocated += probe

	CONFIG_SET(flag/gc_failure_hard_deletes, FALSE)
	var/leaks_before = SSgarbage.totalleaks
	var/left_alive = SSgarbage.leave_failure_alive(probe, 1)
	var/leaks_after_default = SSgarbage.totalleaks

	CONFIG_SET(flag/gc_failure_hard_deletes, TRUE)
	var/escalated = !SSgarbage.leave_failure_alive(probe, 1)
	var/leaks_after_enabled = SSgarbage.totalleaks
	CONFIG_SET(flag/gc_failure_hard_deletes, previous_setting)

	TEST_ASSERT(left_alive, "A failed collection must be left to its remaining references by default.")
	TEST_ASSERT_EQUAL(leaks_after_default, leaks_before + 1, "A failure left alive must be counted.")
	TEST_ASSERT(escalated, "With hard deletes enabled a failure must still escalate.")
	TEST_ASSERT_EQUAL(leaks_after_enabled, leaks_after_default, "An escalated failure is not a leak.")

/// An explicit hard delete hint is a statement by the type, not a collection failure, and keeps working.
/datum/unit_test/gc_failure_policy_explicit_hint/Run()
	var/previous_setting = !!CONFIG_GET(flag/gc_failure_hard_deletes)
	CONFIG_SET(flag/gc_failure_hard_deletes, FALSE)
	var/datum/gc_failure_probe/hinted/probe = new
	qdel(probe)
	CONFIG_SET(flag/gc_failure_hard_deletes, previous_setting)
	// Take it back out so the test world does not pay for a real reference sweep.
	var/list/delete_queue = SSgarbage.queues[GC_QUEUE_HARDDELETE]
	var/found = FALSE
	for(var/index in length(delete_queue) to 1 step -1)
		var/list/entry = delete_queue[index]
		if(entry[GC_QUEUE_ITEM_REF] == probe)
			delete_queue.Cut(index, index + 1)
			found = TRUE
			break
	TEST_ASSERT(found, "A type that asks for a hard delete must still be queued for one.")

/datum/gc_failure_probe/proc/noop()
	return

/// The log line for a failure must name the listeners and timers that outlived Destroy().
/datum/unit_test/gc_failure_clues/Run()
	var/datum/gc_failure_probe/target = new
	var/datum/gc_failure_probe/listener = new
	allocated += list(target, listener)
	TEST_ASSERT_EQUAL(length(listener.gc_failure_clues()), 0, "A clean object must not report clues.")
	listener.RegisterSignal(target, COMSIG_PARENT_QDELETING, TYPE_PROC_REF(/datum/gc_failure_probe, noop))
	var/timer = addtimer(CALLBACK(listener, TYPE_PROC_REF(/datum/gc_failure_probe, noop)), 10 MINUTES, TIMER_STOPPABLE)
	var/list/listener_clues = listener.gc_failure_clues()
	var/list/target_clues = target.gc_failure_clues()
	var/listener_text = listener_clues.Join("; ")
	var/target_text = target_clues.Join("; ")
	deltimer(timer)
	listener.UnregisterSignal(target, COMSIG_PARENT_QDELETING)
	TEST_ASSERT(findtext(listener_text, "still listening to 1 target(s): /datum/gc_failure_probe"), "A held subscription must name its target type, got: [listener_text]")
	TEST_ASSERT(findtext(listener_text, "1 timer(s)") && findtext(listener_text, "noop"), "A pending timer must name its callback, got: [listener_text]")
	TEST_ASSERT(findtext(target_text, "signal(s) listened to"), "The listened-to side must report the signal, got: [target_text]")

	var/obj/item/container = allocate(/obj/item)
	var/obj/item/inside = allocate(/obj/item)
	inside.forceMove(container)
	var/list/inside_clues = inside.gc_failure_clues()
	var/list/container_clues = container.gc_failure_clues()
	TEST_ASSERT(findtext(inside_clues.Join("; "), "inside /obj/item"), "An object still inside something must say so.")
	TEST_ASSERT(findtext(container_clues.Join("; "), "holds 1 object(s)"), "A container must report what it still holds.")
