/// Personal objectives must be destroyed while their owner's body is still available to their cleanup hooks.
/datum/unit_test/performance_mind_objectives/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	var/datum/objective/hug_beggar/hug = new(null, character)
	character.add_personal_objective(hug)
	var/datum/objective/second = new(null, character)
	character.add_personal_objective(second)
	var/datum/objective/third = new(null, character)
	character.add_personal_objective(third)
	var/runtimes_before = GLOB.total_runtimes

	qdel(character)

	TEST_ASSERT(QDELETED(hug) && QDELETED(second) && QDELETED(third), "Deleting a mind must destroy every personal objective, including objectives with body signal handlers.")
	TEST_ASSERT_NULL(body.mind, "The body must release its deleted mind.")
	TEST_ASSERT_NULL(hug.owner, "The removed objective must not retain the deleted mind.")
	// Check before reading character's lists: BYOND can retain their container as a temporary expression reference.
	TEST_ASSERT(refcount(character) <= baseline_refs(), "An objective must not force its deleted owner into a hard delete ([refcount(character)] references; baseline [baseline_refs()]).")
	TEST_ASSERT_EQUAL(length(character.personal_objectives), 0, "Deleted objectives must leave the owner's list.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Objective cleanup must run before the owner loses its body.")

/// Deleting one objective must leave the other objectives and the live mind intact.
/datum/unit_test/performance_personal_objective_removal/Run()
	var/datum/mind/character = allocate(/datum/mind, "performance_objective_owner")
	var/datum/mind/target = allocate(/datum/mind, "performance_objective_target")
	var/datum/objective/removed = new(null, character)
	removed.target = target
	character.add_personal_objective(removed)
	var/datum/objective/kept = new(null, character)
	character.add_personal_objective(kept)

	qdel(removed)

	TEST_ASSERT(!(removed in character.personal_objectives), "A deleted objective must leave its live owner's list.")
	TEST_ASSERT(kept in character.personal_objectives, "Removing one objective must retain the other objective.")
	TEST_ASSERT(!QDELETED(character) && !QDELETED(target) && !QDELETED(kept), "Objective destruction must not delete borrowed minds or other objectives.")
	TEST_ASSERT_NULL(removed.owner, "A deleted objective must release its owner.")
	TEST_ASSERT_NULL(removed.target, "A deleted objective must release its target.")
	character.clear_personal_objectives()
	TEST_ASSERT(QDELETED(kept), "Clearing objectives must still delete the remaining objective.")
	TEST_ASSERT(!QDELETED(character), "Clearing personal objectives must preserve the character.")

/// Several roles on one mind must all be removed even though role destruction edits the owner's list.
/datum/unit_test/performance_mind_antagonists/Run()
	var/datum/mind/character = new
	var/datum/antagonist/first = new
	var/datum/antagonist/second = new
	var/datum/antagonist/third = new
	first.owner = character
	second.owner = character
	third.owner = character
	character.antag_datums = list(first, second, third)
	var/runtimes_before = GLOB.total_runtimes

	qdel(character)

	TEST_ASSERT(QDELETED(first) && QDELETED(second) && QDELETED(third), "Deleting a mind must delete every attached antagonist datum.")
	TEST_ASSERT(!(first in GLOB.antagonists) && !(second in GLOB.antagonists) && !(third in GLOB.antagonists), "Destroyed roles must leave the global antagonist registry.")
	TEST_ASSERT(refcount(character) <= baseline_refs(), "An attached antagonist must not retain a deleted mind.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Deleting multiple antagonist roles must not invalidate the destruction iterator.")

/// Manifest records must retain live characters for target selection, then release only the deleted character reference.
/datum/unit_test/performance_manifest_mind_cleanup/Run()
	var/datum/mind/character = new
	var/datum/data/record/record = new
	allocated += record
	record.fields["name"] = "Performance manifest fixture"
	record.set_mind_ref(character)
	GLOB.data_core.locked += record
	var/datum/objective/objective = allocate(/datum/objective, "Performance manifest fixture")
	var/list/targets = objective.get_crewmember_minds()
	TEST_ASSERT(character in targets, "A live manifest mind must remain available to objective targeting.")
	targets.Cut()

	qdel(character)

	TEST_ASSERT_NULL(record.fields["mindref"], "A permanent manifest must release a deleted mind.")
	TEST_ASSERT_EQUAL(record.fields["name"], "Performance manifest fixture", "Mind deletion must preserve the historical manifest data.")
	TEST_ASSERT(record in GLOB.data_core.locked, "Mind deletion must not erase the manifest record.")
	TEST_ASSERT(refcount(character) <= baseline_refs(), "The manifest must not force its deleted mind into a hard delete.")
	targets = objective.get_crewmember_minds()
	TEST_ASSERT(!(character in targets), "Deleted minds must no longer be offered as objective targets.")

/// Reassigning or deleting a record must not leave deletion listeners attached to an earlier mind.
/datum/unit_test/performance_manifest_reassignment/Run()
	var/datum/mind/first = new
	var/datum/mind/second = allocate(/datum/mind, "performance_manifest_replacement")
	var/datum/data/record/record = new
	allocated += record
	record.set_mind_ref(first)
	record.set_mind_ref(second)
	qdel(first)
	TEST_ASSERT_EQUAL(record.fields["mindref"], second, "Deleting an old mind must not clear the record's new mind.")
	TEST_ASSERT(refcount(first) <= baseline_refs(), "Replacing a record's mind must release the old mind.")
	qdel(record)
	TEST_ASSERT_EQUAL(length(record.fields), 0, "Deleting a record must release its stored references immediately.")
	TEST_ASSERT(!QDELETED(second), "Deleting a record must preserve the live character it described.")
