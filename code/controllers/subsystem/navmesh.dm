/**
 * SSnavmesh — baked navigation mesh subsystem.
 *
 * Responsibilities:
 *  1. On world init: build navmesh data for every non-space turf (timesliced).
 *  2. After init: drain the dirty_turfs queue (timesliced), rebuilding stale turfs.
 *  3. Expose invalidate_turf() for event-driven invalidation from density changes etc.
 *
 * Pathfinding datums should NOT query the navmesh until navmesh_ready = TRUE.
 */
SUBSYSTEM_DEF(navmesh)
	name = "Navmesh"
	priority = FIRE_PRIORITY_NAVMESH
	wait = 0.5

	/// TRUE once the initial full build pass is complete
	var/navmesh_ready = FALSE

	/// Assoc set of turfs that need rebuilding: turf -> TRUE
	var/list/dirty_turfs

	/// Flat list of all non-space, non-null turfs to build on init
	var/list/all_buildable_turfs

	/// Current position in all_buildable_turfs during the initial build pass
	var/build_index = 1

	/// A /datum/can_pass_info with zero pass_flags/access used during build-time CanAStarPass checks
	var/datum/can_pass_info/null_pass_info

	/// Typecache of space turf types — matches SSpathfinder's cache
	var/list/space_type_cache


/datum/controller/subsystem/navmesh/Initialize()
	space_type_cache = typecacheof(/turf/open/space)
	null_pass_info = new(null)
	dirty_turfs = list()

	// Gather all buildable turfs. Space turfs never have content-based gates and
	// their nav bits are always 0, so we skip them here.
	all_buildable_turfs = list()
	for(var/turf/T in world)
		if(!space_type_cache[T.type])
			navmesh_build_turf(T)

	return SS_INIT_SUCCESS


/datum/controller/subsystem/navmesh/stat_entry(msg)
	if(navmesh_ready)
		msg = "Dirty:[length(dirty_turfs)]"
	else
		msg = "Building:[build_index]/[length(all_buildable_turfs)]"
	return ..()


/datum/controller/subsystem/navmesh/fire(resumed)
	if(!navmesh_ready)
		_fire_initial_build()
	else
		_fire_dirty_drain()


/// Initial full-build pass: process a slice of all_buildable_turfs each tick
/datum/controller/subsystem/navmesh/proc/_fire_initial_build()
	var/list/build_list = all_buildable_turfs

	while(build_index <= length(build_list))
		navmesh_build_turf(build_list[build_index])
		build_index++

		if(MC_TICK_CHECK)
			return

	// Done with the initial build
	navmesh_ready = TRUE
	all_buildable_turfs = null  // free memory


/// Dirty drain pass: rebuild turfs queued by invalidate_turf()
/datum/controller/subsystem/navmesh/proc/_fire_dirty_drain()
	if(!length(dirty_turfs))
		return

	// Snapshot into a list of keys so new additions don't interfere with this tick
	var/list/pending = dirty_turfs.Copy()
	dirty_turfs.Cut()

	for(var/i in 1 to length(pending))
		var/turf/T = pending[i]
		if(!T || QDELETED(T))
			continue
		navmesh_build_turf(T)

		if(MC_TICK_CHECK)
			// Requeue anything we didn't get to
			for(var/j in (i + 1) to length(pending))
				dirty_turfs[pending[j]] = TRUE
			return


/// Mark a turf and its 8 neighbors as needing a navmesh rebuild.
/// Safe to call at any time (before or after navmesh_ready).
/datum/controller/subsystem/navmesh/proc/invalidate_turf(turf/T)
	if(!T)
		return
	dirty_turfs[T] = TRUE
	// Neighbors also need rebuilding because their diagonal bits reference T's cardinals,
	// and because gates on neighboring turfs may point to objects on T.
	for(var/dir in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/turf/neighbor = get_step(T, dir)
		if(neighbor)
			dirty_turfs[neighbor] = TRUE
