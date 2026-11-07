/// Repeated contact must record the same evidence without manufacturing disposable components.
/datum/unit_test/performance_forensics_contacts/Run()
	var/obj/item/performance_forensics_probe/evidence = allocate(/obj/item/performance_forensics_probe)
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	evidence.add_fingerprint(subject)
	var/datum/component/forensics/forensics = evidence.GetComponent(/datum/component/forensics)
	var/datum/qdel_item/trash = SSgarbage.items[/datum/component/forensics]
	var/deletions_before = trash ? trash.qdels : 0
	evidence.blood_count_calls = 0
	for(var/i in 1 to 1000)
		evidence.add_fingerprint(subject)
	trash = SSgarbage.items[/datum/component/forensics]
	var/deletions_after = trash ? trash.qdels : 0
	TEST_ASSERT_EQUAL(deletions_after, deletions_before, "Repeated touches must not create and delete duplicate forensic components.")
	TEST_ASSERT_EQUAL(evidence.blood_count_calls, 0, "Clean contacts must not count blood samples or scan turf decals.")
	TEST_ASSERT_EQUAL(evidence.GetComponent(/datum/component/forensics), forensics, "Repeated contact must preserve the evidence component.")
	TEST_ASSERT(md5(subject.dna.uni_identity) in evidence.return_fingerprints(), "Optimized contact must still record fingerprints.")

/obj/item/performance_forensics_probe
	var/blood_count_calls = 0

/obj/item/performance_forensics_probe/blood_DNA_length()
	blood_count_calls++
	return ..()

/// Skipping clean-contact scans must preserve both bare-hand and glove blood transfer rules.
/datum/unit_test/performance_forensics_blood_transfer/Run()
	var/obj/item/evidence = allocate(/obj/item)
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	subject.AddComponent(/datum/component/forensics, null, null, list("bare_donor" = "O+"))
	subject.bloody_hands = 3
	evidence.add_fibers(subject)
	TEST_ASSERT_EQUAL(evidence.return_blood_DNA()["bare_donor"], "O+", "Blood on bare hands must still transfer to a new object.")
	TEST_ASSERT_EQUAL(subject.bloody_hands, 2, "Adding a new blood sample must consume one transfer.")
	evidence.add_fibers(subject)
	TEST_ASSERT_EQUAL(subject.bloody_hands, 2, "Touching the same evidence again must not consume more blood.")
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/roguetown/leather)
	// Set up the worn slot directly: this test exercises evidence transfer, not player equip delays.
	subject.equip_to_slot(gloves, SLOT_GLOVES)
	TEST_ASSERT_EQUAL(subject.gloves, gloves, "The fixture must wear its bloody gloves.")
	gloves.add_blood_DNA(list("glove_donor" = "AB+"))
	gloves.transfer_blood = 3
	evidence.add_fibers(subject)
	TEST_ASSERT_EQUAL(evidence.return_blood_DNA()["glove_donor"], "AB+", "Glove blood must still add its new donor.")
	TEST_ASSERT_EQUAL(gloves.transfer_blood, 2, "Gloves must consume one transfer for a new sample.")
	TEST_ASSERT_EQUAL(subject.bloody_hands, 2, "Wearing gloves must not consume blood on bare hands.")
	evidence.add_fibers(subject)
	TEST_ASSERT_EQUAL(gloves.transfer_blood, 2, "Gloves must not spend a transfer on an existing sample.")

