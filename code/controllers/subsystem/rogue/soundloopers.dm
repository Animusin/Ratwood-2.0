
SUBSYSTEM_DEF(soundloopers)
	name = "soundloopers"
	wait = 1
	flags = SS_NO_INIT
	priority = FIRE_PRIORITY_DEFAULT
	var/list/processing = list()
	/// Existing sound datums form an indexed min-heap; repeating a sound allocates no timer or queue node.
	var/list/sound_queue = list()
	/// Persistent loops and clients awaiting the half-second audibility pass.
	var/list/currentrun = list()
	var/list/clientrun = list()
	var/next_client_update = 0
	var/sound_deadline = 0
	var/processing_due_sounds = FALSE

/datum/controller/subsystem/soundloopers/fire(resumed = 0)
	if(!resumed)
		// A loop gets at most one attempt per fire, including fires resumed on later ticks.
		sound_deadline = world.time
		processing_due_sounds = TRUE
		if(world.time >= next_client_update)
			next_client_update = world.time + 0.5 SECONDS
			currentrun = GLOB.persistent_sound_loops.Copy()
			clientrun = GLOB.clients.Copy()

	if(processing_due_sounds)
		while(length(sound_queue))
			var/datum/looping_sound/thing = sound_queue[1]
			if(thing.next_sound_time >= sound_deadline)
				break
			remove_queued_sound(thing)
			if(QDELETED(thing) || thing.stopped)
				unregister_sound(thing)
			else
				thing.sound_loop()
				// Failed chance rolls retry next fire, as before, without replaying in this fire.
				if(!QDELETED(thing) && !thing.stopped)
					schedule_sound(thing, TRUE)
			if(MC_TICK_CHECK)
				return
		processing_due_sounds = FALSE

	while(length(currentrun))
		var/datum/looping_sound/thing = currentrun[currentrun.len]
		currentrun.len--
		if(!QDELETED(thing) && !thing.stopped && thing.persistent_loop && processing[thing])
			thing.refresh_listeners()
		if(MC_TICK_CHECK)
			return

	while(length(clientrun))
		var/client/listener = clientrun[clientrun.len]
		clientrun.len--
		if(listener?.mob)
			listener.update_sounds()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/soundloopers/proc/register_sound(datum/looping_sound/thing)
	if(QDELETED(thing) || thing.stopped)
		return
	processing[thing] = TRUE
	schedule_sound(thing, TRUE)

/datum/controller/subsystem/soundloopers/proc/unregister_sound(datum/looping_sound/thing)
	remove_queued_sound(thing)
	processing -= thing
	currentrun -= thing

/// Reposition a running loop after playback or a change to its interval.
/datum/controller/subsystem/soundloopers/proc/schedule_sound(datum/looping_sound/thing, after_attempt = FALSE)
	if(!processing[thing] || QDELETED(thing) || thing.stopped)
		return
	thing.next_sound_time = thing.starttime + thing.mid_length
	if(after_attempt)
		thing.next_sound_time = max(world.time, thing.next_sound_time)
	if(!thing.sound_queue_index)
		sound_queue += thing
		thing.sound_queue_index = sound_queue.len
	repair_sound_queue(thing.sound_queue_index)

/datum/controller/subsystem/soundloopers/proc/remove_queued_sound(datum/looping_sound/thing)
	var/index = thing.sound_queue_index
	if(!index)
		return
	thing.sound_queue_index = 0
	var/last_index = sound_queue.len
	if(index == last_index)
		sound_queue.len--
		return
	var/datum/looping_sound/replacement = sound_queue[last_index]
	sound_queue.len--
	sound_queue[index] = replacement
	replacement.sound_queue_index = index
	repair_sound_queue(index)

/datum/controller/subsystem/soundloopers/proc/swap_sounds(first_index, second_index)
	var/datum/looping_sound/first = sound_queue[first_index]
	var/datum/looping_sound/second = sound_queue[second_index]
	sound_queue.Swap(first_index, second_index)
	first.sound_queue_index = second_index
	second.sound_queue_index = first_index

/datum/controller/subsystem/soundloopers/proc/repair_sound_queue(index)
	var/datum/looping_sound/thing = sound_queue[index]
	while(index > 1)
		var/parent_index = index >> 1
		var/datum/looping_sound/parent_sound = sound_queue[parent_index]
		if(parent_sound.next_sound_time <= thing.next_sound_time)
			break
		swap_sounds(index, parent_index)
		index = parent_index
	while(index * 2 <= sound_queue.len)
		var/child_index = index * 2
		var/datum/looping_sound/child = sound_queue[child_index]
		if(child_index < sound_queue.len)
			var/datum/looping_sound/right_child = sound_queue[child_index + 1]
			if(right_child.next_sound_time < child.next_sound_time)
				child_index++
				child = right_child
		if(thing.next_sound_time <= child.next_sound_time)
			break
		swap_sounds(index, child_index)
		index = child_index

/client/proc/update_persistent_sound_loop(datum/looping_sound/PS)
	if(PS in played_loops) //Make sure it's not already on the list
		return

	if((istype(PS, /datum/looping_sound/instrument) || istype(PS, /datum/looping_sound/musloop) || istype(PS, /datum/looping_sound/dmusloop)) && !(prefs?.toggles & SOUND_INSTRUMENTS))
		return

	if(!PS.parent)
		return

	var/turf/parent_turf = get_turf(PS.parent)
	var/turf/mob_turf = get_turf(mob)
	if(get_dist(get_turf(mob),parent_turf) > world.view + PS.extra_range) //Too far away. get_dist shouldn't be too awful for repeated calcs
		return

	if(mob_turf.z - parent_turf.z > 2 || mob_turf.z - parent_turf.z < -2) //for some reason get_dist not checking this properly
		return

	//otherwise add it to the client loops and off we go from there
	var/sound/our_sound = PS.cursound
	if(!istype(our_sound)) //somehow it doesn't have a correct sound
		our_sound = sound(our_sound)
	if(!our_sound)
		return //something fucked up and the loop has no cursound, wups. this should basically never happen

	mob.playsound_local(parent_turf, PS.cursound, PS.volume, PS.vary, PS.frequency, PS.falloff, PS.channel, FALSE, our_sound, repeat = PS)

