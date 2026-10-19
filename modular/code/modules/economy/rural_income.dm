/// Share of eligible standard wages covered by rural income. Zero keeps upstream income.
/datum/config_entry/number/ratwood_rural_wage_coverage
	config_entry_value = 0.75
	integer = FALSE
	min_val = 0
	max_val = 1

/datum/controller/subsystem/treasury
	/// Snapshot after default wages and initial charters, before player adjustments.
	var/list/ratwood_base_wages = list()

/datum/controller/subsystem/treasury/proc/ratwood_capture_base_wages()
	if(steward_machine)
		ratwood_base_wages = steward_machine.daily_payments.Copy()

/datum/controller/subsystem/treasury/proc/ratwood_scaled_rural_tax(base_income)
	var/coverage = CONFIG_GET(number/ratwood_rural_wage_coverage)
	if(coverage <= 0 || !steward_machine)
		return base_income
	var/eligible_wages = 0
	var/list/counted_keys = list()
	for(var/mob/living/carbon/human/owner in bank_accounts)
		if(QDELETED(owner) || owner.stat == DEAD || !owner.mind?.key || owner.mind.current != owner)
			continue
		var/player_key = ckey(owner.mind.key)
		if(player_key in counted_keys)
			continue
		var/datum/fund/account = bank_accounts[owner]
		if(!account || account.wages_suspended)
			continue
		var/wage = min(ratwood_base_wages[owner.job] || 0, steward_machine.daily_payments[owner.job] || 0)
		if(wage <= 0)
			continue
		eligible_wages += wage
		counted_keys += player_key
	return max(base_income, round(eligible_wages * coverage, 1))
