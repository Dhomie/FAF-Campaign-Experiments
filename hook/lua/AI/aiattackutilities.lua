local NavUtils = import("/lua/sim/navutils.lua")

--- Get the best target on a map based on platoon location
--- uses threat map and returns the center of one of the grids in the threat map
---@param aiBrain AIBrain           # aiBrain to use
---@param platoon Platoon           # platoon to find best target for
---@param bSkipPathability any      # skip check to see if platoon can path to destination
---@return table[]                  # A table representing the location of the best threat target
function GetBestThreatTarget(aiBrain, platoon, bSkipPathability)

    -- This is the primary function for determining what to attack on the map
    -- This function uses two user-specified types of "threats" to determine what to attack


    -- Specify what types of "threat" to attack
    -- Threat isn't just what's threatening, but is a measure of various
    -- strengths in the game.  For example, 'Land' threat is a measure of
    -- how many mobile land units are in a given threat area
    -- Economy is a measure of how many economy-generating units there are
    -- in a given threat area
    -- Overall is a sum of all the types of threats
    -- AntiSurface is a measure of  how much damage the units in an area can
    -- do to surface-dwelling units.
    -- there are many other types of threat... CATCH THEM ALL

    local PrimaryTargetThreatType = 'Land'
    local SecondaryTargetThreatType = 'Economy'


    -- These are the values that are used to weight the two types of "threats"
    -- primary by default is weighed most heavily, while a secondary threat is
    -- weighed less heavily
    local PrimaryThreatWeight = 20
    local SecondaryThreatWeight = 0.5

    -- After being sorted by those two types of threats, the places to attack are then
    -- sorted by distance.  So you don't have to worry about specifying that units go
    -- after the closest valid threat - they do this naturally.

    -- If the platoon we're sending is weaker than a potential target, lower
    -- the desirability of choosing that target by this factor
    local WeakAttackThreatWeight = 8 --10

    -- If the platoon we're sending is stronger than a potential target, raise
    -- the desirability of choosing that target by this factor
    local StrongAttackThreatWeight = 8


    -- We can also tune the desirability of a target based on various
    -- distance thresholds.  The thresholds are very near, near, mid, far
    -- and very far.  The Radius value represents the largest distance considered
    -- in a given category; the weight is the multiplicative factor used to increase
    -- the desirability for the distance category

    local VeryNearThreatWeight = 20000
    local VeryNearThreatRadius = 25

    local NearThreatWeight = 2500
    local NearThreatRadius = 75

    local MidThreatWeight = 500
    local MidThreatRadius = 150

    local FarThreatWeight = 100
    local FarThreatRadius = 300

    -- anything that's farther than the FarThreatRadius is considered VeryFar
    local VeryFarThreatWeight = 1

    -- if the platoon is weaker than this threat level, then ignore stronger targets if they're stronger by
    -- the given ratio
    --DUNCAN - Changed from 5
    local IgnoreStrongerTargetsIfWeakerThan = 10
    local IgnoreStrongerTargetsRatio = 10.0
    -- If the platoon is weaker than the target, and the platoon represents a
    -- larger fraction of the unitcap this this value, then ignore
    -- the strength of target - the platoon's death brings more units
    local IgnoreStrongerUnitCap = 0.8

    -- When true, ignores the commander's strength in determining defenses at target location
    local IgnoreCommanderStrength = true

    -- If the combined threat of both primary and secondary threat types
    -- is less than this level, then just outright ignore it as a threat
    local IgnoreThreatLessThan = 15
    -- if the platoon is stronger than this threat level, then ignore weaker targets if the platoon is stronger
    local IgnoreWeakerTargetsIfStrongerThan = 20

    -- When evaluating threat, how many rings in the threat grid do we look at
    local EnemyThreatRings = 1
    -- if we've already chosen an enemy, should this platoon focus on that enemy
    local TargetCurrentEnemy = true

    -----------------------------------------------------------------------------------

    local platoonPosition = platoon:GetPlatoonPosition()
    local selectedWeaponArc = 'None'

    if not platoonPosition then
        --Platoon no longer exists.
        return false
    end

    -- get overrides in platoon data
    local ThreatWeights = platoon.PlatoonData.ThreatWeights
    if ThreatWeights then
        PrimaryThreatWeight = ThreatWeights.PrimaryThreatWeight or PrimaryThreatWeight
        SecondaryThreatWeight = ThreatWeights.SecondaryThreatWeight or SecondaryThreatWeight
        WeakAttackThreatWeight = ThreatWeights.WeakAttackThreatWeight or WeakAttackThreatWeight
        StrongAttackThreatWeight = ThreatWeights.StrongAttackThreatWeight or StrongAttackThreatWeight
        FarThreatWeight = ThreatWeights.FarThreatWeight or FarThreatWeight
        NearThreatWeight = ThreatWeights.NearThreatWeight or NearThreatWeight
        NearThreatRadius = ThreatWeights.NearThreatRadius or NearThreatRadius
        IgnoreStrongerTargetsIfWeakerThan = ThreatWeights.IgnoreStrongerTargetsIfWeakerThan or IgnoreStrongerTargetsIfWeakerThan
        IgnoreStrongerTargetsRatio = ThreatWeights.IgnoreStrongerTargetsRatio or IgnoreStrongerTargetsRatio
        SecondaryTargetThreatType = SecondaryTargetThreatType or ThreatWeights.SecondaryTargetThreatType
        IgnoreCommanderStrength = IgnoreCommanderStrength or ThreatWeights.IgnoreCommanderStrength
        IgnoreWeakerTargetsIfStrongerThan = ThreatWeights.IgnoreWeakerTargetsIfStrongerThan or IgnoreWeakerTargetsIfStrongerThan
        IgnoreThreatLessThan = ThreatWeights.IgnoreThreatLessThan or IgnoreThreatLessThan
        PrimaryTargetThreatType = ThreatWeights.PrimaryTargetThreatType or PrimaryTargetThreatType
        SecondaryTargetThreatType = ThreatWeights.SecondaryTargetThreatType or SecondaryTargetThreatType
        EnemyThreatRings = ThreatWeights.EnemyThreatRings or EnemyThreatRings
        TargetCurrentEnemy = ThreatWeights.TargetCurrentyEnemy or TargetCurrentEnemy
    end

    -- Need to use overall so we can get all the threat points on the map and then filter from there
    -- if a specific threat is used, it will only report back threat locations of that type
    local enemyIndex = nil
    if aiBrain:GetCurrentEnemy() and TargetCurrentEnemy then
        enemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
    end

    local threatTable = aiBrain:GetThreatsAroundPosition(platoonPosition, 16, true, 'Overall', enemyIndex)

    if table.empty(threatTable) then
        return false
    end

    local platoonUnits = platoon:GetPlatoonUnits()
    --eval platoon threat
    local myThreat = GetThreatOfUnits(platoon)
    local friendlyThreat = aiBrain:GetThreatAtPosition(platoonPosition, 1, true, ThreatTable[platoon.MovementLayer], aiBrain:GetArmyIndex()) - myThreat
    friendlyThreat = friendlyThreat * -1

    local threatDist
    local curMaxThreat = -99999999
    local curMaxIndex = 1
    local foundPathableThreat = false
    local mapSizeX = ScenarioInfo.size[1]
    local mapSizeZ = ScenarioInfo.size[2]
    local maxMapLengthSq = math.sqrt((mapSizeX * mapSizeX) + (mapSizeZ * mapSizeZ))
    local logCount = 0

    local unitCapRatio = GetArmyUnitCostTotal(aiBrain:GetArmyIndex()) / GetArmyUnitCap(aiBrain:GetArmyIndex())

    local maxRange = false
    local turretPitch = nil
    if platoon.MovementLayer == 'Water' then
        maxRange, selectedWeaponArc = GetNavalPlatoonMaxRange(aiBrain, platoon)
    end

    for tIndex,threat in threatTable do
        --check if we can path to the position or a position nearby
        if not bSkipPathability then
            if platoon.MovementLayer != 'Water' then
                local success, bestGoalPos = CheckPlatoonPathingEx(platoon, {threat[1], 0, threat[2]})
                logCount = logCount + 1
                if not success then

                    local okThresholdSq = 32 * 32
                    local distSq = (threat[1] - bestGoalPos[1]) * (threat[1] - bestGoalPos[1]) + (threat[2] - bestGoalPos[3]) * (threat[2] - bestGoalPos[3])

                    if distSq < okThresholdSq then
                        threat[1] = bestGoalPos[1]
                        threat[2] = bestGoalPos[3]
                    else
                        continue
                    end
                else
                    threat[1] = bestGoalPos[1]
                    threat[2] = bestGoalPos[3]
                end
            else
                local bestPos = CheckNavalPathing(aiBrain, platoon, {threat[1], 0, threat[2]}, maxRange, selectedWeaponArc)
                if not bestPos then
                    continue
                end
            end
        end

        --threat[3] represents the best target

        -- calculate new threat
        -- for debugging
        --------------------------------
        local baseThreat = 0
        local targetThreat = 0
        local distThreat = 0

        local primaryThreat = 0
        local secondaryThreat = 0
        ----------------------------------

        -- Determine the value of the target
        primaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, 1, true, PrimaryTargetThreatType, enemyIndex)
        secondaryThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, 1, true, SecondaryTargetThreatType, enemyIndex)

        baseThreat = primaryThreat + secondaryThreat

        targetThreat = (primaryThreat or 0) * PrimaryThreatWeight + (secondaryThreat or 0) * SecondaryThreatWeight
        threat[3] = targetThreat

        -- Determine relative strength of platoon compared to enemy threat
        local enemyThreat = aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, EnemyThreatRings, true, ThreatTable[platoon.MovementLayer] or 'AntiSurface')
        if IgnoreCommanderStrength then
            enemyThreat = enemyThreat - aiBrain:GetThreatAtPosition({threat[1], 0, threat[2]}, EnemyThreatRings, true, 'Commander')
        end
        --defaults to no threat (threat difference is opposite of platoon threat)
        local threatDiff =  myThreat - enemyThreat

        --DUNCAN - Moved outside threatdiff check
        -- if we have no threat... what happened?  Also don't attack things way stronger than us
        if myThreat <= IgnoreStrongerTargetsIfWeakerThan
                and (myThreat == 0 or enemyThreat / (myThreat + friendlyThreat) > IgnoreStrongerTargetsRatio)
                and unitCapRatio < IgnoreStrongerUnitCap then
            continue
        end

        if threatDiff <= 0 then
            -- if we're weaker than the enemy... make the target less attractive anyway
            threat[3] = threat[3] + threatDiff * WeakAttackThreatWeight
        else
            -- ignore overall threats that are really low, otherwise we want to defeat the enemy wherever they are
            if (baseThreat <= IgnoreThreatLessThan) then
                continue
            end
            threat[3] = threat[3] + threatDiff * StrongAttackThreatWeight
        end

        -- only add distance if there's a threat at all
        local threatDistNorm = -1
        if targetThreat > 0 then
            threatDist = math.sqrt(VDist2Sq(threat[1], threat[2], platoonPosition[1], platoonPosition[3]))
            --distance is 1-100 of the max map length, distance function weights are split by the distance radius

            threatDistNorm = 100 * threatDist / maxMapLengthSq
            if threatDistNorm < 1 then
                threatDistNorm = 1
            end
            -- farther away is less threatening, so divide
            if threatDist <= VeryNearThreatRadius then
                threat[3] = threat[3] + VeryNearThreatWeight / threatDistNorm
                distThreat = VeryNearThreatWeight / threatDistNorm
            elseif threatDist <= NearThreatRadius then
                threat[3] = threat[3] + MidThreatWeight / threatDistNorm
                distThreat = MidThreatWeight / threatDistNorm
            elseif threatDist <= MidThreatRadius then
                threat[3] = threat[3] + NearThreatWeight / threatDistNorm
                distThreat = NearThreatWeight / threatDistNorm
            elseif threatDist <= FarThreatRadius then
                threat[3] = threat[3] + FarThreatWeight / threatDistNorm
                distThreat = FarThreatWeight / threatDistNorm
            else
                threat[3] = threat[3] + VeryFarThreatWeight / threatDistNorm
                distThreat = VeryFarThreatWeight / threatDistNorm
            end

            -- store max value
            if threat[3] > curMaxThreat then
                curMaxThreat = threat[3]
                curMaxIndex = tIndex
            end
            foundPathableThreat = true
       end --ignoreThreat
    end --threatTable loop

    --no pathable threat found (or no threats at all)
    if not foundPathableThreat or curMaxThreat == 0 then
        return false
    end
    local x = threatTable[curMaxIndex][1]
    local y = GetTerrainHeight(threatTable[curMaxIndex][1], threatTable[curMaxIndex][2])
    local z = threatTable[curMaxIndex][2]

    return {x, y, z}

