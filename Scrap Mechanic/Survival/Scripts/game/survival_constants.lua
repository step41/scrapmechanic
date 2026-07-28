dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/poi_types.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_logs.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )

-- Debug printing
DEBUG_AI_STATES = false

-- Namespace storage channels
STORAGE_CHANNEL_WAREHOUSES = 10
STORAGE_CHANNEL_ELEVATORS = 11
STORAGE_CHANNEL_FIRE = 12
STORAGE_CHANNEL_SPAWNERS = 13
--STORAGE_CHANNEL_WAYPOINT_WAITLIST = 14 Deprecated, No longer used
STORAGE_CHANNEL_BEDS = 15
STORAGE_CHANNEL_TIME = 16
STORAGE_CHANNEL_UNIT_MANAGER = 17
--STORAGE_CHANNEL_SEED_SPAWNS = 18 -- Deprecated, seed spawn are now handeled through scriptable object
STORAGE_CHANNEL_BAGS = 19
--STORAGE_CHANNEL_CROP_ATTACK_CELLS = 20 -- Deprecated, raids are stored in STORAGE_CHANNEL_RAIDMANAGER
STORAGE_CHANNEL_HAYBOT_SPAWNS = 21
STORAGE_CHANNEL_TOTEBOT_GREEN_SPAWNS = 22
STORAGE_CHANNEL_TAPEBOT_SPAWNS = 23
STORAGE_CHANNEL_FARMBOT_SPAWNS = 24
STORAGE_CHANNEL_WOC_SPAWNS = 25
STORAGE_CHANNEL_GLOWGORP_SPAWNS = 26
STORAGE_CHANNEL_LOOTCRATE_SPAWNS = 27
STORAGE_CHANNEL_RUINCHEST_SPAWNS = 28
--STORAGE_CHANNEL_GAS_SPAWNS = 29 -- Deprecated, No longer used
STORAGE_CHANNEL_FARMERBALL_SPAWNS = 30
STORAGE_CHANNEL_EPICLOOTCRATE_SPAWNS = 31
STORAGE_CHANNEL_FOREIGN_CONNECTIONS = 32
--STORAGE_CHANNEL_WAYPOINT_CELLS = 33 --Deprecated, all worlds use navmesh by default
STORAGE_CHANNEL_PERMANENT_BEDS = 34
STORAGE_CHANNEL_BEACONS = 35
--STORAGE_CHANNEL_QUESTS = 36 -- Deprecated, quests are stored in the QuestManager
STORAGE_CHANNEL_LOCATIONS = 37 -- Written by world generation
--STORAGE_CHANNEL_CELL_TILE_STORAGE_KEYS = 38
STORAGE_CHANNEL_KINEMATIC_STATE = 39
--STORAGE_CHANNEL_COMPLEX_AIRLOCK = 40
STORAGE_CHANNEL_UNDERGROUND_WORLDS = 41
STORAGE_CHANNEL_CABLEBOT_SPAWNS = 42
STORAGE_CHANNEL_DOUSED_NAMED_FIRES = 43
STORAGE_CHANNEL_QUESTMANAGER = 44
STORAGE_CHANNEL_RAIDMANAGER = 45
STORAGE_CHANNEL_QUESTENTITYMANAGER = 46
STORAGE_CHANNEL_TAPEBOT_GREEN_SPAWNS = 47
STORAGE_CHANNEL_TAPEBOT_YELLOW_SPAWNS = 48
STORAGE_CHANNEL_RECIPEMANAGER = 49
--STORAGE_CHANNEL_WAREHOUSEEXPLOSION = 50 -- Warehouse Explosion Manager no longer saves anything.
STORAGE_CHANNEL_DIALOGMANAGER = 51
STORAGE_CHANNEL_UNDERGROUND_ELEVATORS = 52
STORAGE_CHANNEL_MINIDUNGEON_ELEVATORS = 53
STORAGE_CHANNEL_MINIDUNGEON_CONNECTIONS = 54
STORAGE_CHANNEL_DEBUG_MARKERS = 55
STORAGE_CHANNEL_QUEST_SPAWN_MANAGER = 56
STORAGE_CHANNEL_ACTIVATED_FIRES = 57
STORAGE_CHANNEL_SCANNERBOT_MANAGER = 58
STORAGE_CHANNEL_DYNAMIC_COMABT_MANAGER = 59
STORAGE_CHANNEL_LOGS = 60
STORAGE_CHANNEL_PATROLMANAGER = 61
STORAGE_CHANNEL_MINERBOT_SPAWNS = 62
STORAGE_CHANNEL_WEATHER = 63
STORAGE_CHANNEL_LEGENDARYLOOTCRATE_SPAWNS = 64
STORAGE_CHANNEL_COMBATROOM_MANAGER = 65
STORAGE_CHANNEL_DRILLBOT_PREFABS = 66
STORAGE_CHANNEL_TOTEBOT_BLUE_SPAWNS = 67
STORAGE_CHANNEL_PRECACHED_MARKERS = 68
STORAGE_CHANNEL_GLOWSTICK_MANAGER = 69
STORAGE_CHANNEL_MININGHUB_LIGHTS = 70
STORAGE_CHANNEL_TOTEBOT_RED_SPAWNS = 71
STORAGE_CHANNEL_TOTEBOT_YELLOW_SPAWNS = 72
STORAGE_CHANNEL_ELEVATOR_LOCATIONS = 73
STORAGE_CHANNEL_GARAGE_IMPORT_MANAGER = 74
STORAGE_CHANNEL_BUILDERGUIDE_SCRAPPER_SPAWNS = 75
STORAGE_CHANNEL_BUILDERGUIDE_FARMER_SPAWNS = 76
STORAGE_CHANNEL_BUILDERGUIDE_TOTEBOT_SPAWNS = 77
STORAGE_CHANNEL_BUILDERGUIDE_GLOWGORP_SPAWNS = 78
STORAGE_CHANNEL_PROGRESSION_MANAGER = 79
STORAGE_CHANNEL_TAPEBOT_RED_SPAWNS = 80
STORAGE_CHANNEL_DRILLBOT_MANAGER = 81
STORAGE_CHANNEL_DRILLBOT_WORLD = 82
STORAGE_CHANNEL_TOTEBOT_LEAF_SPAWNS = 83
STORAGE_CHANNEL_ATTACHED_LOOT_MANAGER = 84
STORAGE_CHANNEL_EXPLOSION_MANAGER = 85
STORAGE_CHANNEL_SEEDBOT_SPAWNS = 86
STORAGE_CHANNEL_KINEMATICMANAGER = 87
STORAGE_CHANNEL_WAYPOINTQUESTUNIT_MANAGER = 88
STORAGE_CHANNEL_AREA_REACTION_MANAGER = 89
STORAGE_CHANNEL_PACKINGSTATION_MANAGER = 90
STORAGE_CHANNEL_TRADER_INFORMATION = 91

