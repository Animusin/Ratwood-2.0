/datum/controller/subsystem/gamemode
	var/list/rolled_villain_events = list()
	var/list/queued_villains = list()

/datum/controller/subsystem/gamemode/proc/count_queued_villains(job_title)
	. = 0
	for(var/ckey in queued_villains)
		if(queued_villains[ckey] == job_title)
			.++

/datum/controller/subsystem/gamemode/proc/get_planned_villain_count(datum/round_event_control/event)
	if(!event || !(event in planned_villain_counts))
		return null
	return planned_villain_counts[event]

/datum/controller/subsystem/gamemode/proc/get_planned_villain_weight(datum/round_event_control/event)
	if(!event || !(event in planned_villain_weights))
		return null
	return planned_villain_weights[event]

/// Clip a plan to the candidates that actually exist and immediately release the unused reserve.
/datum/controller/subsystem/gamemode/proc/reduce_planned_villain_event(datum/round_event_control/antagonist/solo/event, new_count)
	if(!event || !(event in planned_villain_counts))
		return
	new_count = max(min(new_count, planned_villain_counts[event]), 0)
	var/new_weight = 0
	for(var/index in 1 to new_count)
		new_weight += event.get_antag_cap_weight(index)
	var/released_weight = max(planned_villain_weights[event] - new_weight, 0)
	planned_villain_counts[event] = new_count
	planned_villain_weights[event] = new_weight
	roundstart_reserved_antag_weight = max(roundstart_reserved_antag_weight - released_weight, 0)

/// Convert one participant's reservation immediately before their job or antagonist datum is assigned.
/// This keeps the reservation from blocking cap-aware assignment while preserving the combined total.
/datum/controller/subsystem/gamemode/proc/consume_planned_villain_reservation(datum/round_event_control/antagonist/solo/event, participant_index)
	if(!event || !(event in planned_villain_weights))
		return
	var/participant_weight = max(event.get_antag_cap_weight(participant_index), 0)
	var/consumed_weight = min(participant_weight, planned_villain_weights[event])
	planned_villain_weights[event] = max(planned_villain_weights[event] - consumed_weight, 0)
	roundstart_reserved_antag_weight = max(roundstart_reserved_antag_weight - consumed_weight, 0)

/// Release any unconsumed part of a start-event reservation after setup finishes.
/datum/controller/subsystem/gamemode/proc/complete_planned_villain_event(datum/round_event_control/event)
	if(!event || !(event in planned_villain_counts))
		return
	roundstart_reserved_antag_weight = max(roundstart_reserved_antag_weight - planned_villain_weights[event], 0)
	planned_villain_counts -= event
	planned_villain_weights -= event
	maybe_complete_roundstart_antag_allocation()

/datum/controller/subsystem/gamemode/proc/maybe_complete_roundstart_antag_allocation()
	if(round_modifier_policy_name != "ratwood" || roundstart_antag_allocation_complete)
		return
	if(length(planned_villain_counts) || length(queued_villains))
		return
	roundstart_reserved_antag_weight = 0
	roundstart_antag_allocation_complete = TRUE
	message_admins("Ratwood roundstart antagonist allocation completed; dynamic antagonist cap is now active.")

/// Safety valve for a cancelled or deleted event datum. No modifiers are rerolled.
/datum/controller/subsystem/gamemode/proc/finish_stale_roundstart_antag_reservations()
	if(roundstart_antag_allocation_complete)
		return
	if(length(planned_villain_counts))
		message_admins("Ratwood released stale roundstart antagonist reservations: [roundstart_reserved_antag_weight].")
	planned_villain_counts = list()
	planned_villain_weights = list()
	roundstart_reserved_antag_weight = 0
	maybe_complete_roundstart_antag_allocation()