end


--- Generate the attack vector by picking a good place to attack
--- returns the current command queue of all the units in the platoon if it worked
--- or an empty queue if it didn't. Simpler than the land version of this.
---@param aiBrain AIBrain       # aiBrain to use
---@param platoon Platoon       # platoon to find best target for
---@return table                # A table of every command in every command queue for every unit in the platoon or an empty table if it fails
function AIPlatoonNavalAttackVector(aiBrain, platoon)

    GetMostRestrictiveLayer(platoon)
    --Engine handles whether or not we can occupy our vector now, so this should always be a valid, occupiable spot.
    local attackPos = GetBestThreatTarget(aiBrain, platoon)
    if not platoon.PlatoonSurfaceThreat then
        platoon.PlatoonSurfaceThreat = platoon:GetPlatoonThreat('Surface', categories.ALLUNITS)
    end

	--[[-- If we don't have an attack position, ignore layer restrictions, we might be able to bombard the position from range
    if not attackPos then
        attackPos = GetBestThreatTarget(aiBrain, platoon, true)
		
		-- If we still don't have an attack position, get the default highest threat position, and use that.
		if not attackPos then
            attackPos, threat = aiBrain:GetHighestThreatPosition(1, true)
			if not attackPos or 0 >= threat then
				platoon:StopAttack()
				return {}
			end
        end
    end]]

    local oldPathSize = table.getn(platoon.LastAttackDestination)
    local path

    -- if we don't have an old path or our old destination and new destination are different
    if attackPos and (oldPathSize == 0 or attackPos[1] != platoon.LastAttackDestination[oldPathSize][1] or
    attackPos[3] != platoon.LastAttackDestination[oldPathSize][3]) then

        -- check if we can path to here safely... give a large threat weight to sort by threat first
        path = NavUtils.PathToWithThreatThreshold(platoon.MovementLayer, platoon:GetPlatoonPosition(), attackPos, aiBrain, NavUtils.ThreatFunctions.AntiSurface, platoon.PlatoonSurfaceThreat * 10, aiBrain.IMAPConfig.Rings)

        -- clear command queue
        platoon:Stop()

    end

    if not path then
        path = AINavalPlanB(aiBrain, platoon)
    end

    if path then
        platoon.LastAttackDestination = path
        -- move to new location
        platoon:IssueAggressiveMoveAlongRoute(path)
    end

    -- return current command queue
    local cmd = {}
    for k,v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            local unitCmdQ = v:GetCommandQueue()
            for cmdIdx,cmdVal in unitCmdQ do
                table.insert(cmd, cmdVal)
                break
            end
        end
    end
    return cmd
