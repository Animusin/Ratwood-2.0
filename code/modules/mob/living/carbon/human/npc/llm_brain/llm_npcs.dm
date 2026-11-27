// Starter Ratwood LLM-driven Human NPCs (Drifter + Watchman preset) + Admin Management Verbs.

// ============================================================================
// Base Reusable LLM Human NPC (with native /datum/mind for mind.known_people!)
// ============================================================================

/mob/living/carbon/human/species/human/northern/npc_llm
	aggressive = 0
	rude = FALSE
	mode = NPC_AI_IDLE
	faction = list("station")
	ambushable = FALSE
	dodgetime = 3 SECONDS
	flee_in_pain = TRUE
	smart_combatant = TRUE
	special_attacker = FALSE
	possible_rmb_intents = list()
	wander = FALSE

	var/llm_job_name = "Странник"
	var/datum/outfit/llm_outfit_type = /datum/outfit/job/roguetown/vagrantnpc
	var/llm_custom_name = null

/mob/living/carbon/human/species/human/northern/npc_llm/Initialize(mapload)
	. = ..()
	set_species(/datum/species/human/northern)
	addtimer(CALLBACK(src, PROC_REF(after_creation)), 1 SECONDS)

/mob/living/carbon/human/species/human/northern/npc_llm/after_creation()
	..()
	job = llm_job_name
	ADD_TRAIT(src, TRAIT_NOMOOD, TRAIT_GENERIC)
	ADD_TRAIT(src, TRAIT_NOHUNGER, TRAIT_GENERIC)
	ADD_TRAIT(src, TRAIT_LEECHIMMUNE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_BREADY, TRAIT_GENERIC)
	// Ensure a real /datum/mind exists so Ratwood's native mind.known_people & i_know_person() work!
	if(!mind)
		mind = new /datum/mind(null)
		mind.current = src
	randomize_human(src, include_gender = FALSE)
	if(length(llm_custom_name))
		fully_replace_character_name(real_name, llm_custom_name)
	if(llm_outfit_type)
		equipOutfit(new llm_outfit_type)
	setup_llm_brain()
	handle_ai()

/mob/living/carbon/human/species/human/northern/npc_llm/proc/setup_llm_brain()
	if(llm_brain)
		return llm_brain
	llm_brain = new /datum/llm_npc_brain(src)
	configure_llm_persona(llm_brain)
	return llm_brain

/mob/living/carbon/human/species/human/northern/npc_llm/proc/configure_llm_persona(datum/llm_npc_brain/brain)
	brain.archetype = "Житель города"
	brain.social_standing = "простолюдин"

/mob/living/carbon/human/species/human/northern/npc_llm/should_target(mob/living/L)
	if(L.stat != CONSCIOUS)
		return FALSE
	return ..()

// ============================================================================
// Starter NPC #1: Бродяга-завсегдатай таверны (Drifter)
// ============================================================================

/mob/living/carbon/human/species/human/northern/npc_llm/drifter
	llm_job_name = "Бродяга"
	llm_outfit_type = /datum/outfit/job/roguetown/vagrantnpc

/mob/living/carbon/human/species/human/northern/npc_llm/drifter/after_creation()
	if(!length(llm_custom_name))
		llm_custom_name = pick("Корней", "Савва", "Гришка", "Еремка", "Фома", "Трофим")
	..()
	// Give basic everyday items so he can bandage himself, smoke, or pay/barter
	adjust_skillrank(/datum/skill/misc/climbing, 2, TRUE)
	adjust_skillrank(/datum/skill/combat/bows, 1, TRUE)
	new /obj/item/natural/cloth/bandage(src)

