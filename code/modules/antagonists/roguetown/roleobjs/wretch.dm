/datum/antagonist/wretch
	name = "Wretch"
	roundend_category = "wretches"
	antagpanel_category = "Wretches"
	show_name_in_check_antagonists = FALSE

/datum/antagonist/wretch/get_antag_cap_weight()
	if(SSgamemode?.round_modifier_policy_name == "ratwood")
		return 1
	if(ishuman(owner?.current))
		var/mob/living/carbon/human/wretch = owner.current
		if(!wretch.advjob)
			return 1
		var/datum/advclass/selected_class = SSrole_class_handler.get_advclass_by_name(wretch.advjob)
		if(selected_class)
			return selected_class.wretch_antag_cap_weight
	return 1

/datum/antagonist/wretch/on_gain()
	. = ..()
	if(owner)
		owner.special_role = "Wretch"

/datum/antagonist/wretch/on_removal()
	. = ..()
	if(owner)
		owner.special_role = null
