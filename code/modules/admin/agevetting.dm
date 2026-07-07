// This is almost entirely a copy paste of the Ratwood bunker system repurposed for adding in Age vetted people.
// Agevets matter more than simple whitelist access, so the approach is a bit different.
// We currently store age vets in an assoc list locally.
// The keys: player ckeys, values: the admin who added them.

GLOBAL_LIST_INIT(agevetted_list, load_agevets_from_file())
GLOBAL_PROTECT(agevetted_list)

/client/proc/check_agevet()
	if(LAZYACCESS(GLOB.agevetted_list, ckey))
		return TRUE
	if(check_whitelist(ckey))
		if(!LAZYACCESS(GLOB.agevetted_list, ckey))
			add_agevet(ckey, "SYSTEM", src)
		return TRUE
	if(holder)
		return TRUE
	return FALSE

/mob/proc/check_agevet()
	if(client)
		return client.check_agevet()
	if(LAZYACCESS(GLOB.agevetted_list, ckey) || copytext(key,1,2)=="@") //aghosted people stay verified
		return TRUE
	if(check_whitelist(ckey))
		if(!LAZYACCESS(GLOB.agevetted_list, ckey))
			add_agevet(ckey, "SYSTEM")
		return TRUE
	return FALSE

/client/proc/agevet_player()
	set category = "-Server-"
	set name = "BC - Add Age Vetted"

	if(!check_rights())
		return

	var/selection = input("Who would you like to verify?", "CKEY", "") as text|null
	if(selection)
		if(alert(src, "Confirm: [selection] as being ID verified?", "Age Vetting", "Yes!", "No") == "Yes!")
			add_agevet(selection, ckey, src) // keep the client ref to save us a duplicate list call

/proc/add_agevet(target_ckey, admin_ckey = "SYSTEM", clientref)
	if(!target_ckey || (target_ckey in GLOB.agevetted_list))
		return

	if(admin_ckey != "SYSTEM" && IsAdminAdvancedProcCall())
		return

	if(LAZYACCESS(GLOB.agevetted_list, target_ckey))
		to_chat(clientref, span_warning("The ckey \"[target_ckey]\" has already been ID vetted."))
		return

	target_ckey = ckey(target_ckey)
	GLOB.agevetted_list[target_ckey] = admin_ckey
	// The +10 whitelist/age-vet bonus must only ever be paid ONCE per ckey.
	// GLOB.agevetted_list is rebuilt from data/agevets.json at boot and that file
	// has been lost before; when it is, every whitelisted player re-hits this path
	// on login (via check_agevet) and gets paid again. Gate the payout behind a
	// persistent per-player marker so it survives the list being wiped.
	if(!agevet_bonus_already_paid(target_ckey))
		adjust_playerquality(10, target_ckey, admin_ckey, "Age verification bonus")
		mark_agevet_bonus_paid(target_ckey)
	message_admins("ID VETTING: Added [target_ckey] to the agevetted list[admin_ckey? " by [admin_ckey]":""]")
	log_admin("ID VETTING: Added [target_ckey] to the agevetted list[admin_ckey? " by [admin_ckey]":""]")
	save_agevets_to_file()
	log_agevet_to_csv(target_ckey, admin_ckey)

	// if they're online, notify
	var/recipient = LAZYACCESS(GLOB.directory, target_ckey)
	if(recipient)
		to_chat(recipient, span_notice("Good news! You are now ID verified."))

// Read/write the assoc list. Player ckey maps to vetting admin ckey.
/proc/load_agevets_from_file()
	var/json_file = file("data/agevets.json")
	if(fexists(json_file))
		var/list/json = json_decode(file2text(json_file))
		return json
	else
		return list()

/proc/save_agevets_to_file()
	var/json_file = file("data/agevets.json")
	var/list/file_data = list()
	file_data = GLOB.agevetted_list
	fdel(json_file)
	WRITE_FILE(json_file,json_encode(file_data))

