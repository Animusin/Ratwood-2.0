/datum/lag_recorder/test_probe
	var/list/events = list()
	var/list/last_report

/datum/lag_recorder/test_probe/write_event(kind, list/data)
	events += kind
	last_report = data

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
