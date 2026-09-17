/// F7 customization. These tables are shared and read-only during a round.
/// Keep ids stable: personal saves store ids, while labels may be renamed freely.
/// Subgroups use the first matching root; put specific types before broader types.
/// Use DM typepaths so a removed or misspelled root fails at compile time.

/proc/buildmode_catalog_categories()
	var/static/list/categories = list(
		"all" = "Всё",
		"favorites" = "Избранное",
		"recent" = "Недавние",
		"weapons" = "Оружие",
		"clothing" = "Одежда и броня",
		"items" = "Предметы",
		"objects" = "Объекты",
		"turfs" = "Полы и стены",
		"mobs" = "Существа",
		"food" = "Еда",
		"reagents" = "Ёмкости",
		"effects" = "Служебные",
	)
	return categories

// Classification order is separate from the sidebar display order above.
/proc/buildmode_catalog_category(target_type)
	if(ispath(target_type, /turf))
		return "turfs"
	if(ispath(target_type, /mob))
		return "mobs"
	if(ispath(target_type, /obj/item/clothing))
		return "clothing"
	if(ispath(target_type, /obj/item/rogueweapon) || ispath(target_type, /obj/item/gun))
		return "weapons"
	if(ispath(target_type, /obj/item/reagent_containers/food/snacks))
		return "food"
	if(ispath(target_type, /obj/item/reagent_containers))
		return "reagents"
	if(ispath(target_type, /obj/item))
		return "items"
	if(ispath(target_type, /obj/effect))
		return "effects"
	return "objects"

/proc/buildmode_catalog_armor_classes()
	var/static/list/classes = list(
		"all" = "Любой класс",
		"[ARMOR_CLASS_NONE]" = "Без класса",
		"[ARMOR_CLASS_LIGHT]" = "Лёгкая",
		"[ARMOR_CLASS_MEDIUM]" = "Средняя",
		"[ARMOR_CLASS_HEAVY]" = "Тяжёлая",
	)
	return classes

/proc/buildmode_catalog_coverage_zones()
	var/static/list/zones = list(
		"all" = list("name" = "Любое покрытие", "mask" = 0),
		"head" = list("name" = "Голова", "mask" = HEAD),
		"face" = list("name" = "Лицо", "mask" = (MOUTH | NOSE | EYES)),
		"neck" = list("name" = "Шея", "mask" = NECK),
		"chest" = list("name" = "Грудь", "mask" = CHEST),
		"arms" = list("name" = "Руки", "mask" = ARMS),
		"hands" = list("name" = "Кисти", "mask" = HANDS),
		"groin" = list("name" = "Пах", "mask" = GROIN),
		"legs" = list("name" = "Ноги", "mask" = LEGS),
		"feet" = list("name" = "Ступни", "mask" = FEET),
	)
	return zones

