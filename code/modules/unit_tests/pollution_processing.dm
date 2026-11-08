/// Keep forced-budget tests isolated from the live pollution queues and restore them before assertions.
/datum/pollution_processing_test_context
	var/list/old_active
	var/list/old_all
	var/list/old_run
	var/list/old_processed
	var/old_task
	var/old_ticker
	var/old_state
	var/old_limit
	var/list/test_turfs
	var/list/old_pollution = list()
	var/list/old_adjacency = list()

/datum/pollution_processing_test_context/New(turf/bottom_left, turf/top_right)
	old_active = SSpollution.active_pollution
	old_all = SSpollution.all_polution
	old_run = SSpollution.current_run
	old_processed = SSpollution.processed_this_run
	old_task = SSpollution.pollution_task
	old_ticker = SSpollution.dissapation_ticker
	old_state = SSpollution.state
	old_limit = Master.current_ticklimit
	SSpollution.active_pollution = list()
	SSpollution.all_polution = list()
	SSpollution.current_run = list()
	SSpollution.processed_this_run = list()
	SSpollution.pollution_task = POLLUTION_TASK_PROCESS
	SSpollution.dissapation_ticker = 0
	SSpollution.state = SS_RUNNING
	Master.current_ticklimit = INFINITY
	test_turfs = block(bottom_left, top_right)
	for(var/turf/open/tile in test_turfs)
		old_pollution[tile] = tile.pollution
		old_adjacency[tile] = tile.atmos_adjacent_turfs?.Copy()
		tile.pollution = null

/datum/pollution_processing_test_context/Destroy()
	for(var/datum/pollution/cloud as anything in SSpollution.all_polution.Copy())
		qdel(cloud)
	for(var/turf/open/tile in test_turfs)
		tile.pollution = old_pollution[tile]
		tile.atmos_adjacent_turfs = old_adjacency[tile]
	SSpollution.active_pollution = old_active
	SSpollution.all_polution = old_all
	SSpollution.current_run = old_run
	SSpollution.processed_this_run = old_processed
	SSpollution.pollution_task = old_task
	SSpollution.dissapation_ticker = old_ticker
	SSpollution.state = old_state
	Master.current_ticklimit = old_limit
	old_active = null
	old_all = null
	old_run = null
	old_processed = null
	test_turfs = null
	old_pollution = null
	old_adjacency = null
	return ..()

/// Count scheduling independently of diffusion; dissipation still uses the real implementation.
/datum/pollution/processing_test_probe
	var/process_calls = 0
	var/scrub_calls = 0

/datum/pollution/processing_test_probe/process_cell()
	process_calls++

/datum/pollution/processing_test_probe/scrub_amount(amount_to_scrub, update_active = TRUE)
	scrub_calls++
	return ..()

/// A partial process pass must resume its saved remainder, not start again at the end of active_pollution.
/datum/unit_test/pollution_process_resume/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/datum/pollution/processing_test_probe/first = new(run_loc_floor_bottom_left)
	var/datum/pollution/processing_test_probe/second = new(get_step(run_loc_floor_bottom_left, EAST))
	var/datum/pollution/processing_test_probe/third = new(get_step(run_loc_floor_bottom_left, NORTH))
	SSpollution.active_pollution = list(first, second, third)
	Master.current_ticklimit = -1
	SSpollution.fire()
	var/remaining_after_pause = length(SSpollution.current_run)
	var/paused_state = SSpollution.state
	var/processed_after_pause = SSpollution.processed_this_run[third]
	Master.current_ticklimit = INFINITY
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	var/remaining_after_resume = length(SSpollution.current_run)
	var/completed_passes = SSpollution.dissapation_ticker
	qdel(context)
	TEST_ASSERT_EQUAL(remaining_after_pause, 2, "Pausing must retain the two unprocessed cells.")
	TEST_ASSERT_EQUAL(paused_state, SS_PAUSED, "The exhausted processing budget must pause Pollution.")
	TEST_ASSERT(processed_after_pause, "The visited cell must remain marked across a pause.")
	TEST_ASSERT_EQUAL(remaining_after_resume, 0, "Resuming must finish the saved batch.")
	TEST_ASSERT_EQUAL(completed_passes, 1, "One completed batch must advance dissipation once.")
	TEST_ASSERT_EQUAL(first.process_calls, 1, "The first queued cell must process once.")
	TEST_ASSERT_EQUAL(second.process_calls, 1, "The second queued cell must process once.")
	TEST_ASSERT_EQUAL(third.process_calls, 1, "The cell before the pause must not be repeated.")

