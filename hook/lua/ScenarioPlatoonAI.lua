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
local AIUtils = import("/lua/ai/aiutilities.lua")

-- Upvalued for performance
local EntityCategoryContains = EntityCategoryContains
local TableEmpty = table.empty
local TableInsert = table.insert
local TableRemove = table.remove
local TableGetn = table.getn
local TableRandom = table.random

--- Transfers the platoon's units to the 'TransportPool' platoon, or the specified one if BaseName platoon data is given
--- NOTE: Transports are assigned to the land platoon we want to transport, once their commands have been executed, they are reassigned to their original transport pool
--- - TransportMoveLocation - Location to move transport to before assigning to transport pool
--- - MoveRoute - List of locations to move to
--- - MoveChain - Chain of locations to move
---@param platoon Platoon
function TransportPool(platoon)
    local aiBrain = platoon:GetBrain()
    local data = platoon.PlatoonData
	local Difficulty = ScenarioInfo.Options.Difficulty or 3
	
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
	
	-- Move the transports along desired route
    if data.MoveChain or data.MoveRoute then
        MoveToThread(platoon)
    end
	
	-- Add veterancy for self-repair reasons
	for index, unit in platoon:GetPlatoonUnits() do
		if not unit.Dead then
			unit:SetVeterancy(Difficulty + 2)
		end
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

    local scoutUnits = platoon:GetSquadUnits('Scout') or {}

    for num, unit in scoutUnits do
        local id = unit.UnitId
        if not transSlotTable[id] then
            transSlotTable[id] = GetNumTransportSlots(unit)
        end
        TableInsert(transportTable,
            {
                Transport = unit,
                LargeSlots = transSlotTable[id].Large,
                MediumSlots = transSlotTable[id].Medium,
                SmallSlots = transSlotTable[id].Small,
                Units = {}
            }
		)
    end
    local remainingSize3 = {}
    local remainingSize2 = {}
    local remainingSize1 = {}
	
	for num, unit in platoon:GetPlatoonUnits() do
		if not unit.Dead then
			local TransportClass = unit.Blueprint.Transport.TransportClass
			if TransportClass == 3 then
				TableInsert(remainingSize3, unit)
			elseif TransportClass == 2 then
				TableInsert(remainingSize2, unit)
			elseif TransportClass == 1 then
				TableInsert(remainingSize1, unit)
			elseif not EntityCategoryContains(categories.TRANSPORTATION, unit) then
				WARN("AI WARNING: GetLoadTransportsOnce() found no valid TransportClass value found for unit ID: " .. tostring(v.UnitId))
				TableInsert(remainingSize1, unit)
			end
		end
    end
	
	-- Leftover tables
    local Size3Leftovers = {}
	local Size2Leftovers = {}
	local Size1Leftovers = {}
	
	-- Assign large units, and leftovers
    transportTable, Size3Leftovers = SortUnitsOnTransports(transportTable, remainingSize3)
	-- Assign medium units, and leftovers
    transportTable, Size2Leftovers = SortUnitsOnTransports(transportTable, remainingSize2)
    -- Assign small units, and leftovers
    transportTable, Size1Leftovers = SortUnitsOnTransports(transportTable, remainingSize1)
	
	-- Self-destruct any units we couldn't arrange a transport slot for
	for k, v in Size3Leftovers do
		if not v.Dead then
			v:Kill()
		end
	end
	
	for k, v in Size2Leftovers do
		if not v.Dead then
			v:Kill()
		end
	end
	
	for k, v in Size1Leftovers do
		if not v.Dead then
			v:Kill()
		end
	end

	-- Clean up the tables
	remainingSize3 = nil
	remainingSize2 = nil
	remainingSize1 = nil
	Size3Leftovers = nil
	Size2Leftovers = nil
	Size1Leftovers = nil

    -- Old load transports
    local unitsToDrop = {}
    for num, data in transportTable do
        if not TableEmpty(data.Units) then
            IssueClearCommands(data.Units)
            IssueTransportLoad(data.Units, data.Transport)
            for _, v in data.Units do TableInsert(unitsToDrop, v) end
        end
    end

    local attached = true
    repeat
        WaitTicks(10)
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
	
	-- Self-destruct any units that failed to load
    for _, unit in unitsToDrop do
        if not unit.Dead and not unit:IsUnitState('Attached') then
			unit:Kill()
        end
    end

    return true
end

