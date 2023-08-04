---------------------------------------------------------------------------------------------------
-- File     : /lua/ai/OpAI/NavalFleet_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
---------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")

--- Some context information:
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories
--- Changed platoon counts to the default 1/2/3, previously it was 1/1/1 naval fleet, and 1/2/3 sub fleets 

--- InstanceCounts for T2 Child platoons have been increased from 1 to 2, this should result in larger naval fleets

--- AKA 'Do we need more PBM platoons ?'
--- NOTE: This was originally coded to set fleetNum to 1 in all cases, changed it to the default platoon count
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalFleetChildCountDifficulty(aiBrain, master)
    local fleetCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_FleetChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local fleetNum = ScenarioInfo.OSPlatoonCounter[master..'_FleetChildren_D' .. difficulty] or 3
    
    return fleetCounter < fleetNum
end

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalSubChildCountDifficulty(aiBrain, master)
    local subsCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_SubsChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local subsNum = ScenarioInfo.OSPlatoonCounter[master..'_SubsChildren_D' .. difficulty] or 3
        
    return subsCounter < subsNum
end

--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
--- This AM platoon is assembled from a mix of Submarine, and Surface Ship platoons
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalFleetMasterCountDifficulty(aiBrain, master)
    local subsCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_SubsChildren')
	local fleetCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_FleetChildren')
	
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
    local subsNum = ScenarioInfo.OSPlatoonCounter[master..'_SubsChildren_D' .. difficulty] or 3
    local fleetNum = ScenarioInfo.OSPlatoonCounter[master..'_FleetChildren_D' .. difficulty] or 3
	
    return (fleetCounter >= fleetNum) and (subsCounter >= subsNum)
end