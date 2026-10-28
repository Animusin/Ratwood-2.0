/// Exercise the real weather handlers without touching the map's weather or areas.
/datum/particle_weather_test_environment
	var/list/saved_weather_state
	var/list/saved_areas
	var/list/saved_weather_objects
	var/list/saved_weather_observers
	var/list/saved_players
	var/saved_forecast
	var/list/created_weather = list()
	var/list/created_particles = list()
	var/list/area_appearances = list()

/datum/particle_weather_test_environment/New()
	..()
	saved_weather_state = list()
	for(var/field in list("runningWeather", "queued_weather", "queued_weather_start_time", "particleEffect", "weatherEffect", "weather_special_effect"))
		saved_weather_state[field] = SSParticleWeather.vars[field]
		SSParticleWeather.vars[field] = null
	saved_areas = GLOB.areas
	saved_weather_objects = GLOB.weather_act_upon_list
	saved_weather_observers = GLOB.weather_observers
	saved_players = GLOB.player_list
	saved_forecast = GLOB.forecast
	GLOB.areas = list()
	GLOB.weather_act_upon_list = list()
	GLOB.weather_observers = list()
	GLOB.player_list = list()
	SSParticleWeather.weatherEffect = new /obj()

	// Distinct runtime appearances catch both initial() resets and a shared old_plane.
	make_area(TRUE, 'icons/effects/light_overlays/light_32.dmi', "light2", 0, BLEND_ADD, 17)
	make_area(TRUE, 'icons/effects/96x96.dmi', "smoke-static", 13, BLEND_MULTIPLY, 23)
	make_area(FALSE, 'icons/effects/weather_overlay.dmi', "weather_overlay", 19, BLEND_DEFAULT, 29)

/datum/particle_weather_test_environment/Destroy()
	// Destroy test weather while the isolated subsystem and area list are still installed.
	for(var/datum/particle_weather/weather as anything in created_weather)
		if(!QDELETED(weather))
			qdel(weather)
	for(var/particles/weather/particles as anything in created_particles)
		if(!QDELETED(particles))
			qdel(particles)
	QDEL_NULL(SSParticleWeather.particleEffect)
	QDEL_NULL(SSParticleWeather.weatherEffect)
	for(var/area/test_area as anything in area_appearances)
		qdel(test_area)
	for(var/field in saved_weather_state)
		SSParticleWeather.vars[field] = saved_weather_state[field]
	GLOB.areas = saved_areas
	GLOB.weather_act_upon_list = saved_weather_objects
	GLOB.weather_observers = saved_weather_observers
	GLOB.player_list = saved_players
	GLOB.forecast = saved_forecast
	return ..()

/datum/particle_weather_test_environment/proc/make_area(outdoors, area_icon, area_icon_state, area_plane, area_blend, area_invisibility)
	var/area/particle_weather_test/test_area = new
	test_area.outdoors = outdoors
	test_area.icon = area_icon
	test_area.icon_state = area_icon_state
	test_area.plane = area_plane
	test_area.blend_mode = area_blend
	test_area.invisibility = area_invisibility
	var/list/appearance = list()
	for(var/field in list("icon", "icon_state", "plane", "blend_mode", "invisibility"))
		appearance[field] = test_area.vars[field]
	area_appearances[test_area] = appearance
	return test_area

/datum/particle_weather_test_environment/proc/check_areas(datum/unit_test/test, context)
	for(var/area/test_area as anything in area_appearances)
		var/list/appearance = area_appearances[test_area]
		for(var/field in appearance)
			if(test_area.vars[field] != appearance[field])
				test.Fail("[context]: [field] of an [test_area.outdoors ? "outdoor" : "indoor"] area changed from [appearance[field]] to [test_area.vars[field]].")

/datum/particle_weather_test_environment/proc/make_weather(weather_type)
	var/datum/particle_weather/weather = new weather_type()
	created_weather += weather
	return weather

/datum/particle_weather_test_environment/proc/track_particles()
	if(SSParticleWeather.particleEffect)
		created_particles |= SSParticleWeather.particleEffect
	return SSParticleWeather.particleEffect

/datum/particle_weather_test_environment/proc/start_weather(weather_type)
	var/datum/particle_weather/weather = make_weather(weather_type)
	SSParticleWeather.runningWeather = weather
	weather.start()
	track_particles()
	return weather

