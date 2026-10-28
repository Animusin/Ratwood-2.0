// Explicit Discord staff handoff. This does not weaken ordinary duty or SDQL.
// Discord roles/messages are attested by the authenticated backend, not players.
/datum/config_entry/flag/herald_cases_enabled

/datum/config_entry/flag/herald_delegated_admin_enabled

/datum/config_entry/string/herald_case_role_ids

/datum/config_entry/string/herald_case_role_ids/ValidateAndSet(str_val)
	return herald_case_role_config(str_val) && ..(str_val)

/datum/config_entry/string/herald_sanction_role_ids

/datum/config_entry/string/herald_sanction_role_ids/ValidateAndSet(str_val)
	return herald_case_role_config(str_val) && ..(str_val)

/datum/config_entry/string/herald_sanction_approval_channel_id
	config_entry_value = "1252341888023789568"

/datum/config_entry/string/herald_sanction_approval_channel_id/ValidateAndSet(str_val)
	return herald_case_id(str_val, "snowflake") && ..()

/proc/herald_case_role_config(value)
	if(!istext(value))
		return FALSE
	if(!length(value))
		return TRUE
	var/list/roles = splittext(value, ",")
	if(length(roles) > 32)
		return FALSE
	for(var/id in roles)
		if(!herald_case_id(id, "snowflake"))
			return FALSE
	return TRUE

/proc/herald_case_id(value, kind = "hex")
	if(!istext(value))
		return FALSE
	switch(kind)
		if("snowflake")
			return regex("^\[0-9\]{1,22}$").Find(value) && value != "0"
		if("round")
			return regex("^\[A-Za-z0-9_.-\]{1,100}$").Find(value)
		if("ckey")
			return regex("^\[a-z0-9\]{1,32}$").Find(value)
	return regex("^\[a-f0-9\]{32}$").Find(value)

/proc/herald_case_number(value, minimum = 0, maximum = 10000000)
	return isnum(value) && value == round(value) && value >= minimum && value <= maximum

/proc/herald_case_exact_keys(list/data, list/keys)
	if(!islist(data) || length(data) != length(keys))
		return FALSE
	for(var/key in data)
		if(!(key in keys))
			return FALSE
	return TRUE

/proc/herald_case_staff(actor, list/roles, sanction = FALSE)
	if(!herald_case_id(actor, "snowflake") || !islist(roles) || length(roles) > 64)
		return FALSE
	for(var/role in roles)
		if(!herald_case_id(role, "snowflake"))
			return FALSE
	// The transport operator is a configured owner proxy. A non-owner actual
	// actor must carry a role explicitly allowed by the corresponding config.
	if(actor in splittext(CONFIG_GET(string/herald_admin_operator_ids), ","))
		return TRUE
	var/list/allowed = splittext(sanction ? CONFIG_GET(string/herald_sanction_role_ids) : CONFIG_GET(string/herald_case_role_ids), ",")
	for(var/role in roles)
		if(role in allowed)
			return TRUE
	return FALSE

/proc/herald_case_authority(operator, action = "reply")
	if(!(operator in splittext(CONFIG_GET(string/herald_admin_operator_ids), ",")))
		return null
	var/ck = CONFIG_GET(string/herald_admin_ckey)
	var/datum/admins/A = GLOB.admin_datums[ck] || GLOB.deadmins[ck]
	var/right = action == "ban" ? R_BAN : (action == "reply" ? R_AHELP : R_ADMIN)
	return A?.rank && (A.rank.rights & right) ? ck : null

/proc/herald_case_ticket(ticket_id, ck)
	if(!GLOB.ahelp_tickets || length(GLOB.ahelp_tickets.active_tickets) > 1000)
		return null
	for(var/datum/admin_help/T in GLOB.ahelp_tickets.active_tickets)
		if(T && !QDELETED(T) && T.id == ticket_id && T.initiator_ckey == ck && T.state == AHELP_ACTIVE)
			return T
	return null

// Receipts retain audit metadata, not an executable lease. Active leases live
// only on current tickets: restart requires a NEW explicit staff handoff.
GLOBAL_DATUM_INIT(herald_case_ledger, /datum/herald_case_ledger, new)