/// An empty remainder after yielding on the last cell is still an unfinished fire(), not a new batch.
/datum/unit_test/pollution_process_last_cell_resume/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/datum/pollution/processing_test_probe/cloud = new(run_loc_floor_bottom_left)
	SSpollution.active_pollution = list(cloud)
	Master.current_ticklimit = -1
	SSpollution.fire()
	var/paused_state = SSpollution.state
	Master.current_ticklimit = INFINITY
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	var/completed_passes = SSpollution.dissapation_ticker
	qdel(context)
	TEST_ASSERT_EQUAL(paused_state, SS_PAUSED, "The last cell must exercise the actual budget boundary.")
	TEST_ASSERT_EQUAL(cloud.process_calls, 1, "Resuming an empty remainder must not process the last cell twice.")
	TEST_ASSERT_EQUAL(completed_passes, 1, "The resumed final cell must complete exactly one processing pass.")

/// Dissipation must preserve its own queue, including a pause after its last cell.
/datum/unit_test/pollution_dissipation_resume/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/datum/pollution/processing_test_probe/first = new(run_loc_floor_bottom_left)
	var/datum/pollution/processing_test_probe/second = new(get_step(run_loc_floor_bottom_left, EAST))
	first.add_pollutant(/datum/pollutant/fragrance, 100)
	second.add_pollutant(/datum/pollutant/fragrance, 100)
	SSpollution.active_pollution = list()
	SSpollution.dissapation_ticker = TICKS_TO_DISSIPATE * 4 - 1
	Master.current_ticklimit = -1
	SSpollution.fire()
	var/remaining_after_pause = length(SSpollution.current_run)
	var/task_after_pause = SSpollution.pollution_task
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	var/remaining_after_last = length(SSpollution.current_run)
	var/last_paused_state = SSpollution.state
	Master.current_ticklimit = INFINITY
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	var/final_task = SSpollution.pollution_task
	var/first_amount = first.total_amount
	var/second_amount = second.total_amount
	qdel(context)
	TEST_ASSERT_EQUAL(task_after_pause, POLLUTION_TASK_DISSIPATE, "A completed process pass must enter dissipation.")
	TEST_ASSERT_EQUAL(remaining_after_pause, 1, "The pending dissipation cell must survive the pause.")
	TEST_ASSERT_EQUAL(remaining_after_last, 0, "The second slice must consume the saved remainder.")
	TEST_ASSERT_EQUAL(last_paused_state, SS_PAUSED, "Dissipation must also exercise a yield after its last cell.")
	TEST_ASSERT_EQUAL(final_task, POLLUTION_TASK_PROCESS, "Completing dissipation must restore the processing phase.")
	TEST_ASSERT_EQUAL(first.scrub_calls, 1, "The first cell must dissipate exactly once.")
	TEST_ASSERT_EQUAL(second.scrub_calls, 1, "The last cell must not dissipate twice.")
	TEST_ASSERT_EQUAL(first_amount, 100 - POLLUTION_HEIGHT_DIVISOR, "Dissipation must remove only its configured amount.")
	TEST_ASSERT_EQUAL(second_amount, first_amount, "Both cells must lose the same amount across the pause.")

/// A cell deleted while paused must leave the saved queue without dropping its healthy neighbors.
/datum/unit_test/pollution_deleted_during_pause/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/datum/pollution/processing_test_probe/first = new(run_loc_floor_bottom_left)
	var/datum/pollution/processing_test_probe/deleted = new(get_step(run_loc_floor_bottom_left, EAST))
	var/datum/pollution/processing_test_probe/last = new(get_step(run_loc_floor_bottom_left, NORTH))
	SSpollution.active_pollution = list(first, deleted, last)
	Master.current_ticklimit = -1
	SSpollution.fire()
	qdel(deleted)
	var/remaining_after_delete = length(SSpollution.current_run)
	Master.current_ticklimit = INFINITY
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	qdel(context)
	TEST_ASSERT_EQUAL(remaining_after_delete, 1, "Deleting a pending cell must remove only that cell from the saved batch.")
	TEST_ASSERT_EQUAL(first.process_calls, 1, "The surviving pending cell must still process.")
	TEST_ASSERT_EQUAL(deleted.process_calls, 0, "A deleted pending cell must never be processed.")
	TEST_ASSERT_EQUAL(last.process_calls, 1, "Deletion during a pause must not replay completed cells.")

