/// Exercise the actual shared spell with both infection rolls forced to succeed.
/// This keeps the carrier check deterministic while preserving the seven-second channel and healing.
/datum/unit_test/woundlick
	var/caster_has_mind = TRUE
	var/werewolf_type

/datum/unit_test/woundlick/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/species/wildshape/cat)
	if(caster_has_mind)
		caster.mind_initialize()
		allocated += caster.mind
	if(werewolf_type)
		// Register only the carrier identity: avoid unrelated antagonist gain effects in this fixture.
		var/datum/antagonist/werewolf/carrier = new werewolf_type
		carrier.owner = caster.mind
		LAZYADD(caster.mind.antag_datums, carrier)
		allocated += carrier

	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.mind_initialize()
	allocated += target.mind
	TEST_ASSERT(target.can_werewolf(), "The recipient must be eligible for lycanthropy.")
	var/obj/item/bodypart/chest = target.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/wound = new
	allocated += wound
	wound.werewolf_infection_probability = 100
	TEST_ASSERT(wound.apply_to_bodypart(chest, TRUE), "The recipient must have a real wound.")
	var/obj/effect/proc_holder/spell/targeted/woundlick/spell = allocate(/obj/effect/proc_holder/spell/targeted/woundlick)
	spell.infection_chance = 100
	spell.cast(list(target), caster)
	TEST_ASSERT_EQUAL(target.reagents.get_reagent_amount(/datum/reagent/medicine/healthpot), 20, "Licking must retain its healing.")
	TEST_ASSERT_EQUAL(target.reagents.get_reagent_amount(/datum/reagent/water), 20, "Licking must retain its water reagent.")
	if(werewolf_type)
		TEST_ASSERT(wound.werewolf_infection_timer, "A genuine carrier must still start infection when both rolls succeed.")
	else
		TEST_ASSERT(!wound.werewolf_infection_timer, "A non-carrier must never start infection, even when both rolls would succeed.")

/datum/unit_test/woundlick/mindless
	caster_has_mind = FALSE

/datum/unit_test/woundlick/werewolf
	werewolf_type = /datum/antagonist/werewolf

/datum/unit_test/woundlick/lesser_werewolf
	werewolf_type = /datum/antagonist/werewolf/lesser
