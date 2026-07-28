#define PATREON_FILE "data/Members_7968561.csv"

// Vrell - IDK Who hardcoded the patreon lists but I'm changing that. Also, conventient defines.
// TODO - MOVE THESE TO A CONFIG FILE OR SOMETHING IDFK
#define HIGHESTPATREONLEVEL 9
GLOBAL_VAR_INIT(patreonsaylevel, 4) // Minimum patreon level that the fancy say color applies to. 

// V - Yeah not sure if there's a better way to do this but fuck it, it works.
GLOBAL_LIST_INIT(patreonlevelnames, list("Squire", "Knight", "Knight Captain", "Marshal", "Jester", "Steward", "Heir", "Consort", "Grand Baron"))
GLOBAL_LIST_INIT(patreonlevelcolors, list("#f2f2f2", "#f2f2f2", "#9e004f", "#b30000", "#ff66ff", "#009900", "#0000cc", "#cc00cc", "#ff7a05")) // TODO - REPLACE THESE COLOR CODES WITH ONES OF YOUR CHOOSING!!! I KINDA JUST PICKED SOME.

GLOBAL_LIST_INIT(patreonlevels, new/list(HIGHESTPATREONLEVEL))
GLOBAL_LIST_EMPTY(allpatreons)
GLOBAL_VAR(PatreonsLoaded)

/proc/load_patreons()
	if(GLOB.PatreonsLoaded)
		return

	for(var/i = 1, i <= HIGHESTPATREONLEVEL, ++i)
		if(GLOB.patreonlevels[i] == null)
			GLOB.patreonlevels[i] = new/list(0)

	var/csv_file = file(PATREON_FILE)
	var/list/csvlist
	if(fexists(csv_file))
		csvlist = world.file2list(csv_file)

	for(var/i = 1, i <= HIGHESTPATREONLEVEL, ++i)
		for(var/line in world.file2list("[global.config.directory]/roguetown/patreon/p[i].txt"))
			if(!line)
				continue
			if(findtextEx(line,"#",1,2))
				continue
			GLOB.patreonlevels[i] |= ckey(line)
			GLOB.allpatreons |= ckey(line)

	// V - I've got no idea what to do about these here. I don't have the original csv for these.
	// TODO - SOMEONE REFACTOR THIS ONCE YOU FIGURE OUT HOW YOU WANT TO HANDLE TRANSFERING PATREONS TO THIS DATA SET!!! ALSO MAYBE SET THIS UP TO WORK OFF THE SERVER'S DATABASE!!!!
	for(var/line in csvlist)
		if(findtext(line, "ROGUETOWN SILVER"))
			if(findtext(line, "Active patron"))
				var/index = findtext(line, ",")
				var/indexs = findtext(line, ",",index+1)
				var/player_email = copytext(line,index+1,indexs)
//				player_email = sanitize_simple(player_email,list("@"="AT","."="DOT"))
				var/find_ckey = patemail2ckey(player_email)
				if(find_ckey)
					GLOB.patreonlevels[1] |= find_ckey

	for(var/line in csvlist)
		if(findtext(line, "ROGUETOWN GOLD"))
			if(findtext(line, "Active patron"))
				var/index = findtext(line, ",")
				var/indexs = findtext(line, ",",index+1)
				var/player_email = copytext(line,index+1,indexs)
//				player_email = sanitize_simple(player_email,list("@"="AT","."="DOT"))
				var/find_ckey = patemail2ckey(player_email)
				if(find_ckey)
					GLOB.patreonlevels[2] |= find_ckey

	for(var/line in csvlist)
		if(findtext(line, "ROGUETOWN MYTHRIL"))
			if(findtext(line, "Active patron"))
				var/index = findtext(line, ",")
				var/indexs = findtext(line, ",",index+1)
				var/player_email = copytext(line,index+1,indexs)
//				player_email = sanitize_simple(player_email,list("@"="AT","."="DOT"))
				var/find_ckey = patemail2ckey(player_email)
				if(find_ckey)
					GLOB.patreonlevels[3] |= find_ckey

	for(var/line in csvlist)
		if(findtext(line, "ROGUETOWN MERCHANT"))
			if(findtext(line, "Active patron"))
				var/index = findtext(line, ",")
				var/indexs = findtext(line, ",",index+1)
				var/player_email = copytext(line,index+1,indexs)
//				player_email = sanitize_simple(player_email,list("@"="AT","."="DOT"))
				var/find_ckey = patemail2ckey(player_email)
				if(find_ckey)
					GLOB.patreonlevels[4] |= find_ckey

	for(var/line in csvlist)
		if(findtext(line, "ROGUETOWN LORD"))
			if(findtext(line, "Active patron"))
				var/index = findtext(line, ",")
				var/indexs = findtext(line, ",",index+1)
				var/player_email = copytext(line,index+1,indexs)
