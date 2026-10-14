/atom/movable
	/// Restored decor is never a saleable or recyclable source of wealth.
	var/housing_decoration = FALSE

/datum/supporter_housing/proc/register_decor(list/paths, minimum_tier = 1)
	for(var/path in paths)
		decor_types["[path]"] = path
		decor_tiers["[path]"] = minimum_tier

/datum/supporter_housing/proc/register_furnishings()
	register_decor(list(
		/obj/structure/chair/wood/rogue/chair4, /obj/structure/chair/wood/rogue/chair5,
		/obj/structure/chair/wood/rogue/fancy, /obj/structure/chair/stool/rogue,
		/obj/structure/chair/bench, /obj/structure/chair/smallbench,
		/obj/structure/bed/rogue, /obj/structure/bed/rogue/inn, /obj/structure/bed/rogue/inn/wool,
		/obj/structure/bed/rogue/inn/hay, /obj/structure/bed/rogue/inn/double, /obj/structure/bed/rogue/inn/wooldouble,
		/obj/structure/table/wood/poor, /obj/structure/table/wood/poor/alt, /obj/structure/table/wood/poor/alt_alt,
		/obj/structure/table/wood/long_table, /obj/structure/table/wood/long_table/right,
		/obj/structure/closet/crate/chest/crafted, /obj/structure/closet/crate/roguecloset,
		/obj/structure/closet/crate/drawer, /obj/structure/fermentation_keg,
		/obj/item/candle/candlestick/gold, /obj/item/candle/candlestick/silver,
		/obj/item/candle/candlestick/gold/single, /obj/item/candle/candlestick/silver/single,
		/obj/item/flashlight/flare/torch, /obj/item/flashlight/flare/torch/metal,
		/obj/item/flashlight/flare/torch/lantern,
		/obj/item/reagent_containers/glass/cup, /obj/item/reagent_containers/glass/cup/wooden,
		/obj/item/reagent_containers/glass/cup/steel, /obj/item/reagent_containers/glass/cup/silver,
		/obj/item/reagent_containers/glass/cup/golden, /obj/item/reagent_containers/glass/cup/ceramic,
		/obj/item/reagent_containers/glass/cup/porcelain,
		/obj/item/reagent_containers/glass/bowl, /obj/item/reagent_containers/glass/bowl/carved/porcelain,
		/obj/item/cooking/platter, /obj/item/cooking/platter/silver, /obj/item/cooking/platter/gold,
	))
	// Exact paths only. /smelter/great and other unlisted machines can never be restored.
	register_decor(list(/obj/machinery/loom, /obj/machinery/tanningrack, /obj/structure/fluff/grindwheel, /obj/structure/fluff/ceramicswheel, /obj/structure/fluff/alch, /obj/machinery/light/rogue/hearth, /obj/machinery/light/rogue/oven), 2)
	register_decor(list(/obj/machinery/anvil, /obj/machinery/anvil/crafted, /obj/machinery/light/rogue/forge, /obj/machinery/light/rogue/smelter, /obj/machinery/light/rogue/cauldron), 3)

/datum/supporter_housing/proc/is_workstation(path)
	return decor_tiers["[path]"] > 1

/datum/supporter_housing/proc/is_light(path)
	return ispath(path, /obj/item/candle) || ispath(path, /obj/item/flashlight) || ispath(path, /obj/machinery/light)

/datum/supporter_housing/proc/prepare_restored(obj/decor)
	decor.housing_decoration = TRUE
	decor.loadout_item = TRUE
	decor.sellprice = 0
	decor.smeltresult = null
	decor.debris = null
	decor.static_debris = null
	decor.reagents?.clear_reagents()
	// Some craftable holders manufacture a torch during Initialize. They must load empty.
	for(var/obj/item/child in decor.contents.Copy())
		for(var/field in decor.vars)
			if(decor.vars[field] == child)
				decor.vars[field] = null
		qdel(child)
	// Restored fixtures may be broken/burned, but dismantling must not mint materials.
	decor.flags_1 |= NODECONSTRUCT_1
	if("metalizer_result" in decor.vars)
		decor.vars["metalizer_result"] = null
	if(istype(decor, /obj/item))
		var/obj/item/item = decor
		item.salvage_result = null
		item.salvage_amount = 0
		item.loadout_item = TRUE
	if(istype(decor, /obj/structure/chair))
		var/obj/structure/chair/chair = decor
		chair.item_chair = null
		chair.buildstacktype = null
	if(istype(decor, /obj/structure/table))
		var/obj/structure/table/table = decor
		table.buildstack = null
	if(istype(decor, /obj/machinery/light/rogue))
		var/obj/machinery/light/rogue/light = decor
		light.burn_out()
		light.fueluse = 0
	// Never import fuel, lit state, a production queue, container contents, or workpieces.
	decor.update_icon()

/datum/supporter_home/proc/placement_fits(path, turf/destination)
	if(!decor_tile(destination) || destination.density)
		return FALSE
	var/obj/shape = path
	var/left = destination.x + FLOOR(initial(shape.bound_x) / 32, 1)
	var/bottom = destination.y + FLOOR(initial(shape.bound_y) / 32, 1)
	var/right = destination.x + FLOOR((initial(shape.bound_x) + max(initial(shape.bound_width), 32) - 1) / 32, 1)
	var/top = destination.y + FLOOR((initial(shape.bound_y) + max(initial(shape.bound_height), 32) - 1) / 32, 1)
	for(var/turf/tile in block(locate(left, bottom, z), locate(right, top, z)))
		if(!decor_tile(tile) || tile.density)
			return FALSE
	return TRUE

/datum/supporter_home/proc/restore_slot_available(path, turf/destination)
	var/obj/shape = path
	var/count = 0
	for(var/obj/existing in destination)
		if(manager.decor_types["[existing.type]"])
			count++
		if(initial(shape.density) && existing.density)
			return FALSE
	return count < 3
