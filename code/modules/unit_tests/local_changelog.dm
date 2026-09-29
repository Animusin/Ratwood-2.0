/datum/unit_test/local_changelog/Run()
	var/root = "tmp/changelog_test_[md5(REF(src))]/"
	var/archive_file = "[root]archive/2026-09.yml"
	var/local_file = "[root]local/2026-09.yml"
	var/local_only_file = "[root]local/2026-10.yml"
	var/invalid_file = "[root]local/2026-13.yml"
	text2file("upstream", archive_file)
	text2file("local", local_file)
	text2file("local-only", local_only_file)
	text2file("invalid month", invalid_file)
	var/list/sources = changelog_sources(root)
	TEST_ASSERT_EQUAL(length(sources), 2, "Only valid month filenames should appear; local-only months remain visible.")
	var/list/september = sources["2026-09"]
	TEST_ASSERT_EQUAL(length(september), 2, "Upstream and local sources must both be sent for a shared month.")
	TEST_ASSERT_EQUAL(september["2026-09.yml"], archive_file, "Keep the standard archive asset name.")
	TEST_ASSERT_EQUAL(september["local-2026-09.yml"], local_file, "Local files need a separate asset name.")
	TEST_ASSERT_EQUAL(length(sources["2026-10"]), 1, "Local-only months do not request a missing upstream file.")
	var/first_hash = changelog_month_hash(root, "2026-09")
	text2file("another local entry", local_file)
	TEST_ASSERT(first_hash != changelog_month_hash(root, "2026-09"), "Local changes must mark the changelog unread.")
	fdel(local_file)
	TEST_ASSERT_EQUAL(changelog_month_hash(root, "2026-09"), md5(file(archive_file)), "Months without local files retain the original changelog hash.")
	TEST_ASSERT_EQUAL(changelog_month_hash(root, "2026-11"), 0, "A missing month has no changelog hash.")
	fdel(archive_file)
	fdel(local_only_file)
	fdel(invalid_file)

	var/datum/changelog/changelog = new
	allocated += changelog
	var/list/data = changelog.ui_static_data()
	var/list/months = data["month_files"]
	TEST_ASSERT("2026-09" in data["dates"], "The September month must remain available in the real game window.")
	TEST_ASSERT_EQUAL(length(months["2026-09"]), 2, "The real September archive includes the persistent addition.")
	var/datum/asset/changelog_item/assets = new("2026-09")
	allocated += assets
	var/list/mappings = assets.get_url_mappings()
	TEST_ASSERT(mappings["2026-09.yml"], "The upstream archive must have an asset URL.")
	TEST_ASSERT(mappings["local-2026-09.yml"], "The local archive must have an asset URL.")
