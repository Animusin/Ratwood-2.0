// Explicitly enabled autonomous replies only. No punishment or general proccall.
/datum/config_entry/flag/herald_duty_enabled

/proc/herald_duty_now()
	return "[time2text(world.realtime, "YYYY-MM-DD", TIMEZONE_UTC)]T[time2text(world.realtime, "hh:mm:ss", TIMEZONE_UTC)]Z"

/proc/herald_duty_word_count(text)
	// Match Python str.split(), including non-breaking/Unicode spaces.
	var/count = 0
	var/in_word = FALSE
	for(var/i in 1 to length_char(text))
		switch(text2ascii_char(text, i))
			if(9 to 13, 28 to 32, 133, 160, 5760, 8192 to 8202, 8232, 8233, 8239, 8287, 12288)
				in_word = FALSE
			else
				if(!in_word)
					count++
					in_word = TRUE
	return count

/proc/herald_duty_admin_presence()
	var/list/result = list("known" = TRUE, "active" = 0, "total" = 0)
	if(!islist(GLOB.clients) || length(GLOB.clients) > 1000)
		result["known"] = FALSE
		return result
	for(var/client/C in GLOB.clients)
		if(!C || QDELETED(C))
			result["known"] = FALSE
			continue
		// ANY connected staff pauses game replies: AFK, stealth and deadmin too.
		if(C.holder || GLOB.admin_datums[C.ckey] || GLOB.deadmins[C.ckey])
			result["total"]++
			if(C.holder?.rank && (C.holder.rank.rights & R_AHELP) && !C.is_afk())
				result["active"]++
	return result

/datum/admin_help/proc/HeraldDutyConnected()
	return initiator && !QDELETED(initiator) && initiator.ckey == initiator_ckey && initiator.current_ticket == src

/datum/admin_help/proc/HeraldDutyReply(message)
	// No usr spoofing and no configured human admin's name in the actor label.
	if(!HeraldDutyConnected() || state != AHELP_ACTIVE)
		return "player_offline"
	var/body = herald_ahelp_body(message)
	AddInteraction("<font color='blue'>PM from Геральд (автоматический дежурный): [body]</font>", "duty", "Геральд")
	herald_last_duty_player_revision = herald_player_revision
	herald_duty_next_reply = world.time + 1 MINUTES
	to_chat(initiator, span_adminhelp("<b>Геральд — автоматический помощник администрации</b>: [body]<br><i>Это ответ ИИ, а не решение человека. Ответить можно в текущем Adminhelp.</i>"))
	SEND_SOUND(initiator, sound('sound/adminhelp.ogg'))
	window_flash(initiator, ignorepref = TRUE)
	log_admin_private("Herald duty replied to ahelp #[id] ([initiator_ckey]): [message]")
	return "delivered"

/datum/world_topic/herald_duty
	keyword = "herald_duty"
	log = FALSE
	var/static/next_read = 0
	var/static/next_reply = 0
	var/static/list/nonces = list()
	var/static/list/receipts = list()
	var/static/recovered = FALSE
	var/static/generation = 0
	var/static/busy = FALSE
	var/static/recovery_failed = FALSE

/datum/world_topic/herald_duty/proc/authority(operator)
	if(!(operator in splittext(CONFIG_GET(string/herald_admin_operator_ids), ",")))
		return FALSE
	var/ck = CONFIG_GET(string/herald_admin_ckey)
	var/datum/admins/A = GLOB.admin_datums[ck] || GLOB.deadmins[ck]
	return A?.rank && (A.rank.rights & R_AHELP)

/datum/world_topic/herald_duty/proc/admin_presence()
	return herald_duty_admin_presence()

/datum/world_topic/herald_duty/proc/persist()
	generation++
	var/path = "data/herald_duty_receipts_[generation % 2].json"
	if(fexists(path))
		fdel(path)
	return text2file(json_encode(list("round" = "[GLOB.rogue_round_id]", "generation" = generation, "receipts" = receipts)), path)

