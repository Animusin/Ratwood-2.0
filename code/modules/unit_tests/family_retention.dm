/// These fixtures keep complete genealogy graphs alive for assertions, then dismantle only their own graph.
/datum/unit_test/family_retention_fixture/Destroy()
	for(var/mob/living/carbon/human/body in allocated)
		qdel(body)
	for(var/datum/heritage/family in allocated)
		for(var/datum/family_member/member as anything in family.members)
			member.person = null
			member.family = null
			member.parents.Cut()
			member.children.Cut()
			member.spouses.Cut()
			member.former_spouses.Cut()
			qdel(member)
		family.members.Cut()
		family.founder = null
		for(var/body in family.family_icons)
			var/image/indicator = family.family_icons[body]
			indicator.loc = null
		family.family_icons.Cut()
	return ..()

/datum/unit_test/family_deleted_body_history
	parent_type = /datum/unit_test/family_retention_fixture

/// Removing a body must preserve the family record, name, relationships and portrait.
/datum/unit_test/family_deleted_body_history/Run()
	var/mob/living/carbon/human/consistent/father = new(run_loc_floor_bottom_left)
	father.real_name = "Retention Father"
	father.pronouns = HE_HIM
	var/mob/living/carbon/human/consistent/child = allocate(/mob/living/carbon/human/consistent)
	var/datum/heritage/family = new(father, "Retention")
	allocated += family
	var/datum/family_member/father_record = family.founder
	var/datum/family_member/child_record = family.CreateFamilyMember(child)
	child_record.AddParent(father_record)
	var/portrait = father_record.cloned_look
	father.real_name = "Renamed Father"
	qdel(father)
	TEST_ASSERT_NULL(father_record.person, "A historical family record must not retain a deleted body.")
	TEST_ASSERT(father_record in family.members, "Deleting the body must preserve its genealogical record.")
	TEST_ASSERT(father_record in child_record.parents, "Deleting a body must not sever parenthood.")
	TEST_ASSERT(child_record in father_record.children, "Deleting a body must preserve descendant links.")
	TEST_ASSERT_EQUAL(child_record.GetRelationshipTo(father_record), "father", "A deleted father's pronouns must remain available to family relationship labels.")
	TEST_ASSERT(findtext(family.FormatFamilyList(child), "Renamed Father"), "The family list must preserve the body's latest name after deletion.")
	TEST_ASSERT_EQUAL(father_record.cloned_look, portrait, "Deleting a body must preserve its saved family portrait.")
	TEST_ASSERT(!(father in family.family_icons), "The family icon registry must release the deleted body key.")

/datum/unit_test/family_spouse_body_lifecycle
	parent_type = /datum/unit_test/family_retention_fixture

/// Marriage and family icons survive ordinary death/revival and are released only with the body.
/datum/unit_test/family_spouse_body_lifecycle/Run()
	var/mob/living/carbon/human/consistent/first = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/datum/heritage/family = first.MarryTo(second)
	allocated += family
	first.marriedto = second.real_name
	second.marriedto = first.real_name
	var/remembered_name = second.marriedto
	var/datum/family_member/first_record = first.family_member_datum
	var/datum/family_member/second_record = second.family_member_datum
	second.spouse_indicator = image('icons/relations.dmi', first, "related")
	var/image/spouse_image = second.spouse_indicator
	var/image/family_image = family.family_icons[first]
	var/image/kept_image = family.family_icons[second]
	first.death()
	TEST_ASSERT(second.spouse_mob == first && first_record.person == first, "Ordinary death must preserve the spouse and family body for revival.")
	TEST_ASSERT(family.family_icons[first] == family_image, "A corpse must retain its family indicator.")
	first.revive(full_heal = TRUE, admin_revive = TRUE)
	TEST_ASSERT(second.spouse_mob == first, "Revival must preserve the spouse relationship.")
	qdel(first)
	TEST_ASSERT_NULL(second.spouse_mob, "A surviving spouse must release the removed body.")
	TEST_ASSERT_NULL(second.spouse_indicator, "A surviving spouse must release the removed body's indicator.")
	TEST_ASSERT_NULL(spouse_image.loc, "A retained spouse image must not retain the deleted body.")
	TEST_ASSERT_NULL(family_image.loc, "A retained family image must not retain the deleted body.")
	TEST_ASSERT_EQUAL(family.family_icons[second], kept_image, "Removing one body must preserve the other family indicators.")
	TEST_ASSERT(first_record in second_record.spouses, "Removing a body must preserve the marriage history.")
	TEST_ASSERT_EQUAL(second.marriedto, remembered_name, "Technical body cleanup must preserve remembered marriage metadata.")
	TEST_ASSERT(findtext(family.FormatFamilyList(second), remembered_name), "The spouse name used by family examination must survive body removal.")
	second.social_rank = SOCIAL_RANK_PEASANT
	var/runtimes_before = GLOB.total_runtimes
	world.PushUsr(second, CALLBACK(src, PROC_REF(read_social_rank), second))
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The real family/social-rank href must render with an archived spouse.")

