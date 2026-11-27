// LLM-powered NPC subsystem, 3D multi-Z world atlas + landmarks, shared town rumors,
// live authority scanner, and direct Gemini REST client (via rust_g async HTTP).

#define LLM_NPC_REQ_TURN "turn"
#define LLM_NPC_REQ_REFLECT "reflect"
#define LLM_NPC_REQ_TEST "test"

#define LLM_NPC_REQUEST_TIMEOUT (25 SECONDS)
#define LLM_NPC_RATE_WINDOW (60 SECONDS)
#define LLM_MAX_SHARED_RUMORS 12

// ============================================================================
// Mapper Waypoint Landmark (Place on any map for rich named orientation!)
// ============================================================================

/obj/effect/landmark/llm_waypoint
	name = "LLM NPC Waypoint"
	icon_state = "x"
	invisibility = INVISIBILITY_ABSTRACT
	/// Human-readable name shown to LLM NPCs (e.g. "Таверна", "Темница", "Казарма").
	var/waypoint_name = ""
	/// Category tag: "tavern", "square", "market", "church", "barracks", "prison", "inn", "gate", "keep", "generic"
	var/waypoint_category = "generic"
	/// Short flavor/orientation note for NPCs inside this place.
	var/waypoint_desc = ""

/obj/effect/landmark/llm_waypoint/Initialize(mapload)
	. = ..()
	if(!length(waypoint_name))
		var/area/A = get_area(src)
		waypoint_name = A ? trim(A.name) : "Место"
	SSllm_npc.register_waypoint(src)

/obj/effect/landmark/llm_waypoint/Destroy()
	SSllm_npc.unregister_waypoint(src)
	return ..()

// ============================================================================
// Table-Avoiding Peaceful 3D A* Reachability Helper
// ============================================================================

/// Peaceful A* adjacency check: behaves like reachableTurftest3d(), EXCEPT it avoids
/// climbing onto tables/furniture when there is a walkable way around.
/turf/proc/llm_reachable_peaceful(caller, turf/T, ID, recursive_call = 0)
	if(!T || T.density)
		return FALSE
	if(T.z == z)
		if(locate(/obj/structure/table) in T)
			return FALSE
		for(var/obj/structure/S in T)
			if(S.density && S.climbable && !istype(S, /obj/structure/mineral_door))
				return FALSE
	return reachableTurftest3d(caller, T, ID, recursive_call)

// ============================================================================
// World Graph Sub-Datums (Stairs & Location Atlas)
// ============================================================================

/datum/llm_stair_link
	var/datum/weakref/stair_ref
	var/from_z = 0
	var/to_z = 0
	var/move_dir = 0
	var/area_name = ""

/datum/llm_location_info
	var/name = ""
	var/category = "generic"
	var/z_level = 0
	var/area/area_ref
	var/datum/weakref/waypoint_ref
	var/features_summary = "" // e.g. "кровати, стулья, столы, лестница"

// ============================================================================
// Config Entries (keep API keys out of Git via comms.txt, env, or Admin Verb)
// ============================================================================

/datum/config_entry/flag/llm_npc_enabled
	config_entry_value = FALSE

/datum/config_entry/string/llm_npc_api_key
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/llm_npc_model
	config_entry_value = "gemini-4-hydrogen"

/datum/config_entry/string/llm_npc_endpoint
	config_entry_value = "https://generativelanguage.googleapis.com/v1beta/models"

/datum/config_entry/string/llm_npc_thinking_level
	config_entry_value = "low"

/datum/config_entry/number/llm_npc_max_concurrent
	config_entry_value = 4
	min_val = 1
	max_val = 16

/datum/config_entry/number/llm_npc_cooldown_ds
	config_entry_value = 25
	min_val = 10
	max_val = 300

/datum/config_entry/number/llm_npc_ambient_speech_cd_ds
	config_entry_value = 100
	min_val = 40
	max_val = 600

