/// Reading an unmodified stat must accept both empty and unallocated status lists.
/datum/unit_test/runtime_nov08_true_stat_without_effects/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/last_effect = subject.apply_status_effect(/datum/status_effect/debuff/badmeal)
	TEST_ASSERT_NOTNULL(last_effect, "The fixture must apply a real status before clearing the list.")
	var/list/effects = subject.status_effects.Copy()
	for(var/datum/status_effect/effect as anything in effects)
		qdel(effect)
	TEST_ASSERT(!length(subject.status_effects), "Removing all statuses must leave no active effects.")
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(subject.get_true_stat(STATKEY_SPD), subject.get_stat(STATKEY_SPD), "An unmodified stat must remain readable after the last effect is removed.")
	// status_effects is declared nullable; exercise that initial state after real effect cleanup.
	subject.status_effects = null
	TEST_ASSERT_EQUAL(subject.get_true_stat(STATKEY_SPD), subject.get_stat(STATKEY_SPD), "An unallocated status list must also preserve the unmodified stat.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Reading an unmodified stat must not dereference a null list.")

/// Food statuses have no stat modifier list, but must not interrupt either spell windup.
/datum/unit_test/runtime_nov08_windup_with_statless_effect/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.STASPD = 14
	var/datum/status_effect/meal = subject.apply_status_effect(/datum/status_effect/debuff/badmeal)
	TEST_ASSERT_NOTNULL(meal, "The fixture must apply the ordinary bad-meal status.")
	TEST_ASSERT_NULL(meal.effectedstats, "The reported nullable stat-list condition must be present.")
	var/runtimes_before = GLOB.total_runtimes
	for(var/effect_type in list(/datum/status_effect/swingdelay/penalty/committed, /datum/status_effect/swingdelay/disrupt))
		var/datum/status_effect/windup = subject.apply_status_effect(effect_type, 18, TRUE)
		TEST_ASSERT(!QDELETED(windup), "A food status must not abort creation of [effect_type].")
		TEST_ASSERT_EQUAL(subject.get_stat(STATKEY_SPD), 10, "The spell's real windup must still reduce unbuffed speed to ten.")
		TEST_ASSERT_EQUAL(windup.effectedstats[STATKEY_SPD], -4, "Windup must retain its ordinary speed penalty.")
		qdel(windup)
		TEST_ASSERT_EQUAL(subject.get_stat(STATKEY_SPD), 14, "Removing the windup must restore the original speed.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Statless food effects must not break committed or interruptible windups.")

/// Ignore beneficial bonuses without removing penalties or changing actual attributes.
/datum/unit_test/runtime_nov08_true_stat_preserves_penalties/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.STASPD = 14
	subject.apply_status_effect(/datum/status_effect/debuff/badmeal)
	var/datum/status_effect/bonus = subject.apply_status_effect(/datum/status_effect/buff/moondust)
	var/datum/status_effect/penalty = subject.apply_status_effect(/datum/status_effect/debuff/bleeding)
	TEST_ASSERT_NOTNULL(bonus, "The fixture must apply an ordinary positive speed bonus.")
	TEST_ASSERT_NOTNULL(penalty, "The fixture must apply an ordinary negative speed penalty.")
	TEST_ASSERT_EQUAL(subject.get_stat(STATKEY_SPD), 15, "The real modifiers must apply +2 and -1 speed before querying the base stat.")
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(subject.get_true_stat(STATKEY_SPD), 13, "Only the positive bonus must be excluded; the bleeding penalty remains.")
	TEST_ASSERT_EQUAL(subject.get_stat(STATKEY_SPD), 15, "Querying the true stat must not mutate the actual stat.")
	qdel(bonus)
	TEST_ASSERT_EQUAL(subject.get_true_stat(STATKEY_SPD), 13, "Without the buff, the remaining penalty must still be included.")
	qdel(penalty)
	TEST_ASSERT_EQUAL(subject.get_true_stat(STATKEY_SPD), 14, "Removing both modifiers must restore the original stat despite the statless food effect.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Mixed stat and statless effects must not cause a runtime.")
