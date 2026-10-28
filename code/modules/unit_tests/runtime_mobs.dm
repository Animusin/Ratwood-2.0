/datum/unit_test/runtime_retaliation_owner_subscription/Run()
	var/mob/living/simple_animal/hostile/retaliate/rogue/animal = allocate(/mob/living/simple_animal/hostile/retaliate/rogue)
	var/mob/living/owner = allocate(/mob/living)
	animal.owner = owner
	animal.attack_same = TRUE
	animal.vision_range = 0
	var/runtimes_before = GLOB.total_runtimes
	// Retaliate adds nearby mobs, then exempts the animal's owner again.
	animal.Retaliate()
	animal.Retaliate()
	TEST_ASSERT(!(owner in animal.enemies), "An animal must continue to exempt its owner from retaliation.")
	var/list/owner_signals = animal.signal_procs ? animal.signal_procs[owner] : null
	TEST_ASSERT(!owner_signals || !(COMSIG_QDELETING in owner_signals), "Removing an owner from enemies must also remove the deletion subscription.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Repeated retaliation must not overwrite an existing signal handler.")
	animal.add_enemy(owner)
	qdel(owner)
	TEST_ASSERT(!(owner in animal.enemies), "An enemy added later must still be removed when it is deleted.")

/datum/unit_test/runtime_dullahan_vomit_container/Run()
	var/mob/living/carbon/human/vomiter = allocate(/mob/living/carbon/human/consistent)
	vomiter.set_species(/datum/species/dullahan)
	var/datum/species/dullahan/species = vomiter.dna.species
	var/obj/item/bodypart/head/dullahan/head = species.my_head
	TEST_ASSERT(head, "The revenant fixture must have its own detachable head.")
	head.drop_limb(FALSE)
	var/obj/item/storage/backpack/rogue/satchel/short/bag = allocate(/obj/item/storage/backpack/rogue/satchel/short)
	head.forceMove(bag)
	vomiter.physiology.bleed_mod = 2
	var/blood_before = vomiter.get_blood_volume()
	var/runtimes_before = GLOB.total_runtimes
	vomiter.vomit(blood = TRUE, stun = FALSE, distance = 0, message = FALSE)
	var/blood_after = vomiter.get_blood_volume()
	head.attach_limb(vomiter)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A detached head inside a satchel must not read physiology from the satchel.")
	TEST_ASSERT_EQUAL(blood_after, blood_before - 10, "Blood loss must use the revenant's own bleeding multiplier.")

/datum/unit_test/runtime_dullahan_missing_head_hearing/Run()
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent)
	listener.set_species(/datum/species/dullahan)
	var/datum/species/dullahan/species = listener.dna.species
	var/obj/item/bodypart/head/dullahan/head = species.my_head
	TEST_ASSERT(head, "The revenant fixture must begin with a head.")
	// Protect the owner from death so both living and dead hearing can be checked.
	listener.status_flags |= GODMODE
	head.drop_limb(FALSE)
	TEST_ASSERT(listener.can_hear(), "An intact detached head must still provide hearing.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(head)
	TEST_ASSERT_NULL(species.my_head, "The actual head deletion signal must clear the species reference.")
	TEST_ASSERT(!listener.can_hear(), "A living revenant without its head or ears must not hear.")
	listener.stat = DEAD
	TEST_ASSERT(listener.can_hear(), "Dead mobs must retain the existing ability to hear messages.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Checking hearing after head deletion must not dereference a missing head.")

/// Keep the collision's damage observable without relying on random bodypart selection.
/mob/living/carbon/human/consistent/runtime_impact_target
	var/impact_damage = 0

/mob/living/carbon/human/consistent/runtime_impact_target/take_bodypart_damage(brute = 0, burn = 0, stamina = 0, updating_health = TRUE, required_status, check_armor = FALSE)
	impact_damage += brute
	return TRUE

/mob/living/carbon/human/consistent/runtime_impact_target/hitby(atom/movable/AM, skipcatch, hitpush = TRUE, blocked = FALSE, datum/thrownthing/throwingdatum, damage_flag = "blunt")
	return TRUE

/datum/unit_test/runtime_missing_throw_target/Run()
	var/mob/living/carbon/human/consistent/runtime_impact_target/thrown = allocate(/mob/living/carbon/human/consistent/runtime_impact_target)
	var/runtimes_before = GLOB.total_runtimes
	thrown.throw_impact(null)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "The carbon collision handler must preserve the parent's handling of a missing target.")
	TEST_ASSERT_EQUAL(thrown.impact_damage, 0, "A missing target must not cause collision damage.")
	var/mob/living/carbon/human/consistent/runtime_impact_target/target = allocate(/mob/living/carbon/human/consistent/runtime_impact_target)
	thrown.throw_impact(target)
	TEST_ASSERT_EQUAL(thrown.impact_damage, 10, "A valid carbon collision must still injure the thrown mob.")
	TEST_ASSERT_EQUAL(target.impact_damage, 10, "A valid carbon collision must still injure the target.")
