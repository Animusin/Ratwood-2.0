# Supporter housing prototype

Opt-in, single-floor private interiors for city roles, Mercenaries and Adventurers
with a verified active Wizard, Cultist or Assistant subscription. This is an
ordinary RP location:
doors and internal walls can be broken, furnishings can burn, and an open entrance
can be followed. Disconnecting, dying or losing a subscription does not unload a
home during the round.

## Scope and activation

Russian deployment guide for the server programmer:
[`docs/supporter-housing-setup.md`](../../../docs/supporter-housing-setup.md).

The feature is disabled by default. Before a controlled server trial:

1. Apply `SQL/supporter_housing.sql` to the **game** database. If `FEEDBACK_TABLEPREFIX` is
   configured, use it in the migration. The donation database remains the authority
   for subscription eligibility; no subscription records are modified.
2. Add `SUPPORTER_HOUSING` to the server configuration.
3. Join as an eligible subscribed character, claim an existing generic town house
   using the normal door prompt, and apply its townie key to its door. Opening takes five
   interruptible seconds. Entering the revealed passage takes another five seconds.

Only the exact generic Towner and ordinary Mercenary room door types are eligible,
on `rockhill.dmm`, `deserttown.dmm` and `dun_world.dmm`. Profession workshops and
bathhouse rooms remain on the main map. A key cannot claim a different player's
door. Once linked, the entrance is fixed for the round; stolen or shared real keys
remain usable.
The same real key opens the inner door and restored additional keyed doors.

City roles use the existing Noblemen, Garrison, Church, Courtiers, Yeomen,
Peasants, Youngfolk, Inquisition and Guildsmen job groups; Mercenary, Adventurer
and the city-employed Court Agent are explicitly included. Jobs flagged
`antag_job`, including Bandit, Wretch, Assassin and Gnoll, are excluded, as are
monster/tribal and unknown roles. A hidden antagonist retains access through an
otherwise eligible profession; housing does not expose secret antagonist status.
Verified supporters in eligible roles may use the normal claim prompt on a free
generic home, without the original Towner role requirement. The existing
one-resident-key-claim rule still applies: choose the desired home before claiming
any other resident-key room. Non-supporters retain the original claim rules.
The plot is created only when its claimed entrance is first opened, not on login.
Role eligibility is rechecked after opening/saving waits; an existing home stays
in the round after a role change and remains accessible using normal keys/following.

## Sizes and budgets

| Subscription | Plot including boundary | Active items including contents | Workstations | Lights |
|---|---:|---:|---:|---:|
| Wizard | 13 x 15 | 40 | 2 | 8 |
| Cultist | 17 x 19 | 80 | 4 | 12 |
| Assistant | 21 x 23 | 120 | 6 | 16 |

Workstation counts are upper bounds: individual types also require their declared
minimum subscription. Looms, drying racks, grinding/pottery/alchemy benches and
cooking fixtures require Cultist; most other machinery and rotational machines
require Assistant. Ordinary lighting, furniture, doors, bars, barrels, crockery
and candlesticks are available at Wizard.

A single lazily allocated Z-level contains at most **60 homes**, in separate
28 x 28 cells. Its dimensions follow the running world, without increasing X/Y.
Interiors load only on first use, with no per-house polling subsystem. Saves are
limited to 160 items including contents and the archive, 64 changed terrain cells, and
60,000 ASCII JSON characters per account. At most three furnishings may share a
tile, with at most one dense furnishing; large bounds must fit within the home.
Save attempts are limited to once a minute.

Rockhill has **25** eligible generic doors; Desert Town has **26** and Dun World
has **33**. The atlas can hold 60 homes on all three maps, but 60 simultaneous
independently linked homes need additional authored exterior entrances. No
existing main-map DMM is changed.

## Persistence

The fixed bell asks for confirmation. There is no automatic round-end save and no
mid-round rollback. Only the owner, currently playing an eligible role with a
verified qualifying subscription, can save, outside fire/combat. A successful message is
sent only after the database accepts an atomic revision-checked write. Failed
queries or concurrent edits do not overwrite the old snapshot.

Examine the bell as its owner to see this round's tier, furnishing/workstation/light
budgets, archive size, age of the last successful save, and unsaved layout changes.
Ringing previews saved furnishings, structural changes, retained archive entries,
missing furnishings and objects omitted from persistence before confirmation.
Moving or painting furniture does not count as deleting it. If the layout changes
during confirmation, saving stops and asks for a fresh preview. Failed writes keep
the previous saved baseline and the unsaved indicator. These checks run only on
interaction, without a polling subsystem. Save age uses the existing `updated_at`
column; no additional schema migration is required.

Right-click the bell for the guide and an owner-only archive breakdown, including
minimum subscription/layout requirements and placement/capacity conflicts. The
owner gets a short hint on their first conscious entrance each round. Save and
craft failures report the specific budget or offending furnishing/terrain.

The bell explicitly shows **N/40, N/80 or N/120 items**, including the number
inside containers. A chest with ten approved cups uses eleven places. Archived
items, including packed contents, also count toward the separate 160-item storage
cap. Wall/floor changes retain their separate 64-record limit.

Records contain an exact approved type, relative X/Y, direction and a hex colour.
Terrain changes add `kind = wall`; only approved ordinary walls and floors are
accepted. Original wall removal, added partitions and painting are retained.
The hedge, darkness, three-tile landing, built-in inner doorway and approach to
the bell are excluded from edits. Furniture and wall edits outside a smaller
next-round layout, or unavailable at its tier, remain archived in the same save.
They are considered again on a later upgrade. Already-open homes do not resize.
Archived records are explicitly inactive: current furnishings take priority when
their coordinates overlap, and an archived fixture that still cannot fit remains
in storage. Removed-wall deltas survive a move through a larger floor plan.
Expiry blocks new homes and saving, without deleting their stored records. A
subscription or housing database failure is reported without treating it as expiry.

