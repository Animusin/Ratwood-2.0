#!/usr/bin/env python3
"""Regression audit for Rogue Hamlet's three-level smallforest map."""

from __future__ import annotations

import argparse
from collections import Counter, deque
from pathlib import Path

from render_tgm import Atom, Tile, parse_tgm


NATURALSTONE = "/turf/open/floor/rogue/naturalstone"
OPENSPACE = "/turf/open/transparent/openspace"
GENERATOR_TURFS = {
    "/turf/open/floor/rogue/dirt",
    "/turf/open/floor/rogue/dirt/road",
    "/turf/open/floor/rogue/volcanic",
    "/turf/open/water",
    "/turf/open/water/cleanshallow",
    "/turf/open/water/ocean",
}
ROUTE_LINES = [
    [(73, 104), (70, 98), (62, 90), (48, 82)],
    [(48, 82), (38, 69), (44, 56), (60, 49), (78, 52), (88, 66), (82, 82), (65, 90), (48, 82)],
    [(48, 82), (56, 74), (64, 69), (74, 61), (78, 52)],
    [(94, 44), (88, 48), (78, 52)],
    [(44, 56), (42, 48), (37, 42), (36, 36), (36, 32), (27, 28), (23, 24)],
    [(38, 69), (30, 65), (22, 60), (16, 52)],
    [(94, 44), (102, 36), (108, 28), (112, 18)],
    [(44, 103), (50, 101), (56, 96), (62, 90)],
    [(101, 85), (96, 84), (92, 83), (88, 82), (82, 82)],
    [(62, 15), (55, 18), (48, 24), (42, 28), (36, 32)],
]
MODULES = {
    "Sunken Church": ((4, 89, 44, 126), "/area/rogue/under/dungeon/sunkenchurch", 13, 7, 1),
    "Drow Outpost": ((101, 76, 123, 95), "/area/rogue/under/dungeon/drowfort", 8, 6, 1),
    "Wizard Tower": ((62, 9, 74, 21), "/area/rogue/under/dungeon/wizarddungeon", 3, 3, 0),
}


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def bresenham(start: tuple[int, int], end: tuple[int, int]):
    x0, y0 = start
    x1, y1 = end
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    error = dx + dy
    while True:
        yield x0, y0
        if (x0, y0) == (x1, y1):
            return
        doubled = 2 * error
        if doubled >= dy:
            error += dy
            x0 += sx
        if doubled <= dx:
            error += dx
            y0 += sy


def widened_routes() -> set[tuple[int, int]]:
    centers: set[tuple[int, int]] = set()
    for points in ROUTE_LINES:
        for start, end in zip(points, points[1:]):
            centers.update(bresenham(start, end))
    return {
        (x + offset_x, y + offset_y)
        for x, y in centers
        for offset_x in (-1, 0, 1)
        for offset_y in (-1, 0, 1)
    }


def atom(tile: Tile, prefix: str) -> Atom | None:
    return next((candidate for candidate in tile.atoms if candidate.path.startswith(prefix)), None)


def flood(open_cells: set[tuple[int, int]], starts: set[tuple[int, int]]) -> set[tuple[int, int]]:
    seen = set(starts)
    queue = deque(starts)
    while queue:
        x, y = queue.popleft()
        for neighbor in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if neighbor in open_cells and neighbor not in seen:
                seen.add(neighbor)
                queue.append(neighbor)
    return seen