/datum/unit_test/family_spouse_body_lifecycle/proc/read_social_rank(mob/living/carbon/human/subject)
	subject.Topic("", list("social_strata" = "1"))

/datum/unit_test/family_spouse_enemy_cleanup
	parent_type = /datum/unit_test/family_retention_fixture

/// Family listeners must not conflict with the same relative also being a combat enemy.
/datum/unit_test/family_spouse_enemy_cleanup/Run()
	var/mob/living/carbon/human/consistent/first = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/datum/heritage/family = first.MarryTo(second)
	allocated += family
	second.add_enemy(first)
	qdel(first)
	TEST_ASSERT_NULL(second.spouse_mob, "A spouse must be released even when also tracked as an enemy.")
	TEST_ASSERT(!(first in second.enemies), "Family cleanup must preserve enemy-list deletion cleanup.")

/// The surviving family, spouse and captured images stay alive during native collection.
/datum/unit_test/family_body_native_gc
	parent_type = /datum/unit_test/family_retention_fixture
	var/list/retained_images = list()

/datum/unit_test/family_body_native_gc/Run()
	var/list/identity = create_deleted_relative()
	sleep(10 SECONDS)
	TEST_ASSERT(!still_retained(identity), "A deleted spouse/family body must collect naturally without a hard delete.")
	retained_images.Cut()

/datum/unit_test/family_body_native_gc/proc/create_deleted_relative()
	var/mob/living/carbon/human/consistent/first = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/datum/heritage/family = first.MarryTo(second)
	allocated += family
	second.spouse_indicator = image('icons/relations.dmi', first, "related")
	retained_images += second.spouse_indicator
	retained_images += family.family_icons[first]
	var/list/identity = list("reference" = text_ref(first), "type" = first.type)
	qdel(first)
	identity["gc_destroyed"] = first.gc_destroyed
	return identity

/datum/unit_test/family_body_native_gc/proc/still_retained(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]

/datum/unit_test/family_matchmaking_retention
	var/list/saved_viable_spouses

/datum/unit_test/family_matchmaking_retention/Destroy()
	if(!isnull(saved_viable_spouses))
		SSfamilytree.viable_spouses = saved_viable_spouses
	return ..()

/datum/unit_test/family_matchmaking_retention/deletion/Run()
	saved_viable_spouses = SSfamilytree.viable_spouses
	SSfamilytree.viable_spouses = list()
	var/mob/living/carbon/human/consistent/candidate = new(run_loc_floor_bottom_left)
	SSfamilytree.AssignNewlyWed(candidate)
	TEST_ASSERT(candidate in SSfamilytree.viable_spouses, "An unmatched character must remain available to matchmaking.")
	candidate.death()
	TEST_ASSERT(candidate in SSfamilytree.viable_spouses, "Death must preserve an unmatched character for possible revival.")
	qdel(candidate)
	var/remaining_refs = refcount(candidate)
	TEST_ASSERT(!(candidate in SSfamilytree.viable_spouses), "Matchmaking must release a deleted candidate without waiting for a new entrant.")
	TEST_ASSERT(remaining_refs <= baseline_refs(), "An idle matchmaking list must not retain a deleted human ([remaining_refs] references; baseline [baseline_refs()]).")

