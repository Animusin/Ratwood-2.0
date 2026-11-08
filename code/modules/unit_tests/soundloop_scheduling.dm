/// Tests drive the real scheduler without letting the live MC consume their queues.
/datum/soundloop_test_context
	var/list/old_processing
	var/list/old_queue
	var/list/old_run
	var/list/old_clients
	var/list/old_persistent
	var/old_update
	var/old_deadline
	var/old_due
	var/old_state
	var/old_can_fire
	var/old_limit

/datum/soundloop_test_context/New()
	old_processing = SSsoundloopers.processing
	old_queue = SSsoundloopers.sound_queue
	old_run = SSsoundloopers.currentrun
	old_clients = SSsoundloopers.clientrun
	old_persistent = GLOB.persistent_sound_loops
	old_update = SSsoundloopers.next_client_update
	old_deadline = SSsoundloopers.sound_deadline
	old_due = SSsoundloopers.processing_due_sounds
	old_state = SSsoundloopers.state
	old_can_fire = SSsoundloopers.can_fire
	old_limit = Master.current_ticklimit
	SSsoundloopers.processing = list()
	SSsoundloopers.sound_queue = list()
	SSsoundloopers.currentrun = list()
	SSsoundloopers.clientrun = list()
	GLOB.persistent_sound_loops = list()
	SSsoundloopers.next_client_update = world.time + 1 HOURS
	SSsoundloopers.sound_deadline = 0
	SSsoundloopers.processing_due_sounds = FALSE
	SSsoundloopers.state = SS_RUNNING
	SSsoundloopers.can_fire = FALSE
	Master.current_ticklimit = INFINITY

/datum/soundloop_test_context/Destroy()
	for(var/datum/looping_sound/loop as anything in SSsoundloopers.processing.Copy())
		qdel(loop)
	SSsoundloopers.processing = old_processing
	SSsoundloopers.sound_queue = old_queue
	SSsoundloopers.currentrun = old_run
	SSsoundloopers.clientrun = old_clients
	GLOB.persistent_sound_loops = old_persistent
	SSsoundloopers.next_client_update = old_update
	SSsoundloopers.sound_deadline = old_deadline
	SSsoundloopers.processing_due_sounds = old_due
	SSsoundloopers.state = old_state
	SSsoundloopers.can_fire = old_can_fire
	Master.current_ticklimit = old_limit
	old_processing = null
	old_queue = null
	old_run = null
	old_clients = null
	old_persistent = null
	return ..()

/// Replace only audio output; cadence, chance, maximum-loop handling and start/stop remain real.
/datum/looping_sound/scheduling_probe
	mid_sounds = list('sound/blank.ogg')
	mid_length = 100
	var/attempts = 0
	var/plays = 0
	var/refreshes = 0
	var/turf/refreshed_turf
	var/list/attempt_order

/datum/looping_sound/scheduling_probe/sound_loop()
	attempts++
	attempt_order?.Add(src)
	return ..()

/datum/looping_sound/scheduling_probe/play(soundfile)
	plays++
	starttime = world.time
	SSsoundloopers.schedule_sound(src)

/datum/looping_sound/scheduling_probe/refresh_listeners()
	refreshes++
	refreshed_turf = get_turf(parent)

/// Time is controlled through the real interval setter, rather than by changing the heap.
/datum/looping_sound/scheduling_probe/proc/make_due(age = 1)
	starttime = world.time - mid_length - age
	set_mid_length(mid_length)

/datum/looping_sound/scheduling_probe/proc/start_without_timer()
	stopped = FALSE
	loop_started = TRUE
	begin_loop()
	if(persistent_loop)
		GLOB.persistent_sound_loops |= src

