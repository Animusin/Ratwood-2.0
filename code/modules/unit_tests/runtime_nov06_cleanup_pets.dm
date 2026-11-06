/// Taming must not keep a deleted owner's body alive through the surviving pet.
/datum/unit_test/runtime_nov06_pet_owner_deletion/Run()
	var/mob/living/owner = new(run_loc_floor_bottom_left)
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	pet.tamed(owner)
	// TEST_ASSERT_EQUAL stores both operands in locals, which would retain owner during refcount().
	TEST_ASSERT(pet.owner == owner, "Taming must preserve the real owner while they exist.")
	qdel(owner)
	TEST_ASSERT_NULL(pet.owner, "A surviving pet must release its deleted owner.")
	TEST_ASSERT(pet.tame && !QDELETED(pet), "Losing the owner's body must not untame or delete the pet.")
	TEST_ASSERT(refcount(owner) <= baseline_refs(), "The pet's owner link must not cause a hard delete.")

/// A new owner replaces the old deletion subscription without leaving either owner pinned.
/datum/unit_test/runtime_nov06_pet_owner_reassignment/Run()
	var/mob/living/first_owner = new(run_loc_floor_bottom_left)
	var/mob/living/second_owner = new(run_loc_floor_bottom_left)
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	var/first_refs = refcount(first_owner)
	var/runtimes_before = GLOB.total_runtimes
	pet.tamed(first_owner)
	pet.tamed(second_owner)
	pet.tamed(second_owner)
	TEST_ASSERT_EQUAL(refcount(first_owner), first_refs, "Retaming must release the first owner and its signal subscription.")
	qdel(first_owner)
	TEST_ASSERT_EQUAL(pet.owner, second_owner, "Deleting the previous owner must not clear the new owner.")
	qdel(second_owner)
	TEST_ASSERT_NULL(pet.owner, "The new owner must still be tracked after retaming.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Retaming to the same or another owner must not duplicate subscriptions.")

/// Pet deletion must release its owner even while the pet itself is still queued for collection.
/datum/unit_test/runtime_nov06_pet_deletion/Run()
	var/mob/living/owner = allocate(/mob/living)
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	var/owner_refs = refcount(owner)
	pet.tamed(owner)
	qdel(pet)
	TEST_ASSERT_NULL(pet.owner, "A deleted pet must release its surviving owner.")
	TEST_ASSERT_EQUAL(refcount(owner), owner_refs, "Pet deletion must remove the owner subscription and all owned references.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(owner)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Deleting the owner later must not invoke a deleted pet's callback.")

/// Several callers use TRUE to tame a mount without assigning or changing its owner.
/datum/unit_test/runtime_nov06_pet_ownerless_taming/Run()
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	var/mob/living/owner = allocate(/mob/living)
	var/runtimes_before = GLOB.total_runtimes
	pet.tamed(TRUE)
	TEST_ASSERT(pet.tame, "Ownerless taming must still tame the animal.")
	TEST_ASSERT_NULL(pet.owner, "Ownerless taming must not store a number as its owner.")
	pet.tamed(owner)
	pet.tamed(TRUE)
	TEST_ASSERT_EQUAL(pet.owner, owner, "Ownerless taming must preserve an existing owner.")
	qdel(owner)
	TEST_ASSERT_NULL(pet.owner, "Ownerless taming must preserve the real owner's cleanup subscription.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Ownerless taming must never send a signal to a number.")

/// Owner and enemy tracking must coexist; both need the same owner's deletion signal.
/datum/unit_test/runtime_nov06_pet_owner_enemy_tracking/Run()
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	var/mob/living/owner = allocate(/mob/living)
	var/runtimes_before = GLOB.total_runtimes
	pet.add_enemy(owner)
	pet.tamed(owner)
	pet.remove_enemy(owner)
	TEST_ASSERT_EQUAL(pet.owner, owner, "Removing hostility must not remove ownership.")
	pet.add_enemy(owner)
	qdel(owner)
	TEST_ASSERT_NULL(pet.owner, "Enemy cleanup must not replace the owner's deletion callback.")
	TEST_ASSERT(!(owner in pet.enemies), "Owner cleanup must not replace the enemy's deletion callback.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Ownership and hostility must not overwrite each other's signal handlers.")

/// A queued tame call must not reintroduce a reference after the owner's deletion signal has fired.
/datum/unit_test/runtime_nov06_pet_deleted_owner_rejected/Run()
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	var/mob/living/owner = allocate(/mob/living)
	qdel(owner)
	pet.tamed(owner)
	TEST_ASSERT_NULL(pet.owner, "An already deleted mob must never become a new owner.")

/// Saddleborn grief remains independent from releasing the mount's ordinary owner reference.
/datum/unit_test/runtime_nov06_pet_precious_bond/Run()
	var/mob/living/carbon/human/owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/simple_animal/pet = allocate(/mob/living/simple_animal)
	pet.tamed(owner)
	var/datum/component/precious_creature/bond = pet.AddComponent(/datum/component/precious_creature, owner)
	var/runtimes_before = GLOB.total_runtimes
	SEND_SIGNAL(pet, COMSIG_MOB_DEATH, FALSE)
	TEST_ASSERT(owner.has_stress_event(/datum/stressevent/precious_mob_died), "The surviving Saddleborn owner must still grieve its mount.")
	qdel(owner)
	TEST_ASSERT_NULL(pet.owner, "The ordinary mount ownership must release a deleted owner.")
	TEST_ASSERT_NULL(bond.owner.resolve(), "The precious bond must retain its weak ownership semantics.")
	SEND_SIGNAL(pet, COMSIG_MOB_DEATH, FALSE)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A late Saddleborn death callback must tolerate the lost owner.")
