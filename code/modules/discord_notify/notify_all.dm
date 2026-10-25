SUBSYSTEM_DEF(discord_notify)
	name = "Notifier"
	wait = 3000
	init_order = INIT_ORDER_DEFAULT

/datum/controller/subsystem/discord_notify/Initialize(start_timeofday)
	if(!CONFIG_GET(flag/hub))
		can_fire = FALSE
		return ..()

	var/webhook = CONFIG_GET(string/webhook_roundstart)
	if(webhook)
		var/datum/http_request/R = new()

		var/payload = list(
			"content" = "<@&1254782534626312203>\n",
			"embeds" = list(list(
				"title" = "Round [GLOB.rogue_round_id] is starting soon!! Online: [GLOB.player_list.len]",
				"description" = "",
				"color" = 16711680
			))
		)

		R.prepare(
			RUSTG_HTTP_METHOD_POST,
			webhook,
			json_encode(payload),
			list("Content-Type" = "application/json"),
			""
		)
		R.begin_async()

	can_fire = FALSE
	return ..()

// Separate channel-bound webhook. Never put the Discord bot token in game config.
/datum/config_entry/string/webhook_adminhelp
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/webhook_adminhelp/ValidateAndSet(str_val)
	if(!length(str_val))
		return ..()
	var/regex/valid = regex("^https://discord\\.com/api/webhooks/\[0-9\]+/\[A-Za-z0-9_-\]+$")
	return valid.Find(str_val) && ..()

// No client, LLM or admin action is invoked by this subsystem.
SUBSYSTEM_DEF(ahelp_relay)
	name = "Ahelp Discord Relay"
	wait = 2 SECONDS
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	flags = SS_KEEP_TIMING
	var/list/queue = list()
	var/generation = 0
	var/serial = 0
	var/datum/http_request/pending
	var/pending_started = 0
	var/slow_warned = FALSE
	var/next_attempt = 0
	var/failures = 0
	var/blocked_webhook
	var/storage_failed = FALSE
	var/checkpoint_prefix = "data/herald_ahelp_queue"
	var/relay_label = "Ahelp relay"
	var/max_batch_parts = 1
	var/pending_parts = 1

/datum/controller/subsystem/ahelp_relay/proc/get_webhook()
	return CONFIG_GET(string/webhook_adminhelp)

/datum/controller/subsystem/ahelp_relay/Initialize(start_timeofday)
	var/list/best
	for(var/path in list("[checkpoint_prefix]_0.json", "[checkpoint_prefix]_1.json"))
		if(!fexists(path))
			continue
		try
			var/list/saved = json_decode(file2text(path))
			if(islist(saved) && isnum(saved["generation"]) && isnum(saved["serial"]) && islist(saved["queue"]))
				if(!best || saved["generation"] > best["generation"])
					best = saved
		catch
			log_admin("[relay_label]: an incomplete queue checkpoint was ignored; credentials are hidden.")
	if(best)
		queue = best["queue"]
		generation = best["generation"]
		serial = best["serial"]
	return ..()

/datum/controller/subsystem/ahelp_relay/proc/persist()
	return write_checkpoint()

/datum/controller/subsystem/ahelp_relay/proc/write_checkpoint()
	// Alternate checkpoints so an interrupted write cannot destroy both copies.
	generation++
	var/path = "[checkpoint_prefix]_[generation % 2].json"
	var/list/saved = list("generation" = generation, "serial" = serial, "queue" = queue)
	if(fexists(path))
		fdel(path)
	if(!text2file(json_encode(saved), path))
		if(!storage_failed)
			log_admin("[relay_label]: queue checkpoint failed. Memory queue retained; restart recovery is not guaranteed.")
		storage_failed = TRUE
		return FALSE
	storage_failed = FALSE
	return TRUE

/proc/ahelp_relay_plaintext(value)
	var/text = "[value]"
	text = replacetext(text, regex("<br\\s*/?>", "gi"), "\n")
	// Remove hyperlinks INCLUDING href attributes/admin tokens, preserving labels.
	text = replacetext(text, regex("<\[^>\]*>", "g"), "")
	text = html_decode(text)
	// Visible mention text must never become an active Discord notification.
	return replacetext(text, "@", "@\u200b")

