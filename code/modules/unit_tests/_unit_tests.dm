//include unit test files in this module in this ifdef
//Keep this sorted alphabetically

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// For advanced cases, fail unconditionally but don't return (so a test can return multiple results)
#define TEST_FAIL(reason) (Fail(reason || "No reason", __FILE__, __LINE__))

/// Asserts that a condition is true
/// If the condition is not true, fails the test
#define TEST_ASSERT(assertion, reason) if (!(assertion)) { return Fail("Assertion failed: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that a parameter is not null
#define TEST_ASSERT_NOTNULL(a, reason) if (isnull(a)) { return Fail("Expected non-null value: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that a parameter is null
#define TEST_ASSERT_NULL(a, reason) if (!isnull(a)) { return Fail("Expected null value but received [a]: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that the two parameters passed are equal, fails otherwise
/// Optionally allows an additional message in the case of a failure
#define TEST_ASSERT_EQUAL(a, b, message) do { \
	var/lhs = ##a; \
	var/rhs = ##b; \
	if (lhs != rhs) { \
		return Fail("Expected [isnull(lhs) ? "null" : lhs] to be equal to [isnull(rhs) ? "null" : rhs].[message ? " [message]" : ""]", __FILE__, __LINE__); \
	} \
} while (FALSE)

/// Asserts that the two parameters passed are not equal, fails otherwise
/// Optionally allows an additional message in the case of a failure
#define TEST_ASSERT_NOTEQUAL(a, b, message) do { \
	var/lhs = ##a; \
	var/rhs = ##b; \
	if (lhs == rhs) { \
		return Fail("Expected [isnull(lhs) ? "null" : lhs] to not be equal to [isnull(rhs) ? "null" : rhs].[message ? " [message]" : ""]", __FILE__, __LINE__); \
	} \
} while (FALSE)

/// *Only* run the test provided within the parentheses
/// This is useful for debugging when you want to reduce noise, but should never be pushed
/// Intended to be used in the manner of `TEST_FOCUS(/datum/unit_test/math)`
#define TEST_FOCUS(test_path) ##test_path { focus = TRUE; }

/// Logs a noticable message on GitHub, but will not mark as an error.
/// Use this when something shouldn't happen and is of note, but shouldn't block CI.
/// Does not mark the test as failed.
#define TEST_NOTICE(source, message) source.log_for_test((##message), "notice", __FILE__, __LINE__)

/// Constants indicating unit test completion status
#define UNIT_TEST_PASSED 0
#define UNIT_TEST_FAILED 1
#define UNIT_TEST_SKIPPED 2

#define TEST_PRE 0
#define TEST_DEFAULT 1
/// After most test steps, used for tests that run long so shorter issues can be noticed faster
#define TEST_LONGER 10
/// This must be the one of last tests to run due to the inherent nature of the test iterating every single tangible atom in the game and qdeleting all of them (while taking long sleeps to make sure the garbage collector fires properly) taking a large amount of time.
#define TEST_CREATE_AND_DESTROY 9001
/**
 * For tests that rely on create and destroy having iterated through every (tangible) atom so they don't have to do something similar.
 * Keep in mind tho that create and destroy will absolutely break the test platform, anything that relies on its shape cannot come after it.
 */
#define TEST_AFTER_CREATE_AND_DESTROY INFINITY

/// Change color to red on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_RED(text) "\x1B\x5B1;31m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_RED(text) (text)
#endif
/// Change color to green on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_GREEN(text) "\x1B\x5B1;32m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_GREEN(text) (text)
#endif
/// Change color to yellow on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_YELLOW(text) "\x1B\x5B1;33m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_YELLOW(text) (text)
#endif
/// A trait source when adding traits through unit tests
#define TRAIT_SOURCE_UNIT_TESTS "unit_tests"

