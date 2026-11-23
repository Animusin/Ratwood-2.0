// Core cognitive brain datum for LLM-driven NPCs in Ratwood-2.0.
// Full architecture:
//   - Immutable Personality Kernel + Speech DNA (no persona drift)
//   - Emotional State with Inertia & Decay (valence, fear, anger, suspicion, curiosity)
//   - Daily Schedule (dawn/day/dusk/night) + Full Needs & Vices (hunger, thirst, alcohol, smoke, fatigue, greed, intimacy, social)
//   - Natural Speech Pacing Engine (direct replies vs >=10s ambient speech cooldown, anti-spam)
//   - Occasional Quiet Random Thoughts (every ~75-125s when idle, rarely spoken aloud)
//   - 3-Tier Memory (working events -> scored episodic memories -> background reflections) + Shared Town Rumors
//   - Persistent Social Graph integrated with Ratwood's native mind.known_people (trust, fear, respect, attraction, role, notes)
//   - Bribe/Offer Interception, Non-Lethal/Lethal/Archery Combat, Surrender, Sleep/Undress/Redress, Door Etiquette, Multi-Z Nav

// ============================================================================
// Memory & Social Graph Sub-Datums
// ============================================================================

/datum/llm_memory
	var/summary = ""
	var/importance = 5 // 1..10
	var/area_name = ""
	var/created_at = 0
	var/time_label = ""
	var/list/tags = list()

/datum/llm_memory/New(text, imp = 5, area_txt = "", list/mem_tags = null)
	summary = text
	importance = clamp(round(imp), 1, 10)
	area_name = area_txt
	created_at = world.time
	time_label = station_time_timestamp()
	if(islist(mem_tags))
		tags = mem_tags.Copy()

/datum/llm_relationship
	var/entity_id = "" // stable tag like "p1"
	var/datum/weakref/mob_ref
	var/known_name = "незнакомец"
	var/perceived_role = "" // obvious uniform or learned job/title
	var/appearance_hint = ""
	var/examined = FALSE
	var/trust = 0       // -100..+100
	var/fear = 0        // 0..100
	var/respect = 0     // -100..+100
	var/attraction = 0  // -50..+100 (warmth / romantic or personal draw)
	var/interactions = 0
	var/last_seen_at = 0
	var/last_seen_area = ""
	var/list/notes = list()

/datum/llm_relationship/proc/add_note(note_text)
	var/clean = trim(note_text)
	if(!length(clean) || (clean in notes))
		return
	notes += clean
	if(length(notes) > 6)
		notes.Cut(1, 2)

/datum/llm_relationship/proc/describe_attitude()
	var/list/bits = list()
	if(trust >= 50)
		bits += "доверяет"
	else if(trust >= 15)
		bits += "расположен"
	else if(trust <= -50)
		bits += "враждебен"
	else if(trust <= -15)
		bits += "не доверяет"
	else
		bits += "нейтрален"

	if(fear >= 60)
		bits += "сильно боится"
	else if(fear >= 25)
		bits += "опасается"

	if(respect >= 40)
		bits += "уважает"
	else if(respect <= -40)
		bits += "презирает"

	if(attraction >= 50)
		bits += "сильно тянет/симпатия"
	else if(attraction >= 20)
		bits += "привлекателен"
	return jointext(bits, ", ")

// ============================================================================
// Core Reusable LLM Brain Datum
// ============================================================================

