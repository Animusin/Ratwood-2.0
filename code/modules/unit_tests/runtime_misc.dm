/// Successful waking removes the infection from inside its own tick callback.
/datum/unit_test/runtime_zombie_infection/Run()
	var/runtimes_before = GLOB.total_runtimes
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.mind_initialize()
	var/datum/antagonist/zombie/runtime_infection_wake/zombie = new
	allocated += zombie
	zombie.owner = human.mind
	LAZYADD(human.mind.antag_datums, zombie)
	var/datum/status_effect/zombie_infection/infection = human.apply_status_effect(/datum/status_effect/zombie_infection, -1, TRUE)
	TEST_ASSERT(infection, "A human must receive the infection before waking.")
	infection.tick()
	TEST_ASSERT(zombie.woke, "The infection tick must reach the zombie waking callback.")
	TEST_ASSERT(QDELETED(infection), "Waking must remove the infection exactly once.")
	TEST_ASSERT(!human.has_status_effect(/datum/status_effect/zombie_infection), "The removed infection must leave the status registry.")
	var/mob/living/unsupported = allocate(/mob/living)
	unsupported.apply_status_effect(/datum/status_effect/zombie_infection)
	TEST_ASSERT(!unsupported.has_status_effect(/datum/status_effect/zombie_infection), "Non-human hosts must reject infection without registering a deleted effect for processing.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Infection rejection and successful waking must not produce runtimes.")

/datum/antagonist/zombie/runtime_infection_wake
	var/woke = FALSE

/datum/antagonist/zombie/runtime_infection_wake/wake_zombie(infected_wake)
	woke = TRUE
	owner.current.remove_status_effect(/datum/status_effect/zombie_infection)

/// The parent process expires the effect and clears owner before returning to the subtype.
/datum/unit_test/runtime_dagger_expiration/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/huntingknife/knife = allocate(/obj/item/rogueweapon/huntingknife)
	human.put_in_active_hand(knife)
	var/original_speed = human.STASPD
	var/datum/status_effect/buff/dagger_boost/boost = human.apply_status_effect(/datum/status_effect/buff/dagger_boost, 1)
	TEST_ASSERT(boost, "Holding a dagger must allow the boost to be created.")
	var/runtimes_before = GLOB.total_runtimes
	boost.duration = world.time - 1
	boost.process()
	TEST_ASSERT(QDELETED(boost), "The normal process must expire the dagger boost.")
	TEST_ASSERT_EQUAL(human.STASPD, original_speed, "Expiry must restore the original speed.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Dagger expiry must not read its cleared owner.")

/datum/unit_test/runtime_condensed_light/Run()
	var/runtimes_before = GLOB.total_runtimes
	var/obj/item/flashlight/flare/light/orb = allocate(/obj/item/flashlight/flare/light)
	var/datum/looping_sound/torchloop/loop = orb.soundloop
	TEST_ASSERT_EQUAL(loop.parent, orb, "The condensed light sound loop must be attached to its orb.")
	TEST_ASSERT(loop.channel, "A correctly initialized loop must reserve its sound channel.")
	qdel(orb)
	TEST_ASSERT(QDELETED(loop), "Deleting the orb must release its looping sound.")
	TEST_ASSERT_NULL(loop.channel, "Deleting the loop must release its reserved channel.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Orb creation and destruction must not produce runtime warnings.")

/datum/unit_test/runtime_golden_spectacles/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.mind_initialize()
	human.adjust_skillrank_up_to(/datum/skill/craft/engineering, 2, TRUE)
	var/obj/item/clothing/mask/rogue/spectacles/golden/glasses = allocate(/obj/item/clothing/mask/rogue/spectacles/golden)
	var/runtimes_before = GLOB.total_runtimes
	glasses.equipped(human, SLOT_HEAD)
	TEST_ASSERT(glasses.active_item, "A skilled wearer with a mind must activate the spectacles.")
	TEST_ASSERT(human.mind.has_spell(/obj/effect/proc_holder/spell/invoked/engineeranalyze), "Active spectacles must grant their analyze spell.")
	glasses.dropped(human)
	TEST_ASSERT(!human.mind.has_spell(/obj/effect/proc_holder/spell/invoked/engineeranalyze), "Dropping spectacles must remove the granted spell.")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_SANDSTORM_GOGGLES), "Dropping spectacles must remove their sand protection.")
	glasses.equipped(human, SLOT_HEAD)
	qdel(human.mind)
	glasses.dropped(human)
	TEST_ASSERT(!glasses.active_item, "Spectacles must deactivate even after their wearer's mind is removed.")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_ENGINEERING_GOGGLES), "Mind loss must not leave the engineering trait behind on drop.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Dropping active spectacles after mind deletion must not produce runtimes.")

/datum/unit_test/runtime_apprentice_targets/Run()
	var/mob/living/carbon/human/teacher = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/invoked/takeapprentice/spell = allocate(/obj/effect/proc_holder/spell/invoked/takeapprentice)
	var/obj/item/item = allocate(/obj/item)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(spell.cast(list(item), teacher), FALSE, "Items must not be accepted as apprentices.")
	TEST_ASSERT_EQUAL(spell.cast(list(run_loc_floor_bottom_left), teacher), FALSE, "Turfs must not be accepted as apprentices.")
	TEST_ASSERT_EQUAL(spell.cast(list(), teacher), FALSE, "An empty target selection must be rejected.")
	TEST_ASSERT(!teacher.get_apprentice(), "Invalid targets must not create an apprenticeship.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Invalid apprentice targets must not reach mob-only methods.")

/datum/unit_test/runtime_spatial_speech_examine/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/mapless_source = new(null)
	allocated += mapless_source
	var/runtimes_before = GLOB.total_runtimes
	speaker.send_speech("A voice without a turf", source = mapless_source)
	speaker.examinate(mapless_source)
	qdel(mapless_source)
	speaker.examinate(mapless_source)
	speaker.examinate(null)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Mapless speech sources and missing examine targets must not reach turf coordinates or stale atom fields.")
