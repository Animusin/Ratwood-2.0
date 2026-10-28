// A skill, currently meant to be for towner towner (excluding towner, the more freeform role atm)
// Allows you to take on an apprentice, giving them one of the skill gating traits
// And giving them Novice in corresponding skills. 
// Meant to be used once per round per character. Cannot have more than one apprentice per character.
// Encourage people to encourage w/ towners to get skills and give them a point of leverage.
/obj/effect/proc_holder/spell/invoked/takeapprentice
	name = "Take Apprentice"
	desc = "You can take on an apprentice, giving them a trait and Novice in corresponding skills. You can only have one apprentice and you cannot take someone who already have a mentor as your apprentice. \n\
	Should your apprentice disappears completely (e.g. leaving the round), you may take on another apprentice."
	overlay_state = "craft_buff"
	releasedrain = 50
	chargedrain = 0
	chargetime = 3 SECONDS // A charge time mostly to render it useless for putting an input on someone's screen mid combat. 
	recharge_time = 30 SECONDS
	antimagic_allowed = TRUE
	range = 1
	// Miserere mei, Deus, secundum magnam misericordiam tuam
	var/list/traits_to_skills = list (
		TRAIT_HOMESTEAD_EXPERT = list( 
			/datum/skill/labor/fishing,
			/datum/skill/labor/butchering,
			/datum/skill/labor/lumberjacking,
			/datum/skill/labor/farming,
			/datum/skill/craft/cooking,
			/datum/skill/craft/ceramics
		),
		TRAIT_SMITHING_EXPERT = list(
			/datum/skill/craft/blacksmithing,
			/datum/skill/craft/armorsmithing,
			/datum/skill/craft/weaponsmithing,
			/datum/skill/craft/ceramics,
			/datum/skill/craft/engineering,
			/datum/skill/labor/mining
		),
		TRAIT_SURVIVAL_EXPERT = list(
			/datum/skill/craft/cooking,
			/datum/skill/craft/tanning,
			/datum/skill/labor/butchering,
			/datum/skill/labor/fishing,
		),
		TRAIT_SEWING_EXPERT = list(
			/datum/skill/craft/sewing,
			/datum/skill/craft/tanning,
			/datum/skill/labor/butchering
		),
		TRAIT_ALCHEMY_EXPERT = list(
			/datum/skill/craft/alchemy
		),
		TRAIT_MEDICINE_EXPERT = list(
			/datum/skill/misc/medicine
		),
		TRAIT_SEEPRICES = list(
			/datum/skill/misc/reading, // I dunno what skills to give them as this is not a true
			/datum/skill/misc/lockpicking, // Yes I hate thieves but this should come with something
			/datum/skill/misc/stealing // Gating trait so I just give them some that make sense
		)
	)

/obj/effect/proc_holder/spell/invoked/takeapprentice/cast(list/targets, mob/user = usr)
	if(!isliving(user) || QDELETED(user))
		return FALSE
	var/mob/living/L = length(targets) ? targets[1] : null
	if(!istype(L) || QDELETED(L))
		revert_cast(user)
		return FALSE
	. = ..()
	var/list/choices = list()
	if(user.get_apprentice())
		to_chat(user, span_warning("You already have an apprentice and cannot take another."))
		revert_cast(user)
		return
	if(L.get_mentor())
		to_chat(user, span_warning("[L.name] already has a mentor and cannot take another."))
		revert_cast(user)
		return
	if(user == L)
		to_chat(user, span_warning("You cannot take yourself as an apprentice."))
		revert_cast(user)
		return
	for(var/i in traits_to_skills)
		if(HAS_TRAIT(user, i) && !HAS_TRAIT(L, i))
			choices += i
	if(!length(choices))
		to_chat(user, span_warning("Somehow, you do not have any traits that [L.name] can learn."))
		revert_cast(user)
		return FALSE
	var/chosen_trait = input(user, "Choose a trait for [L.name] to learn.", "IMPART YOUR KNOWLEDGE") as null|anything in choices
	if(QDELETED(src) || QDELETED(user))
		return FALSE
	if(!chosen_trait || QDELETED(L))
		revert_cast(user)
		return FALSE
	var/response = alert(L, "[user.name] is offering to take you as an apprentice, teaching you the basics of being a [chosen_trait]. Do you accept?", "Apprenticeship", "SERVE AND LEARN", "I REFUSE")
	if(QDELETED(src) || QDELETED(user))
		return FALSE
	if(response != "SERVE AND LEARN")
		// Daga Kotowaru
		to_chat(user, span_warning("The apprenticeship offer was declined."))
		revert_cast(user)
		return
	// Both dialogs yield; another apprenticeship or a move may have happened meanwhile.
	if(QDELETED(L) || !user.Adjacent(L) || user.get_apprentice() || L.get_mentor() || !HAS_TRAIT(user, chosen_trait) || HAS_TRAIT(L, chosen_trait))
		revert_cast(user)
		return FALSE
	// Give the trait and skills.
	ADD_TRAIT(L, chosen_trait, TRAIT_GENERIC)
	to_chat(L, span_greentext("[user] has taken you as an apprentice, teaching you the basics of being an [chosen_trait]."))
	for(var/skill in traits_to_skills[chosen_trait])
		// We can just skip the check because it only adjust up to 1 anyway
		L.adjust_skillrank_up_to(skill, SKILL_LEVEL_NOVICE)
	L.set_mentor(user)
	user.set_apprentice(L)
