/turf
	///Default probatility of leaving a track when entering this turf
	var/track_prob = 0

//Base probabilities to leave a track.
/turf/open/floor/rogue/dirt
	track_prob = 10

/turf/open/floor/rogue/grass
	track_prob = 10

/turf/open/floor/rogue/grassyel
	track_prob = 10

/turf/open/floor/rogue/grassred
	track_prob = 10

/turf/open/floor/rogue/grasscold
	track_prob = 10

/turf/open/floor/rogue/snow
	track_prob = 20

/turf/open/floor/rogue/AzureSand
	track_prob = 20

/turf/open/floor/rogue/snowrough
	track_prob = 10

/turf/open/floor/carpet
	track_prob = 10

/turf/open/floor/rogue/wood
	track_prob = 5

/turf/open/floor/rogue/dirt/road
	track_prob = 10

/turf/open/floor/rogue/concrete
	track_prob = 5

/turf/open/floor/rogue/rooftop
	track_prob = 10

/turf/open/floor/rogue/cobble
	track_prob = 3

/turf/open/floor/rogue/blocks
	track_prob = 10

/turf/open/floor/rogue/tile/bath
	track_prob = 20

/turf/open/floor/rogue/tile
	track_prob = 10

/turf/open/floor/rogue/hexstone
	track_prob = 10

/turf/open/floor/rogue/churchmarble
	track_prob = 5

/turf/open/floor/rogue/churchbrick
	track_prob = 5

/turf/open/floor/rogue/cobblerock
	track_prob = 10

//Probabilities end (albeit mud is handled seperately).

//For active investigation targets
/mob/living
	/// Weak references to investigators currently tracking this mob.
	var/list/tracking_hunters

/mob/living/carbon/human
	var/mob/living/current_mark
	var/datum/tracking_link/tracking_target_link
	var/list/tracking_only_known_tracks
	var/list/tracking_clue_markers

/// Lower-skilled trackers use the same perception-driven discovery model as ordinary tracks.
/mob/living/carbon/human/proc/can_discover_tracking_clue(atom/evidence)
	var/tracking_skill = get_skill_level(/datum/skill/misc/tracking)
	if(tracking_skill >= SKILL_LEVEL_EXPERT || HAS_TRAIT(src, TRAIT_PERFECT_TRACKER))
		return TRUE
	var/diff = 11
	var/list/event = evidence.read_forensic_event()
	if(length(event))
		diff += round((world.time - event["time"]) / (60 SECONDS), 1)
	diff += rand(0, 5)
	var/competence = STAPER + (2 * tracking_skill)
	if(competence >= diff)
		return TRUE
	if(diff - competence < 5)
		return prob(100 - ((diff - competence) * 20))
	return FALSE

/// A successful area investigation reveals the existing clue icon without overloading the evidence's right-click action.
/mob/living/carbon/human/proc/discover_tracking_clue(atom/evidence, search_range = 7)
	if(!client || cmode)
		return FALSE
	if(!evidence || get_dist(src, evidence) > search_range || !can_see(src, evidence, search_range))
		return FALSE
	var/is_blood_clue = FALSE
	if(isturf(evidence))
		var/turf/evidence_turf = evidence
		for(var/obj/effect/decal/cleanable/blood/blood in evidence_turf)
			if(length(blood.return_blood_DNA()))
				is_blood_clue = TRUE
				break
	else if(!length(evidence.read_forensic_event()))
		var/is_door_or_window = istype(evidence, /obj/structure/mineral_door) || istype(evidence, /obj/structure/roguewindow)
		if(!is_door_or_window || (!length(evidence.return_fibers()) && !length(evidence.return_blood_DNA())))
			return FALSE
	if(isturf(evidence) && !is_blood_clue)
		return FALSE
	for(var/obj/effect/tracking_clue_marker/marker as anything in tracking_clue_markers?.Copy())
		if(!marker || QDELETED(marker))
			tracking_clue_markers -= marker
			continue
		if(marker.matches(evidence, is_blood_clue))
			marker.refresh_lifetime()
			return 1
	if(!can_discover_tracking_clue(evidence))
		return FALSE
	new /obj/effect/tracking_clue_marker(get_turf(evidence), src, evidence, is_blood_clue)
	return 2

/// Combat mode removes both the private image and its click-catching marker.
/mob/living/carbon/human/proc/clear_tracking_clue_markers()
	for(var/obj/effect/tracking_clue_marker/marker as anything in tracking_clue_markers?.Copy())
		if(marker && !QDELETED(marker))
			qdel(marker)
	tracking_clue_markers = null

/obj/effect/tracking_clue_marker
	name = "clue"
	desc = "Right-click to investigate this clue."
	icon = 'modular_hearthstone/icons/obj/effects/track.dmi'
	icon_state = "tracks_structure"
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	var/datum/weakref/investigator_ref
	var/datum/weakref/evidence_ref
	var/is_blood_clue = FALSE
	var/list/private_images
	var/list/linked_blood_decals
	var/lifetime_timer

/obj/effect/tracking_clue_marker/Initialize(mapload, mob/living/carbon/human/investigator, atom/evidence, blood_clue = FALSE)
	. = ..()
	if(!investigator?.client || !evidence)
		return INITIALIZE_HINT_QDEL
	investigator_ref = WEAKREF(investigator)
	evidence_ref = WEAKREF(evidence)
	is_blood_clue = blood_clue
	if(!refresh_private_images())
		return INITIALIZE_HINT_QDEL
	LAZYADD(investigator.tracking_clue_markers, src)
	RegisterSignal(investigator, COMSIG_PARENT_QDELETING, PROC_REF(linked_atom_deleted))
	RegisterSignal(evidence, COMSIG_PARENT_QDELETING, PROC_REF(linked_atom_deleted))
	refresh_lifetime(FALSE)