/datum/config_entry/number/llm_npc_max_calls_per_minute
	config_entry_value = 40
	min_val = 1
	max_val = 600

// ============================================================================
// Async In-Flight Request Wrapper
// ============================================================================

/datum/llm_npc_request
	var/datum/http_request/http
	var/datum/llm_npc_brain/brain
	var/kind = LLM_NPC_REQ_TURN
	var/started_at = 0
	var/client/test_requester

/datum/llm_npc_request/New(datum/http_request/req, datum/llm_npc_brain/target_brain, req_kind = LLM_NPC_REQ_TURN, client/requester = null)
	http = req
	brain = target_brain
	kind = req_kind
	started_at = world.time
	test_requester = requester

// ============================================================================
// Subsystem Definition
// ============================================================================

SUBSYSTEM_DEF(llm_npc)
	name = "LLM NPC"
	wait = 0.5 SECONDS
	flags = SS_KEEP_TIMING | SS_BACKGROUND
	priority = FIRE_PRIORITY_NPC_ACTIONS
	init_order = INIT_ORDER_DEFAULT

	/// Active LLM brains currently attached to living human NPCs.
	var/list/datum/llm_npc_brain/brains = list()
	/// Active non-blocking rust_g HTTP requests waiting for completion.
	var/list/datum/llm_npc_request/in_flight = list()
	/// Timestamps (world.time) of requests sent in the last 60s for rate limiting.
	var/list/recent_call_times = list()

	/// Mapper-placed waypoints on the current map.
	var/list/obj/effect/landmark/llm_waypoint/waypoints = list()
	/// Unified location directory: location_name -> /datum/llm_location_info
	var/list/known_locations = null
	/// Multi-Z stair transition index: "[from_z]" -> list(/datum/llm_stair_link)
	var/list/stairs_by_z = null

	/// Shared town rumors & major world events known across NPCs.
	var/list/shared_rumors = list()

	/// Optional runtime overrides (set via Admin Verb without touching disk/Git).
	var/runtime_enabled = null
	var/runtime_api_key = ""
	var/runtime_model = ""
	var/runtime_endpoint = ""
	var/runtime_thinking_level = ""
	var/debug_logging = FALSE

	/// Telemetry & backoff state.
	var/total_calls = 0
	var/succeeded_calls = 0
	var/failed_calls = 0
	var/consecutive_errors = 0
	var/backoff_until = 0
	var/last_error = ""

/datum/controller/subsystem/llm_npc/can_vv_get(var_name)
	if(var_name == NAMEOF(src, runtime_api_key))
		return FALSE
	return ..()

/datum/controller/subsystem/llm_npc/proc/is_enabled()
	if(!isnull(runtime_enabled))
		return runtime_enabled
	if(CONFIG_GET(flag/llm_npc_enabled))
		return TRUE
	return length(get_api_key()) > 0

/datum/controller/subsystem/llm_npc/proc/get_api_key()
	if(length(runtime_api_key))
		return runtime_api_key
	var/cfg_key = CONFIG_GET(string/llm_npc_api_key)
	if(length(cfg_key))
		return cfg_key
	var/env_key = world.GetConfig("env", "GEMINI_API_KEY")
	if(length(env_key))
		return trim(env_key)
	return ""

/datum/controller/subsystem/llm_npc/proc/get_model()
	if(length(runtime_model))
		return runtime_model
	var/cfg_model = CONFIG_GET(string/llm_npc_model)
	return length(cfg_model) ? cfg_model : "gemini-4-hydrogen"

/datum/controller/subsystem/llm_npc/proc/get_endpoint_base()
	if(length(runtime_endpoint))
		return runtime_endpoint
	var/cfg_ep = CONFIG_GET(string/llm_npc_endpoint)
	return length(cfg_ep) ? cfg_ep : "https://generativelanguage.googleapis.com/v1beta/models"

