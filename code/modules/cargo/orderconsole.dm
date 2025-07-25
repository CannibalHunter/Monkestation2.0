/obj/machinery/computer/cargo
	name = "supply console"
	desc = "Used to order supplies, approve requests, and control the shuttle."
	icon_screen = "supply"
	circuit = /obj/item/circuitboard/computer/cargo
	light_color = COLOR_BRIGHT_ORANGE

	///Can the supply console send the shuttle back and forth? Used in the UI backend.
	var/can_send = TRUE
	///Can this console only send requests?
	var/requestonly = FALSE
	///Can you approve requests placed for cargo? Works differently between the app and the computer.
	var/can_approve_requests = TRUE
	var/contraband = FALSE
	var/self_paid = FALSE
	var/safety_warning = "For safety and ethical reasons, the automated supply shuttle cannot transport live organisms, \
		human remains, classified nuclear weaponry, mail, undelivered departmental order crates, syndicate bombs, \
		homing beacons, unstable eigenstates, fax machines, or machinery housing any form of artificial intelligence."
	var/blockade_warning = "Bluespace instability detected. Shuttle movement impossible."
	/// radio used by the console to send messages on supply channel
	var/obj/item/radio/headset/radio
	/// var that tracks message cooldown
	var/message_cooldown
	var/list/loaded_coupons
	/// var that makes express console use rockets
	var/is_express = FALSE
	///The name of the shuttle template being used as the cargo shuttle. 'cargo' is default and contains critical code. Don't change this unless you know what you're doing.
	var/cargo_shuttle = "cargo"
	///The docking port called when returning to the station.
	var/docking_home = "cargo_home"
	///The docking port called when leaving the station.
	var/docking_away = "cargo_away"
	///If this console can loan the cargo shuttle. Set to false to disable.
	var/stationcargo = TRUE
	///The account this console processes and displays. Independent from the account the shuttle processes.
	var/cargo_account = ACCOUNT_CAR
	///Interface name for the ui_interact call for different subtypes.
	var/interface_type = "Cargo"
	/// are we currently_sending to an ocean point?
	var/currently_sending = FALSE

	///department specific locks
	var/can_send_shuttle = TRUE
	var/can_remove_orders = TRUE

/obj/machinery/computer/cargo/request
	name = "supply request console"
	desc = "Used to request supplies from cargo."
	icon_screen = "request"
	circuit = /obj/item/circuitboard/computer/cargo/request
	can_send = FALSE
	can_approve_requests = FALSE
	requestonly = TRUE

/obj/machinery/computer/cargo/Initialize(mapload)
	. = ..()
	radio = new /obj/item/radio/headset/headset_cargo(src)

/obj/machinery/computer/cargo/Destroy()
	QDEL_NULL(radio)
	return ..()

/obj/machinery/computer/cargo/attacked_by(obj/item/I, mob/living/user)
	if(istype(I,/obj/item/trade_chip))
		var/obj/item/trade_chip/contract = I
		contract.try_to_unlock_contract(user)
		return TRUE
	else
		return ..()

/obj/machinery/computer/cargo/proc/get_export_categories()
	. = EXPORT_CARGO
	if(contraband)
		. |= EXPORT_CONTRABAND
	if(obj_flags & EMAGGED)
		. |= EXPORT_EMAG

/obj/machinery/computer/cargo/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(obj_flags & EMAGGED)
		return FALSE
	if(user)
		if (emag_card)
			user.visible_message(span_warning("[user] swipes [emag_card] through [src]!"))
		to_chat(user, span_notice("You adjust [src]'s routing and receiver spectrum, unlocking special supplies and contraband."))

	obj_flags |= EMAGGED
	contraband = TRUE

	// This also permanently sets this on the circuit board
	var/obj/item/circuitboard/computer/cargo/board = circuit
	board.contraband = TRUE
	board.obj_flags |= EMAGGED
	update_static_data(user)
	return TRUE

/obj/machinery/computer/cargo/on_construction(mob/user)
	. = ..()
	circuit.configure_machine(src)

/obj/machinery/computer/cargo/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, interface_type, name)
		ui.open()