/datum/llm_npc_brain
	var/mob/living/carbon/human/owner

	// ---- Layer 1: Immutable Personality Kernel ----
	var/archetype = "Бродяга-завсегдатай"
	var/backstory = ""
	var/values = ""
	var/fears = ""
	var/flaws_and_quirks = ""
	var/secrets = ""
	var/social_standing = "простолюдин"
	var/speech_style = ""
	var/world_lore = ""
	var/language_name = "Russian"

	// ---- Layer 2: Dynamic Emotional State (with inertia & decay) ----
	var/mood_valence = 0    // -100..+100
	var/fear = 5            // 0..100
	var/anger = 0           // 0..100
	var/suspicion = 15      // 0..100
	var/curiosity = 35      // 0..100
	var/current_emotion = "спокойно-настороженный"

	// ---- Layer 2b: Needs, Vices & Desires (0..100) ----
	var/drive_hunger = 25
	var/drive_thirst = 25
	var/drive_alcohol = 30
	var/drive_smoke = 25
	var/drive_fatigue = 15
	var/drive_social = 40
	var/drive_greed = 35
	var/drive_intimacy = 20

	// ---- Layer 3: Hierarchical Goals & Inner Monologue ----
	var/long_term_goal = "Присматриваться к новостям в городе, разжиться монетой, едой или выпивкой и не влипнуть в смертельную передрягу."
	var/current_plan = "Осмотреться вокруг и пообщаться с тем, кто покажется интересным."
	var/last_thought = ""
	var/last_error = ""

	// ---- 3-Tier Memory & Social Graph ----
	var/list/pending_events = list()
	var/list/working_events = list()
	var/list/datum/llm_memory/memories = list()
	var/list/reflections = list()
	var/list/recent_self_speech = list()
	var/memories_since_reflection = 0

	/// Stable entity tracking: mob REF string -> /datum/llm_relationship
	var/list/relationships_by_ref = list()
	/// Reverse lookup: "p1" -> /datum/llm_relationship
	var/list/relationships_by_tag = list()
	var/next_person_tag_num = 1

	/// Per-turn perception lookup tables ("o1" -> WEAKREF(obj), "i1" -> WEAKREF(item))
	var/list/perceived_objects = list()
	var/list/perceived_items = list()
	var/list/last_visible_mob_refs = list()
	var/last_area_name = ""
	var/last_tod = ""
	var/last_health_snapshot = 100
	var/last_examine_report = ""

	// ---- Pending Bribe / Offered Item State ----
	var/datum/weakref/pending_offer_giver_ref
	var/datum/weakref/pending_offer_item_ref
	var/pending_offer_stealthy = FALSE
	var/pending_offer_at = 0

	// ---- Combat, Sleep, Door Etiquette & Body State ----
	var/nonlethal_combat = FALSE
	var/is_sleeping_by_plan = FALSE
	var/datum/weakref/sleep_bed_ref
	var/list/removed_sleep_clothes = list() // list of WEAKREF(/obj/item) dropped by bed before sleep
	var/datum/weakref/last_opened_door_ref  // auto-close door behind self once passed!
	var/last_weapon_used_at = 0

	// ---- Cognitive Scheduling, Speech Pacing & Random Thoughts ----
	var/in_flight = FALSE
	var/reflect_in_flight = FALSE
	var/last_turn_at = 0
	var/last_speech_at = 0
	var/last_ambient_speech_at = 0
	var/last_idle_beat_at = 0
	var/last_random_thought_at = 0
	var/next_random_thought_at = 0
	var/last_drive_tick_at = 0
	var/last_sensor_tick_at = 0
	var/last_micro_life_at = 0
	var/last_latency_ms = 0
	var/turns_completed = 0

	var/wake_at = 0
	var/wake_urgency = 0
	var/wake_reason = ""
	var/wake_was_direct_speech = FALSE
	var/pending_speech_timer = null

	// ---- Active System-1 Multi-Tick Action State Machine ----
	var/active_action = LLM_ACTION_IDLE
	var/datum/weakref/action_target_ref
	var/action_arg = ""
	var/action_started_at = 0
	var/action_timeout_at = 0
	var/action_last_repath_at = 0
	var/action_stuck_strikes = 0
	var/turf/action_last_turf
	var/datum/llm_location_info/action_dest_loc
	var/datum/llm_stair_link/action_active_stair
	var/datum/weakref/action_escort_dest_mob_ref
	var/datum/weakref/action_move_dest_ref
	var/action_stage = 0
	var/last_action_outcome = ""

/datum/llm_npc_brain/New(mob/living/carbon/human/target_owner)
	..()
	owner = target_owner
	last_drive_tick_at = world.time
	last_idle_beat_at = world.time
	last_sensor_tick_at = world.time
	last_micro_life_at = world.time
	last_random_thought_at = world.time
	next_random_thought_at = world.time + rand(LLM_RANDOM_THOUGHT_MIN_INTERVAL, LLM_RANDOM_THOUGHT_MAX_INTERVAL)
	if(!length(world_lore))
		world_lore = llm_get_ratwood_world_lore()
	if(owner)
		last_health_snapshot = owner.health
		var/area/A = get_area(owner)
		if(A)
			last_area_name = trim(A.name)
		last_tod = "[GLOB.tod]"
	SSllm_npc.register_brain(src)

/datum/llm_npc_brain/Destroy()
	cancel_pending_speech()
	SSllm_npc.unregister_brain(src)
	if(owner && owner.llm_brain == src)
		owner.llm_brain = null
	owner = null
	relationships_by_ref.Cut()
	relationships_by_tag.Cut()
	perceived_objects.Cut()
	perceived_items.Cut()
	removed_sleep_clothes.Cut()
	return ..()

// ============================================================================
// Public Sensory Hooks (called from /mob/living/carbon/human guards)
// ============================================================================

