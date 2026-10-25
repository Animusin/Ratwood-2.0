// Full native SDQL is deliberately dangerous. Owner confirmation is enforced
// by the signed client; this endpoint binds the exact approval/query/round.
// NOT a sandbox: a blocking/non-yielding proc can hang or crash the game.
GLOBAL_VAR(herald_sdql_proc_caller)
GLOBAL_PROTECT(herald_sdql_proc_caller)

/datum/config_entry/flag/herald_sdql_enabled

/datum/config_entry/string/herald_sdql_approval_channel_id
	config_entry_value = "1252341888023789568"

/datum/config_entry/string/herald_sdql_approval_channel_id/ValidateAndSet(str_val)
	return istext(str_val) && regex("^\[0-9\]{15,22}$").Find(str_val) && ..()

// Decimal long division avoids 32-bit float rounding of Unix seconds.
/proc/herald_sdql_time_parts(value)
	if(!istext(value) || !regex("^\[0-9\]{1,12}$").Find(value))
		return null
	var/days = 0
	var/remainder = 0
	for(var/i in 1 to length(value))
		remainder = remainder * 10 + text2num(copytext(value, i, i + 1))
		var/digit = round(remainder / 86400)
		days = days * 10 + digit
		remainder -= digit * 86400
	return list(days, remainder)

/proc/herald_sdql_time_diff(list/first, list/last)
	if(!islist(first) || !islist(last) || abs(last[1] - first[1]) > 1)
		return null
	return (last[1] - first[1]) * 86400 + last[2] - first[2]

/proc/herald_sdql_now_seconds()
	var/raw = rustg_unix_timestamp() // rust-g returns decimal fractional seconds.
	if(!istext(raw) || !regex("^\[0-9\]{1,12}(\\.\[0-9\]+)?$").Find(raw))
		return null
	var/list/parts = splittext(raw, ".")
	return parts[1]

/proc/herald_sdql_approval_current(approved_at, expires_at)
	var/list/approved = herald_sdql_time_parts(approved_at)
	var/list/expires = herald_sdql_time_parts(expires_at)
	var/list/now = herald_sdql_time_parts(herald_sdql_now_seconds())
	var/duration = herald_sdql_time_diff(approved, expires)
	var/age = herald_sdql_time_diff(approved, now)
	var/remaining = herald_sdql_time_diff(now, expires)
	return !isnull(duration) && duration > 0 && duration <= 600 && !isnull(age) && age >= 0 && age <= 600 && !isnull(remaining) && remaining > 0

/proc/herald_sdql_plaintext(value)
	var/text = ahelp_relay_plaintext(value)
	for(var/secret in list(CONFIG_GET(string/herald_readonly_key), CONFIG_GET(string/comms_key), CONFIG_GET(string/webhook_adminhelp), CONFIG_GET(string/webhook_custom_emotes), CONFIG_GET(string/webhook_roundstart)))
		if(istext(secret) && length(secret))
			text = replacetext(text, secret, "<hidden>")
	return text

/datum/world_topic/herald_sdql
	keyword = "herald_sdql"
	log = FALSE
	var/static/list/receipts = list()
	var/static/generation = 0
	var/static/recovered = FALSE
	var/static/recovery_failed = FALSE
	var/static/busy_id
	var/static/next_execute = 0
	var/static/next_status = 0
	var/static/list/nonces = list()

/datum/world_topic/herald_sdql/proc/authority(operator)
	if(!(operator in splittext(CONFIG_GET(string/herald_admin_operator_ids), ",")))
		return null
	var/ck = CONFIG_GET(string/herald_admin_ckey)
	var/datum/admins/A = GLOB.admin_datums[ck] || GLOB.deadmins[ck]
	return A?.rank && (A.rank.rights & R_DEBUG) ? ck : null