/obj/effect/tracking_clue_marker/Destroy(force)
	deltimer(lifetime_timer)
	lifetime_timer = null
	var/mob/living/carbon/human/investigator = investigator_ref?.resolve()
	var/atom/evidence = evidence_ref?.resolve()
	if(investigator)
		UnregisterSignal(investigator, COMSIG_PARENT_QDELETING)
		investigator.client?.images -= private_images
		investigator.tracking_clue_markers -= src
		UNSETEMPTY(investigator.tracking_clue_markers)
	if(evidence)
		UnregisterSignal(evidence, COMSIG_PARENT_QDELETING)
	clear_linked_blood_decals()
	private_images = null
	investigator_ref = null
	evidence_ref = null
	return ..()

/// Replaces the large blood question mark with clickable, investigator-only outlines of the stains themselves.
/obj/effect/tracking_clue_marker/proc/refresh_private_images()
	var/mob/living/carbon/human/investigator = investigator_ref?.resolve()
	var/atom/evidence = evidence_ref?.resolve()
	if(!investigator?.client || !evidence)
		return FALSE
	investigator.client.images -= private_images
	private_images = list()
	clear_linked_blood_decals()
	if(is_blood_clue && isturf(evidence))
		var/turf/evidence_turf = evidence
		for(var/obj/effect/decal/cleanable/blood/blood in evidence_turf)
			if(QDELETED(blood) || !length(blood.return_blood_DNA()))
				continue
			var/image/blood_image = image(loc = src)
			blood_image.appearance = blood.appearance
			blood_image.loc = src
			blood_image.layer = ABOVE_OPEN_TURF_LAYER
			blood_image.invisibility = 0
			blood_image.mouse_opacity = MOUSE_OPACITY_ICON
			blood_image.filters += filter(type = "outline", color = "#ff0000", size = 1)
			private_images += blood_image
			LAZYADD(linked_blood_decals, blood)
			RegisterSignal(blood, COMSIG_PARENT_QDELETING, PROC_REF(linked_blood_deleted))
	else
		var/image/structure_image = image(icon = icon, loc = src, icon_state = icon_state, layer = ABOVE_MOB_LAYER)
		structure_image.invisibility = 0
		structure_image.mouse_opacity = MOUSE_OPACITY_OPAQUE
		structure_image.pixel_y = 16
		private_images += structure_image
	if(!length(private_images))
		return FALSE
	investigator.client.images += private_images
	return TRUE

/obj/effect/tracking_clue_marker/proc/clear_linked_blood_decals()
	for(var/obj/effect/decal/cleanable/blood/blood as anything in linked_blood_decals)
		if(blood && !QDELETED(blood))
			UnregisterSignal(blood, COMSIG_PARENT_QDELETING)
	linked_blood_decals = null

/obj/effect/tracking_clue_marker/proc/linked_blood_deleted(datum/source)
	SIGNAL_HANDLER
	linked_blood_decals -= source
	addtimer(CALLBACK(src, PROC_REF(refresh_after_blood_deleted)), 0, TIMER_UNIQUE)

/obj/effect/tracking_clue_marker/proc/refresh_after_blood_deleted()
	if(QDELETED(src))
		return
	if(!refresh_private_images())
		qdel(src)

/obj/effect/tracking_clue_marker/proc/linked_atom_deleted()
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/tracking_clue_marker/proc/matches(atom/evidence, blood_clue)
	return evidence_ref?.resolve() == evidence && is_blood_clue == blood_clue

/obj/effect/tracking_clue_marker/proc/refresh_lifetime(refresh_visuals = TRUE)
	if(refresh_visuals && is_blood_clue && !refresh_private_images())
		qdel(src)
		return
	deltimer(lifetime_timer)
	lifetime_timer = addtimer(CALLBACK(src, PROC_REF(expire)), 1 MINUTES, TIMER_STOPPABLE)

/obj/effect/tracking_clue_marker/proc/expire()
	lifetime_timer = null
	qdel(src)

/obj/effect/tracking_clue_marker/attack_right(mob/user)
	var/mob/living/carbon/human/investigator = investigator_ref?.resolve()
	var/atom/evidence = evidence_ref?.resolve()
	if(user != investigator || !evidence)
		return
	if(investigator.cmode)
		qdel(src)
		return
	if(!investigator.Adjacent(evidence))
		to_chat(investigator, span_warning("I need to get closer to examine this clue."))
		return
	if(is_blood_clue)
		var/covered
		if(investigator.is_mouth_covered(head_only = 1))
			covered = "headgear"
		else if(investigator.is_mouth_covered(mask_only = 1))
			covered = "mask"
		if(covered)
			to_chat(investigator, span_warning("I have to remove my [covered] first!"))
			return
	if(investigator.m_intent != MOVE_INTENT_SNEAK)
		if(is_blood_clue)
			investigator.visible_message(
				span_info("[investigator] tastes the blood, searching for a trail."),
				span_info("I taste the blood, searching for a trail."),
			)
		else if(istype(evidence, /obj/structure/mineral_door))
			investigator.visible_message(
				span_info("[investigator] rummages around [evidence], searching for signs of tampering."),
				span_info("I rummage around [evidence], searching for signs of tampering."),
			)
		else
			investigator.visible_message(
				span_info("[investigator] searches [evidence] for traces."),
				span_info("I search [evidence] for traces."),
			)
	if(!do_after(investigator, 1.5 SECONDS, target = evidence))
		return
	if(QDELETED(src) || investigator.cmode)
		return
	if(evidence_ref?.resolve() != evidence || !investigator.Adjacent(evidence))
		return
	var/success = FALSE
	if(is_blood_clue && isturf(evidence))
		success = investigator.analyze_blood_on_turf(evidence)
	else
		success = evidence.analyze_forensic_event(investigator)
	if(!success)
		to_chat(investigator, span_warning("The clue is no longer readable."))
	qdel(src)

