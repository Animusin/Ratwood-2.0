/datum/unit_test/admin_antag_slots
	var/old_cap
	var/old_disabled
	var/old_state
	var/old_reserved
	var/datum/mind/player

/datum/unit_test/admin_antag_slots/New()
	. = ..()
	old_cap = SSgamemode.admin_antag_cap
	old_disabled = SSgamemode.antagonists_disabled
	old_state = SSticker.current_state
	old_reserved = SSgamemode.roundstart_reserved_antag_weight

/datum/unit_test/admin_antag_slots/Destroy()
	SSgamemode.admin_antag_cap = old_cap
	SSgamemode.antagonists_disabled = old_disabled
	SSgamemode.roundstart_reserved_antag_weight = old_reserved
	SSticker.current_state = old_state
	player?.remove_all_antag_datums()
	return ..()

/datum/unit_test/admin_antag_slots/Run()
	SSgamemode.antagonists_disabled = FALSE
	SSgamemode.admin_antag_cap = 0
	SSgamemode.roundstart_reserved_antag_weight = 0
	SSticker.current_state = GAME_STATE_PLAYING
	var/datum/job/job = new
	allocated += job
	job.antag_job = TRUE
	job.admin_slot_antag_type = /datum/antagonist/wretch
	job.total_positions = 4
	job.current_positions = 2
	job.admin_antag_slots = 2
	TEST_ASSERT(SSjob.can_assign_antag_job(job), "Extra slots must work at a zero cap.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 0), 4, "Both extra slots must be visible.")
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.mind_initialize()
	player = character.mind
	TEST_ASSERT(SSjob.claim_admin_antag_slot(job, player), "The first join must reserve an exemption.")
	job.current_positions++
	var/datum/antagonist/major = player.add_antag_datum(/datum/antagonist/werewolf)
	TEST_ASSERT(!(major.antag_flags & FLAG_ANTAG_CAP_IGNORE), "A pending minor slot must not exempt a different antagonist.")
	TEST_ASSERT_EQUAL(player.admin_slot_antag_type, /datum/antagonist/wretch, "A different role must not consume the pending exemption.")
	player.remove_antag_datum(/datum/antagonist/werewolf)
	var/datum/antagonist/wretch/granted = player.add_antag_datum(/datum/antagonist/wretch)
	TEST_ASSERT(granted.antag_flags & FLAG_ANTAG_CAP_IGNORE, "The granted minor datum must be exempt.")
	TEST_ASSERT_NULL(player.admin_slot_antag_type, "The pending exemption must be consumed.")
	TEST_ASSERT_EQUAL(job.admin_antag_slots, 1, "Exactly one slot must be spent.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 0), 4, "One extra slot remains after a join.")
	TEST_ASSERT(SSjob.claim_admin_antag_slot(job, player), "The second slot must be claimable.")
	job.current_positions++
	TEST_ASSERT(!SSjob.claim_admin_antag_slot(job, player), "The same pool cannot supply a third exemption.")
	TEST_ASSERT(!SSjob.can_assign_antag_job(job), "Exhausted extra slots must restore normal cap enforcement.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 0), 4, "An exhausted pool must show no vacancies.")
	player.admin_slot_antag_type = null
	player.remove_antag_datum(/datum/antagonist/wretch)
	granted = player.add_antag_datum(/datum/antagonist/wretch)
	TEST_ASSERT(!(granted.antag_flags & FLAG_ANTAG_CAP_IGNORE), "Ordinary antagonists must still count.")
	job.total_positions = -1
	job.admin_antag_slots = 2
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 0), 6, "Unlimited jobs still expose only their finite extra slots at the cap.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 3), 9, "Normal capacity and extra slots must coexist.")
	SSgamemode.admin_antag_cap = null
	var/automatic_cap = SSgamemode.get_antag_cap()
	SSgamemode.admin_antag_cap = 7
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), 7, "The manual cap must override the population formula.")
	SSgamemode.admin_antag_cap = 1
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), 1, "Admins must also be able to lower the cap.")
	TEST_ASSERT(player.has_antag_datum(/datum/antagonist/wretch), "Lowering the cap must not remove existing antagonists.")
	SSgamemode.admin_antag_cap = null
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), automatic_cap, "Clearing the override must restore the population formula.")
	SSgamemode.admin_antag_cap = 7
	SSgamemode.antagonists_disabled = TRUE
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), 0, "Zero Chaos must still disable antagonists.")
	TEST_ASSERT(!SSjob.can_assign_antag_job(job), "Extra slots must not bypass Zero Chaos.")
	TEST_ASSERT(!SSjob.claim_admin_antag_slot(job, player), "Zero Chaos must not consume an extra slot.")
	SSgamemode.antagonists_disabled = FALSE
	SSticker.current_state = GAME_STATE_PREGAME
	TEST_ASSERT(!SSjob.claim_admin_antag_slot(job, player), "Roundstart must not consume midround slots.")