/// Argument-based additions must preserve union semantics, existing clues and blood visuals.
/datum/unit_test/performance_forensics_merge/Run()
	var/obj/item/evidence = allocate(/obj/item/rogueweapon/huntingknife)
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	evidence.record_forensic_event(FORENSIC_EVENT_LOCKPICK_ATTEMPT, subject, evidence)
	var/datum/component/forensics/forensics = evidence.GetComponent(/datum/component/forensics)
	var/clue_timer = forensics.forensic_event_timer
	var/list/old_prints = list("old" = "old")
	var/list/old_hidden = list("shared" = "first", "old" = "old")
	var/list/old_blood = list("shared" = "O+", "old" = "A+")
	var/list/old_fibers = list("old" = "old")
	evidence.AddComponent(/datum/component/forensics, old_prints, old_hidden, old_blood, old_fibers)
	var/list/new_prints = list("new" = "new")
	var/list/new_hidden = list("shared" = "second", "new" = "new")
	var/list/new_blood = list("shared" = "B+", "new" = "AB+")
	var/list/new_fibers = list("new" = "new")
	var/datum/qdel_item/trash = SSgarbage.items[/datum/component/forensics]
	var/deletions_before = trash ? trash.qdels : 0
	var/datum/component/forensics/merged = evidence.AddComponent(/datum/component/forensics, new_prints, new_hidden, new_blood, new_fibers)
	trash = SSgarbage.items[/datum/component/forensics]
	TEST_ASSERT_EQUAL(trash ? trash.qdels : 0, deletions_before, "Merging argument payloads must not delete a temporary component.")
	TEST_ASSERT_EQUAL(merged, forensics, "Adding evidence must return the existing component.")
	TEST_ASSERT(("old" in forensics.fingerprints) && ("new" in forensics.fingerprints), "Fingerprint union must preserve both samples.")
	TEST_ASSERT(("old" in forensics.fibers) && ("new" in forensics.fibers), "Fiber union must preserve both samples.")
	var/list/expected_hidden = old_hidden | new_hidden
	var/list/expected_blood = old_blood | new_blood
	TEST_ASSERT_EQUAL(forensics.hiddenprints["shared"], expected_hidden["shared"], "Hidden prints must keep the existing union precedence.")
	TEST_ASSERT_EQUAL(forensics.blood_DNA["shared"], expected_blood["shared"], "Blood samples must keep the existing union precedence.")
	TEST_ASSERT_EQUAL(forensics.blood_DNA["new"], "AB+", "A new blood donor must be retained.")
	var/datum/component/decal/blood/decal = evidence.GetComponent(/datum/component/decal/blood)
	TEST_ASSERT_NOTNULL(decal, "Adding blood must still create its visual decal.")
	evidence.AddComponent(/datum/component/forensics)
	TEST_ASSERT_EQUAL(evidence.GetComponent(/datum/component/forensics), forensics, "An empty addition must keep the existing evidence component.")
	TEST_ASSERT_EQUAL(evidence.GetComponent(/datum/component/decal/blood), decal, "An empty addition must preserve the existing blood decal.")
	TEST_ASSERT_EQUAL(length(forensics.blood_DNA), length(expected_blood), "An empty addition must preserve every existing DNA sample.")
	trash = SSgarbage.items[/datum/component/forensics]
	TEST_ASSERT_EQUAL(trash ? trash.qdels : 0, deletions_before, "Empty additions must not restore duplicate forensic component churn.")
	TEST_ASSERT_EQUAL(forensics.forensic_event_timer, clue_timer, "Adding trace evidence must not replace the mechanical clue timer.")
	TEST_ASSERT_EQUAL(forensics.forensic_event_type, FORENSIC_EVENT_LOCKPICK_ATTEMPT, "Adding traces must preserve the mechanical clue.")
	TEST_ASSERT_EQUAL(length(old_prints), 1, "Merging must not mutate a caller's original fingerprint list.")
	TEST_ASSERT_EQUAL(length(new_prints), 1, "Merging must not mutate the incoming fingerprint list.")

/// Existing component instances can still be absorbed, not just argument payloads.
/datum/unit_test/performance_forensics_transfer/Run()
	var/obj/source = allocate(/obj)
	var/obj/destination = allocate(/obj)
	var/datum/component/forensics/original = destination.AddComponent(/datum/component/forensics, list("destination" = "destination"), null, list("destination_donor" = "A+"))
	var/datum/component/forensics/incoming = source.AddComponent(/datum/component/forensics, list("source" = "source"), null, list("source_donor" = "B+"))
	var/mob/living/subject = allocate(/mob/living)
	original.add_action(subject, "destination action")
	incoming.add_action(subject, "source action")
	incoming.add_action(subject, "source routine action", TRUE)
	var/datum/forensic_action/incoming_action = incoming.actions[1]
	var/datum/forensic_action/incoming_routine_action = incoming.routine_actions[1]
	incoming.record_forensic_event(FORENSIC_EVENT_LOCKPICK_ATTEMPT, subject, source)
	var/incoming_timer = incoming.forensic_event_timer
	destination.TakeComponent(incoming)
	TEST_ASSERT_EQUAL(destination.GetComponent(/datum/component/forensics), original, "Transferring evidence must keep the destination's component.")
	TEST_ASSERT(("source" in original.fingerprints) && ("destination" in original.fingerprints), "Transfer must preserve evidence from both components.")
	TEST_ASSERT_EQUAL(original.blood_DNA["destination_donor"], "A+", "Component transfer must preserve the destination's blood sample.")
	TEST_ASSERT_EQUAL(original.blood_DNA["source_donor"], "B+", "Component transfer must retain the incoming blood sample.")
	TEST_ASSERT_EQUAL(length(original.actions), 2, "Transfer must merge both components' admin action logs.")
	TEST_ASSERT(incoming_action in original.actions, "The incoming admin action must survive disposal of its component.")
	TEST_ASSERT(incoming_routine_action in original.routine_actions, "The incoming routine action must survive disposal of its component.")
	TEST_ASSERT(QDELETED(incoming), "An absorbed component must be disposed of after transfer.")
	TEST_ASSERT_NULL(incoming.parent, "An absorbed component must not retain its destination.")
	TEST_ASSERT_NULL(timeleft(incoming_timer), "An absorbed component must cancel its abandoned clue timer.")
