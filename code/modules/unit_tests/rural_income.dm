/datum/unit_test/rural_income
	var/list/saved_accounts
	var/list/saved_base_wages
	var/obj/structure/roguemachine/steward/saved_steward
	var/saved_coverage

/datum/unit_test/rural_income/Destroy()
	if(saved_accounts)
		SStreasury.bank_accounts = saved_accounts
		SStreasury.ratwood_base_wages = saved_base_wages
		SStreasury.steward_machine = saved_steward
		CONFIG_SET(number/ratwood_rural_wage_coverage, saved_coverage)
	return ..()

/datum/unit_test/rural_income/Run()
	saved_accounts = SStreasury.bank_accounts
	saved_base_wages = SStreasury.ratwood_base_wages
	saved_steward = SStreasury.steward_machine
	saved_coverage = CONFIG_GET(number/ratwood_rural_wage_coverage)
	SStreasury.bank_accounts = list()
	var/obj/structure/roguemachine/steward/machine = allocate(/obj/structure/roguemachine/steward)
	SStreasury.steward_machine = machine
	CONFIG_SET(number/ratwood_rural_wage_coverage, 0.75)
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 100, "An empty payroll must retain the upstream minimum.")
	machine.daily_payments = list("Test Guard" = 60)
	SStreasury.ratwood_capture_base_wages()
	TEST_ASSERT(SStreasury.ratwood_base_wages != machine.daily_payments, "Defaults must be a copy, not the editable payroll list.")
	var/list/workers = list()
	for(var/i in 1 to 5)
		var/mob/living/carbon/human/worker = allocate(/mob/living/carbon/human/consistent)
		worker.job = "Test Guard"
		worker.mind_initialize()
		worker.mind.key = "rural_income_test_[i]"
		var/datum/fund/account = new("Test wage account", worker)
		allocated += account
		SStreasury.bank_accounts[worker] = account
		workers += worker
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 225, "Five standard 60m wages must produce 225m, even without connected clients.")
	SStreasury.ratwood_base_wages["Test Guard"] = 90
	machine.daily_payments["Test Guard"] = 90
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 338, "Fractional grants must round to whole mammons.")
	SStreasury.ratwood_base_wages["Test Guard"] = 120
	machine.daily_payments["Test Guard"] = 120
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 450, "A 600m payroll must receive 450m.")
	SStreasury.ratwood_base_wages["Test Guard"] = 60
	machine.daily_payments["Test Guard"] = 10000
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 225, "A steward's raise must not increase passive income.")
	machine.daily_payments["Test Guard"] = 40
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 150, "Coverage must not exceed the reduced actual payroll.")
	machine.daily_payments["Test Guard"] = 0
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 100, "Cancelled wages must not attract a subsidy.")
	machine.daily_payments["Test Guard"] = 60
	var/mob/living/carbon/human/first = workers[1]
	first.stat = DEAD
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "Dead workers must be excluded.")
	first.stat = CONSCIOUS
	var/datum/fund/first_account = SStreasury.bank_accounts[first]
	first_account.wages_suspended = TRUE
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "Suspended wages must be excluded.")
	first_account.wages_suspended = FALSE
	SStreasury.remove_person(first)
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "Departed characters removed from banking must be excluded.")
	SStreasury.bank_accounts[first] = first_account
	first.job = "New Paid Role"
	machine.daily_payments[first.job] = 10000
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "Adding an arbitrary paid role must not create a subsidy.")
	first.job = "Test Guard"
	first.mind.key = null
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "An NPC account must not increase the subsidy.")
	var/mob/living/carbon/human/second = workers[2]
	first.mind.key = second.mind.key
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "The same player must not count twice.")
	first.mind.key = "rural_income_test_1"
	first.mind.current = second
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 180, "An abandoned body must not count as another player.")
	first.mind.current = first
	CONFIG_SET(number/ratwood_rural_wage_coverage, 0)
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 100, "Zero coverage must restore upstream income.")
	CONFIG_SET(number/ratwood_rural_wage_coverage, 0.5)
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 150, "Custom fractional coverage must be respected.")
	TEST_ASSERT_EQUAL(SStreasury.ratwood_scaled_rural_tax(250), 250, "A future higher upstream minimum must be preserved.")
	CONFIG_SET(number/ratwood_rural_wage_coverage, -1)
	TEST_ASSERT_EQUAL(CONFIG_GET(number/ratwood_rural_wage_coverage), 0, "Negative coverage must clamp to zero.")
	CONFIG_SET(number/ratwood_rural_wage_coverage, 2)
	TEST_ASSERT_EQUAL(CONFIG_GET(number/ratwood_rural_wage_coverage), 1, "Coverage above one must clamp to one.")
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 300, "Full coverage must match the standard payroll.")
	SStreasury.steward_machine = null
	TEST_ASSERT_EQUAL(SStreasury.get_rural_tax_amount(), 100, "A missing steward machine must retain the upstream minimum.")
	return TRUE
