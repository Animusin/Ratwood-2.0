/datum/supporter_housing/proc/register_wall_types()
	for(var/path in list(/turf/closed/wall/mineral/rogue/wood, /turf/closed/wall/mineral/rogue/wood/window, /turf/closed/wall/mineral/rogue/wooddark, /turf/closed/wall/mineral/rogue/wooddark/window, /turf/closed/wall/mineral/rogue/decowood, /turf/closed/wall/mineral/rogue/stone, /turf/closed/wall/mineral/rogue/stone/window, /turf/closed/wall/mineral/rogue/stonebrick, /turf/closed/wall/mineral/rogue/stonebrick/stonebricklight, /turf/closed/wall/mineral/rogue/decostone, /turf/closed/wall/mineral/rogue/craftstone, /turf/closed/wall/mineral/rogue/brick, /turf/closed/wall/mineral/rogue/brick/window, /turf/open/floor/rogue/ruinedwood, /turf/open/floor/rogue/wood, /turf/open/floor/rogue/dirt, /turf/open/floor/rogue/grass, /turf/open/floor/rogue/cobble))
		wall_types["[path]"] = path

/datum/supporter_home
	/// Baseline geometry of this round's size. Save deltas, rather than entire maps.
	var/list/base_turfs = list()
	var/list/base_colors = list()
	var/list/base_directions = list()
	var/list/applied_geometry = list()

/datum/supporter_home/proc/structural_tile(turf/tile)
	return contains(tile) && tile.x >= x + 2 && tile.x <= x + width - 3 && tile.y >= y + 5 && tile.y <= y + height - 3 && !(tile.x == x + FLOOR(width / 2, 1) && tile.y <= y + 8)

/datum/supporter_home/proc/capture_base_turfs()
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		if(structural_tile(tile))
			base_turfs["[tile.x - x + 1],[tile.y - y + 1]"] = tile.type
			base_colors["[tile.x - x + 1],[tile.y - y + 1]"] = tile.color
			base_directions["[tile.x - x + 1],[tile.y - y + 1]"] = tile.dir

/datum/supporter_home/proc/restore_walls(list/records)
	var/list/active_decor_tiles = list()
	var/list/applied_tiles = list()
	for(var/list/record as anything in records)
		if(record["kind"] != "wall" && !record["archived"])
			active_decor_tiles["[record["x"]],[record["y"]]"] = TRUE
	for(var/list/record as anything in records)
		if(record["kind"] != "wall")
			continue
		var/turf/destination = locate(x + record["x"] - 1, y + record["y"] - 1, z)
		var/tile_id = "[record["x"]],[record["y"]]"
		if(!structural_tile(destination) || (record["archived"] && (active_decor_tiles[tile_id] || applied_tiles[tile_id])))
			archive += list(record.Copy())
			continue
		var/path = manager.wall_types[record["type"]]
		destination = destination.ChangeTurf(path)
		destination.dir = record["dir"]
		if(record["color"])
			destination.color = record["color"]
		var/list/applied_record = record.Copy()
		applied_record -= "archived"
		applied_geometry[tile_id] = applied_record
		applied_tiles[tile_id] = TRUE

/datum/supporter_home/proc/snapshot_walls(list/records)
	for(var/turf/tile in block(locate(x, y, z), locate(x + width - 1, y + height - 1, z)))
		if(!structural_tile(tile))
			continue
		var/tile_id = "[tile.x - x + 1],[tile.y - y + 1]"
		if(tile.type == base_turfs[tile_id] && tile.color == base_colors[tile_id] && tile.dir == base_directions[tile_id])
			var/list/seed = applied_geometry[tile_id]
			// An old removed wall may match the larger template's floor. Keep that explicit
			// removal so returning to the smaller layout does not resurrect the wall.
			if(seed && seed["type"] == "[tile.type]" && (!seed["color"] || seed["color"] == tile.color) && seed["dir"] == tile.dir)
				records += list(seed.Copy())
			continue
		if(!manager.wall_types["[tile.type]"])
			snapshot_error = "[initial(tile.name)] at home position [tile.x - x + 1], [tile.y - y + 1] cannot be saved. Replace it with a supported wall or floor."
			return FALSE
		records += list(list("kind" = "wall", "type" = "[tile.type]", "x" = tile.x - x + 1, "y" = tile.y - y + 1, "dir" = tile.dir, "color" = istext(tile.color) ? tile.color : null))
	return TRUE
