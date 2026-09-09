/// Add single-use exemptions without changing the weight of ordinary antagonists.
/datum/controller/subsystem/gamemode/proc/admin_add_minor_slots(mob/user)
	if(!check_rights_for(user?.client, R_ADMIN) || !SSticker.IsRoundInProgress())
		to_chat(user, span_warning("Minor slots can only be added during a round."))
		return
	var/list/jobs = list()
	for(var/datum/job/job as anything in SSjob.occupations)
		if(job.admin_slot_antag_type)
			jobs[job.title] = job
	var/choice = input(user, "Choose the minor antagonist job:", "Extra Minor Slots") as null|anything in jobs
	if(!choice)
		return
	var/amount = input(user, "How many additional cap-exempt slots (1-100)? These are consumed before normal slots; normal job requirements still apply.", "Extra Minor Slots", 1) as num|null
	if(isnull(amount) || amount < 1 || amount > 100 || !check_rights_for(user?.client, R_ADMIN) || !SSticker.IsRoundInProgress())
		return
	amount = round(amount)
	var/datum/job/job = jobs[choice]
	job.admin_antag_slots += amount
	if(job.total_positions >= 0)
		job.total_positions = max(job.total_positions, job.current_positions) + amount
	log_admin("[key_name(user)] added [amount] cap-exempt [job.title] slots ([job.admin_antag_slots] unclaimed).")
	message_admins("[key_name_admin(user)] added [amount] cap-exempt [job.title] slots ([job.admin_antag_slots] unclaimed).")

/// Only roles with an audited conversion path belong here. No job/subclass outfits are run.
/datum/controller/subsystem/gamemode/proc/get_admin_antag_types()
	return list(
		"Bandit" = /datum/antagonist/bandit,
		"Wretch" = /datum/antagonist/wretch,
		"Gnoll" = /datum/antagonist/gnoll,
		"Werewolf" = /datum/antagonist/werewolf,
		"Lesser Werewolf" = /datum/antagonist/werewolf/lesser,
		"Vampire - Thinblood" = /datum/antagonist/vampire/thinblood,
		"Vampire - Neonate" = /datum/antagonist/vampire/licker,
		"Vampire - Methuselah" = /datum/antagonist/vampire/lord,
		"Lich" = /datum/antagonist/lich,
	)

/datum/controller/subsystem/gamemode/proc/can_receive_admin_antag(mob/target, datum/antagonist/antag, require_client = TRUE)
	if(QDELETED(target) || (require_client && !target.client) || QDELETED(target.mind) || target.mind.current != target)
		return FALSE
	if(isnewplayer(target))
		var/mob/dead/new_player/lobby = target
		if(lobby.spawning)
			return FALSE
	else if(!ishuman(target) || target.stat == DEAD)
		return FALSE
	if(QDELETED(antag) || !antag.can_be_owned(target.mind) || antag.is_banned(target))
		return FALSE
	if(istype(antag, /datum/antagonist/wretch) && is_banned_from(target.ckey, "Wretch"))
		return FALSE
	// Do not overwrite another antagonist's special role or stack incompatible transformations.
	for(var/datum/antagonist/existing as anything in target.mind.antag_datums)
		if(!(existing.antag_flags & FLAG_FAKE_ANTAG))
			return FALSE
	if(ishuman(target))
		var/mob/living/carbon/human/character = target
		if(istype(antag, /datum/antagonist/werewolf) && !character.can_werewolf())
			return FALSE
		if(istype(antag, /datum/antagonist/gnoll) && !is_species(character, /datum/species/gnoll))
			return FALSE
	return TRUE