/datum/herald_case_ledger
	var/list/receipts = list()
	var/generation = 0
	var/recovered = FALSE
	var/recovery_failed = FALSE

/datum/herald_case_ledger/proc/persist()
	generation++
	var/path = "data/herald_case_receipts_[generation % 2].json"
	if(fexists(path))
		fdel(path)
	return text2file(json_encode(list("round" = "[GLOB.rogue_round_id]", "generation" = generation, "receipts" = receipts)), path)

/datum/herald_case_ledger/proc/valid(list/entries)
	if(!islist(entries) || length(entries) > 512)
		return FALSE
	for(var/id in entries)
		var/list/entry = entries[id]
		var/list/result = islist(entry) ? entry["result"] : null
		if(!herald_case_id(id) || !islist(entry) || !istext(entry["fingerprint"]) || !regex("^\[a-f0-9\]{64}$").Find(entry["fingerprint"]) || !islist(result) || result["request_id"] != id || result["round"] != "[GLOB.rogue_round_id]" || !istext(result["status"]) || length(json_encode(result)) > 16000)
			return FALSE
		if(!(result["action"] in list("delegate", "reclaim", "reply", "ban", "kick", "pq")) || !herald_case_id(result["case_id"]) || !herald_case_id(result["ckey"], "ckey"))
			return FALSE
	return TRUE

/datum/herald_case_ledger/proc/recover()
	if(recovered)
		return
	recovered = TRUE
	for(var/path in list("data/herald_case_receipts_0.json", "data/herald_case_receipts_1.json"))
		if(!fexists(path))
			continue
		try
			var/list/saved = json_decode(file2text(path))
			if(islist(saved) && istext(saved["round"]) && saved["round"] != "[GLOB.rogue_round_id]")
				continue
			if(!islist(saved) || saved["round"] != "[GLOB.rogue_round_id]" || !herald_case_number(saved["generation"], 1, 10000000) || !valid(saved["receipts"]))
				recovery_failed = TRUE
				continue
			if(saved["generation"] > generation)
				generation = saved["generation"]
				receipts = saved["receipts"]
		catch
			recovery_failed = TRUE
	if(recovery_failed)
		log_admin("Herald delegated cases paused: receipt checkpoint invalid. No automatic replay; credentials hidden.")

/datum/herald_case_ledger/proc/reserve(request_id, fingerprint, list/result, list/metadata)
	if(recovery_failed || length(receipts) >= 512 || receipts[request_id])
		return FALSE
	var/list/entry = list("fingerprint" = fingerprint, "result" = result)
	if(metadata)
		for(var/key in metadata)
			entry[key] = metadata[key]
	receipts[request_id] = entry
	if(!persist())
		recovery_failed = TRUE // A failed write may be partial; do not clear and retry.
		return FALSE
	return TRUE

/datum/admin_help
	var/list/herald_case_lease
	var/herald_case_epoch = 0
	var/herald_case_revoked_reason = ""

/datum/admin_help/proc/HeraldCaseRevoke(reason)
	if(!herald_case_lease)
		return
	var/list/lease = herald_case_lease
	herald_case_epoch++
	herald_case_lease = null
	herald_case_revoked_reason = copytext_char(reason, 1, 121)
	log_admin("Herald delegated ahelp #[id] case [lease["case_id"]] revoked: [herald_case_revoked_reason].")

/datum/world_topic/herald_case
	keyword = "herald_case"
	log = FALSE
	// world/Topic constructs a new handler for EVERY request.
	var/static/next_action = 0
	var/static/next_read = 0
	var/static/busy = FALSE

/datum/world_topic/herald_case/proc/envelope(request_id, list/result)
	var/payload = json_encode(result)
	return json_encode(list("data" = payload, "signature" = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "case_response|[request_id]|[payload]")))