STORAGE_CHANNEL_TORNADO_MANAGER = 92
STORAGE_CHANNEL_BUILDERGUIDE_WOC_SPAWNS = 93
STORAGE_CHANNEL_BUILDERGUIDE_FARMERSLEEPY_SPAWNS = 94
STORAGE_CHANNEL_BUILDERGUIDE_FARMERKO_SPAWNS = 95
STORAGE_CHANNEL_MINERALMINING_MANAGER = 96
STORAGE_CHANNEL_CINEMATIC_DRILLBOT_SPAWNS = 97 -- TODO: remove this when the correct setup of drillbot cinematic spawns is done
STORAGE_CHANNEL_BABYWOC_MANAGER = 98
STORAGE_CHANNEL_QUEST_ACTOR_MANAGER = 99
STORAGE_CHANNEL_WORLD_MANAGER = 100
STORAGE_CHANNEL_BONDBUILDER_EXCLUSION_TILES = 101 -- Written by world generation

LUA_TYPE = sm.types

-- Select player spawn point
START_AREA_SPAWN_POINT = sm.vec3.new( -2336, -2592, 16 )













SURVIVAL_DEV_SPAWN_POINT = START_AREA_SPAWN_POINT


DAYCYCLE_TIME = 1440.0 -- seconds (24 minutes)
DAYCYCLE_TIME_TICKS = DAYCYCLE_TIME * 40
GAME_START_TIME = ( 8 / 24 ) -- 08:00
GAME_START_TIME_TICKS = DAYCYCLE_TIME_TICKS * GAME_START_TIME

function DaysInTicks( days ) return days * DAYCYCLE_TIME_TICKS end

