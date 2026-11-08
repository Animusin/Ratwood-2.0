/// Ghosts may inspect the squid without entering human-only patron or stress logic.
/datum/unit_test/runtime_nov08_squid_observer/Run()
	var/obj/item/reagent_containers/food/snacks/fish/creepy_squid/squid = allocate(/obj/item/reagent_containers/food/snacks/fish/creepy_squid)
	var/mob/dead/observer/rogue/nodraw/observer = allocate(/mob/dead/observer/rogue/nodraw)
	var/runtimes_before = GLOB.total_runtimes
	var/list/description = squid.examine(observer)
	TEST_ASSERT(length(description), "A ghost must retain the ordinary item description.")
	TEST_ASSERT(!findtext(description.Join(), "As I behold the squid") && !findtext(description.Join(), "most beautiful creature"), "A ghost must not receive either human patron reaction.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Examining a squid as a ghost must not read a nonexistent patron.")

/// A patronless human still receives the ordinary frightening reaction.
/datum/unit_test/runtime_nov08_squid_patronless/Run()
	var/obj/item/reagent_containers/food/snacks/fish/creepy_squid/squid = allocate(/obj/item/reagent_containers/food/snacks/fish/creepy_squid)
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.patron = null
	var/runtimes_before = GLOB.total_runtimes
	var/list/description = squid.examine(human)
	TEST_ASSERT(findtext(description.Join(), "As I behold the squid"), "A susceptible human must still see the frightening vision.")
	TEST_ASSERT(human.has_stress_event(/datum/stressevent/creepy_squid), "The vision must still apply its stress event.")
	TEST_ASSERT(human.IsKnockdown(), "The frightening reaction must retain its knockdown.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A missing patron must not cause an examine runtime.")

/// Mood immunity suppresses the ordinary squid reaction.
/datum/unit_test/runtime_nov08_squid_mood_immunity/Run()
	var/obj/item/reagent_containers/food/snacks/fish/creepy_squid/squid = allocate(/obj/item/reagent_containers/food/snacks/fish/creepy_squid)
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.patron = new /datum/patron/divine/noc
	allocated += human.patron
	ADD_TRAIT(human, TRAIT_NOMOOD, "squid_test")
	var/list/description = squid.examine(human)
	TEST_ASSERT(!findtext(description.Join(), "As I behold the squid"), "Mood immunity must suppress the frightening vision.")
	TEST_ASSERT(!human.has_stress_event(/datum/stressevent/creepy_squid), "Mood immunity must prevent the squid's negative stress.")
	TEST_ASSERT(!human.IsKnockdown(), "An immune human must not be knocked down.")

/// Abyssor worshippers retain their distinct positive reaction, including mood-immune ones.
/datum/unit_test/runtime_nov08_squid_abyssor/Run()
	var/obj/item/reagent_containers/food/snacks/fish/creepy_squid/squid = allocate(/obj/item/reagent_containers/food/snacks/fish/creepy_squid)
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.patron = new /datum/patron/divine/abyssor
	allocated += human.patron
	for(var/mood_immune in list(FALSE, TRUE))
		if(mood_immune)
			ADD_TRAIT(human, TRAIT_NOMOOD, "squid_test")
		var/list/description = squid.examine(human)
		TEST_ASSERT(findtext(description.Join(), "most beautiful creature"), "Abyssor worshippers must retain their special description.")
		TEST_ASSERT(human.has_stress_event(/datum/stressevent/creepy_squid_happy), "Abyssor worshippers must retain their positive stress event.")
		TEST_ASSERT(!human.has_stress_event(/datum/stressevent/creepy_squid) && !human.IsKnockdown(), "Abyssor worshippers must not receive the frightening reaction.")
		human.remove_stress(/datum/stressevent/creepy_squid_happy)
