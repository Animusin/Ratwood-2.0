#define LAG_RECORDER_HISTORY 32
#define LAG_RECORDER_WORK_HISTORY 16
#define LAG_RECORDER_DURATION_MS 900000
#define LAG_RECORDER_COOLDOWN_MS 2000
#define LAG_RECORDER_PING_TIMEOUT_MS 10000
#define LAG_PROFILE_MIN_SELF 0.05
#define LAG_PROFILE_MIN_TOTAL 0.25
#define LAG_PROFILE_ROWS 150
#define LAG_PROFILE_CHUNK 25

/// Bounded capture of synchronous work. Uses the existing downloadable memory_stats.log.
/datum/lag_recorder
	var/static/last_capture_id = 0
	/// Scalar identifier so a sleeping handler never retains the recorder.
	var/capture_id
	var/list/history = new(LAG_RECORDER_HISTORY)
	var/history_cursor = 1
	var/list/work_history = new(LAG_RECORDER_WORK_HISTORY)
	var/work_cursor = 1
	var/previous_wall_ms
	var/previous_world_time
	var/window_wall_ms
	var/window_world_time
	var/next_report_ms = 0
	var/slow_sample = FALSE
	/// Only sample the admin who started the capture. Keep a key so reconnecting can resume the samples.
	var/ping_ckey
	var/ping_sequence = 0
	var/pending_ping_token
	var/ping_sent_ms
	var/ping_sent_world_ds
	/// Numeric span identifiers only; lifecycle probes never retain the departing client or body.
	var/lifecycle_sequence = 0
	/// BYOND's own profiler runs for the length of the capture.
	var/profiling = FALSE

/datum/lag_recorder/New(ping_ckey)
	. = ..()
	capture_id = ++last_capture_id
	src.ping_ckey = ping_ckey
	start_profiler()

/datum/lag_recorder/Destroy()
	finish_profiler()
	return ..()

/// The sampled spans above only see synchronous work of 4 ms and longer inside wrapped entry points.
/// The engine profiler attributes every proc call, sleeping procs and verbs included, and SendMaps.
/datum/lag_recorder/proc/start_profiler()
	world.Profile(PROFILE_RESTART)
	world.Profile(PROFILE_RESTART, type = "sendmaps")
	profiling = TRUE

/datum/lag_recorder/proc/finish_profiler()
	if(!profiling)
		return
	profiling = FALSE
	var/proc_json = world.Profile(PROFILE_REFRESH, format = "json")
	var/sendmaps_json = world.Profile(PROFILE_REFRESH, type = "sendmaps", format = "json")
	world.Profile(PROFILE_STOP)
	world.Profile(PROFILE_STOP, type = "sendmaps")
	write_lag_profile(capture_id, proc_json, sendmaps_json)

/datum/lag_recorder/proc/poll_ping()
	if(!ping_ckey)
		return
	var/client/recipient = GLOB.directory[ping_ckey]
	if(!recipient && !pending_ping_token)
		return

	var/token = begin_ping(rustg_time_milliseconds("lag_recorder"), world.time, !!recipient)
	if(token)
		winset(recipient, null, "command=.lag_recorder_ping+[token]")

/// Keep at most one request pending so a slow reply can still be measured.
/datum/lag_recorder/proc/begin_ping(wall_ms, game_ds, can_send = TRUE)
	if(wall_ms >= LAG_RECORDER_DURATION_MS)
		return
	if(pending_ping_token)
		var/elapsed_ms = wall_ms - ping_sent_ms
		if(elapsed_ms < LAG_RECORDER_PING_TIMEOUT_MS)
			return
		write_event("ping", list("status" = "timeout", "world_ds" = game_ds, "sent_world_ds" = ping_sent_world_ds, "sent_ms" = ping_sent_ms, "elapsed_ms" = elapsed_ms))
		pending_ping_token = null

	if(!can_send)
		return
	ping_sent_ms = wall_ms
	ping_sent_world_ds = game_ds
	pending_ping_token = "[capture_id]-[++ping_sequence]"
	return pending_ping_token

/datum/lag_recorder/proc/record_ping_reply(reply_ckey, token, wall_ms, game_ds)
	if(reply_ckey != ping_ckey || !pending_ping_token || token != pending_ping_token || wall_ms >= LAG_RECORDER_DURATION_MS)
		return
	pending_ping_token = null
	write_event("ping", list("status" = "ok", "world_ds" = game_ds, "sent_world_ds" = ping_sent_world_ds, "sent_ms" = ping_sent_ms, "rtt_ms" = wall_ms - ping_sent_ms))

/// These delimit DM handlers, not the engine's entire disconnect or native reference cleanup.
/datum/lag_recorder/proc/begin_lifecycle(phase, target_type, wall_ms, game_ds)
	if(wall_ms >= LAG_RECORDER_DURATION_MS)
		return null
	var/span_id = ++lifecycle_sequence
	write_event("lifecycle", list("capture_id" = capture_id, "span_id" = span_id, "phase" = phase, "edge" = "begin", "target_type" = target_type, "wall_ms" = wall_ms, "world_ds" = game_ds))
	return span_id

