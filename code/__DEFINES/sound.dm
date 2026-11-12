//max channel is 1024. Only go lower from here, because byond tends to pick the first available channel to play sounds on
#define CHANNEL_LOBBYMUSIC 1024
#define CHANNEL_ADMIN 1023
#define CHANNEL_VOX 1022
#define CHANNEL_JUKEBOX 1021
#define CHANNEL_HEARTBEAT 1020 //sound channel for heartbeats
#define CHANNEL_BOSS_MUSIC 1019
#define CHANNEL_AMBIENCE 1018
#define CHANNEL_BUZZ 1017
#define CHANNEL_TRAITOR 1016
#define CHANNEL_CHARGED_SPELL 1015
#define CHANNEL_ELEVATOR 1014
#define CHANNEL_ESCAPEMENU 1013
#define CHANNEL_WEATHER 1012
//THIS SHOULD ALWAYS BE THE LOWEST ONE!
//KEEP IT UPDATED
#define CHANNEL_HIGHEST_AVAILABLE 1011

#define MAX_INSTRUMENT_CHANNELS (128 * 6)

/* Calculates the volume of a sound based on distance
 *
 * https://www.desmos.com/calculator/ing6lxgd0m Update this when changed please
 *
 * Arguments:
 * * volume: The initial volume of the sound being played
 * * distance: How far away the sound is in tiles from the source
 * * falloff_distance: Distance at which falloff begins. Sound is at peak volume (in regards to falloff) aslong as it is in this range.
 * * falloff_exponent: Rate of falloff for the audio. Higher means quicker drop to low volume. Should generally be over 1 to indicate a quick dive to 0 rather than a slow dive.
 * Returns: The max distance of a sound based on audible volume range
 */
#define CALCULATE_SOUND_VOLUME_RATIO(volume, distance, max_distance, falloff_distance, falloff_exponent)\
	((max(distance - falloff_distance, 0) / (max(max_distance, distance) - falloff_distance)) ** (1 / falloff_exponent))

///Default range of a sound.
#define SOUND_RANGE 15
#define MEDIUM_RANGE_SOUND_EXTRARANGE -3
///default extra range for sounds considered to be quieter
#define SHORT_RANGE_SOUND_EXTRARANGE -7
///The range deducted from sound range for things that are considered silent / sneaky
#define SILENCED_SOUND_EXTRARANGE -10
///Percentage of sound's range where no falloff is applied
#define SOUND_DEFAULT_FALLOFF_DISTANCE 0 //Disabled because it doesn't actually have a nice effect, it just makes the jump to fall-off more shocking. maybe delete
///The default exponent of sound falloff
#define SOUND_FALLOFF_EXPONENT 2.5

#define SOUND_MINIMUM_PRESSURE 10

#define INTERACTION_SOUND_RANGE_MODIFIER -3
#define LIQUID_SLOSHING_SOUND_VOLUME 10
#define PICKUP_SOUND_VOLUME 15
#define DROP_SOUND_VOLUME 20
#define EQUIP_SOUND_VOLUME 30
#define HALFWAY_SOUND_VOLUME 50
#define BLOCK_SOUND_VOLUME 70
#define YEET_SOUND_VOLUME 90

#define AMBIENCE_GENERIC "generic"
#define AMBIENCE_HOLY "holy"
#define AMBIENCE_DANGER "danger"
#define AMBIENCE_RUINS "ruins"
#define AMBIENCE_ENGI "engi"
#define AMBIENCE_MINING "mining"
#define AMBIENCE_ICEMOON "icemoon"
#define AMBIENCE_MEDICAL "med"
#define AMBIENCE_VIROLOGY "viro"
#define AMBIENCE_SPOOKY "spooky"
#define AMBIENCE_SPACE "space"
#define AMBIENCE_MAINT "maint"
#define AMBIENCE_AWAY "away"
#define AMBIENCE_REEBE "reebe" //unused
#define AMBIENCE_CREEPY "creepy" //not to be confused with spooky

//default byond sound environments
#define SOUND_ENVIRONMENT_NONE -1
#define SOUND_ENVIRONMENT_GENERIC 0
#define SOUND_ENVIRONMENT_PADDED_CELL 1
#define SOUND_ENVIRONMENT_ROOM 2
#define SOUND_ENVIRONMENT_BATHROOM 3
#define SOUND_ENVIRONMENT_LIVINGROOM 4
#define SOUND_ENVIRONMENT_STONEROOM 5
#define SOUND_ENVIRONMENT_AUDITORIUM 6
#define SOUND_ENVIRONMENT_CONCERT_HALL 7
#define SOUND_ENVIRONMENT_CAVE 8
#define SOUND_ENVIRONMENT_ARENA 9
#define SOUND_ENVIRONMENT_HANGAR 10
#define SOUND_ENVIRONMENT_CARPETED_HALLWAY 11
#define SOUND_ENVIRONMENT_HALLWAY 12
#define SOUND_ENVIRONMENT_STONE_CORRIDOR 13
#define SOUND_ENVIRONMENT_ALLEY 14
#define SOUND_ENVIRONMENT_FOREST 15
#define SOUND_ENVIRONMENT_CITY 16
#define SOUND_ENVIRONMENT_MOUNTAINS 17
#define SOUND_ENVIRONMENT_QUARRY 18
#define SOUND_ENVIRONMENT_PLAIN 19
#define SOUND_ENVIRONMENT_PARKING_LOT 20
#define SOUND_ENVIRONMENT_SEWER_PIPE 21
#define SOUND_ENVIRONMENT_UNDERWATER 22
#define SOUND_ENVIRONMENT_DRUGGED 23
#define SOUND_ENVIRONMENT_DIZZY 24
#define SOUND_ENVIRONMENT_PSYCHOTIC 25

