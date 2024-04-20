----------------------------------------------------------------------------------
--- File     :  /lua/ai/ScenarioPlatoonAI.lua
--- Summary  :  Houses a number of modified AI threads that are used in operations
---
--- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
----------------------------------------------------------------------------------

local AIBuildStructures = import("/lua/ai/aibuildstructures.lua")
local ScenarioFramework = import("/lua/scenarioframework.lua")
local StructureTemplates = import("/lua/buildingtemplates.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")

-- Upvalued for performance, might be a good idea to do this for other engine functions
local EntityCategoryContains = EntityCategoryContains

--- Transfers the platoon's units to the 'TransportPool' platoon, or the specified one if BaseName platoon data is given
--- Other platoons then can use the transport platoon to get to specified locations
--- NOTE: Transports are assigned to the land platoon we want to transport, once their commands have been executed, they are reassigned to their original transport pool
--- - TransportMoveLocation - Location to move transport to before assigning to transport pool
--- - MoveRoute - List of locations to move to
--- - MoveChain - Chain of locations to move
---@param platoon Platoon
function TransportPool(platoon)
    local aiBrain = platoon:GetBrain()
    local data = platoon.PlatoonData
	
	-- Default transport platoon to grab from
	local poolName = 'TransportPool'
	local BaseName = data.BaseName
	
	-- If base name is specified in platoon data, use that instead
	if BaseName then 
		poolName = BaseName .. '_TransportPool'
	end
	
    local tPool = aiBrain:GetPlatoonUniquelyNamed(poolName)
	if not tPool then
        tPool = aiBrain:MakePlatoon('', '')
        tPool:UniquelyNamePlatoon(poolName)
    end
	
    if data.TransportMoveLocation then
        if type(data.TransportMoveLocation) == 'string' then
            data.MoveRoute = {ScenarioUtils.MarkerToPosition(data.TransportMoveLocation)}
        else
            data.MoveRoute = {data.TransportMoveLocation}
        end
    end

    if data.MoveChain or data.MoveRoute then
        MoveToThread(platoon)
    end

    aiBrain:AssignUnitsToPlatoon(tPool, platoon:GetPlatoonUnits(), 'Scout', 'GrowthFormation')
end

