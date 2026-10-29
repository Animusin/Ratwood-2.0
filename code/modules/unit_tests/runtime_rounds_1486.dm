// Regression tests for runtimes reported from rounds 1485-1490 (server revision 76e20f1).

/// AStar keeps expanded nodes in openc and may find a cheaper route to one of them; re-sorting it must not index the heap at 0.
/datum/unit_test/runtime_path_heap_resort/Run()
	var/runtimes_before = GLOB.total_runtimes
	var/datum/path_minheap/heap = new
	var/datum/PathNode/first = new(null, null, 1, 0, 0, 0)
	var/datum/PathNode/second = new(null, null, 2, 0, 0, 0)
	var/datum/PathNode/third = new(null, null, 3, 0, 0, 0)
	heap.Insert(first)
	heap.Insert(second)
	heap.Insert(third)
	var/datum/PathNode/closed = heap.Pop()
	TEST_ASSERT_EQUAL(closed, first, "The cheapest node must be popped first.")
	closed.setp(null, 0, 0, 0)
	TEST_ASSERT(!heap.ReSort(closed), "Re-sorting a node that already left the heap must be a no-op.")
	TEST_ASSERT_EQUAL(length(heap.L), 2, "Re-sorting a closed node must not touch the remaining heap.")
	third.setp(null, 0, 0, 0)
	TEST_ASSERT(heap.ReSort(third), "A node still in the heap must be re-sorted.")
	TEST_ASSERT_EQUAL(heap.Pop(), third, "A cheaper open node must rise to the top.")
	TEST_ASSERT_EQUAL(heap.Pop(), second, "The remaining node must still be returned.")
	TEST_ASSERT_EQUAL(heap.Sink(0), 0, "Sinking an invalid index must be rejected.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Heap re-sorting must not read outside the list.")

/// The player panel asks a mind's language holder about every language, including for minds without a current body.
/datum/unit_test/runtime_language_holder_without_body/Run()
	var/datum/mind/bodiless = new("runtime_language_holder_test")
	allocated += bodiless
	var/datum/language_holder/holder = new(bodiless)
	allocated += holder
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT_EQUAL(holder.has_language(/datum/language/common), LANGUAGE_KNOWN, "Directly known languages must still be reported.")
	TEST_ASSERT(!holder.has_language(/datum/language/aphasia), "A holder without a body has no shadow languages to offer.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Language checks must not dereference a missing body.")

/// A body can be left pointing at a mind that was deleted while it considered another mob (or nothing) current.
/datum/unit_test/runtime_sleep_adv_deleted_mind/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	body.adjust_skillrank_up_to(/datum/skill/misc/reading, SKILL_LEVEL_APPRENTICE, TRUE)
	var/datum/mind/stale = body.mind
	stale.set_current(null)
	qdel(stale)
	TEST_ASSERT_EQUAL(body.mind, stale, "The fixture must keep the body pointing at the deleted mind.")
	TEST_ASSERT_NULL(stale.sleep_adv, "Deleting the mind must clear its sleep datum.")
	var/runtimes_before = GLOB.total_runtimes
	stale.add_sleep_experience(/datum/skill/misc/reading, 10, TRUE, FALSE)
	body.print_levels()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A deleted mind must not be asked for its cleared sleep datum.")
	body.mind = null
	body.last_mind = null

/// attack_obj also reaches structures; a scroll must refuse them before reading item-only variables.
/datum/unit_test/runtime_enchant_scroll_structure/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/enchantmentscroll/basic/holding/scroll = allocate(/obj/item/enchantmentscroll/basic/holding)
	var/obj/structure/chair/target = allocate(/obj/structure/chair)
	var/runtimes_before = GLOB.total_runtimes
	scroll.attack_obj(target, user)
	TEST_ASSERT(!QDELETED(scroll), "A refused target must not consume the scroll.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Using a scroll on a structure must not read item variables.")