/proc/ahelp_relay_webhook_id(url)
	var/list/parts = splittext(url, "/")
	return length(parts) == 7 ? parts[6] : null

/datum/controller/subsystem/ahelp_relay/proc/queue_ticket_event(datum/admin_help/ticket, message)
	if(!config || !ticket || !length(CONFIG_GET(string/webhook_adminhelp)))
		return
	var/webhook = CONFIG_GET(string/webhook_adminhelp)
	if(webhook == CONFIG_GET(string/webhook_roundstart))
		log_admin("Ahelp relay refused: private tickets cannot use the roundstart webhook.")
		return
	if(length(queue) >= 10000)
		log_admin("Ahelp relay queue full: new event remains in the normal ticket log, not in the relay queue.")
		return
	serial++
	var/round_name = "[GLOB.rogue_round_id]"
	var/event_id = "[round_name]:[ticket.id]:[serial]"
	var/heading = "Round [round_name] | Ahelp #[ticket.id] | [ticket.initiator_ckey] | [time_stamp()]"
	var/body = ahelp_relay_plaintext(message)
	var/list/chunks = list()
	// Preserve full dialogue, splitting rather than silently truncating long text.
	// 800 codepoints also fit Discord's limit with supplementary Unicode/emoji.
	for(var/offset in 1 to max(1, length_char(body)) step 800)
		chunks += copytext_char(body, offset, offset + 800)
	for(var/i in 1 to length(chunks))
		queue += list(list("event_id" = event_id, "webhook_id" = ahelp_relay_webhook_id(webhook),
			"content" = "[heading]\n[chunks[i]]\nEvent [event_id] ([i]/[length(chunks)])"))
	persist()

/datum/controller/subsystem/ahelp_relay/fire(resumed)
	if(pending)
		if(!pending.is_complete())
			if(!slow_warned && world.time - pending_started > 60 SECONDS)
				log_admin("[relay_label]: HTTPS request is slow; queue retained, no concurrent resend.")
				slow_warned = TRUE
			return
		var/datum/http_response/response = pending.into_response()
		qdel(pending)
		pending = null
		if(!response.errored && response.status_code == 200)
			// wait=true returns the created message; only confirmed sends advance.
			var/confirmed = FALSE
			try
				var/list/result = json_decode(response.body)
				confirmed = islist(result) && istext(result["id"]) && length(result["id"])
			catch
				confirmed = FALSE
			if(confirmed)
				queue.Cut(1, pending_parts + 1)
				persist()
				failures = 0
				qdel(response)
				return
		failures++
		var/retry_seconds = min(300, 5 * (2 ** min(failures, 6)))
		if(response.status_code == 429)
			try
				var/list/error = json_decode(response.body)
				if(isnum(error["retry_after"]))
					retry_seconds = max(2, min(3600, error["retry_after"]))
			catch
				retry_seconds = max(2, retry_seconds)
		if(response.status_code in list(401, 403, 404))
			blocked_webhook = get_webhook()
			log_admin("[relay_label] stopped: Discord refused the webhook (HTTP [response.status_code]). Queue retained; update configuration to resume.")
		else if(failures == 1 || failures % 10 == 0)
			log_admin("[relay_label] delivery uncertain/failed (HTTP [response.status_code]); queue retained. Retrying can duplicate queued entries.")
		next_attempt = world.time + retry_seconds SECONDS
		qdel(response)
		return
	if(!config || !length(queue) || world.time < next_attempt)
		return
	var/webhook = get_webhook()
	if(!length(webhook) || webhook == blocked_webhook || webhook == CONFIG_GET(string/webhook_roundstart))
		return
	var/list/event = queue[1]
	if(event["webhook_id"] != ahelp_relay_webhook_id(webhook))
		if(blocked_webhook != webhook)
			log_admin("[relay_label] stopped: queued entries belong to a different webhook. Review backlog before changing its destination.")
		blocked_webhook = webhook
		return
	var/content = prepare_batch()
	var/list/payload = list("content" = content, "allowed_mentions" = list("parse" = list()), "flags" = 4)
	pending = new /datum/http_request(RUSTG_HTTP_METHOD_POST, "[webhook]?wait=true", json_encode(payload), list("Content-Type" = "application/json"))
	pending_started = world.time
	slow_warned = FALSE
	pending.begin_async()