/// A sound environment value below -1 explicitly disables environmental audio (BYOND 515+).
/// SOUND_ENVIRONMENT_NONE remains -1 because existing callers use it as an "inherit" sentinel.
#define SOUND_ENVIRONMENT_DISABLED -2

/// Indices into BYOND's 23-value /sound.environment list.
#define SOUND_ENVIRONMENT_INDEX_SIZE 1
#define SOUND_ENVIRONMENT_INDEX_DIFFUSION 2
#define SOUND_ENVIRONMENT_INDEX_ROOM 3
#define SOUND_ENVIRONMENT_INDEX_ROOM_HF 4
#define SOUND_ENVIRONMENT_INDEX_ROOM_LF 5
#define SOUND_ENVIRONMENT_INDEX_DECAY_TIME 6
#define SOUND_ENVIRONMENT_INDEX_DECAY_HF_RATIO 7
#define SOUND_ENVIRONMENT_INDEX_DECAY_LF_RATIO 8
#define SOUND_ENVIRONMENT_INDEX_REFLECTIONS 9
#define SOUND_ENVIRONMENT_INDEX_REFLECTIONS_DELAY 10
#define SOUND_ENVIRONMENT_INDEX_REVERB 11
#define SOUND_ENVIRONMENT_INDEX_REVERB_DELAY 12
#define SOUND_ENVIRONMENT_INDEX_ECHO_TIME 13
#define SOUND_ENVIRONMENT_INDEX_ECHO_DEPTH 14
#define SOUND_ENVIRONMENT_INDEX_MODULATION_TIME 15
#define SOUND_ENVIRONMENT_INDEX_MODULATION_DEPTH 16
#define SOUND_ENVIRONMENT_INDEX_AIR_ABSORPTION_HF 17
#define SOUND_ENVIRONMENT_INDEX_HF_REFERENCE 18
#define SOUND_ENVIRONMENT_INDEX_LF_REFERENCE 19
#define SOUND_ENVIRONMENT_INDEX_ROOM_ROLLOFF_FACTOR 20
#define SOUND_ENVIRONMENT_INDEX_DIFFUSION_PERCENT 21
#define SOUND_ENVIRONMENT_INDEX_DENSITY 22
#define SOUND_ENVIRONMENT_INDEX_FLAGS 23
#define SOUND_ENVIRONMENT_LIST_LENGTH SOUND_ENVIRONMENT_INDEX_FLAGS

/// /sound.environment flags. These are all eight documented EAX2 scaling switches.
#define SOUND_ENVIRONMENT_FLAG_DECAY_TIME_SCALE (1<<0)
#define SOUND_ENVIRONMENT_FLAG_REFLECTIONS_SCALE (1<<1)
#define SOUND_ENVIRONMENT_FLAG_REFLECTIONS_DELAY_SCALE (1<<2)
#define SOUND_ENVIRONMENT_FLAG_REVERB_SCALE (1<<3)
#define SOUND_ENVIRONMENT_FLAG_REVERB_DELAY_SCALE (1<<4)
#define SOUND_ENVIRONMENT_FLAG_AIR_ABSORPTION_HF_DECAY_HF_RATIO (1<<5)
#define SOUND_ENVIRONMENT_FLAG_ECHO_TIME_SCALE (1<<6)
#define SOUND_ENVIRONMENT_FLAG_MODULATION_TIME_SCALE (1<<7)

/// Indices into BYOND's 18-value /sound.echo list.
#define SOUND_ECHO_INDEX_DIRECT 1
#define SOUND_ECHO_INDEX_DIRECT_HF 2
#define SOUND_ECHO_INDEX_ROOM 3
#define SOUND_ECHO_INDEX_ROOM_HF 4
#define SOUND_ECHO_INDEX_OBSTRUCTION 5
#define SOUND_ECHO_INDEX_OBSTRUCTION_LF_RATIO 6
#define SOUND_ECHO_INDEX_OCCLUSION 7
#define SOUND_ECHO_INDEX_OCCLUSION_LF_RATIO 8
#define SOUND_ECHO_INDEX_OCCLUSION_ROOM_RATIO 9
#define SOUND_ECHO_INDEX_OCCLUSION_DIRECT_RATIO 10
#define SOUND_ECHO_INDEX_EXCLUSION 11
#define SOUND_ECHO_INDEX_EXCLUSION_LF_RATIO 12
#define SOUND_ECHO_INDEX_OUTSIDE_VOLUME_HF 13
#define SOUND_ECHO_INDEX_DOPPLER_FACTOR 14
#define SOUND_ECHO_INDEX_ROLLOFF_FACTOR 15
#define SOUND_ECHO_INDEX_ROOM_ROLLOFF_FACTOR 16
#define SOUND_ECHO_INDEX_AIR_ABSORPTION_FACTOR 17
#define SOUND_ECHO_INDEX_FLAGS 18
#define SOUND_ECHO_LIST_LENGTH SOUND_ECHO_INDEX_FLAGS

