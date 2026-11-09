/// A surviving companion must not pin the body of its deleted summoner.
/datum/unit_test/animal_dryad_owner_cleanup/Run()
	var/mob/living/carbon/human/consistent/owner = new(run_loc_floor_bottom_left)
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/spell = allocate(/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad)
	TEST_ASSERT(spell.cast(list(), owner), "Summoning a dryad must succeed in the open test area.")
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad = spell.conjured_dryad
	TEST_ASSERT_NOTNULL(dryad, "The spell must create a companion.")
	allocated += dryad
	qdel(owner)
	// BYOND retains its last native hearers result even after the visible_message frame returns.
	// Refresh that engine cache so this measures the companion's references, not an idle test world.
	var/list/cached_hearers = hearers(0, run_loc_floor_top_right)
	TEST_ASSERT(!length(cached_hearers), "The distant control tile must have no hearing recipients.")
	var/remaining_refs = refcount(owner)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "The companion's owner and follow links must not retain its destroyed summoner ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT(!QDELETED(dryad), "Deleting the summoner's body must not automatically destroy its companion.")
	var/runtimes_before = GLOB.total_runtimes
	dryad.handle_automated_movement()
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A surviving companion must tolerate its lost owner and follow target.")

/// Forgetting the spell keeps the existing companion alive without retaining the destroyed spell.
/datum/unit_test/animal_dryad_spell_cleanup/Run()
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/spell = new
	TEST_ASSERT(spell.cast(list(), owner), "Summoning the companion must succeed.")
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad = spell.conjured_dryad
	TEST_ASSERT_NOTNULL(dryad, "The spell must create a companion.")
	allocated += dryad
	qdel(spell)
	var/remaining_refs = refcount(spell)
	TEST_ASSERT(remaining_refs <= baseline_refs(), "The companion must not retain its forgotten summon spell ([remaining_refs] references; baseline [baseline_refs()]).")
	TEST_ASSERT(!QDELETED(dryad), "Forgetting the spell must preserve the existing companion's lifetime.")
	var/runtimes_before = GLOB.total_runtimes
	dryad.death()
	TEST_ASSERT(QDELETED(dryad), "The companion must still disappear when killed after its spell is forgotten.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Companion death must not call into a destroyed spell.")

/// Keep the existing owner-death bond, voluntary dismissal and combat-death cooldown behavior.
/datum/unit_test/animal_dryad_bond_lifecycle/Run()
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/spell = allocate(/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad)
	TEST_ASSERT(spell.cast(list(), owner), "The first summon must succeed.")
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/lesser/dryad = spell.conjured_dryad
	TEST_ASSERT_NOTNULL(dryad, "The first summon must create a companion.")
	allocated += dryad
	owner.death()
	owner.lastattacker_weakref = WEAKREF(attacker)
	dryad.handle_automated_movement()
	TEST_ASSERT_EQUAL(dryad.target, attacker, "An intact dead owner's bond must remain usable for the existing auto-defend behavior.")
	TEST_ASSERT(spell.cast(list(), owner), "Voluntary dismissal must still succeed.")
	TEST_ASSERT(QDELETED(dryad), "Voluntary dismissal must destroy the summoned companion.")
	TEST_ASSERT_NULL(spell.conjured_dryad, "Voluntary dismissal must clear the active companion.")
	TEST_ASSERT_EQUAL(spell.death_cooldown_until, 0, "Voluntary dismissal must not add the combat-death cooldown.")
	TEST_ASSERT(spell.cast(list(), owner), "Resummoning after voluntary dismissal must still succeed.")
	dryad = spell.conjured_dryad
	TEST_ASSERT_NOTNULL(dryad, "Resummoning must create another companion.")
	allocated += dryad
	dryad.death()
	TEST_ASSERT(QDELETED(dryad), "Killing the dryad must destroy it.")
	TEST_ASSERT_NULL(spell.conjured_dryad, "Combat death must clear the active companion.")
	TEST_ASSERT(spell.death_cooldown_until >= world.time + 2 MINUTES, "Combat death must retain the two-minute resummon cooldown.")

/// Prove actual collection while the companion remains in the world.
/datum/unit_test/animal_dryad_native_gc/Run()
	var/list/identities = create_deleted_bond()
	// No players generate new hearing queries in this fixture; discard the last native query cache.
	// Strong owner/spell references still survive this refresh on the unpatched code.
	var/list/cached_hearers = hearers(0, run_loc_floor_top_right)
	TEST_ASSERT(!length(cached_hearers), "The distant control tile must have no hearing recipients.")
	sleep(10 SECONDS)
	for(var/list/identity as anything in identities)
		TEST_ASSERT(!still_retained(identity), "A living dryad must not force its deleted [identity["type"]] into a hard delete.")

/datum/unit_test/animal_dryad_native_gc/proc/create_deleted_bond()
	var/mob/living/carbon/human/consistent/owner = new(run_loc_floor_bottom_left)
	var/obj/effect/proc_holder/spell/targeted/summon_lesser_dryad/spell = new
	if(!spell.cast(list(), owner) || !spell.conjured_dryad)
		TEST_FAIL("The native collection fixture must summon a real companion.")
	allocated += spell.conjured_dryad
	var/list/owner_identity = list("reference" = text_ref(owner), "type" = owner.type)
	var/list/spell_identity = list("reference" = text_ref(spell), "type" = spell.type)
	qdel(owner)
	qdel(spell)
	owner_identity["gc_destroyed"] = owner.gc_destroyed
	spell_identity["gc_destroyed"] = spell.gc_destroyed
	return list(owner_identity, spell_identity)

/datum/unit_test/animal_dryad_native_gc/proc/still_retained(list/identity)
	var/datum/candidate = locate(identity["reference"])
	return candidate && candidate.type == identity["type"] && candidate.gc_destroyed == identity["gc_destroyed"]
