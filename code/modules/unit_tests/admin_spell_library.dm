/datum/admin_spell_library/unit_test
	var/mob/test_user

/datum/admin_spell_library/unit_test/can_access(mob/user)
	return user && user == test_user

/datum/unit_test/admin_spell_library/Run()
	var/list/catalog = admin_spell_catalog()
	TEST_ASSERT_EQUAL(length(catalog), length(GLOB.spells), "Every spell from the original Give Spell list must remain available.")
	var/list/seen = list()
	for(var/list/entry as anything in catalog)
		var/spell_type = text2path(entry["path"])
		TEST_ASSERT(spell_type in GLOB.spells, "Catalog contains an invalid spell.")
		TEST_ASSERT(!seen[spell_type], "Catalog must not contain duplicate paths.")
		seen[spell_type] = TRUE
		TEST_ASSERT(entry["category"] in admin_spell_categories(), "Every entry needs a valid purpose category.")
		var/list/sprite = admin_spell_icon(spell_type)
		TEST_ASSERT(sprite["state"] in icon_states(sprite["file"]), "Every entry must display an existing icon: [spell_type].")
	for(var/spell_type in admin_spell_category_rules())
		TEST_ASSERT(spell_type in GLOB.spells, "Purpose rules must reference available spell types: [spell_type].")
	TEST_ASSERT_EQUAL(admin_spell_category(/obj/effect/proc_holder/spell/invoked/projectile/fireball/greater), "attack", "Attack variants inherit the family's purpose.")
	TEST_ASSERT_EQUAL(admin_spell_category(/obj/effect/proc_holder/spell/invoked/projectile/fetch/miracle), "movement", "Fetch must override the projectile attack category.")
	TEST_ASSERT_EQUAL(admin_spell_category(/obj/effect/proc_holder/spell/invoked/forcewall/arcyne_prison), "control", "A prison is control rather than ordinary protection.")
	TEST_ASSERT_EQUAL(admin_spell_category(/obj/effect/proc_holder/spell/invoked/resurrect/abyssor), "healing", "Patron resurrection variants are healing.")

	var/mob/living/carbon/human/dummy/viewer = allocate(/mob/living/carbon/human/dummy)
	var/mob/living/carbon/human/dummy/target = allocate(/mob/living/carbon/human/dummy)
	var/datum/admin_spell_library/denied = new(null, target)
	allocated += denied
	TEST_ASSERT(!denied.can_access(viewer), "A clientless player must not access the real admin window.")
	TEST_ASSERT_EQUAL(length(denied.ui_static_data(viewer)), 0, "Unauthorized viewers receive no catalog.")
	TEST_ASSERT(!denied.grant_spell(viewer, "/obj/effect/proc_holder/spell/invoked/projectile/fireball"), "Unauthorized actions must be rejected server-side.")

	var/datum/admin_spell_library/unit_test/library = new(null, target)
	allocated += library
	library.test_user = viewer
	TEST_ASSERT(!library.grant_spell(viewer, "/mob/living"), "An arbitrary path must never be instantiated.")
	TEST_ASSERT(!library.grant_spell(viewer, list("bad")), "Non-text paths must be rejected.")
	TEST_ASSERT(!library.grant_spell(target, "/obj/effect/proc_holder/spell/invoked/projectile/fireball"), "A different user cannot act on another admin's window.")
	var/old_count = length(target.mob_spell_list)
	library.grant_spell(viewer, "/obj/effect/proc_holder/spell/invoked/projectile/fireball")
	TEST_ASSERT_EQUAL(length(target.mob_spell_list), old_count + 1, "Mindless targets receive a real spell.")
	library.grant_spell(viewer, "/obj/effect/proc_holder/spell/invoked/projectile/fireball")
	TEST_ASSERT_EQUAL(length(target.mob_spell_list), old_count + 1, "Repeated clicks must not duplicate spells.")

	var/datum/mind/mind = new()
	allocated += mind
	target.mind = mind
	mind.current = target
	TEST_ASSERT_NULL(library.get_target(), "Gaining a mind invalidates the earlier recipient snapshot.")
	var/datum/admin_spell_library/unit_test/minded = new(null, target)
	allocated += minded
	minded.test_user = viewer
	var/used_points = mind.used_spell_points
	minded.grant_spell(viewer, "/obj/effect/proc_holder/spell/invoked/blink")
	TEST_ASSERT(mind.has_spell(/obj/effect/proc_holder/spell/invoked/blink, TRUE), "Minded targets receive spells through the mind.")
	TEST_ASSERT_EQUAL(mind.used_spell_points, used_points, "Admin grants do not spend the recipient's learning points.")
	TEST_ASSERT(minded.known_spells(target)["/obj/effect/proc_holder/spell/invoked/projectile/fireball"], "Body-owned spells remain marked known after gaining a mind.")
	mind.current = viewer
	TEST_ASSERT_NULL(minded.get_target(), "A changed mind owner must invalidate the recipient.")
	mind.current = target
	qdel(target)
	TEST_ASSERT_NULL(minded.get_target(), "A deleted recipient must not remain usable.")

