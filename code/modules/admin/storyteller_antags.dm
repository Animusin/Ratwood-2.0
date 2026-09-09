/// Add single-use exemptions without changing the weight of ordinary antagonists.
/datum/controller/subsystem/gamemode/proc/admin_add_minor_slots(mob/user)
	if(!check_rights_for(user?.client, R_ADMIN) || !SSticker.HasRoundStarted() || antagonists_disabled)
		to_chat(user, span_warning("Minor slots can only be added during a round with antagonists enabled."))
		return
	var/list/jobs = list()
	for(var/datum/job/job as anything in SSjob.occupations)
		if(job.admin_slot_antag_type)
			jobs[job.title] = job
	var/choice = input(user, "Choose the minor antagonist job:", "Extra Minor Slots") as null|anything in jobs
	if(!choice)
		return
	var/amount = input(user, "How many additional cap-exempt slots (1-100)? These are consumed before normal slots; normal job requirements still apply.", "Extra Minor Slots", 1) as num|null
	if(isnull(amount) || amount < 1 || amount > 100 || !check_rights_for(user?.client, R_ADMIN) || !SSticker.HasRoundStarted() || antagonists_disabled)
		return
	amount = round(amount)
	var/datum/job/job = jobs[choice]
	job.admin_antag_slots += amount
	if(job.total_positions >= 0)
		job.total_positions = max(job.total_positions, job.current_positions) + amount
	log_admin("[key_name(user)] added [amount] cap-exempt [job.title] slots ([job.admin_antag_slots] unclaimed).")
	message_admins("[key_name_admin(user)] added [amount] cap-exempt [job.title] slots ([job.admin_antag_slots] unclaimed).")

/// Only roles with an audited in-place gain path belong here. No job/subclass outfits are run.
/datum/controller/subsystem/gamemode/proc/get_admin_antag_types()
	return list(
		"Bandit" = /datum/antagonist/bandit,
		"Wretch" = /datum/antagonist/wretch,
		"Gnoll (existing gnoll body)" = /datum/antagonist/gnoll,
		"Werewolf" = /datum/antagonist/werewolf,
		"Lesser Werewolf" = /datum/antagonist/werewolf/lesser,
		"Vampire - Thinblood" = /datum/antagonist/vampire/thinblood,
		"Vampire - Neonate" = /datum/antagonist/vampire/licker,
		"Vampire - Methuselah" = /datum/antagonist/vampire/lord,
		"Lich" = /datum/antagonist/lich,
	)

/datum/controller/subsystem/gamemode/proc/can_receive_admin_antag(mob/living/carbon/human/target, datum/antagonist/antag)
	if(!istype(target) || QDELETED(target) || target.stat == DEAD || !target.client || QDELETED(target.mind) || target.mind.current != target)
		return FALSE
	if(QDELETED(antag) || !antag.can_be_owned(target.mind) || antag.is_banned(target))
		return FALSE
	if(istype(antag, /datum/antagonist/wretch) && is_banned_from(target.ckey, "Wretch"))
		return FALSE
	// Do not overwrite another antagonist's special role or stack incompatible transformations.
	for(var/datum/antagonist/existing as anything in target.mind.antag_datums)
		if(!(existing.antag_flags & FLAG_FAKE_ANTAG))
			return FALSE
	if(istype(antag, /datum/antagonist/werewolf) && !target.can_werewolf())
		return FALSE
	if(istype(antag, /datum/antagonist/gnoll) && !is_species(target, /datum/species/gnoll))
		return FALSE
	return TRUE