/area/particle_weather_test
	name = "particle weather test area"
	unique = FALSE
	outdoors = TRUE

/datum/unit_test/particle_weather_fog_lifecycle/Run()
	var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
	var/datum/particle_weather/fog/fog = environment.start_weather(/datum/particle_weather/fog)
	var/area/outdoor = GLOB.areas[1]
	TEST_ASSERT_EQUAL(outdoor.icon_state, "weather_overlay", "Starting real fog must apply its area overlay.")
	TEST_ASSERT_EQUAL(outdoor.plane, WEATHER_OVERLAY_PLANE, "The fixture must enter the fog rendering plane.")
	// A second start must not replace the saved baseline with the fog appearance.
	fog.start()
	fog.end()
	environment.check_areas(src, "Ending fog after a repeated start must restore each exact appearance")
	TEST_ASSERT_NULL(SSParticleWeather.runningWeather, "Normal fog completion must release the current weather.")
	TEST_ASSERT_NULL(SSParticleWeather.weatherEffect.particles, "Normal fog completion must detach particles.")

/datum/unit_test/particle_weather_fog_destroy/Run()
	var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
	var/datum/particle_weather/fog/fog = environment.start_weather(/datum/particle_weather/fog)
	var/runtimes_before = GLOB.total_runtimes
	qdel(fog)
	environment.check_areas(src, "Directly deleting fog must restore the original area appearances")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Direct deletion must complete without recursive destruction.")
	TEST_ASSERT_NULL(SSParticleWeather.runningWeather, "Deleting the current fog must release its subsystem reference.")
	TEST_ASSERT_NULL(SSParticleWeather.weatherEffect.particles, "Deleting fog must detach its particles from the renderer.")

/datum/unit_test/particle_weather_fog_unstarted/Run()
	for(var/force_replacement in list(FALSE, TRUE))
		var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
		SSParticleWeather.run_weather(/datum/particle_weather/fog, FALSE)
		var/datum/particle_weather/fog/fog = SSParticleWeather.queued_weather
		environment.created_weather += fog
		TEST_ASSERT(fog && !fog.running, "Scheduling fog must queue it without changing the areas yet.")
		TEST_ASSERT_EQUAL(SSParticleWeather.runningWeather, fog, "The fixture must exercise the shared running/queued reference.")
		TEST_ASSERT(length(fog.active_timers), "Queued fog must have real delayed warning/start callbacks to cancel.")
		if(force_replacement)
			SSParticleWeather.run_weather(/datum/particle_weather/rain_gentle, TRUE)
			environment.created_weather += SSParticleWeather.runningWeather
			environment.track_particles()
		else
			fog.end()
		environment.check_areas(src, "[force_replacement ? "Replacing queued fog" : "Ending fog before start"] must not alter areas it never changed")
		TEST_ASSERT(!length(fog.active_timers), "Cancelling queued fog must delete its delayed callbacks.")
		var/datum/particle_weather/current_weather = SSParticleWeather.runningWeather
		var/particles/weather/current_particles = SSParticleWeather.particleEffect
		fog.start()
		environment.track_particles()
		environment.check_areas(src, "A stale start callback must not reapply cancelled fog")
		TEST_ASSERT_EQUAL(SSParticleWeather.runningWeather, current_weather, "A stale callback must preserve the current weather owner.")
		TEST_ASSERT_EQUAL(SSParticleWeather.particleEffect, current_particles, "A stale callback must preserve the current weather's particles.")
		TEST_ASSERT(!length(fog.active_timers), "A stale start must not create new callbacks for deleted fog.")
		// Restore globals before the next scenario, including when check_areas fails.
		allocated -= environment
		qdel(environment)

