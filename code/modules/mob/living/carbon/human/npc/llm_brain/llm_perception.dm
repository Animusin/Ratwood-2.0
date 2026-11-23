// Honest semantic perception (no X-ray grids, no metagaming stranger names!),
// integrated with Ratwood's native mind.known_people acquaintance system,
// obvious uniform/affiliation cues, visible objects/items/exits/stairs, and 3-tier memory recall.

/proc/llm_lower_ru(text)
	if(!istext(text) || !length(text))
		return ""
	var/static/list/ru_upper = list(
		"А" = "а", "Б" = "б", "В" = "в", "Г" = "г", "Д" = "д", "Е" = "е", "Ё" = "ё",
		"Ж" = "ж", "З" = "з", "И" = "и", "Й" = "й", "К" = "к", "Л" = "л", "М" = "м",
		"Н" = "н", "О" = "о", "П" = "п", "Р" = "р", "С" = "с", "Т" = "т", "У" = "у",
		"Ф" = "ф", "Х" = "х", "Ц" = "ц", "Ч" = "ч", "Ш" = "ш", "Щ" = "щ", "Ъ" = "ъ",
		"Ы" = "ы", "Ь" = "ь", "Э" = "э", "Ю" = "ю", "Я" = "я"
	)
	var/out = LOWER_TEXT(text)
	for(var/u in ru_upper)
		if(findtext(out, u))
			out = replacetext(out, u, ru_upper[u])
	return out

/proc/llm_clean_text(raw, max_len = 300)
	if(!istext(raw) || !length(raw))
		return ""
	var/static/regex/tag_re = regex("<\[^>\]*>", "g")
	var/static/regex/ws_re = regex("\\s+", "g")
	var/text = tag_re.Replace(raw, " ")
	text = replacetext(text, "&quot;", "\"")
	text = replacetext(text, "&#39;", "'")
	text = replacetext(text, "&apos;", "'")
	text = replacetext(text, "&amp;", "&")
	text = replacetext(text, "&lt;", "<")
	text = replacetext(text, "&gt;", ">")
	text = replacetext(text, "&nbsp;", " ")
	text = ws_re.Replace(text, " ")
	text = trim(text)
	if(max_len && length_char(text) > max_len)
		text = copytext_char(text, 1, max_len + 1)
	return text

// ============================================================================
// Honest Recognition (Ratwood mind.known_people + Obvious Affiliation ONLY)
// ============================================================================

/datum/llm_npc_brain/proc/is_acquainted_with(mob/living/carbon/human/H)
	if(!H || !owner?.mind)
		return FALSE
	return !isnull(owner.mind.known_people[H.real_name])