/datum/llm_npc_brain/proc/on_hear(atom/movable/speaker, raw_message, message_mode, datum/language/message_language)
	if(!owner || QDELETED(owner) || owner.stat == DEAD)
		return
	if(!speaker || speaker == owner)
		return
	var/clean_msg = llm_clean_text(raw_message, 280)
	if(!length(clean_msg))
		return

	var/speaker_label = "[speaker.name]"
	var/entity_tag = ""
	var/is_direct = FALSE
	var/dist = get_dist(owner, speaker)

	if(isliving(speaker))
		var/mob/living/L = speaker
		var/datum/llm_relationship/rel = get_or_create_relationship(L)
		entity_tag = rel.entity_id
		speaker_label = "[rel.known_name] ([entity_tag])"

		var/lower_msg = llm_lower_ru(clean_msg)
		var/lower_my_name = llm_lower_ru(owner.real_name)
		var/first_word_name = splittext(lower_my_name, " ")[1]
		if(findtext(lower_msg, lower_my_name) || (length_char(first_word_name) >= 3 && findtext(lower_msg, first_word_name)))
			is_direct = TRUE
		else if(dist <= 2)
			is_direct = TRUE
		else if(dist <= 4 && get_dir(L, owner) == L.dir)
			is_direct = TRUE
		else if(length(last_visible_mob_refs) <= 1 && dist <= 5)
			is_direct = TRUE

		// If sleeping peacefully and someone shouts or speaks right next to the bed, wake up!
		if(is_sleeping_by_plan && (is_direct && dist <= 2))
			wake_up_from_sleep("Тебя разбудил голос [rel.known_name].")

		if(owner.stat == CONSCIOUS && !owner.IsSleeping() && dist <= 5 && owner.mode == NPC_AI_IDLE && !owner.IsStandingStill())
			owner.face_atom(L)

	if(owner.stat != CONSCIOUS || owner.IsSleeping())
		return

	var/prefix = (message_mode == MODE_WHISPER || message_mode == MODE_WHISPER_CRIT) ? "ШЕПОТ" : "РЕЧЬ"
	var/addr_hint = is_direct ? " \[к тебе\]" : ""
	push_event("[prefix][addr_hint] [speaker_label] ([dist] тайл.): \"[clean_msg]\"")

	drive_social = max(0, drive_social - 4)
	if(is_direct)
		wake_was_direct_speech = TRUE
		schedule_wake(3, 9, "direct_speech")
	else if(dist <= 5)
		schedule_wake(2, 28, "nearby_speech")
	else
		schedule_wake(1, 55, "distant_speech")

/datum/llm_npc_brain/proc/on_world_message(raw_msg, msg_type)
	if(!owner || QDELETED(owner) || owner.stat != CONSCIOUS || owner.IsSleeping())
		return
	var/clean = llm_clean_text(raw_msg, 220)
	if(!length(clean))
		return
	if(findtext(clean, " говорит, \"") || findtext(clean, " says, \"") || findtext(clean, " шепчет, \"") || findtext(clean, " whispers, \""))
		return
	var/lclean = llm_lower_ru(clean)
	if(findtext(lclean, "выдох") || findtext(lclean, "моргает") || findtext(lclean, "you feel "))
		return
	if(length(pending_events) && findtext(pending_events[length(pending_events)], clean))
		return

	push_event("СОБЫТИЕ: [clean]")

	if(findtext(lclean, "удар") || findtext(lclean, "рубит") || findtext(lclean, "колет") || findtext(lclean, "хватает") || findtext(lclean, "толкает") || findtext(lclean, "attacks") || findtext(lclean, "hits") || findtext(lclean, "grabs") || findtext(lclean, "shoves") || findtext(lclean, "blood") || findtext(lclean, "кров") || findtext(lclean, "draws"))
		adjust_emotions(d_valence = -8, d_fear = 10, d_suspicion = 12)
		schedule_wake(3, 6, "violence_witnessed")
	else
		schedule_wake(1, 35, "world_event")

/datum/llm_npc_brain/proc/on_item_offered(mob/living/carbon/human/giver, obj/item/item_offered, stealthy = FALSE)
	if(!owner || QDELETED(owner) || !giver || !item_offered)
		return
	if(is_sleeping_by_plan)
		wake_up_from_sleep("Тебя растолкали, протягивая предмет.")
	if(owner.stat != CONSCIOUS)
		return

	var/datum/llm_relationship/rel = get_or_create_relationship(giver)
	pending_offer_giver_ref = WEAKREF(giver)
	pending_offer_item_ref = WEAKREF(item_offered)
	pending_offer_stealthy = stealthy
	pending_offer_at = world.time

	var/item_desc = llm_clean_text(item_offered.name, 45)
	if(istype(item_offered, /obj/item/roguecoin))
		var/obj/item/roguecoin/C = item_offered
		item_desc = "[item_desc] ([C.quantity] шт.)"

	var/how = stealthy ? "ТАЙКОМ (похоже на взятку!)" : "открыто"
	owner.face_atom(giver)
	push_event("ПРЕДЛОЖЕНИЕ/ВЗЯТКА: [rel.known_name] ([rel.entity_id]) [how] протягивает тебе «[item_desc]»! Реши: accept_offer (принять) или refuse_offer (отказаться).")
	wake_was_direct_speech = TRUE
	schedule_wake(3, 6, "item_offered")

