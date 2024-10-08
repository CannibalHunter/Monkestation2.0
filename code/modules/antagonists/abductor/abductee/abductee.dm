/**
 * ## Abductees
 *
 * Abductees are created by being operated on by abductors. They get some instructions about not
 * remembering the abduction, plus some random weird objectives for them to act crazy with.
 */
/datum/antagonist/abductee
	name = "\improper Abductee"
	roundend_category = "abductees"
	antagpanel_category = ANTAG_GROUP_ABDUCTORS
	antag_hud_name = "abductee"
	count_against_dynamic_roll_chance = FALSE // monkestation edit

/datum/antagonist/abductee/on_gain()
	give_objective()
	. = ..()

/datum/antagonist/abductee/greet()
	to_chat(owner, span_warning("<b>Your mind snaps!</b>"))
	to_chat(owner, "<big>[span_warning("<b>You will not remember being on the alien ship at all. You will not remember the aliens at all.</b>")]</big>")
	owner.announce_objectives()

/datum/antagonist/abductee/proc/give_objective()
	var/objtype = (prob(75) ? /datum/objective/abductee/random : pick(subtypesof(/datum/objective/abductee/) - /datum/objective/abductee/random))
	var/datum/objective/abductee/objective = new objtype()
	objectives += objective
