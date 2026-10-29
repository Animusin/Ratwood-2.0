/// A healthy processor must yield at the same budget boundary as one leaving the queue.
/datum/unit_test/performance_machines_yield/Run()
	var/obj/machinery/performance_probe/first = allocate(/obj/machinery/performance_probe)
	var/obj/machinery/performance_probe/second = allocate(/obj/machinery/performance_probe)
	var/obj/machinery/performance_probe/third = allocate(/obj/machinery/performance_probe)
	var/list/old_processing = SSmachines.processing
	var/list/old_currentrun = SSmachines.currentrun
	var/old_state = SSmachines.state
	var/old_limit = Master.current_ticklimit
	SSmachines.processing = list(first, second, third)
	SSmachines.state = SS_RUNNING
	Master.current_ticklimit = -1
	SSmachines.fire()
	var/remaining_after_pause = length(SSmachines.currentrun)
	var/paused_state = SSmachines.state
	Master.current_ticklimit = INFINITY
	SSmachines.state = SS_RUNNING
	SSmachines.fire(TRUE)
	var/remaining_after_resume = length(SSmachines.currentrun)
	// Restore the live controller before any assertion can exit the test.
	SSmachines.processing = old_processing
	SSmachines.currentrun = old_currentrun
	SSmachines.state = old_state
	Master.current_ticklimit = old_limit
	TEST_ASSERT_EQUAL(remaining_after_pause, 2, "A healthy machine must yield before processing the rest of the queue.")
	TEST_ASSERT_EQUAL(paused_state, SS_PAUSED, "An exhausted budget must pause Machines.")
	TEST_ASSERT_EQUAL(remaining_after_resume, 0, "Resuming must finish the saved queue.")
	TEST_ASSERT_EQUAL(first.calls, 1, "The first machine must process exactly once across pause/resume.")
	TEST_ASSERT_EQUAL(second.calls, 1, "The second machine must process exactly once across pause/resume.")
	TEST_ASSERT_EQUAL(third.calls, 1, "The third machine must not be reprocessed on resume.")
	TEST_ASSERT_EQUAL(first.last_seconds, SSmachines.wait * 0.1, "Yielding must preserve the simulated interval.")

/obj/machinery/performance_probe
	var/calls = 0
	var/last_seconds
	var/process_result

/obj/machinery/performance_probe/process(seconds)
	calls++
	last_seconds = seconds
	return process_result

/// Pruning a stopped processor must still leave healthy ones scheduled for the next fire.
/datum/unit_test/performance_machines_prune/Run()
	var/obj/machinery/performance_probe/healthy = allocate(/obj/machinery/performance_probe)
	var/obj/machinery/performance_probe/stopped = allocate(/obj/machinery/performance_probe)
	stopped.process_result = PROCESS_KILL
	var/list/old_processing = SSmachines.processing
	var/list/old_currentrun = SSmachines.currentrun
	var/old_state = SSmachines.state
	var/old_limit = Master.current_ticklimit
	SSmachines.processing = list(healthy, stopped)
	SSmachines.state = SS_RUNNING
	Master.current_ticklimit = INFINITY
	SSmachines.fire()
	var/list/remaining = SSmachines.processing
	SSmachines.processing = old_processing
	SSmachines.currentrun = old_currentrun
	SSmachines.state = old_state
	Master.current_ticklimit = old_limit
	TEST_ASSERT_EQUAL(length(remaining), 1, "Only a healthy processor must stay scheduled.")
	TEST_ASSERT(healthy in remaining, "The healthy processor must stay in Machines.")
	TEST_ASSERT_EQUAL(stopped.calls, 1, "A stopped processor must be called before it is removed.")
