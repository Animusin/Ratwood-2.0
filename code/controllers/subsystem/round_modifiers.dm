/datum/controller/subsystem/gamemode
	var/level = 2
	var/budget = 0
	var/list/active_modifiers = list()
	var/modifiers_rolled = FALSE
	var/datum/round_modifier_policy/round_modifier_policy

/datum/controller/subsystem/gamemode/proc/get_round_modifier_policy()
	if(round_modifier_policy)
		return round_modifier_policy
	round_modifier_policy_name = CONFIG_GET(string/round_modifier_policy)
	if(round_modifier_policy_name == "upstream")
		round_modifier_policy = new /datum/round_modifier_policy/upstream
	else
		round_modifier_policy_name = "ratwood"
		round_modifier_policy = new /datum/round_modifier_policy/ratwood
	return round_modifier_policy

/datum/controller/subsystem/gamemode/proc/chaos_vote_result(winner)
	var/datum/round_modifier_policy/policy = get_round_modifier_policy()
	policy.handle_vote(src, winner)
	to_chat(world, span_notice("<b>[chaos_mode_name]!</b>"))
	roll_round_modifiers()

/datum/controller/subsystem/gamemode/proc/roll_round_modifiers()
	if(modifiers_rolled)
		return
	modifiers_rolled = TRUE
	if(istype(SSvote.current_vote, /datum/vote/chaos))
		SSvote.end_vote()
	var/datum/round_modifier_policy/policy = get_round_modifier_policy()
	policy.select_modifiers(src)
	apply_round_modifiers()

/// The old upstream picker is deliberately retained behind the policy hook.
/datum/controller/subsystem/gamemode/proc/roll_upstream_round_modifiers()
	switch(level)
		if(0)
			active_modifiers += new /datum/round_modifier/adventure
		if(1)
			budget = rand(2, 5)
		if(2)
			budget = rand(6, 8)
		if(3)
			budget = rand(6, 12)

	var/list/pool = list()
	for(var/modifier_type in subtypesof(/datum/round_modifier))
		if(ispath(modifier_type, /datum/round_modifier/ratwood))
			continue
		var/datum/round_modifier/modifier = new modifier_type
		if(level < modifier.min_chaos || level > modifier.max_chaos)
			qdel(modifier)
			continue
		pool[modifier] = modifier.weight

	while(budget > 0 && length(pool))
		var/datum/round_modifier/modifier = pickweight(pool)
		pool -= modifier
		if(modifier.cost > budget)
			qdel(modifier)
			continue
		var/blocked = FALSE
		for(var/datum/round_modifier/other in active_modifiers)
			if((other.type in modifier.incompatible) || (modifier.type in other.incompatible))
				blocked = TRUE
				break
		if(blocked)
			qdel(modifier)
			continue
		budget -= modifier.cost
		active_modifiers += modifier

/// Apply the already-selected modifiers. Policies own selection; this is the small shared integration point.
/datum/controller/subsystem/gamemode/proc/apply_round_modifiers()
	var/list/slots = list()
	var/datum/forecast/forecast = SSParticleWeather?.selected_forecast

	for(var/datum/round_modifier/modifier in active_modifiers)
		for(var/job_title in modifier.job_slots)
			slots[job_title] += modifier.job_slots[job_title]
		for(var/event_type in modifier.villain_events)
			var/datum/round_event_control/event = locate(event_type) in control
			if(event)
				rolled_villain_events |= event
		if(forecast && length(modifier.weather_weights))
			for(var/list/weather_list in list(forecast.day_weather, forecast.dawn_weather, forecast.dusk_weather, forecast.night_weather))
				for(var/weather_type in modifier.weather_weights)
					if(weather_type in weather_list)
						weather_list[weather_type] = round(weather_list[weather_type] * modifier.weather_weights[weather_type])

	for(var/job_title in slots)
		var/datum/job/job = SSjob.GetJob(job_title)
		if(!job)
			continue
		job.total_positions += slots[job_title]
		job.spawn_positions += slots[job_title]

	if(!length(active_modifiers))
		to_chat(world, span_notice("<b>Nothing.</b>"))
		return
	to_chat(world, span_boldnotice("Modifiers:"))
	for(var/datum/round_modifier/modifier in active_modifiers)
		if(!modifier.hidden)
			to_chat(world, span_notice("<b>[modifier.name]</b> - [modifier.desc]"))
