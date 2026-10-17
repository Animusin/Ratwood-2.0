#define LEVY_EXPECT(value, reason) if(!(value)) { Fail(reason, __FILE__, __LINE__); }
#define LEVY_EXPECT_EQUAL(value, expected, reason) if((value) != (expected)) { Fail("Expected [value] to equal [expected]: [reason]", __FILE__, __LINE__); }
#define LEVY_EXPECT_NOTNULL(value, reason) if(isnull(value)) { Fail(reason, __FILE__, __LINE__); }
// Native integration coverage for PR 7531: all 104 kits, local job links and mechanics.
/datum/outfit/job/roguetown/levy/unit_test
	var/weapon_option
	var/background_option

/datum/outfit/job/roguetown/levy/unit_test/choose_weapon(mob/living/carbon/human/H)
	return weapon_option

/datum/outfit/job/roguetown/levy/unit_test/choose_background(mob/living/carbon/human/H)
	return background_option

/datum/unit_test/levy/proc/make_levyman()
	var/mob/living/carbon/human/consistent/H = allocate(/mob/living/carbon/human/consistent)
	H.gender = MALE
	H.set_species(/datum/species/human/northern)
	H.mind = new /datum/mind()
	allocated += H.mind
	H.mind.current = H
	H.mind.assigned_role = "Levy"
	H.job = "Levy"
	return H