/// Elapsed wall time may include sleeps. A missing end marks an interrupted handler or capture.
/datum/lag_recorder/proc/end_lifecycle(expected_capture_id, span_id, phase, target_type, start_wall_ms, wall_ms, game_ds)
	if(expected_capture_id != capture_id || !span_id || span_id > lifecycle_sequence)
		return
	write_event("lifecycle", list("capture_id" = capture_id, "span_id" = span_id, "phase" = phase, "edge" = "end", "target_type" = target_type, "wall_ms" = wall_ms, "world_ds" = game_ds, "elapsed_ms" = wall_ms - start_wall_ms))

/datum/lag_recorder/proc/record_sample(kind, label, cost_ms, tick_time, list/details)
	history[history_cursor] = list("kind" = kind, "label" = label, "ms" = round(cost_ms, 0.1), "world_ds" = tick_time, "details" = details)
	history_cursor = history_cursor % LAG_RECORDER_HISTORY + 1
	if(cost_ms >= 80)
		slow_sample = TRUE

/// Work spans are inclusive and can overlap, such as a click that invokes a callback.
/datum/lag_recorder/proc/record_work(kind, label, cost_ms, tick_time, before_controller, target_type, proc_name)
	work_history[work_cursor] = list("kind" = kind, "label" = label, "ms" = round(cost_ms, 0.1), "world_ds" = tick_time, "before_controller" = before_controller, "target_type" = target_type ? "[target_type]" : null, "proc" = proc_name ? copytext("[proc_name]", 1, 129) : null)
	work_cursor = work_cursor % LAG_RECORDER_WORK_HISTORY + 1
	if(cost_ms >= (before_controller ? 25 : 50))
		slow_sample = TRUE

/datum/lag_recorder/proc/record_mob_slice(slice_ms, list/type_costs, processed, slowest_type, slowest_phase, slowest_ms)
	var/list/top_types = list()
	// Only scan the measured types when a mob slice was long enough to retain.
	for(var/i in 1 to min(3, length(type_costs)))
		var/top_type
		var/top_cost = 0
		for(var/mob_type in type_costs)
			if(type_costs[mob_type] > top_cost)
				top_type = mob_type
				top_cost = type_costs[mob_type]
		if(top_type)
			top_types["[top_type]"] = round(top_cost, 0.1)
			type_costs -= top_type
	record_sample("mob_slice", "Mobs", slice_ms, world.time, list("processed" = processed, "top_types_ms" = top_types, "slowest_type" = slowest_type ? "[slowest_type]" : null, "slowest_phase" = slowest_phase, "slowest_ms" = round(slowest_ms, 0.1)))

/// Compare elapsed wall time with simulation progress before starting the next controller pass.
/datum/lag_recorder/proc/observe_tick(wall_ms, game_ds, starting_usage)
	if(wall_ms >= LAG_RECORDER_DURATION_MS)
		write_event("expired", list("world_ds" = game_ds))
		return FALSE
	if(isnull(previous_wall_ms))
		previous_wall_ms = wall_ms
		previous_world_time = game_ds
		window_wall_ms = wall_ms
		window_world_time = game_ds
	var/excess_ms = (wall_ms - previous_wall_ms) - (game_ds - previous_world_time) * 100
	previous_wall_ms = wall_ms
	previous_world_time = game_ds
	var/window_excess_ms = 0
	if(wall_ms - window_wall_ms >= 1000)
		window_excess_ms = (wall_ms - window_wall_ms) - (game_ds - window_world_time) * 100
		window_wall_ms = wall_ms
		window_world_time = game_ds
	var/has_slow_sample = slow_sample
	slow_sample = FALSE
	if(wall_ms < next_report_ms || (!has_slow_sample && excess_ms < 100 && window_excess_ms < 150 && TICK_DELTA_TO_MS(starting_usage) < 80))
		return TRUE
	next_report_ms = wall_ms + LAG_RECORDER_COOLDOWN_MS
	var/list/recent = list()
	for(var/offset in 0 to LAG_RECORDER_HISTORY - 1)
		var/list/entry = history[(history_cursor + offset - 1) % LAG_RECORDER_HISTORY + 1]
		if(entry && game_ds - entry["world_ds"] <= 2 SECONDS)
			recent += list(entry)
	var/list/recent_work = list()
	for(var/offset in 0 to LAG_RECORDER_WORK_HISTORY - 1)
		var/list/entry = work_history[(work_cursor + offset - 1) % LAG_RECORDER_WORK_HISTORY + 1]
		if(entry && game_ds - entry["world_ds"] <= 2 SECONDS)
			recent_work += list(entry)
	write_event("spike", list("world_ds" = game_ds, "gap_excess_ms" = excess_ms, "window_excess_ms" = window_excess_ms, "tick_start_pct" = starting_usage, "tick_budget_ms" = world.tick_lag * 100, "cpu_pct" = world.cpu, "map_cpu_pct" = world.map_cpu, "samples" = recent, "work_samples" = recent_work))
	return TRUE

