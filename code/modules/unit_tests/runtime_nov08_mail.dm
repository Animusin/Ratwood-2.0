/datum/unit_test/runtime_nov08_inquisition_mail
	var/obj/structure/roguemachine/mail/machine
	var/mob/living/carbon/human/consistent/officer
	var/mob/living/carbon/human/consistent/subject
	var/list/previous_indexed
	var/list/previous_accused
	var/list/previous_confessors
	var/list/previous_cursedsamples
	var/previous_marques_made

/datum/unit_test/runtime_nov08_inquisition_mail/Destroy()
	if(previous_indexed)
		GLOB.indexed = previous_indexed
		GLOB.accused = previous_accused
		GLOB.confessors = previous_confessors
		GLOB.cursedsamples = previous_cursedsamples
		GLOB.azure_round_stats[STATS_MARQUES_MADE] = previous_marques_made
	machine = null
	officer = null
	subject = null
	return ..()

/datum/unit_test/runtime_nov08_inquisition_mail/proc/prepare_mail()
	previous_indexed = GLOB.indexed
	previous_accused = GLOB.accused
	previous_confessors = GLOB.confessors
	previous_cursedsamples = GLOB.cursedsamples
	previous_marques_made = GLOB.azure_round_stats[STATS_MARQUES_MADE]
	GLOB.indexed = list()
	GLOB.accused = list()
	GLOB.confessors = list()
	GLOB.cursedsamples = list()
	machine = allocate(/obj/structure/roguemachine/mail)
	officer = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(officer, TRAIT_INQUISITION, "mail_test")
	subject = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(subject, TRAIT_CABAL, "mail_test")

/datum/unit_test/runtime_nov08_inquisition_mail/proc/marques_paid()
	. = 0
	for(var/obj/item/roguecoin/inqcoin/coin in officer.contents)
		. += coin.quantity
	for(var/obj/item/roguecoin/inqcoin/coin in get_turf(officer))
		. += coin.quantity

/// A full INDEXER can still point to a body without a mind. Reject it before updating records or paying out.
/datum/unit_test/runtime_nov08_inquisition_mail/Run()
	prepare_mail()
	TEST_ASSERT_NULL(subject.mind, "The accusation fixture must reproduce a subject without a mind.")
	var/obj/item/paper/inqslip/accusation/slip = allocate(/obj/item/paper/inqslip/accusation)
	var/obj/item/inqarticles/indexer/sample = allocate(/obj/item/inqarticles/indexer)
	slip.signee = officer
	slip.signed = TRUE
	slip.paired = sample
	sample.subject = subject
	sample.full = TRUE
	var/runtimes_before = GLOB.total_runtimes
	for(var/attempt in 1 to 3)
		machine.attackby(slip, officer)
	TEST_ASSERT(!QDELETED(slip) && !QDELETED(sample), "An unidentifiable accusation must preserve both the paper and sample.")
	TEST_ASSERT_EQUAL(marques_paid(), 0, "An unidentifiable sample must not bypass reward deduplication.")
	TEST_ASSERT_EQUAL(length(GLOB.indexed) + length(GLOB.accused) + length(GLOB.cursedsamples), 0, "An invalid accusation must not partially update Inquisition records.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Repeated submission of a mindless subject must not runtime.")

	subject.mind_initialize()
	allocated += subject.mind
	machine.attackby(slip, officer)
	TEST_ASSERT(QDELETED(slip) && QDELETED(sample), "A valid signed accusation must consume its paper and sample.")
	TEST_ASSERT(HAS_TRAIT(subject.mind, TRAIT_INDEXED) && HAS_TRAIT(subject.mind, TRAIT_ACCUSED), "A valid accusation must retain its per-mind deduplication records.")
	TEST_ASSERT_EQUAL(marques_paid(), 6, "A first valid heretic accusation must still award its four Marques plus indexing bonus.")

	var/obj/item/paper/inqslip/accusation/repeated_slip = allocate(/obj/item/paper/inqslip/accusation)
	var/obj/item/inqarticles/indexer/repeated_sample = allocate(/obj/item/inqarticles/indexer)
	repeated_slip.signee = officer
	repeated_slip.signed = TRUE
	repeated_slip.paired = repeated_sample
	repeated_sample.subject = subject
	repeated_sample.full = TRUE
	machine.attackby(repeated_slip, officer)
	TEST_ASSERT(QDELETED(repeated_slip) && QDELETED(repeated_sample), "An already recorded accusation must retain its normal duplicate handling.")
	TEST_ASSERT_EQUAL(marques_paid(), 6, "Submitting the same subject again must not pay twice.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Valid and duplicate accusation processing must remain free of runtimes.")

/// Confessions use the same mind-based records, including optional blood samples.
/datum/unit_test/runtime_nov08_inquisition_mail/confession/Run()
	prepare_mail()
	var/obj/item/paper/inqslip/confession/slip = allocate(/obj/item/paper/inqslip/confession)
	slip.signee = subject
	slip.signed = TRUE
	var/runtimes_before = GLOB.total_runtimes
	machine.attackby(slip, officer)
	TEST_ASSERT(!QDELETED(slip), "A confession with no identifiable signee must not be consumed.")
	TEST_ASSERT_EQUAL(marques_paid(), 0, "A mindless signee must not receive an untracked reward.")
	TEST_ASSERT_EQUAL(length(GLOB.confessors), 0, "An invalid signee must not alter confession records.")

	subject.mind_initialize()
	allocated += subject.mind
	var/obj/item/inqarticles/indexer/sample = allocate(/obj/item/inqarticles/indexer)
	slip.paired = sample
	sample.full = TRUE
	machine.attackby(slip, officer)
	TEST_ASSERT(!QDELETED(slip) && !QDELETED(sample), "A confession with a lost sample subject must preserve its evidence.")
	TEST_ASSERT_EQUAL(marques_paid(), 0, "A lost sample subject must not yield a partial reward.")
	TEST_ASSERT_EQUAL(length(GLOB.confessors), 0, "A rejected sample must not prematurely mark its signee as confessed.")

	sample.subject = subject
	machine.attackby(slip, officer)
	TEST_ASSERT(QDELETED(slip) && QDELETED(sample), "A corrected confession and valid sample must be accepted normally.")
	TEST_ASSERT(HAS_TRAIT(subject.mind, TRAIT_CONFESSED) && HAS_TRAIT(subject.mind, TRAIT_INDEXED), "A valid confession must still update both confession and sample records.")
	TEST_ASSERT_EQUAL(marques_paid(), 8, "A valid heretic confession must retain its six Marques plus indexing bonus.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "Missing and restored confession identities must not cause runtimes.")