/datum/llm_npc_brain/proc/on_combat_engaged(mob/living/attacker)
	if(!owner || QDELETED(owner))
		return
	cancel_pending_speech()
	if(is_sleeping_by_plan)
		wake_up_from_sleep("На тебя напали во сне!", skip_dress = TRUE)

	var/attacker_label = "неизвестный"
	var/list/memory_tags = list("бой")
	if(attacker)
		var/datum/llm_relationship/rel = get_or_create_relationship(attacker)
		rel.trust = clamp(rel.trust - 45, -100, 100)
		rel.fear = clamp(rel.fear + 28, 0, 100)
		rel.add_note("Напал на меня в бою!")
		attacker_label = "[rel.known_name] ([rel.entity_id])"
		memory_tags = list(rel.entity_id, "бой", "нападение")

	adjust_emotions(d_valence = -25, d_fear = 32, d_anger = 32, d_suspicion = 25)
	push_event("ОПАСНОСТЬ: На тебя напал [attacker_label]! Ты вступил в бой. Можешь драться (attack_lethal/attack_nonlethal), стрелять (shoot_bow), бежать (flee) или сдаться (surrender), если слишком страшно.")
	add_memory("На меня напал [attacker_label] в районе [last_area_name || "города"].", 9, memory_tags)
	if(active_action != LLM_ACTION_ATTACK_LETHAL && active_action != LLM_ACTION_ATTACK_NONLETHAL && active_action != LLM_ACTION_FLEE && active_action != LLM_ACTION_SURRENDER)
		active_action = nonlethal_combat ? LLM_ACTION_ATTACK_NONLETHAL : LLM_ACTION_ATTACK_LETHAL
		action_target_ref = attacker ? WEAKREF(attacker) : null
	last_weapon_used_at = world.time
	wake_was_direct_speech = TRUE
	schedule_wake(3, 4, "under_attack")

/datum/llm_npc_brain/proc/inject_director_note(note_text)
	var/clean = trim(note_text)
	if(!length(clean))
		return
	push_event("ВНУТРЕННЕЕ ПРЕДЧУВСТВИЕ: [clean]")
	add_memory(clean, 7, list("предчувствие", "слух"))
	schedule_wake(3, 5, "director_note")

// ============================================================================
// Internal Event, Emotion & Memory Helpers
// ============================================================================

/datum/llm_npc_brain/proc/push_event(event_text)
	var/stamped = "\[[station_time_timestamp()]\] [event_text]"
	pending_events += stamped
	if(length(pending_events) > 16)
		pending_events.Cut(1, 2)
	working_events += stamped
	if(length(working_events) > LLM_MAX_WORKING_EVENTS)
		working_events.Cut(1, 2)

/datum/llm_npc_brain/proc/add_memory(summary_text, importance = 5, list/extra_tags = null)
	var/clean = trim(summary_text)
	if(!length(clean))
		return
	var/area/A = owner ? get_area(owner) : null
	var/aname = A ? trim(A.name) : last_area_name
	var/list/tags = list()
	if(islist(extra_tags))
		for(var/t in extra_tags)
			tags |= llm_lower_ru("[t]")
	for(var/word in splittext(llm_lower_ru(clean), " "))
		var/w = replacetext(replacetext(replacetext(replacetext(word, ".", ""), ",", ""), "!", ""), "?", "")
		if(length_char(w) >= 4)
			tags |= w
		if(length(tags) >= 16)
			break

	memories += new /datum/llm_memory(clean, importance, aname, tags)
	memories_since_reflection++
	// High-importance dramatic events also feed shared town rumors
	if(importance >= 8)
		SSllm_npc.add_shared_rumor(clean, owner ? owner.real_name : "")
	if(length(memories) > LLM_MAX_EPISODIC_MEMORIES)
		var/drop_idx = 1
		var/lowest_score = 999
		for(var/i in 1 to min(length(memories), 20))
			var/datum/llm_memory/M = memories[i]
			if(M.importance < lowest_score)
				lowest_score = M.importance
				drop_idx = i
		memories.Cut(drop_idx, drop_idx + 1)

/datum/llm_npc_brain/proc/adjust_emotions(d_valence = 0, d_fear = 0, d_anger = 0, d_suspicion = 0, d_curiosity = 0)
	mood_valence = clamp(mood_valence + d_valence, -100, 100)
	fear = clamp(fear + d_fear, 0, 100)
	anger = clamp(anger + d_anger, 0, 100)
	suspicion = clamp(suspicion + d_suspicion, 0, 100)
	curiosity = clamp(curiosity + d_curiosity, 0, 100)

/datum/llm_npc_brain/proc/schedule_wake(urgency, debounce_ds, reason)
	var/target_time = world.time + debounce_ds
	if(!wake_at || urgency > wake_urgency || (urgency == wake_urgency && target_time < wake_at))
		wake_at = target_time
		wake_urgency = urgency
		wake_reason = reason

/datum/llm_npc_brain/proc/should_suppress_random_idle()
	if(!owner || !SSllm_npc.is_enabled())
		return FALSE
	return owner.mode != NPC_AI_SLEEP

// ============================================================================
// Main Brain Tick (called every 0.5s by SSllm_npc)
// ============================================================================