/obj/effect/tracking_clue_marker/attack_hand(mob/living/user)
	return TRUE

/obj/effect/tracking_clue_marker/attacked_by(obj/item/I, mob/living/user)
	return TRUE

/// Owns the target deletion signal so Tracking cannot overwrite a mob's unrelated subscriptions.
/datum/tracking_link
	var/datum/weakref/hunter_ref
	var/datum/weakref/target_ref

/datum/tracking_link/New(mob/living/carbon/human/hunter, mob/living/target)
	..()
	hunter_ref = WEAKREF(hunter)
	target_ref = WEAKREF(target)
	RegisterSignal(target, COMSIG_PARENT_QDELETING, PROC_REF(target_deleted))

/datum/tracking_link/Destroy(force)
	var/mob/living/target = target_ref?.resolve()
	if(target)
		UnregisterSignal(target, COMSIG_PARENT_QDELETING)
	hunter_ref = null
	target_ref = null
	return ..()

/datum/tracking_link/proc/target_deleted()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/hunter = hunter_ref?.resolve()
	if(hunter?.tracking_target_link == src)
		hunter.set_tracking_mark(null)

/mob/living/proc/add_tracking_hunter(mob/living/carbon/human/hunter)
	LAZYOR(tracking_hunters, WEAKREF(hunter))

/mob/living/proc/remove_tracking_hunter(mob/living/carbon/human/hunter)
	if(!tracking_hunters)
		return
	tracking_hunters -= WEAKREF(hunter)
	UNSETEMPTY(tracking_hunters)

/mob/living/proc/is_being_tracked()
	if(!length(tracking_hunters))
		return FALSE
	for(var/datum/weakref/hunter_ref as anything in tracking_hunters.Copy())
		var/mob/living/carbon/human/hunter = hunter_ref.resolve()
		if(!hunter || hunter.current_mark != src)
			tracking_hunters -= hunter_ref
	UNSETEMPTY(tracking_hunters)
	return length(tracking_hunters)

/mob/living/proc/is_tracking_mark(mob/living/possible_mark)
	return FALSE

/mob/living/carbon/human/is_tracking_mark(mob/living/possible_mark)
	return current_mark && current_mark == possible_mark

/// The only supported way to change an investigator's active Tracking target.
/mob/living/carbon/human/proc/set_tracking_mark(mob/living/new_mark)
	if(new_mark == src)
		new_mark = null
	if(current_mark == new_mark)
		return FALSE
	var/mob/living/old_mark = current_mark
	if(old_mark)
		old_mark.remove_tracking_hunter(src)
	conceal_tracking_only_traces()
	QDEL_NULL(tracking_target_link)
	current_mark = null
	if(new_mark && !QDELETED(new_mark))
		current_mark = new_mark
		new_mark.add_tracking_hunter(src)
		tracking_target_link = new(src, new_mark)
	return TRUE

/// Deliberately washing through a right-click wash action clears the one remembered quarry.
/mob/living/carbon/human/proc/forget_tracking_quarry_after_wash()
	if(!current_mark)
		return FALSE
	set_tracking_mark(null)
	to_chat(src, span_notice("As I wash, the trail fades from my thoughts."))
	return TRUE

/mob/living/carbon/human/proc/conceal_tracking_only_traces()
	for(var/obj/effect/track/track as anything in tracking_only_known_tracks?.Copy())
		if(!track || QDELETED(track))
			tracking_only_known_tracks -= track
			continue
		if(track.only_visible_while_tracking && (src in track.known_by))
			track.remove_knower(src)
	UNSETEMPTY(tracking_only_known_tracks)

/// Reveals and briefly marks nearby ordinary tracks belonging to the active target.
/mob/living/carbon/human/proc/reveal_tracking_traces(search_range = 10, include_blood = FALSE)
	var/mob/living/mark = current_mark
	if(!mark)
		return
	for(var/obj/effect/track/track in range(search_range, src))
		if(track.type != /obj/effect/track || track.creator != mark)
			continue
		if(!can_see(src, track, search_range))
			continue
		if(!(src in track.known_by))
			if(!track.check_reveal(src))
				continue
			track.handle_revealing(src)
		found_ping(get_turf(track), client, "hidden")
	if(!include_blood || !iscarbon(mark))
		return
	var/mob/living/carbon/carbon_mark = mark
	var/mark_dna = carbon_mark.dna?.unique_enzymes
	if(!mark_dna)
		return
	for(var/obj/effect/decal/cleanable/blood/blood in range(search_range, src))
		if(can_see(src, blood, search_range) && (mark_dna in blood.return_blood_DNA()))
			tracking_blood_outline(blood, src)

