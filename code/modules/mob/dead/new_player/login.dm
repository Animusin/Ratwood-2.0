/mob/dead/new_player
	/// Delayed login work belongs to the connection that scheduled it.
	var/after_login_timer

/mob/dead/new_player/Login()
	var/client/login_client = client
	if(!login_client)
		return FALSE
	// Returning during class selection must not carry that old body's selector into the lobby.
	SSrole_class_handler.cancel_class_handler(ckey)
	if(CONFIG_GET(flag/use_exp_tracking))
		login_client.set_exp_from_db()
		if(QDELETED(src) || !login_client || client != login_client)
			return FALSE
		login_client.set_db_player_flags()
		if(QDELETED(src) || !login_client || client != login_client)
			return FALSE
	if(!mind)
		mind = new /datum/mind(key)
		mind.active = 1
		mind.current = src

	..()
	if(QDELETED(src) || !login_client || client != login_client)
		return FALSE

	if(client)
		client.update_ooc_verb_visibility()

	sight |= SEE_TURFS

	if(after_login_timer)
		deltimer(after_login_timer)
	after_login_timer = addtimer(CALLBACK(src, PROC_REF(do_after_login), login_client), 4 SECONDS, TIMER_STOPPABLE)
	new_player_panel()

	if(client)
		client.playtitlemusic()

/mob/dead/new_player/proc/do_after_login(client/login_client)
	PRIVATE_PROC(TRUE)
	after_login_timer = null
	if(QDELETED(src) || !login_client || client != login_client || login_client.mob != src)
		return

	var/motd = global.config.motd
	if(motd)
		to_chat(src, "<div class=\"motd\">[motd]</div>", handle_whitespace=FALSE)

	if(GLOB.rogue_round_id)
		to_chat(src, span_info("ROUND ID: [GLOB.rogue_round_id]"))

	login_client.sync_donation_info()
	// The database yields; logout or body transfer cancels this connection's work.
	if(QDELETED(src) || !login_client || client != login_client || login_client.mob != src)
		return

	if(client.is_new_player())
		to_chat(src, span_userdanger("Due to an invasion of goblins trying to play ROGUETOWN, you need to register your discord account or support us on patreon to join."))
		to_chat(src, span_info("We dislike discord too, but it's necessary. To register your discord or patreon, please click the 'Register' tab in the top right of the window, and then choose one of the options."))
	else
		var/shown_patreon_level = client.patreonlevel()
		if(!shown_patreon_level)
			shown_patreon_level = "<font color='#617C46'><b>Vale Dweller</b></font>"
		switch(shown_patreon_level)
			if(1)
				shown_patreon_level = "Silver"
			if(2)
				shown_patreon_level = "Gold"
			if(3)
				shown_patreon_level = "Mythril"
			if(4)
				shown_patreon_level = "Merchant"
			if(5)
				shown_patreon_level = "Lord"
		to_chat(src, span_info("Donator Level: [shown_patreon_level]"))
	if(client.donation_info_loaded)
		to_chat(src, span_info("Opyxes: [client.opyxes]"))
		to_chat(src, span_info("Donator Tier: [donation_tier_display_name(client.donation_tier)]"))
	else if(!client.donation_database_available())
		to_chat(src, span_warning("Donation DB is not connected."))
	if(QDELETED(src) || !login_client || client != login_client || login_client.mob != src)
		return
	login_client.changelog()
	if(QDELETED(src) || !login_client || client != login_client || login_client.mob != src)
		return

	var/server_address = CONFIG_GET(string/server)
	var/primary_server = server_address ? "byond://[server_address]" : null
	var/secondary_server = server_address ? "byond://[server_address]" : null
	var/link_style = "color:#638500;text-decoration:underline;"

	if(server_address)
		if(world.port == 22096)
			to_chat(src, "<span style='color:#638500;'>Secondary Server: [secondary_server] <a href='?src=[REF(src)];join_server=secondary' style='[link_style]'><b>(JOIN)</b></a></span>")
		else if(world.port == 22099)
			to_chat(src, "<span style='color:#638500;'>Primary Server: [primary_server] <a href='?src=[REF(src)];join_server=primary' style='[link_style]'><b>(JOIN)</b></a></span>")
		else
			to_chat(src, "<span style='color:#638500;'>Primary Server: [primary_server] <a href='?src=[REF(src)];join_server=primary' style='[link_style]'><b>(JOIN)</b></a></span>")
			to_chat(src, "<span style='color:#638500;'>Secondary Server: [secondary_server] <a href='?src=[REF(src)];join_server=secondary' style='[link_style]'><b>(JOIN)</b></a></span>")

	to_chat(src, "<a href='?src=[REF(src)];open_changelog=1' style='color:#638500;text-decoration:underline;'><b>Open Changelog</b></a>")

	if(GLOB.admin_notice)
		to_chat(src, span_notice("<b>Admin Notice:</b>\n \t [GLOB.admin_notice]"))

	var/spc = CONFIG_GET(number/soft_popcap)
	if(spc && living_player_count() >= spc)
		to_chat(src, span_notice("<b>Server Notice:</b>\n \t [CONFIG_GET(string/soft_popcap_message)]"))

	if(SSticker.current_state < GAME_STATE_SETTING_UP)
		var/tl = SSticker.GetTimeLeft()
		var/postfix
		if(tl > 0)
			postfix = "in about [DisplayTimeText(tl)]"
		else
			postfix = "soon"
		to_chat(src, "The game will start [postfix].")

		SSvote.on_client_login(client)
		var/usedkey = ckey(key)
		var/list/thinz = list("takes a seat.", "settles in.", "joins the session", "joins the table.", "becomes a player.")
		SEND_TEXT(world, span_notice("[usedkey] [pick(thinz)]"))