/datum/controller/subsystem/llm_npc/proc/get_thinking_level()
	if(length(runtime_thinking_level))
		return runtime_thinking_level
	var/cfg_lvl = CONFIG_GET(string/llm_npc_thinking_level)
	return length(cfg_lvl) ? cfg_lvl : "low"

/datum/controller/subsystem/llm_npc/proc/get_cooldown_ds()
	var/cd = CONFIG_GET(number/llm_npc_cooldown_ds)
	return cd ? cd : 25

/datum/controller/subsystem/llm_npc/proc/get_ambient_speech_cd_ds()
	var/cd = CONFIG_GET(number/llm_npc_ambient_speech_cd_ds)
	return cd ? cd : 100

/datum/controller/subsystem/llm_npc/proc/register_brain(datum/llm_npc_brain/brain)
	if(!brain || (brain in brains))
		return
	brains += brain

/datum/controller/subsystem/llm_npc/proc/unregister_brain(datum/llm_npc_brain/brain)
	if(!brain)
		return
	brains -= brain

/datum/controller/subsystem/llm_npc/proc/register_waypoint(obj/effect/landmark/llm_waypoint/W)
	if(!W || (W in waypoints))
		return
	waypoints += W
	known_locations = null // invalidate cache so it rebuilds with the new beacon

/datum/controller/subsystem/llm_npc/proc/unregister_waypoint(obj/effect/landmark/llm_waypoint/W)
	if(!W)
		return
	waypoints -= W
	known_locations = null

// ============================================================================
// Shared Town Rumors & Live Chain-of-Command Scanner
// ============================================================================

/datum/controller/subsystem/llm_npc/proc/add_shared_rumor(rumor_text, source_name = "")
	var/clean = trim(rumor_text)
	if(!length(clean))
		return
	var/entry = "\[[station_time_timestamp()]\] [clean]"
	// Avoid near-duplicate rumors
	var/low = llm_lower_ru(clean)
	for(var/existing in shared_rumors)
		if(findtext(llm_lower_ru(existing), low))
			return
	shared_rumors += entry
	if(length(shared_rumors) > LLM_MAX_SHARED_RUMORS)
		shared_rumors.Cut(1, 2)

/datum/controller/subsystem/llm_npc/proc/get_authority_summary()
	var/list/lines = list()
	var/static/list/command_roles = list(
		"Lord", "King", "Consort", "Prince", "Hand", "Steward", "Bailiff",
		"Captain", "Watchcaptain", "Warden", "Wardenmaster", "Sergeant",
		"Priest", "Chaplain", "Absolutionist", "Orthodoxist", "Puritan"
	)
	for(var/mob/living/carbon/human/H in GLOB.human_list)
		if(!H || QDELETED(H) || H.stat == DEAD)
			continue
		var/j = H.job
		if(!length(j))
			continue
		if((j in command_roles) || (j in GLOB.noble_positions))
			var/area/A = get_area(H)
			var/loc_hint = A ? trim(A.name) : "город"
			lines += "[j]: [H.real_name] (видели у «[loc_hint]»)"
			if(length(lines) >= 8)
				break
	return length(lines) ? jointext(lines, "; ") : "Старших представителей власти пока не слышно."

/datum/controller/subsystem/llm_npc/proc/find_authority_mob(query = "", preferred_z = 0)
	var/q = llm_lower_ru(trim(query))
	var/mob/living/carbon/human/best = null
	for(var/mob/living/carbon/human/H in GLOB.human_list)
		if(!H || QDELETED(H) || H.stat == DEAD)
			continue
		var/j = llm_lower_ru(H.job || "")
		var/n = llm_lower_ru(H.real_name || "")
		var/is_auth = (H.job in GLOB.noble_positions) || (H.job in GLOB.garrison_positions) || (H.job in GLOB.courtier_positions)
		if(length(q))
			if(findtext(j, q) || findtext(n, q))
				return H
		else if(is_auth)
			if(!best || (preferred_z && H.z == preferred_z && best.z != preferred_z))
				best = H
	return best