def audit(map_path: Path) -> None:
    tiles_by_z, size = parse_tgm(map_path)
    require(size == (128, 128, 3), f"expected 128x128x3, got {size}")
    tiles = {
        (tile.x, tile.y, tile.z): tile
        for level in tiles_by_z.values()
        for tile in level
    }

    def get(x: int, y: int, z: int = 1) -> Tile:
        return tiles[(x, y, z)]

    def turf(x: int, y: int, z: int = 1) -> str:
        found = atom(get(x, y, z), "/turf/")
        require(found is not None, f"missing turf at {(x, y, z)}")
        return found.path

    routes = widened_routes()
    dangerous = []
    for x, y in routes:
        require(turf(x, y) == NATURALSTONE, f"route turf changed at {(x, y)}: {turf(x, y)}")
        for candidate in get(x, y).atoms:
            if (
                candidate.path.startswith("/mob/")
                or "mineral_door" in candidate.path
                or "/trap/" in candidate.path
                or "beartrap" in candidate.path
            ):
                dangerous.append((x, y, candidate.path))
    require(not dangerous, f"dangerous atoms on protected routes: {dangerous}")

    open_cells = {
        (x, y)
        for y in range(1, 129)
        for x in range(1, 129)
        if turf(x, y).startswith("/turf/open/")
    }
    reachable = flood(open_cells, {(73, 104), (94, 44)})
    require(reachable == open_cells, f"{len(open_cells - reachable)} open cave cells are unreachable")

    direction_delta = {1: (0, 1), 2: (0, -1), 4: (1, 0), 8: (-1, 0)}
    stair_pairs = []
    for z in (1, 2):
        for y in range(1, 129):
            for x in range(1, 129):
                stairs = [candidate for candidate in get(x, y, z).atoms if candidate.path.startswith("/obj/structure/stairs")]
                if not stairs or turf(x, y, z + 1) != OPENSPACE:
                    continue
                direction = int(stairs[0].variables.get("dir", "2"))
                dx, dy = direction_delta[direction]
                partners = [candidate for candidate in get(x + dx, y + dy, z + 1).atoms if candidate.path.startswith("/obj/structure/stairs")]
                if not partners:
                    continue
                require(int(partners[0].variables.get("dir", "2")) == direction, f"stair direction mismatch at {(x, y, z)}")
                stair_pairs.append((x, y, z, x + dx, y + dy, z + 1))
    require(len(stair_pairs) == 9, f"expected 9 stair pairs, got {len(stair_pairs)}")

    for name, (bounds, expected_area, expected_mobs, expected_loot, expected_keys) in MODULES.items():
        x1, y1, x2, y2 = bounds
        counts: Counter[str] = Counter()
        vertical = []
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                for candidate in get(x, y).atoms:
                    counts["area"] += candidate.path == expected_area
                    counts["mobs"] += candidate.path.startswith("/mob/")
                    counts["loot"] += "lootdrop" in candidate.path
                    counts["keys"] += "roguekey" in candidate.path
                    if (
                        candidate.path.startswith("/obj/structure/stairs")
                        or candidate.path.startswith("/obj/structure/ladder")
                        or candidate.path == OPENSPACE
                    ):
                        vertical.append((x, y, candidate.path))
        require(counts["area"] > 0, f"{name} area is missing")
        require((counts["mobs"], counts["loot"], counts["keys"]) == (expected_mobs, expected_loot, expected_keys), f"{name} population mismatch: {dict(counts)}")
        require(not vertical, f"{name} has unpaired vertical atoms: {vertical}")

    path_counts: Counter[str] = Counter()
    lock_ids = set()
    key_ids = set()
    unsafe_support = []
    for tile in tiles_by_z[1]:
        tile_turf = atom(tile, "/turf/")
        require(tile_turf is not None, f"missing turf at {(tile.x, tile.y, tile.z)}")
        for candidate in tile.atoms:
            path_counts[candidate.path] += 1
            lock_id = candidate.variables.get("lockid", "").strip('"')
            if lock_id:
                if "roguekey" in candidate.path:
                    key_ids.add(lock_id)
                elif candidate.path.startswith("/obj/structure/"):
                    lock_ids.add(lock_id)
            if (
                candidate.path.startswith("/mob/")
                or "lootdrop" in candidate.path
                or "roguekey" in candidate.path
                or candidate.path.startswith("/obj/item/roguecoin")
            ) and tile_turf.path in GENERATOR_TURFS:
                unsafe_support.append((tile.x, tile.y, candidate.path, tile_turf.path))
    require(lock_ids == {"drow", "zizochurchtreasure"}, f"unexpected lock IDs: {sorted(lock_ids)}")
    require(key_ids == lock_ids, f"key IDs do not match locks: keys={sorted(key_ids)} locks={sorted(lock_ids)}")
    require(not unsafe_support, f"authored content on generator turfs: {unsafe_support}")
    require(path_counts["/obj/effect/landmark/quest_spawner/hard"] == 1, "expected one hard quest spawner")
    require(path_counts["/obj/effect/landmark/quest_spawner/medium"] == 1, "expected one medium quest spawner")
    require(path_counts["/obj/effect/landmark/mapGenerator/rogue/cave"] == 1, "cave generator count changed")
    require(path_counts["/obj/effect/landmark/mapGenerator/rogue/cave/spider"] == 1, "spider generator count changed")
    require(path_counts["/obj/structure/dungeon_entry/forest"] == 1, "forest dungeon entry count changed")

    tree_count = sum(
        candidate.path.startswith("/obj/structure/flora/newtree")
        for tile in tiles_by_z[2]
        for candidate in tile.atoms
    )
    openspace_count = sum(
        candidate.path == OPENSPACE
        for tile in tiles_by_z[3]
        for candidate in tile.atoms
    )
    require(tree_count == 2928, f"surface tree count changed: {tree_count}")
    require(openspace_count == 13500, f"canopy openspace count changed: {openspace_count}")

    print(f"OK {map_path}")
    print(f"  connected_open_cells={len(open_cells)} protected_route_cells={len(routes)} stair_pairs={len(stair_pairs)}")
    print(f"  surface_trees={tree_count} canopy_openspace={openspace_count} locks={','.join(sorted(lock_ids))}")
    for name, (bounds, _, expected_mobs, expected_loot, expected_keys) in MODULES.items():
        print(f"  {name}: bounds={bounds} mobs={expected_mobs} loot={expected_loot} keys={expected_keys}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", nargs="?", type=Path, default=Path("_maps/map_files/otherz/smallforest.dmm"))
    args = parser.parse_args()
    try:
        audit(args.map)
    except AuditFailure as error:
        parser.exit(1, f"FAIL {args.map}: {error}\n")


if __name__ == "__main__":
    main()
