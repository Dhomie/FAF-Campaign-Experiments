-----------------------------------------------------------------
-- File     :  /cdimage/lua/editor/EconomyBuildConditions.lua
-- Author(s): Dru Staltman, John Comes
-- Summary  : Generic AI Platoon Build Conditions
--           Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------

local AIUtils = import("/lua/ai/aiutilities.lua")

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseManagerNeedsEngineers(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].EngineerQuantity > aiBrain.BaseManagers[baseName].CurrentEngineerCount
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

    local t3FacList = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.FACTORY * categories.TECH3, bManager:GetPosition(), bManager.Radius)
    local t2FacList = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.FACTORY * categories.TECH2, bManager:GetPosition(), bManager.Radius)
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
---@param level number
---@param baseName string
---@param type string
---@return boolean
function HighestFactoryLevelType(aiBrain, level, baseName, type)
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        return false
    end

    local catCheck
    if type == 'Air' then
        catCheck = categories.AIR
    elseif type == 'Land' then
        catCheck = categories.LAND
    elseif type == 'Sea' then
        catCheck = categories.NAVAL
    end

    local t3FacList = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.FACTORY * categories.TECH3 * catCheck, bManager:GetPosition(), bManager.Radius)
    local t2FacList = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.FACTORY * categories.TECH2 * catCheck, bManager:GetPosition(), bManager.Radius)
    if t3FacList and not table.empty(t3FacList) then
        return level == 3
    elseif t2FacList and not table.empty(t2FacList) then
        return level == 2
    end
    return true
end

---@param aiBrain AIBrain
---@param baseName string
---@param tech integer
---@return boolean
function TransportsTechAllowed(aiBrain, baseName, tech)
    return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].TransportsTech == tech
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function NeedTransports(aiBrain, baseName)
    if not aiBrain.BaseManagers[baseName] then
		return false
	end

    local transportPool = aiBrain:GetPlatoonUniquelyNamed(baseName .. "_TransportPool")
    if not transportPool then
		return true 
	end
	
    return aiBrain.BaseManagers[baseName].TransportsNeeded >= table.getn(transportPool:GetPlatoonUnits())
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseActive(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].Active
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseReclaimEnabled(aiBrain, baseName)
    return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.EngineerReclaiming
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BasePatrollingEnabled(aiBrain, baseName)
    return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.Patrolling
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseBuildingEngineers(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.BuildEngineers
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function BaseEngineersEnabled(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.Engineers
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function LandScoutingEnabled(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.LandScouting
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function AirScoutingEnabled(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.AirScouting
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function ExpansionBasesEnabled(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.ExpansionBases
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function TMLsEnabled(aiBrain, baseName)
    return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.TMLs
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function NukesEnabled(aiBrain, baseName)
	-- Nuke Lobby Option: 1 -> Disabled; 2 -> Enabled
	return (aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.Nukes) or (ScenarioInfo.Options.CampaignAINukes and ScenarioInfo.Options.CampaignAINukes == 2)
end

---@param aiBrain AIBrain
---@param baseName string
---@return boolean
function TransportsEnabled(aiBrain, baseName)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates.Transports
end

--- Checks if the specified functionality is enabled for a BaseManager instance
--- This one is a universal function that could easily replace the 10 or so functions above with just 1 additional parameter
---@param aiBrain AIBrain
---@param baseName string
---@param functionality string
---@return boolean
function BaseManagerFunctionalityEnabled(aiBrain, baseName, functionality)
	return aiBrain.BaseManagers[baseName] and aiBrain.BaseManagers[baseName].FunctionalityStates[functionality]
end

--- Moved Unused Imports for mod compatibility
local ScenarioFramework = import("/lua/scenarioframework.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")