// ============================================================================
// 3D World Atlas & Multi-Z Stair Graph Builder
// ============================================================================

/datum/controller/subsystem/llm_npc/proc/build_world_graph(force = FALSE)
	if(known_locations && stairs_by_z && !force)
		return
	known_locations = list()
	stairs_by_z = list()

	// 1) Index mapper-placed /obj/effect/landmark/llm_waypoint beacons FIRST (highest priority)
	for(var/obj/effect/landmark/llm_waypoint/W as anything in waypoints)
		if(!W || QDELETED(W))
			continue
		var/turf/T = get_turf(W)
		if(!T)
			continue
		var/datum/llm_location_info/info = new()
		info.name = W.waypoint_name
		info.category = W.waypoint_category
		info.z_level = T.z
		info.area_ref = get_area(W)
		info.waypoint_ref = WEAKREF(W)
		info.features_summary = W.waypoint_desc
		known_locations[info.name] = info

	// 2) Auto-scan playable areas and interior features (beds, chairs, tables, doors, stairs)
	var/static/list/skip_prefixes = list(
		"Space", "CentCom", "Admin", "Shuttle", "Area", "Template", "Underworld"
	)
	for(var/area/A as anything in GLOB.sortedAreas)
		if(!A || !A.name || A.type == /area)
			continue
		var/clean_name = trim(A.name)
		if(!length(clean_name) || (clean_name in known_locations))
			continue
		var/skip = FALSE
		for(var/prefix in skip_prefixes)
			if(findtext(clean_name, prefix, 1, length(prefix) + 1))
				skip = TRUE
				break
		if(skip)
			continue

		var/turf/sample = find_walkable_turf_in_area(A)
		if(!sample)
			continue

		var/datum/llm_location_info/info = new()
		info.name = clean_name
		info.z_level = sample.z
		info.area_ref = A
		info.features_summary = scan_area_features(A)
		info.category = infer_area_category(clean_name, info.features_summary)
		known_locations[clean_name] = info
		if(length(known_locations) >= 48)
			break

	// 3) Scan all /obj/structure/stairs across the map to build the 3D Z-level transition graph
	for(var/obj/structure/stairs/S in world)
		var/turf/st_turf = get_turf(S)
		if(!st_turf)
			continue
		var/area/st_area = get_area(S)
		var/st_aname = st_area ? trim(st_area.name) : ""

		// Check UP link
		var/turf/up_dest = S.get_target_loc(S.dir)
		if(up_dest && up_dest.z != st_turf.z)
			var/datum/llm_stair_link/link_up = new()
			link_up.stair_ref = WEAKREF(S)
			link_up.from_z = st_turf.z
			link_up.to_z = up_dest.z
			link_up.move_dir = S.dir
			link_up.area_name = st_aname
			var/zkey = "[st_turf.z]"
			if(!stairs_by_z[zkey])
				stairs_by_z[zkey] = list()
			stairs_by_z[zkey] += link_up

		// Check DOWN link
		var/rev_d = REVERSE_DIR(S.dir)
		var/turf/down_dest = S.get_target_loc(rev_d)
		if(down_dest && down_dest.z != st_turf.z)
			var/datum/llm_stair_link/link_dn = new()
			link_dn.stair_ref = WEAKREF(S)
			link_dn.from_z = st_turf.z
			link_dn.to_z = down_dest.z
			link_dn.move_dir = rev_d
			link_dn.area_name = st_aname
			var/zkey_d = "[st_turf.z]"
			if(!stairs_by_z[zkey_d])
				stairs_by_z[zkey_d] = list()
			stairs_by_z[zkey_d] += link_dn

