/datum/lag_recorder/test_probe
	var/list/events = list()
	var/list/last_report
	var/list/reports = list()

/// Scripted recorders must not restart or dump the engine profiler.
/datum/lag_recorder/test_probe/start_profiler()
	return

/datum/lag_recorder/test_probe/write_event(kind, list/data)
	events += kind
	last_report = data
	reports += list(data)

/// A short stall should keep recent entries in chronological order without flooding the log.
/datum/unit_test/lag_recorder_gap_and_history/Run()
	var/datum/lag_recorder/test_probe/recorder = new
	allocated += recorder
	TEST_ASSERT(recorder.observe_tick(0, 100, 0), "The initial observation must arm the time comparison.")
	recorder.observe_tick(50, 100.5, 0)
	TEST_ASSERT_EQUAL(length(recorder.events), 0, "Normal simulated progress must stay quiet.")
	for(var/i in 1 to 36)
		recorder.record_sample("subsystem", "sample [i]", 5, 100.5)
	recorder.observe_tick(230, 101, 0)
	TEST_ASSERT_EQUAL(length(recorder.events), 1, "A single stall must emit one record.")
	TEST_ASSERT_EQUAL(recorder.last_report["gap_excess_ms"], 130, "Report wall time in excess of game progress.")
	var/list/samples = recorder.last_report["samples"]
	TEST_ASSERT_EQUAL(length(samples), 32, "The history must discard older entries when full.")
	var/list/first_sample = samples[1]
	var/list/last_sample = samples[32]
	TEST_ASSERT_EQUAL(first_sample["label"], "sample 5", "The oldest retained entry must be first.")
	TEST_ASSERT_EQUAL(last_sample["label"], "sample 36", "The most recent retained entry must be last.")
	recorder.observe_tick(410, 101.5, 0)
	TEST_ASSERT_EQUAL(length(recorder.events), 1, "The cooldown must prevent repeated logging in a burst.")

/// Repeated small delays should trigger the window even if no individual tick crosses the gap limit.
/datum/unit_test/lag_recorder_sustained_drift/Run()
	var/datum/lag_recorder/test_probe/recorder = new
	allocated += recorder
	recorder.observe_tick(0, 200, 0)
	for(var/i in 1 to 17)
		recorder.observe_tick(i * 60, 200 + i * 0.5, 0)
	TEST_ASSERT_EQUAL(length(recorder.events), 1, "Accumulated lag should emit a spike.")
	TEST_ASSERT_EQUAL(recorder.last_report["gap_excess_ms"], 10, "Each individual gap was below the spike threshold.")
	TEST_ASSERT_EQUAL(recorder.last_report["window_excess_ms"], 170, "The window must retain the combined drift.")
	TEST_ASSERT(!recorder.observe_tick(900000, 200, 0), "Capture must stop automatically after 15 minutes.")
	TEST_ASSERT_EQUAL(recorder.events[2], "expired", "Expiry must be visible in the log.")

/// A measured deletion should be reported even when the next observation shows no clock drift.
/datum/unit_test/lag_recorder_slow_sample/Run()
	var/datum/lag_recorder/test_probe/recorder = new
	allocated += recorder
	recorder.observe_tick(0, 300, 0)
	recorder.record_sample("hard_delete", "/datum/example", 90, 300)
	recorder.observe_tick(50, 300.5, 0)
	var/list/samples = recorder.last_report?["samples"]
	TEST_ASSERT_EQUAL(length(samples), 1, "A slow deletion must trigger a report with its attribution.")
	var/list/deletion = samples[1]
	TEST_ASSERT_EQUAL(deletion["kind"], "hard_delete", "The source of the measured delay must be preserved.")
	TEST_ASSERT_EQUAL(deletion["ms"], 90, "The report must retain the measured time.")

/// Early work should trigger a microstall report without displacing subsystem samples.
/datum/unit_test/lag_recorder_early_work/Run()
	var/datum/lag_recorder/test_probe/recorder = new
	allocated += recorder
	recorder.observe_tick(0, 400, 0)
	recorder.record_sample("subsystem", "Input", 5, 400)
	recorder.record_work("player", "Move", 30, 400.5, TRUE, null, null)
	recorder.record_work("callback", "InvokeAsync", 6, 400.5, TRUE, "global", /proc/stoplag)
	recorder.observe_tick(50, 400.5, 0)
	TEST_ASSERT_EQUAL(length(recorder.events), 1, "An expensive early handler must trigger without a wall-clock gap.")
	var/list/samples = recorder.last_report["samples"]
	var/list/work = recorder.last_report["work_samples"]
	TEST_ASSERT_EQUAL(length(samples), 1, "Subsystem samples must retain their own space.")
	TEST_ASSERT_EQUAL(length(work), 2, "Both work spans must survive in the report.")
	var/list/handler = work[1]
	var/list/callback = work[2]
	TEST_ASSERT_EQUAL(handler["label"], "Move", "The player handler must be named.")
	TEST_ASSERT(handler["before_controller"], "Early work must be marked explicitly.")
	TEST_ASSERT_EQUAL(callback["proc"], "/proc/stoplag", "The callback must identify the delegated procedure.")