/// Deleting a cell between dissipation slices must not skip or repeat the other cells.
/datum/unit_test/pollution_deleted_during_dissipation/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/datum/pollution/processing_test_probe/first = new(run_loc_floor_bottom_left)
	var/datum/pollution/processing_test_probe/deleted = new(get_step(run_loc_floor_bottom_left, EAST))
	var/datum/pollution/processing_test_probe/last = new(get_step(run_loc_floor_bottom_left, NORTH))
	first.add_pollutant(/datum/pollutant/fragrance, 100)
	deleted.add_pollutant(/datum/pollutant/fragrance, 100)
	last.add_pollutant(/datum/pollutant/fragrance, 100)
	SSpollution.active_pollution = list()
	SSpollution.dissapation_ticker = TICKS_TO_DISSIPATE * 4 - 1
	Master.current_ticklimit = -1
	SSpollution.fire()
	qdel(deleted)
	var/remaining_after_delete = length(SSpollution.current_run)
	Master.current_ticklimit = INFINITY
	SSpollution.state = SS_RUNNING
	SSpollution.fire(TRUE)
	var/first_amount = first.total_amount
	var/last_amount = last.total_amount
	qdel(context)
	TEST_ASSERT_EQUAL(remaining_after_delete, 1, "Deleting a pending cell must preserve the rest of the dissipation batch.")
	TEST_ASSERT_EQUAL(first.scrub_calls, 1, "The surviving pending cell must still dissipate.")
	TEST_ASSERT_EQUAL(deleted.scrub_calls, 0, "A deleted pending cell must never be scrubbed.")
	TEST_ASSERT_EQUAL(last.scrub_calls, 1, "The completed cell must not dissipate twice.")
	TEST_ASSERT_EQUAL(first_amount, 75, "The resumed cell must lose only one dissipation step.")
	TEST_ASSERT_EQUAL(last_amount, 75, "Deletion during the pause must not change the completed cell's amount.")

/// Already visited cells cannot receive a second share in the same pass; every constituent is conserved.
/datum/unit_test/pollution_processed_neighbor_conservation/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/turf/open/source_turf = run_loc_floor_bottom_left
	var/turf/open/visited_turf = get_step(source_turf, EAST)
	var/turf/open/fresh_turf = get_step(source_turf, NORTH)
	var/datum/pollution/source = new(source_turf)
	var/datum/pollution/visited = new(visited_turf)
	source.add_pollutant(/datum/pollutant/fragrance/lavender, 150)
	source.add_pollutant(/datum/pollutant/fragrance/rose, 50)
	visited.add_pollutant(/datum/pollutant/fragrance/rose, 25)
	source_turf.atmos_adjacent_turfs = list(visited_turf, fresh_turf)
	visited_turf.atmos_adjacent_turfs = list(source_turf)
	fresh_turf.atmos_adjacent_turfs = list(source_turf)
	SSpollution.active_pollution = list(source, visited)
	SSpollution.fire()
	var/source_amount = source.total_amount
	var/visited_amount = visited.total_amount
	var/fresh_amount = fresh_turf.pollution?.total_amount
	var/lavender_total = source.pollutants[/datum/pollutant/fragrance/lavender] + visited.pollutants[/datum/pollutant/fragrance/lavender] + fresh_turf.pollution?.pollutants[/datum/pollutant/fragrance/lavender]
	var/rose_total = source.pollutants[/datum/pollutant/fragrance/rose] + visited.pollutants[/datum/pollutant/fragrance/rose] + fresh_turf.pollution?.pollutants[/datum/pollutant/fragrance/rose]
	qdel(context)
	TEST_ASSERT_EQUAL(visited_amount, 25, "A neighbor visited earlier in the pass must not receive another share.")
	TEST_ASSERT_EQUAL(source_amount, 100, "The source must share evenly with the eligible fresh neighbor.")
	TEST_ASSERT_EQUAL(fresh_amount, 100, "Unvisited adjacent cells must still receive pollution.")
	TEST_ASSERT_EQUAL(source_amount + visited_amount + fresh_amount, 225, "Diffusion must conserve the total amount.")
	TEST_ASSERT_EQUAL(lavender_total, 150, "Diffusion must conserve the first constituent.")
	TEST_ASSERT_EQUAL(rose_total, 75, "Diffusion must conserve the second constituent.")

