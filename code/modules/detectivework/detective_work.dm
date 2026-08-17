//CONTAINS: Suit fibers and Detective's Scanning Computer

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
	var/datum/component/forensics/D = AddComponent(/datum/component/forensics)
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
	var/datum/component/forensics/D = AddComponent(/datum/component/forensics)
	. = D.add_fingerprint(M, ignoregloves)

/atom/proc/add_fiber_list(list/fibertext)				//ASSOC LIST FIBERTEXT = FIBERTEXT
	if(QDELETED(src))
		return
	if(length(fibertext))
		. = AddComponent(/datum/component/forensics, null, null, null, fibertext)

/atom/proc/add_fibers(mob/living/carbon/human/M)
	var/old = blood_DNA_length()
	if(M.gloves && istype(M.gloves, /obj/item/clothing))
		var/obj/item/clothing/gloves/G = M.gloves
		if(G.transfer_blood > 1) //bloodied gloves transfer blood to touched objects
			if(add_blood_DNA(G.return_blood_DNA()) && blood_DNA_length() > old) //only reduce the blood supply when this atom gained a new sample
				G.transfer_blood--
	else if(M.bloody_hands > 1)
		if(add_blood_DNA(M.return_blood_DNA()) && blood_DNA_length() > old)
			M.bloody_hands--
	var/datum/component/forensics/D = AddComponent(/datum/component/forensics)
	. = D.add_fibers(M)

/atom/proc/add_hiddenprint_list(list/hiddenprints)	//NOTE: THIS IS FOR ADMINISTRATION FINGERPRINTS, YOU MUST CUSTOM SET THIS TO INCLUDE CKEY/REAL NAMES! CHECK FORENSICS.DM
	if(length(hiddenprints))
		. = AddComponent(/datum/component/forensics, null, hiddenprints)

/atom/proc/add_hiddenprint(mob/M)
	if(QDELETED(src))
		return
	var/datum/component/forensics/D = AddComponent(/datum/component/forensics)
	. = D.add_hiddenprint(M)

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