/datum/controller/subsystem/gamemode/proc/open_villain_signups()
	if(current_storyteller)
		current_storyteller.guarantees_roundstart_roleset = FALSE
		current_storyteller.roundstart_prob = 0
	for(var/datum/round_event_control/event as anything in rolled_villain_events)
		var/event_result = TriggerEvent(event, TRUE)
		if(event_result != EVENT_READY)
			complete_planned_villain_event(event)
	rolled_villain_events = list()
	for(var/datum/round_modifier/M in active_modifiers)
		for(var/event_type in M.trigger_events)
			var/datum/round_event_control/event = locate(event_type) in control
			if(event)
				TriggerEvent(event, TRUE)
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		var/job_title = queued_villains[player.ckey]
		if(!job_title || !player.client || player.spawning)
			continue
		to_chat(player, span_boldwarning("You have been chosen for villainy as a [job_title]!"))
		player.AttemptLateSpawn(job_title)
	queued_villains = list()
	maybe_complete_roundstart_antag_allocation()
	if(!roundstart_antag_allocation_complete)
		addtimer(CALLBACK(src, PROC_REF(finish_stale_roundstart_antag_reservations)), 2 MINUTES)

/mob/dead/new_player/proc/VillainChoices()
	var/list/dat = list()

	if(!SSgamemode.modifiers_rolled)
		dat += "Wait."
	else
		dat += "<b>Mode:</b> [SSgamemode.chaos_mode_name]<br>"
		if(!SSgamemode.roundstart_antag_allocation_complete)
			dat += "<b>Roundstart cap:</b> [SSgamemode.roundstart_cap_snapshot]; <b>major reserve:</b> [SSgamemode.roundstart_reserved_antag_weight]<br><br>"
			var/list/lesser_plan = list()
			for(var/datum/round_modifier/ratwood/lesser/lesser_modifier in SSgamemode.active_modifiers)
				lesser_plan += lesser_modifier.name
			dat += "<b>Lesser plan:</b> [length(lesser_plan) ? lesser_plan.Join(", ") : "None"]<br><br>"
		else
			dat += "<b>Dynamic cap:</b> [SSgamemode.get_antag_count()] / [SSgamemode.get_antag_cap()]<br><br>"
		dat += "<b>Greater Villains:</b><br>"
		if(!length(SSgamemode.rolled_villain_events))
			dat += "None.<br>"
		for(var/datum/round_event_control/antagonist/event in SSgamemode.rolled_villain_events)
			var/slots = 1
			if(istype(event, /datum/round_event_control/antagonist/solo))
				var/datum/round_event_control/antagonist/solo/solo_event = event
				var/planned_slots = SSgamemode.get_planned_villain_count(solo_event)
				slots = isnull(planned_slots) ? solo_event.get_antag_amount() : planned_slots
			var/reserved_weight = SSgamemode.get_planned_villain_weight(event)
			var/event_label = event.round_modifier_label || event.name
			dat += "<b>[event_label]</b> ([slots] slots[isnull(reserved_weight) ? "" : ", [reserved_weight] reserved"])<br>"
		if(length(SSgamemode.rolled_villain_events))
			dat += "<i>These roll at roundstart from your antag preferences.</i><br>"

		dat += "<br><b>Lesser Villains:</b><br>"
		var/found = FALSE
		var/remaining_antag_capacity = SSgamemode.roundstart_antag_allocation_complete ? SSgamemode.get_remaining_antag_capacity() : null
		for(var/job_title in GLOB.villain_positions)
			var/datum/job/J = SSjob.GetJob(job_title)
			var/effective_limit = J ? SSjob.get_latejoin_position_limit(J, remaining_antag_capacity) : 0
			if(!J || !(SSticker.current_state <= GAME_STATE_PREGAME ? J.total_positions : effective_limit))
				continue
			found = TRUE
			if(SSticker.current_state <= GAME_STATE_PREGAME)
				var/pref_label = "NEVER"
				var/pref_color = "red"
				var/next_level = 3
				switch(client.prefs.job_preferences[J.title])
					if(JP_HIGH)
						pref_label = "High"
						pref_color = "slateblue"
						next_level = 4
					if(JP_MEDIUM)
						pref_label = "Medium"
						pref_color = "green"
						next_level = 1
					if(JP_LOW)
						pref_label = "Low"
						pref_color = "orange"
						next_level = 2
				dat += "<a href='?src=[REF(J)];explainjob=1'><font>[J.title]</font></a>([J.total_positions] slots) - <a href='byond://?src=[REF(src)];villain_pref=[J.title];level=[next_level]'><font color=[pref_color]>[pref_label]</font></a><br>"
			else
				var/slot_display = "([J.current_positions]/[effective_limit])"
				var/slot_link = J.current_positions < effective_limit ? "<a href='byond://?src=[REF(src)];SelectedJob=[J.title]'>[slot_display]</a>" : "<font color='gray'>[slot_display] FULL</font>"
				dat += "<a href='?src=[REF(J)];explainjob=1'><font>[J.title]</font></a>[slot_link]<a href='?src=[REF(J)];jobsubclassinfo=1'><b><font color = '#6b6743'>(!)</font></b></a><br>"

		if(!found)
			dat += "No villain roles this round."

	var/datum/browser/popup = new(src, "villainchoices", "Villains", 340, 400)
	popup.add_stylesheet("playeroptions", 'html/browser/playeroptions.css')
	popup.set_content(jointext(dat, ""))
	popup.open(FALSE)

