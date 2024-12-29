-----------------------------------------------------------------
-- File     :  /cdimage/lua/editor/EconomyBuildConditions.lua
-- Author(s): Dru Staltman, John Comes
-- Summary  : Generic AI Platoon Build Conditions
--           Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------

local AIUtils = import("/lua/ai/aiutilities.lua")

--- Upvalue scope for performace
local TableInsert = table.insert

--- Credit to Sorian.
---@param aiBrain AIBrain
---@param upgrade string
---@param has boolean
---@return boolean
function BaseCommanderHasUpgrade(aiBrain, upgrade, base, has)
    local Cmdr = aiBrain:GetListOfUnits(categories.COMMAND, false)
    for k,v in units do
        if v:HasEnhancement(upgrade) and has then
            return true
        elseif not v:HasEnhancement(upgrade) and not has then
            return true
        end
    end
    return false
end

--- Assembles a table of specified owned units in the specified location, and radius
---@param aiBrain AIBrain
---@param categories | Entity categories
---@param location Vector
---@param radius Integer
---@return table | Table of units
function GetOwnUnitsAroundPosition(aiBrain, categories, location, radius)
	local units = aiBrain:GetUnitsAroundPoint(categories, location, radius, 'Ally')
	local index = aiBrain:GetArmyIndex()
	local retUnits = {}
	for _, v in units do
		if not v.Dead and not v:IsBeingBuilt() and v.Brain:GetArmyIndex() == index then
			TableInsert(retUnits, v)
		end
	end

	return retUnits
end