/// Infers job/affiliation automatically ONLY when it is visually obvious at a glance
/// (guard armor/tabards, noble/royal regalia, clergy robes, prisoner mask/rags, jester).
/datum/llm_npc_brain/proc/infer_obvious_affiliation(mob/living/carbon/human/H)
	if(!H)
		return ""
	// Obvious official uniform/rank visible at a glance
	var/static/list/obvious_jobs = list(
		"Lord" = "Лорд (знать)",
		"King" = "Король (знать)",
		"Consort" = "Консорт (знать)",
		"Prince" = "Наследник (знать)",
		"Hand" = "Десница",
		"Captain" = "Капитан стражи",
		"Watchcaptain" = "Капитан стражи",
		"Warden" = "Надзиратель",
		"Wardenmaster" = "Начальник темницы",
		"Sergeant" = "Сержант стражи",
		"Townguard" = "Стражник",
		"Garrison" = "Стражник",
		"Veteran" = "Ветеран стражи",
		"Rookie" = "Новобранец стражи",
		"Dungeoneer" = "Тюремщик",
		"Priest" = "Священник",
		"Chaplain" = "Капеллан",
		"Templar" = "Храмовник",
		"Monk" = "Монах",
		"Absolutionist" = "Инквизитор",
		"Orthodoxist" = "Инквизитор",
		"Puritan" = "Инквизитор",
		"Jester" = "Шут",
		"Prisoner" = "Узник",
		"Barkeep" = "Трактирщик"
	)
	if(H.job && obvious_jobs[H.job])
		// Only obvious if actually dressed in something (not completely disguised/masked)
		if(!H.wear_mask || (H.wear_armor || H.cloak))
			return obvious_jobs[H.job]
	// Visual clothing cues if job isn't obvious
	var/gear = llm_lower_ru("[H.wear_armor?.name] [H.cloak?.name] [H.wear_shirt?.name] [H.head?.name]")
	if(findtext(gear, "garrison") || findtext(gear, "watch") || findtext(gear, "guard") || findtext(gear, "tabard"))
		return "похож на стражника"
	if(findtext(gear, "inquisit") || findtext(gear, "priest") || findtext(gear, "monk") || findtext(gear, "robe"))
		return "похож на служителя церкви"
	if(findtext(gear, "crown") || findtext(gear, "noble") || findtext(gear, "velvet") || findtext(gear, "silk"))
		return "выглядит как знать"
	if(findtext(gear, "prison") || findtext(gear, "rag") || findtext(gear, "loincloth"))
		return "похож на бродягу/узника"
	return ""

/datum/llm_npc_brain/proc/get_or_create_relationship(mob/living/M)
	var/r = REF(M)
	var/datum/llm_relationship/rel = relationships_by_ref[r]
	var/perceived_name = get_perceived_mob_name(M)

	if(!rel)
		rel = new()
		rel.entity_id = "p[next_person_tag_num++]"
		rel.mob_ref = WEAKREF(M)
		rel.known_name = perceived_name
		rel.appearance_hint = build_brief_appearance(M)
		if(ishuman(M))
			rel.perceived_role = infer_obvious_affiliation(M)
		relationships_by_ref[r] = rel
		relationships_by_tag[rel.entity_id] = rel
	else
		rel.appearance_hint = build_brief_appearance(M)
		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(!length(rel.perceived_role))
				rel.perceived_role = infer_obvious_affiliation(H)
			// If we now officially know them via Ratwood's mind.known_people and they aren't masked, recognize them!
			if(is_acquainted_with(H) && H.get_face_name() == H.real_name)
				rel.known_name = llm_clean_text(H.real_name, 50)
				var/list/kp = owner.mind.known_people[H.real_name]
				if(islist(kp) && length(kp["FJOB"]) && kp["FJOB"] != "unknown")
					rel.perceived_role = kp["FJOB"]
	return rel

/// Honest perceived identity:
/// - If masked/hidden face -> "незнакомец в маске"
/// - If already in owner.mind.known_people -> real name (recognized!)
/// - Otherwise -> "незнакомец" / "незнакомка" (+ obvious uniform if any), until examined or introduced!
/datum/llm_npc_brain/proc/get_perceived_mob_name(mob/living/M)
	if(!M)
		return "незнакомец"
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		var/face_name = H.get_face_name()
		if(!length(face_name) || face_name != H.real_name || face_name == "Unknown")
			return "незнакомец в маске"
		if(is_acquainted_with(H))
			return llm_clean_text(H.real_name, 50)
		// Not formally acquainted yet: don't magically know their full name!
		var/obvious = infer_obvious_affiliation(H)
		var/base_label = (H.gender == FEMALE) ? "незнакомка" : "незнакомец"
		return length(obvious) ? "[base_label] ([obvious])" : base_label
	return llm_clean_text(M.name, 50) || "существо"