/datum/world_topic/herald_sdql/proc/persist()
	generation++
	var/path = "data/herald_sdql_receipts_[generation % 2].json"
	if(fexists(path))
		fdel(path)
	return text2file(json_encode(list("round" = "[GLOB.rogue_round_id]", "generation" = generation, "receipts" = receipts)), path)

/datum/world_topic/herald_sdql/proc/valid_receipts(list/entries)
	if(!islist(entries) || length(entries) > 128)
		return FALSE
	for(var/id in entries)
		var/list/entry = entries[id]
		if(!istext(id) || !regex("^\[a-f0-9\]{32}$").Find(id) || !islist(entry) || !istext(entry["fingerprint"]) || !regex("^\[a-f0-9\]{64}$").Find(entry["fingerprint"]) || !istext(entry["operator"]) || !regex("^\[0-9\]{1,20}$").Find(entry["operator"]))
			return FALSE
		var/list/result = entry["result"]
		if(!islist(result) || result["request_id"] != id || result["round"] != "[GLOB.rogue_round_id]" || result["action"] != "execute" || !istext(result["proposal_id"]) || !regex("^\[a-f0-9\]{32}$").Find(result["proposal_id"]) || !istext(result["query_sha256"]) || !regex("^\[a-f0-9\]{64}$").Find(result["query_sha256"]))
			return FALSE
		if(!(result["status"] in list("accepted", "running", "completed", "operation_uncertain", "refused")) || !istext(result["output"]) || length_char(result["output"]) > 12000)
			return FALSE
		if(!istext(entry["approval_message_id"]) || !regex("^\[0-9\]{15,22}$").Find(entry["approval_message_id"]) || !istext(entry["approval_channel_id"]) || !regex("^\[0-9\]{15,22}$").Find(entry["approval_channel_id"]))
			return FALSE
	return TRUE

/datum/world_topic/herald_sdql/proc/recover()
	if(recovered)
		return
	recovered = TRUE
	for(var/path in list("data/herald_sdql_receipts_0.json", "data/herald_sdql_receipts_1.json"))
		if(!fexists(path))
			continue
		try
			var/list/saved = json_decode(file2text(path))
			if(islist(saved) && istext(saved["round"]) && saved["round"] != "[GLOB.rogue_round_id]")
				continue
			if(!islist(saved) || saved["round"] != "[GLOB.rogue_round_id]" || !isnum(saved["generation"]) || saved["generation"] < 1 || saved["generation"] != round(saved["generation"]) || !valid_receipts(saved["receipts"]))
				recovery_failed = TRUE
				continue
			if(saved["generation"] > generation)
				generation = saved["generation"]
				receipts = saved["receipts"]
		catch
			recovery_failed = TRUE
	var/changed = FALSE
	for(var/id in receipts)
		var/list/entry = receipts[id]
		var/list/result = entry["result"]
		if(result["status"] in list("accepted", "running"))
			result["status"] = "operation_uncertain"
			result["output"] = "Server restarted before completion was recorded. Effects may be partial. Do not execute again."
			changed = TRUE
	if(changed && !persist())
		recovery_failed = TRUE
	if(recovery_failed)
		log_admin("Herald SDQL paused: invalid receipt checkpoint. Review required; no automatic replay.")

/datum/world_topic/herald_sdql/proc/envelope(prefix, identity, list/data)
	var/payload = json_encode(data)
	var/encoded = json_encode(list("data" = payload, "signature" = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "[prefix]|[identity]|[payload]")))
	while(length(encoded) > 48000 && length_char(data["output"]))
		data["output"] = copytext_char(data["output"], 1, max(1, round(length_char(data["output"]) / 2)))
		data["truncated"] = TRUE
		payload = json_encode(data)
		encoded = json_encode(list("data" = payload, "signature" = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "[prefix]|[identity]|[payload]")))
	return encoded

/datum/world_topic/herald_sdql/proc/reject(request_id, list/result, code)
	result["status"] = "refused"
	result["error"] = code
	return envelope("sdql_response", request_id, result)