--- Utility Function
--- Get and load transports with platoon units
---@param platoon Platoon
---@return boolean
function GetLoadTransports(platoon)
    local numTransports = GetTransportsThread(platoon)
    if not numTransports then
        return false
    end

    platoon:Stop()
    local aiBrain = platoon:GetBrain()

    -- Load transports
    local transportTable = {}
    local transSlotTable = {}

    local scoutUnits = platoon:GetSquadUnits('scout') or {}

    for num, unit in scoutUnits do
        local id = unit.UnitId
        if not transSlotTable[id] then
            transSlotTable[id] = GetNumTransportSlots(unit)
        end
        table.insert(transportTable,
            {
                Transport = unit,
                LargeSlots = transSlotTable[id].Large,
                MediumSlots = transSlotTable[id].Medium,
                SmallSlots = transSlotTable[id].Small,
                Units = {}
            }
       )
    end
    local shields = {}
    local remainingSize3 = {}
    local remainingSize2 = {}
    local remainingSize1 = {}
    for num, unit in platoon:GetPlatoonUnits() do
        if EntityCategoryContains(categories.url0306 + categories.DEFENSE, unit) then
            table.insert(shields, unit)
        elseif unit.Blueprint.Transport.TransportClass == 3 then
            table.insert(remainingSize3, unit)
        elseif unit.Blueprint.Transport.TransportClass == 2 then
            table.insert(remainingSize2, unit)
        elseif unit.Blueprint.Transport.TransportClass == 1 then
            table.insert(remainingSize1, unit)
        elseif not EntityCategoryContains(categories.TRANSPORTATION, unit) then
            table.insert(remainingSize1, unit)
        end
    end

    local needed = GetNumTransports(platoon)
    local largeHave = 0
    for num, data in transportTable do
        largeHave = largeHave + data.LargeSlots
    end
    local leftoverUnits = {}
    local currLeftovers = {}
    local leftoverShields = {}
    transportTable, leftoverShields = SortUnitsOnTransports(transportTable, shields, largeHave - needed.Large)
    transportTable, leftoverUnits = SortUnitsOnTransports(transportTable, remainingSize3, -1)
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, leftoverShields, -1)
    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, remainingSize2, -1)
    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, remainingSize1, -1)
    for _, v in currLeftovers do table.insert(leftoverUnits, v) end
    transportTable, currLeftovers = SortUnitsOnTransports(transportTable, currLeftovers, -1)
	
	-- Self-destruct any leftovers
	for k, v in currLeftovers do
		if not v.Dead then
			v:Kill()
		end
	end

    -- Old load transports
    local unitsToDrop = {}
    for num, data in transportTable do
        if not table.empty(data.Units) then
            IssueClearCommands(data.Units)
            IssueTransportLoad(data.Units, data.Transport)
            for _, v in data.Units do table.insert(unitsToDrop, v) end
        end
    end

    local attached = true
    repeat
        WaitSeconds(2)
        if not aiBrain:PlatoonExists(platoon) then
            return false
        end
        attached = true
        for _, v in unitsToDrop do
            if not v.Dead and not v:IsIdleState() then
                attached = false
                break
            end
        end
    until attached
	
	-- We actually self-destruct any leftovers for now, usually only 1-2 units get left behind, not much of a point to create a platoon for that many.
	-- I'm keeping the code around though, in case creating a copy of the original platoon from the leftovers is feasable
		-- Any units that aren't transports and aren't attached send back to pool
    local pool
    if platoon.PlatoonData.BuilderName and platoon.PlatoonData.LocationType then
        pool = aiBrain:GetPlatoonUniquelyNamed(platoon.PlatoonData.LocationType..'_LeftoverUnits')
        if not pool then
            pool = aiBrain:MakePlatoon('', '')
            pool:UniquelyNamePlatoon(platoon.PlatoonData.LocationType..'_LeftoverUnits')
            if platoon.PlatoonData.AMPlatoons then
                pool.PlatoonData.AMPlatoons = {platoon.PlatoonData.LocationType..'_LeftoverUnits'}
                pool:SetPartOfAttackForce()
            end
        end
    else
        pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    end
	
	-- For now we self-destruct any leftovers
    for _, unit in unitsToDrop do
        if not unit.Dead and not unit:IsUnitState('Attached') then
			unit:Kill()
            -- aiBrain:AssignUnitsToPlatoon(pool, {unit}, 'Unassigned', 'None')
        end
    end

    return true
end

--- Utility function
--- Sorts units onto transports distributing equally
---@generic T : table
---@param transportTable T
---@param unitTable Unit[]
---@param numSlots? number defaults to 1
---@return T transportTable
---@return Unit[] unitsLeft
function SortUnitsOnTransports(transportTable, unitTable, numSlots)
    local leftoverUnits = {}
    numSlots = numSlots or -1
	
    for num, unit in unitTable do
        if numSlots == -1 or num <= numSlots then
            local transSlotNum = 0
            local remainingLarge = 0
            local remainingMed = 0
            local remainingSml = 0
            for tNum, tData in transportTable do
                if tData.LargeSlots > remainingLarge then
                    transSlotNum = tNum
                    remainingLarge = tData.LargeSlots
                    remainingMed = tData.MediumSlots
                    remainingSml = tData.SmallSlots
                elseif tData.LargeSlots == remainingLarge and tData.MediumSlots > remainingMed then
                    transSlotNum = tNum
                    remainingLarge = tData.LargeSlots
                    remainingMed = tData.MediumSlots
                    remainingSml = tData.SmallSlots
                elseif tData.LargeSlots == remainingLarge and tData.MediumSlots == remainingMed and tData.SmallSlots > remainingSml then
                    transSlotNum = tNum
                    remainingLarge = tData.LargeSlots
                    remainingMed = tData.MediumSlots
                    remainingSml = tData.SmallSlots
                end
            end
            if transSlotNum > 0 then
                table.insert(transportTable[transSlotNum].Units, unit)
                if unit.Blueprint.Transport.TransportClass == 3 and remainingLarge >= 1 then
                    transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - 1
                    transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 2
                    transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 4
                elseif unit.Blueprint.Transport.TransportClass == 2 and remainingMed > 0 then
                    if transportTable[transSlotNum].LargeSlots > 0 then
                        transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - .5
                    end
                    transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 1
                    transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 2
                elseif unit.Blueprint.Transport.TransportClass == 1 and remainingSml > 0 then
                    transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 1
                elseif remainingSml > 0 then
                    transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 1
                else
                    table.insert(leftoverUnits, unit)
                end
            else
                table.insert(leftoverUnits, unit)
            end
        end
    end
    return transportTable, leftoverUnits