/datum/llm_npc_brain/proc/tick_brain()
	if(!owner || QDELETED(owner))
		return
	if(owner.client && !owner.ai_when_client)
		return
	if(owner.stat == DEAD)
		cancel_pending_speech()
		return

	// 1) Passive drive & emotion decay (every 10 seconds)
	if(world.time >= last_drive_tick_at + 10 SECONDS)
		last_drive_tick_at = world.time
		tick_drives_and_emotions()

	// 2) If sleeping by plan, manage peaceful rest & wake-up conditions
	if(is_sleeping_by_plan)
		tick_planned_sleep()
		return

	if(owner.IsDeadOrIncap())
		cancel_pending_speech()
		return

	// 3) Clear stale pending item offers (after 20s or if giver walked away)
	if(pending_offer_item_ref)
		var/mob/living/og = pending_offer_giver_ref?.resolve()
		var/obj/item/oi = pending_offer_item_ref?.resolve()
		if(!og || !oi || get_dist(owner, og) > 3 || world.time > pending_offer_at + 20 SECONDS || og.offered_item_ref?.resolve() != oi)
			pending_offer_giver_ref = null
			pending_offer_item_ref = null
			pending_offer_stealthy = FALSE

	// 4) Monitor active multi-step System-1 action + door closing + automatic sheathing
	tick_active_action()
	try_close_passed_door()

	// 5) Sleep guard: if no players are in spatial grid cells, burn ZERO API calls!
	if(owner.mode == NPC_AI_SLEEP)
		wake_at = 0
		return

	// 6) Passive environmental sensors (every 2 seconds while players are nearby)
	if(world.time >= last_sensor_tick_at + 2 SECONDS)
		last_sensor_tick_at = world.time
		tick_passive_sensors()

	// 7) Subtle human micro-life & peaceful auto-sheathing (every 14s)
	if(world.time >= last_micro_life_at + 14 SECONDS)
		last_micro_life_at = world.time
		tick_micro_life()

	// 8) Occasional quiet random human thoughts (not too often: every 75-125s when idle)
	if(!wake_at && !in_flight && active_action == LLM_ACTION_IDLE && world.time >= next_random_thought_at)
		last_random_thought_at = world.time
		next_random_thought_at = world.time + rand(LLM_RANDOM_THOUGHT_MIN_INTERVAL, LLM_RANDOM_THOUGHT_MAX_INTERVAL)
		push_event("СЛУЧАЙНАЯ МЫСЛЬ: В голову пришла тихая мимолётная мысль (о жизни, погоде, еде, куреве, деньгах, слухах или людях вокруг). Можешь промолчать и просто подумать/сделать жест.")
		schedule_wake(1, 5, "random_thought")

	// 9) Slow ambient initiative heartbeat (every 45-70s if idle near players)
	var/idle_interval = (active_action == LLM_ACTION_IDLE) ? 45 SECONDS : 70 SECONDS
	if(!wake_at && !in_flight && world.time >= last_idle_beat_at + idle_interval)
		last_idle_beat_at = world.time
		schedule_wake(1, 5, "ambient_initiative")

	// 10) Background reflection consolidation
	if(!reflect_in_flight && !in_flight && memories_since_reflection >= LLM_REFLECT_THRESHOLD && wake_urgency < 3 && SSllm_npc.can_dispatch_call())
		dispatch_reflection()
		return

	// 11) Fire debounced event-driven LLM turn
	if(wake_at && world.time >= wake_at && !in_flight)
		var/min_cd = SSllm_npc.get_cooldown_ds()
		if(wake_urgency >= 3)
			min_cd = max(12, round(min_cd * 0.6))
		if(world.time < last_turn_at + min_cd)
			return
		if(!SSllm_npc.can_dispatch_call())
			return
		dispatch_decision_turn()

/datum/llm_npc_brain/proc/tick_drives_and_emotions()
	// Gentle emotional decay toward baseline
	if(mood_valence > 5)
		mood_valence = max(5, mood_valence - 2)
	else if(mood_valence < -5)
		mood_valence = min(-5, mood_valence + 2)
	if(fear > 5)
		fear = max(5, fear - 3)
	if(anger > 0)
		anger = max(0, anger - 3)
	if(suspicion > 15)
		suspicion = max(15, suspicion - 2)

	// Drives evolve naturally across the round
	drive_hunger = clamp(drive_hunger + 1, 0, 100)
	drive_thirst = clamp(drive_thirst + 1, 0, 100)
	if(GLOB.tod == "dusk" || GLOB.tod == "night")
		drive_alcohol = clamp(drive_alcohol + 1, 0, 100)
	if(prob(55))
		drive_smoke = clamp(drive_smoke + 1, 0, 100)
	if(prob(40))
		drive_intimacy = clamp(drive_intimacy + 1, 0, 100)

	if(is_sleeping_by_plan || owner.IsSleeping())
		drive_fatigue = max(0, drive_fatigue - 8)
	else if(owner.buckled)
		drive_fatigue = max(0, drive_fatigue - 3)
	else
		var/fatigue_step = (GLOB.tod == "night") ? 3 : 1
		drive_fatigue = clamp(drive_fatigue + fatigue_step, 0, 100)
	drive_social = clamp(drive_social + 1, 0, 100)

/datum/llm_npc_brain/proc/tick_planned_sleep()
	// Keep resting gently while sleeping
	if(drive_fatigue <= 12 || (GLOB.tod == "dawn" || GLOB.tod == "day"))
		wake_up_from_sleep("Ты выспался и проснулся.")
		return
	if(owner.health < last_health_snapshot - 3)
		wake_up_from_sleep("Тебя разбудила резкая боль!", skip_dress = TRUE)
		return
	// Keep sleeping smoothly if SetSleeping timer ran low
	if(!owner.IsSleeping())
		owner.SetSleeping(160)