/datum/llm_npc_brain/proc/build_brief_appearance(mob/living/M)
	if(!M)
		return ""
	var/list/parts = list()
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.wear_armor)
			parts += "броня: [llm_clean_text(H.wear_armor.name, 28)]"
		else if(H.wear_shirt)
			parts += llm_clean_text(H.wear_shirt.name, 28)
		if(H.cloak)
			parts += llm_clean_text(H.cloak.name, 24)
		if(H.wear_mask)
			parts += "в маске ([llm_clean_text(H.wear_mask.name, 24)])"
		if(H.head)
			parts += llm_clean_text(H.head.name, 24)
	return jointext(parts, ", ")

/// Only obvious at-a-glance cues (drawn weapon, dead/unconscious, cuffed, burning, obvious wounds).
/// Deeper clues (blood-stained hands, debtor marks, embedded weapons, hidden details) come from examine_closer!
/datum/llm_npc_brain/proc/describe_mob_glance_cues(mob/living/M)
	if(!M)
		return ""
	var/list/cues = list()
	if(M.stat == DEAD)
		cues += "МЁРТВ"
	else if(M.stat == UNCONSCIOUS)
		cues += "без сознания"
	else if(M.IsSleeping())
		cues += "спит"
	else if(M.surrendering)
		cues += "СДАЁТСЯ"
	else if(!(M.mobility_flags & MOBILITY_STAND))
		cues += "лежит"
	if(M.buckled)
		cues += "сидит/лежит на [llm_clean_text(M.buckled.name, 24)]"
	if(M.on_fire)
		cues += "ГОРИТ"

	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		var/obj/item/rh = H.get_active_held_item()
		var/obj/item/lh = H.get_inactive_held_item()
		if(rh)
			cues += "в руке: [llm_clean_text(rh.name, 30)][(rh.force >= 8 || istype(rh, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)) ? " (ОРУЖИЕ)" : ""]"
		if(lh && lh != rh)
			cues += "во 2-й руке: [llm_clean_text(lh.name, 30)][(lh.force >= 8 || istype(lh, /obj/item/gun/ballistic/revolver/grenadelauncher/bow)) ? " (ОРУЖИЕ)" : ""]"
		if(H.handcuffed)
			cues += "СВЯЗАН"
		if(H.health < H.maxHealth * 0.65 && H.stat != DEAD)
			cues += "тяжело ранен"
		if(H.offered_item_ref?.resolve())
			cues += "протягивает предмет"
	return jointext(cues, "; ")

/datum/llm_npc_brain/proc/resolve_entity_tag(tag_str)
	var/t = LOWER_TEXT(trim(tag_str))
	if(!length(t))
		return null
	var/datum/llm_relationship/rel = relationships_by_tag[t]
	if(rel?.mob_ref)
		return rel.mob_ref.resolve()
	var/datum/weakref/obj_wr = perceived_objects[t]
	if(obj_wr)
		return obj_wr.resolve()
	var/datum/weakref/item_wr = perceived_items[t]
	if(item_wr)
		return item_wr.resolve()
	// Fallback: match visible mob by known_name or real_name substring
	if(owner)
		var/lt = llm_lower_ru(t)
		for(var/mob/living/L in view(7, owner))
			if(L == owner || (L.alpha == 0 && L.rogue_sneaking))
				continue
			var/datum/llm_relationship/r = relationships_by_ref[REF(L)]
			if((r && findtext(llm_lower_ru(r.known_name), lt)) || findtext(llm_lower_ru(L.name), lt))
				return L
	return null

// ============================================================================
// Semantic Self-State & Scene Graph (Lists of People/Objects/Items/Exits — NO Tile Grid!)
// ============================================================================

