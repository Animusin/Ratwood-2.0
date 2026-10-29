PROCESSING_SUBSYSTEM_DEF(tracks)
	name = "Tracks"
	priority = FIRE_PRIORITY_TRACKS
	wait = 100
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	// Object pooling
	var/list/track_pool
	var/list/thievescant_pool
	var/pool_max_size 
	var/tracks_recycled
	var/tracks_created

/datum/controller/subsystem/processing/tracks/Initialize()
	track_pool = list()
	thievescant_pool = list()

	pool_max_size = 1000
	tracks_recycled = 0
	tracks_created = 0 
	return ..()

/datum/controller/subsystem/processing/tracks/stat_entry()
	if(processing)
		..("P:[length(processing)] | Pool:[length(track_pool)+length(thievescant_pool)] | R:[tracks_recycled] | N:[tracks_created] | B:[GLOB.active_forensic_blood_decals]")

/datum/controller/subsystem/processing/tracks/fire(resumed = 0)
	if (!resumed)
		src.currentrun = processing.Copy()

	var/list/currentrun = src.currentrun

	while(length(currentrun))
		var/obj/effect/track/T = currentrun[currentrun.len]
		currentrun.len--

		if (!T || QDELETED(T))
			processing -= T
			if (MC_TICK_CHECK)
				return
			continue

		if(world.time >= T.expiry_time)
			recycle_track(T)

		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/processing/tracks/proc/add_track(obj/effect/track/T)
	if(!QDELETED(T) && !T.registered_for_expiry && !T.in_track_pool)
		T.registered_for_expiry = TRUE
		processing += T

/datum/controller/subsystem/processing/tracks/proc/remove_track(obj/effect/track/T)
	if(T?.registered_for_expiry)
		T.registered_for_expiry = FALSE
		processing -= T
	if(T?.in_track_pool)
		T.in_track_pool = FALSE
		track_pool -= T
		thievescant_pool -= T

/datum/controller/subsystem/processing/tracks/proc/get_track(track_type = /obj/effect/track, turf/location)
	var/list/pool
	switch(track_type)
		if(/obj/effect/track/thievescant)
			pool = thievescant_pool
		if(/obj/effect/track)
			pool = track_pool

	var/obj/effect/track/T
	while(length(pool))
		T = pool[pool.len]
		pool.len--
		if(QDELETED(T))
			continue
		T.in_track_pool = FALSE
		if(T.type != track_type)
			qdel(T)
			continue
		T.forceMove(location)
		tracks_recycled++
		return T

	T = new track_type(location)
	tracks_created++
	return T

/datum/controller/subsystem/processing/tracks/proc/recycle_track(obj/effect/track/T)
	if(QDELETED(T) || T.in_track_pool)
		return

	remove_track(T)
	var/list/pool

	switch(T.type)
		if(/obj/effect/track/thievescant)
			pool = thievescant_pool
		if(/obj/effect/track)
			pool = track_pool
		else
			// Specialized clues must not be handed out later as ordinary footprints.
			qdel(T)
			return

	if(length(pool) >= pool_max_size)
		qdel(T)
		return

	T.soft_reset()
	T.moveToNullspace()
	T.in_track_pool = TRUE
	pool += T
