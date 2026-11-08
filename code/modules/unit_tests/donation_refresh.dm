/// Exercise the real read/retry/decode path without connecting to, or writing to, a donations database.
/datum/controller/subsystem/donations/refresh_test
	name = "Donation refresh test fixture"
	flags = SS_NO_INIT | SS_NO_FIRE
	can_fire = FALSE
	var/list/replies = list()
	var/list/queries = list()
	var/list/query_arguments = list()

/datum/controller/subsystem/donations/refresh_test/New()
	// Do not invoke the singleton constructor: a test must never replace the live SSdonations.
	return

/datum/controller/subsystem/donations/refresh_test/query(sql, list/arguments, async = TRUE, log_error = TRUE)
	queries += sql
	query_arguments += list(arguments?.Copy())
	if(!length(replies))
		return null
	var/list/result = replies[1]
	replies.Cut(1, 2)
	return result

/datum/controller/subsystem/donations/refresh_test/proc/queue_account(tier, balance)
	replies += list(list("rows" = list(list(tier, balance))))

/// A normal periodic refresh reads tier and balance together and performs no INSERT.
/datum/unit_test/donation_refresh_existing/Run()
	var/datum/controller/subsystem/donations/original_backend = SSdonations
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.queue_account("HOS", "125")
	var/list/info = backend.get_donation_info("donationtest")
	TEST_ASSERT_EQUAL(SSdonations, original_backend, "The test backend must not replace the live singleton.")
	TEST_ASSERT_NOTNULL(info, "An existing account must produce a usable snapshot.")
	TEST_ASSERT_EQUAL(info["tier"], "hos", "Refresh must normalize the subscription tier.")
	TEST_ASSERT_EQUAL(info["opyxes"], 125, "Refresh must decode the balance from the same row.")
	TEST_ASSERT_EQUAL(length(backend.queries), 1, "An existing account must need only one query per refresh.")
	var/list/arguments = backend.query_arguments[1]
	TEST_ASSERT_EQUAL(arguments["ckey"], "donationtest", "The account key must remain a bound SQL parameter.")

/// Every refresh reads fresh data, including external downgrades, spending, and a linked account's new tier.
/datum/unit_test/donation_refresh_fresh_snapshot/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.queue_account("hos", "125")
	backend.queue_account("scientist", "100")
	backend.queue_account(null, "0")
	backend.queue_account("captain", 0)
	var/list/first = backend.get_donation_info("donationtest")
	var/list/downgraded = backend.get_donation_info("donationtest")
	var/list/expired = backend.get_donation_info("donationtest")
	var/list/relinked = backend.get_donation_info("donationtest")
	TEST_ASSERT_EQUAL(first?["opyxes"], 125, "The first snapshot must retain its original balance.")
	TEST_ASSERT_EQUAL(downgraded?["tier"], "scientist", "An external downgrade must not reuse an old entitlement.")
	TEST_ASSERT_EQUAL(downgraded?["opyxes"], 100, "Spending must be visible at the next refresh.")
	TEST_ASSERT_EQUAL(expired?["tier"], "none", "A NULL tier must become the normal unsubscribed tier.")
	TEST_ASSERT_EQUAL(expired?["opyxes"], 0, "An empty account must retain a zero balance.")
	TEST_ASSERT_EQUAL(relinked?["tier"], "captain", "Relinking the ckey must read the currently linked record.")
	TEST_ASSERT_EQUAL(relinked?["opyxes"], 0, "Numeric zero must decode as a valid balance.")
	TEST_ASSERT_EQUAL(length(backend.queries), 4, "Four ordinary refreshes must issue four queries, with no account-ID cache.")