/datum/unit_test/admin_spell_library_revoke/Run()
	var/mob/living/carbon/human/dummy/viewer = allocate(/mob/living/carbon/human/dummy)
	var/mob/living/carbon/human/dummy/target = allocate(/mob/living/carbon/human/dummy)
	var/datum/admin_spell_library/unit_test/library = new(null, target)
	allocated += library
	library.test_user = viewer
	var/fireball_path = "/obj/effect/proc_holder/spell/invoked/projectile/fireball"
	var/greater_path = "/obj/effect/proc_holder/spell/invoked/projectile/fireball/greater"
	library.grant_spell(viewer, fireball_path)
	library.grant_spell(viewer, greater_path)
	var/obj/effect/proc_holder/spell/body_spell = target.mob_spell_list[1]
	var/datum/action/body_action = body_spell.action
	var/obj/effect/proc_holder/spell/duplicate = new /obj/effect/proc_holder/spell/invoked/projectile/fireball()
	duplicate.name = "Renamed fireball"
	target.AddSpell(duplicate)
	var/datum/admin_spell_library/denied = new(null, target)
	allocated += denied
	TEST_ASSERT(!denied.revoke_spell(viewer, fireball_path), "Unauthorized clients cannot remove spells.")
	TEST_ASSERT(!library.revoke_spell(target, fireball_path), "Other users cannot remove spells through this window.")
	TEST_ASSERT(!library.revoke_spell(viewer, "/mob/living"), "Revocation rejects non-spell paths.")
	TEST_ASSERT(!library.revoke_spell(viewer, list("bad")), "Revocation rejects non-text paths.")
	TEST_ASSERT_EQUAL(length(target.mob_spell_list), 3, "Rejected requests must not change any spells.")
	library.revoke_spell(viewer, fireball_path)
	TEST_ASSERT_EQUAL(length(target.mob_spell_list), 1, "Remove all exact-type copies, leaving subtypes intact.")
	TEST_ASSERT(QDELETED(body_spell) && QDELETED(duplicate), "Removed body spells must be deleted.")
	TEST_ASSERT(QDELETED(body_action) && !(body_action in target.actions), "Removing a spell must also remove its action button.")
	TEST_ASSERT(!library.known_spells(target)[fireball_path], "Removed spells must disappear from the known filter.")
	TEST_ASSERT(library.known_spells(target)[greater_path], "Removing a base spell must not remove its stronger variant.")
	library.revoke_spell(viewer, fireball_path)
	TEST_ASSERT_EQUAL(length(target.mob_spell_list), 1, "Repeated removals must not affect another spell.")
	library.grant_spell(viewer, fireball_path)
	TEST_ASSERT(library.known_spells(target)[fireball_path], "Removed spells can be granted again.")

	var/datum/mind/mind = new()
	allocated += mind
	target.mind = mind
	mind.current = target
	library.revoke_spell(viewer, fireball_path)
	TEST_ASSERT(library.known_spells(target)[fireball_path], "A stale mindless window cannot remove spells after a mind is added.")
	var/datum/admin_spell_library/unit_test/minded = new(null, target)
	allocated += minded
	minded.test_user = viewer
	var/obj/effect/proc_holder/spell/mind_spell = new /obj/effect/proc_holder/spell/invoked/projectile/fireball()
	mind.AddSpell(mind_spell)
	var/datum/action/mind_action = mind_spell.action
	minded.grant_spell(viewer, "/obj/effect/proc_holder/spell/invoked/blink")
	var/used_points = mind.used_spell_points
	minded.revoke_spell(viewer, fireball_path)
	TEST_ASSERT(!minded.known_spells(target)[fireball_path], "Revocation must remove the type from both mind and body lists.")
	TEST_ASSERT(QDELETED(mind_spell) && QDELETED(mind_action), "Mind spells and their action buttons must be deleted.")
	TEST_ASSERT(mind.has_spell(/obj/effect/proc_holder/spell/invoked/blink, TRUE), "Other mind-owned spells must remain available.")
	TEST_ASSERT(minded.known_spells(target)[greater_path], "Other body-owned spells must remain available.")
	TEST_ASSERT_EQUAL(mind.used_spell_points, used_points, "Admin revocation must not refund learning points.")
	mind.current = viewer
	minded.revoke_spell(viewer, "/obj/effect/proc_holder/spell/invoked/blink")
	TEST_ASSERT(mind.has_spell(/obj/effect/proc_holder/spell/invoked/blink, TRUE), "A moved mind invalidates revocation requests.")
	mind.current = target
	minded.revoke_spell(viewer, "/obj/effect/proc_holder/spell/invoked/blink")
	TEST_ASSERT(!mind.has_spell(/obj/effect/proc_holder/spell/invoked/blink, TRUE), "Mind-only spells must be removable.")
	qdel(target)
	TEST_ASSERT(minded.revoke_spell(viewer, greater_path), "Deleted recipients should return a refreshed invalid-target status.")
