/// Gas tank air sensor.
/// These always hook to monitors, be mindful of them
/obj/machinery/air_sensor
	name = "gas sensor"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "gsensor1"
	resistance_flags = FIRE_PROOF
	power_channel = AREA_USAGE_ENVIRON
	active_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 1.5
	var/on = TRUE

	/// The unique string that represents which atmos chamber to associate with.
	var/chamber_id
	/// The inlet[injector] controlled by this sensor
	var/inlet_id
	/// The outlet[vent pump] controlled by this sensor
	var/outlet_id

/obj/machinery/air_sensor/Initialize(mapload)
	id_tag = assign_random_name()

	//this global list of air sensors is available to all station monitering consoles round start and to new consoles made during the round
	if(mapload)
		GLOB.map_loaded_sensors[chamber_id] = id_tag
		inlet_id = CHAMBER_INPUT_FROM_ID(chamber_id)
		outlet_id = CHAMBER_OUTPUT_FROM_ID(chamber_id)

	var/static/list/multitool_tips = list(
		TOOL_MULTITOOL = list(
			SCREENTIP_CONTEXT_LMB = "Link logged injectors/vents",
			SCREENTIP_CONTEXT_RMB = "Reset all I/O ports",
		)
	)
	AddElement(/datum/element/contextual_screentip_tools, multitool_tips)

	return ..()

/obj/machinery/air_sensor/Destroy()
	reset()
	return ..()

/obj/machinery/air_sensor/return_air()
	if(!on)
		return
	. = ..()
	use_power(active_power_usage) //use power for analyzing gases

/obj/machinery/air_sensor/process()
	//update appearance according to power state
	if(machine_stat & NOPOWER)
		if(on)
			on = FALSE
			update_appearance()
	else if(!on)
		on = TRUE
		update_appearance()

/obj/machinery/air_sensor/examine(mob/user)
	. = ..()
	. += span_notice("Use multitool to link it to an injector/vent or reset it's ports")
	. += span_notice("Click with hand to turn it off.")

/obj/machinery/air_sensor/attack_hand(mob/living/user, list/modifiers)
	. = ..()

	//switched off version of this air sensor but still anchored to the ground
	var/obj/item/air_sensor/sensor = new(drop_location(), inlet_id, outlet_id)
	sensor.set_anchored(TRUE)
	sensor.balloon_alert(user, "sensor turned off")

	//delete self
	qdel(src)

/obj/machinery/air_sensor/update_icon_state()
	icon_state = "gsensor[on]"
	return ..()

/obj/machinery/air_sensor/proc/reset()
	inlet_id = null
	outlet_id = null

///right click with multi tool to disconnect everything
/obj/machinery/air_sensor/multitool_act_secondary(mob/living/user, obj/item/tool)
	balloon_alert(user, "reset ports")
	reset()
	return TRUE

/obj/machinery/air_sensor/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	. = ..()

	if(istype(multi_tool.buffer, /obj/machinery/atmospherics/components/unary/outlet_injector))
		var/obj/machinery/atmospherics/components/unary/outlet_injector/input = multi_tool.buffer
		inlet_id = input.id_tag
		multi_tool.set_buffer(null)
		balloon_alert(user, "connected to input")

	else if(istype(multi_tool.buffer, /obj/machinery/atmospherics/components/unary/vent_pump))
		var/obj/machinery/atmospherics/components/unary/vent_pump/output = multi_tool.buffer
		//so its no longer controlled by air alarm
		output.disconnect_from_area()
		//configuration copied from /obj/machinery/atmospherics/components/unary/vent_pump/siphon
		output.pump_direction = ATMOS_DIRECTION_SIPHONING
		output.pressure_checks = ATMOS_INTERNAL_BOUND
		output.internal_pressure_bound = 4000
		output.external_pressure_bound = 0
		//finally assign it to this sensor
		outlet_id = output.id_tag
		multi_tool.set_buffer(null)
		balloon_alert(user, "connected to output")

	else
		multi_tool.set_buffer(src)
		balloon_alert(user, "added to multitool buffer")

	return TRUE

