/proc/create_all_lighting_objects()
	// Explicit CHECK_TICK calls copy and schedule this entire nested iterator through stoplag().
	// With hundreds of thousands of turfs, that crashes DreamDaemon 516.1679 during startup.
	// Background processing yields at loop boundaries without sending the iterator through stoplag().
	set background = TRUE

	for(var/area/A in world)
		if(!IS_DYNAMIC_LIGHTING(A))
			continue

		for(var/turf/T in A)

			if(!IS_DYNAMIC_LIGHTING(T))
				continue

			new/atom/movable/lighting_object(T)
