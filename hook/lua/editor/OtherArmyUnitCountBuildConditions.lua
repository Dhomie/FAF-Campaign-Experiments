--****************************************************************************
--**
--**  File     :  /lua/editor/OtherArmyUnitCountBuildConditions.lua
--**  Author(s): Dru Staltman
--**
--**  Summary  : Generic AI Platoon Build Conditions
--**             Build conditions always return true or false
--**
--**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************

---@alias CompareType
---| ">="
---| "<="
---| "=="
---| '>'
---| '<'


---@param aiBrain AIBrain
---@param targetBrains string[]
---@param numReq number
---@param category EntityCategory
---@param compareType CompareType? defaults to `">="`
---@return boolean
function BrainsCompareNumCategory(aiBrain, targetBrains, numReq, category, compareType)
    local num = 0
    local targetBrainSet = {}
    local armySetup = ScenarioInfo.ArmySetup
    if type(targetBrains) == "string" then
        targetBrains = { targetBrains }
    end
    for _, brain in targetBrains do
		-- ScenarioInfo.HumanPlayers store army indexes that are keyed by their names, ie. {Player1 = 1; Player2 = 5; ...}
		-- Calling ipairs() on a non-number indexed/keyed table will not run at all, use pairs(), or nothing at all
        if brain == 'HumanPlayers' then
			for strArmy, iArmy in pairs(ScenarioInfo.HumanPlayers) do
                targetBrainSet[armySetup[strArmy].ArmyName] = true
            end
        else
            targetBrainSet[brain] = true
        end
    end

    for _, testBrain in ipairs(ArmyBrains) do
        if targetBrainSet[testBrain.Name] then
            num = num + testBrain:GetCurrentUnits(category)
        end
    end

    if not compareType or compareType == '>=' then
        return num >= numReq
    elseif compareType == '==' then
        return num == numReq
    elseif compareType == '<=' then
        return num <= numReq
    elseif compareType == '>' then
        return num > numReq
    elseif compareType == '<' then
        return num < numReq
    else
        return false
    end
end

---@param aiBrain AIBrain
---@param targetBrain string[]
---@param numReq number
---@param category EntityCategory
---@return boolean
function BrainGreaterThanNumCategory(aiBrain, targetBrain, numReq, category)
    return BrainsCompareNumCategory(aiBrain, targetBrain, numReq, category, ">")
end

---@param aiBrain AIBrain
---@param targetBrain string[]
---@param numReq number
---@param category EntityCategory
---@return boolean
function BrainLessThanNumCategory(aiBrain, targetBrain, numReq, category)
    return BrainsCompareNumCategory(aiBrain, targetBrain, numReq, category, "<")
end

---@param aiBrain AIBrain
---@param targetBrain string[]
---@param numReq number
---@param category EntityCategory
---@return boolean
function BrainGreaterThanOrEqualNumCategory(aiBrain, targetBrain, numReq, category)
    return BrainsCompareNumCategory(aiBrain, targetBrain, numReq, category, ">=")
end

---@param aiBrain AIBrain
---@param targetBrain string[]
---@param numReq number
---@param category EntityCategory
---@return boolean
function BrainLessThanOrEqualNumCategory(aiBrain, targetBrain, numReq, category)
    return BrainsCompareNumCategory(aiBrain, targetBrain, numReq, category, "<=")
end

---@param aiBrain AIBrain
---@param numReq number
---@param categories EntityCategory
---@param compareType CompareType? defaults to `">="`
---@return boolean
function FocusBrainBeingBuiltOrActiveCategoryCompare(aiBrain, numReq, categories, compareType)
    local num = 0
    local tblArmy = ListArmies()
	-- ScenarioInfo.HumanPlayers store army indexes that are keyed by their names, ie. {Player1 = 1; Player2 = 5; ...}
	-- Calling ipairs() on a non-number indexed/keyed table will not run at all, use pairs(), or nothing at all
    for strArmy, iArmy in pairs(ScenarioInfo.HumanPlayers) do
        local testBrain = GetArmyBrain(strArmy)
        for k, v in categories do
            num = num + testBrain:GetBlueprintStat('Units_BeingBuilt', v)
            num = num + testBrain:GetBlueprintStat('Units_Active', v)
        end
    end
    if not compareType or compareType == '>=' then
        return num >= numReq
    elseif compareType == '==' then
        return num == numReq
    elseif compareType == '<=' then
        return num <= numReq
    elseif compareType == '>' then
        return num > numReq
    elseif compareType == '<' then
        return num < numReq
    else
        return false
    end
end

-- Moved unsed Imports to bottom for mod compatibilty
local AIUtils = import("/lua/ai/aiutilities.lua")
local ScenarioFramework = import("/lua/scenarioframework.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