--- Utility function
--- Sorts units onto transports with higher slot space priority
---@generic T : table
---@param transportTable T
---@param unitTable Unit[]
---@param numSlots? number defaults to 1
---@return T transportTable
---@return Unit[] unitsLeft
function SortUnitsOnTransports(transportTable, unitTable)
    local leftoverUnits = {}
	
    for num, unit in unitTable do
        local transSlotNum = 0
        local remainingLarge = 0
        local remainingMed = 0
        local remainingSml = 0
		local TransportClass = unit.Blueprint.Transport.TransportClass

		-- Since the transports remain in the same order in the table, as they get filled up, new ones will be picked
		-- Ideally this function is called from the highest size to the smallest, meaning, large units get sorted first, then medium, then small
        for tNum, tData in transportTable do
			-- Assign slot counts to local variables
			remainingLarge = tData.LargeSlots
            remainingMed = tData.MediumSlots
            remainingSml = tData.SmallSlots
            if TransportClass == 3 and remainingLarge >= 1 then
                transSlotNum = tNum
				break
            elseif TransportClass == 2 and remainingMed >= 1 then
                transSlotNum = tNum
				break
            elseif TransportClass == 1 and remainingSml >= 1 then
                transSlotNum = tNum
				break
            end
        end
		-- If we got a transport with free slot, take it, and update total slot count
        if transSlotNum > 0 then
            if TransportClass == 3 and remainingLarge >= 1 then
                transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - 1
                transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 2
                transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 4
				TableInsert(transportTable[transSlotNum].Units, unit)
            elseif TransportClass == 2 and remainingMed >= 1 then
                if transportTable[transSlotNum].LargeSlots > 0 then
                    transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - 0.5
				end
                transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 1
                transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 2
				TableInsert(transportTable[transSlotNum].Units, unit)
            elseif TransportClass == 1 and remainingSml >= 1 then
				-- For the case of the T2 UEF Gunship
				if transportTable[transSlotNum].MediumSlots > 0 then
					transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 0.5
				end
                transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 1
				TableInsert(transportTable[transSlotNum].Units, unit)
            else
                TableInsert(leftoverUnits, unit)
            end
        else
            TableInsert(leftoverUnits, unit)
        end
    end
    return transportTable, leftoverUnits
end

--- Utility Function
--- Function that gets the correct number of transports for a platoon, if BaseName platoon data is specified, grabs transports from that platoon
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
            pool = aiBrain:MakePlatoon('None', 'None')
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
                        while tempNeeded.Large >= 1 and tempSlots.Large >= 1 do
                            tempNeeded.Large = tempNeeded.Large - 1
                            tempSlots.Large = tempSlots.Large - 1
                            tempSlots.Medium = tempSlots.Medium - 2
                            tempSlots.Small = tempSlots.Small - 4
                        end
                        while tempNeeded.Medium >= 1 and tempSlots.Medium >= 1 do
                            tempNeeded.Medium = tempNeeded.Medium - 1
                            tempSlots.Medium = tempSlots.Medium - 1
                            tempSlots.Small = tempSlots.Small - 2
                        end
                        while tempNeeded.Small >= 1 and tempSlots.Small >= 1 do
							-- For the case of the T2 UEF Gunship
							if id == 'uea0203' then
								tempSlots.Medium = tempSlots.Medium - 0.5
							end
                            tempNeeded.Small = tempNeeded.Small - 1
                            tempSlots.Small = tempSlots.Small - 1
                        end
                        if tempNeeded.Small < 1 and tempNeeded.Medium < 1 and tempNeeded.Large < 1 then
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
                        TableInsert(transports, curr)
                    end
                end
                if not TableEmpty(transports) then
                    local sortedList = {}
                    -- Sort distances
                    for k = 1, TableGetn(transports) do
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
                        TableRemove(transports, key)
                    end
                    -- Take transports as needed
                    for i = 1, TableGetn(sortedList) do
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
                            while tempNeeded.Large >= 1 and tempSlots.Large >= 1 do
                                tempNeeded.Large = tempNeeded.Large - 1
                                tempSlots.Large = tempSlots.Large - 1
                                tempSlots.Medium = tempSlots.Medium - 2
                                tempSlots.Small = tempSlots.Small - 4
                            end
                            while tempNeeded.Medium >= 1 and tempSlots.Medium >= 1 do
                                tempNeeded.Medium = tempNeeded.Medium - 1
                                tempSlots.Medium = tempSlots.Medium - 1
                                tempSlots.Small = tempSlots.Small - 2
                            end
                            while tempNeeded.Small >= 1 and tempSlots.Small >= 1 do
								-- For the case of the T2 UEF Gunship
								if id == 'uea0203' then
									tempSlots.Medium = tempSlots.Medium - 0.5
								end
                                tempNeeded.Small = tempNeeded.Small - 1
                                tempSlots.Small = tempSlots.Small - 1
                            end
                            if tempNeeded.Small < 1 and tempNeeded.Medium < 1 and tempNeeded.Large < 1 then
                                transportsNeeded = false
                            end
                        end
                    end
                end
            end
            if transportsNeeded then
                WaitSeconds(5)
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
                    ReturnTransportsToPool(platoon)
                    return false
                end
            end
        end
    end
    return numTransports
