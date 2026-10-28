/mob/living/carbon/human/verb/fellowship_verb()
	set name = "Fellowship"
	set category = "IC"
	set desc = "Manage your fellowship."
	if(!ishuman(src) || QDELETED(src) || !client)
		return
	var/datum/fellowship_ui/ui = new(src)
	ui.ui_interact(src)
