// Isolated local-only probe. Not included by the production DME.
var/global/datum/herald_game_probe/herald_game_probe = new

/datum/herald_game_probe
	var/list/checks = list()
	var/failures = 0

/datum/herald_game_probe/New()
	..()
	spawn(0)
		Master.sleep_offline_after_initializations = FALSE
		while(Master.iteration < 2)
			sleep(10)
		try
			run_tests()
		catch(var/exception/E)
			check("exception", FALSE, "[E.name] [E.file]:[E.line] [E.desc]")
		check("zero_runtimes", GLOB.total_runtimes == 0)
		text2file(json_encode(list("passed" = !failures, "checks" = checks, "runtimes" = GLOB.total_runtimes)), "probe-report.json")

/datum/herald_game_probe/proc/check(label, passed, detail = "")
	checks += list(list("name" = label, "passed" = !!passed, "detail" = detail))
	if(!passed)
		failures++

/datum/admin_help/herald_probe/New()
	id = 999
	initiator_ckey = "heraldtest"
	_interactions = list()

/datum/http_request/herald_probe
	var/test_status = 200
	var/test_body = "{\"id\":\"123\"}"

/datum/http_request/herald_probe/is_complete()
	return TRUE

/datum/http_request/herald_probe/into_response()
	var/datum/http_response/R = new
	R.status_code = test_status
	R.body = test_body
	return R

/mob/living/carbon/human/consistent/herald_probe
	var/test_author = "emoteauthor"

/mob/living/carbon/human/consistent/herald_probe/herald_relay_ckey()
	return test_author

/mob/living/carbon/human/consistent/herald_probe/do_subtle_emote(message)
	return // No interactive target dialog in the isolated probe.

