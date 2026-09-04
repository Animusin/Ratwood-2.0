/datum/component/forensics
	dupe_mode = COMPONENT_DUPE_UNIQUE
	can_transfer = TRUE
	var/list/fingerprints		//assoc print = print
	var/list/hiddenprints		//assoc ckey = realname/gloves/ckey
	var/list/blood_DNA			//assoc dna = bloodtype
	var/list/fibers				//assoc print = print
	/// The most recent mechanical clue left on this atom.
	var/forensic_event_type
	var/forensic_event_time
	var/datum/weakref/forensic_event_culprit
	var/forensic_event_tool
	var/forensic_event_timer

/datum/component/forensics/Destroy(force = FALSE, silent = FALSE)
	deltimer(forensic_event_timer)
	forensic_event_timer = null
	return ..()

/datum/component/forensics/InheritComponent(datum/component/forensics/F, original)		//Use of | and |= being different here is INTENTIONAL.
	fingerprints = fingerprints | F.fingerprints
	hiddenprints = hiddenprints | F.hiddenprints
	blood_DNA = blood_DNA | F.blood_DNA
	fibers = fibers | F.fibers
	check_blood()
	return ..()

/datum/component/forensics/Initialize(new_fingerprints, new_hiddenprints, new_blood_DNA, new_fibers)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	fingerprints = new_fingerprints
	hiddenprints = new_hiddenprints
	blood_DNA = new_blood_DNA
	fibers = new_fibers
	check_blood()

/datum/component/forensics/RegisterWithParent()
	check_blood()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(clean_act))

/datum/component/forensics/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT))

/datum/component/forensics/PostTransfer()
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/forensics/proc/wipe_fingerprints()
	fingerprints = null
	return TRUE

/datum/component/forensics/proc/wipe_hiddenprints()
	return	//no.

/datum/component/forensics/proc/wipe_blood_DNA()
	blood_DNA = null
	if(isitem(parent))
		qdel(parent.GetComponent(/datum/component/decal/blood))
	return TRUE

/datum/component/forensics/proc/wipe_fibers()
	fibers = null
	return TRUE

/// Atomically replaces the mechanical clue while preserving collected trace evidence.
/datum/component/forensics/proc/record_forensic_event(event_type, mob/living/culprit, atom/tool)
	if(!event_type || !isliving(culprit))
		return FALSE
	forensic_event_type = event_type
	forensic_event_time = world.time
	forensic_event_culprit = WEAKREF(culprit)
	forensic_event_tool = tool ? tool.name : null
	add_fingerprint(culprit)
	deltimer(forensic_event_timer)
	forensic_event_timer = addtimer(CALLBACK(src, PROC_REF(expire_forensic_event)), 20 MINUTES, TIMER_STOPPABLE)
	return TRUE

/// Returns a snapshot of the current clue, clearing it first when it has expired.
/datum/component/forensics/proc/read_forensic_event()
	if(!forensic_event_type)
		return
	if(world.time >= forensic_event_time + 20 MINUTES)
		clear_forensic_event()
		return
	return list(
		"type" = forensic_event_type,
		"time" = forensic_event_time,
		"culprit" = forensic_event_culprit,
		"tool" = forensic_event_tool,
	)

/// Clears only the physical/mechanical clue. Cleaning trace evidence is handled separately.
/datum/component/forensics/proc/clear_forensic_event()
	deltimer(forensic_event_timer)
	forensic_event_timer = null
	forensic_event_type = null
	forensic_event_time = null
	forensic_event_culprit = null
	forensic_event_tool = null
	return TRUE

/datum/component/forensics/proc/expire_forensic_event()
	forensic_event_timer = null
	clear_forensic_event()

/datum/component/forensics/proc/clean_act(datum/source, strength)
	if(strength >= CLEAN_STRENGTH_FINGERPRINTS)
		wipe_fingerprints()
	if(strength >= CLEAN_STRENGTH_BLOOD)
		wipe_blood_DNA()
	if(strength >= CLEAN_STRENGTH_FIBERS)
		wipe_fibers()

/datum/component/forensics/proc/add_fingerprint_list(list/_fingerprints)	//list(text)
	if(!length(_fingerprints))
		return
	LAZYINITLIST(fingerprints)
	for(var/i in _fingerprints)	//We use an associative list, make sure we don't just merge a non-associative list into ours.
		fingerprints[i] = i
	return TRUE