/datum/unit_test/levy/Run()
	var/datum/job/roguetown/vanguard/job = new
	allocated += job
	TEST_ASSERT_EQUAL(job.title, "Levy", "The legacy Vanguard job becomes Levy.")
	TEST_ASSERT_EQUAL(job.total_positions, 5, "Five levymen can join.")
	TEST_ASSERT_EQUAL(job.spawn_positions, 5, "Five positions are available at roundstart.")
	TEST_ASSERT_EQUAL(SSjob.GetJob("Levy"), SSjob.GetJobType(/datum/job/roguetown/vanguard), "The job registry resolves the renamed role.")
	TEST_ASSERT_NULL(SSjob.GetJob("Vanguard"), "Vanguard is no longer a separate selectable role.")
	TEST_ASSERT("Levy" in GLOB.garrison_positions, "The job remains in the garrison.")
	TEST_ASSERT_EQUAL(civic_department("Levy"), "KEEP", "Civic classification recognizes Levy.")
	TEST_ASSERT_NULL(job.outfit, "The job does not run the two equipment prompts before the subclass does.")
	TEST_ASSERT_EQUAL(job.job_subclasses.len, 1, "The old archer and footman are replaced by one customizable Levy.")
	var/obj/effect/landmark/start/vanguard/old_spawn = allocate(/obj/effect/landmark/start/vanguard)
	TEST_ASSERT_EQUAL(old_spawn.name, "Levy", "Existing mapped Vanguard spawns now serve Levy.")
	var/obj/effect/landmark/start/vanguardlate/late = allocate(/obj/effect/landmark/start/vanguardlate)
	TEST_ASSERT(late in GLOB.jobspawn_overrides["Levy"], "Existing latejoin locations support Levy.")
	var/obj/effect/proc_holder/spell/self/convertrole/vanguard/recruit = new
	allocated += recruit
	TEST_ASSERT_EQUAL(recruit.new_role, "Levy", "Master Warden recruitment uses the new job.")
	var/datum/outfit/job/roguetown/levy/unit_test/options = new
	allocated += options
	var/list/weapons = options.get_weapon_options()
	var/list/backgrounds = options.get_background_options()
	TEST_ASSERT_EQUAL(weapons.len, 13, "All thirteen weapons are present.")
	TEST_ASSERT_EQUAL(backgrounds.len, 8, "All eight occupations are present.")
	var/list/descriptions = options.get_background_descriptions()
	TEST_ASSERT_EQUAL(descriptions.len, backgrounds.len, "Each selectable background has details inside the choice window.")
	var/datum/tgui_list_input/details = new(null, "Choose", "Levy", backgrounds, null, 0, GLOB.tgui_always_state, FALSE, descriptions)
	allocated += details
	var/list/menu_data = details.ui_static_data(null)
	var/list/menu_descriptions = menu_data["descriptions"]
	for(var/background in backgrounds)
		TEST_ASSERT_EQUAL(menu_descriptions[background], descriptions[background], "Background details survive the menu option mapping.")
		TEST_ASSERT(findtext(descriptions[background], "Final Stats:"), "The choice window includes final stat totals.")
	var/list/weapon_skills = list(
		/datum/skill/combat/swords,
		/datum/skill/combat/knives,
		/datum/skill/combat/maces,
		/datum/skill/combat/slings,
		/datum/skill/combat/whipsflails,
		/datum/skill/combat/polearms,
		/datum/skill/combat/whipsflails,
		/datum/skill/combat/axes,
		/datum/skill/labor/mining,
		/datum/skill/labor/farming,
		/datum/skill/combat/polearms,
		/datum/skill/craft/cooking,
		/datum/skill/combat/unarmed
	)
	// STR, CON, WIL, INT, PER, SPD, LCK: local balanced sums, including base class bonuses.
	var/list/background_stats = list(
		list(1, 1, 1, -1, 0, 0, 1),
		list(1, 1, 1, 3, 0, 1, -1),
		list(0, 0, 0, 3, 0, 2, -1),
		list(2, 2, 1, -1, 0, -1, -1),
		list(1, -1, 1, -1, 0, 3, -1),
		list(0, 0, 0, -1, 0, 2, 1),
		list(1, 1, 1, -1, -1, 1, -1),
		list(1, 2, 2, -1, -1, 0, -1)
	)
	var/list/stat_keys = list(STATKEY_STR, STATKEY_CON, STATKEY_WIL, STATKEY_INT, STATKEY_PER, STATKEY_SPD, STATKEY_LCK)
	for(var/weapon_index in 1 to weapons.len)
		for(var/background_index in 1 to backgrounds.len)
			var/mob/living/carbon/human/H = make_levyman()
			var/list/original_stats = list()
			for(var/key in stat_keys)
				original_stats[key] = H.get_stat(key)
			var/datum/outfit/job/roguetown/levy/unit_test/kit = new
			allocated += kit
			kit.weapon_option = weapons[weapon_index]
			kit.background_option = backgrounds[background_index]
			var/datum/advclass/levy/class = new
			allocated += class
			class.outfit = kit
			class.applies_post_equipment = FALSE
			class.equipme(H)
			var/context = "[kit.weapon_option] / [kit.background_option]"
			LEVY_EXPECT(H.class_equip_finished, "Full outfit finished: [context]")
			LEVY_EXPECT_NOTNULL(H.head, "Helmet exists: [context]")
			LEVY_EXPECT_NOTNULL(H.wear_neck, "Coif exists: [context]")
			LEVY_EXPECT_NOTNULL(H.wear_mask, "Arming cap fits: [context]")
			if(H.wear_mask)
				LEVY_EXPECT(H.wear_mask.icon_state in icon_states(H.wear_mask.mob_overlay_icon), "The under-helmet cap has a valid worn frame: [context]")
			LEVY_EXPECT_NOTNULL(H.cloak, "Tabard exists: [context]")
			LEVY_EXPECT_NOTNULL(H.wear_shirt, "Gambeson exists: [context]")
			LEVY_EXPECT_NOTNULL(H.gloves, "Gloves exist: [context]")
			LEVY_EXPECT_NOTNULL(H.shoes, "Boots exist: [context]")
			LEVY_EXPECT_NOTNULL(H.belt, "Belt exists: [context]")
			LEVY_EXPECT(istype(H.backl, /obj/item/storage/backpack/rogue), "Each occupation has a bag: [context]")
			var/list/delivered = H.GetAllContents()
			LEVY_EXPECT(locate(/obj/item/signal_horn) in delivered, "The horn is delivered: [context]")
			LEVY_EXPECT(locate(/obj/item/storage/keyring/guard) in delivered, "Garrison keys are delivered: [context]")
			LEVY_EXPECT(locate(/obj/item/scomstone/bad/garrison) in delivered, "Garrison communication is delivered: [context]")
			LEVY_EXPECT(H.get_skill_level(weapon_skills[weapon_index]) >= SKILL_LEVEL_EXPERT, "Chosen weapon proficiency remains Expert: [context]")
			LEVY_EXPECT(H.get_skill_level(/datum/skill/combat/wrestling) >= SKILL_LEVEL_JOURNEYMAN, "Every levyman starts with level-three wrestling: [context]")
			if(weapon_index == 12)
				LEVY_EXPECT(H.get_skill_level(/datum/skill/combat/knives) >= SKILL_LEVEL_EXPERT, "The kitchen kit also retains Expert cleaver proficiency: [context]")
			for(var/trait in list(TRAIT_LEVY, TRAIT_LEECHRESIST, TRAIT_SELF_RELIANCE, TRAIT_DECEIVING_MEEKNESS))
				LEVY_EXPECT(HAS_TRAIT(H, trait), "Core trait [trait] is retained: [context]")
			var/list/expected = background_stats[background_index]
			for(var/stat_index in 1 to stat_keys.len)
				var/key = stat_keys[stat_index]
				LEVY_EXPECT_EQUAL(H.get_stat(key), original_stats[key] + expected[stat_index], "Local [key] balance: [context]")
			if(background_index == 1)
				LEVY_EXPECT_EQUAL(H.get_skill_level(/datum/skill/craft/weaponsmithing), SKILL_LEVEL_NOVICE, "Self-Reliance raises the cap without granting Journeyman smithing.")
				LEVY_EXPECT(!HAS_TRAIT(H, TRAIT_SQUIRE_REPAIR), "Self-Reliance does not grant squire repairs.")
			if(background_index == 3)
				LEVY_EXPECT(H.mind.has_spell(/obj/effect/proc_holder/spell/invoked/diagnose/secular), "The field doctor can diagnose patients.")
				LEVY_EXPECT(locate(/obj/item/paper/levy_field_medicine) in delivered, "The doctor has a usable local recipe.")
				LEVY_EXPECT(locate(/obj/item/folding_table_stored/alchcauldron) in delivered, "The doctor receives the portable local cauldron.")
			if(background_index == 8)
				LEVY_EXPECT(locate(/obj/item/rogueweapon/shield/heater) in H.held_items, "The shield occupies a free hand without destroying the bag or weapon.")
			if(weapon_index == 4)
				var/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog/slingshot = locate() in delivered
				LEVY_EXPECT_NOTNULL(slingshot, "Slingshot is worn on the back.")
				LEVY_EXPECT(slingshot.icon_state in icon_states(slingshot.icon), "Slingshot has a valid inventory and held frame.")
				var/ammo_count = 0
				for(var/obj/item/quiver/sling/iron/quiver in delivered)
					ammo_count++
				LEVY_EXPECT_EQUAL(ammo_count, 2, "Both ammunition quivers survive the shield choice.")
			// All listed tools, consumables and secondary weapons must remain on the character.
			for(var/item_path in kit.backpack_contents)
				var/item_count = 0
				for(var/obj/item/I in delivered)
					if(I.type == item_path && istype(I.loc, /obj/item/storage))
						item_count++
				LEVY_EXPECT(item_count >= kit.backpack_contents[item_path], "No kit items are lost: [item_path] in [context]")
			qdel(H)
			CHECK_TICK
	var/datum/skill/smithing = GetSkillRef(/datum/skill/craft/weaponsmithing)
	TEST_ASSERT_EQUAL(smithing.trait_uncap[TRAIT_SELF_RELIANCE], SKILL_LEVEL_JOURNEYMAN, "Crafting caps recognize Self-Reliance.")
	var/datum/skill/mining = GetSkillRef(/datum/skill/labor/mining)
	TEST_ASSERT_EQUAL(mining.trait_uncap[TRAIT_SELF_RELIANCE], SKILL_LEVEL_JOURNEYMAN, "Labor caps recognize Self-Reliance.")
	var/mob/living/carbon/human/default_H = make_levyman()
	var/datum/outfit/job/roguetown/levy/default_kit = new
	allocated += default_kit
	TEST_ASSERT_EQUAL(default_kit.choose_weapon(default_H), weapons[1], "Cancelling weapon selection yields a complete deterministic kit.")
	TEST_ASSERT_EQUAL(default_kit.choose_background(default_H), backgrounds[1], "Cancelling occupation selection yields a complete deterministic kit.")

