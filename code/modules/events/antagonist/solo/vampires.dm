/datum/round_event_control/antagonist/solo/vampires
	name = "Vampires"
	tags = list(
		TAG_COMBAT,
		TAG_HAUNTED,
		TAG_VILLIAN,
	)
	roundstart = TRUE
	antag_flag = ROLE_NBEAST
	shared_occurence_type = SHARED_HIGH_THREAT

	weight = 4
	max_occurrences = 1

	denominator = 80

	base_antags = 1
	maximum_antags = 2

	earliest_start = 0 SECONDS

	typepath = /datum/round_event/antagonist/solo/vampire
	antag_datum = /datum/antagonist/vampire
	var/leader_antag_datum = /datum/antagonist/vampire/lord

	restricted_roles = DEFAULT_ANTAG_BLACKLISTED_ROLES

/datum/round_event_control/antagonist/solo/vampires/get_antag_cap_weight(index)
	return index == 1 ? 3 : 2

/datum/round_event/antagonist/solo/vampire
	var/leader = FALSE

/datum/round_event/antagonist/solo/vampire/add_datum_to_mind(datum/mind/antag_mind)
	var/datum/round_event_control/antagonist/solo/vampires/vampire_control = control
	if(!leader)
		var/datum/job/J = SSjob.GetJob(antag_mind.current?.job)
		J?.current_positions = max(J?.current_positions-1, 0)
		antag_mind.current.unequip_everything()
		var/leader_type = vampire_control.leader_antag_datum
		var/datum/antagonist/vampire/lord/lorde = new leader_type()
		antag_mind.add_antag_datum(lorde)
		leader = TRUE
		return
	else
		if(!antag_mind.has_antag_datum(antag_datum))
			var/datum/job/J = SSjob.GetJob(antag_mind.current?.job)
			J?.current_positions = max(J?.current_positions-1, 0)
			antag_mind.current.unequip_everything()
			var/vampire_type = vampire_control.antag_datum
			var/datum/antagonist/vampire/servante = new vampire_type(forced_clan = null, generation = GENERATION_ANCILLAE)
			antag_mind.add_antag_datum(servante)
			return
