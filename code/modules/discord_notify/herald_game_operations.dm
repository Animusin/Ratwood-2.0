// Fixed administrative operations. No caller-supplied SQL, paths, roles or procs.
GLOBAL_DATUM_INIT(herald_game_operations, /datum/herald_game_operations, new)

/datum/herald_game_operations/proc/connect_database()
	return SSdbcore.Connect()

/datum/herald_game_operations/proc/new_query(sql, list/arguments)
	return SSdbcore.NewQuery(sql, arguments)

/datum/herald_game_operations/proc/execute(action, ck, list/data, operator, admin_ckey, audit_actor, ticket_actor, datum/callback/permission_guard, ticket_kind = "human")
	var/datum/admins/holder = GLOB.admin_datums[admin_ckey] || GLOB.deadmins[admin_ckey]
	var/required_right = action == "ban" ? R_BAN : R_ADMIN
	if(!holder?.rank || !(holder.rank.rights & required_right))
		return list("status" = "admin_rights_denied")
	if(permission_guard && !permission_guard.Invoke())
		return list("status" = "approval_or_authority_changed")
	var/reason = html_encode(data["reason"])
	var/actor = audit_actor || "[admin_ckey] via Herald Discord [operator]"
	var/interaction_actor = ticket_actor || admin_ckey
	if(action in list("ban", "kick"))
		if(GLOB.admin_datums[ck] || GLOB.deadmins[ck])
			return list("status" = "admin_target_protected")
	switch(action)
		if("ban")
			return ban(ck, data["minutes"], data["reason"], actor, admin_ckey, interaction_actor, permission_guard, ticket_kind)
		if("kick")
			var/client/C = GLOB.directory[ck]
			if(!C)
				return list("status" = "player_not_connected")
			to_chat(C, span_adminhelp("[actor] отключил вас от сервера. Причина: [reason]"))
			log_admin("[actor] kicked [ck]. Reason: [reason]")
			message_admins("[actor] kicked [ck]. Reason: [reason]")
			GLOB.ahelp_tickets.CKey2ActiveTicket(ck)?.AddInteraction("[actor] kicked [ck]. Reason: [reason]", ticket_kind, interaction_actor)
			qdel(C)
			return list("status" = "kicked")
		if("pq")
			if(!fexists("data/player_saves/[copytext(ck, 1, 2)]/[ck]/preferences.sav"))
				return list("status" = "unknown_player")
			var/before = get_playerquality(ck)
			var/expected = CLAMP(before + data["delta"], -100, PQ_CAP)
			adjust_playerquality(data["delta"], ck, actor, reason)
			var/path = "data/player_saves/[copytext(ck, 1, 2)]/[ck]/pq_num.json"
			if(!fexists(path))
				return list("status" = "operation_uncertain")
			var/list/saved = json_decode(file2text(path))
			var/after = saved[ck]
			if(!isnum(after) || after != expected)
				return list("status" = "operation_uncertain")
			var/client/C = GLOB.directory[ck]
			if(C)
				to_chat(C, span_adminhelp("[actor] изменил ПК: [before] → [after]. Причина: [reason]"))
			GLOB.ahelp_tickets.CKey2ActiveTicket(ck)?.AddInteraction("[actor] adjusted PQ [before] → [after]. Reason: [reason]", ticket_kind, interaction_actor)
			return list("status" = "pq_adjusted", "before" = before, "after" = after, "applied_delta" = after - before)
	return list("status" = "unsupported_action")