/// Many long sounds must remain queued without being replayed, reordered or copied every scheduler tick.
/datum/unit_test/soundloop_future_queue/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/list/loops = list()
	for(var/i in 1 to 64)
		var/datum/looping_sound/scheduling_probe/loop = allocate(/datum/looping_sound/scheduling_probe)
		loop.mid_length = 1 HOURS
		loop.start_without_timer()
		loops += loop
	var/list/queue = SSsoundloopers.sound_queue
	var/list/registered = SSsoundloopers.processing
	for(var/i in 1 to 50)
		SSsoundloopers.fire()
	var/queue_preserved = SSsoundloopers.sound_queue == queue && SSsoundloopers.processing == registered
	var/queued = length(queue)
	var/attempts = 0
	for(var/datum/looping_sound/scheduling_probe/loop as anything in loops)
		attempts += loop.attempts
	qdel(context)
	TEST_ASSERT(queue_preserved, "Future playback must reuse its queue instead of allocating a full processing snapshot per fire.")
	TEST_ASSERT_EQUAL(queued, 64, "All future loops must remain scheduled.")
	TEST_ASSERT_EQUAL(attempts, 64, "Fifty idle scheduler fires must not attempt any of the 64 future loops again.")

/// Deadlines, including a shortened interval, determine order; removing arbitrary entries preserves heap indices.
/datum/unit_test/soundloop_heap_order/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/list/loops = list()
	for(var/i in 1 to 7)
		var/datum/looping_sound/scheduling_probe/loop = allocate(/datum/looping_sound/scheduling_probe)
		loop.mid_length = (8 - i) * 100
		loop.start_without_timer()
		loops += loop
	var/datum/looping_sound/scheduling_probe/shortened = loops[1]
	shortened.set_mid_length(10)
	var/shortened_is_first = SSsoundloopers.sound_queue[1] == shortened
	shortened.stop()
	var/datum/looping_sound/scheduling_probe/interior = SSsoundloopers.sound_queue[3]
	interior.stop()
	var/heap_valid = TRUE
	for(var/index in 1 to length(SSsoundloopers.sound_queue))
		var/datum/looping_sound/loop = SSsoundloopers.sound_queue[index]
		if(loop.sound_queue_index != index)
			heap_valid = FALSE
		if(index > 1)
			var/datum/looping_sound/parent_loop = SSsoundloopers.sound_queue[index >> 1]
			if(parent_loop.next_sound_time > loop.next_sound_time)
				heap_valid = FALSE
	var/remaining = length(SSsoundloopers.sound_queue)
	var/stopped_index = shortened.sound_queue_index
	qdel(context)
	TEST_ASSERT(shortened_is_first, "Shortening a live interval must move its loop to the next playback position.")
	TEST_ASSERT(heap_valid, "Removing the first and an interior loop must preserve every heap index and deadline.")
	TEST_ASSERT_EQUAL(remaining, 5, "Only the two stopped loops must leave the queue.")
	TEST_ASSERT_EQUAL(stopped_index, 0, "Stopped loops must no longer have a queue index.")

/// Yielding after the last due item must not replay it or lose remaining due loops.
/datum/unit_test/soundloop_due_resume/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/datum/looping_sound/scheduling_probe/first = allocate(/datum/looping_sound/scheduling_probe)
	var/datum/looping_sound/scheduling_probe/second = allocate(/datum/looping_sound/scheduling_probe)
	first.start_without_timer()
	second.start_without_timer()
	first.make_due(2)
	second.make_due(1)
	var/list/order = list()
	first.attempt_order = order
	second.attempt_order = order
	Master.current_ticklimit = -1
	SSsoundloopers.fire()
	var/first_paused = SSsoundloopers.state
	SSsoundloopers.state = SS_RUNNING
	SSsoundloopers.fire(TRUE)
	var/last_paused = SSsoundloopers.state
	Master.current_ticklimit = INFINITY
	SSsoundloopers.state = SS_RUNNING
	SSsoundloopers.fire(TRUE)
	var/order_correct = length(order) == 2 && order[1] == first && order[2] == second
	qdel(context)
	TEST_ASSERT_EQUAL(first_paused, SS_PAUSED, "The first due loop must exercise a real scheduler pause.")
	TEST_ASSERT_EQUAL(last_paused, SS_PAUSED, "The last due loop must also exercise a real scheduler pause.")
	TEST_ASSERT(order_correct, "Due sounds must play in deadline order across the paused slices.")
	TEST_ASSERT_EQUAL(first.attempts, 2, "The first sound must have its initial attempt and one repeat.")
	TEST_ASSERT_EQUAL(second.attempts, 2, "The final sound must not repeat again when resuming an empty due batch.")

