# Daily Navigator market recovery

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

## Upstream updates

The production integration consists of the include in `roguetown.dme` and one
call to `SSmerchant_trade.ratwood_recover_market()` in the dawn branch of
`code/__HELPERS/time.dm`. Keep it inside the time-of-day transition guard.
It deliberately does not use `daily_tick()`'s increasing-day guard: the calendar
wraps from day 7 back to day 1.

Do not copy or override upstream market procedures. After merging upstream,
check that the hook still runs once per dawn and that `pool_capacity`,
`pool_consumed` and `broadcast_market_change()` retain
their meaning. Run the `market_daily_recovery` unit test for saturation bounds,
configuration, dynamic categories and compatibility with ship relief.