/mob/living/carbon/human/species/human/northern/npc_llm/drifter/configure_llm_persona(datum/llm_npc_brain/brain)
	brain.archetype = "Бывалый бродяга и завсегдатай таверны"
	brain.social_standing = "простолюдин без земли, живёт случайными заработками и слухами"
	brain.backstory = "Раньше ты ходил в охране купеческих обозов у границ Aavar и Gloomwood, пока не сбежал от боярской повинности с дырявым кошельком. Знаешь, чем пахнет беда, любишь тёплый очаг, кружку эля, самокрутку и свежие городские сплетни."
	brain.values = "Собственная шкура, звонкая монета, кружка выпивки, табак, человеческое тепло и хорошие истории. Уважаешь тех, кто угощает едой или честно платит за слухи."
	brain.fears = "Инквизиция, вооружённые дворяне в гневе, люди в масках с кровью на одежде, голодная ночь и тёмные переулки. Если прижмут всерьёз — предпочитаешь сбежать или сдаться живым."
	brain.flaws_and_quirks = "Чёрный юмор, привычка приглядываться к людям (examine_closer), тяга к выпивке и табаку, слабость к монетам и красивым собеседникам, ворчливость когда голоден или не выспался."
	brain.secrets = "Скрываешь, что когда-то дезертировал из боярского ополчения, и потому осторожничаешь перед стражей и знатью."
	brain.speech_style = "Живой, слегка хриплый, приземлённый русский простолюдина. Короткие фразы по делу, без книжной вычурности. Со стражей и знатью — сдержанно; с равными — проще, иногда язвительно или с тёплым флиртом."
	brain.long_term_goal = "Жить по городскому ритму: днём бродить и выведывать новости ради монеты или еды, вечером осесть в таверне выпить и покурить, ночью найти кровать и выспаться."
	brain.current_plan = "Осмотреться вокруг, прикинуть кто рядом и стоит ли приглядеться поближе."
	brain.drive_hunger = rand(25, 45)
	brain.drive_thirst = rand(25, 45)
	brain.drive_alcohol = rand(30, 55)
	brain.drive_smoke = rand(25, 50)
	brain.drive_social = rand(35, 60)
	brain.drive_greed = rand(40, 65)
	brain.drive_intimacy = rand(20, 45)

// ============================================================================
// Starter NPC #2: Городской стражник (Watchman — arrest, escort, bribes, bow!)
// ============================================================================

/mob/living/carbon/human/species/human/northern/npc_llm/watchman
	llm_job_name = "Townguard"
	llm_outfit_type = /datum/outfit/job/roguetown/guardsman/cityguard

/mob/living/carbon/human/species/human/northern/npc_llm/watchman/after_creation()
	if(!length(llm_custom_name))
		llm_custom_name = pick("Бронислав", "Ратмир", "Демид", "Влас", "Игнат", "Северин")
	..()
	adjust_skillrank(/datum/skill/misc/climbing, 2, TRUE)
	adjust_skillrank(/datum/skill/combat/bows, 3, TRUE)
	// Ensure rope & bandages for arresting and first aid!
	new /obj/item/rope(src)
	new /obj/item/natural/cloth/bandage(src)

/mob/living/carbon/human/species/human/northern/npc_llm/watchman/configure_llm_persona(datum/llm_npc_brain/brain)
	brain.archetype = "Городской стражник гарнизона"
	brain.social_standing = "служивый гарнизона, подчиняется Сержанту, Капитану стражи, Приставу и Лорду"
	brain.backstory = "Ты уже не первый год тянешь лямку в городской страже. Видел и пьяные драки в таверне, и воров на площади, и культистов в переулках. Служишь за жалование, ценишь порядок, но устал от бессонных смен и не прочь иногда закрыть глаза за щедрую взятку — если дело не касается убийства или измены."
	brain.values = "Порядок на улицах, дисциплина перед начальством, сохранность товарищей по гарнизону, тёплая еда, табак и звонкая монета."
	brain.fears = "Гнев Лорда или Инквизиции, засада в темноте, остаться одному против толпы вооружённых разбойников."
	brain.flaws_and_quirks = "Подозрителен к людям в масках и с кровью (всегда осматривает подозрительных через examine_closer), предпочитает сперва усмирить буяна нелетально (attack_nonlethal), связать (restrain) и отвести в камеру или к Капитану с докладом (escort_to). При мелких проступках может заколебаться перед хорошей взяткой."
	brain.secrets = "Один раз уже взял горсть серебра, чтобы отпустить контрабандиста, и боится, что Капитан об этом узнает."
	brain.speech_style = "Короткий, деловой, немного усталый тон бывалого стражника. Приказы чёткие, доклады старшим — почтительные, с буянами — суровые."
	brain.long_term_goal = "Патрулировать город, выявлять нарушителей и окровавленных подозреваемых, задерживать и доставлять их в темницу или к Капитану, а вечером перекусить и отдохнуть."
	brain.current_plan = "Осмотреть окрестности и проверить, нет ли подозрительных лиц или драк."
	brain.drive_hunger = rand(20, 40)
	brain.drive_thirst = rand(20, 40)
	brain.drive_smoke = rand(30, 55)
	brain.drive_greed = rand(30, 50)

