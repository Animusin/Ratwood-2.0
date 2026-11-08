/// Start the real sound loop and both singing effects without opening a song picker.
/datum/unit_test/proc/start_nov08_harpy_song(mob/living/carbon/human/singer)
	var/obj/item/organ/vocal_cords/harpy/cords = allocate(/obj/item/organ/vocal_cords/harpy)
	cords.Insert(singer, TRUE)
	var/obj/item/rogue/instrument/vocals/harpy_vocals/vocals = cords.vocals
	vocals.soundloop.set_mid_sounds(list('sound/music/instruments/vocalsf (1).ogg'))
	TEST_ASSERT(vocals.soundloop.start(singer), "The real singing sound loop must start.")
	vocals.playing = TRUE
	singer.apply_status_effect(/datum/status_effect/buff/playing_music, /datum/stressevent/music, "#ffffff")
	singer.apply_status_effect(/datum/status_effect/buff/harpy_sing)
	return cords

/datum/unit_test/runtime_nov08_harpy_normal_stop/Run()
	var/mob/living/carbon/human/singer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/vocal_cords/harpy/cords = start_nov08_harpy_song(singer)
	var/obj/item/rogue/instrument/vocals/harpy_vocals/vocals = cords.vocals
	var/datum/status_effect/buff/harpy_sing/singing = singer.has_status_effect(/datum/status_effect/buff/harpy_sing)
	var/runtimes_before = GLOB.total_runtimes
	singing.tick()
	TEST_ASSERT(vocals.playing && !vocals.soundloop.stopped, "An awake singer with intact vocal cords must keep singing.")
	singer.remove_status_effect(/datum/status_effect/buff/harpy_sing)
	TEST_ASSERT(!vocals.playing && vocals.soundloop.stopped, "Ending singing must stop the actual instrument and sound loop.")
	TEST_ASSERT_NULL(vocals.soundloop.channel, "Stopping singing must release its sound channel.")
	TEST_ASSERT(!singer.has_status_effect(/datum/status_effect/buff/playing_music), "Ending singing must remove its music effect.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Ordinary song cleanup must not cause runtimes.")

/datum/unit_test/runtime_nov08_harpy_removed_voice/Run()
	var/mob/living/carbon/human/singer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/vocal_cords/harpy/cords = start_nov08_harpy_song(singer)
	var/obj/item/rogue/instrument/vocals/harpy_vocals/vocals = cords.vocals
	var/datum/status_effect/buff/harpy_sing/singing = singer.has_status_effect(/datum/status_effect/buff/harpy_sing)
	var/runtimes_before = GLOB.total_runtimes
	singing.tick()
	cords.Remove(singer, TRUE)
	TEST_ASSERT_NULL(singer.getorganslot(ORGAN_SLOT_VOICE), "The original voice organ must actually be absent.")
	singer.remove_status_effect(/datum/status_effect/buff/harpy_sing)
	TEST_ASSERT(!vocals.playing && vocals.soundloop.stopped, "Removing singing after organ loss must still stop the detached instrument.")
	TEST_ASSERT_NULL(vocals.soundloop.channel, "A detached voice must return its sound channel.")
	TEST_ASSERT(!singer.has_status_effect(/datum/status_effect/buff/playing_music), "A missing voice must not leave the music effect running.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Song cleanup must not dereference the missing voice organ.")

/datum/unit_test/runtime_nov08_harpy_replaced_voice/Run()
	var/mob/living/carbon/human/singer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/vocal_cords/harpy/cords = start_nov08_harpy_song(singer)
	var/obj/item/rogue/instrument/vocals/harpy_vocals/vocals = cords.vocals
	var/datum/status_effect/buff/harpy_sing/singing = singer.has_status_effect(/datum/status_effect/buff/harpy_sing)
	var/obj/item/organ/vocal_cords/replacement = allocate(/obj/item/organ/vocal_cords)
	var/runtimes_before = GLOB.total_runtimes
	replacement.Insert(singer, TRUE)
	TEST_ASSERT(singer.getorganslot(ORGAN_SLOT_VOICE) == replacement, "The singer must now have ordinary replacement vocal cords.")
	singing.tick()
	TEST_ASSERT(QDELETED(singing), "Losing the singing organ must end its watchdog on the next tick.")
	TEST_ASSERT(!vocals.playing && vocals.soundloop.stopped, "Replacing the organ must stop the original voice rather than access vocals on its replacement.")
	TEST_ASSERT(!singer.has_status_effect(/datum/status_effect/buff/playing_music), "Replacing the voice must remove its obsolete music effect.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Ordinary replacement vocal cords must not be treated as harpy instruments.")

/datum/unit_test/runtime_nov08_harpy_destroyed_instrument/Run()
	var/mob/living/carbon/human/singer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/vocal_cords/harpy/cords = start_nov08_harpy_song(singer)
	var/datum/status_effect/buff/harpy_sing/singing = singer.has_status_effect(/datum/status_effect/buff/harpy_sing)
	var/runtimes_before = GLOB.total_runtimes
	qdel(cords.vocals)
	singing.tick()
	TEST_ASSERT(QDELETED(singing), "Deleting the hidden vocal instrument must end singing.")
	TEST_ASSERT(!singer.has_status_effect(/datum/status_effect/buff/playing_music), "A destroyed vocal instrument must not leave its music effect running.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The singing watchdog must safely handle an already deleted instrument.")

/datum/unit_test/runtime_nov08_harpy_sleep/Run()
	var/mob/living/carbon/human/singer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/vocal_cords/harpy/cords = start_nov08_harpy_song(singer)
	var/obj/item/rogue/instrument/vocals/harpy_vocals/vocals = cords.vocals
	var/datum/status_effect/buff/harpy_sing/singing = singer.has_status_effect(/datum/status_effect/buff/harpy_sing)
	var/runtimes_before = GLOB.total_runtimes
	singer.apply_status_effect(STATUS_EFFECT_SLEEPING, 10 SECONDS)
	singing.tick()
	TEST_ASSERT(QDELETED(singing), "Falling asleep must still end singing.")
	TEST_ASSERT(!vocals.playing && vocals.soundloop.stopped, "Sleeping must stop the actual vocal sound.")
	TEST_ASSERT(!singer.has_status_effect(/datum/status_effect/buff/playing_music), "Sleeping must remove the playing music effect.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Sleeping must not access the singing effect after removing it.")
