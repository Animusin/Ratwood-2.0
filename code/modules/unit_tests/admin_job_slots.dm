/datum/unit_test/admin_job_slots/Run()
	for(var/job_type in list(/datum/job/roguetown/adventurer, /datum/job/roguetown/mercenary))
		var/datum/job/job = new job_type
		allocated += job
		var/configured_total = job.total_positions
		var/automatic_limit = job.get_position_limit(TRUE)
		job.current_positions = automatic_limit
		job.set_admin_position_limit(max(job.current_positions, job.get_position_limit(TRUE)) + 1)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), automatic_limit + 1, "Add 1 must actually expose a latejoin slot for [job.title].")
		TEST_ASSERT_EQUAL(job.get_position_limit(FALSE), automatic_limit + 1, "An explicit limit must also be honored at roundstart.")
		job.set_admin_position_limit(job.get_position_limit(TRUE) - 1)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), automatic_limit, "Remove must close the added slot.")
		job.set_admin_position_limit(100)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), 100, "Custom limits may exceed the population ceiling.")
		job.set_admin_position_limit(0)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), 0, "Zero must close the job instead of restoring automatic slots.")
		job.set_admin_position_limit(-1)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), -1, "Unlimit must bypass population scaling.")
		job.set_admin_position_limit(job.current_positions)
		TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job), job.current_positions, "Limit must close vacancies without removing occupants.")
		job.reset_admin_position_limit()
		TEST_ASSERT_EQUAL(job.total_positions, configured_total, "Reset must restore the configured total after multiple edits.")
		TEST_ASSERT_EQUAL(job.get_position_limit(TRUE), automatic_limit, "Reset must restore population scaling.")

	var/datum/job/static_job = new
	allocated += static_job
	static_job.total_positions = 7
	static_job.spawn_positions = 3
	static_job.set_admin_position_limit(8)
	TEST_ASSERT_EQUAL(static_job.get_position_limit(TRUE), 8, "Static jobs must still accept admin limits.")
	static_job.reset_admin_position_limit()
	TEST_ASSERT_EQUAL(static_job.get_position_limit(TRUE), 7, "Reset must preserve configured static latejoin slots.")
	TEST_ASSERT_EQUAL(static_job.get_position_limit(FALSE), 3, "Reset must preserve separate roundstart slots.")