/datum/world_topic/herald_duty/proc/valid_receipts(list/entries)
	if(!islist(entries) || length(entries) > 512)
		return FALSE
	for(var/id in entries)
		if(!istext(id) || !regex("^\[a-f0-9\]{32}$").Find(id))
			return FALSE
		var/list/entry = entries[id]
		if(!islist(entry) || !istext(entry["fingerprint"]) || !length(entry["fingerprint"]) || length(entry["fingerprint"]) > 300)
			return FALSE
		var/list/result = entry["result"]
		if(!islist(result) || result["action"] != "reply" || result["round"] != "[GLOB.rogue_round_id]" || result["request_id"] != id || !istext(result["ckey"]) || !regex("^\[a-z0-9\]{1,32}$").Find(result["ckey"]))
			return FALSE
		if(!isnum(result["ticket_id"]) || result["ticket_id"] != round(result["ticket_id"]) || result["ticket_id"] < 1 || result["ticket_id"] > 9999999 || !isnum(result["version"]) || result["version"] != round(result["version"]) || result["version"] < 0 || result["version"] > 10000000)
			return FALSE
		if(!(result["status"] in list("delivered", "operation_uncertain", "human_present", "human_handled", "ticket_changed", "player_offline", "disabled", "admin_rights_denied", "no_new_player_message", "cooldown", "snapshot_unknown")))
			return FALSE
		if(result["status"] == "delivered" && (!isnum(result["new_version"]) || result["new_version"] <= result["version"]))
			return FALSE
	return TRUE

/datum/world_topic/herald_duty/proc/recover()
	if(recovered)
		return
	recovered = TRUE
	for(var/path in list("data/herald_duty_receipts_0.json", "data/herald_duty_receipts_1.json"))
		if(!fexists(path))
			continue
		try
			var/list/saved = json_decode(file2text(path))
			if(islist(saved) && istext(saved["round"]) && saved["round"] != "[GLOB.rogue_round_id]")
				continue // Explicitly different round, not a corrupt current ledger.
			if(!islist(saved) || saved["round"] != "[GLOB.rogue_round_id]" || !isnum(saved["generation"]) || saved["generation"] != round(saved["generation"]) || saved["generation"] < 1 || !valid_receipts(saved["receipts"]))
				recovery_failed = TRUE
				continue
			if(saved["generation"] > generation)
				generation = saved["generation"]
				receipts = saved["receipts"]
		catch
			recovery_failed = TRUE
	if(recovery_failed)
		log_admin("Herald duty paused: unreadable receipt checkpoint; no new replies until reviewed. Credentials hidden.")

/datum/world_topic/herald_duty/proc/envelope(prefix, identity, list/data)
	var/payload = json_encode(data)
	if(prefix == "duty_snapshot_response")
		// Outer JSON quotes/escapes this JSON string again. Reserve >2x room
		// within the client's 60000-byte Topic frame, even for control text.
		var/list/rows = data["tickets"]
		while(length(payload) > 24000 && length(rows))
			rows.Cut(length(rows), length(rows) + 1)
			data["truncated"] = TRUE
			payload = json_encode(data)
	return json_encode(list("data" = payload, "signature" = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "[prefix]|[identity]|[payload]")))

/datum/world_topic/herald_duty/proc/snapshot()
	var/list/tickets = list()
	var/total = length(GLOB.ahelp_tickets?.active_tickets)
	// New unhandled player messages take precedence over old open/handled
	// tickets. After a duty reply their priority drops until the player writes.
	// At most 1000 tickets inspected twice; no world/inventory traversal.
	for(var/pass in 1 to 2)
		for(var/i in 1 to min(total, 1000))
			if(length(tickets) >= 10)
				break
			var/datum/admin_help/T = GLOB.ahelp_tickets.active_tickets[i]
			var/pending_player = !length(T.herald_handler) && T.herald_player_revision > T.herald_last_duty_player_revision && T.HeraldDutyConnected()
			if((pass == 1 && !pending_player) || (pass == 2 && pending_player))
				continue
			var/list/interactions = list()
			for(var/j in max(1, length(T.herald_interactions) - 2) to length(T.herald_interactions))
				interactions += list(T.herald_interactions[j].Copy())
			tickets += list(list("id" = T.id, "ckey" = T.initiator_ckey, "state" = "active", "version" = T.herald_revision,
				"handler" = T.herald_handler, "human_active" = !!length(T.herald_handler), "online" = !!T.HeraldDutyConnected(),
				"last_interactions" = interactions))
	return list("read_only" = TRUE, "duty_enabled" = TRUE, "round" = "[GLOB.rogue_round_id]", "generated_at" = herald_duty_now(),
		"admins" = admin_presence(), "tickets" = tickets, "truncated" = total > 10, "total_active" = total,
		"runtimes" = list("total" = GLOB.total_runtimes, "skipped" = GLOB.total_runtimes_skipped))