DAYCYCLE_DAWN = 0.21 -- ~ 5 / 24
DAYCYCLE_NOON = 12 / 24 -- 0.5
DAYCYCLE_NIGHT = 21 / 24 -- 0.875
DAYCYCLE_SOUND_TIMES = { 0, 3 / 24, 6 / 24, 18 / 24, 21 / 24, 1 }
DAYCYCLE_SOUND_VALUES = { 1, 1, 0, 0, 1, 1 }
assert( #DAYCYCLE_SOUND_TIMES == #DAYCYCLE_SOUND_VALUES )

DAYCYCLE_LIGHTING_TIMES = { 0, 2 / 24, 6 / 24, 18 / 24, 22 / 24, 1 }
DAYCYCLE_LIGHTING_VALUES = { 0, 0, 0.5, 0.5, 1, 1 }
assert( #DAYCYCLE_LIGHTING_TIMES == #DAYCYCLE_LIGHTING_VALUES )

CELL_SIZE = 64

DURATION_PER_PIPE = 0.025
PIPE_MINIMUM_DURATION = 2.0

AUDIO_MASS_DIVIDE_RATIO = 76800

BUSY_NOTIFICATION_DURATION = 1.5

HEIGHT_DISTANCE_MULTIPLIER = 3.75
AIR_TICK_TIME_TO_TUMBLE = 20
DEFAULT_TUMBLE_TICK_TIME = 40
DEFAULT_CRUSH_TICK_TIME = 8

MAX_CHARACTER_KNOCKBACK_VELOCITY = 50.0

CUTSCENE_FADE_IN_TIME = 0.5 -- Seconds
CUTSCENE_FADE_OUT_TIME = 1.0 -- Seconds

KINEMATIC_EVENTTRIGGER_TABLE = "persistentKinematicActivations"
KEY_LOCK_TABLE = "unlockTagFlags"
KEY_LOCK_COUNTER_TABLE = "keyLockCount"
KINEMATIC_ROOT_NAME_TABLE = "parentedKinematicRootNames"
TILESTORAGE_FLAGS_TABLE = "tilestorageTagFlags"
KINEMATIC_STORAGE_TABLE = "kinematicStorage"
DRILLBOT_KINEMATICS_TABLE = "drillbotKinematicsStorage"
BUILDERGUIDE_PLATFORM_TABLE = "builderGuidePlatform"
KINEMATIC_SPINNER_DOOR_TABLE = "kinematicSpinnerDoor"
MINIDUNGEON_ELEVATOR_TABLE = "minidungeonElevator"
UNDERGROUND_ELEVATOR_TABLE = "undergroundElevator"
TILE_ELEVATOR_TABLE = "tileElevator"
NON_PLAYER_CRAFTER_TABLE = "nonPlayerCrafter"
MININGHUB_POWER_ACTIVATOR_TABLE = "mininghubPowerActivator"
SURPRISE_SPAWNER_TABLE = "surpriseSpawners"
POWER_CORE_SOCKET_TABLE = "powerCoreSocket"
PATROL_WAIT_TABLE = "patrolWait"
MININGHUB_CRAFTERS_TABLE = "mininghubCrafters"
POWERLADDER_RAIL_TABLE = "powerLadderRails"

-- Sync
SYNC_KEY = "sync"

-- Warehouse
CELL_TAG_TO_WAREHOUSE_FLOORS = { ["WAREHOUSE2"] = 2, ["WAREHOUSE3"] = 3, ["WAREHOUSE4"] = 4, ["POI_TEST"] = 1, ["WAREHOUSE4QUEST"] = 4 }

WAREHOUSE_DESTRUCTION_TICKS = 40 * 60 * 5 -- 5 minutes

LIMITED_LOOT_DEFAULT_LIMIT = 5

-- Ordered HexStr colors selectable from the paint-tool
-- NOTE: first entry is a deliberate egregious test color (bright magenta) standing in for the
-- original "eeeeeeff" - confirms in-game whether the paint tool is actually reading this array
-- at all before we trust the 88 newly appended colors below. Revert to "eeeeeeff" once confirmed.
PAINT_COLORS =
{
	"ff00ffff", "f5f071ff", "cbf66fff", "68ff88ff", "7eededff", "4c6fe3ff", "ae79f0ff", "ee7bf0ff", "f06767ff", "eeaf5cff",
	"7f7f7fff", "e2db13ff", "a0ea00ff", "19e753ff", "2ce6e6ff", "0a3ee2ff", "7514edff", "cf11d2ff", "d02525ff", "df7f00ff",
	"4a4a4aff", "817c00ff", "577d07ff", "0e8031ff", "118787ff", "0f2e91ff", "500aa6ff", "720a74ff", "7c0000ff", "673b00ff",
	"222222ff", "323000ff", "375000ff", "064023ff", "0a4444ff", "0a1d5aff", "35086cff", "520653ff", "560202ff", "472800ff",

	-- Jungle / desert / military vehicle tones (24)
	"4b5320ff", "3b4226ff", "4d5d23ff", "2f3b24ff", "434829ff", "6c541eff", "4b3621ff", "738678ff", "5b6f55ff", "3e4a2eff",
	"556b2fff", "2e3b1fff", "c19a6bff", "c3b091ff", "dccca3ff", "e2c799ff", "7f5539ff", "5c4033ff", "d8c9a3ff", "bfa76fff",
	"a88350ff", "8a7355ff", "2a3439ff", "5c5b4eff",

	-- Muted hue-wheel extension, 16 hues x 4 shades (64) - deliberately desaturated, no neon
	"cda2a2ff", "b04f4fff", "6e3535ff", "3c2020ff", "cdb2a2ff", "b0734fff", "6e4a35ff", "3c2a20ff", "cdc2a2ff", "b0984fff",
	"6e6035ff", "3c3520ff", "c8cda2ff", "a4b04fff", "676e35ff", "383c20ff", "b8cda2ff", "80b04fff", "526e35ff", "2e3c20ff",
	"a8cda2ff", "5bb04fff", "3c6e35ff", "243c20ff", "a2cdadff", "4fb067ff", "356e43ff", "203c27ff", "a2cdbdff", "4fb08cff",
	"356e59ff", "203c31ff", "a2cdcdff", "4fb0b0ff", "356e6eff", "203c3cff", "a2bdcdff", "4f8cb0ff", "35596eff", "20313cff",
	"a2adcdff", "4f67b0ff", "35436eff", "20273cff", "a8a2cdff", "5b4fb0ff", "3c356eff", "24203cff", "b8a2cdff", "7f4fb0ff",
	"52356eff", "2e203cff", "c8a2cdff", "a44fb0ff", "67356eff", "38203cff", "cda2c2ff", "b04f98ff", "6e3560ff", "3c2035ff",
	"cda2b2ff", "b04f73ff", "6e354aff", "3c202aff"
}

-- Units
RAIDER_TARGETING_RADIUS = 6.0 -- The area of which the raiders will try and target structures around the farm
RAIDER_BREACH_DISTANCE = 12.0 -- The distance of which the enemies will begin attacking their way through structures instead of pathing
RAIDER_TICK_LIFETIME = 40 * 60 * 10 -- Despawn after 10 minutes flee only when raid is over
AGGRESSIVE_TARGET_DISTANCE = 60
RAIDER_LOOTBOT_TICK_LIFETIME = 40 * 60 -- Despawn after 60 seconds (flee after 50)
RAID_RADIUS = 96.0

-- BabyWoc
BABYWOC_BAGUETTE_CONTAINER_INDEX = 0
BABYWOC_GLOWSTICK_CONTAINER_INDEX = 1

-- Cablebot
CABLEBOT_PLAYER_ATTACKER_CHANCE = 0.3334 -- Chance for cablebot to exclusively attack players
CABLEBOT_WEAK_SHAPES = {
	ITEMS.obj_resource_wonkstonks
}

-- Collision
TUMBLE_VELOCITY_THRESHOLD = 12 -- Start tumbling from collisions at this velocity difference
TUMBLE_VELOCITY_MAX_IMPACT = 80 -- At this velocity difference the tumble time stops scaling and remains at TUMBLE_MAX_TICK_TIME
TUMBLE_MIN_TICK_TIME = 40 -- The least amount of time to tumble (small collisions)
TUMBLE_MAX_TICK_TIME = 160 -- The most amount of time to tumble (large collisions)

SMALL_TUMBLE_TICK_TIME = 1.0 * 40
MEDIUM_TUMBLE_TICK_TIME = 2.0 * 40
LARGE_TUMBLE_TICK_TIME = 4.0 * 40

RAIL_KINEMATIC_UNSTOPPABLE_THRESHOLD = 3.0 -- Kinematic won't stop for units when traveling fast

SPINNER_ANGULAR_THRESHOLD = 3.5
PLASMA_ANGULAR_THRESHOLD = 50.0
PLASMA_BOT_HIT_EFFECT_TICK_THRESHOLD = 5 -- Minimum ticks between plasma bot hit effects

-- Lost Item Tick Times
LOST_BAG_SHOW_TICKS =  DAYCYCLE_TIME_TICKS * 5

-- Harvestable
TREE_TRUNK_HITS = 3
TREE_LOG_HITS = 1

-- Manager
PESTICIDE_SIZE = sm.vec3.new( 5.0, 5.0, 3.0 )
FIRE_EFFECT_BUDGET = 3000 -- How many fire effects are allowed to exist
FIRE_INSTANCE_LIMIT = FIRE_EFFECT_BUDGET * 0.9

-- Math
FLT_EPSILON = 1.192092896e-07
DBL_EPSILON = 2.2204460492503131e-016

-- Colors
WHITE = sm.color.new( "ffffff" )
BLACK = sm.color.new( "000000" )
RED = sm.color.new( "ff0000" )
GREEN = sm.color.new( "00ff00" )
BLUE = sm.color.new( "0000ff" )
CYAN = sm.color.new( "00ffff" )
MAGENTA = sm.color.new( "ff00ff" )
YELLOW = sm.color.new( "ffff00" )

-- Physics
GRAVITY = 10.0

-- Network
SERVER_TICKS_PER_SECOND = 40

-- Attacks can be used by the right side or left side.
-- TRASH_BALL, LAUGH, PUSHBACK, SPRAY_GROUND, CONTINUOUS_VOLLEY and CLEAR_PATTERN are sideless (defaults to right side internally)
TrashbotAttack =
{
	BULLET_SPRAY = 1,
	JUNK_WAVE = 2,
	VOLLEY_BOMB = 3,
	CHARGED_BULLET = 4,
	TRASH_BALL = 5,
	TURBO_BULLET_SPRAY = 6,
	LAUGH = 7,
	PUSHBACK = 8,
    SPRAY_GROUND = 9,
    CONTINUOUS_VOLLEY = 10,
    TRASH_SPRINKLER = 11,
	CLEAR_PATTERN = 12,
	DESTRUCTION_SWAY = 13
}

ScannerbotBehaviour =
{
	UNKNOWN = 0,
	ROAD = 1,
	RELOCATE_ASCEND = 2,
	RELOCATE = 3,
	RELOCATE_DESCEND = 4,
}

CameraState =
{
	DEFAULT = 1,
	TUMBLING = 2,
	INTERACTABLE = 3,
	CUTSCENE = 4,
	CUSTOM = 5,
	SEAT_LOCKED_CAMERA = 6
}

CORNADE_LIFETIME = 70
SCANNERBOT_GROUND_HEIGHT_RELOCATE = 310
SCANNERBOT_GROUND_HEIGHT_ROAD = 120
SCANNERBOT_CHARACTER_HEIGHT_OFFSET = 0.5 -- Based on capsule size

PATROL_LEADER_TOLERANCE = 1.0

DrillbotAttack =
{
	DELAY = 1,
	ATTACK_LEFT = 2,
	ATTACK_RIGHT = 3,
	DRILL = 4,
	SHOOT = 5,
	COMBO_LEFT01 = 6,
	COMBO_LEFT02 = 7
}

DRILLBOT_ARENA_WIDTH = 25
DRILLBOT_ARENA_LENGTH = 40
DRILLBOT_ARENA_HEIGHT = 8
DRILLBOT_FACE_HITS = 5

MESSAGE_TYPES = {
	GENERAL = {
		ProjectileHit = "ProjectileHit",
		ProjectileFire = "ProjectileFire",
		Collision = "Collision",
		TrashbotDefeated = "TrashbotDefeated",
		SetTrashbotBossMusic = "SetTrashbotBossMusic"
	},

	EFFECT_EVENTS = {
		ClearWarehouseAttack = "event.quest_clear_warehouse.attack",
		DrillbotDrop = "event.cinematic.drillbotdrop"
	},

	QUEST = {
		TerrainLoaded = "QuestEntityTerrainLoaded"
	}
}

DrillbotTrackTypes =
{
	Combat = 1,
	Enter = 2,
	Rollercoaster = 3,
	Down = 4,
	End = 5,
	Cinematic = 6,
	DownTransition = 7,
	EndTransition = 8,
	Intro = 9
}

DrillbotTrackNames = {
	"Combat",
	"Enter",
	"Rollercoaster",
	"Down",
	"End",
	"Cinematic",
	"DownTransition",
	"EndTransition",
	"Intro"
}

UNDERGROUND_DEFS = {
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldMiningHub" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_mininghub.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldTutorial" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_onboarding.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldStation1" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_station_01.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldDrill1" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_drill_01.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldScrapyard" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_scrapyard.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldDrill2" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_drill_02.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldStation2" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_station_02.world" },
	{ script = { file = "$SURVIVAL_DATA/Scripts/game/worlds/UndergroundWorld.lua", class = "UndergroundWorldFinalBossLobby" }, world = "$SURVIVAL_DATA/Terrain/Worlds/undergroundworld_final_boss_lobby.world" },
}

UNDERGROUND_ELEVATORS = {
	["MAIN"] =  {
		floors =
		{
			{ debug = "overworld, scrap city", depth = 0, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = "s", requiresKey = LOGS.log_underground_elevator_key_01, callButtonLocked = true },
			{ debug = "mining hub, main elevator", depth = 1, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 1, requiresKey = LOGS.log_underground_elevator_key_01, callButtonLocked = true },
			{ debug = "onboarding", depth = 2, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 2, requiresKey = LOGS.log_accesscard_01 },
			{ debug = "station1", depth = 3, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 3, requiresKey = LOGS.log_accesscard_02 },
			{ debug = "drill1", depth = 4, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 4, requiresKey = LOGS.log_accesscard_02 },
			{ debug = "scrapyard", depth = 5, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = "t", requiresKey = LOGS.log_accesscard_03 },
			{ debug = "drill2", depth = 6, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 5, requiresKey = LOGS.log_accesscard_03 },
			{ debug = "station2", depth = 7, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 6, requiresKey = LOGS.log_accesscard_04 },
			{ debug = "drillbot lobby", depth = 8, connectionTag = "UNDERGROUND_ELEVATOR_MAIN", displayDepth = 7, requiresKey = LOGS.log_underground_minerboss_key }
		},
		hubFloor = 2,
	},
	["EXCAVATION"] = {
		floors = {
			{ debug = "overworld, excavation", depth = 0, connectionTag = "UNDERGROUND_ELEVATOR_EXCAVATION", displayDepth = 0, requiresKey = LOGS.log_underground_elevator_key_01, callButtonLocked = true },
			{ debug = "mining hub, excavation elevator", depth = 1, connectionTag = "UNDERGROUND_ELEVATOR_EXCAVATION", displayDepth = 1, requiresKey = LOGS.log_underground_elevator_key_01 },
		},
		hubFloor = 1,
	},
	["MECHANICSTATION"] = {
		floors = {
			{ debug = "overworld, mechanic station", depth = 0, connectionTag = "UNDERGROUND_ELEVATOR_MECHANICSTATION", displayDepth = 0, requiresKey = LOGS.log_underground_elevator_key_01, callButtonLocked = true },
			{ debug = "mining hub, mechanic station elevator", depth = 1, connectionTag = "UNDERGROUND_ELEVATOR_MECHANICSTATION", displayDepth = 1, requiresKey = LOGS.log_underground_elevator_key_01 },
		},
		hubFloor = 1,
	},
}

CONNECTION_TO_ELEVATOR_NAME = {}
for name, elevator in pairs( UNDERGROUND_ELEVATORS ) do
	for _, floor in ipairs( elevator.floors ) do
		CONNECTION_TO_ELEVATOR_NAME[floor.connectionTag] = name
	end
end

UNDERGROUND_CONNECTIONS = {
	"UNDERGROUND_ELEVATOR_MAIN",
	"UNDERGROUND_ELEVATOR_MAIN_BOTTOM",
	"UNDERGROUND_ELEVATOR_EXCAVATION",
	"UNDERGROUND_ELEVATOR_MECHANICSTATION",
}

UNDERGROUND_CONNECTION_TO_KEY_UUID = {
    ["UNDERGROUND_ELEVATOR_EXCAVATION"] = LOGS.log_underground_elevator_key_01,
    ["UNDERGROUND_ELEVATOR_MAIN"] = LOGS.log_underground_elevator_key_01,
    ["UNDERGROUND_ELEVATOR_MECHANICSTATION"] = LOGS.log_underground_elevator_key_01,
}

GROWLAB_POI_ORDER = {
	POI_MEADOW_GROWLAB_QUEST_LARGE,
	POI_DESERT_GROWLAB_CLIFFTOP_LARGE,
	POI_BURNTFOREST_GROWLAB_FROZEN_LARGE,
	POI_FOREST_GROWLAB_STATION_LARGE,
	POI_MEADOW_GROWLAB_SILODISTRICT_XL,
	POI_LAKE_GROWLAB_ISLAND_XL,
	POI_RUINCITY_XL
}

POI_TYPE_TO_LOG_UUID = {
	[POI_MEADOW_GROWLAB_QUEST_LARGE] = LOGS.log_growlab_01,
	[POI_DESERT_GROWLAB_CLIFFTOP_LARGE] = LOGS.log_growlab_02,
	[POI_BURNTFOREST_GROWLAB_FROZEN_LARGE] = LOGS.log_growlab_03,
	[POI_FOREST_GROWLAB_STATION_LARGE] = LOGS.log_growlab_04,
	[POI_MEADOW_GROWLAB_SILODISTRICT_XL] = LOGS.log_growlab_05,
	[POI_LAKE_GROWLAB_ISLAND_XL] = LOGS.log_growlab_06,
	[POI_RUINCITY_XL] = LOGS.log_growlab_07
}

POI_TYPE_TO_GROWLAB_WORLD_PATH = {
	[POI_MEADOW_GROWLAB_QUEST_LARGE] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_01.world",
	[POI_DESERT_GROWLAB_CLIFFTOP_LARGE] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_02.world",
	[POI_BURNTFOREST_GROWLAB_FROZEN_LARGE] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_03.world",
	[POI_FOREST_GROWLAB_STATION_LARGE] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_04.world",
	[POI_MEADOW_GROWLAB_SILODISTRICT_XL] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_05.world",
	[POI_LAKE_GROWLAB_ISLAND_XL] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_06.world",
	[POI_RUINCITY_XL] = "$SURVIVAL_DATA/Terrain/Worlds/growlab_07.world"
}

POI_TYPE_TO_GROWLAB_BALLOONCRATE_REWARD = {
	[POI_MEADOW_GROWLAB_QUEST_LARGE] = tostring( ITEMS.obj_container_chest_looting ),
	[POI_DESERT_GROWLAB_CLIFFTOP_LARGE] = tostring( ITEMS.obj_interactive_beehive ),
	[POI_BURNTFOREST_GROWLAB_FROZEN_LARGE] = tostring( ITEMS.obj_interactive_freezer ),
	[POI_FOREST_GROWLAB_STATION_LARGE] = tostring( ITEMS.tool_shotgun ),
	[POI_MEADOW_GROWLAB_SILODISTRICT_XL] = tostring( ITEMS.obj_interactive_thruster_01 ),
	[POI_LAKE_GROWLAB_ISLAND_XL] = tostring( ITEMS.obj_container_XXL_chest ),
	[POI_RUINCITY_XL] = tostring( ITEMS.obj_rewards_fireworks )
}

SEED_TYPE_TO_SEED_TIER = {
	tomato = 1,
	carrot = 2,
	redbeet = 3,
	banana = 4,
	blueberry = 5,
	orange = 6,
	broccoli = 7,
	pineapple = 8,
	potato = 1
}

ALERT_COLOR_OVERRIDE = sm.color.new( 0.8, 0.1, 0.1 )

MAX_CINEMATIC_DISTANCE = 300.0

RADIOACTIVE_CARRY_ITEMS = {
}

GYRO_CORE_TIMEOUT_TICKS = 40 * 60 * 10 -- 10 minutes


GARAGE_IDS =  {
	SCRAP_CITY_GARAGE = 1,
}



