end

--- Utility Function
--- Function that gets the correct number of transports for a platoon
--- If BaseName platoon data is specified, grabs transports from that platoon
---@param platoon Platoon
---@return number
function GetTransportsThread(platoon)
    local data = platoon.PlatoonData
    local aiBrain = platoon:GetBrain()
	
	-- Default transport platoon to grab from
	local poolName = 'TransportPool'
	local BaseName = data.BaseName
	
	-- If base name is specified in platoon data, use that instead
	if BaseName then 
		poolName = BaseName .. '_TransportPool'
	end

    local neededTable = GetNumTransports(platoon)
    local numTransports = 0
    local transportsNeeded = false
    if neededTable.Small > 0 or neededTable.Medium > 0 or neededTable.Large > 0 then
        transportsNeeded = true
    end
    local transSlotTable = {}

    if transportsNeeded then
        local pool = aiBrain:GetPlatoonUniquelyNamed(poolName)
		
		if not pool then
			pool = aiBrain:MakePlatoon('', '')
			pool:UniquelyNamePlatoon(poolName)
		end
		
        while transportsNeeded do
            neededTable = GetNumTransports(platoon)
            -- Make sure more are needed
            local tempNeeded = {}
            tempNeeded.Small = neededTable.Small
            tempNeeded.Medium = neededTable.Medium
            tempNeeded.Large = neededTable.Large
            -- Find out how many units are needed currently
            for _, v in platoon:GetPlatoonUnits() do
                if not v.Dead then
                    if EntityCategoryContains(categories.TRANSPORTATION, v) then
                        local id = v.UnitId
                        if not transSlotTable[id] then
                            transSlotTable[id] = GetNumTransportSlots(v)
                        end
                        local tempSlots = {}
                        tempSlots.Small = transSlotTable[id].Small
                        tempSlots.Medium = transSlotTable[id].Medium
                        tempSlots.Large = transSlotTable[id].Large
                        while tempNeeded.Large > 0 and tempSlots.Large > 0 do
                            tempNeeded.Large = tempNeeded.Large - 1
                            tempSlots.Large = tempSlots.Large - 1
                            tempSlots.Medium = tempSlots.Medium - 2
                            tempSlots.Small = tempSlots.Small - 4
                        end
                        while tempNeeded.Medium > 0 and tempSlots.Medium > 0 do
                            tempNeeded.Medium = tempNeeded.Medium - 1
                            tempSlots.Medium = tempSlots.Medium - 1
                            tempSlots.Small = tempSlots.Small - 2
                        end
                        while tempNeeded.Small > 0 and tempSlots.Small > 0 do
                            tempNeeded.Small = tempNeeded.Small - 1
                            tempSlots.Small = tempSlots.Small - 1
                        end
                        if tempNeeded.Small <= 0 and tempNeeded.Medium <= 0 and tempNeeded.Large <= 0 then
                            transportsNeeded = false
                        end
                    end
                end
            end
            if transportsNeeded then
                local location = platoon:GetPlatoonPosition()
                local transports = {}
                -- Determine distance of transports from platoon
                for _, unit in pool:GetPlatoonUnits() do
                    if EntityCategoryContains(categories.TRANSPORTATION, unit) and not unit:IsUnitState('Busy') then
                        local unitPos = unit:GetPosition()
                        local curr = {Unit = unit, Distance = VDist2(unitPos[1], unitPos[3], location[1], location[3]), Id = unit.UnitId}
                        table.insert(transports, curr)
                    end
                end
                if not table.empty(transports) then
                    local sortedList = {}
                    -- Sort distances
                    for k = 1, table.getn(transports) do
                        local lowest = -1
                        local key, value
                        for j, u in transports do
                            if lowest == -1 or u.Distance < lowest then
                                lowest = u.Distance
                                value = u
                                key = j
                            end
                        end
                        sortedList[k] = value
                        -- Remove from unsorted table
                        table.remove(transports, key)
                    end
                    -- Take transports as needed
                    for i = 1, table.getn(sortedList) do
                        if transportsNeeded then
                            local id = sortedList[i].Id
                            aiBrain:AssignUnitsToPlatoon(platoon, {sortedList[i].Unit}, 'Scout', 'GrowthFormation')
                            numTransports = numTransports + 1
                            if not transSlotTable[id] then
                                transSlotTable[id] = GetNumTransportSlots(sortedList[i].Unit)
                            end
                            local tempSlots = {}
                            tempSlots.Small = transSlotTable[id].Small
                            tempSlots.Medium = transSlotTable[id].Medium
                            tempSlots.Large = transSlotTable[id].Large
                            -- Update number of slots needed
                            while tempNeeded.Large > 0 and tempSlots.Large > 0 do
                                tempNeeded.Large = tempNeeded.Large - 1
                                tempSlots.Large = tempSlots.Large - 1
                                tempSlots.Medium = tempSlots.Medium - 2
                                tempSlots.Small = tempSlots.Small - 4
                            end
                            while tempNeeded.Medium > 0 and tempSlots.Medium > 0 do
                                tempNeeded.Medium = tempNeeded.Medium - 1
                                tempSlots.Medium = tempSlots.Medium - 1
                                tempSlots.Small = tempSlots.Small - 2
                            end
                            while tempNeeded.Small > 0 and tempSlots.Small > 0 do
                                tempNeeded.Small = tempNeeded.Small - 1
                                tempSlots.Small = tempSlots.Small - 1
                            end
                            if tempNeeded.Small <= 0 and tempNeeded.Medium <= 0 and tempNeeded.Large <= 0 then
                                transportsNeeded = false
                            end
                        end
                    end
                end
            end
            if transportsNeeded then
                WaitSeconds(7)
                if not aiBrain:PlatoonExists(platoon) then
                    return false
                end
                local unitFound = false
                for _, unit in platoon:GetPlatoonUnits() do
                    if not EntityCategoryContains(categories.TRANSPORTATION, unit) then
                        unitFound = true
                        break
                    end
                end
                if not unitFound then
                    ReturnTransportsToPool(platoon, data)
                    return false
                end
            end
        end
    end
    return numTransports