//				player_email = sanitize_simple(player_email,list("@"="AT","."="DOT"))
				var/find_ckey = patemail2ckey(player_email)
				if(find_ckey)
					GLOB.patreonlevels[5] |= find_ckey

	GLOB.PatreonsLoaded = TRUE

/proc/check_patreon_lvl(ckey)
	if(!ckey)
		return
	for(var/X in GLOB.temporary_donators)
		if(X == ckey)
			return GLOB.temporary_donators[X]
	var/db_donation_level = SSdonations?.get_cached_patreon_level_for_ckey(ckey)
	if(db_donation_level)
		return db_donation_level
	if(!GLOB.PatreonsLoaded)
		return get_patreon_manual(ckey)
	var/num1 = 0
	for(var/i = 1, i <= HIGHESTPATREONLEVEL, ++i)
		if(ckey in GLOB.patreonlevels[i])
			num1 = i
	return num1

/proc/get_patreon_manual(ckey)
	var/the_email
	var/json_file = file("data/patemail2ckey.json")
	if(!fexists(json_file))
		WRITE_FILE(json_file, "{}")
	var/list/json = json_decode(file2text(json_file))
	for(var/email in json)
		if(json[email] == ckey)
			the_email = email
			break

	if(!the_email)
		return 0

	var/list/csvlist
	var/csv_file = file(PATREON_FILE)
	if(fexists(csv_file))
		csvlist = world.file2list(csv_file)
	for(var/line in csvlist)
		if(findtext(line, the_email))
			if(findtext(line, "Active patron"))
				if(findtext(line, "ROGUETOWN SILVER"))
					return 1
				if(findtext(line, "ROGUETOWN GOLD"))
					return 2
				if(findtext(line, "ROGUETOWN MYTHRIL"))
					return 3
				if(findtext(line, "ROGUETOWN MERCHANT"))
					return 4
				if(findtext(line, "ROGUETOWN LORD"))
					return 5
			return 0

// TODO - If you add patreon verb perks, clean this up!!!!

GLOBAL_LIST_INIT(pleveloneverbs, world.pleveloneverbs())
GLOBAL_PROTECT(pleveloneverbs)
/world/proc/pleveloneverbs()
	return list(
	)

GLOBAL_LIST_INIT(pleveltwoverbs, world.pleveltwoverbs())
GLOBAL_PROTECT(pleveltwoverbs)
/world/proc/pleveltwoverbs()
	return list(
	)

GLOBAL_LIST_INIT(plevelthreeverbs, world.plevelthreeverbs())
GLOBAL_PROTECT(plevelthreeverbs)
/world/proc/plevelthreeverbs()
	return list(
	)

GLOBAL_LIST_INIT(plevelfourverbs, world.plevelfourverbs())
GLOBAL_PROTECT(plevelfourverbs)
/world/proc/plevelfourverbs()
	return list(
	)

GLOBAL_LIST_INIT(plevelfiveverbs, world.plevelfiveverbs())
GLOBAL_PROTECT(plevelfiveverbs)
/world/proc/plevelfiveverbs()
	return list(
	)

/client/proc/add_patreon_verbs()
	set waitfor = 0
	var/plev = check_patreon_lvl(ckey)

	if(plev > 1)
		verbs |= GLOB.pleveloneverbs
	if(plev > 2)
		verbs |= GLOB.pleveltwoverbs
	if(plev > 3)
		verbs |= GLOB.plevelthreeverbs
	if(plev > 4)
		verbs |= GLOB.plevelfourverbs
	if(plev > 5)
		verbs |= GLOB.plevelfiveverbs

GLOBAL_LIST_EMPTY(hiderole)


GLOBAL_LIST_EMPTY(anonymize)

/mob/dead/new_player/verb/anonymize()
	set category = "Options"
	set name = "Anonymize"
	if(!client)
		return
	if(get_playerquality(client.ckey) <= -5)
		client.prefs.anonymize = FALSE
		client.prefs.save_preferences()
		to_chat(src, span_warning("Your PQ is too low!"))
		return
