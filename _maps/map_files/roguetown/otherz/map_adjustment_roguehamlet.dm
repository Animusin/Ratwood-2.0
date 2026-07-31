/*
		Rogue Hamlet uses Rockhill's job roster and map-specific balancing.
		The smaller layout supplies fewer physical starts for high-population roles,
		but keeps the same set of professions available.
*/

/datum/map_adjustment/template/rockhill/roguehamlet
	map_file_name = "roguehamlet.dmm"
	realm_name = "Rogue Hamlet"
	threat_regions = list(
		THREAT_REGION_AZURE_GROVE,
		THREAT_REGION_MOUNT_DECAP,
	)

/datum/map_adjustment/template/rockhill/roguehamlet/job_change()
	// Unlike Rockhill, the compact Hamlet garrison has a dedicated sergeant start.
	blacklist -= /datum/job/roguetown/sergeant
	. = ..()

	// Keep roundstart populations within the number of distinct physical starts.
	// Otherwise SSjob reuses an occupied landmark and stacks players on one tile.
	change_job_position(/datum/job/roguetown/monk, 1)
	change_job_position(/datum/job/roguetown/nightmaiden, 2)
	change_job_position(/datum/job/roguetown/councillor, 2)
	change_job_position(/datum/job/roguetown/druid, 2)
	change_job_position(/datum/job/roguetown/wapprentice, 1)
	change_job_position(/datum/job/roguetown/orthodoxist, 2)
	change_job_position(/datum/job/roguetown/prisonerr, 2)
	change_job_position(/datum/job/roguetown/servant, 4)
	change_job_position(/datum/job/roguetown/farmer, 4)
	change_job_position(/datum/job/roguetown/squire, 2)
	change_job_position(/datum/job/roguetown/knavewench, 2)
	change_job_position(/datum/job/roguetown/templar, 1)
	change_job_position(/datum/job/roguetown/villager, 5)
	change_job_position(/datum/job/roguetown/orphan, 4)
	return .

/*
	Compatibility aliases for the compact wilderness map which originally
	shipped with Rogue Hamlet. These preserve its layout while using current
	codebase behavior and equipment.
*/

/area/rogue/outdoors/river
	parent_type = /area/rogue/outdoors/woods

/area/rogue/outdoors/woods_safe
	parent_type = /area/rogue/outdoors/woods

/mob/living/simple_animal/hostile/retaliate/rogue/saigabuck
	parent_type = /mob/living/simple_animal/hostile/retaliate/rogue/saiga/saigabuck

/obj/effect/landmark/start/pilgrim
	parent_type = /obj/effect/landmark/start/adventurer

/obj/item/reagent_containers/glass/bucket/wooden
	parent_type = /obj/item/reagent_containers/glass/bucket

/obj/machinery/light/rogue/lanternpost/fixed
	parent_type = /obj/machinery/light/rogue/lanternpost

/obj/structure/bed/rogue/hay
	parent_type = /obj/structure/bed/rogue/inn/hay

/obj/structure/chair/bench/ancientlog
	parent_type = /obj/structure/chair/bench

/obj/structure/fermenting_barrel
	parent_type = /obj/structure/fermentation_keg

/obj/structure/flora/newtree/scorched
	parent_type = /obj/structure/flora/newtree

/obj/structure/flora/rogueflower/ppflowers
	parent_type = /obj/structure/flora/ausbushes/ppflowers

/obj/structure/kneestingers
	parent_type = /obj/structure/trap/bogtrap/kneestingers

/obj/structure/roguetent/preopen
	parent_type = /obj/structure/roguetent

/obj/structure/roguewindow/solid
	parent_type = /obj/structure/roguewindow

/turf/open/floor/rogue/ruinedwood/darker
	parent_type = /turf/open/floor/rogue/ruinedwood