/// Reads the physical clue selected through a private investigation marker.
/atom/proc/analyze_forensic_event(mob/living/user)
	if(!ishuman(user))
		return FALSE
	var/tracking_skill = user.get_skill_level(/datum/skill/misc/tracking)
	var/list/event = read_forensic_event()
	var/list/found_fibers = return_fibers()
	var/list/found_blood = return_blood_DNA()
	if(!length(event) && !length(found_fibers) && !length(found_blood))
		return FALSE
	if(tracking_skill < SKILL_LEVEL_JOURNEYMAN)
		if(length(event))
			to_chat(user, span_notice("Tracking suggests that [src] was disturbed, but I cannot read the details."))
		else
			to_chat(user, span_notice("I notice residual traces on [src], but I cannot interpret them."))
		return TRUE
	if(length(event))
		var/event_name = forensic_event_display_name(event["type"])
		var/age = world.time - event["time"]
		var/age_text = "old"
		if(age <= 2 MINUTES)
			age_text = "fresh"
		else if(age <= 7 MINUTES)
			age_text = "recent"
		if(tracking_skill >= SKILL_LEVEL_EXPERT)
			var/tool_text = event["tool"] ? html_encode(event["tool"]) : "an unknown implement"
			if(tracking_skill >= SKILL_LEVEL_MASTER)
				var/exact_age = age < 1 MINUTES ? "[round(age / (1 SECONDS), 0.1)] seconds" : "[round(age / (1 MINUTES), 0.1)] minutes"
				to_chat(user, span_notice("Tracking reveals [event_name], made with [tool_text], [exact_age] ago."))
			else
				to_chat(user, span_notice("Tracking reveals [event_name], made with [tool_text]. The clue is [age_text]."))
		else
			to_chat(user, span_notice("Tracking reveals [event_name]. The clue is [age_text]."))
	else
		to_chat(user, span_notice("I find no readable mechanical event, only residual traces."))
	if(length(found_fibers))
		if(tracking_skill >= SKILL_LEVEL_EXPERT)
			to_chat(user, span_notice("Fibers found on the object:"))
			for(var/fiber in found_fibers)
				to_chat(user, span_info("- [html_encode(fiber)]"))
		else
			to_chat(user, span_notice("I can make out fibers here, but not their exact source."))
	else if(tracking_skill >= SKILL_LEVEL_EXPERT)
		to_chat(user, span_info("No fibers can be distinguished."))
	var/mob/living/blood_target
	if(length(found_blood))
		var/list/blood_owners = list()
		to_chat(user, span_notice("Blood traces found on the object:"))
		for(var/dna_key in found_blood)
			var/list/owners = get_forensic_blood_owners(dna_key)
			blood_owners[dna_key] = owners
			var/mob/living/carbon/first_owner = length(owners) ? owners[1] : null
			var/race = get_forensic_blood_species(dna_key)
			if(!race)
				race = first_owner?.dna?.species?.name ? first_owner.dna.species.name : "unknown race"
			if(tracking_skill >= SKILL_LEVEL_EXPERT)
				to_chat(user, span_info("- Blood type [found_blood[dna_key]]; [race]; freshness unknown."))
			else
				to_chat(user, span_info("- [race]; freshness unknown."))
		if(length(found_blood) == 1)
			var/only_dna = found_blood[1]
			var/list/only_owners = blood_owners[only_dna]
			if(length(only_owners) == 1)
				blood_target = only_owners[1]
	var/mob/living/culprit
	if(length(event))
		var/datum/weakref/culprit_ref = event["culprit"]
		culprit = culprit_ref?.resolve()
	if(tracking_skill < SKILL_LEVEL_EXPERT)
		if(length(event) || length(found_blood))
			to_chat(user, span_warning("I can read where the trail begins, but I need expert Tracking to fix its owner as my quarry."))
		return TRUE
	if(culprit)
		var/mob/living/carbon/human/investigator = user
		investigator.set_tracking_mark(culprit)
		investigator.reveal_tracking_traces(10)
		to_chat(user, span_warning("The clue gives me a trail to follow, but no name."))
	else if(length(event))
		to_chat(user, span_warning("The disturbance left a trail, but its maker is no longer present to follow."))
	else if(!length(event) && blood_target)
		var/mob/living/carbon/human/investigator = user
		investigator.set_tracking_mark(blood_target)
		investigator.reveal_tracking_traces(10, TRUE)
		to_chat(user, span_warning("The single blood trace gives me a quarry, but no name."))
	else if(!length(event) && length(found_blood))
		if(length(found_blood) > 1)
			to_chat(user, span_warning("The blood is mixed; I cannot choose a single quarry."))
		else
			to_chat(user, span_warning("The blood is readable, but it does not resolve to one present owner."))
	return TRUE

