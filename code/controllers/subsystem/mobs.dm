SUBSYSTEM_DEF(mobs)
	name = "Mobs"
	priority = FIRE_PRIORITY_MOBS
	flags = SS_KEEP_TIMING | SS_NO_INIT
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	var/list/currentrun = list()
	var/static/list/clients_by_zlevel[][]
	var/static/list/dead_players_by_zlevel[][] = list(list())
	var/static/list/cubemonkeys = list()
	var/alive_mobs = 0

/datum/controller/subsystem/mobs/stat_entry()
	..("P:[GLOB.mob_living_list.len]")

/datum/controller/subsystem/mobs/proc/MaxZChanged()
	if (!islist(clients_by_zlevel))
		clients_by_zlevel = new /list(world.maxz,0)
		dead_players_by_zlevel = new /list(world.maxz,0)
	while (clients_by_zlevel.len < world.maxz)
		clients_by_zlevel.len++
		clients_by_zlevel[clients_by_zlevel.len] = list()
		dead_players_by_zlevel.len++
		dead_players_by_zlevel[dead_players_by_zlevel.len] = list()

/datum/controller/subsystem/mobs/proc/MaxZDec()
	if (!islist(clients_by_zlevel))
		clients_by_zlevel = new /list(world.maxz,0)
		dead_players_by_zlevel = new /list(world.maxz,0)
	while (clients_by_zlevel.len > world.maxz)
		clients_by_zlevel.len--
		dead_players_by_zlevel.len--

/datum/controller/subsystem/mobs/fire(resumed = 0)
	var/seconds = wait * 0.1

	if (!resumed)
		src.currentrun = GLOB.mob_living_list.Copy()
		alive_mobs = 0
	var/list/currentrun = src.currentrun
	var/times_fired = src.times_fired
	var/datum/lag_recorder/recorder = Master.lag_recorder
	var/slice_tick = recorder ? world.time : 0
	var/slice_start = recorder ? TICK_USAGE : 0
	var/list/type_costs = recorder ? list() : null
	var/slowest_cost = 0
	var/slowest_type
	var/slowest_phase
	var/processed = 0

	while(currentrun.len)
		var/mob/living/L = currentrun[currentrun.len]
		currentrun.len--

		if(!L || QDELETED(L))
			GLOB.mob_living_list.Remove(L)
			continue

		var/start_usage = recorder ? TICK_USAGE : 0
		var/mob_type = recorder ? L.type : null
		var/dead = L.stat == DEAD
		if(dead)
			L.DeadLife()
		else
			L.Life(seconds, times_fired)
			alive_mobs++

		if(recorder && slice_tick == world.time)
			processed++
			var/cost_ms = TICK_USAGE_TO_MS(start_usage)
			if(cost_ms > 0)
				type_costs[mob_type] = (type_costs[mob_type] || 0) + cost_ms
				if(cost_ms > slowest_cost)
					slowest_cost = cost_ms
					slowest_type = mob_type
					slowest_phase = dead ? "DeadLife" : "Life"
		if (MC_TICK_CHECK)
			break

	if(recorder && !QDELETED(recorder) && slice_tick == world.time && TICK_USAGE_TO_MS(slice_start) >= 4)
		recorder.record_mob_slice(TICK_USAGE_TO_MS(slice_start), type_costs, processed, slowest_type, slowest_phase, slowest_cost)
