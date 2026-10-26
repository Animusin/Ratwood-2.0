// Synthetic case delegation / approved sanctions. Only included by local probe.
/datum/herald_case_ledger/herald_probe
	var/datum/admin_help/intervene_after_reservation

/datum/herald_case_ledger/herald_probe/persist()
	var/result = ..()
	if(intervene_after_reservation)
		intervene_after_reservation.HeraldRecord("Администратор снова взял дело", "human", "humanprobe")
		intervene_after_reservation = null
	return result

/datum/herald_game_operations/herald_probe/approval_revoke/new_query(sql, list/arguments)
	if(findtext(sql, "SELECT id"))
		CONFIG_SET(flag/herald_delegated_admin_enabled, FALSE)
	return ..()

/datum/world_topic/herald_delegated_admin/herald_probe
	var/test_current = TRUE

/datum/world_topic/herald_delegated_admin/herald_probe/validate(action, list/data, require_current = TRUE)
	if(require_current && !test_current)
		return FALSE
	return ..()

/datum/herald_game_probe/proc/case_request(action, list/data, request_id, endpoint = "herald_case", ck = "heraldcase")
	var/list/input = list("round" = "[GLOB.rogue_round_id]", "ckey" = ck,
		"payload" = json_encode(data), "minute" = num2text(round(world.realtime / 600) + 15778080, 10), "request_id" = request_id, "operator" = "2")
	input[endpoint] = action
	return case_sign(input, endpoint)

/datum/herald_game_probe/proc/case_sign(list/input, endpoint = "herald_case")
	var/prefix = endpoint == "herald_case" ? "case_request" : "delegated_admin_request"
	var/hash = rustg_hash_string(RUSTG_HASH_SHA256, input["payload"])
	input["signature"] = herald_read_signature(CONFIG_GET(string/herald_readonly_key), "[prefix]|[input[endpoint]]|[input["round"]]|[input["ckey"]]|[hash]|[input["minute"]]|[input["request_id"]]|[input["operator"]]")
	return input

/datum/herald_game_probe/proc/case_result(datum/world_topic/api, list/input, endpoint = "herald_case")
	var/list/response = json_decode(api.TryRun(input))
	if(!response["data"])
		return response
	var/prefix = endpoint == "herald_case" ? "case_response" : "delegated_admin_response"
	check("signed_[endpoint]_response", response["signature"] == herald_read_signature(CONFIG_GET(string/herald_readonly_key), "[prefix]|[input["request_id"]]|[response["data"]]"))
	return json_decode(response["data"])

/datum/herald_game_probe/proc/case_handoff(datum/admin_help/T, actor = "30", role = "4")
	return list("ticket_id" = T.id, "version" = T.herald_revision, "case_id" = "f1111111111111111111111111111111", "actor_id" = actor,
		"actor_role_ids" = list(role), "source_message_id" = "200000000000000111", "source_channel_id" = "1252341888023789568")

/datum/herald_game_probe/proc/sanction_data(actor = "30", role = "3", serial = 1)
	return list("case_id" = "f1111111111111111111111111111111", "proposal_id" = md5("proposal [serial]"),
		"approval_message_id" = "200000000000000[serial]", "approval_channel_id" = CONFIG_GET(string/herald_sanction_approval_channel_id),
		"approved_by" = actor, "approved_role_ids" = list(role), "approved_at" = sdql_time(), "expires_at" = sdql_time(600),
		"operation" = list("minutes" = 60, "reason" = "Изолированная проверка подтверждения"))