/datum/controller/subsystem/ahelp_relay/proc/prepare_batch()
	var/list/event = queue[1]
	var/content = event["content"]
	pending_parts = 1
	// Emote relay batches small entries; the original ahelp relay keeps one part/request.
	for(var/i in 2 to min(length(queue), max_batch_parts))
		var/list/next_event = queue[i]
		var/combined = "[content]\n[next_event["content"]]"
		// Conservative UTF-16 bound, including supplementary emoji.
		if(next_event["webhook_id"] != event["webhook_id"] || length_char(combined) * 2 > 1900)
			break
		content = combined
		pending_parts++
	return content

// Independent channel and durable queue, reusing the bounded HTTPS transport above.
/datum/config_entry/string/webhook_custom_emotes
	parent_type = /datum/config_entry/string/webhook_adminhelp

SUBSYSTEM_DEF(emote_relay)
	parent_type = /datum/controller/subsystem/ahelp_relay
	name = "Custom Emote Discord Relay"
	checkpoint_prefix = "data/herald_emote_queue"
	relay_label = "Emote relay"
	max_batch_parts = 20
	var/checkpoint_dirty = FALSE
	var/next_overflow_warning = 0

/datum/controller/subsystem/emote_relay/get_webhook()
	var/webhook = CONFIG_GET(string/webhook_custom_emotes)
	// Also enforce isolation when sending a previously queued backlog.
	if(webhook == CONFIG_GET(string/webhook_roundstart) || webhook == CONFIG_GET(string/webhook_adminhelp))
		return null
	return webhook

/datum/controller/subsystem/emote_relay/persist()
	// Speech/emotes only append in memory. At most one checkpoint write per fire.
	checkpoint_dirty = TRUE
	return TRUE

/datum/controller/subsystem/emote_relay/fire(resumed)
	if(checkpoint_dirty)
		checkpoint_dirty = !write_checkpoint()
	return ..()

/datum/controller/subsystem/emote_relay/Shutdown()
	if(checkpoint_dirty)
		write_checkpoint()
	return ..()

/mob
	var/herald_emote_until = 0
	var/herald_emote_author

// A small seam for local synthetic probes; production identity is the actual ckey.
/mob/proc/herald_relay_ckey()
	return ckey

/datum/controller/subsystem/emote_relay/proc/queue_character_event(mob/actor, message, message_type, custom_emote = FALSE)
	if(!config || !isliving(actor) || !(message_type in list(LOG_EMOTE, LOG_SAY, LOG_WHISPER)))
		return
	var/webhook = get_webhook()
	if(!length(webhook) || webhook == CONFIG_GET(string/webhook_roundstart) || webhook == CONFIG_GET(string/webhook_adminhelp))
		return
	var/author = actor.herald_relay_ckey()
	if(!length(author))
		return // NPCs without a player ckey do not open windows.
	if(custom_emote && message_type == LOG_EMOTE)
		actor.herald_emote_author = author
		actor.herald_emote_until = world.time + 3 MINUTES
	if(actor.herald_emote_author != author || world.time >= actor.herald_emote_until)
		return
	var/kind = message_type == LOG_EMOTE ? "EMOTE" : (message_type == LOG_WHISPER ? "WHISPER" : "SAY")
	var/character = copytext_char(ahelp_relay_plaintext(actor.real_name || actor.name), 1, 81)
	character = replacetext(replacetext(character, "\n", " "), ascii2text(13), " ")
	var/heading = "[time2text(world.realtime, "YYYY-MM-DD hh:mm:ss", TIMEZONE_UTC)] UTC | [author] | [character] | [kind] "
	var/body = ahelp_relay_plaintext(message)
	var/parts = max(1, CEILING(length_char(body) / 700, 1))
	if(length(queue) + parts > 2000)
		if(world.time >= next_overflow_warning)
			log_admin("Emote relay queue full: new entries remain in normal game logs; relay overflow warnings limited to once per minute.")
			next_overflow_warning = world.time + 1 MINUTES
		return
	serial++
	for(var/offset in 1 to max(1, length_char(body)) step 700)
		queue += list(list("event_id" = "[GLOB.rogue_round_id]:[serial]", "webhook_id" = ahelp_relay_webhook_id(webhook),
			"content" = "[heading][copytext_char(body, offset, offset + 700)]"))
	persist()