/datum/world_topic/herald_sdql/TryRun(list/input)
	if(!config || length(CONFIG_GET(string/herald_readonly_key)) < 64)
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	if(!(action in list("execute", "status")))
		return json_encode(list("error" = "unsupported_action"))
	var/list/allowed = action == "execute" ? list(keyword, "round", "payload", "minute", "request_id", "operator", "signature") : list(keyword, "round", "minute", "request_id", "nonce", "operator", "signature")
	for(var/key in input)
		if(!(key in allowed))
			return json_encode(list("error" = "invalid_argument"))
	var/round_id = input["round"]
	var/stamp = input["minute"]
	var/request_id = input["request_id"]
	var/operator = input["operator"]
	var/secret = CONFIG_GET(string/herald_readonly_key)
	if(!istext(round_id) || !regex("^\[A-Za-z0-9_.-\]{1,100}$").Find(round_id) || !istext(stamp) || !regex("^\[0-9\]{1,10}$").Find(stamp) || !istext(request_id) || !regex("^\[a-f0-9\]{32}$").Find(request_id) || !istext(operator) || !regex("^\[0-9\]{1,20}$").Find(operator))
		return json_encode(list("error" = "invalid_argument"))
	var/current_minute = round(world.realtime / 600) + 15778080
	if(abs(text2num(stamp) - current_minute) > 3)
		return json_encode(list("error" = "expired"))
	if(action == "status")
		var/nonce = input["nonce"]
		if(!istext(nonce) || !regex("^\[a-f0-9\]{32}$").Find(nonce))
			return json_encode(list("error" = "invalid_argument"))
		if(input["signature"] != herald_read_signature(secret, "sdql_status|[round_id]|[request_id]|[stamp]|[nonce]|[operator]"))
			return json_encode(list("error" = "unauthorized"))
		if(!authority(operator))
			return json_encode(list("error" = "admin_rights_denied"))
		if(round_id != "[GLOB.rogue_round_id]")
			return json_encode(list("error" = "wrong_round"))
		if(world.time < next_status)
			return json_encode(list("error" = "rate_limited"))
		next_status = world.time + 2 SECONDS
		for(var/old_nonce in nonces.Copy())
			if(nonces[old_nonce] < world.time)
				nonces -= old_nonce
		if(nonces[nonce] || length(nonces) >= 128)
			return json_encode(list("error" = "replayed_or_busy"))
		nonces[nonce] = world.time + 4 MINUTES
		recover()
		var/list/entry = receipts[request_id]
		var/list/result = list("action" = "execute", "round" = round_id, "request_id" = request_id, "query_sha256" = "", "proposal_id" = "", "status" = "refused", "error" = "not_found", "output" = "", "truncated" = FALSE)
		if(entry && entry["operator"] == operator)
			result = entry["result"]
		return envelope("sdql_status_response", nonce, result.Copy())
	var/payload = input["payload"]
	if(!istext(payload) || length(payload) > 20000)
		return json_encode(list("error" = "invalid_argument"))
	var/payload_hash = rustg_hash_string(RUSTG_HASH_SHA256, payload)
	if(input["signature"] != herald_read_signature(secret, "sdql_request|[round_id]|[payload_hash]|[stamp]|[request_id]|[operator]"))
		return json_encode(list("error" = "unauthorized"))
	var/list/data
	try
		data = json_decode(payload)
	catch
		return json_encode(list("error" = "invalid_argument"))
	if(!islist(data) || length(data) != 7)
		return json_encode(list("error" = "invalid_argument"))
	for(var/key in data)
		if(!(key in list("query", "query_sha256", "proposal_id", "approval_message_id", "approval_channel_id", "approved_at", "expires_at")))
			return json_encode(list("error" = "invalid_argument"))
	var/query_text = data["query"]
	if(!istext(query_text) || !length(trim(query_text)) || length(query_text) > 8000 || !istext(data["query_sha256"]) || data["query_sha256"] != rustg_hash_string(RUSTG_HASH_SHA256, query_text) || !istext(data["proposal_id"]) || !regex("^\[a-f0-9\]{32}$").Find(data["proposal_id"]))
		return json_encode(list("error" = "invalid_argument"))
	var/list/result = list("action" = "execute", "round" = round_id, "request_id" = request_id, "query_sha256" = data["query_sha256"], "proposal_id" = data["proposal_id"], "status" = "accepted", "output" = "", "truncated" = FALSE)
	if(!CONFIG_GET(flag/herald_sdql_enabled))
		return reject(request_id, result, "disabled")
	if(!authority(operator))
		return reject(request_id, result, "admin_rights_denied")
	if(round_id != "[GLOB.rogue_round_id]")
		return reject(request_id, result, "wrong_round")
	if(!istext(data["approval_message_id"]) || !regex("^\[0-9\]{15,22}$").Find(data["approval_message_id"]) || data["approval_channel_id"] != CONFIG_GET(string/herald_sdql_approval_channel_id))
		return reject(request_id, result, "approval_mismatch")
	recover()
	if(recovery_failed)
		return reject(request_id, result, "receipt_storage_failed")
	var/fingerprint = rustg_hash_string(RUSTG_HASH_SHA256, "[round_id]|[operator]|[payload_hash]")
	var/list/previous = receipts[request_id]
	if(previous)
		if(previous["fingerprint"] != fingerprint)
			return reject(request_id, result, "request_id_conflict")
		var/list/cached = previous["result"]
		var/list/copy = cached.Copy()
		copy["duplicate"] = TRUE
		return envelope("sdql_response", request_id, copy)
	if(!herald_sdql_approval_current(data["approved_at"], data["expires_at"]))
		return reject(request_id, result, "approval_expired")
	for(var/id in receipts)
		var/list/old = receipts[id]
		var/list/old_result = old["result"]
		if(old["approval_message_id"] == data["approval_message_id"] || old_result["proposal_id"] == data["proposal_id"])
			return reject(request_id, result, "approval_already_used")
	if(busy_id || GLOB.AdminProcCaller || world.time < next_execute || length(receipts) >= 128)
		return reject(request_id, result, "busy_or_limited")
	var/list/trees
	try
		trees = SDQL_parse(SDQL2_tokenize(query_text))
	catch
		return reject(request_id, result, "parse_error")
	if(!length(trees) || length(trees) > 64)
		return reject(request_id, result, "parse_error_or_batch_too_large")
	busy_id = request_id
	receipts[request_id] = list("fingerprint" = fingerprint, "operator" = operator, "approval_message_id" = data["approval_message_id"], "approval_channel_id" = data["approval_channel_id"], "approved_at" = data["approved_at"], "expires_at" = data["expires_at"], "result" = result)
	if(!persist())
		receipts -= request_id
		busy_id = null
		return reject(request_id, result, "receipt_storage_failed")
	next_execute = world.time + 30 SECONDS
	var/datum/herald_sdql_job/job = new(src, request_id, query_text, trees)
	var/list/ack = result.Copy()
	spawn(0)
		job.Run()
	return envelope("sdql_response", request_id, ack)