/datum/world_topic/herald_case/proc/validate(action, list/data)
	if(!islist(data))
		return FALSE
	var/list/keys
	switch(action)
		if("delegate", "reclaim")
			keys = list("ticket_id", "version", "case_id", "actor_id", "actor_role_ids", "source_message_id", "source_channel_id")
			if(!herald_case_number(data["version"]) || !herald_case_id(data["source_message_id"], "snowflake") || !herald_case_id(data["source_channel_id"], "snowflake") || !herald_case_staff(data["actor_id"], data["actor_role_ids"]))
				return FALSE
		if("snapshot")
			keys = list("ticket_id", "case_id")
		if("reply")
			keys = list("ticket_id", "version", "case_id", "lease_token", "lease_revision", "text")
			if(!herald_case_number(data["version"]) || !herald_case_id(data["lease_token"]) || !herald_case_number(data["lease_revision"], 1) || !istext(data["text"]) || !length(trim(data["text"])) || length_char(data["text"]) > 1000 || herald_duty_word_count(data["text"]) > 30)
				return FALSE
		else
			return FALSE
	return herald_case_exact_keys(data, keys) && herald_case_number(data["ticket_id"], 1, 9999999) && herald_case_id(data["case_id"])

/datum/world_topic/herald_case/proc/guard(datum/admin_help/T, list/data, action)
	if(!T || QDELETED(T) || T.state != AHELP_ACTIVE || !(T in GLOB.ahelp_tickets?.active_tickets))
		return "ticket_changed"
	if(action == "snapshot")
		return null
	if(T.herald_revision != data["version"])
		return "ticket_changed"
	if(action in list("delegate", "reclaim"))
		if(!herald_case_staff(data["actor_id"], data["actor_role_ids"]))
			return "staff_proof_denied"
		if(T.herald_case_lease && T.herald_case_lease["case_id"] != data["case_id"])
			return "case_conflict"
		return null
	var/list/lease = T.herald_case_lease
	if(!islist(lease) || lease["round"] != "[GLOB.rogue_round_id]" || lease["case_id"] != data["case_id"] || lease["token"] != data["lease_token"] || T.herald_case_epoch != data["lease_revision"])
		return "lease_revoked"
	if(!T.HeraldDutyConnected())
		return "player_offline"
	if(world.time < T.herald_duty_next_reply)
		return "cooldown"
	return null

/datum/world_topic/herald_case/proc/execute(action, datum/admin_help/T, list/data, operator)
	switch(action)
		if("delegate")
			T.herald_case_epoch++
			T.herald_case_lease = list("round" = "[GLOB.rogue_round_id]", "case_id" = data["case_id"], "token" = md5("[rustg_unix_timestamp()]|[rand()]|[REF(T)]|[T.herald_case_epoch]|[CONFIG_GET(string/herald_readonly_key)]"),
				"actor_id" = data["actor_id"], "source_message_id" = data["source_message_id"], "source_channel_id" = data["source_channel_id"])
			T.herald_case_revoked_reason = ""
			T.HeraldRecord("Явное назначение Геральду из Discord [data["actor_id"]], case [data["case_id"]].", "system", "Геральд")
			log_admin("Herald ahelp #[T.id] delegated by actual Discord staff [data["actor_id"]] roles [jointext(data["actor_role_ids"], ",")], message [data["source_message_id"]], owner-proxy [operator].")
			return list("status" = "delegated", "lease_token" = T.herald_case_lease["token"], "lease_revision" = T.herald_case_epoch, "version" = T.herald_revision)
		if("reclaim")
			T.HeraldCaseRevoke("Discord staff [data["actor_id"]] explicitly reclaimed case")
			T.HeraldRecord("Дело возвращено человеку в Discord [data["actor_id"]].", "human", "Discord [data["actor_id"]]")
			return list("status" = "reclaimed", "lease_revision" = T.herald_case_epoch, "version" = T.herald_revision)
		if("reply")
			return list("status" = T.HeraldDutyReply(data["text"]), "lease_revision" = T.herald_case_epoch, "version" = T.herald_revision)
	return list("status" = "unsupported_action")