// Optional fixed admin capabilities. One legacy HERALD_READONLY_KEY is shared;
// writes remain disabled unless an operator allowlist and real admin are configured.
/datum/config_entry/string/herald_admin_operator_ids
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/herald_admin_operator_ids/ValidateAndSet(str_val)
	if(!length(str_val))
		return ..()
	var/list/operators = splittext(str_val, ",")
	if(length(operators) > 32)
		return FALSE
	for(var/i in 1 to length(operators))
		operators[i] = trim(operators[i])
		if(!length(operators[i]) || length(operators[i]) > 20 || operators[i] == "0" || !regex("^\[0-9\]+$").Find(operators[i]))
			return FALSE
	return ..(jointext(operators, ","))

/datum/config_entry/string/herald_admin_ckey
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/herald_admin_ckey/ValidateAndSet(str_val)
	return (!length(str_val) || (length(str_val) <= 32 && ckey(str_val) == str_val)) && ..()

/proc/herald_ahelp_body(message)
	// Literal text, never HTML, clickable admin links, embeds or executable code.
	return replacetext(html_encode(message), "\n", "<br>")

/datum/admin_help/proc/HeraldReply(operator, message, admin_ckey)
	var/client/recipient = initiator
	if(!recipient || recipient.ckey != initiator_ckey || recipient.current_ticket != src || state != AHELP_ACTIVE)
		return "player_offline_or_ticket_changed"
	var/display = "[admin_ckey] через Геральда (Discord [operator])"
	var/body = herald_ahelp_body(message)
	AddInteraction("<font color='blue'>PM from [display]: [body]</font>", "human", admin_ckey)
	heard_by_no_admins = FALSE
	to_chat(recipient, span_adminhelp("<b>Admin PM from [display]</b>: [body]<br><i>Ответить можно в текущем тикете Adminhelp.</i>"))
	SEND_SOUND(recipient, sound('sound/adminhelp.ogg'))
	window_flash(recipient, ignorepref = TRUE)
	log_admin_private("Herald Discord [operator] replied to ahelp #[id] ([initiator_ckey]): [message]")
	message_admins(span_adminnotice("Herald Discord [operator] replied to ahelp #[id] ([initiator_ckey]): [body]"))
	return "delivered"

/datum/world_topic/herald_admin
	keyword = "herald_admin"
	log = FALSE
	var/static/next_action = 0
	var/static/list/receipts = list()
	var/static/busy = FALSE
	var/static/recovered = FALSE
	var/static/generation = 0

/datum/world_topic/herald_admin/proc/recover_receipts()
	if(recovered)
		return
	recovered = TRUE
	for(var/path in list("data/herald_admin_receipts_0.json", "data/herald_admin_receipts_1.json"))
		if(!fexists(path))
			continue
		try
			var/list/saved = json_decode(file2text(path))
			if(islist(saved) && saved["round"] == "[GLOB.rogue_round_id]" && isnum(saved["generation"]) && saved["generation"] > generation && islist(saved["receipts"]) && length(saved["receipts"]) <= 512)
				generation = saved["generation"]
				receipts = saved["receipts"]
		catch
			log_admin("Herald admin: incomplete receipt checkpoint ignored; credentials hidden.")