end

--- Utility Function
--- Returns the number of transports required to move the platoon
---@param platoon Platoon
---@return table
function GetNumTransports(platoon)
    local transportNeeded = {
        Small = 0,
        Medium = 0,
        Large = 0,
    }
    for _, v in platoon:GetPlatoonUnits() do
		if not v.Dead then
			if v.Blueprint.Transport.TransportClass == 1 then
				transportNeeded.Small = transportNeeded.Small + 1
			elseif v.Blueprint.Transport.TransportClass == 2 then
				transportNeeded.Medium = transportNeeded.Medium + 1
			elseif v.Blueprint.Transport.TransportClass == 3 then
				transportNeeded.Large = transportNeeded.Large + 1
			else
				transportNeeded.Small = transportNeeded.Small + 1
			end
		end
    end

    return transportNeeded
end

--- Deprecated utility Function
--- Returns the number of slots the transport has available, or at least tries that, with a considerable inconsistency if either the bone counts, and/or the unit's blueprint is fucked up
--- For the sake of an example, it returns with less available slots for the T2 UEF Transport than it actually has
---@param unit Unit
---@return table
--[[function GetNumTransportSlots(unit)
    local bones = {
        Large = 0,
        Medium = 0,
        Small = 0,
    }

    -- compute count based on bones
    for i = 1, unit:GetBoneCount() do
        if unit:GetBoneName(i) ~= nil then
            if string.find(unit:GetBoneName(i), 'Attachpoint_Lrg') then
                bones.Large = bones.Large + 1
            elseif string.find(unit:GetBoneName(i), 'Attachpoint_Med') then
                bones.Medium = bones.Medium + 1
            elseif string.find(unit:GetBoneName(i), 'Attachpoint') then
                bones.Small = bones.Small + 1
            end
        end
    end

    -- retrieve number of slots set by blueprint, if it is set
    local largeSlotsByBlueprint = unit.Blueprint.Transport.SlotsLarge or bones.Large 
    local mediumSlotsByBlueprint = unit.Blueprint.Transport.SlotsMedium or bones.Medium 
    local smallSlotsByBlueprint = unit.Blueprint.Transport.SlotsSmall or bones.Small 

    -- take the minimum of the two
    bones.Large = math.min(bones.Large, largeSlotsByBlueprint)
    bones.Medium = math.min(bones.Medium, mediumSlotsByBlueprint)
    bones.Small = math.min(bones.Small, smallSlotsByBlueprint)

    return bones
end]]

