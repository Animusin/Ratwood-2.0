/datum/unit_test/antag_cap_weights/Run()
	var/datum/job/wretch_job = SSjob.GetJob("Wretch")
	var/datum/job/gnoll_job = SSjob.GetJob("Gnoll")
	var/datum/job/bandit_job = SSjob.GetJob("Bandit")
	var/datum/job/assassin_job = SSjob.GetJob("Assassin")

	TEST_ASSERT_EQUAL(wretch_job?.antag_cap_weight, 1, "Wretch job should consume one antagonist slot.")
	TEST_ASSERT_EQUAL(gnoll_job?.antag_cap_weight, 1, "Gnoll job should consume one antagonist slot.")
	TEST_ASSERT_EQUAL(bandit_job?.antag_cap_weight, 1, "Bandit job should consume one antagonist slot.")
	TEST_ASSERT_EQUAL(assassin_job?.antag_cap_weight, 0, "Fake-antag Assassin job should not consume antagonist capacity.")

	var/datum/migrant_wave/bandit/bandit_wave = new
	var/datum/migrant_wave/assassin/assassin_wave = new
	var/datum/migrant_wave/lich/lich_wave = new
	TEST_ASSERT_EQUAL(bandit_wave.get_antag_cap_weight(), 4, "Four-bandit migrant wave should require four capacity.")
	TEST_ASSERT_EQUAL(assassin_wave.get_antag_cap_weight(), 0, "Fake-antag Assassin migrant wave should require no capacity.")
	TEST_ASSERT_EQUAL(lich_wave.get_antag_cap_weight(), 3, "Lich migrant wave should use the Lich weight of three.")
	qdel(bandit_wave)
	qdel(assassin_wave)
	qdel(lich_wave)

	var/datum/round_event_control/antagonist/solo/vampires/vampire_event = new
	var/datum/round_event_control/antagonist/solo/masquerade/masquerade_event = new
	TEST_ASSERT_EQUAL(vampire_event.get_antag_cap_weight(1), 3, "The first Vampire event pick should be a weight-three Lord.")
	TEST_ASSERT_EQUAL(vampire_event.get_antag_cap_weight(2), 2, "Additional Vampire event picks should be weight-two Ancillae.")
	TEST_ASSERT_EQUAL(masquerade_event.get_antag_cap_weight(1), 2, "Masquerade picks should be weight-two Ancillae.")
	qdel(vampire_event)
	qdel(masquerade_event)
