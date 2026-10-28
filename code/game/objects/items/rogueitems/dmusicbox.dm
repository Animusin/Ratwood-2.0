GLOBAL_LIST_EMPTY(musicboxes) //list of all music boxes
GLOBAL_VAR_INIT(musicboxes_last_upload, 0) //last time of the last upload, to prevent multiple uploads within seconds of eachother
GLOBAL_VAR_INIT(musicboxes_last_play, 0) //last time of the last played track, to prevent spamming clients too often with play/stop
GLOBAL_VAR_INIT(custom_music_upload_sequence, 0)

/// Subtypes must revalidate access to the item after all file/name/subscription dialogs.
/obj/item/proc/can_accept_custom_music_upload(mob/user)
	return FALSE

/// Shared by instruments and music boxes. Failed/cancelled uploads never debit Triumphs.
/obj/item/proc/store_custom_music_upload(mob/user, infile)
	if(QDELETED(src) || !user?.client || !infile)
		return null
	var/client/player = user.client
	var/file_ext = LOWER_TEXT(copytext("[infile]", -4))
	var/file_size = length(infile)
	if(file_ext != ".ogg" || file_size <= 0 || file_size > 6485760)
		to_chat(user, span_warning("Song must be a non-empty OGG file, 6 MB or less."))
		return null
	var/cost = player.custom_music_upload_cost(TRUE)
	if(isnull(cost))
		to_chat(user, span_warning("Unable to check your subscription. No Triumphs were spent; try again later."))
		return null
	if(QDELETED(src) || QDELETED(user) || user.client != player || !can_accept_custom_music_upload(user))
		return null
	if(cost && SStriumphs.get_triumphs(player.ckey) < cost)
		to_chat(user, span_warning("One custom song upload costs [cost] Triumphs. You do not have enough."))
		return null
	// Never use the uploaded filename as a server path or overwrite an earlier paid song.
	var/upload_number = ++GLOB.custom_music_upload_sequence
	var/path = "data/jukeboxuploads/round-[GLOB.round_id || "NULL"]/[player.ckey[1]]/[player.ckey]/[world.realtime]-[world.time]-[upload_number].ogg"
	if(!fcopy(infile, path))
		to_chat(user, span_warning("Could not save song. No Triumphs were spent."))
		return null
	var/uploaded_file = file(path)
	if(length(uploaded_file) != file_size || !SStriumphs.try_spend_triumphs(player.ckey, cost))
		fdel(path)
		to_chat(user, span_warning("Upload failed or your Triumph balance changed. No Triumphs were spent."))
		return null
	user.log_message("uploaded custom song: [path] (cost: [cost] Triumphs)", LOG_GAME)
	message_admins("[ADMIN_LOOKUPFLW(user)] uploaded a custom song ([file_size] bytes, [cost] Triumphs).")
	if(cost)
		to_chat(user, span_notice("Custom song uploaded for [cost] Triumphs. Replaying it costs nothing."))
	return uploaded_file

/datum/looping_sound/dmusloop
	mid_sounds = list()
	mid_length = 12000 // 20 minutes to force a loop. File size determines server load, not audio length. Low bitrate .ogg files can run long and have their uses as ambient sound.
	volume = 100
	falloff = 2
	extra_range = 10	// Up from 5, fill a room.
	var/stress2give = /datum/stressevent/music
	persistent_loop = TRUE
	channel = CHANNEL_CMUSIC1

/datum/looping_sound/dmusloop/on_hear_sound(mob/M)
	. = ..()
	if(stress2give)
		if(isliving(M))
			var/mob/living/carbon/L = M
			L.add_stress(stress2give)

/obj/item/dmusicbox
	name = "dwarven music box"
	desc = "It is essential that the deepest caves be tuned to the right frequency of vibrations."
	icon = 'icons/roguetown/misc/machines.dmi'
	icon_state = "mbox0"
	gripped_intents = list(INTENT_GENERIC)
	w_class = WEIGHT_CLASS_HUGE
	twohands_required = TRUE
	force = 20
	throwforce = 20
	throw_range = 2
	var/datum/looping_sound/dmusloop/soundloop
	var/curfile
	var/playing = FALSE
	var/loaded = TRUE
	var/lastfilechange = 0
	var/curvol = 100
	anvilrepair = /datum/skill/craft/blacksmithing

/obj/item/dmusicbox/Initialize(mapload)
	GLOB.musicboxes += src
	soundloop = new(src, FALSE)
//	soundloop.start()
	update_icon()
	. = ..()

