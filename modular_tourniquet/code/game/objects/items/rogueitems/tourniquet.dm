// Tourniquet: cinches a limb to stop arterial bleeding, at the cost of the limb itself.
// Numb after TOURNIQUET_NUMB_TIME, permanently necrotic after TOURNIQUET_NECROSIS_TIME.

#define TOURNIQUET_NUMB_TIME (2 MINUTES)
#define TOURNIQUET_NECROSIS_TIME (15 MINUTES)
#define TRAIT_TOURNIQUET "tourniquet"

/obj/item/natural/cloth/tourniquet
	name = "tourniquet"
	icon = 'icons/roguetown/items/tourniquet.dmi'
	icon_state = "tourniquet"
	desc = "A strip of tough cloth and cord, meant to be cinched tight around a limb until the bleeding stops. It will choke off even a severed artery, or a wound deep enough to be lethal - but blood carries life, and a limb left bound for too long will first grow cold and numb, then dead."
	force = 0
	throwforce = 0
	bundletype = null // never merges itself into a cloth bundle
	bundleable = FALSE // and never gets swept up when other cloth is bundled
	bandage_effectiveness = 0
	bandage_speed = 5 SECONDS
	bandage_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	/// The limb this is tied around, and the mob whose blood it is choking off.
	var/obj/item/bodypart/attached_limb
	var/mob/living/carbon/human/wearer
	/// world.time at which this was tied on.
	var/tied_time
	var/numbed = FALSE
	var/necrotised = FALSE

/obj/item/natural/cloth/tourniquet/attack_right(mob/user)
	return // don't let it get bundled up with regular cloth

/obj/item/natural/cloth/tourniquet/can_bandage_limb(obj/item/bodypart/limb)
	return limb?.is_organic_limb()

/obj/item/natural/cloth/tourniquet/on_bandaged(mob/living/carbon/host, obj/item/bodypart/limb)
	if(!ishuman(host) || !limb)
		return
	attached_limb = limb
	wearer = host
	tied_time = world.time
	START_PROCESSING(SSobj, src)

/obj/item/natural/cloth/tourniquet/on_unbandaged(mob/living/carbon/host, obj/item/bodypart/limb)
	release()

/obj/item/natural/cloth/tourniquet/Destroy()
	release()
	return ..()

/// Drops tracking and undoes the numbness. Necrosis is permanent, so rotted is left alone.
/obj/item/natural/cloth/tourniquet/proc/release()
	STOP_PROCESSING(SSobj, src)
	if(!QDELETED(attached_limb))
		REMOVE_TRAIT(attached_limb, TRAIT_PARALYSIS, TRAIT_TOURNIQUET)
		attached_limb.update_disabled()
	attached_limb = null
	wearer = null
	numbed = FALSE
	necrotised = FALSE

/obj/item/natural/cloth/tourniquet/process()
	// Nothing left to choke once the limb or its owner is gone.
	if(!attached_limb || attached_limb.owner != wearer)
		return release()
	var/elapsed = world.time - tied_time
	if(!numbed && elapsed >= TOURNIQUET_NUMB_TIME)
		numbed = TRUE
		ADD_TRAIT(attached_limb, TRAIT_PARALYSIS, TRAIT_TOURNIQUET)
		attached_limb.update_disabled()
		to_chat(wearer, span_warning("My [attached_limb.name] has gone cold and numb beneath the tourniquet."))
	if(!necrotised && elapsed >= TOURNIQUET_NECROSIS_TIME)
		necrotised = TRUE
		attached_limb.rotted = TRUE
		attached_limb.update_disabled()
		wearer.update_body()
		to_chat(wearer, span_userdanger("The flesh of my [attached_limb.name] has gone black and lifeless - it is necrotic!"))
