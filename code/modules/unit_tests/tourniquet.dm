/// Tests the tourniquet: it must stop arterial bleeding completely, then numb and
/// finally necrose the limb over time, and removal must undo only the numbness.
/datum/unit_test/tourniquet/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(victim, "Could not allocate a human to test on")

	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(arm, "The human has no left arm")
	TEST_ASSERT_NULL(arm.bandage, "The arm started with a bandage on it")

	// An untreated severed artery must actually bleed, otherwise the test proves nothing.
	arm.add_wound(/datum/wound/artery, silent = TRUE)
	TEST_ASSERT(arm.get_bleed_rate() > 0, "An untreated artery should be bleeding")

	// A regular bandage only halves bleeding, so it must NOT stop an artery.
	var/obj/item/natural/cloth/plain_bandage = allocate(/obj/item/natural/cloth)
	arm.try_bandage(plain_bandage)
	TEST_ASSERT_EQUAL(arm.bandage, plain_bandage, "The regular bandage did not attach")
	TEST_ASSERT(arm.get_bleed_rate() > 0, "A regular bandage must not stop arterial bleeding")
	arm.remove_bandage()
	TEST_ASSERT_NULL(arm.bandage, "The regular bandage did not come off")

	// Now the tourniquet: it must choke off the artery completely and start ticking.
	var/obj/item/natural/cloth/tourniquet/tourniquet = allocate(/obj/item/natural/cloth/tourniquet)
	TEST_ASSERT_EQUAL(arm.try_bandage(tourniquet), TRUE, "The tourniquet refused to attach")
	TEST_ASSERT_EQUAL(arm.bandage, tourniquet, "The tourniquet is not on the arm")
	TEST_ASSERT_EQUAL(arm.get_bleed_rate(), 0, "A tourniquet must stop arterial bleeding entirely")
	TEST_ASSERT_EQUAL(arm.get_hud_bleed_rate(), 0, "A tourniquet must stop the bleed HUD too")
	TEST_ASSERT_EQUAL(arm.get_arterial_bleed_rate(), ARTERY_LIMB_BLEEDRATE, "The arterial contribution should be the whole bleed")

	// A tourniquet pinches off arteries ONLY - a plain slash must keep bleeding past it.
	var/obj/item/bodypart/other_arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	other_arm.add_wound(/datum/wound/slash, silent = TRUE)
	var/slash_bleed = other_arm.get_bleed_rate()
	TEST_ASSERT(slash_bleed > 0, "A slash should bleed")
	var/obj/item/natural/cloth/tourniquet/slash_tourniquet = allocate(/obj/item/natural/cloth/tourniquet)
	other_arm.try_bandage(slash_tourniquet)
	TEST_ASSERT(other_arm.get_bleed_rate() > 0, "A tourniquet must NOT stop a non-arterial wound")
	TEST_ASSERT_EQUAL(other_arm.get_bleed_rate(), slash_bleed, "A slash bleed rate must be untouched by the tourniquet")

	// A pinned artery must not clot or heal away, or the bleeding would be lost forever.
	var/datum/wound/artery = arm.has_wound(/datum/wound/artery)
	TEST_ASSERT_NOTNULL(artery, "The artery wound went missing")
	artery.bleed_rate = ARTERY_LIMB_BLEEDRATE
	artery.clotting_rate = 10
	artery.clotting_threshold = 0
	artery.passive_healing = 50
	for(var/i in 1 to 10)
		artery.on_life()
	TEST_ASSERT_EQUAL(artery.bleed_rate, ARTERY_LIMB_BLEEDRATE, "A pinned artery must not clot shut")
	TEST_ASSERT_NOTNULL(arm.has_wound(/datum/wound/artery), "A pinned artery must not heal away")

	// The tourniquet is immune to blood-soaking: process_bandage must not drain it.
	var/initial_health = tourniquet.bandage_health
	arm.process_bandage(arm.bleeding)
	TEST_ASSERT_EQUAL(tourniquet.bandage_health, initial_health, "A tourniquet must ignore blood soak damage")

	// Numbness kicks in once enough real time has passed.
	tourniquet.tied_time -= TOURNIQUET_NUMB_TIME
	tourniquet.process()
	TEST_ASSERT(tourniquet.numbed, "The tourniquet never numbed the limb")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_PARALYSIS_L_ARM), "The limb should feel numb")
	TEST_ASSERT_EQUAL(arm.disabled, BODYPART_DISABLED_PARALYSIS, "A numb arm should be paralysed")
	// Numbness must not kill the limb yet.
	TEST_ASSERT_EQUAL(arm.rotted, FALSE, "The limb should not necrose from numbness alone")

	// Necrosis only follows after the longer deadline.
	tourniquet.tied_time -= TOURNIQUET_NECROSIS_TIME
	tourniquet.process()
	TEST_ASSERT(tourniquet.necrotised, "The tourniquet never necrosed the limb")
	TEST_ASSERT_EQUAL(arm.rotted, TRUE, "The limb should be necrotic")
	TEST_ASSERT_EQUAL(arm.disabled, BODYPART_DISABLED_ROT, "A necrotic limb should be disabled by rot")

	// Removing the tourniquet must clear the numbness but NOT undo the necrosis.
	arm.remove_bandage()
	TEST_ASSERT_NULL(arm.bandage, "The tourniquet did not come off")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_PARALYSIS_L_ARM), "Removing the tourniquet should undo the numbness")
	TEST_ASSERT_EQUAL(arm.rotted, TRUE, "Necrosis must be permanent even after removal")
	TEST_ASSERT(arm.get_bleed_rate() > 0, "The artery should bleed again once the tourniquet is off")

	// A tourniquet must refuse non-limb zones and non-organic limbs.
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_NOTNULL(chest, "The human has no chest")
	TEST_ASSERT_EQUAL(tourniquet.can_bandage_limb(arm), TRUE, "A tourniquet should accept an organic arm")
	TEST_ASSERT(!(chest.body_zone in tourniquet.bandage_zones), "A tourniquet must not list the chest as a valid zone")
	TEST_ASSERT(!(BODY_ZONE_PRECISE_L_HAND in tourniquet.bandage_zones), "Zones are matched on body_zone, not precise zone")
	TEST_ASSERT(tourniquet.bandage_zones.len == 4, "A tourniquet should target exactly the four limbs")
