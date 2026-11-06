/// Supply the image without starting a hallucination on a connected player.
/datum/hallucination/chasing_mob/unit_test_nov06/New(mob/living/carbon/patient)
	target = patient
	hallucinated_image = image('icons/roguetown/maniac/dreamer_mobs.dmi', get_turf(patient), "M3")

/datum/unit_test/runtime_nov06_chasing_image_cleanup/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/hallucination/chasing_mob/hallucination = new /datum/hallucination/chasing_mob/unit_test_nov06(patient)
	allocated += hallucination
	var/image/appearance = hallucination.hallucinated_image
	var/runtimes_before = GLOB.total_runtimes
	// The real chase callback cancels after a player disconnects.
	hallucination.chase_step(patient, get_turf(patient), 3, 5)
	TEST_ASSERT(QDELETED(hallucination), "A disconnected victim must end the chase.")
	TEST_ASSERT_NULL(hallucination.hallucinated_image, "Ending a chase must release its image reference.")
	TEST_ASSERT(!QDELETED(appearance), "Releasing a hallucination must not send its image through qdel.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Chasing hallucination cleanup must not qdel an image.")

/datum/beam/unit_test_nov06
	var/draw_calls = 0

/datum/beam/unit_test_nov06/Draw(atom/movable/mover, atom/oldloc)
	draw_calls++
	return ..()

/datum/unit_test/runtime_nov06_beam_shared_endpoint
	var/movement_notifications = 0

/datum/unit_test/runtime_nov06_beam_shared_endpoint/proc/count_movement(datum/source)
	SIGNAL_HANDLER
	movement_notifications++

/datum/unit_test/runtime_nov06_beam_shared_endpoint/Run()
	var/obj/origin = allocate(/obj)
	RegisterSignal(origin, COMSIG_MOVABLE_MOVED, PROC_REF(count_movement))
	var/datum/beam/unit_test_nov06/beam = new(origin, origin)
	allocated += beam
	var/runtimes_before = GLOB.total_runtimes
	beam.Start()
	TEST_ASSERT_EQUAL(beam.draw_calls, 1, "Starting a beam must still draw it.")
	origin.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(movement_notifications > 0, "The fixture must send real movement notifications.")
	TEST_ASSERT_EQUAL(beam.draw_calls, 1 + movement_notifications, "A shared endpoint must redraw exactly once for each movement notification.")
	qdel(origin)
	TEST_ASSERT(QDELETED(beam), "Deleting the shared endpoint must still remove its beam.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A beam with one shared endpoint must not register either signal twice.")

	var/obj/first = allocate(/obj)
	var/obj/second = allocate(/obj, run_loc_floor_top_right)
	movement_notifications = 0
	RegisterSignal(first, COMSIG_MOVABLE_MOVED, PROC_REF(count_movement))
	RegisterSignal(second, COMSIG_MOVABLE_MOVED, PROC_REF(count_movement))
	var/datum/beam/unit_test_nov06/ordinary = new(first, second)
	allocated += ordinary
	ordinary.Start()
	first.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(movement_notifications > 0, "Moving the origin must notify its beam.")
	var/origin_notifications = movement_notifications
	second.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(movement_notifications > origin_notifications, "Moving the distinct target must notify its beam too.")
	TEST_ASSERT_EQUAL(ordinary.draw_calls, 1 + movement_notifications, "An ordinary beam must redraw once per notification from either endpoint.")
	qdel(second)
	TEST_ASSERT(QDELETED(ordinary), "Deleting the distinct target must still remove its beam.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Both ordinary and shared endpoint beams must clean up without runtime warnings.")

/mob/living/simple_animal/hostile/retaliate/rogue/voiddragon/unit_test_nov06
	AIStatus = AI_OFF

/// A target can block the LOS probe on its own tile, as happened in the live stack.
/mob/living/simple_animal/hostile/retaliate/rogue/voiddragon/unit_test_nov06/los_check(mob/first, mob/second)
	return FALSE

/mob/living/carbon/human/consistent/unit_test_nov06_lightning
	var/shock_calls = 0
	var/shock_total = 0

/mob/living/carbon/human/consistent/unit_test_nov06_lightning/anti_magic_check(magic, holy, tinfoil, chargecost, self)
	return FALSE

/mob/living/carbon/human/consistent/unit_test_nov06_lightning/electrocute_act(shock_damage, source, siemens_coeff, flags)
	shock_calls++
	shock_total += shock_damage
	return shock_damage

