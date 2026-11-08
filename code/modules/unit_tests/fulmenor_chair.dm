/// Replace only the player dialog; revival, buckling, resources, and sparks remain real.
/obj/structure/chair/frankenstein/unit_test_fulmenor
	var/mob/living/carbon/human/operator
	var/mob/living/carbon/human/patient
	var/obj/structure/chair/other_chair
	var/turf/operator_destination
	var/consent = TRUE
	var/consent_action
	var/prompt_count = 0
	var/effect_count = 0

/obj/structure/chair/frankenstein/unit_test_fulmenor/Destroy()
	operator = null
	patient = null
	other_chair = null
	operator_destination = null
	return ..()

/obj/structure/chair/frankenstein/unit_test_fulmenor/confirm_reanimation(mob/living/occupant)
	prompt_count++
	var/action = consent_action
	consent_action = null
	switch(action)
		if("nested_click")
			MiddleClick(operator)
		if("other_chair")
			unbuckle_mob(occupant, TRUE)
			other_chair.buckle_mob(occupant, TRUE, FALSE)
		if("operator_left")
			operator.forceMove(operator_destination)
		if("necra_vow")
			ADD_TRAIT(occupant, TRAIT_NECRAS_VOW, "fulmenor_test")
		if("delete_patient")
			qdel(occupant)
	return consent

/obj/structure/chair/frankenstein/unit_test_fulmenor/reanimation_effects(mob/living/occupant)
	effect_count++
	return ..()

/datum/unit_test/proc/allocate_fulmenor_fixture()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate(/obj/structure/chair/frankenstein/unit_test_fulmenor)
	chair.operator = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	chair.operator.adjust_skillrank_up_to(/datum/skill/misc/medicine, SKILL_LEVEL_MASTER, TRUE)
	chair.patient = allocate(/mob/living/carbon/human/consistent)
	chair.patient.mind_initialize()
	allocated += chair.patient.mind
	// Keep the real revival and debuff, while excluding the separate shock damage mechanic.
	ADD_TRAIT(chair.patient, TRAIT_SHOCKIMMUNE, "fulmenor_test")
	chair.patient.death(FALSE, TRUE)
	chair.patient.mind.active = TRUE
	chair.buckle_mob(chair.patient, TRUE, FALSE)
	chair.charge = chair.max_charge
	chair.current_brew = chair.max_brew
	chair.update_icon()
	return chair

/datum/unit_test/fulmenor_human_revival/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	TEST_ASSERT(chair.patient.buckled == chair && chair.patient.check_revive(chair.operator) && chair.patient.can_be_revived(), "The fixture must be a genuinely revivable corpse buckled to this chair.")
	var/runtimes_before = GLOB.total_runtimes
	chair.MiddleClick(chair.operator)
	TEST_ASSERT(chair.patient.stat != DEAD, "A consenting, intact patient must be revived.")
	TEST_ASSERT(chair.patient.has_status_effect(/datum/status_effect/debuff/revived), "Successful revival must apply the actual revived status datum.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew - chair.brew_required, "A successful ordinary revival must consume one dose of fluid.")
	TEST_ASSERT_EQUAL(chair.charge, 0, "A successful revival must consume the charge.")
	TEST_ASSERT_EQUAL(chair.prompt_count, 1, "The patient must receive one consent prompt.")
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "Successful revival must emit one discharge.")
	chair.MiddleClick(chair.operator)
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "Clicking a spent chair must not repeat its effects.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew - chair.brew_required, "Clicking a spent chair must not consume another dose.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Successful revival must finish without a status-effect runtime.")

