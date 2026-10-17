/datum/advclass/levy
	name = "Levy"
	tutorial = "When the Bailiff came knocking for you, it was the worst dae of your lyfe. Hastily pressed into the Crown's service with little more than a helmet, a household tool turned weapon and a bottle of beer for comfort, you joined the Levy squad.<br><br>As one of the realm's so-called \"folk-heroes\", you are first to answer a peasant's reports of danger beyond the walls. Find the problem and solve it yourself or, if dire, send word for backup, and hold the line until the Armsmen or Wardens arrive to earn their keep."
	allowed_sexes = list(MALE, FEMALE)
	allowed_races = ACCEPTED_RACES

	outfit = /datum/outfit/job/roguetown/levy
	traits_applied = list(TRAIT_LEVY, TRAIT_DECEIVING_MEEKNESS, TRAIT_LEECHRESIST, TRAIT_SELF_RELIANCE)
	cmode_music = 'sound/music/cmode/towner/combat_towner2.ogg'
	category_tags = list(CTAG_VANGUARD)
	maximum_possible_slots = 5
	subclass_stats = list(
		STATKEY_CON = 1,
		STATKEY_STR = 1,
		STATKEY_WIL = 1,
		STATKEY_INT = -1,
	)
	subclass_skills = list(
		/datum/skill/combat/axes = SKILL_LEVEL_APPRENTICE,
		/datum/skill/combat/wrestling = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/combat/unarmed = SKILL_LEVEL_NOVICE,
		/datum/skill/misc/athletics = SKILL_LEVEL_APPRENTICE,
		/datum/skill/misc/swimming = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/misc/climbing = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/misc/reading = SKILL_LEVEL_NOVICE,
		/datum/skill/misc/hunting = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/crafting = SKILL_LEVEL_APPRENTICE,
		/datum/skill/craft/cooking = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/sewing = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/carpentry = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/craft/masonry = SKILL_LEVEL_APPRENTICE,
		/datum/skill/craft/blacksmithing = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/armorsmithing = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/weaponsmithing = SKILL_LEVEL_NOVICE,
		/datum/skill/labor/lumberjacking = SKILL_LEVEL_APPRENTICE,
		/datum/skill/labor/farming = SKILL_LEVEL_NOVICE,
		/datum/skill/labor/butchering = SKILL_LEVEL_APPRENTICE,
	)

/datum/outfit/job/roguetown/levy
	job_bitflag = BITFLAG_GARRISON
	id = /obj/item/scomstone/bad/garrison

/datum/outfit/job/roguetown/levy/pre_equip(mob/living/carbon/human/H)
	..()
	head = /obj/item/clothing/head/roguetown/helmet/kettle/iron
	neck = /obj/item/clothing/neck/roguetown/coif
	mask = /obj/item/clothing/head/roguetown/armingcap/levy
	cloak = /obj/item/clothing/cloak/stabard/bog/levy
	shirt = /obj/item/clothing/suit/roguetown/armor/gambeson
	wrists = /obj/item/clothing/wrists/roguetown/bracers/leather
	pants = /obj/item/clothing/under/roguetown/trou/leather
	shoes = /obj/item/clothing/shoes/roguetown/boots
	beltl = /obj/item/flashlight/flare/torch/lantern

	if(!H.mind)
		return
	var/weapon_choice = choose_weapon(H)
	if(QDELETED(H) || !H.mind)
		return
	apply_weapon(H, weapon_choice)
	var/background_choice = choose_background(H)
	if(QDELETED(H) || !H.mind)
		return
	apply_background(H, background_choice)
	LAZYINITLIST(backpack_contents)
	backpack_contents[/obj/item/storage/keyring/guard] = 1
	H.verbs |= /mob/proc/haltyell
	H.set_blindness(0)