end

--- Utility Function
--- Returns the number of transport slots required to move the platoon
---@param platoon Platoon
---@return table
function GetNumTransports(platoon)
    local transportNeeded = {
        Small = 0,
        Medium = 0,
        Large = 0,
    }
    for _, v in platoon:GetPlatoonUnits() do
		if not v.Dead and not EntityCategoryContains(categories.TRANSPORTATION, v) then
			local TransportClass = v.Blueprint.Transport.TransportClass
			if TransportClass == 1 then
				transportNeeded.Small = transportNeeded.Small + 1
			elseif TransportClass == 2 then
				transportNeeded.Medium = transportNeeded.Medium + 1
			elseif TransportClass == 3 then
				transportNeeded.Large = transportNeeded.Large + 1
			else
				WARN("AI WARNING: GetNumTransports() found no valid TransportClass value found for unit ID: " .. tostring(v.UnitId))
				transportNeeded.Small = transportNeeded.Small + 1
			end
		end
    end

    return transportNeeded
end

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
	
	local TransportSlotTable = unit.Blueprint.Transport
	
	local largeSlotsByBlueprint = TransportSlotTable.SlotsLarge
	local mediumSlotsByBlueprint = TransportSlotTable.SlotsMedium
	local smallSlotsByBlueprint = TransportSlotTable.SlotsSmall
	bones.Large = largeSlotsByBlueprint
	bones.Medium = mediumSlotsByBlueprint
	bones.Small = smallSlotsByBlueprint

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

EngineerBuildAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        local factionIndex = self:GetFactionIndex()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile
        if not cons then
            WARN('*AI WARNING: No Construction table in PlatoonData for EngineerBuildAI.  Aborting Platoon AI Thread for: .' .. tostring(aiBrain.Name))
            self:Stop()
            aiBrain:PBMAdjustPriority(self, -20)
            aiBrain:DisbandPlatoon(self)
            return
        else
            buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
            baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
            buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
            baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

            if cons.Location then
                local coords = aiBrain:PBMGetLocationCoords(cons.Location)
                self:MoveToLocation(coords, false)
                WaitSeconds(5)
                if not aiBrain:PlatoonExists(self) then
                    return
                end
            end
            local eng
            for k, v in platoonUnits do
                if not v.Dead and EntityCategoryContains(categories.CONSTRUCTION, v) then
                    if not eng then
                        eng = v
                    else
                        IssueToUnitClearCommands(v)
                        IssueGuard({v}, eng)
                    end
                end
            end

            if not eng or eng.Dead then
                aiBrain:DisbandPlatoon(self)
                return
            end

            if self.PlatoonData.NeedGuard then
                eng.NeedGuard = true
            end

            ---- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES ----
            local reference = false
            local refName = false
            local buildFunction
            local closeToBuilder
            local relative
            local baseTmplList = {}
            if cons.BuildStructures then
                if cons.NearUnitCategory then
                    self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
                    local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, self:GetPlatoonPosition(), 60)
                    if unitNearBy then
                        reference = unitNearBy:GetPosition()
                    else
                        reference = eng:GetPosition()
                    end
                    relative = false
                    buildFunction = AIBuildStructures.AIExecuteBuildStructure
                    TableInsert( baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation( baseTmpl, reference ) )
                elseif cons.Wall then
                    local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
                    local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
                    relative = false
                    reference = AIUtils.GetLocationNeedingWalls( aiBrain, 200, 4, 'STRUCTURE - WALLS', cons.ThreatMin, cons.ThreatMax, cons.ThreatRings )
                    table.insert( baseTmplList, 'Blank' )
                    buildFunction = AIBuildStructures.WallBuilder
                elseif cons.NearBasePatrolPoints then
                    relative = false
                    reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
                    baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
                    for k,v in reference do
                        table.insert( baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation( baseTmpl, v ) )
                    end
                    -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                    buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
                elseif cons.NearMarkerType and cons.MarkerUnitCount then
                    local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
                    local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
                    reference, refName = AIUtils.AIGetMarkerLeastUnits( aiBrain, cons.NearMarkerType, (cons.MarkerRadius or 100),
                            pos, radius, cons.MarkerUnitCount, ParseEntityCategory( cons.MarkerUnitCategory ), cons.ThreatMin,
                            cons.ThreatMax, cons.ThreatRings )
                    if not cons.BaseTemplate and ( cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area' ) then
                        baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
                    end
                    if cons.ExpansionBase and refName then
                        AIBuildStructures.AINewExpansionBase( aiBrain, refName, reference, (cons.ExpansionRadius or 75), cons.ExpansionTypes )
                    end
                    relative = false
                    if reference and aiBrain:GetInfluenceAtPosition( reference , 1, false ) > -5 then
                        --aiBrain:ExpansionHelp( eng, reference )
                    end
                    table.insert( baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation( baseTmpl, reference ) )
                    -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                    buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
                elseif cons.NearMarkerType then
                    if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                        cons.ThreatMin = -1000000
                        cons.ThreatMax = 1000000
                        cons.ThreatRings = 0
                    end
                    if not cons.BaseTemplate and ( cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area' ) then
                        baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
                    end
                    relative = false
                    local pos = self:GetPlatoonPosition()
                    reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
                    if cons.ExpansionBase and refName then
                        AIBuildStructures.AINewExpansionBase( aiBrain, refName, reference, (cons.ExpansionRadius or 75), cons.ExpansionTypes )
                    end
                    if reference and aiBrain:GetInfluenceAtPosition( reference, 1, false ) > -5 then
                        --aiBrain:ExpansionHelp( eng, reference )
                    end
                    table.insert( baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation( baseTmpl, reference ) )
                    buildFunction = AIBuildStructures.AIExecuteBuildStructure
                elseif cons.AdjacencyCategory then
                    relative = false
                    local pos = self:GetPlatoonPosition()
                    local cat = ParseEntityCategory(cons.AdjacencyCategory)
                    local radius = ( cons.AdjacencyDistance or 50 )
                    if not pos or not pos then
                        aiBrain:DisbandPlatoon(self)
                        return
                    end
                    reference  = AIUtils.GetOwnUnitsAroundPoint( aiBrain, cat, pos, radius, cons.ThreatMin,
                                                                cons.ThreatMax, cons.ThreatRings)
                    buildFunction = AIBuildStructures.AIBuildAdjacency
                    table.insert( baseTmplList, baseTmpl )
                else
                    table.insert( baseTmplList, baseTmpl )
                    relative = true
                    reference = true
                    buildFunction = AIBuildStructures.AIExecuteBuildStructure
                end
                if cons.BuildClose then
                    closeToBuilder = eng
                end

                ---- BUILD BUILDINGS HERE ----
                for baseNum, baseListData in baseTmplList do
                    for k, v in cons.BuildStructures do
                        if aiBrain:PlatoonExists(self) then
                            if not eng:IsDead() then
                                IssueStop({eng})
                                IssueClearCommands({eng})
                                local retVal, pos = buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference)
                                if not retVal and pos then
                                    --LOG('*AI DEBUG: ARMY ' .. aiBrain:GetArmyIndex() .. ' - Engineer moving to capture at ' .. pos[1] .. ', ' .. pos[3] )
                                    IssueMove( {eng}, pos )
                                end
                                if retVal or pos then
                                    repeat
                                        WaitSeconds(1)
                                        if not aiBrain:PlatoonExists(self) then
                                            return
                                        end
                                    until eng.Dead or eng:IsIdleState()
                                end
                                if pos then
                                    -- Check if unit at location
                                    local checkUnits = aiBrain:GetUnitsAroundPoint( categories.STRUCTURE + ( categories.MOBILE * categories.LAND), pos, 10, 'Enemy' )
                                    --( Rect( pos[1] - 7, pos[3] - 7, pos[1] + 7, pos[3] + 7 ) )
                                    if checkUnits then
                                        for num,unit in checkUnits do
                                            if not unit:IsDead() and EntityCategoryContains( categories.ENGINEER, unit ) and ( unit:GetAIBrain():GetFactionIndex() ~= aiBrain:GetFactionIndex() ) then
                                                IssueReclaim( {eng}, unit )
                                            else
                                                IssueCapture( {eng}, unit )
                                            end
                                        end
                                        repeat
                                            WaitSeconds(1)
                                            if not aiBrain:PlatoonExists(self) then
                                                return
                                            end
                                        until eng:IsDead() or eng:IsIdleState()
                                    end
                                end
                            else
                                if aiBrain:PlatoonExists(self) then
                                    aiBrain:DisbandPlatoon(self)
                                end
                            end
                        end
                    end
                end
            end
        end
        if aiBrain:PlatoonExists(self) then
            local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
            self:MoveToLocation(location, false)
            aiBrain:DisbandPlatoon(self)
        end
    end