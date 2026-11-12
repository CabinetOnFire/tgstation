/// Admin-only preview tool for inspecting BYOND's per-sound environment and EAX echo settings.
/datum/audio_panel
	var/client/owner
	var/channel
	var/selected_sound = 'sound/items/weapons/gun/revolver/shot.ogg'
	var/volume = 35
	var/sound_x = 0
	var/sound_y = 0
	var/sound_z = 1
	var/loop_playback = FALSE
	var/preview_playing = FALSE
	var/preview_loop_active = FALSE
	var/preview_with_echo = TRUE
	var/environment_enabled = TRUE
	var/list/environment_values
	var/list/environment_presets
	var/list/environment_preset_ids
	var/list/echo_values

	var/static/list/environment_field_definitions = list(
		list("index" = SOUND_ENVIRONMENT_INDEX_SIZE, "label" = "Environment size", "group" = "Room", "min" = 1, "max" = 100, "step" = 0.1, "unit" = "m"),
		list("index" = SOUND_ENVIRONMENT_INDEX_DIFFUSION, "label" = "Environment diffusion", "group" = "Room", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_ROOM, "label" = "Room", "group" = "Room", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ENVIRONMENT_INDEX_ROOM_HF, "label" = "Room HF", "group" = "Room", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ENVIRONMENT_INDEX_ROOM_LF, "label" = "Room LF", "group" = "Room", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ENVIRONMENT_INDEX_DECAY_TIME, "label" = "Decay time", "group" = "Decay", "min" = 0.1, "max" = 20, "step" = 0.01, "unit" = "s"),
		list("index" = SOUND_ENVIRONMENT_INDEX_DECAY_HF_RATIO, "label" = "Decay HF ratio", "group" = "Decay", "min" = 0.1, "max" = 2, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_DECAY_LF_RATIO, "label" = "Decay LF ratio", "group" = "Decay", "min" = 0.1, "max" = 2, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_REFLECTIONS, "label" = "Reflections", "group" = "Reflections and reverb", "min" = -10000, "max" = 1000, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ENVIRONMENT_INDEX_REFLECTIONS_DELAY, "label" = "Reflections delay", "group" = "Reflections and reverb", "min" = 0, "max" = 0.3, "step" = 0.001, "unit" = "s"),
		list("index" = SOUND_ENVIRONMENT_INDEX_REVERB, "label" = "Reverb", "group" = "Reflections and reverb", "min" = -10000, "max" = 2000, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ENVIRONMENT_INDEX_REVERB_DELAY, "label" = "Reverb delay", "group" = "Reflections and reverb", "min" = 0, "max" = 0.1, "step" = 0.001, "unit" = "s"),
		list("index" = SOUND_ENVIRONMENT_INDEX_ECHO_TIME, "label" = "Echo time", "group" = "Echo and modulation", "min" = 0.075, "max" = 0.25, "step" = 0.001, "unit" = "s"),
		list("index" = SOUND_ENVIRONMENT_INDEX_ECHO_DEPTH, "label" = "Echo depth", "group" = "Echo and modulation", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_MODULATION_TIME, "label" = "Modulation time", "group" = "Echo and modulation", "min" = 0.04, "max" = 4, "step" = 0.01, "unit" = "s"),
		list("index" = SOUND_ENVIRONMENT_INDEX_MODULATION_DEPTH, "label" = "Modulation depth", "group" = "Echo and modulation", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_AIR_ABSORPTION_HF, "label" = "Air absorption HF", "group" = "Other", "min" = -100, "max" = 0, "step" = 1, "unit" = "dB/km"),
		list("index" = SOUND_ENVIRONMENT_INDEX_HF_REFERENCE, "label" = "HF reference", "group" = "Other", "min" = 1000, "max" = 20000, "step" = 10, "unit" = "Hz"),
		list("index" = SOUND_ENVIRONMENT_INDEX_LF_REFERENCE, "label" = "LF reference", "group" = "Other", "min" = 20, "max" = 1000, "step" = 1, "unit" = "Hz"),
		list("index" = SOUND_ENVIRONMENT_INDEX_ROOM_ROLLOFF_FACTOR, "label" = "Room rolloff factor", "group" = "Other", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ENVIRONMENT_INDEX_DIFFUSION_PERCENT, "label" = "Diffusion", "group" = "Other", "min" = 0, "max" = 100, "step" = 1, "unit" = "%"),
		list("index" = SOUND_ENVIRONMENT_INDEX_DENSITY, "label" = "Density", "group" = "Other", "min" = 0, "max" = 100, "step" = 1, "unit" = "%"),
	)

	var/static/list/echo_field_definitions = list(
		list("index" = SOUND_ECHO_INDEX_DIRECT, "label" = "Direct", "group" = "Direct and room", "min" = -10000, "max" = 1000, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_DIRECT_HF, "label" = "Direct HF", "group" = "Direct and room", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_ROOM, "label" = "Room", "group" = "Direct and room", "min" = -10000, "max" = 1000, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_ROOM_HF, "label" = "Room HF", "group" = "Direct and room", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_OBSTRUCTION, "label" = "Obstruction", "group" = "Obstruction and occlusion", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_OBSTRUCTION_LF_RATIO, "label" = "Obstruction LF ratio", "group" = "Obstruction and occlusion", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_OCCLUSION, "label" = "Occlusion", "group" = "Obstruction and occlusion", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_OCCLUSION_LF_RATIO, "label" = "Occlusion LF ratio", "group" = "Obstruction and occlusion", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_OCCLUSION_ROOM_RATIO, "label" = "Occlusion room ratio", "group" = "Obstruction and occlusion", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_OCCLUSION_DIRECT_RATIO, "label" = "Occlusion direct ratio", "group" = "Obstruction and occlusion", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_EXCLUSION, "label" = "Exclusion", "group" = "Exclusion and outside volume", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_EXCLUSION_LF_RATIO, "label" = "Exclusion LF ratio", "group" = "Exclusion and outside volume", "min" = 0, "max" = 1, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_OUTSIDE_VOLUME_HF, "label" = "Outside volume HF", "group" = "Exclusion and outside volume", "min" = -10000, "max" = 0, "step" = 1, "unit" = "mB"),
		list("index" = SOUND_ECHO_INDEX_DOPPLER_FACTOR, "label" = "Doppler factor", "group" = "Distance and air absorption", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_ROLLOFF_FACTOR, "label" = "Rolloff factor", "group" = "Distance and air absorption", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_ROOM_ROLLOFF_FACTOR, "label" = "Room rolloff factor", "group" = "Distance and air absorption", "min" = 0, "max" = 10, "step" = 0.01),
		list("index" = SOUND_ECHO_INDEX_AIR_ABSORPTION_FACTOR, "label" = "Air absorption factor", "group" = "Distance and air absorption", "min" = 0, "max" = 10, "step" = 0.01),
	)

