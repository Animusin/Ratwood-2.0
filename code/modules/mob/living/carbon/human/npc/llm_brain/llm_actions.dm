// Complex BYOND Body Wrapper & Multi-Tick System-1 Action Engine for /datum/llm_npc_brain.
// Handles:
//   - Natural speech pacing (direct replies vs hard >=10s ambient speech cap + typing delay)
//   - 3D Multi-Z Navigation across /obj/structure/stairs + table-avoiding peaceful A*
//   - Parkour pursuit & escape (jumping, vaulting railings/fences) + explicit climb_over / jump_to
//   - Door etiquette (auto-open unlocked/keyed doors AND auto-close behind self!)
//   - Lethal & Non-Lethal combat, Archery with automatic Arc-Shot over allies' heads, Draw/Sheathe, Surrender
//   - Restraining with rope/chains + Escorting/Carrying prisoners/wounded to cells or superiors with report
//   - Accepting/Refusing bribes & offered items via native offer_item / try_accept_offered_item
//   - Healing (bandages, suturing needles, potions, giving water to others)
//   - Eating off plates/tables, drinking water/alcohol, lighting & smoking cigarettes/pipes
//   - Sleep lifecycle (walk to bed -> undress by bed -> lie down -> sleep -> wake -> dress back up!)
//   - Item/object relocation (pickup, drop, move_item, give_item, interact, examine_closer)

// ============================================================================
// Speech Pacing Engine & Custom Emotes
// ============================================================================

/datum/llm_npc_brain/proc/execute_llm_emote(raw_emote)
	if(!owner || QDELETED(owner) || owner.IsDeadOrIncap())
		return
	var/clean = llm_clean_text(raw_emote, 140)
	if(!length(clean))
		return
	if(findtext(clean, owner.real_name, 1, length(owner.real_name) + 2))
		clean = trim(copytext(clean, length(owner.real_name) + 1))
	if(!length(clean))
		return
	owner.emote("me", EMOTE_VISIBLE, clean, intentional = TRUE, custom_me = TRUE)

/datum/llm_npc_brain/proc/cancel_pending_speech()
	if(pending_speech_timer)
		deltimer(pending_speech_timer)
		pending_speech_timer = null

/datum/llm_npc_brain/proc/schedule_human_speech(raw_text, speech_mode = "say", is_direct_reply = FALSE)
	if(!owner || QDELETED(owner) || owner.IsDeadOrIncap())
		return
	var/clean = llm_clean_text(raw_text, 240)
	if(!length(clean))
		return

	// 1) Never repeat the exact same phrase back-to-back
	if(length(recent_self_speech) && llm_lower_ru(recent_self_speech[length(recent_self_speech)]) == llm_lower_ru(clean))
		return

	// 2) Anti-spam speech pacing gate:
	//    - Direct replies / combat shouts / surrender pleas: minimum ~3.5s apart
	//    - Unprompted / ambient / random-thought speech: hard >=10s cooldown (configurable!)
	var/is_urgent_speech = is_direct_reply || (speech_mode == "shout") || (owner.mode == NPC_AI_HUNT) || (owner.mode == NPC_AI_FLEE) || owner.surrendering
	if(is_urgent_speech)
		if(world.time < last_speech_at + LLM_DIRECT_SPEECH_MIN_CD)
			return
	else
		var/ambient_cd = SSllm_npc.get_ambient_speech_cd_ds()
		if(world.time < last_speech_at + ambient_cd || world.time < last_ambient_speech_at + ambient_cd)
			return
		// Don't babble to an empty room when nobody is in earshot
		if(!length(last_visible_mob_refs))
			return

	cancel_pending_speech()

	// Proportional reading/typing cadence: ~0.7s to ~2.2s
	var/delay_ds = clamp(round(6 + length_char(clean) * 0.13), 7, 22)
	if(speech_mode == "shout" || owner.mode == NPC_AI_HUNT || owner.mode == NPC_AI_FLEE || owner.surrendering)
		delay_ds = min(delay_ds, 5)

	pending_speech_timer = addtimer(CALLBACK(src, PROC_REF(deliver_scheduled_speech), clean, speech_mode, is_urgent_speech), delay_ds, TIMER_STOPPABLE)

/datum/llm_npc_brain/proc/deliver_scheduled_speech(clean_text, speech_mode, was_urgent = FALSE)
	pending_speech_timer = null
	if(!owner || QDELETED(owner) || owner.IsDeadOrIncap())
		return

	if(length_char(clean_text) >= 2)
		var/first_c = copytext_char(clean_text, 1, 2)
		var/last_c = copytext_char(clean_text, length_char(clean_text))
		if((first_c == "\"" && last_c == "\"") || (first_c == "«" && last_c == "»"))
			clean_text = trim(copytext_char(clean_text, 2, length_char(clean_text)))
	if(!length(clean_text))
		return

	if(speech_mode == "whisper")
		owner.whisper(clean_text)
	else
		owner.say(clean_text)

	last_speech_at = world.time
	if(!was_urgent)
		last_ambient_speech_at = world.time
	drive_social = max(0, drive_social - 10)
	recent_self_speech += clean_text
	if(length(recent_self_speech) > LLM_MAX_RECENT_SPEECH)
		recent_self_speech.Cut(1, 2)
	push_event("ТЫ СКАЗАЛ ([speech_mode]): \"[clean_text]\"")

// ============================================================================
// High-Level System-2 -> System-1 Action Dispatcher
// ============================================================================

