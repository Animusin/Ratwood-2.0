/datum/unit_test/market_daily_recovery
	var/list/saved_market_state
	var/saved_recovery

/datum/unit_test/market_daily_recovery/Destroy()
	if(saved_market_state)
		for(var/field in saved_market_state)
			SSmerchant_trade.vars[field] = saved_market_state[field]
		CONFIG_SET(number/ratwood_market_daily_recovery, saved_recovery)
	return ..()

/datum/unit_test/market_daily_recovery/Run()
	var/datum/controller/subsystem/merchant_trade/market = SSmerchant_trade
	saved_recovery = CONFIG_GET(number/ratwood_market_daily_recovery)
	saved_market_state = list()
	for(var/field in list("pool_capacity", "pool_consumed", "lifetime_pool_relieved", "pending_ship_demand", "bm_pool_consumed", "market_watchers"))
		saved_market_state[field] = market.vars[field]
		market.vars[field] = list()
	var/obj/effect/market_recovery_test_watcher/watcher = allocate(/obj/effect/market_recovery_test_watcher)
	market.market_watchers += watcher
	var/bucket = NAVIGATOR_BUCKET_VALUABLES_CRAFTED
	market.pool_capacity[bucket] = 800
	market.pool_consumed[bucket] = 800
	market.lifetime_pool_relieved[bucket] = 0
	market.pending_ship_demand[bucket] = 200
	market.bm_pool_consumed[bucket] = 300
	CONFIG_SET(number/ratwood_market_daily_recovery, 0.5)

	TEST_ASSERT_EQUAL(market.get_saturation_factor(bucket), 0, "The full pool must initially refuse exports.")
	TEST_ASSERT(market.ratwood_recover_market(), "A saturated pool should recover.")
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 400, "One dawn must free half the capacity.")
	TEST_ASSERT_EQUAL(market.get_saturation_factor(bucket), 1, "Recovery must allow exports again.")
	TEST_ASSERT_EQUAL(market.lifetime_pool_relieved[bucket], 0, "Passive recovery must not be reported as ship relief.")
	TEST_ASSERT_EQUAL(watcher.refreshes, 1, "Open market windows must refresh after recovery.")
	TEST_ASSERT_EQUAL(market.pending_ship_demand[bucket], 200, "Passive recovery must not create ship demand.")
	TEST_ASSERT_EQUAL(market.bm_pool_consumed[bucket], 300, "Black-market saturation must be untouched.")
	market.ratwood_recover_market()
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 0, "Two dawns without sales must fully recover this pool.")
	TEST_ASSERT(!market.ratwood_recover_market(), "An empty pool must not bank additional capacity.")
	TEST_ASSERT_EQUAL(market.lifetime_pool_relieved[bucket], 0, "Empty pools must not inflate ship statistics.")
	TEST_ASSERT_EQUAL(watcher.refreshes, 2, "Unchanged pools must not refresh windows.")

	market.pool_consumed[bucket] = 100
	market.ratwood_recover_market()
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 0, "Partial recovery must stop at zero consumption.")
	TEST_ASSERT_EQUAL(market.lifetime_pool_relieved[bucket], 0, "Partial recovery must not alter ship statistics.")
	market.pool_capacity["future upstream category"] = 1000
	market.pool_consumed["future upstream category"] = 1000
	market.pool_capacity[bucket] = 1200
	market.pool_consumed[bucket] = 1500
	market.ratwood_recover_market()
	TEST_ASSERT_EQUAL(market.pool_consumed["future upstream category"], 500, "New upstream categories must recover automatically.")
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 900, "Use current capacity, including when an export overshot the cap.")

	CONFIG_SET(number/ratwood_market_daily_recovery, 0)
	var/refreshes_before = watcher.refreshes
	var/relief_before = market.lifetime_pool_relieved[bucket]
	TEST_ASSERT(!market.ratwood_recover_market(), "Zero must disable the local mechanic.")
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 900, "Disabling must preserve saturation.")
	TEST_ASSERT_EQUAL(market.lifetime_pool_relieved[bucket], relief_before, "Disabling must preserve statistics.")
	TEST_ASSERT_EQUAL(watcher.refreshes, refreshes_before, "Disabling must not refresh windows.")
	CONFIG_SET(number/ratwood_market_daily_recovery, -1)
	TEST_ASSERT_EQUAL(CONFIG_GET(number/ratwood_market_daily_recovery), 0, "Negative configuration must clamp to zero.")
	CONFIG_SET(number/ratwood_market_daily_recovery, 2)
	TEST_ASSERT_EQUAL(CONFIG_GET(number/ratwood_market_daily_recovery), 1, "Configuration above one must clamp to one.")
	market.ratwood_recover_market()
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 0, "Full recovery must clear consumption below capacity.")

	// A ship must still provide its normal relief and demand after passive recovery.
	CONFIG_SET(number/ratwood_market_daily_recovery, 0.5)
	market.pool_capacity[bucket] = 800
	market.pool_consumed[bucket] = 800
	market.pending_ship_demand[bucket] = 0
	market.lifetime_pool_relieved[bucket] = 0
	market.ratwood_recover_market()
	var/datum/foreign_realm/realm = new
	allocated += realm
	realm.demanded_categories = list(bucket)
	market.add_ship_demand_for_realm(realm)
	TEST_ASSERT_EQUAL(market.pool_consumed[bucket], 0, "A ship must add its usual 50% relief after dawn recovery.")
	TEST_ASSERT_EQUAL(market.lifetime_pool_relieved[bucket], 400, "Ship statistics must count only the ship's actual relief.")
	TEST_ASSERT_EQUAL(market.pending_ship_demand[bucket], 400, "Ships must still generate their usual demand.")
	return TRUE

/obj/effect/market_recovery_test_watcher
	var/refreshes = 0

/obj/effect/market_recovery_test_watcher/update_static_data_for_all_viewers()
	refreshes++
