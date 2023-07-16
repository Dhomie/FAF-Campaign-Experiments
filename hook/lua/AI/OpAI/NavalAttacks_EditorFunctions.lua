----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/NavalAttacks_EditorFunctions
-- Author(s): speed2
-- Summary  : Generic AI Platoon Build Conditions. Build conditions always return true or false
----------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")

--- Some context information:
--- AttackManager -> AM for short
--- PlatoonBuildManager -> PBM for short
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories
--- Platoon counts usually are: 1, 2, or 3, depending on the difficulty

--- NOTE: This file is used by SCFA's BaseOpAI, which allows customization of what OpAI platoon we want to assemble
--- So, platoon counts can be set by mission creators, but if they are not set, we fall back to some default values instead

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
--- AKA 'Do we need more PBM platoons ?'
--- SCFA's BaseOpAI filters out platoons by allowed 'child' unit types, any unallowed ones' platoon builder is either removed from the PBM, or receive an additional 'False' build condition from MiscBuildConditions.lua
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalAttacksChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
    return counter < number
end

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is more or the same as desired.
--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalAttacksMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
	return counter >= number
end