# Local economy support

## Daily Navigator market recovery

At every transition to dawn, the ordinary Navigator market frees 50% of each
category's current capacity. For a capacity of 800, a fully consumed pool goes
from 800 consumed to 400, then to 0 after another dawn without sales. Unused
recovery does not accumulate beyond the pool's capacity.

The server setting `RATWOOD_MARKET_DAILY_RECOVERY` accepts a fraction from 0 to 1
in `config/config.txt`. It defaults to `0.5` without a config-file change. Set it
to `0` to disable this extension, or `1` to recover one full capacity per dawn.
Values outside that range are clamped by the configuration system.

Recovery uses the upstream category list and current capacities, including
population and market modifiers. It refreshes open market windows when anything
changes. Ship relief, ship demand, prices, treasury income and the black market
retain their existing behavior. The existing "Ship Relieved" statistics still
count only relief from ships, not this passive recovery.

## Passive treasury income

At dawn, rural income is the greater of the upstream minimum (currently 100m)
and 75% of eligible standard wages, rounded to whole mammons. This is the total
daily rural income, not an extra grant on top of it. For a standard payroll of
300m, rural income is 225m; for 600m it is 450m.

`RATWOOD_RURAL_WAGE_COVERAGE` is a separate server setting from 0 to 1, defaulting
to `0.75`. Setting it to `0` restores upstream rural income. Both settings can
be set independently in `config/config.txt` and require no config-file changes
to enable their defaults.

Standard wages are copied from the mapped Nerve Master's payroll during treasury
initialization, after initial charters have applied their wage floors. No wage
table is duplicated. Player raises and newly added paid roles cannot increase
the grant. Lowered wages reduce the eligible amount; cancelled or suspended
wages do not count. Neither do dead, deleted or departed account holders, NPCs,
or abandoned bodies. A disconnected player's living current character still
counts, and a player key can be counted only once.

The existing rural-income getter is used for both the actual dawn deposit and
the steward's income projection. The normal treasury ledger, statistics and
debt handling continue to apply. This extension does not change salaries.

## Upstream updates

Market recovery's production integration consists of its include and one
call to `SSmerchant_trade.ratwood_recover_market()` in the dawn branch of
`code/__HELPERS/time.dm`. Keep it inside the time-of-day transition guard.
It deliberately does not use `daily_tick()`'s increasing-day guard: the calendar
wraps from day 7 back to day 1.

Do not copy or override upstream market procedures. After merging upstream,
check that the hook still runs once per dawn and that `pool_capacity`,
`pool_consumed` and `broadcast_market_change()` retain
their meaning. Run the `market_daily_recovery` unit test for saturation bounds,
configuration, dynamic categories and compatibility with ship relief.

Rural-income scaling lives in `rural_income.dm`. Its production integration is
one include, `ratwood_capture_base_wages()` after `init_decrees()` in treasury
initialization, and the call from `get_rural_tax_amount()` passing upstream's
`RURAL_TAX` minimum. Keep the wage snapshot before player edits and after the
mapped steward and default charters have initialized. The `rural_income` test
covers eligibility, disconnected players, payroll-edit exploits, the minimum
and the independent off switch.