/datum/unit_test/fulmenor_failed_revival/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	var/obj/item/bodypart/head = chair.patient.get_bodypart(BODY_ZONE_HEAD)
	head.rotted = TRUE
	TEST_ASSERT(chair.patient.check_revive(chair.operator), "A present but rotted head must reach the actual revival attempt.")
	TEST_ASSERT(!chair.patient.can_be_revived(), "The rotted head must prevent actual revival.")
	var/runtimes_before = GLOB.total_runtimes
	for(var/attempt in 1 to 10)
		chair.MiddleClick(chair.operator)
	TEST_ASSERT_EQUAL(chair.patient.stat, DEAD, "Repeated attempts must not revive an irreparable corpse.")
	TEST_ASSERT_EQUAL(chair.effect_count, 0, "Failed revival must not produce repeatable eight-spark discharges.")
	TEST_ASSERT_EQUAL(chair.charge, chair.max_charge, "Failed revival must preserve the charge.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew, "Failed revival must preserve the fluid.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Failed revival must not cause runtimes.")

/datum/unit_test/fulmenor_pending_consent/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	chair.consent_action = "nested_click"
	var/runtimes_before = GLOB.total_runtimes
	chair.MiddleClick(chair.operator)
	TEST_ASSERT_EQUAL(chair.prompt_count, 2, "A pending consent prompt must not prevent a later attempt from completing.")
	TEST_ASSERT(chair.patient.stat != DEAD, "The nested accepted attempt must revive the patient.")
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "Returning from the older consent prompt must not duplicate the completed discharge.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew - chair.brew_required, "Returning from an older prompt must not consume a second dose.")
	TEST_ASSERT_EQUAL(chair.charge, 0, "The completed nested revival must consume its charge.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Returning stale consent after a completed revival must not cause runtimes.")

/datum/unit_test/fulmenor_cancelled_consent/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	chair.consent = FALSE
	chair.MiddleClick(chair.operator)
	TEST_ASSERT_EQUAL(chair.patient.stat, DEAD, "Refusing consent must leave the patient dead.")
	TEST_ASSERT_EQUAL(chair.effect_count, 0, "Refusing consent must not emit a discharge.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew, "Refusing consent must not consume fluid.")
	TEST_ASSERT_EQUAL(chair.charge, chair.max_charge, "Refusing consent must not consume charge.")
	chair.consent = TRUE
	chair.MiddleClick(chair.operator)
	TEST_ASSERT(chair.patient.stat != DEAD, "The patient must be able to accept a later attempt.")
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "Only the accepted retry must discharge.")

/datum/unit_test/fulmenor_stale_consent/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	chair.other_chair = allocate(/obj/structure/chair)
	chair.operator_destination = get_step(get_step(run_loc_floor_bottom_left, NORTH), NORTH)
	var/runtimes_before = GLOB.total_runtimes
	for(var/action in list("other_chair", "operator_left", "necra_vow"))
		chair.consent_action = action
		chair.MiddleClick(chair.operator)
		TEST_ASSERT_EQUAL(chair.patient.stat, DEAD, "Stale consent ([action]) must not revive the patient.")
		TEST_ASSERT_EQUAL(chair.effect_count, 0, "Stale consent ([action]) must not discharge.")
		TEST_ASSERT_EQUAL(chair.charge, chair.max_charge, "Stale consent ([action]) must preserve charge.")
		TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew, "Stale consent ([action]) must preserve fluid.")
		chair.other_chair.unbuckle_mob(chair.patient, TRUE)
		if(!chair.patient.buckled)
			chair.buckle_mob(chair.patient, TRUE, FALSE)
		chair.operator.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
		REMOVE_TRAIT(chair.patient, TRAIT_NECRAS_VOW, "fulmenor_test")
	chair.MiddleClick(chair.operator)
	TEST_ASSERT(chair.patient.stat != DEAD, "Correcting the stale conditions must allow a new attempt.")
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "Only the final valid attempt must discharge.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Stale consent must not cause runtimes.")

/datum/unit_test/fulmenor_deleted_patient/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	chair.consent_action = "delete_patient"
	var/runtimes_before = GLOB.total_runtimes
	chair.MiddleClick(chair.operator)
	TEST_ASSERT(QDELETED(chair.patient), "The dialog fixture must delete its original patient.")
	TEST_ASSERT_EQUAL(chair.effect_count, 0, "A deleted patient must not receive a discharge.")
	TEST_ASSERT_EQUAL(chair.charge, chair.max_charge, "A deleted patient must not consume charge.")
	TEST_ASSERT_EQUAL(chair.current_brew, chair.max_brew, "A deleted patient must not consume fluid.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A deleted patient must not be dereferenced after consent.")

/datum/unit_test/fulmenor_spark_cleanup/Run()
	var/obj/structure/chair/frankenstein/unit_test_fulmenor/chair = allocate_fulmenor_fixture()
	var/list/spark_refs = list()
	// Earlier tests may still have moving sparks just outside their cleanup area.
	var/list/existing_sparks = list()
	for(var/obj/effect/particle_effect/sparks/spark in range(3, chair))
		existing_sparks[REF(spark)] = TRUE
	var/runtimes_before = GLOB.total_runtimes
	chair.MiddleClick(chair.operator)
	for(var/obj/effect/particle_effect/sparks/spark in range(3, chair))
		if(!existing_sparks[REF(spark)])
			spark_refs += WEAKREF(spark)
	TEST_ASSERT_EQUAL(length(spark_refs), 8, "One successful discharge must create its eight real sparks.")
	sleep(4 SECONDS)
	for(var/datum/weakref/spark_ref as anything in spark_refs)
		TEST_ASSERT_NULL(spark_ref.resolve(), "Each discharge spark must expire without manual cleanup.")
	TEST_ASSERT_EQUAL(chair.effect_count, 1, "A discharged chair must not continuously generate more effects.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The spark movement and timed cleanup must finish without runtimes.")
