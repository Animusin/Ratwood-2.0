#define DONATION_TIER_NONE "none"
#define DONATION_TIER_CARGO "cargo"
#define DONATION_TIER_ENGINEER "engineer"
#define DONATION_TIER_SCIENTIST "scientist"
#define DONATION_TIER_HOS "hos"
#define DONATION_TIER_CAPTAIN "captain"
#define DONATION_TIER_WIZARD "wizard"
#define DONATION_TIER_CULTIST "cultist"
#define DONATION_TIER_ASSISTANT "assistant"

#define DONATIONS_TRANSACTION_TYPE_PURCHASE "donation_store_purchase"

SUBSYSTEM_DEF(donations)
	name = "Donations"
	flags = SS_NO_FIRE
	init_order = INIT_ORDER_DONATIONS

	var/const/FAILED_DONATION_DB_CONNECTION_CUTOFF = 5
	var/failed_connection_timeout = 0
	var/failed_connections = 0
	var/last_error
	var/connection

/datum/controller/subsystem/donations/Initialize()
	if(!CONFIG_GET(flag/sql_enabled))
		log_sql("Donations database is disabled because SQL is disabled.")
		return ..()

	if(!CONFIG_GET(flag/donations_enabled))
		log_sql("Donations database is disabled by configuration.")
		return ..()

	if(Connect())
		log_world("Donations database connection established.")
		update_all_clients()
	else
		log_sql("Your server failed to establish a connection with the donations database.")

	return ..()

/datum/controller/subsystem/donations/Shutdown()
	Disconnect()

/datum/controller/subsystem/donations/Recover()
	connection = SSdonations.connection

/datum/controller/subsystem/donations/proc/Connect()
	if(IsConnected())
		return TRUE

	if(!IsConfigured())
		return FALSE

	if(failed_connection_timeout <= world.time)
		failed_connections = 0

	if(failed_connections > FAILED_DONATION_DB_CONNECTION_CUTOFF)
		failed_connection_timeout = world.time + 50
		return FALSE

	var/timeout = max(CONFIG_GET(number/async_query_timeout), CONFIG_GET(number/blocking_query_timeout))
	var/thread_limit = CONFIG_GET(number/bsql_thread_limit)

	var/list/result = json_decode(rustg_sql_connect_pool(json_encode(list(
		"host" = CONFIG_GET(string/donation_address),
		"port" = CONFIG_GET(number/donation_port),
		"user" = CONFIG_GET(string/donation_login),
		"pass" = CONFIG_GET(string/donation_password),
		"db_name" = CONFIG_GET(string/donation_database),
		"read_timeout" = timeout,
		"write_timeout" = timeout,
		"max_threads" = thread_limit,
	))))

	. = (result["status"] == "ok")
	if(.)
		connection = result["handle"]
	else
		connection = null
		last_error = result["data"]
		log_sql("Donations Connect() failed | [last_error]")
		++failed_connections

/datum/controller/subsystem/donations/proc/Disconnect()
	failed_connections = 0
	if(connection)
		rustg_sql_disconnect_pool(connection)
	connection = null

/datum/controller/subsystem/donations/proc/IsConnected()
	if(!IsConfigured())
		return FALSE
	if(!connection)
		return FALSE
	return json_decode(rustg_sql_connected(connection))["status"] == "online"

/datum/controller/subsystem/donations/proc/IsConfigured()
	if(!CONFIG_GET(flag/sql_enabled))
		last_error = "SQL is disabled."
		return FALSE
	if(!CONFIG_GET(flag/donations_enabled))
		last_error = "Donations database is disabled."
		return FALSE
	if(!CONFIG_GET(string/donation_address) || !CONFIG_GET(number/donation_port) || !CONFIG_GET(string/donation_database) || !CONFIG_GET(string/donation_login) || !CONFIG_GET(string/donation_password))
		last_error = "Donations database is not configured."
		return FALSE
	return TRUE

/datum/controller/subsystem/donations/proc/IsAvailable()
	if(!IsConfigured())
		return FALSE
	return IsConnected() || Connect()

/datum/controller/subsystem/donations/proc/query(sql, list/arguments, async = TRUE, log_error = TRUE)
	if(!Connect())
		return

	var/job_result_str
	if(async)
		var/job_id = rustg_sql_query_async(connection, sql, json_encode(arguments || list()))
		UNTIL((job_result_str = rustg_sql_check_query(job_id)) != RUSTG_JOB_NO_RESULTS_YET)

		if(job_result_str == RUSTG_JOB_ERROR)
			last_error = job_result_str
			return
	else
		job_result_str = rustg_sql_query_blocking(connection, sql, json_encode(arguments || list()))

	var/list/result = json_decode(job_result_str)
	switch(result["status"])
		if("ok")
			return result
		if("err")
			last_error = result["data"]
		if("offline")
			last_error = "offline"

	if(log_error)
		log_sql("[last_error] | Donations query used: [sql]")