/client/proc/update_sounds()
	//Now we check how far away etc we are
	for(var/datum/looping_sound/loop in played_loops)
		if (!loop)
			played_loops -= loop
			continue

		if((istype(loop, /datum/looping_sound/instrument) || istype(loop, /datum/looping_sound/musloop) || istype(loop, /datum/looping_sound/dmusloop)) && !(prefs?.toggles & SOUND_INSTRUMENTS))
			var/list/muted_loop = played_loops[loop]
			var/sound/muted_sound = muted_loop?["SOUND"]
			if(loop.persistent_loop)
				muted_loop["MUTESTATUS"] = TRUE
				muted_loop["VOL"] = 0
				if(muted_sound)
					mob.mute_sound(muted_sound)
			else
				played_loops -= loop
				loop.thingshearing -= WEAKREF(mob)
				if(muted_sound)
					mob.stop_sound_channel(muted_sound.channel)
			continue
		
		var/atom/loop_parent = loop.parent
		if(!loop_parent)
			// Parent is gone — stale entry. Remove it so its old channel number
			// can't corrupt volume-update packets sent to a recycled channel.
			// Do NOT stop the channel: it may have been reused by another datum.
			played_loops -= loop
			continue

		if(mob && loop_parent == mob) //the sound's coming from inside the house!
			// Skip distance-based attenuation for your own instrument, but still
			// clear MUTESTATUS if it got stuck TRUE (e.g. playsound() missed the
			// musician during a z-level transition and muted them in play()).
			var/list/self_loop = played_loops[loop]
			if(self_loop && self_loop["MUTESTATUS"])
				self_loop["MUTESTATUS"] = FALSE
				self_loop["VOL"] = loop.volume
				var/sound/self_sound = self_loop["SOUND"]
				if(self_sound)
					mob.unmute_sound(self_sound)
			continue

		var/max_distance = world.view + loop.extra_range
		var/turf/source_turf = get_turf(loop_parent)
		var/distance_between = get_dist(mob, loop_parent)

		if(isturf(loop_parent))
			source_turf = loop_parent
		if(!source_turf) //somehow
			continue

		var/list/found_loop = played_loops[loop]
		var/sound/found_sound = found_loop["SOUND"]

		if(!found_loop || !istype(found_sound)) //somethin fucky goin on. lets ignore it
			played_loops -= loop
			continue

		if(distance_between > max_distance || mob.IsSleeping()) // || !mob in hearers(max_distance,source_turf))
			//We are too far away, turn it off, or suppress it if its a persistent tune like music boxes
			if(loop.persistent_loop)
				found_loop["MUTESTATUS"] = TRUE
				found_loop["VOL"] = 0
				mob.mute_sound(found_sound)
			else
				played_loops -= loop
				loop.thingshearing -= WEAKREF(mob)
				mob.stop_sound_channel(found_sound.channel)

		else if(distance_between <= max_distance)
			//We are close enough to hear, check if volume should be changed

			var/new_volume = loop.volume
			var/old_volume = found_loop["VOL"]

			new_volume -= (distance_between * (0.1 * new_volume)) //reduce volume by 10% per tile

			if(new_volume > 100)
				new_volume = 100 //could just min() this but whatever. we old skool

			if(new_volume <= 0) //Too quiet to hear despite being in range
				if(loop.persistent_loop) //Copy pasting instead of making a new proc? egads you monster
					found_loop["MUTESTATUS"] = TRUE
					found_loop["VOL"] = 0
					mob.mute_sound(found_sound)
				else
					played_loops -= loop
					loop.thingshearing -= WEAKREF(mob)
					mob.stop_sound_channel(found_sound.channel)
				continue

			//Some hacks for z-levels- this should be get_turf_above and _below
			//those would require us building a block of turfs though, ehhhh
			if(source_turf.z == mob.z + 1 || source_turf.z == mob.z - 1)
				new_volume = new_volume / 2
			else if (source_turf.z == mob.z + 2 || source_turf.z == mob.z - 2)
				new_volume = new_volume / 4

			new_volume = new_volume * (prefs.mastervol * 0.01) //Modify it at the end by the player's volume setting

			// Always clear MUTESTATUS when in range, regardless of whether volume changed.
			// Previously this was inside if(old_volume != new_volume), meaning a sound that
			// was muted and came back in range at an equal volume would stay permanently muted
			// (e.g. after a z-level transition where volume calculations produce the same value).
			if(loop.persistent_loop && found_loop["MUTESTATUS"] == TRUE)
				found_loop["MUTESTATUS"] = FALSE
				mob.unmute_sound(found_sound)

			if(old_volume != new_volume)
				var/turf/T = get_turf(mob)
				var/dx = source_turf.x - T.x
				if(dx <= 1 && dx >= -1)
					found_sound.x = 0
				else
					found_sound.x = dx
				var/dz = source_turf.y - T.y
				if(dz <= 1 && dz >= -1)
					found_sound.z = 0
				else
					found_sound.z = dz
//				var/dy = source_turf.z - T.z
//				found_sound.y = dy

				found_loop["VOL"] = new_volume
				mob.update_sound_volume(played_loops[loop]["SOUND"], new_volume)

