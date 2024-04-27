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