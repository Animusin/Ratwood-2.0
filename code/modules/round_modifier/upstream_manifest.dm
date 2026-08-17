/// Explicit review gate for upstream RoundMods. Entries are classifications, never an automatic pool.
/proc/get_ratwood_upstream_round_modifier_manifest()
	return list(
		/datum/round_modifier/adventure = "ignored",
		/datum/round_modifier/nowretch = "ignored",
		/datum/round_modifier/lesswretch = "ignored",
		/datum/round_modifier/low_bandits = "ignored",
		/datum/round_modifier/medium_bandits = "ignored",
		/datum/round_modifier/high_bandits = "ignored",
		/datum/round_modifier/low_gnolls = "ignored",
		/datum/round_modifier/medium_gnolls = "ignored",
		/datum/round_modifier/high_gnolls = "ignored",
		/datum/round_modifier/high_wretches = "ignored",
		/datum/round_modifier/vampire = "ignored",
		/datum/round_modifier/vampirelord = "ignored",
		/datum/round_modifier/assassin = "ignored",
		/datum/round_modifier/rebel = "ignored",
		/datum/round_modifier/dreamwalker = "ignored",
		/datum/round_modifier/clear = "inherited",
		/datum/round_modifier/fog = "inherited",
		/datum/round_modifier/stormy = "inherited",
	)

/// Explicit review gate for upstream solo-antagonist event controls.
/proc/get_ratwood_upstream_solo_event_manifest()
	return list(
		/datum/round_event_control/antagonist/solo/from_ghosts = "ignored",
		/datum/round_event_control/antagonist/solo/assassins = "wrapped",
		/datum/round_event_control/antagonist/solo/bandits = "ignored",
		/datum/round_event_control/antagonist/solo/dreamwalker = "wrapped",
		/datum/round_event_control/antagonist/solo/lich = "wrapped",
		/datum/round_event_control/antagonist/solo/masquerade = "wrapped",
		/datum/round_event_control/antagonist/solo/rebel = "wrapped",
		/datum/round_event_control/antagonist/solo/thievesguild = "ignored",
		/datum/round_event_control/antagonist/solo/vampires = "wrapped",
		/datum/round_event_control/antagonist/solo/vampires_and_werewolves = "ignored",
		/datum/round_event_control/antagonist/solo/werewolf = "wrapped",
		/datum/round_event_control/antagonist/solo/aspirants = "ignored",
	)

/// Review checklist for upstream-derived population formulas and Ratwood-specific balance.
/proc/get_ratwood_solo_event_contracts()
	return list(
		/datum/round_event_control/antagonist/solo/masquerade/ratwood = list("base" = 2, "maximum" = 4, "denominator" = 80, "minimum" = 0, "datum" = /datum/antagonist/vampire/ratwood, "roundstart" = TRUE, "weight" = 2),
		/datum/round_event_control/antagonist/solo/rebel/ratwood = list("base" = 1, "maximum" = 3, "denominator" = 50, "minimum" = 0, "datum" = /datum/antagonist/prebel/head/ratwood, "roundstart" = TRUE, "weight" = 2),
		/datum/round_event_control/antagonist/solo/dreamwalker/ratwood = list("base" = 1, "maximum" = 2, "denominator" = 80, "minimum" = 40, "datum" = /datum/antagonist/dreamwalker/ratwood, "roundstart" = TRUE, "weight" = 2),
		/datum/round_event_control/antagonist/solo/assassins/ratwood = list("base" = 2, "maximum" = 2, "denominator" = 20, "minimum" = 0, "datum" = /datum/antagonist/assassin/ratwood, "roundstart" = TRUE, "weight" = 0.5),
		/datum/round_event_control/antagonist/solo/vampires/ratwood = list("base" = 1, "maximum" = 2, "denominator" = 80, "minimum" = 0, "datum" = /datum/antagonist/vampire/ratwood, "roundstart" = TRUE, "weight" = 3),
		/datum/round_event_control/antagonist/solo/werewolf/ratwood = list("base" = 1, "maximum" = 2, "denominator" = 50, "minimum" = 25, "datum" = /datum/antagonist/werewolf/ratwood, "roundstart" = TRUE, "weight" = 2),
		/datum/round_event_control/antagonist/solo/lich/ratwood = list("base" = 1, "maximum" = 2, "denominator" = 80, "minimum" = 0, "datum" = /datum/antagonist/lich/ratwood, "roundstart" = TRUE, "weight" = 2),
	)
