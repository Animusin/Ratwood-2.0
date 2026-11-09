GLOBAL_LIST_EMPTY(antagonist_teams)

//A barebones antagonist team.
/datum/team
	var/list/datum/mind/members = list()
	var/name = "team"
	var/member_name = "member"
	var/list/objectives = list() //common objectives, these won't be added or removed automatically, subtypes handle this, this is here for bookkeeping purposes.
	var/show_roundend_report = TRUE

/datum/team/New(starting_members)
	. = ..()
	GLOB.antagonist_teams += src
	if(starting_members)
		if(islist(starting_members))
			for(var/datum/mind/M in starting_members)
				add_member(M)
		else
			add_member(starting_members)

/datum/team/Destroy(force, ...)
	GLOB.antagonist_teams -= src
	for(var/datum/mind/member as anything in members)
		UnregisterSignal(member, COMSIG_QDELETING)
	members.Cut()
	. = ..()

/datum/team/proc/is_solo()
	return members.len == 1

/datum/team/proc/add_member(datum/mind/new_member)
	if(QDELETED(new_member) || (new_member in members))
		return
	members |= new_member
	RegisterSignal(new_member, COMSIG_QDELETING, PROC_REF(on_member_deleted))

/datum/team/proc/remove_member(datum/mind/member)
	if(!(member in members))
		return
	members -= member
	UnregisterSignal(member, COMSIG_QDELETING)

/datum/team/proc/on_member_deleted(datum/mind/member)
	SIGNAL_HANDLER
	remove_member(member)

//Display members/victory/failure/objectives for the team
/datum/team/proc/roundend_report()
	if(!show_roundend_report)
		return

	var/list/report = list()

	report += span_header("[name]:")
	report += "The [member_name]s were:"
	report += printplayerlist(members)

	if(objectives.len)
		report += span_header("Team had following objectives:")
		var/win = TRUE
		var/objective_count = 1
		for(var/datum/objective/objective in objectives)
			if(objective.check_completion())
				report += "<B>Objective #[objective_count]</B>: [objective.explanation_text] <span class='greentext'>Success!</span>"
			else
				report += "<B>Objective #[objective_count]</B>: [objective.explanation_text] <span class='redtext'>Fail.</span>"
				win = FALSE
			objective_count++
		if(win)
			report += span_greentext("The [name] was successful!")
		else
			report += span_redtext("The [name] have failed!")
		report += "<br>"


	return "<div class='panel redborder'>[report.Join("<br>")]</div>"