/datum/controller/subsystem/gamemode/proc/admin_offer_antag(mob/user)
	if(!check_rights_for(user?.client, R_ADMIN) || SSticker.current_state == GAME_STATE_FINISHED)
		return
	var/target_ckey = ckey(input(user, "Enter the connected player's ckey:", "Offer Antagonist") as text|null)
	if(!target_ckey)
		return
	var/client/target_client = GLOB.directory[target_ckey]
	var/mob/target = target_client?.mob
	if(!target?.mind || (!isnewplayer(target) && (!ishuman(target) || target.stat == DEAD)))
		to_chat(user, span_warning("That ckey must be in the lobby or control a living human character."))
		return
	var/datum/mind/target_mind = target.mind
	if(isnewplayer(target) && !SSticker.IsRoundInProgress())
		to_chat(user, span_warning("Lobby antagonist spawning is available once the round has started."))
		return
	var/list/types = get_admin_antag_types()
	var/choice = input(user, "Choose the role to offer. Lobby players spawn directly as this antagonist and choose its class where applicable. Existing characters keep their job and equipment. Skill ranks never stack.", "Offer Antagonist") as null|anything in types
	if(!choice)
		return
	var/antag_type = types[choice]
	var/datum/antagonist/antag = new antag_type
	if(!check_rights_for(user?.client, R_ADMIN) || !can_receive_admin_antag(target, antag) || target.client != target_client || target.mind != target_mind || pending_admin_antags[target_mind] || target_mind.queued_admin_antag || target_mind.picking)
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
	var/offer_details = isnewplayer(target) ? "Accepting spawns you directly as this antagonist, with its equipment and class selection where applicable. You do not need to join another job first." : "You keep your character, equipment, job and location. Skills use the higher of your existing rank and the role's rank, never their sum."
	var/response = tgui_input_list(target, "An administrator offers you the [choice] antagonist role. [offer_details] Role powers, objectives, appearance and patron may change. Do you accept?", "Antagonist Offer", list("Decline", "Accept"), default = "Decline", timeout = 30 SECONDS, strict_modern = TRUE)
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
	if(!check_rights_for(user?.client, R_ADMIN) || SSticker.current_state == GAME_STATE_FINISHED || !can_receive_admin_antag(target, antag) || target.client != target_client || target.mind != target_mind || target_client.ckey != target_ckey)
		to_chat(user, span_warning("The offer expired because the player, character or admin permissions changed."))
		qdel(antag)
		return
	var/mob/living/carbon/human/character = target
	if(isnewplayer(target))
		if(!spawn_admin_antag(target, antag, user.ckey))
			to_chat(user, span_warning("The antagonist could not be spawned. The player remains in the lobby."))
		return
	if(istype(character) && character.admin_antag_setup_pending)
		target_mind.queue_admin_antag(antag, target_ckey, user.ckey)
		to_chat(target, span_notice("Your [choice] role will apply to this character as soon as you finish the open class selection."))
		log_admin("[key_name(user)] queued [choice] for [target_ckey] with player consent (cap-exempt: [cap_exempt]).")
		message_admins("[key_name_admin(user)] queued [choice] for [target_ckey]'s character after job/class setup, with player consent.")
		return
	var/datum/antagonist/granted = target_mind.add_antag_datum(antag)
	if(QDELETED(granted))
		to_chat(user, span_warning("The antagonist role could not be assigned."))
		return
	log_admin("[key_name(user)] assigned [choice] to [target_ckey] with player consent (cap-exempt: [cap_exempt]).")
	message_admins("[key_name_admin(user)] assigned [choice] to [key_name_admin(target)] with player consent (cap-exempt: [cap_exempt]).")
	to_chat(target, span_notice("Your [choice] antagonist role has been assigned."))

/// Major roles with their own complete outfit do not need an unrelated job or subclass.
/datum/job/roguetown/admin_antagonist
	title = "Antagonist"
	total_positions = 0
	spawn_positions = 0
	outfit = null
	outfit_female = null
	department_flag = WANDERERS
	announce_latejoin = FALSE

/datum/controller/subsystem/gamemode/proc/get_admin_antag_job(datum/antagonist/antag)
	switch(antag.type)
		if(/datum/antagonist/bandit)
			return SSjob.GetJobType(/datum/job/roguetown/bandit)
		if(/datum/antagonist/wretch)
			return SSjob.GetJobType(/datum/job/roguetown/wretch)
		if(/datum/antagonist/gnoll)
			return SSjob.GetJobType(/datum/job/roguetown/gnoll)
		if(/datum/antagonist/lich, /datum/antagonist/vampire/lord)
			return SSjob.GetJobType(/datum/job/roguetown/admin_antagonist)
		if(/datum/antagonist/werewolf, /datum/antagonist/werewolf/lesser, /datum/antagonist/vampire/thinblood, /datum/antagonist/vampire/licker)
			return SSjob.GetJobType(/datum/job/roguetown/adventurer)