/datum/component/forensics/proc/add_fingerprint(mob/living/M, ignoregloves = FALSE)
	if(!isliving(M))
		if(!iscameramob(M))
			return
	add_hiddenprint(M)
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		var/atom/forensic_parent = parent
		forensic_parent.add_fibers(H)
		if(H.gloves) //Check if the gloves (if any) hide fingerprints
			if(!istype(H.gloves, /obj/item/clothing/gloves))
				return
			var/obj/item/clothing/gloves/G = H.gloves
			if(G.transfer_prints)
				ignoregloves = TRUE
			if(!ignoregloves)
				H.gloves.add_fingerprint(H, TRUE) //ignoregloves = 1 to avoid infinite loop.
				return
		if(H.dna)
			var/full_print = md5(H.dna.uni_identity)
			LAZYSET(fingerprints, full_print, full_print)
	return TRUE

/datum/component/forensics/proc/add_fiber_list(list/_fibertext)		//list(text)
	if(!length(_fibertext))
		return
	LAZYINITLIST(fibers)
	for(var/i in _fibertext)	//We use an associative list, make sure we don't just merge a non-associative list into ours.
		fibers[i] = i
	return TRUE

/datum/component/forensics/proc/add_fibers(mob/living/carbon/human/M)
	var/fibertext
	var/item_multiplier = isitem(parent) ? 1.2 : 1
	if(M.wear_armor)
		fibertext = "Material from \a [M.wear_armor]."
		if(prob(10*item_multiplier) && !LAZYACCESS(fibers, fibertext))
			LAZYSET(fibers, fibertext, fibertext)
		if(!(M.wear_armor.body_parts_covered & CHEST))
			if(M.wear_pants)
				fibertext = "Fibers from \a [M.wear_pants]."
				if(prob(12*item_multiplier) && !LAZYACCESS(fibers, fibertext)) //Wearing a suit means less of the uniform exposed.
					LAZYSET(fibers, fibertext, fibertext)
		if(!(M.wear_armor.body_parts_covered & HANDS))
			if(M.gloves)
				fibertext = "Material from a pair of [M.gloves.name]."
				if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fibertext))
					LAZYSET(fibers, fibertext, fibertext)
	else if(M.wear_pants)
		fibertext = "Fibers from \a [M.wear_pants]."
		if(prob(15*item_multiplier) && !LAZYACCESS(fibers, fibertext))
			// "Added fibertext: [fibertext]"
			LAZYSET(fibers, fibertext, fibertext)
		if(M.gloves)
			fibertext = "Material from a pair of [M.gloves.name]."
			if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fibertext))
				LAZYSET(fibers, fibertext, fibertext)
	else if(M.gloves)
		fibertext = "Material from a pair of [M.gloves.name]."
		if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fibertext))
			LAZYSET(fibers, fibertext, fibertext)
	return TRUE

/datum/component/forensics/proc/add_hiddenprint_list(list/_hiddenprints)	//list(ckey = text)
	if(!length(_hiddenprints))
		return
	LAZYINITLIST(hiddenprints)
	for(var/i in _hiddenprints)	//We use an associative list, make sure we don't just merge a non-associative list into ours.
		hiddenprints[i] = _hiddenprints[i]
	return TRUE

/datum/component/forensics/proc/add_hiddenprint(mob/M)
	if(!isliving(M))
		if(!iscameramob(M))
			return
	if(!M.key)
		return
	var/hasgloves = ""
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.gloves)
			hasgloves = "(gloves)"
	var/current_time = time_stamp()
	if(!LAZYACCESS(hiddenprints, M.key))
		LAZYSET(hiddenprints, M.key, "First: [M.real_name]\[[current_time]\][hasgloves]. Ckey: [M.ckey]")
	else
		var/laststamppos = findtext(LAZYACCESS(hiddenprints, M.key), " Last: ")
		if(laststamppos)
			LAZYSET(hiddenprints, M.key, copytext(hiddenprints[M.key], 1, laststamppos))
		hiddenprints[M.key] += " Last: [M.real_name]\[[current_time]\][hasgloves]. Ckey: [M.ckey]"	//made sure to be existing by if(!LAZYACCESS);else
	var/atom/A = parent
	A.fingerprintslast = M.ckey
	return TRUE

/datum/component/forensics/proc/add_blood_DNA(list/dna)		//list(dna_enzymes = type)
	if(!length(dna))
		return
	LAZYINITLIST(blood_DNA)
	for(var/i in dna)
		blood_DNA[i] = dna[i]
	check_blood()
	return TRUE

/datum/component/forensics/proc/check_blood()
	if(!isitem(parent))
		return
	if(!length(blood_DNA))
		return
	parent.LoadComponent(/datum/component/decal/blood)
