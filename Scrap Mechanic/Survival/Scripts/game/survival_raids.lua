dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"

------------------------------------------- CONTROL VALUES -------------------------------------------

local RaidLevelThresholds = { 0, 50, 100, 550, 1000, 5500, 10000 } -- Raid planting values for level 1-7
local RaidMaxValue = 100000 -- The maximum value for the raid level, used for the super fraction calculation
local DefaultGroupNextDropDelay = 2 -- The default time between group spawns (can be overwritten per group)
local DefaultGroupDistance = 30 -- The default distance from base for group spawns (can be overwritten per group)

function GetRaidLevel( value )
	if value > RaidLevelThresholds[#RaidLevelThresholds] then
		return #RaidLevelThresholds
	end
	for level, levelThreshold in reverse_ipairs( RaidLevelThresholds ) do
		if value >= levelThreshold then
			return math.min( level, #RaidLevelThresholds - 1 )
		end
	end
	return 0
end

function GetRaidLevelFraction( value )
	if value <= 0 then
		return 0
	end
	if value >= RaidMaxValue then
		return 1
	end
	local level = GetRaidLevel( value )
	local value0 = RaidLevelThresholds[level]
	local value1 = level < #RaidLevelThresholds and RaidLevelThresholds[level + 1] or RaidMaxValue
	local fraction = clamp( ( value - value0 ) / ( value1 - value0 ), 0, 1 )
	return fraction
end

local function GetMultiplayerBudgetModifier( playerCount )
	playerCount = playerCount or #sm.player.getAllPlayers()
	return math.min( 1 + ( playerCount - 1 ) * 0.5, 2 )
end

local CropData = {
	[tostring( hvs_growing_tomato )] = 		{ cost = 1 },
	[tostring( hvs_growing_potato )] = 		{ cost = 1 },
	[tostring( hvs_growing_carrot )] = 		{ cost = 2 },
	[tostring( hvs_growing_redbeet )] = 	{ cost = 5 },
	[tostring( hvs_growing_banana )] = 		{ cost = 15 },
	[tostring( hvs_growing_chili )] = 		{ cost = 15 },
	[tostring( hvs_growing_blueberry )] =	{ cost = 50 },
	[tostring( hvs_growing_orange )] = 		{ cost = 100 },
	[tostring( hvs_growing_broccoli )] = 	{ cost = 500 },
	[tostring( hvs_growing_pineapple )] = 	{ cost = 1000 },
}

function GetPlantValue( uidString )
	local data = CropData[uidString]
	if data and data.cost then
		return data.cost
	end
	return 0
end

local RaidLevelBudget = {
	[1] = { 2, 30 },
	[2] = { 20, 50 },
	[3] = { 75, 135 },
	[4] = { 125, 200 },
	[5] = { 300, 500 },
	[6] = { 500, 700 },
	[7] = { 1000, 5000 },
}

function GetRaidBudget( level, fraction, playerCount )
	local minBudget = RaidLevelBudget[level][1]
	local maxBudget = RaidLevelBudget[level][2]
	return math.ceil( fraction * ( maxBudget - minBudget ) + minBudget * GetMultiplayerBudgetModifier( playerCount ) )
end

local InitialSpawnGroups = {
	[1] = {
		{ enemyList = { { uuid = unit_haybot, quantity = 1 }, { uuid = unit_totebot_green, quantity = 2 } } },
	},
	[2] = {
		{ enemyList = { { uuid = unit_haybot, quantity = 3 }, { uuid = unit_totebot_green, quantity = 2 } } },
	},
	[3] = {
		{ enemyList = { { uuid = unit_haybot, quantity = 3 }, { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 } }, nextDropDelay = 2 },
	},
	[4] = {
		{ enemyList = { { uuid = unit_haybot, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 }, { uuid = unit_tapebot_green_1, quantity = 1 }, { uuid = unit_tapebot_yellow, quantity = 1 } }, nextDropDelay = 2 },
		{ enemyList = { { uuid = unit_haybot, quantity = 2 }, { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 }, { uuid = unit_tapebot_green_1, quantity = 1 } }, nextDropDelay = 2 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_red, quantity = 1 } }, nextDropDelay = 2 },
	},
	[5] = {
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 } }, nextDropDelay = 5 },
	},
	[6] = {
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 } }, nextDropDelay = 5 },
	},
	[7] = {
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 }, { uuid = unit_farmbot, quantity = 1 }, { uuid = unit_farmbot, quantity = 1 } }, nextDropDelay = 5 },
	},
}

