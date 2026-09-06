/obj/shapeshift_holder
	name = "Shapeshift holder"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ON_FIRE | UNACIDABLE | ACID_PROOF
	var/mob/living/stored
	var/mob/living/shape
	var/restoring = FALSE
	var/initial_damage_percent = 0
	var/obj/item/bodypart/damage_bodypart
	var/datum/soullink/shapeshift/slink
	var/obj/effect/proc_holder/spell/targeted/shapeshift/source

/obj/shapeshift_holder/Initialize(mapload,obj/effect/proc_holder/spell/targeted/shapeshift/source,mob/living/caster)
	. = ..()
	src.source = source
	shape = loc
	if(!istype(shape))
		CRASH("shapeshift holder created outside mob/living")
	stored = caster
	if(stored.mind)
		stored.mind.transfer_to(shape)
	stored.forceMove(src)
	stored.notransform = TRUE
	if(source.convert_damage)
		initial_damage_percent = max(0, (stored.maxHealth - stored.health) / stored.maxHealth)
		if(source.preserve_injuries && iscarbon(stored))
			var/mob/living/carbon/carbon_caster = stored
			var/worst_injury = -1
			for(var/obj/item/bodypart/part as anything in carbon_caster.bodyparts)
				var/injury = (part.brute_dam + part.burn_dam) / part.max_damage
				if(injury > worst_injury)
					worst_injury = injury
					damage_bodypart = part
			initial_damage_percent = min(0.99, max(initial_damage_percent, worst_injury))
		var/damapply = initial_damage_percent * shape.maxHealth

		shape.apply_damage(damapply, source.convert_damage_type, forced = TRUE);

	slink = soullink(/datum/soullink/shapeshift, stored , shape)
	slink.source = src

/obj/shapeshift_holder/Destroy()
	if(!restoring)
		restore()
	stored = null
	shape = null
	. = ..()

/obj/shapeshift_holder/Moved()
	. = ..()
	if(!restoring || QDELETED(src))
		restore()

/obj/shapeshift_holder/handle_atom_del(atom/A)
	if(A == stored && !restoring)
		restore()

/obj/shapeshift_holder/Exited(atom/movable/AM)
	if(AM == stored && !restoring)
		restore()

/obj/shapeshift_holder/proc/casterDeath()
	//Something kills the stored caster through direct damage.
	//Specialized holders, such as ooze_death, do not have a spell source.
	if(!source)
		return
	if(source.revert_on_death)
		restore(death=TRUE)
	else
		shape.death()

/obj/shapeshift_holder/proc/shapeDeath()
	//Shape dies.
	if(!source)
		return
	if(source.die_with_shapeshifted_form)
		if(source.revert_on_death)
			restore(death=TRUE)
	else
		restore(knockout=source.knockout_on_death)

/obj/shapeshift_holder/proc/restore(death=FALSE, knockout=0)
	if(restoring)
		return
	restoring = TRUE
	qdel(slink)
	if (stored)
		stored.forceMove(get_turf(src))
		stored.notransform = FALSE

		// leave a track to indicate something has shifted out here
		var/obj/effect/track/the_evidence = new(stored.loc)
		the_evidence.handle_creation(stored)
		the_evidence.track_type = "expanding animal tracks into humanoid footprints"
		the_evidence.ambiguous_track_type = "curious footprints"
		the_evidence.base_diff = 6
		if (knockout)
			stored.Unconscious(knockout, TRUE, TRUE)
			stored.visible_message(span_boldwarning("[stored] twists and shifts back into humen guise in a sickening lurch of flesh and bone, and promptly passes out!"), span_userdanger("I quickly flee the waning vitality of my former shape, but the strain is too much--"))
			to_chat(stored, span_crit("...DARKNESS..."))

	if(shape && shape.mind)
		shape.mind?.transfer_to(stored)
	if(death)
		stored.death()
	else if(stored && source.convert_damage)
		var/damage_percent = (shape.maxHealth - shape.health) / shape.maxHealth
		if(source.preserve_injuries)
			// Carbon health ignores brute wounds. Return damage to the same limb
			// used on entry, so shifting again cannot provide a fresh health pool.
			if(damage_bodypart?.owner == stored && damage_percent > initial_damage_percent)
				var/new_damage = max(0, damage_percent * damage_bodypart.max_damage - damage_bodypart.brute_dam - damage_bodypart.burn_dam)
				stored.apply_damage(new_damage, source.convert_damage_type, damage_bodypart, forced = TRUE)
		else
			stored.revive(full_heal = TRUE, admin_revive = FALSE)
			var/damapply = stored.maxHealth * damage_percent

			stored.apply_damage(damapply, source.convert_damage_type, forced = TRUE)
	to_chat(stored, span_notice("Bug notice: If you can no longer see emotes, move to a different z level and back (up/down a level). This is a known bug."))
	qdel(shape)
	if (!QDELETED(src))
		qdel(src)

/datum/soullink/shapeshift
	var/obj/shapeshift_holder/source

/datum/soullink/shapeshift/ownerDies(gibbed, mob/living/owner)
	if(source)
		source.casterDeath(gibbed)

/datum/soullink/shapeshift/sharerDies(gibbed, mob/living/sharer)
	if(source)
		source.shapeDeath(gibbed)
