/// A ghost keeps a character through death and body changes, but must release a deleted mind.
/datum/unit_test/mind_observer_deletion/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	var/mob/dead/observer/ghost = new(body)
	allocated += ghost
	TEST_ASSERT(ghost.mind == character, "Creating an observer must preserve its character association.")

	qdel(character)

	var/remaining_refs = refcount(character)
	TEST_ASSERT_NULL(ghost.mind, "An observer must release a mind when that mind is deleted.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "An observer must not retain a deleted mind ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT(!QDELETED(ghost), "Deleting the character must not delete its observer.")

/// Body death, revival and transfer must not be mistaken for deletion of the character.
/datum/unit_test/mind_observer_body_lifecycle/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/replacement = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	body.death()
	var/mob/dead/observer/ghost = new(body)
	allocated += ghost
	TEST_ASSERT(ghost.mind == character && character.current == body, "The observer must retain its dead character for revival.")
	body.revive(full_heal = TRUE, admin_revive = TRUE)
	TEST_ASSERT(ghost.mind == character && character.current == body, "Revival must preserve the observer's character association.")
	character.transfer_to(replacement)
	TEST_ASSERT(ghost.mind == character && ghost.mind.current == replacement, "The observer must follow the character to its replacement body.")
	qdel(body)
	TEST_ASSERT(ghost.mind == character && !QDELETED(character), "Deleting a former body must preserve the transferred character.")
	qdel(ghost)
	TEST_ASSERT(!QDELETED(character) && character.current == replacement, "Deleting an observer must preserve its living character.")
	qdel(character)

/// Teams must retain living and dead members, but never a mind that has actually been destroyed.
/datum/unit_test/mind_team_deletion/Run()
	var/datum/team/team = new
	allocated += team
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	team.add_member(character)
	team.add_member(character)
	TEST_ASSERT_EQUAL(length(team.members), 1, "Adding the same character twice must not duplicate team membership.")
	body.death()
	TEST_ASSERT(character in team.members, "A dead character must remain a team member for revival and round-end reporting.")

	qdel(character)

	var/remaining_refs = refcount(character)
	TEST_ASSERT(!(character in team.members), "A team must release a destroyed character.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "Team membership must not retain a deleted mind ([remaining_refs] references; baseline [baseline_refs()]).")

/// Leaving or deleting a team must not delete any member, or leave the team holding it.
/datum/unit_test/mind_team_removal/Run()
	var/datum/team/team = new
	var/datum/mind/removed = new
	var/datum/mind/kept = new
	team.add_member(removed)
	team.add_member(kept)
	team.remove_member(removed)
	qdel(removed)
	var/remaining_refs = refcount(removed)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "A former team member must be released after removal.")
	TEST_ASSERT(kept in team.members, "Removing one character must preserve the other member.")
	qdel(team)
	TEST_ASSERT_EQUAL(length(team.members), 0, "Deleting a team must release its member list.")
	TEST_ASSERT(!QDELETED(kept), "Deleting a team must preserve its former members.")
	qdel(kept)

/// Exercise normal target selection without depending on other characters in the test manifest.
/datum/objective/assassinate/mind_retention_fixture
	var/list/candidates = list()

/datum/objective/assassinate/mind_retention_fixture/get_crewmember_minds()
	return candidates.Copy()

/datum/unit_test/mind_objective_target_deletion/Run()
	var/datum/objective/assassinate/mind_retention_fixture/objective = allocate(/datum/objective/assassinate/mind_retention_fixture)
	var/datum/mind/character = create_dead_target(objective)
	TEST_ASSERT_NOTNULL(character, "The fixture must create a character for target cleanup.")
	var/explanation_before = objective.explanation_text
	qdel(character)
	var/remaining_refs = refcount(character)
	TEST_ASSERT_NULL(objective.target, "An objective must release a deleted target mind.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "Another character's objective must not retain a deleted mind ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT_EQUAL(objective.explanation_text, explanation_before, "Deleting a target must preserve the objective's historical description.")
	TEST_ASSERT(objective.check_completion(), "An assassinated character that no longer exists must remain a completed objective.")

/// End the selection frame: find_target() returns the mind and BYOND may retain that temporary.
/datum/unit_test/mind_objective_target_deletion/proc/create_dead_target(datum/objective/assassinate/mind_retention_fixture/objective)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	objective.candidates += character
	objective.find_target()
	objective.candidates.Cut()
	TEST_ASSERT(objective.target == character, "Normal objective selection must find the fixture character.")
	body.death()
	TEST_ASSERT(objective.target == character, "Death alone must preserve the objective target for possible revival.")
	return character

/// Replacing an objective target must detach only the old target's deletion subscription.
/datum/unit_test/mind_objective_target_reassignment/Run()
	var/datum/objective/assassinate/mind_retention_fixture/objective = allocate(/datum/objective/assassinate/mind_retention_fixture)
	var/mob/living/carbon/human/consistent/first_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second_body = allocate(/mob/living/carbon/human/consistent)
	first_body.mind_initialize()
	second_body.mind_initialize()
	var/datum/mind/first = first_body.mind
	var/datum/mind/second = second_body.mind
	objective.candidates += first
	objective.find_target()
	objective.candidates.Cut()
	objective.candidates += second
	objective.find_target()
	objective.candidates.Cut()
	qdel(first)
	var/remaining_refs = refcount(first)
	TEST_ASSERT(objective.target == second, "Deleting an earlier target must preserve the replacement target.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "Reassignment must release the old target's references.")
	qdel(objective)
	TEST_ASSERT(!QDELETED(second), "Deleting an objective must preserve the character it targeted.")
	qdel(second)

/// Keep the observer/team/objective alive while the normal garbage queue collects their former mind.
/datum/unit_test/mind_borrower_native_gc/Run()
	var/list/identities = list()
	for(var/borrower in list("observer", "team", "objective"))
		identities[borrower] = create_deleted_character(borrower)
	sleep(10 SECONDS)
	for(var/borrower in identities)
		TEST_ASSERT(!still_retained(identities[borrower]), "A mind formerly referenced by [borrower] must collect naturally without a hard delete.")

/datum/unit_test/mind_borrower_native_gc/proc/create_deleted_character(borrower)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	var/datum/mind/character = body.mind
	switch(borrower)
		if("observer")
			var/mob/dead/observer/ghost = new(body)
			allocated += ghost
		if("team")
			var/datum/team/team = new
			allocated += team
			team.add_member(character)
		if("objective")
			var/datum/objective/assassinate/mind_retention_fixture/objective = allocate(/datum/objective/assassinate/mind_retention_fixture)
			objective.candidates += character
			objective.find_target()
			objective.candidates.Cut()
	var/list/identity = list("reference" = text_ref(character), "type" = character.type)
	qdel(character)
	identity["gc_destroyed"] = character.gc_destroyed
	return identity

/// Raw ref IDs can be reused after collection; do not mistake a replacement for the deleted character.
/datum/unit_test/mind_borrower_native_gc/proc/still_retained(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]