// ============================================================================
// Admin Verbs (Live API Key/Model Config, Spawning, Waypoints, Mind Inspector)
// ============================================================================

/client/proc/cmd_llm_npc_config()
	set category = "Fun"
	set name = "LLM NPC: Configure Gemini"
	if(!check_rights(R_DEBUG))
		return

	var/key_status = length(SSllm_npc.get_api_key()) ? "SET (hidden)" : "NOT SET"
	var/choice = input(src,
		"Status: [SSllm_npc.is_enabled() ? "ENABLED" : "DISABLED"]\nModel: [SSllm_npc.get_model()]\nThinking: [SSllm_npc.get_thinking_level()]\nAPI Key: [key_status]\nActive Brains: [length(SSllm_npc.brains)] | In-Flight: [length(SSllm_npc.in_flight)]\nWaypoints: [length(SSllm_npc.waypoints)] | Shared Rumors: [length(SSllm_npc.shared_rumors)]\nCalls: [SSllm_npc.total_calls] (OK: [SSllm_npc.succeeded_calls], Fail: [SSllm_npc.failed_calls])\nLast Error: [SSllm_npc.last_error || "none"]",
		"LLM NPC Configuration"
	) as null|anything in list(
		"Test Gemini API Connection",
		"Set Runtime API Key (in-memory)",
		"Set Model Name",
		"Set Thinking Level",
		"Toggle Enabled",
		"Toggle Debug Logging",
		"Place Map Waypoint Here",
		"Refresh World Atlas & Stairs",
		"Add Shared Town Rumor"
	)
	if(!choice)
		return

	switch(choice)
		if("Test Gemini API Connection")
			if(!length(SSllm_npc.get_api_key()))
				to_chat(src, span_boldwarning("\[LLM NPC\] API key is not set yet. Set it first via this menu, config/comms.txt, or GEMINI_API_KEY env."))
				return
			to_chat(src, span_notice("\[LLM NPC\] Sending live test request to [SSllm_npc.get_model()]..."))
			SSllm_npc.send_test_request(src)

		if("Set Runtime API Key (in-memory)")
			var/new_key = input(src, "Paste Gemini API Key (stored in server RAM only, never saved to Git; leave blank to clear):", "Set Gemini API Key") as text|null
			if(isnull(new_key))
				return
			SSllm_npc.runtime_api_key = trim(new_key)
			if(length(SSllm_npc.runtime_api_key) && isnull(SSllm_npc.runtime_enabled))
				SSllm_npc.runtime_enabled = TRUE
			log_admin("[key_name(src)] updated SSllm_npc runtime API key ([length(SSllm_npc.runtime_api_key) ? "set" : "cleared"]).")
			to_chat(src, span_notice("\[LLM NPC\] Runtime API key [length(SSllm_npc.runtime_api_key) ? "updated" : "cleared"]."))

		if("Set Model Name")
			var/new_model = input(src, "Enter Gemini model ID (default: gemini-4-hydrogen):", "Set Gemini Model", SSllm_npc.get_model()) as text|null
			if(!length(trim(new_model)))
				return
			SSllm_npc.runtime_model = trim(new_model)
			log_admin("[key_name(src)] set SSllm_npc model to [SSllm_npc.runtime_model].")
			to_chat(src, span_notice("\[LLM NPC\] Model set to: [SSllm_npc.runtime_model]"))

		if("Set Thinking Level")
			var/new_lvl = input(src, "Choose thinkingLevel for live NPC turns:", "Thinking Level", SSllm_npc.get_thinking_level()) as null|anything in list("low", "medium", "high", "off")
			if(!new_lvl)
				return
			SSllm_npc.runtime_thinking_level = new_lvl
			log_admin("[key_name(src)] set SSllm_npc thinking level to [new_lvl].")
			to_chat(src, span_notice("\[LLM NPC\] Thinking level set to: [new_lvl]"))

		if("Toggle Enabled")
			SSllm_npc.runtime_enabled = !SSllm_npc.is_enabled()
			log_admin("[key_name(src)] toggled SSllm_npc to [SSllm_npc.runtime_enabled ? "ENABLED" : "DISABLED"].")
			to_chat(src, span_notice("\[LLM NPC\] Subsystem is now [SSllm_npc.runtime_enabled ? "ENABLED" : "DISABLED"]."))

		if("Toggle Debug Logging")
			SSllm_npc.debug_logging = !SSllm_npc.debug_logging
			to_chat(src, span_notice("\[LLM NPC\] Debug logging is now [SSllm_npc.debug_logging ? "ON" : "OFF"]."))

		if("Place Map Waypoint Here")
			var/turf/T = get_turf(mob)
			if(!T)
				return
			var/area/A = get_area(T)
			var/wname = input(src, "Название маяка (например: Таверна, Темница, Казарма):", "Place LLM Waypoint", A ? trim(A.name) : "Точка") as text|null
			if(!length(trim(wname)))
				return
			var/wcat = input(src, "Категория маяка:", "Waypoint Category") as null|anything in list("tavern", "square", "market", "church", "barracks", "prison", "bedroom", "keep", "gate", "generic")
			if(!wcat)
				return
			var/wdesc = input(src, "Короткое описание для ориентирования NPC внутри (опционально):", "Waypoint Description") as text|null
			var/obj/effect/landmark/llm_waypoint/W = new(T)
			W.waypoint_name = trim(wname)
			W.waypoint_category = wcat
			W.waypoint_desc = trim(wdesc || "")
			SSllm_npc.build_world_graph(force = TRUE)
			to_chat(src, span_notice("\[LLM NPC\] Placed waypoint «[W.waypoint_name]» ([wcat]) at [AREACOORD(T)] (Z[T.z])."))

		if("Refresh World Atlas & Stairs")
			SSllm_npc.build_world_graph(force = TRUE)
			var/stair_cnt = 0
			for(var/zk in SSllm_npc.stairs_by_z)
				stair_cnt += length(SSllm_npc.stairs_by_z[zk])
			to_chat(src, span_notice("\[LLM NPC\] Atlas rebuilt: [length(SSllm_npc.known_locations)] locations/waypoints, [stair_cnt] stair Z-links.\nLocations: [jointext(SSllm_npc.get_known_location_summaries(0, 20), "; ")]"))

		if("Add Shared Town Rumor")
			var/rumor = input(src, "Введите городской слух/новость для общей памяти всех LLM NPC:", "Add Shared Rumor") as text|null
			if(length(trim(rumor)))
				SSllm_npc.add_shared_rumor(trim(rumor), "GM")
				to_chat(src, span_notice("\[LLM NPC\] Shared rumor added: \"[trim(rumor)]\""))

