/**
 * Navmesh baked pathfinding system.
 *
 * Each turf stores precomputed connection bitmasks (nav_ground_connections, nav_all_connections)
 * and an optional list of /datum/nav_gate entries for conditional blockers (doors, windows, etc.).
 *
 * The navmesh is built/rebuilt by SSnavmesh during world init and updated lazily via dirty_turfs.
 *
 * Use NAV_CAN_STEP (see code/__DEFINES/path.dm) to query the navmesh.
 */

// ────────────────────────────────────────────────────────────
// /datum/nav_gate — represents a conditional blocker for one
// direction on a source turf.
// ────────────────────────────────────────────────────────────

/**
 * A gate datum attached to a source turf that describes a blocker in a specific direction.
 *
 * Type A: static pass_flags blocker (windows, railings).
 *   Cleared if pass_info.pass_flags & blocker_pass_flags_self.
 *
 * Type B: dynamic CanAStarPass blocker (doors, border firedoors).
 *   is_open is cached from COMSIG_ATOM_DENSITY_CHANGED on the blocker.
 *   If is_open, the gate is immediately cleared.
 *   Otherwise CanAStarPass is called with the live pass_info.
 */
/datum/nav_gate
	/// Which direction from the source turf this gate controls (a cardinal or diagonal direction bit)
	var/dir
	/// Which direction to pass to CanAStarPass. May differ from dir for destination-side blockers.
	var/check_dir
	/// Weakref to the blocking object
	var/datum/weakref/blocker
	/// Type A: copy of blocker.pass_flags_self at build time. 0 for Type B.
	var/blocker_pass_flags_self = 0
	/// TRUE = Type A (pass_flags check). FALSE = Type B (CanAStarPass call).
	var/is_type_a = FALSE
	/// Type B only: cached open/closed state. Updated via COMSIG_ATOM_DENSITY_CHANGED.
	var/is_open = FALSE

/datum/nav_gate/Destroy(force)
	if(!is_type_a)
		var/obj/blocker_obj = blocker?.resolve()
		if(blocker_obj)
			UnregisterSignal(blocker_obj, COMSIG_ATOM_DENSITY_CHANGED)
	blocker = null
	return ..()

/// Called when the backing blocker atom changes density. Updates is_open to match.
/datum/nav_gate/proc/handle_blocker_density_changed(atom/source)
	SIGNAL_HANDLER
	is_open = !source.density


// ────────────────────────────────────────────────────────────
// Gate query
// ────────────────────────────────────────────────────────────

/**
 * Returns TRUE if all gates on T for the given direction permit passage with pass_info.
 * Returns FALSE as soon as any gate blocks.
 *
 * Called from NAV_CAN_STEP when T.nav_gates is non-null.
 */
/proc/navmesh_check_gates(turf/T, dir, datum/can_pass_info/pass_info)
	for(var/datum/nav_gate/gate as anything in T.nav_gates)
		if(gate.dir != dir)
			continue

		if(gate.is_type_a)
			// Type A: cleared if mover has the required pass_flags
			if(!(pass_info.pass_flags & gate.blocker_pass_flags_self))
				return FALSE
		else
			// Type B: short-circuit on is_open, otherwise ask the blocker
			if(gate.is_open)
				continue
			var/obj/blocker_obj = gate.blocker?.resolve()
			if(!blocker_obj || QDELETED(blocker_obj))
				// Stale gate — blocker is gone; queue a turf rebuild and assume clear
				SSnavmesh.invalidate_turf(T)
				continue
			if(!blocker_obj.CanAStarPass(gate.check_dir, pass_info))
				return FALSE

	return TRUE


// ────────────────────────────────────────────────────────────
// Build logic
// ────────────────────────────────────────────────────────────

/// Typecache of directional border object types that must be checked in source-turf pass evaluation
GLOBAL_LIST_INIT(navmesh_dir_blocker_cache, typecacheof(list(
	/obj/structure/window,
	/obj/machinery/door/window,
	/obj/structure/railing,
	/obj/machinery/door/firedoor/border_only,
)))