/datum/llm_npc_brain/proc/tick_passive_sensors()
	// A) Area transition detection
	var/area/A = get_area(owner)
	var/aname = A ? trim(A.name) : ""
	if(length(aname) && aname != last_area_name)
		var/old_area = last_area_name
		last_area_name = aname
		if(length(old_area))
			push_event("ПЕРЕМЕЩЕНИЕ: Ты перешёл из «[old_area]» в «[aname]».")

	// B) Time-of-day shift detection (triggers schedule rhythm)
	var/cur_tod = "[GLOB.tod]"
	if(length(cur_tod) && cur_tod != last_tod)
		last_tod = cur_tod
		push_event("ВРЕМЯ СУТОК изменилось: сейчас [cur_tod]. [llm_describe_daily_schedule(cur_tod, archetype)]")
		schedule_wake(2, 20, "tod_shift")

	// C) Sudden health drop / injury awareness
	if(owner.health < last_health_snapshot - 8)
		var/dmg = round(last_health_snapshot - owner.health)
		adjust_emotions(d_valence = -15, d_fear = 22, d_anger = 15)
		push_event("БОЛЬ: Ты получил ранение (- [dmg] здоровья, сейчас [round(owner.health)]/[round(owner.maxHealth)]).")
		schedule_wake(3, 5, "took_damage")
	last_health_snapshot = owner.health

	// D) Line-of-sight arrival / departure diffing + NPC-to-NPC rumor swap
	var/list/current_refs = list()
	for(var/mob/living/L in view(7, owner))
		if(L == owner || (L.alpha == 0 && L.rogue_sneaking))
			continue
		var/r = REF(L)
		current_refs += r
		var/datum/llm_relationship/rel = get_or_create_relationship(L)
		rel.last_seen_at = world.time
		rel.last_seen_area = last_area_name

		if(!(r in last_visible_mob_refs))
			var/dir_txt = dir2text(get_dir(owner, L))
			var/extra = describe_mob_glance_cues(L)
			var/cue_str = length(extra) ? " ([extra])" : ""
			push_event("ПОЯВИЛСЯ: [rel.known_name] ([rel.entity_id])[cue_str], [get_dist(owner, L)] тайл. ([dir_txt]).")
			if(L.stat == DEAD)
				adjust_emotions(d_valence = -15, d_fear = 25, d_suspicion = 25)
				schedule_wake(3, 8, "saw_corpse")
			else if(get_dist(owner, L) <= 4 && L.client)
				schedule_wake(2, 24, "person_approached")

	for(var/old_r in last_visible_mob_refs)
		if(!(old_r in current_refs))
			var/datum/llm_relationship/old_rel = relationships_by_ref[old_r]
			if(old_rel)
				push_event("УШЁЛ из поля зрения: [old_rel.known_name] ([old_rel.entity_id]).")

	last_visible_mob_refs = current_refs

/datum/llm_npc_brain/proc/tick_micro_life()
	if(owner.mode != NPC_AI_IDLE || active_action != LLM_ACTION_IDLE || owner.IsStandingStill() || owner.surrendering)
		return
	// Automatic peaceful weapon sheathing: don't wave a drawn sword around town for no reason!
	if(fear < 30 && anger < 30 && world.time > last_weapon_used_at + 35 SECONDS)
		var/obj/item/held = owner.get_active_held_item()
		if(held && (istype(held, /obj/item/rogueweapon) || istype(held, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)))
			if(held.equip_to_best_slot(owner))
				execute_llm_emote("убирает [llm_clean_text(held.name, 30)]")
				return

	// Subtle human glances toward nearby people
	var/mob/living/closest = null
	var/best_dist = 99
	for(var/mob/living/L in view(5, owner))
		if(L == owner || (L.alpha == 0 && L.rogue_sneaking))
			continue
		var/d = get_dist(owner, L)
		if(d < best_dist)
			best_dist = d
			closest = L
	if(closest && prob(45))
		owner.face_atom(closest)
	else if(prob(20))
		owner.setDir(turn(owner.dir, pick(90, -90)))

// ============================================================================
// Dispatching & Applying Gemini Decisions + Reflections
// ============================================================================

/datum/llm_npc_brain/proc/dispatch_decision_turn()
	in_flight = TRUE
	last_turn_at = world.time
	last_idle_beat_at = world.time
	wake_at = 0
	wake_urgency = 0

	var/sys_prompt = build_system_prompt()
	var/user_prompt = build_turn_user_prompt()
	var/list/schema = build_turn_schema()

	pending_events.Cut()
	last_examine_report = ""

	var/ok = SSllm_npc.send_gemini_request(
		brain = src,
		req_kind = LLM_NPC_REQ_TURN,
		system_prompt = sys_prompt,
		user_prompt = user_prompt,
		response_schema = schema,
		thinking_level = SSllm_npc.get_thinking_level(),
		temperature = 0.85,
		max_output_tokens = 900
	)
	if(!ok)
		in_flight = FALSE
		last_error = SSllm_npc.last_error