/client/proc/cmd_llm_npc_spawn()
	set category = "Fun"
	set name = "LLM NPC: Spawn Starter NPC"
	if(!check_rights(R_FUN))
		return
	var/turf/T = get_turf(mob)
	if(!T)
		return

	var/archetype_pick = input(src, "Choose starter LLM NPC archetype:", "Spawn LLM NPC") as null|anything in list(
		"Бродяга-завсегдатай (Drifter)",
		"Городской стражник (Watchman)"
	)
	if(!archetype_pick)
		return

	var/custom_name = input(src, "Имя NPC (оставь пустым для случайного имени):", "Spawn LLM NPC") as text|null
	if(isnull(custom_name))
		return
	var/custom_goal = input(src, "Опциональная цель/сюжетный крючок (или пусто для стандартной):", "Spawn LLM NPC") as text|null

	var/mob/living/carbon/human/species/human/northern/npc_llm/N
	if(archetype_pick == "Городской стражник (Watchman)")
		N = new /mob/living/carbon/human/species/human/northern/npc_llm/watchman(T)
	else
		N = new /mob/living/carbon/human/species/human/northern/npc_llm/drifter(T)

	if(length(trim(custom_name)))
		N.llm_custom_name = trim(custom_name)
	if(length(trim(custom_goal)))
		addtimer(CALLBACK(src, PROC_REF(_apply_spawn_goal), N, trim(custom_goal)), 1.5 SECONDS)

	log_admin("[key_name(src)] spawned [archetype_pick] LLM NPC at [AREACOORD(T)].")
	message_admins("[key_name_admin(src)] spawned an LLM NPC ([archetype_pick]) at [ADMIN_VERBOSEJMP(T)].")
	to_chat(src, span_notice("\[LLM NPC\] Spawned [archetype_pick] at [AREACOORD(T)]. (Enabled=[SSllm_npc.is_enabled()], Key=[length(SSllm_npc.get_api_key()) ? "SET" : "NOT SET"])"))