/**
 * Builds (or rebuilds) the navmesh for a single turf.
 * Clears existing connection bits and gates, then recomputes from scratch.
 */
/proc/navmesh_build_turf(turf/T)
	// Clear previous data
	T.nav_ground_connections = 0
	T.nav_all_connections = 0

	if(T.nav_gates)
		for(var/datum/nav_gate/gate as anything in T.nav_gates)
			qdel(gate)
		T.nav_gates = null

	// Space turfs are destinations, not sources — skip their content checks
	if(SSnavmesh.space_type_cache[T.type])
		return

	// Build cardinal directions first; diagonal bits depend on cardinal results
	for(var/dir in list(NORTH, SOUTH, EAST, WEST))
		_navmesh_build_cardinal(T, dir)

	// Diagonal bits: set only when both cardinal components are already traversable.
	// The real diagonal check (LinkBlockedWithAccess) says a diagonal is unblocked if
	// at LEAST ONE midstep path is clear — our conservative approximation is to require
	// both cardinals from T to be open, which is correct for the vast majority of maps.
	_navmesh_build_diagonals(T)


/**
 * Evaluates one cardinal direction and sets the appropriate connection bits + gates on T.
 */
/proc/_navmesh_build_cardinal(turf/T, dir)
	var/turf/N = get_step(T, dir)
	if(!N)
		return

	// Space is a permanent block for both movement types
	if(SSnavmesh.space_type_cache[N.type])
		return

	// Check destination turf traversability
	var/ground_ok = TRUE
	switch(N.pathing_pass_method)
		if(TURF_PATHING_PASS_NO)
			return  // hard block, no bits set
		if(TURF_PATHING_PASS_PROC)
			// Only /turf/open/openspace uses this currently.
			// Ground movers fall through openspace; flying movers hover over it.
			ground_ok = FALSE
			// fly_ok stays TRUE — set nav_all_connections bit below
		// TURF_PATHING_PASS_DENSITY (default) falls through here
		else
			if(N.density)
				return  // dense wall, hard block

	// Evaluate blocking objects.
	// Returns FALSE if a permanent (non-gate) blocker is found; TRUE if bits should be set.
	var/list/built_gates = null
	var/list/navmesh_dir_blocker_cache = GLOB.navmesh_dir_blocker_cache
	var/reverse_dir = REVERSE_DIR(dir)

	// Source-side: directional border objects (windows, railings, border firedoors).
	// For CANASTARPASS_ALWAYS_PROC objects we always create a gate (even when currently open)
	// so that density changes later are caught by the gate's signal handler.
	for(var/obj/border as anything in T.contents)
		if(!navmesh_dir_blocker_cache[border.type])
			continue
		if(!border.density && border.can_astar_pass == CANASTARPASS_DENSITY)
			continue  // non-dense density-type, never blocks

		if(border.can_astar_pass == CANASTARPASS_ALWAYS_PROC)
			// Dynamic — always gate regardless of current state
			var/result = _navmesh_make_gate(border, dir, dir, built_gates)
			if(result == FALSE)
				return
			built_gates = result
			continue

		// CANASTARPASS_DENSITY: check if it actually blocks this direction right now
		if(border.CanAStarPass(dir, SSnavmesh.null_pass_info))
			continue  // doesn't block this direction

		var/result = _navmesh_make_gate(border, dir, dir, built_gates)
		if(result == FALSE)
			return
		built_gates = result

	// Destination-side: dense objects or CANASTARPASS_ALWAYS_PROC objects on N.
	// Same logic: ALWAYS_PROC gets a gate even if currently open.
	for(var/obj/iter_obj as anything in N.contents)
		if(!iter_obj.density && iter_obj.can_astar_pass == CANASTARPASS_DENSITY)
			continue  // non-dense density-type, never blocks

		if(iter_obj.can_astar_pass == CANASTARPASS_ALWAYS_PROC)
			// Dynamic — always gate regardless of current state
			var/result = _navmesh_make_gate(iter_obj, dir, reverse_dir, built_gates)
			if(result == FALSE)
				return
			built_gates = result
			continue

		// CANASTARPASS_DENSITY: check if it actually blocks in the reverse direction
		if(iter_obj.CanAStarPass(reverse_dir, SSnavmesh.null_pass_info))
			continue  // doesn't block

		var/result = _navmesh_make_gate(iter_obj, dir, reverse_dir, built_gates)
		if(result == FALSE)
			return
		built_gates = result

	// ── Commit ──────────────────────────────────────────────
	if(built_gates)
		if(!T.nav_gates)
			T.nav_gates = list()
		T.nav_gates += built_gates

	if(ground_ok)
		T.nav_ground_connections |= dir
	T.nav_all_connections |= dir  // openspace: ground_ok=FALSE but fly bit still set


