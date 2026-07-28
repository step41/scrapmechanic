dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$CHALLENGE_DATA/Scripts/challenge/world_util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/HudManager.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_raids.lua"
dofile "$SURVIVAL_DATA/Scripts/game/raid_util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/DialogManager.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua"

-- Server side
RaidManager = class( nil )

-- Gui
local RaidPanelGui = {}
RaidPanelGui.root = dofile( "$SURVIVAL_DATA/Gui/JsonGuis/RaidPanel.gui" )
RaidPanelGui.index = IndexWidgets( RaidPanelGui.root )
RaidPanelGui.index.RaidPanel.Alpha = 0
RaidPanelGui.raidBars = {
	RaidPanelGui.index.RaidBarStep1,
	RaidPanelGui.index.RaidBarStep2,
	RaidPanelGui.index.RaidBarStep3
}
RaidPanelGui.milestones = {
	RaidPanelGui.index.MilestoneStep1,
	RaidPanelGui.index.MilestoneStep2
}

local MilestoneEffectBoxNames = {}
for i = 1, #RaidPanelGui.milestones do
	MilestoneEffectBoxNames[i] = RaidPanelGui.milestones[i].Childs[1].Name
end

local BarSectionWidth = 100
local SuperBarWidth = 300

local SuperBarAlphaSwapTime = 0.35


RaidPanelGui.index.RaidBarStep1.width = BarSectionWidth
RaidPanelGui.index.RaidBarStep2.width = BarSectionWidth
RaidPanelGui.index.RaidBarStep3.width = BarSectionWidth
RaidPanelGui.index.RaidBarFillSuper.width = SuperBarWidth

local PreviewBarColor1 = sm.color.new( 1.0, 1.0, 1.0 )
local PreviewBarColor2 = sm.color.new(  0.7, 0.7, 0.7 )
local OscillationFrequency = 0.55

-- Constants
local VERSION = 1

local RaidPlantingRadius = 10.0

local MultiDropRandomOffset = 2.0

local RaidIncomingTickTime = 40 * 60.0 -- The countdown time it takes for a triggered raid to start spawning waves
local RaidResetOnPlantTickTime = 40 * 10.0
local RaidTimeoutTickTime = RAIDER_TICK_LIFETIME -- Time before a raid will automatically end
local TicksBetweenLockOnEffects = math.floor( 40 * 0.03 ) -- Time between lock on effects

local InEffectDelayTicks = 40 * 12.0
local DelayBeforeBarMovement = 0.2
local BarMoveDuration = 0.4

local DropEffectTravelDistance = 500
local DropEffectDuration = 5.2
local MarkerTickLifetime = 40 * 12.0
local RaidMarkerOffset = sm.vec3.new( 0, 0, 0.9 )
local RaidCountdownEffectValues = {
	[30] = true,
	[20] = true,
	[10] = true,
	[5] = true,
	[4] = true,
	[3] = true,
	[2] = true,
	[1] = true
}

local DoorDissolveDuration = 0.5
local DoorDissolveDelay = 16.0

local GuiFadeInDuration = 0.075
local GuiFadeOutDuration = 0.1

local function GetRaidGuiMilestone( value )
	local level = GetRaidLevel( value )
	return clamp( math.floor( ( level - 1 ) / 2 ), 0, 2 )
end

local function GetRaidGuiFraction( value )
	local level = GetRaidLevel( value )
	if level > 6 then
		return 1.0
	end
	local fraction = GetRaidLevelFraction( value )
	return ( ( level - 1 ) % 2 + fraction ) / 2
end

local function GetRaidIsSuper( value )
	return GetRaidLevel( value ) > 6
end

local function GetRaidSuperFraction( value )
	if not GetRaidIsSuper( value ) then
		return 0
	end
	local fraction = GetRaidLevelFraction( value )
	return math.log( fraction + 1, 2 )
end

