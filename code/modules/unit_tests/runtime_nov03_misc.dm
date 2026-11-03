/// Character previews have no mind and must not grant spells, devotion or prompt for a class.
/datum/unit_test/runtime_toiler_preview/Run()
	var/mob/living/carbon/human/dummy/preview = allocate(/mob/living/carbon/human/dummy)
	var/datum/outfit/job/wretch/wretchedtoiler/outfit = new
	allocated += outfit
	TEST_ASSERT_NULL(preview.mind, "The preview fixture must not have a player's mind.")
	var/runtimes_before = GLOB.total_runtimes
	outfit.equip(preview, visualsOnly = TRUE)
	TEST_ASSERT(istype(preview.belt, /obj/item/storage/belt/rogue/leather), "Previewing the outfit must still equip the shared visible loadout.")
	TEST_ASSERT_NULL(preview.devotion, "An outfit preview must not create a devotion datum.")
	TEST_ASSERT(!length(preview.mob_spell_list), "An outfit preview must not grant gameplay spells.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The mindless outfit preview must complete without a runtime.")

/// A dead mount can outlive its owner's body; the death signal must tolerate an expired weakref.
/datum/unit_test/runtime_precious_mount_owner/Run()
	var/mob/living/carbon/human/owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/simple_animal/hostile/retaliate/rogue/goat/tame/mount = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/goat/tame)
	var/datum/component/precious_creature/bond = mount.AddComponent(/datum/component/precious_creature, owner)
	TEST_ASSERT(bond, "The mount must receive its bond before the death signal.")
	var/runtimes_before = GLOB.total_runtimes
	SEND_SIGNAL(mount, COMSIG_MOB_DEATH, FALSE)
	TEST_ASSERT(owner.has_stress_event(/datum/stressevent/precious_mob_died), "A surviving owner must still grieve their mount.")
	qdel(owner)
	TEST_ASSERT_NULL(bond.owner.resolve(), "The mount's owner weakref must expire after body deletion.")
	SEND_SIGNAL(mount, COMSIG_MOB_DEATH, FALSE)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The death signal must not call add_stress on a deleted owner.")

/// Exercise WEEP's actual delay: a wound can heal or move to somebody else before transfer.
/datum/unit_test/runtime_weep_wound_lifetime/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/invoked/psydonlux_tamper/spell = allocate(/obj/effect/proc_holder/spell/invoked/psydonlux_tamper)
	var/obj/item/bodypart/patient_arm = patient.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/other_arm = other_patient.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/caster_arm = caster.get_bodypart(BODY_ZONE_R_ARM)
	var/runtimes_before = GLOB.total_runtimes
	var/datum/wound/slash/small/healed = new
	allocated += healed
	healed.apply_to_bodypart(patient_arm, silent = TRUE)
	QDEL_IN(healed, 1)
	world.PushUsr(caster, CALLBACK(src, PROC_REF(cast_weep), spell, patient, caster))
	TEST_ASSERT(QDELETED(healed), "The wound must be healed while WEEP is waiting.")
	TEST_ASSERT(!length(caster.get_wounds()), "An already healed wound must not be recreated on the caster.")

	var/datum/wound/slash/small/transferred = new
	allocated += transferred
	transferred.apply_to_bodypart(patient_arm, silent = TRUE)
	addtimer(CALLBACK(transferred, TYPE_PROC_REF(/datum/wound, apply_to_bodypart), other_arm, TRUE), 1)
	world.PushUsr(caster, CALLBACK(src, PROC_REF(cast_weep), spell, patient, caster))
	TEST_ASSERT_EQUAL(transferred.bodypart_owner, other_arm, "WEEP must not steal a wound that left its selected patient during the delay.")
	TEST_ASSERT(!length(caster.get_wounds()), "A wound belonging to another patient must not reach the caster.")

	var/datum/wound/slash/small/remaining = new
	allocated += remaining
	remaining.apply_to_bodypart(patient_arm, silent = TRUE)
	world.PushUsr(caster, CALLBACK(src, PROC_REF(cast_weep), spell, patient, caster))
	TEST_ASSERT_EQUAL(remaining.bodypart_owner, caster_arm, "A wound that remains on the patient must still transfer normally.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Concurrent wound healing and transfer must not produce runtimes.")

