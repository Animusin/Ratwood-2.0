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
	TEST_ASSERT_EQUAL(arm.get_lethal_bleed_rate(), ARTERY_LIMB_BLEEDRATE, "The lethal contribution should be the whole bleed")

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
	TEST_ASSERT(HAS_TRAIT_FROM(arm, TRAIT_PARALYSIS, TRAIT_TOURNIQUET), "The limb should feel numb")
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
	TEST_ASSERT(!HAS_TRAIT_FROM(arm, TRAIT_PARALYSIS, TRAIT_TOURNIQUET), "Removing the tourniquet should undo the numbness")
	TEST_ASSERT_EQUAL(arm.rotted, TRUE, "Necrosis must be permanent even after removal")
	TEST_ASSERT(arm.get_bleed_rate() > 0, "The artery should bleed again once the tourniquet is off")

	// A slash that escalated to artery-level bleeding is "lethal" and must be pinched
	// off just like an artery, even though its type is not /datum/wound/artery.
	var/obj/item/bodypart/lethal_arm = victim.get_bodypart(BODY_ZONE_L_LEG)
	var/datum/wound/dynamic/slash/deep_cut = lethal_arm.add_wound(/datum/wound/dynamic/slash, silent = TRUE)
	TEST_ASSERT_NOTNULL(deep_cut, "Could not apply a dynamic slash")
	deep_cut.set_bleed_rate(ARTERY_LIMB_BLEEDRATE)
	TEST_ASSERT_EQUAL(lethal_arm.get_lethal_bleed_rate(), ARTERY_LIMB_BLEEDRATE, "An artery-level slash counts as lethal")
	TEST_ASSERT_EQUAL(lethal_arm.get_bleed_rate(), ARTERY_LIMB_BLEEDRATE, "The lethal slash should bleed before the tourniquet")
	lethal_arm.try_bandage(allocate(/obj/item/natural/cloth/tourniquet))
	TEST_ASSERT_EQUAL(lethal_arm.get_bleed_rate(), 0, "A tourniquet must stop a lethal slash too")

	// A fracture is critical but rates only SEVERE and bleeds well under artery
	// level, so a tourniquet must leave its bleeding alone.
	var/obj/item/bodypart/broken_arm = victim.get_bodypart(BODY_ZONE_R_LEG)
	var/datum/wound/fracture/breakage = broken_arm.add_wound(/datum/wound/fracture, silent = TRUE)
	TEST_ASSERT_NOTNULL(breakage, "Could not fracture a leg")
	TEST_ASSERT_EQUAL(breakage.critical, TRUE, "A fracture is flagged critical in this codebase")
	TEST_ASSERT_EQUAL(broken_arm.get_lethal_bleed_rate(), 0, "A fracture must not count as pinnable bleeding")
	broken_arm.try_bandage(allocate(/obj/item/natural/cloth/tourniquet))
	TEST_ASSERT_EQUAL(broken_arm.get_bleed_rate(), breakage.bleed_rate, "A tourniquet must not stop a fracture's bleeding")

	// A tourniquet must refuse non-limb zones and non-organic limbs.
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_NOTNULL(chest, "The human has no chest")
	TEST_ASSERT_EQUAL(tourniquet.can_bandage_limb(arm), TRUE, "A tourniquet should accept an organic arm")
	TEST_ASSERT(!(chest.body_zone in tourniquet.bandage_zones), "A tourniquet must not list the chest as a valid zone")
	TEST_ASSERT(!(BODY_ZONE_PRECISE_L_HAND in tourniquet.bandage_zones), "Zones are matched on body_zone, not precise zone")
	TEST_ASSERT(tourniquet.bandage_zones.len == 4, "A tourniquet should target exactly the four limbs")

	// It must survive cloth bundling: a tourniquet is a cloth subtype, so the base
	// bundling sweeps up everything on the floor, and attackby merges matching bundletypes.
	TEST_ASSERT_EQUAL(tourniquet.bundleable, FALSE, "A tourniquet must never be swept up when cloth is bundled")
	TEST_ASSERT_NULL(tourniquet.bundletype, "A tourniquet must never merge itself into a cloth bundle")

/// Measures real blood loss through handle_blood(): an untreated wound must drain
/// blood, a tourniquet must stop the drain, and removing it must resume the drain.
/datum/unit_test/tourniquet_blood_loss/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(victim, "Could not allocate a human to test on")
	TEST_ASSERT(victim.blood_volume > 0, "The test human starts with no blood")

	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(arm, "The human has no left arm")

	// Baseline: no wound, no blood loss at all.
	var/start_volume = victim.blood_volume
	for(var/i in 1 to 5)
		victim.handle_blood()
	TEST_ASSERT_EQUAL(victim.blood_volume, start_volume, "An unhurt human must not lose blood")

	// An untreated artery must actually drain blood over time.
	arm.add_wound(/datum/wound/artery, silent = TRUE)
	TEST_ASSERT(arm.get_bleed_rate() > 0, "An untreated artery should be bleeding")
	var/untreated_volume = victim.blood_volume
	for(var/i in 1 to 5)
		victim.handle_blood()
	TEST_ASSERT(victim.blood_volume < untreated_volume, "An untreated artery must drain blood volume")

	// A tourniquet must pin the drain shut without removing the wound.
	// Note: this codebase regenerates +0.5 blood per tick whenever the mob is below
	// BLOOD_VOLUME_NORMAL, so a pinned limb may very slightly GAIN blood. What matters
	// is that it never loses any.
	var/obj/item/natural/cloth/tourniquet/tourniquet = allocate(/obj/item/natural/cloth/tourniquet)
	arm.try_bandage(tourniquet)
	TEST_ASSERT_EQUAL(arm.get_bleed_rate(), 0, "A tourniquet must stop the artery")
	var/pinned_volume = victim.blood_volume
	for(var/i in 1 to 5)
		victim.handle_blood()
	TEST_ASSERT(victim.blood_volume >= pinned_volume, "A tourniquet must stop blood loss entirely")

	// Non-arterial wounds must keep draining blood past the tourniquet. The bleed rate
	// is the reliable signal here: a slash only loses 0.4/tick, which the +0.5/tick
	// regeneration fully cancels out, so blood_volume alone cannot show the drain.
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	leg.add_wound(/datum/wound/slash, silent = TRUE)
	var/slash_bleed = leg.get_bleed_rate()
	TEST_ASSERT(slash_bleed > 0, "A slash should bleed")
	leg.try_bandage(allocate(/obj/item/natural/cloth/tourniquet))
	TEST_ASSERT_EQUAL(leg.get_bleed_rate(), slash_bleed, "A slash must keep bleeding at full rate under a tourniquet")
	TEST_ASSERT_EQUAL(leg.get_lethal_bleed_rate(), 0, "A shallow slash is not lethal, so there is nothing to pinch off")

	// Removing the tourniquet from a pinned artery must bring the drain back.
	arm.remove_bandage()
	TEST_ASSERT_NULL(arm.bandage, "The tourniquet should be off the arm")
	TEST_ASSERT(arm.get_bleed_rate() > 0, "The artery should bleed again with the tourniquet off")
	var/released_volume = victim.blood_volume
	for(var/i in 1 to 5)
		victim.handle_blood()
	TEST_ASSERT(victim.blood_volume < released_volume, "Bleeding must resume once the tourniquet is removed")