/datum/outfit/job/roguetown/levy/proc/get_weapon_options()
	return list(
		"THE FAMILY SWORD (Sword)",
		"A BIG KNIFE (Dagger)",
		"THE LEGENDARY BOG-STICK (Club)",
		"THE BOGMAN'S BOW (Sling)",
		"AN OLDE CATTLE LASH (Whip)",
		"THE FINEST PITCHFORK (Polearm)",
		"MINE THRESHER (Flail)",
		"A GOOD SHOVEL (Axe)",
		"THE MINER'S PICKAXE (Pickaxe)",
		"MINE SCYTHE (Scythe)",
		"THE RELIABLE VOLFKILLER (Staff)",
		"THE WHOLE KITCHEN (Mess Kit + Cleaver)",
		"THESE GODS-GIVEN FISTS (Unarmed)",
	)

/datum/outfit/job/roguetown/levy/proc/get_background_options()
	return list(
		"UNEMPLOYED, SER!!",
		"A HOMESTEADER, SER!!",
		"A COOKER-DOC, SER!!",
		"A THUG, SER!!",
		"A SCAVENGER, SER!!",
		"A BATHMAID, SER!!",
		"ALMOST A SQUIRE, SER!!",
		"ALMOST AN ARMSMAN, SER!!"
	)

/datum/outfit/job/roguetown/levy/proc/choose_weapon(mob/living/carbon/human/H)
	var/list/options = get_weapon_options()
	var/choice = tgui_input_list(H, "Choose the household weapon you brought into service. Your chosen weapon skill starts at Expert.", "Levy - Weapon", options)
	return (choice in options) ? choice : options[1]

/datum/outfit/job/roguetown/levy/proc/choose_background(mob/living/carbon/human/H)
	var/list/options = get_background_options()
	var/choice = tgui_input_list(H, "Choose your former occupation. Select an option to see its details.", "Levy - Background", options, strict_modern = TRUE, descriptions = get_background_descriptions())
	return (choice in options) ? choice : options[1]

/datum/outfit/job/roguetown/levy/proc/get_background_descriptions()
	return list(
		"UNEMPLOYED, SER!!" = "Traits: None.\nFinal Stats: +1 CON, +1 STR, +1 WIL, -1 INT, +1 LCK.\nSkills: No extras.\nEquipment: Satchel, Rope, Signal Horn, 4x Beer.",
		"A HOMESTEADER, SER!!" = "Traits: Jack of All Trades, Homestead Expert, Smithing Expert, Survival Expert.\nFinal Stats: +1 CON, +1 STR, +1 WIL, +3 INT, +1 SPD, -1 LCK.\nSkills: No extras.\nEquipment: Backpack, Small Shovel, Stone Hammer, Chisel, Handsaw, Hoe, Hunting Knife, Rope, Poor Coin Pouch, Signal Horn, Beer, Broom, Coal.",
		"A COOKER-DOC, SER!!" = "Traits: Medicine Expert, Cicerone.\nFinal Stats: +3 INT, +2 SPD, -1 LCK.\nSkills: Medicine (Expert), Cooking (Journeyman), Alchemy (Apprentice). Knows Secular Diagnose.\nEquipment: Backpack, Bedroll, Signal Horn, Hunting Knife, Rope, Beer, Bottle Kit, Calendula Seeds, Field Medicine Recipe, Surgery Bag, Folding Alchemy Cauldron, Coal.",
		"A THUG, SER!!" = "Traits: No Pain Stun, Steelhearted. Knows Thieves' Cant.\nFinal Stats: +2 STR, +2 CON, +1 WIL, -1 SPD, -1 INT, -1 LCK.\nSkills: Athletics (Journeyman), Maces (Apprentice).\nEquipment: Satchel, Cudgel, Signal Horn, Hunting Knife, 2x Beer.",
		"A SCAVENGER, SER!!" = "Traits: Dodge Expert, Graverobber.\nFinal Stats: -1 CON, +1 STR, +1 WIL, -1 INT, +3 SPD, -1 LCK.\nSkills: Sneaking (Journeyman), Knives (Journeyman), Sewing (Journeyman), Smelting (Journeyman).\nEquipment: Backpack, Combat Knife, Small Shovel, Scissors, Signal Horn, Beer, Rope, 2x Coal, Iron Ore, Tongs.",
		"A BATHMAID, SER!!" = "Traits: Empath, Good Lover, Nutcracker. Knows Thieves' Cant.\nFinal Stats: +2 SPD, -1 INT, +1 LCK.\nSkills: Medicine (Novice), Lockpicking (Journeyman), Sneaking (Journeyman), Riding (Master).\nEquipment: Satchel, Bath Soap, Gold Hairpin, Signal Horn, Beer, Rope.",
		"ALMOST A SQUIRE, SER!!" = "Traits: Squire Repair, Expert Hunter.\nFinal Stats: +1 CON, +1 STR, +1 WIL, -1 INT, +1 SPD, -1 PER, -1 LCK.\nSkills: No extras.\nEquipment: Satchel, Rich Coin Pouch, Stone Hammer, Polishing Cream, Armor Brush, Signal Horn, Needle.",
		"ALMOST AN ARMSMAN, SER!!" = "Traits: Guardsman, Steelhearted.\nFinal Stats: +2 CON, +1 STR, +2 WIL, -1 INT, -1 PER, -1 LCK.\nSkills: Shields (Journeyman).\nEquipment: Heater Shield, Backpack, Beltpack, Chain, Signal Horn, Hunting Knife, Health Potion, Beer.",
	)

