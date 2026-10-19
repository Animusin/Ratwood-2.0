/// Fraction of each ordinary Navigator market pool freed at dawn. Zero keeps upstream behavior.
/datum/config_entry/number/ratwood_market_daily_recovery
	config_entry_value = 0.5
	integer = FALSE
	min_val = 0
	max_val = 1

/// Local low-pop relief. Called once by settod() on entering dawn, including week rollover.
/// Use upstream capacities; ship demand and ship-relief statistics remain separate.
/datum/controller/subsystem/merchant_trade/proc/ratwood_recover_market()
	var/fraction = CONFIG_GET(number/ratwood_market_daily_recovery)
	if(fraction <= 0)
		return FALSE
	var/changed = FALSE
	for(var/bucket in pool_capacity)
		var/capacity = pool_capacity[bucket]
		if(capacity <= 0)
			continue
		var/consumed = pool_consumed[bucket] || 0
		var/relief = min(consumed, round(capacity * fraction))
		if(relief <= 0)
			continue
		pool_consumed[bucket] = consumed - relief
		changed = TRUE
	if(changed)
		broadcast_market_change()
	return changed