/datum/unit_test/family_matchmaking_retention/native_gc/Run()
	saved_viable_spouses = SSfamilytree.viable_spouses
	SSfamilytree.viable_spouses = list()
	var/list/identity = create_deleted_candidate()
	sleep(10 SECONDS)
	TEST_ASSERT(!still_retained(identity), "An unmatched candidate must collect naturally even when nobody else joins matchmaking.")

/datum/unit_test/family_matchmaking_retention/native_gc/proc/create_deleted_candidate()
	var/mob/living/carbon/human/consistent/candidate = new(run_loc_floor_bottom_left)
	SSfamilytree.AssignNewlyWed(candidate)
	var/list/identity = list("reference" = text_ref(candidate), "type" = candidate.type)
	qdel(candidate)
	identity["gc_destroyed"] = candidate.gc_destroyed
	return identity

/datum/unit_test/family_matchmaking_retention/native_gc/proc/still_retained(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]

/// Exercise the real family subsystem while restoring its round-wide state even if an assertion fails.
/datum/unit_test/family_archive_operations
	parent_type = /datum/unit_test/family_retention_fixture
	var/datum/heritage/saved_ruling_family
	var/list/saved_families
	var/replaced_familytree = FALSE

/datum/unit_test/family_archive_operations/proc/use_family(datum/heritage/family)
	saved_ruling_family = SSfamilytree.ruling_family
	saved_families = SSfamilytree.families
	replaced_familytree = TRUE
	SSfamilytree.ruling_family = family
	SSfamilytree.families = list(family)

/datum/unit_test/family_archive_operations/Destroy()
	if(replaced_familytree)
		SSfamilytree.ruling_family = saved_ruling_family
		SSfamilytree.families = saved_families
	return ..()

/// Validation must preserve archived relatives on both sides of a live person's relationships.
/datum/unit_test/family_archive_operations/validation/Run()
	var/mob/living/carbon/human/consistent/father = new(run_loc_floor_bottom_left)
	father.real_name = "Archived Father"
	father.pronouns = HE_HIM
	var/mob/living/carbon/human/consistent/grandmother = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/child = allocate(/mob/living/carbon/human/consistent)
	var/datum/heritage/family = new(father, "Archive")
	allocated += family
	var/datum/family_member/father_record = family.founder
	var/datum/family_member/grandmother_record = family.CreateFamilyMember(grandmother)
	var/datum/family_member/child_record = family.CreateFamilyMember(child)
	father_record.AddParent(grandmother_record)
	child_record.AddParent(father_record)
	qdel(father)
	TEST_ASSERT_NULL(family.GetFamilyMember(null), "A missing body must not resolve to an unrelated archived relative.")
	TEST_ASSERT_NULL(family.GetMemberForPerson(null), "A global family list must not invent an archived viewer.")
	var/runtimes_before = GLOB.total_runtimes
	SSfamilytree.ValidateFamily(family)
	TEST_ASSERT(father_record in family.members, "Validation must preserve a deliberately archived family member.")
	TEST_ASSERT((father_record in child_record.parents) && (child_record in father_record.children), "Validation must preserve an archived parent's reciprocal descendant links.")
	TEST_ASSERT((father_record in grandmother_record.children) && (grandmother_record in father_record.parents), "Validation must preserve an archived child's reciprocal ancestor links.")
	TEST_ASSERT_EQUAL(child_record.GetRelationshipTo(father_record), "father", "Validated archived relatives must retain their relationship labels.")
	TEST_ASSERT(findtext(family.FormatFamilyList(child), "Archived Father"), "Validated family UI must retain the historical name.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Archived family validation and rendering must not runtime.")

