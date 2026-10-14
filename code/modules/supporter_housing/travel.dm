/mob/living
	var/housing_last_attack = -INFINITY
	var/housing_attack_serial = 0
	var/list/known_supporter_homes = list()

/datum/component/housing_activity/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/housing_activity/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_APPLY_DAMGE, PROC_REF(damaged))
	RegisterSignal(parent, list(COMSIG_MOB_ITEM_BEING_ATTACKED, COMSIG_MOB_ATTACKED_BY_HAND, COMSIG_LIVING_ATTACKED_BY), PROC_REF(attacked))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(died))

/datum/component/housing_activity/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOB_APPLY_DAMGE, COMSIG_MOB_ITEM_BEING_ATTACKED, COMSIG_MOB_ATTACKED_BY_HAND, COMSIG_LIVING_ATTACKED_BY, COMSIG_LIVING_DEATH))

/datum/component/housing_activity/proc/damaged(mob/living/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		source.housing_last_attack = world.time
		source.housing_attack_serial++

/datum/component/housing_activity/proc/attacked(mob/living/source)
	SIGNAL_HANDLER
	source.housing_last_attack = world.time
	source.housing_attack_serial++

/datum/component/housing_activity/proc/died(mob/living/source)
	SIGNAL_HANDLER
	source.known_supporter_homes.Cut()

/datum/housing_action_guard
	var/mob/living/user
	var/turf/target
	var/atom/origin
	var/attack_time

/datum/housing_action_guard/New(mob/living/new_user, turf/new_target)
	user = new_user
	target = new_target
	origin = user.loc
	user.AddComponent(/datum/component/housing_activity)
	attack_time = user.housing_attack_serial
	return ..()

/datum/housing_action_guard/proc/check()
	if(QDELETED(user) || !target || user.loc != origin || !user.Adjacent(target) || user.incapacitated() || user.pulledby || user.housing_attack_serial != attack_time)
		return FALSE
	for(var/obj/item/grabbing/grab as anything in user.grabbedby)
		if(!QDELETED(grab) && grab.grabbee && grab.grabbee != user)
			return FALSE
	return TRUE

/obj/structure/fluff/traveltile/housing
	name = "home passage"
	desc = "A passage to a private home. Anyone can follow while the entrance is open."
	aportalid = null
	aportalgoesto = null
	watchable = FALSE
	craftblock = FALSE
	resistance_flags = INDESTRUCTIBLE | FIRE_PROOF | LAVA_PROOF | UNACIDABLE | ACID_PROOF
	var/datum/supporter_home/home
	var/is_exterior = FALSE

/obj/structure/fluff/traveltile/housing/deconstruct(disassembled = TRUE)
	return

/obj/structure/fluff/traveltile/housing/return_connected_turfs()
	if(!home)
		return list()
	return list(is_exterior ? get_turf(home.exit) : home.return_destination())

/obj/structure/fluff/traveltile/housing/attack_hand(mob/user)
	if(isliving(user))
		try_living_travel(null, user)

/obj/structure/fluff/traveltile/housing/attack_ghost(mob/dead/observer/user)
	if(is_exterior && home?.test_session && !home.test_session.authorized(user))
		return
	if(home)
		user.forceMove(is_exterior ? get_turf(home.exit) : home.outside)

/obj/structure/fluff/traveltile/housing/Crossed(atom/movable/mover)
	// No parent call: ordinary travel uses global IDs and grants a shared trait.
	if(home && !home.transferring && isliving(mover))
		INVOKE_ASYNC(src, PROC_REF(try_living_travel), null, mover)

/obj/structure/fluff/traveltile/housing/proc/travel_party(mob/living/leader)
	if(leader.pulledby || leader.buckled)
		return null
	var/list/party = list(leader)
	for(var/index in 1 to 4)
		if(index > length(party))
			break
		var/mob/living/member = party[index]
		if(member.buckled || member.has_buckled_mobs())
			return null
		if(ishuman(member))
			var/mob/living/carbon/human/human = member
			if(human.sexcon?.knotted_status)
				return null
		if(member.pulling)
			if(!isliving(member.pulling))
				return null
			party |= member.pulling
		if(iscarbon(member))
			var/mob/living/carbon/carbon = member
			for(var/obj/item/grabbing/grab in list(carbon.r_grab, carbon.l_grab, carbon.mouth))
				if(!QDELETED(grab) && grab.grabbed)
					if(!isliving(grab.grabbed))
						return null
					party |= grab.grabbed
		if(length(party) > 4)
			return null
	for(var/mob/living/member as anything in party)
		if(QDELETED(member) || !leader.Adjacent(member) || (member.pulledby && !(member.pulledby in party)))
			return null
		for(var/obj/item/grabbing/grab as anything in member.grabbedby)
			if(!QDELETED(grab) && grab.grabbee && !(grab.grabbee in party))
				return null
	return party

/obj/structure/fluff/traveltile/housing/can_go(atom/movable/mover)
	if(!home || home.transferring || !isliving(mover))
		return FALSE
	var/mob/living/user = mover
	if(is_exterior && home.test_session && !home.test_session.authorized(user))
		return FALSE
	if(is_exterior && home.exterior?.density)
		return FALSE
	if(!user.Adjacent(src) || user.incapacitated() || world.time < user.recent_travel + 15 SECONDS)
		return FALSE
	return TRUE

/obj/structure/fluff/traveltile/housing/try_living_travel(obj/structure/fluff/traveltile/unused, mob/living/user)
	if(!can_go(user))
		return FALSE
	var/list/party = travel_party(user)
	if(!party)
		to_chat(user, span_warning("I cannot pass while held by someone outside the group, buckled, or pulling furniture."))
		return FALSE
	var/datum/housing_action_guard/guard = new(user, get_turf(src))
	to_chat(user, span_notice("I begin passing through the entrance..."))
	var/completed = do_after(user, 5 SECONDS, needhand = FALSE, target = src, extra_checks = CALLBACK(guard, TYPE_PROC_REF(/datum/housing_action_guard, check)))
	if(!completed || !guard.check() || !can_go(user))
		qdel(guard)
		return FALSE
	qdel(guard)
	var/list/current_party = travel_party(user)
	if(!current_party || length(party) != length(current_party) || length(party - current_party))
		return FALSE
	var/turf/destination = is_exterior ? get_turf(home.exit) : home.return_destination()
	if(!destination || destination.density)
		return FALSE
	for(var/obj/obstruction in destination)
		if(obstruction.density && (is_exterior || obstruction != home.exterior))
			to_chat(user, span_warning("The other end of the passage is obstructed."))
			return FALSE
	if(is_exterior)
		// view(), rather than hearers(), respects walls and opacity. Blind/KO witnesses learn nothing.
		for(var/mob/living/carbon/human/witness in viewers(6, src))
			if(!home.can_witness(witness, user))
				continue
			witness.AddComponent(/datum/component/housing_activity)
			witness.known_supporter_homes |= home
			to_chat(witness, span_notice("I watch [user] pass through this home's entrance and remember it."))
	// forceMove normally calls stop_pulling(), deleting grab objects. Preserve the existing links
	// across this synchronous group move; never recreate grabs or remove their control effects.
	var/list/pullers = list()
	home.transferring = TRUE
	for(var/mob/living/member as anything in party)
		pullers[member] = member.pulledby
		member.pulledby = null
	for(var/mob/living/member as anything in party)
		member.recent_travel = world.time
		member.known_supporter_homes |= home
		member.AddComponent(/datum/component/housing_activity)
		member.forceMove(destination)
	for(var/mob/living/member as anything in party)
		member.pulledby = pullers[member]
		member.update_mobility()
		if(is_exterior)
			home.welcome_owner(member)
	home.transferring = FALSE
	return TRUE

/datum/supporter_home/proc/can_witness(mob/living/carbon/human/witness, mob/living/traveller)
	return witness.stat == CONSCIOUS && !witness.IsUnconscious() && !HAS_TRAIT(witness, TRAIT_BLIND) && !HAS_TRAIT(witness, TRAIT_PARALYSIS) && (traveller in view(6, witness)) && witness.can_see_cone(traveller)
