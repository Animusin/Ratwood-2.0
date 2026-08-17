#define RATWOOD_CHAOS_LOW "Low Chaos"
#define RATWOOD_CHAOS_HIGH "High Chaos"
#define RATWOOD_LOW_DIVISOR 15
#define RATWOOD_HIGH_DIVISOR 10

/datum/round_modifier_policy
	var/id = "upstream"

/datum/round_modifier_policy/proc/handle_vote(datum/controller/subsystem/gamemode/mode, winner)
	return

/datum/round_modifier_policy/proc/select_modifiers(datum/controller/subsystem/gamemode/mode)
	return

/datum/round_modifier_policy/upstream/handle_vote(datum/controller/subsystem/gamemode/mode, winner)
	mode.chaos_mode_name = winner == RATWOOD_CHAOS_HIGH ? RATWOOD_CHAOS_HIGH : RATWOOD_CHAOS_LOW
	mode.level = mode.chaos_mode_name == RATWOOD_CHAOS_HIGH ? 3 : 1
	mode.chaos_divisor = ANTAG_CAP_DENOMINATOR
	mode.roundstart_antag_allocation_complete = TRUE

/datum/round_modifier_policy/upstream/select_modifiers(datum/controller/subsystem/gamemode/mode)
	mode.roll_upstream_round_modifiers()

/datum/round_modifier_policy/ratwood
	id = "ratwood"

/datum/round_modifier_policy/ratwood/handle_vote(datum/controller/subsystem/gamemode/mode, winner)
	mode.chaos_mode_name = winner == RATWOOD_CHAOS_HIGH ? RATWOOD_CHAOS_HIGH : RATWOOD_CHAOS_LOW
	mode.level = mode.chaos_mode_name == RATWOOD_CHAOS_HIGH ? 3 : 1
	mode.chaos_divisor = mode.chaos_mode_name == RATWOOD_CHAOS_HIGH ? RATWOOD_HIGH_DIVISOR : RATWOOD_LOW_DIVISOR
	// A late fallback may run after pre_setup() has already snapshotted the lobby.
	// Recounting after character transfer would lose the number of players who readied up.
	if(!SSticker.HasRoundStarted())
		mode.calculate_ready_players()
	mode.roundstart_cap_snapshot = calculate_roundstart_cap(mode.ready_players, mode.chaos_divisor)
	mode.roundstart_antag_allocation_complete = FALSE
	mode.roundstart_reserved_antag_weight = 0
	mode.planned_villain_counts = list()
	mode.planned_villain_weights = list()

/datum/round_modifier_policy/ratwood/select_modifiers(datum/controller/subsystem/gamemode/mode)
	if(!mode.roundstart_cap_snapshot)
		handle_vote(mode, RATWOOD_CHAOS_LOW)
	mode.budget = mode.roundstart_cap_snapshot
	var/list/pool = get_modifier_pool(mode.chaos_mode_name)

	while(mode.budget > 0 && length(pool))
		var/list/affordable = list()
		for(var/datum/round_modifier/ratwood/modifier as anything in pool)
			var/exclusive_group_taken = FALSE
			for(var/datum/round_modifier/ratwood/active_modifier in mode.active_modifiers)
				if(modifier.exclusive_group && modifier.exclusive_group == active_modifier.exclusive_group)
					exclusive_group_taken = TRUE
					break
			if(!exclusive_group_taken && modifier.minimum_cost <= mode.budget && modifier.minimum_players <= mode.ready_players)
				affordable += modifier
		if(!length(affordable))
			break
		var/datum/round_modifier/ratwood/selected_modifier = pick(affordable)
		pool -= selected_modifier
		if(!selected_modifier.prepare(mode, mode.budget))
			qdel(selected_modifier)
			continue
		mode.budget -= selected_modifier.cost
		mode.active_modifiers += selected_modifier
		selected_modifier.reserve(mode)

	roll_weather(mode)

/datum/round_modifier_policy/ratwood/proc/get_modifier_pool(chaos_mode)
	var/list/pool = list(
		new /datum/round_modifier/ratwood/lesser/bandit,
		new /datum/round_modifier/ratwood/lesser/wretch,
		new /datum/round_modifier/ratwood/lesser/gnoll,
		new /datum/round_modifier/ratwood/major/masquerade,
		new /datum/round_modifier/ratwood/major/rebellion,
		new /datum/round_modifier/ratwood/major/dreamwalker,
		new /datum/round_modifier/ratwood/major/assassins,
	)
	if(chaos_mode == RATWOOD_CHAOS_HIGH)
		pool += list(
			new /datum/round_modifier/ratwood/major/vampire_lord,
			new /datum/round_modifier/ratwood/major/werewolf,
			new /datum/round_modifier/ratwood/major/lich,
		)
	return pool

