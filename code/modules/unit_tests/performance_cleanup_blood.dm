/// Forensic sampling must not run medical treatment or consume the source's bandage.
/datum/unit_test/performance_forensic_blood_sampling/Run()
	var/mob/living/carbon/human/consistent/source = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/limb = source.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(limb, "The blood source must have an attached arm.")
	var/obj/item/natural/cloth/bandage = allocate(/obj/item/natural/cloth)
	bandage.bandage_health = 100
	bandage.bandage_effectiveness = 0.5
	bandage.medicine_quality = 2
	bandage.medicine_amount = 5
	limb.bleeding = 12
	limb.brute_dam = 20
	TEST_ASSERT(limb.try_bandage(bandage), "The source must have a medicated bandage.")
	TEST_ASSERT_EQUAL(source.get_bleed_rate(process_bandages = FALSE), 6, "Read-only sampling must retain bandage effectiveness.")
	var/obj/effect/decal/cleanable/blood/stain = allocate(/obj/effect/decal/cleanable/blood)
	for(var/iteration in 1 to 10)
		TEST_ASSERT(stain.add_mob_blood(source), "The stain must record the source's blood.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_SIGNIFICANT, "Forensic severity must use the current effective bleed rate.")
	TEST_ASSERT_EQUAL(bandage.bandage_health, 100, "Recording blood must not wear out a bandage.")
	TEST_ASSERT_EQUAL(bandage.medicine_amount, 5, "Recording blood must not consume medicine.")
	TEST_ASSERT_EQUAL(limb.brute_dam, 20, "Recording blood must not heal the source.")
	// This also creates/updates a blood decal; treatment must still run exactly once.
	source.handle_blood()
	TEST_ASSERT_EQUAL(bandage.bandage_health, 88, "A real bleeding tick must still process the bandage once.")
	TEST_ASSERT_EQUAL(bandage.medicine_amount, 4.75, "A real bleeding tick must still consume one dose of medicine.")
	TEST_ASSERT_EQUAL(limb.brute_dam, 18, "A real bleeding tick must still apply the bandage's healing once.")

/// The forensic read must preserve clamping rules rather than using the simplified HUD rate.
/datum/unit_test/performance_forensic_blood_clamping/Run()
	var/mob/living/carbon/human/consistent/source = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/limb = source.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(limb, "The blood source must have an attached arm.")
	var/obj/item/rogueweapon/surgery/hemostat/clamp = allocate(/obj/item/rogueweapon/surgery/hemostat)
	clamp.forceMove(limb)
	limb.embedded_objects += clamp
	limb.bleeding = ARTERY_LIMB_BLEEDRATE
	TEST_ASSERT(limb.get_surgery_flags() & SURGERY_CLAMPED, "The fixture must have a surgical clamp.")
	TEST_ASSERT_EQUAL(source.get_bleed_rate(process_bandages = FALSE), 0.5, "Read-only sampling must preserve the surgical bleed limit.")
	TEST_ASSERT_EQUAL(source.get_bleed_rate(), 0.5, "Normal and read-only rates must agree for a clamped wound.")
	var/obj/effect/decal/cleanable/blood/stain = allocate(/obj/effect/decal/cleanable/blood)
	TEST_ASSERT(stain.add_mob_blood(source), "The stain must record clamped bleeding.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_MINOR, "Clamped bleeding must not be recorded as severe.")
	limb.embedded_objects -= clamp
	TEST_ASSERT(stain.add_mob_blood(source), "The stain must record renewed bleeding after unclamping.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_SEVERE, "Unclamping must restore the full forensic severity.")
	limb.bleeding = 0
	TEST_ASSERT(stain.add_mob_blood(source), "The stain must continue to accept later samples.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_SEVERE, "A later mild sample must not erase the highest observed severity.")