/datum/llm_npc_brain/proc/dispatch_reflection()
	reflect_in_flight = TRUE
	var/sys_prompt = build_reflection_system_prompt()
	var/user_prompt = build_reflection_user_prompt()
	var/list/schema = build_reflection_schema()

	var/ok = SSllm_npc.send_gemini_request(
		brain = src,
		req_kind = LLM_NPC_REQ_REFLECT,
		system_prompt = sys_prompt,
		user_prompt = user_prompt,
		response_schema = schema,
		thinking_level = "medium",
		temperature = 0.6,
		max_output_tokens = 512
	)
	if(!ok)
		reflect_in_flight = FALSE

/datum/llm_npc_brain/proc/on_llm_error(req_kind, err_msg)
	if(req_kind == LLM_NPC_REQ_REFLECT)
		reflect_in_flight = FALSE
	else
		in_flight = FALSE
	last_error = err_msg
	if(SSllm_npc.debug_logging)
		log_game("LLM Brain ([owner]): [req_kind] error: [err_msg]")

/datum/llm_npc_brain/proc/on_llm_decision(list/data, elapsed_ms = 0)
	in_flight = FALSE
	last_latency_ms = elapsed_ms
	last_error = ""
	turns_completed++
	var/was_direct = wake_was_direct_speech
	wake_was_direct_speech = FALSE

	if(!owner || QDELETED(owner) || owner.IsDeadOrIncap())
		return

	// 1) Inner monologue & emotional shift
	if(istext(data["thought"]))
		last_thought = copytext_char(trim(data["thought"]), 1, 320)
	if(istext(data["emotion_label"]) && length(trim(data["emotion_label"])))
		current_emotion = copytext_char(trim(data["emotion_label"]), 1, 60)

	adjust_emotions(
		d_valence = isnum(data["valence_delta"]) ? clamp(round(data["valence_delta"]), -35, 35) : 0,
		d_fear = isnum(data["fear_delta"]) ? clamp(round(data["fear_delta"]), -35, 35) : 0,
		d_anger = isnum(data["anger_delta"]) ? clamp(round(data["anger_delta"]), -35, 35) : 0,
		d_suspicion = isnum(data["suspicion_delta"]) ? clamp(round(data["suspicion_delta"]), -35, 35) : 0
	)

	if(istext(data["plan"]) && length(trim(data["plan"])))
		current_plan = copytext_char(trim(data["plan"]), 1, 200)

	// 2) Relationship update (Theory of Mind + Attraction + Role)
	var/list/rel_upd = data["person_update"]
	if(islist(rel_upd) && istext(rel_upd["target_id"]) && length(rel_upd["target_id"]))
		var/datum/llm_relationship/rel = relationships_by_tag[LOWER_TEXT(trim(rel_upd["target_id"]))]
		if(rel)
			rel.interactions++
			if(isnum(rel_upd["trust_delta"]))
				rel.trust = clamp(rel.trust + round(rel_upd["trust_delta"]), -100, 100)
			if(isnum(rel_upd["fear_delta"]))
				rel.fear = clamp(rel.fear + round(rel_upd["fear_delta"]), 0, 100)
			if(isnum(rel_upd["respect_delta"]))
				rel.respect = clamp(rel.respect + round(rel_upd["respect_delta"]), -100, 100)
			if(isnum(rel_upd["attraction_delta"]))
				rel.attraction = clamp(rel.attraction + round(rel_upd["attraction_delta"]), -50, 100)
			if(istext(rel_upd["remembered_name"]) && length(trim(rel_upd["remembered_name"])))
				rel.known_name = copytext_char(trim(rel_upd["remembered_name"]), 1, 50)
			if(istext(rel_upd["perceived_role"]) && length(trim(rel_upd["perceived_role"])))
				rel.perceived_role = copytext_char(trim(rel_upd["perceived_role"]), 1, 50)
			if(istext(rel_upd["note"]) && length(trim(rel_upd["note"])))
				rel.add_note(copytext_char(trim(rel_upd["note"]), 1, 140))

	// 3) Episodic memory + optional town rumor sharing
	if(istext(data["memory_note"]) && length(trim(data["memory_note"])))
		var/imp = isnum(data["memory_importance"]) ? data["memory_importance"] : 5
		var/list/mtags = list()
		if(islist(rel_upd) && istext(rel_upd["target_id"]) && length(rel_upd["target_id"]))
			mtags += rel_upd["target_id"]
		add_memory(copytext_char(trim(data["memory_note"]), 1, 200), imp, mtags)

	if(istext(data["share_rumor"]) && length(trim(data["share_rumor"])))
		SSllm_npc.add_shared_rumor(copytext_char(trim(data["share_rumor"]), 1, 180), owner.real_name)

	// 4) Facing target & immediate Emote
	var/face_id = istext(data["face_target"]) ? LOWER_TEXT(trim(data["face_target"])) : ""
	if(length(face_id))
		var/atom/face_atom_target = resolve_entity_tag(face_id)
		if(face_atom_target && (face_atom_target in view(7, owner)))
			owner.face_atom(face_atom_target)

	var/emote_txt = istext(data["emote"]) ? trim(data["emote"]) : ""
	if(length(emote_txt))
		execute_llm_emote(emote_txt)

	// 5) Speech with strict natural pacing engine (direct reply vs >=10s ambient cap)
	var/speech_txt = istext(data["speech"]) ? trim(data["speech"]) : ""
	var/speech_mode = istext(data["speech_mode"]) ? LOWER_TEXT(trim(data["speech_mode"])) : "say"
	if(length(speech_txt) && speech_mode != "none" && speech_mode != "silent")
		schedule_human_speech(speech_txt, speech_mode, is_direct_reply = was_direct)

	// 6) High-level System-1 Action Dispatch
	var/act = istext(data["action"]) ? LOWER_TEXT(trim(data["action"])) : LLM_ACTION_IDLE
	var/act_target = istext(data["action_target"]) ? trim(data["action_target"]) : ""
	var/act_arg = istext(data["action_arg"]) ? trim(data["action_arg"]) : ""
	start_llm_action(act, act_target, act_arg)

	if(SSllm_npc.debug_logging)
		log_game("LLM Brain ([owner]) [elapsed_ms]ms | mood=[current_emotion] | act=[act]([act_target],[act_arg]) | say=[copytext_char(speech_txt, 1, 80)] | thought=[copytext_char(last_thought, 1, 100)]")

