/datum/unit_test/speech_mannerisms/Run()
	for(var/mannerism in GLOB.character_mannerisms)
		if(mannerism == "No mannerism")
			continue
		for(var/section in list("full", "start", "end", "multiword", "syllable", "initial", "middle", "prefix", "repeat"))
			TEST_ASSERT(islist(get_mannerism_list_for_name(mannerism, section)), "[mannerism] must define [section], even when empty, to avoid runtimes while speaking.")
	TEST_ASSERT("Rhotacism" in GLOB.character_mannerisms, "Rhotacism must be selectable and survive preference validation.")
	TEST_ASSERT_EQUAL(apply_mannerism_preview("No mannerism", "Роза, ёж и рыцарь."), "Роза, ёж и рыцарь.", "No mannerism must preserve the original text.")
	TEST_ASSERT_EQUAL(apply_mannerism_preview("Lisp", "Сосна, ЗВОН, цапля! rose"), "Шошна, ЖВОН, чапля! rothe", "Lisp must preserve case and support mixed Russian/English speech.")
	TEST_ASSERT_EQUAL(apply_mannerism_preview("Rhotacism", "Рыжий рыцарь. РР! Red rose"), "Лыжий лыцаль. ЛЛ! Wed wose", "Rhotacism must replace both Latin and Cyrillic R, preserving case.")
	TEST_ASSERT_EQUAL(apply_mannerism_preview("Lisp", "рассказывает*Сосна и звон."), "рассказывает*Шошна и жвон.", "A custom speech verb must remain unchanged.")
	TEST_ASSERT_EQUAL(apply_mannerism_preview("Rhotacism", "рычит*Роза!"), "рычит*Лоза!", "Rhotacism must preserve a custom speech verb.")

	// Check the actual speech signal path as well as the preferences preview.
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human)
	speaker.char_accent = "No accent"
	for(var/mannerism in list("Lisp", "Rhotacism"))
		speaker.char_mannerism = mannerism
		var/list/speech_args = list()
		speech_args.len = SPEECH_MESSAGE
		speech_args[SPEECH_MESSAGE] = "Роза и рыцарь."
		speaker.dna.species.handle_speech(speaker, speech_args)
		TEST_ASSERT_EQUAL(speech_args[SPEECH_MESSAGE], mannerism == "Lisp" ? "Рожа и рычарь." : "Лоза и лыцаль.", "Live speech must apply the selected mannerism.")

	var/list/stutter_patterns = list(
		"Nervous Stutter" = "^(Привет|П-Привет)$",
		"Stutter" = "^(Привет|П-ривет|Пр-ивет|При-вет|Прив-ет)$",
		"Heavy Stutter" = "^(Привет|Пр-Пр-Привет)$",
	)
	var/list/english_patterns = list(
		"Nervous Stutter" = "^(Hello|H-Hello)$",
		"Stutter" = "^(Hello|H-ello|He-llo|Hel-lo)$",
		"Heavy Stutter" = "^(Hello|He-He-Hello)$",
	)
	for(var/mannerism in stutter_patterns)
		var/regex/cyrillic = regex(stutter_patterns[mannerism])
		var/regex/english = regex(english_patterns[mannerism])
		var/changed = FALSE
		// Exercise probabilistic effects repeatedly; every result must be intact text.
		for(var/attempt in 1 to 128)
			var/result = apply_mannerism_preview(mannerism, "Привет")
			TEST_ASSERT(cyrillic.Find(result), "[mannerism] split a Cyrillic character: [result]")
			changed |= result != "Привет"
			TEST_ASSERT(english.Find(apply_mannerism_preview(mannerism, "Hello")), "English stuttering must still work.")
			if(mannerism != "Nervous Stutter")
				TEST_ASSERT_EQUAL(apply_mannerism_preview(mannerism, "я ты ёж"), "я ты ёж", "Length limits must count characters, not UTF-8 bytes.")
		TEST_ASSERT(changed, "[mannerism] must actually affect Cyrillic speech.")
