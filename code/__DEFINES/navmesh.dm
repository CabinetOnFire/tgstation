// Navigation capability flags used by the navmesh system.
// Stored on /datum/can_pass_info to describe what kind of terrain a pathfinder can traverse.

/// Mover is ground-based; subject to gravity / density checks.
#define NAV_CAP_GROUND  (1<<0)
/// Mover is airborne; can pass through openspace / fly-only connections.
#define NAV_CAP_FLYING  (1<<1)
/// Mover can phase through walls; navmesh bits are bypassed entirely.
#define NAV_CAP_PHASING (1<<2)
