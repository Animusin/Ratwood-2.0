# Repository agent instructions

## Map editing

- Treat `.dmm` files as TGM maps. Do not edit their dictionary keys or coordinate blocks with blind text replacement.
- Use the parser in `tools/mapmerge2/dmm.py` for coordinate-safe mutations and remove unused keys before saving.
- Preserve unrelated dirty-worktree files. Generated map renders, CSV audits, runtime logs and temporary baselines belong under `tmp/` or `data/logs/`, not in commits.
- Before changing vertical geometry, inventory all stairs, ladders and openspace turfs on both adjacent z-levels. A lower stair requires openspace directly above it and a same-direction partner one tile forward on the upper level.

## Rogue Hamlet invariants

- `_maps/map_files/otherz/smallforest.dmm` has three levels: cave, forest surface and canopy. Do not replace the canopy with ruins or copy underground content onto z2/z3.
- The cave's mandatory routes are three cells wide and use naturalstone so cave generators cannot obstruct them. Doors, mobs, traps and loot must not be placed on that protected spine.
- Sunken Church, Drow Outpost and Wizard Tower are optional side branches. Their local stairs/ladders must stay removed, and their keys must remain reachable before the corresponding lock.
- The common Dungeon Map has an exact-type separator at x=130 on both levels. Do not allow procedural templates to bridge the `center/hamlet` and `forest` branches.
- Run `python tools/map_audit/audit_smallforest.py` after every forest edit. Update its declared routes or module bounds only when the intentional map design changes.

## Required validation

1. Render every changed map with `tools/map_audit/render_tgm.py`; inspect all affected z-levels and require zero unexplained placement issues or unsafe starts.
2. Run maplint for each changed map: `python -m tools.maplint.source <map.dmm>` with `tmp/maplint-deps` on `PYTHONPATH` when using the bundled environment.
3. Compile `roguetown.dme` with Dream Maker and require `0 errors, 0 warnings`.
4. For generator or map-link changes, perform three Rogue Hamlet loads and one Rockhill load when shared Dungeon Map behavior changed. Require every generator to finish, Icon Smoothing initialization to complete and runtime logs to contain no errors.
5. Delete `data/next_map.json` and stop the exact DreamDaemon test process before handing off.

The unchanged Rockhill map has baseline maplint findings. Do not mass-fix them while working on Rogue Hamlet; verify that the live Rockhill load and full build remain clean instead.