function NeedStructure(aiBrain, structureType, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	if not bManager then
		return false
	end
	
	
end

---@param aiBrain AIBrain
---@param baseName string
---@param category EntityCategory
---@param varName | String or Integer
---@return boolean
function NumUnitsLessNearBase(aiBrain, baseName, category, varName)
	-- Try getting the base from an existing base template
	local base = aiBrain.BaseManagers[baseName] or aiBrain.BaseTemplates[baseName]
	
	-- If no such template exists, try getting it via a PBM build location, if that list exists
    if not base and aiBrain.PBM.Locations then
		for Index, Location in aiBrain.PBM.Locations do
			if baseName == Location.LocationType then
				base = Location
				break
			end
		end
    end
	
	-- If we couldn't get a valid base, return false
	if not base then
		return false
	end
	
	-- Get all allied units near the base, and filter them via a brain comparison (might be better to do an army index comparison?)
	-- Units being built are also added to this
    local unitList = aiBrain:GetUnitsAroundPoint(category, (base.Location or base.Position), base.Radius, 'Ally')
    local count = 0
    for Index, Unit in unitList do
        if Unit.Brain == aiBrain then
            count = count + 1
        end
    end
	
	-- GPG behaviour for BaseManagers, gotta check the type of base we got and the param
	-- Things like sACU and total Engineer counts are stored inside "ScenarioInfo.VarTable"
	local compareVar = ScenarioInfo.VarTable[varName] or varName
	return count < compareVar
end

---@param aiBrain AIBrain
---@param baseName string
---@param category EntityCategory
---@param varName | String or Integer
---@return boolean
function NumUnitsGreaterOrEqualNearBase(aiBrain, baseName, category, varName)
	-- Try getting the base from an existing base template
	local base = aiBrain.BaseManagers[baseName] or aiBrain.BaseTemplates[baseName]
	
	-- If no such template exists, try getting it via a PBM build location, if that list exists
    if not base and aiBrain.PBM.Locations then
		for Index, Location in aiBrain.PBM.Locations do
			if baseName == Location.LocationType then
				base = Location
				break
			end
		end
    end
	
	-- If we couldn't get a valid base, return false
	if not base then
		return false
	end
	
	-- Get all allied units near the base, and filter them via a brain comparison (might be better to do an army index comparison?)
	-- Units being built are also added to this
    local unitList = aiBrain:GetUnitsAroundPoint(category, (base.Location or base.Position), base.Radius, 'Ally')
    local count = 0
    for Index, Unit in unitList do
        if Unit.Brain == aiBrain then
            count = count + 1
        end
    end
	
	-- GPG behaviour for BaseManagers, gotta check the type of base we got and the param
	-- Things like sACU and total Engineer counts are stored inside "ScenarioInfo.VarTable"
	local compareVar = ScenarioInfo.VarTable[varName] or varName
	return count >= compareVar
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseManagerNeedsEngineers(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.EngineerQuantity > bManager.CurrentEngineerCount
end

---@param aiBrain ArmiesTable
---@param level number
---@param baseName string
---@return boolean
function HighestFactoryLevel(aiBrain, level, baseName)
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        return false
    end
	
	local basePos = bManager:GetPosition()
    local baseRad = bManager.Radius

    local t3FacList = GetOwnUnitsAroundPosition(aiBrain, categories.FACTORY * categories.TECH3, basePos, baseRad)
    local t2FacList = GetOwnUnitsAroundPosition(aiBrain, categories.FACTORY * categories.TECH2, basePos, baseRad)
    if t3FacList and not table.empty(t3FacList) then
		return level == 3
    elseif t2FacList and not table.empty(t2FacList) then
        return level == 2
    end
    return true
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function UnfinishedBuildingsCheck(aiBrain, baseName)
    local bManager = aiBrain.BaseManagers[baseName]
	
	-- Return if the BaseManager doesn't exist, or the list is empty, or all buildings are finished
    if not bManager or table.empty(bManager.UnfinishedBuildings) then
        return false
    end

    -- Check list
    local armyIndex = aiBrain:GetArmyIndex()
    local beingBuiltList = {}
    local buildingEngs = aiBrain:GetListOfUnits(categories.ENGINEER, false)
    for _, v in buildingEngs do
        local buildingUnit = v.UnitBeingBuilt
        if buildingUnit and buildingUnit.UnitName then
            beingBuiltList[buildingUnit.UnitName] = true
        end
    end

    for unitName, _ in bManager.UnfinishedBuildings do
        if ScenarioInfo.UnitNames[armyIndex][unitName] and not ScenarioInfo.UnitNames[armyIndex][unitName].Dead then
            if not beingBuiltList[unitName] then
                return true
            end
        end
    end
    return false
end

---@param aiBrain AIBrain
---@param baseName string
---@param catTable string
---@return boolean
function CategoriesBeingBuilt(aiBrain, baseName, catTable)
	local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        return false
    end

    local basePos = bManager:GetPosition()
    local baseRad = bManager.Radius
    if not (basePos and baseRad) then
        return false
    end
	
    --local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false) -- This is rather ineffecient, because it returns with ALL construction units on the map
	local unitsBuilding = GetOwnUnitsAroundPosition(aiBrain, categories.CONSTRUCTION, basePos, baseRad)
    for unitNum, unit in unitsBuilding do
        if not unit.Dead and unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead then
                for catNum, buildeeCat in catTable do
                    local buildCat = ParseEntityCategory(buildeeCat)
                    if EntityCategoryContains(buildCat, buildingUnit) then
                        --local unitPos = unit:GetPosition()
                        --if unitPos and VDist2(basePos[1], basePos[3], unitPos[1], unitPos[3]) < baseRad then
                            return true
                        --end
                    end
                end
            end
        end
    end
    return false
end

---@param aiBrain AIBrain
---@param level number
---@param baseName string
---@param type string
---@return boolean
function HighestFactoryLevelType(aiBrain, level, baseName, type)
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        return false
    end
	
	local basePos = bManager:GetPosition()
    local baseRad = bManager.Radius

    local catCheck
    if type == 'Air' then
        catCheck = categories.AIR
    elseif type == 'Land' then
        catCheck = categories.LAND
    elseif type == 'Sea' then
        catCheck = categories.NAVAL
    end

    local t3FacList = GetOwnUnitsAroundPosition(aiBrain, categories.FACTORY * categories.TECH3 * catCheck, basePos, baseRad)
    local t2FacList = GetOwnUnitsAroundPosition(aiBrain, categories.FACTORY * categories.TECH2 * catCheck, basePos, baseRad)
    if t3FacList and not table.empty(t3FacList) then
        return level == 3
    elseif t2FacList and not table.empty(t2FacList) then
        return level == 2
    end
    return true
end

---@param aiBrain AIBrain
---@param techLevel number
---@param engQuantity number
---@param pType string
---@param baseName string
---@return boolean
function FactoryCountAndNeed(aiBrain, techLevel, engQuantity, pType, baseName)
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        return false
    end

    local facCat = ParseEntityCategory('FACTORY * TECH'..techLevel)
    local facList = GetOwnUnitsAroundPosition(aiBrain, facCat, bManager:GetPosition(), bManager.Radius)
    local typeCount = {Air = 0, Land = 0, Sea = 0, }
    for k, v in facList do
        if EntityCategoryContains(categories.AIR, v) then
            typeCount['Air'] = typeCount['Air'] + 1
        elseif EntityCategoryContains(categories.LAND, v) then
            typeCount['Land'] = typeCount['Land'] + 1
        elseif EntityCategoryContains(categories.NAVAL, v) then
            typeCount['Sea'] = typeCount['Sea'] + 1
        end
    end
	
	--LOG("BMBC: Engineer count in " .. tostring(baseName) .. " : " .. tostring(bManager.CurrentEngineerCount) .. " | with EngineersBuilding added: " .. tostring(bManager.CurrentEngineerCount + bManager:GetEngineersBuilding()))

    if typeCount[pType] >= typeCount['Air'] and typeCount[pType] >= typeCount['Land'] and typeCount[pType] >= typeCount['Sea'] then
        if typeCount[pType] == engQuantity and bManager.EngineerQuantity >= (bManager.CurrentEngineerCount + bManager:GetEngineersBuilding() + engQuantity) then
            return true
        elseif bManager.EngineerQuantity - (bManager.CurrentEngineerCount + bManager:GetEngineersBuilding() + engQuantity) == 0 and typeCount[pType] >= engQuantity then
            return true
        elseif bManager.EngineerQuantity - (bManager.CurrentEngineerCount + bManager:GetEngineersBuilding() + engQuantity) > 0 and engQuantity == 5 and typeCount[pType] >= 5 then
            return true
        end
    end

    return false
end

---@param aiBrain AIBrain
---@param baseName string
---@param tech integer
---@return boolean
function TransportsTechAllowed(aiBrain, baseName, tech)
	local bManager = aiBrain.BaseManagers[baseName]
    return bManager and bManager.TransportsTech == tech
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function NeedTransports(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
		return false
	end
	
	-- Get either the specific transport platoon, or the universal 'TransportPool' platoon
    local platoon = aiBrain:GetPlatoonUniquelyNamed(baseName .. "_TransportPool")
	-- If neither exists, we need to build transports, return true
	if not platoon then
		return true
	end
	
	-- The engine version of GetPlatoonUnits() can return with the dead/destroyed units, we gotta check if the units are actually alive
	local counter = 0
	local units = platoon:GetPlatoonUnits()
	for index, unit in units do
		if not unit:BeenDestroyed() then
			counter = counter + 1
		end
	end

	return counter < bManager.TransportsNeeded
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseActive(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.Active
end

--- Deprecated, it was supposed to be a condition for an unfinished reclaim function/thread
---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseReclaimEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
    return bManager and bManager.FunctionalityStates.EngineerReclaiming
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BasePatrollingEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
    return bManager and bManager.FunctionalityStates.Patrolling
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseBuildingEngineers(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.BuildEngineers
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseEngineersEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.Engineers
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function LandScoutingEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.LandScouting
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function AirScoutingEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.AirScouting
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function ExpansionBasesEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.ExpansionBases
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function TMLsEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
    return bManager and bManager.FunctionalityStates.TMLs
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function NukesEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	-- Nuke Lobby Option: 1 -> Disabled; 2 -> Enabled
	return (bManager and bManager.FunctionalityStates.Nukes) or (ScenarioInfo.Options.CampaignAINukes and ScenarioInfo.Options.CampaignAINukes == 2)
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function TransportsEnabled(aiBrain, baseName)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates.Transports
end

--- Checks if the specified functionality is enabled for a BaseManager instance
--- This one is a universal function that could easily replace the 10 or so functions above with just 1 additional parameter
---@param aiBrain AIBrain
---@param baseName string
---@param functionality string
---@return boolean
function BaseManagerFunctionalityEnabled(aiBrain, baseName, functionality)
	local bManager = aiBrain.BaseManagers[baseName]
	return bManager and bManager.FunctionalityStates[functionality]
end

--- Moved Unused Imports for mod compatibility
local ScenarioFramework = import("/lua/scenarioframework.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")