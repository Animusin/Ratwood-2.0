/datum/unit_test/lowtown_job_whitelists/Run()
	for(var/job_type in list(/datum/job/roguetown/baron, /datum/job/roguetown/baron_retainer))
		var/datum/job/job = new job_type
		allocated += job
		TEST_ASSERT(job.whitelist_req, "[job.title] must require whitelist access.")