/obj/machinery/computer/cargo/ui_data()
	var/list/data = list()
	data["department"] = "Cargo" // Hardcoded here, for customization in budgetordering.dm AKA NT IRN
	data["location"] = SSshuttle.supply.getStatusText()
	var/datum/bank_account/D = SSeconomy.get_dep_account(cargo_account)
	if(D)
		data["points"] = D.account_balance
	data["grocery"] = SSshuttle.chef_groceries.len
	data["away"] = SSshuttle.supply.getDockedId() == docking_away
	data["self_paid"] = self_paid
	data["docked"] = SSshuttle.supply.mode == SHUTTLE_IDLE
	data["loan"] = !!SSshuttle.shuttle_loan
	data["loan_dispatched"] = SSshuttle.shuttle_loan && SSshuttle.shuttle_loan.dispatched
	data["can_send"] = can_send
	data["can_approve_requests"] = can_approve_requests
	var/message = "Remember to stamp and send back the supply manifests."
	if(SSshuttle.centcom_message)
		message = SSshuttle.centcom_message
	if(SSshuttle.supply_blocked)
		message = blockade_warning
	data["message"] = message

	var/cart_list = list()
	for(var/datum/supply_order/order in SSshuttle.shopping_list)
		if(cart_list[order.pack.name])
			cart_list[order.pack.name][1]["amount"]++
			cart_list[order.pack.name][1]["cost"] += order.get_final_cost()
			if(order.department_destination)
				cart_list[order.pack.name][1]["dep_order"]++
			if(!isnull(order.paying_account))
				cart_list[order.pack.name][1]["paid"]++
			continue

		cart_list[order.pack.name] = list(list(
			"cost_type" = order.cost_type,
			"object" = order.pack.name,
			"cost" = order.get_final_cost(),
			"id" = order.id,
			"amount" = 1,
			"orderer" = order.orderer,
			"paid" = !isnull(order.paying_account) ? 1 : 0, //number of orders purchased privatly
			"dep_order" = order.department_destination ? 1 : 0, //number of orders purchased by a department
			"can_be_cancelled" = order.can_be_cancelled,
		))
	data["cart"] = list()
	for(var/item_id in cart_list)
		data["cart"] += cart_list[item_id]


	data["requests"] = list()
	for(var/datum/supply_order/SO in SSshuttle.request_list)
		data["requests"] += list(list(
			"object" = SO.pack.name,
			"cost" = SO.pack.get_cost(),
			"orderer" = SO.orderer,
			"reason" = SO.reason,
			"id" = SO.id
		))

	return data

/obj/machinery/computer/cargo/ui_static_data(mob/user)
	var/list/data = list()
	data["supplies"] = list()
	for(var/pack in SSshuttle.supply_packs)
		var/datum/supply_pack/P = SSshuttle.supply_packs[pack]
		if(!data["supplies"][P.group])
			data["supplies"][P.group] = list(
				"name" = P.group,
				"packs" = list()
			)
		if((P.hidden && !(obj_flags & EMAGGED)) || (P.contraband && !contraband) || (P.special && !P.special_enabled) || P.drop_pod_only)
			continue
		data["supplies"][P.group]["packs"] += list(list(
			"name" = P.name,
			"cost" = P.get_cost(),
			"id" = pack,
			"desc" = P.desc || P.name, // If there is a description, use it. Otherwise use the pack's name.
			"goody" = P.goody,
			"access" = P.access
		))
	return data

/**
 * adds an supply pack to the checkout cart
 * * params - an list with id of the supply pack to add to the cart as its only element
 */
