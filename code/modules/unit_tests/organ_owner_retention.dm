/// Removed organs remain usable across their donor's death, revival and transplantation.
/datum/unit_test/organ_removed_owner_lifecycle/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/liver/organ = donor.getorganslot(ORGAN_SLOT_LIVER)
	organ.Remove(donor, special = TRUE)
	organ.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(organ.owner, "Surgical removal must release the organ's active owner.")
	TEST_ASSERT(!QDELETED(organ), "An ordinary extracted organ must remain an item.")
	donor.death()
	donor.revive(full_heal = TRUE, admin_revive = TRUE)
	organ.Insert(donor, TRUE, FALSE)
	TEST_ASSERT_EQUAL(donor.getorganslot(ORGAN_SLOT_LIVER), organ, "The same organ must remain insertable into its revived donor.")
	organ.Remove(donor, special = TRUE)
	organ.Insert(recipient, TRUE, FALSE)
	qdel(donor)
	TEST_ASSERT_EQUAL(organ.owner, recipient, "Deleting the old donor must preserve the transplanted organ's current owner.")
	TEST_ASSERT_EQUAL(recipient.getorganslot(ORGAN_SLOT_LIVER), organ, "The recipient must keep the transplanted organ in its organ slots.")
	organ.Remove(recipient, special = TRUE)
	organ.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!QDELETED(organ), "An ordinary organ must remain movable after its former donor is deleted.")
	allocated += organ

/// Internal-only organs must remember prior insertion even when that body no longer exists.
/datum/unit_test/organ_internal_only_owner_history/Run()
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	var/obj/item/organ/dullahan_vision/organ = allocate(/obj/item/organ/dullahan_vision)
	organ.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!QDELETED(organ), "An internal-only organ that has never been inserted must remain movable during setup.")
	organ.Insert(donor, TRUE, FALSE)
	TEST_ASSERT_EQUAL(organ.owner, donor, "The fixture must actually insert its internal-only organ.")
	organ.Remove(donor, special = TRUE)
	qdel(donor)
	TEST_ASSERT(!QDELETED(organ), "Removing the donor alone must not change the internal-only organ's movement-triggered lifetime.")
	organ.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(QDELETED(organ), "A previously inserted internal-only organ must still delete on movement after its donor is gone.")

/// Extracted and transplanted organs must not pin their former bodies in the garbage queue.
/datum/unit_test/organ_removed_owner_native_gc/Run()
	var/list/identities = list()
	for(var/transplanted in list(FALSE, TRUE))
		identities += list(create_deleted_donor(transplanted))
	sleep(10 SECONDS)
	for(var/list/identity in identities)
		TEST_ASSERT(!is_same_deleted_donor(identity), "An extracted or transplanted organ must allow ordinary collection of its destroyed former donor.")

/datum/unit_test/organ_removed_owner_native_gc/proc/create_deleted_donor(transplanted)
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	var/obj/item/organ/liver/organ = donor.getorganslot(ORGAN_SLOT_LIVER)
	organ.Remove(donor, special = TRUE)
	if(transplanted)
		var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
		organ.Insert(recipient, TRUE, FALSE)
	else
		organ.forceMove(run_loc_floor_bottom_left)
		allocated += organ
	var/list/identity = list("reference" = text_ref(donor), "type" = donor.type)
	qdel(donor)
	identity["gc_destroyed"] = donor.gc_destroyed
	return identity

/datum/unit_test/organ_removed_owner_native_gc/proc/is_same_deleted_donor(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]
