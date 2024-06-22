-----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/HeavyLandAttack_EditorFunctions
-- Author(s): Dru Staltman
-- Summary  : Generic AI Platoon Build Conditions. Build conditions always return true or false
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------------------------------------------
local ScenarioFramework = import("/lua/scenarioframework.lua")

--- Some context information:
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories
--- Platoon counts by default are: 1, 2, or 3, depending on the difficulty

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function HeavyLandAttackChildDirectFire(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_DirectFireChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
    local num = ScenarioInfo.OSPlatoonCounter[master..'_DirectFireChildren_D' .. difficulty] or difficulty

    return counter < num
end

--- AKA 'Do we need more of this platoon ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function HeavyLandAttackChildArtillery(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_ArtilleryChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
    local num = ScenarioInfo.OSPlatoonCounter[master..'_ArtilleryChildren_D' .. difficulty] or difficulty

	return counter < num
end

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function HeavyLandAttackChildAntiAir(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_AntiAirChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
    local num = ScenarioInfo.OSPlatoonCounter[master..'_AntiAirChildren_D' .. difficulty] or 1
    
	return counter < num
end

--- AKA 'Do we need more PBM platoons ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function HeavyLandAttackChildDefensive(aiBrain, master)
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_DefensiveChildren')
	local difficulty = ScenarioInfo.Options.Difficulty or 3

    local num = ScenarioInfo.OSPlatoonCounter[master..'_DefensiveChildren_D' .. difficulty] or 1
	
	return counter < num
end

--- AKA 'Do we have enough PBM platoons to form the AM platoon ?'
--- This AM platoon is assembled from a mix of Direct-Fire, Artillery, AA, and Mobile Shield/Stealth platoons.
---@param aiBrain AIBrain
---@param master string
---@return boolean
function HeavyLandAttackMasterCountDifficulty(aiBrain, master)
	local difficulty = ScenarioInfo.Options.Difficulty or 3
	
    local directFireCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_DirectFireChildren')
    local directFireNum = ScenarioInfo.OSPlatoonCounter[master..'_DirectFireChildren_D' .. difficulty] or difficulty

    local artilleryCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_ArtilleryChildren')
    local artilleryNum = ScenarioInfo.OSPlatoonCounter[master..'_ArtilleryChildren_D' .. difficulty] or difficulty

    local antiAirCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_AntiAirChildren')
    local antiAirNum = ScenarioInfo.OSPlatoonCounter[master..'_AntiAirChildren_D' .. difficulty] or 1

    local defensiveCounter = ScenarioFramework.AMPlatoonCounter(aiBrain, master..'_DefensiveChildren')
    local defensiveNum = ScenarioInfo.OSPlatoonCounter[master..'_DefensiveChildren_D' .. difficulty] or 1
    

	return (directFireCounter >= directFireNum) and (artilleryCounter >= artilleryNum) and (antiAirCounter >= antiAirNum) and (defensiveCounter >= defensiveNum or not CheckDefensiveBuildable(aiBrain))
end

--- Checks if the given AI army has the required factory, and no unit restrictions to build Mobile Shields or Mobile Stealth
--- AKA 'Can I build Mobile Shields or Mobile Stealth from one of my current factories ?'
---@param aiBrain AIBrain
---@return boolean
function CheckDefensiveBuildable(aiBrain)
    local facIndex = aiBrain:GetFactionIndex()
    local factories = aiBrain:GetListOfUnits(categories.FACTORY * categories.LAND * (categories.TECH3 + categories.TECH2), false)
	local defensiveUnitIDs = {'uel0307', 'ual0307', 'url0306'} -- UEF = 1; Aeon = 2; Cybran = 3
	
	return not table.empty(factories) and factories[1]:CanBuild(defensiveUnitIDs[facIndex])
end