/datum/llm_npc_brain/proc/start_llm_action(act, target_str = "", arg_str = "")
	if(!owner || QDELETED(owner) || owner.stat == DEAD)
		return

	// Waking up from planned sleep
	if(act == LLM_ACTION_WAKE_UP)
		wake_up_from_sleep("Ты решил проснуться и встать.")
		return

	if(owner.IsDeadOrIncap())
		return

	// Don't let idle silently cancel active combat/flee unless explicitly calming down / surrendering
	if((owner.mode == NPC_AI_HUNT || owner.mode == NPC_AI_FLEE) && act == LLM_ACTION_IDLE)
		return

	// Clear old non-combat state cleanly
	if(act != active_action || length(target_str) || length(arg_str))
		action_stuck_strikes = 0
		action_last_turf = get_turf(owner)
		action_dest_loc = null
		action_active_stair = null
		action_escort_dest_mob_ref = null
		action_move_dest_ref = null
		action_stage = 0

	active_action = act
	action_arg = arg_str
	action_started_at = world.time
	action_timeout_at = world.time + 24 SECONDS
	action_last_repath_at = 0

	var/atom/resolved = length(target_str) ? resolve_entity_tag(target_str) : null
	action_target_ref = resolved ? WEAKREF(resolved) : null

	switch(act)
		if(LLM_ACTION_IDLE, "wait", "none")
			active_action = LLM_ACTION_IDLE
			if(owner.mode == NPC_AI_IDLE)
				owner.clear_path()
				walk(owner, 0)
			return

		if(LLM_ACTION_STAND_UP)
			ensure_unbuckled()
			if(!(owner.mobility_flags & MOBILITY_STAND))
				owner.npc_stand()
			finish_action("Ты встал на ноги.")
			return

		if(LLM_ACTION_SURRENDER)
			nonlethal_combat = FALSE
			owner.clear_enemies()
			owner.back_to_idle()
			owner.clear_path()
			owner.submit(instant = TRUE)
			finish_action("Ты бросил оружие, поднял руки и сдался!", wake_brain = FALSE)
			return

		if(LLM_ACTION_CALM_DOWN)
			nonlethal_combat = FALSE
			owner.clear_enemies()
			owner.back_to_idle()
			if(owner.pulling)
				owner.stop_pulling()
			adjust_emotions(d_anger = -25, d_fear = -15)
			finish_action("Ты прекратил бой и успокоился.")
			return

		// ---- Combat & Pursuit ----
		if(LLM_ACTION_ATTACK_LETHAL, "attack")
			if(!isliving(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Некого атаковать — цель вне поля зрения.")
				return
			ensure_unbuckled()
			nonlethal_combat = FALSE
			last_weapon_used_at = world.time
			try_draw_best_weapon(prefer_bow = FALSE, silent = TRUE)
			owner.retaliate(resolved)
			owner.m_intent = MOVE_INTENT_RUN
			action_timeout_at = world.time + 45 SECONDS
			return

		if(LLM_ACTION_ATTACK_NONLETHAL)
			if(!isliving(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Некого усмирять — цель вне поля зрения.")
				return
			ensure_unbuckled()
			nonlethal_combat = TRUE
			last_weapon_used_at = world.time
			owner.retaliate(resolved)
			owner.m_intent = MOVE_INTENT_RUN
			action_timeout_at = world.time + 40 SECONDS
			return

		if(LLM_ACTION_SHOOT_BOW)
			if(!isliving(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Цель для выстрела из лука вне поля зрения.")
				return
			perform_archery_shot(resolved)
			return

		if(LLM_ACTION_FLEE)
			ensure_unbuckled()
			if(owner.pulling)
				owner.stop_pulling()
			owner.clear_path()
			if(isliving(resolved))
				owner.target = resolved
			owner.mode = NPC_AI_FLEE
			owner.m_intent = MOVE_INTENT_RUN
			action_timeout_at = world.time + 28 SECONDS
			return

		if(LLM_ACTION_CHASE)
			if(!isliving(resolved) || !(resolved in view(7, owner)))
				finish_action("Не за кем гнаться — цель не видна.")
				return
			ensure_unbuckled()
			action_timeout_at = world.time + 40 SECONDS
			begin_smart_move_to(resolved, peaceful = FALSE, sprint = TRUE)
			return

		// ---- Weapon Draw / Sheathe ----
		if(LLM_ACTION_DRAW_WEAPON)
			var/obj/item/w = try_draw_best_weapon(prefer_bow = findtext(llm_lower_ru(arg_str), "лук") || findtext(llm_lower_ru(arg_str), "bow"), query = arg_str, silent = FALSE)
			if(w)
				last_weapon_used_at = world.time
				finish_action("Ты достал в руку [llm_clean_text(w.name, 36)].")
			else
				finish_action("У тебя нет подходящего оружия, чтобы достать.")
			return

		if(LLM_ACTION_SHEATHE_WEAPON)
			var/did = perform_sheathe_weapons()
			finish_action(did ? "Ты убрал оружие." : "В руках нет оружия, которое можно убрать.")
			return

		// ---- Restraining & Escorting/Carrying with Report ----
		if(LLM_ACTION_RESTRAIN)
			if(!ishuman(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Некого связывать — цель не видна.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				perform_restrain(resolved)
				return
			begin_smart_move_to(resolved, peaceful = FALSE, sprint = TRUE)
			return

		if(LLM_ACTION_ESCORT)
			if(!isliving(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Некого вести/нести — цель не видна.")
				return
			ensure_unbuckled()
			// Destination can be a person/authority (e.g. "p3", "Captain", "Lord") OR a location/cell (e.g. "Dungeon", "Камера")
			var/atom/dest_person = resolve_entity_tag(arg_str)
			if(isliving(dest_person) && dest_person != owner && dest_person != resolved)
				action_escort_dest_mob_ref = WEAKREF(dest_person)
			else
				var/mob/living/carbon/human/auth = SSllm_npc.find_authority_mob(arg_str, owner.z)
				var/datum/llm_location_info/loc_info = SSllm_npc.find_location_info(arg_str)
				if(loc_info)
					action_dest_loc = loc_info
				else if(auth && auth != owner && auth != resolved)
					action_escort_dest_mob_ref = WEAKREF(auth)
				else
					// Fallback: look for prison/cell location or any authority
					action_dest_loc = SSllm_npc.find_location_info("prison")
					if(!action_dest_loc && auth)
						action_escort_dest_mob_ref = WEAKREF(auth)
			if(!action_dest_loc && !action_escort_dest_mob_ref)
				finish_action("Не знаю, куда вести [get_perceived_mob_name(resolved)] (нет такой камеры/начальника).")
				return
			action_stage = 0 // 0 = approach & grab, 1 = escort to destination
			action_timeout_at = world.time + 65 SECONDS
			if(owner.Adjacent(resolved))
				owner.start_pulling(resolved)
				action_stage = 1
				step_escort_to_destination()
			else
				begin_smart_move_to(resolved, peaceful = TRUE)
			return

		// ---- Bribe / Offered Item Handling ----
		if(LLM_ACTION_ACCEPT_OFFER)
			perform_accept_offer()
			return

		if(LLM_ACTION_REFUSE_OFFER)
			perform_refuse_offer()
			return

		// ---- Local Semantic Navigation, Parkour & Multi-Z Town Travel ----
		if(LLM_ACTION_APPROACH)
			if(!resolved || !(resolved in view(7, owner)))
				finish_action("Цель не видна, подойти не удалось.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				owner.face_atom(resolved)
				finish_action("Ты уже рядом с [llm_clean_text(resolved.name, 40)].")
				return
			begin_smart_move_to(resolved, peaceful = TRUE)
			return

		if(LLM_ACTION_FOLLOW)
			if(!isliving(resolved) || !(resolved in view(7, owner)))
				finish_action("Не за кем следовать — цель не видна.")
				return
			ensure_unbuckled()
			action_timeout_at = world.time + 50 SECONDS
			begin_smart_move_to(resolved, peaceful = TRUE)
			return

		if(LLM_ACTION_KEEP_DISTANCE)
			if(!isliving(resolved) || !(resolved in view(7, owner)))
				finish_action("Не от кого держать дистанцию.")
				return
			ensure_unbuckled()
			owner.face_atom(resolved)
			if(get_dist(owner, resolved) <= 2)
				var/away_dir = get_dir(resolved, owner)
				var/turf/step_t = get_step(owner, away_dir)
				if(step_t && !step_t.density && !(locate(/obj/structure/table) in step_t) && step_t.can_traverse_safely(owner))
					step(owner, away_dir)
					owner.face_atom(resolved)
			finish_action("Ты держишь безопасную дистанцию от [get_perceived_mob_name(resolved)].")
			return

		if(LLM_ACTION_WANDER)
			ensure_unbuckled()
			var/turf/dest = pick_open_walkable_turf(arg_str)
			if(!dest)
				finish_action("Некуда пройтись по открытой территории рядом.")
				return
			action_target_ref = WEAKREF(dest)
			begin_smart_move_to(dest, peaceful = TRUE)
			return

		if(LLM_ACTION_GO_TO_AREA)
			var/area_query = length(arg_str) ? arg_str : target_str
			var/datum/llm_location_info/dest_info = SSllm_npc.find_location_info(area_query)
			if(!dest_info)
				finish_action("Не знаю дороги до «[area_query]».")
				return
			if(dest_info.area_ref && get_area(owner) == dest_info.area_ref && owner.z == dest_info.z_level)
				finish_action("Ты уже в «[dest_info.name]».")
				return
			ensure_unbuckled()
			action_dest_loc = dest_info
			action_timeout_at = world.time + 60 SECONDS
			step_toward_location_3d(dest_info)
			return

		if(LLM_ACTION_CLIMB_OVER)
			if(!istype(resolved, /obj/structure) || !(resolved in view(6, owner)))
				finish_action("Нет преграды/перил поблизости, чтобы перелезть.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				var/obj/structure/S = resolved
				if(S.climbable)
					S.climb_structure(owner)
					finish_action("Ты перелез через [llm_clean_text(S.name, 35)].", wake_brain = TRUE)
				else
					finish_action("Через [llm_clean_text(S.name, 35)] не перелезть.")
				return
			begin_smart_move_to(resolved, peaceful = FALSE)
			return

		if(LLM_ACTION_JUMP_TO)
			if(!resolved || !(resolved in view(7, owner)))
				finish_action("Некуда прыгать.")
				return
			ensure_unbuckled()
			owner.face_atom(resolved)
			if(owner.npc_try_jump_to(resolved))
				finish_action("Ты прыгнул в сторону [llm_clean_text(resolved.name, 35)]!", wake_brain = TRUE)
			else
				finish_action("Прыжок не удался (не хватило сил или мешает преграда).")
			return

		// ---- Item Manipulation (Pickup, Drop, Move, Give) ----
		if(LLM_ACTION_PICKUP)
			if(!isitem(resolved) || !isturf(resolved.loc) || !(resolved in view(6, owner)))
				finish_action("Предмет недоступен или не виден.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				perform_pickup(resolved)
				return
			begin_smart_move_to(resolved, peaceful = TRUE)
			return

		if(LLM_ACTION_DROP)
			var/obj/item/to_drop = find_owned_item(length(arg_str) ? arg_str : target_str)
			if(!to_drop)
				finish_action("У тебя нет такого предмета, чтобы выкинуть.")
				return
			if(owner.dropItemToGround(to_drop))
				finish_action("Ты выложил на землю [llm_clean_text(to_drop.name, 40)].")
			else
				finish_action("Не удалось выпустить [llm_clean_text(to_drop.name, 40)].")
			return

		if(LLM_ACTION_MOVE_ITEM)
			// Relocate an item onto a visible table/object/turf, OR drag a movable structure (chair/crate)
			var/atom/dest_obj = length(arg_str) ? resolve_entity_tag(arg_str) : null
			if(!resolved)
				resolved = find_owned_item(target_str)
			if(!resolved || !(resolved in view(6, owner)) && resolved.loc != owner)
				finish_action("Не вижу предмета/объекта, который нужно переместить.")
				return
			ensure_unbuckled()
			action_target_ref = WEAKREF(resolved)
			if(dest_obj)
				action_move_dest_ref = WEAKREF(dest_obj)
			else
				var/turf/drop_t = pick_open_walkable_turf(arg_str)
				if(drop_t)
					action_move_dest_ref = WEAKREF(drop_t)
			if(!action_move_dest_ref)
				finish_action("Непонятно, куда именно переместить [llm_clean_text(resolved.name, 35)].")
				return
			action_stage = (isitem(resolved) && resolved.loc == owner) ? 1 : 0
			action_timeout_at = world.time + 30 SECONDS
			if(action_stage == 0)
				if(owner.Adjacent(resolved))
					advance_move_item(resolved)
				else
					begin_smart_move_to(resolved, peaceful = TRUE)
			else
				var/atom/md = action_move_dest_ref.resolve()
				if(md && owner.Adjacent(md))
					finish_move_item(resolved, md)
				else if(md)
					begin_smart_move_to(md, peaceful = TRUE)
			return

		if(LLM_ACTION_GIVE)
			if(!ishuman(resolved) || resolved == owner || !(resolved in view(7, owner)))
				finish_action("Некому передать предмет — адресат не виден.")
				return
			var/obj/item/gift = find_owned_item(arg_str, search_worn = TRUE)
			if(!gift)
				finish_action("У тебя нет предмета «[arg_str]», чтобы передать.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				perform_give_item(resolved, gift)
				return
			begin_smart_move_to(resolved, peaceful = TRUE)
			return

		// ---- Eating, Drinking, Smoking, Healing, Sleeping ----
		if(LLM_ACTION_EAT_DRINK)
			perform_or_start_eat_drink(resolved, arg_str)
			return

		if(LLM_ACTION_SMOKE)
			perform_smoke(resolved, arg_str)
			return

		if(LLM_ACTION_HEAL)
			var/mob/living/patient = isliving(resolved) ? resolved : owner
			if(patient != owner && !(patient in view(7, owner)))
				finish_action("Раненый вне поля зрения.")
				return
			action_target_ref = WEAKREF(patient)
			if(patient == owner || owner.Adjacent(patient))
				perform_heal(patient, arg_str)
				return
			ensure_unbuckled()
			begin_smart_move_to(patient, peaceful = TRUE)
			return

		if(LLM_ACTION_GO_SLEEP)
			start_sleep_routine(resolved, arg_str)
			return

		if(LLM_ACTION_INTERACT)
			if(!resolved || !(resolved in view(6, owner)))
				finish_action("Объект взаимодействия не виден.")
				return
			ensure_unbuckled()
			if(owner.Adjacent(resolved))
				perform_interact(resolved)
				return
			begin_smart_move_to(resolved, peaceful = TRUE)
			return

		if(LLM_ACTION_EXAMINE)
			if(!resolved || !(resolved in view(7, owner)))
				finish_action("Некого или нечего осмотреть.")
				return
			perform_detailed_examine(resolved)
			return

		else
			active_action = LLM_ACTION_IDLE

// ============================================================================
// Multi-Tick Action Monitor (Runs every 0.5s inside SSllm_npc.fire())
// ============================================================================

/datum/llm_npc_brain/proc/tick_active_action()
	if(active_action == LLM_ACTION_IDLE)
		return
	if(!owner || QDELETED(owner) || owner.IsDeadOrIncap())
		active_action = LLM_ACTION_IDLE
		return

	// Combat / Flee handoff
	if(active_action == LLM_ACTION_ATTACK_LETHAL || active_action == LLM_ACTION_ATTACK_NONLETHAL)
		if(owner.mode == NPC_AI_IDLE)
			nonlethal_combat = FALSE
			finish_action("Бой завершился.", wake_brain = TRUE)
		else if(owner.target && get_dist(owner, owner.target) >= 4)
			// Jump/parkour during pursuit!
			owner.npc_try_jump()
		return
	if(active_action == LLM_ACTION_FLEE)
		if(owner.mode == NPC_AI_IDLE)
			finish_action("Ты отбежал в безопасное место.", wake_brain = TRUE)
		return

	if(owner.mode == NPC_AI_HUNT || owner.mode == NPC_AI_FLEE)
		active_action = (owner.mode == NPC_AI_FLEE) ? LLM_ACTION_FLEE : (nonlethal_combat ? LLM_ACTION_ATTACK_NONLETHAL : LLM_ACTION_ATTACK_LETHAL)
		return

	if(world.time >= action_timeout_at)
		owner.clear_path()
		if(active_action == LLM_ACTION_ESCORT && owner.pulling)
			owner.stop_pulling()
		finish_action("Действие «[active_action]» заняло слишком много времени и прервалось.", wake_brain = TRUE)
		return

	// Auto-open doors blocking path AND traverse stairs when arriving on an active stair link!
	try_open_blocking_door()
	if(action_active_stair)
		if(try_traverse_active_stair())
			return

	var/atom/target_atom = action_target_ref?.resolve()

	switch(active_action)
		if(LLM_ACTION_GO_TO_AREA)
			if(!action_dest_loc)
				finish_action("Пункт назначения потерян.")
				return
			if(action_dest_loc.area_ref && get_area(owner) == action_dest_loc.area_ref && owner.z == action_dest_loc.z_level)
				owner.clear_path()
				finish_action("Ты добрался до «[action_dest_loc.name]».", wake_brain = TRUE)
				return
			if(!length(owner.myPath) && world.time >= action_last_repath_at + 2 SECONDS)
				if(!step_toward_location_3d(action_dest_loc))
					finish_action("Дорога к «[action_dest_loc.name]» перекрыта или недоступна.", wake_brain = TRUE)
					return

		if(LLM_ACTION_WANDER)
			if(!target_atom || get_dist(owner, target_atom) <= 1)
				owner.clear_path()
				finish_action("Ты прогулялся по округе.")
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_APPROACH)
			if(!target_atom || QDELETED(target_atom))
				finish_action("Цель исчезла.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				owner.face_atom(target_atom)
				finish_action("Ты подошёл к [llm_clean_text(target_atom.name, 40)].", wake_brain = TRUE)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_FOLLOW)
			if(!isliving(target_atom) || QDELETED(target_atom) || get_dist(owner, target_atom) > 12 || target_atom.z != owner.z)
				owner.clear_path()
				finish_action("Ты потерял из виду того, за кем шёл.", wake_brain = TRUE)
				return
			if(get_dist(owner, target_atom) > 2 && (!length(owner.myPath) || world.time >= action_last_repath_at + 2.5 SECONDS))
				begin_smart_move_to(target_atom, peaceful = TRUE)
			else if(get_dist(owner, target_atom) <= 2)
				owner.face_atom(target_atom)

		if(LLM_ACTION_CHASE)
			if(!isliving(target_atom) || QDELETED(target_atom) || get_dist(owner, target_atom) > 16 || target_atom.z != owner.z)
				owner.clear_path()
				finish_action("Беглец оторвался и скрылся.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				owner.face_atom(target_atom)
				finish_action("Ты догнал [get_perceived_mob_name(target_atom)]!", wake_brain = TRUE)
				return
			if(get_dist(owner, target_atom) >= 4)
				owner.npc_try_jump_to(target_atom)
			if(!length(owner.myPath) || world.time >= action_last_repath_at + 1.5 SECONDS)
				begin_smart_move_to(target_atom, peaceful = FALSE, sprint = TRUE)

		if(LLM_ACTION_CLIMB_OVER)
			if(!istype(target_atom, /obj/structure))
				finish_action("Преграда исчезла.")
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				var/obj/structure/S = target_atom
				S.climb_structure(owner)
				finish_action("Ты перелез через [llm_clean_text(S.name, 35)].", wake_brain = TRUE)
				return
			check_stuck_and_repath(target_atom, peaceful = FALSE)

		if(LLM_ACTION_PICKUP)
			if(!isitem(target_atom) || !isturf(target_atom.loc))
				owner.clear_path()
				finish_action("Предмет уже забрали или он исчез.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				perform_pickup(target_atom)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_MOVE_ITEM)
			var/atom/dest_atom = action_move_dest_ref?.resolve()
			if(!target_atom || !dest_atom)
				owner.clear_path()
				if(owner.pulling)
					owner.stop_pulling()
				finish_action("Перемещение прервалось.", wake_brain = TRUE)
				return
			if(action_stage == 0)
				if(owner.Adjacent(target_atom))
					owner.clear_path()
					advance_move_item(target_atom)
				else
					check_stuck_and_repath(target_atom, peaceful = TRUE)
			else
				if(owner.Adjacent(dest_atom))
					owner.clear_path()
					finish_move_item(target_atom, dest_atom)
				else
					check_stuck_and_repath(dest_atom, peaceful = TRUE)

		if(LLM_ACTION_GIVE)
			if(!ishuman(target_atom) || QDELETED(target_atom) || get_dist(owner, target_atom) > 10)
				owner.clear_path()
				finish_action("Не удалось догнать адресата для передачи.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				var/obj/item/gift = find_owned_item(action_arg, search_worn = TRUE)
				if(gift)
					perform_give_item(target_atom, gift)
				else
					finish_action("Предмет для передачи пропал.", wake_brain = TRUE)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_EAT_DRINK)
			if(!isitem(target_atom) || QDELETED(target_atom))
				owner.clear_path()
				finish_action("Еда/напиток исчезли.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom) || target_atom.loc == owner)
				owner.clear_path()
				consume_item(target_atom)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_HEAL)
			if(!isliving(target_atom) || QDELETED(target_atom))
				owner.clear_path()
				finish_action("Раненый исчез.", wake_brain = TRUE)
				return
			if(target_atom == owner || owner.Adjacent(target_atom))
				owner.clear_path()
				perform_heal(target_atom, action_arg)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

		if(LLM_ACTION_RESTRAIN)
			if(!ishuman(target_atom) || QDELETED(target_atom) || get_dist(owner, target_atom) > 12)
				owner.clear_path()
				finish_action("Нарушитель скрылся, не удалось связать.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				perform_restrain(target_atom)
				return
			check_stuck_and_repath(target_atom, peaceful = FALSE)

		if(LLM_ACTION_ESCORT)
			if(!isliving(target_atom) || QDELETED(target_atom))
				if(owner.pulling)
					owner.stop_pulling()
				finish_action("Тот, кого ты вёл, исчез.", wake_brain = TRUE)
				return
			if(action_stage == 0)
				if(owner.Adjacent(target_atom))
					owner.clear_path()
					owner.start_pulling(target_atom)
					action_stage = 1
					step_escort_to_destination()
				else
					check_stuck_and_repath(target_atom, peaceful = TRUE)
				return
			// Stage 1: actively escorting/carrying to cell or superior
			if(owner.pulling != target_atom)
				if(owner.Adjacent(target_atom))
					owner.start_pulling(target_atom)
				else
					action_stage = 0
					begin_smart_move_to(target_atom, peaceful = TRUE)
					return

			var/mob/living/dest_mob = action_escort_dest_mob_ref?.resolve()
			if(dest_mob)
				if(owner.z == dest_mob.z && get_dist(owner, dest_mob) <= 2)
					owner.clear_path()
					owner.stop_pulling()
					owner.face_atom(dest_mob)
					wake_was_direct_speech = TRUE
					finish_action("Ты доставил [get_perceived_mob_name(target_atom)] к [get_perceived_mob_name(dest_mob)]! Пора доложить о случившемся.", wake_brain = TRUE)
					return
				if(!length(owner.myPath) && world.time >= action_last_repath_at + 2 SECONDS)
					step_escort_to_destination()
				return

			if(action_dest_loc)
				if(action_dest_loc.area_ref && get_area(owner) == action_dest_loc.area_ref && owner.z == action_dest_loc.z_level)
					owner.clear_path()
					owner.stop_pulling()
					wake_was_direct_speech = TRUE
					finish_action("Ты доставил [get_perceived_mob_name(target_atom)] в «[action_dest_loc.name]» и отпустил там.", wake_brain = TRUE)
					return
				if(!length(owner.myPath) && world.time >= action_last_repath_at + 2 SECONDS)
					step_escort_to_destination()

		if(LLM_ACTION_GO_SLEEP)
			if(istype(target_atom, /obj/structure/bed))
				if(owner.Adjacent(target_atom))
					owner.clear_path()
					complete_sleep_on_bed(target_atom)
				else
					check_stuck_and_repath(target_atom, peaceful = TRUE)
			else if(action_dest_loc)
				// Walk to bedroom area, then locate a free bed!
				if(action_dest_loc.area_ref && get_area(owner) == action_dest_loc.area_ref && owner.z == action_dest_loc.z_level)
					var/obj/structure/bed/B = find_free_bed_nearby(7)
					if(B)
						action_target_ref = WEAKREF(B)
						action_dest_loc = null
						begin_smart_move_to(B, peaceful = TRUE)
					else
						finish_action("В комнате нет свободной кровати.", wake_brain = TRUE)
				else if(!length(owner.myPath) && world.time >= action_last_repath_at + 2 SECONDS)
					step_toward_location_3d(action_dest_loc)
			else
				finish_action("Не нашёл свободную кровать.")

		if(LLM_ACTION_INTERACT)
			if(!target_atom || QDELETED(target_atom))
				owner.clear_path()
				finish_action("Объект исчез.", wake_brain = TRUE)
				return
			if(owner.Adjacent(target_atom))
				owner.clear_path()
				perform_interact(target_atom)
				return
			check_stuck_and_repath(target_atom, peaceful = TRUE)

/datum/llm_npc_brain/proc/finish_action(outcome_text, wake_brain = FALSE)
	last_action_outcome = outcome_text
	if(length(outcome_text))
		push_event("ИТОГ ДЕЙСТВИЯ: [outcome_text]")
	active_action = LLM_ACTION_IDLE
	action_target_ref = null
	action_dest_loc = null
	action_active_stair = null
	action_escort_dest_mob_ref = null
	action_move_dest_ref = null
	action_arg = ""
	action_stage = 0
	action_stuck_strikes = 0
	if(wake_brain)
		schedule_wake(2, 10, "action_completed")

// ============================================================================
// 3D Multi-Z Navigation, Table Avoidance & Door Etiquette (Open + Close Behind!)
// ============================================================================

/datum/llm_npc_brain/proc/ensure_unbuckled()
	if(owner.buckled)
		owner.buckled.unbuckle_mob(owner)

/// Pathfinding wrapper:
/// - peaceful = TRUE: uses llm_reachable_peaceful (avoids climbing onto tables/furniture!)
/// - peaceful = FALSE: uses full reachableTurftest3d (allows vaulting railings/obstacles in pursuit!)
/datum/llm_npc_brain/proc/begin_smart_move_to(atom/dest, peaceful = TRUE, sprint = FALSE)
	if(!dest || !owner)
		return FALSE
	owner.m_intent = sprint ? MOVE_INTENT_RUN : MOVE_INTENT_WALK
	owner.clear_path()
	action_last_repath_at = world.time
	var/turf/target_t = get_turf(dest)
	if(!target_t)
		return FALSE

	var/const/MAX_RANGE_FIND = 32
	owner.pathfinding_target = dest
	owner.is_currently_pathing = TRUE
	var/list/path = null
	if(peaceful)
		path = get_path_to(owner, target_t, TYPE_PROC_REF(/turf, Heuristic_cardinal_3d), MAX_RANGE_FIND + 1, 250, 1, adjacent = TYPE_PROC_REF(/turf, llm_reachable_peaceful))
	// Fallback to full 3D path (with climbables) only if peaceful path was completely boxed in or we are chasing
	if(!length(path))
		path = get_path_to(owner, target_t, TYPE_PROC_REF(/turf, Heuristic_cardinal_3d), MAX_RANGE_FIND + 1, 250, 1, adjacent = TYPE_PROC_REF(/turf, reachableTurftest3d))
	owner.is_currently_pathing = FALSE

	if(length(path))
		path -= get_turf(owner)
		owner.myPath = path
		owner.pathing_frustration = 0
		return TRUE
	return FALSE

/// Multi-Z + multi-hop navigation to any /datum/llm_location_info across floors & distances!
/datum/llm_npc_brain/proc/step_toward_location_3d(datum/llm_location_info/dest_info)
	if(!dest_info)
		return FALSE
	// 1) Different Z-level? Route to nearest stairs stepping toward dest_info.z_level!
	if(dest_info.z_level && dest_info.z_level != owner.z)
		var/datum/llm_stair_link/st_link = SSllm_npc.find_stairs_for_z_step(get_turf(owner), dest_info.z_level)
		if(!st_link)
			return FALSE
		var/obj/structure/stairs/S = st_link.stair_ref?.resolve()
		if(!S)
			return FALSE
		action_active_stair = st_link
		return step_toward_turf_multihop(get_turf(S), peaceful = TRUE)

	// 2) Same Z-level: resolve landmark or walkable area turf
	action_active_stair = null
	var/turf/goal_turf = SSllm_npc.resolve_location_turf(dest_info, owner.z)
	if(!goal_turf)
		return FALSE
	return step_toward_turf_multihop(goal_turf, peaceful = TRUE)

/datum/llm_npc_brain/proc/step_toward_turf_multihop(turf/goal_turf, peaceful = TRUE)
	if(!goal_turf)
		return FALSE
	if(get_dist(owner, goal_turf) > 26 && goal_turf.z == owner.z)
		var/dx = goal_turf.x - owner.x
		var/dy = goal_turf.y - owner.y
		var/max_d = max(abs(dx), abs(dy), 1)
		var/wx = clamp(owner.x + round(dx * 20 / max_d), 1, world.maxx)
		var/wy = clamp(owner.y + round(dy * 20 / max_d), 1, world.maxy)
		var/turf/mid = find_open_turf_near(wx, wy, owner.z, 4)
		if(mid)
			return begin_smart_move_to(mid, peaceful = peaceful)
	return begin_smart_move_to(goal_turf, peaceful = peaceful)

/// Traverses a staircase once the NPC stands on or adjacent to the active stair link.
/datum/llm_npc_brain/proc/try_traverse_active_stair()
	if(!action_active_stair)
		return FALSE
	var/obj/structure/stairs/S = action_active_stair.stair_ref?.resolve()
	if(!S)
		action_active_stair = null
		return FALSE
	if(owner.z == action_active_stair.to_z)
		action_active_stair = null
		return FALSE
	if(get_turf(owner) == get_turf(S) || owner.Adjacent(S))
		owner.clear_path()
		if(get_turf(owner) != get_turf(S))
			owner.Move(get_turf(S))
		if(get_turf(owner) == get_turf(S))
			S.user_walk_into_target_loc(owner, action_active_stair.move_dir)
			action_active_stair = null
			action_last_repath_at = world.time
			return TRUE
	return FALSE

/datum/llm_npc_brain/proc/step_escort_to_destination()
	var/mob/living/dest_mob = action_escort_dest_mob_ref?.resolve()
	if(dest_mob)
		if(dest_mob.z != owner.z)
			var/datum/llm_stair_link/sl = SSllm_npc.find_stairs_for_z_step(get_turf(owner), dest_mob.z)
			if(sl?.stair_ref?.resolve())
				action_active_stair = sl
				return step_toward_turf_multihop(get_turf(sl.stair_ref.resolve()), peaceful = TRUE)
		return step_toward_turf_multihop(get_turf(dest_mob), peaceful = TRUE)
	if(action_dest_loc)
		return step_toward_location_3d(action_dest_loc)
	return FALSE

/datum/llm_npc_brain/proc/find_open_turf_near(cx, cy, cz, radius = 3)
	var/turf/center = locate(cx, cy, cz)
	if(center && isopenturf(center) && !center.density && !istransparentturf(center) && !(locate(/obj/structure/table) in center))
		return center
	for(var/turf/open/T in range(radius, center))
		if(!T.density && !istransparentturf(T) && !(locate(/obj/structure/table) in T))
			return T
	return null

/// Open-territory wandering (optional directional hint like "north", "south 3", "east", "west").
/datum/llm_npc_brain/proc/pick_open_walkable_turf(dir_hint = "")
	var/hint_dir = 0
	var/want_steps = rand(3, 5)
	if(length(dir_hint))
		var/ld = llm_lower_ru(dir_hint)
		if(findtext(ld, "north") || findtext(ld, "север"))
			hint_dir |= NORTH
		if(findtext(ld, "south") || findtext(ld, "юг"))
			hint_dir |= SOUTH
		if(findtext(ld, "east") || findtext(ld, "восток"))
			hint_dir |= EAST
		if(findtext(ld, "west") || findtext(ld, "запад"))
			hint_dir |= WEST

	if(hint_dir)
		var/turf/cur = get_turf(owner)
		var/turf/best = null
		for(var/i in 1 to want_steps)
			var/turf/next_t = get_step(cur, hint_dir)
			if(!next_t || next_t.density || istransparentturf(next_t) || (locate(/obj/structure/table) in next_t))
				break
			var/obj/structure/mineral_door/D = locate() in next_t
			if(D && D.locked)
				break
			best = next_t
			cur = next_t
		if(best)
			return best

	var/list/candidates = list()
	for(var/turf/open/T in view(6, owner))
		if(T.density || istransparentturf(T) || !T.can_traverse_safely(owner))
			continue
		if(locate(/obj/structure/table) in T)
			continue
		var/obj/structure/mineral_door/D = locate() in T
		if(D && D.locked)
			continue
		var/d = get_dist(owner, T)
		if(d >= 2 && d <= 6)
			candidates += T
	return length(candidates) ? pick(candidates) : null

/datum/llm_npc_brain/proc/check_stuck_and_repath(atom/target_atom, peaceful = TRUE)
	var/turf/cur = get_turf(owner)
	if(cur == action_last_turf)
		action_stuck_strikes++
	else
		action_stuck_strikes = 0
		action_last_turf = cur

	if(action_stuck_strikes >= 5)
		owner.clear_path()
		finish_action("Путь к [llm_clean_text(target_atom.name, 40)] оказался заблокирован.", wake_brain = TRUE)
		return

	if(!length(owner.myPath) && world.time >= action_last_repath_at + 2 SECONDS)
		if(!begin_smart_move_to(target_atom, peaceful = peaceful))
			action_stuck_strikes += 2

/// Automatically opens closed unlocked (or keyed) doors along our path, AND remembers the door
/// so try_close_passed_door() closes it politely behind us once we step through!
/datum/llm_npc_brain/proc/try_open_blocking_door()
	if(!length(owner.myPath))
		return
	var/turf/next_t = owner.myPath[1]
	if(!next_t || !owner.Adjacent(next_t))
		return
	var/obj/structure/mineral_door/D = locate() in next_t
	if(!D || D.door_opened || D.isSwitchingStates)
		return
	if(D.locked)
		var/obj/item/roguekey/K = find_matching_key(D.lockid, D.lockhash)
		if(K)
			D.attackby(K, owner)
		else
			owner.clear_path()
			finish_action("Дверь «[llm_clean_text(D.name, 35)]» заперта, подходящего ключа нет.", wake_brain = TRUE)
			return
	if(!D.locked && !D.door_opened)
		D.Open(user = owner)
		last_opened_door_ref = WEAKREF(D)

/// Closes a door we opened right behind us once we have stepped cleanly off its tile!
/datum/llm_npc_brain/proc/try_close_passed_door()
	if(!last_opened_door_ref)
		return
	var/obj/structure/mineral_door/D = last_opened_door_ref.resolve()
	if(!D || QDELETED(D) || !D.door_opened)
		last_opened_door_ref = null
		return
	// Don't bother closing doors if sprinting/fleeing/chasing
	if(owner.mode == NPC_AI_HUNT || owner.mode == NPC_AI_FLEE || active_action == LLM_ACTION_CHASE)
		last_opened_door_ref = null
		return
	var/turf/door_t = get_turf(D)
	if(!door_t || owner.z != door_t.z)
		last_opened_door_ref = null
		return
	// Still standing on the doorway or waiting to step into it
	if(get_turf(owner) == door_t)
		return
	if(length(owner.myPath) && owner.myPath[1] == door_t)
		return
	// Wait until anyone we're pulling is also past the door
	if(owner.pulling && get_turf(owner.pulling) == door_t)
		return
	if(get_dist(owner, D) == 1)
		// Don't slam the door on another living mob standing in the doorway
		if(!(locate(/mob/living) in door_t))
			D.Close(user = owner)
		last_opened_door_ref = null
	else if(get_dist(owner, D) > 2)
		last_opened_door_ref = null

// ============================================================================
// Weapons, Archery (with Arc-Shot Over Allies!), Restraining & Bribes
// ============================================================================

/datum/llm_npc_brain/proc/try_draw_best_weapon(prefer_bow = FALSE, query = "", silent = FALSE)
	var/obj/item/cur = owner.get_active_held_item()
	if(cur && ((prefer_bow && istype(cur, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)) || (!prefer_bow && istype(cur, /obj/item/rogueweapon))))
		return cur

	var/q = llm_lower_ru(trim(query))
	var/obj/item/best = null
	for(var/obj/item/I in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
		if(length(q) && findtext(llm_lower_ru(I.name), q))
			best = I
			break
		if(prefer_bow && istype(I, /obj/item/gun/ballistic/revolver/grenadelauncher/bow))
			best = I
			break
		if(!prefer_bow && istype(I, /obj/item/rogueweapon))
			if(!best || I.force > best.force)
				best = I
		// Check inside worn sheaths/bags too
		if(istype(I, /obj/item/storage))
			for(var/obj/item/sub in I.contents)
				if(length(q) && findtext(llm_lower_ru(sub.name), q))
					best = sub
					break
				if(prefer_bow && istype(sub, /obj/item/gun/ballistic/revolver/grenadelauncher/bow))
					best = sub
					break
				if(!prefer_bow && istype(sub, /obj/item/rogueweapon) && (!best || sub.force > best.force))
					best = sub

	if(!best)
		return null
	if(cur && cur != best)
		cur.equip_to_best_slot(owner)
	if(owner.put_in_hands(best))
		if(prefer_bow)
			var/obj/item/off = owner.get_inactive_held_item()
			if(off)
				off.equip_to_best_slot(owner)
		if(!silent)
			execute_llm_emote("выхватывает [llm_clean_text(best.name, 30)]")
		return best
	return null

/datum/llm_npc_brain/proc/perform_sheathe_weapons()
	var/stowed_any = FALSE
	var/obj/item/rh = owner.get_active_held_item()
	if(rh && (istype(rh, /obj/item/rogueweapon) || istype(rh, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)))
		if(rh.equip_to_best_slot(owner))
			stowed_any = TRUE
	var/obj/item/lh = owner.get_inactive_held_item()
	if(lh && (istype(lh, /obj/item/rogueweapon) || istype(lh, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)))
		if(lh.equip_to_best_slot(owner))
			stowed_any = TRUE
	if(stowed_any)
		execute_llm_emote("убирает оружие")
	return stowed_any

/// Archery: draws bow, frees offhand, nocks an arrow from quiver/inventory, checks line of fire
/// for allies, and automatically switches to Ratwood's native ARC SHOT (rog_intent_change(2))
/// to shoot cleanly over allies' heads!
/datum/llm_npc_brain/proc/perform_archery_shot(mob/living/target_mob)
	var/obj/item/gun/ballistic/revolver/grenadelauncher/bow/bow = owner.get_active_held_item()
	if(!istype(bow))
		bow = try_draw_best_weapon(prefer_bow = TRUE, silent = FALSE)
	if(!istype(bow))
		finish_action("У тебя нет лука для стрельбы.", wake_brain = TRUE)
		return

	// Must have inactive hand free to draw a bow!
	var/obj/item/off = owner.get_inactive_held_item()
	if(off && !off.equip_to_best_slot(owner))
		owner.dropItemToGround(off)

	// Nock an arrow if chamber is empty
	if(!bow.chambered)
		var/obj/item/ammo_casing/caseless/rogue/arrow/arrow = find_arrow_for_bow()
		if(!arrow)
			finish_action("Закончились стрелы!", wake_brain = TRUE)
			return
		bow.attackby(arrow, owner)
		if(!bow.chambered)
			finish_action("Не удалось наложить стрелу на тетиву.", wake_brain = TRUE)
			return

	// Check line of fire for friendly/bystander mobs!
	var/ally_in_line = FALSE
	var/list/line_turfs = getline(get_turf(owner), get_turf(target_mob))
	for(var/turf/LT in line_turfs)
		if(LT == get_turf(owner) || LT == get_turf(target_mob))
			continue
		for(var/mob/living/bystander in LT)
			if(bystander != owner && bystander != target_mob && bystander.stat != DEAD && (bystander.mobility_flags & MOBILITY_STAND))
				ally_in_line = TRUE
				break
		if(ally_in_line)
			break

	var/dist = get_dist(owner, target_mob)
	// If ally is standing right in front (< 3 tiles), sidestep laterally first for a safe shot
	if(ally_in_line && dist < 3)
		var/side_dir = turn(get_dir(owner, target_mob), pick(90, -90))
		var/turf/side_t = get_step(owner, side_dir)
		if(side_t && !side_t.density && !(locate(/obj/structure/table) in side_t))
			step(owner, side_dir)

	owner.face_atom(target_mob)
	// Intent 2 = /datum/intent/arc/bow (shoot in an arc over allies' heads!); Intent 1 = direct shot
	if(ally_in_line)
		owner.rog_intent_change(2)
		execute_llm_emote("натягивает лук навесом поверх голов, целясь в [get_perceived_mob_name(target_mob)]")
	else
		owner.rog_intent_change(1)
		execute_llm_emote("натягивает тетиву, целясь в [get_perceived_mob_name(target_mob)]")

	owner.used_intent = owner.a_intent
	last_weapon_used_at = world.time
	bow.process_fire(target_mob, owner, TRUE)
	finish_action("Ты выстрелил из лука [ally_in_line ? "навесом поверх союзников " : ""]в [get_perceived_mob_name(target_mob)]!", wake_brain = TRUE)

/datum/llm_npc_brain/proc/find_arrow_for_bow()
	for(var/obj/item/I in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
		if(istype(I, /obj/item/ammo_casing/caseless/rogue/arrow))
			return I
		if(istype(I, /obj/item/quiver) || istype(I, /obj/item/storage))
			var/obj/item/ammo_casing/caseless/rogue/arrow/A = locate() in I.contents
			if(A)
				return A
	return null

/datum/llm_npc_brain/proc/perform_restrain(mob/living/carbon/human/target_human)
	owner.face_atom(target_human)
	var/obj/item/rope/R = find_owned_type(/obj/item/rope)
	if(!R)
		// No rope -> grab and hold them instead!
		owner.start_pulling(target_human)
		finish_action("Верёвки нет, поэтому ты крепко схватил [get_perceived_mob_name(target_human)]!", wake_brain = TRUE)
		return
	if(R != owner.get_active_held_item())
		var/obj/item/cur = owner.get_active_held_item()
		if(cur)
			cur.equip_to_best_slot(owner)
		owner.put_in_hands(R)
	// Set exact Ratwood rope tying intent & arm aimheight
	owner.aimheight = 10
	owner.used_intent = new /datum/intent/tie
	INVOKE_ASYNC(R, TYPE_PROC_REF(/obj/item/rope, attack), target_human, owner)
	finish_action("Ты начал связывать руки [get_perceived_mob_name(target_human)] при помощи [llm_clean_text(R.name, 30)].", wake_brain = TRUE)

/datum/llm_npc_brain/proc/perform_accept_offer()
	var/mob/living/giver = pending_offer_giver_ref?.resolve()
	var/obj/item/item_offered = pending_offer_item_ref?.resolve()
	var/stealthy = pending_offer_stealthy
	pending_offer_giver_ref = null
	pending_offer_item_ref = null
	pending_offer_stealthy = FALSE

	if(!giver || !item_offered || get_dist(owner, giver) > 2 || giver.offered_item_ref?.resolve() != item_offered)
		finish_action("Предложение уже неактуально — человек убрал руку или отошёл.")
		return

	owner.face_atom(giver)
	// Ensure active hand is free for try_accept_offered_item()!
	var/obj/item/cur = owner.get_active_held_item()
	if(cur)
		if(!owner.get_inactive_held_item())
			owner.swap_hand()
		else if(!cur.equip_to_best_slot(owner))
			owner.dropItemToGround(cur)

	if(owner.try_accept_offered_item(giver, item_offered, stealthy))
		var/datum/llm_relationship/rel = get_or_create_relationship(giver)
		rel.trust = clamp(rel.trust + 12, -100, 100)
		if(istype(item_offered, /obj/item/roguecoin))
			drive_greed = max(0, drive_greed - 25)
			adjust_emotions(d_valence = 12)
			rel.add_note("[stealthy ? "Дал взятку" : "Заплатил монеты"]: [llm_clean_text(item_offered.name, 30)].")
		else
			rel.add_note("Передал мне [llm_clean_text(item_offered.name, 30)].")
		finish_action("Ты принял [stealthy ? "тайком " : ""][llm_clean_text(item_offered.name, 36)] от [rel.known_name].", wake_brain = TRUE)
	else
		finish_action("Не удалось принять предмет (руки заняты).", wake_brain = TRUE)

/datum/llm_npc_brain/proc/perform_refuse_offer()
	var/mob/living/giver = pending_offer_giver_ref?.resolve()
	pending_offer_giver_ref = null
	pending_offer_item_ref = null
	pending_offer_stealthy = FALSE
	if(giver && (giver in view(5, owner)))
		owner.face_atom(giver)
		execute_llm_emote("отрицательно качает головой и отводит руку [get_perceived_mob_name(giver)]")
	finish_action("Ты отказался принимать предложенный предмет.")

// ============================================================================
// Eating (Plates/Tables/Handheld), Drinking, Smoking & Medical Care
// ============================================================================

/datum/llm_npc_brain/proc/perform_or_start_eat_drink(atom/resolved, arg_str)
	var/obj/item/consumable = null
	if(isitem(resolved) && (istype(resolved, /obj/item/reagent_containers/food/snacks) || istype(resolved, /obj/item/reagent_containers/glass)))
		consumable = resolved
	if(!consumable)
		consumable = find_owned_item(arg_str, search_worn = TRUE)
		if(consumable && !istype(consumable, /obj/item/reagent_containers))
			consumable = null
	if(!consumable)
		consumable = find_owned_type(/obj/item/reagent_containers/food/snacks) || find_owned_type(/obj/item/reagent_containers/glass)
	if(!consumable)
		// Check visible plates/food/drinks on nearby tables or floor!
		for(var/obj/item/reagent_containers/RC in view(5, owner))
			if(!isturf(RC.loc))
				continue
			if(length(arg_str) && !findtext(llm_lower_ru(RC.name), llm_lower_ru(arg_str)))
				continue
			consumable = RC
			break

	if(!consumable)
		finish_action("Рядом и в карманах нет еды или напитков.")
		return

	action_target_ref = WEAKREF(consumable)
	if(consumable.loc == owner || owner.Adjacent(consumable))
		consume_item(consumable)
	else
		ensure_unbuckled()
		begin_smart_move_to(consumable, peaceful = TRUE)

/datum/llm_npc_brain/proc/consume_item(obj/item/consumable)
	if(!consumable || QDELETED(consumable))
		finish_action("Еда или напиток исчезли.")
		return
	owner.face_atom(consumable)
	// Eating directly from a table/plate OR from hand!
	var/is_alcohol = consumable.reagents?.has_reagent(/datum/reagent/consumable/ethanol)
	var/is_food = istype(consumable, /obj/item/reagent_containers/food/snacks)
	var/on_table = isturf(consumable.loc) && (locate(/obj/structure/table) in consumable.loc)

	if(on_table && is_food)
		// Eat right off the plate/table without picking the whole dish up!
		consumable.attack(owner, owner)
		drive_hunger = max(0, drive_hunger - 30)
		adjust_emotions(d_valence = 8)
		finish_action("Ты поел прямо с тарелки/стола: [llm_clean_text(consumable.name, 36)].")
		return

	if(consumable.loc != owner)
		if(!owner.put_in_hands(consumable))
			// Fallback: consume in place if hands full
			consumable.attack(owner, owner)
	if(consumable.loc == owner)
		consumable.attack(owner, owner)

	if(is_food)
		drive_hunger = max(0, drive_hunger - 30)
		adjust_emotions(d_valence = 6)
		finish_action("Ты перекусил: [llm_clean_text(consumable.name, 36)].")
	else
		drive_thirst = max(0, drive_thirst - 30)
		if(is_alcohol)
			drive_alcohol = max(0, drive_alcohol - 35)
			adjust_emotions(d_valence = 12, d_fear = -10)
		finish_action("Ты выпил из [llm_clean_text(consumable.name, 36)][is_alcohol ? " (хмельное согрело душу)" : ""].")

/datum/llm_npc_brain/proc/perform_smoke(atom/resolved, arg_str)
	var/obj/item/clothing/mask/cigarette/cig = null
	if(istype(resolved, /obj/item/clothing/mask/cigarette))
		cig = resolved
	if(!cig && istype(owner.wear_mask, /obj/item/clothing/mask/cigarette))
		cig = owner.wear_mask
	if(!cig)
		cig = find_owned_type(/obj/item/clothing/mask/cigarette)
	if(!cig)
		finish_action("У тебя нет курева (самокрутки или трубки).")
		return

	if(!cig.lit)
		var/obj/item/match/M = find_owned_type(/obj/item/match)
		if(M)
			if(!M.lit)
				M.matchignite()
			cig.light()
		else
			// Check for nearby fire/hearth/lit candle to light from!
			var/found_fire = FALSE
			for(var/obj/O in view(2, owner))
				if(O.light_power >= 2)
					found_fire = TRUE
					break
			if(found_fire)
				cig.light()
			else
				finish_action("Курево есть, но нет спичек или огня, чтобы прикурить.")
				return

	if(cig != owner.wear_mask)
		owner.equip_to_slot_if_possible(cig, SLOT_MOUTH, disable_warning = TRUE)
	drive_smoke = max(0, drive_smoke - 40)
	adjust_emotions(d_valence = 8, d_fear = -8, d_anger = -8)
	execute_llm_emote("затягивается дымом и медленно выдыхает")
	finish_action("Ты закурил [llm_clean_text(cig.name, 32)] и немного расслабился.")

/datum/llm_npc_brain/proc/perform_heal(mob/living/patient, tool_hint = "")
	if(patient != owner)
		owner.face_atom(patient)
	var/lh = llm_lower_ru(trim(tool_hint))

	// Priority: explicit hint -> bandage -> needle -> potion/drink!
	var/obj/item/med = null
	if(findtext(lh, "игол") || findtext(lh, "needle") || findtext(lh, "шв"))
		med = find_owned_type(/obj/item/needle)
	else if(findtext(lh, "бинт") || findtext(lh, "тряп") || findtext(lh, "bandag") || findtext(lh, "cloth"))
		med = find_owned_type(/obj/item/natural/cloth/bandage) || find_owned_type(/obj/item/natural/cloth)
	else if(findtext(lh, "вод") || findtext(lh, "зел") || findtext(lh, "potion") || findtext(lh, "water") || findtext(lh, "drink"))
		med = find_owned_type(/obj/item/reagent_containers/glass)

	if(!med)
		med = find_owned_type(/obj/item/natural/cloth/bandage) || find_owned_type(/obj/item/needle) || find_owned_type(/obj/item/natural/cloth) || find_owned_type(/obj/item/reagent_containers/glass)

	if(!med)
		finish_action("У тебя нет бинтов, иглы, зелья или воды для помощи.")
		return

	if(med != owner.get_active_held_item())
		var/obj/item/cur = owner.get_active_held_item()
		if(cur)
			cur.equip_to_best_slot(owner)
		owner.put_in_hands(med)

	if(istype(med, /obj/item/natural/cloth))
		var/obj/item/natural/cloth/CL = med
		INVOKE_ASYNC(CL, TYPE_PROC_REF(/obj/item/natural/cloth, attack), patient, owner)
		finish_action("Ты перевязал [patient == owner ? "себя" : get_perceived_mob_name(patient)] при помощи [llm_clean_text(CL.name, 32)].", wake_brain = TRUE)
	else if(istype(med, /obj/item/needle))
		var/obj/item/needle/ND = med
		INVOKE_ASYNC(ND, TYPE_PROC_REF(/obj/item/needle, attack), patient, owner)
		finish_action("Ты начал зашивать раны [patient == owner ? "себе" : get_perceived_mob_name(patient)] иглой.", wake_brain = TRUE)
	else if(istype(med, /obj/item/reagent_containers/glass))
		med.attack(patient, owner)
		finish_action("Ты напоил [patient == owner ? "себя" : get_perceived_mob_name(patient)] из [llm_clean_text(med.name, 32)].", wake_brain = TRUE)

// ============================================================================
// Full Sleep Lifecycle: Walk to Bed -> Undress -> Lie Down -> Sleep -> Wake -> Dress!
// ============================================================================

/datum/llm_npc_brain/proc/find_free_bed_nearby(radius = 7)
	for(var/obj/structure/bed/B in view(radius, owner))
		if(!B.has_buckled_mobs())
			return B
	return null

/datum/llm_npc_brain/proc/start_sleep_routine(atom/resolved, arg_str)
	ensure_unbuckled()
	var/obj/structure/bed/B = istype(resolved, /obj/structure/bed) ? resolved : find_free_bed_nearby(7)
	if(B && !B.has_buckled_mobs())
		action_target_ref = WEAKREF(B)
		if(owner.Adjacent(B))
			complete_sleep_on_bed(B)
		else
			begin_smart_move_to(B, peaceful = TRUE)
		return
	// No bed right here: route to a known bedroom/inn/barracks area!
	var/datum/llm_location_info/bed_loc = SSllm_npc.find_location_info(length(arg_str) ? arg_str : "bedroom")
	if(!bed_loc)
		bed_loc = SSllm_npc.find_location_info("tavern")
	if(!bed_loc)
		finish_action("Поблизости нет свободной кровати для сна.")
		return
	action_dest_loc = bed_loc
	action_timeout_at = world.time + 55 SECONDS
	step_toward_location_3d(bed_loc)

/datum/llm_npc_brain/proc/complete_sleep_on_bed(obj/structure/bed/B)
	if(!B || B.has_buckled_mobs())
		finish_action("Кровать уже занята.")
		return
	// 1) Undress outer gear neatly onto the bed tile (remembering WEAKREFs to redress on wake!)
	removed_sleep_clothes.Cut()
	var/list/to_remove = list(owner.wear_armor, owner.cloak, owner.head, owner.belt, owner.shoes, owner.gloves)
	var/removed_count = 0
	for(var/obj/item/garment in to_remove)
		if(!garment)
			continue
		if(owner.dropItemToGround(garment))
			removed_sleep_clothes += WEAKREF(garment)
			removed_count++
	// Also stow any held items onto the bedside
	for(var/obj/item/held in list(owner.get_active_held_item(), owner.get_inactive_held_item()))
		if(held && owner.dropItemToGround(held))
			removed_sleep_clothes += WEAKREF(held)
			removed_count++

	if(removed_count > 0)
		execute_llm_emote("снимает верхнюю одежду и складывает её у кровати")

	// 2) Lie down on the bed and fall asleep!
	owner.Move(get_turf(B))
	B.buckle_mob(owner, check_loc = FALSE)
	owner.set_resting(TRUE, TRUE)
	owner.SetSleeping(240)
	sleep_bed_ref = WEAKREF(B)
	is_sleeping_by_plan = TRUE
	active_action = LLM_ACTION_IDLE
	push_event("СОН: Ты разделся у кровати, лёг и уснул.")

/datum/llm_npc_brain/proc/wake_up_from_sleep(reason_text = "Ты проснулся.", skip_dress = FALSE)
	if(!is_sleeping_by_plan)
		return
	is_sleeping_by_plan = FALSE
	owner.SetSleeping(0, FALSE)
	owner.set_resting(FALSE, TRUE)
	ensure_unbuckled()
	if(!(owner.mobility_flags & MOBILITY_STAND))
		owner.npc_stand()

	// Pick up and put back on every garment we removed before sleeping!
	var/dressed_count = 0
	if(!skip_dress && length(removed_sleep_clothes))
		for(var/datum/weakref/wr as anything in removed_sleep_clothes)
			var/obj/item/garment = wr?.resolve()
			if(!garment || QDELETED(garment) || !isturf(garment.loc) || get_dist(owner, garment) > 2)
				continue
			if(garment.equip_to_best_slot(owner))
				dressed_count++
			else if(owner.put_in_hands(garment))
				dressed_count++
		if(dressed_count > 0)
			execute_llm_emote("поднимается с кровати, потягивается и одевается")
	removed_sleep_clothes.Cut()
	sleep_bed_ref = null

	push_event("ПРОБУЖДЕНИЕ: [reason_text][dressed_count > 0 ? " Ты снова оделся." : ""]")
	schedule_wake(2, 12, "woke_up")

// ============================================================================
// Object Relocation, Examine (Native Acquaintances!), Pickup, Give, Interact
// ============================================================================

/datum/llm_npc_brain/proc/advance_move_item(atom/target_atom)
	var/atom/dest = action_move_dest_ref?.resolve()
	if(!dest)
		finish_action("Некуда перемещать.")
		return
	if(isitem(target_atom))
		if(!owner.put_in_hands(target_atom))
			finish_action("Не удалось взять [llm_clean_text(target_atom.name, 35)] в руки.")
			return
	else if(ismovable(target_atom))
		owner.start_pulling(target_atom)
	action_stage = 1
	if(owner.Adjacent(dest))
		finish_move_item(target_atom, dest)
	else
		begin_smart_move_to(dest, peaceful = TRUE)

/datum/llm_npc_brain/proc/finish_move_item(atom/target_atom, atom/dest_atom)
	var/turf/dest_t = get_turf(dest_atom)
	if(isitem(target_atom) && target_atom.loc == owner)
		var/obj/item/moved_item = target_atom
		if(owner.dropItemToGround(moved_item))
			if(dest_t && owner.Adjacent(dest_t))
				moved_item.forceMove(dest_t)
			execute_llm_emote("переставляет [llm_clean_text(moved_item.name, 32)] на [llm_clean_text(dest_atom.name, 32)]")
			finish_action("Ты перенёс [llm_clean_text(moved_item.name, 35)] к [llm_clean_text(dest_atom.name, 35)].")
			return
	else if(owner.pulling == target_atom)
		owner.stop_pulling()
		finish_action("Ты передвинул [llm_clean_text(target_atom.name, 35)].")
		return
	finish_action("Не удалось завершить перемещение.")

/// Runs Ratwood's native examine(owner):
/// - Automatically triggers on_examine_face -> owner.mind.i_know_person(H) if unmasked!
/// - Reveals blood-stained hands/clothes, bleeding wounds, embedded weapons, Crown/Church debtor status, traits!
/datum/llm_npc_brain/proc/perform_detailed_examine(atom/target_atom)
	owner.face_atom(target_atom)
	var/list/ex_lines = target_atom.examine(owner)
	var/joined = islist(ex_lines) ? llm_clean_text(jointext(ex_lines, " | "), 520) : llm_clean_text("[ex_lines]", 520)

	if(ishuman(target_atom))
		var/mob/living/carbon/human/H = target_atom
		var/datum/llm_relationship/rel = get_or_create_relationship(H)
		rel.examined = TRUE
		// Sync acquainted name & job if Ratwood's examine registered them in mind.known_people!
		if(is_acquainted_with(H) && H.get_face_name() == H.real_name)
			rel.known_name = llm_clean_text(H.real_name, 50)
			var/list/kp = owner.mind.known_people[H.real_name]
			if(islist(kp) && length(kp["FJOB"]) && kp["FJOB"] != "unknown")
				rel.perceived_role = kp["FJOB"]
		// Flag obvious danger/suspicion cues from examine text
		var/lex = llm_lower_ru(joined)
		if(findtext(lex, "blood") || findtext(lex, "bleed") || findtext(lex, "debtor"))
			adjust_emotions(d_suspicion = 15)
		last_examine_report = "Детальный осмотр [rel.known_name] (\[[rel.entity_id]\]): [joined]"
	else
		last_examine_report = "Детальный осмотр [llm_clean_text(target_atom.name, 40)]: [joined]"

	push_event(last_examine_report)
	finish_action("Ты внимательно осмотрел [llm_clean_text(target_atom.name, 40)].", wake_brain = TRUE)

/datum/llm_npc_brain/proc/find_matching_key(target_lockid, target_lockhash)
	for(var/obj/item/roguekey/K in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
		if((target_lockid && K.lockid == target_lockid) || (target_lockhash && K.lockhash == target_lockhash))
			return K
	for(var/obj/item/held in list(owner.get_active_held_item(), owner.get_inactive_held_item()))
		if(istype(held, /obj/item/roguekey))
			var/obj/item/roguekey/RK = held
			if((target_lockid && RK.lockid == target_lockid) || (target_lockhash && RK.lockhash == target_lockhash))
				return RK
	return null

/datum/llm_npc_brain/proc/find_owned_type(typepath)
	for(var/obj/item/held in list(owner.get_active_held_item(), owner.get_inactive_held_item()))
		if(istype(held, typepath))
			return held
	for(var/obj/item/I in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
		if(istype(I, typepath))
			return I
		if(istype(I, /obj/item/storage))
			var/obj/item/found = locate(typepath) in I.contents
			if(found)
				return found
	return null

/datum/llm_npc_brain/proc/find_owned_item(query, search_worn = FALSE)
	var/q = llm_lower_ru(trim(query))
	var/obj/item/rh = owner.get_active_held_item()
	var/obj/item/lh = owner.get_inactive_held_item()
	if(!length(q))
		return rh || lh
	if(rh && findtext(llm_lower_ru(rh.name), q))
		return rh
	if(lh && findtext(llm_lower_ru(lh.name), q))
		return lh
	if(search_worn)
		for(var/obj/item/I in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
			if(findtext(llm_lower_ru(I.name), q))
				return I
			if(istype(I, /obj/item/storage))
				for(var/obj/item/sub in I.contents)
					if(findtext(llm_lower_ru(sub.name), q))
						return sub
	return null

/datum/llm_npc_brain/proc/perform_pickup(obj/item/I)
	owner.face_atom(I)
	if(owner.get_active_held_item() && owner.get_inactive_held_item())
		var/obj/item/off = owner.get_inactive_held_item()
		off.equip_to_best_slot(owner)
	if(owner.put_in_hands(I))
		if(istype(I, /obj/item/roguecoin))
			drive_greed = max(0, drive_greed - 15)
			adjust_emotions(d_valence = 8)
		finish_action("Ты подобрал [llm_clean_text(I.name, 40)].", wake_brain = TRUE)
	else
		finish_action("Не удалось подобрать [llm_clean_text(I.name, 40)] (заняты руки или предмет тяжёлый).", wake_brain = TRUE)

/datum/llm_npc_brain/proc/perform_give_item(mob/living/carbon/human/recipient, obj/item/gift)
	owner.face_atom(recipient)
	if(recipient.put_in_hands(gift))
		execute_llm_emote("протягивает [llm_clean_text(gift.name, 35)] [get_perceived_mob_name(recipient)]")
		finish_action("Ты передал [llm_clean_text(gift.name, 40)] в руки [get_perceived_mob_name(recipient)].", wake_brain = TRUE)
	else if(owner.dropItemToGround(gift))
		execute_llm_emote("кладет [llm_clean_text(gift.name, 35)] перед [get_perceived_mob_name(recipient)]")
		finish_action("Руки [get_perceived_mob_name(recipient)] заняты, ты положил [llm_clean_text(gift.name, 40)] рядом.", wake_brain = TRUE)
	else
		finish_action("Не удалось передать [llm_clean_text(gift.name, 40)].", wake_brain = TRUE)

/datum/llm_npc_brain/proc/perform_interact(atom/target_atom)
	owner.face_atom(target_atom)

	// 1) Stairs (explicit climb up/down!)
	if(istype(target_atom, /obj/structure/stairs))
		var/obj/structure/stairs/ST = target_atom
		owner.Move(get_turf(ST))
		var/want_down = findtext(llm_lower_ru(action_arg), "вниз") || findtext(llm_lower_ru(action_arg), "down")
		var/move_d = want_down ? REVERSE_DIR(ST.dir) : ST.dir
		if(!ST.get_target_loc(move_d))
			move_d = REVERSE_DIR(move_d)
		if(ST.get_target_loc(move_d))
			ST.user_walk_into_target_loc(owner, move_d)
			finish_action("Ты прошёл по лестнице на другой этаж.", wake_brain = TRUE)
		else
			finish_action("Эта лестница никуда не ведёт.")
		return

	// 2) Doors (open / close / unlock with key)
	if(istype(target_atom, /obj/structure/mineral_door))
		var/obj/structure/mineral_door/D = target_atom
		if(D.locked)
			var/obj/item/roguekey/K = find_matching_key(D.lockid, D.lockhash)
			if(K)
				D.attackby(K, owner)
				finish_action("Ты применил ключ [llm_clean_text(K.name, 30)] к двери [llm_clean_text(D.name, 35)].", wake_brain = TRUE)
			else
				finish_action("Дверь [llm_clean_text(D.name, 35)] заперта, ключа нет.", wake_brain = TRUE)
			return
		if(D.door_opened)
			D.Close(user = owner)
			finish_action("Ты закрыл дверь [llm_clean_text(D.name, 35)].")
		else
			D.Open(user = owner)
			finish_action("Ты открыл дверь [llm_clean_text(D.name, 35)].")
		return

	// 3) Chairs & Beds
	if(istype(target_atom, /obj/structure/chair) || istype(target_atom, /obj/structure/bed))
		var/obj/structure/seat = target_atom
		if(owner.buckled == seat)
			seat.unbuckle_mob(owner)
			finish_action("Ты встал с [llm_clean_text(seat.name, 35)].")
			return
		if(seat.has_buckled_mobs())
			finish_action("[llm_clean_text(seat.name, 35)] уже занят.", wake_brain = TRUE)
			return
		owner.Move(get_turf(seat))
		if(seat.buckle_mob(owner, check_loc = FALSE))
			drive_fatigue = max(0, drive_fatigue - 10)
			finish_action("Ты устроился на [llm_clean_text(seat.name, 35)].")
		else
			finish_action("Не удалось сесть на [llm_clean_text(seat.name, 35)].")
		return

	// 4) Closets / Chests
	if(istype(target_atom, /obj/structure/closet))
		var/obj/structure/closet/C = target_atom
		if(C.locked)
			finish_action("[llm_clean_text(C.name, 35)] заперт.", wake_brain = TRUE)
			return
		if(C.opened)
			C.close(owner)
			finish_action("Ты закрыл [llm_clean_text(C.name, 35)].")
		else
			C.open(owner)
			finish_action("Ты открыл [llm_clean_text(C.name, 35)].", wake_brain = TRUE)
		return

	// 5) Generic interaction
	var/obj/item/held = owner.get_active_held_item()
	if(held)
		target_atom.attackby(held, owner)
	else
		target_atom.attack_hand(owner)
	finish_action("Ты повзаимодействовал с [llm_clean_text(target_atom.name, 40)].", wake_brain = TRUE)
