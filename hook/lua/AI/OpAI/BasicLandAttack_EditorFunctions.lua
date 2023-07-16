----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/BasicLandAttack_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions. Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
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
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function BasicLandAttackChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
    local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
    return counter < number
end

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is more or the same as desired.
--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function BasicLandAttackMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
    local difficulty = ScenarioInfo.Options.Difficulty or 3
    local number = ScenarioInfo.OSPlatoonCounter[master .. "_D" .. difficulty] or difficulty
	
    return counter >= number
end

--- Checks if the OpAI platoon has the 'Transports' functionality enabled, returns true if its origin base has less than 5 transports in its unique transport pool
--- AKA 'Am I allowed to build transports, if so, do I have enough of them ?'
--- NOTE: The functionality can be enabled by using the 'OpAI:SetFunctionStatus(funcName, bool)' on an OpAI instance, example: OpAI:SetFunctionStatus('Transports', true)
---@param aiBrain AIBrain
---@param masterName string
---@param locationName Vector
---@return boolean
function NeedTransports(aiBrain, masterName, locationName)
	-- If we didn't enable transport functionality for our OpAI platoon, return false
	if not ScenarioInfo.OSPlatoonCounter[masterName .. '_Transports'] then
        return false
    end
	
	local poolName = 'TransportPool'
	
	if locationName then
		poolName = locationName .. '_TransportPool'
	end
	
    local transportPool = aiBrain:GetPlatoonUniquelyNamed(poolName)
	
    return not(transportPool and table.getn(transportPool:GetPlatoonUnits()) > 5) 
end