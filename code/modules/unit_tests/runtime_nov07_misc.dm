/// Stored language paths must remain usable even when the display name differs.
/datum/unit_test/runtime_nov07_language_paths/Run()
	var/datum/language_holder/holder = allocate(/datum/language_holder)
	holder.remove_all_languages()
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(holder.grant_language("/datum/language/otavan", source = "saved character"), "A stored Otavan path must grant its language.")
	TEST_ASSERT(holder.has_language(/datum/language/otavan), "A stored path must grant the actual language type.")
	TEST_ASSERT(holder.has_language("Otavais"), "The displayed language name must still resolve.")
	TEST_ASSERT(holder.grant_language("OTAVAIS", source = "equipment"), "Display names must support a second independent source.")
	TEST_ASSERT(!holder.remove_language("/datum/language/otavan", source = "saved character"), "Removing one source must preserve the other.")
	var/language_path = holder.get_random_understood_language()
	TEST_ASSERT_EQUAL(language_path, /datum/language/otavan, "Random speech must receive a type path, not stored text.")
	var/datum/language/language = GLOB.language_datum_instances[language_path]
	TEST_ASSERT_NOTNULL(language, "Random speech must resolve to a real language instance.")
	TEST_ASSERT(istext(language.scramble("A message from the test.")), "The selected language must be usable for speech scrambling.")
	TEST_ASSERT(holder.remove_language("Otavais", source = "equipment"), "Removing the final source must forget the language.")
	TEST_ASSERT(!holder.grant_language("not a language"), "Invalid language names must not poison the cache.")
	TEST_ASSERT(!holder.has_language("not a language"), "Invalid names must be safely rejected during lookup.")
	TEST_ASSERT(!holder.remove_language("not a language"), "Invalid names must be safely rejected during removal.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Stored language paths must not cause speech runtimes.")

/// Older holders may already contain a string key; random hallucinated speech must normalize it.
/datum/unit_test/runtime_nov07_legacy_language_speech/Run()
	var/datum/language_holder/holder = allocate(/datum/language_holder)
	holder.languages = list("/datum/language/otavan" = list(LANGUAGE_SOURCE_GENERIC))
	var/language_path = holder.get_random_understood_language()
	TEST_ASSERT_EQUAL(language_path, /datum/language/otavan, "A legacy string key must produce a valid language path.")
	TEST_ASSERT_NOTNULL(GLOB.language_datum_instances[language_path], "Legacy speech must resolve to an existing language instance.")

/// Starting the smoker must finish the same tick's bee calming and fuel consumption.
/datum/unit_test/runtime_nov07_bee_smoker/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bee_smoker/smoker = allocate(/obj/item/bee_smoker)
	var/obj/effect/bees/bees = allocate(/obj/effect/bees)
	bees.agitated = TRUE
	bees.agitation_countdown = 10
	bees.attacked_mobs += user
	var/fuel_before = smoker.fuel
	var/runtimes_before = GLOB.total_runtimes
	smoker.attack_self(user)
	TEST_ASSERT(smoker.active, "Lighting a fueled smoker must activate it.")
	TEST_ASSERT_EQUAL(smoker.fuel, fuel_before - 1, "The smoker must consume fuel after creating smoke.")
	TEST_ASSERT(!bees.agitated && !bees.agitation_countdown, "Smoke must calm nearby bees.")
	TEST_ASSERT(!length(bees.attacked_mobs), "Calmed bees must forget their attack targets.")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/particle_effect/smoke) in get_turf(smoker), "The smoker must still create visible smoke.")
	smoker.attack_self(user)
	TEST_ASSERT(!smoker.active, "The smoker must still be extinguishable.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Visual smoke must not be passed to the chemical smoke API.")

/// Hitscan endpoints can leave the map; valid beams must retain their ordinary rendering.
/datum/unit_test/runtime_nov07_tracer_endpoints/Run()
	var/datum/point/start = allocate(/datum/point)
	var/datum/point/end = allocate(/datum/point, run_loc_floor_top_right)
	var/runtimes_before = GLOB.total_runtimes
	end.x = (world.maxx + 2) * world.icon_size
	TEST_ASSERT_NULL(generate_tracer_between_points(start, end, /obj/effect/projectile/tracer/laser, "#ffffff"), "An off-map endpoint must not create a beam or invoke getline with null.")
	end = allocate(/datum/point, run_loc_floor_top_right)
	var/obj/effect/projectile/tracer/beam = generate_tracer_between_points(start, end, /obj/effect/projectile/tracer/laser, "#ffffff", qdel_in = 0)
	TEST_ASSERT_NOTNULL(beam, "A valid same-level beam must still be rendered.")
	allocated += beam
	TEST_ASSERT_NOTNULL(get_turf(beam), "A valid beam must have a map location.")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/projectile_lighting) in start.return_turf(), "A valid beam must retain its lighting.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Off-map tracer endpoints must not cause runtimes.")

/// Zephyr's trait must be applied as a trait rather than entering numeric stat calculations.
/datum/unit_test/runtime_nov07_zephyr_stats/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/advclass/janissary/zephyr/zephyr = new
	allocated += zephyr
	// Exercise class bonuses without the interactive equipment/character preference pickers.
	zephyr.outfit = null
	zephyr.applies_post_equipment = FALSE
	var/speed_before = human.STASPD
	var/perception_before = human.STAPER
	var/will_before = human.STAWIL
	var/runtimes_before = GLOB.total_runtimes
	zephyr.equipme(human)
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_DODGEEXPERT), "The Zephyr must receive its dodge trait.")
	TEST_ASSERT_EQUAL(human.STASPD, speed_before + 2, "The Zephyr must keep its speed bonus.")
	TEST_ASSERT_EQUAL(human.STAPER, perception_before + 2, "The Zephyr must keep its perception bonus.")
	TEST_ASSERT_EQUAL(human.STAWIL, will_before + 1, "The Zephyr must keep its will bonus.")
	for(var/stat in zephyr.subclass_stats)
		TEST_ASSERT(isnum(zephyr.subclass_stats[stat]), "Every bonus shown by the job explanation must be numeric.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Applying Zephyr bonuses must not treat a trait list as a stat.")
