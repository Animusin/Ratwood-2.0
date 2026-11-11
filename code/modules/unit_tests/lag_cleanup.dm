/datum/unit_test/lag_chase_cleanup/Run()
	var/mob/living/simple_animal/pet/cat/rogue/cat = allocate(/mob/living/simple_animal/pet/cat/rogue)
	cat.toggle_ai(AI_OFF)
	var/list/rat_identity = delete_hunted_rat(cat)
	TEST_ASSERT(rat_identity, "The cat must have finished hunting the rat.")
	var/mob/living/simple_animal/hostile/animal = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/wolf)
	animal.toggle_ai(AI_OFF)
	var/list/human_identity = delete_combat_target(animal)
	TEST_ASSERT(human_identity, "The test must finish the combat setup.")
	TEST_ASSERT_NULL(animal.target, "Destroying the current target must stop combat targeting immediately.")
	sleep(10 SECONDS)
	TEST_ASSERT(!still_retained(rat_identity), "The cat's finished pursuit must release the rat for normal collection.")
	TEST_ASSERT(!still_retained(human_identity), "Destroying a chased human must release both the AI and native walking references.")

/datum/unit_test/lag_chase_cleanup/proc/delete_hunted_rat(mob/living/simple_animal/pet/cat/rogue/cat)
	var/obj/item/reagent_containers/food/snacks/smallrat/rat = new(run_loc_floor_bottom_left)
	cat.Life()
	sleep(1 SECONDS)
	TEST_ASSERT(rat.dead, "The cat must still kill a rat it catches.")
	var/reference = text_ref(rat)
	qdel(rat)
	return list(reference, rat.type, rat.gc_destroyed)

/datum/unit_test/lag_chase_cleanup/proc/delete_combat_target(mob/living/simple_animal/hostile/animal)
	var/mob/living/carbon/human/consistent/first = new(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/second = new(run_loc_floor_bottom_left)
	animal.GiveTarget(first)
	animal.set_enemy(second, TRUE)
	animal.GiveTarget(second)
	qdel(first)
	TEST_ASSERT_EQUAL(animal.target, second, "Deleting the old target must preserve the new one.")
	second.death()
	TEST_ASSERT_EQUAL(animal.target, second, "Ordinary death must not run deletion cleanup.")
	animal.Goto(second, animal.move_to_delay, animal.minimum_distance)
	var/reference = text_ref(second)
	qdel(second)
	TEST_ASSERT(!(second in animal.enemies), "Target cleanup must not overwrite enemy-list cleanup.")
	return list(reference, second.type, second.gc_destroyed)

/datum/unit_test/lag_chase_cleanup/proc/still_retained(list/identity)
	var/datum/candidate = locate(identity[1])
	return candidate && candidate.type == identity[2] && candidate.gc_destroyed == identity[3]

/datum/unit_test/lag_combat_target_subscription/Run()
	var/mob/living/simple_animal/hostile/retaliate/rogue/wolf/lag_subscription_test/animal = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/wolf/lag_subscription_test)
	animal.toggle_ai(AI_OFF)
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/runtimes_before = GLOB.total_runtimes
	animal.set_enemy(first, TRUE)
	animal.GiveTarget(first)
	// New-style AI attacks use UnarmedAttack while legacy retaliation still uses GiveTarget.
	animal.UnarmedAttack(second)
	TEST_ASSERT_EQUAL(animal.attacked_target, second, "Unarmed attacks must still act on the newly selected target.")
	animal.GiveTarget(first)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Returning to the earlier combat target after an unarmed attack must not register it twice.")
	// Legacy control paths can replace target without invoking the setter.
	animal.target = null
	animal.GiveTarget(first)
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Reacquiring a directly cleared target must not register its deletion signal twice.")
	animal.target = second
	animal.GiveTarget(second)
	var/datum/component/hostile_combat_target/tracker = animal.combat_target_tracker
	TEST_ASSERT(!tracker.signal_procs[first], "Changing targets must release the previous subscription even after a direct assignment.")
	TEST_ASSERT(tracker.signal_procs[second], "The replacement target must have deletion cleanup.")
	qdel(first)
	TEST_ASSERT_EQUAL(animal.target, second, "Deleting a previous target must not cancel the new pursuit.")
	TEST_ASSERT(!(first in animal.enemies), "Combat subscription cleanup must leave enemy-list cleanup intact.")
	for(var/i in 1 to 5)
		animal.LoseTarget()
		TEST_ASSERT(!length(tracker.signal_procs), "Losing a target must release the listener's target references.")
		animal.GiveTarget(second)
	second.death()
	TEST_ASSERT_EQUAL(animal.target, second, "Death without deletion must retain normal combat targeting.")
	qdel(second)
	TEST_ASSERT_NULL(animal.target, "Deleting the replacement target must cancel pursuit.")
	TEST_ASSERT(!length(tracker.signal_procs), "Deleting a target must release its subscription.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Repeated targeting must not emit runtime warnings.")

