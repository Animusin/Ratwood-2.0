/// Admin-only presentation metadata. Spell mechanics and the mage library are unchanged.
/proc/admin_spell_categories()
	var/static/list/categories = list(
		"attack" = "Атака",
		"healing" = "Лечение",
		"protection" = "Защита",
		"summoning" = "Призыв",
		"movement" = "Перемещение",
		"buff" = "Усиление",
		"control" = "Контроль",
		"other" = "Прочее",
	)
	return categories

/// More specific rules override a family's usual purpose (e.g. Fetch is not an attack).
/proc/admin_spell_category_rules()
	var/static/list/rules = list(
		/obj/effect/proc_holder/spell/aimed = "attack",
		/obj/effect/proc_holder/spell/aoe_turf/conjure = "summoning",
		/obj/effect/proc_holder/spell/aoe_turf/conjure/mime_wall = "protection",
		/obj/effect/proc_holder/spell/aoe_turf/conjure/the_traps = "control",
		/obj/effect/proc_holder/spell/bloodcrawl = "movement",
		/obj/effect/proc_holder/spell/invoked/abduct = "movement",
		/obj/effect/proc_holder/spell/invoked/abscond = "movement",
		/obj/effect/proc_holder/spell/invoked/abyssal_infusion = "buff",
		/obj/effect/proc_holder/spell/invoked/abyssal_strength = "buff",
		/obj/effect/proc_holder/spell/invoked/abyssheal = "healing",
		/obj/effect/proc_holder/spell/invoked/abyssor_bends = "control",
		/obj/effect/proc_holder/spell/invoked/acceleration = "buff",
		/obj/effect/proc_holder/spell/invoked/aquatic_compulsion = "control",
		/obj/effect/proc_holder/spell/invoked/attach_bodypart = "healing",
		/obj/effect/proc_holder/spell/invoked/avert = "protection",
		/obj/effect/proc_holder/spell/invoked/baothablessings = "buff",
		/obj/effect/proc_holder/spell/invoked/between_the_lines = "movement",
		/obj/effect/proc_holder/spell/invoked/blade_burst = "attack",
		/obj/effect/proc_holder/spell/invoked/bless_food = "buff",
		/obj/effect/proc_holder/spell/invoked/blindness = "control",
		/obj/effect/proc_holder/spell/invoked/blink = "movement",
		/obj/effect/proc_holder/spell/invoked/blood_heal = "healing",
		/obj/effect/proc_holder/spell/invoked/bonechill = "attack",
		/obj/effect/proc_holder/spell/invoked/bonemend = "healing",
		/obj/effect/proc_holder/spell/invoked/call_dreamfiend = "summoning",
		/obj/effect/proc_holder/spell/invoked/call_mossback = "summoning",
		/obj/effect/proc_holder/spell/invoked/cascade = "attack",
		/obj/effect/proc_holder/spell/invoked/chain_lightning_breath = "attack",
		/obj/effect/proc_holder/spell/invoked/challenge = "control",
		/obj/effect/proc_holder/spell/invoked/churnwealthy = "attack",
		/obj/effect/proc_holder/spell/invoked/command_undead = "control",
		/obj/effect/proc_holder/spell/invoked/conjure_primordial = "summoning",
		/obj/effect/proc_holder/spell/invoked/conjure_tool = "summoning",
		/obj/effect/proc_holder/spell/invoked/conjure_weapon = "summoning",
		/obj/effect/proc_holder/spell/invoked/convergence = "buff",
		/obj/effect/proc_holder/spell/invoked/counterspell = "protection",
		/obj/effect/proc_holder/spell/invoked/craftercovenant = "buff",
		/obj/effect/proc_holder/spell/invoked/create_campfire = "summoning",
		/obj/effect/proc_holder/spell/invoked/create_shrooms = "summoning",
		/obj/effect/proc_holder/spell/invoked/cure_rot = "healing",
		/obj/effect/proc_holder/spell/invoked/darkvision = "buff",
		/obj/effect/proc_holder/spell/invoked/deaths_door = "protection",
		/obj/effect/proc_holder/spell/invoked/divergence = "control",
		/obj/effect/proc_holder/spell/invoked/divine_rebirth = "healing",
		/obj/effect/proc_holder/spell/invoked/dragon_lightning = "attack",
		/obj/effect/proc_holder/spell/invoked/dragon_swoop = "attack",
		/obj/effect/proc_holder/spell/invoked/dream_bind = "control",
		/obj/effect/proc_holder/spell/invoked/dream_trance = "control",
		/obj/effect/proc_holder/spell/invoked/ele_quake = "attack",
		/obj/effect/proc_holder/spell/invoked/enchant_weapon = "buff",
		/obj/effect/proc_holder/spell/invoked/enlarge = "buff",
		/obj/effect/proc_holder/spell/invoked/ensnare = "control",
		/obj/effect/proc_holder/spell/invoked/eora_blessing = "buff",
		/obj/effect/proc_holder/spell/invoked/eoracurse = "control",
		/obj/effect/proc_holder/spell/invoked/equalize = "control",
		/obj/effect/proc_holder/spell/invoked/evil_resurrect = "summoning",
		/obj/effect/proc_holder/spell/invoked/eyebite = "attack",
		/obj/effect/proc_holder/spell/invoked/featherfall = "protection",
		/obj/effect/proc_holder/spell/invoked/fiend_meteor = "attack",
		/obj/effect/proc_holder/spell/invoked/fire_cascade = "attack",
		/obj/effect/proc_holder/spell/invoked/fire_obelisk_beam = "attack",
		/obj/effect/proc_holder/spell/invoked/firewalker = "protection",
		/obj/effect/proc_holder/spell/invoked/forcewall = "protection",
		/obj/effect/proc_holder/spell/invoked/forcewall/arcyne_prison = "control",
		/obj/effect/proc_holder/spell/invoked/fortitude = "protection",
		/obj/effect/proc_holder/spell/invoked/frostbite = "attack",
		/obj/effect/proc_holder/spell/invoked/giants_strength = "buff",
		/obj/effect/proc_holder/spell/invoked/griefflower = "control",
		/obj/effect/proc_holder/spell/invoked/guidance = "buff",
		/obj/effect/proc_holder/spell/invoked/hammerfall = "attack",
		/obj/effect/proc_holder/spell/invoked/haste = "buff",
		/obj/effect/proc_holder/spell/invoked/hawks_eyes = "buff",
		/obj/effect/proc_holder/spell/invoked/heal = "healing",
		/obj/effect/proc_holder/spell/invoked/heartweave = "buff",
		/obj/effect/proc_holder/spell/invoked/heatmetal = "attack",
		/obj/effect/proc_holder/spell/invoked/huntersyell = "control",
		/obj/effect/proc_holder/spell/invoked/ignition = "attack",
		/obj/effect/proc_holder/spell/invoked/immolation = "attack",
		/obj/effect/proc_holder/spell/invoked/infestation = "attack",
		/obj/effect/proc_holder/spell/invoked/invisibility = "buff",
		/obj/effect/proc_holder/spell/invoked/jaunt = "movement",
		/obj/effect/proc_holder/spell/invoked/joyride = "movement",
		/obj/effect/proc_holder/spell/invoked/lasthigh = "buff",
		/obj/effect/proc_holder/spell/invoked/leap = "movement",
		/obj/effect/proc_holder/spell/invoked/lesser_heal = "healing",
		/obj/effect/proc_holder/spell/invoked/longstrider = "buff",
		/obj/effect/proc_holder/spell/invoked/magicshield = "protection",
		/obj/effect/proc_holder/spell/invoked/malum_flame_rogue = "attack",
		/obj/effect/proc_holder/spell/invoked/massage = "healing",
		/obj/effect/proc_holder/spell/invoked/mastersillusion = "summoning",
		/obj/effect/proc_holder/spell/invoked/meteor_storm = "attack",
		/obj/effect/proc_holder/spell/invoked/mineroresight = "buff",
		/obj/effect/proc_holder/spell/invoked/minion_order = "control",
		/obj/effect/proc_holder/spell/invoked/mockery = "attack",
		/obj/effect/proc_holder/spell/invoked/necra_crows = "summoning",
		/obj/effect/proc_holder/spell/invoked/necra_vow = "buff",
		/obj/effect/proc_holder/spell/invoked/necras_sight = "buff",
		/obj/effect/proc_holder/spell/invoked/noc_sight = "buff",
		/obj/effect/proc_holder/spell/invoked/order = "buff",
		/obj/effect/proc_holder/spell/invoked/painkiller = "healing",
		/obj/effect/proc_holder/spell/invoked/persistence = "healing",
		/obj/effect/proc_holder/spell/invoked/pestilent_blade = "buff",
		/obj/effect/proc_holder/spell/invoked/pestra_heal = "healing",
		/obj/effect/proc_holder/spell/invoked/pestra_leech = "healing",
		/obj/effect/proc_holder/spell/invoked/pomegranate = "protection",
		/obj/effect/proc_holder/spell/invoked/primordialmark = "buff",
		/obj/effect/proc_holder/spell/invoked/projectile = "attack",
		/obj/effect/proc_holder/spell/invoked/projectile/blood_net = "control",
		/obj/effect/proc_holder/spell/invoked/projectile/blowingdust = "control",
		/obj/effect/proc_holder/spell/invoked/projectile/fetch = "movement",
		/obj/effect/proc_holder/spell/invoked/projectile/repel = "control",
		/obj/effect/proc_holder/spell/invoked/psydonamend = "healing",
		/obj/effect/proc_holder/spell/invoked/psydonendure = "healing",
		/obj/effect/proc_holder/spell/invoked/pyroclastic_puff = "attack",
		/obj/effect/proc_holder/spell/invoked/raise_deadite = "summoning",
		/obj/effect/proc_holder/spell/invoked/raise_spirit_respite = "summoning",
		/obj/effect/proc_holder/spell/invoked/raise_spirits_vengeance = "summoning",
		/obj/effect/proc_holder/spell/invoked/raise_undead = "summoning",
		/obj/effect/proc_holder/spell/invoked/raise_undead_formation = "summoning",
		/obj/effect/proc_holder/spell/invoked/raise_undead_guard = "summoning",
		/obj/effect/proc_holder/spell/invoked/rebuke = "attack",
		/obj/effect/proc_holder/spell/invoked/regression = "healing",
		/obj/effect/proc_holder/spell/invoked/repulse = "control",
		/obj/effect/proc_holder/spell/invoked/resurrect = "healing",
		/obj/effect/proc_holder/spell/invoked/revel_in_slaughter = "attack",
		/obj/effect/proc_holder/spell/invoked/revive = "healing",
		/obj/effect/proc_holder/spell/invoked/sanctify_tree = "summoning",
		/obj/effect/proc_holder/spell/invoked/shadowstep = "movement",
		/obj/effect/proc_holder/spell/invoked/silence = "control",
		/obj/effect/proc_holder/spell/invoked/slick_trick = "control",
		/obj/effect/proc_holder/spell/invoked/slick_trick_small = "control",
		/obj/effect/proc_holder/spell/invoked/song = "buff",
		/obj/effect/proc_holder/spell/invoked/song/dirge_fortune = "control",
		/obj/effect/proc_holder/spell/invoked/song/discordant_dirge = "control",
		/obj/effect/proc_holder/spell/invoked/song/of_her_embrace = "healing",
		/obj/effect/proc_holder/spell/invoked/song/pestilent_piedpiper = "control",
		/obj/effect/proc_holder/spell/invoked/song/recovery_song = "healing",
		/obj/effect/proc_holder/spell/invoked/song/rejuvenation_song = "healing",
		/obj/effect/proc_holder/spell/invoked/stasis = "protection",
		/obj/effect/proc_holder/spell/invoked/stoneskin = "protection",
		/obj/effect/proc_holder/spell/invoked/summon_bed = "summoning",
		/obj/effect/proc_holder/spell/invoked/summon_dreamfiend_curse = "control",
		/obj/effect/proc_holder/spell/invoked/summon_marked = "movement",
		/obj/effect/proc_holder/spell/invoked/summon_rift = "summoning",
		/obj/effect/proc_holder/spell/invoked/sundering_lightning = "attack",
		/obj/effect/proc_holder/spell/invoked/tame_undead = "control",
		/obj/effect/proc_holder/spell/invoked/thunderstrike = "attack",
		/obj/effect/proc_holder/spell/invoked/tug_of_war = "control",
		/obj/effect/proc_holder/spell/invoked/veilbound_shift = "movement",
		/obj/effect/proc_holder/spell/invoked/vigorousexchange = "buff",
		/obj/effect/proc_holder/spell/invoked/wither = "attack",
		/obj/effect/proc_holder/spell/invoked/wound_closure = "healing",
		/obj/effect/proc_holder/spell/invoked/wound_heal = "healing",
		/obj/effect/proc_holder/spell/invoked/xylixlian_luck = "buff",
		/obj/effect/proc_holder/spell/self/abyssor_wind = "healing",
		/obj/effect/proc_holder/spell/self/astrata_gaze = "buff",
		/obj/effect/proc_holder/spell/self/astratan_path = "buff",
		/obj/effect/proc_holder/spell/self/astratan_spear = "summoning",
		/obj/effect/proc_holder/spell/self/bearclaws = "buff",
		/obj/effect/proc_holder/spell/self/cabbitclaws = "buff",
		/obj/effect/proc_holder/spell/self/call_infernals = "summoning",
		/obj/effect/proc_holder/spell/self/catclaws = "buff",
		/obj/effect/proc_holder/spell/self/claws = "buff",
		/obj/effect/proc_holder/spell/self/colossus_stomp = "attack",
		/obj/effect/proc_holder/spell/self/conjure_armor = "protection",
		/obj/effect/proc_holder/spell/self/conjure_floral_seed = "summoning",
		/obj/effect/proc_holder/spell/self/create_abyssoid = "summoning",
		/obj/effect/proc_holder/spell/self/create_vines = "summoning",
		/obj/effect/proc_holder/spell/self/createhoney = "summoning",
		/obj/effect/proc_holder/spell/self/crescendo = "buff",
		/obj/effect/proc_holder/spell/self/divine_strike = "attack",
		/obj/effect/proc_holder/spell/self/dragon_slam = "attack",
		/obj/effect/proc_holder/spell/self/findfamiliar = "summoning",
		/obj/effect/proc_holder/spell/self/foxclaws = "buff",
		/obj/effect/proc_holder/spell/self/graggar_bloodrage = "buff",
		/obj/effect/proc_holder/spell/self/harpy_flight = "movement",
		/obj/effect/proc_holder/spell/self/harpy_sing = "control",
		/obj/effect/proc_holder/spell/self/howl = "buff",
		/obj/effect/proc_holder/spell/self/light = "summoning",
		/obj/effect/proc_holder/spell/self/lurking_step = "movement",
		/obj/effect/proc_holder/spell/self/magicians_brick = "summoning",
		/obj/effect/proc_holder/spell/self/moleclaw = "buff",
		/obj/effect/proc_holder/spell/self/phantasm_fade = "movement",
		/obj/effect/proc_holder/spell/self/phantom_flicker = "protection",
		/obj/effect/proc_holder/spell/self/psydonic_inspire = "buff",
		/obj/effect/proc_holder/spell/self/psydonic_inviolability = "protection",
		/obj/effect/proc_holder/spell/self/psydonic_lux_bolt = "attack",
		/obj/effect/proc_holder/spell/self/psydonic_retribution = "attack",
		/obj/effect/proc_holder/spell/self/psydonic_sacrosanctity = "protection",
		/obj/effect/proc_holder/spell/self/psydonpersist = "protection",
		/obj/effect/proc_holder/spell/self/psydonrespite = "healing",
		/obj/effect/proc_holder/spell/self/recall = "movement",
		/obj/effect/proc_holder/spell/self/rhythm = "buff",
		/obj/effect/proc_holder/spell/self/rhythm/concussive = "attack",
		/obj/effect/proc_holder/spell/self/rhythm/malaise = "control",
		/obj/effect/proc_holder/spell/self/rhythm/regenerating = "healing",
		/obj/effect/proc_holder/spell/self/saigahoofs = "buff",
		/obj/effect/proc_holder/spell/self/smolder_shroud = "protection",
		/obj/effect/proc_holder/spell/self/soothing_bloom = "healing",
		/obj/effect/proc_holder/spell/self/spiderfangs = "buff",
		/obj/effect/proc_holder/spell/self/spin_web = "control",
		/obj/effect/proc_holder/spell/self/starseers_cry = "buff",
		/obj/effect/proc_holder/spell/self/stillness_of_stone = "protection",
		/obj/effect/proc_holder/spell/self/suicidebomb = "attack",
		/obj/effect/proc_holder/spell/self/summon_obelisks = "summoning",
		/obj/effect/proc_holder/spell/self/verdant_sprout = "summoning",
		/obj/effect/proc_holder/spell/self/verdant_veil = "protection",
		/obj/effect/proc_holder/spell/self/weaveweb = "control",
		/obj/effect/proc_holder/spell/self/wolfclaws = "buff",
		/obj/effect/proc_holder/spell/self/xylixslip = "control",
		/obj/effect/proc_holder/spell/targeted/abrogation = "protection",
		/obj/effect/proc_holder/spell/targeted/architect_conjure = "summoning",
		/obj/effect/proc_holder/spell/targeted/area_teleport = "movement",
		/obj/effect/proc_holder/spell/targeted/beasttame = "control",
		/obj/effect/proc_holder/spell/targeted/churn = "attack",
		/obj/effect/proc_holder/spell/targeted/conjure_glowshroom = "summoning",
		/obj/effect/proc_holder/spell/targeted/conjure_item = "summoning",
		/obj/effect/proc_holder/spell/targeted/conjure_vines = "summoning",
		/obj/effect/proc_holder/spell/targeted/emplosion = "attack",
		/obj/effect/proc_holder/spell/targeted/ethereal_jaunt = "movement",
		/obj/effect/proc_holder/spell/targeted/forcewall = "protection",
		/obj/effect/proc_holder/spell/targeted/lesser_dryad_special = "buff",
		/obj/effect/proc_holder/spell/targeted/pioneer/plant_bogtrap_delayed = "control",
		/obj/effect/proc_holder/spell/targeted/projectile = "attack",
		/obj/effect/proc_holder/spell/targeted/ravox_challenge = "control",
		/obj/effect/proc_holder/spell/targeted/skirmisher_trap = "control",
		/obj/effect/proc_holder/spell/targeted/spiderconjur = "summoning",
		/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad = "summoning",
		/obj/effect/proc_holder/spell/targeted/summonitem = "movement",
		/obj/effect/proc_holder/spell/targeted/summonweapon = "summoning",
		/obj/effect/proc_holder/spell/targeted/tesla = "attack",
		/obj/effect/proc_holder/spell/targeted/touch/loversruin = "attack",
		/obj/effect/proc_holder/spell/targeted/touch/nondetection = "protection",
		/obj/effect/proc_holder/spell/targeted/touch/summonrogueweapon = "summoning",
		/obj/effect/proc_holder/spell/targeted/transfix_neu = "control",
		/obj/effect/proc_holder/spell/targeted/turf_teleport = "movement",
		/obj/effect/proc_holder/spell/targeted/woundlick = "healing",
	)
	return rules