/datum/controller/subsystem/llm_npc/proc/scan_area_features(area/A)
	var/has_bed = FALSE
	var/has_chair = FALSE
	var/has_table = FALSE
	var/has_stairs = FALSE
	var/checked = 0
	for(var/turf/open/T in A)
		checked++
		if(checked > 90)
			break
		if(!has_bed && (locate(/obj/structure/bed) in T))
			has_bed = TRUE
		if(!has_chair && (locate(/obj/structure/chair) in T))
			has_chair = TRUE
		if(!has_table && (locate(/obj/structure/table) in T))
			has_table = TRUE
		if(!has_stairs && (locate(/obj/structure/stairs) in T))
			has_stairs = TRUE
		if(has_bed && has_chair && has_table && has_stairs)
			break
	var/list/feats = list()
	if(has_bed)
		feats += "кровати"
	if(has_chair)
		feats += "стулья"
	if(has_table)
		feats += "столы"
	if(has_stairs)
		feats += "лестница"
	return jointext(feats, ", ")

/datum/controller/subsystem/llm_npc/proc/infer_area_category(area_name, features)
	var/la = llm_lower_ru(area_name)
	if(findtext(la, "tavern") || findtext(la, "inn") || findtext(la, "таверн") || findtext(la, "трактир"))
		return "tavern"
	if(findtext(la, "dungeon") || findtext(la, "prison") || findtext(la, "cell") || findtext(la, "jail") || findtext(la, "темниц") || findtext(la, "камер"))
		return "prison"
	if(findtext(la, "church") || findtext(la, "chapel") || findtext(la, "cathedral") || findtext(la, "церк") || findtext(la, "храм"))
		return "church"
	if(findtext(la, "garrison") || findtext(la, "barrack") || findtext(la, "guard") || findtext(la, "казарм"))
		return "barracks"
	if(findtext(la, "keep") || findtext(la, "throne") || findtext(la, "lord") || findtext(la, "замок") || findtext(la, "зал"))
		return "keep"
	if(findtext(la, "market") || findtext(la, "square") || findtext(la, "рынок") || findtext(la, "площад"))
		return "market"
	if(findtext(features, "кровати"))
		return "bedroom"
	return "generic"

/datum/controller/subsystem/llm_npc/proc/find_walkable_turf_in_area(area/A, preferred_z = 0)
	if(!A)
		return null
	var/turf/fallback = null
	var/checked = 0
	for(var/turf/open/T in A)
		checked++
		if(checked > 90)
			break
		if(T.density || istransparentturf(T) || (locate(/obj/structure/table) in T))
			continue
		if(!preferred_z || T.z == preferred_z)
			return T
		if(!fallback)
			fallback = T
	return fallback

/datum/controller/subsystem/llm_npc/proc/find_location_info(query)
	if(!length(query))
		return null
	build_world_graph()
	var/q = llm_lower_ru(trim(query))
	// Exact name match
	for(var/name_key in known_locations)
		if(llm_lower_ru(name_key) == q)
			return known_locations[name_key]
	// Category alias match (e.g. "камера", "темница", "таверна", "кровать")
	var/cat_hint = ""
	if(findtext(q, "камер") || findtext(q, "темниц") || findtext(q, "тюрьм") || findtext(q, "prison") || findtext(q, "dungeon") || findtext(q, "cell"))
		cat_hint = "prison"
	else if(findtext(q, "таверн") || findtext(q, "трактир") || findtext(q, "tavern") || findtext(q, "inn"))
		cat_hint = "tavern"
	else if(findtext(q, "церк") || findtext(q, "храм") || findtext(q, "church") || findtext(q, "chapel"))
		cat_hint = "church"
	else if(findtext(q, "казарм") || findtext(q, "страж") || findtext(q, "garrison") || findtext(q, "barrack"))
		cat_hint = "barracks"
	else if(findtext(q, "кроват") || findtext(q, "спальн") || findtext(q, "bed"))
		cat_hint = "bedroom"

	// Substring name match first
	for(var/name_key in known_locations)
		var/lname = llm_lower_ru(name_key)
		if(findtext(lname, q) || findtext(q, lname))
			return known_locations[name_key]

	// Category fallback
	if(length(cat_hint))
		for(var/name_key in known_locations)
			var/datum/llm_location_info/info = known_locations[name_key]
			if(info.category == cat_hint)
				return info
	return null