--- Utility Function
--- Returns the number of slots the transport has available
---@param unit Unit
---@return table
function GetNumTransportSlots(unit)
    local bones = {
        Large = 0,
        Medium = 0,
        Small = 0,
    }
	
	-- I'm not a fan of having to hardcode these values, but the blueprint, and even engine method are unreliable
	-- The old function can be found above for reference
	if EntityCategoryContains(categories.xea0306, unit) then
		bones.Large = 8
		bones.Medium = 10
		bones.Small = 24
	elseif EntityCategoryContains(categories.uea0203, unit) then
		bones.Large = 0
		bones.Medium = 1
		bones.Small = 1
	elseif EntityCategoryContains(categories.uea0104, unit) then
		bones.Large = 3
		bones.Medium = 6
		bones.Small = 14
	elseif EntityCategoryContains(categories.uea0107, unit) then
		bones.Large = 1
		bones.Medium = 2
		bones.Small = 6
	elseif EntityCategoryContains(categories.uaa0107, unit) then
		bones.Large = 1
		bones.Medium = 3
		bones.Small = 6
	elseif EntityCategoryContains(categories.uaa0104, unit) then
		bones.Large = 3
		bones.Medium = 6
		bones.Small = 12
	elseif EntityCategoryContains(categories.ura0107, unit) then
		bones.Large = 1
		bones.Medium = 2
		bones.Small = 6
	elseif EntityCategoryContains(categories.ura0104, unit) then
		bones.Large = 2
		bones.Medium = 4
		bones.Small = 10
	elseif EntityCategoryContains(categories.xsa0107, unit) then
		bones.Large = 1
		bones.Medium = 4
		bones.Small = 8
	elseif EntityCategoryContains(categories.xsa0104, unit) then
		bones.Large = 4
		bones.Medium = 8
		bones.Small = 16
	else
		-- If all else fails, try to get the slots from the unit's blueprint
		local largeSlotsByBlueprint = unit.Blueprint.Transport.SlotsLarge
		local mediumSlotsByBlueprint = unit.Blueprint.Transport.SlotsMedium
		local smallSlotsByBlueprint = unit.Blueprint.Transport.SlotsSmall
		
		bones.Large = largeSlotsByBlueprint
		bones.Medium = mediumSlotsByBlueprint
		bones.Small = smallSlotsByBlueprint
	end

    return bones
end

--- Utility Function
--- Takes transports in platoon, returns them to pool, flies them back to return location
---@param platoon Platoon
---@param data table
function ReturnTransportsToPool(platoon, data)
    -- Put transports back in TPool
    local aiBrain = platoon:GetBrain()
    local transports = platoon:GetSquadUnits('Scout')
	
	-- Default transport platoon to grab from
	local poolName = 'TransportPool'
	local BaseName = data.BaseName
	
	-- If base name is specified in platoon data, use that instead
	if BaseName then 
		poolName = BaseName .. '_TransportPool'
	end
	
	local tPool = aiBrain:GetPlatoonUniquelyNamed(poolName)
	if not tPool then
        tPool = aiBrain:MakePlatoon('', '')
        tPool:UniquelyNamePlatoon(poolName)
    end
	
	if table.empty(transports) then
        return
    end

    aiBrain:AssignUnitsToPlatoon(tPool, transports, 'Scout', 'None')

    -- If a route or chain was given, reverse it on return
    if data.TransportRoute then
        for i = table.getn(data.TransportRoute), 1, -1 do
            if type(data.TransportRoute[i]) == 'string' then
                IssueMove(transports, ScenarioUtils.MarkerToPosition(data.TransportRoute[i]))
            else
                IssueMove(transports, data.TransportRoute[i])
            end
        end
        -- If a route chain was given, reverse the route on return
    elseif data.TransportChain then
        local transPositionChain = ScenarioUtils.ChainToPositions(data.TransportChain)
        for i = table.getn(transPositionChain), 1, -1 do
            IssueMove(transports, transPositionChain[i])
        end
    end

    -- Return to Transport Return position
    if data.TransportReturn then
        if type(data.TransportReturn) == 'string' then
            IssueMove(transports, ScenarioUtils.MarkerToPosition(data.TransportReturn))
        else
            IssueMove(transports, data.TransportReturn)
        end
    end
end

-- kept for mod backwards compatibility
local Utilities = import("/lua/utilities.lua")