/// A removed monarch must not prevent a later royal from finding the remaining monarch.
/datum/unit_test/family_archive_operations/royal_assignment/Run()
	var/mob/living/carbon/human/consistent/removed_monarch = new(run_loc_floor_bottom_left)
	removed_monarch.job = "Grand Duke"
	var/datum/heritage/family = new(removed_monarch, "Archive Royals")
	allocated += family
	var/datum/family_member/removed_record = family.founder
	removed_record.generation = 12
	var/mob/living/carbon/human/consistent/remaining_monarch = allocate(/mob/living/carbon/human/consistent)
	remaining_monarch.job = "Grand Duchess"
	var/datum/family_member/remaining_record = family.CreateFamilyMember(remaining_monarch)
	remaining_record.generation = 12
	use_family(family)
	qdel(removed_monarch)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(SSfamilytree.GetCurrentMonarch(), remaining_record, "A deleted royal body must be skipped when selecting a current monarch.")
	var/mob/living/carbon/human/consistent/progeny = allocate(/mob/living/carbon/human/consistent)
	SSfamilytree.AddRoyal(progeny, FAMILY_PROGENY)
	TEST_ASSERT(remaining_record in progeny.family_member_datum.parents, "A later royal must still be assigned to the existing monarch.")
	TEST_ASSERT(removed_record in family.members, "Royal assignment must not erase the archived monarch.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Selecting and assigning royals after a body removal must not runtime.")

/// Archived parents cannot supply the live age-based candidate for a new aunt or uncle.
/datum/unit_test/family_archive_operations/aunt_assignment/Run()
	var/mob/living/carbon/human/consistent/removed_parent = new(run_loc_floor_bottom_left)
	removed_parent.age = AGE_MIDDLEAGED
	var/datum/heritage/family = new(removed_parent, "Archive Parents")
	allocated += family
	var/datum/family_member/removed_record = family.founder
	var/mob/living/carbon/human/consistent/child = allocate(/mob/living/carbon/human/consistent)
	child.age = AGE_ADULT
	var/datum/family_member/child_record = family.CreateFamilyMember(child)
	child_record.AddParent(removed_record)
	use_family(family)
	qdel(removed_parent)
	var/mob/living/carbon/human/consistent/new_relative = allocate(/mob/living/carbon/human/consistent)
	new_relative.age = AGE_MIDDLEAGED
	var/runtimes_before = GLOB.total_runtimes
	SSfamilytree.AssignAuntUncle(new_relative)
	TEST_ASSERT_NULL(new_relative.family_member_datum, "A house with only an archived parent must not select that parent as a live age-based match.")
	TEST_ASSERT(removed_record in child_record.parents, "Skipping an archived candidate must preserve the child's parent history.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Aunt/uncle assignment must not dereference an archived parent's missing body.")

/// New siblings can share historical parent records without trying to read their removed DNA.
/datum/unit_test/family_archive_operations/sibling_assignment/Run()
	var/mob/living/carbon/human/consistent/father = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/mother = new(run_loc_floor_bottom_left)
	var/datum/heritage/family = new(father, "Archive Siblings")
	allocated += family
	var/datum/family_member/father_record = family.founder
	var/datum/family_member/mother_record = family.CreateFamilyMember(mother)
	var/mob/living/carbon/human/consistent/child = allocate(/mob/living/carbon/human/consistent)
	child.age = AGE_ADULT
	var/datum/family_member/child_record = family.CreateFamilyMember(child)
	child_record.AddParent(father_record)
	child_record.AddParent(mother_record)
	qdel(father)
	qdel(mother)
	var/mob/living/carbon/human/consistent/sibling = allocate(/mob/living/carbon/human/consistent)
	sibling.age = AGE_ADULT
	var/runtimes_before = GLOB.total_runtimes
	SSfamilytree.AddPersonToHouse(family, sibling)
	TEST_ASSERT(sibling.family_member_datum, "A live sibling match must still create the newcomer's family record.")
	TEST_ASSERT((father_record in sibling.family_member_datum.parents) && (mother_record in sibling.family_member_datum.parents), "Siblings must share the historical parents even after their bodies are removed.")
	TEST_ASSERT(sibling.family_member_datum.AreSiblings(child_record), "Historical parents must remain usable by relationship lookup.")
	father_record.AddSpouse(mother_record)
	TEST_ASSERT(father_record in mother_record.spouses, "Archived relationship updates must remain valid without parent DNA.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Sharing archived parents and updating their shared children must not runtime.")
