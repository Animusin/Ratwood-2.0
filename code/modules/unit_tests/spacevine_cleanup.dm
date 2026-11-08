/// Removing a controller alone must release references without deleting its visible plants.
/datum/unit_test/spacevine_controller_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/vine = controller.vines[1]
	var/old_icon = vine.icon_state

	qdel(controller)

	TEST_ASSERT(!QDELETED(tree), "Controller deletion must leave its tree on the map.")
	TEST_ASSERT(!QDELETED(vine), "Controller deletion must leave its vines on the map.")
	TEST_ASSERT_EQUAL(vine.icon_state, old_icon, "Controller cleanup must not change a vine's appearance.")
	TEST_ASSERT_NULL(tree.controller, "The tree must release its destroyed controller.")
	TEST_ASSERT_NULL(vine.master, "The vine must release its destroyed controller.")
	TEST_ASSERT_NULL(controller.tree, "The controller must release its tree.")
	TEST_ASSERT_NULL(controller.vines, "The controller must release its vines.")
	TEST_ASSERT_NULL(controller.growth_queue, "The controller must release its growth queue.")
	TEST_ASSERT_NULL(controller.vine_mutations_list, "The controller must release its mutation list.")
	TEST_ASSERT(!(controller in SSobj.processing), "The destroyed controller must stop processing.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "The destroyed controller must have no references beyond this test and the garbage queue.")

/// The normal end-of-event path leaves weakened, withered vines and releases the controller.
/datum/unit_test/spacevine_end_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/first = controller.vines[1]
	var/obj/structure/vine/second = controller.spawn_spacevine_piece(get_step(run_loc_floor_bottom_left, EAST), first)
	var/first_icon = first.icon_state
	var/second_icon = second.icon_state

	controller.endvines()

	TEST_ASSERT(QDELETED(controller), "Ending vines must delete their controller.")
	TEST_ASSERT(!QDELETED(first) && !QDELETED(second), "Ending vines must keep their withered remains.")
	TEST_ASSERT_EQUAL(first.icon_state, "[first_icon]d", "The original vine must wither.")
	TEST_ASSERT_EQUAL(second.icon_state, "[second_icon]d", "Spread vines must wither too.")
	TEST_ASSERT_EQUAL(first.obj_integrity, 1, "Withered vines must retain their reduced integrity.")
	TEST_ASSERT_EQUAL(second.obj_integrity, 1, "Spread vines must retain their reduced integrity.")
	TEST_ASSERT_NULL(first.master, "The original withered vine must release its controller.")
	TEST_ASSERT_NULL(second.master, "Spread withered vines must release their controller.")
	TEST_ASSERT_NULL(tree.controller, "The remaining tree must release its controller.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "Withered plants must not force their controller to hard-delete.")
	// Removing the remains later must not call back into the destroyed controller.
	qdel(first)
	qdel(second)

/// Destroying the tree must safely finish the event while its own Destroy is still running.
/datum/unit_test/spacevine_tree_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/vine = controller.vines[1]
	var/old_icon = vine.icon_state

	qdel(tree)
	// Capture before property assertions: BYOND retains the last field receiver in a temporary.
	var/controller_refs = refcount(controller)

	TEST_ASSERT(QDELETED(controller), "Destroying the tree must end its vine controller.")
	TEST_ASSERT(!QDELETED(vine), "Destroying the tree must leave withered vines behind.")
	TEST_ASSERT_EQUAL(vine.icon_state, "[old_icon]d", "Tree destruction must wither its vines.")
	TEST_ASSERT_NULL(vine.master, "The surviving vine must release its controller.")
	TEST_ASSERT_NULL(tree.controller, "The destroyed tree must release its controller.")
	TEST_ASSERT_NULL(controller.tree, "The destroyed controller must release its tree.")
	TEST_ASSERT(controller_refs <= baseline_refs(), "Tree destruction must leave its controller collectable ([controller_refs] references; baseline [baseline_refs()]).")

/// Cutting the last vine destroys the controller even while the tree remains alive.
/datum/unit_test/spacevine_last_vine_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/vine = controller.vines[1]

	qdel(vine)

	TEST_ASSERT(QDELETED(controller), "Removing the last vine must destroy its controller.")
	TEST_ASSERT(!QDELETED(tree), "Removing the last vine must preserve the tree.")
	TEST_ASSERT_NULL(tree.controller, "The surviving tree must not retain the finished controller.")
	TEST_ASSERT_NULL(vine.master, "The destroyed vine must release its controller.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "The last vine's controller must be collectable.")

/// Removing one of several vines must preserve the event and its remaining growth queue.
/datum/unit_test/spacevine_partial_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/vine/first = controller.vines[1]
	var/obj/structure/vine/second = controller.spawn_spacevine_piece(get_step(run_loc_floor_bottom_left, EAST), first)

	qdel(first)
	var/still_active = !QDELETED(controller) && (controller in SSobj.processing)
	var/remaining_vines = length(controller.vines)
	var/remaining_growth = length(controller.growth_queue)
	var/second_registered = second.master == controller && (second in controller.vines) && (second in controller.growth_queue)
	// Clean up the event before any assertion can leave it running in another test.
	qdel(controller)

	TEST_ASSERT(still_active, "Removing one vine must keep the remaining event active.")
	TEST_ASSERT_EQUAL(remaining_vines, 1, "Only the destroyed vine must leave the controller's list.")
	TEST_ASSERT_EQUAL(remaining_growth, 1, "Only the destroyed vine must leave the growth queue.")
	TEST_ASSERT(second_registered, "The surviving vine must retain its growth registration.")

/// Admin deletion must survive the final vine deleting its controller during iteration.
/datum/unit_test/spacevine_purge_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/first = controller.vines[1]
	var/obj/structure/vine/second = controller.spawn_spacevine_piece(get_step(run_loc_floor_bottom_left, EAST), first)
	var/obj/structure/vine/third = controller.spawn_spacevine_piece(get_step(run_loc_floor_bottom_left, NORTH), first)

	controller.DeleteVines()

	TEST_ASSERT(QDELETED(first) && QDELETED(second) && QDELETED(third), "Purging vines must delete every member of the cluster.")
	TEST_ASSERT(QDELETED(controller), "Purging vines must delete their controller.")
	TEST_ASSERT(!QDELETED(tree), "Purging vines must preserve the tree, as before.")
	TEST_ASSERT_NULL(tree.controller, "The tree must release its purged controller.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "The purged controller must be collectable after the deletion loop returns.")

/// Mutation callbacks may end their event while the processing loop is still running.
/datum/unit_test/spacevine_callback_cleanup/Run()
	var/datum/vine_controller/controller = new(run_loc_floor_bottom_left)
	var/obj/structure/vine/vine = controller.vines[1]
	var/datum/vine_mutation/spacevine_cleanup_process/mutation = new
	vine.mutations += mutation

	controller.process()

	TEST_ASSERT(QDELETED(controller), "The mutation must destroy its controller during processing.")
	TEST_ASSERT_NULL(controller.growth_queue, "Processing must not restore the destroyed controller's queue.")
	TEST_ASSERT_NULL(vine.master, "The surviving vine must release the controller destroyed by its callback.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "Processing callbacks must leave their destroyed controller collectable.")

/datum/vine_mutation/spacevine_cleanup_process/process_mutation(obj/structure/vine/holder)
	qdel(holder.master)

/// A spread callback can destroy the tree and end the event before process() restores its queue.
/datum/unit_test/spacevine_spread_cleanup/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/datum/vine_controller/controller = new(center)
	var/obj/structure/flora/roguetree/evil/tree = controller.tree
	var/obj/structure/vine/vine = controller.vines[1]
	var/datum/vine_mutation/spacevine_cleanup_spread/mutation = new
	vine.mutations += mutation

	controller.process()

	TEST_ASSERT(QDELETED(tree), "The spread mutation must destroy the tree.")
	TEST_ASSERT(QDELETED(controller), "Tree destruction from spread must destroy the controller.")
	TEST_ASSERT_NULL(controller.growth_queue, "Finishing spread must not recreate the destroyed controller's queue.")
	TEST_ASSERT_NULL(vine.master, "The withered vine must release the controller destroyed during spread.")
	TEST_ASSERT(refcount(controller) <= baseline_refs(), "A controller ended during spread must remain collectable.")

/datum/vine_mutation/spacevine_cleanup_spread/on_spread(obj/structure/vine/holder, turf/target)
	qdel(holder.master.tree)