/// Chance failure retains the old retry cadence, while max_loops stops and unregisters normally.
/datum/unit_test/soundloop_chance_and_limit/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/datum/looping_sound/scheduling_probe/chance_loop = allocate(/datum/looping_sound/scheduling_probe)
	chance_loop.chance = -1
	chance_loop.start_without_timer()
	chance_loop.make_due()
	SSsoundloopers.fire()
	var/attempts_after_first = chance_loop.attempts
	var/retry_deadline = chance_loop.next_sound_time
	SSsoundloopers.fire(TRUE)
	var/attempts_after_resume = chance_loop.attempts
	// Advance one tick with this subsystem disabled; a failed roll must be eligible again next fire.
	sleep(world.tick_lag)
	SSsoundloopers.state = SS_RUNNING
	SSsoundloopers.fire()
	var/attempts_after_retry = chance_loop.attempts
	var/datum/looping_sound/scheduling_probe/limited = allocate(/datum/looping_sound/scheduling_probe)
	limited.max_loops = 1
	limited.start_without_timer()
	limited.make_due()
	SSsoundloopers.fire()
	var/limit_stopped = limited.stopped && !limited.sound_queue_index && !(limited in SSsoundloopers.processing)
	qdel(context)
	TEST_ASSERT_EQUAL(attempts_after_first, 2, "A failed roll must still receive its due retry.")
	TEST_ASSERT_EQUAL(attempts_after_resume, 2, "A failed roll must not busy-loop in a resumed fire.")
	TEST_ASSERT(attempts_after_retry >= 3, "A failed roll must retry at the next eligible scheduler fire.")
	TEST_ASSERT(retry_deadline > 0, "A failed roll must remain scheduled.")
	TEST_ASSERT_EQUAL(chance_loop.plays, 0, "A failed chance roll must never play audio.")
	TEST_ASSERT(limit_stopped, "Reaching max_loops must stop and unregister the loop.")
	TEST_ASSERT_EQUAL(limited.plays, 1, "A one-loop sound must only play once.")

/// A queued start callback must never register a sound after stop(), including rapid restarts.
/datum/unit_test/soundloop_pending_start_stop/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/datum/looping_sound/scheduling_probe/loop = allocate(/datum/looping_sound/scheduling_probe)
	loop.start_sound = sound('sound/blank.ogg')
	loop.start_length = 10 SECONDS
	loop.start()
	var/first_timer = loop.timerid
	loop.start()
	var/replaced_timer = loop.timerid
	loop.stop()
	var/attempts_at_stop = loop.attempts
	loop.begin_loop()
	var/stopped_clear = loop.stopped && isnull(loop.timerid) && !loop.sound_queue_index && !(loop in SSsoundloopers.processing)
	qdel(context)
	TEST_ASSERT(first_timer && replaced_timer && first_timer != replaced_timer, "Restarting during the intro must replace its pending start timer.")
	TEST_ASSERT(stopped_clear, "Stopping during the intro must leave no timer or scheduled loop.")
	TEST_ASSERT_EQUAL(loop.attempts, attempts_at_stop, "A stale begin_loop callback must not attempt playback after stop.")