end

--- Generate the attack vector by picking a good place to attack, returns the current command queue of all the units in the platoon if it worked, or an empty queue if it didn't
---@param aiBrain AIBrain       # aiBrain to use
---@param platoon Platoon       # platoon to find best target for
---@param bAggro any            # Descriptor needed
---@return table                # A table of every command in every command queue for every unit in the platoon or an empty table if it fails
function AIPlatoonSquadAttackVector(aiBrain, platoon, bAggro)
    --Engine handles whether or not we can occupy our vector now, so this should always be a valid, occupiable spot.
    local attackPos = GetBestThreatTarget(aiBrain, platoon)
    if not platoon.PlatoonSurfaceThreat then
        platoon.PlatoonSurfaceThreat = platoon:GetPlatoonThreat('Surface', categories.ALLUNITS)
    end

    local bNeedTransports = false
	
    -- If we don't have an attack position, ignore layer restrictions, we might be able to bombard the position from range
    if not attackPos then
        attackPos = GetBestThreatTarget(aiBrain, platoon, true)
        bNeedTransports = true
		
		-- If we still don't have an attack position, get the default highest threat position, and use that.
        if not attackPos then
            attackPos, threat = aiBrain:GetHighestThreatPosition(1, true)
			if not attackPos or 0 >= threat then
				platoon:StopAttack()
				return {}
			end
        end
    end


    -- avoid mountains by slowly moving away from higher areas
    GetMostRestrictiveLayer(platoon)
    if platoon.MovementLayer == 'Land' then
        local bestPos = attackPos
        local attackPosHeight = GetTerrainHeight(attackPos[1], attackPos[3])
        -- if we're land
        if attackPosHeight >= GetSurfaceHeight(attackPos[1], attackPos[3]) then
            local lookAroundTable = {1,0,-2,-1,2}
            local squareRadius = (ScenarioInfo.size[1] / 16) / table.getn(lookAroundTable)
            for ix, offsetX in lookAroundTable do
                for iz, offsetZ in lookAroundTable do
                    local surf = GetSurfaceHeight(bestPos[1]+offsetX, bestPos[3]+offsetZ)
                    local terr = GetTerrainHeight(bestPos[1]+offsetX, bestPos[3]+offsetZ)
                    -- is it lower land... make it our new position to continue searching around
                    if terr >= surf and terr < attackPosHeight then
                        bestPos[1] = bestPos[1] + offsetX
                        bestPos[3] = bestPos[3] + offsetZ
                        attackPosHeight = terr
                    end
                end
            end
        end
        attackPos = bestPos
    end

    local oldPathSize = table.getn(platoon.LastAttackDestination)

    -- if we don't have an old path or our old destination and new destination are different
    if oldPathSize == 0 or attackPos[1] != platoon.LastAttackDestination[oldPathSize][1] or
    attackPos[3] != platoon.LastAttackDestination[oldPathSize][3] then

        GetMostRestrictiveLayer(platoon)
        -- check if we can path to here safely... give a large threat weight to sort by threat first
        local path, reason = NavUtils.PathToWithThreatThreshold(platoon.MovementLayer, platoon:GetPlatoonPosition(), attackPos, aiBrain, NavUtils.ThreatFunctions.AntiSurface, platoon.PlatoonSurfaceThreat * 10, aiBrain.IMAPConfig.Rings)

        -- clear command queue
        platoon:Stop()

        local usedTransports = false
        local position = platoon:GetPlatoonPosition()
		-- Require transports if we can't path to our destination
        if (not path and reason == 'NoPath') or bNeedTransports then
            -- usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, platoon, attackPos, 3, true)
			usedTransports = SendPlatoonWithTransportsNoCheck(aiBrain, platoon, attackPos, true)
        -- Use if possible over 500 away
        elseif VDist2Sq(position[1], position[3], attackPos[1], attackPos[3]) > 512*512 then
            -- usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, platoon, attackPos, 2, true)
			usedTransports = SendPlatoonWithTransportsNoCheck(aiBrain, platoon, attackPos, false)
        -- Use if possible at 250
        elseif VDist2Sq(position[1], position[3], attackPos[1], attackPos[3]) > 256*256 then
			usedTransports = SendPlatoonWithTransportsNoCheck(aiBrain, platoon, attackPos, false)
            -- usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, platoon, attackPos, 1, false)
        end

        if not usedTransports then
            if not path then
                if reason == 'NoStartNode' or reason == 'NoEndNode' then
                    --Couldn't find a valid pathing node. Just use shortest path.
                    platoon:AggressiveMoveToLocation(attackPos)
                end
                -- force reevaluation
                platoon.LastAttackDestination = {attackPos}
            else
                -- store path
                platoon.LastAttackDestination = path
                -- move to new location
                if bAggro then
                    platoon:IssueAggressiveMoveAlongRoute(path)
                else
                    platoon:IssueMoveAlongRoute(path)
                end
            end
        end
    end

    -- return current command queue
    local cmd = {}
    for k,v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            local unitCmdQ = v:GetCommandQueue()
            for cmdIdx,cmdVal in unitCmdQ do
                table.insert(cmd, cmdVal)
                break
            end
        end
    end
    return cmd
