/proc/format_blockade_time(deciseconds)
	if(deciseconds <= 0)
		return "0:00"
	var/total_seconds = round(deciseconds / 10)
	var/minutes = round(total_seconds / 60)
	var/seconds = total_seconds % 60
	return "[minutes]:[seconds < 10 ? "0[seconds]" : "[seconds]"]"

/obj/item/quest_writ/blockade
	name = "blockade defense writ"
	icon_state = "scroll_quest_info"
	base_icon_state = "scroll_quest"
	var/last_arrival_check = 0

/obj/item/quest_writ/blockade/Initialize(mapload)
	. = ..()
	desc = "A writ calling for a blockade to be cleared. \
	The bearer is enjoined to travel to the blockaded region and break three successive waves \
	of raiders - each wave must fall within [BLOCKADE_WAVE_TIMER_DS / (1 MINUTES)] minutes. \
	A trade-blockade writ expires if the fight has not begun within [BLOCKADE_ARM_TIMEOUT_DS / (1 MINUTES)] minutes of issue; \
	the Steward may recall it after [BLOCKADE_RECALL_WINDOW_DS / (1 MINUTES)] minutes, provided the fight has not begun. \
	Hand this writ directly to a bearer, or pin it to the Grand Contract Ledger to require a Fellowship of [BLOCKADE_FELLOWSHIP_REQUIREMENT]. \
	Every additional person at the blockade, until the sixth, attracts more enemies and rewards. \
	If brigands are sitting on stolen Crown coins, breaking the blockade seizes the hoard and has it taxed by the Crown as Recovered Spoils."

/obj/item/quest_writ/blockade/attack_self(mob/user)
	if(!assigned_quest)
		return ..()
	var/datum/quest/kill/blockade_defense/Q = assigned_quest
	if(!Q.quest_receiver_reference)
		if(!Q.can_claim(user))
			to_chat(user, span_warning(Q.claim_failure_reason(user)))
			return
		if(!SStreasury.has_account(user))
			to_chat(user, span_warning("No account on record - register with a Nervelock before taking a contract, lest there be no purse to pay you."))
			return
		Q.quest_receiver_reference = WEAKREF(user)
		Q.quest_receiver_name = user.real_name
		to_chat(user, span_notice("You take up the blockade writ. Travel to the marked region - the waves will begin when you arrive."))
		var/obj/effect/landmark/quest_spawner/landmark = Q.pending_landmark_ref?.resolve()
		if(landmark)
			Q.materialize(landmark)
			Q.materialized = TRUE
		update_quest_text()
	opened = TRUE
	update_icon_state()
	refresh_compass(user)
	ui_interact(user)

/obj/item/quest_writ/blockade/process()
	. = ..()
	var/datum/quest/kill/blockade_defense/Q = assigned_quest
	if(!Q)
		return
	if(!Q.armed)
		return
	if(world.time < last_arrival_check + (5 SECONDS))
		return
	last_arrival_check = world.time
	var/mob/bearer = Q.quest_receiver_reference?.resolve()
	if(!bearer)
		return
	var/atom/loc_chain = src.loc
	var/found_bearer = FALSE
	while(loc_chain)
		if(loc_chain == bearer)
			found_bearer = TRUE
			break
		if(isturf(loc_chain))
			break
		loc_chain = loc_chain.loc
	if(!found_bearer)
		return
	Q.check_arrival(bearer)