/datum/world_topic/herald_duty/proc/guard(datum/admin_help/T, ck, version)
	var/list/staff = admin_presence()
	if(!staff["known"])
		return "snapshot_unknown"
	if(staff["total"] > 0)
		return "human_present"
	if(!T || T.state != AHELP_ACTIVE || T.initiator_ckey != ck || T.herald_revision != version)
		return "ticket_changed"
	if(length(T.herald_handler))
		return "human_handled"
	if(!T.HeraldDutyConnected())
		return "player_offline"
	if(T.herald_player_revision <= T.herald_last_duty_player_revision)
		return "no_new_player_message"
	if(world.time < T.herald_duty_next_reply)
		return "cooldown"
	return null

/datum/world_topic/herald_duty/TryRun(list/input)
	if(!config || !CONFIG_GET(flag/herald_duty_enabled) || length(CONFIG_GET(string/herald_readonly_key)) < 64 || !GLOB.ahelp_tickets)
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	if(!(action in list("snapshot", "reply")))
		return json_encode(list("error" = "unsupported_action"))
	var/list/allowed = action == "snapshot" ? list(keyword, "minute", "nonce", "operator", "signature") : list(keyword, "round", "ckey", "payload", "minute", "request_id", "operator", "signature")
	for(var/key in input)
		if(!(key in allowed))
			return json_encode(list("error" = "invalid_argument"))
	var/stamp = input["minute"]
	var/operator = input["operator"]
	var/secret = CONFIG_GET(string/herald_readonly_key)
	if(!istext(stamp) || !regex("^\[0-9\]{1,10}$").Find(stamp) || !istext(operator) || !regex("^\[0-9\]{1,20}$").Find(operator))
		return json_encode(list("error" = "invalid_argument"))
	var/current_minute = round(world.realtime / 600) + 15778080
	if(abs(text2num(stamp) - current_minute) > 3)
		return json_encode(list("error" = "expired"))
	if(action == "snapshot")
		var/nonce = input["nonce"]
		if(!istext(nonce) || !regex("^\[a-f0-9\]{32}$").Find(nonce))
			return json_encode(list("error" = "invalid_argument"))
		if(input["signature"] != herald_read_signature(secret, "duty_snapshot|[stamp]|[nonce]|[operator]"))
			return json_encode(list("error" = "unauthorized"))
		if(!authority(operator))
			return json_encode(list("error" = "admin_rights_denied"))
		if(world.time < next_read)
			return json_encode(list("error" = "rate_limited"))
		next_read = world.time + 2 SECONDS
		for(var/old in nonces.Copy())
			if(nonces[old] < world.time)
				nonces -= old
		if(nonces[nonce] || length(nonces) >= 128)
			return json_encode(list("error" = "replayed_or_busy"))
		nonces[nonce] = world.time + 4 MINUTES
		return envelope("duty_snapshot_response", nonce, snapshot())
	var/round_id = input["round"]
	var/ck = input["ckey"]
	var/payload = input["payload"]
	var/request_id = input["request_id"]
	if(!istext(round_id) || !regex("^\[A-Za-z0-9_.-\]{1,100}$").Find(round_id) || !istext(ck) || !regex("^\[a-z0-9\]{1,32}$").Find(ck) || !istext(payload) || length(payload) > 8000 || !istext(request_id) || !regex("^\[a-f0-9\]{32}$").Find(request_id))
		return json_encode(list("error" = "invalid_argument"))
	var/hash = rustg_hash_string(RUSTG_HASH_SHA256, payload)
	if(input["signature"] != herald_read_signature(secret, "duty_request|[round_id]|[ck]|[hash]|[stamp]|[request_id]|[operator]"))
		return json_encode(list("error" = "unauthorized"))
	if(!authority(operator))
		return json_encode(list("error" = "admin_rights_denied"))
	var/list/data
	try
		data = json_decode(payload)
	catch
		return json_encode(list("error" = "invalid_argument"))
	if(!islist(data) || length(data) != 3)
		return json_encode(list("error" = "invalid_argument"))
	for(var/key in data)
		if(!(key in list("ticket_id", "version", "text")))
			return json_encode(list("error" = "invalid_argument"))
	var/text = data["text"]
	if(!isnum(data["ticket_id"]) || data["ticket_id"] != round(data["ticket_id"]) || data["ticket_id"] < 1 || data["ticket_id"] > 9999999 || !isnum(data["version"]) || data["version"] != round(data["version"]) || data["version"] < 0 || data["version"] > 10000000 || !istext(text) || !length(trim(text)) || length_char(text) > 1000)
		return json_encode(list("error" = "invalid_argument"))
	if(herald_duty_word_count(text) > 30)
		return json_encode(list("error" = "invalid_argument"))
	if(round_id != "[GLOB.rogue_round_id]")
		return json_encode(list("error" = "wrong_round"))
	recover()
	if(recovery_failed)
		return json_encode(list("error" = "receipt_storage_failed"))
	var/fingerprint = "[round_id]|[ck]|[hash]|[operator]"
	var/list/previous = receipts[request_id]
	if(previous)
		if(previous["fingerprint"] != fingerprint)
			return json_encode(list("error" = "request_id_conflict"))
		var/list/old_result = previous["result"]
		var/list/cached = old_result.Copy()
		cached["duplicate"] = TRUE
		return envelope("duty_response", request_id, cached)
	if(busy || world.time < next_reply || length(receipts) >= 512)
		return json_encode(list("error" = "rate_limited"))
	var/datum/admin_help/T
	for(var/i in 1 to min(length(GLOB.ahelp_tickets.active_tickets), 1000))
		var/datum/admin_help/candidate = GLOB.ahelp_tickets.active_tickets[i]
		if(candidate.id == data["ticket_id"])
			T = candidate
			break
	var/list/result = list("action" = "reply", "round" = round_id, "ckey" = ck, "ticket_id" = data["ticket_id"], "version" = data["version"], "request_id" = request_id, "status" = "operation_uncertain")
	var/refusal = guard(T, ck, data["version"])
	if(refusal)
		result["status"] = refusal
		return envelope("duty_response", request_id, result)
	// Reserve durably before touching a player's ticket, then recheck all guards.
	receipts[request_id] = list("fingerprint" = fingerprint, "result" = result)
	if(!persist())
		receipts -= request_id
		return json_encode(list("error" = "receipt_storage_failed"))
	busy = TRUE
	next_reply = world.time + 10 SECONDS
	try
		refusal = !CONFIG_GET(flag/herald_duty_enabled) ? "disabled" : (!authority(operator) ? "admin_rights_denied" : guard(T, ck, data["version"]))
		if(round_id != "[GLOB.rogue_round_id]")
			refusal = "ticket_changed"
		result["status"] = refusal || T.HeraldDutyReply(text)
		result["new_version"] = T?.herald_revision
	catch
		log_admin("Herald duty reply [request_id] uncertain after internal error; no automatic repeat.")
	busy = FALSE
	if(!persist())
		result["warning"] = "Receipt update failed; uncertain reservation retained on disk. Do not repeat."
	log_admin("Herald automatic duty ahelp #[data["ticket_id"]], request [request_id], status [result["status"]].")
	return envelope("duty_response", request_id, result)