/proc/buildmode_catalog_groups()
	var/static/list/groups
	if(groups)
		return groups
	groups = list()
	groups["weapons"] = list(
		"greatswords" = list("name" = "Двуручные мечи", "roots" = list(/obj/item/rogueweapon/greatsword)),
		"swords" = list(
			"name" = "Мечи",
			"roots" = list(
				/obj/item/rogueweapon/sword,
				/obj/item/rogueweapon/estoc,
			),
		),
		"knives" = list(
			"name" = "Ножи и кинжалы",
			"roots" = list(
				/obj/item/rogueweapon/huntingknife,
				/obj/item/rogueweapon/katar,
			),
		),
		"axes" = list(
			"name" = "Топоры",
			"roots" = list(
				/obj/item/rogueweapon/greataxe,
				/obj/item/rogueweapon/stoneaxe,
			),
		),
		"maces" = list(
			"name" = "Булавы и молоты",
			"roots" = list(
				/obj/item/rogueweapon/mace,
				/obj/item/rogueweapon/hammer,
				/obj/item/rogueweapon/eaglebeak,
				/obj/item/rogueweapon/lordscepter,
			),
		),
		"flails" = list("name" = "Цепы", "roots" = list(/obj/item/rogueweapon/flail)),
		"polearms" = list(
			"name" = "Древковое",
			"roots" = list(
				/obj/item/rogueweapon/spear,
				/obj/item/rogueweapon/light_spear,
				/obj/item/rogueweapon/halberd,
				/obj/item/rogueweapon/fishspear,
				/obj/item/rogueweapon/pitchfork,
				/obj/item/rogueweapon/scythe,
			),
		),
		"staves" = list("name" = "Посохи", "roots" = list(/obj/item/rogueweapon/woodstaff)),
		"whips" = list("name" = "Кнуты", "roots" = list(/obj/item/rogueweapon/whip)),
		"shields" = list("name" = "Щиты", "roots" = list(/obj/item/rogueweapon/shield)),
		"ranged" = list(
			"name" = "Стрелковое",
			"roots" = list(
				/obj/item/gun,
				/obj/item/rogueweapon/blowrod,
			),
		),
		"tools" = list(
			"name" = "Инструменты",
			"roots" = list(
				/obj/item/rogueweapon/chisel,
				/obj/item/rogueweapon/handsaw,
				/obj/item/rogueweapon/hoe,
				/obj/item/rogueweapon/pick,
				/obj/item/rogueweapon/shovel,
				/obj/item/rogueweapon/sickle,
				/obj/item/rogueweapon/surgery,
				/obj/item/rogueweapon/thresher,
				/obj/item/rogueweapon/tongs,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["objects"] = list(
		"doors" = list(
			"name" = "Двери и ограждения",
			"roots" = list(
				/obj/structure/mineral_door,
				/obj/structure/roguewindow,
				/obj/structure/gate,
				/obj/structure/gate_vertical,
				/obj/structure/floordoor,
				/obj/structure/bars,
				/obj/structure/fence,
				/obj/structure/barricade,
				/obj/structure/curtain,
				/obj/structure/fluff/railing,
			),
		),
		"storage" = list(
			"name" = "Хранилища",
			"roots" = list(
				/obj/structure/closet,
				/obj/structure/bookcase,
				/obj/structure/rack,
				/obj/structure/stone_rack,
				/obj/structure/displaycase,
				/obj/structure/reliquarybox,
				/obj/structure/loot,
			),
		),
		"furniture" = list(
			"name" = "Мебель",
			"roots" = list(
				/obj/structure/table,
				/obj/structure/chair,
				/obj/structure/bed,
				/obj/structure/roguethrone,
				/obj/structure/vampthrone,
				/obj/structure/thronething,
				/obj/structure/toilet,
				/obj/structure/mirror,
				/obj/structure/mannequin,
				/obj/structure/piano,
				/obj/structure/easel,
				/obj/structure/fluff/pillow,
			),
		),
		"workshops" = list(
			"name" = "Мастерские",
			"roots" = list(
				/obj/structure/fluff/grindwheel,
				/obj/structure/fluff/ceramicswheel,
				/obj/structure/autogrinder,
				/obj/structure/autosmither,
				/obj/structure/fermentation_keg,
				/obj/machinery/anvil,
				/obj/machinery/light/rogue/forge,
				/obj/machinery/light/rogue/oven,
				/obj/machinery/loom,
				/obj/machinery/tanningrack,
			),
		),
		"lighting" = list(
			"name" = "Освещение и огонь",
			"roots" = list(
				/obj/machinery/light,
				/obj/structure/life_candle,
			),
		),
		"nature" = list(
			"name" = "Природа и хозяйство",
			"roots" = list(
				/obj/structure/flora,
				/obj/structure/soil,
				/obj/structure/soil_seedling,
				/obj/structure/tree_sapling,
				/obj/structure/bush_sapling,
				/obj/structure/wild_plant,
				/obj/structure/roguerock,
				/obj/structure/roguesand,
				/obj/structure/vine,
				/obj/structure/mushroom_sprout,
				/obj/structure/flower_sprout,
				/obj/structure/composter,
				/obj/structure/apiary,
				/obj/structure/beehive,
				/obj/structure/plough,
				/obj/structure/well,
				/obj/structure/fluff/nest,
			),
		),
		"travel" = list(
			"name" = "Лестницы и переходы",
			"roots" = list(
				/obj/structure/stairs,
				/obj/structure/ladder,
				/obj/structure/wallladder,
				/obj/structure/rope_ladder,
				/obj/structure/portal,
				/obj/structure/portal_jaunt,
				/obj/structure/dungeon_entry,
				/obj/structure/dungeon_exit,
				/obj/structure/industrial_lift,
				/obj/structure/minecart_rail,
				/obj/structure/fluff/traveltile,
			),
		),
		"machines" = list(
			"name" = "Механизмы",
			"roots" = list(
				/obj/structure/roguemachine,
				/obj/structure/gearbox,
				/obj/structure/vertical_gearbox,
				/obj/structure/lever,
				/obj/structure/winch,
				/obj/structure/waterwheel,
				/obj/structure/windmill,
				/obj/structure/bombard,
				/obj/machinery,
			),
		),
		"decoration" = list(
			"name" = "Украшения",
			"roots" = list(
				/obj/structure/fluff,
				/obj/structure/statue,
				/obj/structure/flagpole,
				/obj/structure/gravemarker,
				/obj/structure/bonepile,
				/obj/structure/bearpelt,
				/obj/structure/bobcatpelt,
				/obj/structure/foxpelt,
				/obj/structure/giantfur,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["items"] = list(
		"storage" = list(
			"name" = "Сумки и контейнеры",
			"roots" = list(
				/obj/item/storage,
				/obj/item/parcel,
				/obj/item/bodybag,
			),
		),
		"materials" = list(
			"name" = "Материалы",
			"roots" = list(
				/obj/item/natural,
				/obj/item/ingot,
				/obj/item/rogueore,
				/obj/item/roguegem,
				/obj/item/carvedgem,
				/obj/item/scrap,
				/obj/item/shaft,
				/obj/item/construction,
			),
		),
		"ammo" = list(
			"name" = "Боеприпасы",
			"roots" = list(
				/obj/item/ammo_casing,
				/obj/item/ammo_box,
				/obj/item/cannonball,
				/obj/item/powderflask,
				/obj/item/ramrod,
			),
		),
		"books" = list(
			"name" = "Книги и бумаги",
			"roots" = list(
				/obj/item/book,
				/obj/item/paper,
				/obj/item/recipe_book,
				/obj/item/skillbook,
				/obj/item/manuscript,
			),
		),
		"keys" = list(
			"name" = "Ключи и деньги",
			"roots" = list(
				/obj/item/roguekey,
				/obj/item/skeleton_key,
				/obj/item/lockpick,
				/obj/item/lockpickring,
				/obj/item/roguecoin,
				/obj/item/mattcoin,
			),
		),
		"magic" = list(
			"name" = "Магия и алхимия",
			"roots" = list(
				/obj/item/magic,
				/obj/item/alch,
				/obj/item/staff,
				/obj/item/rune,
				/obj/item/enchantmentscroll,
				/obj/item/teleportation_scroll,
				/obj/item/scrying,
				/obj/item/phylactery,
				/obj/item/scomstone,
			),
		),
		"lighting" = list(
			"name" = "Свет и огонь",
			"roots" = list(
				/obj/item/flashlight,
				/obj/item/candle,
				/obj/item/match,
				/obj/item/lighter,
				/obj/item/flint,
				/obj/item/signal_flare,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["reagents"] = list(
		"bottles" = list("name" = "Бутылки", "roots" = list(/obj/item/reagent_containers/glass/bottle)),
		"drinking" = list(
			"name" = "Кружки и чаши",
			"roots" = list(
				/obj/item/reagent_containers/glass/cup,
				/obj/item/reagent_containers/glass/cup/wooden,
			),
		),
		"powders" = list("name" = "Порошки и лекарства", "roots" = list(/obj/item/reagent_containers/powder)),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["food"] = list(
		"produce" = list("name" = "Урожай", "roots" = list(/obj/item/reagent_containers/food/snacks/grown)),
		"meat" = list("name" = "Мясо и рыба", "roots" = list(/obj/item/reagent_containers/food/snacks/rogue/meat)),
		"bread" = list(
			"name" = "Хлеб и выпечка",
			"roots" = list(
				/obj/item/reagent_containers/food/snacks/rogue/bread,
				/obj/item/reagent_containers/food/snacks/rogue/pie,
				/obj/item/reagent_containers/food/snacks/rogue/cake,
				/obj/item/reagent_containers/food/snacks/rogue/biscuit,
				/obj/item/reagent_containers/food/snacks/rogue/cookie,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["mobs"] = list(
		"humans" = list("name" = "Люди", "roots" = list(/mob/living/carbon/human)),
		"hostile" = list("name" = "Враждебные", "roots" = list(/mob/living/simple_animal/hostile)),
		"animals" = list(
			"name" = "Животные",
			"roots" = list(
				/mob/living/simple_animal,
				/mob/living/basic,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["turfs"] = list(
		"walls" = list("name" = "Стены", "roots" = list(/turf/closed/wall)),
		"floors" = list("name" = "Полы", "roots" = list(/turf/open/floor)),
		"water" = list(
			"name" = "Вода и лава",
			"roots" = list(
				/turf/open/water,
				/turf/open/lava,
			),
		),
		"open" = list("name" = "Открытые клетки", "roots" = list(/turf/open)),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	groups["effects"] = list(
		"decals" = list(
			"name" = "Следы и декали",
			"roots" = list(
				/obj/effect/decal,
				/obj/effect/turf_decal,
			),
		),
		"visuals" = list(
			"name" = "Визуальные эффекты",
			"roots" = list(
				/obj/effect/temp_visual,
				/obj/effect/visuals,
				/obj/effect/overlay,
				/obj/effect/particle_effect,
				/obj/effect/beam,
				/obj/effect/ebeam,
			),
		),
		"spawners" = list(
			"name" = "Спавнеры",
			"roots" = list(
				/obj/effect/spawner,
				/obj/effect/mob_spawn,
				/obj/effect/gibspawner,
				/obj/effect/quest_spawn,
			),
		),
		"mapping" = list(
			"name" = "Метки карты",
			"roots" = list(
				/obj/effect/landmark,
				/obj/effect/mapping_helpers,
				/obj/effect/baseturf_helper,
			),
		),
		"other" = list("name" = "Прочее", "roots" = list()),
	)
	return groups