/datum/controller/subsystem/llm_npc/proc/resolve_location_turf(datum/llm_location_info/info, preferred_z = 0)
	if(!info)
		return null
	var/obj/effect/landmark/llm_waypoint/W = info.waypoint_ref?.resolve()
	if(W)
		return get_turf(W)
	return find_walkable_turf_in_area(info.area_ref, preferred_z)

/// Finds the nearest /datum/llm_stair_link on from_turf.z that moves one Z-level toward target_z.
/datum/controller/subsystem/llm_npc/proc/find_stairs_for_z_step(turf/from_turf, target_z)
	if(!from_turf || from_turf.z == target_z)
		return null
	build_world_graph()
	var/want_z = from_turf.z + (target_z > from_turf.z ? 1 : -1)
	var/list/links = stairs_by_z["[from_turf.z]"]
	if(!islist(links) || !length(links))
		return null
	var/datum/llm_stair_link/best = null
	var/best_dist = 999999
	for(var/datum/llm_stair_link/L as anything in links)
		if(L.to_z != want_z)
			continue
		var/obj/structure/stairs/S = L.stair_ref?.resolve()
		if(!S)
			continue
		var/d = get_dist(from_turf, S)
		if(d < best_dist)
			best_dist = d
			best = L
	return best

/datum/controller/subsystem/llm_npc/proc/get_known_location_summaries(current_z = 0, limit = 18)
	build_world_graph()
	var/list/out = list()
	for(var/name_key in known_locations)
		var/datum/llm_location_info/info = known_locations[name_key]
		var/z_tag = (current_z && info.z_level != current_z) ? " (Z[info.z_level])" : ""
		var/feat_tag = length(info.features_summary) ? " \[есть: [info.features_summary]\]" : ""
		out += "[info.name][z_tag][feat_tag]"
		if(length(out) >= limit)
			break
	return out

// ============================================================================
// Rate Limiting & Gemini REST Client (Direct Async HTTPS via rust_g)
// ============================================================================

/datum/controller/subsystem/llm_npc/proc/can_dispatch_call()
	if(!is_enabled())
		return FALSE
	if(!length(get_api_key()))
		return FALSE
	if(world.time < backoff_until)
		return FALSE
	var/max_conc = CONFIG_GET(number/llm_npc_max_concurrent) || 4
	if(length(in_flight) >= max_conc)
		return FALSE
	var/cutoff = world.time - LLM_NPC_RATE_WINDOW
	while(length(recent_call_times) && recent_call_times[1] < cutoff)
		recent_call_times.Cut(1, 2)
	var/max_rpm = CONFIG_GET(number/llm_npc_max_calls_per_minute) || 40
	if(length(recent_call_times) >= max_rpm)
		return FALSE
	return TRUE

