----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/LandAssault_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions. Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
----------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")
local ScenarioPlatoonAI = import("/lua/scenarioplatoonai.lua")

--- Some context information:
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories
--- Platoon counts by default are: 3, 4, or 5, depending on the difficulty

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function LandAssaultChildCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master..'_D'..difficulty] or (difficulty + 2)
	
	return counter < number
end

--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
---@param aiBrain AIBrain
---@param master string
---@return boolean
function LandAssaultMasterCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local number = ScenarioInfo.OSPlatoonCounter[master..'_D'..difficulty] or (difficulty + 2)
	
	return counter >= number
end

--- Assigns platoon data if none is given for the Master platoon via some very scripted naming methods from the map's 'save.lua'
--- Otherwise this is just 'LandAssaultWithTransports' from 'ScenarioPlatoonAI.lua'
---@param platoon Platoon
function LandAssaultAttack(platoon)
    local aiBrain = platoon:GetBrain()
    local master = string.sub(platoon.PlatoonData.BuilderName, 12)
	
    if not platoon.PlatoonData.LandingChain and Scenario.Chains[master .. '_LandingChain'] then
        platoon.PlatoonData.LandingChain = master .. '_LandingChain'
    elseif Scenario.Chains[aiBrain.Name .. '_LandingChain'] then
        platoon.PlatoonData.LandingChain = aiBrain.Name .. '_LandingChain'
    end
	
    if not platoon.PlatoonData.AttackChain and Scenario.Chains[master .. '_AttackChain'] then
        platoon.PlatoonData.AttackChain = master .. '_AttackChain'
    elseif Scenario.Chains[aiBrain.Name .. '_AttackChain'] then
        platoon.PlatoonData.AttackChain = aiBrain.Name .. '_AttackChain'
    end
	
    if not platoon.PlatoonData.TransportReturn then
        if Scenario.MasterChain._MASTERCHAIN_.Markers[master .. '_TransportReturn'] then
            platoon.PlatoonData.TransportReturn = master .. '_TransportReturn'
        elseif Scenario.MasterChain._MASTERCHAIN_.Markers[aiBrain.Name .. '_TransportReturn'] then
            platoon.PlatoonData.TransportReturn = aiBrain.Name .. '_TransportReturn'
        end
    end
	
    if (platoon.PlatoonData.LandingChain and platoon.PlatoonData.AttackChain) or platoon.PlatoonData.AssaultChains then
        ScenarioPlatoonAI.LandAssaultWithTransports(platoon)
    else
        error('*AI ERROR: LandAssault looking for chains --\"'..master.. '_LandingChain\"-- or --\"'..aiBrain.Name .. '_LandingChain\"-- and --\"'..master.. '_AttackChain\"-- or --\"'..aiBrain.Name .. '_AttackChain\"--', 2)
    end
end

--- Checks the AI's transport count, returns true if it has less than desired transports in one of its transport pools
--- AKA 'Do we have enough transports to assume we can transport our Master platoon ?'
---@param aiBrain AIBrain default_brain
---@param tCount number[] default_transport_count
---@param locationName string default_location_type
---@return boolean
function LandAssaultTransport(aiBrain, tCount)
	-- Get the the universal 'TransportPool' platoon, if we can't get it, return true, we need transports
    local transportPool = aiBrain:GetPlatoonUniquelyNamed('TransportPool')
	if not transportPool then
		return true
	end

	-- Default to 4 if tCount isn't provided, or valid
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	local count = tCount
	if not count or type(count) ~= 'number' then
		count = 4
	end
	
	-- Multiply total transport count according to difficulty, since we multiply the land platoon's size as well
	local num = count * difficulty
	
	-- The engine version of GetPlatoonUnits() can return with the dead/destroyed units, we gotta check if the units are actually alive
	local counter = 0
	local units = transportPool:GetPlatoonUnits()
	for index, unit in units do
		if not unit:BeenDestroyed() then
			counter = counter + 1
		end
	end
	
	return counter < num
end

--- Assigns TransportMoveLocation platoon data if none is given for the Master platoon via some very scripted naming methods from the map's 'save.lua'
--- Otherwise this is just 'TransportPool' from 'ScenarioPlatoonAI.lua'
---@param platoon Platoon default_platoon
function LandAssaultTransportThread(platoon)
    local aiBrain = platoon:GetBrain()
    local master = string.sub(platoon.PlatoonData.BuilderName, 11)
    local position = platoon.PlatoonData.TransportMoveLocation
	
    if not position and Scenario.MasterChain._MASTERCHAIN_.Markers[master .. '_TransportMoveLocation'] then
        position = master .. '_TransportMoveLocation'
    elseif not position and Scenario.MasterChain._MASTERCHAIN_.Markers[aiBrain.Name .. '_TransportMoveLocation'] then
        position = master .. '_TransportMoveLocation'
    end
	
    if position then
        platoon.PlatoonData.TransportMoveLocation = position
    end
    ScenarioPlatoonAI.TransportPool(platoon)
end