/datum/herald_sdql_job
	var/datum/world_topic/herald_sdql/api
	var/request_id
	var/query_text
	var/list/trees
	var/list/queries = list()
	var/active_calls = 0
	var/failed = FALSE
	var/actor
	var/output = ""
	var/truncated = FALSE

/datum/herald_sdql_job/New(datum/world_topic/herald_sdql/new_api, new_id, text, list/new_trees)
	api = new_api
	request_id = new_id
	query_text = text
	trees = new_trees
	actor = "HERALD_SDQL_[api.receipts[request_id]["operator"]]"

/datum/herald_sdql_job/proc/append_output(value)
	var/piece = herald_sdql_plaintext(value)
	var/remaining = 12000 - length_char(output)
	if(remaining <= 0)
		truncated = TRUE
		return
	if(length_char(piece) > remaining)
		truncated = TRUE
	output += copytext_char(piece, 1, remaining + 1)

/datum/herald_sdql_job/proc/end_call()
	active_calls--
	if(active_calls > 0)
		// Nested argument proccalls may have cleared the native caller at
		// count zero; restore it for the still-active outer expression.
		if(!GLOB.AdminProcCaller)
			GLOB.AdminProcCaller = actor
	else
		if(GLOB.AdminProcCaller == actor)
			GLOB.AdminProcCallCount = 0
			GLOB.AdminProcCaller = null
		if(GLOB.herald_sdql_proc_caller == actor)
			GLOB.herald_sdql_proc_caller = null

