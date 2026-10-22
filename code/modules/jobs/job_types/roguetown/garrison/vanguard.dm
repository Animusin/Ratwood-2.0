// Keep the legacy path so existing maps and job flags remain compatible.
/datum/job/roguetown/vanguard
	title = "Levy"
	flag = BOGGUARD
	department_flag = GARRISON
	faction = "Station"
	total_positions = 5
	spawn_positions = 5
	selection_color = JCOLOR_SOLDIER

	allowed_sexes = list(MALE, FEMALE)
	allowed_races = ACCEPTED_RACES
	allowed_ages = list(AGE_ADULT, AGE_MIDDLEAGED, AGE_OLD)
	tutorial = "Pressed into the Crown's service with a helmet, a household weapon and a bottle of beer, you are the first to answer reports of danger beyond the walls. Patrol the outskirts, answer to the lowtown baron and Master Warden, and hold the line until the Wardens or garrison arrive. Your weapon and former occupation determine what you bring to the Levy."
	display_order = JDO_TOWNGUARD
	whitelist_req = TRUE

	outfit = null // The single subclass handles both choices and equips once.
	visuals_only_outfit = /datum/outfit/job/roguetown/levy/preview
	advclass_cat_rolls = list(CTAG_VANGUARD = 20)

	give_bank_account = 8
	min_pq = 0
	max_pq = null
	round_contrib_points = 2
	cmode_music = 'sound/music/combat_blackoak.ogg'
	social_rank = SOCIAL_RANK_PEASANT
	job_traits = list(TRAIT_LEVY)
	job_subclasses = list(/datum/advclass/levy)
