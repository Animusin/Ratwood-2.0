/// Inspiration changes the effective rank without spending the XP already banked at the old rank.
/datum/unit_test/runtime_skill_progress_last_rank/Run()
	var/mob/living/carbon/human/consistent/artisan = allocate(/mob/living/carbon/human/consistent)
	artisan.mind_initialize()
	ADD_TRAIT(artisan, TRAIT_SMITHING_EXPERT, TRAIT_SOURCE_UNIT_TESTS)
	artisan.adjust_skillrank(/datum/skill/craft/blacksmithing, SKILL_LEVEL_EXPERT, TRUE)
	var/datum/sleep_adv/advancement = artisan.mind.sleep_adv
	advancement.sleep_exp[/datum/skill/craft/blacksmithing] = 395
	var/runtimes_before = GLOB.total_runtimes
	artisan.add_stress(/datum/stressevent/artistic_inspiration_minor)
	TEST_ASSERT_EQUAL(artisan.get_skill_level(/datum/skill/craft/blacksmithing), SKILL_LEVEL_MASTER, "Inspiration must raise the effective rank without spending the banked XP.")
	var/html = artisan.print_levels()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Opening skills with banked XP above the last attainable rank must not divide by zero.")
	TEST_ASSERT(findtext(html, ">100%</span>"), "Progress must stop at 100% when only Legendary remains, even with excess banked XP.")
	TEST_ASSERT_EQUAL(advancement.get_sleep_xp(/datum/skill/craft/blacksmithing), 395, "Rendering progress must never discard XP when a temporary bonus changes the thresholds.")
	artisan.remove_stress(/datum/stressevent/artistic_inspiration_minor)
	html = artisan.print_levels()
	TEST_ASSERT(findtext(html, ">150%</span>"), "The original progress must return when inspiration expires.")
	advancement.sleep_exp[/datum/skill/craft/blacksmithing] = 110
	html = artisan.print_levels()
	TEST_ASSERT(findtext(html, ">50%</span>"), "Ordinary progress to Master must still display 50% at 110 of 220 XP.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Opening skills before, during, and after inspiration must not divide by zero.")

/// Exercise the same outfit equip entry point used by update_preview_icon.
/datum/unit_test/runtime_shaman_preview/Run()
	var/mob/living/carbon/human/dummy/preview = allocate(/mob/living/carbon/human/dummy)
	// Preferences copy a playable species onto the dummy before equipping the preview.
	// Its initial abstract /human species is excluded by clothing's race check.
	preview.set_species(/datum/species/human/northern)
	preview.gender = MALE
	var/datum/outfit/job/roguetown/mercenary/atgervishaman/outfit = new
	allocated += outfit
	var/initial_intelligence = preview.STAINT
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_NULL(preview.client, "The preview fixture must not have a client to answer role-selection prompts.")
	var/obj/item/bodypart/preview_head = preview.get_bodypart(BODY_ZONE_HEAD)
	outfit.equip(preview, visualsOnly = TRUE)
	TEST_ASSERT(istype(preview.head, /obj/item/clothing/head/roguetown/helmet/leather/shaman_hood), "The preview must retain the shaman hood. head=[preview.head?.type], outfit.head=[outfit.head], head bodypart=[preview_head?.type], bodyparts=[length(preview.bodyparts)], species=[preview.dna?.species?.type], ears=[preview.ears?.type], armor=[preview.wear_armor?.type], inhumen=[HAS_TRAIT(preview, TRAIT_INHUMEN_ANATOMY)]")
	TEST_ASSERT(istype(preview.wear_armor, /obj/item/clothing/suit/roguetown/armor/leather/heavy/atgervi), "The preview must retain the shamanic coat.")
	TEST_ASSERT(istype(preview.gloves, /obj/item/clothing/gloves/roguetown/angle/gronnfur), "The preview must display the default claw loadout's gloves.")
	TEST_ASSERT_NULL(preview.devotion, "Previewing the shaman must not grant devotion.")
	TEST_ASSERT(!length(preview.mob_spell_list), "Previewing the shaman must not grant combat techniques.")
	TEST_ASSERT(!HAS_TRAIT(preview, TRAIT_DUALWIELDER), "Previewing the claw equipment must not apply its gameplay trait.")
	TEST_ASSERT_EQUAL(preview.STAINT, initial_intelligence, "Previewing the shaman must not change gameplay stats.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A clientless shaman preview must not reach input().")

/datum/unit_test/runtime_radial_late_click/Run()
	var/mob/living/user = allocate(/mob/living)
	var/datum/radial_menu/menu = new
	allocated += menu
	var/atom/movable/screen/radial/slice/slice = allocate(/atom/movable/screen/radial/slice)
	var/atom/movable/screen/radial/center/center = allocate(/atom/movable/screen/radial/center)
	slice.parent = menu
	center.parent = menu
	menu.elements += slice
	menu.close_button = center
	var/runtimes_before = GLOB.total_runtimes
	qdel(menu)
	TEST_ASSERT_NULL(slice.parent, "Destroying the menu must detach its slices before the queued click arrives.")
	TEST_ASSERT_NULL(center.parent, "Destroying the menu must detach its center before the queued click arrives.")
	world.PushUsr(user, CALLBACK(src, PROC_REF(click_button), slice))
	world.PushUsr(user, CALLBACK(src, PROC_REF(click_button), center))
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Queued clicks after menu destruction must not access the cleared parent.")

