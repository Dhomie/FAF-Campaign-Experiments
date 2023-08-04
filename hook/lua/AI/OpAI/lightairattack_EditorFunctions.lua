---------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/lightairattack_EditorFunctions
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
--- Platoon counts by default are: 1, 2, or 3, depending on the difficulty

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain
---@param master string
---@return boolean
function LightAirChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local num = ScenarioInfo.OSPlatoonCounter[master .. '_D' .. difficulty] or difficulty
	
	return counter < num
end

--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
---@param aiBrain AIBrain
---@param master string
---@return boolean
function LightAirMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local num = ScenarioInfo.OSPlatoonCounter[master .. '_D' .. difficulty] or difficulty
	
	return counter >= num
end