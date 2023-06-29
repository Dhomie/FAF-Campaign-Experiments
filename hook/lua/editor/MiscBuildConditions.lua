----------------------------------------------------------------------------
--
--  File     :  /lua/MiscBuildConditions.lua
--  Author(s): Dru Staltman, John Comes
--
--  Summary  : Generic AI Platoon Build Conditions
--             Build conditions always return true or false
--
--  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
----------------------------------------------------------------------------

local AIUtils = import("/lua/ai/aiutilities.lua")


---@param aiBrain AIBrain unused
---@return boolean
function True(aiBrain)
    return true
end

---@param aiBrain AIBrain unused
---@return boolean
function False(aiBrain)
    return false
end

---@param aiBrain AIBrain unused
---@param higherThan number
---@param lowerThan number
---@param minNumber number
---@param maxNumber number
---@return true | nil
function RandomNumber(aiBrain, higherThan, lowerThan, minNumber, maxNumber)
    local num = Random(minNumber, maxNumber)
	return higherThan < num and lowerThan > num
end

---@param aiBrain AIBrain
---@param layerPref string
---@return true | nil
function IsAIBrainLayerPref(aiBrain, layerPref)
	return layerPref == aiBrain.LayerPref
end

---@param aiBrain AIBrain unused
---@param num number
---@return true | nil
function MissionNumber(aiBrain, num)
	return ScenarioInfo.MissionNumber and ScenarioInfo.MissionNumber == num
end

---@param aiBrain AIBrain unused
---@param num number
---@return true | nil
function MissionNumberGreaterOrEqual(aiBrain, num)
	return ScenarioInfo.MissionNumber and ScenarioInfo.MissionNumber >= num
end

---@param aiBrain AIBrain unused
---@param num number
---@return true | nil
function MissionNumberLessOrEqual(aiBrain, num)
	return ScenarioInfo.MissionNumber and ScenarioInfo.MissionNumber <= num
end

---@param aiBrain AIBrain unused
---@param varName string
---@return true | nil
function CheckScenarioInfoVarTable(aiBrain, varName)
    if ScenarioInfo.VarTable[varName] then
        return true
    end
end

---@param aiBrain AIBrain unused
---@param varName string
---@return boolean
function CheckScenarioInfoVarTableFalse(aiBrain, varName)
    return not ScenarioInfo.VarTable[varName]
end

---@param aiBrain AIBrain unused
---@param diffLevel number
---@return true | nil
function DifficultyEqual(aiBrain, diffLevel)
	return ScenarioInfo.Options.Difficulty and ScenarioInfo.Options.Difficulty == diffLevel
end

---@param aiBrain AIBrain unused
---@param diffLevel number
---@return true | nil
function DifficultyGreaterOrEqual(aiBrain, diffLevel)
	return ScenarioInfo.Options.Difficulty and ScenarioInfo.Options.Difficulty >= diffLevel
end

---@param aiBrain AIBrain unused
---@param diffLevel number
---@return true | nil
function DifficultyLessOrEqual(aiBrain, diffLevel)
	return ScenarioInfo.Options.Difficulty and ScenarioInfo.Options.Difficulty <= diffLevel
end

---@param aiBrain AIBrain
---@param num number
---@return true | nil
function GreaterThanGameTime(aiBrain, num)
    local Time = GetGameTimeSeconds()
    if aiBrain.CheatEnabled then
        Time = Time * 2
    end
	return num < Time
end

---@param aiBrain AIBrain unused
---@param sizeX number
---@param sizeZ number
---@return true | nil
function MapGreaterThan(aiBrain, sizeX, sizeZ)
    local mapSizeX, mapSizeZ = GetMapSize()
	return mapSizeX > sizeX or mapSizeZ > sizeZ
end

---@param aiBrain AIBrain unused
---@param sizeX number
---@param sizeZ number
---@return true | nil
function MapLessThan(aiBrain, sizeX, sizeZ)
    local mapSizeX, mapSizeZ = GetMapSize()
	return mapSizeX < sizeX and mapSizeZ < sizeZ
end

--- Buildcondition to check pathing to current enemy 
--- Note this requires the CanPathToCurrentEnemy thread to be running
---@param aiBrain AIBrain
---@param locationType string
---@param pathType string
---@return boolean
function PathToEnemy(aiBrain, locationType, pathType)
    local currentEnemy = aiBrain:GetCurrentEnemy()
    if not currentEnemy then
        return true
    end
    local enemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
    local selfIndex = aiBrain:GetArmyIndex()
    if aiBrain.CanPathToEnemy[selfIndex][enemyIndex][locationType] == pathType then
        return true
    end
    return false
end

-- unused imports kept for mod support
local Utils = import("/lua/utilities.lua")