/datum/herald_game_probe/proc/test_cases()
	check("case_flags_and_roles_main_config", CONFIG_GET(flag/herald_cases_enabled) && CONFIG_GET(flag/herald_delegated_admin_enabled) && CONFIG_GET(string/herald_case_role_ids) == "3,4" && CONFIG_GET(string/herald_sanction_role_ids) == "3")
	check("case_owner_guard_townwatch_distinct", herald_case_staff("2", list()) && herald_case_staff("30", list("4")) && !herald_case_staff("30", list("4"), TRUE) && herald_case_staff("30", list("3"), TRUE) && !herald_case_staff("30", list("999")))
	var/datum/world_topic/herald_case/api = new
	var/datum/herald_case_ledger/herald_probe/ledger = new
	GLOB.herald_case_ledger = ledger
	var/datum/admin_help/herald_duty_probe/T = new
	T.id = 993
	T.initiator_ckey = "heraldcase"
	GLOB.ahelp_tickets.active_tickets += T
	T.HeraldRecord("Человек уже разбирал обращение", "human", "humanprobe")
	var/list/handoff = case_handoff(T)
	var/list/input = case_request("delegate", handoff, "f1111111111111111111111111111111")
	CONFIG_SET(flag/herald_cases_enabled, FALSE)
	var/list/result = case_result(api, input)
	check("case_optin_required", result["error"] == "disabled" && !T.herald_case_lease)
	CONFIG_SET(flag/herald_cases_enabled, TRUE)
	var/list/invalid = input.Copy()
	invalid["signature"] = "bad"
	result = case_result(api, invalid)
	check("case_signature_required", result["error"] == "unauthorized" && !T.herald_case_lease)
	var/list/forged = case_handoff(T, "30", "999")
	result = case_result(api, case_request("delegate", forged, "f2222222222222222222222222222222"))
	check("case_player_role_claim_not_authorized", result["error"] == "invalid_argument" && !T.herald_case_lease)
	invalid = input.Copy()
	invalid["round"] = "PreviousRound"
	case_sign(invalid)
	result = case_result(api, invalid)
	check("case_round_bound", result["status"] == "wrong_round" && !T.herald_case_lease)
	result = case_result(api, input)
	check("case_explicit_townwatch_handoff_overrides_prior_human_handler", result["status"] == "delegated" && T.herald_case_lease && length(T.herald_handler) && result["version"] == T.herald_revision)
	var/datum/world_topic/herald_case/other_api = new
	check("case_topic_instances_share_pacing_and_busy", other_api.next_action == api.next_action)
	api.busy = TRUE
	check("case_topic_instances_share_actual_busy", other_api.busy)
	api.busy = FALSE
	qdel(other_api)
	var/token = result["lease_token"]
	var/epoch = result["lease_revision"]
	result = case_result(api, input)
	check("case_duplicate_handoff_no_new_lease", result["duplicate"] && T.herald_case_epoch == epoch && T.herald_case_lease["token"] == token)
	var/list/reply = list("ticket_id" = T.id, "version" = T.herald_revision, "case_id" = handoff["case_id"], "lease_token" = token, "lease_revision" = epoch, "text" = "Я Геральд. Администратор явно передал мне это обращение.")
	api.next_action = 0
	result = case_result(api, case_request("reply", reply, "f3333333333333333333333333333333"))
	check("case_lease_replies_even_prior_human_handler", result["status"] == "delivered" && T.duty_reply_count == 1)
	T.HeraldRecord("Дополнение игрока", "player", "heraldcase")
	check("case_player_feedback_keeps_lease", T.herald_case_lease && T.herald_case_epoch == epoch)
	T.HeraldRecord("Человек вмешался", "human", "humanprobe")
	check("case_native_human_intervention_revokes", !T.herald_case_lease && T.herald_case_epoch > epoch && findtext(T.herald_case_revoked_reason, "humanprobe"))
	reply["version"] = T.herald_revision
	T.herald_duty_next_reply = 0
	api.next_action = 0
	result = case_result(api, case_request("reply", reply, "f4444444444444444444444444444444"))
	check("case_revoked_lease_cannot_reply", result["status"] == "lease_revoked" && T.duty_reply_count == 1)
	handoff = case_handoff(T)
	input = case_request("delegate", handoff, "f5555555555555555555555555555555")
	result = case_result(api, input)
	check("case_new_explicit_handoff_after_human_allowed", result["status"] == "delegated")
	token = result["lease_token"]
	epoch = T.herald_case_epoch
	reply["version"] = T.herald_revision
	reply["lease_token"] = token
	reply["lease_revision"] = epoch
	api.next_action = 0
	ledger.intervene_after_reservation = T
	result = case_result(api, case_request("reply", reply, "f6666666666666666666666666666666"))
	check("case_human_after_reservation_blocks_effect", result["status"] == "ticket_changed" && T.duty_reply_count == 1 && !T.herald_case_lease)
	handoff = case_handoff(T)
	api.next_action = 0
	input = case_request("delegate", handoff, "f7777777777777777777777777777777")
	result = case_result(api, input)
	check("case_lease_restored_only_explicitly", result["status"] == "delegated")
	result = case_result(api, case_request("reclaim", case_handoff(T), "f8888888888888888888888888888888"))
	check("case_explicit_reclaim_immediate", result["status"] == "reclaimed" && !T.herald_case_lease)
	ledger.recovered = FALSE
	ledger.recover()
	result = case_result(api, input)
	check("case_receipt_recovery_never_restores_lease", result["duplicate"] && result["status"] == "delegated" && !T.herald_case_lease)
	api.next_read = 0
	result = case_result(api, case_request("snapshot", list("ticket_id" = T.id, "case_id" = handoff["case_id"]), "f9999999999999999999999999999999"))
	check("case_snapshot_exposes_revoked_state_typed_history", result["status"] == "ok" && !result["lease_active"] && length(result["interactions"]) <= 12)
	var/datum/world_topic/herald_delegated_admin/herald_probe/sanctions = new
	var/datum/herald_game_operations/herald_probe/ops = GLOB.herald_game_operations
	var/before_inserts = ops.ban_inserts
	var/list/data = sanction_data("30", "4")
	result = case_result(sanctions, case_request("ban", data, "fa111111111111111111111111111111", "herald_delegated_admin", "heraldtarget"), "herald_delegated_admin")
	check("sanction_townwatch_cannot_approve", result["error"] == "invalid_approval" && ops.ban_inserts == before_inserts)
	data = sanction_data()
	input = case_request("ban", data, "fa222222222222222222222222222222", "herald_delegated_admin", "heraldtarget")
	CONFIG_SET(flag/herald_delegated_admin_enabled, FALSE)
	result = case_result(sanctions, input, "herald_delegated_admin")
	check("sanction_optin_required", result["error"] == "disabled" && ops.ban_inserts == before_inserts)
	CONFIG_SET(flag/herald_delegated_admin_enabled, TRUE)
	var/datum/admin_help/sanction_ticket = GLOB.ahelp_tickets.CKey2ActiveTicket("heraldtarget")
	var/list/original_sanction_lease = sanction_ticket.herald_case_lease
	sanction_ticket.herald_case_lease = list("case_id" = data["case_id"])
	result = case_result(sanctions, input, "herald_delegated_admin")
	check("sanction_royalguard_approval_executes_typed_ban", result["status"] == "banned" && result["approved_by"] == "30" && ops.ban_inserts == before_inserts + 1)
	var/datum/world_topic/herald_delegated_admin/other_sanctions = new
	check("sanction_topic_instances_share_pacing", other_sanctions.next_action == sanctions.next_action)
	sanctions.busy = TRUE
	check("sanction_topic_instances_share_actual_busy", other_sanctions.busy)
	sanctions.busy = FALSE
	qdel(other_sanctions)
	var/list/ban_query
	for(var/list/query in ops.queries)
		if(findtext(query["sql"], "(bantime"))
			ban_query = query
	var/list/arguments = ban_query["arguments"]
	check("sanction_honest_authority_actual_approver_audit", arguments["admin_ckey"] == "heraldadminprobe" && findtext(arguments["reason"], "Discord 30") && findtext(arguments["reason"], "proxy 2") && findtext(arguments["adminwho"], "30"))
	var/list/last_interaction = sanction_ticket.herald_interactions[length(sanction_ticket.herald_interactions)]
	check("sanction_discord_confirmation_keeps_lease_and_actual_actor", sanction_ticket.herald_case_lease && last_interaction["kind"] == "system" && last_interaction["actor"] == "Discord 30")
	sanction_ticket.herald_case_lease = original_sanction_lease
	result = case_result(sanctions, input, "herald_delegated_admin")
	check("sanction_receipt_exact_duplicate_no_effect", result["duplicate"] && ops.ban_inserts == before_inserts + 1)
	sanctions.test_current = FALSE
	result = case_result(sanctions, input, "herald_delegated_admin")
	check("sanction_exact_receipt_read_survives_expiry_without_new_execute", result["duplicate"] && result["status"] == "banned" && ops.ban_inserts == before_inserts + 1)
	var/list/expired = sanction_data("30", "3", 9)
	result = case_result(sanctions, case_request("ban", expired, "fa999999999999999999999999999999", "herald_delegated_admin", "heraldtarget"), "herald_delegated_admin")
	check("sanction_new_expired_approval_no_execute", result["status"] == "approval_expired" && ops.ban_inserts == before_inserts + 1)
	sanctions.test_current = TRUE
	result = case_result(sanctions, case_request("ban", data, "fa333333333333333333333333333333", "herald_delegated_admin", "heraldtarget"), "herald_delegated_admin")
	check("sanction_same_approval_new_request_denied", result["status"] == "approval_already_used" && ops.ban_inserts == before_inserts + 1)
	data = sanction_data("30", "3", 2)
	data["approval_channel_id"] = "999"
	check("sanction_wrong_private_channel_denied", !sanctions.validate("ban", data))
	data = sanction_data("30", "3", 3)
	data["expires_at"] = sdql_time(601)
	check("sanction_approval_max_ten_minutes", !sanctions.validate("ban", data))
	check("sanction_native_guard_before_effect", !sanctions.guard("ban", data, "2", "PreviousRound"))
	var/datum/herald_game_operations/herald_probe/approval_revoke/revoking_ops = new
	GLOB.herald_game_operations = revoking_ops
	sanctions.next_action = 0
	data = sanction_data("30", "3", 4)
	result = case_result(sanctions, case_request("ban", data, "fa444444444444444444444444444444", "herald_delegated_admin", "heraldtarget"), "herald_delegated_admin")
	check("sanction_switch_off_during_database_read_prevents_insert", result["status"] == "approval_or_authority_changed" && revoking_ops.ban_inserts == 0)
	GLOB.herald_game_operations = ops
	CONFIG_SET(flag/herald_delegated_admin_enabled, TRUE)
	data = sanction_data("30", "3", 11)
	var/list/uncertain_input = case_request("ban", data, "fabbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "herald_delegated_admin", "heraldtarget")
	var/hash = rustg_hash_string(RUSTG_HASH_SHA256, uncertain_input["payload"])
	var/fingerprint = rustg_hash_string(RUSTG_HASH_SHA256, "sanction|ban|[GLOB.rogue_round_id]|heraldtarget|[hash]|2")
	var/list/pending = list("action" = "ban", "round" = "[GLOB.rogue_round_id]", "ckey" = "heraldtarget", "case_id" = data["case_id"], "proposal_id" = data["proposal_id"], "approved_by" = "30", "approval_message_id" = data["approval_message_id"], "request_id" = uncertain_input["request_id"], "status" = "operation_uncertain")
	check("sanction_pending_receipt_reserved_before_effect", ledger.reserve(uncertain_input["request_id"], fingerprint, pending, list("proposal_id" = data["proposal_id"], "approval_message_id" = data["approval_message_id"])))
	ledger.recovered = FALSE
	ledger.recover()
	result = case_result(sanctions, uncertain_input, "herald_delegated_admin")
	check("sanction_recovered_pending_unknown_never_reexecutes", result["duplicate"] && result["status"] == "operation_uncertain" && ops.ban_inserts == before_inserts + 1)
	check("case_malformed_receipt_rejected", !ledger.valid(list("garbage" = list())))
	var/checkpoint = "data/herald_case_receipts_0.json"
	var/backup = file2text(checkpoint)
	fdel(checkpoint)
	text2file("not JSON", checkpoint)
	ledger.recovered = FALSE
	ledger.recover()
	check("case_corrupt_checkpoint_fails_closed", ledger.recovery_failed)
	fdel(checkpoint)
	text2file(backup, checkpoint)
	ledger.recovered = FALSE
	ledger.recovery_failed = FALSE
	ledger.recover()
	check("case_exact_checkpoint_restore_safe", !ledger.recovery_failed)
	var/old_lease = T.herald_case_lease
	T.herald_case_lease = list("case_id" = "f1111111111111111111111111111111")
	T.RemoveActive()
	check("case_native_close_revokes_lease", !T.herald_case_lease)
	T.herald_case_lease = old_lease
	GLOB.ahelp_tickets.active_tickets -= T
	qdel(T)
	var/datum/admin_help/herald_duty_probe/wire = new
	wire.id = 992
	wire.initiator_ckey = "heraldcasewire"
	wire.HeraldRecord("Есть прежний обработчик", "human", "humanprobe")
	GLOB.ahelp_tickets.active_tickets += wire