/client/proc/_apply_spawn_goal(mob/living/carbon/human/N, goal_txt)
	if(N && !QDELETED(N) && N.llm_brain)
		N.llm_brain.long_term_goal = goal_txt

/client/proc/cmd_llm_npc_attach()
	set category = "Fun"
	set name = "LLM NPC: Attach/Detach Brain"
	if(!check_rights(R_FUN))
		return

	var/list/candidates = list()
	for(var/mob/living/carbon/human/H in view(10, mob))
		if(H.client)
			continue
		candidates["[H.real_name] ([H.job || H.type])[H.llm_brain ? " \[HAS BRAIN\]" : ""]"] = H
	if(!length(candidates))
		to_chat(src, span_warning("\[LLM NPC\] No non-player humans found within 10 tiles."))
		return

	var/pick_key = input(src, "Select a nearby human NPC:", "Attach/Detach LLM Brain") as null|anything in candidates
	if(!pick_key)
		return
	var/mob/living/carbon/human/H = candidates[pick_key]
	if(!H || QDELETED(H))
		return

	if(H.llm_brain)
		if(alert(src, "[H.real_name] already has an LLM brain. Detach and remove it?", "Detach Brain", "Yes", "No") == "Yes")
			QDEL_NULL(H.llm_brain)
			to_chat(src, span_notice("\[LLM NPC\] Detached brain from [H.real_name]."))
		return

	var/archetype = input(src, "Архетип / роль персонажа:", "Attach LLM Brain", H.job || "Горожанин") as text|null
	if(!length(trim(archetype)))
		return
	var/backstory = input(src, "Краткая биография и характер (1-3 предложения):", "Attach LLM Brain") as message|null
	if(isnull(backstory))
		return

	if(!H.mind)
		H.mind = new /datum/mind(null)
		H.mind.current = H
	H.llm_brain = new /datum/llm_npc_brain(H)
	H.llm_brain.archetype = trim(archetype)
	H.llm_brain.backstory = trim(backstory)
	H.llm_brain.speech_style = "Живой приземлённый русский, короткие фразы 1-2 предложения, без театрального пафоса."
	H.mode = NPC_AI_IDLE
	H.wander = FALSE
	H.handle_ai()

	log_admin("[key_name(src)] attached LLM brain ([archetype]) to [H.real_name].")
	to_chat(src, span_notice("\[LLM NPC\] Attached LLM brain to [H.real_name] ([archetype])."))