// this menu allows players 2 boost their stats to wretch tier (+12 weight) & choose between DE / Heavy Armor
/mob/living/carbon/human/var/datum/antag_setup/antag_setup

/datum/antag_setup
	var/mob/living/carbon/human/user
	var/list/stats = list()
	var/list/defaults = list()
	var/chosen_trait
	var/budget = 12
	var/static/list/stat_keys = list(STATKEY_STR, STATKEY_PER, STATKEY_INT, STATKEY_CON, STATKEY_WIL, STATKEY_SPD)

/datum/antag_setup/New(mob/living/carbon/human/H)
	user = H
	H.antag_setup = src
	var/waited = 0
	while(!H.advjob)
		sleep(1 SECONDS)
		waited += 1 SECONDS
		if(QDELETED(H) || waited > 60 SECONDS)
			qdel(src)
			return
	for(var/key in stat_keys)
		stats[key] = H.get_stat_level(key)
		defaults[key] = stats[key]
	open_menu()

/datum/antag_setup/proc/statweight(key)
	if(key == STATKEY_STR || key == STATKEY_SPD)
		return 2
	return 1

/datum/antag_setup/proc/statspent()
	. = 0
	for(var/key in stat_keys)
		. += (stats[key] - 10) * statweight(key)

/datum/antag_setup/proc/open_menu()
	var/contents = "Points remaining: [budget - statspent()]</center><BR>"
	contents += "--------------<BR>"
	for(var/key in stat_keys)
		contents += "<b>[capitalize(key)]</b> ([statweight(key)]x): [stats[key]] "
		contents += "<a href='?src=[REF(src)];raise=[key]'>\[+\]</a> "
		contents += "<a href='?src=[REF(src)];lower=[key]'>\[-\]</a><BR>"
	contents += "--------------<BR>"
	contents += "<b>Choose a trait:</b><BR>"
	contents += "<a href='?src=[REF(src)];trait=dodge'>Dodge Expert</a><BR>"
	contents += "<a href='?src=[REF(src)];trait=heavy'>Heavy Armor</a><BR>"
	contents += "Chosen: [chosen_trait]<BR>"
	contents += "--------------<BR>"
	contents += "<center><a href='?src=[REF(src)];confirm=1'>\[CONFIRM\]</a></center>"
	var/datum/browser/popup = new(user, "antagsetup", "Take Up Arms", 300, 420)
	popup.set_content(contents)
	popup.open(FALSE)

/datum/antag_setup/Topic(href, href_list)
	if(usr != user)
		return
	if(href_list["raise"])
		var/key = href_list["raise"]
		if(stats[key] < 20 && (budget - statspent()) >= statweight(key))
			stats[key] += 1
		open_menu()
	if(href_list["lower"])
		var/key = href_list["lower"]
		if(stats[key] > defaults[key])
			stats[key] -= 1
		open_menu()
	if(href_list["trait"])
		if(href_list["trait"] == "dodge")
			chosen_trait = TRAIT_DODGEEXPERT
		if(href_list["trait"] == "heavy")
			chosen_trait = TRAIT_HEAVYARMOR
		open_menu()
	if(href_list["confirm"])
		if(!chosen_trait)
			to_chat(user, span_warning("Choose a trait."))
			return
		for(var/key in stat_keys)
			var/diff = stats[key] - defaults[key]
			if(diff)
				user.change_stat(key, diff)
		ADD_TRAIT(user, chosen_trait, TRAIT_GENERIC)
		user.antag_setup = null
		user << browse(null, "window=antagsetup")
		qdel(src)
