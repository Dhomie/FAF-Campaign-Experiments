----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/NavalAttacks_EditorFunctions
-- Author(s): speed2
-- Summary  : Generic AI Platoon Build Conditions. Build conditions always return true or false
----------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")

--- NavalAttacksChildCountDifficulty = BuildCondition   doc = "Please work function docs."
---@param aiBrain AIBrain
---@param master string
---@param number number
---@return boolean
function NavalAttacksChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
    return counter < number
end

--- NavalAttacksMasterCountDifficulty = BuildCondition   doc = "Please work function docs."
---@param aiBrain AIBrain
---@param master string
---@return boolean
function NavalAttacksMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
	return counter >= number
end