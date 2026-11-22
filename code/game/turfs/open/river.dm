#define RANDOM_UPPER_X 200
#define RANDOM_UPPER_Y 200

#define RANDOM_LOWER_X 50
#define RANDOM_LOWER_Y 50

/proc/spawn_rivers(target_z, nodes, turf_type, whitelist_area, min_x = RANDOM_LOWER_X, min_y = RANDOM_LOWER_Y, max_x = RANDOM_UPPER_X, max_y = RANDOM_UPPER_Y, datum/random_generation/rng)
	var/list/mapped_waypoints = GLOB.river_waypoint_list["[target_z]"]
	var/list/waypoints = list()
	for (var/obj/effect/landmark/river_waypoint/marker as anything in mapped_waypoints)
		waypoints += list(list(marker.x, marker.y))
	generate_river_terrain(target_z, nodes, turf_type, whitelist_area, waypoints, min_x, min_y, max_x, max_y, rng)
	for (var/obj/effect/landmark/river_waypoint/marker as anything in mapped_waypoints)
		qdel(marker)
	GLOB.river_waypoint_list -= "[target_z]"

/// Carves from mapped waypoints and generated points without creating additional landmarks.
/proc/generate_river_terrain(target_z, nodes, turf_type, whitelist_area, list/waypoints, min_x = RANDOM_LOWER_X, min_y = RANDOM_LOWER_Y, max_x = RANDOM_UPPER_X, max_y = RANDOM_UPPER_Y, datum/random_generation/rng)
	if (!rng)
		rng = new

	var/list/possible_locs = list()
	if (min_x <= world.maxx && min_y <= world.maxy && max_x > min_x && max_y > min_y)
		for (var/y in min_y to min(max_y - 1, world.maxy))
			possible_locs += block(min_x, y, target_z, max_x - 1, y, target_z)
	while (nodes > 0 && length(possible_locs))
		var/turf/candidate = rng.pick_from(possible_locs)
		if (!istype(get_area(candidate), whitelist_area) || (candidate.turf_flags & NO_LAVA_GEN))
			possible_locs -= candidate
			continue
		waypoints += list(list(candidate.x, candidate.y))
		nodes--

	for (var/waypoint_index in 1 to length(waypoints))
		var/list/origin = waypoints[waypoint_index]
		var/turf/current = locate(origin[1], origin[2], target_z)
		current = new turf_type(current)
		if (length(waypoints) == 1)
			break

		var/target_index = rng.rand_range(1, length(waypoints) - 1)
		if (target_index >= waypoint_index)
			target_index++
		var/list/destination = waypoints[target_index]
		var/turf/target = locate(destination[1], destination[2], target_z)
		var/detouring = FALSE
		var/direction = get_dir(current, target)
		var/steps_remaining = world.maxx * world.maxy
		while (current != target && steps_remaining-- > 0)
			if (detouring)
				if (rng.chance(20))
					detouring = FALSE
					direction = get_dir(current, target)
			else if (rng.chance(20))
				detouring = TRUE
				direction = turn(direction, rng.chance(50) ? 45 : -45)
			else
				direction = get_dir(current, target)

			var/turf/next = get_step(current, direction)
			if (!next || !istype(get_area(next), whitelist_area) || (next.turf_flags & NO_LAVA_GEN))
				detouring = FALSE
				direction = get_dir(next || current, target)
				current = get_step(next || current, direction) || next || current
				continue

			current = new turf_type(next)
			current.Spread(25, 11, whitelist_area, rng)

/obj/effect/landmark/river_waypoint
	name = "river waypoint"
	invisibility = INVISIBILITY_ABSTRACT

/obj/effect/landmark/river_waypoint/Initialize(mapload)
	. = ..()
	LAZYADD(GLOB.river_waypoint_list["[z]"], src)

/obj/effect/landmark/river_waypoint/Destroy()
	LAZYREMOVE(GLOB.river_waypoint_list["[z]"], src)
	return ..()

/turf/proc/Spread(probability = 30, prob_loss = 25, whitelisted_area, datum/random_generation/rng)
	if(probability <= 0)
		return
	if (!rng)
		rng = new
	var/list/cardinal_turfs = list()
	var/list/diagonal_turfs = list()
	var/logged_turf_type
	for(var/turf/canidate as anything in RANGE_TURFS(1, src) - src)
		if(!canidate || (canidate.density && !ismineralturf(canidate)) || isindestructiblefloor(canidate))
			continue

		var/area/new_area = get_area(canidate)
		if((!istype(new_area, whitelisted_area) && whitelisted_area) || (canidate.turf_flags & NO_LAVA_GEN))
			continue

		if(!logged_turf_type && ismineralturf(canidate))
			var/turf/closed/mineral/mineral_canidate = canidate
			logged_turf_type = mineral_canidate.turf_type

		if(get_dir(src, canidate) in GLOB.cardinals)
			cardinal_turfs += canidate
		else
			diagonal_turfs += canidate

	for(var/turf/cardinal_canidate as anything in cardinal_turfs) //cardinal turfs are always changed but don't always spread
		// NOTE: WE ARE SKIPPING CHANGETURF HERE
		// The calls in this proc only serve to provide a satisfactory (if it's not ALREADY this) check. They do not actually call changeturf
		// This is safe because this proc can only be run during mapload, and nothing has initialized by now so there's nothing to inherit or delete
		if(!istype(cardinal_canidate, logged_turf_type) && cardinal_canidate.ChangeTurf(type, baseturfs, CHANGETURF_SKIP) && rng.chance(probability))
			if(baseturfs)
				cardinal_canidate.baseturfs = baseturfs
			cardinal_canidate.Spread(probability - prob_loss, prob_loss, whitelisted_area, rng)

	for(var/turf/diagonal_canidate as anything in diagonal_turfs) //diagonal turfs only sometimes change, but will always spread if changed
		// Important NOTE: SEE ABOVE
		if(!istype(diagonal_canidate, logged_turf_type) && rng.chance(probability) && diagonal_canidate.ChangeTurf(type, baseturfs, CHANGETURF_SKIP))
			if(baseturfs)
				diagonal_canidate.baseturfs = baseturfs
			diagonal_canidate.Spread(probability - prob_loss, prob_loss, whitelisted_area, rng)
		else if(ismineralturf(diagonal_canidate))
			var/turf/closed/mineral/diagonal_mineral = diagonal_canidate
			// SEE ABOVE, THIS IS ONLY VERY RARELY SAFE
			new diagonal_mineral.turf_type(diagonal_mineral)

#undef RANDOM_UPPER_X
#undef RANDOM_UPPER_Y

#undef RANDOM_LOWER_X
#undef RANDOM_LOWER_Y
