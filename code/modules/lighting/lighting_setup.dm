/proc/create_all_lighting_objects()
	// Must not call stoplag()/sleep (this is what CHECK_TICK did here): explicit
	// sleeps amid the initial lighting appearance churn hard-crash Linux
	// DreamDaemon 516.1679 ("BUG: Unable to read icon" + illegal operation).
	// Background yielding survives it, so we rely on set background instead.
	// See also /datum/controller/subsystem/lighting/proc/init_all_queues().
	set background = TRUE

	for(var/area/A in world)
		if(!IS_DYNAMIC_LIGHTING(A))
			continue

		for(var/turf/T in A)

			if(!IS_DYNAMIC_LIGHTING(T))
				continue

			T.underlays += GLOB.lighting_underlay_dark
			T.luminosity = 0
