/datum/rotation_network
	var/total_stress = 0
	var/used_stress = 0
	var/overstressed = FALSE
	var/rebuilding = FALSE

	var/list/connected = list()

/datum/rotation_network/proc/add_connection(obj/structure/incoming)
	connected |= incoming
	incoming.rotation_network = src
	incoming.update_animation_effect()

/datum/rotation_network/proc/remove_connection(obj/structure/outgoing)
	if(outgoing.last_stress_generation)
		total_stress -= outgoing.last_stress_generation
	if(!outgoing.stress_generator)
		outgoing.rotation_direction = null
		outgoing.set_rotations_per_minute(0)
	if(outgoing.last_stress_added)
		used_stress -= outgoing.last_stress_added
		outgoing.last_stress_added = 0
	outgoing.rotation_network = null
	connected -= outgoing
	outgoing.update_animation_effect()

/datum/rotation_network/proc/check_stress()
	if(rebuilding)
		return
	if(total_stress > 0 && total_stress < used_stress)
		breakdown()
	else if(overstressed)
		restore()

/datum/rotation_network/proc/breakdown()
	overstressed = TRUE
	for(var/obj/structure/child as anything in connected)
		if(QDELETED(child))
			continue
		child.MakeParticleEmitter(/particles/sparks, FALSE, 1 SECONDS)
	update_animation_effect()

/datum/rotation_network/proc/restore()
	overstressed = FALSE
	update_animation_effect()

/datum/rotation_network/proc/update_animation_effect()
	for(var/obj/structure/child in connected)
		child.update_animation_effect()

/// Reset all non stress generators. Re-propagate from stress generators.
/datum/rotation_network/proc/rebuild_group()
	rebuilding = TRUE
	var/obj/structure/driver
	for(var/obj/structure/child in connected)
		if(!child.stress_generator)
			child.rotation_direction = null
			child.set_rotations_per_minute(0)
			var/old_stress_use = child.stress_use
			child.set_stress_use(0)
			child.set_stress_use(old_stress_use, check_network = FALSE)
			continue
		if(!child.rotation_direction || !child.rotations_per_minute)
			continue
		if(!driver || child.rotations_per_minute > driver.rotations_per_minute)
			driver = child

	// A connected drivetrain has one effective RPM. Propagating once from the fastest active
	// source avoids traversing the entire network once per generator whenever it is rebuilt.
	if(driver)
		driver.find_and_propagate(list(), TRUE)
	rebuilding = FALSE
	check_stress()

/datum/rotation_network/proc/reassess_group(obj/structure/deleted)
	var/list/returned_nearbys = deleted.return_surrounding_rotation(src)

	for(var/obj/structure/near in returned_nearbys)
		if(!(near in connected))
			continue
		var/list/returned = near.return_connected(deleted, list(), src)
		if(!length(returned))
			continue
		if(length(connected) == length(returned))
			rebuild_group()
			return
		var/datum/rotation_network/new_network = new
		for(var/obj/structure/returned_object in returned)
			remove_connection(returned_object)
			new_network.add_connection(returned_object)
			if(returned_object.stress_use) // remove_connection resets last_stress_added
				returned_object.set_stress_use(returned_object.stress_use, check_network = FALSE)
			if(returned_object.stress_generator)
				new_network.total_stress += returned_object.last_stress_generation // this is undone in set_stress_generation
				returned_object.set_stress_generation(returned_object.last_stress_generation, check_network = FALSE)
		new_network.rebuild_group()

	if(!length(connected))
		qdel(src)
		return
	rebuild_group()