/datum/controller/subsystem/donations/proc/update_all_clients()
	set waitfor = FALSE
	for(var/client/player in GLOB.clients)
		update_client(player)

/datum/controller/subsystem/donations/proc/ensure_player(ckey)
	if(!ckey)
		return FALSE
	var/list/result = query("INSERT IGNORE INTO players (ckey) VALUES (:ckey)", list("ckey" = ckey))
	return !!result

/datum/controller/subsystem/donations/proc/update_client(client/player)
	if(!player?.ckey)
		return FALSE
	if(!ensure_player(player.ckey))
		return FALSE

	var/list/tier_result = query({"
		SELECT patron_types.type
		FROM players
		LEFT JOIN patron_types ON players.patron_type = patron_types.id
		WHERE players.ckey = :ckey
		LIMIT 1
	"}, list("ckey" = player.ckey))

	var/tier = DONATION_TIER_NONE
	var/list/tier_rows = tier_result?["rows"]
	if(length(tier_rows))
		var/list/tier_row = tier_rows[1]
		if(tier_row[1])
			tier = LOWER_TEXT(tier_row[1])

	var/list/opyx_result = query({"
		SELECT COALESCE(SUM(points_transactions.`change`), 0)
		FROM points_transactions
		JOIN players ON players.id = points_transactions.player
		WHERE players.ckey = :ckey
	"}, list("ckey" = player.ckey))

	var/opyxes = 0
	var/list/opyx_rows = opyx_result?["rows"]
	if(length(opyx_rows))
		var/list/opyx_row = opyx_rows[1]
		opyxes = text2num(opyx_row[1])

	player.donation_tier = tier
	player.opyxes = opyxes
	player.is_donator = (tier != DONATION_TIER_NONE) || (opyxes > 0)
	player.donation_info_loaded = TRUE
	player.patreonlevel = -1
	return TRUE

/datum/controller/subsystem/donations/proc/get_tier_for_ckey(ckey)
	if(!ckey)
		return DONATION_TIER_NONE

	var/client/player = GLOB.directory[ckey]
	if(player?.donation_info_loaded)
		return player.donation_tier || DONATION_TIER_NONE

	if(!ensure_player(ckey))
		return DONATION_TIER_NONE

	var/list/result = query({"
		SELECT patron_types.type
		FROM players
		LEFT JOIN patron_types ON players.patron_type = patron_types.id
		WHERE players.ckey = :ckey
		LIMIT 1
	"}, list("ckey" = ckey))
	var/list/rows = result?["rows"]
	if(!length(rows))
		return DONATION_TIER_NONE
	var/list/row = rows[1]
	return row[1] ? LOWER_TEXT(row[1]) : DONATION_TIER_NONE

/datum/controller/subsystem/donations/proc/get_patreon_level_for_ckey(ckey)
	return donation_tier_to_patreon_level(get_tier_for_ckey(ckey))

/datum/controller/subsystem/donations/proc/get_cached_tier_for_ckey(ckey)
	if(!ckey)
		return DONATION_TIER_NONE

	var/client/player = GLOB.directory[ckey]
	if(!player?.donation_info_loaded)
		return DONATION_TIER_NONE

	return player.donation_tier || DONATION_TIER_NONE

/datum/controller/subsystem/donations/proc/get_cached_patreon_level_for_ckey(ckey)
	return donation_tier_to_patreon_level(get_cached_tier_for_ckey(ckey))

/datum/controller/subsystem/donations/proc/get_opyxes_for_ckey(ckey)
	if(!ckey)
		return 0

	var/client/player = GLOB.directory[ckey]
	if(player?.donation_info_loaded)
		return player.opyxes

	if(!ensure_player(ckey))
		return 0

	var/list/result = query({"
		SELECT COALESCE(SUM(points_transactions.`change`), 0)
		FROM points_transactions
		JOIN players ON players.id = points_transactions.player
		WHERE players.ckey = :ckey
	"}, list("ckey" = ckey))
	var/list/rows = result?["rows"]
	if(!length(rows))
		return 0
	var/list/row = rows[1]
	return text2num(row[1])

/datum/controller/subsystem/donations/proc/is_donator_ckey(ckey)
	return !!get_patreon_level_for_ckey(ckey) || get_opyxes_for_ckey(ckey) > 0

/datum/controller/subsystem/donations/proc/create_transaction(client/player, change, type = DONATIONS_TRANSACTION_TYPE_PURCHASE, comment = "Ratwood donation transaction")
	if(!player?.ckey || !isnum(change))
		return FALSE
	if(!ensure_player(player.ckey))
		return FALSE

	var/list/result = query({"
		INSERT INTO points_transactions (player, type, datetime, `change`, comment)
		SELECT players.id, points_transactions_types.id, NOW(), :change, :comment
		FROM players
		JOIN points_transactions_types ON points_transactions_types.type = :type
		WHERE players.ckey = :ckey
			AND (
				SELECT COALESCE(SUM(existing_transactions.`change`), 0)
				FROM points_transactions AS existing_transactions
				WHERE existing_transactions.player = players.id
			) + :change >= 0
		LIMIT 1
	"}, list("ckey" = player.ckey, "type" = type, "change" = change, "comment" = comment))

	if(!result || text2num(result["affected"]) <= 0)
		update_client(player)
		return FALSE

	update_client(player)
	return text2num(result["last_insert_id"])

/datum/controller/subsystem/donations/proc/spend_opyxes(client/player, amount, comment, type = DONATIONS_TRANSACTION_TYPE_PURCHASE)
	if(!isnum(amount) || amount <= 0)
		return FALSE
	return create_transaction(player, -amount, type, comment)

/proc/donation_tier_to_patreon_level(tier)
	switch(LOWER_TEXT(tier))
		if(DONATION_TIER_CARGO)
			return 1
		if(DONATION_TIER_ENGINEER)
			return 2
		if(DONATION_TIER_SCIENTIST)
			return 3
		if(DONATION_TIER_HOS)
			return 4
		if(DONATION_TIER_CAPTAIN)
			return 5
		if(DONATION_TIER_WIZARD)
			return 6
		if(DONATION_TIER_CULTIST)
			return 7
		if(DONATION_TIER_ASSISTANT)
			return 8
	return 0

/proc/donation_tier_ooc_color(tier)
	switch(LOWER_TEXT(tier))
		if(DONATION_TIER_CARGO)
			return "#5c72bc"
		if(DONATION_TIER_ENGINEER)
			return "#009cb7"
		if(DONATION_TIER_SCIENTIST)
			return "#b54a9d"
		if(DONATION_TIER_HOS)
			return "#e51919"
		if(DONATION_TIER_CAPTAIN)
			return "#e5b232"
		if(DONATION_TIER_WIZARD)
			return "#ed0776"
		if(DONATION_TIER_CULTIST)
			return "#ea4f07"
		if(DONATION_TIER_ASSISTANT)
			return "#74767a"

/proc/donation_tier_ooc_font_size(tier)
	var/patreon_level = donation_tier_to_patreon_level(tier)
	if(!patreon_level)
		return
	return 100 + (patreon_level * 5)

/proc/donation_tier_display_name(tier)
	switch(LOWER_TEXT(tier))
		if(DONATION_TIER_CARGO)
			return "Cargo Technician"
		if(DONATION_TIER_ENGINEER)
			return "Engineer"
		if(DONATION_TIER_SCIENTIST)
			return "Scientist"
		if(DONATION_TIER_HOS)
			return "Head of Security"
		if(DONATION_TIER_CAPTAIN)
			return "Captain"
		if(DONATION_TIER_WIZARD)
			return "Wizard"
		if(DONATION_TIER_CULTIST)
			return "Cultist"
		if(DONATION_TIER_ASSISTANT)
			return "Assistant"
	return "None"

/client/proc/sync_donation_info()
	if(!SSdonations)
		return FALSE
	return SSdonations.update_client(src)

/client/proc/get_opyxes(refresh = FALSE)
	if(refresh)
		sync_donation_info()
	return opyxes

/client/proc/donation_database_available()
	return SSdonations?.IsAvailable()

/client/proc/spend_opyxes(amount, comment, type = DONATIONS_TRANSACTION_TYPE_PURCHASE)
	if(!SSdonations)
		return FALSE
	return SSdonations.spend_opyxes(src, amount, comment, type)

#undef DONATION_TIER_NONE
#undef DONATION_TIER_CARGO
#undef DONATION_TIER_ENGINEER
#undef DONATION_TIER_SCIENTIST
#undef DONATION_TIER_HOS
#undef DONATION_TIER_CAPTAIN
#undef DONATION_TIER_WIZARD
#undef DONATION_TIER_CULTIST
#undef DONATION_TIER_ASSISTANT