/proc/admin_spell_category(spell_type)
	var/list/rules = admin_spell_category_rules()
	while(ispath(spell_type, /obj/effect/proc_holder/spell))
		if(rules[spell_type])
			return rules[spell_type]
		spell_type = type2parent(spell_type)
	return "other"

/proc/admin_spell_icon(obj/effect/proc_holder/spell/spell_type)
	var/icon_file = initial(spell_type.action_icon)
	var/static/list/states_by_file = list()
	if(icon_file)
		var/list/states = states_by_file[icon_file]
		if(!states)
			states = icon_states(icon_file)
			states_by_file[icon_file] = states
		for(var/state in list(initial(spell_type.overlay_state), initial(spell_type.action_icon_state)))
			if(state && (state in states))
				return list("file" = icon_file, "state" = state)
	return list("file" = 'icons/mob/actions/roguespells.dmi', "state" = "spell")

/proc/admin_spell_sprite_key(spell_type)
	return "admin_spell_[md5("[spell_type]")]"

/datum/asset/spritesheet/admin_spells
	name = "admin_spells"

/datum/asset/spritesheet/admin_spells/create_spritesheets()
	for(var/spell_type in GLOB.spells)
		var/list/sprite = admin_spell_icon(spell_type)
		Insert(admin_spell_sprite_key(spell_type), sprite["file"], sprite["state"])