/datum/controller/subsystem/llm_npc/proc/send_gemini_request(
	datum/llm_npc_brain/brain,
	req_kind,
	system_prompt,
	user_prompt,
	list/response_schema,
	thinking_level = null,
	temperature = 0.8,
	max_output_tokens = 850,
	client/test_requester = null
)
	var/api_key = get_api_key()
	if(!length(api_key))
		last_error = "Gemini API key is not configured."
		return FALSE

	var/model = get_model()
	var/endpoint_base = trim_right(get_endpoint_base())
	while(length(endpoint_base) && copytext(endpoint_base, length(endpoint_base)) == "/")
		endpoint_base = copytext(endpoint_base, 1, length(endpoint_base))
	var/url = "[endpoint_base]/[model]:generateContent"

	var/lvl = thinking_level ? thinking_level : get_thinking_level()
	var/list/gen_cfg = list(
		"temperature" = temperature,
		"maxOutputTokens" = max_output_tokens,
		"responseMimeType" = "application/json",
		"responseJsonSchema" = response_schema
	)
	if(length(lvl) && LOWER_TEXT(lvl) != "off")
		gen_cfg["thinkingConfig"] = list("thinkingLevel" = LOWER_TEXT(lvl))

	var/list/payload = list(
		"systemInstruction" = list(
			"parts" = list(list("text" = system_prompt))
		),
		"contents" = list(
			list(
				"role" = "user",
				"parts" = list(list("text" = user_prompt))
			)
		),
		"generationConfig" = gen_cfg
	)

	var/body_json = json_encode(payload)
	var/list/headers = list(
		"Content-Type" = "application/json",
		"x-goog-api-key" = api_key
	)

	var/datum/http_request/req = new()
	req.prepare(RUSTG_HTTP_METHOD_POST, url, body_json, headers)
	req.begin_async()

	if(!req.in_progress)
		failed_calls++
		last_error = "Failed to dispatch rust_g async HTTP request."
		return FALSE

	total_calls++
	recent_call_times += world.time
	in_flight += new /datum/llm_npc_request(req, brain, req_kind, test_requester)
	if(debug_logging)
		log_game("SSllm_npc: Dispatched [req_kind] to [model] ([length(body_json)] bytes) for [brain ? brain.owner : "TEST"].")
	return TRUE

/datum/controller/subsystem/llm_npc/proc/send_test_request(client/requester)
	var/list/schema = list(
		"type" = "object",
		"properties" = list(
			"ok" = list("type" = "boolean"),
			"greeting" = list("type" = "string")
		),
		"required" = list("ok", "greeting")
	)
	return send_gemini_request(
		brain = null,
		req_kind = LLM_NPC_REQ_TEST,
		system_prompt = "Ты средневековый трактирный завсегдатай в мире Ratwood. Ответь строго в JSON.",
		user_prompt = "Верни ok=true и короткое атмосферное приветствие на русском (до 12 слов) для проверки связи.",
		response_schema = schema,
		thinking_level = get_thinking_level(),
		temperature = 0.7,
		max_output_tokens = 256,
		test_requester = requester
	)

/datum/controller/subsystem/llm_npc/fire(resumed = FALSE)
	// 1) Poll in-flight HTTP requests
	if(length(in_flight))
		var/list/completed = list()
		for(var/datum/llm_npc_request/entry as anything in in_flight)
			if(!entry || !entry.http)
				completed += entry
				continue
			if(entry.http.is_complete())
				completed += entry
				handle_completed_request(entry)
			else if(world.time - entry.started_at > LLM_NPC_REQUEST_TIMEOUT)
				completed += entry
				handle_timed_out_request(entry)
			if(MC_TICK_CHECK)
				break
		if(length(completed))
			in_flight -= completed

	if(!length(brains))
		return

	// 2) Tick brains
	var/list/dead_brains = list()
	for(var/datum/llm_npc_brain/brain as anything in brains)
		if(!brain || QDELETED(brain) || !brain.owner || QDELETED(brain.owner))
			dead_brains += brain
			continue
		brain.tick_brain()
		if(MC_TICK_CHECK)
			break
	if(length(dead_brains))
		brains -= dead_brains

/datum/controller/subsystem/llm_npc/proc/handle_timed_out_request(datum/llm_npc_request/entry)
	failed_calls++
	consecutive_errors++
	last_error = "Request timed out after [LLM_NPC_REQUEST_TIMEOUT / 10]s ([entry.kind])."
	if(entry.brain && !QDELETED(entry.brain))
		entry.brain.on_llm_error(entry.kind, last_error)
	if(entry.test_requester)
		to_chat(entry.test_requester, span_boldwarning("\[LLM NPC Test\] Timeout: [last_error]"))