/// Tracking blood analysis is initiated from the turf because blood decals ignore the mouse.
/mob/living/carbon/human/proc/analyze_blood_on_turf(turf/target_turf)
	var/tracking_skill = get_skill_level(/datum/skill/misc/tracking)
	var/list/samples = list()
	var/trace_severity = FORENSIC_BLEED_UNKNOWN
	var/overwhelmingly_mixed = FALSE
	for(var/obj/effect/decal/cleanable/blood/blood in target_turf)
		var/list/blood_dna = blood.return_blood_DNA()
		if(!length(blood_dna))
			continue
		tracking_blood_outline(blood, src)
		trace_severity = max(trace_severity, blood.forensic_bleed_severity)
		overwhelmingly_mixed ||= blood.blood_samples_overflow
		for(var/dna_key in blood_dna)
			var/list/sample = samples[dna_key]
			if(!sample)
				sample = list(
					"blood_type" = blood_dna[dna_key],
					"owners" = null,
					"fresh" = FALSE,
					"dry" = FALSE,
				)
				samples[dna_key] = sample
			if(blood.is_dry)
				sample["dry"] = TRUE
			else
				sample["fresh"] = TRUE
	if(!length(samples))
		return FALSE
	if(tracking_skill < SKILL_LEVEL_JOURNEYMAN)
		to_chat(src, span_notice("I can tell these bloodstains form a trail, but I cannot read the details."))
		return TRUE
	to_chat(src, span_notice("I examine the blood traces on this ground."))
	for(var/dna_key in samples)
		var/list/sample = samples[dna_key]
		var/list/owners = get_forensic_blood_owners(dna_key)
		sample["owners"] = owners
		var/mob/living/carbon/first_owner = length(owners) ? owners[1] : null
		var/race = get_forensic_blood_species(dna_key)
		if(!race)
			race = first_owner?.dna?.species?.name ? first_owner.dna.species.name : "unknown race"
		var/state = sample["fresh"] ? (sample["dry"] ? "fresh and dried" : "fresh") : "dried"
		if(tracking_skill >= SKILL_LEVEL_EXPERT)
			to_chat(src, span_info("Blood type [sample["blood_type"]]; [race]; [state]."))
		else
			to_chat(src, span_info("Blood from [race]; [state]."))
	if(tracking_skill >= SKILL_LEVEL_EXPERT && length(samples) == 1 && !overwhelmingly_mixed)
		switch(trace_severity)
			if(FORENSIC_BLEED_MINOR)
				to_chat(src, span_info("The blood loss appears minor."))
			if(FORENSIC_BLEED_SIGNIFICANT)
				to_chat(src, span_warning("The victim was bleeding significantly."))
			if(FORENSIC_BLEED_SEVERE)
				to_chat(src, span_danger("The victim was bleeding heavily."))
	if(overwhelmingly_mixed)
		to_chat(src, span_warning("The blood is too thoroughly mixed to separate."))
		return TRUE
	if(tracking_skill < SKILL_LEVEL_EXPERT)
		if(length(samples) == 1)
			to_chat(src, span_warning("This is one blood trail, but I need expert Tracking to fix its owner as my quarry."))
		else
			to_chat(src, span_warning("The blood is mixed; I cannot choose a single quarry."))
		return TRUE
	if(length(samples) == 1)
		var/only_dna = samples[1]
		var/list/only_sample = samples[only_dna]
		var/list/only_owners = only_sample["owners"]
		if(length(only_owners) == 1)
			var/mob/living/only_owner = only_owners[1]
			set_tracking_mark(only_owner)
			reveal_tracking_traces(10, TRUE)
			to_chat(src, span_warning("This single blood trail gives me one quarry, but no name."))
		else
			to_chat(src, span_warning("The blood is readable, but its owner is no longer present to follow."))
	else
		to_chat(src, span_warning("The blood is mixed; I cannot choose a single quarry."))
	return TRUE

/proc/tracking_blood_outline(obj/effect/decal/cleanable/blood/blood, mob/living/viewer)
	if(!blood || !viewer?.client)
		return
	var/image/highlight = image(icon = blood.icon, loc = blood, icon_state = blood.icon_state, layer = ABOVE_OPEN_TURF_LAYER, dir = blood.dir)
	highlight.overlays = blood.overlays
	highlight.color = blood.color
	highlight.alpha = blood.alpha
	highlight.filters += filter(type = "outline", color = "#ff0000", size = 1)
	highlight.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	flick_overlay(highlight, list(viewer.client), 30)

//Analysis levels depending on skillcheck during reveal.
#define ANALYSIS_TERRIBLE 1
#define ANALYSIS_BAD 2
#define ANALYSIS_DECENT 3
#define ANALYSIS_GOOD 4
#define ANALYSIS_PERFECT 5

/obj/effect/track
	name = "\improper track"
	desc = null
	anchored = TRUE
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	invisibility = INVISIBILITY_MAXIMUM
	icon = 'modular_hearthstone/icons/obj/effects/track.dmi' //This sucks, but too bad!
	///The visible state for those that know this.
	var/real_icon_state = "tracks"
	///The image knowers see.
	var/real_image
	///List of mobs aware of this track.
	var/list/mob/living/known_by = list()
	///When this was created. Adjusts difficulty of locating / analyzing.
	var/creation_time = 0
	///What kind of foot, or footwear, created this.
	var/track_type = "codersock tracks"
	///Like above, except what you get if you are not good.
	var/ambiguous_track_type = "footwear tracks"
	///The way the mob was facing when this was created. Obviously can be messed with if you e.g. walk backwards.
	var/facing = "nowhere"
	///If the depth of the tracks is abnormal, e.g. because of heavy armor.
	var/depth
	///If the creator was moving in a special way, e.g. running / sneaking. Difficult to discern.
	var/special_movement
	///The exact mob that created this. Only used to see if the spotter can notice their own tracks (fairly easy)
	var/mob/living/creator
	///Some things may be easier or harder to track. This adjusts the base difficulty accordingly.
	var/tracking_modifier = 0
	///Tracks how many tracks have been chain-overwritten before this track. Could indicate a commonly passed area.
	var/overwrites = 0
	///The world.time when this track should expire (used by subsystem)
	var/expiry_time
	///A preserved dir for the highlights
	var/original_dir
	///Whether this track allows its owner to be Marked
	var/markable = TRUE
	/// Only the investigators actively tracking creator may reveal this fallback trace.
	var/only_visible_while_tracking = FALSE
	///Base difficulty for noticing these tracks
	var/base_diff = 11