local RaidLevelGroups = {
	 [1] = {
	 	{ enemyList = { { uuid = unit_totebot_green, quantity = 1 } }, cost = 2, weight = 1.0 },
	 	{ enemyList = { { uuid = unit_totebot_green, quantity = 2 } }, cost = 4, weight = 10.0 },
		{ enemyList = { { uuid = unit_haybot, quantity = 1 } }, cost = 5, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 1 } }, cost = 9, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 2 } }, cost = 12, weight = 100.0 },
	},
	[2] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 12, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 17, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 3 } }, cost = 19, weight = 100.0 },
	 },
	[3] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 12, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 17, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 3 } }, cost = 19, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_red, quantity = 1 } }, cost = 24, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot_green_1, quantity = 1 }, { uuid = unit_tapebot_yellow, quantity = 1 } }, cost = 16, weight = 50.0 },
	},
	[4] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 12, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 2 }, { uuid = unit_totebot_blue, quantity = 1 } }, cost = 17, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 3 } }, cost = 19, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_red, quantity = 1 } }, cost = 19, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_totebot_yellow, quantity = 1 } }, cost = 19, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot_green_1, quantity = 1 }, { uuid = unit_tapebot_yellow, quantity = 1 } }, cost = 16, weight = 50.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_tapebot_green_1, quantity = 2 }, { uuid = unit_tapebot_yellow, quantity = 1 } }, cost = 19, weight = 50.0 },
	 },
	[5] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 2 } }, cost = 14, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_haybot, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_blue, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_yellow, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_red, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot_green_1, quantity = 3 }, { uuid = unit_tapebot_yellow, quantity = 2 } }, cost = 31, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot, quantity = 2 } }, cost = 56, weight = 80.0 },
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 } }, cost = 75, weight = 60.0, nextDropDelay = 5 },
	 },
	[6] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 2 } }, cost = 14, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_haybot, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_blue, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_yellow, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_red, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot_green_1, quantity = 3 }, { uuid = unit_tapebot_yellow, quantity = 2 } }, cost = 31, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot, quantity = 2 } }, cost = 56, weight = 80.0 },
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 } }, cost = 75, weight = 60.0, nextDropDelay = 5 },
	},
	[7] = {
		{ enemyList = { { uuid = unit_totebot_green, quantity = 1 }, { uuid = unit_haybot, quantity = 1 } }, cost = 7, weight = 1.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 2 }, { uuid = unit_haybot, quantity = 2 } }, cost = 14, weight = 10.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_haybot, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_blue, quantity = 3 } }, cost = 21, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_yellow, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_totebot_red, quantity = 2 } }, cost = 36, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot_green_1, quantity = 3 }, { uuid = unit_tapebot_yellow, quantity = 2 } }, cost = 31, weight = 100.0 },
		{ enemyList = { { uuid = unit_totebot_green, quantity = 3 }, { uuid = unit_tapebot, quantity = 2 } }, cost = 56, weight = 80.0 },
		{ enemyList = { { uuid = unit_farmbot, quantity = 1 } }, cost = 75, weight = 60.0, nextDropDelay = 5 },
	},
}





























-----------------------------------------------------------------------------------------------------------------------------------

function GetInitialRaidGroup( value )
	local level = GetRaidLevel( value )
	local groups = InitialSpawnGroups[level]
	local totalWeight = 0
	for _,group in ipairs( groups ) do
		totalWeight = totalWeight + ( group.weight or 1 )
	end
	local randomValue = math.random() * totalWeight
	totalWeight = 0
	for _, group in ipairs( groups ) do
		totalWeight = totalWeight + ( group.weight or 1 )
		if randomValue <= totalWeight then
			return {
				enemyList = group.enemyList,
				nextDelay = math.floor( ( group.nextDropDelay or DefaultGroupNextDropDelay ) * 40 ),
				distance = group.distance or DefaultGroupDistance -- TODO: Use
			}
		end
	end
	return nil
end

function GetRaidGroups( value )
	local selectedGroups = {}
	local level = GetRaidLevel( value )
	local fraction = GetRaidLevelFraction( value )
	local budget = GetRaidBudget( level, fraction )

	local lowestCost = 0
	while budget >= lowestCost do
		local groups = {}
		local totalWeight = 0
		for _, group in ipairs( RaidLevelGroups[level] ) do
			local cost = math.max( group.cost or 1, 1 )
			if budget >= cost then
				groups[#groups + 1] = group
				totalWeight = totalWeight + ( group.weight or 1 )
				if lowestCost == 0 or cost < lowestCost then
					lowestCost = cost
				end
			end
		end
		if #groups == 0 then
			break
		end
		local randomValue = math.random() * totalWeight
		totalWeight = 0
		for _, group in ipairs( groups ) do
			totalWeight = totalWeight + ( group.weight or 1 )
			if randomValue <= totalWeight then
				selectedGroups[#selectedGroups + 1] = {
					enemyList = group.enemyList,
					nextDelay = math.floor( ( group.nextDropDelay or DefaultGroupNextDropDelay ) * 40 ),
					distance = group.distance or DefaultGroupDistance -- TODO: Use
				}
				local cost = math.max( group.cost or 1, 1 )
				budget = budget - cost
				break
			end
		end
	end
	return selectedGroups
end