/datum/unit_test/levy_mechanics/Run()
	var/mob/living/carbon/human/consistent/H = allocate(/mob/living/carbon/human/consistent)
	H.gender = MALE
	H.set_species(/datum/species/human/northern)
	H.mind = new /datum/mind()
	allocated += H.mind
	H.mind.current = H
	var/mob/living/carbon/human/consistent/buddy = allocate(/mob/living/carbon/human/consistent)
	var/turf/target = get_turf(H)
	TEST_ASSERT(!H.can_levy_callout(target), "Outsiders cannot call out.")
	ADD_TRAIT(buddy, TRAIT_LEVY, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!H.can_levy_callout(target), "Standing near a Levy does not give outsiders callouts.")
	ADD_TRAIT(H, TRAIT_LEVY, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(H.can_levy_callout(target), "Two conscious levymen can coordinate.")
	buddy.stat = DEAD
	TEST_ASSERT(!H.can_levy_callout(target), "A dead teammate does not unlock cooperation.")
	buddy.stat = CONSCIOUS
	H.mob_timers["contact_callout"] = world.time
	TEST_ASSERT(!H.can_levy_callout(target), "The ten-second callout cooldown is enforced.")
	H.mob_timers["contact_callout"] = world.time - 10 SECONDS
	TEST_ASSERT(H.can_levy_callout(target), "Callouts become available when the cooldown ends.")
	H.cmode = FALSE
	TEST_ASSERT(findtext(H.get_levy_callout_message(buddy), "paces"), "A conscious person receives a noncombat callout.")
	TEST_ASSERT(!findtext(H.get_levy_callout_message(buddy), buddy.real_name), "A callout does not reveal a human target's hidden name.")
	H.cmode = TRUE
	H.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(findtext(H.get_levy_callout_message(buddy), "CHEST"), "A combat callout identifies the selected body zone.")
	TEST_ASSERT(findtext(H.get_levy_callout_message(target), "Move there!"), "Terrain receives a movement callout in combat.")
	H.STASPD = 10
	H.STALUC = 10
	TEST_ASSERT_EQUAL(H.get_wild_leech_avoidance(), 0, "Outsiders retain normal leech exposure.")
	ADD_TRAIT(H, TRAIT_LEECHRESIST, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(H.get_wild_leech_avoidance(), 20, "Donor baseline avoidance is twenty percent.")
	H.STASPD = 20
	TEST_ASSERT_EQUAL(H.get_wild_leech_avoidance(), 100, "Avoidance is capped at one hundred.")
	TEST_ASSERT(H.avoids_wild_leech(), "Guaranteed avoidance prevents environmental attachment.")
	H.STASPD = 0
	H.STALUC = 0
	TEST_ASSERT_EQUAL(H.get_wild_leech_avoidance(), 0, "Avoidance never becomes negative.")
	var/obj/item/bodypart/chest = H.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/natural/worms/leech/leech = new(H)
	allocated += leech
	chest.add_embedded_object(leech, silent = TRUE)
	var/original_damage = chest.brute_dam
	var/obj/item/grabbing/grab = allocate(/obj/item/grabbing)
	H.put_in_hands(grab)
	grab.grabbed = H
	grab.limb_grabbed = chest
	grab.sublimb_grabbed = REF(leech)
	grab.removeembeddeditem(H)
	TEST_ASSERT(!(leech in chest.embedded_objects), "Leech removal actually detaches the parasite.")
	TEST_ASSERT_EQUAL(chest.brute_dam, original_damage, "Leech Awareness prevents removal injury.")
	REMOVE_TRAIT(H, TRAIT_LEECHRESIST, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/natural/worms/leech/ordinary_leech = new(H)
	allocated += ordinary_leech
	chest.add_embedded_object(ordinary_leech, silent = TRUE)
	var/obj/item/grabbing/ordinary_grab = allocate(/obj/item/grabbing)
	H.put_in_hands(ordinary_grab)
	ordinary_grab.grabbed = H
	ordinary_grab.limb_grabbed = chest
	ordinary_grab.sublimb_grabbed = REF(ordinary_leech)
	ordinary_grab.removeembeddeditem(H)
	TEST_ASSERT(chest.brute_dam > original_damage, "Ordinary hosts still receive native extraction damage.")
	var/obj/item/rogueweapon/mace/woodclub/militia/club = allocate(/obj/item/rogueweapon/mace/woodclub/militia)
	var/datum/intent/mace/demolish/demolish = new
	allocated += demolish
	H.used_intent = demolish
	var/obj/structure/table/table = allocate(/obj/structure/table)
	table.max_integrity = 200
	table.obj_integrity = 200
	TEST_ASSERT(club.demolish_structure(table, H), "Demolish can damage ordinary structures.")
	TEST_ASSERT_EQUAL(table.obj_integrity, 170, "Demolish deals fifteen percent of maximum integrity.")
	table.max_integrity = 3001
	table.obj_integrity = 3001
	TEST_ASSERT(!club.demolish_structure(table, H), "Overly strong structures resist Demolish.")
	TEST_ASSERT_EQUAL(table.obj_integrity, 3001, "Rejected targets receive no bonus damage.")
	var/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog/slingshot = allocate(/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog)
	slingshot.update_icon()
	TEST_ASSERT_EQUAL(slingshot.icon_state, "altsling", "Empty slingshot retains its own sprite.")
	var/obj/item/ammo_casing/caseless/rogue/sling_bullet/ammo = new(slingshot)
	allocated += ammo
	slingshot.chambered = ammo
	slingshot.update_icon()
	TEST_ASSERT_EQUAL(slingshot.icon_state, "altsling_ready", "Loaded slingshot retains its own sprite.")
	slingshot.chambered = null
	slingshot.update_icon()
	TEST_ASSERT_EQUAL(slingshot.icon_state, "altsling", "Unloading restores the correct sprite.")

#undef LEVY_EXPECT
#undef LEVY_EXPECT_EQUAL
#undef LEVY_EXPECT_NOTNULL