/// /sound.echo flags. Defaults enable distance-based Direct, Room, and RoomHF adjustments.
#define SOUND_ECHO_FLAG_AUTO_DIRECT (1<<0)
#define SOUND_ECHO_FLAG_AUTO_ROOM (1<<1)
#define SOUND_ECHO_FLAG_AUTO_ROOM_HF (1<<2)
#define SOUND_ECHO_DEFAULT_FLAGS (SOUND_ECHO_FLAG_AUTO_DIRECT | SOUND_ECHO_FLAG_AUTO_ROOM | SOUND_ECHO_FLAG_AUTO_ROOM_HF)

//If we ever make custom ones add them here
#define SOUND_ENVIROMENT_PHASED list(1.8, 0.5, -1000, -4000, 0, 5, 0.1, 1, -15500, 0.007, 2000, 0.05, 0.25, 1, 1.18, 0.348, -5, 2000, 250, 0, 3, 100, 63)

//"sound areas": easy way of keeping different types of areas consistent.
#define SOUND_AREA_STANDARD_STATION SOUND_ENVIRONMENT_PARKING_LOT
#define SOUND_AREA_LARGE_ENCLOSED SOUND_ENVIRONMENT_QUARRY
#define SOUND_AREA_SMALL_ENCLOSED SOUND_ENVIRONMENT_BATHROOM
#define SOUND_AREA_TUNNEL_ENCLOSED SOUND_ENVIRONMENT_STONEROOM
#define SOUND_AREA_LARGE_SOFTFLOOR SOUND_ENVIRONMENT_CARPETED_HALLWAY
#define SOUND_AREA_MEDIUM_SOFTFLOOR SOUND_ENVIRONMENT_LIVINGROOM
#define SOUND_AREA_SMALL_SOFTFLOOR SOUND_ENVIRONMENT_ROOM
#define SOUND_AREA_ASTEROID SOUND_ENVIRONMENT_CAVE
#define SOUND_AREA_SPACE SOUND_ENVIRONMENT_UNDERWATER
#define SOUND_AREA_LAVALAND SOUND_ENVIRONMENT_MOUNTAINS
#define SOUND_AREA_ICEMOON SOUND_ENVIRONMENT_CAVE
#define SOUND_AREA_WOODFLOOR SOUND_ENVIRONMENT_CITY


///Announcer audio keys
#define ANNOUNCER_AIMALF "announcer_aimalf"
#define ANNOUNCER_ALIENS "announcer_aliens"
#define ANNOUNCER_ANIMES "announcer_animes"
#define ANNOUNCER_GRANOMALIES "announcer_granomalies"
#define ANNOUNCER_INTERCEPT "announcer_intercept"
#define ANNOUNCER_IONSTORM "announcer_ionstorm"
#define ANNOUNCER_METEORS "announcer_meteors"
#define ANNOUNCER_OUTBREAK5 "announcer_outbreak5"
#define ANNOUNCER_OUTBREAK7 "announcer_outbreak7"
#define ANNOUNCER_POWEROFF "announcer_poweroff"
#define ANNOUNCER_POWERON "announcer_poweron"
#define ANNOUNCER_RADIATION "announcer_radiation"
#define ANNOUNCER_SHUTTLECALLED "announcer_shuttlecalled"
#define ANNOUNCER_SHUTTLEDOCK "announcer_shuttledock"
#define ANNOUNCER_SHUTTLERECALLED "announcer_shuttlerecalled"
#define ANNOUNCER_SPANOMALIES "announcer_spanomalies"

/// Global list of all of our announcer keys.
GLOBAL_LIST_INIT(announcer_keys, list(
	ANNOUNCER_AIMALF,
	ANNOUNCER_ALIENS,
	ANNOUNCER_ANIMES,
	ANNOUNCER_GRANOMALIES,
	ANNOUNCER_INTERCEPT,
	ANNOUNCER_IONSTORM,
	ANNOUNCER_METEORS,
	ANNOUNCER_OUTBREAK5,
	ANNOUNCER_OUTBREAK7,
	ANNOUNCER_POWEROFF,
	ANNOUNCER_POWERON,
	ANNOUNCER_RADIATION,
	ANNOUNCER_SHUTTLECALLED,
	ANNOUNCER_SHUTTLEDOCK,
	ANNOUNCER_SHUTTLERECALLED,
	ANNOUNCER_SPANOMALIES,
))

// Standard is 44.1khz
#define MIN_EMOTE_PITCH 40000
#define MAX_EMOTE_PITCH 48000
// ~0.6 - 1.4 at 0.12
#define EMOTE_TTS_PITCH_MULTIPLIER 0.12
