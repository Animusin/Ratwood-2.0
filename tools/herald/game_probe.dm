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