/obj/machinery/computer/cargo/proc/add_item(params)
	if(is_express)
		return
	var/id = params["id"]
	id = text2path(id) || id
	var/datum/supply_pack/pack = SSshuttle.supply_packs[id]
	if(!istype(pack))
		CRASH("Unknown supply pack id given by order console ui. ID: [params["id"]]")
	if((pack.hidden && !(obj_flags & EMAGGED)) || (pack.contraband && !contraband) || pack.drop_pod_only || (pack.special && !pack.special_enabled))
		return

	var/name = "*None Provided*"
	var/rank = "*None Provided*"
	var/ckey = usr.ckey
	if(ishuman(usr))
		var/mob/living/carbon/human/human = usr
		name = human.get_authentification_name()
		rank = human.get_assignment(hand_first = TRUE)
	else if(issilicon(usr))
		name = usr.real_name
		rank = "Silicon"

	var/datum/bank_account/account
	if(self_paid && isliving(usr))
		var/mob/living/living_user = usr
		var/obj/item/card/id/id_card = living_user.get_idcard(TRUE)
		if(!istype(id_card))
			say("No ID card detected.")
			return
		account = id_card.registered_account
		if(!istype(account))
			say("Invalid bank account.")
			return
		var/list/access = id_card.GetAccess()
		if(pack.access_view && !(pack.access_view in access))
			say("[id_card] lacks the requisite access for this purchase.")
			return

	var/reason = ""
	if(requestonly && !self_paid)
		reason = tgui_input_text(usr, "Reason", name)
		if(isnull(reason))
			return

	if(pack.goody && !self_paid)
		playsound(src, 'sound/machines/buzz-sigh.ogg', 50, FALSE)
		say("ERROR: Small crates may only be purchased by private accounts.")
		return

	var/amount = params["amount"]
	amount = clamp(amount, 0, 100)
	for(var/count in 1 to amount)
		var/obj/item/coupon/applied_coupon
		for(var/obj/item/coupon/coupon_check in loaded_coupons)
			if(pack.type == coupon_check.discounted_pack)
				say("Coupon found! [round(coupon_check.discount_pct_off * 100)]% off applied!")
				coupon_check.moveToNullspace()
				applied_coupon = coupon_check
				break

		var/datum/supply_order/SO = new(pack = pack ,orderer = name, orderer_rank = rank, orderer_ckey = ckey, reason = reason, paying_account = account, coupon = applied_coupon, account_to_charge = params["account_to_charge"])
		if(requestonly && !self_paid)
			SSshuttle.request_list += SO
		else
			SSshuttle.shopping_list += SO

	if(self_paid)
		say("Order processed. The price will be charged to [account.account_holder]'s bank account on delivery.")
	if(requestonly && message_cooldown < world.time)
		var/message = amount == 1 ? "A new order has been requested." : "[amount] order has been requested."
		radio.talk_into(src, message, RADIO_CHANNEL_SUPPLY)
		message_cooldown = world.time + 30 SECONDS
	. = TRUE

/**
 * removes an item from the checkout cart
 * * params - an list with the id of the cart item to remove as its only element
 */
/obj/machinery/computer/cargo/proc/remove_item(params)
	var/id = text2num(params["id"])
	for(var/datum/supply_order/order in SSshuttle.shopping_list)
		if(order.id != id)
			continue
		if(!can_remove_orders && order.account_to_charge != cargo_account)
			say("ERROR: This console lacks permission to remove orders not added by them!")
			return
		if(order.department_destination)
			say("Only the department that ordered this item may cancel it.")
			return
		if(order.applied_coupon)
			say("Coupon refunded.")
			order.applied_coupon.forceMove(get_turf(src))
		SSshuttle.shopping_list -= order
		. = TRUE
		break

/**
 * maps the ordename displayed on the ui to its supply pack id
 * * order_name - the name of the order
 */
/obj/machinery/computer/cargo/proc/name_to_id(order_name)
	for(var/pack in SSshuttle.supply_packs)
		var/datum/supply_pack/supply = SSshuttle.supply_packs[pack]
		if(order_name == supply.name)
			return pack
	return null

