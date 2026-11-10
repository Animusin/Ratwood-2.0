/// Stores information about a chat payload
/datum/chat_payload
	/// Sequence number of this payload
	var/sequence = 0
	var/encoded_content
	var/legacy_message

/// Converts the chat payload into a JSON string.
/datum/chat_payload/proc/into_message()
	return "{\"sequence\":[sequence],\"content\":[encoded_content]}"