/datum/controller/subsystem/gamemode/proc/admin_offer_antag(mob/user)
	if(!check_rights_for(user?.client, R_ADMIN) || !SSticker.HasRoundStarted() || antagonists_disabled)
		to_chat(user, span_warning("Roles can only be offered during a round with antagonists enabled."))
		return
	var/target_ckey = ckey(input(user, "Enter the connected player's ckey:", "Offer Antagonist") as text|null)
	if(!target_ckey)
		return
	var/client/target_client = GLOB.directory[target_ckey]
	var/mob/living/carbon/human/target = target_client?.mob
	if(!istype(target) || !target.mind || target.stat == DEAD)
		to_chat(user, span_warning("That ckey must control a living human character."))
		return
	var/datum/mind/target_mind = target.mind
	var/list/types = get_admin_antag_types()
	var/choice = input(user, "Choose the role to offer. Existing skills, equipment, job and location are retained; role powers and traits are added.", "Offer Antagonist") as null|anything in types
	if(!choice)
		return
	var/antag_type = types[choice]
	var/datum/antagonist/antag = new antag_type
	if(!check_rights_for(user?.client, R_ADMIN) || !can_receive_admin_antag(target, antag) || target.client != target_client || target.mind != target_mind || pending_admin_antags[target_mind] || target_mind.picking)
		to_chat(user, span_warning("The character is unavailable, incompatible, banned, or already has a pending antagonist offer."))
		qdel(antag)
		return
	var/cap_exempt = antag_type in list(/datum/antagonist/bandit, /datum/antagonist/wretch, /datum/antagonist/gnoll)
	antag.preserve_character = TRUE
	antag.requires_confirmation = FALSE // Consent is obtained before any on_gain effects.
	if(cap_exempt)
		antag.antag_flags |= FLAG_ANTAG_CAP_IGNORE
	pending_admin_antags[target_mind] = antag
	target_mind.picking = TRUE
	log_admin("[key_name(user)] offered [choice] to [target_ckey] (cap-exempt: [cap_exempt]).")
	var/response = tgui_input_list(target, "An administrator offers your current character the [choice] antagonist role. Your existing skills, equipment, job and location will be kept. Role powers, objectives, appearance and patron may change. Do you accept?", "Antagonist Offer", list("Decline", "Accept"), default = "Decline", timeout = 30 SECONDS, strict_modern = TRUE)
	// Select a clan before adding the datum; vampire on_gain otherwise opens a blocking dialog
	// halfway through converting the character, after which they may be in another body.
	if(response == "Accept" && istype(antag, /datum/antagonist/vampire) && can_receive_admin_antag(target, antag) && target.client == target_client && target.mind == target_mind)
		var/list/clans = list()
		for(var/datum/clan/clan_type as anything in subtypesof(/datum/clan))
			if(initial(clan_type.selectable_by_vampires))
				clans[initial(clan_type.name)] = clan_type
		var/clan_choice = tgui_input_list(target, "Choose your vampire clan. Cancelling declines the role.", "Vampire Clan", clans, timeout = 30 SECONDS, strict_modern = TRUE)
		if(!clan_choice)
			response = "Decline"
		else
			var/datum/antagonist/vampire/vampire = antag
			vampire.default_clan = clans[clan_choice]
			vampire.clan_selected = TRUE
	pending_admin_antags -= target_mind
	if(!QDELETED(target_mind))
		target_mind.picking = FALSE
	if(response != "Accept")
		log_admin("[target_ckey] declined or timed out on the [choice] offer.")
		message_admins("[target_ckey] declined or timed out on the [choice] offer.")
		qdel(antag)
		return
	// The dialog yields: consent belongs to this exact client, mind and body.
	if(!check_rights_for(user?.client, R_ADMIN) || !SSticker.HasRoundStarted() || antagonists_disabled || !can_receive_admin_antag(target, antag) || target.client != target_client || target.mind != target_mind || target_client.ckey != target_ckey)
		to_chat(user, span_warning("The offer expired because the player, character or admin permissions changed."))
		qdel(antag)
		return
	var/datum/antagonist/granted = target_mind.add_antag_datum(antag)
	if(QDELETED(granted))
		to_chat(user, span_warning("The antagonist role could not be assigned."))
		return
	log_admin("[key_name(user)] assigned [choice] to [target_ckey] with player consent (cap-exempt: [cap_exempt]).")
	message_admins("[key_name_admin(user)] assigned [choice] to [key_name_admin(target)] with player consent (cap-exempt: [cap_exempt]).")
