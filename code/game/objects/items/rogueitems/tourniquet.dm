// Tourniquet: cinch a limb to stop ALL bleeding, arterial included, at the slow cost of the limb itself.
// Numbness after TOURNIQUET_NUMB_TIME, irreversible necrosis after TOURNIQUET_NECROSIS_TIME.

#define TOURNIQUET_NUMB_TIME (2 MINUTES)
#define TOURNIQUET_NECROSIS_TIME (15 MINUTES)
#define TOURNIQUET_TRAIT_SOURCE "tourniquet"

/obj/item/natural/cloth/tourniquet
	name = "tourniquet"
	icon = 'icons/roguetown/items/surgery.dmi'
	icon_state = "bandageroll"
	desc = "A strip of tough cloth and cord, meant to be cinched tight around a limb until the bleeding stops. It will choke off even a severed artery - but blood carries life, and a limb left bound for too long will first grow cold and numb, then dead."
	force = 0
	throwforce = 0
	bandage_effectiveness = 0
	bandage_health = 600
	bandage_speed = 5 SECONDS
	bandage_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	/// The limb this tourniquet is currently tied around.
	var/obj/item/bodypart/attached_limb
	/// The mob whose limb we are currently choking off.
	var/mob/living/carbon/human/wearer
	/// world.time at which this tourniquet was tied on.
	var/tied_time = 0
	/// The per-limb paralysis trait we applied, so it can be removed cleanly.
	var/numb_trait
	/// Whether we have already numbed the limb.
	var/numbed = FALSE
	/// Whether we have already killed the limb.
	var/necrotised = FALSE

/obj/item/natural/cloth/tourniquet/attack_right(mob/user)
	return

/obj/item/natural/cloth/tourniquet/examine(mob/user)
	. = ..()
	if(attached_limb)
		. += span_notice("It is tied tightly around a [attached_limb.name].")

/obj/item/natural/cloth/tourniquet/can_bandage_limb(obj/item/bodypart/limb)
	if(!limb?.is_organic_limb())
		return FALSE
	return TRUE

/obj/item/natural/cloth/tourniquet/on_bandaged(mob/living/carbon/host, obj/item/bodypart/limb)
	if(!ishuman(host) || !limb)
		return
	attached_limb = limb
	wearer = host
	tied_time = world.time
	numbed = FALSE
	necrotised = FALSE
	START_PROCESSING(SSobj, src)

/obj/item/natural/cloth/tourniquet/on_unbandaged(mob/living/carbon/host, obj/item/bodypart/limb)
	release()

/obj/item/natural/cloth/tourniquet/Destroy()
	release()
	return ..()

/// Cleans up tracking and reversible effects. Necrosis (rotted) is permanent and is deliberately left alone.
/obj/item/natural/cloth/tourniquet/proc/release()
	STOP_PROCESSING(SSobj, src)
	if(numb_trait && !QDELETED(wearer))
		REMOVE_TRAIT(wearer, numb_trait, TOURNIQUET_TRAIT_SOURCE)
	numb_trait = null
	if(!QDELETED(attached_limb))
		attached_limb.update_disabled()
	attached_limb = null
	wearer = null
	numbed = FALSE
	necrotised = FALSE

/obj/item/natural/cloth/tourniquet/process()
	// If the limb is gone, the mob is gone, or the limb left its owner, there is nothing left to choke.
	if(!attached_limb || !wearer || QDELETED(attached_limb) || QDELETED(wearer) || attached_limb.owner != wearer)
		release()
		return
	var/elapsed = world.time - tied_time
	if(!numbed && elapsed >= TOURNIQUET_NUMB_TIME)
		numb_limb()
	if(!necrotised && elapsed >= TOURNIQUET_NECROSIS_TIME)
		necrose_limb()

/// The limb has been starved of blood long enough to go numb.
/obj/item/natural/cloth/tourniquet/proc/numb_limb()
	numbed = TRUE
	if(!attached_limb || !wearer)
		return
	numb_trait = get_paralysis_trait(attached_limb.body_zone)
	if(numb_trait)
		ADD_TRAIT(wearer, numb_trait, TOURNIQUET_TRAIT_SOURCE)
	attached_limb.update_disabled()
	to_chat(wearer, span_warning("My [attached_limb.name] has gone cold and numb beneath the tourniquet."))

/// The limb has died. Unlike numbness, this does NOT recover when the tourniquet is removed.
/obj/item/natural/cloth/tourniquet/proc/necrose_limb()
	necrotised = TRUE
	if(!attached_limb || !wearer)
		return
	if(!attached_limb.rotted)
		attached_limb.rotted = TRUE
		attached_limb.update_disabled()
		wearer.update_body()
		to_chat(wearer, span_userdanger("The flesh of my [attached_limb.name] has gone black and lifeless - it is necrotic!"))

/// Maps a body zone to the per-limb paralysis trait used to numb it.
/obj/item/natural/cloth/tourniquet/proc/get_paralysis_trait(zone)
	switch(zone)
		if(BODY_ZONE_L_ARM)
			return TRAIT_PARALYSIS_L_ARM
		if(BODY_ZONE_R_ARM)
			return TRAIT_PARALYSIS_R_ARM
		if(BODY_ZONE_L_LEG)
			return TRAIT_PARALYSIS_L_LEG
		if(BODY_ZONE_R_LEG)
			return TRAIT_PARALYSIS_R_LEG
	return null
