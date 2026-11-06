/datum/unit_test/runtime_nov06_background_speech/Run()
	var/mob/living/carbon/human/consistent/speaker = allocate(/mob/living/carbon/human/consistent)
	speaker.grant_language(/datum/language/dwarvish)
	var/runtimes_before = GLOB.total_runtimes
	var/previous_usr = usr
	usr = 0
	var/rendered = speaker.compose_message(speaker, /datum/language/dwarvish, "A dwarvish warning.", null, list())
	usr = previous_usr
	TEST_ASSERT(findtext(rendered, "A dwarvish warning."), "Background speech must finish rendering its message.")
	TEST_ASSERT(!findtext(rendered, "lang_name="), "A clientless listener must not receive a link to an unrelated usr.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "NPC speech with usr=0 must not access 0.client.")

/obj/machinery/artificer_table/unit_test_nov06
	var/prompt_count = 0
	var/interrupt_on_prompt = 0
	var/obj/item/replacement
	var/delete_material = FALSE

/obj/machinery/artificer_table/unit_test_nov06/prompt_recipe_choice(mob/user, message, list/options)
	prompt_count++
	if(prompt_count == interrupt_on_prompt)
		var/obj/item/old_material = material
		material = replacement
		if(delete_material)
			qdel(old_material)
		else
			old_material.forceMove(get_turf(src))
	return options[1]

/datum/unit_test/runtime_nov06_artificer_menu/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	for(var/stage in 1 to 2)
		var/obj/machinery/artificer_table/unit_test_nov06/table = allocate(/obj/machinery/artificer_table/unit_test_nov06)
		var/obj/item/natural/wood/plank/workpiece = allocate(/obj/item/natural/wood/plank, table)
		table.material = workpiece
		table.interrupt_on_prompt = stage
		TEST_ASSERT(!table.choose_recipe(user), "Removing material during menu [stage] must cancel selection.")
		TEST_ASSERT_NULL(workpiece.artrecipe, "Removed material must not receive a recipe.")
		TEST_ASSERT_EQUAL(table.prompt_count, stage, "Selection must stop at the interrupted menu.")

	var/obj/machinery/artificer_table/unit_test_nov06/replaced_table = allocate(/obj/machinery/artificer_table/unit_test_nov06)
	var/obj/item/natural/wood/plank/original = allocate(/obj/item/natural/wood/plank, replaced_table)
	var/obj/item/natural/wood/plank/replacement = allocate(/obj/item/natural/wood/plank, replaced_table)
	replaced_table.material = original
	replaced_table.replacement = replacement
	replaced_table.interrupt_on_prompt = 2
	TEST_ASSERT(!replaced_table.choose_recipe(user), "Replacing material during the menu must cancel stale selection.")
	TEST_ASSERT_NULL(replacement.artrecipe, "The old menu must not change another workpiece.")
	replaced_table.prompt_count = 0
	replaced_table.delete_material = TRUE
	TEST_ASSERT(!replaced_table.choose_recipe(user), "Deleting material during the menu must cancel selection.")
	TEST_ASSERT(QDELETED(replacement), "The destruction fixture must actually consume its material.")

	var/obj/machinery/artificer_table/unit_test_nov06/ordinary = allocate(/obj/machinery/artificer_table/unit_test_nov06)
	var/obj/item/natural/wood/plank/live_material = allocate(/obj/item/natural/wood/plank, ordinary)
	ordinary.material = live_material
	TEST_ASSERT(ordinary.choose_recipe(user), "An uninterrupted choice must still assign a valid recipe.")
	TEST_ASSERT(istype(live_material.artrecipe, /datum/artificer_recipe), "The workpiece must retain its chosen recipe.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Artificer menus must tolerate removed, replaced and deleted materials.")