// ERP age-gating. Stripping intimate clothing (underwear) and enabling the ERP
// panel both require age verification (whitelist). Both the wearer and whoever
// is undressing them must be vetted. On non-mature builds the restriction is
// compiled out so ordinary undressing is unaffected.
/mob/living/carbon/human/proc/erp_undress_allowed(mob/stripper)
#ifndef MATURESERVER
	return TRUE
#else
	if(!stripper)
		stripper = src
	if(!stripper.check_agevet())
		to_chat(stripper, span_warning("You must be age-verified to do that. Open a ticket in the server's verification channel to get whitelisted."))
		return FALSE
	if(!check_agevet())
		if(stripper == src)
			to_chat(stripper, span_warning("You must be age-verified to do that. Open a ticket in the server's verification channel to get whitelisted."))
		else
			to_chat(stripper, span_warning("[src] is not age-verified, so you cannot undress their underwear."))
		return FALSE
	return TRUE
#endif

// for more convenient host oversight and perhaps an eventual database import.
/proc/log_agevet_to_csv(target_ckey, admin_ckey = "SYSTEM")
	if(IsAdminAdvancedProcCall()) // sorry for using this twice
		return
	var/csv_file = file("data/agevets_log.csv")
	var/current_date = time2text(world.timeofday, "YYYY-MM-DD")
	if(!fexists(csv_file))
		var/csv_columns = "player_ckey,admin_ckey,datestamp,rogue_round_id"
		WRITE_FILE(csv_file,csv_columns)
	csv_file << "[target_ckey],[admin_ckey],[current_date],[GLOB.rogue_round_id]"

