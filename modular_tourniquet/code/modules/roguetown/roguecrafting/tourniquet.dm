// Tourniquet crafting. Inherits the needle, the tanning rack and the skincrafting
// skill from /datum/crafting_recipe/roguetown/leather, so the only thing declared
// here is the cost and the expert requirement.
/datum/crafting_recipe/roguetown/leather/tourniquet
	name = "tourniquet"
	result = list(/obj/item/natural/cloth/tourniquet)
	reqs = list(/obj/item/natural/hide/cured = 1,
				/obj/item/natural/fibers = 2)
	craftdiff = SKILL_LEVEL_EXPERT
	display_category = ITEM_CAT_TOOLS_SUNDRIES