/datum/world_topic/herald_admin/proc/persist_receipts()
	generation++
	var/path = "data/herald_admin_receipts_[generation % 2].json"
	if(fexists(path))
		fdel(path)
	return text2file(json_encode(list("round" = "[GLOB.rogue_round_id]", "generation" = generation, "receipts" = receipts)), path)

/datum/world_topic/herald_admin/proc/envelope(secret, request_id, list/data)
	var/payload = json_encode(data)
	return json_encode(list("data" = payload, "signature" = herald_read_signature(secret, "admin_response|[request_id]|[payload]")))

/datum/world_topic/herald_admin/proc/admin_identity(operator, action)
	if(!(operator in splittext(CONFIG_GET(string/herald_admin_operator_ids), ",")))
		return null
	var/admin_ckey = CONFIG_GET(string/herald_admin_ckey)
	var/datum/admins/holder = GLOB.admin_datums[admin_ckey] || GLOB.deadmins[admin_ckey]
	var/required_right = action == "reply" ? R_AHELP : (action == "ban" ? R_BAN : R_ADMIN)
	if(!holder?.rank || !(holder.rank.rights & required_right))
		return null
	return admin_ckey

/datum/world_topic/herald_admin/proc/validate_payload(action, list/data)
	if(!islist(data))
		return FALSE
	var/list/allowed
	switch(action)
		if("reply")
			allowed = list("ticket_id", "text")
			if(!isnum(data["ticket_id"]) || data["ticket_id"] != round(data["ticket_id"]) || data["ticket_id"] < 1 || data["ticket_id"] > 9999999 || !istext(data["text"]) || !length(trim(data["text"])) || length_char(data["text"]) > 1000)
				return FALSE
		if("ban", "kick", "pq")
			allowed = action == "ban" ? list("minutes", "reason") : (action == "pq" ? list("delta", "reason") : list("reason"))
			if(!istext(data["reason"]) || !length(trim(data["reason"])) || length_char(data["reason"]) > 500)
				return FALSE
			if(action == "ban" && (!isnum(data["minutes"]) || data["minutes"] != round(data["minutes"]) || data["minutes"] < 0 || data["minutes"] > 525600))
				return FALSE
			if(action == "pq" && (!isnum(data["delta"]) || !data["delta"] || abs(data["delta"]) > 100))
				return FALSE
	for(var/key in data)
		if(!(key in allowed))
			return FALSE
	return TRUE

/datum/world_topic/herald_admin/proc/execute(action, ck, list/data, operator, admin_ckey)
	if(action == "reply")
		var/datum/admin_help/ticket
		for(var/i in 1 to min(length(GLOB.ahelp_tickets.active_tickets), 1000))
			var/datum/admin_help/candidate = GLOB.ahelp_tickets.active_tickets[i]
			if(candidate.id == data["ticket_id"])
				ticket = candidate
				break
		if(!ticket || ticket.state != AHELP_ACTIVE || ticket.initiator_ckey != ck)
			return list("status" = "ticket_not_active_or_ckey_mismatch")
		return list("status" = ticket.HeraldReply(operator, data["text"], admin_ckey), "ticket_id" = ticket.id)
	return GLOB.herald_game_operations.execute(action, ck, data, operator, admin_ckey)