/datum/unit_test/lag_recorder_connection_ping/Run()
	var/datum/lag_recorder/test_probe/recorder = new("tester")
	allocated += recorder
	var/first = recorder.begin_ping(0, 100)
	TEST_ASSERT(first, "A capture should issue an initial connection ping.")
	TEST_ASSERT_NULL(recorder.begin_ping(3000, 130), "A slow ping must remain pending across sampling passes.")
	recorder.record_ping_reply("other", first, 3500, 135)
	recorder.record_ping_reply("tester", "stale", 3500, 135)
	TEST_ASSERT_EQUAL(length(recorder.events), 0, "Ignore replies from other clients and stale requests.")

	recorder.record_ping_reply("tester", first, 4300, 143)
	recorder.record_ping_reply("tester", first, 4400, 144)
	TEST_ASSERT_EQUAL(length(recorder.events), 1, "Log a valid reply exactly once.")
	TEST_ASSERT_EQUAL(recorder.last_report["status"], "ok", "A valid reply should be marked successful.")
	TEST_ASSERT_EQUAL(recorder.last_report["rtt_ms"], 4300, "RTT must use elapsed wall time, even across a stall.")
	TEST_ASSERT_EQUAL(recorder.last_report["sent_world_ds"], 100, "Keep the send tick for spike correlation.")

	var/second = recorder.begin_ping(4500, 145)
	TEST_ASSERT_NULL(recorder.begin_ping(14499, 245), "Do not time out a pending request early.")
	var/third = recorder.begin_ping(14500, 245)
	TEST_ASSERT(third && third != second, "After a timeout issue a fresh request.")
	TEST_ASSERT_EQUAL(recorder.last_report["status"], "timeout", "A missing reply must be visible in the log.")
	TEST_ASSERT_EQUAL(recorder.last_report["elapsed_ms"], 10000, "Report how long the request had been pending.")
	recorder.record_ping_reply("tester", second, 14600, 246)
	TEST_ASSERT_EQUAL(length(recorder.events), 2, "A late reply cannot complete the new request.")
	TEST_ASSERT_NULL(recorder.begin_ping(24500, 345, FALSE), "A disconnected client cannot receive another ping.")
	TEST_ASSERT_EQUAL(length(recorder.events), 3, "The outstanding request must time out even if the client has disconnected.")
	TEST_ASSERT_NULL(recorder.begin_ping(900000, 300), "Do not send another ping after capture expiry.")

/// Nested lifecycle phases need independent scalar IDs and a capture guard across stop/restart.
/datum/unit_test/lag_recorder_lifecycle_events/Run()
	var/datum/lag_recorder/test_probe/recorder = new
	var/datum/lag_recorder/test_probe/replacement = new
	allocated += list(recorder, replacement)
	var/outer = recorder.begin_lifecycle("living_logout_dm", "/mob/living/carbon/human", 100, 10)
	var/inner = recorder.begin_lifecycle("mob_logout_dm", "/mob/living/carbon/human", 102, 10)
	TEST_ASSERT(outer && inner && outer != inner, "Nested DM phases must receive separate numeric span IDs.")
	recorder.end_lifecycle(recorder.capture_id, inner, "mob_logout_dm", "/mob/living/carbon/human", 102, 112, 10)
	TEST_ASSERT_EQUAL(recorder.last_report["elapsed_ms"], 10, "The end must preserve elapsed wall time for that phase.")
	TEST_ASSERT_EQUAL(recorder.last_report["span_id"], inner, "The end must pair with its own begin.")
	recorder.end_lifecycle(recorder.capture_id, outer, "living_logout_dm", "/mob/living/carbon/human", 100, 250, 11)
	TEST_ASSERT_EQUAL(recorder.last_report["elapsed_ms"], 150, "A yielding phase must remain elapsed wall time, not be discarded or called CPU time.")
	replacement.begin_lifecycle("client_del_dm", "/client", 0, 11)
	replacement.end_lifecycle(recorder.capture_id, outer, "living_logout_dm", "/mob/living/carbon/human", 100, 200, 11)
	TEST_ASSERT_EQUAL(length(replacement.events), 1, "A previous capture's end must never be written into the next capture.")
	TEST_ASSERT_NULL(recorder.begin_lifecycle("client_del_dm", "/client", 900000, 11), "Do not start a phase after capture expiry.")
	for(var/list/report as anything in recorder.reports)
		TEST_ASSERT(isnum(report["capture_id"]) && isnum(report["span_id"]) && istext(report["target_type"]), "Only scalar IDs and a type string may identify a lifecycle event.")
		TEST_ASSERT(!("ckey" in report) && !("key" in report) && !("ref" in report), "Lifecycle output must not contain player identities or object references.")

