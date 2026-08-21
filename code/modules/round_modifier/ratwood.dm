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
	// Snapshot all connected players. The live cap switches back to the same online-player
	// formula after roundstart allocation finishes.
	mode.roundstart_population_snapshot = length(GLOB.clients)
	mode.roundstart_cap_snapshot = calculate_roundstart_cap(mode.roundstart_population_snapshot, mode.chaos_divisor)
	mode.roundstart_antag_allocation_complete = FALSE
	mode.roundstart_reserved_antag_weight = 0
	mode.planned_villain_counts = list()
	mode.planned_villain_weights = list()

/datum/round_modifier_policy/ratwood/select_modifiers(datum/controller/subsystem/gamemode/mode)
	if(mode.roundstart_antag_allocation_complete)
		handle_vote(mode, RATWOOD_CHAOS_LOW)
	mode.budget = mode.roundstart_cap_snapshot
	var/list/pool = get_major_modifier_pool(mode.chaos_mode_name)
	var/list/available_modes = list()
	for(var/datum/round_modifier/ratwood/major/modifier as anything in pool)
		if(modifier.minimum_cost <= mode.budget && modifier.minimum_players <= mode.roundstart_population_snapshot)
			available_modes += modifier

	if(length(available_modes))
		var/datum/round_modifier/ratwood/major/selected_mode = pick(available_modes)
		if(selected_mode.prepare(mode, mode.budget))
			mode.budget -= selected_mode.cost
			mode.active_modifiers += selected_mode
			selected_mode.reserve(mode)
		else
			qdel(selected_mode)

	for(var/datum/round_modifier/ratwood/unused_modifier as anything in pool)
		if(!(unused_modifier in mode.active_modifiers) && !QDELETED(unused_modifier))
			qdel(unused_modifier)

	roll_weather(mode)

/datum/round_modifier_policy/ratwood/proc/get_major_modifier_pool(chaos_mode)
	var/list/pool = list(
		new /datum/round_modifier/ratwood/major/masquerade,
		new /datum/round_modifier/ratwood/major/rebellion,
		new /datum/round_modifier/ratwood/major/dreamwalker,
		new /datum/round_modifier/ratwood/major/assassins,
	)
	if(chaos_mode == RATWOOD_CHAOS_HIGH)
		pool += list(
			new /datum/round_modifier/ratwood/major/vampire_lord,
			new /datum/round_modifier/ratwood/major/werewolf,
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
/proc/calculate_roundstart_cap(online_players, divisor)
	return calculate_ratwood_antag_cap(online_players, divisor)

/// Ratwood uses the online population ratio plus the shared flat antagonist allowance.
/proc/calculate_ratwood_antag_cap(online_players, divisor)
	if(divisor <= 0)
		return 0
	return FLOOR(max(online_players, 0) / divisor, 1) + ANTAG_CAP_FLAT

/proc/calculate_antag_cap_from_population(cap_population, divisor)
	return FLOOR(max(cap_population, 0) / divisor, 1) + ANTAG_CAP_FLAT

/datum/round_modifier/ratwood
	min_chaos = 99 // Never enter the upstream subtype picker.
	var/minimum_cost = 1
	var/minimum_players = 0
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

/datum/round_modifier/ratwood/major
	var/datum/round_event_control/antagonist/solo/prepared_event

/datum/round_modifier/ratwood/major/prepare(datum/controller/subsystem/gamemode/mode, remaining_budget)
	prepared_event = locate(villain_event_type) in mode.control
	if(!prepared_event)
		return FALSE
	return plan_for_budget(remaining_budget, mode.roundstart_population_snapshot)

/// Plan no more than the event's population-derived amount while respecting the cap.
/// Modes returning a null planning limit may keep adding participants while they fit.
/datum/round_modifier/ratwood/major/proc/plan_for_budget(remaining_budget, online_players)
	planned_antag_count = 0
	planned_antag_weight = 0
	var/planning_limit = get_planning_limit(online_players)
	while(isnull(planning_limit) || planned_antag_count < planning_limit)
		var/next_weight = max(prepared_event.get_antag_cap_weight(planned_antag_count + 1), 0)
		if(!next_weight)
			break
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

/datum/round_modifier/ratwood/major/proc/get_planning_limit(online_players)
	return prepared_event.get_desired_antag_amount(online_players)

/datum/round_modifier/ratwood/major/masquerade
	name = "Masquerade"
	minimum_cost = 2
	villain_event_type = /datum/round_event_control/antagonist/solo/masquerade/ratwood

/datum/round_modifier/ratwood/major/masquerade/get_planning_limit(online_players)
	return null

/datum/round_modifier/ratwood/major/rebellion
	name = "Rebellion"
	minimum_cost = 2
	villain_event_type = /datum/round_event_control/antagonist/solo/rebel/ratwood

/datum/round_modifier/ratwood/major/dreamwalker
	name = "Dreamwalker"
	minimum_cost = 2
	minimum_players = 40
	villain_event_type = /datum/round_event_control/antagonist/solo/dreamwalker/ratwood

/datum/round_modifier/ratwood/major/assassins
	name = "Assassins"
	villain_event_type = /datum/round_event_control/antagonist/solo/assassins/ratwood

/datum/round_modifier/ratwood/major/vampire_lord
	name = "Vampire Lord"
	minimum_cost = 3
	villain_event_type = /datum/round_event_control/antagonist/solo/vampires/ratwood

/datum/round_modifier/ratwood/major/vampire_lord/get_planning_limit(online_players)
	return null

/datum/round_modifier/ratwood/major/werewolf
	name = "Werewolf"
	minimum_cost = 2
	minimum_players = 25
	villain_event_type = /datum/round_event_control/antagonist/solo/werewolf/ratwood

/datum/round_modifier/ratwood/major/lich
	name = "Lich"
	minimum_cost = 3
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
	antag_cap_weight = 3
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
	return 3

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