/obj/machinery/computer/cargo/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	switch(action)
		if("send")
			if(!can_send_shuttle)
				say("ERROR: This console lacks permission to call or send the Shuttle")
				return
			if(currently_sending)
				say("Contents are already on their way")
				return
			if(!SSshuttle.supply.canMove())
				say(safety_warning)
				return
			if(SSshuttle.supply_blocked)
				say(blockade_warning)
				return

			//create the paper from the SSshuttle.shopping_list
			if(length(SSshuttle.shopping_list))
				var/obj/item/paper/requisition_paper = new(get_turf(src))
				requisition_paper.name = "requisition form"
				var/requisition_text = "<h2>[station_name()] Supply Requisition</h2>"
				requisition_text += "<hr/>"
				requisition_text += "Time of Order: [station_time_timestamp()]<br/><br/>"
				for(var/datum/supply_order/order as anything in SSshuttle.shopping_list)
					requisition_text += "<b>[order.pack.name]</b></br>"
					requisition_text += "- Order ID: [order.id]</br>"
					var/restrictions = SSid_access.get_access_desc(order.pack.access)
					if(restrictions)
						requisition_text += "- Access Restrictions: [restrictions]</br>"
					requisition_text += "- Ordered by: [order.orderer] ([order.orderer_rank])</br>"
					var/paying_account = order.paying_account
					if(paying_account)
						requisition_text += "- Paid Privately by: [order.paying_account.account_holder]<br/>"
					var/reason = order.reason
					if(reason)
						requisition_text += "- Reason Given: [reason]</br>"
					requisition_text += "</br></br>"
				requisition_paper.add_raw_text(requisition_text)
				requisition_paper.update_appearance()

			if(!length(SSmapping.levels_by_trait(ZTRAIT_OSHAN)))
				if(SSshuttle.supply.getDockedId() == docking_home)
					SSshuttle.supply.export_categories = get_export_categories()
					SSshuttle.moveShuttle(cargo_shuttle, docking_away, TRUE)
					say("The supply shuttle is departing.")
					usr.investigate_log("sent the supply shuttle away.", INVESTIGATE_CARGO)
				else
					usr.investigate_log("called the supply shuttle.", INVESTIGATE_CARGO)
					say("The supply shuttle has been called and will arrive in [SSshuttle.supply.timeLeft(600)] minutes.")
					SSshuttle.moveShuttle(cargo_shuttle, docking_home, TRUE, cargo_account)
			else
				if(!length(GLOB.cargo_launch_points))
					stack_trace("Erm, we are attempting to launch cargo crates on a map with no cargo landing points")
					return
				currently_sending = TRUE
				var/list/goodies_by_buyer = list()
				for(var/datum/supply_order/order as anything in SSshuttle.shopping_list)

					var/price = order.pack.get_cost()
					if(order.applied_coupon)
						price *= (1 - order.applied_coupon.discount_pct_off)

					var/datum/bank_account/paying_for_this
					if(!order.department_destination && order.charge_on_purchase)
						if(order.paying_account) //Someone paid out of pocket
							var/list/current_buyer_orders = goodies_by_buyer[order.paying_account] // so we can access the length a few lines down
							if(!order.pack.goody)
								price *= 1.1 //TODO make this customizable by the quartermaster
							else if(LAZYLEN(current_buyer_orders) == 5)
								price += 700
								paying_for_this.bank_card_talk("Goody order size exceeds free shipping limit: Assessing 700 credit S&H fee.")
						else
							paying_for_this = SSeconomy.get_dep_account(order.account_to_charge)
							if(order.account_to_charge != ACCOUNT_CAR)
								var/datum/bank_account/department/cargo = SSeconomy.get_dep_account(ACCOUNT_CAR)
								cargo.adjust_money(order.pack.get_cost() * 0.1) // give some back for actually getting the crates
						if(paying_for_this)
							if(!paying_for_this.adjust_money(-price, "Cargo: [order.pack.name]"))
								if(order.paying_account)
									paying_for_this.bank_card_talk("Cargo order #[order.id] rejected due to lack of funds. Credits required: [price]")
								continue

					if(order.paying_account)
						paying_for_this = order.paying_account
						if(order.pack.goody)
							LAZYADD(goodies_by_buyer[order.paying_account], order)
						var/reciever_message = "Cargo order #[order.id] has been launched towards cargo."
						if(order.charge_on_purchase)
							reciever_message += " [price] credits have been charged to your bank account"
						paying_for_this.bank_card_talk(reciever_message)
						SSeconomy.track_purchase(paying_for_this, price, order.pack.name)
						var/datum/bank_account/department/cargo = SSeconomy.get_dep_account(ACCOUNT_CAR)
						cargo.adjust_money(price - order.pack.get_cost()) //Cargo gets the handling fee

					sleep(3 SECONDS)
					var/obj/effect/oshan_launch_point/cargo/picked_point = pick(GLOB.cargo_launch_points)
					var/turf/open/spawning_turf = get_edge_target_turf(picked_point, picked_point.map_edge_direction)
					var/obj/structure/closet/crate/new_atom = order.generate(spawning_turf)
					SSshuttle.shopping_list -= order
					var/distance = get_dist(spawning_turf, picked_point)
					new_atom.throw_at(picked_point, distance + 4, 2)

				if(prob(25))
					var/obj/structure/closet/crate/mail/economy/new_create
					var/obj/effect/oshan_launch_point/cargo/picked_point = pick(GLOB.cargo_launch_points)
					var/turf/open/spawning_turf = get_edge_target_turf(picked_point, picked_point.map_edge_direction)
					if(!SSeconomy.mail_crate)
						new_create = new /obj/structure/closet/crate/mail/economy(spawning_turf)
						SSeconomy.mail_crate = new_create
					if(SSeconomy.mail_crate)
						SSeconomy.mail_crate.forceMove(spawning_turf)
						new_create = SSeconomy.mail_crate
						var/distance = get_dist(spawning_turf, picked_point)
						new_create.throw_at(picked_point, distance + 4, 2)
						SSeconomy.mail_crate = null

				currently_sending = FALSE

			. = TRUE
		if("loan")
			if(!SSshuttle.shuttle_loan)
				return
			if(SSshuttle.supply_blocked)
				say(blockade_warning)
				return
			else if(SSshuttle.supply.mode != SHUTTLE_IDLE)
				return
			else if(SSshuttle.supply.getDockedId() != docking_away)
				return
			else if(stationcargo != TRUE)
				return
			else
				SSshuttle.shuttle_loan.loan_shuttle()
				say("The supply shuttle has been loaned to CentCom.")
				usr.investigate_log("accepted a shuttle loan event.", INVESTIGATE_CARGO)
				usr.log_message("accepted a shuttle loan event.", LOG_GAME)
				. = TRUE
		if("add")
			params += "account_to_charge"
			params["account_to_charge"] = cargo_account
			return add_item(params)
		if("add_by_name")
			var/supply_pack_id = name_to_id(params["order_name"])
			if(!supply_pack_id)
				return
			return add_item(list("id" = supply_pack_id, "amount" = 1, "account_to_charge" = cargo_account))
		if("remove")
			var/order_name = params["order_name"]
			//try removing atleast one item with the specified name. An order may not be removed if it was from the department
			//also we create an copy of the cart list else we would get runtimes when removing & iterating over the same SSshuttle.shopping_list
			var/list/shopping_cart = SSshuttle.shopping_list.Copy()
			for(var/datum/supply_order/order in shopping_cart)
				if(order.pack.name != order_name)
					continue
				if(remove_item(list("id" = order.id)))
					return TRUE

			return TRUE
		if("modify")
			var/order_name = params["order_name"]

			//clear out all orders with the above mentioned order_name name to make space for the new amount
			var/list/shopping_cart = SSshuttle.shopping_list.Copy() //we operate on the list copy else we would get runtimes when removing & iterating over the same SSshuttle.shopping_list
			for(var/datum/supply_order/order in shopping_cart) //find corresponding order id for the order name
				if(order.pack.name == order_name)
					remove_item(list("id" = "[order.id]"))

			//now add the new amount stuff
			var/amount = text2num(params["amount"])
			if(amount == 0)
				return TRUE
			var/supply_pack_id = name_to_id(order_name) //map order name to supply pack id for adding
			if(!supply_pack_id)
				return
			return add_item(list("id" = supply_pack_id, "amount" = amount, "account_to_charge" = cargo_account))
		if("clear")
			//create copy of list else we will get runtimes when iterating & removing items on the same list SSshuttle.shopping_list
			var/list/shopping_cart = SSshuttle.shopping_list.Copy()
			for(var/datum/supply_order/cancelled_order in shopping_cart)
				if(cancelled_order.department_destination || !cancelled_order.can_be_cancelled)
					continue //don't cancel other department's orders or orders that can't be cancelled
				remove_item(list("id" = "[cancelled_order.id]")) //remove & properly refund any coupons attached with this order
		if("approve")
			var/id = text2num(params["id"])
			for(var/datum/supply_order/SO in SSshuttle.request_list)
				if(SO.id == id)
					SSshuttle.request_list -= SO
					SSshuttle.shopping_list += SO
					. = TRUE
					break
		if("deny")
			var/id = text2num(params["id"])
			for(var/datum/supply_order/SO in SSshuttle.request_list)
				if(SO.id == id)
					SSshuttle.request_list -= SO
					. = TRUE
					break
		if("denyall")
			SSshuttle.request_list.Cut()
			. = TRUE
		if("toggleprivate")
			self_paid = !self_paid
			. = TRUE
	if(.)
		post_signal(cargo_shuttle)

/obj/machinery/computer/cargo/proc/post_signal(command)

	var/datum/radio_frequency/frequency = SSradio.return_frequency(FREQ_STATUS_DISPLAYS)

	if(!frequency)
		return

	var/datum/signal/status_signal = new(list("command" = command))
	frequency.post_signal(src, status_signal)
