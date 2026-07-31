#!/usr/bin/env python3
"""Render a compact overview and placement audit for a TGM-formatted DMM map."""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


KEY_RE = re.compile(r'^"([A-Za-z]+)" = \($')
BLOCK_RE = re.compile(r'^\((\d+),(\d+),(\d+)\) = \{"$')
PATH_RE = re.compile(r"^(/[^,{)]+)")
VAR_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\n}]+)")


@dataclass(frozen=True)
class Atom:
    path: str
    variables: dict[str, str]


@dataclass(frozen=True)
class Tile:
    x: int
    y: int
    z: int
    atoms: tuple[Atom, ...]


def parse_atoms(lines: list[str]) -> tuple[Atom, ...]:
    atoms: list[Atom] = []
    current: list[str] = []
    brace_depth = 0

    def finish() -> None:
        if not current:
            return
        text = "\n".join(current)
        match = PATH_RE.match(text)
        if match:
            atoms.append(Atom(match.group(1), dict(VAR_RE.findall(text))))
        current.clear()

    for line in lines:
        if line.startswith("/") and brace_depth == 0:
            finish()
        current.append(line.rstrip(","))
        brace_depth += line.count("{") - line.count("}")
    finish()
    return tuple(atoms)


def parse_tgm(path: Path) -> tuple[dict[int, list[Tile]], tuple[int, int, int]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    definitions: dict[str, tuple[Atom, ...]] = {}
    index = 0

    while index < len(lines):
        key_match = KEY_RE.match(lines[index])
        if key_match:
            key = key_match.group(1)
            index += 1
            body: list[str] = []
            while index < len(lines):
                if KEY_RE.match(lines[index]) or BLOCK_RE.match(lines[index]):
                    break
                body.append(lines[index])
                index += 1
            definitions[key] = parse_atoms(body)
            continue
        if BLOCK_RE.match(lines[index]):
            break
        index += 1

    if not definitions:
        raise ValueError(f"{path} does not contain a TGM key dictionary")

    tiles_by_z: dict[int, list[Tile]] = {}
    max_x = max_y = max_z = 0
    while index < len(lines):
        block_match = BLOCK_RE.match(lines[index])
        if not block_match:
            index += 1
            continue
        x, base_y, z = map(int, block_match.groups())
        index += 1
        keys: list[str] = []
        while index < len(lines) and lines[index] != '"}':
            key = lines[index]
            if key not in definitions:
                raise ValueError(f"Unknown map key {key!r} in block ({x},{base_y},{z})")
            keys.append(key)
            index += 1

        # TGM stores each vertical block from north to south (highest Y first),
        # even though the block header contains its lowest Y coordinate.
        for row, key in enumerate(keys):
            y = base_y + len(keys) - row - 1
            tiles_by_z.setdefault(z, []).append(Tile(x, y, z, definitions[key]))
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            max_z = max(max_z, z)
        index += 1

    return tiles_by_z, (max_x, max_y, max_z)


def turf_color(path: str) -> tuple[int, int, int]:
    if path.startswith("/turf/closed"):
        return (35, 38, 42)
    if "openspace" in path or path == "/turf/open/space":
        return (6, 9, 14)
    if "/water" in path:
        return (37, 104, 153)
    if "/lava" in path:
        return (186, 58, 32)
    if "grass" in path:
        return (67, 112, 66)
    if "dirt" in path or "mud" in path:
        return (105, 78, 52)
    if "wood" in path or "twig" in path:
        return (139, 104, 67)
    if "carpet" in path:
        return (112, 49, 62)
    if any(part in path for part in ("stone", "cobble", "brick", "concrete", "tile", "blocks")):
        return (113, 119, 122)
    if path.startswith("/turf/open"):
        return (94, 91, 82)
    return (18, 21, 25)


def atom_paths(tile: Tile) -> list[str]:
    return [atom.path for atom in tile.atoms]


def placement_issue(tile: Tile) -> tuple[list[str], list[str]] | None:
    paths = atom_paths(tile)
    items = [path for path in paths if path.startswith("/obj/item/")]
    if not items:
        return None

    supports = (
        "/obj/structure/table",
        "/obj/structure/rack",
        "/obj/structure/bookcase",
        "/obj/structure/closet",
        "/obj/structure/chest",
        "/obj/structure/bed",
        "/obj/structure/shelf",
        "/obj/structure/roguemachine/stockpile",
    )
    if any(path.startswith(supports) for path in paths):
        return None

    blockers = [
        path
        for path in paths
        if path.startswith(
            (
                "/turf/closed",
                "/obj/structure/mineral_door",
                "/obj/structure/roguewindow",
                "/obj/structure/bars",
                "/obj/structure/stairs",
                "/obj/structure/fluff/railing",
                "/obj/machinery/door",
            )
        )
    ]
    return (items, blockers) if blockers else None


def spawn_blockers(tile: Tile) -> list[str]:
    """Return solid atoms that make a mapped job start unsafe."""
    blockers: list[str] = []
    for path in atom_paths(tile):
        blocked = path.startswith(
            (
                "/turf/closed",
                "/obj/structure/mineral_door",
                "/obj/machinery/door",
                "/obj/structure/table",
                "/obj/structure/bars",
                "/obj/structure/fermentation_keg",
                "/obj/structure/dungeon_entry",
                "/obj/structure/fluff/grindwheel",
                "/obj/machinery/light/rogue/cauldron",
                "/obj/machinery/light/rogue/firebowl",
            )
        )
        if path.startswith("/obj/structure/rack") and "/shelf" not in path:
            blocked = True
        # Coffin starts are intentional late-arrival/resting landmarks.
        if path.startswith("/obj/structure/closet") and "/coffin" not in path:
            blocked = True
        if path.startswith("/obj/machinery/light/rogue/firebowl/standing"):
            blocked = False
        if blocked:
            blockers.append(path)
    return blockers


def render_map(
    tiles_by_z: dict[int, list[Tile]],
    size: tuple[int, int, int],
    output_dir: Path,
    scale: int,
) -> tuple[list[dict[str, str | int]], list[dict[str, str | int]]]:
    width, height, _ = size
    output_dir.mkdir(parents=True, exist_ok=True)
    issues: list[dict[str, str | int]] = []
    spawns: list[dict[str, str | int]] = []

    for z, tiles in sorted(tiles_by_z.items()):
        image = Image.new("RGB", (width * scale, height * scale), (12, 15, 19))
        draw = ImageDraw.Draw(image)
        for tile in tiles:
            paths = atom_paths(tile)
            turf = next((path for path in paths if path.startswith("/turf/")), "")
            left = (tile.x - 1) * scale
            top = (height - tile.y) * scale
            box = (left, top, left + scale - 1, top + scale - 1)
            draw.rectangle(box, fill=turf_color(turf))

            if any(path.startswith("/obj/structure/mineral_door") for path in paths):
                draw.rectangle(box, fill=(68, 181, 190))
            elif any(path.startswith("/obj/structure/roguewindow") for path in paths):
                draw.rectangle(box, fill=(105, 177, 218))

            has_item = any(path.startswith("/obj/item/") for path in paths)
            has_table = any(path.startswith("/obj/structure/table") for path in paths)
            if has_table:
                draw.rectangle(box, outline=(255, 80, 205), width=max(1, scale // 2))
            if has_item:
                radius = max(1, scale // 4)
                cx = left + scale // 2
                cy = top + scale // 2
                draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 195, 55))

            roles = [
                path.removeprefix("/obj/effect/landmark/start/")
                for path in paths
                if path.startswith("/obj/effect/landmark/start/")
            ]
            if roles:
                blockers = spawn_blockers(tile)
                inset = max(1, scale // 5)
                draw.rectangle(
                    (left + inset, top + inset, left + scale - inset - 1, top + scale - inset - 1),
                    outline=(235, 50, 50) if blockers else (70, 255, 110),
                    width=max(1, scale // 3),
                )
                spawns.append(
                    {
                        "x": tile.x,
                        "y": tile.y,
                        "z": tile.z,
                        "roles": "; ".join(roles),
                        "blockers": "; ".join(blockers),
                    }
                )

            issue = placement_issue(tile)
            if issue:
                items, blockers = issue
                draw.rectangle(box, fill=(222, 48, 48))
                issues.append(
                    {
                        "x": tile.x,
                        "y": tile.y,
                        "z": tile.z,
                        "items": "; ".join(items),
                        "blockers": "; ".join(blockers),
                    }
                )

        image.save(output_dir / f"z{z}.png")

    with (output_dir / "placement_issues.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=("x", "y", "z", "items", "blockers"))
        writer.writeheader()
        writer.writerows(issues)
    with (output_dir / "spawn_points.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=("x", "y", "z", "roles", "blockers"))
        writer.writeheader()
        writer.writerows(spawns)
    return issues, spawns


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", type=Path, help="TGM-formatted .dmm file")
    parser.add_argument("output", type=Path, help="directory for z-level PNGs and CSV audit")
    parser.add_argument("--scale", type=int, default=4, help="pixels per map tile (default: 4)")
    args = parser.parse_args()
    if args.scale < 2:
        parser.error("--scale must be at least 2")

    tiles_by_z, size = parse_tgm(args.map)
    issues, spawns = render_map(tiles_by_z, size, args.output, args.scale)
    unsafe_spawns = sum(bool(spawn["blockers"]) for spawn in spawns)
    print(
        f"Rendered {size[2]} z-levels ({size[0]}x{size[1]}); "
        f"{len(issues)} placement issues; {len(spawns)} spawn tiles ({unsafe_spawns} unsafe)"
    )


if __name__ == "__main__":
    main()
