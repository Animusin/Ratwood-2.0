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
	CONFIG_SET(string/webhook_adminhelp, "")
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