/// Exercise real target routing without rolling attack damage or killing either fixture.
/mob/living/simple_animal/hostile/retaliate/rogue/wolf/lag_subscription_test
	var/atom/attacked_target

/mob/living/simple_animal/hostile/retaliate/rogue/wolf/lag_subscription_test/AttackingTarget()
	attacked_target = target
	return TRUE

/mob/living/simple_animal/hostile/retaliate/rogue/wolf/lag_subscription_test/Destroy()
	attacked_target = null
	return ..()

/datum/unit_test/lag_mirespider_follower_cleanup/Run()
	var/mob/living/simple_animal/hostile/rogue/mirespider_lurker/leader = allocate(/mob/living/simple_animal/hostile/rogue/mirespider_lurker)
	var/mob/living/simple_animal/hostile/retaliate/rogue/mirespider/orphan = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/mirespider)
	var/mob/living/simple_animal/hostile/retaliate/rogue/mirespider/follower = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/mirespider)
	var/mob/living/simple_animal/hostile/retaliate/rogue/mirespider/deleted = allocate(/mob/living/simple_animal/hostile/retaliate/rogue/mirespider)
	QDEL_NULL(orphan.ai_controller)
	var/datum/ai_controller/controller = follower.ai_controller
	TEST_ASSERT_NOTNULL(controller, "A normal follower must have its AI controller.")
	controller.set_blackboard_key(BB_FOLLOW_TARGET, leader)
	controller.set_blackboard_key(BB_TRAVEL_DESTINATION, run_loc_floor_bottom_left)
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, leader)
	leader.followers = list(orphan, follower, deleted)
	qdel(deleted)
	leader.clear_followers_if_any()
	TEST_ASSERT(!length(leader.followers), "Cleanup must release all followers, including those with deleted controllers.")
	TEST_ASSERT_NULL(controller.blackboard[BB_FOLLOW_TARGET], "A controllerless follower must not prevent the next follower from losing its leader.")
	TEST_ASSERT_NULL(controller.blackboard[BB_TRAVEL_DESTINATION], "Cleanup must clear the remaining follower's travel destination.")
	TEST_ASSERT_NULL(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "Cleanup must clear the remaining follower's combat target.")
	leader.clear_followers_if_any()

/datum/unit_test/lag_legacy_vice_cleanup/Run()
	var/mob/living/carbon/human/consistent/character = allocate(/mob/living/carbon/human/consistent)
	var/datum/charflaw/first = new /datum/charflaw/addiction/sadist
	var/datum/charflaw/second = allocate(/datum/charflaw/addiction/smoker)
	character.charflaw = first
	character.vices = list(first, second)
	character.delete_legacy_charflaw()
	TEST_ASSERT(QDELETED(first), "Removing the legacy vice must dispose of it.")
	TEST_ASSERT_NULL(character.charflaw, "The legacy slot must be cleared.")
	TEST_ASSERT(!(first in character.vices), "The list must release the deleted vice.")
	TEST_ASSERT_EQUAL(length(character.vices), 1, "Removing one vice must keep the other entries.")
	TEST_ASSERT_EQUAL(character.vices[1], second, "Keep the other vice instance.")

/datum/unit_test/lag_chat_payload_sequence/Run()
	var/test_ckey = "unit-test-lag-chat"
	var/list/content = list("type" = "notice", "html" = "<b>Test \"message\"</b>")
	var/encoded_content = json_encode(content)
	var/datum/chat_payload/first = SSchat.generate_payload(test_ckey, encoded_content, message_to_html(content))
	var/datum/chat_payload/second = SSchat.generate_payload(test_ckey, encoded_content, message_to_html(content))
	SSchat.client_to_sequence_number -= test_ckey
	allocated += list(first, second)
	var/list/first_message = json_decode(first.into_message())
	var/list/second_message = json_decode(second.into_message())
	TEST_ASSERT_EQUAL(first_message["sequence"], 0, "A new connection must start with valid sequence zero.")
	TEST_ASSERT_EQUAL(second_message["sequence"], 1, "The next message must advance the sequence.")
	TEST_ASSERT_EQUAL(first_message["content"]["html"], content["html"], "Encoding a broadcast must preserve its content.")
	TEST_ASSERT_EQUAL(second.legacy_message, content["html"], "Legacy output must still get the same message.")
