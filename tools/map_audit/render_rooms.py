#!/usr/bin/env python3
"""Render a room-by-room atlas with furniture and job-start overlays."""

from __future__ import annotations

import argparse
import csv
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from render_tgm import Tile, atom_paths, parse_tgm, spawn_blockers, turf_color


START_PREFIX = "/obj/effect/landmark/start/"
INDOOR_AREAS = (
    "/area/rogue/indoors",
    "/area/rogue/under/town/basement",
)
DOOR_PREFIXES = (
    "/obj/structure/mineral_door",
    "/obj/machinery/door",
)


def tile_area(tile: Tile) -> str:
    return next((path for path in atom_paths(tile) if path.startswith("/area/")), "")


def tile_turf(tile: Tile) -> str:
    return next((path for path in atom_paths(tile) if path.startswith("/turf/")), "")


def is_room_floor(tile: Tile) -> bool:
    area = tile_area(tile)
    turf = tile_turf(tile)
    paths = atom_paths(tile)
    return (
        area.startswith(INDOOR_AREAS)
        and turf.startswith("/turf/open")
        and "openspace" not in turf
        and turf != "/turf/open/space"
        and not any(path.startswith(DOOR_PREFIXES) for path in paths)
    )


def room_components(tiles: list[Tile], minimum_size: int) -> list[set[tuple[int, int]]]:
    floors = {(tile.x, tile.y) for tile in tiles if is_room_floor(tile)}
    components: list[set[tuple[int, int]]] = []
    while floors:
        origin = floors.pop()
        component = {origin}
        queue = deque([origin])
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in floors:
                    floors.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        if len(component) >= minimum_size:
            components.append(component)
    return sorted(components, key=lambda room: (-max(y for _, y in room), min(x for x, _ in room)))


def job_starts(tile: Tile) -> list[str]:
    starts = []
    for path in atom_paths(tile):
        if path.startswith(START_PREFIX):
            starts.append(path.removeprefix(START_PREFIX))
        elif path == "/obj/effect/landmark/start":
            starts.append("generic")
    return starts


def object_glyphs(tile: Tile) -> list[tuple[str, tuple[int, int, int]]]:
    paths = atom_paths(tile)
    rules = (
        (("/obj/structure/mineral_door", "/obj/machinery/door"), "D", (65, 225, 235)),
        (("/obj/structure/roguewindow",), "W", (120, 205, 255)),
        (("/obj/structure/table",), "T", (255, 85, 205)),
        (("/obj/structure/chair",), "c", (230, 160, 80)),
        (("/obj/structure/bed",), "B", (225, 225, 235)),
        (("/obj/structure/closet", "/obj/structure/chest"), "H", (210, 130, 45)),
        (("/obj/structure/bookcase",), "K", (180, 110, 55)),
        (("/obj/structure/rack", "/obj/structure/shelf"), "R", (205, 145, 70)),
        (("/obj/structure/stairs",), "^", (250, 245, 155)),
        (("/obj/machinery/light", "/obj/structure/fluff/railing"), "|", (145, 145, 150)),
        (("/obj/machinery/oven", "/obj/structure/oven", "/obj/structure/cookfire"), "O", (255, 105, 45)),
        (("/obj/structure/cauldron",), "A", (165, 100, 230)),
    )
    result = []
    for prefixes, glyph, color in rules:
        if any(path.startswith(prefixes) for path in paths):
            result.append((glyph, color))
    if any(path.startswith("/obj/item/") for path in paths):
        result.append(("*", (255, 205, 55)))
    return result[:2]


def short_area_name(area: str) -> str:
    return area.removeprefix("/area/rogue/").replace("/", "-") or "room"


