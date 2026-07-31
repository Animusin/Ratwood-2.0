#!/usr/bin/env python3
"""Inspect TGM map contents without opening Dream Maker."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

from render_tgm import Atom, parse_tgm


def format_atom(atom: Atom) -> str:
    if not atom.variables:
        return atom.path
    variables = "; ".join(f"{name}={value}" for name, value in sorted(atom.variables.items()))
    return f"{atom.path} {{{variables}}}"


def parse_coordinate(value: str) -> tuple[int, int, int]:
    try:
        coordinate = tuple(int(part) for part in value.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("coordinates must be X,Y,Z") from error
    if len(coordinate) != 3 or any(part < 1 for part in coordinate):
        raise argparse.ArgumentTypeError("coordinates must be positive X,Y,Z")
    return coordinate


def print_counter(title: str, counter: Counter[str], limit: int) -> None:
    print(f"  {title}: {sum(counter.values())}")
    for atom_path, count in counter.most_common(limit):
        print(f"    {count:6}  {atom_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", type=Path, help="TGM-formatted .dmm map")
    parser.add_argument("--z", dest="levels", type=int, action="append", help="inspect only this z-level; repeatable")
    parser.add_argument("--top", type=int, default=20, help="number of paths shown per category")
    parser.add_argument("--find", action="append", default=[], help="case-insensitive path fragment to locate; repeatable")
    parser.add_argument("--at", type=parse_coordinate, action="append", default=[], help="print one X,Y,Z tile; repeatable")
    args = parser.parse_args()

    tiles_by_z, size = parse_tgm(args.map)
    selected_levels = args.levels or sorted(tiles_by_z)
    invalid = [level for level in selected_levels if level not in tiles_by_z]
    if invalid:
        parser.error(f"z-levels outside map: {invalid}")

    print(f"map={args.map} size={size[0]}x{size[1]}x{size[2]}")
    for level in selected_levels:
        areas: Counter[str] = Counter()
        turfs: Counter[str] = Counter()
        movables: Counter[str] = Counter()
        for tile in tiles_by_z[level]:
            for atom in tile.atoms:
                if atom.path.startswith("/area/"):
                    areas[atom.path] += 1
                elif atom.path.startswith("/turf/"):
                    turfs[atom.path] += 1
                else:
                    movables[atom.path] += 1
        print(f"z={level} tiles={len(tiles_by_z[level])}")
        print_counter("areas", areas, args.top)
        print_counter("turfs", turfs, args.top)
        print_counter("movables", movables, args.top)

    coordinate_index = {
        (tile.x, tile.y, tile.z): tile
        for tiles in tiles_by_z.values()
        for tile in tiles
    }
    for coordinate in args.at:
        tile = coordinate_index.get(coordinate)
        print(f"tile={coordinate}")
        if tile is None:
            print("  outside map")
            continue
        for atom in tile.atoms:
            print(f"  {format_atom(atom)}")

    for fragment in args.find:
        needle = fragment.casefold()
        matches = []
        for tiles in tiles_by_z.values():
            for tile in tiles:
                for atom in tile.atoms:
                    if needle in atom.path.casefold():
                        matches.append((tile.x, tile.y, tile.z, atom))
        print(f"find={fragment!r} matches={len(matches)}")
        for x, y, z, atom in matches:
            print(f"  ({x},{y},{z}) {format_atom(atom)}")


if __name__ == "__main__":
    main()