/datum/world_topic/herald_case/TryRun(list/input)
	if(!config || !CONFIG_GET(flag/herald_cases_enabled) || length(CONFIG_GET(string/herald_readonly_key)) < 64)
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	var/round_id = input["round"]
	var/ck = input["ckey"]
	var/payload = input["payload"]
	var/stamp = input["minute"]
	var/request_id = input["request_id"]
	var/operator = input["operator"]
	if(!herald_case_exact_keys(input, list(keyword, "round", "ckey", "payload", "minute", "request_id", "operator", "signature")) || !(action in list("delegate", "reclaim", "snapshot", "reply")) || !herald_case_id(round_id, "round") || !herald_case_id(ck, "ckey") || !herald_case_id(request_id) || !herald_case_id(operator, "snowflake") || !istext(payload) || length(payload) > 8000 || !istext(stamp) || !regex("^\[0-9\]{1,10}$").Find(stamp))
		return json_encode(list("error" = "invalid_argument"))
	if(abs(text2num(stamp) - (round(world.realtime / 600) + 15778080)) > 3)
		return json_encode(list("error" = "expired"))
	var/hash = rustg_hash_string(RUSTG_HASH_SHA256, payload)
	if(input["signature"] != herald_read_signature(CONFIG_GET(string/herald_readonly_key), "case_request|[action]|[round_id]|[ck]|[hash]|[stamp]|[request_id]|[operator]"))
		return json_encode(list("error" = "unauthorized"))
	if(!herald_case_authority(operator))
		return json_encode(list("error" = "admin_rights_denied"))
	var/list/data
	try
		data = json_decode(payload)
	catch
		return json_encode(list("error" = "invalid_argument"))
	if(!islist(data) || !validate(action, data))
		return json_encode(list("error" = "invalid_argument"))
	var/list/result = list("action" = action, "round" = round_id, "ckey" = ck, "case_id" = data["case_id"], "ticket_id" = data["ticket_id"], "request_id" = request_id, "status" = "operation_uncertain")
	if(round_id != "[GLOB.rogue_round_id]")
		result["status"] = "wrong_round"
		return envelope(request_id, result)
	var/datum/admin_help/T = herald_case_ticket(data["ticket_id"], ck)
	if(action == "snapshot")
		if(world.time < next_read)
			result["status"] = "rate_limited"
		else
			next_read = world.time + 2 SECONDS
			result["status"] = T ? "ok" : "ticket_changed"
			if(T)
				result["version"] = T.herald_revision
				result["handler"] = T.herald_handler
				result["online"] = !!T.HeraldDutyConnected()
				result["lease_active"] = !!(T.herald_case_lease && T.herald_case_lease["case_id"] == data["case_id"])
				result["reply_cooldown_seconds"] = HERALD_AHELP_REPLY_COOLDOWN_SECONDS
				result["lease_revision"] = T.herald_case_epoch
				result["revoked_reason"] = T.herald_case_revoked_reason
				result["interactions"] = T.herald_interactions.Copy()
		return envelope(request_id, result)
	GLOB.herald_case_ledger.recover()
	if(GLOB.herald_case_ledger.recovery_failed)
		result["status"] = "receipt_storage_failed"
		return envelope(request_id, result)
	var/fingerprint = rustg_hash_string(RUSTG_HASH_SHA256, "case|[action]|[round_id]|[ck]|[hash]|[operator]")
	var/list/previous = GLOB.herald_case_ledger.receipts[request_id]
	if(previous)
		if(previous["fingerprint"] != fingerprint)
			result["status"] = "request_id_conflict"
			return envelope(request_id, result)
		var/list/previous_result = previous["result"]
		var/list/cached = previous_result.Copy()
		cached["duplicate"] = TRUE
		return envelope(request_id, cached)
	var/refusal = guard(T, data, action)
	if(refusal || busy || (action != "reclaim" && world.time < next_action))
		result["status"] = refusal || "rate_limited"
		return envelope(request_id, result)
	if(!GLOB.herald_case_ledger.reserve(request_id, fingerprint, result, null))
		result["status"] = "receipt_storage_failed"
		return envelope(request_id, result)
	busy = TRUE
	next_action = world.time + 2 SECONDS
	try
		refusal = !CONFIG_GET(flag/herald_cases_enabled) ? "disabled" : (!herald_case_authority(operator) ? "admin_rights_denied" : guard(T, data, action))
		if(round_id != "[GLOB.rogue_round_id]")
			refusal = "wrong_round"
		if(refusal)
			result["status"] = refusal
		else
			var/list/outcome = execute(action, T, data, operator)
			for(var/key in outcome)
				result[key] = outcome[key]
	catch
		log_admin("Herald case [action] [request_id] uncertain; no automatic repeat.")
	busy = FALSE
	if(!GLOB.herald_case_ledger.persist())
		GLOB.herald_case_ledger.recovery_failed = TRUE
		result["warning"] = "Final receipt not saved; do not repeat uncertain operations."
	return envelope(request_id, result)

