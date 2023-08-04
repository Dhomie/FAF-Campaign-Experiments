--- Utility Function
--- Get and load transports with platoon units
---@param units Unit[]
---@param transports AirUnit[]
---@param location Vector
---@param UnitPlatoon Platoon
---@return boolean
function UseTransports(units, transports, location, UnitPlatoon)
    local aiBrain
	local NavUtils = import("/lua/sim/navutils.lua")
    for k, v in units do
        if not v.Dead then
            aiBrain = v:GetAIBrain()
            break
        end
    end

    if not aiBrain then
        return false
    end

    -- Load transports
    local transportTable = {}
    local transSlotTable = {}
    if not transports then
        return false
    end

    IssueClearCommands(transports)

    for num, unit in transports do
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
    local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    for num, unit in units do
        if not unit.Dead then
            if unit:IsUnitState('Attached') then
                --aiBrain:AssignUnitsToPlatoon(pool, {unit}, 'Unassigned', 'None')
				unit:Kill()
            elseif EntityCategoryContains(categories.url0306 + categories.DEFENSE, unit) then
                table.insert(shields, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 3 then
                table.insert(remainingSize3, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 2 then
                table.insert(remainingSize2, unit)
            elseif unit:GetBlueprint().Transport.TransportClass == 1 then
                table.insert(remainingSize1, unit)
            else
                table.insert(remainingSize1, unit)
            end
        end
    end

    local needed = GetNumTransports(units)
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
	
	--Self-destruct any left-overs
		--aiBrain:AssignUnitsToPlatoon(pool, currLeftovers, 'Unassigned', 'None')
	for k, v in currLeftovers do
		if not v.Dead then
			v:Kill()
		end
	end
	
    if UnitPlatoon then
        UnitPlatoon.UsingTransport = true
    end

    local monitorUnits = {}
    for num, data in transportTable do
        if not table.empty(data.Units) then
            IssueClearCommands(data.Units)
            IssueTransportLoad(data.Units, data.Transport)
            for k, v in data.Units do table.insert(monitorUnits, v) end
        end
    end

    local attached = true
    repeat
        coroutine.yield(20)
        local allDead = true
        local transDead = true
        for k, v in units do
            if not v.Dead then
                allDead = false
                break
            end
        end
        for k, v in transports do
            if not v.Dead then
                transDead = false
                break
            end
        end
        if allDead or transDead then return false end
        attached = true
        for k, v in monitorUnits do
            if not v.Dead and not v:IsIdleState() then
                attached = false
                break
            end
        end
    until attached

    -- Any units that aren't transports and aren't attached, create a new platoon and assign them there.
	--local LeftoverPlatoon = aiBrain:MakePlatoon('', '')
	
    for k, unit in units do
        if not unit.Dead and not EntityCategoryContains(categories.TRANSPORTATION, unit) then
            if not unit:IsUnitState('Attached') then
                --aiBrain:AssignUnitsToPlatoon(LeftoverPlatoon, {unit}, 'Attack', 'AttackFormation')
				unit:Kill()
            end
        elseif not unit.Dead and EntityCategoryContains(categories.TRANSPORTATION, unit) and table.empty(unit:GetCargo()) then
            ReturnTransportsToPool({unit}, true)
            table.remove(transports, k)
        end
    end
	
	--Tell the new platoon to start doing something if it has any units
	--if not table.empty(LeftoverPlatoon:GetPlatoonUnits()) then
		--if not LeftoverPlatoon.PlatoonData then
			--LeftoverPlatoon.PlatoonData = {}
		--end
		--LeftoverPlatoon.PlatoonData.UseFormation = 'AttackFormation',
		
		--LeftoverPlatoon:SetAIPlan('AttackForceAI')
	--end
    -- If some transports have no units return to pool
    for k, t in transports do
        if not t.Dead and table.empty(t:GetCargo()) then
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {t}, 'Scout', 'None')
            table.remove(transports, k)
        end
    end

    if not table.empty(transports) then
        -- If no location then we have loaded transports then return true
        if location then
            -- Adding Surface Height, so the transporter get not confused, because the target is under the map (reduces unload time)
            location = {location[1], GetSurfaceHeight(location[1],location[3]), location[3]}
            -- local safePath = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', transports[1]:GetPosition(), location, 200)
			local airthreatMax = 250
			local safePath = NavUtils.PathToWithThreatThreshold('Air', transports[1]:GetPosition(), location, aiBrain, NavUtils.ThreatFunctions.AntiAir, airthreatMax, aiBrain.IMAPConfig.Rings)
            if safePath then
                for _, p in safePath do
                    IssueMove(transports, p)
                end
                IssueMove(transports, location)
                IssueTransportUnload(transports, location)
            else
                IssueMove(transports, location)
                IssueTransportUnload(transports, location)
            end
        else
            return true
        end
    else
        -- If no transports return false
        return false
    end

    local attached = true
    while attached do
        coroutine.yield(20)
        local allDead = true
        for _, v in transports do
            if not v.Dead then
                allDead = false
                break
            end
        end

        if allDead then
            return false
        end

        attached = false
        for num, unit in units do
            if not unit.Dead and unit:IsUnitState('Attached') then
                attached = true
                break
            end
        end
    end

    if UnitPlatoon then
        UnitPlatoon.UsingTransport = false
    end
    ReturnTransportsToPool(transports, true)

    return true
end

--- Utility Function
--- Function that gets the correct number of transports for a platoon
---@param platoon Platoon
---@param units Unit[]|nil
---@return number
---@return number
---@return number
---@return number
function GetTransports(platoon, units)
    if not units then
        units = platoon:GetPlatoonUnits()
    end

    -- Check for empty platoon
    if table.empty(units) then
        return 0
    end

    local neededTable = GetNumTransports(units)
    local transportsNeeded = false
    if neededTable.Small > 0 or neededTable.Medium > 0 or neededTable.Large > 0 then
        transportsNeeded = true
    end


    local aiBrain = platoon:GetBrain()
    local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')

    -- Make sure more are needed
    local tempNeeded = {}
    tempNeeded.Small = neededTable.Small
    tempNeeded.Medium = neededTable.Medium
    tempNeeded.Large = neededTable.Large

    local location = platoon:GetPlatoonPosition()
    if not location then
        -- We can assume we have at least one unit here
        location = units[1]:GetPosition()
    end

    if not location then
        return 0
    end

    -- Determine distance of transports from platoon
    local transports = {}
    for _, unit in pool:GetPlatoonUnits() do
        if not unit.Dead and EntityCategoryContains(categories.TRANSPORTATION - categories.uea0203, unit) and not unit:IsUnitState('Busy') and not unit:IsUnitState('TransportLoading') and table.empty(unit:GetCargo()) and unit:GetFractionComplete() == 1 then
            local unitPos = unit:GetPosition()
            local curr = {Unit = unit, Distance = VDist2(unitPos[1], unitPos[3], location[1], location[3]),
                           Id = unit.UnitId}
            table.insert(transports, curr)
        end
    end

    local numTransports = 0
    local transSlotTable = {}
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
            if transportsNeeded and table.empty(sortedList[i].Unit:GetCargo()) and not sortedList[i].Unit:IsUnitState('TransportLoading') then
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

    if transportsNeeded then
        ReturnTransportsToPool(platoon:GetSquadUnits('Scout'), false)
        return false, tempNeeded.Small, tempNeeded.Medium, tempNeeded.Large
    else
        platoon.UsingTransport = true
        return numTransports, 0, 0, 0
    end
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
end

--- Utility Function
--- Takes transports in platoon, returns them to pool, flys them back to return location
---@param units Unit[]
---@param move any
---@return boolean
function ReturnTransportsToPool(units, move)
    -- Put transports back in TPool
    local unit
    if not units then
        return false
    end

    for k, v in units do
        if not v.Dead then
            unit = v
            break
        end
    end

    if not unit then
        return false
    end

    local aiBrain = unit:GetAIBrain()
    local x, z = aiBrain:GetArmyStartPos()
    local position = RandomLocation(x, z)
    local safePath, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Air', unit:GetPosition(), position, 200)
    for k, unit in units do
        if not unit.Dead and EntityCategoryContains(categories.TRANSPORTATION, unit) then
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {unit}, 'Scout', 'None')
            if move then
                if safePath then
                    for _, p in safePath do
                        IssueMove({unit}, p)
                    end
                else
                    IssueMove({unit}, position)
                end
            end
        end
    end
end

--------------------
-- Cheat Utilities
--------------------

---@param aiBrain AIBrain
---@param cheatBool boolean
function SetupCampaignCheat(aiBrain, cheatBool)
    if cheatBool then
        aiBrain.CampaignCheatEnabled = true

        local buffDef = Buffs['CheatBuildRate']
        local buffAffects = buffDef.Affects
        buffAffects.BuildRate.Mult = tonumber(ScenarioInfo.Options.CampaignBuildMult)

        buffDef = Buffs['CheatIncome']
        buffAffects = buffDef.Affects
        buffAffects.EnergyProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)
        buffAffects.MassProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)

        local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        for _, v in pool:GetPlatoonUnits() do
            -- Apply build rate and income buffs
            ApplyCampaignCheatBuffs(v)
        end
    end
end

---@param unit Unit
function ApplyCampaignCheatBuffs(unit)
    Buff.ApplyBuff(unit, 'CheatIncome')
    Buff.ApplyBuff(unit, 'CheatBuildRate')
	
	-- Flag the unit as buffed, to avoid duplicate buff applications on maps that manually buff units via map script
	unit.EcoBuffed = true
	unit.BuildBuffed = true
end