/datum/llm_npc_brain/proc/build_self_state_text()
	var/area/A = get_area(owner)
	var/area_name = A ? llm_clean_text(A.name, 60) : "неизвестное место"
	var/posture = "стоит"
	if(owner.surrendering)
		posture = "СДАЁТСЯ (руки подняты, безоружен)"
	else if(owner.buckled)
		posture = "сидит/лежит на [llm_clean_text(owner.buckled.name, 30)]"
	else if(!(owner.mobility_flags & MOBILITY_STAND))
		posture = "лежит на земле"

	var/health_desc = "здоров"
	if(owner.health < owner.maxHealth * 0.4)
		health_desc = "при смерти ([round(owner.health)]/[round(owner.maxHealth)])"
	else if(owner.health < owner.maxHealth * 0.75)
		health_desc = "ранен ([round(owner.health)]/[round(owner.maxHealth)])"
	else if(owner.health < owner.maxHealth * 0.95)
		health_desc = "лёгкие ушибы"

	var/pain_val = round(owner.get_complex_pain())
	var/combat_mode_txt = "мирный"
	if(owner.mode == NPC_AI_HUNT)
		combat_mode_txt = "[nonlethal_combat ? "НЕЛЕТАЛЬНЫЙ БОЙ" : "СМЕРТЕЛЬНЫЙ БОЙ"] против [owner.target ? get_perceived_mob_name(owner.target) : "врага"]"
	else if(owner.mode == NPC_AI_FLEE)
		combat_mode_txt = "УБЕГАЕТ"

	var/drunk_txt = ""
	if(owner.reagents?.has_reagent(/datum/reagent/consumable/ethanol))
		drunk_txt = " | ПОДВЫПИЛ"

	var/pull_txt = owner.pulling ? " | Тащишь/ведёшь: [llm_clean_text(owner.pulling.name, 35)]" : ""

	// Hands & useful inventory items (never leaks organs!)
	var/obj/item/active_item = owner.get_active_held_item()
	var/obj/item/inactive_item = owner.get_inactive_held_item()
	var/list/held_desc = list()
	if(active_item)
		held_desc += "[llm_clean_text(active_item.name, 35)] (осн. рука)"
	if(inactive_item && inactive_item != active_item)
		held_desc += "[llm_clean_text(inactive_item.name, 35)] (вт. рука)"

	var/list/weapons_stowed = list()
	var/list/utility_items = list()
	var/list/keys_desc = list()
	var/coin_total = 0
	var/arrow_count = 0
	for(var/obj/item/I in owner.get_equipped_items(include_pockets = TRUE, include_beltslots = TRUE))
		if(I == active_item || I == inactive_item)
			continue
		if(istype(I, /obj/item/roguecoin))
			var/obj/item/roguecoin/C = I
			coin_total += C.quantity
			continue
		if(istype(I, /obj/item/roguekey))
			keys_desc += llm_clean_text(I.name, 28)
			continue
		if(istype(I, /obj/item/rogueweapon) || istype(I, /obj/item/gun/ballistic/revolver/grenadelauncher/bow))
			weapons_stowed += llm_clean_text(I.name, 28)
			continue
		if(istype(I, /obj/item/quiver))
			for(var/obj/item/ammo_casing/caseless/rogue/arrow/AR in I.contents)
				arrow_count++
			utility_items += "колчан (стрел: [arrow_count])"
			continue
		if(istype(I, /obj/item/rope) || istype(I, /obj/item/natural/cloth) || istype(I, /obj/item/needle) || istype(I, /obj/item/reagent_containers) || istype(I, /obj/item/clothing/mask/cigarette) || istype(I, /obj/item/match))
			utility_items += llm_clean_text(I.name, 28)

	var/list/lines = list()
	lines += "Имя: [owner.real_name] | Роль: [owner.job || archetype] | Сословие: [social_standing]"
	lines += "Локация: [area_name] (этаж Z[owner.z]) | Время суток: [GLOB.tod || "day"] | Поза: [posture]"
	lines += "Расписание сейчас: [llm_describe_daily_schedule(GLOB.tod, archetype)]"
	lines += "Состояние: [health_desc], боль=[pain_val], режим=[combat_mode_txt][drunk_txt][pull_txt]"
	lines += "Эмоции: [current_emotion] (настроение=[mood_valence], страх=[fear], злость=[anger], подозрительность=[suspicion])"
	lines += "Потребности (0-100): голод=[drive_hunger], жажда=[drive_thirst], алкоголь=[drive_alcohol], курево=[drive_smoke], усталость=[drive_fatigue], общение=[drive_social], деньги=[drive_greed], близость=[drive_intimacy]"
	lines += "В руках: [length(held_desc) ? jointext(held_desc, ", ") : "пусто"]"
	if(length(weapons_stowed))
		lines += "Оружие в ножнах/на поясе/спине: [jointext(weapons_stowed, ", ")]"
	if(length(utility_items))
		lines += "Снаряжение/еда/медицина/курево: [jointext(utility_items, ", ")]"
	if(coin_total > 0)
		lines += "Монеты при себе: [coin_total]"
	if(length(keys_desc))
		lines += "Ключи: [jointext(keys_desc, ", ")]"

	// Active pending bribe/item offer!
	if(pending_offer_item_ref)
		var/mob/living/og = pending_offer_giver_ref?.resolve()
		var/obj/item/oi = pending_offer_item_ref?.resolve()
		if(og && oi)
			var/datum/llm_relationship/orel = get_or_create_relationship(og)
			lines += "!!! ТЕБЕ СЕЙЧАС ПРОТЯГИВАЮТ ПРЕДМЕТ: [orel.known_name] (\[[orel.entity_id]\]) [pending_offer_stealthy ? "ТАЙКОМ (взятка!)" : "открыто"] предлагает «[llm_clean_text(oi.name, 40)]» — можешь accept_offer или refuse_offer!"

	// Known acquaintances summary (from Ratwood's native mind.known_people!)
	if(owner.mind && length(owner.mind.known_people))
		var/list/acq = list()
		for(var/kname in owner.mind.known_people)
			var/list/kdata = owner.mind.known_people[kname]
			var/kjob = (islist(kdata) && length(kdata["FJOB"]) && kdata["FJOB"] != "unknown") ? " ([kdata["FJOB"]])" : ""
			acq += "[kname][kjob]"
			if(length(acq) >= 10)
				break
		lines += "Твои знакомые в городе: [jointext(acq, ", ")]"

	lines += "Текущее действие: [active_action][length(action_arg) ? " ([action_arg])" : ""][length(last_action_outcome) ? " | Итог прошлого: [last_action_outcome]" : ""]"
	lines += "Краткий план: [current_plan]"
	lines += "Долгая цель: [long_term_goal]"
	return jointext(lines, "\n")

