/// Both ordinary deletion and the conjured item's decay callback must release the spell's knife.
/datum/unit_test/runtime_nov06_aetherknife_item_cleanup/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/aetherknife/spell = allocate(/datum/action/cooldown/spell/aetherknife)
	spell.Grant(caster)
	var/runtimes_before = GLOB.total_runtimes
	for(var/use_decay in list(FALSE, TRUE))
		TEST_ASSERT(spell.cast(caster), "Aetherknife must still conjure a blade.")
		var/obj/item/knife = spell.conjured_knife
		TEST_ASSERT_NOTNULL(knife, "The spell must remember its conjured blade.")
		TEST_ASSERT(caster.is_holding(knife), "Aetherknife must still put its blade in a free hand.")
		if(use_decay)
			caster.dropItemToGround(knife)
			var/datum/component/conjured_item/conjuration = knife.GetComponent(/datum/component/conjured_item)
			TEST_ASSERT_NOTNULL(conjuration.decay_timer, "A dropped conjured knife must still schedule decay.")
			// Real decay happens after five minutes, long after the drop animation releases its reference.
			sleep(1 SECONDS)
			conjuration.dispel()
		else
			qdel(knife)
		TEST_ASSERT(QDELETED(knife), "Both destruction paths must delete the knife.")
		TEST_ASSERT_NULL(spell.conjured_knife, "Aetherknife must release a blade destroyed independently of its next cast.")
		TEST_ASSERT(refcount(knife) <= baseline_refs(), "A destroyed conjured knife must not be retained by its spell or deletion subscription (decay: [use_decay], refs: [refcount(knife)], baseline: [baseline_refs()]).")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Deleting and decaying conjured knives must not leave stale callbacks.")

/// Recasting replaces just the old knife, and forgetting the spell still dispels the replacement.
/datum/unit_test/runtime_nov06_aetherknife_recast_cleanup/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/aetherknife/spell = allocate(/datum/action/cooldown/spell/aetherknife)
	spell.Grant(caster)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(spell.cast(caster), "The initial Aetherknife cast must succeed.")
	var/obj/item/first = spell.conjured_knife
	TEST_ASSERT(spell.cast(caster), "Recasting Aetherknife must replace the first blade.")
	var/obj/item/replacement = spell.conjured_knife
	TEST_ASSERT(QDELETED(first), "Recasting must delete the previous knife.")
	TEST_ASSERT(replacement && replacement != first && !QDELETED(replacement), "Recasting must leave one live replacement knife.")
	TEST_ASSERT(refcount(first) <= baseline_refs(), "A replaced knife must not keep its old deletion subscription.")
	qdel(spell)
	TEST_ASSERT(QDELETED(replacement), "Forgetting Aetherknife must still dispel its current knife.")
	TEST_ASSERT_NULL(spell.conjured_knife, "A deleted spell must not retain its last knife.")
	TEST_ASSERT(refcount(replacement) <= baseline_refs(), "Forgetting Aetherknife must leave the knife collectable.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Recasting and forgetting Aetherknife must clean up without duplicate deletion callbacks.")

/// The reported ferramancy rapier must also be collectable after direct deletion or decay.
/datum/unit_test/runtime_nov06_form_blade_item_cleanup/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/form_blade/spell = allocate(/datum/action/cooldown/spell/form_blade)
	spell.form_index = 2
	spell.Grant(caster)
	var/runtimes_before = GLOB.total_runtimes
	for(var/use_decay in list(FALSE, TRUE))
		TEST_ASSERT(spell.cast(caster), "Form Blade must still conjure its selected weapon.")
		var/obj/item/weapon = spell.conjured_weapon
		TEST_ASSERT(istype(weapon, /obj/item/rogueweapon/sword/rapier/ferramancy), "Selecting Rapier must preserve the chosen weapon type.")
		TEST_ASSERT(caster.is_holding(weapon), "Form Blade must still put its weapon in a free hand.")
		if(use_decay)
			caster.dropItemToGround(weapon)
			var/datum/component/conjured_item/conjuration = weapon.GetComponent(/datum/component/conjured_item)
			TEST_ASSERT_NOTNULL(conjuration.decay_timer, "A dropped form weapon must still schedule decay.")
			// Real decay happens after five minutes, long after the drop animation releases its reference.
			sleep(1 SECONDS)
			conjuration.dispel()
		else
			qdel(weapon)
		TEST_ASSERT(QDELETED(weapon), "Both destruction paths must delete the form weapon.")
		TEST_ASSERT_NULL(spell.conjured_weapon, "Form Blade must release a weapon destroyed independently of its next cast.")
		TEST_ASSERT(refcount(weapon) <= baseline_refs(), "A destroyed form weapon must not be retained by its spell or deletion subscription (decay: [use_decay], refs: [refcount(weapon)], baseline: [baseline_refs()]).")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Deleting and decaying form weapons must not leave stale callbacks.")

/// Multiple granted form actions must still share the one-conjured-weapon restriction.
/datum/unit_test/runtime_nov06_form_blade_recast_cleanup/Run()
	var/mob/living/carbon/human/caster = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/form_blade/first_spell = allocate(/datum/action/cooldown/spell/form_blade)
	var/datum/action/cooldown/spell/form_blade/second_spell = allocate(/datum/action/cooldown/spell/form_blade)
	first_spell.Grant(caster)
	second_spell.Grant(caster)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(first_spell.cast(caster), "The first form action must conjure a weapon.")
	var/obj/item/first = first_spell.conjured_weapon
	TEST_ASSERT(second_spell.cast(caster), "Another form action must still replace the existing form weapon.")
	var/obj/item/replacement = second_spell.conjured_weapon
	TEST_ASSERT(QDELETED(first), "Casting another form action must delete the previous weapon.")
	TEST_ASSERT_NULL(first_spell.conjured_weapon, "The first action must release the weapon replaced by another action.")
	TEST_ASSERT(replacement && !QDELETED(replacement), "The second action must retain its live replacement.")
	TEST_ASSERT(refcount(first) <= baseline_refs(), "Replacing another action's form weapon must leave it collectable.")
	qdel(first_spell)
	TEST_ASSERT(!QDELETED(replacement), "Forgetting the first action must preserve the second action's weapon.")
	qdel(second_spell)
	TEST_ASSERT(QDELETED(replacement), "Forgetting the owning form action must dispel its weapon.")
	TEST_ASSERT_NULL(second_spell.conjured_weapon, "A deleted form action must release its weapon.")
	TEST_ASSERT(refcount(replacement) <= baseline_refs(), "Forgetting Form Blade must leave the final weapon collectable.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Replacing and forgetting form actions must clean up without stale signals.")
