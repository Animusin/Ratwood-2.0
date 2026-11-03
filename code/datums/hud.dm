/* HUD DATUMS */

GLOBAL_LIST_EMPTY(all_huds)

//GLOBAL HUD LIST
GLOBAL_LIST_INIT(huds, alist(
	ROGUE_HUD_MARRIED = new/datum/atom_hud/antag(),
	ANTAG_HUD_TRAITOR = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_REV = new/datum/atom_hud/antag(),
	ANTAG_HUD_VAMPIRE = new/datum/atom_hud/antag()
	))

/datum/atom_hud
	var/list/atom/hudatoms = list() //list of all atoms which display this hud
	var/list/hudusers = list() //list with all mobs who can see the hud
	var/list/hud_icons = list() //these will be the indexes for the atom's hud_list

	var/list/next_time_allowed = list() //mobs associated with the next time this hud can be added to them
	var/list/queued_to_see = list() //mobs that have triggered the cooldown and are queued to see the hud, but do not yet
	var/hud_exceptions = list() // huduser = list(ofatomswiththeirhudhidden) - aka everyone hates targeted invisiblity

/datum/atom_hud/New()
	GLOB.all_huds += src

/datum/atom_hud/Destroy()
	for(var/mob/M in next_time_allowed)
		UnregisterSignal(M, COMSIG_QDELETING)
	next_time_allowed.Cut()
	for(var/v in hudusers)
		remove_hud_from(v)
	for(var/v in hudatoms)
		remove_from_hud(v)
	GLOB.all_huds -= src
	return ..()

/datum/atom_hud/proc/remove_hud_from(mob/M)
	if(!M || !hudusers[M])
		return
	if (!--hudusers[M])
		hudusers -= M
		if(queued_to_see[M])
			queued_to_see -= M
		else
			for(var/atom/A in hudatoms)
				remove_from_single_hud(M, A)

/datum/atom_hud/proc/remove_from_hud(atom/A)
	if(!A)
		return FALSE
	for(var/mob/M in hudusers)
		remove_from_single_hud(M, A)
	hudatoms -= A
	for(var/mob/viewer in hud_exceptions)
		hud_exceptions[viewer] -= A
	// A former viewer's cooldown still needs its deletion subscription.
	if(!(A in next_time_allowed))
		UnregisterSignal(A, COMSIG_QDELETING)
	return TRUE

/datum/atom_hud/proc/remove_from_single_hud(mob/M, atom/A) //unsafe, no sanity apart from client
	if(!M || !M.client || !A)
		return
	for(var/i in hud_icons)
		M.client.images -= A.hud_list[i]

/datum/atom_hud/proc/add_hud_to(mob/M)
	if(QDELETED(M))
		return
	if(!(M in next_time_allowed))
		if(!(M in hudatoms))
			RegisterSignal(M, COMSIG_QDELETING, PROC_REF(on_hud_atom_deleted))
		next_time_allowed[M] = 0
	if(!hudusers[M])
		hudusers[M] = 1
		if(next_time_allowed[M] > world.time)
			if(!queued_to_see[M])
				addtimer(CALLBACK(src, PROC_REF(show_hud_images_after_cooldown), M), next_time_allowed[M] - world.time)
				queued_to_see[M] = TRUE
		else
			next_time_allowed[M] = world.time + ADD_HUD_TO_COOLDOWN
			for(var/atom/A in hudatoms)
				add_to_single_hud(M, A)
	else
		hudusers[M]++

/// Targets and viewers can have independent membership; neither may retain a deleted atom.
/datum/atom_hud/proc/on_hud_atom_deleted(atom/A)
	SIGNAL_HANDLER
	if(hudusers[A])
		var/mob/M = A
		hudusers[M] = 1
		remove_hud_from(M)
	next_time_allowed -= A
	queued_to_see -= A
	hud_exceptions -= A
	UnregisterSignal(A, COMSIG_QDELETING)
	// A viewer is not necessarily a HUD target. Removing a non-target from a
	// basic alternate appearance deletes that appearance for every other viewer.
	if(A in hudatoms)
		remove_from_hud(A)

/datum/atom_hud/proc/hide_single_atomhud_from(hud_user,hidden_atom)
	if(hudusers[hud_user])
		remove_from_single_hud(hud_user,hidden_atom)
	if(!hud_exceptions[hud_user])
		hud_exceptions[hud_user] = list(hidden_atom)
	else
		hud_exceptions[hud_user] += hidden_atom

/datum/atom_hud/proc/unhide_single_atomhud_from(hud_user,hidden_atom)
	hud_exceptions[hud_user] -= hidden_atom
	if(hudusers[hud_user])
		add_to_single_hud(hud_user,hidden_atom)

/datum/atom_hud/proc/show_hud_images_after_cooldown(M)
	if(queued_to_see[M])
		queued_to_see -= M
		next_time_allowed[M] = world.time + ADD_HUD_TO_COOLDOWN
		for(var/atom/A in hudatoms)
			add_to_single_hud(M, A)

/datum/atom_hud/proc/add_to_hud(atom/A)
	if(QDELETED(A))
		return FALSE
	if(!(A in hudatoms) && !(A in next_time_allowed))
		RegisterSignal(A, COMSIG_QDELETING, PROC_REF(on_hud_atom_deleted))
	hudatoms |= A
	for(var/mob/M in hudusers)
		if(!queued_to_see[M])
			add_to_single_hud(M, A)
	return TRUE

/datum/atom_hud/proc/add_to_single_hud(mob/M, atom/A) //unsafe, no sanity apart from client
	if(!M || !M.client || !A)
		return
	for(var/i in hud_icons)
		if(A.hud_list[i] && (!hud_exceptions[M] || !(A in hud_exceptions[M])))
			M.client.images |= A.hud_list[i]

//MOB PROCS
/mob/proc/reload_huds()
	for(var/datum/atom_hud/hud in GLOB.all_huds)
		if(hud && hud.hudusers[src])
			for(var/atom/A in hud.hudatoms)
				hud.add_to_single_hud(src, A)

/mob/dead/new_player/reload_huds()
	return

/mob/proc/add_click_catcher()
	client.screen += client.void

/mob/dead/new_player/add_click_catcher()
	return
