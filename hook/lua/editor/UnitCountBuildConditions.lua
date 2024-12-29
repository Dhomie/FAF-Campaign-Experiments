--****************************************************************************
--**
--**  File     :  /lua/editor/UnitCountBuildConditions.lua
--**  Author(s): Dru Staltman, John Comes
--**
--**  Summary  : Generic AI Platoon Build Conditions
--**             Build conditions always return true or false
--**
--**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************
local AIUtils = import("/lua/ai/aiutilities.lua")
local ScenarioFramework = import("/lua/scenarioframework.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local Utils = import("/lua/utilities.lua")

---@param aiBrain AIBrain
---@param numReq number
---@param category EntityCategory
---@param idleReq boolean
---@return boolean
function HaveEqualToUnitsWithCategory(aiBrain, numReq, category, idleReq)
    local numUnits
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    if not idleReq then
        numUnits = aiBrain:GetCurrentUnits(testCat)
    else
        numUnits = table.getn(aiBrain:GetListOfUnits(testCat, true))
    end

	return numUnits == numReq
end

---@param aiBrain AIBrain
---@param numReq number
---@param category EntityCategory
---@param idleReq boolean
---@return boolean
function HaveGreaterThanUnitsWithCategory(aiBrain, numReq, category, idleReq)
    local numUnits
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    if not idleReq then
        numUnits = aiBrain:GetCurrentUnits(testCat)
    else
        numUnits = table.getn(aiBrain:GetListOfUnits(testCat, true))
    end

	return numUnits > numReq
end

---@param aiBrain AIBrain
---@param numReq number
---@param category EntityCategory
---@param idleReq boolean
---@return boolean
function HaveLessThanUnitsWithCategory(aiBrain, numReq, category, idleReq)
    local numUnits
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    if not idleReq then
        numUnits = aiBrain:GetCurrentUnits(testCat)
    else
        numUnits = table.getn(aiBrain:GetListOfUnits(testCat, true))
    end
	return numUnits < numReq
end

---@param aiBrain AIBrain
---@param numReq number
---@param category EntityCategory
---@param area Area
---@return boolean
function HaveLessThanUnitsWithCategoryInArea(aiBrain, numReq, category, area)
    local numUnits = ScenarioFramework.NumCatUnitsInArea(category, ScenarioUtils.AreaToRect(area), aiBrain)
	return numUnits < numReq
end

---@param aiBrain AIBrain
---@param baseName string
---@param category EntityCategory
---@param num number
---@return boolean
function NumUnitsLessNearBase(aiBrain, baseName, category, num)
	-- Try getting the base from an existing base template
	local base = aiBrain.BaseTemplates[baseName].Location
	
	-- If no such template exists, try getting it via a PBM build location, if that list exists
    if not base and aiBrain.PBM.Locations then
		for Index, Location in aiBrain.PBM.Locations do
			if baseName == Location.LocationType then
				base = Location
				break
			end
		end
    end
	
	-- If we couldn't get a valid base, return false
	if not base then
		return false
	end
	
	-- Get all allied units near the base, and filter them via a brain comparison (might be better to do an army index comparison?)
	-- Units being built are also added to this
    local unitList = aiBrain:GetUnitsAroundPoint(category, base.Location, base.Radius, 'Ally')
    local count = 0
    for Index, Unit in unitList do
        if Unit.Brain == aiBrain then
            count = count + 1
        end
    end
	return count < num
end

---@param aiBrain AIBrain
---@param category1 EntityCategory
---@param category2 EntityCategory
---@return boolean
function HaveLessThanUnitComparison(aiBrain, category1, category2)
    local testCat1 = category1
    if type(category1) == 'string' then
        testCat1 = ParseEntityCategory(category1)
    end
    local testCat2 = category2
    if type(category2) == 'string' then
        testCat2 = ParseEntityCategory(category2)
    end
	
    return aiBrain:GetCurrentUnits(testCat1) < aiBrain:GetCurrentUnits(testCat2)
end

---@param aiBrain AIBrain
---@param category1 EntityCategory
---@param category2 EntityCategory
---@return boolean
function HaveGreaterThanUnitComparison(aiBrain, category1, category2)
    local testCat1 = category1
    if type(category1) == 'string' then
        testCat1 = ParseEntityCategory(category1)
    end
    local testCat2 = category2
    if type(category2) == 'string' then
        testCat2 = ParseEntityCategory(category2)
    end
	
    return aiBrain:GetCurrentUnits(testCat1) > aiBrain:GetCurrentUnits(testCat2)
end

---@param aiBrain AIBrain
---@param varName string
---@param category EntityCategory
---@return boolean
function HaveLessThanVarTableUnitsWithCategory(aiBrain, varName, category)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local numUnits = aiBrain:GetCurrentUnits(testCat)

    return ScenarioInfo.VarTable[varName] and (numUnits < ScenarioInfo.VarTable[varName])
end

---@param aiBrain AIBrain
---@param varName string
---@param category EntityCategory
---@return boolean
function HaveGreaterThanVarTableUnitsWithCategory(aiBrain, varName, category)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local numUnits = aiBrain:GetCurrentUnits(testCat)
    
	return ScenarioInfo.VarTable[varName] and (numUnits > ScenarioInfo.VarTable[varName])
end

---@param aiBrain AIBrain
---@param varName string
---@param category EntityCategory
---@param area string
---@return boolean
function HaveLessThanVarTableUnitsWithCategoryInArea(aiBrain, varName, category, area)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local numUnits = ScenarioFramework.NumCatUnitsInArea(testCat, ScenarioUtils.AreaToRect(area), aiBrain)

	return ScenarioInfo.VarTable[varName] and (numUnits < ScenarioInfo.VarTable[varName])
end

---@param aiBrain AIBrain
---@param varName string
---@param category EntityCategory
---@param area string
---@return boolean
function HaveGreaterThanVarTableUnitsWithCategoryInArea(aiBrain, varName, category, area)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local numUnits = ScenarioFramework.NumCatUnitsInArea(testCat, ScenarioUtils.AreaToRect(area), aiBrain)
	
	return ScenarioInfo.VarTable[varName] and (numUnits > ScenarioInfo.VarTable[varName])
end

---@param aiBrain AIBrain
---@param numReq number
---@param category EntityCategory
---@param constructionCat EntityCategory
---@return boolean
function HaveGreaterThanUnitsInCategoryBeingBuilt(aiBrain, numReq, category, constructionCat)
    local cat = category
    if type(category) == 'string' then
        cat = ParseEntityCategory(category)
    end

    local consCat = constructionCat
    if consCat and type(consCat) == 'string' then
        consCat = ParseEntityCategory(constructionCat)
    end

    local numUnits
    if consCat then
        numUnits = aiBrain:NumCurrentlyBuilding(cat, cat + categories.CONSTRUCTION + consCat)
    else
        numUnits = aiBrain:NumCurrentlyBuilding(cat, cat + categories.CONSTRUCTION)
    end

    return numUnits > numReq
end

---@param aiBrain AIBrain
---@param numunits number
---@param category EntityCategory
---@return boolean
function HaveLessThanUnitsInCategoryBeingBuilt(aiBrain, numunits, category)
    --DUNCAN - rewritten, credit to Sorian
    if type(category) == 'string' then
        category = ParseEntityCategory(category)
    end

    local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
    local numBuilding = 0
    for unitNum, unit in unitsBuilding do
        if not unit:BeenDestroyed() and unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                numBuilding = numBuilding + 1
            end
        end
        --DUNCAN - added to pick up engineers that havent started building yet... does it work?
        if not unit:BeenDestroyed() and not unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                --LOG('Engi building but not in building state...')
                numBuilding = numBuilding + 1
            end
        end
        if numunits <= numBuilding then
            return false
        end
    end
    return numunits > numBuilding
end

---@param aiBrain AIBrain
---@param greater boolean
---@param numReq number
---@param category EntityCategory
---@param alliance string
---@return boolean
function HaveUnitsWithCategoryAndAlliance(aiBrain, greater, numReq, category, alliance)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    local numUnits = aiBrain:GetNumUnitsAroundPoint(testCat, Vector(0,0,0), 100000, alliance)
	
	return (numUnits > numReq and greater) or (numUnits < numReq and not greater)
end