/datum/llm_npc_brain/proc/build_scene_perception_text(list/visible_entity_tags_out)
	perceived_objects.Cut()
	perceived_items.Cut()

	var/list/people_lines = list()
	var/list/struct_lines = list()
	var/list/item_lines = list()
	var/list/nearby_areas = list()
	var/cur_area = get_area(owner)

	// 1) Visible People & Creatures (Honest: known_people OR obvious uniform only until examined!)
	for(var/mob/living/L in view(7, owner))
		if(L == owner || (L.alpha == 0 && L.rogue_sneaking))
			continue
		var/datum/llm_relationship/rel = get_or_create_relationship(L)
		if(islist(visible_entity_tags_out))
			visible_entity_tags_out |= rel.entity_id

		var/dist = get_dist(owner, L)
		var/dir_txt = dir2text(get_dir(owner, L))
		var/cues = describe_mob_glance_cues(L)
		var/app = rel.appearance_hint
		var/role_txt = length(rel.perceived_role) ? " | род/вид: [rel.perceived_role]" : ""
		var/att = rel.describe_attitude()
		var/exam_hint = (!rel.examined && ishuman(L)) ? " (не осмотрен — examine_closer покажет кровь/раны/приметы)" : ""
		var/notes_txt = length(rel.notes) ? " | Помнишь: [jointext(rel.notes, "; ")]" : ""
		people_lines += "- \[[rel.entity_id]\] [rel.known_name] ([dist] тайл., [dir_txt])[role_txt][length(app) ? " | одежда: [app]" : ""][length(cues) ? " | сейчас: [cues]" : ""] | отношение: [att] (доверие=[rel.trust], страх=[rel.fear], симпатия=[rel.attraction])[exam_hint][notes_txt]"
		if(length(people_lines) >= 12)
			break

	// 2) Visible Interactive Structures (Doors, Stairs UP/DOWN, Beds, Chairs, Tables, Closets, Railings/Fences)
	var/obj_idx = 1
	for(var/obj/structure/S in view(6, owner))
		var/desc_tag = ""
		if(istype(S, /obj/structure/mineral_door))
			var/obj/structure/mineral_door/D = S
			desc_tag = "дверь ([D.door_opened ? "открыта" : (D.locked ? "ЗАПЕРТА" : "закрыта")])"
		else if(istype(S, /obj/structure/stairs))
			var/obj/structure/stairs/ST = S
			var/goes_up = !isnull(ST.get_target_loc(ST.dir))
			var/goes_dn = !isnull(ST.get_target_loc(REVERSE_DIR(ST.dir)))
			desc_tag = "лестница ([goes_up ? "ВВЕРХ " : ""][goes_dn ? "ВНИЗ" : ""])"
		else if(istype(S, /obj/structure/bed))
			desc_tag = S.has_buckled_mobs() ? "кровать (занята)" : "кровать (свободна, можно go_sleep)"
		else if(istype(S, /obj/structure/chair))
			desc_tag = S.has_buckled_mobs() ? "стул (занят)" : "стул (свободен)"
		else if(istype(S, /obj/structure/closet))
			var/obj/structure/closet/C = S
			desc_tag = C.opened ? "шкаф/сундук (открыт)" : (C.locked ? "шкаф/сундук (ЗАПЕРТ)" : "шкаф/сундук (закрыт)")
		else if(istype(S, /obj/structure/table))
			desc_tag = "стол"
		else if(S.climbable && S.density)
			desc_tag = "перила/ограда (можно перелезть climb_over)"
		else
			continue

		var/oid = "o[obj_idx++]"
		perceived_objects[oid] = WEAKREF(S)
		struct_lines += "- \[[oid]\] [llm_clean_text(S.name, 30)] — [desc_tag] ([get_dist(owner, S)] тайл., [dir2text(get_dir(owner, S))])"
		if(length(struct_lines) >= 12)
			break

	// 3) Visible Ground & Table Items (Food/plates, drinks, coins, weapons, bandages, needles, potions, rope, smokes!)
	var/item_idx = 1
	for(var/obj/item/I in view(5, owner))
		if(!isturf(I.loc) || I.anchored)
			continue
		var/iid = "i[item_idx++]"
		perceived_items[iid] = WEAKREF(I)
		var/extra = ""
		if(istype(I, /obj/item/roguecoin))
			var/obj/item/roguecoin/C = I
			extra = " (монеты: [C.quantity] шт.)"
		else if(istype(I, /obj/item/reagent_containers/food/snacks))
			extra = (locate(/obj/structure/table) in I.loc) ? " (еда на столе — можно eat_or_drink)" : " (еда)"
		else if(istype(I, /obj/item/reagent_containers/glass))
			extra = " (напиток/зелье)"
		else if(istype(I, /obj/item/clothing/mask/cigarette))
			extra = " (курево)"
		else if(istype(I, /obj/item/natural/cloth) || istype(I, /obj/item/needle))
			extra = " (медицина)"
		else if(istype(I, /obj/item/rope))
			extra = " (верёвка/связывание)"
		else if(istype(I, /obj/item/gun/ballistic/revolver/grenadelauncher/bow))
			extra = " (лук)"
		else if(I.force >= 8)
			extra = " (оружие)"
		item_lines += "- \[[iid]\] [llm_clean_text(I.name, 34)][extra] ([get_dist(owner, I)] тайл., [dir2text(get_dir(owner, I))])"
		if(length(item_lines) >= 12)
			break

	// 4) Visible adjacent/connected rooms (open orientation without tile coordinates!)
	for(var/turf/open/T in view(7, owner))
		var/area/TA = get_area(T)
		if(TA && TA != cur_area && length(trim(TA.name)))
			var/tname = trim(TA.name)
			if(!(tname in nearby_areas))
				nearby_areas += "[tname] ([dir2text(get_dir(owner, T))])"
				if(length(nearby_areas) >= 5)
					break

	var/list/sections = list()
	sections += "ЛЮДИ В ПОЛЕ ЗРЕНИЯ:"
	sections += length(people_lines) ? jointext(people_lines, "\n") : "- Никого не видно."
	if(length(struct_lines))
		sections += "\nОБЪЕКТЫ И ПРОХОДЫ РЯДОМ:\n[jointext(struct_lines, "\n")]"
	if(length(item_lines))
		sections += "\nПРЕДМЕТЫ ВОКРУГ (НА ЗЕМЛЕ/СТОЛАХ):\n[jointext(item_lines, "\n")]"
	if(length(nearby_areas))
		sections += "\nСОСЕДНИЕ ПОМЕЩЕНИЯ/ВЫХОДЫ РЯДОМ: [jointext(nearby_areas, ", ")]"
	if(length(last_examine_report))
		sections += "\nРЕЗУЛЬТАТ ДЕТАЛЬНОГО ОСМОТРА:\n[last_examine_report]"

	var/list/loc_list = SSllm_npc.get_known_location_summaries(owner.z, 16)
	if(length(loc_list))
		sections += "\nИЗВЕСТНЫЕ МАЯКИ И ЛОКАЦИИ ГОРОДА (для go_to_area / escort_to):\n- [jointext(loc_list, "\n- ")]"

	sections += "\nВЛАСТЬ ГОРОДА СЕЙЧАС: [SSllm_npc.get_authority_summary()]"
	if(length(SSllm_npc.shared_rumors))
		sections += "\nОБЩИЕ СЛУХИ В ГОРОДЕ:\n- [jointext(SSllm_npc.shared_rumors, "\n- ")]"

	return jointext(sections, "\n")