/datum/unit_test/runtime_weep_wound_lifetime/proc/cast_weep(obj/effect/proc_holder/spell/invoked/psydonlux_tamper/spell, mob/living/carbon/human/patient, mob/living/carbon/human/caster)
	// Refunds use usr just as they do when this cast is invoked by the spell's player action.
	return spell.cast(list(patient), caster)

/// Replacing a turf keeps old turf references pointing at the new type.
/datum/unit_test/runtime_pollution_replaced_turf
	var/turf/changed_turf
	var/original_type
	var/original_baseturfs

/datum/unit_test/runtime_pollution_replaced_turf/Destroy()
	if(changed_turf)
		changed_turf.ChangeTurf(original_type, original_baseturfs)
	return ..()

/datum/unit_test/runtime_pollution_replaced_turf/Run()
	changed_turf = run_loc_floor_bottom_left
	original_type = changed_turf.type
	original_baseturfs = islist(changed_turf.baseturfs) ? changed_turf.baseturfs.Copy() : changed_turf.baseturfs
	var/datum/pollution/cloud = new(changed_turf)
	allocated += cloud
	var/obj/effect/abstract/pollution/overlay = allocate(/obj/effect/abstract/pollution)
	cloud.managed_overlay = overlay
	changed_turf.vis_contents += overlay
	SSpollution.active_pollution[cloud] = TRUE
	SSpollution.current_run[cloud] = TRUE
	SSpollution.processed_this_run[cloud] = TRUE
	var/runtimes_before = GLOB.total_runtimes
	changed_turf = changed_turf.ChangeTurf(/turf/closed/wall/mineral/rogue/stone)
	TEST_ASSERT(isclosedturf(cloud.my_turf), "The old pollution reference must now point at the replacement wall.")
	qdel(cloud)
	TEST_ASSERT_NULL(cloud.my_turf, "Deleted pollution must release its turf reference.")
	TEST_ASSERT(QDELETED(overlay), "The last pollution overlay must be deleted during cleanup.")
	TEST_ASSERT(!(cloud in SSpollution.all_polution) && !(cloud in SSpollution.active_pollution), "Deleted pollution must leave the registered and active collections.")
	TEST_ASSERT(!(cloud in SSpollution.current_run) && !(cloud in SSpollution.processed_this_run), "Deleted pollution must leave both processing collections.")
	TEST_ASSERT(cloud.gc_destroyed != GC_CURRENTLY_BEING_QDELETED, "Cleanup must return to qdel instead of aborting inside Destroy.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Cleaning pollution after floor-to-wall replacement must not access missing fields.")

/// Characters with custom or obsolete job names can still have a social rank.
/datum/unit_test/runtime_social_rank_unknown_job/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/examiner = allocate(/mob/living/carbon/human/consistent)
	subject.job = "Nonexistent former profession for unit test"
	subject.social_rank = SOCIAL_RANK_PEASANT
	examiner.social_rank = SOCIAL_RANK_PEASANT
	var/runtimes_before = GLOB.total_runtimes
	world.PushUsr(examiner, CALLBACK(src, PROC_REF(read_social_rank), subject))
	TEST_ASSERT_EQUAL(subject.social_rank, SOCIAL_RANK_PEASANT, "Unknown job metadata must not change the subject's social standing.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Reading social rank must tolerate a job title missing from the job registry.")

/datum/unit_test/runtime_social_rank_unknown_job/proc/read_social_rank(mob/living/carbon/human/subject)
	subject.Topic("", list("social_strata" = "1"))