/datum/audio_panel/New(client/new_owner)
	. = ..()
	owner = new_owner
	RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(owner_deleted))
	channel = SSsounds.reserve_sound_channel_for_datum(src)
	initialize_environment_presets()
	environment_values = environment_presets["Generic"].Copy()
	echo_values = list(0, 0, 0, 0, 0, 0, 0, 0.25, 1.5, 1, 0, 1, 0, 0, 0, 0, 1, SOUND_ECHO_DEFAULT_FLAGS)

/datum/audio_panel/Destroy()
	stop_preview()
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	owner = null
	return ..()

/datum/audio_panel/proc/owner_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/audio_panel/proc/initialize_environment_presets()
	// Source for these settings: https://zxgit.org/RomanRom2/whoa/src/commit/94bb7736aa8ba50835179720b4cab1086aa68cdf/vendor/fmodex-4.32.09/win32/inc/fmod.h
	environment_presets = list(
		"Generic" = list(7.5, 1, -1000, -100, 0, 1.49, 0.83, 1, -2602, 0.007, 200, 0.011, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Padded Cell" = list(1.4, 1, -1000, -6000, 0, 0.17, 0.1, 1, -1204, 0.001, 207, 0.002, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Room" = list(1.9, 1, -1000, -454, 0, 0.4, 0.83, 1, -1646, 0.002, 53, 0.003, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Bathroom" = list(1.4, 1, -1000, -1200, 0, 1.49, 0.54, 1, -370, 0.007, 1030, 0.011, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 60, 63),
		"Living Room" = list(2.5, 1, -1000, -6000, 0, 0.5, 0.1, 1, -1376, 0.003, -1104, 0.004, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Stone Room" = list(11.6, 1, -1000, -300, 0, 2.31, 0.64, 1, -711, 0.012, 83, 0.017, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Auditorium" = list(21.6, 1, -1000, -476, 0, 4.32, 0.59, 1, -789, 0.02, -289, 0.03, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Concert Hall" = list(19.6, 1, -1000, -500, 0, 3.92, 0.7, 1, -1230, 0.02, -2, 0.029, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Cave" = list(14.6, 1, -1000, 0, 0, 2.91, 1.3, 1, -602, 0.015, -302, 0.022, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 31),
		"Arena" = list(36.2, 1, -1000, -698, 0, 7.24, 0.33, 1, -1166, 0.02, 16, 0.03, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Hangar" = list(50.3, 1, -1000, -1000, 0, 10.05, 0.23, 1, -602, 0.02, 198, 0.03, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Carpeted Hallway" = list(1.9, 1, -1000, -4000, 0, 0.3, 0.1, 1, -1831, 0.002, -1630, 0.03, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Hallway" = list(1.8, 1, -1000, -300, 0, 1.49, 0.59, 1, -1219, 0.007, 441, 0.011, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Stone Corridor" = list(13.5, 1, -1000, -237, 0, 2.7, 0.79, 1, -1214, 0.013, 395, 0.02, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Alley" = list(7.5, 0.3, -1000, -270, 0, 1.49, 0.86, 1, -1204, 0.007, -4, 0.011, 0.125, 0.95, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Forest" = list(38, 0.3, -1000, -3300, 0, 1.49, 0.54, 1, -2560, 0.162, -229, 0.088, 0.125, 1, 0.25, 0, -5, 5000, 250, 0, 79, 100, 63),
		"City" = list(7.5, 0.5, -1000, -800, 0, 1.49, 0.67, 1, -2273, 0.007, -1691, 0.011, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 50, 100, 63),
		"Mountains" = list(100, 0.27, -1000, -2500, 0, 1.49, 0.21, 1, -2780, 0.3, -1434, 0.1, 0.25, 1, 0.25, 0, -5, 5000, 250, 0, 27, 100, 31),
		"Quarry" = list(17.5, 1, -1000, -1000, 0, 1.49, 0.83, 1, -10000, 0.061, 500, 0.025, 0.125, 0.7, 0.25, 0, -5, 5000, 250, 0, 100, 100, 63),
		"Plain" = list(42.5, 0.21, -1000, -2000, 0, 1.49, 0.5, 1, -2466, 0.179, -1926, 0.1, 0.25, 1, 0.25, 0, -5, 5000, 250, 0, 21, 100, 63),
		"Parking Lot" = list(8.3, 1, -1000, 0, 0, 1.65, 1.5, 1, -1363, 0.008, -1153, 0.012, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 100, 100, 31),
		"Sewer Pipe" = list(1.7, 0.8, -1000, -1000, 0, 2.81, 0.14, 1, 429, 0.014, 1023, 0.021, 0.25, 0, 0.25, 0, -5, 5000, 250, 0, 80, 60, 63),
		"Underwater" = list(1.8, 1, -1000, -4000, 0, 1.49, 0.1, 1, -449, 0.007, 1700, 0.011, 0.25, 0, 1.18, 0.348, -5, 5000, 250, 0, 100, 100, 63),
		"Drugged" = list(1.9, 0.5, -1000, 0, 0, 8.39, 1.39, 1, -115, 0.002, 985, 0.03, 0.25, 0, 0.25, 1, -5, 5000, 250, 0, 100, 100, 31),
		"Dizzy" = list(1.8, 0.6, -1000, -400, 0, 17.23, 0.56, 1, -1713, 0.02, -613, 0.03, 0.25, 1, 0.81, 0.31, -5, 5000, 250, 0, 100, 100, 31),
		"Psychotic" = list(1, 0.5, -1000, -151, 0, 7.56, 0.91, 1, -626, 0.02, 774, 0.03, 0.25, 0, 4, 1, -5, 5000, 250, 0, 100, 100, 31),
	)
	environment_preset_ids = list(
		"Generic" = SOUND_ENVIRONMENT_GENERIC,
		"Padded Cell" = SOUND_ENVIRONMENT_PADDED_CELL,
		"Room" = SOUND_ENVIRONMENT_ROOM,
		"Bathroom" = SOUND_ENVIRONMENT_BATHROOM,
		"Living Room" = SOUND_ENVIRONMENT_LIVINGROOM,
		"Stone Room" = SOUND_ENVIRONMENT_STONEROOM,
		"Auditorium" = SOUND_ENVIRONMENT_AUDITORIUM,
		"Concert Hall" = SOUND_ENVIRONMENT_CONCERT_HALL,
		"Cave" = SOUND_ENVIRONMENT_CAVE,
		"Arena" = SOUND_ENVIRONMENT_ARENA,
		"Hangar" = SOUND_ENVIRONMENT_HANGAR,
		"Carpeted Hallway" = SOUND_ENVIRONMENT_CARPETED_HALLWAY,
		"Hallway" = SOUND_ENVIRONMENT_HALLWAY,
		"Stone Corridor" = SOUND_ENVIRONMENT_STONE_CORRIDOR,
		"Alley" = SOUND_ENVIRONMENT_ALLEY,
		"Forest" = SOUND_ENVIRONMENT_FOREST,
		"City" = SOUND_ENVIRONMENT_CITY,
		"Mountains" = SOUND_ENVIRONMENT_MOUNTAINS,
		"Quarry" = SOUND_ENVIRONMENT_QUARRY,
		"Plain" = SOUND_ENVIRONMENT_PLAIN,
		"Parking Lot" = SOUND_ENVIRONMENT_PARKING_LOT,
		"Sewer Pipe" = SOUND_ENVIRONMENT_SEWER_PIPE,
		"Underwater" = SOUND_ENVIRONMENT_UNDERWATER,
		"Drugged" = SOUND_ENVIRONMENT_DRUGGED,
		"Dizzy" = SOUND_ENVIRONMENT_DIZZY,
		"Psychotic" = SOUND_ENVIRONMENT_PSYCHOTIC,
	)

/datum/audio_panel/proc/get_environment_preset_name()
	if(!environment_enabled)
		return "None"
	for(var/preset_name in environment_presets)
		var/list/preset_values = environment_presets[preset_name]
		var/is_match = TRUE
		for(var/index in 1 to SOUND_ENVIRONMENT_INDEX_FLAGS)
			if(abs(environment_values[index] - preset_values[index]) > 0.0001)
				is_match = FALSE
				break
		if(is_match)
			return preset_name
	return "Custom"

/datum/audio_panel/proc/build_field_data(list/definitions, list/values)
	var/list/field_data = list()
	for(var/list/definition as anything in definitions)
		var/list/field = definition.Copy()
		field["value"] = values[definition["index"]]
		field_data += list(field)
	return field_data

/datum/audio_panel/proc/build_flag_data(list/definitions, flag_value)
	var/list/flag_data = list()
	for(var/list/definition as anything in definitions)
		flag_data += list(list(
			"name" = definition["name"],
			"bit" = definition["bit"],
			"enabled" = !!(flag_value & definition["bit"]),
		))
	return flag_data

/datum/audio_panel/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != owner || !check_rights_for(owner, R_SOUND))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AudioPanel")
		ui.open()

/datum/audio_panel/ui_state(mob/user)
	return ADMIN_STATE(R_SOUND)

/datum/audio_panel/ui_data(mob/user)
	var/list/data = list()
	data["soundFile"] = "[selected_sound]"
	data["volume"] = volume
	data["soundX"] = sound_x
	data["soundY"] = sound_y
	data["soundZ"] = sound_z
	data["loop"] = loop_playback
	data["environmentEnabled"] = environment_enabled
	var/current_preset = get_environment_preset_name()
	data["environmentPreset"] = current_preset
	data["environmentPresets"] = list("None")
	for(var/preset_name in environment_presets)
		data["environmentPresets"] += preset_name
	if(current_preset == "Custom")
		data["environmentPresets"] += "Custom"
	data["environmentFields"] = build_field_data(environment_field_definitions, environment_values)
	data["environmentFlags"] = build_flag_data(list(
		list("name" = "Decay time scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_DECAY_TIME_SCALE),
		list("name" = "Reflections level scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_REFLECTIONS_SCALE),
		list("name" = "Reflections delay scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_REFLECTIONS_DELAY_SCALE),
		list("name" = "Reverb level scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_REVERB_SCALE),
		list("name" = "Reverb delay scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_REVERB_DELAY_SCALE),
		list("name" = "Air absorption HF scales decay HF ratio", "bit" = SOUND_ENVIRONMENT_FLAG_AIR_ABSORPTION_HF_DECAY_HF_RATIO),
		list("name" = "Echo time scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_ECHO_TIME_SCALE),
		list("name" = "Modulation time scales with environment size", "bit" = SOUND_ENVIRONMENT_FLAG_MODULATION_TIME_SCALE),
	), environment_values[SOUND_ENVIRONMENT_INDEX_FLAGS])
	data["echoEnabled"] = TRUE
	data["echoFields"] = build_field_data(echo_field_definitions, echo_values)
	data["echoFlags"] = build_flag_data(list(
		list("name" = "Automatic Direct adjustment by distance", "bit" = SOUND_ECHO_FLAG_AUTO_DIRECT),
		list("name" = "Automatic Room adjustment by distance", "bit" = SOUND_ECHO_FLAG_AUTO_ROOM),
		list("name" = "Automatic Room HF adjustment by distance", "bit" = SOUND_ECHO_FLAG_AUTO_ROOM_HF),
	), echo_values[SOUND_ECHO_INDEX_FLAGS])
	data["previewChannel"] = channel
	return data

/datum/audio_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!owner || QDELETED(owner) || ui.user.client != owner || !check_rights_for(owner, R_SOUND))
		qdel(src)
		return TRUE

	switch(action)
		if("choose_sound")
			var/new_sound = input(owner.mob, "Choose an audio file to preview.", "Audio Panel") as null|sound
			if(QDELETED(src) || !owner || QDELETED(owner) || !check_rights_for(owner, R_SOUND))
				return TRUE
			if(new_sound)
				selected_sound = new_sound
				if(preview_loop_active)
					play_preview(preview_with_echo)
			return TRUE
		if("set_volume")
			var/new_volume = params["value"]
			if(isnum(new_volume))
				volume = clamp(new_volume, 0, 100)
				update_looping_preview()
			return TRUE
		if("set_position")
			var/axis = params["axis"]
			var/position = params["value"]
			if(!istext(axis) || !isnum(position))
				return TRUE
			position = round(clamp(position, -127, 127))
			switch(axis)
				if("x")
					sound_x = position
				if("y")
					sound_y = position
				if("z")
					sound_z = position
				else
					return TRUE
			update_looping_preview()
			return TRUE
		if("toggle_loop")
			loop_playback = !loop_playback
			if(preview_playing && (preview_loop_active || loop_playback))
				update_running_preview()
			return TRUE
		if("reset_echo")
			echo_values = list(0, 0, 0, 0, 0, 0, 0, 0.25, 1.5, 1, 0, 1, 0, 0, 0, 0, 1, SOUND_ECHO_DEFAULT_FLAGS)
			update_looping_preview()
			return TRUE
		if("set_environment_preset")
			var/preset_name = params["value"]
			if(!istext(preset_name))
				return TRUE
			if(preset_name == "None")
				environment_enabled = FALSE
			else if(environment_presets[preset_name])
				environment_enabled = TRUE
				environment_values = environment_presets[preset_name].Copy()
			update_looping_preview()
			return TRUE
		if("set_environment_field", "set_echo_field")
			var/is_environment = action == "set_environment_field"
			var/index = params["index"]
			if(!isnum(index))
				index = text2num(index)
			var/value = params["value"]
			var/list/definitions = is_environment ? environment_field_definitions : echo_field_definitions
			var/list/values = is_environment ? environment_values : echo_values
			if(!isnum(index) || index < 1 || index > length(values) || index != round(index) || !isnum(value))
				return TRUE
			var/list/definition
			for(var/list/candidate as anything in definitions)
				if(candidate["index"] == index)
					definition = candidate
					break
			if(!definition)
				return TRUE
			value = clamp(value, definition["min"], definition["max"])
			if(index == SOUND_ENVIRONMENT_INDEX_FLAGS && is_environment || index == SOUND_ECHO_INDEX_FLAGS && !is_environment)
				value = round(value)
			values[index] = value
			update_looping_preview()
			return TRUE
		if("toggle_environment_flag", "toggle_echo_flag")
			var/is_environment = action == "toggle_environment_flag"
			var/bit = params["bit"]
			if(!isnum(bit))
				bit = text2num(bit)
			var/list/values = is_environment ? environment_values : echo_values
			var/flags_index = is_environment ? SOUND_ENVIRONMENT_INDEX_FLAGS : SOUND_ECHO_INDEX_FLAGS
			var/valid_mask = is_environment ? 255 : SOUND_ECHO_DEFAULT_FLAGS
			if(!isnum(bit) || bit < 1 || bit > valid_mask || bit != round(bit) || !(bit & valid_mask) || bit & (bit - 1))
				return TRUE
			if(values[flags_index] & bit)
				values[flags_index] &= ~bit
			else
				values[flags_index] |= bit
			update_looping_preview()
			return TRUE
		if("play")
			play_preview(TRUE)
			return TRUE
		if("play_without_echo")
			play_preview(FALSE)
			return TRUE
		if("stop")
			stop_preview()
			return TRUE

/datum/audio_panel/proc/play_preview(include_echo)
	stop_preview()
	if(!owner?.mob || !selected_sound)
		return
	preview_with_echo = include_echo
	var/sound/preview = create_preview_sound(include_echo, FALSE)
	SEND_SOUND(owner.mob, preview)
	preview_playing = TRUE
	preview_loop_active = loop_playback

/datum/audio_panel/proc/create_preview_sound(include_echo, update_existing)
	var/sound/preview = sound(selected_sound)
	preview.channel = channel
	preview.volume = volume
	preview.repeat = loop_playback ? 1 : FALSE
	preview.wait = 0
	preview.status = update_existing ? SOUND_UPDATE : SOUND_STREAM
	// These relative coordinates and falloff make the preview world-space so BYOND applies EAX.
	preview.x = sound_x
	preview.y = sound_y
	preview.z = sound_z
	preview.falloff = SOUND_RANGE
	if(environment_enabled)
		var/preset_name = get_environment_preset_name()
		preview.environment = preset_name == "Custom" ? environment_values.Copy() : environment_preset_ids[preset_name]
	else
		preview.environment = SOUND_ENVIRONMENT_DISABLED
	preview.echo = include_echo ? echo_values.Copy() : null
	return preview

/datum/audio_panel/proc/update_looping_preview()
	if(preview_loop_active)
		update_running_preview()

/datum/audio_panel/proc/update_running_preview()
	if(!preview_playing || !owner?.mob || !selected_sound)
		return
	SEND_SOUND(owner.mob, create_preview_sound(preview_with_echo, TRUE))
	preview_loop_active = loop_playback

/datum/audio_panel/proc/stop_preview()
	if(owner?.mob && channel)
		SEND_SOUND(owner.mob, sound(null, repeat = FALSE, wait = 0, channel = channel))
	preview_playing = FALSE
	preview_loop_active = FALSE

/datum/audio_panel/ui_close(mob/user)
	qdel(src)

ADMIN_VERB(open_audio_panel, R_SOUND, "Audio Panel", "Preview a sound with BYOND environment and echo settings.", ADMIN_CATEGORY_DEBUG)
	var/datum/audio_panel/lab = new(user)
	lab.ui_interact(user.mob)