/datum/herald_game_operations/proc/ban(ck, minutes, reason, actor, admin_ckey, ticket_actor, datum/callback/permission_guard, ticket_kind = "human")
	if(!connect_database())
		return list("status" = "database_unavailable")
	var/datum/DBQuery/Q = new_query("SELECT ckey FROM [format_table_name("player")] WHERE ckey = :ckey LIMIT 1", list("ckey" = ck))
	if(!Q.Execute())
		qdel(Q)
		return list("status" = "database_read_failed")
	var/known = Q.NextRow()
	qdel(Q)
	if(!known)
		return list("status" = "unknown_player")
	Q = new_query("SELECT id FROM [format_table_name("ban")] WHERE ckey = :ckey AND role = 'Server' AND unbanned_datetime IS NULL AND (expiration_time IS NULL OR expiration_time > NOW()) LIMIT 1", list("ckey" = ck))
	if(!Q.Execute())
		qdel(Q)
		return list("status" = "database_read_failed")
	if(Q.NextRow())
		var/ban_id = Q.item[1]
		qdel(Q)
		return list("status" = "already_banned", "ban_id" = ban_id)
	qdel(Q)
	// Re-check after yielding database reads. Never target/admin-ban other staff.
	var/datum/admins/holder = GLOB.admin_datums[admin_ckey] || GLOB.deadmins[admin_ckey]
	if(!holder?.rank || !(holder.rank.rights & R_BAN) || GLOB.admin_datums[ck] || GLOB.deadmins[ck])
		return list("status" = "admin_rights_denied")
	if(permission_guard && !permission_guard.Invoke())
		return list("status" = "approval_or_authority_changed")
	var/audit_reason = "[reason] ([actor])"
	Q = new_query({"
		INSERT INTO [format_table_name("ban")]
		(bantime, server_ip, server_port, round_id, role, expiration_time, applies_to_admins,
		 reason, ckey, a_ckey, a_ip, a_computerid, who, adminwho)
		VALUES (NOW(), INET_ATON(:server_ip), :port, :round_id, 'Server',
		 IF(:minutes IS NULL, NULL, NOW() + INTERVAL :minutes MINUTE), 0,
		 :reason, :ckey, :admin_ckey, 0, '', :who, :adminwho)
	"}, list("server_ip" = world.internet_address || "0", "port" = world.port,
		"round_id" = GLOB.round_id, "minutes" = minutes ? minutes : null, "reason" = audit_reason,
		"ckey" = ck, "admin_ckey" = admin_ckey, "who" = copytext_char(GLOB.clients.Join(", "), 1, 2001), "adminwho" = actor))
	if(!Q.Execute())
		qdel(Q)
		return list("status" = "operation_uncertain") // INSERT might have committed before a lost ACK.
	var/ban_id = Q.last_insert_id
	qdel(Q)
	if(!isnum(ban_id) || ban_id < 1)
		return list("status" = "operation_uncertain")
	var/duration = minutes ? "[minutes] минут" : "навсегда"
	var/body = html_encode(audit_reason)
	log_admin_private("[actor] server-banned [ck] for [duration]. Ban #[ban_id]. Reason: [body]")
	message_admins("[actor] server-banned [ck] for [duration]. Ban #[ban_id]. Reason: [body]")
	GLOB.ahelp_tickets.CKey2ActiveTicket(ck)?.AddInteraction("[actor] server-banned [ck] for [duration]. Ban #[ban_id]. Reason: [body]", ticket_kind, ticket_actor || admin_ckey)
	var/client/C = GLOB.directory[ck]
	if(C && !GLOB.admin_datums[ck] && !GLOB.deadmins[ck])
		to_chat(C, span_adminhelp("[actor] заблокировал доступ на сервер на [duration]. Причина: [body]"))
		qdel(C)
	// Standard note table too; no use of interactive usr-based create_message().
	Q = new_query({"
		INSERT INTO [format_table_name("messages")]
		(type, targetckey, adminckey, text, timestamp, server, server_ip, server_port, round_id, secret, severity)
		VALUES ('note', :ckey, :admin_ckey, :text, NOW(), :server, INET_ATON(:server_ip), :port, :round_id, 0, 'High')
	"}, list("ckey" = ck, "admin_ckey" = admin_ckey, "text" = "Server ban #[ban_id] for [duration]: [audit_reason]",
		"server" = CONFIG_GET(string/serversqlname), "server_ip" = world.internet_address || "0", "port" = world.port, "round_id" = GLOB.round_id))
	var/note_saved = Q.Execute()
	qdel(Q)
	var/list/result = list("status" = "banned", "ban_id" = ban_id, "minutes" = minutes)
	if(!note_saved)
		result["warning"] = "Ban confirmed, but the additional note was not confirmed. Do not repeat the ban."
	return result