end

--- Find transports and use them to move platoon.  If bRequired is set, then have platoon
--- wait 60 seconds for transports before failing
---@param aiBrain AIBrain           # aiBrain to use
---@param platoon Platoon           # platoon to find best target for
---@param destination Vector        # table representing the destination location
---@param bRequired boolean         # wait for transports if there aren't any, since it's required to use them
---@param bSkipLastMove any         # don't do the final move... useful for when engineers use this function
---@param waitLonger any            # Need Descriptor
---@return boolean                  # true if successful, false if couldn't use transports
function SendPlatoonWithTransports(aiBrain, platoon, destination, bRequired, bSkipLastMove, waitLonger)

    GetMostRestrictiveLayer(platoon)

    local units = platoon:GetPlatoonUnits()

    -- only get transports for land (or partial land) movement
    if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then

        if platoon.MovementLayer == 'Land' then
            -- if it's water, this is not valid at all
            local terrain = GetTerrainHeight(destination[1], destination[2])
            local surface = GetSurfaceHeight(destination[1], destination[2])
            if terrain < surface then
                return false
            end
        end

        -- if we don't *need* transports, then just call GetTransports...
        if not bRequired then
            --  if it doesn't work, tell the aiBrain we want transports and bail
            if AIUtils.GetTransports(platoon) == false then
                aiBrain.WantTransports = true
                return false
            end
        else
            -- we were told that transports are the only way to get where we want to go...
            -- ask for a transport every 10 seconds
            local counter = 0
            if waitLonger then
                counter = -6
            end
            local transportsNeeded = AIUtils.GetNumTransports(units)
            local numTransportsNeeded = math.ceil((transportsNeeded.Small + (transportsNeeded.Medium * 2) + (transportsNeeded.Large * 4)) / 10)
            if not aiBrain.NeedTransports then
                aiBrain.NeedTransports = 0
            end
            aiBrain.NeedTransports = aiBrain.NeedTransports + numTransportsNeeded
            if aiBrain.NeedTransports > 10 then
                aiBrain.NeedTransports = 10
            end
            local bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
            while not bUsedTransports and counter < 6 do
                -- if we have overflow, self-destruct the overflow and just send what we can
                if not bUsedTransports and overflowSm + overflowMd + overflowLg > 0 then
                    local goodunits, overflow = AIUtils.SplitTransportOverflow(units, overflowSm, overflowMd, overflowLg)
                    local numOverflow = table.getn(overflow)
                    if table.getn(goodunits) > numOverflow and numOverflow > 0 then
                        for _, v in overflow do
                            if not v.Dead then
                                --aiBrain:AssignUnitsToPlatoon(pool, {v}, 'Unassigned', 'None')
								v:Kill()
                            end
                        end
                        units = goodunits
                    end
                end
                bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
                if bUsedTransports then
                    break
                end
                counter = counter + 1
                WaitSeconds(10)
                if not aiBrain:PlatoonExists(platoon) then
                    aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
                    if aiBrain.NeedTransports < 0 then
                        aiBrain.NeedTransports = 0
                    end
                    return false
                end

                local survivors = {}
                for _,v in units do
                    if not v.Dead then
                        table.insert(survivors, v)
                    end
                end
                units = survivors

            end

            aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
            if aiBrain.NeedTransports < 0 then
                aiBrain.NeedTransports = 0
            end

            -- couldn't use transports...
            if bUsedTransports == false then
                return false
            end
        end
        -- presumably, if we're here, we've gotten transports
        -- find an appropriate transport marker if it's on the map
        local transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Land Path Node', destination[1], destination[3])
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Transport Marker', destination[1], destination[3])
        end
        local useGraph = 'Land'
        if not transportLocation then
            -- go directly to destination, do not pass go.  This move might kill you, fyi.
            transportLocation = platoon:GetPlatoonPosition()
            useGraph = 'Air'
        end

        if transportLocation then
            local minThreat = aiBrain:GetThreatAtPosition(transportLocation, 0, true)
            if minThreat > 0 then
                local threatTable = aiBrain:GetThreatsAroundPosition(transportLocation, 1, true, 'Overall')
                for threatIdx,threatEntry in threatTable do
                    if threatEntry[3] < minThreat then
                        -- if it's land...
                        local terrain = GetTerrainHeight(threatEntry[1], threatEntry[2])
                        local surface = GetSurfaceHeight(threatEntry[1], threatEntry[2])
                        if terrain >= surface then
                           minThreat = threatEntry[3]
                           transportLocation = {threatEntry[1], 0, threatEntry[2]}
                       end
                    end
                end
            end
        end

        -- path from transport drop off to end location
        --local path, reason = PlatoonGenerateSafePathTo(aiBrain, useGraph, transportLocation, destination, 200)
		local path, reason = NavUtils.PathToWithThreatThreshold(platoon.MovementLayer, transportLocation, destination, aiBrain, NavUtils.ThreatFunctions.AntiSurface, platoon.PlatoonSurfaceThreat * 10, aiBrain.IMAPConfig.Rings)
		
        -- use the transport!
        AIUtils.UseTransports(units, platoon:GetSquadUnits('Scout'), transportLocation, platoon)

        -- just in case we're still landing...
        for _,v in units do
            if not v.Dead then
                if v:IsUnitState('Attached') then
                   WaitSeconds(2)
                end
            end
        end

        -- check to see we're still around
        if not platoon or not aiBrain:PlatoonExists(platoon) then
            return false
        end

        -- then go to attack location
        if not path then
            -- directly
            if not bSkipLastMove then
                platoon:AggressiveMoveToLocation(destination)
                platoon.LastAttackDestination = {destination}
            end
        else
            -- or indirectly
            -- store path for future comparison
            platoon.LastAttackDestination = path

            local pathSize = table.getn(path)
            --move to destination afterwards
            for wpidx,waypointPath in path do
                if wpidx == pathSize then
                    if not bSkipLastMove then
                        platoon:AggressiveMoveToLocation(waypointPath)
                    end
                else
                    platoon:MoveToLocation(waypointPath, false)
                end
            end
        end
    end

    return true
