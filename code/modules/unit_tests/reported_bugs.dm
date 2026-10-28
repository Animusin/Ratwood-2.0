/// Lens destruction and overlapping sources must never make X-ray permanent.
/datum/unit_test/shimmering_lens_expiry/Run()
	var/mob/living/recipient = allocate(/mob/living)
	var/obj/item/clothing/ring/active/shimmeringlens/lens = allocate(/obj/item/clothing/ring/active/shimmeringlens)
	lens.activate(recipient)
	var/datum/status_effect/effect = recipient.has_status_effect(/datum/status_effect/shimmering_lens)
	TEST_ASSERT(effect, "The lens must grant a timed effect to its recipient.")
	qdel(lens)
	TEST_ASSERT(HAS_TRAIT(recipient, TRAIT_XRAY_VISION), "Losing the item must not prematurely cancel its duration.")
	effect.duration = world.time - 1
	effect.process()
	TEST_ASSERT(!HAS_TRAIT(recipient, TRAIT_XRAY_VISION), "The recipient's effect must expire even after the item is deleted, without usr.")

	ADD_TRAIT(recipient, TRAIT_XRAY_VISION, TRAIT_SOURCE_UNIT_TESTS)
	recipient.apply_status_effect(/datum/status_effect/shimmering_lens)
	recipient.remove_status_effect(/datum/status_effect/shimmering_lens)
	TEST_ASSERT(HAS_TRAIT(recipient, TRAIT_XRAY_VISION), "Expiry must preserve X-ray from unrelated sources.")
	REMOVE_TRAIT(recipient, TRAIT_XRAY_VISION, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/apprentice_basic_magic
	var/datum/mind/player

/datum/unit_test/apprentice_basic_magic/Destroy()
	player?.RemoveAllSpells()
	player = null
	return ..()

/datum/unit_test/apprentice_basic_magic/Run()
	var/mob/living/carbon/human/consistent/apprentice = allocate(/mob/living/carbon/human/consistent)
	var/datum/advclass/wapprentice/apprentice/subclass = new
	allocated += subclass
	for(var/trait in subclass.traits_applied)
		ADD_TRAIT(apprentice, trait, TRAIT_SOURCE_UNIT_TESTS)
	apprentice.mind_initialize()
	player = apprentice.mind
	player.mage_aspect_config = subclass.subclass_mage_aspects.Copy()
	player.ensure_mage_basics()
	TEST_ASSERT(player.has_spell(/datum/action/cooldown/spell/touch/prestidigitation), "Apprentices must receive Prestidigitation from their subclass configuration.")
	TEST_ASSERT(player.has_spell(/datum/action/cooldown/spell/conjure_arcyne_ward), "Apprentices must receive the ward enabled by their aspect configuration.")
	var/spell_count = length(player.spell_list)
	player.ensure_mage_basics()
	TEST_ASSERT_EQUAL(length(player.spell_list), spell_count, "Refreshing basics must not duplicate spells.")

// Suppress browser output while exercising the real purchase handler headlessly.
/obj/effect/proc_holder/spell/self/learnmiracle/unit_test/open_learn_ui(mob/living/carbon/human/H)
	return

/obj/effect/proc_holder/spell/self/learnmiracle/unit_test/proc/purchase(spell_path)
	return Topic(null, list("learnspell" = "[spell_path]"))

/datum/unit_test/noc_miracle_purchase
	var/datum/mind/player

/datum/unit_test/noc_miracle_purchase/Destroy()
	player?.RemoveAllSpells()
	player = null
	return ..()

/datum/unit_test/noc_miracle_purchase/Run()
	var/mob/living/carbon/human/consistent/cleric = allocate(/mob/living/carbon/human/consistent)
	cleric.mind_initialize()
	player = cleric.mind
	cleric.patron = new /datum/patron/divine/noc
	allocated += cleric.patron
	cleric.miracle_points = 100
	var/obj/effect/proc_holder/spell/self/learnmiracle/menu = allocate(/obj/effect/proc_holder/spell/self/learnmiracle/unit_test)
	var/spell_path = /datum/action/cooldown/spell/noc/spellpack
	TEST_ASSERT_EQUAL(get_spell_tier(spell_path), CLERIC_T3, "Action-based Noc miracles must retain their patron tier.")
	TEST_ASSERT("Noc" in get_spell_patron_names(spell_path), "Action-based miracles must retain patron ownership.")
	world.PushUsr(cleric, CALLBACK(menu, TYPE_PROC_REF(/obj/effect/proc_holder/spell/self/learnmiracle/unit_test, purchase), spell_path))
	TEST_ASSERT(player.has_spell(spell_path, TRUE), "The purchase must actually grant the new action-based miracle.")
	var/points_after_purchase = cleric.miracle_points
	TEST_ASSERT(points_after_purchase < 100, "A successful purchase must consume Miracle Points.")
	world.PushUsr(cleric, CALLBACK(menu, TYPE_PROC_REF(/obj/effect/proc_holder/spell/self/learnmiracle/unit_test, purchase), spell_path))
	TEST_ASSERT_EQUAL(cleric.miracle_points, points_after_purchase, "Buying an already learned action must not consume points.")
	var/list/buckets = menu._build_learn_buckets(cleric)
	var/found_learned = FALSE
	for(var/list/entry as anything in buckets["Noc"])
		if(entry["type"] == spell_path)
			found_learned = entry["learned"]
	TEST_ASSERT(found_learned, "The learning menu must recognize already owned action-based miracles.")
	TEST_ASSERT_EQUAL(get_spell_tier(/obj/effect/proc_holder/spell/invoked/blindness), CLERIC_T2, "Legacy miracles must retain their tiers too.")

/// A deterministic bow collaborator: test quiver bookkeeping through its normal attack interaction.
/obj/item/gun/ballistic/revolver/grenadelauncher/bow/unit_test/attackby(obj/item/ammunition, mob/user, params)
	if(istype(ammunition, /obj/item/ammo_casing/caseless/rogue/arrow))
		ammunition.forceMove(src)
		chambered = ammunition
		return TRUE
	return ..()

/datum/unit_test/quiver_last_arrow/Run()
	var/mob/living/carbon/human/consistent/archer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/quiver/quiver = allocate(/obj/item/quiver)
	var/obj/item/ammo_casing/caseless/rogue/arrow/iron/arrow = allocate(/obj/item/ammo_casing/caseless/rogue/arrow/iron)
	var/obj/item/gun/ballistic/revolver/grenadelauncher/bow/bow = allocate(/obj/item/gun/ballistic/revolver/grenadelauncher/bow/unit_test)
	quiver.eatarrow(arrow)
	TEST_ASSERT_EQUAL(quiver.icon_state, "quiver1", "Loading an arrow must show the full quiver.")
	quiver.attackby(bow, archer, null)
	TEST_ASSERT_EQUAL(length(quiver.arrows), 0, "Loading the bow must remove the final arrow.")
	TEST_ASSERT_EQUAL(arrow.loc, bow, "The bow must receive the arrow.")
	TEST_ASSERT_EQUAL(quiver.icon_state, "quiver0", "Drawing the final arrow into a bow must show the empty quiver.")

/datum/unit_test/greatweapon_strap_distance/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/scabbard/gwstrap/strap = allocate(/obj/item/rogueweapon/scabbard/gwstrap)
	var/obj/item/rogueweapon/mace/weapon = allocate(/obj/item/rogueweapon/mace)
	weapon.forceMove(strap)
	strap.sheathed = weapon
	strap.sheathe_time = 0.5 SECONDS
	var/turf/far_away = get_step(get_step(get_turf(user), NORTH), NORTH)
	addtimer(CALLBACK(user, TYPE_PROC_REF(/atom/movable, forceMove), far_away), 1)
	TEST_ASSERT(!strap.puke_sword(user), "Walking away from a floor strap must prevent remotely drawing its weapon.")
	TEST_ASSERT_EQUAL(weapon.loc, strap, "The distant weapon must stay inside its strap.")

	// The same movement must remain valid when the strap itself is carried.
	strap.forceMove(user)
	var/turf/back_again = run_loc_floor_bottom_left
	addtimer(CALLBACK(user, TYPE_PROC_REF(/atom/movable, forceMove), back_again), 1)
	TEST_ASSERT(strap.puke_sword(user), "Drawing from a carried strap while walking must still work.")
	TEST_ASSERT_EQUAL(weapon.loc, user, "A reachable weapon must be delivered to the user.")

/datum/unit_test/dropped_arcyne_ward/Run()
	var/mob/living/carbon/human/consistent/caster = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/roguetown/armor/manual/arcyne_ward/ward = allocate(/obj/item/clothing/suit/roguetown/armor/manual/arcyne_ward, caster)
	caster.skin_armor = ward
	ward.setup_ward(caster)
	ward.forceMove(get_turf(caster))
	ward.dropped(caster, TRUE)
	TEST_ASSERT(QDELETED(ward), "Dropping a ward during shapeshifting must not leave an invisible clothing item on the floor.")
	TEST_ASSERT_NULL(caster.skin_armor, "Dropping the ward must clear its protection from the old body.")

/datum/unit_test/conjured_spectacles_assets/Run()
	var/datum/action/cooldown/spell/conjure_spectacles/spell = new
	allocated += spell
	for(var/label in spell.spectacles)
		var/obj/item/clothing/mask/rogue/spectacles/item = allocate(spell.spectacles[label])
		TEST_ASSERT(item.icon_state in icon_states(item.icon), "[label] must have a visible inventory/world sprite.")
		TEST_ASSERT(item.icon_state in icon_states(item.mob_overlay_icon), "[label] must have a visible worn sprite.")
		TEST_ASSERT(item.slot_flags & ITEM_SLOT_MASK, "[label] must be wearable in the mask slot.")

/datum/unit_test/small_loincloth_assets/Run()
	var/obj/item/undies/loinclothunder/item = allocate(/obj/item/undies/loinclothunder)
	TEST_ASSERT(item.icon_state in icon_states(item.icon), "Removed Small Loincloth must have a visible world/hand sprite.")
	TEST_ASSERT_EQUAL(item.sprite_acc, /datum/sprite_accessory/underwear/loinclothunder, "Putting the garment back on must restore a loincloth, not default briefs.")

/datum/unit_test/tomato_slice_assets/Run()
	var/obj/item/reagent_containers/food/snacks/grown/fruit/tomato/tomato = allocate(/obj/item/reagent_containers/food/snacks/grown/fruit/tomato)
	var/obj/item/reagent_containers/food/snacks/grown/fruit/tomato_sliced/slice = allocate(tomato.slice_path)
	TEST_ASSERT(slice.icon_state in icon_states(slice.icon), "The result of slicing a tomato must reference an existing sprite.")