// Fixed sanctions require a separate explicit Owner/Royal Guard approval.
// Town Watch can delegate, but cannot approve sanctions. Full SDQL is unchanged.
/datum/world_topic/herald_delegated_admin
	keyword = "herald_delegated_admin"
	log = FALSE
	var/static/busy = FALSE
	var/static/next_action = 0

/datum/world_topic/herald_delegated_admin/proc/envelope(request_id, list/result)
	var/payload = json_encode(result)
	return json_encode(list("data" = payload, "signature" = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "delegated_admin_response|[request_id]|[payload]")))

/datum/world_topic/herald_delegated_admin/proc/validate(action, list/data, require_current = TRUE)
	if(!herald_case_exact_keys(data, list("case_id", "proposal_id", "approval_message_id", "approval_channel_id", "approved_by", "approved_role_ids", "approved_at", "expires_at", "operation")) || !herald_case_id(data["case_id"]) || !herald_case_id(data["proposal_id"]) || !herald_case_id(data["approval_message_id"], "snowflake") || data["approval_channel_id"] != CONFIG_GET(string/herald_sanction_approval_channel_id) || !herald_case_staff(data["approved_by"], data["approved_role_ids"], TRUE))
		return FALSE
	var/duration = herald_sdql_time_diff(herald_sdql_time_parts(data["approved_at"]), herald_sdql_time_parts(data["expires_at"]))
	if(isnull(duration) || duration <= 0 || duration > 600 || (require_current && !herald_sdql_approval_current(data["approved_at"], data["expires_at"])))
		return FALSE
	var/datum/world_topic/herald_admin/validator = new
	var/list/op = data["operation"]
	var/valid = validator.validate_payload(action, op)
	qdel(validator)
	return valid

/datum/world_topic/herald_delegated_admin/proc/guard(action, list/data, operator, round_id)
	return CONFIG_GET(flag/herald_delegated_admin_enabled) && round_id == "[GLOB.rogue_round_id]" && herald_case_authority(operator, action) && validate(action, data)

/datum/world_topic/herald_delegated_admin/proc/execute(action, ck, list/data, operator, authority)
	var/actor = "Геральд: подтверждение Discord [data["approved_by"]], сообщение [data["approval_message_id"]], case [data["case_id"]]; игровое полномочие [authority], proxy [operator]"
	// A confirmed Discord action is an audit event, not native human takeover.
	return GLOB.herald_game_operations.execute(action, ck, data["operation"], operator, authority, actor, "Discord [data["approved_by"]]", CALLBACK(src, PROC_REF(guard), action, data, operator, "[GLOB.rogue_round_id]"), "system")

