/datum/asset/spritesheet/anvil_recipes
	name = "anvil_recipes"
	// Build the recipe icons during startup so opening the anvil cannot force a cold build.
	load_immediately = TRUE

/datum/asset/spritesheet/anvil_recipes/create_spritesheets()
	for(var/datum/anvil_recipe/recipe as anything in GLOB.anvil_recipes)
		var/icon = recipe.created_item::icon
		var/icon_state = recipe.created_item::icon_state

		if(!icon || !icon_state)
			continue

		Insert("[sanitize_css_class_name("recipe_[REF(recipe)]")]", icon, icon_state)