/// Reading the catalog must never instantiate a spell or run its Initialize().
/proc/admin_spell_catalog()
	var/static/list/catalog
	if(catalog)
		return catalog
	var/list/entries = list()
	var/datum/asset/spritesheet/spritesheet = get_asset_datum(/datum/asset/spritesheet/admin_spells)
	var/static/regex/breaks = regex("<br\\s*/?>", "gi")
	var/static/regex/tags = regex("<.*?>", "g")
	for(var/obj/effect/proc_holder/spell/spell_type as anything in GLOB.spells)
		var/description = initial(spell_type.desc) || ""
		description = html_decode(tags.Replace(breaks.Replace(description, "\n"), ""))
		entries += list(list(
			"path" = "[spell_type]",
			"name" = initial(spell_type.name) || "Без названия",
			"desc" = description,
			"category" = admin_spell_category(spell_type),
			"icon" = spritesheet.icon_class_name(admin_spell_sprite_key(spell_type)),
			"cooldown" = initial(spell_type.charge_type) == "recharge" ? initial(spell_type.recharge_time) / 10 : 0,
			"charge_time" = initial(spell_type.skipcharge) ? 0 : initial(spell_type.chargetime) / 10,
		))
	catalog = entries
	return catalog

/datum/admin_spell_library
	var/owner_ckey
	var/datum/weakref/target_ref
	var/datum/weakref/target_mind_ref
	var/target_had_mind = FALSE
	var/datum/ui_state/admin_state/access_state
	var/status_message