// ============================================================================
// Scored Episodic Memory Retrieval
// ============================================================================

/datum/llm_npc_brain/proc/retrieve_relevant_memories(list/visible_tags, max_results = 6)
	if(!length(memories))
		return list()

	var/list/query_words = list()
	for(var/ev in pending_events)
		for(var/w in splittext(llm_lower_ru(ev), " "))
			var/cw = replacetext(replacetext(replacetext(replacetext(w, ".", ""), ",", ""), "\"", ""), "?", "")
			if(length_char(cw) >= 4)
				query_words |= cw

	var/list/scored = list()
	for(var/datum/llm_memory/M as anything in memories)
		var/score = M.importance * 2
		var/age_min = max(0, (world.time - M.created_at) / (1 MINUTES))
		score += max(0, 10 - round(age_min * 0.7))
		if(length(last_area_name) && M.area_name == last_area_name)
			score += 3
		if(islist(visible_tags))
			for(var/vt in visible_tags)
				if(vt in M.tags)
					score += 6
		var/kw_hits = 0
		for(var/qw in query_words)
			if(qw in M.tags)
				kw_hits++
				if(kw_hits >= 3)
					break
		score += kw_hits * 3
		scored[M] = score

	var/list/results = list()
	for(var/i in 1 to min(max_results, length(scored)))
		var/datum/llm_memory/best_m = null
		var/best_s = -9999
		for(var/datum/llm_memory/M as anything in scored)
			if(scored[M] > best_s)
				best_s = scored[M]
				best_m = M
		if(!best_m)
			break
		results += "\[[best_m.time_label], [best_m.area_name || "город"]\] [best_m.summary]"
		scored -= best_m
	return results