The exact catalog covers most craftable structures and is checked into
`craft_catalog.dm`; new recipes do **not** automatically authorize more types.
Items use a separate explicit crockery/lighting list. Exclusions include the large
steel furnace, stairs and ladders, floor passages, apiaries, infernal engines,
antagonist altars/wonders, and service trading/communication machines.

Approved small items directly inside approved closet-based furniture (chests,
drawers and cupboards) are saved with their container, up to its native capacity
or 30 items, whichever is lower. Each child records only its approved type,
direction and colour. Nested bags, machine inputs, unapproved loot, mobs, bodies,
liquids, fuel, workpieces, production queues, fire and arbitrary object vars are
excluded. Close filled containers before saving; opening one puts its contents on
the floor, where the normal overlap limits apply. A container and its contents are
restored or archived together, including when their combined count exceeds the
current tier's item/light limits. Old saves without contents remain compatible;
the JSON format expands inside the existing column, with no new SQL migration.
New fixtures lose generated contents before approved saved children are restored.
Burning machinery loads extinguished. Restored objects and stored items have zero
sale value even after derived-price, loot and glaze adjustments; they cannot be
smelted or dismantled into materials. Walls/doors retain ordinary damage behavior.
Custom sign text, wiring, mechanical network connections, object integrity and
per-object production state are outside this prototype's record format.

## Admin testing without Patreon or databases

With `R_ADMIN`, take control of a human on an ordinary floor outside a supporter
home and open **Admin > Test Supporter Home**. Select **Set test subscription**
for Wizard/Cultist/Assistant, then **Create / enter**. Ring the bell to preview and
save, and use **Reload saved test home** to exercise restoration or tier changes.
The entrance portal is limited to the owning admin; return remains possible after
rights are lost. Test saving bypasses the donor, job and save-cooldown checks, but
still validates ownership/admin rights, item budgets, layout and fire/combat.

**Expired**, **Service unavailable**, and **Toggle storage outage** exercise failed
creation/saving while retaining the existing test home and snapshot. Reloading
requires confirmation, evacuates occupants, deletes objects left in the test plot
and reuses that same reserved plot. **Return outside** leaves the test area.
Test snapshots live only in memory until round end and use no SQL or Patreon
connection. Normal house records and real subscription levels are never changed.
Testing works with the feature flag off and uses the shared, bounded home atlas.

## Passage behavior

Anyone can follow an open entrance; normal locking/picking/destruction governs
access afterwards. Visible, conscious, non-blind human witnesses remember that
specific home on their current body, cleared on death. No global bandit access
trait is granted. Destroying the exterior door leaves an explicit passage; the
return route never requires a key, job or subscription.

Both passage and opening cancel on movement, incapacitation or an incoming
attack/damage signal. A character held by someone outside their travelling party
cannot use it. A party of up to four living mobs, including pulled/grabbed prisoners,
moves synchronously with its existing pull and grab objects intact. Contested
grabs, buckling, furniture dragging and knots are rejected rather than detached.

Crafting and blueprint placement check the destination, protecting only the local
landing/approach, instead of the normal seven-tile travel crafting radius.
Forced furniture moves into the landing are moved aside without deleting loot.

## Validation and remaining integration work

Transient probes and map renders live under `tmp/housing/`, outside commits.
The probe uses the production module in an isolated DreamDaemon world with SQL
disabled: it checks subscriptions, malformed records, archives/upgrades, pricing,
wall restoration, doors, timed prisoner passage, death/exit behavior, constructor
inventories, and the 60-plot limit. It also loads 120 simple decorations in each
stress-test manor. The storage probe replaces the SQL transport while exercising
the production read/write methods, including insert/update collisions, outages,
and corrupt JSON. The real databases are not touched. The final probe passed 799
checks without failures or runtime errors, including retrying an interrupted home
creation without another plot or database read, dark-wood window persistence,
unsupported terrain rejection and window lock directions. Its 60 homes, with
roughly 7,000 simple furnishings, loaded in 14.22 seconds; peak working set of the
entire isolated process was 672 MiB. Feedback checks cover dirty-state comparisons,
archive explanations, removal/omission previews, specific errors, owner-only status,
one-time welcome, cancelled/changed confirmations, successful saves and failed-write
preservation. Container/admin checks cover strict child schemas, shared budgets,
storage movement, whole-container downgrade/upgrade archives, empty liquids and
zero-value restored contents, isolated memory saves, simulated outages/expiry,
revoked authorization and reuse of the same test plot. Positive admin authorization,
confirmation and SQL are simulated; actual client dialog presentation
still needs an in-game check. The full BYOND 516.1687 build had no errors or warnings and
all three home templates passed maplint. Actual Rockhill, Desert Town and Dun
World configs were checked for generic-door access, workshop exclusion and atlas
capacity. Role checks cover city professions, Mercenaries, Adventurers, explicit
antagonist/monster exclusions, hidden antagonists and role changes. The door audit
counted 25, 26 and 33 eligible entrances respectively.
This is not a benchmark of 60 connected clients, simultaneously lit homes,
active production, mass combat or fire.

Before enabling on a live server, exercise the real game/donation database,
ownership/confirmation UI, expiry and failed saves, door picking, directional
visibility, concurrent openings and worst-case lighting/production with players.
Other maps and more exterior entrances need a separate mapping pass.