/**
 * A portable version of the /obj/machinery/air_sensor
 * Wrenching it & turning it on will convert it back to /obj/machinery/air_sensor
 * Unwelding /obj/machinery/air_sensor will turn it back to /obj/item/air_sensor
 * The logic is same as meters
 */
/obj/item/air_sensor
	name = "Air Sensor"
	desc = "A device designed to detect gases and their concentration in an area."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "gsensor0"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT, /datum/material/glass = SMALL_MATERIAL_AMOUNT) // MONKESTATION EDIT CHANGE OLD // REQUIRES PR #75052

	/// The injector linked with this sensor
	var/input_id
	/// The vent pump linked with this sensor
	var/output_id

/obj/item/air_sensor/Initialize(mapload, inlet, outlet)
	. = ..()
	register_context()
	input_id = inlet
	output_id = outlet

/obj/item/air_sensor/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	if(isnull(held_item))
		return NONE

	if(held_item.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_LMB] = anchored ? "Unwrench" : "Wrench"
		return CONTEXTUAL_SCREENTIP_SET

	if(held_item.tool_behaviour == TOOL_WELDER && !anchored)
		context[SCREENTIP_CONTEXT_LMB] = "Dismantle"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/obj/item/air_sensor/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_notice("It's [EXAMINE_HINT("wrenched")] in place")
	else
		. += span_notice("It should be [EXAMINE_HINT("wrenched")] in place to turn it on.")
	. +=  span_notice("It could be [EXAMINE_HINT("welded")] apart.")
	. +=  span_notice("Click with hand to turn it on.")

/obj/item/air_sensor/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(!anchored)
		return

	//List of air sensor's by name
	var/list/available_sensors = list()
	for(var/chamber_id in GLOB.station_gas_chambers)
		//don't let it conflict with existing distro & waste moniter meter's
		if(chamber_id == ATMOS_GAS_MONITOR_DISTRO)
			continue
		if(chamber_id == ATMOS_GAS_MONITOR_WASTE)
			continue
		available_sensors += GLOB.station_gas_chambers[chamber_id]

	//make the choice
	var/chamber_name = tgui_input_list(user, "Select Sensor Purpose", "Select Sensor ID", available_sensors)
	if(isnull(chamber_name))
		return

	//map chamber name back to id
	var/target_chamber
	for(var/chamber_id in GLOB.station_gas_chambers)
		if(GLOB.station_gas_chambers[chamber_id] != chamber_name)
			continue
		target_chamber = chamber_id
		break

	//build the sensor from the subtypes of sensor's available
	var/static/list/chamber_subtypes = null
	if(isnull(chamber_subtypes))
		chamber_subtypes = subtypesof(/obj/machinery/air_sensor)
	for(var/obj/machinery/air_sensor/sensor as anything in chamber_subtypes)
		if(initial(sensor.chamber_id) != target_chamber)
			continue

		//make real air sensor in it's place
		var/obj/machinery/air_sensor/new_sensor = new sensor(get_turf(src))
		new_sensor.inlet_id = input_id
		new_sensor.outlet_id = output_id
		new_sensor.balloon_alert(user, "sensor turned on")
		qdel(src)

		break

/obj/item/air_sensor/wrench_act(mob/living/user, obj/item/tool)
	if(default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN)
		return TOOL_ACT_TOOLTYPE_SUCCESS
	return

/obj/item/air_sensor/welder_act(mob/living/user, obj/item/tool)
	if(!tool.tool_start_check(user, amount = 1))
		return

	loc.balloon_alert(user, "dismantling sensor")
	if(!tool.use_tool(src, user, 2 SECONDS, volume = 30, amount = 1))
		return
	loc.balloon_alert(user, "sensor dismanteled")

	deconstruct(TRUE)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/item/air_sensor/deconstruct(disassembled)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/analyzer(loc)
		new /obj/item/stack/sheet/iron(loc, 1)
	return ..()
