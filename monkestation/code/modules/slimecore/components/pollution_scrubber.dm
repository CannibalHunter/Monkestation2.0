/datum/component/pollution_scrubber
	///the amount we try to scrub each process
	var/scrubbing_amount
	///the lifetime if set it will delete itself after this point
	var/lifetime

/datum/component/pollution_scrubber/Initialize(scrubbing_amount, lifetime)
	. = ..()
	src.scrubbing_amount = scrubbing_amount
	src.lifetime = lifetime

	if(lifetime)
		QDEL_IN(src, lifetime)
	START_PROCESSING(SSobj, src)

/datum/component/pollution_scrubber/Destroy(force)
	STOP_PROCESSING(SSobj, src)
	return ..()

/datum/component/pollution_scrubber/process(seconds_per_tick)
	if(isliving(parent))
		var/mob/living/living = parent
		if(living.stat == DEAD)
			return

	var/turf/open/turf = get_turf(parent)
	turf.pollution?.scrub_amount(scrubbing_amount)
