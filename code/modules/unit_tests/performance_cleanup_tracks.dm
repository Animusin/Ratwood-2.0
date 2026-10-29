/// Isolate reusable tracks without disturbing the live expiry queue or pre-existing pools.
/datum/performance_track_pool_fixture
	var/list/old_tracks
	var/list/old_cant
	var/old_created
	var/old_recycled

/datum/performance_track_pool_fixture/New()
	old_tracks = SStracks.track_pool
	old_cant = SStracks.thievescant_pool
	old_created = SStracks.tracks_created
	old_recycled = SStracks.tracks_recycled
	SStracks.track_pool = list()
	SStracks.thievescant_pool = list()

/datum/performance_track_pool_fixture/Destroy()
	for(var/obj/effect/track/track as anything in SStracks.track_pool.Copy())
		qdel(track)
	for(var/obj/effect/track/track as anything in SStracks.thievescant_pool.Copy())
		qdel(track)
	SStracks.track_pool = old_tracks
	SStracks.thievescant_pool = old_cant
	SStracks.tracks_created = old_created
	SStracks.tracks_recycled = old_recycled
	old_tracks = null
	old_cant = null
	return ..()

/datum/unit_test/proc/count_ordinary_tracks(turf/location)
	. = 0
	for(var/obj/effect/track/track in location)
		if(track.type == /obj/effect/track)
			.++

/// Existing three-track tiles must converge to one fresh footprint without erasing other clue types.
/datum/unit_test/performance_tracks_single_latest/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/turf/location = run_loc_floor_bottom_left
	for(var/i in 1 to 3)
		var/obj/effect/track/legacy = allocate(/obj/effect/track)
		legacy.handle_creation(first)
		legacy.add_knower(first)
	var/obj/effect/track/structure/clue = allocate(/obj/effect/track/structure)
	clue.handle_creation(first)
	var/obj/effect/track/thievescant/cant = allocate(/obj/effect/track/thievescant)
	cant.handle_creation(first, "Keep this engraving")
	second.dir = EAST
	var/obj/effect/track/latest = second.create_ordinary_track(location)
	TEST_ASSERT_EQUAL(count_ordinary_tracks(location), 1, "Replacing legacy tracks must leave exactly one ordinary footprint on the tile.")
	TEST_ASSERT_EQUAL(latest.creator, second, "The remaining footprint must belong to the most recent passerby.")
	TEST_ASSERT_EQUAL(latest.facing, "east", "The fresh footprint must use the new passerby's direction.")
	TEST_ASSERT_EQUAL(latest.creation_time, world.time, "The remaining footprint must have a fresh timestamp.")
	TEST_ASSERT_EQUAL(latest.expiry_time, world.time + 20 MINUTES, "The single-footprint limit must preserve the full lifetime.")
	TEST_ASSERT_EQUAL(length(latest.known_by), 0, "The previous footprint's viewers must not inherit knowledge of a different passerby.")
	TEST_ASSERT((clue in location) && !QDELETED(clue), "The ordinary-footprint limit must preserve structure clues.")
	TEST_ASSERT((cant in location) && cant.message == "Keep this engraving", "The ordinary-footprint limit must preserve engravings.")