/datum/llm_npc_brain/proc/on_llm_reflection(list/data)
	reflect_in_flight = FALSE
	memories_since_reflection = 0
	if(!islist(data))
		return
	var/list/new_refs = data["reflections"]
	if(islist(new_refs))
		for(var/line in new_refs)
			if(!istext(line))
				continue
			var/clean = copytext_char(trim(line), 1, 180)
			if(length(clean) && !(clean in reflections))
				reflections += clean
		while(length(reflections) > LLM_MAX_REFLECTIONS)
			reflections.Cut(1, 2)
	if(istext(data["updated_long_term_goal"]) && length(trim(data["updated_long_term_goal"])))
		long_term_goal = copytext_char(trim(data["updated_long_term_goal"]), 1, 200)

// ============================================================================
// Minimal Zero-Overhead Hooks on /mob/living/carbon/human
// ============================================================================

/mob/living/carbon/human
	var/datum/llm_npc_brain/llm_brain

/mob/living/carbon/human/Destroy()
	QDEL_NULL(llm_brain)
	return ..()

/mob/living/carbon/human/Hear(message, atom/movable/speaker, datum/language/message_language, raw_message, radio_freq, list/spans, message_mode, original_message)
	if(llm_brain && !client && stat != DEAD)
		llm_brain.on_hear(speaker, raw_message, message_mode, message_language)
	return ..()

/mob/living/carbon/human/show_message(msg, type, alt_msg, alt_type)
	if(llm_brain && !client && stat == CONSCIOUS)
		llm_brain.on_world_message(msg, type)
	return ..()

/mob/living/carbon/human/ongive(mob/living/carbon/human/user, params)
	var/obj/item/item_to_offer = ishuman(user) ? user.get_active_held_item() : null
	var/was_offering = ishuman(user) ? user.offered_item_ref : null
	. = ..()
	if(llm_brain && !client && ishuman(user) && item_to_offer && !was_offering && user.offered_item_ref?.resolve() == item_to_offer)
		llm_brain.on_item_offered(user, item_to_offer, user.m_intent == MOVE_INTENT_SNEAK)

/mob/living/carbon/human/retaliate(mob/living/L)
	var/was_hunting = (mode == NPC_AI_HUNT && target == L)
	. = ..()
	if(llm_brain && !was_hunting && target == L)
		llm_brain.on_combat_engaged(L)

/mob/living/carbon/human/npc_should_resist(ignore_grab = FALSE)
	if(llm_brain && surrendering && !on_fire)
		return FALSE
	return ..()

/mob/living/carbon/human/process_ai()
	if(llm_brain && surrendering)
		cmode = 0
		walk_to(src, 0)
		return FALSE
	return ..()

/mob/living/carbon/human/do_best_melee_attack(mob/living/victim)
	if(llm_brain && llm_brain.nonlethal_combat && isliving(victim))
		// Non-lethal subdue mode: try grappling or unarmed knockdown instead of lethal blade slashes
		if(!get_inactive_held_item() && prob(35))
			if(npc_try_make_grab(victim))
				return TRUE
		// Stow sharp weapon briefly or strike unarmed
		var/obj/item/W = get_active_held_item()
		if(W && W.force >= 12)
			W.equip_to_best_slot(src)
		rog_intent_change(4)
		used_intent = a_intent
		UnarmedAttack(victim, 1)
		changeNext_move(used_intent ? used_intent.clickcd : 10)
		return TRUE
	return ..()

/mob/living/carbon/human/npc_idle()
	if(llm_brain && llm_brain.should_suppress_random_idle())
		return
	return ..()
