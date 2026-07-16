/*
		Rogue Hamlet uses Rockhill's job roster and map-specific balancing.
		The smaller layout supplies fewer physical starts for high-population roles,
		but keeps the same set of professions available.
*/

/datum/map_adjustment/template/rockhill/roguehamlet
	map_file_name = "roguehamlet.dmm"
	realm_name = "Rogue Hamlet"

/datum/map_adjustment/template/rockhill/roguehamlet/job_change()
	// Unlike Rockhill, the compact Hamlet garrison has a dedicated sergeant start.
	blacklist -= /datum/job/roguetown/sergeant
	return ..()