/datum/controller/subsystem/llm_npc/proc/handle_completed_request(datum/llm_npc_request/entry)
	var/datum/http_response/resp = entry.http.into_response()
	var/elapsed_ms = round((world.time - entry.started_at) * 100)

	if(!resp || resp.errored)
		failed_calls++
		consecutive_errors++
		last_error = "HTTP transport error: [resp ? resp.error : "null response"]"
		apply_error_backoff()
		if(entry.brain && !QDELETED(entry.brain))
			entry.brain.on_llm_error(entry.kind, last_error)
		if(entry.test_requester)
			to_chat(entry.test_requester, span_boldwarning("\[LLM NPC Test\] Transport Error: [last_error]"))
		return

	if(resp.status_code < 200 || resp.status_code >= 300)
		failed_calls++
		consecutive_errors++
		var/err_detail = copytext_char("[resp.body]", 1, 240)
		last_error = "HTTP [resp.status_code]: [err_detail]"
		apply_error_backoff()
		if(entry.brain && !QDELETED(entry.brain))
			entry.brain.on_llm_error(entry.kind, last_error)
		if(entry.test_requester)
			to_chat(entry.test_requester, span_boldwarning("\[LLM NPC Test\] [last_error]"))
		return

	var/list/parsed = extract_gemini_json(resp.body)
	if(!islist(parsed))
		failed_calls++
		consecutive_errors++
		last_error = "Invalid JSON from Gemini: [copytext_char("[resp.body]", 1, 200)]"
		if(entry.brain && !QDELETED(entry.brain))
			entry.brain.on_llm_error(entry.kind, last_error)
		if(entry.test_requester)
			to_chat(entry.test_requester, span_boldwarning("\[LLM NPC Test\] [last_error]"))
		return

	succeeded_calls++
	consecutive_errors = 0
	backoff_until = 0

	if(entry.kind == LLM_NPC_REQ_TEST)
		if(entry.test_requester)
			to_chat(entry.test_requester, span_notice("\[LLM NPC Test\] OK in ~[elapsed_ms]ms via [get_model()]: \"[parsed["greeting"]]\""))
		return

	if(!entry.brain || QDELETED(entry.brain))
		return

	if(entry.kind == LLM_NPC_REQ_REFLECT)
		entry.brain.on_llm_reflection(parsed)
	else
		entry.brain.on_llm_decision(parsed, elapsed_ms)

/datum/controller/subsystem/llm_npc/proc/apply_error_backoff()
	if(consecutive_errors >= 3)
		var/delay = min(60 SECONDS, (2 ** min(consecutive_errors - 2, 5)) SECONDS)
		backoff_until = world.time + delay

/datum/controller/subsystem/llm_npc/proc/extract_gemini_json(raw_body)
	if(!length(raw_body))
		return null
	var/list/root
	try
		root = json_decode(raw_body)
	catch
		return null
	if(!islist(root))
		return null
	var/list/candidates = root["candidates"]
	if(!islist(candidates) || !length(candidates))
		return null
	var/list/first = candidates[1]
	if(!islist(first))
		return null
	var/list/content = first["content"]
	if(!islist(content))
		return null
	var/list/parts = content["parts"]
	if(!islist(parts) || !length(parts))
		return null

	var/model_text = null
	for(var/list/part as anything in parts)
		if(!islist(part))
			continue
		if(part["thought"])
			continue
		if(istext(part["text"]) && length(trim(part["text"])))
			model_text = trim(part["text"])
			break
	if(!length(model_text))
		return null

	if(copytext(model_text, 1, 4) == "```")
		var/first_nl = findtext(model_text, "\n")
		if(first_nl)
			model_text = copytext(model_text, first_nl + 1)
		var/end_fence = findtext(model_text, "```")
		if(end_fence)
			model_text = copytext(model_text, 1, end_fence)
		model_text = trim(model_text)

	var/list/decoded
	try
		decoded = json_decode(model_text)
	catch
		return null
	return islist(decoded) ? decoded : null
