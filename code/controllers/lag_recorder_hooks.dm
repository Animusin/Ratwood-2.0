// Loaded after the handlers so ..() forwards the original arguments and return value.
// Measure one synchronous slice. An async parent returns at its first yield; a synchronous
// parent that crosses a tick cannot be timed as one slice. No input values or identities are logged.
#define LAG_RECORD_CALL(KIND, LABEL, TARGET_TYPE, PROC_NAME, CALL) \
	var/capture_id = Master?.lag_recorder?.capture_id; \
	if(!capture_id) { return CALL; } \
	var/start_tick = world.time; \
	var/before_controller = isnull(Master.lag_recorder.previous_world_time) || Master.lag_recorder.previous_world_time < start_tick; \
	var/start_usage = TICK_USAGE; \
	. = CALL; \
	if(world.time != start_tick) { return; } \
	var/cost_ms = TICK_USAGE_TO_MS(start_usage); \
	if(cost_ms >= 4 && Master?.lag_recorder?.capture_id == capture_id) { \
		Master.lag_recorder.record_work(KIND, LABEL, cost_ms, start_tick, before_controller, TARGET_TYPE, PROC_NAME); \
	}

#define LAG_RECORD_HANDLER(KIND, LABEL, TARGET_TYPE, PROC_NAME) LAG_RECORD_CALL(KIND, LABEL, TARGET_TYPE, PROC_NAME, ..())

/client/Click(atom/object, atom/location, control, params)
	LAG_RECORD_HANDLER("player", "Click", object?.type, null)

/client/Topic(href, href_list, hsrc)
	LAG_RECORD_HANDLER("player", "Topic", null, null)

/client/Move(new_loc, direct)
	LAG_RECORD_HANDLER("player", "Move", null, null)

/client/MouseDown(object, location, control, params)
	LAG_RECORD_HANDLER("player", "MouseDown", null, null)

/client/MouseUp(object, location, control, params)
	LAG_RECORD_HANDLER("player", "MouseUp", null, null)

/client/MouseDrag(src_object, atom/over_object, src_location, over_location, src_control, over_control, params)
	LAG_RECORD_HANDLER("player", "MouseDrag", null, null)

/client/MouseDrop(src_object, over_object, src_location, over_location, src_control, over_control, params)
	LAG_RECORD_HANDLER("player", "MouseDrop", null, null)

/client/verb/keyDown(_key as text)
	set instant = TRUE
	set hidden = TRUE
	LAG_RECORD_CALL("player", "keyDown", null, null, handle_key_down(_key))

/client/verb/keyUp(_key as text)
	set instant = TRUE
	set hidden = TRUE
	LAG_RECORD_CALL("player", "keyUp", null, null, handle_key_up(_key))

/datum/tgui/on_message(type, list/payload, list/href_list)
	LAG_RECORD_HANDLER("player", "TGUI", interface, null)

/datum/callback/Invoke(...)
	LAG_RECORD_HANDLER("callback", "Invoke", lag_callback_target_type(object), delegate)

/datum/callback/InvokeAsync(...)
	set waitfor = FALSE
	LAG_RECORD_HANDLER("callback", "InvokeAsync", lag_callback_target_type(object), delegate)

/world/ImmediateInvokeAsync(thingtocall, proctocall, ...)
	set waitfor = FALSE
	LAG_RECORD_HANDLER("callback", "ImmediateInvokeAsync", lag_callback_target_type(thingtocall), proctocall)

/// Callback receivers may be datums, clients, the global sentinel or a type path.
/proc/lag_callback_target_type(target)
	if(istype(target, /datum) || istype(target, /client))
		var/datum/receiver = target
		return receiver.type
	if(ispath(target))
		return target
	if(target == GLOBAL_PROC)
		return "global"
	return null

#undef LAG_RECORD_HANDLER
#undef LAG_RECORD_CALL
