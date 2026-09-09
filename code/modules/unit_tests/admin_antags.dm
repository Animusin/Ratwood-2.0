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
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), 7, "Zero Chaos must not hide an explicit admin cap.")
	TEST_ASSERT(!SSgamemode.can_inject_antags(), "An admin cap must not enable automatic Zero Chaos events.")
	TEST_ASSERT_EQUAL(SSgamemode.get_remaining_antag_capacity(), 0, "Automatic assignments must remain disabled.")
	TEST_ASSERT(SSjob.can_assign_antag_job(job), "Explicit extra slots must bypass Zero Chaos.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 100), 6, "Only admin slots may be shown in Zero Chaos.")
	TEST_ASSERT(SSjob.claim_admin_antag_slot(job, player), "An explicit Zero Chaos slot must be claimable.")
	TEST_ASSERT(SSjob.claim_admin_antag_slot(job, player), "Each explicit slot must be claimable once.")
	TEST_ASSERT(!SSjob.can_assign_antag_job(job), "Ordinary slots must stay closed when the admin pool runs out.")
	TEST_ASSERT_EQUAL(SSjob.get_latejoin_position_limit(job, 100), 0, "Zero Chaos must not expose ordinary slots.")
	SSgamemode.admin_antag_cap = null
	TEST_ASSERT_EQUAL(SSgamemode.get_antag_cap(), 0, "Resetting the cap must restore automatic Zero Chaos behavior.")
	SSgamemode.antagonists_disabled = FALSE
	job.admin_antag_slots = 1
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
	character.adjust_skillrank_up_to(/datum/skill/combat/polearms, 2, TRUE)
	var/datum/skill/crafting_skill = GetSkillRef(/datum/skill/craft/crafting)
	var/original_crafting_xp = original_skills.skill_experience[crafting_skill]
	player.spell_points = 20
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
	TEST_ASSERT_EQUAL(character.skills.skill_experience[crafting_skill], original_crafting_xp, "Accumulated XP must survive.")
	var/expected_polearms = (istype(granted, /datum/antagonist/lich) || istype(granted, /datum/antagonist/vampire/lord)) ? 4 : 2
	TEST_ASSERT_EQUAL(character.get_skill_level(/datum/skill/combat/polearms), expected_polearms, "The role must use its own skill floor instead of adding ranks.")
	granted.apply_admin_skill_profile()
	TEST_ASSERT_EQUAL(character.get_skill_level(/datum/skill/combat/polearms), expected_polearms, "Applying a skill profile twice must not stack ranks.")
	TEST_ASSERT_EQUAL(character.get_item_by_slot(SLOT_SHOES), boots, "Existing gear must survive.")
	TEST_ASSERT_EQUAL(get_turf(character), original_turf, "The character must not teleport to an antagonist spawn.")
	TEST_ASSERT_EQUAL(player.assigned_role, "Refugee", "The assigned job must survive.")
	TEST_ASSERT_EQUAL(character.job, "Refugee", "The body job must survive.")
	TEST_ASSERT_EQUAL(character.real_name, "Existing Character", "The character must not be renamed.")
	if(istype(granted, /datum/antagonist/lich))
		var/datum/antagonist/lich/lich = granted
		TEST_ASSERT_EQUAL(length(lich.phylacteries), 1, "An in-place lich still needs its phylactery.")
		TEST_ASSERT_EQUAL(player.spell_points, 27, "Lich spell points must use a floor, not 20 + 27.")
		TEST_ASSERT(player.get_spell(/obj/effect/proc_holder/spell/invoked/raise_undead), "An in-place lich still needs its role powers.")

	// Check teardown too: CI waits for garbage collection after the gain assertions.
	var/list/coven_actions = list()
	for(var/datum/action/coven/action in character.actions)
		coven_actions += action
	var/list/phylacteries = list()
	if(istype(granted, /datum/antagonist/lich))
		var/datum/antagonist/lich/lich = granted
		phylacteries = lich.phylacteries.Copy()
	player.remove_all_antag_datums()
	for(var/datum/action/coven/action in coven_actions)
		TEST_ASSERT(QDELETED(action), "Removing vampire status must delete its coven actions.")
		TEST_ASSERT_NULL(action.coven, "Deleted actions must release their covens.")
	for(var/obj/item/phylactery/phyl in phylacteries)
		TEST_ASSERT_NULL(phyl.possessor, "Removing lich status must release its phylacteries.")
	player.RemoveAllSpells()
	qdel(character)
	for(var/datum/atom_hud/hud in GLOB.all_huds)
		TEST_ASSERT(!(character in hud.next_time_allowed), "HUD cooldowns must release deleted characters even after role removal.")

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

/datum/unit_test/admin_antag_phylactery_cleanup/Run()
	var/datum/antagonist/lich/lich = new
	allocated += lich
	var/obj/item/phylactery/phyl = allocate(/obj/item/phylactery)
	lich.phylacteries += phyl
	phyl.possessor = lich
	qdel(phyl)
	TEST_ASSERT(!length(lich.phylacteries), "Destroyed phylacteries must leave their living owner's list.")
	TEST_ASSERT_NULL(phyl.possessor, "Destroyed phylacteries must release their owner.")
	phyl = allocate(/obj/item/phylactery)
	lich.phylacteries += phyl
	phyl.possessor = lich
	qdel(lich)
	TEST_ASSERT_NULL(phyl.possessor, "Deleting the role first must also break the link.")
	phyl.be_consumed(1)
	sleep(2)
	TEST_ASSERT(QDELETED(phyl), "Consumption without a living role must safely dispose of the phylactery.")

/datum/unit_test/admin_antag_lobby
	var/datum/mind/player
	var/old_disabled

/datum/unit_test/admin_antag_lobby/New()
	. = ..()
	old_disabled = SSgamemode.antagonists_disabled

/datum/unit_test/admin_antag_lobby/Destroy()
	SSgamemode.antagonists_disabled = old_disabled
	player?.clear_queued_admin_antag()
	player?.remove_all_antag_datums()
	player?.RemoveAllSpells()
	return ..()

/datum/unit_test/admin_antag_lobby/Run()
	SSgamemode.antagonists_disabled = TRUE
	var/mob/dead/new_player/lobby = allocate(/mob/dead/new_player)
	player = new /datum/mind("adminantagtest")
	allocated += player
	lobby.mind = player
	player.current = lobby
	var/datum/antagonist/lich/offer = new
	offer.preserve_character = TRUE
	TEST_ASSERT(player.queue_admin_antag(offer, "adminantagtest", "admin"), "A consented lobby offer must be reservable.")
	TEST_ASSERT_NULL(offer.owner, "Queueing must not run on_gain on a lobby mob.")
	TEST_ASSERT(!length(player.antag_datums), "The lobby must remain free of active antagonist effects.")
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.admin_antag_setup_pending = TRUE
	player.transfer_to(character)
	qdel(lobby)
	TEST_ASSERT_EQUAL(player.queued_admin_antag, offer, "Normal lobby deletion after transfer must retain the reservation.")
	TEST_ASSERT(!player.apply_queued_admin_antag(), "The offer must wait for job and class equipment.")
	character.adjust_skillrank_up_to(/datum/skill/combat/polearms, 3, TRUE)
	player.spell_points = 20
	character.finish_admin_antag_setup()
	TEST_ASSERT_NULL(player.queued_admin_antag, "Finishing setup must consume the reservation.")
	TEST_ASSERT_EQUAL(player.has_antag_datum(/datum/antagonist/lich), offer, "The consented role must apply even during Zero Chaos.")
	TEST_ASSERT_EQUAL(character.get_skill_level(/datum/skill/combat/polearms), 4, "Job rank 3 and lich rank 4 must produce rank 4, not Legendary.")
	TEST_ASSERT_EQUAL(player.spell_points, 27, "Job spell points must not add to the lich budget.")
	character.finish_admin_antag_setup()
	TEST_ASSERT_EQUAL(length(player.antag_datums), 1, "Repeated completion hooks must not reapply the role.")
	TEST_ASSERT_EQUAL(length(offer.phylacteries), 1, "Repeated completion hooks must not duplicate role equipment.")
	var/datum/antagonist/wretch/wrong_account = new
	wrong_account.preserve_character = TRUE
	player.queue_admin_antag(wrong_account, "someoneelse", "admin")
	TEST_ASSERT(!player.apply_queued_admin_antag(), "A reservation must not cross account identity.")
	TEST_ASSERT(QDELETED(wrong_account), "An invalid reservation must be cleaned up.")
	TEST_ASSERT(!player.has_antag_datum(/datum/antagonist/wretch), "Invalid consent must not grant a role.")
	var/mob/dead/new_player/abandoned_lobby = allocate(/mob/dead/new_player)
	var/datum/mind/abandoned_mind = new /datum/mind("abandoned")
	allocated += abandoned_mind
	abandoned_lobby.mind = abandoned_mind
	abandoned_mind.current = abandoned_lobby
	var/datum/antagonist/wretch/abandoned_offer = new
	abandoned_mind.queue_admin_antag(abandoned_offer, "abandoned", "admin")
	qdel(abandoned_lobby)
	TEST_ASSERT_NULL(abandoned_mind.queued_admin_antag, "Leaving the lobby without spawning must cancel the reservation.")
	TEST_ASSERT(QDELETED(abandoned_offer), "Abandoned lobby offers must not leak antagonist datums.")
	player.remove_all_antag_datums()
	TEST_ASSERT(!(player in SSmapping.retainer.liches), "Removing lich status must release the mind from the retainer.")
	var/datum/language_holder/languages = player.language_holder
	qdel(character)
	qdel(player)
	TEST_ASSERT(QDELETED(languages), "Deleting the consenting mind must delete its copied language holder.")
	TEST_ASSERT_NULL(languages.owner, "The deleted language holder must release its mind.")
	player = null
