------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/AirAttacks_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions
--            Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------------------

local ScenarioFramework = import("/lua/scenarioframework.lua")

--- AirAttackChildCountDifficulty = BuildCondition   doc = "Please work function docs."
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function AirAttackChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty

    return counter < number
end

--- AirAttackMasterCountDifficulty = BuildCondition   doc = "Please work function docs."
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function AirAttackMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master..'_D'..ScenarioInfo.Options.Difficulty] or difficulty

    return counter >= number
end