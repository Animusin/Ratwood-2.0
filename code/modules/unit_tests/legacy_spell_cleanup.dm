/datum/unit_test/legacy_spell_cleanup/Run()
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.mind_initialize()
	delete_spell(character, FALSE)
	delete_spell(character, TRUE)

/datum/unit_test/legacy_spell_cleanup/proc/delete_spell(mob/living/carbon/human/character, give_to_mind)
	var/obj/effect/proc_holder/spell/spell = new /obj/effect/proc_holder/spell/self/choose_riding_virtue_mount
	if(give_to_mind)
		character.mind.AddSpell(spell)
	else
		character.AddSpell(spell)

	var/datum/action/spell_action/action = spell.action
	TEST_ASSERT_EQUAL(action.owner, character, "The spell action must be granted to the character")
	qdel(spell)

	TEST_ASSERT(!(spell in character.mob_spell_list), "The mob spell list retained the deleted spell")
	TEST_ASSERT(!(spell in character.mind.spell_list), "The mind spell list retained the deleted spell")
	TEST_ASSERT(QDELETED(action), "Deleting the spell must delete the action")
	TEST_ASSERT(!(action in character.actions), "The character retained the deleted action")