/datum/round_modifier_policy/ratwood/proc/roll_weather(datum/controller/subsystem/gamemode/mode)
	var/list/weather_pool = list("None" = 10, /datum/round_modifier/ratwood/weather/clear = 10, /datum/round_modifier/ratwood/weather/fog = 10)
	if(mode.chaos_mode_name == RATWOOD_CHAOS_HIGH)
		weather_pool[/datum/round_modifier/ratwood/weather/stormy] = 8
	var/weather_type = pickweight(weather_pool)
	if(ispath(weather_type))
		mode.active_modifiers += new weather_type

/// Kept pure for unit tests and for admin tooling.
/proc/calculate_roundstart_cap(ready_players, divisor)
	return calculate_antag_cap_from_population(ready_players, divisor)

/proc/calculate_antag_cap_from_population(cap_population, divisor)
	return FLOOR(max(cap_population, 0) / divisor, 1) + ANTAG_CAP_FLAT

/datum/round_modifier/ratwood
	min_chaos = 99 // Never enter the upstream subtype picker.
	var/minimum_cost = 1
	var/minimum_players = 0
	var/exclusive_group
	var/planned_antag_count = 0
	var/planned_antag_weight = 0
	var/villain_event_type

/datum/round_modifier/ratwood/proc/prepare(datum/controller/subsystem/gamemode/mode, remaining_budget)
	return cost <= remaining_budget

/datum/round_modifier/ratwood/proc/reserve(datum/controller/subsystem/gamemode/mode)
	if(!villain_event_type || !planned_antag_count)
		return
	var/datum/round_event_control/event = locate(villain_event_type) in mode.control
	if(!event)
		return
	mode.planned_villain_counts[event] = planned_antag_count
	mode.planned_villain_weights[event] = planned_antag_weight
	mode.roundstart_reserved_antag_weight += planned_antag_weight

/datum/round_modifier/ratwood/lesser
	var/job_title

/datum/round_modifier/ratwood/lesser/prepare(datum/controller/subsystem/gamemode/mode, remaining_budget)
	planned_antag_count = rand(1, remaining_budget)
	planned_antag_weight = planned_antag_count
	cost = planned_antag_count
	name = "[job_title] [planned_antag_count]"
	desc = "[planned_antag_count] [job_title] slot[planned_antag_count == 1 ? "" : "s"]."
	job_slots = list()
	job_slots[job_title] = planned_antag_count
	return TRUE

/datum/round_modifier/ratwood/lesser/bandit
	job_title = "Bandit"
	exclusive_group = "bandit"

/datum/round_modifier/ratwood/lesser/wretch
	job_title = "Wretch"
	exclusive_group = "wretch"

/datum/round_modifier/ratwood/lesser/gnoll
	job_title = "Gnoll"
	exclusive_group = "gnoll"

/datum/round_modifier/ratwood/major
	var/datum/round_event_control/antagonist/solo/prepared_event

/datum/round_modifier/ratwood/major/prepare(datum/controller/subsystem/gamemode/mode, remaining_budget)
	prepared_event = locate(villain_event_type) in mode.control
	if(!prepared_event)
		return FALSE
	var/desired_count = get_desired_count(mode)
	for(var/index in 1 to desired_count)
		var/next_weight = prepared_event.get_antag_cap_weight(index)
		if(planned_antag_weight + next_weight > remaining_budget)
			break
		planned_antag_weight += next_weight
		planned_antag_count++
	if(!planned_antag_count)
		return FALSE
	cost = planned_antag_weight
	villain_events = list(villain_event_type)
	desc = "[planned_antag_count] planned participant[planned_antag_count == 1 ? "" : "s"], reserving [planned_antag_weight] antagonist capacity."
	return TRUE

/datum/round_modifier/ratwood/major/proc/get_desired_count(datum/controller/subsystem/gamemode/mode)
	return prepared_event.get_desired_antag_amount(mode.ready_players)

/datum/round_modifier/ratwood/major/masquerade
	name = "Masquerade"
	villain_event_type = /datum/round_event_control/antagonist/solo/masquerade/ratwood

/datum/round_modifier/ratwood/major/rebellion
	name = "Rebellion"
	villain_event_type = /datum/round_event_control/antagonist/solo/rebel/ratwood

/datum/round_modifier/ratwood/major/dreamwalker
	name = "Dreamwalker"
	minimum_players = 40
	villain_event_type = /datum/round_event_control/antagonist/solo/dreamwalker/ratwood

/datum/round_modifier/ratwood/major/assassins
	name = "Assassins"
	villain_event_type = /datum/round_event_control/antagonist/solo/assassins/ratwood