local function GetRaidEnemies( raid )
	if raid.attackData.groupSpawns == nil then
		raid.attackData.groupSpawns = {}
	end
	local spawnTickDelay = InEffectDelayTicks
	local spawnPointIndex = 1

	local initialGroup = GetInitialRaidGroup( raid.value )
	if initialGroup then
		raid.attackData.groupSpawns[#raid.attackData.groupSpawns+1] = { enemyList = initialGroup.enemyList, tickDelay = spawnTickDelay, spawnIndex = spawnPointIndex }
		spawnTickDelay = spawnTickDelay + initialGroup.nextDelay
		spawnPointIndex = spawnPointIndex + 1
	end

	local groups = GetRaidGroups( raid.value )
	for _,groupData in ipairs( groups ) do
		raid.attackData.groupSpawns[#raid.attackData.groupSpawns+1] = { enemyList = groupData.enemyList, tickDelay = spawnTickDelay, spawnIndex = spawnPointIndex }
		spawnTickDelay = spawnTickDelay + groupData.nextDelay
		spawnPointIndex = spawnPointIndex + 1
	end

	raid.totalEnemyCount = 0
	raid.lastSpawnTick = 0
	for _,spawn in ipairs( raid.attackData.groupSpawns ) do
		for _,enemyData in ipairs( spawn.enemyList ) do
			raid.totalEnemyCount = raid.totalEnemyCount + enemyData.quantity
		end
		raid.lastSpawnTick = math.max( raid.lastSpawnTick, spawn.tickDelay )
	end
	raid.timeoutTick = raid.lastSpawnTick + RaidTimeoutTickTime
end

local function HasNearbyPlayer( raidCenter )
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		if sm.exists( player.character ) then
			local distance2 = ( raidCenter - player.character.worldPosition ):length2()
			if distance2 <= RAID_RADIUS * RAID_RADIUS then
				return true
			end
		end
	end
	return false
end

local function HasLocalPlayerInRange( raidCenter )
	local player = sm.localPlayer.getPlayer()
	if sm.exists( player.character ) then
		local distance2 = ( raidCenter - player.character.worldPosition ):length2()
		if distance2 <= RAID_RADIUS * RAID_RADIUS then
			return true
		end
	end
	return false
end
















































































--[[ Server ]]
function RaidManager.server_onCreate( self )
	g_raidManager = self
	self.sv = {}
	self.sv.navmeshHandles = {}
	self.sv.finishedNavMeshLoads = {}
	self.sv.activeRaidLoadHandles = {}
	self.sv.raidPaths = {}
	self.sv.raidsPathGenerationData = {}

	self.sv.saved = sm.storage.load( STORAGE_CHANNEL_RAIDMANAGER )
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.worldRaids = {}
		self.sv.saved.version = VERSION
		sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
	end
	self.sv.isDirty = false
	self:sv_syncClientData()
	self.sv.synchToClients = false
end

function RaidManager.server_onFixedUpdate( self, dt )
	-- Synch client data
	if self.sv.synchToClients then
		self:sv_syncClientData()
		self.sv.synchToClients = false
	end
	if self.sv.isDirty then
		sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
		self.sv.isDirty = false
	end
end

function RaidManager.server_onUnload( self )
	sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
end

function RaidManager.sv_syncClientData( self )
	local worldRaidSync = {}
	for worldId,raids in pairs( self.sv.saved.worldRaids ) do
		worldRaidSync[worldId] = {}
		for raidKey,raid in pairs( raids ) do
			local crops = {}
			for _,harvestable in pairs( raid.existingCrops ) do
				crops[#crops+1] = harvestable
			end
			local groupSpawns = {}
			if raid.attackData.groupSpawns then
				for _,groupSpawn in ipairs( raid.attackData.groupSpawns ) do
					groupSpawns[#groupSpawns+1] = { tickDelay = groupSpawn.tickDelay, spawnIndex = groupSpawn.spawnIndex }
				end
			end
			local attackData = {
				attackPosition = raid.attackData.attackPosition,
				attackTick = raid.attackData.attackTick,
				spawnPositions = raid.attackData.spawnPositions,
				groupSpawns = groupSpawns
			}
			worldRaidSync[worldId][raidKey] = {
				key = raidKey,
				crops = crops,
				level = raid.level,
				value = raid.value,
				center = raid.center,
				attackData = attackData,
				tickCounter = raid.tickCounter,
				timeoutTick = raid.timeoutTick,
				lastSavedTick = raid.savedTick,
				attackPosition = raid.attackPosition,
			}
		end
	end
	self.network:setClientData( { worldRaidSync = worldRaidSync } )
end

function RaidManager.sv_getRaidKey( self, worldId, worldPosition )
	local overlappingRaids = {}
	local raids = self.sv.saved.worldRaids[worldId] or {}
	for raidKey, raid in pairs( raids ) do
		local distance2 = ( raid.center - worldPosition ):length2()
		if distance2 <= RAID_RADIUS * RAID_RADIUS then
			overlappingRaids[#overlappingRaids+1] = { raidKey = raidKey, distance2 = distance2 }
		end
	end
	table.sort( overlappingRaids, function( a, b ) return a.distance2 < b.distance2 end ) -- Shortest distance first
	if #overlappingRaids > 0 then
		-- Return first raid
		return overlappingRaids[1].raidKey
	end
	return nil
end

function RaidManager.sv_getRaidAtPosition( self, worldId, worldPosition )
	local raids = self.sv.saved.worldRaids[worldId] or {}
	local raidKey = self:sv_getRaidKey( worldId, worldPosition )
	if raidKey then
		-- Return first raid
		return raids[raidKey]
	end
	return nil
end

function RaidManager.Sv_AreaHasActiveRaid( position, worldId )
	if g_raidManager then
		return g_raidManager:sv_areaHasActiveRaid( position, worldId )
	end
	return false
end

function RaidManager.sv_areaHasActiveRaid( self, position, worldId )
	local raid = self:sv_getRaidAtPosition( worldId, position )
	local raidIsLocked = raid and ( raid.timeoutTick )
	return raidIsLocked
end

function RaidManager.Sv_DetectCrop( cropHarvestable )
	if g_raidManager then
		sm.event.sendToScriptableObject( g_raidManager.scriptableObject, "sv_detectCrop", cropHarvestable )
	end
end

function RaidManager.sv_detectCrop( self, cropHarvestable )
	if g_disableRaids or GetPlantValue( tostring( cropHarvestable.uuid ) ) == 0 then return end
	local worldId = cropHarvestable:getWorld().id
	local raid = self:sv_getRaidAtPosition( worldId, cropHarvestable.worldPosition )
	local raidIsLocked = raid and ( raid.timeoutTick )
	if raidIsLocked then return end -- Ignore new crops while the raid is on cooldown or spawning raid waves
	local currentTick = sm.game.getCurrentTick()

	if raid == nil then
		-- Create a new raid
		raid = {}
		raid.center = cropHarvestable.worldPosition
		raid.plantingLocations = { cropHarvestable.worldPosition }
		raid.key = worldId.."|"..math.floor( raid.center.x ).."|"..math.floor( raid.center.y ).."|"..math.floor( raid.center.z )
		raid.cropPositions = {}
		raid.existingCrops = {}
		raid.value = 0
		raid.maxValue = 0
		raid.level = 0
		raid.tickCounter = 0
		raid.plantingOrder = {}
		self.sv.saved.worldRaids[worldId] = self.sv.saved.worldRaids[worldId] or {}
		self.sv.saved.worldRaids[worldId][raid.key] = raid
	end
	-- Add crop
	local closeToOtherPlants = false
	for _,pos in ipairs( raid.plantingLocations ) do
		if ( pos - cropHarvestable.worldPosition ):length2() < ( RaidPlantingRadius * RaidPlantingRadius ) then
			closeToOtherPlants = true
			break
		end
	end
	if not closeToOtherPlants then
		raid.plantingLocations[#raid.plantingLocations+1] = cropHarvestable.worldPosition
	end
	raid.value = raid.value + GetPlantValue( tostring( cropHarvestable.uuid ) )
	raid.maxValue = raid.value
	raid.cropPositions[#raid.cropPositions+1] = cropHarvestable.worldPosition
	raid.existingCrops[cropHarvestable.id] = cropHarvestable
	raid.center = sm.util.geometricMedian( raid.cropPositions, nil, 12 )
	raid.plantingOrder[#raid.plantingOrder+1] = { uid = cropHarvestable.uuid, position = cropHarvestable.worldPosition }

	if raid.attackData and raid.attackData.attackTick and currentTick <= raid.attackData.attackTick - RaidIncomingTickTime + RaidResetOnPlantTickTime then
		raid.attackData.attackTick = currentTick + RaidIncomingTickTime





	end

	raid.level = GetRaidLevel( raid.value ) -- Update raid level





	if raid.attackData == nil then
		raid.attackData = { attackPosition = raid.center, attackTick = currentTick + RaidIncomingTickTime }





	else
		raid.attackData.attackPosition = raid.center
	end

	local success, result = sm.physics.raycast( raid.attackData.attackPosition + sm.vec3.new( 0, 0, 126 ), raid.attackData.attackPosition - sm.vec3.new( 0, 0, 126 ), nil, sm.physics.filter.terrainSurface, cropHarvestable:getWorld() )
	if success then
		raid.attackData.attackPosition = result.pointWorld
	end

	raid.savedTick = currentTick
	sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
	self.sv.synchToClients = true
end

function RaidManager.Sv_CropDestroyed( cropHarvestable )
	if g_raidManager then
		g_raidManager:sv_cropDestroyed( cropHarvestable )
	end
end

function RaidManager.sv_cropDestroyed( self, cropHarvestable )
	local worldId = cropHarvestable:getWorld().id
	local raid = self:sv_getRaidAtPosition( worldId, cropHarvestable.worldPosition )
	if not raid then
		return
	end
	raid.existingCrops[cropHarvestable.id] = nil
	for i, pos in ipairs( raid.cropPositions ) do
		if pos == cropHarvestable.worldPosition then
			table.remove( raid.cropPositions, i )
			break
		end
	end
	if raid.attackData and not IsEmptyTable( raid.cropPositions ) and not raid.timeoutTick then
		raid.attackData.attackPosition = sm.util.geometricMedian( raid.cropPositions, nil, 12 )
		local success, result = sm.physics.raycast( raid.attackData.attackPosition + sm.vec3.new( 0, 0, 126 ), raid.attackData.attackPosition - sm.vec3.new( 0, 0, 126 ), nil, sm.physics.filter.terrainSurface, cropHarvestable:getWorld() )
		if success then
			raid.attackData.attackPosition = result.pointWorld
		end
	end
	if IsEmptyTable( raid.existingCrops ) then
		local raidKey = self:sv_getRaidKey( worldId, cropHarvestable.worldPosition )
		sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_failRaid", { raid = raid, worldId = worldId, raidKey = raidKey } )
	end
	if not raid.attackData.groupSpawns then
		for i,orderData in ipairs( raid.plantingOrder ) do
			if cropHarvestable.uuid == orderData.uid and cropHarvestable.worldPosition == orderData.position then
				table.remove( raid.plantingOrder, i )
				break
			end
		end
		local value = 0
		for _,orderData in ipairs( raid.plantingOrder ) do
			value = value + GetPlantValue( tostring( orderData.uid ) )
		end
		raid.value = value
		raid.maxValue = raid.value
		raid.level = GetRaidLevel( raid.value )





	end
	for index,position in reverse_ipairs( raid.plantingLocations ) do
		local needsRemoval = true
		for _,plantLocation in pairs( raid.cropPositions ) do
			if ( position - plantLocation ):length2() < ( RaidPlantingRadius * RaidPlantingRadius ) then
				needsRemoval = false
				break
			end
		end
		if needsRemoval then
			table.remove( raid.plantingLocations, index )
		end
	end
	raid.savedTick = sm.game.getCurrentTick()
	sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
	self.sv.synchToClients = true
end

function RaidManager.sv_navMeshCreated( self, world, x, y, params )
	self.sv.finishedNavMeshLoads[params.key] = self.sv.finishedNavMeshLoads[params.key] + 1
end

function RaidManager.Sv_AddRaider( raidKey, unit )
	if g_raidManager then
		g_raidManager:sv_addRaider( raidKey, unit )
	end
end

function RaidManager.sv_addRaider( self, raidKey, unit )
	local worldId = unit.character:getWorld().id
	local raids = self.sv.saved.worldRaids[worldId] or {}
	local raid = raids[raidKey]
	if raid then
		if raid.raiders then
			if raid.raiders[unit.id] then
				return
			end
			raid.raiders[unit.id] = { unit = unit, uuid = unit.character:getCharacterType() }
		else
			raid.raiders = { [unit.id] = { unit = unit, uuid = unit.character:getCharacterType() } }
		end
		raid.savedTick = sm.game.getCurrentTick()
		sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
	end
end

function RaidManager.Sv_RemoveRaider( raidKey, unit )
	if g_raidManager then
		g_raidManager:sv_removeRaider( raidKey, unit )
	end
end

function RaidManager.sv_removeRaider( self, raidKey, unit )
	local worldId = unit.character:getWorld().id
	local raids = self.sv.saved.worldRaids[worldId] or {}
	local raid = raids[raidKey]
	if raid then
		if raid.raiders then
			if raid.attackData == nil then
				return
			end
			if raid.raiders[unit.id] then
				raid.value = raid.value - ( raid.maxValue / raid.totalEnemyCount )
			end
			raid.raiders[unit.id] = nil
			if IsEmptyTable( raid.raiders ) then
				raid.raiders = nil
			end
			if raid.enemiesLeft == nil then
				raid.enemiesLeft = raid.totalEnemyCount
			end
			raid.enemiesLeft = raid.enemiesLeft - 1



			if raid.enemiesLeft <= 0 and ( raid.lastSpawnTick <= raid.tickCounter ) then
				self:sv_raidCompleted( raid, worldId )
				if raidKey then
					self.sv.saved.worldRaids[worldId][raidKey] = nil
				end
			end
			raid.savedTick = sm.game.getCurrentTick()
			sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
			self.sv.synchToClients = true
		end
	end
end

function RaidManager.sv_raidCompleted( self, raid, worldId )
	local hasCarrots = false
	local hasBananas = false
	for _,harvestable in pairs( raid.existingCrops ) do
		if sm.exists( harvestable ) then
			sm.event.sendToHarvestable( harvestable, "sv_e_raidSurvived" )
			if harvestable.uuid == hvs_growing_carrot then
				hasCarrots = true
			elseif harvestable.uuid == hvs_growing_banana then
				hasBananas = true
			end
		end
	end
	if QuestManager.Sv_IsQuestComplete( "quest_mystery_call" ) then
		if hasCarrots then
			DialogManager.Sv_PlayNamedBondBuilder( "carrot_raid" )
		end
		if hasBananas then
			DialogManager.Sv_PlayNamedBondBuilder( "banana_raid" )
		end
		
	end
	if worldId then
		for _,player in ipairs( sm.player.getAllPlayers() ) do
			if sm.exists( player.character ) and player.character:getWorld().id == worldId then
				sm.event.sendToPlayer( player, "sv_e_raidCompleted" )
			end
		end
	end
	
	if (raid.level >= 5) then
		sm.achievement.addi("005aaeb2-4562-40a4-ae14-2b7881b42e7e", 1, nil)
	end
	sm.achievement.addi("0524f0c7-040d-40d8-be90-b405fd63bd64", 1, nil)
end

-- Chat command
function RaidManager.Sv_CancelRaids( world )
	if g_raidManager then
		g_raidManager:sv_cancelRaids( world )
	end
end

function RaidManager.sv_cancelRaids( self, world )
	local worldId = world.id
	for _, raid in pairs( self.sv.saved.worldRaids[worldId] or {} ) do
		for _,harvestable in pairs( raid.existingCrops ) do
			if sm.exists( harvestable ) then
				sm.event.sendToHarvestable( harvestable, "sv_e_raidNuke" )
			end
		end
		if raid.raiders then
			for _,raider in pairs( raid.raiders ) do
				if sm.exists( raider.unit ) then
					raider.unit:destroy()
				end
			end
		end
	end
	self.sv.saved.worldRaids[worldId] = nil
	sm.storage.save( STORAGE_CHANNEL_RAIDMANAGER, self.sv.saved )
	self.sv.synchToClients = true
end

function RaidManager.sv_e_failRaid( self, data )
	self:sv_failRaid( data.raid, data.worldId, data.raidKey )
end

function RaidManager.sv_failRaid( self, raid, worldId, raidKey )
	if raid.timeoutTick then
		for _,harvestable in pairs( raid.existingCrops ) do
			if sm.exists( harvestable ) then
				sm.event.sendToHarvestable( harvestable, "sv_e_raidSurvived" )
			end
		end
	end
	self:sv_cleanUpRaid( raid, worldId, raidKey )
end

function RaidManager.sv_cleanUpRaid( self, raid, worldId, raidKey )
	if raid.raiders then
		for _,raider in pairs( raid.raiders ) do
			if sm.exists( raider.unit ) then
				sm.event.sendToUnit( raider.unit, "sv_e_raidOver" )
			end
		end
	end
	if raidKey then
		self.sv.saved.worldRaids[worldId][raidKey] = nil
		self.sv.synchToClients = true
		if self.sv.activeRaidLoadHandles[raidKey] then
			for _,handle in ipairs( self.sv.activeRaidLoadHandles[raidKey] ) do
				handle:release()
			end
			self.sv.activeRaidLoadHandles[raidKey] = nil
		end
	end
end

function RaidManager.Sv_GetPlantLocations( worldId, raidKey )
	if g_raidManager then
		return g_raidManager:sv_getPlantLocations( worldId, raidKey )
	end
	return {}
end

function RaidManager.sv_getPlantLocations( self, worldId, raidKey )
	local raid = self.sv.saved.worldRaids[worldId] and self.sv.saved.worldRaids[worldId][raidKey]
	if raid then
		return raid.plantingLocations
	end
	return {}
end

function RaidManager.Sv_OnWorldFixedUpdate( world )
	if g_raidManager then
		g_raidManager:sv_onWorldFixedUpdate( world )
	end
end

function RaidManager.sv_onWorldFixedUpdate( self, world )
	local worldId = world.id
	local currentTick = sm.game.getCurrentTick()
	local raids = self.sv.saved.worldRaids[worldId] or {}
	for raidKey, raid in pairs( raids ) do
		if HasNearbyPlayer( raid.center ) then
			if self.sv.activeRaidLoadHandles[raidKey] == nil then
				self.sv.activeRaidLoadHandles[raidKey] = {}
				local range = math.floor( GetRaidCellRange() )
				local raidPosition = raid.center
				local cellX = math.floor( raidPosition.x / 64 )
				local cellY = math.floor( raidPosition.y / 64 )
				for x = -range, range do
					for y = -range, range do
						self.sv.activeRaidLoadHandles[raidKey][#self.sv.activeRaidLoadHandles[raidKey]+1] = world:loadCellWithHandle( cellX + x, cellY + y )
					end
				end
			end

			if raid.attackData.groupSpawns and raid.attackData.spawnPositions then
				for _,group in ipairs( raid.attackData.groupSpawns ) do
					if raid.tickCounter >= group.tickDelay and not group.isSpawned then
						local spawnPos = raid.attackData.spawnPositions[( group.spawnIndex - 1 ) % #raid.attackData.spawnPositions + 1].path
						local raiders = {}
						for _,enemyData in ipairs( group.enemyList ) do
							for _ = 1, enemyData.quantity do
								raiders[#raiders+1] = RaidEnemySubTypeRandomizer( enemyData.uuid )
							end
						end
						group.isSpawned = true
						local attackPos = raid.attackData.attackPosition
						for _,pos in ipairs( raid.plantingLocations ) do
							if ( pos - spawnPos ):length2() < ( spawnPos - attackPos ):length2() then
								attackPos = pos
							end
						end
						sm.event.sendToWorld( world, "sv_e_spawnRaiders", { raidKey = raidKey, attackPos = attackPos, raidCenter = raid.center, raiders = raiders, spawnPos = spawnPos } )
					end
				end
			end

			if raid.timeoutTick then -- deactivate raid when timed out
				if raid.tickCounter >= raid.timeoutTick then
					self:sv_raidCompleted( raid, world.id )
					self:sv_cleanUpRaid( raid, world.id, raidKey )
					self.sv.isDirty = true
					self.sv.synchToClients = true
				end
			end

			if raid.attackData and raid.attackData.groupSpawns then
				raid.tickCounter = raid.tickCounter + 1
				raid.savedTick = currentTick
			end

			if raid.attackData then -- Manage active raid
				-- generate attack points at start
				if raid.attackData.attackTick and currentTick >= raid.attackData.attackTick then
					-- Prepare raid groups
					GetRaidEnemies( raid )



					raid.savedTick = currentTick
					self.sv.isDirty = true
					self.sv.synchToClients = true

					raid.attackData.attackTick = nil
					raid.needsSpawnPoints = true
				end

				if raid.needsSpawnPoints and not self.sv.navmeshHandles[raidKey] then
					self.sv.navmeshHandles[raidKey] = {}
					self.sv.finishedNavMeshLoads[raidKey] = 0
					local cellX = math.floor( raid.center.x / 64 )
					local cellY = math.floor( raid.center.y / 64 )
					local range = math.floor( GetRaidCellRange() )
					for x = -range, range do
						for y = -range, range do
							self.sv.navmeshHandles[raidKey][#self.sv.navmeshHandles[raidKey]+1] = world:loadNavMeshWithHandle( x + cellX, y + cellY, "sv_navMeshCreated", { key = raidKey }, g_raidManager )
						end
					end
				end

				if self.sv.navmeshHandles[raidKey] and self.sv.finishedNavMeshLoads[raidKey] == #self.sv.navmeshHandles[raidKey] then
					self.sv.raidPaths[raidKey] = {}
					self.sv.raidsPathGenerationData[raidKey] = { rotation = math.rad( math.random() * 360 ), currentIndex = 1 }
					self.sv.finishedNavMeshLoads[raidKey] = nil
				end

				-- Generate 1 path per tick until enough spawn points are gathered
				if self.sv.raidPaths[raidKey] and self.sv.raidsPathGenerationData[raidKey] then
					self.sv.raidPaths[raidKey][#self.sv.raidPaths[raidKey]+1] = CreateRaidPath( raid.center, world, self.sv.raidsPathGenerationData[raidKey].rotation, self.sv.raidsPathGenerationData[raidKey].currentIndex )
					self.sv.raidsPathGenerationData[raidKey].currentIndex = self.sv.raidsPathGenerationData[raidKey].currentIndex + 1
					if #self.sv.raidPaths[raidKey] == RAID_SAMPLE_POINT_COUNT then
						raid.attackData.spawnPositions = FilterAndSelectPoints( self.sv.raidPaths[raidKey], world, raid.center )
						shuffle( raid.attackData.spawnPositions )
						raid.needsSpawnPoints = false
						self.sv.isDirty = true
						self.sv.synchToClients = true

						for _,handle in ipairs( self.sv.navmeshHandles[raidKey] ) do
							handle:release()
						end
						self.sv.navmeshHandles[raidKey] = nil
						self.sv.raidPaths[raidKey] = nil
						self.sv.raidsPathGenerationData[raidKey] = nil
					end
				end
			end
		else
			if self.sv.activeRaidLoadHandles[raidKey] then
				for _,handle in ipairs( self.sv.activeRaidLoadHandles[raidKey] ) do
					handle:release()
				end
				self.sv.activeRaidLoadHandles[raidKey] = nil
			end
		end
	end
end

function RaidManager.Sv_GetClosestPlayerInRaid( worldId, raidKey, position )
	if g_raidManager then
		return g_raidManager:sv_getClosestPlayerInRaid( worldId, raidKey, position )
	end
	return nil
end

function RaidManager.sv_getClosestPlayerInRaid( self, worldId, raidKey, position )
	local closestCharacter = nil
	local bestRange = math.huge
	local raids = self.sv.saved.worldRaids[worldId] or {}
	if raids[raidKey] then
		for _,player in ipairs( sm.player.getAllPlayers() ) do
			local character = player:getCharacter()
			if character then
				if ( character.worldPosition - raids[raidKey].center ):length2() <= ( RAID_RADIUS * RAID_RADIUS ) then
					local distSqr = ( position - character.worldPosition ):length2()
					if distSqr <= bestRange then
						closestCharacter = character
						bestRange = distSqr
					end
				end
			end
		end
	end
	return closestCharacter
end

--[[ Client ]]

function RaidManager.client_onCreate( self )
	g_raidManagerClient = self
	self.cl = {}
	self.cl.worldRaids = {}
	self.cl.heldPlant = nil
	self.cl.localPlayerPlantingGui = nil
	self.cl.trackedRaidEnemies = {}
	self.cl.fadeTimer = 0
	self.cl.oscillationTimer = 0
end

function RaidManager.Cl_ShowPlantingOutcome( uuid )
	if g_raidManagerClient then
		g_raidManagerClient:cl_showPlantingOutcome( uuid )
	end
end

function RaidManager.Cl_HidePlantingOutcome()
	if g_raidManagerClient then
		g_raidManagerClient:cl_showPlantingOutcome( nil )
	end
end

function RaidManager.cl_showPlantingOutcome( self, uuid )
	self.cl.heldPlant = uuid
	self:cl_triggerGuiRedraw()
end

function RaidManager.cl_triggerGuiRedraw( self )
	local worldId = sm.localPlayer.getPlayer().character:getWorld().id
	local raids = self.cl.worldRaids[worldId] or {}
	for _, raid in pairs( raids ) do
		raid.cl.previousShowGui = false
	end
end

function RaidManager.client_onClientDataUpdate( self, clientData, channel )
	if channel == 1 then
		-- Add/Update worldRaids
		local updatedWorldRaids = {}
		for worldId, raids in pairs( clientData.worldRaidSync ) do
			updatedWorldRaids[worldId] = {}
			local prevRaids = self.cl.worldRaids[worldId] or {}
			for raidId, raidSync in pairs( raids ) do
				-- Move existing client raid data/gui
				local updatedRaid = { raidSync = {}, cl = {} }
				if prevRaids[raidId] then
					updatedRaid.cl = prevRaids[raidId].cl or {}
					prevRaids[raidId] = nil
				end
				-- Set raid data from server
				updatedRaid.raidSync = raidSync
				updatedRaid.cl.previousShowGui = false
				if updatedRaid.cl.previousValue == nil and updatedRaid.cl.fromValue == nil then
					updatedRaid.cl.fromValue = 0
					updatedRaid.cl.barMoveTimer = 0
					updatedRaid.cl.barDelayTimer = 0
					updatedRaid.cl.alphaSwapTimer = 0
				elseif updatedRaid.cl.fromValue == nil then
					updatedRaid.cl.fromValue = updatedRaid.cl.previousValue
					updatedRaid.cl.barMoveTimer = 0
					updatedRaid.cl.barDelayTimer = 0
					updatedRaid.cl.alphaSwapTimer = 0
				end
				updatedRaid.cl.previousValue = raidSync.value
				updatedWorldRaids[worldId][raidId] = updatedRaid
			end
		end

		-- Cleanup leftover client raid data
		for _, raids in pairs( self.cl.worldRaids ) do
			for _, raid in pairs( raids ) do
				if raid.cl.raidStatusJsonGui then
					raid.cl.raidStatusJsonGui:close()
					raid.cl.raidStatusJsonGui = nil
				end
				if raid.cl.markerEffectNear then
					raid.cl.markerEffectNear:destroy()
					raid.cl.markerEffectNear = nil
				end
				if raid.cl.markerEffectFar then
					raid.cl.markerEffectFar:destroy()
					raid.cl.markerEffectFar = nil
				end
				if g_compassHud then
					if raid.cl.compassMarkers then
						for _,pointData in pairs( raid.cl.compassMarkers ) do
							g_compassHud:compassRemoveIcon( pointData.name )
						end
						raid.cl.compassMarkers = nil
					end
				end
				if raid.cl.activeDropEffects then
					for _,effectData in pairs( raid.cl.activeDropEffects ) do
						if sm.exists( effectData.effect ) then
							effectData.effect:destroy()
						end
						if sm.exists( effectData.impactEffect ) then
							effectData.impactEffect:destroy()
						end
					end
					raid.cl.activeDropEffects = nil
				end
				if g_compassHud then
					g_compassHud:compassRemoveIcon( raid.raidSync.key )
				end
			end
		end
		self.cl.updateGui = true
		self.cl.worldRaids = updatedWorldRaids
	end
end

function RaidManager.Cl_OnWorldUpdate( worldId, deltaTime )
	if g_raidManagerClient then
		g_raidManagerClient:cl_onWorldUpdate( worldId, deltaTime )
	end
end

local function CreateCompassMarker( character )
	if g_compassHud then
		local icon = "icon_farmraid_compass_bot.png"
		if character:getCharacterType() == unit_farmbot then
			icon = "icon_farmraid_compass_farmbot.png"
		end
		g_compassHud:compassAddIcon( "enemy"..character.id, icon, false, 8, 12  )
		g_compassHud:compassSetIconHost( "enemy"..character.id, character )
		g_compassHud:setVisible( "enemy"..character.id, true )
	end
end

function RaidManager.Cl_AddTrackedRaidEnemy( raidKey, character )
	if g_raidManagerClient then
		g_raidManagerClient:cl_addTrackedRaidEnemy( raidKey, character )
	end
end

function RaidManager.cl_addTrackedRaidEnemy( self, raidKey, character )
	if self.cl.trackedRaidEnemies[raidKey] == nil then
		self.cl.trackedRaidEnemies[raidKey] = {}
	end
	self.cl.trackedRaidEnemies[raidKey][character.id] = character
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil
	local myPosition = sm.exists( myCharacter ) and myCharacter.worldPosition or nil
	if not myPosition then
		return
	end
	if self.cl.worldRaids[character:getWorld().id] and not IsEmptyTable( self.cl.worldRaids[character:getWorld().id] ) then
		for raidId, raid in pairs( self.cl.worldRaids[character:getWorld().id] ) do
			if raidId == raidKey then
				local myDistance2 = myPosition and ( myPosition - raid.raidSync.center ):length2() or math.huge
				local insideRaidArea = myDistance2 <= RAID_RADIUS * RAID_RADIUS
				if insideRaidArea then
					CreateCompassMarker( character )
				end
				break
			end
		end
	end
end

function RaidManager.Cl_RemoveTrackedRaidEnemy( raidKey, character )
	if g_raidManagerClient then
		g_raidManagerClient:cl_removeTrackedRaidEnemy( raidKey, character )
	end
end

function RaidManager.cl_removeTrackedRaidEnemy( self, raidKey, character )
	if self.cl.trackedRaidEnemies[raidKey] then
		if self.cl.trackedRaidEnemies[raidKey][character.id] then
			if g_compassHud then
				g_compassHud:compassRemoveIcon( "enemy"..character.id )
			end
			self.cl.trackedRaidEnemies[raidKey][character.id] = nil
		end
	end
end

function RaidManager.cl_markRaiders( self, raidKey )
	if self.cl.trackedRaidEnemies[raidKey] == nil then
		return
	end
	for _, character in pairs( self.cl.trackedRaidEnemies[raidKey] ) do
		if sm.exists( character ) then
			CreateCompassMarker( character)
		end
	end
end

function RaidManager.cl_unmarkRaiders( self, raidKey )
	if self.cl.trackedRaidEnemies[raidKey] == nil then
		return
	end
	for characterId, character in pairs( self.cl.trackedRaidEnemies[raidKey] ) do
		if g_compassHud then
			g_compassHud:compassRemoveIcon( "enemy"..character.id )
		end
	end
end

-- Gui and effects

local function GetCountdownText( raid, currentTick )
	local numericalValue = math.max( 0, math.floor( ( raid.raidSync.attackData.attackTick - currentTick ) / 40 ) )
	local stringValue = ( numericalValue < 10 ) and ( "0"..tostring( numericalValue ) ) or tostring( numericalValue )
	return stringValue, numericalValue
end

local function Cl_TryPlayCountdownEffect( raid, numericalValue )
	local attackTick = raid.raidSync.attackData and raid.raidSync.attackData.attackTick
	if attackTick == nil then
		raid.cl.previousCountdownValue = nil
		return
	end

	if raid.cl.previousCountdownValue ~= numericalValue then
		raid.cl.previousCountdownValue = numericalValue
		if RaidCountdownEffectValues[numericalValue] then
			sm.effect.playEffect( "audio:event:/ui/raid/countdown", sm.vec3.zero() )
		elseif numericalValue == 0 then
			sm.effect.playEffect( "audio:event:/ui/raid/countdown_end", sm.vec3.zero() )
			raid.cl.previousCountdownValue = nil
		end
	end
end

function RaidManager.cl_handleGuiFade( self, anyRaidControllingGui, deltaTime )
	if self.cl.localPlayerPlantingGui then
		if not anyRaidControllingGui then
			if RaidPanelGui.index.RaidPanel.Alpha > 0 then
				local newAlpha = lerp( 1.0, 0.0, self.cl.fadeTimer / GuiFadeOutDuration )
				RaidPanelGui.index.RaidPanel.Alpha = newAlpha
				self.cl.fadeTimer = self.cl.fadeTimer + deltaTime
			else
				self.cl.localPlayerPlantingGui:close()
				self.cl.localPlayerPlantingGui = nil
				self.cl.fadeTimer = 0
			end
		else
			if RaidPanelGui.index.RaidPanel.Alpha < 1 then
				local newAlpha = lerp( 0.0, 1.0, self.cl.fadeTimer / GuiFadeInDuration )
				RaidPanelGui.index.RaidPanel.Alpha = newAlpha
				self.cl.fadeTimer = self.cl.fadeTimer + deltaTime
			else
				self.cl.fadeTimer = 0
			end
		end
		if self.cl.localPlayerPlantingGui then
			self.cl.localPlayerPlantingGui:render( RaidPanelGui.root )
		end
	end
end

function RaidManager.cl_onWorldUpdate( self, worldId, deltaTime )
	local currentTick = sm.game.getServerTick()
	local raids = self.cl.worldRaids[worldId] or {}
	local closestRaidId
	local closestRaidDistance2 = math.huge
	local anyRaidControllingGui = false
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil
	local myPosition = sm.exists( myCharacter ) and myCharacter.worldPosition or nil

	for raidId, raid in pairs( raids ) do
		-- Update gui position
		if raid.raidSync.attackData and raid.raidSync.attackData.attackPosition then
			if raid.cl.guiWorldPosition == nil then
				raid.cl.guiWorldPosition = raid.raidSync.attackData.attackPosition
			else
				raid.cl.previousPosition = raid.cl.guiWorldPosition
				local pos = raid.raidSync.attackData and raid.raidSync.attackData.attackPosition
				raid.cl.guiWorldPosition = magicPositionInterpolation( raid.cl.guiWorldPosition, pos, deltaTime, 1/6 )
			end
		end

		local myDistance2 = myPosition and ( myPosition - raid.raidSync.center ):length2() or math.huge
		local insideRaidArea = myDistance2 <= RAID_RADIUS * RAID_RADIUS

		if myDistance2 < closestRaidDistance2 then
			closestRaidDistance2 = myDistance2
			closestRaidId = raidId
		end
		local activeAttack = raid.raidSync.attackData and raid.raidSync.attackData.spawnPositions ~= nil
		local showInfo = insideRaidArea and raid.cl.isClosest and raid.raidSync.value > 0
		local showMarker = raid.raidSync.center ~= nil and raid.raidSync.attackData.attackTick and currentTick > raid.raidSync.attackData.attackTick - RaidIncomingTickTime + RaidResetOnPlantTickTime
		local showCompassDrops = insideRaidArea and raid.cl.isClosest and raid.raidSync.attackData and raid.raidSync.attackData.spawnPositions
		local showRaidDropEffects = raid.raidSync.level > 1 and raid.raidSync.attackData and raid.raidSync.attackData.spawnPositions and raid.raidSync.timeoutTick

		if not raid.cl.notificationShown and raid.raidSync.attackData and raid.raidSync.attackData.attackTick
		and currentTick >= raid.raidSync.attackData.attackTick - RaidIncomingTickTime + RaidResetOnPlantTickTime then
			NotificationManager.Cl_AddRaidWarningNotification( "#{RAID_WARNING_MESSAGE}" )
			raid.cl.notificationShown = true
		end

		if raid.cl.previousInsideRaidArea ~= insideRaidArea then
			raid.cl.previousInsideRaidArea = insideRaidArea
			if insideRaidArea then
				self:cl_markRaiders( raidId )
			else
				self:cl_unmarkRaiders( raidId )
			end
		end

		if not anyRaidControllingGui then
			anyRaidControllingGui = HasLocalPlayerInRange( raid.raidSync.center )
		end

		local hasNearbyPlayer = HasNearbyPlayer( raid.raidSync.center )
		if hasNearbyPlayer and showRaidDropEffects then
			if raid.cl.compassMarkers == nil then
				raid.cl.compassMarkers = {}
				for i,groupData in ipairs( raid.raidSync.attackData.groupSpawns ) do
					local position = raid.raidSync.attackData.spawnPositions[( groupData.spawnIndex - 1 ) % #raid.raidSync.attackData.spawnPositions + 1].path
					local direction = ( position - ( raid.raidSync.attackData and raid.raidSync.attackData.attackPosition ) ):safeNormalize( sm.vec3.new( 0, 0, 1 ) )
					local first = groupData.tickDelay == raid.raidSync.attackData.groupSpawns[1].tickDelay
					local fromPos = first and position - direction * DropEffectTravelDistance or position + direction * DropEffectTravelDistance
					raid.cl.compassMarkers[#raid.cl.compassMarkers+1] = { active = false, name = raid.raidSync.key..tostring( i ), fromPos = fromPos, toPos = position }
					if g_compassHud then
						g_compassHud:compassAddIcon( raid.cl.compassMarkers[#raid.cl.compassMarkers].name, "icon_compass_dropcargo.png", true, 32 )
						g_compassHud:compassSetIconWorldPosition( raid.cl.compassMarkers[#raid.cl.compassMarkers].name, fromPos )
						g_compassHud:compassSetIconStacking( raid.cl.compassMarkers[#raid.cl.compassMarkers].name, false )
					end
				end
			end
			if raid.raidSync.attackData.groupSpawns then
				if raid.cl.activeDropEffects == nil then
					raid.cl.activeDropEffects = {}
				end
				local ticksPassed = ( currentTick - raid.raidSync.lastSavedTick ) + raid.raidSync.tickCounter
				for i,groupData in ipairs( raid.raidSync.attackData.groupSpawns ) do
					if ticksPassed >= ( groupData.tickDelay - InEffectDelayTicks ) and not raid.cl.compassMarkers[i].effectDone then
						local spawnPoint = raid.raidSync.attackData.spawnPositions[( groupData.spawnIndex - 1 ) % #raid.raidSync.attackData.spawnPositions + 1].path
						local material = raid.raidSync.attackData.spawnPositions[( groupData.spawnIndex - 1 ) % #raid.raidSync.attackData.spawnPositions + 1].material
						if material == "" then
							material = sm.physics.getGroundMaterial( spawnPoint )
						end
						local direction = spawnPoint - ( raid.raidSync.attackData and raid.raidSync.attackData.attackPosition )
						direction.z = 0
						if ( groupData.tickDelay - raid.raidSync.attackData.groupSpawns[1].tickDelay ) <= MultiDropRandomOffset * 40 then
							local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), direction:safeNormalize( sm.vec3.new( 1, 0, 0 ) ) )
							local effect = sm.effect.createEffect( "Raidrop01 - Droppod" )
							effect:setPosition( spawnPoint )
							effect:setRotation( rotation )
							effect:setParameter( "material", sm.shape.material.metal )
							effect:start()

							local impactEffect = sm.effect.createEffect( "Raidrop01 - DroppodImpact" )
							impactEffect:setPosition( spawnPoint )
							impactEffect:setRotation( rotation )
							impactEffect:setParameter( "material", sm.physics.getMaterialId( material ) )
							impactEffect:start()
							raid.cl.activeDropEffects[i] = { effect = effect, impactEffect = impactEffect, timer = 0 }
						else
							local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), ( -direction ):safeNormalize( sm.vec3.new( 1, 0, 0 ) ) )
							local effect = sm.effect.createEffect( "Raidrop02 - Droppod" )
							effect:setPosition( spawnPoint )
							effect:setRotation( rotation )
							effect:setParameter( "material", sm.shape.material.metal )
							effect:start()
							
							local impactEffect = sm.effect.createEffect( "Raidrop01 - DroppodImpact" )
							impactEffect:setPosition( spawnPoint )
							impactEffect:setRotation( rotation )
							impactEffect:setParameter( "material", sm.physics.getMaterialId( material ) )
							impactEffect:start()
							raid.cl.activeDropEffects[i] = { effect = effect, impactEffect = impactEffect, timer = 0 }
						end
						raid.cl.compassMarkers[i].effectStartTick = currentTick
						raid.cl.compassMarkers[i].active = true
						raid.cl.compassMarkers[i].effectDone = true
						if g_compassHud and showCompassDrops then
							g_compassHud:setVisible( raid.cl.compassMarkers[i].name, true )
							g_compassHud:compassPingMarker( raid.cl.compassMarkers[i].name, "Gui - Raid_Arrows01_loop" )
						end
					elseif ticksPassed >= ( groupData.tickDelay - InEffectDelayTicks + MarkerTickLifetime ) and raid.cl.compassMarkers[i].active then
						raid.cl.compassMarkers[i].active = false
						if g_compassHud and showCompassDrops then
							g_compassHud:setVisible( raid.cl.compassMarkers[i].name, false )
						end
					end
				end
			end
			for _, compassData in ipairs( raid.cl.compassMarkers ) do
				if compassData.effectStartTick and compassData.active and not compassData.movementDone then
					local fraction = math.min( ( currentTick - compassData.effectStartTick ) / 40 / DropEffectDuration, 1.0 )
					if fraction <= 1.0 then
						if fraction >= 1.0 then
							compassData.movementDone = true
						end
						local pos = lerp( compassData.fromPos, compassData.toPos, fraction )
						if g_compassHud and showCompassDrops then
							g_compassHud:compassSetIconWorldPosition( compassData.name, pos )
						end
					end
				end
			end
			for i,effectData in reverse_ipairs( raid.cl.activeDropEffects ) do
				if effectData.effect and effectData.effect:isPlaying() then
					effectData.timer = effectData.timer + deltaTime
					if effectData.timer >= DoorDissolveDelay then
						local fraction = math.min( ( effectData.timer - DoorDissolveDelay ) / DoorDissolveDuration , 1.0 )
						effectData.effect:setParameter( "pose2", lerp( 0.5, 1, fraction ) )
					end
				end
			end
		elseif showRaidDropEffects then
			if raid.cl.compassMarkers then
				for _,markerData in pairs( raid.cl.compassMarkers ) do
					if markerData.active == true then
						markerData.active = false
						if g_compassHud then
							g_compassHud:setVisible( markerData.name, false )
						end
					end
				end
			end
		end

		if showInfo and ( not raid.cl.previousShowGui and ( self.cl.updateGui or raid.cl.raidStatusJsonGui == nil ) or ( raid.cl.barMoveTimer ~= nil ) ) then
			if raid.cl.raidStatusJsonGui == nil then
				raid.cl.raidStatusJsonGui = sm.jsonGui.createGui( { isHud = true, needsCursor = false, isInteractive = false } )
				raid.cl.guiCreationTick = currentTick
				local newAlpha = GetRaidIsSuper( raid.raidSync.value ) and 0 or 1
				RaidPanelGui.index.RaidBar.Alpha = newAlpha
				for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
					data.Alpha = newAlpha
				end
			end
			if RaidPanelGui.index.RaidPanel.Alpha == 0 then
				RaidPanelGui.index.RaidPanel.Alpha = 1
			end
			RaidPanelGui.index.RaidBarHighlight.Visible = false
			RaidPanelGui.index.RaidBarHighlightSuper.Visible = false
			if raid.cl.barMoveTimer and raid.cl.barMoveTimer == 0 then
				RaidPanelGui.index.RaidBarHighlightEffect.Effects[1].ResetPlayOnce = true
				RaidPanelGui.index.RaidBarHighlightSuperEffect.Effects[1].ResetPlayOnce = true
			else
				RaidPanelGui.index.RaidBarHighlightEffect.Effects[1].ResetPlayOnce = false
				RaidPanelGui.index.RaidBarHighlightEffect.Effects[1].PlayState = "Stopped"
				RaidPanelGui.index.RaidBarHighlightSuperEffect.Effects[1].ResetPlayOnce = false
				RaidPanelGui.index.RaidBarHighlightSuperEffect.Effects[1].PlayState = "Stopped"
			end

			if not activeAttack then
				local newColor = sm.color.lerp( PreviewBarColor1, PreviewBarColor2, ( math.sin( math.rad( self.cl.oscillationTimer * 180 / OscillationFrequency ) ) + 1 ) * 0.5 )
				RaidPanelGui.index.RaidBarPreview.Colour = newColor:getGuiColorStr()
				RaidPanelGui.index.RaidBarPreviewSuper.Colour = newColor:getGuiColorStr()
				self.cl.oscillationTimer = self.cl.oscillationTimer + deltaTime
			else
				RaidPanelGui.index.RaidBarPreview.Colour = "1 1 1 1"
			end

			local plantValue = 0
			if self.cl.heldPlant and not activeAttack then
				plantValue = GetPlantValue( self.cl.heldPlant )
			end
			local fullSteps = GetRaidGuiMilestone( raid.raidSync.value )
			local fraction = GetRaidGuiFraction( raid.raidSync.value )
			local previewSteps = GetRaidGuiMilestone( raid.raidSync.value + plantValue )
			local previewFraction = GetRaidGuiFraction( raid.raidSync.value + plantValue )
			local isLoss = false
			if raid.cl.fromValue then
				isLoss = raid.raidSync.value < raid.cl.fromValue
			end
			if not isLoss then
				RaidPanelGui.index.RaidBarPreview.width = math.min( math.floor( previewSteps * BarSectionWidth + previewFraction * BarSectionWidth ), BarSectionWidth * 3 )
				if GetRaidIsSuper( raid.raidSync.value + plantValue ) then
					local superFraction = GetRaidSuperFraction( raid.raidSync.value + plantValue )
					RaidPanelGui.index.RaidBarPreviewSuper.width = math.floor( superFraction * SuperBarWidth )
				end
			else
				for i = 1, #RaidPanelGui.raidBars do
					RaidPanelGui.raidBars[i].width = math.min( math.floor( fullSteps * BarSectionWidth + fraction * BarSectionWidth ), BarSectionWidth * i )
					RaidPanelGui.raidBars[i].Visible = fullSteps + 1 >= i
				end
			end

			if raid.cl.barDelayTimer > DelayBeforeBarMovement then
				if raid.cl.fromValue or not ( RaidPanelGui.index.RaidBar.Alpha == 1 or RaidPanelGui.index.RaidBar.Alpha == 0.0 ) then
					RaidPanelGui.index.RaidBarHighlightEffect.Visible = true
					local fromValue = raid.cl.fromValue or raid.raidSync.value
					local lerpValue = lerp( fromValue, raid.raidSync.value, raid.cl.barMoveTimer / BarMoveDuration )
					local lerpSteps = GetRaidGuiMilestone( lerpValue )
					local lerpFraction = GetRaidGuiFraction( lerpValue )
					if not GetRaidIsSuper( lerpValue ) then
						if RaidPanelGui.index.RaidBar.Alpha < 1 then
							local newAlpha = lerp( 0.0, 1.0, raid.cl.alphaSwapTimer / SuperBarAlphaSwapTime )
							RaidPanelGui.index.RaidBar.Alpha = newAlpha
							for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
								data.Alpha = newAlpha
							end
							raid.cl.alphaSwapTimer = raid.cl.alphaSwapTimer + deltaTime
						end
						if not isLoss and not activeAttack then
							for i = 1, #RaidPanelGui.raidBars do
								RaidPanelGui.raidBars[i].width = math.min( math.floor( lerpSteps * BarSectionWidth + lerpFraction * BarSectionWidth ), BarSectionWidth * i )
								RaidPanelGui.raidBars[i].Visible = lerpSteps + 1 >= i
							end
							for i = 1, math.min( lerpSteps, #RaidPanelGui.milestones ) do
								local playEffect = RaidPanelGui.milestones[i].Visible == false
								if playEffect then
									local widget = raid.cl.raidStatusJsonGui:getWidget( MilestoneEffectBoxNames[i] )
									if widget then
										widget:startEffect( "ping" )
									end
								end
								RaidPanelGui.milestones[i].Visible = true
							end
							local enableHighlight = false
							local fromStep = GetRaidGuiMilestone( fromValue )
							local toSteps = GetRaidGuiMilestone( raid.raidSync.value )
							if fromStep < toSteps then
								enableHighlight = true
							end
							if not enableHighlight then
								local fromFraction = GetRaidGuiFraction( fromValue )
								local toFraction = GetRaidGuiFraction( raid.raidSync.value )
								if toFraction - fromFraction >= 0.12 then
									enableHighlight = true
								end
							end
							RaidPanelGui.index.RaidBarHighlight.Visible = enableHighlight
							if enableHighlight then
								RaidPanelGui.index.RaidBarHighlightEffect.Effects[1].PlayState = "Auto play once"
							end
							if lerpSteps + 1 <= #RaidPanelGui.raidBars then
								RaidPanelGui.index.RaidBarHighlight.x = RaidPanelGui.raidBars[lerpSteps + 1].width + 1
								RaidPanelGui.index.RaidBarHighlightEffect.x = RaidPanelGui.raidBars[lerpSteps + 1].width
							end
						else
							RaidPanelGui.index.RaidBarPreview.width = math.floor( lerpSteps * BarSectionWidth + lerpFraction * BarSectionWidth )
							for i = lerpSteps + 1, #RaidPanelGui.milestones do
								RaidPanelGui.milestones[i].Visible = false
							end
							for i = 1, math.min( fullSteps, #RaidPanelGui.milestones ) do
								RaidPanelGui.milestones[i].Visible = true
							end
						end
					else -- Super bar
						RaidPanelGui.index.RaidBarSuper.Visible = true
						RaidPanelGui.index.RaidBarHighlightEffect.Visible = false
						if RaidPanelGui.index.RaidBar.Alpha == 1 then
							for i = 1, #RaidPanelGui.milestones do
								RaidPanelGui.milestones[i].Visible = false
							end
						end
						if RaidPanelGui.index.RaidBar.Alpha > 0 then
							local newAlpha = lerp( 1.0, 0.0, raid.cl.alphaSwapTimer / SuperBarAlphaSwapTime )
							RaidPanelGui.index.RaidBar.Alpha = newAlpha
							for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
								data.Alpha = newAlpha
							end
							raid.cl.alphaSwapTimer = raid.cl.alphaSwapTimer + deltaTime
						end

						local superLerpFraction = GetRaidSuperFraction( lerpValue )
						if not isLoss and not activeAttack then
							RaidPanelGui.index.RaidBarFillSuper.width = math.floor( SuperBarWidth * superLerpFraction )
							RaidPanelGui.index.RaidBarHighlightSuper.x = RaidPanelGui.index.RaidBarFillSuper.width + 1
							RaidPanelGui.index.RaidBarHighlightSuperEffect.x = RaidPanelGui.index.RaidBarFillSuper.width
							local enableHighlight = false
							local fromFraction = GetRaidSuperFraction( fromValue )
							local toFraction = GetRaidSuperFraction( raid.raidSync.value )
							if toFraction - fromFraction > 0.04 then
								enableHighlight = true
							end
							RaidPanelGui.index.RaidBarHighlightSuper.Visible = enableHighlight

							if enableHighlight then
								RaidPanelGui.index.RaidBarHighlightSuperEffect.Effects[1].PlayState = "Auto play once"
							end
						else
							local superAbsolueFraction = GetRaidSuperFraction( raid.raidSync.value )
							RaidPanelGui.index.RaidBarFillSuper.width = math.floor( SuperBarWidth * superAbsolueFraction )
							RaidPanelGui.index.RaidBarPreviewSuper.width = math.floor( SuperBarWidth * superLerpFraction )
						end
					end
					if lerpValue == raid.raidSync.value then
						raid.cl.fromValue = nil
					end
				else
					raid.cl.fromValue = nil
					if not raid.cl.previousShowGui then
						if GetRaidIsSuper( raid.raidSync.value ) then
							RaidPanelGui.index.RaidBar.Alpha = 0
							for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
								data.Alpha = 0
							end
							local superLerpFraction = GetRaidSuperFraction( raid.raidSync.value )
							local superAbsolueFraction = GetRaidSuperFraction( raid.raidSync.value )
							RaidPanelGui.index.RaidBarFillSuper.width = math.floor( SuperBarWidth * superAbsolueFraction )
							RaidPanelGui.index.RaidBarPreviewSuper.width = math.floor( SuperBarWidth * superLerpFraction )
						else
							RaidPanelGui.index.RaidBar.Alpha = 1
							for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
								data.Alpha = 1
							end
							for i = 1, #RaidPanelGui.raidBars do
								RaidPanelGui.raidBars[i].width = math.min( math.floor( fullSteps * BarSectionWidth + fraction * BarSectionWidth ), BarSectionWidth * i )
								RaidPanelGui.raidBars[i].Visible = fullSteps + 1 >= i
							end
							for i = 1, math.min( fullSteps, #RaidPanelGui.milestones ) do
								RaidPanelGui.milestones[i].Visible = true
							end
						end
					end
				end
				raid.cl.barMoveTimer = raid.cl.barMoveTimer + deltaTime
			end
			raid.cl.barDelayTimer = raid.cl.barDelayTimer + deltaTime
			raid.cl.raidStatusJsonGui:render( RaidPanelGui.root )
		elseif not showInfo then
			-- Destroy gui
			if raid.cl.raidStatusJsonGui then
				raid.cl.raidStatusJsonGui:close()
				raid.cl.raidStatusJsonGui = nil
				raid.cl.startEffectPlayed = false
				raid.cl.guiCreationTick = nil
				RaidPanelGui.index.RaidActiveStartEffect.Effects[1].PlayState = "Stopped"
				RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState = "Stopped"
				RaidPanelGui.index.RaidActiveStartEffect.Effects[3].PlayState = "Stopped"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[1].PlayState = "Stopped"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState = "Stopped"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[3].PlayState = "Stopped"
			end
		end

		-- active raid effect activations
		if activeAttack and raid.cl.raidStatusJsonGui and ( currentTick - raid.cl.guiCreationTick ) < GuiFadeInDuration * 40 then -- Effect when entering active raid area
			if GetRaidIsSuper( raid.raidSync.value ) then
				if not raid.cl.startEffectPlayed then
					raid.cl.startEffectPlayed = true
					RaidPanelGui.index.RaidActiveStartEffect.Effects[3].PlayState = "Stopped"
					RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[3].PlayState = "Auto play once"
				end
			else
				if not raid.cl.startEffectPlayed then
					raid.cl.startEffectPlayed = true
					RaidPanelGui.index.RaidActiveStartEffect.Effects[3].PlayState = "Auto play once"
					RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[3].PlayState = "Stopped"
				end
			end
		end

		if activeAttack and raid.cl.raidStatusJsonGui and ( RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState == "Stopped" or RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState == "Stopped" ) then
			if GetRaidIsSuper( raid.raidSync.value ) and RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState == "Stopped" then
				RaidPanelGui.index.RaidActiveStartEffect.Effects[1].PlayState = "Stopped"
				RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState = "Stopped"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[1].PlayState = "Auto play once"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState = "Auto play once"
			elseif not GetRaidIsSuper( raid.raidSync.value ) and RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState == "Stopped" then
				RaidPanelGui.index.RaidActiveStartEffect.Effects[1].PlayState = "Auto play once"
				RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState = "Auto play once"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[1].PlayState = "Stopped"
				RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState = "Stopped"
			end
		end

		if showMarker then
			-- Create marker gui
			if not showInfo then
				if raid.cl.markerEffectFar == nil then
					raid.cl.markerEffectFar = sm.effect.createEffect( "RaidMarkerFar" )
					raid.cl.markerEffectFar:setPosition( raid.cl.guiWorldPosition + RaidMarkerOffset )
				end
				if raid.cl.markerEffectFar and not raid.cl.markerEffectFar:isPlaying() then
					raid.cl.markerEffectFar:start()
				end
				if raid.cl.markerEffectFar then
					-- Update gui position
					if raid.cl.guiWorldPosition and ( raid.cl.previousPosition == nil or raid.cl.previousPosition ~= raid.cl.guiWorldPosition ) then
						raid.cl.markerEffectFar:setPosition( raid.cl.guiWorldPosition + RaidMarkerOffset )
					end
				end
				if raid.cl.markerEffectNear and raid.cl.markerEffectNear:isPlaying() then
					raid.cl.markerEffectNear:stop()
				end
			else
				if raid.cl.markerEffectNear == nil then
					raid.cl.markerEffectNear = sm.effect.createEffect( "RaidMarkerNear" )
					raid.cl.markerEffectNear:setPosition( raid.cl.guiWorldPosition + RaidMarkerOffset )
					if raid.raidSync.attackData.attackTick then
						local stringValue, numericalValue = GetCountdownText( raid, currentTick )
						raid.cl.markerEffectNear:setParameter( "TextContent", stringValue )
					end
	
					if raid.cl.compassPlaced == nil and g_compassHud then
						raid.cl.compassPlaced = true
						g_compassHud:compassAddIcon( raid.raidSync.key, "icon_compass_bot.png" )
						g_compassHud:compassSetIconWorldPosition( raid.raidSync.key, raid.raidSync.center )
						g_compassHud:setVisible( raid.raidSync.key, true )
					end
				end
				if raid.cl.markerEffectNear and not raid.cl.markerEffectNear:isPlaying() then
					raid.cl.markerEffectNear:start()
				end
				if raid.cl.markerEffectNear then
					-- Update gui text
					if raid.cl.guiWorldPosition and ( raid.cl.previousPosition == nil or raid.cl.previousPosition ~= raid.cl.guiWorldPosition ) then
						raid.cl.markerEffectNear:setPosition( raid.cl.guiWorldPosition + RaidMarkerOffset )
						if raid.cl.compassPlaced and g_compassHud then
							g_compassHud:compassSetIconWorldPosition( raid.raidSync.key, raid.cl.guiWorldPosition )
						end
					end
					if raid.raidSync.attackData.attackTick then
						local stringValue, numericalValue = GetCountdownText( raid, currentTick )
						raid.cl.markerEffectNear:setParameter( "TextContent", stringValue )
						Cl_TryPlayCountdownEffect( raid, numericalValue )
					else
						raid.cl.markerEffectNear:setParameter( "TextContent", "" )
						raid.cl.markerEffectNear:setParameter( "textureIndex", 2 )
					end
				end
				if raid.cl.markerEffectFar and raid.cl.markerEffectFar:isPlaying() then
					raid.cl.markerEffectFar:stop()
				end
			end
			if activeAttack and ( raid.cl.lastActivationTick == nil or ( currentTick - raid.cl.lastActivationTick ) > TicksBetweenLockOnEffects ) then
				if raid.cl.cropEffects == nil then
					raid.cl.cropEffects = {}
					local player = sm.localPlayer.getPlayer()
					local character = player and player.character
					if character then
						local playerPosition = sm.localPlayer.getPlayer().character.worldPosition
						local function ascendingSort( a, b )
							return ( a.worldPosition - playerPosition ):length2() < ( b.worldPosition - playerPosition ):length2()
						end
						table.sort( raid.raidSync.crops, ascendingSort )
					end
				end
				for _,crop in ipairs( raid.raidSync.crops ) do
					if sm.exists( crop ) then
						if raid.cl.cropEffects[crop.id] == nil then
							raid.cl.cropEffects[crop.id] = sm.effect.createEffect( "Raid - Lockontarget" )
							raid.cl.cropEffects[crop.id]:setPosition( crop.worldPosition + sm.vec3.new( 0, 0, 0.3 ) )
							raid.cl.cropEffects[crop.id]:start()
							raid.cl.lastActivationTick = currentTick
							break
						end
					end
				end
			end
		else
			-- Destroy gui
			if raid.cl.markerEffectNear then
				raid.cl.markerEffectNear:destroy()
				raid.cl.markerEffectNear = nil
				if g_compassHud then
					g_compassHud:compassRemoveIcon( raid.raidSync.key )
				end
			end
			if raid.cl.markerEffectFar then
				raid.cl.markerEffectFar:destroy()
				raid.cl.markerEffectFar = nil
			end
			if g_compassHud then
				if raid.cl.compassMarkers then
					for _,pointData in pairs( raid.cl.compassMarkers ) do
						g_compassHud:compassRemoveIcon( pointData.name )
					end
				end
			end
		end
		raid.cl.isClosest = nil
		raid.cl.previousShowGui = showInfo
	end
	if closestRaidId and raids[closestRaidId] then
		raids[closestRaidId].cl.isClosest = true
	end

	if anyRaidControllingGui then
		if self.cl.localPlayerPlantingGui == nil then
			self.cl.localPlayerPlantingGui = sm.jsonGui.createGui( { isHud = true, needsCursor = false, isInteractive = false } )
		end
	end

	if self.cl.heldPlant and GetPlantValue( self.cl.heldPlant ) > 0 and not anyRaidControllingGui then
		local plantValue = GetPlantValue( self.cl.heldPlant )
		if plantValue == 0 then
			return
		end
		if self.cl.localPlayerPlantingGui == nil then
			self.cl.localPlayerPlantingGui = sm.jsonGui.createGui( { isHud = true, needsCursor = false, isInteractive = false } )
		end
		RaidPanelGui.raidBars[1].width = 0
		RaidPanelGui.raidBars[2].width = 0
		RaidPanelGui.raidBars[3].width = 0
		for i = 1, #RaidPanelGui.milestones do
			RaidPanelGui.milestones[i].Visible = false
		end

		local level = GetRaidGuiMilestone( plantValue )
		local fraction = GetRaidGuiFraction( plantValue )
		local newColor = sm.color.lerp( PreviewBarColor1, PreviewBarColor2, ( math.sin( math.rad( self.cl.oscillationTimer * 180 / OscillationFrequency ) ) + 1 ) * 0.5 )
		RaidPanelGui.index.RaidBarPreview.Colour = newColor:getGuiColorStr()
		self.cl.oscillationTimer = self.cl.oscillationTimer + deltaTime

		RaidPanelGui.index.RaidBarPreview.width = math.floor( ( BarSectionWidth * level ) + ( fraction * BarSectionWidth ) )
		self:cl_handleGuiFade( true, deltaTime )

	elseif self.cl.localPlayerPlantingGui and not anyRaidControllingGui then
		self:cl_handleGuiFade( anyRaidControllingGui, deltaTime )
	elseif not anyRaidControllingGui and RaidPanelGui.raidBars[1].width > 0 then
		-- reset values
		self.cl.oscillationTimer = 0
		RaidPanelGui.raidBars[1].width = 0
		RaidPanelGui.raidBars[2].width = 0
		RaidPanelGui.raidBars[3].width = 0
		RaidPanelGui.index.RaidBarPreview.width = 0
		RaidPanelGui.index.RaidBarPreview.Colour = "1 1 1 1"
		RaidPanelGui.index.RaidBarPreviewSuper.width = 0
		RaidPanelGui.index.RaidBarFillSuper.width = 0
		RaidPanelGui.index.RaidActiveStartEffect.Effects[1].PlayState = "Stopped"
		RaidPanelGui.index.RaidActiveStartEffect.Effects[2].PlayState = "Stopped"
		RaidPanelGui.index.RaidActiveStartEffect.Effects[3].PlayState = "Stopped"
		RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[1].PlayState = "Stopped"
		RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[2].PlayState = "Stopped"
		RaidPanelGui.index.SuperRaidActiveStartEffect.Effects[3].PlayState = "Stopped"
		for i = 1, #RaidPanelGui.milestones do
			RaidPanelGui.milestones[i].Visible = false
		end
		RaidPanelGui.index.RaidBarHighlightSuper.Visible = false
		RaidPanelGui.index.RaidBarHighlightSuperEffect.Effects[1].PlayState = "Stopped"
		RaidPanelGui.index.RaidBarHighlightEffect.Effects[1].PlayState = "Stopped"
		RaidPanelGui.index.RaidBar.Alpha = 1
		for _,data in ipairs( RaidPanelGui.index.RaidBar.Childs ) do
			data.Alpha = 1
		end
		RaidPanelGui.index.RaidBarPreview.width = 0
		self:cl_handleGuiFade( anyRaidControllingGui, deltaTime )
	end
end