/// Missing accounts are created once, then read back instead of assuming a zero balance or tier.
/datum/unit_test/donation_refresh_missing_account/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.replies += list(list("rows" = list()))
	backend.replies += list(list("affected" = "1"))
	backend.queue_account("hos", "50")
	var/list/info = backend.get_donation_info("donationtest")
	TEST_ASSERT_EQUAL(length(backend.queries), 3, "Only a missing account may require SELECT, INSERT IGNORE, and a retry.")
	TEST_ASSERT_EQUAL(info?["tier"], "hos", "The retry must observe a concurrently linked subscription.")
	TEST_ASSERT_EQUAL(info?["opyxes"], 50, "The retry must observe a concurrently credited balance.")
	for(var/list/arguments as anything in backend.query_arguments)
		TEST_ASSERT_EQUAL(arguments["ckey"], "donationtest", "Creation and retry must use the original account key.")

/// A failed read must not be mistaken for a missing player and trigger a write.
/datum/unit_test/donation_refresh_failed_read/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.replies += list(null)
	var/list/info = backend.get_donation_info("donationtest")
	TEST_ASSERT_NULL(info, "A database error must not produce a successful or zero-valued snapshot.")
	TEST_ASSERT_EQUAL(length(backend.queries), 1, "A failed SELECT must not attempt INSERT IGNORE.")
	backend.queue_account("hos", "75")
	info = backend.get_donation_info("donationtest")
	TEST_ASSERT_EQUAL(info?["opyxes"], 75, "The next refresh must recover after the database becomes available.")
	TEST_ASSERT_EQUAL(length(backend.queries), 2, "Recovery must use one fresh SELECT.")

/// Failure to create a missing record must stop before another read.
/datum/unit_test/donation_refresh_failed_creation/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.replies += list(list("rows" = list()))
	backend.replies += list(null)
	var/list/info = backend.get_donation_info("donationtest")
	TEST_ASSERT_NULL(info, "A failed creation must keep donation information unavailable.")
	TEST_ASSERT_EQUAL(length(backend.queries), 2, "Failed creation must not continue to a third query.")

/// A failed or still-missing retry is not a successful unsubscribed account.
/datum/unit_test/donation_refresh_failed_retry/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.replies += list(list("rows" = list()))
	backend.replies += list(list("affected" = "0"))
	backend.replies += list(null)
	var/list/failed_read = backend.get_donation_info("donationtest")
	backend.replies += list(list("rows" = list()))
	backend.replies += list(list("affected" = "0"))
	backend.replies += list(list("rows" = list()))
	var/list/still_missing = backend.get_donation_info("donationtest")
	TEST_ASSERT_NULL(failed_read, "An error reading the created record must not claim loaded donation information.")
	TEST_ASSERT_NULL(still_missing, "A record still missing after INSERT IGNORE must remain unavailable.")
	TEST_ASSERT_EQUAL(length(backend.queries), 6, "Each missing account attempt must have a bounded single retry.")

/// An invalid payload must fail without overwriting client data with guessed entitlements or balances.
/datum/unit_test/donation_refresh_invalid_row/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	backend.replies += list(list("rows" = list(list("hos"))))
	backend.queue_account("hos", "not a balance")
	var/list/incomplete = backend.get_donation_info("donationtest")
	var/list/invalid_balance = backend.get_donation_info("donationtest")
	TEST_ASSERT_NULL(incomplete, "An incomplete row must not produce a successful snapshot.")
	TEST_ASSERT_NULL(invalid_balance, "An invalid balance must not silently become zero.")
	TEST_ASSERT_EQUAL(length(backend.queries), 2, "Malformed rows must not cause record creation or retry loops.")

/// Missing keys and disconnected callers must be rejected without querying the database.
/datum/unit_test/donation_refresh_missing_client/Run()
	var/datum/controller/subsystem/donations/refresh_test/backend = allocate(/datum/controller/subsystem/donations/refresh_test)
	TEST_ASSERT_NULL(backend.get_donation_info(null), "A missing ckey must not produce donation data.")
	TEST_ASSERT(!backend.update_client(null), "A disconnected client must not be refreshed.")
	TEST_ASSERT_EQUAL(length(backend.queries), 0, "Invalid or disconnected callers must perform no database work.")
