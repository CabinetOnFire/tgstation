SUBSYSTEM_DEF(statpanels)
	name = "Stat Panels"
	wait = 4
	priority = FIRE_PRIORITY_STATPANEL
	runlevels = RUNLEVELS_DEFAULT | RUNLEVEL_LOBBY
	ss_flags = SS_NO_INIT
	var/list/currentrun = list()
	var/list/global_data
	var/list/mc_data
	var/list/mc_subsystem_data
	var/mc_subsystem_usage_per_tick = 0

	///how many subsystem fires between most tab updates
	var/default_wait = 10
	///how many subsystem fires between updates of the status tab
	var/status_wait = 2
	///how many subsystem fires between updates of the MC tab
	var/mc_wait = 5
	///how many full runs this subsystem has completed. used for variable rate refreshes.
	var/num_fires = 0

/datum/controller/subsystem/statpanels/fire(resumed = FALSE)
	if (!resumed)
		num_fires++
		var/datum/map_config/cached = SSmap_vote.next_map_config

		if(isnull(SSmapping.current_map))
			global_data = list("Loading")
		else if(SSmapping.current_map.feedback_link)
			global_data = list(list("Map: [SSmapping.current_map.map_name]", " (Feedback)", "action=openLink&link=[SSmapping.current_map.feedback_link]"))
		else
			global_data = list("Map: [SSmapping.current_map?.map_name]")

		if(SSmapping.current_map?.mapping_url)
			global_data += list(list("same_line", " | (View in Browser)", "action=openWebMap"))

		if(cached)
			global_data += "Next Map: [cached.map_name]"

		global_data += list(
			"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
			"Server Time/NST: [server_timestamp(format = "YYYY-MM-DD hh:mm:ss", ic_time = TRUE)]",
			"Shift Time/PT: [(SSticker.round_start_time == 0) ? "Pre-Game" : round_timestamp()]",
			"Time Dilation: [round(SStime_track.time_dilation_current,1)]% AVG:([round(SStime_track.time_dilation_avg_fast,1)]%, [round(SStime_track.time_dilation_avg,1)]%, [round(SStime_track.time_dilation_avg_slow,1)]%)",
		)

		if(SSshuttle.emergency)
			var/ETA = SSshuttle.emergency.getModeStr()
			if(ETA)
				global_data += "[ETA] [SSshuttle.emergency.getTimerStr()]"

		src.currentrun = GLOB.clients.Copy()
		update_usage_collection()
		mc_data = null
		mc_subsystem_data = null

	var/list/currentrun = src.currentrun
	while(length(currentrun))
		var/client/target = currentrun[length(currentrun)]
		currentrun.len--

		if(!target.stat_panel.is_ready())
			continue

		if(target.stat_tab == "Status" && num_fires % status_wait == 0)
			set_status_tab(target)

		if(!target.holder)
			target.stat_panel.send_message("remove_admin_tabs")
		else
			target.stat_panel.send_message("update_split_admin_tabs", !!(target.prefs.toggles & SPLIT_ADMIN_TABS))

			if(!("MC" in target.panel_tabs) || !("Tickets" in target.panel_tabs))
				target.stat_panel.send_message("add_admin_tabs", target.holder.href_token)

			if(target.stat_tab == "MC" && ((num_fires % mc_wait == 0) || target?.prefs.read_preference(/datum/preference/toggle/fast_mc_refresh)))
				set_MC_tab(target)

			if(target.stat_tab == "Tickets" && num_fires % default_wait == 0)
				set_tickets_tab(target)

			if(!length(GLOB.sdql2_queries) && ("SDQL2" in target.panel_tabs))
				target.stat_panel.send_message("remove_sdql2")

			else if(length(GLOB.sdql2_queries) && (target.stat_tab == "SDQL2" || !("SDQL2" in target.panel_tabs)) && num_fires % default_wait == 0)
				set_SDQL2_tab(target)

		if(MC_TICK_CHECK)
			return