// BEGIN_INCLUDE
#include "admin_antags.dm"
#include "admin_job_slots.dm"
#include "anchored_mobs.dm"
#include "animal_dryad_orders.dm"
#include "animal_dryad_retention.dm"
#include "animal_retention.dm"
#include "animal_retention_extra.dm"
#include "anvil_recipes.dm"
#include "baseturfs.dm"
#include "bodypart_consumption_retention.dm"
#include "bodypart_owner_retention.dm"
#include "buildmode_catalog.dm"
#include "colorblind_hud_palette.dm"
#include "component_tests.dm"
#include "create_and_destroy.dm"
#include "donation_refresh.dm"
#include "family_retention.dm"
#include "focus_only_tests.dm"
#include "fulmenor_chair.dm"
#include "ghost_protection.dm"
#include "harddels.dm"
#include "health_mobility.dm"
#include "health_movespeed.dm"
#include "health_transform.dm"
#include "human_retention_extra.dm"
#include "lag_cleanup.dm"
#include "lag_recorder.dm"
#include "legacy_spell_cleanup.dm"
#include "market_daily_recovery.dm"
#include "migrant_config.dm"
#include "mind_retention_extra.dm"
#include "mobs_meter_updates.dm"
#include "mobs_sneak_updates.dm"
#include "mobs_species_life.dm"
#include "mobs_visible_names.dm"
#include "npc_processing.dm"
#include "ooze_forms.dm"
#include "organ_owner_retention.dm"
#include "particle_weather.dm"
#include "performance_cleanup_blood.dm"
#include "performance_cleanup_forensics.dm"
#include "performance_cleanup_intents.dm"
#include "performance_cleanup_mobs.dm"
#include "performance_cleanup_processing.dm"
#include "performance_cleanup_tracks.dm"
#include "performance_cleanup_visuals.dm"
#include "pollution_processing.dm"
#include "qdel_report.dm"
#include "reagent_id_typos.dm"
#include "reagent_recipe_collisions.dm"
#include "reported_bugs.dm"
#include "respawn_burial.dm"
#include "respawn_bypass.dm"
#include "respawn_lifecycle.dm"
#include "round_statistics.dm"
#include "runtime_combat.dm"
#include "runtime_interfaces.dm"
#include "runtime_lifecycle.dm"
#include "runtime_misc.dm"
#include "runtime_mobs.dm"
#include "runtime_nov03_goblin.dm"
#include "runtime_nov03_harddels.dm"
#include "runtime_nov03_misc.dm"
#include "runtime_nov03_rituals.dm"
#include "runtime_nov03_spells.dm"
#include "runtime_nov03_tracks.dm"
#include "runtime_nov05_combat.dm"
#include "runtime_nov05_inventory.dm"
#include "runtime_nov05_lifecycle.dm"
#include "runtime_nov05_ui.dm"
#include "runtime_nov06_cleanup_clan.dm"
#include "runtime_nov06_cleanup_pets.dm"
#include "runtime_nov06_cleanup_spells.dm"
#include "runtime_nov06_crafting_speech.dm"
#include "runtime_nov06_lifecycle.dm"
#include "runtime_nov06_mobs.dm"
#include "runtime_nov06_ui.dm"
#include "runtime_nov07_combat.dm"
#include "runtime_nov07_intents.dm"
#include "runtime_nov07_lighting.dm"
#include "runtime_nov07_misc.dm"
#include "runtime_nov07_misc_guards.dm"
#include "runtime_nov07_movement.dm"
#include "runtime_nov08_fish.dm"
#include "runtime_nov08_harpy.dm"
#include "runtime_nov08_mail.dm"
#include "runtime_nov08_stats.dm"
#include "runtime_rounds_1486.dm"
#include "rural_income.dm"
#include "scabbard_sprites.dm"
#include "soundloop_scheduling.dm"
#include "spacevine_cleanup.dm"
#include "spark_retention.dm"
#include "spawn_humans.dm"
#include "species_whitelists.dm"
#include "speech_mannerisms.dm"
#include "subsystem_init.dm"
#include "tgui_assets.dm"
#include "timer_sanity.dm"
#include "timers.dm"
#include "unit_test.dm"
#include "upstream_nov07_admin.dm"
#include "upstream_nov07_forcing.dm"
#include "upstream_nov07_structures.dm"
// END_INCLUDE
// #ifdef REFERENCE_TRACKING_DEBUG //Don't try and parse this file if ref tracking isn't turned on. IE: don't parse ref tracking please mr linter
// #include "find_reference_sanity.dm"
// #endif

#undef TEST_ASSERT
#undef TEST_ASSERT_EQUAL
#undef TEST_ASSERT_NOTEQUAL
//#undef TEST_FOCUS - This define is used by vscode unit test extension to pick specific unit tests to run and appended later so needs to be used out of scope here
#endif
