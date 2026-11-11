/// Keeping the savefile open must not change what a save puts on disk or what a load reads back.
/datum/unit_test/preferences_held_savefile/Run()
	var/datum/preferences/prefs = new
	allocated += prefs
	var/path = "data/unit_test_held_prefs_[rand(1, 999999)].sav"
	var/copy = "[path].copy"
	fdel(path)
	prefs.path = path
	prefs.default_slot = 1
	TEST_ASSERT(prefs.save_preferences(), "Saving preferences to a new file failed.")
	TEST_ASSERT(prefs.save_character(), "Saving a character to a new file failed.")
	TEST_ASSERT(isnull(prefs.held_savefile), "Preferences without a connected client must not keep their file open.")

	prefs.hold_savefile(require_client = FALSE)
	TEST_ASSERT(!isnull(prefs.held_savefile), "An existing savefile must be held on request.")
	prefs.asaycolor = "#12ab34"
	prefs.real_name = "Held Savefile Probe"
	TEST_ASSERT(prefs.save_preferences(), "Saving preferences through a held file failed.")
	TEST_ASSERT(prefs.save_character(), "Saving a character through a held file failed.")

	// Read a copy of the file so the object that is being held cannot answer for the disk.
	fcopy(path, copy)
	var/savefile/on_disk = new /savefile(copy)
	var/saved_colour
	var/saved_name
	on_disk.cd = "/"
	on_disk["asaycolor"] >> saved_colour
	on_disk.cd = "/character1"
	on_disk["real_name"] >> saved_name
	on_disk = null
	TEST_ASSERT_EQUAL(saved_colour, "#12ab34", "A preference saved through a held file must be on disk.")
	TEST_ASSERT_EQUAL(saved_name, "Held Savefile Probe", "A character saved through a held file must be on disk.")

	prefs.real_name = "Changed In Memory"
	TEST_ASSERT(prefs.load_character(1), "Loading a character through a held file failed.")
	TEST_ASSERT_EQUAL(prefs.real_name, "Held Savefile Probe", "A load through a held file must read what was saved.")

	prefs.release_savefile()
	TEST_ASSERT(isnull(prefs.held_savefile), "Releasing must drop the held file.")
	fdel(copy)
	fdel(path)