/datum/unit_test/particle_weather_wind_down/Run()
	var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
	var/datum/particle_weather/weather = environment.start_weather(/datum/particle_weather/leaves_gentle)
	var/particles/weather/particles = SSParticleWeather.particleEffect
	TEST_ASSERT(particles.spawning > 0, "The fixture must spawn particles before wind-down.")
	weather.wind_down()
	if(particles.spawning != 0)
		TEST_FAIL("Wind-down must stop spawning completely, including weather with a minimum severity or spawn rate.")
	weather.start()
	environment.track_particles()
	if(SSParticleWeather.particleEffect != particles || SSParticleWeather.particleEffect?.spawning != 0)
		TEST_FAIL("A repeated start during wind-down must not replace or restart the fading particles.")
	// A severity callback queued before wind-down must not restart the effect.
	weather.ChangeSeverity()
	if(SSParticleWeather.particleEffect?.spawning != 0)
		TEST_FAIL("A pending severity callback must not resume particle spawning after wind-down.")
	weather.end()

	weather = environment.make_weather(/datum/particle_weather)
	weather.particleEffectType = null
	SSParticleWeather.runningWeather = weather
	weather.start()
	weather.wind_down()
	TEST_ASSERT(QDELETED(weather), "Weather without particles must finish immediately instead of waiting for a nonexistent fade timer.")
	TEST_ASSERT_NULL(SSParticleWeather.runningWeather, "Particle-free weather must not permanently block the next forecast.")

/datum/unit_test/particle_weather_replacement/Run()
	var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
	var/datum/particle_weather/stale = environment.start_weather(/datum/particle_weather/leaves_gentle)
	// Retain an old datum while another weather becomes the subsystem's owner.
	var/datum/particle_weather/fog/fog = environment.start_weather(/datum/particle_weather/fog)
	var/particles/weather/current_particles = SSParticleWeather.particleEffect
	var/datum/particle_weather/unused = environment.make_weather(/datum/particle_weather)
	for(var/datum/particle_weather/obsolete as anything in list(stale, unused))
		qdel(obsolete)
		if(SSParticleWeather.particleEffect != current_particles || QDELETED(current_particles))
			TEST_FAIL("Deleting stale or never-started weather must not delete the current fog's particles.")
		if(SSParticleWeather.weatherEffect.particles != current_particles)
			TEST_FAIL("Deleting unrelated weather must leave the current renderer attached.")
	SSParticleWeather.run_weather(/datum/particle_weather/rain_gentle, TRUE)
	environment.created_weather += SSParticleWeather.runningWeather
	environment.track_particles()
	environment.check_areas(src, "Forcing rain over active fog must restore the areas before replacement")
	TEST_ASSERT(QDELETED(fog), "Forced replacement must dispose of the previous fog.")
	TEST_ASSERT(istype(SSParticleWeather.runningWeather, /datum/particle_weather/rain_gentle), "The requested replacement weather must become active.")
	TEST_ASSERT(SSParticleWeather.particleEffect && !QDELETED(SSParticleWeather.particleEffect), "The replacement must retain its own live particles.")
	TEST_ASSERT_EQUAL(SSParticleWeather.weatherEffect.particles, SSParticleWeather.particleEffect, "The renderer must use the replacement's particles.")

/datum/unit_test/particle_weather_sand_destroy/Run()
	var/datum/particle_weather_test_environment/environment = allocate(/datum/particle_weather_test_environment)
	var/datum/particle_weather/sand_storm/storm = environment.start_weather(/datum/particle_weather/sand_storm)
	var/mob/living/recipient = allocate(/mob/living)
	storm.weather_sound_effect(recipient)
	var/datum/looping_sound/weather_sound = storm.currentSounds[recipient]
	TEST_ASSERT(weather_sound && !QDELETED(weather_sound), "The fixture must register a real sandstorm sound for its recipient.")
	// Avoid the random damage in weather_act; reproduce its trait source explicitly.
	ADD_TRAIT(recipient, TRAIT_SANDSTORMED, TRAIT_GENERIC)
	ADD_TRAIT(recipient, TRAIT_SANDSTORMED, TRAIT_SOURCE_UNIT_TESTS)
	qdel(storm)
	TEST_ASSERT(!HAS_TRAIT_FROM(recipient, TRAIT_SANDSTORMED, TRAIT_GENERIC), "Deleting a sandstorm directly must remove its effect from recipients without clients too.")
	TEST_ASSERT(HAS_TRAIT_FROM(recipient, TRAIT_SANDSTORMED, TRAIT_SOURCE_UNIT_TESTS), "Weather cleanup must preserve the same trait supplied by an independent source.")
	TEST_ASSERT(QDELETED(weather_sound), "Deleting the storm must dispose of its looping sound.")
