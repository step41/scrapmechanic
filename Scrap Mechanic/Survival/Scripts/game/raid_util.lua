RAID_TARGET_POINT_COUNT = 3
RAID_SAMPLE_POINT_COUNT = 18
local RaidCellRange = 1
local MaxAttackRange = 45.0
local AcceptedSpawnPointOffsetSqr = 15 * 15
local CliffIdentifierCount = 5
local AllowedCliffPathChecks = 10
local CurvedPathAvoidanceThresholdSqr = 64.0
local CliffCheckSteppingDistance = 4
local AllowedHeightDifference = 4
local ReversalDistance = 5.0
local AvoidedAttackRangeSqr = ( MaxAttackRange / 2 ) * ( MaxAttackRange / 2 )
local Degrees = 360 / RAID_SAMPLE_POINT_COUNT
local RaycastHeightOffset = sm.vec3.new( 0, 0, 128 )





function GetRaidCellRange()
    return RaidCellRange
end

local function filterSpawnPoints( spawnPoints, origin )
    local spawnPointData = {}
    local pointsInAvoidedAttackRange = 0

    for _,spawnInfo in ipairs( spawnPoints ) do
        if spawnInfo.path and not IsEmptyTable( spawnInfo.path ) then
            local startPosition = spawnInfo.path[#spawnInfo.path].toNode:getPosition()
            local birdDistanceSqr = ( origin - startPosition ):length2()
            local totalWalkingDistance = 0
            for index,point in ipairs( spawnInfo.path ) do
                if index > 1 then
                    totalWalkingDistance = totalWalkingDistance + ( point.toNode:getPosition() - spawnInfo.path[index-1].toNode:getPosition() ):length()
                end
            end
            if birdDistanceSqr < AvoidedAttackRangeSqr then
                pointsInAvoidedAttackRange = pointsInAvoidedAttackRange + 1
            end
            spawnPointData[#spawnPointData+1] = { birdDistanceSqr = birdDistanceSqr, totalWalkingDistance = totalWalkingDistance }
        end
    end

    local removedIndexes = {}
    for index,pathData in reverse_ipairs( spawnPointData ) do
        if pointsInAvoidedAttackRange == 0 then
            if pathData.totalWalkingDistance / MaxAttackRange > 1.5 or pathData.totalWalkingDistance / MaxAttackRange < 0.75 then
                table.remove( spawnPoints, index )
                removedIndexes[#removedIndexes+1] = index
            end
        elseif #spawnPointData > pointsInAvoidedAttackRange then
            if pathData.birdDistanceSqr < AvoidedAttackRangeSqr then
                table.remove( spawnPoints, index )
                removedIndexes[#removedIndexes+1] = index
            end
        end
        if #removedIndexes >= ( #spawnPointData - 1 ) then -- cant remove everything
            break
        end
    end

    return spawnPoints
end

local function getPositionAtBestDistance( pointList, origin )
    local returnPoint = pointList[#pointList].toNode:getPosition()
    local selectedIndex = 1
    for i,point in ipairs( pointList ) do
        local direction = sm.vec3.new( 0, 0, 0 )
        if i > 1 then
            local toPoint = ( pointList[i-1].toNode:getPosition() - point.toNode:getPosition() )
            direction = toPoint:safeNormalize( sm.vec3.new( 0, 0, 0 ) )
        else
            local toPoint = ( origin - point.toNode:getPosition() )
            direction = toPoint:safeNormalize( sm.vec3.new( 0, 0, 0 ) )
        end
        selectedIndex = i
        returnPoint = point.toNode:getPosition() + direction * 3
    end

    -- step back through points that are close to each other until we find a point that has longer distance to previous
    -- this helps spawn points from being placed on cliffsides and close to corners
    if selectedIndex > 1 then
        if not ( ( pointList[selectedIndex].toNode:getPosition() - pointList[selectedIndex-1].toNode:getPosition() ):length2() >= CurvedPathAvoidanceThresholdSqr ) then
            for i = selectedIndex, 2, -1 do
                local fromPoint = pointList[i].toNode:getPosition()
                local toPoint = pointList[i-1].toNode:getPosition()
                local direction = ( toPoint - fromPoint ):safeNormalize( sm.vec3.new( 1, 0, 0 ) )
                local distSqr = ( toPoint - fromPoint ):length2()
                if distSqr >= CurvedPathAvoidanceThresholdSqr then
                    returnPoint = pointList[i].toNode:getPosition() + direction * ReversalDistance
                    break
                end
            end
        end
    end

    return returnPoint
end

local function selectPointsFromCollection( spawnPoints, world )
    local selectedMainSpawns = {}
    for _,spawnInfo in ipairs( spawnPoints ) do
        selectedMainSpawns[#selectedMainSpawns+1] = spawnInfo
    end
    if #selectedMainSpawns > 0 and #selectedMainSpawns < RAID_TARGET_POINT_COUNT then
        for i = #selectedMainSpawns + 1, RAID_TARGET_POINT_COUNT do
            selectedMainSpawns[#selectedMainSpawns+1].path = selectedMainSpawns[i -1].path
        end
    end



	local updatedMainPositions = {}
	for _,info in ipairs( selectedMainSpawns ) do
		local enemySpawnPosition = getPositionAtBestDistance( info.path, info.path[1].toNode:getPosition() ) -- gets the position at max walking distance from attack point
		enemySpawnPosition = sm.pathfinder.constrainPointToNavMesh( world, enemySpawnPosition )













		updatedMainPositions[#updatedMainPositions+1] = { path = enemySpawnPosition, material = info.material }
	end
    return updatedMainPositions
end

function FilterAndSelectPoints( spawnPoints, world, attackPosition )
    spawnPoints = filterSpawnPoints( spawnPoints, attackPosition )
    return selectPointsFromCollection( spawnPoints, world )
end

function CreateRaidPath( attackPosition, world, rotationValue, index )
    local spawnPoint = nil
    local targetIsOnCliff = nil
    local offset = sm.vec3.new( 1, 1, 0 ):safeNormalize( sm.vec3.new( 1, 0, 0 ) ) * MaxAttackRange
    local directionOffset = offset:rotateZ( rotationValue ):rotateZ( math.rad( index * Degrees ) )
    local raycastPoint = attackPosition + directionOffset
    local success, hitPoint = sm.physics.raycast( raycastPoint + RaycastHeightOffset, raycastPoint - RaycastHeightOffset, nil, sm.physics.filter.default - sm.physics.filter.harvestable, world )
    local currentDistanceMultiplier = 1.0

    -- Step out of water in case we are targeting water
    while ( success == false or sm.physics.isPointInLiquid( hitPoint.pointWorld, world ) ) and currentDistanceMultiplier > 0.0 do
        currentDistanceMultiplier = currentDistanceMultiplier - 0.1
        raycastPoint = attackPosition + directionOffset * currentDistanceMultiplier
        success, hitPoint = sm.physics.raycast( raycastPoint + RaycastHeightOffset, raycastPoint - RaycastHeightOffset, nil, sm.physics.filter.default - sm.physics.filter.harvestable, world )
    end






    if success then
        local spawnToTargetPointPath = sm.pathfinder.getWorldPath( world, hitPoint.pointWorld, attackPosition, { canWalk = true, canSwim = false } )

        while currentDistanceMultiplier > 0.0 do
            local pathFound = false
            if #spawnToTargetPointPath > 0 then
                local pathEnd = spawnToTargetPointPath[#spawnToTargetPointPath].toNode:getPosition()
                if ( pathEnd - attackPosition ):length2() <= AcceptedSpawnPointOffsetSqr then -- path reached close enough or to the player's defenses. not on a cliff
                    local reversePath = {}
                    for _, pathPoint in reverse_ipairs( spawnToTargetPointPath ) do
                        reversePath[#reversePath+1] = pathPoint
                    end
                    print( "adding path from spawn to target with size of: ", #reversePath )
                    spawnPoint = { path = reversePath, material = hitPoint:getTerrainAssetMaterialName() }
                    pathFound = true
                elseif targetIsOnCliff == nil then -- path did not reach. check static shape blockers
                    local cliffPathCounter = 0
                    
                    local cliffPathingEndPoint = spawnToTargetPointPath[#spawnToTargetPointPath].toNode:getPosition()
                    local vecToTarget = attackPosition - cliffPathingEndPoint
                    local directionToTarget = vecToTarget:safeNormalize( sm.vec3.new( 1, 0, 0 ) )
                    local castToPos = cliffPathingEndPoint + directionToTarget * CliffCheckSteppingDistance
                    local wallHit, _ = sm.physics.spherecast( cliffPathingEndPoint, castToPos, 0.5, nil, sm.physics.filter.staticBody, world )
                    local pathCheck = spawnToTargetPointPath
                    
                    if wallHit then -- path was blocked by a static shape, step over it and check if it is on a cliff
                        while cliffPathCounter < AllowedCliffPathChecks and targetIsOnCliff == nil and not pathFound do
                            local nextPoint = cliffPathingEndPoint + directionToTarget * CliffCheckSteppingDistance
                            local castSuccess, castHit = sm.physics.raycast( nextPoint + RaycastHeightOffset, nextPoint - RaycastHeightOffset, nil, sm.physics.filter.terrainSurface + sm.physics.filter.terrainAsset, world )
                            if castSuccess then
                                if math.abs( cliffPathingEndPoint.z - castHit.pointWorld.z ) > AllowedHeightDifference then -- check if the point is on top of a cliff we cant path to
                                    -- do multiple raycasts and check if a majority hit a terrain asset
                                    local distanceToNextPoint = ( cliffPathingEndPoint - castHit.pointWorld ):length()
                                    local cliffRaycastPoint = sm.vec3.new( cliffPathingEndPoint.x, cliffPathingEndPoint.y, castHit.pointWorld.z )
                                    local castDirection = sm.vec3.new( directionToTarget.x, directionToTarget.y, 0 ):safeNormalize( sm.vec3.new( 1, 0, 0 ) )
                                    local perpendicular = castDirection:cross( sm.vec3.new( 0, 0, 1 ) )
                                    local cliffHitCount = 0

                                    for castAngleMultiplier = 1, 9 do
                                        local toPoint = cliffRaycastPoint + castDirection:rotate( math.rad( -10 * castAngleMultiplier ), perpendicular ) * distanceToNextPoint * 1.1
                                        local cliffCastSuccess, _ = sm.physics.raycast( cliffRaycastPoint, toPoint, nil, sm.physics.filter.terrainAsset, world )





                                        if cliffCastSuccess then
                                            cliffHitCount = cliffHitCount + 1
                                        end
                                        if cliffHitCount >= CliffIdentifierCount then -- a majority of the raycasts hit a a terrain asset. we can assume it is a cliff
                                            targetIsOnCliff = true
                                            break
                                        end
                                    end
                                    if not targetIsOnCliff then
                                        targetIsOnCliff = false
                                    end
                                end

                                if not targetIsOnCliff then
                                    pathCheck = sm.pathfinder.getWorldPath( world, castHit.pointWorld, attackPosition, { canWalk = true, canSwim = false } )
                                    if #pathCheck > 0 then
                                        cliffPathingEndPoint = pathCheck[#pathCheck].toNode:getPosition()
                                        vecToTarget = attackPosition - cliffPathingEndPoint
                                        directionToTarget = vecToTarget:safeNormalize( sm.vec3.new( 1, 0, 0 ) )
                                        castToPos = cliffPathingEndPoint + directionToTarget * CliffCheckSteppingDistance

                                        if vecToTarget:length2() <= AcceptedSpawnPointOffsetSqr then
                                            local reversePath = {}
                                            for _, pathPoint in reverse_ipairs( spawnToTargetPointPath ) do
                                                reversePath[#reversePath+1] = pathPoint
                                            end
                                            pathFound = true
                                            print( "adding successful cliff traversal path: ", #reversePath )
                                            spawnPoint = { path = reversePath, material = hitPoint:getTerrainAssetMaterialName() }
                                            break
                                        end
                                    end
                                end
                            else
                                break
                            end
                            cliffPathCounter = cliffPathCounter + 1
                        end
                    end
                end
            end

            if pathFound then
                break
            else
                raycastPoint = attackPosition + directionOffset * currentDistanceMultiplier
                success, hitPoint = sm.physics.raycast( raycastPoint + RaycastHeightOffset, raycastPoint - RaycastHeightOffset, nil, sm.physics.filter.default - sm.physics.filter.harvestable, world )
                currentDistanceMultiplier = currentDistanceMultiplier - 0.1
                spawnToTargetPointPath = {}
                if success then
                    spawnToTargetPointPath = sm.pathfinder.getWorldPath( world, hitPoint.pointWorld, attackPosition, { canWalk = true, canSwim = false } )
                end
            end
        end
    else
        print("failed the raycast")





    end
    return spawnPoint
end


local RaidEnemyRandomList = {
	[tostring( unit_tapebot_green_1 )] = { unit_tapebot_green_1, unit_tapebot_green_2, unit_tapebot_green_3 },
	[tostring( unit_tapebot )] = { unit_tapebot, unit_tapebot_taped_1, unit_tapebot_taped_2, unit_tapebot_taped_3 }
}

local RaidEnemyRandomToBase = {
	[tostring( unit_tapebot_green_1 )] = unit_tapebot_green_1,
	[tostring( unit_tapebot_green_2 )] = unit_tapebot_green_1,
	[tostring( unit_tapebot_green_3 )] = unit_tapebot_green_1,
	[tostring( unit_tapebot )] = unit_tapebot,
	[tostring( unit_tapebot_taped_1 )] = unit_tapebot,
	[tostring( unit_tapebot_taped_2 )] = unit_tapebot,
	[tostring( unit_tapebot_taped_3 )] = unit_tapebot
}

function RaidEnemySubTypeRandomizer( enemyUuid )
	local stringUid = tostring( enemyUuid )
	if RaidEnemyRandomList[stringUid] then
		return RaidEnemyRandomList[stringUid][math.random( 1, #RaidEnemyRandomList[stringUid] )]
	end
	return enemyUuid
end

function RaidEnemySubTypeToBase( enemyUuid )
	local stringUid = tostring( enemyUuid )
	if not RaidEnemyRandomToBase[stringUid] then
		return enemyUuid
	end
	return RaidEnemyRandomToBase[stringUid] or enemyUuid
end



















