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
--- Platoon counts usually are: 1, 2, or 3, depending on the difficulty

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
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

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is more or the same as desired.
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