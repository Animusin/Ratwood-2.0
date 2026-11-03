/datum/runeritual/unit_test_cleanup
	blacklisted = TRUE
	required_atoms = list(/obj/item/magic/infernal/ash = 1)

/datum/runeritual/unit_test_cleanup/on_finished_recipe(mob/living/user, list/selected_atoms, turf/location)
	return TRUE

/// A completed rune must not retain its ingredients or unrelated objects from the range scan.
/datum/unit_test/ritual_releases_scanned_atoms/Run()
	var/obj/effect/decal/cleanable/roguerune/arcyne/enchantment/rune = allocate(/obj/effect/decal/cleanable/roguerune/arcyne/enchantment)
	rune.runesize = 0
	var/obj/item/magic/infernal/ash/ingredient = new(run_loc_floor_bottom_left)
	var/obj/item/magic/fae/dust/bystander = new(run_loc_floor_bottom_left)
	rune.invoke(list(), /datum/runeritual/unit_test_cleanup)
	TEST_ASSERT(QDELETED(ingredient), "A successful ritual must still consume its required ingredient.")
	TEST_ASSERT(!QDELETED(bystander), "Unselected items must survive the ritual.")
	TEST_ASSERT(refcount(ingredient) <= baseline_refs(), "The completed rune must not retain its consumed ingredient ([refcount(ingredient)] references; baseline [baseline_refs()]).")
	qdel(bystander)
	TEST_ASSERT(refcount(bystander) <= baseline_refs(), "A rune's range scan must not keep unrelated deleted items alive.")
	TEST_ASSERT_NULL(rune.selected_atoms, "Completed rituals must release their selection.")
	TEST_ASSERT_NULL(rune.pickritual, "Completed rituals must release their owned recipe datum.")

/// Missing components must not leave even partially selected ingredients pinned to the rune.
/datum/runeritual/unit_test_cleanup/missing
	required_atoms = list(/obj/item/magic/infernal/ash = 2)

/datum/unit_test/ritual_failure_releases_selection/Run()
	var/obj/effect/decal/cleanable/roguerune/arcyne/enchantment/rune = allocate(/obj/effect/decal/cleanable/roguerune/arcyne/enchantment)
	rune.runesize = 0
	var/obj/item/magic/infernal/ash/ingredient = new(run_loc_floor_bottom_left)
	rune.invoke(list(), /datum/runeritual/unit_test_cleanup/missing)
	TEST_ASSERT(!QDELETED(ingredient), "A failed ritual must preserve the supplied ingredient.")
	TEST_ASSERT_NULL(rune.selected_atoms, "Failed rituals must release the selection.")
	TEST_ASSERT_NULL(rune.pickritual, "Failed rituals must release the recipe datum.")
	qdel(ingredient)
	var/remaining_refs = refcount(ingredient)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "A failed rune must release partially selected ingredients ([remaining_refs] references; baseline [baseline_refs()]).")

/// Rune destruction owns the recipe, but must only release borrowed ingredients and results.
/datum/unit_test/ritual_destroy_releases_state/Run()
	var/obj/effect/decal/cleanable/roguerune/rune = allocate(/obj/effect/decal/cleanable/roguerune)
	var/obj/item/ingredient = allocate(/obj/item)
	var/mob/living/result = allocate(/mob/living)
	var/datum/runeritual/recipe = new /datum/runeritual/unit_test_cleanup
	rune.pickritual = recipe
	rune.selected_atoms = list(ingredient)
	rune.ritual_result = result
	qdel(rune)
	TEST_ASSERT(QDELETED(recipe), "Deleting a rune must delete its owned recipe datum.")
	TEST_ASSERT(!QDELETED(ingredient) && !QDELETED(result), "Deleting a rune must preserve borrowed ingredients and result mobs.")
	TEST_ASSERT_NULL(rune.selected_atoms, "Deleting a rune must release its ingredient list.")
	TEST_ASSERT_NULL(rune.ritual_result, "Deleting a rune must release the previous result.")
	TEST_ASSERT(refcount(recipe) <= baseline_refs(), "The destroyed rune must not retain its recipe datum.")

/// Replace only the modal input so the real invocation and cleanup paths remain under test.
/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection
	associated_ritual = /datum/runeritual/unit_test_cleanup
	runesize = 0
	var/prompt_count = 0
	var/locked_during_prompt = FALSE
	var/reentry_kept_recipe = FALSE
	var/delete_destination = FALSE
	var/destination_name = "Unit test teleport destination"

/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection/select_destination(mob/living/user, list/potential_runes)
	prompt_count++
	if(prompt_count > 1)
		return null
	locked_during_prompt = rune_in_use
	var/datum/runeritual/recipe_before = pickritual
	attack_hand(user)
	reentry_kept_recipe = pickritual == recipe_before && !QDELETED(recipe_before)
	if(delete_destination)
		qdel(potential_runes[destination_name])
		return destination_name
	return null

/datum/unit_test/ritual_teleport_cancel_releases_selection/Run()
	var/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection/rune = allocate(/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection)
	allocate(/obj/effect/decal/cleanable/roguerune/arcyne/teleport)
	var/obj/item/magic/infernal/ash/ingredient = allocate(/obj/item/magic/infernal/ash)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	user.adjust_skillrank(/datum/skill/magic/arcane, 1, TRUE)
	var/runtimes_before = GLOB.total_runtimes
	rune.invoke(list(user))
	TEST_ASSERT(rune.locked_during_prompt, "The teleport rune must remain locked while its destination prompt is open.")
	TEST_ASSERT_EQUAL(rune.prompt_count, 1, "A second click during selection must not start another invocation.")
	TEST_ASSERT(rune.reentry_kept_recipe, "An attempted second invocation must preserve the pending recipe.")
	TEST_ASSERT(!QDELETED(ingredient), "Cancelling teleport must not consume its ingredients.")
	TEST_ASSERT_NULL(rune.selected_atoms, "Cancelling teleport must release its selected ingredients.")
	TEST_ASSERT_NULL(rune.pickritual, "Cancelling teleport must release its recipe.")
	TEST_ASSERT(!rune.rune_in_use, "Cancelling teleport must unlock the rune for another attempt.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Cancelling or clicking a pending teleport must not produce runtimes.")

/datum/unit_test/ritual_teleport_deleted_destination/Run()
	var/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection/rune = allocate(/obj/effect/decal/cleanable/roguerune/arcyne/teleport/unit_test_selection)
	var/obj/effect/decal/cleanable/roguerune/arcyne/teleport/destination = allocate(/obj/effect/decal/cleanable/roguerune/arcyne/teleport)
	destination.listkey = rune.destination_name
	var/obj/item/magic/infernal/ash/ingredient = allocate(/obj/item/magic/infernal/ash)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	user.adjust_skillrank(/datum/skill/magic/arcane, 1, TRUE)
	rune.delete_destination = TRUE
	var/runtimes_before = GLOB.total_runtimes
	rune.invoke(list(user))
	TEST_ASSERT_EQUAL(rune.prompt_count, 1, "The test must reach destination selection.")
	TEST_ASSERT(!QDELETED(ingredient), "A destination deleted during selection must not consume ingredients.")
	TEST_ASSERT_NULL(rune.selected_atoms, "A vanished destination must release the pending selection.")
	TEST_ASSERT_NULL(rune.pickritual, "A vanished destination must release the pending recipe.")
	TEST_ASSERT(!rune.rune_in_use, "A vanished destination must unlock the source rune.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A deleted destination must not be dereferenced after the prompt.")
