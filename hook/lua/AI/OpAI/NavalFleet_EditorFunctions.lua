---------------------------------------------------------------------------------------------------
-- File     : /lua/ai/OpAI/NavalFleet_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
---------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")

--- Some context information:
--- AttackManager -> AM for short
--- PlatoonBuildManager -> PBM for short
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories
--- Platoon counts usually are: 1, 2, or 3, depending on the difficulty

--- The corresponding 'save.lua' has been slightly changed
--- InstanceCounts for T2 Child platoons have been increased from 1 to 2, this should result in larger naval fleets

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
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

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
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

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
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