/datum/herald_sdql_job/proc/Run()
	try
		Execute()
	catch
		failed = TRUE
		var/list/entry = api.receipts[request_id]
		var/list/result = entry["result"]
		result["status"] = "operation_uncertain"
		append_output("Native job orchestration failed. Effects may be partial; do not execute again.\n")
		result["output"] = output
		result["truncated"] = truncated
	// A wrapper error is not permission to start another job while native
	// queries/proccalls that already started are still live.
	while(unfinished_queries() || active_calls)
		sleep(1)
	Finish()

/datum/herald_sdql_job/proc/unfinished_queries()
	for(var/datum/SDQL2_query/herald_remote/Q in queries)
		if(!QDELETED(Q) && Q.herald_started && !Q.herald_returned)
			return TRUE
	return FALSE

/datum/herald_sdql_job/proc/Execute()
	var/list/entry = api.receipts[request_id]
	var/list/result = entry["result"]
	if(!CONFIG_GET(flag/herald_sdql_enabled) || !api.authority(entry["operator"]) || result["round"] != "[GLOB.rogue_round_id]" || entry["approval_channel_id"] != CONFIG_GET(string/herald_sdql_approval_channel_id) || !herald_sdql_approval_current(entry["approved_at"], entry["expires_at"]))
		result["status"] = "refused"
		result["error"] = "approval_no_longer_valid"
	else
		result["status"] = "running"
		if(!api.persist())
			result["status"] = "refused"
			result["error"] = "receipt_storage_failed"
		else
			log_admin("Herald owner-confirmed SDQL [request_id], approver Discord [entry["operator"]], approval [entry["approval_message_id"]]: [herald_sdql_plaintext(query_text)]")
			message_admins("Herald: owner-confirmed SDQL [request_id] started; native R_DEBUG authority verified.")
			var/sequential = FALSE
			for(var/list/tree in trees)
				var/datum/SDQL2_query/herald_remote/Q = new(tree, FALSE, TRUE)
				Q.herald_job = src
				queries += Q
				var/list/options = tree["options"]
				if(islist(options) && options["sequential"] == "true")
					sequential = TRUE
			if(sequential)
				for(var/datum/SDQL2_query/herald_remote/Q in queries)
					Q.herald_launch_allowed = TRUE
					Q.ARun()
					while(!QDELETED(Q) && !Q.herald_returned)
						sleep(1)
					if(QDELETED(Q) || Q.state == SDQL2_STATE_ERROR || (!Q.finished && Q.query_tree[1] != "explain"))
						failed = TRUE
						break
			else
				for(var/datum/SDQL2_query/herald_remote/Q in queries)
					Q.herald_launch_allowed = TRUE
					Q.ARun()
				var/pending = TRUE
				while(pending)
					pending = FALSE
					for(var/datum/SDQL2_query/herald_remote/Q in queries)
						if(!QDELETED(Q) && !Q.herald_returned)
							pending = TRUE
					if(pending)
						sleep(1)
			while(active_calls)
				sleep(1)
			for(var/query_index in 1 to length(queries))
				var/datum/SDQL2_query/herald_remote/Q = queries[query_index]
				if(QDELETED(Q))
					failed = TRUE
					append_output("A native query was deleted before its result was captured.\n")
					continue
				var/is_explain = Q.query_tree[1] == "explain"
				if((!Q.finished && !is_explain) || Q.state == SDQL2_STATE_ERROR)
					failed = TRUE
				append_output("Query #[Q.id]: [Q.finished || is_explain ? "runner completed" : "error, halted or incomplete"].\n")
				if(is_explain)
					append_output(Q.get_query_text())
				for(var/piece in Q.select_text)
					append_output(piece)
				append_output("\n")
				if(Q.finished && !(Q.options & SDQL2_OPTION_DO_NOT_AUTOGC))
					QDEL_IN(Q, 50)
			result["status"] = failed ? "operation_uncertain" : "completed"
			result["output"] = output
			result["truncated"] = truncated