def render_room(
    room: set[tuple[int, int]],
    tiles_by_coord: dict[tuple[int, int], Tile],
    z: int,
    room_number: int,
    output: Path,
    scale: int,
) -> dict[str, str | int]:
    padding = 2
    min_x = max(1, min(x for x, _ in room) - padding)
    max_x = max(x for x, _ in room) + padding
    min_y = max(1, min(y for _, y in room) - padding)
    max_y = max(y for _, y in room) + padding
    panel_width = 260
    map_width = (max_x - min_x + 1) * scale
    map_height = (max_y - min_y + 1) * scale
    image = Image.new("RGB", (map_width + panel_width, max(map_height, 150)), (13, 16, 20))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    starts: list[tuple[str, int, int, list[str]]] = []
    areas = Counter()

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            tile = tiles_by_coord.get((x, y))
            left = (x - min_x) * scale
            top = (max_y - y) * scale
            box = (left, top, left + scale - 1, top + scale - 1)
            if not tile:
                draw.rectangle(box, fill=(8, 10, 13))
                continue
            color = turf_color(tile_turf(tile))
            if (x, y) not in room:
                color = tuple(channel // 2 for channel in color)
            draw.rectangle(box, fill=color, outline=(30, 33, 37))
            if (x, y) in room:
                areas[tile_area(tile)] += 1
            glyphs = object_glyphs(tile)
            for index, (glyph, glyph_color) in enumerate(glyphs):
                draw.text((left + 2 + index * (scale // 2), top + 1), glyph, fill=glyph_color, font=font)
            for role in job_starts(tile) if (x, y) in room else ():
                blockers = spawn_blockers(tile)
                starts.append((role, x, y, blockers))
                ring = (left + 1, top + 1, left + scale - 2, top + scale - 2)
                draw.ellipse(ring, outline=(255, 55, 55) if blockers else (65, 255, 105), width=2)

    area = areas.most_common(1)[0][0] if areas else ""
    title = f"z{z} room {room_number:02d}  {short_area_name(area)}"
    draw.text((map_width + 10, 10), title, fill=(245, 245, 245), font=font)
    draw.text((map_width + 10, 28), f"bbox ({min_x},{min_y})-({max_x},{max_y})", fill=(170, 175, 185), font=font)
    draw.text((map_width + 10, 44), f"floor tiles: {len(room)}", fill=(170, 175, 185), font=font)
    draw.text((map_width + 10, 66), "starts:", fill=(245, 245, 245), font=font)
    line_y = 82
    for role, x, y, blockers in starts:
        warning = " !" if blockers else ""
        draw.text((map_width + 10, line_y), f"{role} ({x},{y}){warning}", fill=(255, 90, 90) if blockers else (105, 245, 130), font=font)
        line_y += 14
    if not starts:
        draw.text((map_width + 10, line_y), "none", fill=(125, 130, 140), font=font)
        line_y += 14
    draw.text((map_width + 10, line_y + 8), "T table  c chair  B bed", fill=(190, 190, 195), font=font)
    draw.text((map_width + 10, line_y + 22), "O oven  A cauldron  ^ stairs", fill=(190, 190, 195), font=font)
    draw.text((map_width + 10, line_y + 36), "D door  W window  * item", fill=(190, 190, 195), font=font)

    filename = f"z{z}_room_{room_number:02d}_{short_area_name(area)}.png"
    image.save(output / filename)
    return {
        "z": z,
        "room": room_number,
        "area": area,
        "floor_tiles": len(room),
        "min_x": min_x + padding,
        "min_y": min_y + padding,
        "max_x": max_x - padding,
        "max_y": max_y - padding,
        "starts": "; ".join(f"{role}@{x},{y}" for role, x, y, _ in starts),
        "spawn_issues": "; ".join(
            f"{role}@{x},{y}: {','.join(blockers)}" for role, x, y, blockers in starts if blockers
        ),
        "image": filename,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--scale", type=int, default=20)
    parser.add_argument("--minimum-size", type=int, default=4)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    tiles_by_z, _ = parse_tgm(args.map)
    rows = []
    for z, tiles in sorted(tiles_by_z.items()):
        by_coord = {(tile.x, tile.y): tile for tile in tiles}
        for number, room in enumerate(room_components(tiles, args.minimum_size), 1):
            rows.append(render_room(room, by_coord, z, number, args.output, args.scale))

    with (args.output / "rooms.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys() if rows else ("z", "room"))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Rendered {len(rows)} rooms; {sum(bool(row['spawn_issues']) for row in rows)} have suspicious starts")


if __name__ == "__main__":
    main()