/datum/world_topic/herald_delegated_admin/TryRun(list/input)
	if(!config || !CONFIG_GET(flag/herald_delegated_admin_enabled) || length(CONFIG_GET(string/herald_readonly_key)) < 64)
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	var/round_id = input["round"]
	var/ck = input["ckey"]
	var/payload = input["payload"]
	var/stamp = input["minute"]
	var/request_id = input["request_id"]
	var/operator = input["operator"]
	if(!herald_case_exact_keys(input, list(keyword, "round", "ckey", "payload", "minute", "request_id", "operator", "signature")) || !(action in list("ban", "kick", "pq")) || !herald_case_id(round_id, "round") || !herald_case_id(ck, "ckey") || !herald_case_id(request_id) || !herald_case_id(operator, "snowflake") || !istext(payload) || length(payload) > 8000 || !istext(stamp) || !regex("^\[0-9\]{1,10}$").Find(stamp))
		return json_encode(list("error" = "invalid_argument"))
	if(abs(text2num(stamp) - (round(world.realtime / 600) + 15778080)) > 3)
		return json_encode(list("error" = "expired"))
	var/hash = rustg_hash_string(RUSTG_HASH_SHA256, payload)
	if(input["signature"] != herald_read_signature(CONFIG_GET(string/herald_readonly_key), "delegated_admin_request|[action]|[round_id]|[ck]|[hash]|[stamp]|[request_id]|[operator]"))
		return json_encode(list("error" = "unauthorized"))
	var/authority = herald_case_authority(operator, action)
	if(!authority)
		return json_encode(list("error" = "admin_rights_denied"))
	var/list/data
	try
		data = json_decode(payload)
	catch
		return json_encode(list("error" = "invalid_argument"))
	if(!islist(data) || !validate(action, data, FALSE))
		return json_encode(list("error" = "invalid_approval"))
	var/list/result = list("action" = action, "round" = round_id, "ckey" = ck, "case_id" = data["case_id"], "proposal_id" = data["proposal_id"], "approved_by" = data["approved_by"], "approval_message_id" = data["approval_message_id"], "request_id" = request_id, "status" = "operation_uncertain")
	if(round_id != "[GLOB.rogue_round_id]")
		result["status"] = "wrong_round"
		return envelope(request_id, result)
	GLOB.herald_case_ledger.recover()
	if(GLOB.herald_case_ledger.recovery_failed)
		result["status"] = "receipt_storage_failed"
		return envelope(request_id, result)
	var/fingerprint = rustg_hash_string(RUSTG_HASH_SHA256, "sanction|[action]|[round_id]|[ck]|[hash]|[operator]")
	var/list/previous = GLOB.herald_case_ledger.receipts[request_id]
	if(previous)
		if(previous["fingerprint"] != fingerprint)
			result["status"] = "request_id_conflict"
			return envelope(request_id, result)
		var/list/previous_result = previous["result"]
		var/list/cached = previous_result.Copy()
		cached["duplicate"] = TRUE
		return envelope(request_id, cached)
	if(!validate(action, data))
		result["status"] = "approval_expired"
		return envelope(request_id, result)
	for(var/id in GLOB.herald_case_ledger.receipts)
		var/list/entry = GLOB.herald_case_ledger.receipts[id]
		if(entry["proposal_id"] == data["proposal_id"] || entry["approval_message_id"] == data["approval_message_id"])
			result["status"] = "approval_already_used"
			return envelope(request_id, result)
	if(busy || world.time < next_action)
		result["status"] = "rate_limited"
		return envelope(request_id, result)
	if(!GLOB.herald_case_ledger.reserve(request_id, fingerprint, result, list("proposal_id" = data["proposal_id"], "approval_message_id" = data["approval_message_id"])))
		result["status"] = "receipt_storage_failed"
		return envelope(request_id, result)
	busy = TRUE
	next_action = world.time + 2 SECONDS
	try
		if(!CONFIG_GET(flag/herald_delegated_admin_enabled) || !herald_case_authority(operator, action) || !validate(action, data) || round_id != "[GLOB.rogue_round_id]")
			result["status"] = "approval_or_authority_changed"
		else
			var/list/outcome = execute(action, ck, data, operator, authority)
			for(var/key in outcome)
				result[key] = outcome[key]
	catch
		log_admin("Herald approved sanction [request_id] uncertain; no automatic repeat.")
	busy = FALSE
	if(!GLOB.herald_case_ledger.persist())
		GLOB.herald_case_ledger.recovery_failed = TRUE
		result["warning"] = "Final receipt not saved; do not repeat uncertain operations."
	log_admin("Herald sanction [action] [ck], actual Discord approver [data["approved_by"]] roles [jointext(data["approved_role_ids"], ",")], configured game authority [authority], owner-proxy [operator], approval [data["approval_message_id"]], case [data["case_id"]], proposal [data["proposal_id"]], request [request_id], status [result["status"]].")
	return envelope(request_id, result)