/// Exercise real gain paths with pre-existing character state, including XP and equipped items.
/datum/unit_test/admin_antag_preserve
	var/antag_type = /datum/antagonist/wretch
	var/datum/mind/player

/datum/unit_test/admin_antag_preserve/Destroy()
	player?.remove_all_antag_datums()
	player?.RemoveAllSpells()
	player = null
	return ..()

/datum/unit_test/admin_antag_preserve/Run()
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.mind_initialize()
	player = character.mind
	player.assigned_role = "Refugee"
	character.job = "Refugee"
	character.real_name = "Existing Character"
	var/turf/original_turf = get_turf(character)
	var/datum/skill_holder/original_skills = character.ensure_skills()
	character.adjust_skillrank_up_to(/datum/skill/craft/crafting, 4, TRUE)
	character.adjust_skillrank_up_to(/datum/skill/combat/swords, 5, TRUE)
	original_skills.skill_experience[/datum/skill/craft/crafting] = 123
	var/obj/item/clothing/shoes/roguetown/boots/boots = allocate(/obj/item/clothing/shoes/roguetown/boots)
	character.equip_to_slot(boots, SLOT_SHOES)
	TEST_ASSERT_EQUAL(character.get_item_by_slot(SLOT_SHOES), boots, "The fixture must start with equipped boots.")
	var/datum/antagonist/antag = new antag_type
	antag.preserve_character = TRUE
	antag.requires_confirmation = FALSE
	if(istype(antag, /datum/antagonist/vampire))
		var/datum/antagonist/vampire/vampire = antag
		vampire.clan_selected = TRUE
		vampire.default_clan = /datum/clan/nosferatu
	var/datum/antagonist/granted = player.add_antag_datum(antag)
	TEST_ASSERT_NOTNULL(granted, "The real gain path must grant the role.")
	TEST_ASSERT_EQUAL(player.current, character, "Granting a role must keep the body and mind together.")
	TEST_ASSERT_EQUAL(character.skills, original_skills, "Granting a role must retain the skill holder.")
	TEST_ASSERT_EQUAL(character.get_skill_level(/datum/skill/craft/crafting), 4, "Crafting skills must be retained.")
	TEST_ASSERT_EQUAL(character.get_skill_level(/datum/skill/combat/swords), 5, "Combat skills must be retained.")
	TEST_ASSERT_EQUAL(character.skills.skill_experience[/datum/skill/craft/crafting], 123, "Accumulated XP must survive.")
	TEST_ASSERT_EQUAL(character.get_item_by_slot(SLOT_SHOES), boots, "Existing gear must survive.")
	TEST_ASSERT_EQUAL(get_turf(character), original_turf, "The character must not teleport to an antagonist spawn.")
	TEST_ASSERT_EQUAL(player.assigned_role, "Refugee", "The assigned job must survive.")
	TEST_ASSERT_EQUAL(character.job, "Refugee", "The body job must survive.")
	TEST_ASSERT_EQUAL(character.real_name, "Existing Character", "The character must not be renamed.")
	if(istype(granted, /datum/antagonist/lich))
		var/datum/antagonist/lich/lich = granted
		TEST_ASSERT_EQUAL(length(lich.phylacteries), 1, "An in-place lich still needs its phylactery.")
		TEST_ASSERT(player.get_spell(/obj/effect/proc_holder/spell/invoked/raise_undead), "An in-place lich still needs its role powers.")

/datum/unit_test/admin_antag_preserve/bandit
	antag_type = /datum/antagonist/bandit

/datum/unit_test/admin_antag_preserve/werewolf
	antag_type = /datum/antagonist/werewolf

/datum/unit_test/admin_antag_preserve/lich
	antag_type = /datum/antagonist/lich

/datum/unit_test/admin_antag_preserve/vampire
	antag_type = /datum/antagonist/vampire/licker

/datum/unit_test/admin_antag_preserve/vampire_lord
	antag_type = /datum/antagonist/vampire/lord

/datum/unit_test/admin_antag_offer_timeout/Run()
	var/datum/tgui_list_input/prompt = new(null, "Offer", "Antagonist Offer", list("Decline", "Accept"), "Decline", 1 SECONDS)
	prompt.wait()
	TEST_ASSERT(QDELETED(prompt), "An unanswered role offer must expire.")
	TEST_ASSERT_NULL(prompt.choice, "An expired offer must never imply acceptance.")