end

---@param aiBrain AIBrain
---@param platoon Platoon
---@param destination Vector
---@param bRequired any
---@param bSkipLastMove any
---@return boolean
function SendPlatoonWithTransportsNoCheck(aiBrain, platoon, destination, bRequired, bSkipLastMove)

    GetMostRestrictiveLayer(platoon)
    local units = platoon:GetPlatoonUnits()


    -- only get transports for land (or partial land) movement
    if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then

        -- DUNCAN - commented out, why check it?
        -- UVESO - If we reach this point, then we have either a platoon with Land or Amphibious MovementLayer.
        --         Both are valid if we have a Land destination point. But if we have a Amphibious destination
        --         point then we don't want to transport landunits.
        --         (This only happens on maps without AI path markers. Path graphing would prevent this.)
        if platoon.MovementLayer == 'Land' then
            local terrain = GetTerrainHeight(destination[1], destination[2])
            local surface = GetSurfaceHeight(destination[1], destination[2])
            if terrain < surface then
                return false
            end
        end

        -- if we don't *need* transports, then just call GetTransports...
        if not bRequired then
            --  if it doesn't work, tell the aiBrain we want transports and bail
            if AIUtils.GetTransports(platoon) == false then
                aiBrain.WantTransports = true
                return false
            end
        else
            -- we were told that transports are the only way to get where we want to go...
            -- ask for a transport every 10 seconds
            local counter = 0
            local transportsNeeded = AIUtils.GetNumTransports(units)
            local numTransportsNeeded = math.ceil((transportsNeeded.Small + (transportsNeeded.Medium * 2) + (transportsNeeded.Large * 4)) / 10)
            if not aiBrain.NeedTransports then
                aiBrain.NeedTransports = 0
            end
            aiBrain.NeedTransports = aiBrain.NeedTransports + numTransportsNeeded
            if aiBrain.NeedTransports > 10 then
                aiBrain.NeedTransports = 10
            end
            local bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
            while not bUsedTransports and counter < 9 do --DUNCAN - was 6
                -- if we have overflow, self-destruct the overflow and just send what we can
                if not bUsedTransports and overflowSm+overflowMd+overflowLg > 0 then
                    local goodunits, overflow = AIUtils.SplitTransportOverflow(units, overflowSm, overflowMd, overflowLg)
                    local numOverflow = table.getn(overflow)
                    if table.getn(goodunits) > numOverflow and numOverflow > 0 then
                        for _,v in overflow do
                            if not v.Dead then
                                v:Kill()
                            end
                        end
                        units = goodunits
                    end
                end
                bUsedTransports, overflowSm, overflowMd, overflowLg = AIUtils.GetTransports(platoon)
                if bUsedTransports then
                    break
                end
                counter = counter + 1
                WaitSeconds(10)
                if not aiBrain:PlatoonExists(platoon) then
                    aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
                    if aiBrain.NeedTransports < 0 then
                        aiBrain.NeedTransports = 0
                    end
                    return false
                end

                local survivors = {}
                for _,v in units do
                    if not v.Dead then
                        table.insert(survivors, v)
                    end
                end
                units = survivors

            end

            aiBrain.NeedTransports = aiBrain.NeedTransports - numTransportsNeeded
            if aiBrain.NeedTransports < 0 then
                aiBrain.NeedTransports = 0
            end

            -- couldn't use transports...
            if bUsedTransports == false then
                return false
            end
        end

        -- presumably, if we're here, we've gotten transports
        local transportLocation = false

        --DUNCAN - try the destination directly? Only do for engineers (eg skip last move is true)
        if bSkipLastMove then
            transportLocation = destination
        end

        --DUNCAN - try the land path nodefirst , not the transport marker as this will get units closer(thanks to Sorian).
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Land Path Node', destination[1], destination[3])
        end
        -- find an appropriate transport marker if it's on the map
        if not transportLocation then
            transportLocation = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Transport Marker', destination[1], destination[3])
        end

        local useGraph = 'Land'
        if not transportLocation then
            -- go directly to destination, do not pass go.  This move might kill you, fyi.
            transportLocation = AIUtils.RandomLocation(destination[1],destination[3]) --Duncan - was platoon:GetPlatoonPosition()
            useGraph = 'Air'
        end

        if transportLocation then
            local minThreat = aiBrain:GetThreatAtPosition(transportLocation, 0, true)
            if minThreat > 0 then
                local threatTable = aiBrain:GetThreatsAroundPosition(transportLocation, 1, true, 'Overall')
                for threatIdx,threatEntry in threatTable do
                    if threatEntry[3] < minThreat then
                        -- if it's land...
                        local terrain = GetTerrainHeight(threatEntry[1], threatEntry[2])
                        local surface = GetSurfaceHeight(threatEntry[1], threatEntry[2])
                        if terrain >= surface  then
                           minThreat = threatEntry[3]
                           transportLocation = {threatEntry[1], 0, threatEntry[2]}
                       end
                    end
                end
            end
        end

        -- path from transport drop off to end location
        --local path, reason = PlatoonGenerateSafePathTo(aiBrain, useGraph, transportLocation, destination, 200)
		local path, reason = NavUtils.PathToWithThreatThreshold(platoon.MovementLayer, transportLocation, destination, aiBrain, NavUtils.ThreatFunctions.AntiSurface, platoon.PlatoonSurfaceThreat * 10, aiBrain.IMAPConfig.Rings)
        -- use the transport!
        AIUtils.UseTransports(units, platoon:GetSquadUnits('Scout'), transportLocation, platoon)

        -- just in case we're still landing...
        for _,v in units do
            if not v.Dead then
                if v:IsUnitState('Attached') then
                   WaitSeconds(2)
                end
            end
        end

        -- check to see we're still around
        if not platoon or not aiBrain:PlatoonExists(platoon) then
            return false
        end

        -- then go to attack location
        if not path then
            -- directly
            if not bSkipLastMove then
                platoon:AggressiveMoveToLocation(destination)
                platoon.LastAttackDestination = {destination}
            end
        else
            -- or indirectly
            -- store path for future comparison
            platoon.LastAttackDestination = path

            local pathSize = table.getn(path)
            --move to destination afterwards
            for wpidx,waypointPath in path do
                if wpidx == pathSize then
                    if not bSkipLastMove then
                        platoon:AggressiveMoveToLocation(waypointPath)
                    end
                else
                    platoon:MoveToLocation(waypointPath, false)
                end
            end
        end
    else
        return false
    end

    return true
end