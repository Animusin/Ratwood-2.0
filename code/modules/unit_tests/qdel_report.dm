/// Reports must retain every type, respect the existing ordering and leave live counters untouched.
/datum/unit_test/qdel_report_snapshot/Run()
	var/datum/qdel_report/report = new
	allocated += report
	var/list/items = list()
	for(var/index in 1 to 257)
		var/path = "/test/type_[index]"
		var/datum/qdel_item/item = new(path)
		allocated += item
		item.hard_delete_time = index % 7
		item.destroy_time = index % 11
		item.failures = index % 3
		item.qdels = index
		items[path] = item
	var/list/original = items.Copy()
	var/list/expected = items.Copy()
	sortTim(expected, cmp = /proc/cmp_qdel_item_time, associative = TRUE)
	report.build(items)
	TEST_ASSERT_EQUAL(length(report.rows), length(items), "The snapshot must retain all types, including types with no failures.")
	for(var/index in 1 to items.len)
		TEST_ASSERT_EQUAL(items[index], original[index], "Viewing a report must not sort the live garbage statistics.")
		var/list/row = report.rows[index]
		TEST_ASSERT_EQUAL(row["path"], expected[index], "The snapshot must use the existing hard-delete, Destroy, failure and count ordering.")
	var/datum/qdel_item/first = items[expected[1]]
	var/list/first_row = report.rows[1]
	var/saved_count = first.qdels
	first.qdels += 100
	TEST_ASSERT_EQUAL(first_row["qdels"], saved_count, "Later garbage activity must not mutate a page's snapshot.")
	var/all_pages = "[report.page_html(1)][report.page_html(2)][report.page_html(3)]"
	for(var/path in items)
		TEST_ASSERT_EQUAL(length(splittext(all_pages, "<u>[path]</u>")), 2, "Each type must appear on exactly one page.")
	TEST_ASSERT_EQUAL(length(splittext(report.page_html(1), "<li><u>")), 101, "The first page must contain only 100 types.")
	TEST_ASSERT_EQUAL(length(splittext(report.page_html(3), "<li><u>")), 58, "The final partial page must remain accessible.")
	TEST_ASSERT_EQUAL(report.page_html(0), report.page_html(1), "A page below the range must clamp to the first page.")
	TEST_ASSERT_EQUAL(report.page_html(999), report.page_html(3), "A page above the range must clamp to the last page.")

/datum/unit_test/qdel_report_empty/Run()
	var/datum/qdel_report/report = new
	allocated += report
	report.build(list())
	var/html = report.page_html()
	TEST_ASSERT(findtext(html, "0 types. Page 1 of 1."), "An empty report must show an empty first page.")
	TEST_ASSERT(!findtext(html, "<li><u>"), "An empty report must not index a nonexistent row.")

/// Repeated ties must keep their original order even when an uneven merge has only one side left.
/datum/unit_test/qdel_report_ties/Run()
	var/datum/qdel_report/report = new
	allocated += report
	var/list/items = list()
	for(var/index in 1 to 65)
		var/path = "/test/tie_[index]"
		var/datum/qdel_item/item = new(path)
		allocated += item
		items[path] = item
	report.build(items)
	for(var/index in 1 to items.len)
		var/list/row = report.rows[index]
		TEST_ASSERT_EQUAL(row["path"], items[index], "Equal counters must preserve their original order without dropping tail rows.")