/// Persistent listener refresh survives a pause and notices a moving source without replaying its long audio.
/datum/unit_test/soundloop_listener_resume/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/datum/looping_sound/scheduling_probe/first = allocate(/datum/looping_sound/scheduling_probe)
	var/datum/looping_sound/scheduling_probe/second = allocate(/datum/looping_sound/scheduling_probe)
	first.persistent_loop = TRUE
	second.persistent_loop = TRUE
	first.start_without_timer()
	second.start_without_timer()
	SSsoundloopers.next_client_update = world.time
	Master.current_ticklimit = -1
	SSsoundloopers.fire()
	var/remaining = length(SSsoundloopers.currentrun)
	var/next_update = SSsoundloopers.next_client_update
	var/turf/new_source = get_step(run_loc_floor_bottom_left, EAST)
	first.set_parent(new_source)
	Master.current_ticklimit = INFINITY
	SSsoundloopers.state = SS_RUNNING
	SSsoundloopers.fire(TRUE)
	var/first_refreshes = first.refreshes
	var/second_refreshes = second.refreshes
	var/refreshed_turf = first.refreshed_turf
	SSsoundloopers.fire()
	var/no_early_refresh = first.refreshes == first_refreshes && second.refreshes == second_refreshes
	qdel(context)
	TEST_ASSERT_EQUAL(remaining, 1, "Listener refresh must save its remaining persistent loop when yielding.")
	TEST_ASSERT_EQUAL(first_refreshes, 1, "The pending loop must refresh after resume.")
	TEST_ASSERT_EQUAL(second_refreshes, 1, "The completed loop must not refresh twice after resume.")
	TEST_ASSERT_EQUAL(refreshed_turf, new_source, "The resumed refresh must use the source's current position.")
	TEST_ASSERT(next_update > world.time - 0.5 SECONDS, "Listener updates must use a half-second deadline.")
	TEST_ASSERT(no_early_refresh, "Ordinary fires before the half-second deadline must not repeat listener discovery.")
	TEST_ASSERT_EQUAL(first.attempts, 1, "Moving a persistent source must not replay its long sound.")

/// Deletion must remove both playback and paused listener references, allowing the loop to collect.
/datum/unit_test/soundloop_deleted_cleanup/proc/create_queued_loop()
	var/datum/looping_sound/scheduling_probe/loop = new(run_loc_floor_bottom_left)
	loop.persistent_loop = TRUE
	loop.start_without_timer()
	SSsoundloopers.currentrun += loop
	return loop

/datum/unit_test/soundloop_deleted_cleanup/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	// Finish the setup frame first so BYOND's expression temporaries cannot inflate the reference count.
	var/datum/looping_sound/scheduling_probe/loop = create_queued_loop()
	qdel(loop)
	var/remaining_refs = refcount(loop)
	var/queues_clear = !length(SSsoundloopers.sound_queue) && !length(SSsoundloopers.processing) && !length(SSsoundloopers.currentrun)
	var/global_clear = !(loop in GLOB.persistent_sound_loops)
	qdel(context)
	TEST_ASSERT(queues_clear && global_clear, "Deleted loops must leave all scheduling and listener collections.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "A deleted loop must not be retained by the heap or paused snapshot: [remaining_refs] references remain (baseline [baseline_refs()]).")

/// Dynamic intervals preserve the strict deadline and can move a loop earlier or later without duplicate entries.
/datum/unit_test/soundloop_dynamic_interval/Run()
	var/datum/soundloop_test_context/context = allocate(/datum/soundloop_test_context)
	var/datum/looping_sound/scheduling_probe/loop = allocate(/datum/looping_sound/scheduling_probe)
	loop.start_without_timer()
	loop.starttime = world.time - 10
	loop.set_mid_length(10)
	SSsoundloopers.fire()
	var/at_exact_deadline = loop.attempts
	loop.set_mid_length(9)
	SSsoundloopers.fire()
	var/after_shortening = loop.attempts
	loop.set_mid_length(100)
	SSsoundloopers.register_sound(loop)
	SSsoundloopers.register_sound(loop)
	var/queue_size = length(SSsoundloopers.sound_queue)
	SSsoundloopers.fire()
	var/after_lengthening = loop.attempts
	qdel(context)
	TEST_ASSERT_EQUAL(at_exact_deadline, 1, "The original strict greater-than deadline must not play early.")
	TEST_ASSERT_EQUAL(after_shortening, 2, "Shortening an active interval past its deadline must make it eligible immediately.")
	TEST_ASSERT_EQUAL(after_lengthening, 2, "Lengthening the interval must postpone playback.")
	TEST_ASSERT_EQUAL(queue_size, 1, "Repeated registration must never duplicate a loop in the heap.")
