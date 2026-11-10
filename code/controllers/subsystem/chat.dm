/*!
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

SUBSYSTEM_DEF(chat)
	name = "Chat"
	flags = SS_TICKER|SS_NO_INIT
	wait = 1
	priority = FIRE_PRIORITY_CHAT
	// init_stage = INITSTAGE_LAST

	/// Assosciates a ckey with a list of messages to send to them.
	var/list/list/datum/chat_payload/client_to_payloads = list()


	/// Assosciates a ckey with their next sequence number.
	var/list/client_to_sequence_number = list()

/datum/controller/subsystem/chat/proc/generate_payload(target_ckey, encoded_content, legacy_message)
	var/datum/chat_payload/payload = new
	payload.sequence = client_to_sequence_number[target_ckey] || 0
	client_to_sequence_number[target_ckey] = payload.sequence + 1
	payload.encoded_content = encoded_content
	payload.legacy_message = legacy_message
	return payload

/datum/controller/subsystem/chat/proc/send_payload_to_client(client/target, datum/chat_payload/payload)
	target.tgui_panel.window.send_message("chat/message", payload.into_message())
	SEND_TEXT(target, payload.legacy_message)

/datum/controller/subsystem/chat/fire()
	for(var/ckey in client_to_payloads)
		var/client/target = GLOB.directory[ckey]
		if(isnull(target)) // verify client still exists
			LAZYREMOVE(client_to_payloads, ckey)
			continue

		var/list/payloads = client_to_payloads[ckey]
		for(var/index in 1 to length(payloads))
			send_payload_to_client(target, payloads[index])
			if(index % 8 == 0 && index < length(payloads) && MC_TICK_CHECK)
				// Keep unsent messages in order and give the next client the first turn.
				payloads.Cut(1, index + 1)
				client_to_payloads -= ckey
				client_to_payloads[ckey] = payloads
				return
		LAZYREMOVE(client_to_payloads, ckey)

		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/chat/proc/queue(queue_target, list/message_data)
	dispatch_message(queue_target, message_data)

/datum/controller/subsystem/chat/proc/send_immediate(send_target, list/message_data)
	dispatch_message(send_target, message_data, immediate = TRUE)

/datum/controller/subsystem/chat/proc/dispatch_message(send_target, list/message_data, immediate = FALSE)
	var/list/targets = islist(send_target) ? send_target : list(send_target)
	var/encoded_content
	var/legacy_message
	for(var/target in targets)
		var/client/client = CLIENT_FROM_VAR(target)
		if(isnull(client))
			continue

		// A broadcast has the same content for every recipient.
		if(isnull(encoded_content))
			encoded_content = json_encode(message_data)
			legacy_message = message_to_html(message_data)

		var/datum/chat_payload/payload = generate_payload(client.ckey, encoded_content, legacy_message)
		if(immediate)
			send_payload_to_client(client, payload)
		else
			LAZYADDASSOCLIST(client_to_payloads, client.ckey, payload)
