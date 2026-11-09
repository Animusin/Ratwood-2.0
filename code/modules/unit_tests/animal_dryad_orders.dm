/// The real command menu must preserve follow, guard and combat transitions with weak owner links.
/datum/unit_test/animal_dryad_order_transitions/Run()
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	owner.mind_initialize()
	var/mob/living/carbon/human/consistent/enemy = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/spell = allocate(/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad)
	var/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/orders = allocate(/obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad)
	TEST_ASSERT(spell.cast(list(), owner), "The ordered companion must be summoned normally.")
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad = spell.conjured_dryad
	TEST_ASSERT_NOTNULL(dryad, "Summoning must create a commandable companion.")
	allocated += dryad
	issue_order(orders, owner, "follow")
	TEST_ASSERT_EQUAL(dryad.follow_target_ref?.resolve(), owner, "Follow must keep tracking the living summoner.")
	TEST_ASSERT_NULL(dryad.guard_turf, "Follow must cancel the guard destination.")
	issue_order(orders, owner, "goto", run_loc_floor_top_right)
	TEST_ASSERT_NULL(dryad.follow_target_ref, "Guard must release the follow link.")
	TEST_ASSERT_EQUAL(dryad.guard_turf, run_loc_floor_top_right, "Guard must retain the selected destination.")
	issue_order(orders, owner, "attack", null, enemy)
	TEST_ASSERT_EQUAL(dryad.target, enemy, "Attack must retain the selected enemy.")
	TEST_ASSERT(enemy in dryad.enemies, "Attack must still register hostility.")
	TEST_ASSERT_NULL(dryad.guard_turf, "Attack must cancel the guard destination.")
	issue_order(orders, owner, "follow")
	TEST_ASSERT_NULL(dryad.target, "Follow must cancel the previous attack.")
	TEST_ASSERT(!length(dryad.enemies), "Follow must clear previous hostility.")
	issue_order(orders, owner, "toggle_stance")
	TEST_ASSERT_NULL(dryad.follow_target_ref, "Stand-ground stance must release the follow link.")
	TEST_ASSERT_EQUAL(dryad.guard_turf, get_turf(dryad), "Stand-ground stance must guard the current tile.")
	issue_order(orders, owner, "toggle_stance")
	TEST_ASSERT_EQUAL(dryad.follow_target_ref?.resolve(), owner, "Toggling back must resume following the summoner.")
	issue_order(orders, owner, "aggressive", null, enemy)
	TEST_ASSERT_NULL(dryad.follow_target_ref, "Guarding an ally's position must release the follow link.")
	TEST_ASSERT_EQUAL(dryad.guard_turf, get_turf(enemy), "Guarding an ally must retain that ally's tile.")

/datum/unit_test/animal_dryad_order_transitions/proc/issue_order(obj/effect/proc_holder/spell/invoked/minion_order/lesser_dryad/orders, mob/living/carbon/human/caster, order_type, turf/destination, mob/living/target)
	var/mob/previous_usr = usr
	usr = caster
	orders.process_minions(order_type, destination, target, "[caster.real_name]_faction")
	usr = previous_usr