/obj/item/dmusicbox/Destroy()
	GLOB.musicboxes -= src
	playing = FALSE
	QDEL_NULL(soundloop)
	return ..()

/obj/item/dmusicbox/update_icon()
	if(playing)
		icon_state = "mboxon"
	else
		icon_state = "mbox[loaded]"

/obj/item/dmusicbox/attackby(obj/item/P, mob/user, params)
	if(!loaded)
		if(istype(P, /obj/item/roguecoin/copper))
			loaded=TRUE
			qdel(P)
			update_icon()
			playsound(loc, 'sound/misc/machinevomit.ogg', 100, TRUE, -1)
			return
	. = ..()

/obj/item/dmusicbox/rmb_self(mob/user)
	attack_right(user)
	return

/obj/item/dmusicbox/attack_right(mob/user)
	. = ..()
	if(.)
		return
	if(loc != user)
		return
	if(!user.ckey)
		return
	if(playing)
		return
	if(!user.can_upload_custom_music())
		to_chat(user, span_warning("Custom music uploads cost [CUSTOM_MUSIC_UPLOAD_COST] Triumphs each; Scientist subscribers and admins upload for free."))
		return
	user.changeNext_move(CLICK_CD_MELEE)
	if(lastfilechange)
		if(world.time < lastfilechange + 3 MINUTES)
			say("NOT YET!")
			return
	if(!loaded)
		say("ONE COIN, A COPPER COIN FOR AN AFTERNOON OF JOY!")
		return
	playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
	INVOKE_ASYNC(src, PROC_REF(upload_file), user) // call as thread to avoid halting while waiting for user file input

/obj/item/dmusicbox/can_accept_custom_music_upload(mob/user)
	return !QDELETED(user) && user.client && loc == user && loaded && !playing && (!lastfilechange || world.time >= lastfilechange + 3 MINUTES) && world.time >= GLOB.musicboxes_last_upload + 30 SECONDS

/obj/item/dmusicbox/proc/upload_file(mob/user)
	set waitfor = FALSE
	if(!can_accept_custom_music_upload(user))
		return
	var/infile = input(user, "CHOOSE A NEW SONG ([CUSTOM_MUSIC_UPLOAD_COST] Triumphs per successful upload; free for Scientist+ and admins). Replaying is free; cancelling costs nothing.", src) as null|file
	if(!infile)
		return
	var/uploaded_file = store_custom_music_upload(user, infile)
	if(!uploaded_file)
		return
	curfile = uploaded_file
	lastfilechange = world.time
	GLOB.musicboxes_last_upload = world.time
	loaded = FALSE
	update_icon()

/obj/item/dmusicbox/attack_self(mob/living/user)
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
	if(!playing)
		if(curfile)
			var/new_channel = find_free_channel()
			if(!new_channel)
				to_chat(user, span_warning("TOO MANY MUSIC BOXES IN USE AT THE SAME TIME IN THE WORLD."))
				return
			if(world.time < GLOB.musicboxes_last_play + 10 SECONDS)
				to_chat(user, span_warning("STILL WARMING UP..."))
				return
			GLOB.musicboxes_last_play = world.time
			playing = TRUE
			soundloop.channel = new_channel
			soundloop.set_mid_sounds(list(curfile))
			soundloop.cursound = null
			soundloop.start()
			user.log_message("played jukebox song: [curfile]", LOG_GAME)
	else
		playing = FALSE
		soundloop.stop()
		if(curfile)
			user.log_message("stopped jukebox song: [curfile]", LOG_GAME)
	update_icon()

/obj/item/dmusicbox/proc/find_free_channel()
	var/free_channel = 1|2|4|8
	for(var/obj/item/dmusicbox/musicbox in GLOB.musicboxes)
		if(!musicbox.playing || musicbox.soundloop.stopped)
			continue
		switch(musicbox.soundloop.channel)
			if(CHANNEL_CMUSIC1)
				free_channel &= ~1
			if(CHANNEL_CMUSIC2)
				free_channel &= ~2
			if(CHANNEL_CMUSIC3)
				free_channel &= ~4
			if(CHANNEL_CMUSIC4)
				free_channel &= ~8
	if(!free_channel) // no channels free, abort
		return 0

	if(free_channel&1)
		return CHANNEL_CMUSIC1
	if(free_channel&2)
		return CHANNEL_CMUSIC2
	if(free_channel&4)
		return CHANNEL_CMUSIC3
	if(free_channel&8)
		return CHANNEL_CMUSIC4
	return 0