/datum/herald_game_probe/proc/test_emote_relay()
	SSemote_relay.can_fire = FALSE // Synthetic URL must never reach Discord.
	check("emote_webhook_loaded_from_main_config", CONFIG_GET(string/webhook_custom_emotes) == "https://discord.com/api/webhooks/456/emotetesttoken")
	check("relay_queues_independent", SSemote_relay.queue != SSahelp_relay.queue && SSemote_relay.checkpoint_prefix != SSahelp_relay.checkpoint_prefix)
	var/emote_webhook = CONFIG_GET(string/webhook_custom_emotes)
	CONFIG_SET(string/webhook_adminhelp, emote_webhook)
	check("ahelp_destination_collision_disabled", !SSemote_relay.get_webhook())
	CONFIG_SET(string/webhook_adminhelp, "")
	var/mob/living/carbon/human/consistent/herald_probe/A = new(locate(1, 1, 1))
	var/mob/living/carbon/human/consistent/herald_probe/B = new(locate(1, 1, 1))
	A.real_name = "Пробный персонаж"
	B.test_author = "otherauthor"
	A.log_talk("До кастома", LOG_SAY)
	A.emote("cough", intentional = TRUE, custom_me = TRUE)
	check("speech_and_star_builtin_do_not_trigger", !length(SSemote_relay.queue) && !A.herald_emote_until)
	A.next_me_emote = 0
	A.emote("me", 1, "пишет кастом 🐟 @everyone <a href='?admin_token=HIDDEN'>текст</a>", TRUE, custom_me = TRUE)
	check("real_custom_hook_triggers_once", length(SSemote_relay.queue) == 1 && A.herald_emote_until == world.time + 3 MINUTES)
	var/list/first = SSemote_relay.queue[1]
	check("date_identity_unicode_and_scrubbing", findtext(first["content"], " UTC | emoteauthor | Пробный персонаж | EMOTE ") && findtext(first["content"], "🐟") && !findtext(first["content"], "HIDDEN") && !findtext(first["content"], "@everyone"))
	var/deadline = A.herald_emote_until
	A.log_talk("Сейлог", LOG_SAY)
	A.log_talk("Шёпот", LOG_WHISPER)
	A.next_me_emote = 0
	A.emote("cough", intentional = TRUE, custom_me = TRUE)
	check("window_forwards_speech_whisper_builtin_without_refresh", length(SSemote_relay.queue) == 4 && A.herald_emote_until == deadline)
	B.log_talk("Не этот автор", LOG_SAY)
	B.test_author = "emoteauthor"
	B.log_talk("Тот же игрок, другой персонаж", LOG_SAY)
	A.log_talk("LOOC", LOG_LOOC)
	A.log_message("Seen copy", LOG_SEEN)
	A.log_talk("Recipient copy", LOG_SAY, log_globally = FALSE)
	check("others_ooc_and_recipient_copies_excluded", length(SSemote_relay.queue) == 4)
	A.test_author = "newpossessor"
	A.log_talk("Другое управление", LOG_SAY)
	check("different_ckey_cannot_inherit_window", length(SSemote_relay.queue) == 4)
	A.test_author = "emoteauthor"
	A.herald_emote_until = world.time
	A.log_talk("На границе трёх минут", LOG_SAY)
	check("deadline_exclusive", length(SSemote_relay.queue) == 4)
	A.next_me_emote = 0
	A.emote("me", 1, "обновляет окно", TRUE, custom_me = TRUE)
	check("new_custom_refreshes_window", length(SSemote_relay.queue) == 5 && A.herald_emote_until == world.time + 3 MINUTES)
	A.next_me_emote = 0
	A.herald_emote_until = 0
	A.emote("me", 1, "автоматический", FALSE, custom_me = TRUE)
	check("rejected_automatic_custom_does_not_trigger", length(SSemote_relay.queue) == 5 && !A.herald_emote_until)
	A.next_me_emote = 0
	A.emote("subtle", 1, "тихий кастом", TRUE, custom_me = TRUE)
	check("subtle_custom_triggers", length(SSemote_relay.queue) == 6 && A.herald_emote_until == world.time + 3 MINUTES)
	A.next_me_emote = 0
	A.emote("пишет произвольный эмоут", intentional = TRUE, custom_me = TRUE)
	check("free_text_fallback_triggers", length(SSemote_relay.queue) == 7)
	var/long_message = ""
	for(var/i in 1 to 1501)
		long_message += "я"
	A.log_message(long_message, LOG_EMOTE)
	check("long_emote_split_without_truncation", length(SSemote_relay.queue) == 10)
	var/list/part1 = SSemote_relay.queue[8]
	var/list/part2 = SSemote_relay.queue[9]
	var/list/part3 = SSemote_relay.queue[10]
	check("split_sizes", length_char(part1["content"]) == length_char(part2["content"]) && length_char(part3["content"]) == length_char(part1["content"]) - 599)
	var/batch = SSemote_relay.prepare_batch()
	check("short_entries_batched_with_bounded_size", SSemote_relay.pending_parts > 1 && length_char(batch) * 2 <= 1900)
	var/sent_parts = SSemote_relay.pending_parts
	var/datum/http_request/herald_probe/mock = new
	mock.test_status = 429
	mock.test_body = "{\"retry_after\":3}"
	SSemote_relay.pending = mock
	SSemote_relay.fire()
	check("batched_rate_limit_retains_all_parts", length(SSemote_relay.queue) == 10 && SSemote_relay.next_attempt >= world.time + 3 SECONDS)
	mock = new
	SSemote_relay.pending = mock
	SSemote_relay.fire()
	check("batch_ack_removes_exact_sent_parts", length(SSemote_relay.queue) == 10 - sent_parts)
	CONFIG_SET(string/webhook_custom_emotes, "")
	SSemote_relay.fire() // Checkpoint only; synthetic HTTPS is now disabled.
	check("emote_checkpoint_separate", fexists("data/herald_emote_queue_0.json") || fexists("data/herald_emote_queue_1.json"))
	SSemote_relay.queue.Cut()
	SSemote_relay.persist()
	CONFIG_SET(string/webhook_custom_emotes, emote_webhook)
	SSemote_relay.queue.len = 2000
	A.log_talk("Сверх очереди", LOG_SAY)
	check("queue_cap_and_overflow_warning", length(SSemote_relay.queue) == 2000 && SSemote_relay.next_overflow_warning > world.time)
	SSemote_relay.queue.Cut()
	A.test_author = ""
	SSemote_relay.queue_character_event(A, "NPC custom", LOG_EMOTE, TRUE)
	check("npc_without_ckey_excluded", !length(SSemote_relay.queue))
	CONFIG_SET(string/webhook_custom_emotes, "")
	SSemote_relay.Shutdown()
	check("orderly_shutdown_flushes_queue", !SSemote_relay.storage_failed)
	qdel(A)
	qdel(B)

