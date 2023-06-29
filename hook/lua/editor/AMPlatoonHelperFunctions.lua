--- ChildCountDifficulty = BuildCondition
---@param aiBrain AIBrain
---@param master string
---@return boolean
function ChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master..'_D'..difficulty] or difficulty
	
	return counter < number
end

--- MasterCountDifficulty = BuildCondition
---@param aiBrain AIBrain
---@param master string
---@return boolean
function MasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master..'_D'..difficulty] or difficulty
	
	return counter >= number
end

-- Unused Files but moved for Mod Support
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local AIUtils = import("/lua/ai/aiutilities.lua")