/datum/lag_recorder/proc/write_event(kind, list/data)
	WRITE_LOG(GLOB.world_mem_log, "LAGTRACE [kind] [json_encode(data)]")

/proc/cmp_lag_profile_self_dsc(list/first, list/second)
	return second["self"] - first["self"]

/proc/cmp_lag_profile_total_dsc(list/first, list/second)
	return second["total"] - first["total"]

/// Keeps the complete profiles beside the round logs and a ranked digest in memory_stats.log.
/// Runs detached from the recorder, which is already gone by the time the digest is built.
/proc/write_lag_profile(capture_id, proc_json, sendmaps_json)
	set waitfor = FALSE
	if(GLOB.log_directory)
		if(length(proc_json))
			rustg_file_write(proc_json, "[GLOB.log_directory]/lag_profile_[capture_id].json")
		if(length(sendmaps_json))
			rustg_file_write(sendmaps_json, "[GLOB.log_directory]/lag_sendmaps_[capture_id].json")
	sleep(world.tick_lag)

	var/list/sendmaps = length(sendmaps_json) ? safe_json_decode(sendmaps_json) : null
	if(islist(sendmaps))
		write_lag_profile_rows(capture_id, "sendmaps", sendmaps)
	sleep(world.tick_lag)

	var/list/entries = length(proc_json) ? safe_json_decode(proc_json) : null
	if(!islist(entries))
		WRITE_LOG(GLOB.world_mem_log, "LAGTRACE profile [json_encode(list("capture_id" = capture_id, "section" = "error", "rows" = list()))]")
		return
	sleep(world.tick_lag)
	// Seconds over the whole capture. Anything below these cannot explain a lag complaint.
	var/list/by_self = list()
	var/list/by_total = list()
	var/scanned = 0
	for(var/list/entry as anything in entries)
		if(!islist(entry))
			continue
		if(entry["self"] >= LAG_PROFILE_MIN_SELF)
			by_self += list(entry)
		if(entry["total"] >= LAG_PROFILE_MIN_TOTAL)
			by_total += list(entry)
		if(!(++scanned % 2000))
			sleep(world.tick_lag)
	sortTim(by_self, GLOBAL_PROC_REF(cmp_lag_profile_self_dsc))
	sleep(world.tick_lag)
	sortTim(by_total, GLOBAL_PROC_REF(cmp_lag_profile_total_dsc))
	sleep(world.tick_lag)
	by_self.Cut(min(length(by_self), LAG_PROFILE_ROWS) + 1)
	by_total.Cut(min(length(by_total), LAG_PROFILE_ROWS) + 1)
	write_lag_profile_rows(capture_id, "self", by_self)
	write_lag_profile_rows(capture_id, "total", by_total)

/proc/write_lag_profile_rows(capture_id, section, list/rows)
	var/total = length(rows)
	for(var/start in 1 to total step LAG_PROFILE_CHUNK)
		var/list/chunk = rows.Copy(start, min(start + LAG_PROFILE_CHUNK, total + 1))
		WRITE_LOG(GLOB.world_mem_log, "LAGTRACE profile [json_encode(list("capture_id" = capture_id, "section" = section, "first" = start, "of" = total, "rows" = chunk))]")

/client/proc/toggle_lag_recorder()
	set category = "Debug"
	set name = "Toggle Lag Recorder"
	if(!check_rights(R_DEBUG))
		return
	if(Master.lag_recorder)
		Master.lag_recorder.write_event("stopped", list("world_ds" = world.time))
		QDEL_NULL(Master.lag_recorder)
		to_chat(src, span_notice("Lag Recorder stopped. Look for LAGTRACE in memory_stats.log; the full proc and SendMaps profiles are lag_profile_*.json and lag_sendmaps_*.json in the round's log folder."))
		return
	rustg_time_reset("lag_recorder")
	Master.lag_recorder = new(ckey)
	Master.lag_recorder.write_event("started", list("world_ds" = world.time, "duration_ms" = LAG_RECORDER_DURATION_MS))
	to_chat(src, span_notice("Lag Recorder enabled for 15 minutes. Spikes, your connection ping and a proc profile are written to memory_stats.log."))

#undef LAG_RECORDER_HISTORY
#undef LAG_RECORDER_WORK_HISTORY
#undef LAG_RECORDER_DURATION_MS
#undef LAG_RECORDER_COOLDOWN_MS
#undef LAG_RECORDER_PING_TIMEOUT_MS
#undef LAG_PROFILE_MIN_SELF
#undef LAG_PROFILE_MIN_TOTAL
#undef LAG_PROFILE_ROWS
#undef LAG_PROFILE_CHUNK
