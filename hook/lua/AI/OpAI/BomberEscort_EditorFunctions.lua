---------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/BomberEscort_EditorFunctions
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

--- Changed platoon counts to the default, previously it was 1 for Easy, 2 for Normal and Hard

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function BomberEscortChildBomberCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_BomberChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local num = ScenarioInfo.OSPlatoonCounter[master..'_BomberChildren_D' .. difficulty] or difficulty

    return counter < num 
end

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less than desired.
--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function BomberEscortChildEscortCountDifficulty(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_EscortChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
    local num = ScenarioInfo.OSPlatoonCounter[master..'_EscortChildren_D' .. difficulty] or difficulty

    return counter < num

end

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is more or the same as desired.
--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
--- This AM platoon is assembled from a mix of Air-To-Surface, and Air-to-Air combat units
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function BomberEscortMasterCountDifficulty(aiBrain, master)
    local escortCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_EscortChildren')
	local bomberCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_BomberChildren')
	
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
	local escortNum = ScenarioInfo.OSPlatoonCounter[master..'_EscortChildren_D' .. difficulty] or difficulty
    local bomberNum = ScenarioInfo.OSPlatoonCounter[master..'_BomberChildren_D' .. difficulty] or difficulty
	
    return bomberCounter >= bomberNum and escortCounter >= escortNum
end

--- BomberEscortAI = AddFunction   doc = "Please work function docs."
---@param platoon Platoon
function BomberEscortAI(platoon)
    local aiBrain = platoon:GetBrain()
	
    while aiBrain:PlatoonExists(platoon) do
        local target = false
		
        if table.getn(platoon:GetSquadUnits('artillery')) > 0 then
            target = platoon:FindClosestUnit('artillery', 'Enemy', true, categories.ALLUNITS-categories.WALL)
        else
            target = platoon:FindClosestUnit('attack', 'Enemy', true, categories.ALLUNITS)
        end
		
        if target and not target:IsDead() then
            platoon:Stop()
			local cmd = platoon:AggressiveMoveToLocation( target:GetPosition() )
        else
            platoon:AggressiveMoveToLocation((aiBrain:GetHighestThreatPosition(2, true)))
        end
        WaitTicks(180)
    end
end