/datum/world_topic/herald_admin/TryRun(list/input)
	if(!config)
		return json_encode(list("error" = "disabled"))
	var/secret = CONFIG_GET(string/herald_readonly_key)
	if(length(secret) < 64 || !length(CONFIG_GET(string/herald_admin_operator_ids)) || !length(CONFIG_GET(string/herald_admin_ckey)))
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	if(!(action in list("reply", "ban", "kick", "pq")))
		return json_encode(list("error" = "unsupported_action"))
	var/list/allowed = list(keyword, "round", "ckey", "payload", "minute", "request_id", "operator", "signature")
	for(var/key in input)
		if(!(key in allowed))
			return json_encode(list("error" = "invalid_argument"))
	var/round_id = input["round"]
	var/ck = input["ckey"]
	var/payload = input["payload"]
	var/stamp = input["minute"]
	var/request_id = input["request_id"]
	var/operator = input["operator"]
	if(!istext(round_id) || !length(round_id) || length(round_id) > 100 || !regex("^\[A-Za-z0-9_.-\]+$").Find(round_id))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(ck) || !length(ck) || length(ck) > 32 || ckey(ck) != ck)
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(payload) || length(payload) > 8000)
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(stamp) || !regex("^\[0-9\]{1,10}$").Find(stamp) || !istext(request_id) || !regex("^\[a-f0-9\]{32}$").Find(request_id))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(operator) || !length(operator) || length(operator) > 20 || !regex("^\[0-9\]+$").Find(operator))
		return json_encode(list("error" = "unauthorized"))
	var/current_minute = round(world.realtime / 600) + 15778080
	if(abs(text2num(stamp) - current_minute) > 3)
		return json_encode(list("error" = "expired"))
	var/payload_hash = rustg_hash_string(RUSTG_HASH_SHA256, payload)
	var/signed = "admin_request|[action]|[round_id]|[ck]|[payload_hash]|[stamp]|[request_id]|[operator]"
	if(input["signature"] != herald_read_signature(secret, signed))
		return json_encode(list("error" = "unauthorized"))
	var/admin_ckey = admin_identity(operator, action)
	if(!admin_ckey)
		return json_encode(list("error" = "admin_rights_denied"))
	var/list/data
	try
		data = json_decode(payload)
	catch
		return json_encode(list("error" = "invalid_argument"))
	if(!validate_payload(action, data))
		return json_encode(list("error" = "invalid_argument"))
	if(round_id != "[GLOB.rogue_round_id]")
		return json_encode(list("error" = "wrong_round"))
	recover_receipts()
	var/fingerprint = "[action]|[round_id]|[ck]|[payload_hash]|[operator]"
	var/list/previous = receipts[request_id]
	if(previous)
		if(previous["fingerprint"] != fingerprint)
			return json_encode(list("error" = "request_id_conflict"))
		var/list/previous_result = previous["result"]
		var/list/result = previous_result.Copy()
		result["duplicate"] = TRUE
		return envelope(secret, request_id, result)
	if(busy || world.time < next_action || length(receipts) >= 512)
		return json_encode(list("error" = "rate_limited_or_full"))
	next_action = world.time + 2 SECONDS
	var/list/result = list("action" = action, "round" = round_id, "ckey" = ck, "request_id" = request_id, "status" = "operation_uncertain")
	// Reserve before any side effect. Never resend after a partial runtime/response loss.
	receipts[request_id] = list("fingerprint" = fingerprint, "result" = result)
	if(!persist_receipts())
		receipts -= request_id
		return json_encode(list("error" = "receipt_storage_failed"))
	busy = TRUE
	try
		var/list/outcome = execute(action, ck, data, operator, admin_ckey)
		for(var/key in outcome)
			result[key] = outcome[key]
	catch
		log_admin("Herald admin [action] [request_id] uncertain after an internal error; do not repeat automatically.")
	busy = FALSE
	if(!persist_receipts())
		result["warning"] = "Receipt update failed; the persisted reservation prevents automatic re-execution after restart."
	log_admin("Herald Discord [operator] / [admin_ckey]: [action] [ck], request [request_id], status [result["status"]].")
	return envelope(secret, request_id, result)

// Read-only actions remain unchanged; the optional admin endpoint above is opt-in.
/datum/config_entry/string/herald_readonly_key
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/herald_readonly_key/ValidateAndSet(str_val)
	return (!length(str_val) || (length(str_val) >= 64 && length(str_val) <= 128)) && ..()

/proc/herald_read_signature(secret, message)
	// Key on both sides prevents SHA length-extension; secret never crosses Topic.
	return rustg_hash_string(RUSTG_HASH_SHA256, "[secret]|[message]|[secret]")

/datum/world_topic/herald_readonly
	keyword = "herald_read"
	log = FALSE // Parent world.Topic must not log authentication or private results.
	var/static/next_request = 0
	var/static/list/nonces = list()