/*
 * send_message for the stat panel can be sent 1 of 4 things:
 * 1- A string entry, to show up as plain text.
 * 2- An empty string (""), which will translate to a new line, to for a break between lines.
 * 3- a list, in which the first entry is plain text, the second entry is highlighted text, and the third entry is a link
 * that clicking the second entry will take you to.
 * 4- a list with "same_line" as the first entry, which will automatically put it on the line above it,
 * with the second/third entry matching #3 (text & url), allowing you to have 2 clickable links on one line.
 */
/datum/controller/subsystem/statpanels/proc/set_status_tab(client/target)
	if(!global_data)//statbrowser hasnt fired yet and we were called from immediate_send_stat_data()
		return
	target.stat_panel.send_message("update_stat", list(
		"global_data" = global_data,
		"other_str" = target.mob?.get_status_tab_items(),
	))

/datum/controller/subsystem/statpanels/proc/set_MC_tab(client/target)
	var/turf/eye_turf = get_turf(target.eye)
	var/coord_entry = COORD(eye_turf)
	if(!Master.statpanel_rolling_usage_active)
		Master.statpanel_rolling_usage_active = TRUE
		Master.update_rolling_usage()
	if(!mc_data)
		generate_mc_data()
	var/list/tick_summary = list(
		"tick_usage" = TICK_USAGE,
		"running_limit" = TICK_LIMIT_RUNNING,
		"mc_limit" = TICK_LIMIT_MC,
		"map_cpu" = MAPTICK_LAST_INTERNAL_TICK_USAGE,
		"subsystem_usage_per_tick" = mc_subsystem_usage_per_tick,
		"usage_window_seconds" = Master.rolling_usage_length / 10,
		"usage_collection_active" = Master.use_rolling_usage,
	)
	target.stat_panel.send_message("update_mc", list(
		"mc_data" = mc_data,
		"coord_entry" = coord_entry,
		"tick_summary" = tick_summary,
		"subsystems" = mc_subsystem_data,
	))

/datum/controller/subsystem/statpanels/proc/update_usage_collection()
	var/has_mc_admin = FALSE
	for(var/client/admin_client as anything in GLOB.clients)
		if(admin_client.holder && admin_client.stat_tab == "MC")
			has_mc_admin = TRUE
			break
	Master.statpanel_rolling_usage_active = has_mc_admin
	Master.update_rolling_usage()

/datum/controller/subsystem/statpanels/proc/set_tickets_tab(client/target)
	var/list/ahelp_tickets = GLOB.ahelp_tickets.stat_entry()
	target.stat_panel.send_message("update_tickets", ahelp_tickets)
	var/datum/interview_manager/m = GLOB.interviews

	// get open interview count
	var/dc = 0
	for (var/ckey in m.open_interviews)
		var/datum/interview/current_interview = m.open_interviews[ckey]
		if (current_interview && !current_interview.owner)
			dc++
	var/stat_string = "([m.open_interviews.len - dc] online / [dc] disconnected)"

	// Prepare each queued interview
	var/list/queued = list()
	for (var/datum/interview/queued_interview in m.interview_queue)
		queued += list(list(
			"ref" = REF(queued_interview),
			"status" = "\[[queued_interview.pos_in_queue]\]: [queued_interview.owner_ckey][!queued_interview.owner ? " (DC)": ""] \[INT-[queued_interview.id]\]"
		))

	var/list/data = list(
		"status" = list(
			"Active:" = "[m.open_interviews.len] [stat_string]",
			"Queued:" = "[m.interview_queue.len]",
			"Closed:" = "[m.closed_interviews.len]"),
		"interviews" = queued
	)

	// Push update
	target.stat_panel.send_message("update_interviews", data)

/datum/controller/subsystem/statpanels/proc/set_SDQL2_tab(client/target)
	var/list/sdql2A = list()
	sdql2A[++sdql2A.len] = list("", "Access Global SDQL2 List", REF(GLOB.sdql2_vv_statobj))
	var/list/sdql2B = list()
	for(var/datum/sdql2_query/query as anything in GLOB.sdql2_queries)
		sdql2B = query.generate_stat()

	sdql2A += sdql2B
	target.stat_panel.send_message("update_sdql2", sdql2A)

