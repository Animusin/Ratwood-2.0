/client/verb/update_ping(time as num)
	set instant = TRUE
	set name = ".update_ping"
	var/ping = pingfromtime(time)
	lastping = ping
	if (!avgping)
		avgping = ping
	else
		avgping = MC_AVERAGE_SLOW(avgping, ping)

/client/proc/pingfromtime(time)
	return ((world.time+world.tick_lag*TICK_USAGE_REAL/100)-time)*100

/client/verb/display_ping(time as num)
	set instant = TRUE
	set name = ".display_ping"
	var/thingy = round(pingfromtime(time)/2,1)
	to_chat(src, span_notice("[thingy]ms"))

/client/verb/ping()
	set name = "Ping"
	set category = "Options"
	winset(src, null, "command=.display_ping+[world.time+world.tick_lag*TICK_USAGE_REAL/100]")

/// Round-trip over the native client command channel, without involving the chat panel.
/client/verb/lag_recorder_ping(token as text)
	set name = ".lag_recorder_ping"
	set hidden = TRUE
	set instant = TRUE

	var/datum/lag_recorder/recorder = Master?.lag_recorder
	if(recorder)
		recorder.record_ping_reply(ckey, token, rustg_time_milliseconds("lag_recorder"), world.time)