/obj/effect/track/Initialize(mapload)
	. = ..()
	real_image = image(icon, src, real_icon_state, ABOVE_OPEN_TURF_LAYER) //Default image in case manually created.

/obj/effect/track/Destroy(force)
	real_image = null
	for(var/knowing_one as anything in known_by.Copy())
		remove_knower(knowing_one)
	if(creator)
		clear_creator_reference(creator)
	known_by = null
	SStracks.remove_track(src)
	return ..()

/// Resets track state for reuse from pool - called before recycling
/obj/effect/track/proc/soft_reset()
	// Clear all knowers
	for(var/knowing_one as anything in known_by.Copy())
		remove_knower(knowing_one)
	known_by = list()

	// Clear creator reference
	if(creator)
		clear_creator_reference(creator)
	creator = null

	// Reset variables to defaults
	creation_time = 0
	expiry_time = 0
	track_type = "codersock tracks"
	ambiguous_track_type = "footwear tracks"
	facing = "nowhere"
	depth = null
	special_movement = null
	tracking_modifier = 0
	overwrites = 0
	original_dir = null
	markable = TRUE
	only_visible_while_tracking = FALSE

	// Reset image
	real_image = null
	real_icon_state = initial(real_icon_state)

/obj/effect/track/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	to_chat(user, span_info("You start concealing the tracks.."))
	if(!do_after(user, 4 SECONDS, target = src))
		return
	to_chat(user, span_warning("Nobody should be able to follow these tracks anymore.."))
	qdel(src)
	return TRUE

///Handles checks for if a mob can reveal this. Also returns FALSE if already known to mob.
/obj/effect/track/proc/check_reveal(mob/living/user)
	if(user in known_by)
		return FALSE
	if(only_visible_while_tracking && !user.is_tracking_mark(creator))
		return FALSE
	var/success = FALSE
	if(user.is_tracking_mark(creator))
		success = TRUE
	else if(!HAS_TRAIT(user, TRAIT_PERFECT_TRACKER))
		var/diff = base_diff //Base Tracking Difficulty
		diff += tracking_modifier
		diff += round((world.time - creation_time) / (60 SECONDS), 1) //Gets more difficult to spot the older.
		diff += rand(0, 5) //Entropy.

		var/competence = user.STAPER
		if(user.mind)
			competence += 2 * user.get_skill_level(/datum/skill/misc/tracking)

		if(competence >= diff)
			success = TRUE
		else if(diff - competence < 5)
			success = prob((100 - ((diff - competence) * 20)))
	else
		success = TRUE
	if(success && user.mind && creator != user)
		user.mind.add_sleep_experience(/datum/skill/misc/tracking, (user.STAINT*2))
	return success

///Handles revealing the track, including checking how well the tracker can analyze it.
/obj/effect/track/proc/handle_revealing(mob/living/user)
	//Second layer of skill check: How much knowledge you get.
	var/analysis_result = 0
	if(!HAS_TRAIT(user, TRAIT_PERFECT_TRACKER))
		var/diff = 0
		diff += tracking_modifier
		diff += round((world.time - creation_time) / (60 SECONDS), 1)
		var/competence = abs(user.STAPER - 5)
		if(user.mind)
			competence += 5 * user.get_skill_level(/datum/skill/misc/tracking) //Skill is much more relevant for analysis.
		switch(competence - diff)
			if(30 to INFINITY)
				analysis_result = ANALYSIS_PERFECT
			if(20 to 29)
				analysis_result = ANALYSIS_GOOD
			if(10 to 19)
				analysis_result = ANALYSIS_DECENT
			if(0 to 9)
				analysis_result = ANALYSIS_BAD
			if(-INFINITY to 0)
				analysis_result = ANALYSIS_TERRIBLE
	else
		analysis_result = ANALYSIS_PERFECT
	add_knower(user, analysis_result)

//Handles value settings done for a track that need to be done.
/obj/effect/track/proc/handle_creation(mob/living/track_source)
	creator = track_source
	RegisterSignal(track_source, COMSIG_PARENT_QDELETING, PROC_REF(clear_creator_reference), TRUE)
	creation_time = world.time
	track_source.get_track_info(src)
	if(track_source.m_intent == MOVE_INTENT_SNEAK)
		special_movement = "Their creator appears to have been sneaking.."
	else if(track_source.m_intent == MOVE_INTENT_RUN)
		special_movement = "Their creator appears to have been running!"
	switch(track_source.dir)
		if(NORTH)
			facing = "north"
		if(SOUTH)
			facing = "south"
		if(EAST)
			facing = "east"
		if(WEST)
			facing = "west"
		if(NORTHWEST)
			facing = "northwest"
		if(NORTHEAST)
			facing = "northeast"
		if(SOUTHWEST)
			facing = "southwest"
		if(SOUTHEAST)
			facing = "southeast"
	real_image = image(icon, src, real_icon_state, ABOVE_OPEN_TURF_LAYER, track_source.dir) //Recreate image with correct dir.
	original_dir = track_source.dir
	expiry_time = world.time + 20 MINUTES
	SStracks.add_track(src)

///Adds a new person to the list of people who can see this track.
/obj/effect/track/proc/add_knower(mob/living/tracker, competence = 1)
	known_by[tracker] = competence
	if(only_visible_while_tracking && ishuman(tracker))
		var/mob/living/carbon/human/human_tracker = tracker
		LAZYOR(human_tracker.tracking_only_known_tracks, src)
	if(tracker.client)
		tracker.client.images += real_image
	RegisterSignal(tracker, COMSIG_PARENT_QDELETING, PROC_REF(remove_knower), override = TRUE)