/datum/unit_test/runtime_radial_late_click/proc/click_button(atom/movable/screen/button)
	button.Click(null, "mapwindow.map", "left=1")

/// Observe real Click dispatch, including action deletion during its sound callback.
/datum/action/runtime_nov05_button
	var/trigger_count = 0

/datum/action/runtime_nov05_button/Trigger(trigger_flags)
	trigger_count++
	return TRUE

/mob/living/runtime_nov05_button_user
	var/datum/action/action_to_delete_on_sound

/mob/living/runtime_nov05_button_user/playsound_local(atom/turf_source, soundin, vol, vary, frequency, falloff, channel, pressure_affected = TRUE, sound/S, repeat, muffled)
	QDEL_NULL(action_to_delete_on_sound)

/datum/unit_test/runtime_action_late_click/Run()
	var/mob/living/runtime_nov05_button_user/user = allocate(/mob/living/runtime_nov05_button_user)
	var/datum/action/runtime_nov05_button/action = new(user)
	allocated += action
	action.Grant(user)
	var/atom/movable/screen/movable/action_button/button = allocate(/atom/movable/screen/movable/action_button)
	button.linked_action = action
	var/runtimes_before = GLOB.total_runtimes
	world.PushUsr(user, CALLBACK(src, PROC_REF(click_button), button))
	TEST_ASSERT_EQUAL(action.trigger_count, 1, "A live action's button must still trigger its action once.")
	qdel(button)
	user.next_click = 0
	world.PushUsr(user, CALLBACK(src, PROC_REF(click_button), button))
	TEST_ASSERT_EQUAL(action.trigger_count, 1, "A stale click must not trigger the former action of a destroyed button.")

	var/atom/movable/screen/movable/action_button/other_button = allocate(/atom/movable/screen/movable/action_button)
	other_button.linked_action = action
	user.action_to_delete_on_sound = action
	user.next_click = 0
	world.PushUsr(user, CALLBACK(src, PROC_REF(click_button), other_button))
	TEST_ASSERT(QDELETED(action), "The sound callback must delete the action after the initial permission check.")
	TEST_ASSERT_EQUAL(action.trigger_count, 1, "An action removed during Click must not be triggered afterward.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Queued or interrupted action clicks must not invoke a missing action.")

/datum/unit_test/runtime_action_late_click/proc/click_button(atom/movable/screen/movable/action_button/button)
	button.Click(null, "mapwindow.map", "left=1")

/// Capture only the transformed speaker's overlays, without requiring a connected test client.
/mob/living/carbon/human/consistent/runtime_nov05_listener
	var/runechat_enabled = TRUE
	var/hearing_enabled = TRUE
	var/parlor_messages = 0

/mob/living/carbon/human/consistent/runtime_nov05_listener/can_see_runechat(atom/movable/speaker)
	return runechat_enabled

/mob/living/carbon/human/consistent/runtime_nov05_listener/can_hear()
	return hearing_enabled

/mob/living/carbon/human/consistent/runtime_nov05_listener/create_chat_message(atom/movable/speaker, datum/language/message_language, raw_message, list/spans = list(), message_mode)
	if(istype(speaker, /obj/effect/dummy/parlor_trick))
		parlor_messages++

/datum/unit_test/runtime_parlor_runechat_recipients/Run()
	var/mob/living/carbon/human/consistent/speaker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/runtime_nov05_listener/listener = allocate(/mob/living/carbon/human/consistent/runtime_nov05_listener)
	var/obj/effect/dummy/parlor_trick/disguise = allocate(/obj/effect/dummy/parlor_trick)
	speaker.forceMove(disguise)
	TEST_ASSERT(npc in get_hearers_in_view(0, speaker), "The clientless NPC must be in the real speech recipient list.")
	TEST_ASSERT(listener in get_hearers_in_view(0, speaker), "The eligible listener must be in the real speech recipient list.")
	var/runtimes_before = GLOB.total_runtimes
	speaker.send_speech("First message", 0, speaker, spans = list(), message_language = /datum/language/common)
	TEST_ASSERT_EQUAL(listener.parlor_messages, 1, "Eligible listeners must still receive the disguise's speech overlay.")
	listener.runechat_enabled = FALSE
	speaker.send_speech("Second message", 0, speaker, spans = list(), message_language = /datum/language/common)
	TEST_ASSERT_EQUAL(listener.parlor_messages, 1, "Disabling runechat must also hide Parlor Trick's overlays.")
	listener.runechat_enabled = TRUE
	listener.hearing_enabled = FALSE
	speaker.send_speech("Third message", 0, speaker, spans = list(), message_language = /datum/language/common)
	TEST_ASSERT_EQUAL(listener.parlor_messages, 1, "Deaf listeners must not receive a separate Parlor Trick overlay.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Speaking while disguised must not construct chatmessages owned by clientless NPCs.")