// ---------------------------------------------------------------------------
// Whitelist / age-vet bonus dedup
//
// Persistent "the +10 whitelist bonus was already paid" marker. Lives in the
// player's own save dir so it survives data/agevets.json being wiped, which is
// the thing that used to let the bonus be paid over and over.
/proc/agevet_bonus_already_paid(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return FALSE
	return fexists("data/player_saves/[copytext(target_ckey,1,2)]/[target_ckey]/agevet_bonus.json")

/proc/mark_agevet_bonus_paid(target_ckey, amount = 10)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	var/marker = file("data/player_saves/[copytext(target_ckey,1,2)]/[target_ckey]/agevet_bonus.json")
	if(fexists(marker))
		return
	WRITE_FILE(marker, json_encode(list("granted" = amount, "round" = GLOB.rogue_round_id)))

/// Lowercase keyword fragments that mark a manual admin PQ deduction as a
/// whitelist-dupe correction rather than a genuine punishment. Used by the dedup
/// pass to decide which manual removals to hand back to the player.
GLOBAL_LIST_INIT(agevet_dedup_reason_keywords, list(
	"dup", "дубл", "дюп", "whitelist", "вайтлист", "вайт",
	"agevet", "age vet", "verif", "бонус", "bonus"))

/proc/agevet_reason_is_dedup_related(line)
	for(var/kw in GLOB.agevet_dedup_reason_keywords)
		if(findtext(line, kw)) // findtext is case-insensitive
			return TRUE
	return FALSE

/// Parses one player's playerquality.txt and summarises the whitelist-bonus
/// situation WITHOUT modifying anything. Returns an assoc list:
///   "bonus_count"      - how many +10 "Age verification bonus" payouts were logged
///   "bonus_total"      - sum of those payouts (bonus_count * 10)
///   "restore_keyword"  - magnitude of manual admin removals whose reason matches a dedup keyword
///   "restore_ten"      - magnitude of manual admin removals of exactly -10
///   "restore_all"      - magnitude of ALL manual admin removals (negative, non-SYSTEM)
///   "detail"           - human-readable list of the candidate manual removal lines
/proc/analyze_agevet_pq(target_ckey)
	var/list/result = list(
		"bonus_count" = 0, "bonus_total" = 0,
		"restore_keyword" = 0, "restore_ten" = 0, "restore_all" = 0,
		"detail" = "")
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return result
	var/path = "data/player_saves/[copytext(target_ckey,1,2)]/[target_ckey]/playerquality.txt"
	if(!fexists(path))
		return result
	for(var/line in world.file2list(path))
		if(!line)
			continue
		// The amount is the first whitespace-delimited token. "NOTE..." lines
		// (amt == 0 admin notes) parse to null and are skipped.
		var/list/parts = splittext(line, " ")
		if(!parts.len)
			continue
		var/amt = text2num(parts[1])
		if(isnull(amt))
			continue
		// A real bonus payout is a POSITIVE amount tagged with the reason string
		// only add_agevet ever writes.
		if(amt > 0 && findtext(line, "Age verification bonus"))
			result["bonus_count"] += 1
			result["bonus_total"] += amt
			continue
		// Candidate manual admin removal: negative and not a SYSTEM-written line.
		if(amt < 0 && !findtext(line, " by SYSTEM "))
			result["restore_all"] += -amt
			if(amt == -10)
				result["restore_ten"] += -amt
			if(agevet_reason_is_dedup_related(line))
				result["restore_keyword"] += -amt
				result["detail"] += "[line]\n"
	return result

/// Computes and (optionally) applies the correction for a single ckey.
/// mode: "keyword" (default, safest), "ten", "all", or "none".
/// Returns the net delta that was (or would be) applied. dry_run reports only.
/// The correction removes duplicate +10 bonuses down to a single entitlement and
/// hands back manual admin removals selected by `mode`, capped so we never restore
/// more PQ than the duplicates cost in the first place.
/proc/fix_agevet_pq_single(target_ckey, mode = "keyword", dry_run = TRUE, admin_ckey, force = FALSE)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return 0
	var/prefix = copytext(target_ckey, 1, 2)
	var/marker = "data/player_saves/[prefix]/[target_ckey]/pq_agevet_dedup_v1.json"
	if(!dry_run && !force && fexists(marker))
		return 0
	var/list/info = analyze_agevet_pq(target_ckey)
	var/bonus_count = info["bonus_count"]
	if(bonus_count <= 0)
		return 0
	// Seal the one legit entitlement so the fixed add_agevet never re-pays it,
	// even under a dry run (this only records that a bonus exists; it grants nothing).
	if(!dry_run)
		mark_agevet_bonus_paid(target_ckey)
	var/excess = info["bonus_total"] - 10 // keep exactly one +10
	if(excess < 0)
		excess = 0
	var/restore = 0
	switch(mode)
		if("keyword")
			restore = info["restore_keyword"]
		if("ten")
			restore = info["restore_ten"]
		if("all")
			restore = info["restore_all"]
		else
			restore = 0
	restore = min(restore, excess) // never hand back more than the dupes cost
	var/net_delta = restore - excess
	if(!dry_run)
		if(net_delta != 0)
			adjust_playerquality(net_delta, target_ckey, admin_ckey, "Whitelist bonus dedup (removed [excess] dupe, restored [restore] manual)")
		WRITE_FILE(file(marker), json_encode(list(
			"applied" = net_delta, "excess" = excess, "restored" = restore,
			"bonus_count" = bonus_count, "mode" = mode, "round" = GLOB.rogue_round_id)))
	return net_delta

/client/proc/fix_agevet_pq_bulk()
	set category = "-Special Verbs-"
	set name = "PQ - Dedup Whitelist Bonus (Bulk)"
	set waitfor = FALSE
	if(!holder || !check_rights(R_ADMIN, 0))
		return
	var/run = alert(src, "Scan every player save for duplicate +10 whitelist bonuses (caused by the agevets list being lost) and correct them.\n\nDRY RUN just reports what it would do. APPLY writes the changes and is processed once per ckey.", "PQ Whitelist Dedup", "Dry Run", "Apply", "Cancel")
	if(run == "Cancel" || !run)
		return
	var/dry_run = (run == "Dry Run")
	var/mode = "keyword"
	if(alert(src, "Which manual admin PQ removals should be handed back?\n\nKeyword = only removals whose reason mentions dupe/whitelist/agevet (SAFEST).\nAdvanced = pick ten / all / none.\n\n(All modes are capped so you never restore more than the dupes were worth.)", "Restore mode", "Keyword (recommended)", "Advanced") == "Advanced")
		mode = input(src, "Restore mode:\n- ten: any manual -10\n- all: every manual removal\n- none: remove dupes only, restore nothing", "Restore mode", "ten") as null|anything in list("keyword", "ten", "all", "none")
		if(!mode)
			return
	var/scanned = 0
	var/affected = 0
	var/total_delta = 0
	for(var/pfx in flist("data/player_saves/"))
		if(copytext(pfx, length(pfx)) != "/")
			continue
		for(var/ckey_dir in flist("data/player_saves/[pfx]"))
			if(copytext(ckey_dir, length(ckey_dir)) != "/")
				continue
			var/the_ckey = ckey(copytext(ckey_dir, 1, length(ckey_dir)))
			if(!the_ckey)
				continue
			scanned++
			var/list/info = analyze_agevet_pq(the_ckey)
			if(info["bonus_count"] <= 1) // 0 or 1 bonus = nothing to dedup
				CHECK_TICK
				continue
			var/delta = fix_agevet_pq_single(the_ckey, mode, dry_run, src.ckey)
			if(delta != 0)
				affected++
				total_delta += delta
				if(dry_run)
					to_chat(src, span_info("[the_ckey]: [info["bonus_count"]] bonuses, would apply [delta] (excess -[info["bonus_total"] - 10], restore capped by mode '[mode]')."))
			CHECK_TICK
	var/msg = "[src.ckey] ran whitelist-bonus dedup ([dry_run ? "DRY RUN" : "APPLIED"], mode '[mode]'): [scanned] scanned, [affected] affected, net [total_delta] PQ."
	to_chat(src, "<span class=\"admin\"><span class=\"prefix\">ADMIN LOG:</span> <span class=\"message linkify\">[msg]</span></span>")
	if(!dry_run)
		message_admins(msg)
		log_admin(msg)

/client/proc/fix_agevet_pq_lookup()
	set category = "-Special Verbs-"
	set name = "PQ - Dedup Whitelist Bonus (Single)"
	if(!holder || !check_rights(R_ADMIN, 0))
		return
	var/the_ckey = ckey(stripped_input(src, "Which ckey?", "PQ Whitelist Dedup", ""))
	if(!the_ckey)
		return
	var/list/info = analyze_agevet_pq(the_ckey)
	var/report = "[the_ckey]: [info["bonus_count"]] bonus payouts (total +[info["bonus_total"]]).\nManual removal candidates - keyword-matched: -[info["restore_keyword"]], any -10: -[info["restore_ten"]], all: -[info["restore_all"]]."
	if(info["detail"])
		report += "\nKeyword-matched lines:\n[info["detail"]]"
	to_chat(src, span_info(report))
	if(info["bonus_count"] <= 1)
		to_chat(src, span_notice("Nothing to dedup (0 or 1 bonus)."))
		return
	var/mode = input(src, "Restore mode (see previous report):", "Restore mode", "keyword") as null|anything in list("keyword", "ten", "all", "none")
	if(!mode)
		return
	var/run = alert(src, "Preview or apply?", "PQ Whitelist Dedup", "Dry Run", "Apply", "Cancel")
	if(run == "Cancel" || !run)
		return
	var/dry_run = (run == "Dry Run")
	var/marker = "data/player_saves/[copytext(the_ckey,1,2)]/[the_ckey]/pq_agevet_dedup_v1.json"
	var/force = FALSE
	if(!dry_run && fexists(marker))
		if(alert(src, "[the_ckey] was already deduped. Force again? (may double-correct)", "PQ Whitelist Dedup", "No", "Yes") != "Yes")
			return
		force = TRUE
	var/delta = fix_agevet_pq_single(the_ckey, mode, dry_run, src.ckey, force)
	var/msg = "[src.ckey] [dry_run ? "previewed" : "applied"] whitelist dedup for [the_ckey] (mode '[mode]'): net [delta] PQ."
	to_chat(src, span_info(msg))
	if(!dry_run)
		message_admins(msg)
		log_admin(msg)
