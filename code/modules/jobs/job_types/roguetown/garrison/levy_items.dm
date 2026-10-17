// PR 7531 equipment; these subtypes leave the existing weapons unchanged.
/datum/intent/mace/demolish
	name = "demolish"
	desc = "A deliberate structure-breaking blow. Deals bonus damage equal to 15% of a structure's maximum integrity."
	icon_state = "incrush"
	blade_class = BCLASS_SMASH
	attack_verb = list("demolishes", "crushes", "wrecks")
	animname = "strike"
	hitsound = list('sound/combat/hits/blunt/metalblunt (1).ogg', 'sound/combat/hits/blunt/metalblunt (2).ogg', 'sound/combat/hits/blunt/metalblunt (3).ogg')
	item_d_type = "blunt"
	penfactor = 0
	clickcd = CLICK_CD_HEAVY
	swingdelay = 10

/obj/item/rogueweapon/mace/woodclub/militia
	name = "bogbark club"
	desc = "A stout bogbark cudgel. An unmistakable green aura of power surrounds it."
	gripped_intents = list(/datum/intent/mace/strike/wood, /datum/intent/mace/smash/wood, /datum/intent/effect/daze, /datum/intent/mace/demolish)
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/rogueweapon/mace/woodclub/militia/Initialize(mapload)
	. = ..()
	add_filter("bog_aura", 2, list("type" = "outline", "size" = 1, "color" = "#00ff00"))

/obj/item/rogueweapon/mace/woodclub/militia/proc/demolish_structure(atom/target, mob/living/user)
	if(QDELETED(target) || !istype(user?.used_intent, /datum/intent/mace/demolish))
		return FALSE
	var/maximum
	if(isobj(target))
		var/obj/O = target
		maximum = O.max_integrity
	else if(isturf(target))
		var/turf/T = target
		maximum = T.max_integrity
	if(!isnum(maximum) || maximum <= 0)
		return FALSE
	if(maximum > 3000)
		to_chat(user, span_warning("Too hard, sire!"))
		return FALSE
	var/bonus_damage = round(maximum * 0.15)
	if(isobj(target))
		var/obj/O = target
		O.take_damage(bonus_damage, BRUTE, d_type, TRUE)
	else
		var/turf/T = target
		T.take_damage(bonus_damage, BRUTE, d_type, TRUE)
	to_chat(user, span_warning("My blow caves into [target]! (+[bonus_damage])"))
	return TRUE

/obj/item/rogueweapon/mace/woodclub/militia/attack_obj(obj/O, mob/living/user)
	. = ..()
	if(.)
		demolish_structure(O, user)

/obj/item/rogueweapon/mace/woodclub/militia/attack_turf(turf/T, mob/living/user, multiplier)
	. = ..()
	if(.)
		demolish_structure(T, user)

/obj/item/rogueweapon/scythe/militia
	name = "militia scythe"
	desc = "A peasant's scythe reinforced for militia service. It harvests crops and sometimes souls."
	smeltresult = /obj/item/ingot/iron
	force = 18
	force_wielded = 28

/datum/intent/swing/sling/wood/prewarning()
	if(mastermob)
		mastermob.visible_message(span_warning("[mastermob] draws [masteritem]!"))
		playsound(mastermob, 'sound/combat/Ranged/bow-draw-01.ogg', 100, FALSE)

/datum/intent/arc/sling/wood/prewarning()
	if(mastermob)
		mastermob.visible_message(span_warning("[mastermob] draws [masteritem] in an arc!"))
		playsound(mastermob, 'sound/combat/Ranged/bow-draw-01.ogg', 100, FALSE)

/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood
	name = "slingshot"
	desc = "A forked branch fitted with braided cords and a leather cup. It launches stones by drawing the cords taut."
	icon = 'icons/roguetown/weapons/levy_slingshot.dmi'
	icon_state = "altsling"
	item_state = "altsling"
	possible_item_intents = list(/datum/intent/swing/sling/wood, /datum/intent/arc/sling/wood, INTENT_GENERIC)
	slot_flags = ITEM_SLOT_HIP | ITEM_SLOT_BELT | ITEM_SLOT_NECK | ITEM_SLOT_BACK

/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/update_icon()
	. = ..()
	cut_overlays()
	icon_state = chambered ? "[initial(icon_state)]_ready" : initial(icon_state)
	if(ismob(loc))
		var/mob/M = loc
		M.update_inv_hands()

/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/attack_self(mob/user)
	. = ..()
	update_icon()

/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog
	name = "bogbark slingshot"
	desc = "A dark, warped bogbark slingshot. Tales of the trolls it has felled grow longer with every retelling."

/obj/item/gun/ballistic/revolver/grenadelauncher/sling/wood/bog/Initialize(mapload)
	. = ..()
	add_filter("bog_aura", 2, list("type" = "outline", "size" = 1, "color" = "#00ff00"))

// Native under-helmet layer. Preserve the ordinary cap's stats and head-slot use.
/obj/item/clothing/head/roguetown/armingcap/levy
	slot_flags = ITEM_SLOT_HEAD | ITEM_SLOT_MASK | ITEM_SLOT_HIP
	mob_overlay_icon = 'icons/roguetown/clothing/onmob/head.dmi'