/datum/round_modifier/ratwood/major/assassins/get_desired_count(datum/controller/subsystem/gamemode/mode)
	return 2

/datum/round_modifier/ratwood/major/vampire_lord
	name = "Vampire Lord"
	minimum_cost = 3
	villain_event_type = /datum/round_event_control/antagonist/solo/vampires/ratwood

/datum/round_modifier/ratwood/major/werewolf
	name = "Werewolf"
	minimum_cost = 2
	minimum_players = 25
	villain_event_type = /datum/round_event_control/antagonist/solo/werewolf/ratwood

/datum/round_modifier/ratwood/major/lich
	name = "Lich"
	minimum_cost = 2
	villain_event_type = /datum/round_event_control/antagonist/solo/lich/ratwood

// Round-modifier-only event controls inherit all upstream candidate and spawn behavior.
/datum/round_event_control/antagonist/solo/masquerade/ratwood
	name = "Ratwood: Masquerade"
	round_modifier_label = "Masquerade"
	round_modifier_only = TRUE
	max_occurrences = 1
	antag_datum = /datum/antagonist/vampire/ratwood

/datum/round_event_control/antagonist/solo/rebel/ratwood
	name = "Ratwood: Rebellion"
	round_modifier_label = "Rebellion"
	round_modifier_only = TRUE
	antag_cap_weight = 2
	antag_datum = /datum/antagonist/prebel/head/ratwood

/datum/round_event_control/antagonist/solo/dreamwalker/ratwood
	name = "Ratwood: Dreamwalker"
	round_modifier_label = "Dreamwalker"
	round_modifier_only = TRUE
	roundstart = TRUE
	max_occurrences = 1
	antag_cap_weight = 2
	antag_datum = /datum/antagonist/dreamwalker/ratwood

/datum/round_event_control/antagonist/solo/assassins/ratwood
	name = "Ratwood: Assassins"
	round_modifier_label = "Assassins"
	round_modifier_only = TRUE
	checks_antag_cap = TRUE
	base_antags = 2
	maximum_antags = 2
	max_occurrences = 1
	antag_cap_weight = 0.5
	requires_full_planned_count = TRUE
	antag_datum = /datum/antagonist/assassin/ratwood

/datum/round_event_control/antagonist/solo/vampires/ratwood
	name = "Ratwood: Vampire Lord"
	round_modifier_label = "Vampire Lord"
	round_modifier_only = TRUE
	antag_datum = /datum/antagonist/vampire/ratwood
	leader_antag_datum = /datum/antagonist/vampire/lord/ratwood

/datum/round_event_control/antagonist/solo/werewolf/ratwood
	name = "Ratwood: Werewolf"
	round_modifier_label = "Werewolf"
	round_modifier_only = TRUE
	weight = 10
	max_occurrences = 1
	antag_cap_weight = 2
	antag_datum = /datum/antagonist/werewolf/ratwood

/datum/round_event_control/antagonist/solo/lich/ratwood
	name = "Ratwood: Lich"
	round_modifier_label = "Lich"
	round_modifier_only = TRUE
	max_occurrences = 1
	antag_cap_weight = 2
	antag_datum = /datum/antagonist/lich/ratwood

// Actual cap weights mirror the costs reserved above.
/datum/antagonist/vampire/ratwood

/datum/antagonist/vampire/ratwood/get_antag_cap_weight()
	return 2

/datum/antagonist/vampire/lord/ratwood

/datum/antagonist/vampire/lord/ratwood/get_antag_cap_weight()
	return 3

/datum/antagonist/assassin/ratwood
	antag_flags = NONE

/datum/antagonist/assassin/ratwood/get_antag_cap_weight()
	return 0.5

/datum/antagonist/prebel/head/ratwood/get_antag_cap_weight()
	return 2

/datum/antagonist/dreamwalker/ratwood/get_antag_cap_weight()
	return 2

/datum/antagonist/werewolf/ratwood/get_antag_cap_weight()
	return 2

/datum/antagonist/lich/ratwood/get_antag_cap_weight()
	return 2

// Weather wrappers intentionally inherit upstream behavior instead of duplicating it.
/datum/round_modifier/ratwood/weather/clear
	parent_type = /datum/round_modifier/clear
	min_chaos = 99

/datum/round_modifier/ratwood/weather/fog
	parent_type = /datum/round_modifier/fog
	min_chaos = 99

/datum/round_modifier/ratwood/weather/stormy
	parent_type = /datum/round_modifier/stormy
	min_chaos = 99

#undef RATWOOD_CHAOS_LOW
#undef RATWOOD_CHAOS_HIGH
#undef RATWOOD_LOW_DIVISOR
#undef RATWOOD_HIGH_DIVISOR