///Removes a knower from the known ones. Usually only done when qdeleted.
/obj/effect/track/proc/remove_knower(mob/living/tracker)
	SIGNAL_HANDLER
	UnregisterSignal(tracker, COMSIG_PARENT_QDELETING)
	if(tracker.client)
		tracker.client.images -= real_image
	if(ishuman(tracker))
		var/mob/living/carbon/human/human_tracker = tracker
		human_tracker.tracking_only_known_tracks -= src
		UNSETEMPTY(human_tracker.tracking_only_known_tracks)
	known_by -= tracker
	if(creator == tracker)
		creator = null

///Clears the reference to the creator. Is replaced by the above proc if the creator analyzes it.
/obj/effect/track/proc/clear_creator_reference(mob/living/creator_arg)
	SIGNAL_HANDLER
	UnregisterSignal(creator, COMSIG_PARENT_QDELETING)
	creator = null

///Called when the track's time expires, at which point it becomes indistinguishable (aka, deleted)
/obj/effect/track/proc/track_expire()
	qdel(src)

/obj/effect/track/examine(mob/user)
	. = ..()
	var/knowledge = known_by[user]
	if(!knowledge)
		return //Huh?
	. += knowledge_readout(user, knowledge)

/obj/effect/track/proc/knowledge_readout(mob/user, knowledge)
	if(knowledge >= ANALYSIS_DECENT)
		. += "Looks like some [track_type].<br>"
	else
		. += "Looks like some [ambiguous_track_type].<br>"
	. += "This track leads [facing].<br>"
	if(knowledge > ANALYSIS_DECENT)
		var/timepassed = ((world.time - creation_time) * SSticker.station_time_rate_multiplier)
		var/timetext = ""
		var/realtime = round((world.time - creation_time) / 600, 1)
		if(timepassed >= 36000)
			timetext = "[round(timepassed / 36000)] hour[(round(timepassed / 36000)) == 1 ? "" : "s"]"
		else
			timetext = "[round(timepassed / 600)] minute[(round(timepassed / 600)) == 1 ? "" : "s"]"
		. += "These tracks are about [timetext] old. <i>([realtime] minute[realtime == 1 ? "" : "s"] real-time)</i><br>"
		if(depth)
			. += "These tracks are [depth]!<br>"
	if(knowledge > ANALYSIS_GOOD && special_movement)
		. += "[span_danger("[special_movement]")]<br>"
	if(knowledge > ANALYSIS_TERRIBLE && creator == user)
		. += "[span_nicegreen("These are your own tracks!")]<br>"
	if(knowledge >= ANALYSIS_GOOD)
		if(overwrites > 10)
			. += "[span_warning("There are traces of many older tracks here, too..")]<br>"
		else if(overwrites >= 2)
			. += "[span_warning("There are traces of around [overwrites] older tracks here, too..")]<br>"
		if(ishuman(user))
			var/mob/living/carbon/human/H = user
			if(!isnull(H.current_mark) && H.current_mark == creator)
				. += span_nicegreen("This track belongs to your mark.")
			if(H.get_skill_level(/datum/skill/misc/tracking) >= SKILL_LEVEL_EXPERT)
				. += span_nicegreen("<i><font size = 2>Right-click this track to Mark its owner.</font></i>")
	return .

///Gets special info for a track relative to a mob, such as type and depth. Override if desiring tracking modifier adjustment.
/mob/living/proc/get_track_info(obj/effect/track/this_track)
	var/mob/living/prototype = type
	this_track.track_type = "[initial(prototype.name)] tracks" //Lets not mess with someone naming their mob.
	this_track.ambiguous_track_type = "beast tracks" //Override proc if your mob has weird tracks.

/mob/living/carbon/human/get_track_info(obj/effect/track/this_track)
	if(!(mobility_flags & MOBILITY_STAND)) //Either pulled or crawling.
		this_track.track_type = "drag marks"
	else
		if(shoes && (shoes.body_parts_covered & FEET))
			this_track.track_type = "[shoes.name] tracks"
			this_track.ambiguous_track_type = "footwear tracks"
		else
			this_track.track_type = "[dna.species.name] footprints" //Look, I am not going to track the species of every single leg you do surgical malpractice with, so this will do.
			this_track.ambiguous_track_type = "humanoid footprints"

	var/bonus_weight = 0
	if(wear_armor)
		switch(wear_armor.armor_class)
			if(ARMOR_CLASS_HEAVY)
				bonus_weight += 1
			if(ARMOR_CLASS_MEDIUM)
				bonus_weight += 0.5
	if(wear_shirt)
		switch(wear_shirt.armor_class)
			if(ARMOR_CLASS_HEAVY)
				bonus_weight += 1
			if(ARMOR_CLASS_MEDIUM)
				bonus_weight += 0.5
	switch(bonus_weight)
		if(2 to INFINITY)
			this_track.depth = "very deep"
		if(1 to 2)
			this_track.depth = "deep"
	return //This is needed at the moment.