/datum/herald_sdql_job/proc/Finish()
	var/list/entry = api.receipts[request_id]
	var/list/result = entry["result"]
	if(!api.persist())
		result["warning"] = "Result checkpoint failed; an earlier reservation remains. Never execute again automatically."
	api.busy_id = null
	log_admin("Herald SDQL [request_id] status [result["status"]]. Native completion does not guarantee every requested effect or spawned proc finished.")
	query_text = null
	trees = null
	qdel(src)

/datum/SDQL2_query/herald_remote
	var/datum/herald_sdql_job/herald_job
	var/herald_started = FALSE
	var/herald_returned = FALSE
	var/herald_scheduled = FALSE
	var/herald_launch_allowed = FALSE

/datum/SDQL2_query/herald_remote/CanProcCall(procname)
	return FALSE // Wrapper internals are not a second execution gateway.

/datum/SDQL2_query/herald_remote/can_vv_get(var_name)
	if(var_name in list("vars", "herald_job", "herald_started", "herald_returned", "herald_scheduled", "herald_launch_allowed"))
		return FALSE
	return ..()

/datum/SDQL2_query/herald_remote/vv_edit_var(var_name, var_value)
	if(var_name in list("herald_job", "herald_started", "herald_returned", "herald_scheduled", "herald_launch_allowed"))
		return FALSE
	return ..()

/datum/SDQL2_query/herald_remote/admin_run(mob/user = usr)
	return FALSE // Native UI RUN cannot reuse an owner-approved remote query.

/datum/SDQL2_query/herald_remote/ARun()
	if(!herald_launch_allowed || herald_scheduled || herald_started || !herald_job || QDELETED(herald_job))
		return FALSE
	herald_launch_allowed = FALSE
	herald_scheduled = TRUE
	return ..()

/datum/SDQL2_query/herald_remote/Run()
	// This check MUST precede all flag changes: a duplicate Run while the
	// first is yielding must not report that first call as returned.
	if(herald_started || !herald_scheduled || !herald_job || QDELETED(herald_job))
		return FALSE // KEEP_ALIVE is inspectable, not an unapproved re-execution.
	herald_started = TRUE
	herald_returned = FALSE
	try
		var/value = ..()
		herald_returned = TRUE
		return value
	catch
		state = SDQL2_STATE_ERROR
		herald_returned = TRUE
		herald_job.failed = TRUE
		return FALSE

/datum/SDQL2_query/herald_remote/SDQL_function_blocking(datum/object, procname, list/arguments, source)
	if(!herald_job || QDELETED(herald_job))
		return null
	if(GLOB.AdminProcCaller && GLOB.AdminProcCaller != herald_job.actor)
		herald_job.failed = TRUE
		return null
	herald_job.active_calls++
	GLOB.AdminProcCaller = herald_job.actor
	GLOB.herald_sdql_proc_caller = herald_job.actor
	var/value
	try
		value = ..()
	catch(var/exception/E)
		herald_job.failed = TRUE
		herald_job.end_call()
		throw E
	herald_job.end_call()
	return value