/datum/outfit/job/roguetown/levy/proc/apply_weapon(mob/living/carbon/human/H, weapon_choice)
	if(!(weapon_choice in get_weapon_options()))
		return FALSE
	switch(weapon_choice)

		if ("THE FAMILY SWORD (Sword)")
			H.adjust_skillrank_up_to(/datum/skill/combat/swords, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/sword/falchion/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			backr = /obj/item/rogueweapon/scabbard/sword
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THE LEGENDARY BOG-STICK (Club)")
			H.adjust_skillrank_up_to(/datum/skill/combat/maces, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/mace/woodclub/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("AN OLDE CATTLE LASH (Whip)")
			H.adjust_skillrank_up_to(/datum/skill/combat/whipsflails, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/whip
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if("THE FINEST PITCHFORK (Polearm)")
			H.adjust_skillrank_up_to(/datum/skill/combat/polearms, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/spear/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			backr = /obj/item/rogueweapon/scabbard/gwstrap
			beltr = /obj/item/rogueweapon/pick/bronze

		if("MINE THRESHER (Flail)")
			H.adjust_skillrank_up_to(/datum/skill/combat/whipsflails, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/flail/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("A GOOD SHOVEL (Axe)")
			H.adjust_skillrank_up_to(/datum/skill/combat/axes, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/greataxe/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			backr = /obj/item/rogueweapon/scabbard/gwstrap
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THE MINER'S PICKAXE (Pickaxe)")
			H.adjust_skillrank_up_to(/datum/skill/labor/mining, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/pick/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("MINE SCYTHE (Scythe)")
			H.adjust_skillrank_up_to(/datum/skill/labor/farming, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/rogueweapon/scythe/militia
			gloves = /obj/item/clothing/gloves/roguetown/leather
			backr = /obj/item/rogueweapon/scabbard/gwstrap
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("A BIG KNIFE (Dagger)")
			H.adjust_skillrank_up_to(/datum/skill/combat/knives, SKILL_LEVEL_EXPERT, TRUE)
			l_hand = /obj/item/rogueweapon/huntingknife/idagger
			backr = /obj/item/rogueweapon/scabbard/sheath
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THE WHOLE KITCHEN (Mess Kit + Cleaver)")
			H.adjust_skillrank_up_to(/datum/skill/craft/cooking, SKILL_LEVEL_EXPERT, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/combat/knives, SKILL_LEVEL_EXPERT, TRUE)
			r_hand = /obj/item/storage/gadget/messkit
			l_hand = /obj/item/rogueweapon/huntingknife/cleaver
			gloves = /obj/item/clothing/gloves/roguetown/leather
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THE BOGMAN'S BOW (Sling)")
			H.adjust_skillrank_up_to(/datum/skill/combat/slings, SKILL_LEVEL_EXPERT, TRUE)
			gloves = /obj/item/clothing/gloves/roguetown/leather
			r_hand = /obj/item/quiver/sling/iron
			l_hand = /obj/item/quiver/sling/iron
			backr = /obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THE RELIABLE VOLFKILLER (Staff)")
			H.adjust_skillrank_up_to(/datum/skill/combat/polearms, SKILL_LEVEL_EXPERT, TRUE)
			gloves = /obj/item/clothing/gloves/roguetown/leather
			backr = /obj/item/rogueweapon/woodstaff/quarterstaff/iron
			beltr = /obj/item/rogueweapon/pick/bronze

		if ("THESE GODS-GIVEN FISTS (Unarmed)")
			ADD_TRAIT(H, TRAIT_CIVILIZEDBARBARIAN, TRAIT_GENERIC)
			H.adjust_skillrank_up_to(/datum/skill/combat/unarmed, SKILL_LEVEL_EXPERT, TRUE)
			gloves = /obj/item/clothing/gloves/roguetown/bandages/pugilist
			beltr = /obj/item/rogueweapon/pick/bronze
	return TRUE

/datum/outfit/job/roguetown/levy/proc/apply_background(mob/living/carbon/human/H, specialty_choice)
	if(!(specialty_choice in get_background_options()))
		return FALSE
	switch(specialty_choice)

		if("UNEMPLOYED, SER!!")
			H.change_stat(STATKEY_LCK, 1)
			belt = /obj/item/storage/belt/rogue/leather
			backl = /obj/item/storage/backpack/rogue/satchel
			backpack_contents = list(
				/obj/item/rope = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 4,
				/obj/item/signal_horn = 1,
				)

		if("A HOMESTEADER, SER!!")
			ADD_TRAIT(H, TRAIT_JACKOFALLTRADES, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_HOMESTEAD_EXPERT, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_SMITHING_EXPERT, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_SURVIVAL_EXPERT, TRAIT_GENERIC)
			H.change_stat(STATKEY_INT, 4)
			H.change_stat(STATKEY_SPD, 1)
			H.change_stat(STATKEY_LCK, -1)
			belt = /obj/item/storage/backpack/rogue/satchel/beltpack
			backl = /obj/item/storage/backpack/rogue/backpack
			backpack_contents = list(
				/obj/item/rogueweapon/shovel/small = 1,
				/obj/item/rogueweapon/hammer/stone = 1,
				/obj/item/rogueweapon/chisel = 1,
				/obj/item/rogueweapon/handsaw = 1,
				/obj/item/storage/belt/rogue/pouch/coins/poor = 1,
				/obj/item/rogueweapon/huntingknife = 1,
				/obj/item/rope = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 1,
				/obj/item/signal_horn = 1,
				/obj/item/rogueweapon/hoe = 1,
				/obj/item/broom = 1,
				/obj/item/rogueore/coal = 1,
				)

		if("A COOKER-DOC, SER!!")
			ADD_TRAIT(H, TRAIT_MEDICINE_EXPERT, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_CICERONE, TRAIT_GENERIC)
			H.mind.AddSpell(new /obj/effect/proc_holder/spell/invoked/diagnose/secular)
			H.adjust_skillrank_up_to(/datum/skill/misc/medicine, SKILL_LEVEL_EXPERT, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/craft/cooking, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/craft/alchemy, SKILL_LEVEL_APPRENTICE, TRUE)
			H.change_stat(STATKEY_INT, 4)
			H.change_stat(STATKEY_SPD, 2)
			H.change_stat(STATKEY_LCK, -1)
			H.change_stat(STATKEY_STR, -1)
			H.change_stat(STATKEY_WIL, -1)
			H.change_stat(STATKEY_CON, -1)
			belt = /obj/item/storage/backpack/rogue/satchel/beltpack
			backl = /obj/item/storage/backpack/rogue/backpack
			backpack_contents = list(
				/obj/item/bedroll = 1,
				/obj/item/signal_horn = 1,
				/obj/item/rogueweapon/huntingknife = 1,
				/obj/item/rope = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 1,
				/obj/item/bottle_kit = 1,
				/obj/item/herbseed/calendula = 1,
				/obj/item/paper/levy_field_medicine = 1,
				/obj/item/storage/belt/rogue/surgery_bag = 1,
				/obj/item/rogueore/coal = 1,
				/obj/item/folding_table_stored/alchcauldron = 1,
				)

		if("A THUG, SER!!")
			H.grant_language(/datum/language/thievescant)
			ADD_TRAIT(H, TRAIT_NOPAINSTUN, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_STEELHEARTED, TRAIT_GENERIC)
			H.adjust_skillrank_up_to(/datum/skill/misc/athletics, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/combat/maces, SKILL_LEVEL_APPRENTICE, TRUE)
			H.change_stat(STATKEY_STR, 1)
			H.change_stat(STATKEY_CON, 1)
			H.change_stat(STATKEY_SPD, -1)
			H.change_stat(STATKEY_LCK, -1)
			belt = /obj/item/storage/belt/rogue/leather
			backl = /obj/item/storage/backpack/rogue/satchel
			backpack_contents = list(
				/obj/item/rogueweapon/mace/cudgel = 1,
				/obj/item/signal_horn = 1,
				/obj/item/rogueweapon/huntingknife = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 2,
				)

		if("A SCAVENGER, SER!!")
			ADD_TRAIT(H, TRAIT_DODGEEXPERT, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_GRAVEROBBER, TRAIT_GENERIC)
			H.adjust_skillrank_up_to(/datum/skill/misc/sneaking, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/combat/knives, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/craft/sewing, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/craft/smelting, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.change_stat(STATKEY_CON, -2)
			H.change_stat(STATKEY_SPD, 3)
			H.change_stat(STATKEY_LCK, -1)
			belt = /obj/item/storage/backpack/rogue/satchel/beltpack
			backl = /obj/item/storage/backpack/rogue/backpack
			backpack_contents = list(
				/obj/item/rogueweapon/huntingknife/combat = 1,
				/obj/item/rogueweapon/huntingknife/scissors = 1,
				/obj/item/rogueweapon/shovel/small = 1,
				/obj/item/signal_horn = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 1,
				/obj/item/rope = 1,
				/obj/item/rogueore/coal = 2,
				/obj/item/rogueore/iron = 1,
				/obj/item/rogueweapon/tongs = 1,
				)

		if("A BATHMAID, SER!!")
			H.grant_language(/datum/language/thievescant)
			ADD_TRAIT(H, TRAIT_EMPATH, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_GOODLOVER, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_NUTCRACKER, TRAIT_GENERIC)
			H.adjust_skillrank_up_to(/datum/skill/misc/medicine, SKILL_LEVEL_NOVICE, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/misc/lockpicking, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/misc/sneaking, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.adjust_skillrank_up_to(/datum/skill/misc/riding, SKILL_LEVEL_MASTER, TRUE)
			H.change_stat(STATKEY_SPD, 2)
			H.change_stat(STATKEY_CON, -1)
			H.change_stat(STATKEY_STR, -1)
			H.change_stat(STATKEY_WIL, -1)
			H.change_stat(STATKEY_LCK, 1)
			belt = /obj/item/storage/belt/rogue/leather
			backl = /obj/item/storage/backpack/rogue/satchel
			backpack_contents = list(
				/obj/item/soap/bath = 1,
				/obj/item/lockpick/goldpin = 1,
				/obj/item/signal_horn = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 1,
				/obj/item/rope = 1,
				)

		if("ALMOST A SQUIRE, SER!!")
			ADD_TRAIT(H, TRAIT_SQUIRE_REPAIR, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_EXPERT_HUNTER, TRAIT_GENERIC)
			H.change_stat(STATKEY_SPD, 1)
			H.change_stat(STATKEY_PER, -1)
			H.change_stat(STATKEY_LCK, -1)
			belt = /obj/item/storage/belt/rogue/leather
			backl = /obj/item/storage/backpack/rogue/satchel
			backpack_contents = list(
				/obj/item/rogueweapon/hammer/stone = 1,
				/obj/item/polishing_cream = 1,
				/obj/item/armor_brush = 1,
				/obj/item/signal_horn = 1,
				/obj/item/storage/belt/rogue/pouch/coins/rich = 1,
				/obj/item/needle/thorn = 1,
				)

		if("ALMOST AN ARMSMAN, SER!!")
			ADD_TRAIT(H, TRAIT_GUARDSMAN, TRAIT_GENERIC)
			ADD_TRAIT(H, TRAIT_STEELHEARTED, TRAIT_GENERIC)
			H.adjust_skillrank_up_to(/datum/skill/combat/shields, SKILL_LEVEL_JOURNEYMAN, TRUE)
			H.change_stat(STATKEY_CON, 1)
			H.change_stat(STATKEY_WIL, 1)
			H.change_stat(STATKEY_PER, -1)
			H.change_stat(STATKEY_LCK, -1)
			belt = /obj/item/storage/backpack/rogue/satchel/beltpack
			backl = /obj/item/storage/backpack/rogue/backpack
			backpack_contents = list(
				/obj/item/rope/chain = 1,
				/obj/item/signal_horn = 1,
				/obj/item/rogueweapon/huntingknife = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/healthpotnew = 1,
				/obj/item/reagent_containers/glass/bottle/rogue/beer = 1,
				)
	if(specialty_choice == "ALMOST AN ARMSMAN, SER!!")
		// Retain the weapon carrier and give the shield a free hand instead of losing the bag.
		if(l_hand)
			if(!r_hand)
				r_hand = l_hand
			else
				backpack_contents[l_hand] = (backpack_contents[l_hand] ? backpack_contents[l_hand] : 0) + 1
		l_hand = /obj/item/rogueweapon/shield/heater
	return TRUE

/obj/item/paper/levy_field_medicine
	name = "Field Medicine Recipe"
	desc = "A field doctor's notes for the local healing brew."
	info = "<h3>Elixir of Health</h3>Unfold the cauldron, light its fuel and boil 20 ounces of water in the folding cauldron (30 ounces in a full-size cauldron). Add two different alchemical ingredients with the smell of sweet berries. Brew with Apprentice Alchemy or better, then bottle the medicine. Gather and process local herbs; use the bottle kit for spare glass."

// Character-setup preview: show the uniform without opening selection dialogs.
/datum/outfit/job/roguetown/levy/preview/pre_equip(mob/living/carbon/human/H)
	head = /obj/item/clothing/head/roguetown/helmet/kettle/iron
	neck = /obj/item/clothing/neck/roguetown/coif
	mask = /obj/item/clothing/head/roguetown/armingcap/levy
	cloak = /obj/item/clothing/cloak/stabard/bog/levy
	shirt = /obj/item/clothing/suit/roguetown/armor/gambeson
	wrists = /obj/item/clothing/wrists/roguetown/bracers/leather
	pants = /obj/item/clothing/under/roguetown/trou/leather
	shoes = /obj/item/clothing/shoes/roguetown/boots
	gloves = /obj/item/clothing/gloves/roguetown/leather
	belt = /obj/item/storage/belt/rogue/leather
	backl = /obj/item/storage/backpack/rogue/satchel