//Checks if the mob should create a track, and creates one if the case (potentially replacing older tracks on the turf)
/mob/living/proc/check_track_creation(turf/new_turf)
	if(!new_turf)
		return //Guh?
	if(isnull(mind))
		return
	if(!(movement_type & GROUND) || (movement_type & (FLOATING|FLYING))) //For some reason some mobs have both ground and flying at once.
		return
	var/probability = round(track_creation_prob(new_turf) * 1.5, 0.1)
	if(!probability)
		return
	var/tracking_only = FALSE
	if(!prob(probability))
		if(!is_being_tracked() || !prob(min(probability * 1.5, 50)))
			return
		tracking_only = TRUE

	var/list/ordinary_tracks = list()
	var/obj/effect/track/same_track
	var/updated_overwrites = 0
	for(var/obj/effect/track/existing in new_turf)
		if(existing.type != /obj/effect/track)
			continue
		ordinary_tracks += existing
		if(existing.creator == src && existing.only_visible_while_tracking == tracking_only)
			same_track = existing
	if(same_track)
		updated_overwrites = same_track.overwrites + 1
		ordinary_tracks -= same_track
		SStracks.recycle_track(same_track)
	while(length(ordinary_tracks) >= 3)
		var/obj/effect/track/oldest_unprotected
		var/obj/effect/track/oldest_any
		for(var/obj/effect/track/existing as anything in ordinary_tracks)
			if(!oldest_any || existing.creation_time < oldest_any.creation_time)
				oldest_any = existing
			if(existing.only_visible_while_tracking && existing.creator?.is_being_tracked())
				continue
			if(!oldest_unprotected || existing.creation_time < oldest_unprotected.creation_time)
				oldest_unprotected = existing
		var/obj/effect/track/replaced_track = oldest_unprotected ? oldest_unprotected : oldest_any
		ordinary_tracks -= replaced_track
		SStracks.recycle_track(replaced_track)
	var/obj/effect/track/new_track = SStracks.get_track(/obj/effect/track, new_turf)
	new_track.only_visible_while_tracking = tracking_only
	new_track.overwrites = updated_overwrites
	new_track.handle_creation(src)

//Gets the probability of this mob to create a track on the passed turf.
/mob/living/proc/track_creation_prob(turf/new_turf)
	. = new_turf.track_prob
	if(!.)
		return 0
	if(m_intent == MOVE_INTENT_SNEAK)
		var/remaining_mod = 0.7
		if(mind)
			remaining_mod -= 0.1 * get_skill_level(/datum/skill/misc/sneaking)
		. *= remaining_mod
	else if(m_intent == MOVE_INTENT_RUN)
		. *= 3

/mob/living/carbon/human/track_creation_prob(turf/new_turf)
	. = ..()
	if(!.)
		return
	var/bonus_weight = 0
	if(wear_armor)
		switch(wear_armor.armor_class)
			if(ARMOR_CLASS_HEAVY)
				bonus_weight += 0.5
			if(ARMOR_CLASS_MEDIUM)
				bonus_weight += 0.25
			else
	if(wear_shirt)
		switch(wear_shirt.armor_class)
			if(ARMOR_CLASS_HEAVY)
				bonus_weight += 0.5
			if(ARMOR_CLASS_MEDIUM)
				bonus_weight += 0.25
	if(bonus_weight)
		. *= (1 + bonus_weight)

/obj/effect/track/attack_right(mob/user)
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(H.get_skill_level(/datum/skill/misc/tracking) > SKILL_LEVEL_JOURNEYMAN)	//Expert+
			if(!markable)
				to_chat(H, span_warning("This is not enough to Mark them. I need proper tracks."))
				return
			if(H.m_intent == MOVE_INTENT_SNEAK)
				to_chat(H, span_info("You start taking note of the person's gait, weight and other distinct features."))
			else
				H.visible_message(
					span_info("[H] kneels down and searches the ground for tracks."),
					span_info("I start taking note of the person's gait, weight and other distinct features."),
				)
			if(do_after(user, (50 - H.STAPER*2)))
				if(!creator || QDELETED(creator))
					to_chat(H, span_warning("The trail goes cold before I can fix it in my mind."))
					return
				H.set_tracking_mark(creator)
				to_chat(H, span_warning("You've marked this person. You'll notice their tracks if you find any new ones."))
		else
			to_chat(H, span_info("I am not skilled enough for this! (Expert level required)"))

/obj/effect/track/thievescant
	name = "engraved symbols"
	gender = PLURAL
	real_icon_state = "thieves_cant"
	markable = FALSE
	base_diff = 5 //Easier to notice
	var/message

/obj/effect/track/thievescant/soft_reset()
	..()
	message = null
	alpha = initial(alpha)

/obj/effect/track/thievescant/handle_creation(mob/living/track_source, thiefmessage)
	creator = track_source
	RegisterSignal(track_source, COMSIG_PARENT_QDELETING, PROC_REF(clear_creator_reference), override = TRUE)
	creation_time = world.time
	track_source.get_track_info(src)
	real_image = image(icon, src, real_icon_state, BULLET_HOLE_LAYER, track_source.dir)
	alpha = 128
	message = thiefmessage
	// Thieves cant engravings persist much longer - 2 hours
	expiry_time = world.time + 2 HOURS
	SStracks.add_track(src)

/obj/effect/track/thievescant/knowledge_readout(mob/user, knowledge)
	if(!user.has_language(/datum/language/thievescant))
		. += "Looks like a bunch of meaningless engravings..."
	else
		. += "An engraved message left by [creator == user ? "me" : "one of my fellows"]. It reads...<br>"
		. += "<font color = '#0d5381'>\"[message]\"</font>"

	return .

/obj/effect/track/thievescant/attack_right(mob/user)
	to_chat(user,span_info("You can't distinguish an object like this."))
	return

#undef ANALYSIS_TERRIBLE
#undef ANALYSIS_BAD
#undef ANALYSIS_DECENT
#undef ANALYSIS_GOOD
#undef ANALYSIS_PERFECT
