//CONTAINS: Suit fibers and Detective's Scanning Computer

GLOBAL_LIST_EMPTY(forensic_blood_species)
GLOBAL_LIST_EMPTY(forensic_blood_owner_refs)
GLOBAL_VAR_INIT(active_forensic_blood_decals, 0)
GLOBAL_VAR_INIT(next_forensic_blood_decal_warning, 0)

/// Stores one lightweight identity record per blood source instead of repeating species data on every stain.
/proc/register_forensic_blood_identity(mob/living/source)
	if(!iscarbon(source))
		return
	var/mob/living/carbon/carbon_source = source
	var/dna_key = carbon_source.dna?.unique_enzymes
	if(!dna_key)
		return
	var/species_name = carbon_source.dna?.species?.name
	if(species_name)
		GLOB.forensic_blood_species[dna_key] = "[species_name]"
	var/list/owner_refs = GLOB.forensic_blood_owner_refs[dna_key]
	if(!owner_refs)
		owner_refs = list()
		GLOB.forensic_blood_owner_refs[dna_key] = owner_refs
	owner_refs |= WEAKREF(carbon_source)

/// Resolves every currently present owner sharing a forensic blood identity.
/proc/get_forensic_blood_owners(dna_key)
	var/list/owners = list()
	var/list/owner_refs = GLOB.forensic_blood_owner_refs[dna_key]
	if(!length(owner_refs))
		return owners
	for(var/datum/weakref/owner_ref as anything in owner_refs.Copy())
		var/mob/living/carbon/owner = owner_ref.resolve()
		if(owner)
			owners |= owner
		else
			owner_refs -= owner_ref
	if(!length(owner_refs))
		GLOB.forensic_blood_owner_refs -= dna_key
	return owners

/proc/get_forensic_blood_species(dna_key)
	return GLOB.forensic_blood_species[dna_key]

/atom/proc/return_fingerprints()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(D)
		. = D.fingerprints

/atom/proc/return_hiddenprints()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(D)
		. = D.hiddenprints

/atom/proc/return_blood_DNA()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(D)
		. = D.blood_DNA

/atom/proc/blood_DNA_length()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(D)
		. = length(D.blood_DNA)

/turf/blood_DNA_length()
	var/list/unique_samples = list()
	for(var/obj/effect/decal/cleanable/blood/blood in src)
		var/list/blood_dna = blood.return_blood_DNA()
		for(var/dna_key in blood_dna)
			unique_samples[dna_key] = TRUE
	return length(unique_samples)

/atom/proc/return_fibers()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(D)
		. = D.fibers

/atom/proc/record_forensic_event(event_type, mob/living/culprit, atom/tool)
	if(QDELETED(src) || !event_type || !isliving(culprit))
		return FALSE
	var/datum/component/forensics/D = LoadComponent(/datum/component/forensics)
	return D.record_forensic_event(event_type, culprit, tool)

/atom/proc/read_forensic_event()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	return D?.read_forensic_event()

/atom/proc/clear_forensic_event()
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	return D?.clear_forensic_event()

/proc/forensic_event_display_name(event_type)
	switch(event_type)
		if(FORENSIC_EVENT_LOCKPICK_ATTEMPT)
			return "an attempted lockpick"
		if(FORENSIC_EVENT_LOCKPICK_SUCCESS)
			return "a successful lockpick"
		if(FORENSIC_EVENT_FORCED_BREAK)
			return "forced destruction"
	return "an unknown disturbance"

/atom/proc/add_fingerprint_list(list/fingerprints)		//ASSOC LIST FINGERPRINT = FINGERPRINT
	if(QDELETED(src))
		return
	if(length(fingerprints))
		. = AddComponent(/datum/component/forensics, fingerprints)

//Set ignoregloves to add prints irrespective of the mob having gloves on.
/atom/proc/add_fingerprint(mob/M, ignoregloves = FALSE)
	if(QDELETED(src))
		return
	var/datum/component/forensics/D = LoadComponent(/datum/component/forensics)
	. = D.add_fingerprint(M, ignoregloves)

/atom/proc/add_fiber_list(list/fibertext)				//ASSOC LIST FIBERTEXT = FIBERTEXT
	if(QDELETED(src))
		return
	if(length(fibertext))
		. = AddComponent(/datum/component/forensics, null, null, null, fibertext)

/atom/proc/add_fibers(mob/living/carbon/human/M)
	if(istype(M.gloves, /obj/item/clothing/gloves))
		var/obj/item/clothing/gloves/G = M.gloves
		if(G.transfer_blood > 1) //bloodied gloves transfer blood to touched objects
			var/old = blood_DNA_length()
			if(add_blood_DNA(G.return_blood_DNA()) && blood_DNA_length() > old) //only reduce the blood supply when this atom gained a new sample
				G.transfer_blood--
	else if(M.bloody_hands > 1)
		var/old = blood_DNA_length()
		if(add_blood_DNA(M.return_blood_DNA()) && blood_DNA_length() > old)
			M.bloody_hands--
	var/datum/component/forensics/D = LoadComponent(/datum/component/forensics)
	. = D.add_fibers(M)

/atom/proc/add_hiddenprint_list(list/hiddenprints)	//NOTE: THIS IS FOR ADMINISTRATION FINGERPRINTS, YOU MUST CUSTOM SET THIS TO INCLUDE CKEY/REAL NAMES! CHECK FORENSICS.DM
	if(length(hiddenprints))
		. = AddComponent(/datum/component/forensics, null, hiddenprints)