//	if(!check_whitelist(client.ckey))
//		to_chat(src, span_warning("Whitelisted players only."))
//		return
	if(client.prefs.anonymize == TRUE)
		if(alert(src, "Disable Anonymize? (Not Recommended)", "ROGUETOWN", "YES", "NO") == "YES")
			if(GLOB.respawncounts[client.ckey])
				to_chat(src, span_warning("You have already spawned."))
				return
			client.prefs.anonymize = FALSE
			client.prefs.save_preferences()
			to_chat(src, "No longer anonymous.")
			GLOB.anonymize -= client.ckey
	else
		if(alert(src, "Enable Anonymize? This will hide your BYOND name from anyone except \
		Dungeon Masters while playing here, useful for dealing with negative OOC bias or \
		maintaining privacy from other BYOND users.", "ROGUETOWN", "YES", "NO") == "YES")
			if(GLOB.respawncounts[client.ckey])
				to_chat(src, span_warning("You have already spawned."))
				return
			client.prefs.anonymize = TRUE
			client.prefs.save_preferences()
			to_chat(src, "Anonymous... OK")
			GLOB.anonymize |= client.ckey

GLOBAL_LIST_EMPTY(temporary_donators)

/client/proc/patreonlevel()
	if(patreonlevel != -1)
		return patreonlevel
	else
		patreonlevel = check_patreon_lvl(ckey)
		return patreonlevel

#define CUSTOM_MUSIC_MINIMUM_PATREON_LEVEL 3 // Scientist

/mob/proc/can_upload_custom_music()
	return client && (client.holder || client.patreonlevel() >= CUSTOM_MUSIC_MINIMUM_PATREON_LEVEL)

#undef CUSTOM_MUSIC_MINIMUM_PATREON_LEVEL

/proc/patemail2ckey(input)
	if(!input)
		return
	var/json_file = file("data/patemail2ckey.json")
	if(!fexists(json_file))
		WRITE_FILE(json_file, "{}")
	var/list/json = json_decode(file2text(json_file))
	var/list/donatorss = json[input]
	if(isnull(donatorss))
		return
	for(var/X in donatorss)
		return X
/*
/mob/dead/new_player/proc/register_patreon()
	set name = "RegisterPatreon"
	set category = "Register"
	if(client)
		if(client.patreonlevel())
			return
	var/name = input("Enter your patreon DISPLAY NAME exactly as it appears on Patreon.","Ratwood") as text|null
	if(!name)
		return
	var/email = input("Enter your patreon EMAIL ADDRESS exactly as it appears on Patreon.","Ratwood") as text|null
	if(!email)
		return
	if(!patreon_lookup(name) || !patreon_lookup(email) || !findtext(email, "@"))
		to_chat(src, span_warning("We couldn't find that name/email combo.</span> <span class='info'>Donator status is updated weekly before every playtest. If you have waited a week, contact server staff."))
		return
//	var/saniemail = sanitize_simple(email,list("@"="AT","."="DOT"))
	var/fug = patemail2ckey(email)
	if(fug && (fug != ckey))
		to_chat(src, span_warning("That Patreon is already registered to a different player.</span> <span class='info'>Donator status is updated weekly before every playtest. If you have waited a week, contact server staff."))
		return
	add_patreon(ckey,email)
	client.patreonlevel = -1
	to_chat(src, span_boldnotice("Patreon registered."))
	var/shown_patreon_level = client.patreonlevel()
	if(!shown_patreon_level)
		shown_patreon_level = "NONE"
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
	to_chat(src, span_info("Your Donator Level: [shown_patreon_level]"))
*/
/proc/add_patreon(ckey,email)
	if(!email || !ckey)
		return
	var/csv_file = file(PATREON_FILE)
	var/list/csvlist
	if(fexists(csv_file))
		csvlist = world.file2list(csv_file)
	for(var/line in csvlist)
		if(findtext(line, email))
			if(findtext(line, "ROGUETOWN SILVER"))
				GLOB.patreonlevels[1] |= ckey
			if(findtext(line, "ROGUETOWN GOLD"))
				GLOB.patreonlevels[2] |= ckey
			if(findtext(line, "ROGUETOWN MYTHRIL"))
				GLOB.patreonlevels[3] |= ckey
			if(findtext(line, "ROGUETOWN MERCHANT"))
				GLOB.patreonlevels[4] |= ckey
			if(findtext(line, "ROGUETOWN LORD"))
				GLOB.patreonlevels[5] |= ckey
			break

	var/json_file = file("data/patemail2ckey.json")
	if(!fexists(json_file))
		WRITE_FILE(json_file, "{}")
	var/list/json = json_decode(file2text(json_file))
	json[email] = list(ckey)
	fdel(json_file)
	WRITE_FILE(json_file, json_encode(json))

/proc/patreon_lookup(name)
	if(name == "Active patron")
		return FALSE
	var/csv_file = file(PATREON_FILE)
	var/list/csvlist
	if(fexists(csv_file))
		csvlist = world.file2list(csv_file)
	for(var/line in csvlist)
		if(findtext(line, name))
			if(findtext(line, "Active patron"))
				return TRUE

#undef PATREON_FILE