/client/proc/cmd_llm_npc_inspect()
	set category = "Fun"
	set name = "LLM NPC: Inspect Mind / Director Note"
	if(!check_rights(R_DEBUG))
		return
	if(!length(SSllm_npc.brains))
		to_chat(src, span_warning("\[LLM NPC\] No active LLM brains in the world."))
		return

	var/list/choices = list()
	for(var/datum/llm_npc_brain/B as anything in SSllm_npc.brains)
		if(!B || QDELETED(B) || !B.owner || QDELETED(B.owner))
			continue
		choices["[B.owner.real_name] ([B.archetype]) @ [B.last_area_name || "?"]"] = B
	if(!length(choices))
		return

	var/picked = input(src, "Choose an LLM NPC to inspect:", "Inspect LLM Mind") as null|anything in choices
	if(!picked)
		return
	var/datum/llm_npc_brain/B = choices[picked]
	if(!B || QDELETED(B) || !B.owner)
		return

	var/list/out = list()
	out += "<b>=== LLM MIND: [B.owner.real_name] ([B.archetype]) ===</b>"
	out += "<b>Location:</b> [B.last_area_name] (Z[B.owner.z]) | <b>TOD:</b> [GLOB.tod] | <b>Turns:</b> [B.turns_completed] | <b>Latency:</b> [B.last_latency_ms]ms | <b>In-Flight:</b> [B.in_flight]"
	out += "<b>Emotion:</b> [B.current_emotion] (valence=[B.mood_valence], fear=[B.fear], anger=[B.anger], suspicion=[B.suspicion])"
	out += "<b>Drives:</b> hunger=[B.drive_hunger], thirst=[B.drive_thirst], alcohol=[B.drive_alcohol], smoke=[B.drive_smoke], fatigue=[B.drive_fatigue], social=[B.drive_social], greed=[B.drive_greed], intimacy=[B.drive_intimacy]"
	out += "<b>Active Action:</b> [B.active_action] ([B.action_arg]) | <b>Sleep:</b> [B.is_sleeping_by_plan] | <b>Surrender:</b> [B.owner.surrendering] | <b>Outcome:</b> [B.last_action_outcome]"
	out += "<b>Plan:</b> [B.current_plan]"
	out += "<b>Long-Term Goal:</b> [B.long_term_goal]"
	out += "<b>Last Thought:</b> <i>[B.last_thought || "(none yet)"]</i>"
	if(length(B.last_error))
		out += "<span class='danger'><b>Last Error:</b> [B.last_error]</span>"

	if(B.owner.mind && length(B.owner.mind.known_people))
		var/list/kn = list()
		for(var/k in B.owner.mind.known_people)
			kn += k
		out += "<b>Native Acquaintances (mind.known_people):</b> [jointext(kn, ", ")]"

	if(length(B.relationships_by_tag))
		out += "<b>Relationships:</b>"
		for(var/tag in B.relationships_by_tag)
			var/datum/llm_relationship/R = B.relationships_by_tag[tag]
			out += "  - \[[tag]\] [R.known_name][length(R.perceived_role) ? " ([R.perceived_role])" : ""]: trust=[R.trust], fear=[R.fear], respect=[R.respect], attract=[R.attraction] ([R.describe_attitude()]) [length(R.notes) ? "| [jointext(R.notes, "; ")]" : ""]"

	if(length(B.reflections))
		out += "<b>Reflections:</b>"
		for(var/rf in B.reflections)
			out += "  * [rf]"

	if(length(B.memories))
		out += "<b>Recent Memories ([length(B.memories)] total):</b>"
		var/start_i = max(1, length(B.memories) - 5)
		for(var/i in start_i to length(B.memories))
			var/datum/llm_memory/M = B.memories[i]
			out += "  - \[[M.time_label], imp=[M.importance]\] [M.summary]"

	to_chat(src, jointext(out, "<br>"))

	var/action_pick = alert(src, "Action for [B.owner.real_name]:", "LLM Mind Inspector", "Send Director Note", "Jump To NPC", "Close")
	if(action_pick == "Send Director Note")
		var/note = input(src, "Enter an inner hunch/rumor/cue for [B.owner.real_name]:", "GM Director Note") as text|null
		if(length(trim(note)))
			B.inject_director_note(note)
			log_admin("[key_name(src)] sent LLM director note to [B.owner.real_name]: [note]")
			to_chat(src, span_notice("\[LLM NPC\] Director note injected into [B.owner.real_name]."))
	else if(action_pick == "Jump To NPC")
		if(B.owner && !QDELETED(B.owner))
			mob.forceMove(get_turf(B.owner))
