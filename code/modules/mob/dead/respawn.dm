/// One authoritative body/life per account. Old corpses may retain an obsolete state safely.
GLOBAL_LIST_EMPTY(respawn_states)

/datum/respawn_state
	var/player_ckey
	var/datum/weakref/body_ref
	/// Null while the body is alive; zero is a valid death time.
	var/death_time
	var/waived = FALSE
	/// Invalidates confirmations when a body changes, revives, dies, or receives a waiver.
	var/revision = 0
	var/bypass_in_progress = FALSE

/datum/respawn_state/New(account_key, mob/living/body)
	player_ckey = ckey(account_key)
	if(body)
		start_life(body)
		if(body.stat == DEAD)
			start_death(body.timeofdeath)

/datum/respawn_state/proc/is_current()
	return player_ckey && GLOB.respawn_states[player_ckey] == src

/datum/respawn_state/proc/is_current_body(mob/living/body)
	// resolve() rejects a body already inside Destroy; it must still record its final deletion.
	return body && is_current() && body.respawn_state == src && body_ref?.reference == REF(body)

/datum/respawn_state/proc/start_life(mob/living/body)
	body_ref = WEAKREF(body)
	body.respawn_state = src
	death_time = null
	waived = FALSE
	revision++

/datum/respawn_state/proc/start_death(died_at)
	if(!isnull(death_time))
		return FALSE
	death_time = died_at
	waived = FALSE
	revision++
	return TRUE

/datum/respawn_state/proc/waive()
	if(!is_current())
		return FALSE
	if(!waived)
		waived = TRUE
		revision++
	return TRUE

/// -1 means there is no death to count from; it cannot be bought off as a timed cooldown.
/datum/respawn_state/proc/get_time_left()
	if(waived)
		return 0
	if(isnull(death_time))
		return -1
	return max(death_time + RESPAWNTIME - world.time, 0)

/proc/get_respawn_time_left_for_ckey(account_key)
	var/player_ckey = ckey(account_key)
	if(!player_ckey || GLOB.admin_datums[player_ckey] || GLOB.deadmins[player_ckey])
		return 0
	var/datum/respawn_state/state = GLOB.respawn_states[player_ckey]
	return state ? state.get_time_left() : 0

/proc/reset_respawn_cooldown_for_ckey(account_key)
	var/datum/respawn_state/state = GLOB.respawn_states[ckey(account_key)]
	return state?.waive() || FALSE

/mob/living
	var/datum/respawn_state/respawn_state

/// Called when a player actually controls this body, including a newly created undead role.
/mob/living/proc/register_respawn_body(account_key = key || mind?.key)
	if(QDELETED(src) || istype(src, /mob/living/carbon/spirit) || istype(src, /mob/living/brain) || respawn_body_override)
		return null
	var/player_ckey = ckey(account_key)
	if(!player_ckey)
		return null
	if(respawn_state?.player_ckey == player_ckey && respawn_state.is_current_body(src))
		return respawn_state
	respawn_state = new /datum/respawn_state(player_ckey, src)
	GLOB.respawn_states[player_ckey] = respawn_state
	return respawn_state

/// Offline/ghosted bodies retain their association even when their mind has left for the underworld.
/mob/living/proc/record_respawn_death()
	if(istype(src, /mob/living/carbon/spirit) || respawn_body_override)
		return FALSE
	if(!respawn_state && !QDELETED(src))
		var/player_ckey = ckey(key || mind?.key)
		// Never let a previously untracked old corpse overwrite an account's newer body.
		if(player_ckey && !GLOB.respawn_states[player_ckey])
			register_respawn_body(player_ckey)
	if(!respawn_state?.is_current_body(src))
		return FALSE
	return respawn_state.start_death(world.time)

/// Called only on the actual DEAD-to-alive transition, before updatehealth can kill the body again.
/mob/living/proc/record_respawn_revival()
	if(istype(src, /mob/living/carbon/spirit) || respawn_body_override)
		return FALSE
	if(!respawn_state?.is_current_body(src))
		return FALSE
	respawn_state.start_life(src)
	return TRUE

/// A shapeshift or mind transfer follows the playable body; the abandoned shell loses authority.
/mob/living/proc/transfer_respawn_body(mob/living/new_body)
	if(!istype(new_body) || QDELETED(new_body) || new_body == src)
		return FALSE
	if(istype(src, /mob/living/brain))
		return FALSE
	if(istype(src, /mob/living/carbon/spirit) || istype(new_body, /mob/living/carbon/spirit) || respawn_body_override || new_body.respawn_body_override)
		return FALSE
	if(!respawn_state?.is_current_body(src))
		return FALSE
	// A head or brain can receive funeral rites for this life without becoming a new body.
	if(istype(new_body, /mob/living/brain))
		new_body.respawn_state = respawn_state
		return FALSE
	respawn_state.start_life(new_body)
	if(new_body.stat == DEAD)
		respawn_state.start_death(new_body.timeofdeath)
	return TRUE

/mob/living/proc/clear_respawn_cooldown_for_burial()
	if(stat != DEAD || !respawn_state?.is_current())
		return FALSE
	if(istype(src, /mob/living/brain))
		return !isnull(respawn_state.death_time) && respawn_state.waive()
	if(!respawn_state.is_current_body(src))
		return FALSE
	return respawn_state.waive()