/datum/unit_test/runtime_nov06_dragon_no_self_bounce/Run()
	var/mob/living/simple_animal/hostile/retaliate/rogue/voiddragon/dragon = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/voiddragon/unit_test_nov06)
	var/mob/living/carbon/human/consistent/unit_test_nov06_lightning/first = allocate(/mob/living/carbon/human/consistent/unit_test_nov06_lightning)
	var/runtimes_before = GLOB.total_runtimes
	dragon.Bolt(dragon, first, 30, 2, dragon)
	TEST_ASSERT_EQUAL(first.shock_calls, 1, "A lone victim must not repeatedly bounce lightning into itself when its LOS check fails.")
	TEST_ASSERT_EQUAL(first.shock_total, 30, "The initial lightning hit must keep its damage.")
	var/mob/living/carbon/human/consistent/unit_test_nov06_lightning/second = allocate(/mob/living/carbon/human/consistent/unit_test_nov06_lightning)
	first.shock_calls = 0
	dragon.Bolt(dragon, first, 30, 1, dragon)
	TEST_ASSERT_EQUAL(first.shock_calls, 1, "The initial target must receive one hit before bouncing.")
	TEST_ASSERT_EQUAL(second.shock_calls, 1, "Lightning must still bounce to another nearby victim.")
	TEST_ASSERT_EQUAL(second.shock_total, 25, "A normal bounce must retain its reduced damage.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Dragon lightning must not create duplicate endpoint subscriptions.")

/datum/unit_test/runtime_nov06_knifebelt_lifetime/Run()
	var/obj/item/storage/belt/rogue/leather/knifebelt/belt = allocate(/obj/item/storage/belt/rogue/leather/knifebelt/black/psydon)
	TEST_ASSERT_EQUAL(length(belt.knives), 5, "A preloaded belt must retain all five blades.")
	var/obj/item/knife = belt.knives[1]
	TEST_ASSERT_NULL(knife.loc, "Preloaded blades must not take up ordinary storage slots.")
	var/runtimes_before = GLOB.total_runtimes
	qdel(knife)
	TEST_ASSERT_EQUAL(length(belt.knives), 4, "A destroyed preloaded blade must immediately leave the registry.")
	var/list/remaining = belt.knives.Copy()
	qdel(belt)
	for(var/obj/item/blade as anything in remaining)
		TEST_ASSERT(QDELETED(blade), "Deleting a belt must clean up its owned nullspace blades.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Belt and blade cleanup must not leave stale deletion callbacks.")

/datum/unit_test/runtime_nov06_knifebelt_withdrawal/Run()
	var/obj/item/storage/belt/rogue/leather/knifebelt/belt = allocate(/obj/item/storage/belt/rogue/leather/knifebelt)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/rogueweapon/huntingknife/throwingknife/knife = allocate(/obj/item/rogueweapon/huntingknife/throwingknife)
	var/runtimes_before = GLOB.total_runtimes
	TEST_ASSERT(user.put_in_hands(knife), "The knife must begin held.")
	belt.attackby(knife, user)
	TEST_ASSERT(knife in belt.knives, "Inserting a held blade must register it.")
	TEST_ASSERT(!user.is_holding(knife), "An inserted blade must leave the hand.")
	TEST_ASSERT_EQUAL(knife.loc, belt, "Inserted blades must stay in the belt until withdrawn.")
	// Recreate a legacy stale entry without relying on garbage-collector timing.
	belt.knives += list(null)
	TEST_ASSERT(belt.attack_right(user), "Withdrawal must skip a missing blade and reach the surviving one.")
	TEST_ASSERT(user.is_holding(knife), "The surviving blade must be drawn into a hand.")
	TEST_ASSERT_EQUAL(length(belt.knives), 0, "Withdrawal must consume both the stale entry and the drawn blade.")
	user.dropItemToGround(knife)
	TEST_ASSERT(belt.eatknife(knife), "Gathering a blade must still work.")
	knife.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(length(belt.knives), 0, "A blade removed through another route must leave the registry.")
	TEST_ASSERT(!belt.attack_right(user), "An empty belt must not retrieve a blade that is now elsewhere.")
	TEST_ASSERT_EQUAL(knife.loc, run_loc_floor_top_right, "The removed blade must remain where it was moved.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Empty, stale and ordinary belt withdrawals must not runtime.")