/// Explicit, consented admission. It does not open public slots or spend another player's exemption.
/datum/controller/subsystem/gamemode/proc/spawn_admin_antag(mob/dead/new_player/lobby, datum/antagonist/antag, admin_ckey)
	var/datum/job/job = get_admin_antag_job(antag)
	if(!job || !SSticker.IsRoundInProgress() || !can_receive_admin_antag(lobby, antag))
		qdel(antag)
		return FALSE
	if((istype(antag, /datum/antagonist/lich) && !length(GLOB.lich_starts)) || (istype(antag, /datum/antagonist/vampire/lord) && !length(GLOB.vlord_starts)))
		to_chat(lobby, span_warning("This map has no spawn point for that antagonist."))
		qdel(antag)
		return FALSE
	var/client/player = lobby.client
	var/datum/mind/player_mind = lobby.mind
	var/player_ckey = player.ckey
	player_mind.picking = TRUE
	SSrole_class_handler.cancel_class_handler(player_ckey)
	player_mind.assigned_role = job.title // create_character uses this to load gnoll preferences.
	player_mind.admin_slot_antag_type = job.admin_slot_antag_type
	job.current_positions++
	SSjob.unassigned -= lobby
	SSticker.queued_players -= lobby
	var/mob/living/carbon/human/character = lobby.create_character(TRUE)
	if(QDELETED(character))
		player_mind.picking = FALSE
		job.current_positions = max(0, job.current_positions - 1)
		qdel(antag)
		return FALSE
	character.admin_antag_spawn = TRUE
	character.islatejoin = TRUE
	SSjob.EquipRank(character, job.title, TRUE)
	if(!job.override_latejoin_spawn(character))
		SSjob.SendToLateJoin(character)
	SSticker.minds |= player_mind
	GLOB.joined_player_list |= player_ckey
	GLOB.round_join_times[player_ckey] = world.time
	GLOB.respawncounts[player_ckey]++
	player.prefs.lastclass = null
	player.prefs.save_preferences()
	var/has_classes = length(job.advclass_cat_rolls)
	if(!has_classes)
		apply_character_post_equipment(character, player)
		antag.preserve_character = FALSE // Lich/Methuselah spawn with their own complete loadout.
	var/datum/antagonist/granted = player_mind.has_antag_datum(antag.type, FALSE)
	if(granted)
		granted.antag_flags |= antag.antag_flags & FLAG_ANTAG_CAP_IGNORE
		qdel(antag)
	else if(can_receive_admin_antag(character, antag))
		granted = player_mind.add_antag_datum(antag)
	if(QDELETED(granted))
		player_mind.picking = FALSE
		to_chat(character, span_warning("This character is incompatible with the offered role. Returning to the lobby."))
		qdel(antag)
		character.admin_send_back_to_lobby(null, TRUE)
		return FALSE
	player_mind.picking = FALSE
	GLOB.character_list[character.mobid] = "[player_ckey] was [character.real_name] ([granted.name])<BR>"
	GLOB.character_ckey_list[character.real_name] = player_ckey
	log_character("[player_ckey] - [character.real_name] - admin [granted.name] spawn")
	log_admin("[admin_ckey] spawned [player_ckey] as [granted.name] with player consent.")
	message_admins("[admin_ckey] spawned [key_name_admin(character)] as [granted.name] with player consent.")
	to_chat(character, span_notice("You have spawned as [granted.name].[has_classes ? " Choose your class to finish." : ""]"))
	player.update_ooc_verb_visibility()
	if(has_classes)
		SSrole_class_handler.setup_class_handler(character)
	else
		character.finish_admin_antag_setup()
	return TRUE

/datum/mind/proc/queue_admin_antag(datum/antagonist/antag, player_ckey, admin_ckey)
	if(queued_admin_antag || QDELETED(antag) || antag.owner)
		return FALSE
	queued_admin_antag = antag
	queued_admin_antag_ckey = player_ckey
	queued_admin_antag_author = admin_ckey
	return TRUE

/datum/mind/proc/clear_queued_admin_antag()
	QDEL_NULL(queued_admin_antag)
	queued_admin_antag_ckey = null
	queued_admin_antag_author = null

/// Called only after the ordinary job, subclass and preference bonuses have all finished.
/mob/living/carbon/human/proc/finish_admin_antag_setup()
	admin_antag_setup_pending = FALSE
	admin_antag_spawn = FALSE
	mind?.apply_queued_admin_antag()

/datum/mind/proc/apply_queued_admin_antag()
	if(!queued_admin_antag)
		return FALSE
	var/mob/living/carbon/human/character = current
	if(istype(character) && character.admin_antag_setup_pending)
		return FALSE
	var/datum/antagonist/antag = queued_admin_antag
	var/player_ckey = queued_admin_antag_ckey
	var/admin_ckey = queued_admin_antag_author
	// Consume before running any gain effects, even if they yield or trigger another setup hook.
	queued_admin_antag = null
	queued_admin_antag_ckey = null
	queued_admin_antag_author = null
	// Consent is attached to this mind. A disconnect after spawning does not change its owner.
	if(!istype(character) || QDELETED(character) || character.stat == DEAD || character.mind != src || ckey(key) != player_ckey || (character.client && character.client.ckey != player_ckey) || SSticker.current_state == GAME_STATE_FINISHED)
		qdel(antag)
		return FALSE
	var/role_ban = istype(antag, /datum/antagonist/wretch) ? "Wretch" : antag.job_rank
	if(is_banned_from(player_ckey, list(ROLE_SYNDICATE, role_ban)))
		qdel(antag)
		return FALSE
	var/datum/antagonist/existing = has_antag_datum(antag.type, FALSE)
	if(existing)
		// The chosen job may already have granted this exact role. Do not run its on_gain twice.
		existing.antag_flags |= antag.antag_flags & FLAG_ANTAG_CAP_IGNORE
		existing.apply_admin_skill_profile()
		qdel(antag)
	else
		if(!SSgamemode.can_receive_admin_antag(character, antag, require_client = FALSE))
			message_admins("Cancelled [admin_ckey]'s queued [antag.name] offer for [player_ckey]: the spawned character is incompatible or banned.")
			to_chat(character, span_warning("Your reserved antagonist role could not be applied to this character. Contact an administrator."))
			qdel(antag)
			return FALSE
		existing = add_antag_datum(antag)
	if(QDELETED(existing))
		return FALSE
	log_admin("Applied [admin_ckey]'s consented [existing.name] offer to [player_ckey] after character setup.")
	message_admins("Applied [admin_ckey]'s consented [existing.name] offer to [key_name_admin(character)] after character setup.")
	to_chat(character, span_notice("Your [existing.name] antagonist role has been assigned."))
	return TRUE
