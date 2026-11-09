/// A manufactured limb must not invent a donor before first use, then must keep its first actual body.
/datum/unit_test/bodypart_owner_unassigned/Run()
	var/obj/item/bodypart/l_arm/arm = new(run_loc_floor_bottom_left)
	allocated += arm
	var/runtimes_before = GLOB.total_runtimes
	arm.update_limb()
	TEST_ASSERT_NULL(arm.original_owner, "A source-less limb must remain without an original donor.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Refreshing an unassigned limb must safely leave it without a donor.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/replaced_arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	replaced_arm.drop_limb(FALSE)
	qdel(replaced_arm)
	TEST_ASSERT(arm.attach_limb(recipient), "An unassigned limb must still attach normally.")
	arm.update_limb()
	TEST_ASSERT_EQUAL(arm.original_owner, recipient, "The first actual body must become the limb's original owner.")

/// A corpse remains the original donor until its body is actually destroyed.
/datum/unit_test/bodypart_owner_death_revival/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(arm.drop_limb(FALSE), "The fixture must detach its actual arm.")
	TEST_ASSERT_EQUAL(arm.original_owner, donor, "A detached arm must remember its living donor.")
	donor.death()
	TEST_ASSERT_EQUAL(arm.original_owner, donor, "Ordinary death must preserve limb ownership for revival.")
	donor.revive(admin_revive = TRUE)
	TEST_ASSERT(donor.stat != DEAD, "The donor must actually revive.")
	TEST_ASSERT_EQUAL(arm.original_owner, donor, "Revival must retain the original donor.")
	TEST_ASSERT(arm.attach_limb(donor), "A revived donor must accept their own detached arm.")
	arm.update_limb()
	TEST_ASSERT(!arm.no_update, "A donor's own reattached arm must still follow their appearance.")
	TEST_ASSERT_EQUAL(donor.get_bodypart(BODY_ZONE_L_ARM), arm, "Reattachment must restore the original limb slot.")

/// A transplanted arm keeps its original appearance after the donor's deleted body is released.
/datum/unit_test/bodypart_owner_transplant/Run()
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	donor.gender = FEMALE
	recipient.gender = MALE
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	arm.update_limb(source = donor)
	var/donor_icon = arm.species_icon
	var/donor_gender = arm.body_gender
	TEST_ASSERT(arm.drop_limb(FALSE), "The donor's arm must be detached before transplantation.")
	var/obj/item/bodypart/replaced_arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	replaced_arm.drop_limb(FALSE)
	qdel(replaced_arm)
	TEST_ASSERT(arm.attach_limb(recipient), "The recipient must accept the transplanted arm.")
	arm.update_limb()
	TEST_ASSERT_EQUAL(arm.owner, recipient, "A transplant must acquire its current owner.")
	TEST_ASSERT_EQUAL(arm.original_owner, donor, "A transplant must preserve its existing donor while the body exists.")
	qdel(donor)
	TEST_ASSERT_NULL(arm.original_owner, "The transplant must release an actually destroyed donor.")
	TEST_ASSERT_EQUAL(arm.owner, recipient, "Deleting the donor must not clear the transplant's current owner.")
	arm.update_limb()
	TEST_ASSERT(arm.no_update, "A removed donor's arm must remain foreign instead of adopting the recipient's appearance.")
	TEST_ASSERT_EQUAL(arm.species_icon, donor_icon, "The transplanted arm must preserve the donor's icon.")
	TEST_ASSERT_EQUAL(arm.body_gender, donor_gender, "The transplanted arm must preserve the donor's body appearance.")
	arm.update_limb(source = recipient)
	TEST_ASSERT_NULL(arm.original_owner, "Refreshing a foreign limb must not claim the recipient as a new original donor.")
	TEST_ASSERT_EQUAL(arm.body_gender, donor_gender, "An explicit appearance refresh must preserve the removed donor's appearance.")
	TEST_ASSERT(arm.drop_limb(FALSE), "A foreign limb must remain detachable after donor deletion.")
	TEST_ASSERT(!QDELETED(recipient), "Removing the foreign limb must not delete the recipient.")
	qdel(arm)

/// Destroying a transplant's current body must release its donor subscription without harming the donor.
/datum/unit_test/bodypart_owner_recipient_deleted/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/recipient = new(run_loc_floor_bottom_left)
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(FALSE)
	var/obj/item/bodypart/replaced_arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	replaced_arm.drop_limb(FALSE)
	qdel(replaced_arm)
	arm.attach_limb(recipient)
	qdel(recipient)
	TEST_ASSERT(QDELETED(arm), "Deleting the recipient must still dispose of its transplanted bodyparts.")
	TEST_ASSERT_NULL(arm.owner, "A destroyed transplant must release its current body.")
	TEST_ASSERT_NULL(arm.original_owner, "A destroyed transplant must release its still-existing donor.")
	TEST_ASSERT(!QDELETED(donor), "Transplant cleanup must not delete the donor.")
	var/list/donor_signals = arm.signal_procs?[donor]
	TEST_ASSERT(!donor_signals || !(COMSIG_QDELETING in donor_signals), "Destroying a transplant must unsubscribe from the surviving donor.")
	qdel(donor)

/// A combat-dismembered transplant must follow each recipient's lifetime independently of its donor.
/datum/unit_test/bodypart_owner_dismembered_transplant/Run()
	var/mob/living/carbon/human/original_donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/first_recipient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second_recipient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = original_donor.get_bodypart(BODY_ZONE_L_ARM)
	arm.update_limb(source = original_donor)
	arm.drop_limb(FALSE)
	var/obj/item/bodypart/first_arm = first_recipient.get_bodypart(BODY_ZONE_L_ARM)
	first_arm.drop_limb(FALSE)
	qdel(first_arm)
	arm.attach_limb(first_recipient)
	arm.admin_dismember()
	TEST_ASSERT(!(arm in first_recipient.bodyparts), "Combat must actually detach the transplanted arm.")
	TEST_ASSERT_EQUAL(arm.owner, first_recipient, "Dismemberment must preserve its existing live combat owner bookkeeping.")
	TEST_ASSERT_EQUAL(arm.original_owner, original_donor, "Combat must not rewrite the original donor.")
	var/obj/item/bodypart/second_arm = second_recipient.get_bodypart(BODY_ZONE_L_ARM)
	second_arm.drop_limb(FALSE)
	qdel(second_arm)
	arm.attach_limb(second_recipient)
	var/list/old_owner_signals = arm.signal_procs?[first_recipient]
	TEST_ASSERT(!old_owner_signals || !(COMSIG_QDELETING in old_owner_signals), "Reattachment must release the former recipient subscription.")
	qdel(first_recipient)
	TEST_ASSERT_EQUAL(arm.owner, second_recipient, "Deleting the old recipient must not sever the current attachment.")
	arm.admin_dismember()
	qdel(second_recipient)
	TEST_ASSERT_NULL(arm.owner, "Deleting a combat-dismembered transplant recipient must release its bookkeeping reference.")
	TEST_ASSERT_EQUAL(arm.original_owner, original_donor, "Deleting a recipient must preserve the still-existing original donor.")
	qdel(arm)

/// Ownership restrictions must not treat an extinct donor as a never-owned, freely compatible limb.
/datum/unit_test/bodypart_owner_necra_vow/Run()
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(FALSE)
	var/obj/item/bodypart/old_arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	old_arm.drop_limb(FALSE)
	qdel(old_arm)
	qdel(donor)
	recipient.apply_status_effect(/datum/status_effect/buff/necras_vow)
	TEST_ASSERT(recipient.has_status_effect(/datum/status_effect/buff/necras_vow), "The fixture must have an active Necra vow.")
	var/datum/surgery_step/add_prosthetic/surgery = new
	allocated += surgery
	TEST_ASSERT_EQUAL(surgery.preop(recipient, recipient, BODY_ZONE_L_ARM, arm), FALSE, "Surgery must reject a foreign donor's limb even after that donor is deleted.")
	var/obj/effect/proc_holder/spell/invoked/attach_bodypart/spell = allocate(/obj/effect/proc_holder/spell/invoked/attach_bodypart)
	spell.cast(list(recipient), recipient)
	TEST_ASSERT_NULL(recipient.get_bodypart(BODY_ZONE_L_ARM), "Pestra's attachment spell must respect the same donor restriction.")
	recipient.remove_status_effect(/datum/status_effect/buff/necras_vow)
	REMOVE_TRAIT(recipient, TRAIT_NECRAS_VOW, TRAIT_MIRACLE)
	spell.cast(list(recipient), recipient)
	TEST_ASSERT_EQUAL(recipient.get_bodypart(BODY_ZONE_L_ARM), arm, "Without the vow, a foreign donor's arm must still be transplantable.")

/mob/living/carbon/human/consistent/bodypart_hearing_receiver
	var/relayed_messages = 0

/mob/living/carbon/human/consistent/bodypart_hearing_receiver/Hear(message, atom/movable/speaker, message_language, raw_message, radio_freq, list/spans, message_mode)
	relayed_messages++

/// Live and dead detached heads keep hearing; admin revival reattaches the actual head.
/datum/unit_test/bodypart_owner_dullahan_revival/Run()
	var/mob/living/carbon/human/consistent/bodypart_hearing_receiver/donor = allocate(/mob/living/carbon/human/consistent/bodypart_hearing_receiver)
	donor.set_species(/datum/species/dullahan)
	var/datum/species/dullahan/species = donor.dna.species
	var/obj/item/bodypart/head/dullahan/head = species.my_head
	head.drop_limb(FALSE)
	TEST_ASSERT(species.headless, "Removing the head must activate normal revenant headless behavior.")
	var/heard_before = donor.relayed_messages
	head.Hear("test", donor, raw_message = "test")
	TEST_ASSERT_EQUAL(donor.relayed_messages, heard_before + 1, "A living detached head must still relay hearing to its donor.")
	donor.death()
	TEST_ASSERT_EQUAL(head.original_owner, donor, "Death must not detach a revenant head from its existing corpse.")
	heard_before = donor.relayed_messages
	head.Hear("test", donor, raw_message = "test")
	TEST_ASSERT_EQUAL(donor.relayed_messages, heard_before + 1, "A dead revenant's head must keep its existing hearing relay.")
	donor.revive(full_heal = TRUE, admin_revive = TRUE)
	TEST_ASSERT(donor.stat != DEAD, "The revenant must actually revive.")
	TEST_ASSERT_EQUAL(donor.get_bodypart(BODY_ZONE_HEAD), head, "Admin revival must restore the same detached head.")
	TEST_ASSERT(!species.headless, "Reattachment must restore ordinary headed behavior.")
	TEST_ASSERT_EQUAL(head.original_owner, donor, "Revival must preserve donor identity.")

/// A detached head becomes an inert item when its body is destroyed, without callbacks into freed state.
/datum/unit_test/bodypart_owner_dullahan_deleted/Run()
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	donor.set_species(/datum/species/dullahan)
	var/datum/species/dullahan/species = donor.dna.species
	var/obj/item/bodypart/head/dullahan/head = species.my_head
	head.drop_limb(FALSE)
	allocated += head
	var/mob/living/carbon/human/handler = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	qdel(donor)
	TEST_ASSERT_NULL(head.original_owner, "A detached revenant head must release a destroyed body.")
	TEST_ASSERT(!QDELETED(head), "Destroying the body must preserve its detached head as an item.")
	head.Hear("test", handler, raw_message = "test")
	head.forceMove(handler)
	head.on_enter_storage(null)
	head.on_exit_storage(null)
	head.forceMove(run_loc_floor_bottom_left)
	head.say_mod("test", null)
	head.send_speech("test")
	TEST_ASSERT_EQUAL(head.check_closest_zones(handler), FALSE, "A bodyless head must not offer interactions with its destroyed donor.")
	TEST_ASSERT_EQUAL(head.drop_limb(FALSE), FALSE, "An already detached bodyless head must not try to detach from missing flesh.")
	head.drop_organs(handler, FALSE)
	qdel(head)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Moving, hearing, handling, and disposing of a bodyless head must not access its removed donor.")

/// Check native collection for surgical detachment, combat dismemberment and a detached revenant head.
/datum/unit_test/bodypart_owner_native_gc/Run()
	var/list/identities = list()
	for(var/method in list("surgical", "combat", "dullahan", "transplanted_combat", "transplanted_reattached"))
		identities[method] = create_deleted_donor(method)
	// Dismemberment messages leave BYOND's last native hearers result cached in an otherwise idle world.
	// Refresh that cache to test the retained limbs and organs themselves, as in the dryad GC fixture.
	var/list/cached_hearers = hearers(0, run_loc_floor_top_right)
	TEST_ASSERT(!length(cached_hearers), "The native hearers cache control must use an empty distant tile.")
	sleep(10 SECONDS)
	for(var/method in identities)
		TEST_ASSERT(!is_same_deleted_donor(identities[method]), "A [method] bodypart must allow ordinary collection of its destroyed donor.")

/datum/unit_test/bodypart_owner_native_gc/proc/create_deleted_donor(method)
	var/mob/living/carbon/human/consistent/donor = new(run_loc_floor_bottom_left)
	var/obj/item/bodypart/limb
	if(method == "dullahan")
		donor.set_species(/datum/species/dullahan)
		limb = donor.get_bodypart(BODY_ZONE_HEAD)
	else if(method == "transplanted_combat" || method == "transplanted_reattached")
		var/mob/living/carbon/human/original_donor = allocate(/mob/living/carbon/human/consistent)
		limb = original_donor.get_bodypart(BODY_ZONE_L_ARM)
		limb.update_limb(source = original_donor)
		limb.drop_limb(FALSE)
		var/obj/item/bodypart/replaced_limb = donor.get_bodypart(BODY_ZONE_L_ARM)
		replaced_limb.drop_limb(FALSE)
		qdel(replaced_limb)
		limb.attach_limb(donor)
	else
		limb = donor.get_bodypart(BODY_ZONE_L_ARM)
	if(method == "combat" || method == "transplanted_combat" || method == "transplanted_reattached")
		limb.admin_dismember()
	else
		limb.drop_limb(FALSE)
	if(limb in donor.bodyparts)
		TEST_FAIL("The [method] fixture must actually detach its limb.")
	if(method == "transplanted_reattached")
		var/mob/living/carbon/human/new_recipient = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/bodypart/replaced_limb = new_recipient.get_bodypart(BODY_ZONE_L_ARM)
		replaced_limb.drop_limb(FALSE)
		qdel(replaced_limb)
		limb.attach_limb(new_recipient)
	allocated += limb
	var/list/identity = list("reference" = text_ref(donor), "type" = donor.type)
	qdel(donor)
	identity["gc_destroyed"] = donor.gc_destroyed
	return identity

/datum/unit_test/bodypart_owner_native_gc/proc/is_same_deleted_donor(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]