/// Repeated footsteps refresh one atom and one expiry registration, including transformation-to-footstep reuse.
/datum/unit_test/performance_tracks_refresh/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/track/track = first.create_ordinary_track(run_loc_floor_bottom_left)
	var/created_before = SStracks.tracks_created
	track.base_diff = 6
	track.track_type = "transformation clue"
	track.overwrites = 7
	track.add_knower(first)
	var/obj/effect/track/refreshed = first.create_ordinary_track(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(refreshed, track, "Repeated footsteps must reuse the track in place.")
	TEST_ASSERT_EQUAL(track.overwrites, 8, "A repeated footprint must preserve the overwrite count.")
	TEST_ASSERT_EQUAL(track.base_diff, initial(track.base_diff), "A normal footstep must not inherit a transformation clue's easier difficulty.")
	TEST_ASSERT(track.track_type != "transformation clue", "Refreshing must replace the previous clue description.")
	TEST_ASSERT_EQUAL(length(track.known_by), 0, "Refreshing must remove stale viewer knowledge.")
	for(var/i in 1 to 100)
		var/mob/living/passerby = (i % 2) ? first : second
		TEST_ASSERT_EQUAL(passerby.create_ordinary_track(run_loc_floor_bottom_left), track, "Different passersby must reuse the same footprint atom.")
	TEST_ASSERT_EQUAL(SStracks.tracks_created, created_before, "Repeated footsteps must not allocate additional track atoms.")
	TEST_ASSERT_EQUAL(count_ordinary_tracks(run_loc_floor_bottom_left), 1, "Repeated footsteps must not accumulate on a tile.")
	var/registrations = 0
	for(var/obj/effect/track/entry as anything in SStracks.processing)
		if(entry == track)
			registrations++
	TEST_ASSERT_EQUAL(registrations, 1, "Refreshing must leave exactly one expiry registration.")

/// Manual recycling must unschedule a track, and repeating it must not duplicate the pool entry.
/datum/unit_test/performance_tracks_pool_lifecycle/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/mob/living/creator = allocate(/mob/living)
	var/obj/effect/track/track = creator.create_ordinary_track(run_loc_floor_bottom_left)
	SStracks.recycle_track(track)
	TEST_ASSERT(!(track in SStracks.processing), "A pooled track must leave the expiry queue immediately.")
	TEST_ASSERT(!track.registered_for_expiry && track.in_track_pool, "Recycling must update the scheduling and pool state.")
	TEST_ASSERT_NULL(track.loc, "A pooled track must leave the map.")
	TEST_ASSERT_NULL(track.creator, "A pooled track must release its creator.")
	SStracks.recycle_track(track)
	SStracks.add_track(track)
	TEST_ASSERT_EQUAL(length(SStracks.track_pool), 1, "Recycling twice must not enqueue the same atom twice.")
	TEST_ASSERT(!(track in SStracks.processing), "A dormant pooled track must not be rescheduled.")
	var/obj/effect/track/reused = SStracks.get_track(/obj/effect/track, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(reused, track, "A reusable footprint must be checked out from its pool.")
	TEST_ASSERT(!reused.in_track_pool, "Checking out a track must clear its pool state.")
	reused.handle_creation(creator)
	TEST_ASSERT(reused in SStracks.processing, "A reused footprint must resume expiry tracking.")
	SStracks.recycle_track(reused)
	qdel(reused)
	TEST_ASSERT_EQUAL(length(SStracks.track_pool), 0, "Deleting a pooled atom must remove its stale pool entry.")

/// Specialized clues and stale references must never be returned as ordinary footprints.
/datum/unit_test/performance_tracks_pool_types/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/obj/effect/track/structure/clue = allocate(/obj/effect/track/structure)
	SStracks.recycle_track(clue)
	TEST_ASSERT(QDELETED(clue), "Unsupported clue subtypes must expire instead of contaminating the ordinary pool.")
	TEST_ASSERT_EQUAL(length(SStracks.track_pool), 0, "A structure clue must not enter the ordinary pool.")
	var/obj/effect/track/ordinary = allocate(/obj/effect/track)
	SStracks.recycle_track(ordinary)
	var/obj/effect/track/special = SStracks.get_track(/obj/effect/track/structure, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(special.type, /obj/effect/track/structure, "An unsupported pool subtype must be constructed as its requested type.")
	TEST_ASSERT_EQUAL(length(SStracks.track_pool), 1, "Requesting a specialized clue must not drain the ordinary pool.")
	TEST_ASSERT(ordinary in SStracks.track_pool, "A specialized request must leave reusable ordinary footprints untouched.")
	var/obj/effect/track/structure/wrong_type = allocate(/obj/effect/track/structure)
	wrong_type.in_track_pool = TRUE
	SStracks.track_pool += wrong_type
	var/obj/effect/track/stale = allocate(/obj/effect/track)
	qdel(stale)
	SStracks.track_pool += stale
	var/runtimes_before = GLOB.total_runtimes
	var/obj/effect/track/replacement = SStracks.get_track(/obj/effect/track, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(replacement.type, /obj/effect/track, "A checkout must return the requested exact type.")
	TEST_ASSERT(!QDELETED(replacement), "A checkout must discard stale deleted entries.")
	TEST_ASSERT(QDELETED(wrong_type), "A mismatched pooled subtype must be discarded.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Stale pool entries must not trigger movement runtimes.")

/// Expiry must recycle only elapsed tracks and leave fresh evidence scheduled.
/datum/unit_test/performance_tracks_expiry/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/mob/living/creator = allocate(/mob/living)
	var/obj/effect/track/expired = creator.create_ordinary_track(run_loc_floor_bottom_left)
	var/obj/effect/track/fresh = creator.create_ordinary_track(run_loc_floor_top_right)
	expired.expiry_time = world.time - 1
	var/list/old_currentrun = SStracks.currentrun
	var/old_state = SStracks.state
	var/old_limit = Master.current_ticklimit
	SStracks.currentrun = list(expired, fresh)
	SStracks.state = SS_RUNNING
	Master.current_ticklimit = INFINITY
	SStracks.fire(TRUE)
	SStracks.currentrun = old_currentrun
	SStracks.state = old_state
	Master.current_ticklimit = old_limit
	TEST_ASSERT(expired.in_track_pool && !(expired in SStracks.processing), "Elapsed evidence must be recycled and unscheduled.")
	TEST_ASSERT_NULL(expired.loc, "Elapsed evidence must disappear from its tile.")
	TEST_ASSERT(fresh.registered_for_expiry && (fresh in SStracks.processing), "Unexpired evidence must stay scheduled.")
	TEST_ASSERT_EQUAL(fresh.loc, run_loc_floor_top_right, "Unexpired evidence must remain on its tile.")

/// A creator who also knows their own track uses the shared viewer deletion handler.
/datum/unit_test/performance_tracks_creator_knower/Run()
	allocate(/datum/performance_track_pool_fixture)
	var/mob/living/creator = allocate(/mob/living)
	var/obj/effect/track/track = creator.create_ordinary_track(run_loc_floor_bottom_left)
	track.add_knower(creator)
	qdel(creator)
	TEST_ASSERT_NULL(track.creator, "Deleting a creator who knows their track must still clear the creator reference.")
	TEST_ASSERT_EQUAL(length(track.known_by), 0, "Deleting a creator must remove their viewer knowledge as well.")
	TEST_ASSERT(!QDELETED(track), "Deleting a creator must preserve the remaining anonymous evidence until expiry.")