/// A visited recipient postpones sharing, rather than permanently deactivating the source.
/datum/unit_test/pollution_deferred_neighbor/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/turf/open/source_turf = run_loc_floor_bottom_left
	var/turf/open/neighbor_turf = get_step(source_turf, EAST)
	var/datum/pollution/source = new(source_turf)
	var/datum/pollution/neighbor = new(neighbor_turf)
	source.add_pollutant(/datum/pollutant/fragrance, 200)
	neighbor.add_pollutant(/datum/pollutant/fragrance, 25)
	source_turf.atmos_adjacent_turfs = list(neighbor_turf)
	neighbor_turf.atmos_adjacent_turfs = list(source_turf)
	SSpollution.active_pollution = list(source, neighbor)
	SSpollution.fire()
	var/first_source_amount = source.total_amount
	var/source_still_active = (source in SSpollution.active_pollution)
	SSpollution.fire()
	var/second_source_amount = source.total_amount
	var/second_neighbor_amount = neighbor.total_amount
	qdel(context)
	TEST_ASSERT_EQUAL(first_source_amount, 200, "The source must defer sharing with its only visited neighbor.")
	TEST_ASSERT(source_still_active, "Deferring sharing must keep the source scheduled for the next pass.")
	TEST_ASSERT_EQUAL(second_source_amount, 112.5, "The next pass must share the retained pollution.")
	TEST_ASSERT_EQUAL(second_neighbor_amount, 112.5, "Deferral must not permanently starve the recipient.")

/// Sharing can lower a cell enough to wake a higher neighbor that was visited earlier in the pass.
/datum/unit_test/pollution_reactivate_visited_neighbor/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/turf/open/source_turf = run_loc_floor_bottom_left
	var/turf/open/higher_turf = get_step(source_turf, EAST)
	var/turf/open/fresh_turf = get_step(source_turf, NORTH)
	var/datum/pollution/source = new(source_turf)
	var/datum/pollution/higher = new(higher_turf)
	source.add_pollutant(/datum/pollutant/fragrance, 175)
	higher.add_pollutant(/datum/pollutant/fragrance, 200)
	source_turf.atmos_adjacent_turfs = list(higher_turf, fresh_turf)
	higher_turf.atmos_adjacent_turfs = list(source_turf)
	fresh_turf.atmos_adjacent_turfs = list(source_turf)
	SSpollution.active_pollution = list(source, higher)
	SSpollution.fire()
	var/higher_active = (higher in SSpollution.active_pollution)
	var/higher_amount = higher.total_amount
	var/source_amount = source.total_amount
	var/fresh_amount = fresh_turf.pollution?.total_amount
	qdel(context)
	TEST_ASSERT(higher_active, "A visited higher neighbor must wake when a lower neighbor gains capacity.")
	TEST_ASSERT_EQUAL(higher_amount, 200, "Waking a neighbor must not process it twice in one pass.")
	TEST_ASSERT_EQUAL(source_amount, 87.5, "Sharing must lower the source enough to admit the higher neighbor next pass.")
	TEST_ASSERT_EQUAL(fresh_amount, 87.5, "The fresh neighbor must still receive its share.")

/// Real door adjacency must continue to block pollution when closed and allow it when opened.
/datum/unit_test/pollution_door_adjacency/Run()
	var/datum/pollution_processing_test_context/context = allocate(/datum/pollution_processing_test_context, run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/turf/open/source_turf = run_loc_floor_bottom_left
	var/turf/open/door_turf = get_step(source_turf, EAST)
	var/obj/structure/mineral_door/door = allocate(/obj/structure/mineral_door, door_turf)
	var/datum/pollution/source = new(source_turf)
	source.add_pollutant(/datum/pollutant/fragrance, 200)
	source.process_cell()
	var/amount_behind_closed_door = door_turf.pollution?.total_amount || 0
	door.force_open()
	source_turf.ImmediateCalculateAdjacentTurfs()
	source.process_cell()
	var/amount_after_opening = door_turf.pollution?.total_amount || 0
	var/total_amount = 0
	for(var/datum/pollution/cloud as anything in SSpollution.all_polution)
		total_amount += cloud.total_amount
	qdel(door)
	qdel(context)
	TEST_ASSERT_EQUAL(amount_behind_closed_door, 0, "Pollution must not pass into a closed door's cell.")
	TEST_ASSERT(amount_after_opening > 0, "Opening the door must let pollution enter the newly connected cell.")
	TEST_ASSERT_EQUAL(total_amount, 200, "Changing door adjacency must not create or destroy pollution.")