/datum/world_topic/herald_readonly/TryRun(list/input)
	if(!config)
		return json_encode(list("error" = "disabled"))
	var/secret = CONFIG_GET(string/herald_readonly_key)
	if(length(secret) < 64)
		return json_encode(list("error" = "disabled"))
	var/action = input[keyword]
	if(!(action in list("status", "players", "character")))
		return json_encode(list("error" = "unsupported_action"))
	var/ck = input["ckey"] || ""
	var/offset_text = input["offset"]
	var/nonce = input["nonce"]
	var/stamp = input["minute"]
	var/operator = input["operator"]
	var/signature = input["signature"]
	if(!istext(ck) || length(ck) > 32 || (length(ck) && ckey(ck) != ck))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(nonce) || length(nonce) != 32 || !regex("^\[a-f0-9\]+$").Find(nonce))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(stamp) || length(stamp) > 10 || !regex("^\[0-9\]+$").Find(stamp))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(operator) || length(operator) > 20 || !regex("^\[0-9\]+$").Find(operator))
		return json_encode(list("error" = "invalid_argument"))
	if(!istext(offset_text) || length(offset_text) > 4 || !regex("^\[0-9\]+$").Find(offset_text))
		return json_encode(list("error" = "invalid_argument"))
	var/offset = text2num(offset_text)
	if(offset < 0 || offset > 1000 || (action == "character" && !length(ck)))
		return json_encode(list("error" = "invalid_argument"))
	// Unix minutes avoid the precision loss of large Unix seconds in DM floats.
	var/current_minute = round(world.realtime / 600) + 15778080
	if(abs(text2num(stamp) - current_minute) > 3)
		return json_encode(list("error" = "expired"))
	var/signed = "request|[action]|[ck]|[offset_text]|[stamp]|[nonce]|[operator]"
	if(!istext(signature) || length(signature) != 64 || signature != herald_read_signature(secret, signed))
		return json_encode(list("error" = "unauthorized"))
	// Cheap fixed-size responses, one request/sec globally, replay protection.
	if(world.time < next_request)
		return json_encode(list("error" = "rate_limited"))
	next_request = world.time + 1 SECONDS
	for(var/old_nonce in nonces.Copy())
		if(nonces[old_nonce] < world.time)
			nonces -= old_nonce
	if(nonces[nonce] || length(nonces) >= 512)
		return json_encode(list("error" = "replayed_or_busy"))
	nonces[nonce] = world.time + 8 MINUTES
	var/list/data = list("round" = "[GLOB.rogue_round_id]", "read_only" = TRUE)
	switch(action)
		if("status")
			data["map"] = SSmapping?.current_map?.map_name
			data["players"] = length(GLOB.clients)
			data["cpu"] = world.cpu
			data["tick_lag"] = world.tick_lag
			data["round_state"] = SSticker?.current_state
		if("players")
			var/list/rows = list()
			var/end = min(length(GLOB.clients), offset + 25)
			for(var/i in (offset + 1) to end)
				var/client/C = GLOB.clients[i]
				rows += list(list("ckey" = C.ckey, "character" = copytext_char("[C.mob?.name]", 1, 101), "stat" = C.mob?.stat))
			data["players"] = rows
			data["next_offset"] = end < min(length(GLOB.clients), 1000) ? end : null
			data["total"] = length(GLOB.clients)
		if("character")
			var/list/result
			// Maximum 1000 clients; no scan of world contents, atoms or inventories.
			for(var/i in 1 to min(length(GLOB.clients), 1000))
				var/client/C = GLOB.clients[i]
				if(C.ckey != ck)
					continue
				var/mob/M = C.mob
				result = list("ckey" = C.ckey, "name" = copytext_char("[M?.name]", 1, 101), "stat" = M?.stat,
					"x" = M?.x, "y" = M?.y, "z" = M?.z)
				if(isliving(M))
					var/mob/living/L = M
					result["health"] = L.health
				break
			data["character"] = result
	log_admin("Herald read-only [action] requested by Discord operator [operator].")
	var/payload = json_encode(data)
	return json_encode(list("data" = payload, "signature" = herald_read_signature(secret, "response|[nonce]|[payload]")))