/// Entering combat removes the skate effect inside its own tick; the tick must stop instead of draining a cleared owner.
/datum/unit_test/runtime_verglas_skate_combat/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/verglas_concentration/skate/skate = human.apply_status_effect(/datum/status_effect/verglas_concentration/skate, list(), null)
	TEST_ASSERT(skate, "The fixture must start skating.")
	var/runtimes_before = GLOB.total_runtimes
	human.in_combat_until = world.time + 10 SECONDS
	skate.tick()
	TEST_ASSERT(QDELETED(skate), "Combat must end the skate concentration.")
	TEST_ASSERT(!human.has_status_effect(/datum/status_effect/verglas_concentration/skate), "The removed effect must leave the status registry.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The tick must not use its owner after removing itself.")

/// The ingredient list must follow what is really in the cauldron.
/datum/unit_test/runtime_cauldron_stale_ingredients/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/light/rogue/cauldron/cauldron = allocate(/obj/machinery/light/rogue/cauldron)
	cauldron.burn_out()
	var/obj/item/alch/viscera/kept = allocate(/obj/item/alch/viscera)
	var/obj/item/alch/viscera/destroyed = allocate(/obj/item/alch/viscera)
	kept.forceMove(cauldron)
	destroyed.forceMove(cauldron)
	cauldron.ingredients = list(kept, destroyed)
	qdel(destroyed)
	TEST_ASSERT(!(destroyed in cauldron.ingredients), "An ingredient deleted in place must leave the list.")
	cauldron.ingredients += null
	var/runtimes_before = GLOB.total_runtimes
	cauldron.attack_hand(user)
	TEST_ASSERT(user.is_holding(kept), "Pulling must hand over the real ingredient, skipping the stale entry.")
	TEST_ASSERT_EQUAL(length(cauldron.ingredients), 0, "Nothing may be left listed once the real ingredient is out.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Stale ingredient entries must not be pulled out.")

/// Player bank accounts are /datum/fund instances; code must move balances through the treasury API.
/datum/unit_test/runtime_fund_account_arithmetic
	var/list/saved_accounts

/datum/unit_test/runtime_fund_account_arithmetic/Destroy()
	if(saved_accounts)
		SStreasury.bank_accounts = saved_accounts
	return ..()

/datum/unit_test/runtime_fund_account_arithmetic/Run()
	saved_accounts = SStreasury.bank_accounts
	SStreasury.bank_accounts = list()
	var/mob/living/carbon/human/debtor = allocate(/mob/living/carbon/human/consistent)
	var/datum/fund/account = new("Runtime test debtor", debtor, 100)
	allocated += account
	SStreasury.bank_accounts[debtor] = account
	var/datum/charflaw/indebted/flaw = new
	allocated += flaw
	flaw.bounty_added = TRUE
	var/runtimes_before = GLOB.total_runtimes

	flaw.calculate_childsupport(debtor)
	TEST_ASSERT_EQUAL(SStreasury.get_account(debtor), account, "Paying debts must keep the debtor's fund.")
	TEST_ASSERT_EQUAL(account.balance, 70, "A 100m balance must pay the 30m minimum.")

	account.balance = 20
	flaw.calculate_childsupport(debtor)
	TEST_ASSERT_EQUAL(SStreasury.get_account(debtor), account, "Defaulting must empty the fund, not replace it with a number.")
	TEST_ASSERT_EQUAL(SStreasury.get_balance(debtor), 0, "Defaulting must take the whole remaining balance.")

	account.balance = 5
	debtor.apply_status_effect(/datum/status_effect/matthios_favor)
	TEST_ASSERT(account.balance >= 0 && account.balance < 5, "Matthios' favor must skim from the fund balance.")
	TEST_ASSERT_EQUAL(SStreasury.get_account(debtor), account, "Matthios' favor must keep the fund.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Fund balances must not be used as numbers.")