/atom/proc/add_hiddenprint(mob/M)
	if(QDELETED(src))
		return
	var/datum/component/forensics/D = LoadComponent(/datum/component/forensics)
	. = D.add_hiddenprint(M)

/// Notes a player opening, locking, picking or breaking this for admins' View Forensics. Mobs without a player are skipped.
/// Routine is everyday use (opening, closing, keyed locking, picking up, dropping), kept in its own capped list.
/// only_if_tracked skips atoms no player has handled yet, so mass drops of untouched gear make no component.
/// Evidence also goes to the game log and the player's own log, so it outlives the atom. Routine use is too frequent to log,
/// and so are repeats: an action that folds into the last entry, such as the twentieth hit on a door, is not logged again.
/atom/proc/add_forensic_action(mob/user, action, routine = FALSE, only_if_tracked = FALSE)
	if(!user?.ckey || QDELETED(src))
		return
	var/datum/component/forensics/D = GetComponent(/datum/component/forensics)
	if(!D)
		if(only_if_tracked)
			return
		D = AddComponent(/datum/component/forensics)
	if(D.add_action(user, action, routine) && !routine)
		user.log_message("forensics on [src] ([type]): [action]", LOG_GAME)

/// add_forensic_action() for something no player did, such as a fire, an explosion or a mob without a player. Always evidence.
/atom/proc/add_unattributed_forensic_action(action)
	if(QDELETED(src))
		return
	var/datum/component/forensics/D = AddComponent(/datum/component/forensics)
	if(D.add_action(null, action))
		log_game("forensics on [src] ([type]) at [AREACOORD(src)]: [action]")

/// Notes poison going into or out of food and drink, and drinks spiked on the rim, for admins' View Forensics.
/// transfer_log is what trans_to() moved, reagent type = amount. Only spiking prepends.
/datum/reagents/proc/record_forensic_transfer(atom/target_atom, list/transfer_log, mob/transfered_by, method, prepend)
	if(!transfered_by.ckey)
		return
	var/list/reagent_names = list()
	var/list/poison_names = list()
	for(var/reagent_type in transfer_log)
		// trans_to() logs every reagent even when nothing moved, such as into a full container
		if(!transfer_log[reagent_type])
			continue
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[reagent_type]
		if(!reagent)
			continue
		reagent_names |= reagent.name
		if(reagent.is_poison())
			poison_names |= reagent.name
	var/poisons = english_list(poison_names)
	var/source = my_atom ? format_text("[my_atom]") : "something"

	if(isobj(target_atom))
		if(prepend)
			target_atom.add_forensic_action(transfered_by, "spiked the rim with [english_list(reagent_names)] from [source][length(poison_names) ? ", poisoning it with [poisons]" : ""]")
		else if(length(poison_names))
			target_atom.add_forensic_action(transfered_by, "added poison ([poisons]) from [source]")
		return

	// Consumption is noted on the food or drink, as the victim's mob has no View Forensics.
	if(method != INGEST || !length(poison_names) || !isobj(my_atom) || !ismob(target_atom))
		return
	var/mob/victim = target_atom
	if(victim == transfered_by)
		my_atom.add_forensic_action(transfered_by, "ate or drank poison ([poisons]) from it")
	else
		my_atom.add_forensic_action(transfered_by, "fed poison ([poisons]) from it to [victim.real_name] ([victim.ckey || "no player"])")

/atom/proc/add_blood_DNA(list/dna)						//ASSOC LIST DNA = BLOODTYPE
	return FALSE

/obj/add_blood_DNA(list/dna)
	. = ..()
	if(QDELETED(src))
		return
	if(length(dna))
		. = AddComponent(/datum/component/forensics, null, null, dna)

/obj/item/clothing/gloves/add_blood_DNA(list/blood_dna)
	. = ..()
	transfer_blood = rand(2, 4)

/turf/add_blood_DNA(list/blood_dna)
	var/obj/effect/decal/cleanable/blood/splatter/B = locate() in src
	if(!B)
		B = new /obj/effect/decal/cleanable/blood/splatter(src)
	B.add_blood_DNA(blood_dna) //give blood info to the blood decal.
	return TRUE //we bloodied the floor

/mob/living/carbon/human/add_blood_DNA(list/blood_dna)
	if(dna?.species?.id == "gnoll")
		if(length(blood_dna))
			AddComponent(/datum/component/forensics, null, null, blood_dna)
		bloody_hands = 0
		update_inv_gloves()
		return TRUE

	if(cloak)
		cloak.add_blood_DNA(blood_dna)
		update_inv_cloak()
	else if(wear_armor)
		wear_armor.add_blood_DNA(blood_dna)
		update_inv_armor()
	else if(wear_shirt)
		wear_shirt.add_blood_DNA(blood_dna)
		update_inv_shirt()
	else if(wear_pants)
		wear_pants.add_blood_DNA(blood_dna)
		update_inv_pants()
	if(gloves)
		var/obj/item/clothing/gloves/G = gloves
		G.add_blood_DNA(blood_dna)
	else if(length(blood_dna))
		AddComponent(/datum/component/forensics, null, null, blood_dna)
		bloody_hands = rand(2, 4)
	update_inv_gloves()	//handles bloody hands overlays and updating
	return TRUE

/atom/proc/transfer_fingerprints_to(atom/A)
	A.add_fingerprint_list(return_fingerprints())
	A.add_hiddenprint_list(return_hiddenprints())
	A.fingerprintslast = fingerprintslast