/**
 * Creates an appropriate gate datum for one blocking object.
 *
 * gate_dir  - the direction from T that this gate guards
 * check_dir - the direction to pass to CanAStarPass at runtime
 * existing  - list of already-created gates to append to (may be null)
 *
 * Returns:
 *   FALSE      - permanent blocker; caller should abort the connection entirely
 *   list       - updated (or newly created) gate list
 */
/proc/_navmesh_make_gate(obj/blocker, gate_dir, check_dir, list/existing)
	var/datum/nav_gate/gate = new()
	gate.dir = gate_dir
	gate.check_dir = check_dir
	gate.blocker = WEAKREF(blocker)

	if(blocker.can_astar_pass == CANASTARPASS_ALWAYS_PROC)
		// Type B: dynamic — track density changes to maintain is_open cache
		gate.is_type_a = FALSE
		gate.is_open = !blocker.density
		gate.RegisterSignal(blocker, COMSIG_ATOM_DENSITY_CHANGED, TYPE_PROC_REF(/datum/nav_gate, handle_blocker_density_changed))
	else
		// CANASTARPASS_DENSITY — object is dense (otherwise it wouldn't have blocked above)
		if(blocker.pass_flags_self)
			// Type A: passable with correct pass_flags
			gate.is_type_a = TRUE
			gate.blocker_pass_flags_self = blocker.pass_flags_self
		else
			// No bypass at all — this is a permanent hard block
			qdel(gate)
			return FALSE

	var/list/result = existing || list()
	result += gate
	return result


/**
 * Sets diagonal connection bits on T based on already-computed cardinal bits.
 * A diagonal D is available if both component cardinal directions from T are available.
 */
/proc/_navmesh_build_diagonals(turf/T)
	var/ground = T.nav_ground_connections
	var/all = T.nav_all_connections

	// NORTHEAST: needs NORTH and EAST
	if((all & NORTH) && (all & EAST))
		if((ground & NORTH) && (ground & EAST))
			T.nav_ground_connections |= NORTHEAST
		T.nav_all_connections |= NORTHEAST

	// NORTHWEST: needs NORTH and WEST
	if((all & NORTH) && (all & WEST))
		if((ground & NORTH) && (ground & WEST))
			T.nav_ground_connections |= NORTHWEST
		T.nav_all_connections |= NORTHWEST

	// SOUTHEAST: needs SOUTH and EAST
	if((all & SOUTH) && (all & EAST))
		if((ground & SOUTH) && (ground & EAST))
			T.nav_ground_connections |= SOUTHEAST
		T.nav_all_connections |= SOUTHEAST

	// SOUTHWEST: needs SOUTH and WEST
	if((all & SOUTH) && (all & WEST))
		if((ground & SOUTH) && (ground & WEST))
			T.nav_ground_connections |= SOUTHWEST
		T.nav_all_connections |= SOUTHWEST