/datum/herald_game_probe/proc/run_tests()
	check("key_loaded_from_main_config", CONFIG_GET(string/herald_readonly_key) == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	check("webhook_loaded_from_main_config", CONFIG_GET(string/webhook_adminhelp) == "https://discord.com/api/webhooks/123/testtoken")
	SSahelp_relay.can_fire = FALSE
	var/datum/admin_help/herald_probe/ticket = new
	ticket.AddInteraction("<font color='blue'>PM from <a href='?admin_token=SECRET'>Admin</a>: Привет<br>Рыбка @everyone</font>")
	check("all_ticket_interactions_relayed", length(SSahelp_relay.queue) == 1)
	var/list/event = SSahelp_relay.queue[1]
	var/content = event["content"]
	check("unicode_preserved", findtext(content, "Привет") && findtext(content, "Рыбка"))
	check("href_secrets_removed", !findtext(content, "SECRET") && !findtext(content, "admin_token"))
	check("checkpoint_created", fexists("data/herald_ahelp_queue_0.json") || fexists("data/herald_ahelp_queue_1.json"))
	var/datum/http_request/herald_probe/mock = new
	mock.test_status = 429
	mock.test_body = "{\"retry_after\":3}"
	SSahelp_relay.pending = mock
	SSahelp_relay.fire()
	check("rate_limit_retains_queue", length(SSahelp_relay.queue) == 1 && SSahelp_relay.next_attempt >= world.time + 3 SECONDS)
	mock = new
	mock.test_status = 403
	SSahelp_relay.pending = mock
	SSahelp_relay.fire()
	check("permission_denial_stops_retries", length(SSahelp_relay.queue) == 1 && length(SSahelp_relay.blocked_webhook))
	mock = new
	SSahelp_relay.pending = mock
	SSahelp_relay.fire()
	check("confirmed_delivery_advances", !length(SSahelp_relay.queue))
	SSahelp_relay.queue += list(list("content" = "one", "webhook_id" = "123"))
	SSahelp_relay.queue += list(list("content" = "two", "webhook_id" = "123"))
	check("original_ahelp_keeps_one_part_per_request", SSahelp_relay.prepare_batch() == "one" && SSahelp_relay.pending_parts == 1)
	SSahelp_relay.queue.Cut()
	SSahelp_relay.persist()
	CONFIG_SET(string/webhook_adminhelp, "")
	test_emote_relay()
	test_admin_actions()
	var/mob/living/carbon/human/consistent/M = new(locate(1, 1, 1))
	M.name = "Herald Probe"
	GLOB.player_list |= M
	var/old_health = M.health
	var/old_stat = M.stat
	var/old_location = M.loc
	var/list/queries = list(
		"SELECT * IN global.player_list MAP name",
		"SELECT * IN global.player_list WHERE name == 'Herald Probe' MAP health",
		"SELECT * IN global.player_list WHERE name == 'Herald Probe' MAP stat",
		"SELECT * IN global.player_list WHERE name == 'Herald Probe' MAP \[x, y, z\]")
	for(var/query in queries)
		var/list/parsed = SDQL_parse(SDQL2_tokenize(query))
		check("parse_[query]", length(parsed) == 1)
		if(length(parsed) != 1)
			continue
		var/datum/SDQL2_query/Q = new(parsed[1], FALSE, FALSE)
		var/started = world.time
		Q.Run()
		check("execute_[query]", Q.finished && Q.state == SDQL2_STATE_IDLE && world.time - started < 3 SECONDS, jointext(Q.select_text, ""))
		qdel(Q)
	check("sdql_did_not_mutate_character", !QDELETED(M) && M.health == old_health && M.stat == old_stat && M.loc == old_location && M.name == "Herald Probe")
	qdel(M)

// Test-only identities and database seam; never loaded by production roguetown.dme.
/datum/admins/herald_probe/New(datum/admin_rank/R, ck)
	rank = R
	target = ck

/datum/admin_help/herald_reply_probe
	var/reply_count = 0

/datum/admin_help/herald_reply_probe/New()
	id = 997
	initiator_ckey = "heraldtarget"
	_interactions = list()

/datum/admin_help/herald_reply_probe/HeraldReply(operator, message, admin_ckey)
	reply_count++
	AddInteraction("PM from [admin_ckey] via Herald Discord [operator]: [herald_ahelp_body(message)]")
	return "delivered" // Fake recipient; real client delivery requires deployment testing.

/datum/DBQuery/herald_admin_probe/New(sql_text, list/args)
	sql = sql_text
	arguments = args
	rows = list()
	if(findtext(sql, "SELECT ckey"))
		rows = list(list("heraldtarget"))
	if(findtext(sql, "INSERT INTO") && findtext(sql, "(bantime"))
		last_insert_id = 77

/datum/DBQuery/herald_admin_probe/Execute(async = TRUE, log_error = TRUE)
	return TRUE

/datum/herald_game_operations/herald_probe
	var/list/queries = list()
	var/ban_inserts = 0

/datum/herald_game_operations/herald_probe/connect_database()
	return TRUE

/datum/herald_game_operations/herald_probe/new_query(sql, list/arguments)
	queries += list(list("sql" = sql, "arguments" = arguments))
	if(findtext(sql, "INSERT INTO") && findtext(sql, "(bantime"))
		ban_inserts++
	return new /datum/DBQuery/herald_admin_probe(sql, arguments)

/datum/herald_game_probe/proc/admin_sign(list/input)
	var/payload_hash = rustg_hash_string(RUSTG_HASH_SHA256, input["payload"])
	var/signed = "admin_request|[input["herald_admin"]]|[input["round"]]|[input["ckey"]]|[payload_hash]|[input["minute"]]|[input["request_id"]]|[input["operator"]]"
	input["signature"] = herald_read_signature(CONFIG_GET(string/herald_readonly_key), signed)
	return input

/datum/herald_game_probe/proc/admin_request(action, ck, list/data, request_id)
	return admin_sign(list("herald_admin" = action, "round" = "[GLOB.rogue_round_id]", "ckey" = ck,
		"payload" = json_encode(data), "minute" = num2text(round(world.realtime / 600) + 15778080, 10), "request_id" = request_id, "operator" = "2"))

/datum/herald_game_probe/proc/admin_result(datum/world_topic/herald_admin/api, list/input)
	var/list/envelope = json_decode(api.TryRun(input))
	if(envelope["data"])
		check("signed_admin_response", envelope["signature"] == herald_read_signature(CONFIG_GET(string/herald_readonly_key), "admin_response|[input["request_id"]]|[envelope["data"]]"))
		return json_decode(envelope["data"])
	return envelope

/datum/herald_game_probe/proc/test_admin_actions()
	// The tiny probe stays in the lobby, before normal round ID assignment.
	GLOB.rogue_round_id = "HeraldProbe1"
	check("admin_mapping_loaded_from_main_config", CONFIG_GET(string/herald_admin_operator_ids) == "2" && CONFIG_GET(string/herald_admin_ckey) == "heraldadminprobe")
	var/datum/admin_rank/R = new("Herald local probe", R_ADMIN | R_BAN | R_AHELP)
	var/datum/admins/herald_probe/holder = new(R, "heraldadminprobe")
	GLOB.admin_datums["heraldadminprobe"] = holder
	var/datum/admin_help/herald_reply_probe/ticket = new
	GLOB.ahelp_tickets.active_tickets += ticket
	var/datum/admin_help/herald_reply_probe/wire_ticket = new
	wire_ticket.id = 998
	wire_ticket.initiator_ckey = "heraldwire"
	GLOB.ahelp_tickets.active_tickets += wire_ticket
	var/datum/herald_game_operations/herald_probe/ops = new
	GLOB.herald_game_operations = ops // Every SQL query is mocked for the local wire test too.
	var/datum/world_topic/herald_admin/api = new
	var/list/reply = admin_request("reply", "heraldtarget", list("ticket_id" = 997, "text" = "Привет 🐟 <script>нет</script>\nОтвет"), "11111111111111111111111111111111")
	CONFIG_SET(string/herald_admin_operator_ids, "")
	var/list/result = admin_result(api, reply)
	check("admin_write_disabled_without_mapping", result["error"] == "disabled")
	CONFIG_SET(string/herald_admin_operator_ids, "2")
	result = admin_result(api, reply)
	check("ahelp_reply_recorded_once", result["status"] == "delivered" && ticket.reply_count == 1 && length(ticket._interactions) == 1, json_encode(result))
	if(!length(ticket._interactions))
		return
	check("reply_html_is_literal", findtext(ticket._interactions[1], "&lt;script&gt;") && !findtext(ticket._interactions[1], "<script>") && findtext(ticket._interactions[1], "Привет"))
	result = admin_result(api, reply)
	check("ahelp_retry_idempotent", result["duplicate"] && ticket.reply_count == 1)
	var/list/conflict = reply.Copy()
	conflict["payload"] = json_encode(list("ticket_id" = 997, "text" = "Другой текст"))
	result = admin_result(api, admin_sign(conflict))
	check("request_id_conflict_denied", result["error"] == "request_id_conflict")
	var/list/invalid = reply.Copy()
	invalid["signature"] = "bad"
	result = admin_result(api, invalid)
	check("admin_bad_signature_denied", result["error"] == "unauthorized")
	invalid = reply.Copy()
	invalid["operator"] = "3"
	result = admin_result(api, admin_sign(invalid))
	check("admin_operator_not_allowlisted_denied", result["error"] == "admin_rights_denied")
	invalid = reply.Copy()
	invalid["round"] = "not_this_round"
	result = admin_result(api, admin_sign(invalid))
	check("old_round_write_denied", result["error"] == "wrong_round")
	invalid = reply.Copy()
	invalid["query"] = "SELECT * FROM world"
	result = admin_result(api, invalid)
	check("extra_sql_arguments_denied", result["error"] == "invalid_argument")
	invalid = reply.Copy()
	invalid["herald_admin"] = "proccall"
	result = admin_result(api, invalid)
	check("arbitrary_admin_action_denied", result["error"] == "unsupported_action")
	var/path = "data/player_saves/h/heraldpqprobe/preferences.sav"
	text2file("probe", path)
	text2file("{\"heraldpqprobe\":40}", "data/player_saves/h/heraldpqprobe/pq_num.json")
	var/list/pq = admin_request("pq", "heraldpqprobe", list("delta" = -10, "reason" = "Проверка"), "22222222222222222222222222222222")
	api.next_action = 0
	result = admin_result(api, pq)
	check("real_pq_deduction_persisted", result["status"] == "pq_adjusted" && result["before"] == 40 && result["after"] == 30 && get_playerquality("heraldpqprobe") == 30)
	result = admin_result(api, pq)
	check("pq_retry_does_not_double_deduct", result["duplicate"] && get_playerquality("heraldpqprobe") == 30)
	api.next_action = 0
	result = admin_result(api, admin_request("pq", "heraldpqprobe", list("delta" = 5, "reason" = "Возврат"), "33333333333333333333333333333333"))
	check("real_pq_award_persisted", result["status"] == "pq_adjusted" && get_playerquality("heraldpqprobe") == 35)
	var/list/ban_request = admin_request("ban", "heraldtarget", list("minutes" = 60, "reason" = "x'); DROP TABLE ban; --"), "44444444444444444444444444444444")
	api.next_action = 0
	result = admin_result(api, ban_request)
	check("ban_uses_standard_table_with_mock_database", result["status"] == "banned" && result["ban_id"] == 77 && ops.ban_inserts == 1)
	var/list/insert = ops.queries[3]
	var/list/arguments = insert["arguments"]
	check("ban_values_parameterized_not_sql", !findtext(insert["sql"], "DROP TABLE") && findtext(arguments["reason"], "DROP TABLE") && arguments["admin_ckey"] == "heraldadminprobe" && arguments["minutes"] == 60)
	result = admin_result(api, ban_request)
	check("ban_retry_does_not_repeat_insert", result["duplicate"] && ops.ban_inserts == 1)
	GLOB.admin_datums["heraldprotected"] = holder
	api.next_action = 0
	result = admin_result(api, admin_request("kick", "heraldprotected", list("reason" = "test"), "55555555555555555555555555555555"))
	check("staff_cannot_be_kicked", result["status"] == "admin_target_protected")
	api.next_action = 0
	result = admin_result(api, admin_request("kick", "notonline", list("reason" = "test"), "66666666666666666666666666666666"))
	check("offline_kick_not_claimed_success", result["status"] == "player_not_connected")
	R.rights = R_AHELP
	result = admin_result(api, admin_sign(ban_request.Copy()))
	check("game_admin_rights_rechecked_even_for_retry", result["error"] == "admin_rights_denied")
	R.rights = R_ADMIN | R_BAN | R_AHELP
	api.receipts = list()
	api.generation = 0
	api.recovered = FALSE
	api.next_action = 0
	result = admin_result(api, pq)
	check("server_receipts_recovered_without_duplicate_pq", result["duplicate"] && get_playerquality("heraldpqprobe") == 35)
	api.next_action = 0
