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

/mob/living/carbon/human/consistent/performance_colored_blood
	var/test_blood_color = "#00ff00"

/mob/living/carbon/human/consistent/performance_colored_blood/get_blood_color()
	return test_blood_color

/// Colored fresh blood must rewet existing evidence without losing its source, severity or sample cap.
/datum/unit_test/performance_forensic_blood_color_lifecycle/Run()
	var/mob/living/carbon/human/consistent/performance_colored_blood/source = allocate(/mob/living/carbon/human/consistent/performance_colored_blood)
	var/obj/item/bodypart/limb = source.get_bodypart(BODY_ZONE_L_ARM)
	limb.bleeding = 12
	var/obj/effect/decal/cleanable/blood/stain = source.create_sourced_blood_decal(run_loc_floor_bottom_left, /obj/effect/decal/cleanable/blood)
	TEST_ASSERT_NOTNULL(stain, "The real source helper must create a blood stain.")
	allocated |= stain
	var/source_dna = source.dna.unique_enzymes
	TEST_ASSERT(source_dna in stain.return_blood_DNA(), "A colored stain must retain its source DNA.")
	TEST_ASSERT_EQUAL(stain.blood_color, "#00ff00", "The source helper must pass the donor color into the decal.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_SIGNIFICANT, "The colored stain must retain forensic severity.")
	TEST_ASSERT(timeleft(stain.blood_timer) > 0, "Fresh colored blood must still be scheduled to dry.")
	// Emulate the callback after its scheduled timer has been removed from the queue.
	deltimer(stain.blood_timer)
	stain.become_dry()
	TEST_ASSERT(stain.is_dry && stain.dried, "Visual and forensic drying states must agree.")
	TEST_ASSERT_EQUAL(stain.color, stain.dried_color, "Dry blood must use its dry donor tint.")
	TEST_ASSERT_NULL(stain.blood_timer, "A completed drying callback must clear its timer handle.")

	source.test_blood_color = "#0000ff"
	TEST_ASSERT_EQUAL(source.create_sourced_blood_decal(run_loc_floor_bottom_left, /obj/effect/decal/cleanable/blood), stain, "Fresh blood on the same tile must reuse the existing stain.")
	TEST_ASSERT(!stain.is_dry && !stain.dried, "Rewetting must reset both drying states.")
	TEST_ASSERT_EQUAL(stain.blood_color, "#0000ff", "Rewetting must accept the new donor tint.")
	TEST_ASSERT_EQUAL(stain.color, "#0000ff", "The rewetted stain must visibly use its fresh tint.")
	TEST_ASSERT(timeleft(stain.blood_timer) > 0, "Rewetting must restart drying for the existing stain.")
	TEST_ASSERT(source_dna in stain.return_blood_DNA(), "Rewetting must preserve the original source's evidence.")
	TEST_ASSERT_EQUAL(stain.forensic_bleed_severity, FORENSIC_BLEED_SIGNIFICANT, "Rewetting must not discard forensic severity.")
	var/list/samples = list()
	for(var/index in 1 to FORENSIC_MAX_BLOOD_SAMPLES + 2)
		samples["extra_sample_[index]"] = "O+"
	stain.add_blood_DNA(samples, "#ff00ff")
	TEST_ASSERT_EQUAL(stain.blood_DNA_length(), FORENSIC_MAX_BLOOD_SAMPLES, "The colored-blood API must preserve the per-decal evidence cap.")
	TEST_ASSERT(stain.blood_samples_overflow, "Discarded extra DNA must retain the forensic overflow marker.")
	stain.add_blood_DNA(list("over_capacity" = "AB+"), "#00ff00")
	TEST_ASSERT_EQUAL(stain.blood_DNA_length(), FORENSIC_MAX_BLOOD_SAMPLES, "A color change must not bypass the sample cap.")
	TEST_ASSERT_EQUAL(stain.blood_color, "#00ff00", "A full evidence list must still allow the blood's visual color to change.")
	TEST_ASSERT(source_dna in stain.return_blood_DNA(), "Overflow must not evict the original source's evidence.")

/// Mapped old blood and the footprint-specific drying override must use the same forensic state.
/datum/unit_test/performance_forensic_blood_dry_variants/Run()
	var/obj/effect/decal/cleanable/blood/old/old_stain = allocate(/obj/effect/decal/cleanable/blood/old, run_loc_floor_top_right, "#00ff00")
	TEST_ASSERT(old_stain.is_dry && old_stain.dried, "Old blood must begin dry for both the renderer and investigation.")
	TEST_ASSERT_EQUAL(old_stain.color, old_stain.dried_color, "Old blood must use its dry donor tint from initialization.")
	TEST_ASSERT_NULL(old_stain.blood_timer, "Already-dry blood must not create another drying timer.")
	var/obj/effect/decal/cleanable/blood/footprints/footprints = allocate(/obj/effect/decal/cleanable/blood/footprints, run_loc_floor_bottom_left, "#0000ff")
	footprints.add_blood_DNA(list("footprint_donor" = "B+"), "#0000ff")
	footprints.entered_dirs = NORTH
	footprints.update_icon()
	TEST_ASSERT(length(footprints.overlays), "Colored footprints must render their directional overlay.")
	deltimer(footprints.blood_timer)
	footprints.become_dry()
	TEST_ASSERT(footprints.is_dry && footprints.dried, "The footprint override must also mark forensic evidence dry.")
	TEST_ASSERT_NULL(footprints.blood_timer, "Drying footprints must clear their timer handle.")
	TEST_ASSERT_EQUAL(footprints.return_blood_DNA()["footprint_donor"], "B+", "Drying must retain the footprint's blood evidence.")
	TEST_ASSERT(length(footprints.overlays), "Drying must retain the directional footprint overlay.")