/datum/controller/subsystem/statpanels/proc/generate_mc_data()
	mc_data = list(
		list("", "CPU:", world.cpu),
		list("", "Instances:", "[num2text(world.contents.len, 10)]"),
		list("", "World Time:", "[world.time]"),
		list("", "Globals:", GLOB.stat_entry(), text_ref(GLOB)),
		list("", "[config]:", config.stat_entry(), text_ref(config)),
		list("", "Byond:", "(FPS:[world.fps]) (TickCount:[world.time/world.tick_lag]) (TickDrift:[round(Master.tickdrift,1)]([round((Master.tickdrift/(world.time/world.tick_lag))*100,0.1)]%))\n  (Internal Tick Usage: [round(MAPTICK_LAST_INTERNAL_TICK_USAGE,0.1)]%)"),
		list("", "Master Controller:", Master.stat_entry(), text_ref(Master)),
		list("", "Failsafe Controller:", Failsafe.stat_entry(), text_ref(Failsafe)),
		list("", "", "")
	)
#if defined(MC_TAB_TRACY_INFO) || defined(SPACEMAN_DMM)
	var/static/tracy_dll
	var/static/tracy_present
	if(isnull(tracy_dll))
		tracy_dll = TRACY_DLL_PATH
		tracy_present = fexists(tracy_dll)
	if(tracy_present)
		if(Tracy.enabled)
			mc_data.Insert(2, list(list("", "byond-tracy:", "Active (reason: [Tracy.init_reason || "N/A"])")))
		else if(Tracy.error)
			mc_data.Insert(2, list(list("", "byond-tracy:", "Errored ([Tracy.error])")))
		else if(fexists(TRACY_ENABLE_PATH))
			mc_data.Insert(2, list(list("", "byond-tracy:", "Queued for next round")))
		else
			mc_data.Insert(2, list(list("", "byond-tracy:", "Inactive")))
	else
		mc_data.Insert(2, list(list("", "byond-tracy:", "[tracy_dll] not present")))
#endif
	mc_subsystem_data = list()
	mc_subsystem_usage_per_tick = 0
	var/rolling_usage_denominator = max(1, DS2TICKS(Master.rolling_usage_length))
	for(var/datum/controller/subsystem/sub_system as anything in Master.subsystems)
		var/list/rolling_usage = sub_system.rolling_usage
		sub_system.prune_rolling_usage()
		var/rolling_usage_sum = 0
		for(var/i in 2 to length(rolling_usage) step 2)
			rolling_usage_sum += rolling_usage[i]
		var/usage_per_tick = rolling_usage_sum / rolling_usage_denominator
		mc_subsystem_usage_per_tick += usage_per_tick
		mc_subsystem_data += list(list(
			"name" = sub_system.name,
			"ref" = text_ref(sub_system),
			"state" = sub_system.state_letter(),
			"initialized" = sub_system.initialized,
			"can_fire" = sub_system.can_fire,
			"doesnt_fire" = !!(sub_system.ss_flags & SS_NO_FIRE),
			"ticker" = !!(sub_system.ss_flags & SS_TICKER),
			"background" = !!(sub_system.ss_flags & SS_BACKGROUND),
			"priority" = sub_system.priority,
			"allocation" = sub_system.tick_allocation_avg,
			"usage" = sub_system.tick_usage,
			"usage_per_tick" = usage_per_tick,
			"cost" = sub_system.cost,
			"overrun" = sub_system.tick_overrun,
			"stat_entry" = sub_system.stat_entry(),
		))

///immediately update the active statpanel tab of the target client
/datum/controller/subsystem/statpanels/proc/immediate_send_stat_data(client/target)
	if(!target.stat_panel.is_ready())
		return FALSE

	if(target.stat_tab == "Status")
		set_status_tab(target)
		return TRUE

	if(!target.holder)
		return FALSE

	if(target.stat_tab == "MC")
		set_MC_tab(target)
		return TRUE

	if(target.stat_tab == "Tickets")
		set_tickets_tab(target)
		return TRUE

	if(!length(GLOB.sdql2_queries) && ("SDQL2" in target.panel_tabs))
		target.stat_panel.send_message("remove_sdql2")

	else if(length(GLOB.sdql2_queries) && target.stat_tab == "SDQL2")
		set_SDQL2_tab(target)
