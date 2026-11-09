/// Apprenticeships survive ordinary death/revival but may not retain an actually deleted body.
/datum/unit_test/human_apprenticeship_cleanup/Run()
	var/mob/living/carbon/human/teacher = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/student = create_deleted_student(teacher)
	var/remaining_refs = refcount(student)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "The mentor must release the deleted student ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT_NULL(teacher.get_apprentice(), "A deleted apprentice must no longer occupy the mentor's body reference.")

/// End the interaction frame before measuring native references; BYOND retains field/call receivers.
/datum/unit_test/human_apprenticeship_cleanup/proc/create_deleted_student(mob/living/carbon/human/teacher)
	var/mob/living/carbon/human/consistent/student = new(run_loc_floor_bottom_left)
	teacher.set_apprentice(student)
	student.set_mentor(teacher)
	student.death()
	TEST_ASSERT_EQUAL(teacher.get_apprentice(), student, "An apprenticeship must survive the student's ordinary death.")
	TEST_ASSERT_EQUAL(student.get_mentor(), teacher, "A corpse must retain its mentor for revival.")
	student.revive(full_heal = TRUE)
	TEST_ASSERT_EQUAL(student.get_mentor(), teacher, "Revival must preserve the apprenticeship.")
	qdel(student)
	return student

/datum/unit_test/human_mentor_cleanup/Run()
	var/mob/living/carbon/human/student = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/teacher = create_deleted_teacher(student)
	var/remaining_refs = refcount(teacher)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "The apprentice must release the deleted mentor ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT_NULL(student.get_mentor(), "A deleted mentor must no longer be retained by the apprentice.")

/datum/unit_test/human_mentor_cleanup/proc/create_deleted_teacher(mob/living/carbon/human/student)
	var/mob/living/carbon/human/consistent/teacher = new(run_loc_floor_bottom_left)
	student.set_mentor(teacher)
	teacher.set_apprentice(student)
	qdel(teacher)
	return teacher

/// One skill holder may refer to the same body in both roles without losing either deletion subscription.
/datum/unit_test/human_apprenticeship_reassignment/Run()
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	holder.set_mentor(first)
	holder.set_apprentice(first)
	holder.set_mentor(second)
	qdel(first)
	TEST_ASSERT_EQUAL(holder.get_mentor(), second, "Deleting a replaced mentor must not clear the current mentor.")
	TEST_ASSERT_NULL(holder.get_apprentice(), "Removing one shared role must preserve deletion cleanup for the other.")
	holder.set_apprentice(second)
	holder.set_mentor(null)
	TEST_ASSERT_EQUAL(holder.get_apprentice(), second, "Explicitly removing a mentor must preserve the apprentice role.")
	qdel(second)
	TEST_ASSERT_NULL(holder.get_apprentice(), "The remaining shared role must still be cleaned on deletion.")

/// The skill holder follows the character's mind; destroying its former body must not delete it.
/datum/unit_test/human_apprenticeship_mind_transfer/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/teacher = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	old_body.set_mentor(teacher)
	var/datum/skill_holder/skills = old_body.skills
	old_body.mind.transfer_to(new_body)
	qdel(old_body)
	TEST_ASSERT(!QDELETED(skills), "Deleting a former body must preserve the transferred skills.")
	TEST_ASSERT_EQUAL(new_body.get_mentor(), teacher, "The transferred skill holder must keep its living mentor.")
	qdel(teacher)
	TEST_ASSERT_NULL(new_body.get_mentor(), "Transferred skills must still release a subsequently deleted mentor.")

/// A panel may outlive a dead character, but not the destruction of that character's body.
/datum/unit_test/human_examine_panel_cleanup
	var/datum/examine_panel/panel

/datum/unit_test/human_examine_panel_cleanup/Run()
	var/mob/living/carbon/human/subject = create_deleted_subject()
	var/remaining_refs = refcount(subject)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "An examine panel must release its deleted subject ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT(QDELETED(panel), "Deleting the subject must close its examine panel.")
	TEST_ASSERT_NULL(panel.holder, "A closed panel must release its subject.")

/datum/unit_test/human_examine_panel_cleanup/proc/create_deleted_subject()
	var/mob/living/carbon/human/consistent/subject = new(run_loc_floor_bottom_left)
	panel = new(subject)
	allocated += panel
	subject.death()
	TEST_ASSERT(!QDELETED(panel), "An ordinary corpse must still have a valid examine panel.")
	TEST_ASSERT_EQUAL(panel.holder, subject, "The panel must retain the existing corpse until actual deletion.")
	qdel(subject)
	return subject

/// Scalar identities verify actual collection without weakref.resolve() hiding qdeleted objects.
/datum/unit_test/human_relationship_native_gc/Run()
	var/list/identities = list()
	for(var/relationship in list("mentor", "apprentice", "examine"))
		identities[relationship] = create_deleted_subject(relationship)
	sleep(10 SECONDS)
	for(var/relationship in identities)
		TEST_ASSERT(!is_same_deleted_subject(identities[relationship]), "The [relationship] relationship must allow ordinary collection without a hard delete.")

/datum/unit_test/human_relationship_native_gc/proc/create_deleted_subject(relationship)
	var/mob/living/carbon/human/consistent/subject = new(run_loc_floor_bottom_left)
	if(relationship == "examine")
		var/datum/examine_panel/panel = new(subject)
		allocated += panel
	else
		var/mob/living/carbon/human/partner = allocate(/mob/living/carbon/human/consistent)
		if(relationship == "mentor")
			partner.set_mentor(subject)
		else
			partner.set_apprentice(subject)
	var/list/identity = list("reference" = text_ref(subject), "type" = subject.type)
	qdel(subject)
	identity["gc_destroyed"] = subject.gc_destroyed
	return identity

/datum/unit_test/human_relationship_native_gc/proc/is_same_deleted_subject(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]