/datum/admin_spell_library/New(client/owner, mob/target)
	. = ..()
	owner_ckey = owner?.ckey
	target_ref = WEAKREF(target)
	target_mind_ref = WEAKREF(target?.mind)
	target_had_mind = !!target?.mind
	access_state = new(NONE)

/datum/admin_spell_library/Destroy()
	QDEL_NULL(access_state)
	target_ref = null
	target_mind_ref = null
	return ..()

/datum/admin_spell_library/proc/can_access(mob/user)
	return user?.client && owner_ckey && user.ckey == owner_ckey && check_rights_for(user.client, NONE)

/datum/admin_spell_library/proc/get_target()
	var/mob/target = target_ref?.resolve()
	if(!target)
		return null
	if(target_had_mind)
		var/datum/mind/original_mind = target_mind_ref?.resolve()
		if(!original_mind || target.mind != original_mind || original_mind.current != target)
			return null
	else if(target.mind)
		return null
	return target

/datum/admin_spell_library/ui_state(mob/user)
	return access_state

/datum/admin_spell_library/ui_status(mob/user, datum/ui_state/state)
	return can_access(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/admin_spell_library/ui_interact(mob/user, datum/tgui/ui)
	if(!can_access(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AdminSpellLibrary", "Выдача заклинаний")
		ui.open()

/datum/admin_spell_library/ui_close(mob/user)
	. = ..()
	qdel(src)

/datum/admin_spell_library/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/spritesheet/admin_spells))

/datum/admin_spell_library/ui_static_data(mob/user)
	if(!can_access(user))
		return list()
	var/list/categories = list()
	for(var/id in admin_spell_categories())
		categories += list(list("id" = id, "name" = admin_spell_categories()[id]))
	return list("spells" = admin_spell_catalog(), "categories" = categories)

/datum/admin_spell_library/proc/known_spells(mob/target)
	var/list/known = list()
	if(!target)
		return known
	for(var/obj/effect/proc_holder/spell/spell as anything in (target.mob_spell_list + target.mind?.spell_list))
		if(!QDELETED(spell))
			known["[spell.type]"] = TRUE
	return known

/datum/admin_spell_library/ui_data(mob/user)
	if(!can_access(user))
		return list()
	var/mob/target = get_target()
	return list(
		"target_name" = target ? target.name : "Получатель недоступен",
		"target_key" = target?.key,
		"target_valid" = !!target,
		"mindless" = target && !target.mind,
		"known_spells" = known_spells(target),
		"status_message" = status_message,
	)

/datum/admin_spell_library/ui_act(action, list/params)
	. = ..()
	if(.)
		return
	if(action == "grant")
		return grant_spell(usr, params["path"])
	if(action == "revoke")
		return revoke_spell(usr, params["path"])

/datum/admin_spell_library/proc/grant_spell(mob/user, path_text)
	if(!can_access(user))
		return FALSE
	var/mob/target = get_target()
	if(!target)
		status_message = "Получатель изменился или был удалён. Откройте выдачу заново."
		return TRUE
	if(!istext(path_text))
		return FALSE
	var/spell_type = text2path(path_text)
	if(!ispath(spell_type, /obj/effect/proc_holder/spell) || !(spell_type in GLOB.spells))
		return FALSE
	if(known_spells(target)[path_text])
		status_message = "У получателя уже есть это заклинание."
		return TRUE
	var/obj/effect/proc_holder/spell/spell = new spell_type()
	// Constructors may yield; recheck the recipient and access before granting.
	if(!can_access(user) || get_target() != target || known_spells(target)[path_text])
		qdel(spell)
		return TRUE
	if(!spell.action)
		qdel(spell)
		status_message = "Этот тип не создаёт доступную для выдачи способность."
		return TRUE
	if(target.mind)
		target.mind.AddSpell(spell)
	else
		target.AddSpell(spell)
	log_admin("[key_name(user)] gave [key_name(target)] the spell [spell_type].")
	message_admins(span_adminnotice("[key_name_admin(user)] gave [key_name_admin(target)] the spell [spell_type]."))
	SSblackbox.record_feedback("tally", "admin_verb", 1, "Give Spell")
	status_message = "Выдано: [spell.name] → [target.name]."
	return TRUE

/datum/admin_spell_library/proc/revoke_spell(mob/user, path_text)
	if(!can_access(user))
		return FALSE
	var/mob/target = get_target()
	if(!target)
		status_message = "Получатель изменился или был удалён. Откройте выдачу заново."
		return TRUE
	if(!istext(path_text))
		return FALSE
	var/spell_type = text2path(path_text)
	if(!ispath(spell_type, /obj/effect/proc_holder/spell) || !(spell_type in GLOB.spells))
		return FALSE
	// Cards represent exact types; do not remove their subtypes or skip body-owned spells.
	var/list/spells_to_remove = list()
	for(var/obj/effect/proc_holder/spell/spell as anything in (target.mob_spell_list + target.mind?.spell_list))
		if(!QDELETED(spell) && spell.type == spell_type)
			spells_to_remove |= spell
	if(!length(spells_to_remove))
		status_message = "У получателя уже нет этого заклинания."
		return TRUE
	var/obj/effect/proc_holder/spell/first_spell = spells_to_remove[1]
	var/spell_name = first_spell.name
	for(var/obj/effect/proc_holder/spell/spell as anything in spells_to_remove)
		target.mob_spell_list -= spell
		target.mind?.spell_list -= spell
		qdel(spell)
	log_admin("[key_name(user)] removed the spell [spell_type] from [key_name(target)].")
	message_admins(span_adminnotice("[key_name_admin(user)] removed the spell [spell_type] from [key_name_admin(target)]."))
	SSblackbox.record_feedback("tally", "admin_verb", 1, "Remove Spell")
	status_message = "Забрано: [spell_name] → [target.name]."
	return TRUE