/// Exercise real nested Logout handlers with capture off and on, including return and body preservation.
/datum/unit_test/lag_recorder_logout_handlers/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/lag_recorder/test_probe/recorder = new
	allocated += recorder
	var/datum/lag_recorder/previous = Master.lag_recorder
	Master.lag_recorder = null
	var/unrecorded_result = body.Logout()
	var/body_location = body.loc
	var/body_status = body.stat
	rustg_time_reset("lag_recorder")
	Master.lag_recorder = recorder
	var/recorded_result = body.Logout()
	Master.lag_recorder = previous
	TEST_ASSERT_EQUAL(recorded_result, unrecorded_result, "Recording must preserve Logout's return value.")
	TEST_ASSERT(!QDELETED(body) && body.loc == body_location && body.stat == body_status, "Recording a logout must not remove, move or kill its body.")
	TEST_ASSERT_EQUAL(length(recorder.reports), 4, "A living body's logout must record both nested begins and ends.")
	var/list/outer_begin = recorder.reports[1]
	var/list/inner_begin = recorder.reports[2]
	var/list/inner_end = recorder.reports[3]
	var/list/outer_end = recorder.reports[4]
	TEST_ASSERT_EQUAL(outer_begin["phase"], "living_logout_dm", "The living wrapper must begin before the base mob handler.")
	TEST_ASSERT_EQUAL(inner_begin["phase"], "mob_logout_dm", "The base mob handler must remain separately measurable.")
	TEST_ASSERT_EQUAL(inner_begin["span_id"], inner_end["span_id"], "The base mob handler must close its own span.")
	TEST_ASSERT_EQUAL(outer_begin["span_id"], outer_end["span_id"], "The living handler must close after its base handler.")
	TEST_ASSERT_EQUAL(inner_end["edge"], "end", "The base handler must return normally.")
	TEST_ASSERT_EQUAL(outer_end["edge"], "end", "The living handler must return normally.")

/datum/lag_lifecycle_capture_switch
	var/datum/lag_recorder/replacement

/datum/lag_lifecycle_capture_switch/proc/on_logout()
	SIGNAL_HANDLER
	Master.lag_recorder = replacement

/// A real logout callback can stop capture; neither enclosing handler may write into its replacement.
/datum/unit_test/lag_recorder_logout_capture_switch/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/lag_recorder/test_probe/recorder = new
	var/datum/lag_recorder/test_probe/replacement = new
	var/datum/lag_lifecycle_capture_switch/switcher = new
	allocated += list(recorder, replacement, switcher)
	switcher.replacement = replacement
	switcher.RegisterSignal(body, COMSIG_MOB_LOGOUT, TYPE_PROC_REF(/datum/lag_lifecycle_capture_switch, on_logout))
	var/datum/lag_recorder/previous = Master.lag_recorder
	rustg_time_reset("lag_recorder")
	Master.lag_recorder = recorder
	body.Logout()
	Master.lag_recorder = previous
	switcher.UnregisterSignal(body, COMSIG_MOB_LOGOUT)
	switcher.replacement = null
	TEST_ASSERT_EQUAL(length(recorder.reports), 2, "The original capture must retain only the two begins emitted before it stopped.")
	TEST_ASSERT_EQUAL(length(replacement.reports), 0, "Interrupted spans must not leak their ends into a new capture.")

/// A capture must leave the engine's proc and SendMaps profiles beside the round logs.
/datum/unit_test/lag_recorder_profile_dump/Run()
	var/datum/lag_recorder/recorder = new
	var/capture_id = recorder.capture_id
	TEST_ASSERT(recorder.profiling, "Starting a capture must start the engine profiler.")
	var/busy = 0
	for(var/i in 1 to 20000)
		busy += sqrt(i)
	qdel(recorder)
	var/proc_path = "[GLOB.log_directory]/lag_profile_[capture_id].json"
	var/sendmaps_path = "[GLOB.log_directory]/lag_sendmaps_[capture_id].json"
	TEST_ASSERT(fexists(proc_path), "The proc profile must be written when the capture ends.")
	TEST_ASSERT(fexists(sendmaps_path), "The SendMaps profile must be written when the capture ends.")
	var/list/entries = safe_json_decode(file2text(proc_path))
	TEST_ASSERT(islist(entries) && length(entries), "The proc profile must be a non-empty JSON list.")
	var/list/first = entries[1]
	TEST_ASSERT(istext(first["name"]) && isnum(first["self"]) && isnum(first["total"]), "Profile rows must carry the fields the digest ranks by.")
	fdel(proc_path)
	fdel(sendmaps_path)
