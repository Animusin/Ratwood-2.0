/// Only replace the blocking player prompt; use the real spell target collection and validation.
/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention
	has_action = FALSE
	range = 0
	include_user = TRUE
	var/prompt_open = FALSE
	var/release_prompt = FALSE
	var/prompt_finished = FALSE
	var/caster_was_available = FALSE
	var/rejected_was_available = FALSE
	var/prompt_option_count = 0
	var/mob/living/rejected_target
	var/mob/living/selected_target
	var/mob/living/cast_target
	var/turf/prompt_move_destination
	var/delete_selected_target = FALSE
	var/cast_count = 0
	var/cancel_count = 0

/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/Destroy()
	rejected_target = null
	selected_target = null
	cast_target = null
	prompt_move_destination = null
	return ..()

/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/can_target(mob/living/target)
	return target != rejected_target

/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/prompt_target(mob/user, list/possible_targets)
	prompt_open = TRUE
	caster_was_available = (user in possible_targets)
	rejected_was_available = (rejected_target in possible_targets)
	prompt_option_count = length(possible_targets)
	while(!release_prompt)
		sleep(1)
	if(prompt_move_destination)
		selected_target.forceMove(prompt_move_destination)
	if(delete_selected_target)
		qdel(selected_target)
	prompt_finished = TRUE
	return selected_target

/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/revert_cast(mob/user)
	cancel_count++
	return

/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/perform(list/targets, recharge = TRUE, mob/user = usr)
	cast_count++
	cast_target = targets[1]

/datum/unit_test/spark_retention_pending_spell/proc/start_prompt(obj/effect/proc_holder/spell/targeted/spell, mob/living/caster)
	var/obj/effect/particle_effect/sparks/spark = new(caster.loc)
	var/reference = text_ref(spark)
	INVOKE_ASYNC(spell, TYPE_PROC_REF(/obj/effect/proc_holder/spell/targeted, choose_targets), caster)
	qdel(spark)
	return reference

/// A spell prompt can stay open indefinitely. Unrelated effects must be physically collected meanwhile.
/datum/unit_test/spark_retention_pending_spell/Run()
	var/mob/living/carbon/human/consistent/caster = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/spell = allocate(/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention)
	var/spark_reference = start_prompt(spell, caster)
	if(!spell.prompt_open || !spell.caster_was_available)
		Fail("The real target collection must reach a pending prompt with its living caster available.")
	sleep(10 SECONDS)
	if(locate(spark_reference))
		Fail("An unrelated spark is still retained by the pending spell target prompt after deletion and the garbage filter.")
	spell.release_prompt = TRUE
	sleep(2)
	if(!spell.prompt_finished)
		Fail("Cancelling the pending target prompt must finish normally.")
	if(spell.cast_count || spell.cancel_count != 1)
		Fail("Cancelling the target prompt must revert the spell without casting.")

/// Filtering must retain the old eligibility rules and revalidate the chosen mob after the prompt.
/datum/unit_test/spark_retention_target_selection/Run()
	var/mob/living/carbon/human/consistent/caster = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/allowed = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/rejected = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention/spell = allocate(/obj/effect/proc_holder/spell/targeted/unit_test_spark_retention)
	spell.release_prompt = TRUE
	spell.include_user = FALSE
	spell.selected_target = allowed
	spell.rejected_target = rejected
	spell.choose_targets(caster)
	TEST_ASSERT(!spell.caster_was_available && !spell.rejected_was_available && spell.prompt_option_count == 1, "The prompt must exclude the caster and mobs rejected by can_target().")
	TEST_ASSERT(spell.cast_count == 1 && spell.cast_target == allowed, "The eligible selected target must still receive the spell.")

	spell.include_user = TRUE
	spell.selected_target = caster
	spell.choose_targets(caster)
	TEST_ASSERT(spell.caster_was_available && spell.prompt_option_count == 2 && spell.cast_count == 2 && spell.cast_target == caster, "Spells that permit self-targeting must still include and select the caster.")

	spell.selected_target = allowed
	spell.prompt_move_destination = get_step(run_loc_floor_bottom_left, NORTH)
	spell.choose_targets(caster)
	TEST_ASSERT(spell.cast_count == 2 && spell.cancel_count == 1, "A target that left range during the prompt must cancel the cast.")

	allowed.forceMove(run_loc_floor_bottom_left)
	spell.prompt_move_destination = null
	spell.delete_selected_target = TRUE
	spell.choose_targets(caster)
	TEST_ASSERT(spell.cast_count == 2 && spell.cancel_count == 2, "A target deleted during the prompt must cancel the cast.")
