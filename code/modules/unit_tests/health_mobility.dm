/// A health refresh must preserve the distinction between ordinary pulling and restraints.
/datum/unit_test/health_mobility_restraints/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/puller = allocate(/mob/living/carbon/human/consistent)
	puller.start_pulling(human)
	TEST_ASSERT_EQUAL(human.pulledby, puller, "The fixture must establish a real pull.")
	TEST_ASSERT(!human.incapacitated(), "An ordinary pull must not incapacitate a human by default.")
	TEST_ASSERT(human.incapacitated(ignore_grab = FALSE), "Explicit grab checks must still recognize the pull.")
	human.updatehealth()
	TEST_ASSERT(human.mobility_flags & MOBILITY_UI, "An ordinary pull must leave interface interaction available.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_PULL, "An ordinary pull must leave the ability to pull available.")
	puller.stop_pulling()

	var/obj/item/rope/cuffs = allocate(/obj/item/rope)
	puller.put_in_active_hand(cuffs)
	cuffs.apply_cuffs(human, puller)
	TEST_ASSERT_EQUAL(human.handcuffed, cuffs, "The real rope cuffing action must restrain the fixture's hands.")
	human.updatehealth()
	TEST_ASSERT(human.incapacitated(), "Real handcuffs must incapacitate the restrained fixture.")
	TEST_ASSERT(!human.incapacitated(ignore_restraints = TRUE), "Ignoring restraints must still distinguish cuffs from unconsciousness.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_UI), "Handcuffs must block interface interaction.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_PULL), "Handcuffs must block pulling.")
	human.uncuff()
	human.updatehealth()
	TEST_ASSERT(human.mobility_flags & MOBILITY_UI, "Removing handcuffs must restore interface interaction.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_PULL, "Removing handcuffs must restore pulling.")

/// Health refreshes must settle incapacitation and recovery without losing UI/pull flags.
/datum/unit_test/health_mobility_unconsciousness/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.Unconscious(10 SECONDS, FALSE)
	human.updatehealth()
	TEST_ASSERT_EQUAL(human.stat, UNCONSCIOUS, "A real unconsciousness status must affect stat on health refresh.")
	TEST_ASSERT(!(human.mobility_flags & (MOBILITY_UI | MOBILITY_PULL | MOBILITY_MOVE)), "An unconscious human must lose interface, pulling and movement control.")
	human.SetUnconscious(0)
	human.updatehealth()
	TEST_ASSERT_EQUAL(human.stat, CONSCIOUS, "Removing the unconsciousness status must restore consciousness.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_UI, "Waking must restore interface control.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_PULL, "Waking must restore pulling control.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_MOVE, "Waking must restore movement control even while still resting.")

/// The first mobility pass can drop the stick used in its own standing calculation.
/// The complete health refresh must settle the new inventory state before returning.
/datum/unit_test/health_mobility_dropped_walking_stick/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/leg = human.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(leg, "The walking-stick fixture must start with a removable leg.")
	allocated += leg
	leg.drop_limb(TRUE)
	var/obj/item/broom/stick = allocate(/obj/item/broom)
	human.put_in_active_hand(stick)
	human.set_resting(FALSE)
	TEST_ASSERT_EQUAL(human.get_num_legs(), 1, "The walking-stick fixture must have exactly one usable leg.")
	TEST_ASSERT(human.is_holding(stick), "The fixture must actually hold the walking stick.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_STAND, "One leg and a walking stick must initially support standing.")
	// This public parameter deliberately defers mobility to the following health refresh.
	human.Stun(10 SECONDS, FALSE)
	human.updatehealth()
	TEST_ASSERT(!human.is_holding(stick), "Stunning the human must drop the walking stick.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_CANSTAND), "Losing the supporting stick must remove the ability to stand in the same health refresh.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_STAND), "A stunned human with one leg and no stick must finish the health refresh lying down.")

/// A posture transform can clear FLOATING, invalidating the first pass's leg exemption.
/datum/unit_test/health_mobility_floating_posture/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	for(var/zone in list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG))
		var/obj/item/bodypart/leg = human.get_bodypart(zone)
		TEST_ASSERT_NOTNULL(leg, "The floating fixture must start with both removable legs.")
		allocated += leg
		leg.drop_limb(TRUE)
	TEST_ASSERT_EQUAL(human.get_num_legs(), 0, "The floating fixture must have no usable legs.")
	// Stage a resting posture change before its next health refresh, while still floating.
	human.setMovetype(human.movement_type | FLOATING)
	human.lying = 0
	human.lying_prev = 0
	human.resting = TRUE
	human.updatehealth()
	TEST_ASSERT(!(human.movement_type & FLOATING), "The real posture transform must clear floating on this transition.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_CANSTAND), "The final health refresh must account for losing the floating leg exemption.")
	TEST_ASSERT(!(human.mobility_flags & MOBILITY_STAND), "A resting human with no legs must remain prone after the transform.")
	TEST_ASSERT(human.mobility_flags & MOBILITY_MOVE, "A conscious legless human with usable arms must retain crawling movement.")
