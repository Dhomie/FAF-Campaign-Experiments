------------------------------------------------------------------------------
-- File     :  /cdimage/lua/ai/opai/BaseManagerPlatoonThreads.lua
-- Author(s):  Drew Staltman
-- Summary  :  Houses a number of AI threads that are used by the Base Manager
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------------------

local AIUtils = import("/lua/ai/aiutilities.lua")
local AMPlatoonHelperFunctions = import("/lua/editor/amplatoonhelperfunctions.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local ScenarioPlatoonAI = import("/lua/scenarioplatoonai.lua")
local AIBehaviors = import("/lua/ai/aibehaviors.lua")
local SUtils = import("/lua/ai/sorianutilities.lua")
local TriggerFile = import("/lua/scenariotriggers.lua")
local Buff = import("/lua/sim/buff.lua")
local BMBC = import("/lua/editor/basemanagerbuildconditions.lua")
local MIBC = import("/lua/editor/miscbuildconditions.lua")
local UpgradeTemplates = import("/lua/upgradetemplates.lua")

local EngineerBuildDelay = tonumber(ScenarioInfo.Options.EngineerBuildDelay) or 15

-- Upvalued for performance
local TableEmpty = table.empty
local TableInsert = table.insert
local TableRemove = table.remove
local TableGetn = table.getn
local TableRandom = table.random

--- Automatically enables the auto-overcharge option for ACUs
---@param self Platoon
function EnableCDRAutoOvercharge(platoon)
	local Units = platoon:GetPlatoonUnits()
	
	-- Loop through each existing unit (if we received a platoon of multiple units), checks if its an ACU, and enable the auto-overcharge option
	for index, unit in Units do
		if not unit.Dead and unit.SetAutoOvercharge then
			unit:SetAutoOvercharge(true)
		end
	end
end

--- Split the Engineer platoon into single unit platoons
---@param platoon Platoon
function BaseManagerEngineerPlatoonSplit(platoon)
    local aiBrain = platoon:GetBrain()
    local units = platoon:GetPlatoonUnits()
    local baseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        aiBrain:DisbandPlatoon(platoon)
		return
    end
    for _, v in units do
        if not v.Dead then
            -- Make sure current base manager isn't at capacity of engineers
            if EntityCategoryContains(categories.ENGINEER, v) and bManager.EngineerQuantity > bManager.CurrentEngineerCount then
                if bManager.EngineerBuildRateBuff then
                    Buff.ApplyBuff(v, bManager.EngineerBuildRateBuff)
                end

                local engPlat = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(engPlat, {v}, 'Support', 'None')
                engPlat:SetPlatoonData(platoon.PlatoonData)
                v.BaseName = baseName
                engPlat:ForkAIThread(BaseManagerSingleEngineerPlatoon)

                -- If engineer is not a commander or sub-commander, increment number of units working for the base
                -- set up death trigger for the engineer
                if not EntityCategoryContains(categories.COMMAND + categories.SUBCOMMANDER, v) then
                    bManager:AddCurrentEngineer()

                    -- Only add death callback if it hasnt been set yet
                    if not v.Subtracted then
                        TriggerFile.CreateUnitDestroyedTrigger(BaseManagerSingleDestroyed, v)
                    end

                    -- If the base is building engineers, subtract one from the amount being built
                    if bManager:GetEngineersBuilding() > 0 then
                        bManager:SetEngineersBuilding(-1)
                    end
                end
            end
        end
    end
    aiBrain:DisbandPlatoon(platoon)
end

--- NOTE: Only use this for sACUs,
--- Split the sACU platoon into single unit platoons
---@param platoon Platoon
function BaseManagerSupportACUPlatoonSplit(platoon)
    local aiBrain = platoon:GetBrain()
    local units = platoon:GetPlatoonUnits()
    local baseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    if not bManager then
        aiBrain:DisbandPlatoon(platoon)
		return
    end
    for _, v in units do
        if not v.Dead then
            -- Make sure current base manager isn't at capacity of sACUs
            if EntityCategoryContains(categories.SUBCOMMANDER, v) and bManager.SupportACUQuantity > bManager.CurrentSupportACUCount then
                if bManager.EngineerBuildRateBuff then
                    Buff.ApplyBuff(v, bManager.EngineerBuildRateBuff)
                end

                local SACUPlatoon = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(SACUPlatoon, {v}, 'Support', 'None')
                SACUPlatoon:SetPlatoonData(platoon.PlatoonData)
                v.BaseName = baseName
                SACUPlatoon:ForkAIThread(BaseManagerSingleACUPlatoon)

                bManager:AddCurrentSupportACU()

                -- Only add death callback if it hasn't been set yet
                if not v.Subtracted then
                    TriggerFile.CreateUnitDestroyedTrigger(BaseManagerSingleSupportACUDestroyed, v)
                end

                -- If the base is building sACUs, subtract one from the amount being built
                if bManager:GetSupportACUsBuilding() > 0 then
                    bManager:SetSupportACUsBuilding(-1)
                end
            end
        end
    end
    aiBrain:DisbandPlatoon(platoon)
end

--- Death callback when sACUs die to decrease counter
---@param unit Unit
function BaseManagerSingleSupportACUDestroyed(unit)
    if not unit.Subtracted then
        unit.Subtracted = true
        local aiBrain = unit:GetAIBrain()
        local bManager = aiBrain.BaseManagers[unit.BaseName]
        bManager:SubtractCurrentSupportACU()
    end
end

--- Callback function when an engineering unit starts building something
--- If that 'something' is a named unit the Engineer was told to build, then it caches the necessary data on the named unit
--- Also resets the unit name we cached on the Engineer, so if any mishaps happen, the Engineer can just build something else afterwards
--- We handle cases of BuildingUnitName and ConditionalUnitName, the former is for Base Manager structures, the later is for Conditional Builds (ie. experimentals)
--- Handles special case where a guarding Engineer initiates the construction INSTEAD of our primary Engineer
--- Also handles BM upgrades for instant structure upgrading, this is to avoid issues with PBM factory assigning
---@param unit Unit
---@param unitBeingBuilt Unit
function EngineerOnStartBuild(unit, unitBeingBuilt)
	-- Normally the Engineer we issued the build order for starts the initial construction, however if it has guarding Engineers, they might do so instead
	-- We don't queue several build related orders in the campaign enviroment, so if the Engineer that initialized construction is currently guarding another, it's the ONLY order it has right now
	-- If we are guarding something, overwrite the origin unit to that, we don't copy over any data, simply treat this Engineer as the primary one, and reset data on the actual primary Engineer
	local Guardee = unit:GetGuardedUnit()
	if Guardee and not Guardee.Dead then
		unit = Guardee
	end
	
	-- We cached the name of the unit we want to build, and the Engineer's BaseManager, 1st when we ordered the Engineer to build, 2nd when the Engineer's platoon was formed
	local StructureUnitName = unit.BuildingUnitName
	local ExperimentalUnitName = unit.ConditionalBuildUnitName
	local BaseName = unit.BaseName
	local bManager = unit.Brain.BaseManagers[BaseName]
	local armyIndex = unit.Brain:GetArmyIndex()
	
	-- First check if we were told to build a BM structure, if not, check if it's a CB
	if StructureUnitName and bManager then
		-- Cache names to the structure
		unitBeingBuilt.UnitName = StructureUnitName
		unitBeingBuilt.BaseName = BaseName
		
		-- Flag the structure as unfinished so the BM can maintain its construction
		bManager.UnfinishedBuildings[StructureUnitName] = true
		
		-- Update the global UnitNames table so the BM knows the structure exists
		ScenarioInfo.UnitNames[armyIndex][StructureUnitName] = unitBeingBuilt
		
		-- Reset the cached unit name, so a new one can be picked right after
		unit.BuildingUnitName = nil
		
		-- Register callbacks
		if not unitBeingBuilt.AddedCompletionCallback then
			unitBeingBuilt:AddUnitCallback(InitialStructureBuildSuccessful, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedCompletionCallback = true
		end
	elseif ExperimentalUnitName and bManager then
		-- Restore the index saved in the CanConditionalBuild call
		local buildIndex = bManager.ConditionalBuildData.Index
		local selectedBuild = bManager.ConditionalBuildTable[buildIndex]

		-- Store the unit
        bManager.ConditionalBuildData.Unit = unitBeingBuilt

        -- If we're supposed to keep a certain number of these guys in the field, store the info on him so he can reinsert himself in the conditional build table when he bites it.
        if selectedBuild.data.KeepAlive then
            unitBeingBuilt.KeepAlive = true
            unitBeingBuilt.ConditionalBuild = selectedBuild
            unitBeingBuilt.ConditionalBuildData = bManager.ConditionalBuildData

            -- Register rebuild callback
            TriggerFile.CreateUnitDestroyedTrigger(ConditionalBuildDied, unitBeingBuilt)
        end

        -- Cache names to the unit
		unitBeingBuilt.UnitName = ExperimentalUnitName
        unitBeingBuilt.BaseName = BaseName

        -- Set variables so other Engineers can see what's going on
        bManager.ConditionalBuildData.IsInitiated = false
        bManager.ConditionalBuildData.IsBuilding = true
		
		-- Reset the cached unit name, so a new one can be picked right after
		unit.ConditionalBuildUnitName = nil
		
		-- Register callbacks
		if not unitBeingBuilt.AddedCompletionCallback then
			unitBeingBuilt:AddUnitCallback(ConditionalBuildSuccessful, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedCompletionCallback = true
		end
	end
end

--- Callback function when an engineering unit failed to build something, this is called in several cases
--- Resets the unit name we assigned to the Engineer, so in case it's still alive, it can start building something else
---@param unit Unit
function EngineerOnFailedToBuild(unit)
	unit.ConditionalBuildUnitName = nil
	unit.BuildingUnitName = nil
end

--- Callback function when a structure is initially finished building
--- Marks the unit as finished for the unit's BaseManager, so Engineers won't try to finish it (infinite loop of repair orders on a full health unit), and decrements the amount of times it can be rebuilt
---@param unit Unit
function InitialStructureBuildSuccessful(unit)
	local aiBrain = unit.Brain
	local bManager = aiBrain.BaseManagers[unit.BaseName]
	
	if bManager then
		local StructureName = unit.UnitName
		
		if bManager.UnfinishedBuildings[StructureName] then
			bManager.UnfinishedBuildings[StructureName] = nil
			bManager:DecrementUnitBuildCounter(StructureName)
		end
		
		local factionIndex = aiBrain:GetFactionIndex()
		local upgradeID = aiBrain:FindUpgradeBP(unit.UnitId, UpgradeTemplates.StructureUpgradeTemplates[factionIndex])
		
		-- Check if our structure can even upgrade to begin with
		if upgradeID then
			-- Check if the BM is supposed to upgrade this structure
			for index, structure in bManager.UpgradeTable do
				-- If the names match, and the IDs don't, we need to upgrade
				if StructureName == structure.UnitName and unit.UnitId ~= structure.FinalUnit and not unit.SetToUpgrade then
					UpgradeBaseManagerStructure(unit, upgradeID)
				end
			end
		end
	end
end

--- Function that will upgrade factories, radar, etc. to next level
---@param unit Unit
function UpgradeBaseManagerStructure(unit, upgradeID)
	-- Add callback when the structure starts building something
	if not unit.AddedUpgradeCallback then
		unit:AddOnStartBuildCallback(StructureOnStartBuild)
		unit.AddedUpgradeCallback = true
	end

    IssueUpgrade({unit}, upgradeID)
	unit.SetToUpgrade = true
end

--- Callback function when a structure marked for needing an upgrade starts building something
--- If that 'something' is the upgrade itself, create a callback for the upgrade
---@param unit Unit
---@param unitBeingBuilt Unit being constructed
function StructureOnStartBuild(unit, unitBeingBuilt)
	-- If we are in the upgrading state, then it's the upgrade we want under normal circumstances.
	-- We don't use different upgrades paths for coop, only that of the original SCFA (no Support Factory upgrade paths whatsoever)
	-- If you decide to mess around with AI armies in cheat mode, and order a newly added upgrade path instead anyway, then any mishaps happening afterwards is on you!
	if unit:IsUnitState('Upgrading') then
		unitBeingBuilt.UnitName = unit.UnitName
		unitBeingBuilt.BaseName = unit.BaseName

		-- Add callback when the upgrade is finished
		if not unitBeingBuilt.AddedFinishedCallback then
			unitBeingBuilt:AddUnitCallback(UpgradeOnStopBeingBuilt, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedFinishedCallback = true
		end
	end
end

--- Callback function when a structure upgrade is finished building
--- Updates the ScenarioInfo.UnitNames table with the new unit, and upgrades further if needed
---@param unit Unit
function UpgradeOnStopBeingBuilt(unit)
	local aiBrain = unit.Brain
	local bManager = aiBrain.BaseManagers[unit.BaseName]
	if bManager then
		local armyIndex = aiBrain:GetArmyIndex()
		ScenarioInfo.UnitNames[armyIndex][unit.UnitName] = unit
		
		local factionIndex = aiBrain:GetFactionIndex()
		local upgradeID = aiBrain:FindUpgradeBP(unit.UnitId, UpgradeTemplates.StructureUpgradeTemplates[factionIndex])
		
		-- Check if our structure can even upgrade to begin with
		if upgradeID then
			-- Check if the BM is supposed to upgrade this structure further
			for index, structure in bManager.UpgradeTable do
				-- If the names match, and the IDs don't, we need to upgrade
				if unit.UnitName == structure.UnitName and unit.UnitId ~= structure.FinalUnit and not unit.SetToUpgrade then
					UpgradeBaseManagerStructure(unit, upgradeID)
				end
			end
		end
	end
end

--- Main function for Base Manager Engineers
---@param platoon Platoon
function BaseManagerSingleEngineerPlatoon(platoon)
    platoon.PlatoonData.DontDisband = true

    local aiBrain = platoon:GetBrain()
	local unit = platoon:GetPlatoonUnits()[1]

    local baseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    unit.BaseName = baseName
	
	-- Add build callbacks for these Engineers
	if not unit.AddedBuildCallback then
		-- The universal function doesn't work for OnStartBuild, unit.unitBeingBuilt is only accessable after the DoUnitCallback has been executed
		unit:AddOnStartBuildCallback(EngineerOnStartBuild)
		unit:AddUnitCallback(EngineerOnFailedToBuild, "OnFailedToBuild")
		unit.AddedBuildCallback = true
	end
	
    while aiBrain:PlatoonExists(platoon) do
        if BMBC.BaseEngineersEnabled(aiBrain, baseName) then
            -- Move to expansion base
            if BMBC.ExpansionBasesEnabled(aiBrain, baseName) and BMBC.ExpansionBasesNeedEngineers(aiBrain, baseName) then
                ExpansionEngineer(platoon)
				
			-- Assist a conditional builder under construction
            elseif bManager.ConditionalBuildData.Unit and not bManager.ConditionalBuildData.Unit.Dead and bManager.ConditionalBuildData.NeedsMoreBuilders() then
                AssistConditionalBuild(platoon)

            -- If we can do a conditional build here, then do it
            elseif CanConditionalBuild(platoon) then
                DoConditionalBuild(platoon)

            -- Try to build buildings
            elseif BMBC.NeedAnyStructure(aiBrain, baseName) and bManager:GetConstructionEngineerCount() < bManager:GetConstructionEngineerMaximum() then
                bManager:AddConstructionEngineer(unit)
                TriggerFile.CreateUnitDestroyedTrigger(ConstructionUnitDeath, unit)
                BaseManagerEngineerThread(platoon)
                bManager:RemoveConstructionEngineer(unit)

            -- Permanent Assist - Assist factories until the unit dies
            elseif bManager:NeedPermanentFactoryAssist() then
                bManager:IncrementPermanentAssisting()
                PermanentFactoryAssist(platoon)

            -- Finish unfinished buildings
            elseif BMBC.UnfinishedBuildingsCheck(aiBrain, baseName) then
                BuildUnfinishedStructures(platoon)

            -- Try to assist
            elseif BMBC.CategoriesBeingBuilt(aiBrain, baseName, {'MOBILE LAND', 'ALLUNITS' }) or(bManager:ConstructionNeedsAssister()) then
                BaseManagerAssistThread(platoon)

            -- Try to patrol
            elseif BMBC.BasePatrollingEnabled(aiBrain, baseName) and not unit:IsUnitState('Patrolling') then
                BaseManagerEngineerPatrol(platoon)
            end
        end
        WaitTicks(100)
    end
end

--- Main function for Base Manager Command Units
---@param platoon Platoon
function BaseManagerSingleACUPlatoon(platoon)
    platoon.PlatoonData.DontDisband = true

    local aiBrain = platoon:GetBrain()
	local unit = platoon:GetPlatoonUnits()[1]
	local UpgradeName

    local baseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    unit.BaseName = baseName
	
	-- Determine the type of unit
    local unitType = false
    if EntityCategoryContains(categories.COMMAND, unit) then
        unitType = 'DefaultACU'
    elseif EntityCategoryContains(categories.SUBCOMMANDER, unit) then
        unitType = 'DefaultSACU'
    end
	
	-- Cache the platoon data on the unit in case other functions make use of it
	if platoon.PlatoonData and not unit.CDRData then
        unit.CDRData = platoon.PlatoonData
    end
	
	-- Add build callbacks for these Engineers
	if not unit.AddedBuildCallback then
		-- The universal function doesn't work for OnStartBuild, unit.unitBeingBuilt is only accessable after the DoUnitCallback has been executed
		unit:AddOnStartBuildCallback(EngineerOnStartBuild)
		unit:AddUnitCallback(EngineerOnFailedToBuild, "OnFailedToBuild")
		unit.AddedBuildCallback = true
	end
	
    while aiBrain:PlatoonExists(platoon) do
        if BMBC.BaseEngineersEnabled(aiBrain, baseName) then
			UpgradeName = bManager:UnitNeedsUpgrade(unit, unitType)
			-- Do any set upgrades first and foremost
			if UpgradeName then
				UnitUpgradeThread(platoon, UpgradeName)

            -- Try to build buildings
            elseif BMBC.NeedAnyStructure(aiBrain, baseName) and bManager:GetConstructionEngineerCount() < bManager:GetConstructionEngineerMaximum() then
                bManager:AddConstructionEngineer(unit)
                TriggerFile.CreateUnitDestroyedTrigger(ConstructionUnitDeath, unit)
                BaseManagerEngineerThread(platoon)
                bManager:RemoveConstructionEngineer(unit)

            -- Finish unfinished buildings
            elseif BMBC.UnfinishedBuildingsCheck(aiBrain, baseName) then
                BuildUnfinishedStructures(platoon)

            -- Try to assist
            elseif BMBC.CategoriesBeingBuilt(aiBrain, baseName, {'MOBILE LAND', 'ALLUNITS' }) or(bManager:ConstructionNeedsAssister()) then
                BaseManagerAssistThread(platoon)

            -- Try to patrol
            elseif BMBC.BasePatrollingEnabled(aiBrain, baseName) and not unit:IsUnitState('Patrolling') then
                BaseManagerEngineerPatrol(platoon)
            end
        end
        WaitTicks(100)
    end
end

--- If there is a conditional build that this engineer can tackle, then this function will return true
--- and the base managers ConditionalBuildData.Index will have the index of ConditionalBuildTable stored in it
---@param singleEngineerPlatoon Platoon
---@return boolean
function CanConditionalBuild(singleEngineerPlatoon)
    local aiBrain = singleEngineerPlatoon:GetBrain()
	local baseName = singleEngineerPlatoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    local engineer = singleEngineerPlatoon:GetPlatoonUnits()[1]
    engineer.BaseName = baseName
	
    -- Is there a build in progress?
    if bManager.ConditionalBuildData.IsBuilding then
        -- If there's a build in progress but the unit is dead, reset the variables.
        if bManager.ConditionalBuildData.Unit:BeenDestroyed() then
            local selectedBuild = bManager.ConditionalBuildTable[bManager.ConditionalBuildData.Index]
            -- If we're not supposed to retry, then remove from the conditional build list
            if not selectedBuild.data.Retry then
                TableRemove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
            end
            bManager.ConditionalBuildData.Reset()
        else
            return false
        end
    end

    -- Is there a build being initiated (unit is moving to start the build)?
    if bManager.ConditionalBuildData.IsInitiated then
        -- Is the initiator is still alive? (If the initiator is dead it means he died before the build was started and we can ignore the IsInitiated flag)
        if bManager.ConditionalBuildData.MainBuilder and not bManager.ConditionalBuildData.MainBuilder.Dead then
            return false
        end
    end
	
	-- Are there no conditional builds?
    if TableEmpty(bManager.ConditionalBuildTable) then
        return false
    end

    -- What we should build from the conditional build list.
    local buildIndex = 0

    -- Go through the list of conditional builds and see if any of the conditions are met
    table.foreachi(bManager.ConditionalBuildTable, function(index, build)
        if buildIndex ~= 0 then return end

        -- Check if this engineer can build this particular structure
        if type(build.name) == 'table' then --table of units to build at random
            for i, unitName in build.name do
                local unitToBuild = ScenarioUtils.FindUnit(unitName, Scenario.Armies[aiBrain.Name].Units)
                if not unitToBuild then error('*CONDITIONAL BUILD ERROR: No unit exists with name ' ..unitName) end
                if not engineer:CanBuild(unitToBuild.type) then return end
            end
        else
            local unitToBuild = ScenarioUtils.FindUnit(build.name, Scenario.Armies[aiBrain.Name].Units)
            if not unitToBuild then error('*CONDITIONAL BUILD ERROR: No unit exists with name ' ..build.name) end
            if not engineer:CanBuild(unitToBuild.type) then return end
        end

        local Conditions = build.data.BuildCondition or {}

        -- If this particular conditional build has a post-death timer lock on it.
        if ScenarioInfo.ConditionalBuildLocks and ScenarioInfo.ConditionalBuildLocks[build.name] then
            return
        end

        -- If Conditions is a new-style predicate condition function...
        if type(Conditions) == "function" then
            if not Conditions() then return end

            -- Condition is true.
            buildIndex = index

        -- If Conditions is an old-style condition table...
        else
            local conditionsMet = true
            table.foreachi(Conditions, function(idx, cond)
                if not conditionsMet then return end

                if not import(cond[1])[cond[2]](aiBrain, unpack(cond[3])) then
                    conditionsMet = false
                    return
                end
            end)

            if not conditionsMet then return end

            -- Condition is true.
            buildIndex = index

        end
    end)

    -- Bail out if we didnt find a conditional unit
    if buildIndex == 0 then return false end

    -- Save index for use
    bManager.ConditionalBuildData.Index = buildIndex

    return true
end

---@param conditionalUnit any
function ConditionalBuildDied(conditionalUnit)
	local aiBrain = conditionalUnit.Brain
    local bManager = aiBrain.BaseManagers[conditionalUnit.BaseName]
    local selectedBuild = conditionalUnit.ConditionalBuild
	
    -- Reinsert the conditional build (for one of these units)
    TableInsert(bManager.ConditionalBuildTable, {
        name = selectedBuild.name,
        data =  {
            MaxAssist = selectedBuild.data.MaxAssist,
            BuildCondition = selectedBuild.data.BuildCondition,
            PlatoonAIFunction = selectedBuild.data.PlatoonAIFunction,
            PlatoonData = selectedBuild.data.PlatoonData,
            FormCallbacks = selectedBuild.data.FormCallbacks,
            Retry = selectedBuild.data.Retry,
            KeepAlive = true,
            Amount = 1,
            WaitSecondsAfterDeath = selectedBuild.data.WaitSecondsAfterDeath,
        },
    })
end

---@param conditionalUnit any
function ConditionalBuildSuccessful(conditionalUnit)
    local aiBrain = conditionalUnit.Brain
    local bManager = aiBrain.BaseManagers[conditionalUnit.BaseName]
    local selectedBuild = bManager.ConditionalBuildTable[bManager.ConditionalBuildData.Index]

    -- Assign to a new platoon, along with the PlatoonData
    local newPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(newPlatoon, {conditionalUnit}, 'Attack', 'None')
    newPlatoon:StopAI()
    newPlatoon:SetPlatoonData(selectedBuild.data.PlatoonData)
	
	-- First run any FormCallbacks, as these should only be utility/auxiliary functions that do stuff like enable stealth/jamming
	-- The actual platoon threads could reassign the ConditionalUnit into an entirely new platoon (ie. "AddExperimentalToPlatoon" used in several missions to form platoons of several experimentals)
	-- In which case the FormCallbacks would not be called in time IF they were to be run AFTER the main platoon threads
	if selectedBuild.data.FormCallbacks then
        for _, callback in selectedBuild.data.FormCallbacks do
            if type(callback) == "function" then
                newPlatoon:ForkThread(callback)
            else
                newPlatoon:ForkThread(import(callback[1])[callback[2]])
            end
        end
    end
	
	-- Run the actual platoon thread AFTER the FormCallbacks have been finished
    if selectedBuild.data.PlatoonAIFunction then
		if type (selectedBuild.data.PlatoonAIFunction) == "function" then
			newPlatoon:ForkAIThread(selectedBuild.data.PlatoonAIFunction)
		else
			newPlatoon:ForkAIThread(import(selectedBuild.data.PlatoonAIFunction[1])[selectedBuild.data.PlatoonAIFunction[2]])
		end
    end	

    -- Set up a death wait thing for it to rebuild
    if bManager.ConditionalBuildData.WaitSecondsAfterDeath then
        -- If were supposed to wait a certain amount of time before building the unit again, handle that here.
        ScenarioInfo.ConditionalBuildLocks = ScenarioInfo.ConditionalBuildLocks or {}
        ScenarioInfo.ConditionalBuildLocks[selectedBuild.name] = true

        local waitTime = bManager.ConditionalBuildData.WaitSecondsAfterDeath

        -- Register death callback
        TriggerFile.CreateUnitDestroyedTrigger(function(unit)
            ForkThread(function()
                WaitSeconds(waitTime)
                ScenarioInfo.ConditionalBuildLocks[selectedBuild.name] = false
            end)
        end,
        conditionalUnit
        )
    end

    -- Remove from the conditional build list if were not supposed to build any more
    if not selectedBuild.data.Amount then
        TableRemove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
    elseif selectedBuild.data.Amount > 0 then
        -- Decrement the amount left to build
        selectedBuild.data.Amount = selectedBuild.data.Amount - 1

        -- If none are left to build, remove from the build table
        if selectedBuild.data.Amount == 0 then
            TableRemove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
        end
    end

    -- Reset conditional build variables
    bManager.ConditionalBuildData.Reset()
end

--- Called if there is a conditional build in progress that can be assisted
---@param singleEngineerPlatoon Platoon
function AssistConditionalBuild(singleEngineerPlatoon)
    local aiBrain = singleEngineerPlatoon:GetBrain()
    local baseName = singleEngineerPlatoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    local engineer = singleEngineerPlatoon:GetPlatoonUnits()[1]
    engineer.BaseName = baseName

    -- Restore the index saved in the CanConditionalBuild call
    local buildIndex = bManager.ConditionalBuildData.Index

    -- Register death callback
    TriggerFile.CreateUnitDestroyedTrigger(ConditionalBuilderDead, engineer)

    -- Increment number of units assisting
    bManager.ConditionalBuildData.IncrementAssisting()

    -- Give orders to repair the unit
    IssueToUnitClearCommands(engineer)
    IssueRepair({engineer}, bManager.ConditionalBuildData.Unit)

    -- Super loop
    while aiBrain:PlatoonExists(singleEngineerPlatoon) do
        WaitTicks(30)

        if engineer:IsIdleState() then
            break
        end
    end

    IssueToUnitClearCommands(engineer)
    TriggerFile.RemoveUnitTrigger(engineer, ConditionalBuilderDead)
end

--- Called if there is a conditional build available to start
---@param singleEngineerPlatoon Platoon
function DoConditionalBuild(singleEngineerPlatoon)
    local aiBrain = singleEngineerPlatoon:GetBrain()
    local baseName = singleEngineerPlatoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    local engineer = singleEngineerPlatoon:GetPlatoonUnits()[1]
    engineer.BaseName = baseName

    -- Restore the index saved in the CanConditionalBuild call
    local buildIndex = bManager.ConditionalBuildData.Index
    local selectedBuild = bManager.ConditionalBuildTable[buildIndex]

    -- Get unit plans from the scenario
    local unitToBuild, unitName
    if type(selectedBuild.name) == 'table' then
		unitName = TableRandom(selectedBuild.name)
        unitToBuild = ScenarioUtils.FindUnit(unitName, Scenario.Armies[aiBrain.Name].Units)
        if not unitToBuild then error('Unit with name "' .. unitName .. '" could not be found for conditional building.') return end
    else
		unitName = selectedBuild.name
        unitToBuild = ScenarioUtils.FindUnit(unitName, Scenario.Armies[aiBrain.Name].Units)
        if not unitToBuild then error('Unit with name "' .. unitName .. '" could not be found for conditional building.') return end
    end

    -- Initialize variables
    bManager.ConditionalBuildData.MainBuilder = engineer
    bManager.ConditionalBuildData.NumAssisting = 1
    bManager.ConditionalBuildData.MaxAssisting = selectedBuild.data.MaxAssist or 1
    bManager.ConditionalBuildData.Unit = false
    bManager.ConditionalBuildData.IsInitiated = true  -- Prevents other engineers from trying to start their own builds
    bManager.ConditionalBuildData.IsBuilding = false
    bManager.ConditionalBuildData.WaitSecondsAfterDeath = selectedBuild.data.WaitSecondsAfterDeath or false

    -- Register death callback
    TriggerFile.CreateUnitDestroyedTrigger(ConditionalBuilderDead, engineer)

    -- Issue build orders
    IssueToUnitClearCommands(engineer)
    aiBrain:BuildStructure(engineer, unitToBuild.type, {unitToBuild.Position[1], unitToBuild.Position[3], 0})
	engineer.ConditionalBuildUnitName = unitName

    -- Enter build monitoring loop, the bulk of the data assigning logic is handled in "EngineerOnStartBuild()"
	repeat
		WaitTicks(30)
		
		if not aiBrain:PlatoonExists(singleEngineerPlatoon) then
            return
        end
    until engineer:IsIdleState()
	
    IssueToUnitClearCommands(engineer)
    TriggerFile.RemoveUnitTrigger(engineer, ConditionalBuilderDead)
end

---@param platoon Platoon
function PermanentFactoryAssist(platoon)
    local aiBrain = platoon:GetBrain()
    local bManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]
    local assistFac = false
    local unit = platoon:GetPlatoonUnits()[1]

    TriggerFile.CreateUnitDestroyedTrigger(PermanentAssisterDead, unit)
    while aiBrain:PlatoonExists(platoon) do
        -- Get all factories in the base manager
        local facs = bManager:GetAllBaseFactories()

        -- Determine the number of guards on all factories
        local high, highFac, low, lowFac
        for k, v in facs do
            if not v.Dead then
                local guards = v:GetGuards()
                local numGuards = 0
                for gNum, gUnit in guards do
                    -- Make sure this guy is a permanent assister and not a transient assister
                    if not gUnit.Dead and not EntityCategoryContains(categories.FACTORY, gUnit) and bManager.PermanentAssisters[gUnit] then
                        numGuards = numGuards + 1
                    end
                end
                if not high or numGuards > high then
                    high = numGuards
                    highFac = v
                end
                if not low or numGuards < low then
                    low = numGuards
                    lowFac = v
                end
            end
        end
        -- If we don't have a factory or our factory is dead, or the disparity between factories is more than 1, reorganize engineers.
        if ((not assistFac or assistFac.Dead) and lowFac) or (high and low and lowFac and high > low + 1 and highFac == unit:GetGuardedUnit()) then
            assistFac = lowFac
            platoon:Stop()
            IssueGuard({unit}, lowFac)

            -- Add to the list of units that are permanently assisting in this base manager
            bManager.PermanentAssisters[unit] = true
        end
        WaitTicks(150)
    end
end

--- Assist units that are building structures and units
--- Excludes external factories by default, because Engineers will follow Carriers/Experimentals that are otherwise meant to attack something AND build at the same time
---@param platoon Platoon
function BaseManagerAssistThread(platoon)
    platoon:Stop()

    local unit = platoon:GetPlatoonUnits()[1]
    local aiBrain = platoon:GetBrain()
	local BaseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[BaseName]
	local bManagerPos = bManager.Position
    local assistData = platoon.PlatoonData.Assist
    local assistee = false
    local assistingBool = false
    --local beingBuiltCategories = assistData.BeingBuiltCategories or {'MASSPRODUCTION', 'ENERGYPRODUCTION', 'FACTORY', 'EXPERIMENTAL', 'DEFENSE', 'MOBILE LAND', 'ALLUNITS'}
	local beingBuiltCategories = assistData.BeingBuiltCategories or {'MASSPRODUCTION', 'ENERGYPRODUCTION', 'FACTORY', 'EXPERIMENTAL', 'DEFENSE', 'MOBILE', 'ALLUNITS'}

    local assistRange = assistData.AssistRange or bManager.Radius
    local counter = 0
	local waitTime = 50
    while counter < (assistData.Time or 150) and aiBrain:PlatoonExists(platoon) do
		local GuardedUnit = unit:GetGuardedUnit()
        -- If the engineer is assisting a construction unit that is building, or we don't need assisters, or we are a construction unit, break out and do nothing
        if not GuardedUnit or (not GuardedUnit:IsUnitState('Building') and not bManager:ConstructionNeedsAssister() and not bManager:IsConstructionUnit(GuardedUnit)) then
            if bManager:ConstructionNeedsAssister() then
                local consUnits = bManager.ConstructionEngineers
                local lowNum = 100000
                local highNum = 0
                local currLow = false
                for _, v in consUnits do
                    local guardNum = TableGetn(v:GetGuards())
                    if not v.Dead and guardNum < lowNum then
                        currLow = v
                        lowNum = TableGetn(v:GetGuards())
                    end
                    if guardNum > highNum then
                        highNum = guardNum
                    end
                end
                if GuardedUnit then
                    if GuardedUnit.Dead or EntityCategoryContains(categories.FACTORY - categories.EXTERNALFACTORYUNIT, GuardedUnit) or
                            highNum > lowNum + 1 then
                        assistee = currLow
                    end
                else
                    assistee = currLow
                end
            end
            -- Find valid unit to assist
            -- Get all units building stuff - TODO get list with point and radius; get list of units with state
            if not assistee then
				local unitsBuilding = BMBC.GetOwnUnitsAroundPosition(aiBrain, categories.CONSTRUCTION, bManagerPos, assistRange)
                -- Iterate through being built categories
                for catNum, buildeeCat in beingBuiltCategories do
                    local buildCat = ParseEntityCategory(buildeeCat)
                    for unitNum, constructionUnit in unitsBuilding do
                        -- Check if the unit is actually building something
                        if not constructionUnit.Dead and constructionUnit:IsUnitState('Building') then
                            -- Check to make sure unit being built is of proper category
                            local buildingUnit = constructionUnit.UnitBeingBuilt
                            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(buildCat, buildingUnit) then
                                -- If the unit building is a factory make sure its in the right PBM Location Type
                                if not EntityCategoryContains(categories.FACTORY, constructionUnit) or aiBrain:PBMFactoryLocationCheck(constructionUnit, BaseName) then
                                    assistee = constructionUnit
                                    break
                                end
                            end
                        end
                    end
                    -- If we have found a valid unit to assist break off
                    if assistee then
                        break
                    end
                end
            end

            -- If the unit to be assisted is a factory, assist whatever it is assisting or is assisting it
            -- Makes sure all factories have someone helping out to load balance better
            if assistee and not assistee.Dead and EntityCategoryContains(categories.FACTORY - categories.EXTERNALFACTORYUNIT, assistee) then
                platoon:Stop()
                local guardee = assistee:GetGuardedUnit()
                if guardee and not guardee.Dead and EntityCategoryContains(categories.FACTORY - categories.EXTERNALFACTORYUNIT, guardee) then
                    local factories = AIUtils.AIReturnAssistingFactories(guardee)
                    TableInsert(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoon:GetPlatoonUnits(), factories)
                    assistingBool = true
                elseif not TableEmpty(assistee:GetGuards()) then
                    local factories = AIUtils.AIReturnAssistingFactories(assistee)
                    TableInsert(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoon:GetPlatoonUnits(), factories)
                    assistingBool = true
                end
            end
            if assistee and not assistee.Dead then
                if not assistingBool then
                    platoon:Stop()
                    IssueGuard(platoon:GetPlatoonUnits(), assistee)
                end
            end
        end
        WaitTicks(waitTime)

        counter = counter + waitTime
    end
end

--- Engineer build structures
---@param platoon Platoon
function BaseManagerEngineerThread(platoon)
    platoon:Stop()

    local aiBrain = platoon:GetBrain()
	local baseManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]
	
	-- Handle case of invalid data
	if not platoon.PlatoonData.BaseName or not baseManager then
        error('*AI DEBUG: Missing Base Name or invalid base name for base manager engineer thread', 2)
    end
	
	-- Grab the Engineer
    local Engineer
	
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and EntityCategoryContains(categories.CONSTRUCTION, v) then
            if not Engineer then
                Engineer = v
            else
                IssueToUnitClearCommands(v)
                IssueGuard({v}, Engineer)
            end
        end
    end
	
	-- If no Engineer was found, return
    if not Engineer or Engineer.Dead then
        aiBrain:DisbandPlatoon(platoon)
        return
    end

    local StructurePriorities = platoon.PlatoonData.StructurePriorities or 
	{
		'T3Resource', 'T2Resource', 'T1Resource', 'T3EnergyProduction', 'T2EnergyProduction', 'T1EnergyProduction', 'T3MassCreation',
		'T2EngineerSupport', 'T3SupportLandFactory', 'T3SupportAirFactory', 'T3SupportSeaFactory', 'T2SupportLandFactory', 'T2SupportAirFactory', 'T2SupportSeaFactory', 'T1LandFactory', 'T1AirFactory', 'T1SeaFactory',
		'T4LandExperimental1', 'T4LandExperimental2', 'T4AirExperimental1', 'T4SeaExperimental1',
		'T3ShieldDefense', 'T2ShieldDefense', 'T3StrategicMissileDefense', 'T3Radar', 'T2Radar', 'T1Radar',
        'T3AADefense', 'T3GroundDefense', 'T3NavalDefense', 'T2AADefense', 'T2MissileDefense', 'T2GroundDefense', 'T2NavalDefense', 'ALLUNITS'
	}

    local StructureFound, UnitName
	
	-- The idea is to search for a structure (or any unit, but 99% it's a structure) based on the priorities set above that needs to be built
	-- If we found one, and the build order could be issued (see 'BuildBaseManagerStructure()' for that), we wait until our engineer finishes its task, then check for the next structure
	-- The original iteration uses the same dual 'for' loop, however if a structure of a higher priority got destroyed, the engineer would ignore that until all remaining categories were exhausted
	-- In this case we check through the priorities every single time
	-- Ie. our engineer is building walls, and a T3 resource structure is destroyed during that -> the engineer will rebuild said resource structure, and return to finishing the rest of the walls
	while aiBrain:PlatoonExists(platoon) do
		-- Assume we found no structure at the start of each loop
		StructureFound = false
		
		-- Loop through each build group
		for index, levelData in baseManager.LevelNames do
			-- Loop through each priority category if the current build group has a higher build priority than 0
			if levelData.Priority > 0 then
				for k, v in StructurePriorities do
					local UnitType = false
					if v ~= 'ALLUNITS' then
						UnitType = v
					end
					
					-- Check each structure
					StructureFound, UnitName = BuildBaseManagerStructure(aiBrain, Engineer, baseManager, levelData.Name, UnitType, platoon)
					if StructureFound and UnitName then
						Engineer.BuildingUnitName = UnitName
						-- Break out, and do so again for the other 'for' loop
						break
					end
				end
			end
			
			if StructureFound and UnitName then
				break
			end
		end
		
		-- We've went through the structure list, wait until the engineer is idle or dead, 
		-- We gotta wait at least once under any circumstances, so I'm not using a "while" loop here, because this function can freeze the sim if say, an T1 Aeon Bomber stuns our engineer unit
		repeat
			WaitTicks(EngineerBuildDelay)
			
			if not aiBrain:PlatoonExists(platoon) then
                return
            end
        until Engineer.Dead or Engineer:IsIdleState()
		
		-- Break out if we couldn't find a structure to build
		if not StructureFound then
			break
		end
	end
	
	platoon:MoveToLocation(aiBrain.BaseManagers[platoon.PlatoonData.BaseName]:GetPosition(), false)
end

--- Guts of the build thing
---@param aiBrain AIBrain
---@param eng Unit
---@param baseManager BaseManager
---@param levelName string
---@param buildingType string
---@param platoon Platoon
---@return boolean
---@return boolean
function BuildBaseManagerStructure(aiBrain, eng, baseManager, levelName, buildingType, platoon)
    local buildTemplate = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].Template
    local buildList = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].List
	
    if not buildTemplate or not buildList or not aiBrain:PlatoonExists(platoon) then
        return false
    end

    local namesTable = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].UnitNames
    local buildCounter = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].BuildCounter
    for k, v in buildTemplate do
        -- Check if type (ex. T1AirFactory) is correct
        if (not buildingType or buildingType == 'ALLUNITS' or buildingType == v[1][1]) and baseManager:CheckStructureBuildable(v[1][1]) then
            local category
            for catName, catData in buildList do
                if catData.StructureType == v[1][1] then
                    category = catData.StructureCategory
                    break
                end
            end
            if category and eng:CanBuild(category) then
                local engineerPos = eng:GetPosition()
                local closest = nil
                -- Iterate through build locations
                for num, location in v do
                    -- Check if it can be built and then build
					-- The coordinates are as the following: {X, Z, 0}, where 0 is meant to be the orientation of the structure (set to 0 due to inconsistent behaviour, no Y (height) coordinates are saved in the template!
                    if num > 1 and aiBrain:CanBuildStructureAt(category, {location[1], 0, location[2]}) and baseManager:CheckUnitBuildCounter(location, buildCounter) then
                        if not closest or (VDist2(location[1], location[2], engineerPos[1], engineerPos[3]) < VDist2(closest[1], closest[2], engineerPos[1], engineerPos[3])) then
                            closest = location
                        end
                    end
                end

                if closest then
					-- We no longer save the 3rd element (orientation) in the BM, because it's ALWAYS 0, so it's set here instead
					closest[3] = 0
                    -- Removed transport call as the pathing check was creating problems with base manager rebuilding
                    -- TODO: develop system where base managers more easily rebuild in far away or hard to reach locations
                    -- and TransportUnitsToLocation(platoon, {closest[1], 0, closest[2]}) then
                    IssueToUnitClearCommands(eng)
                    aiBrain:BuildStructure(eng, category, closest, false)

                    local unitName = nil
                    if namesTable[closest[1]][closest[2]] then
                        unitName = namesTable[closest[1]][closest[2]]
                    end

                    return true, unitName
                end
            end
        end
    end
    return false
end

--- Assigns the units of the given platoon into new single unit platoons, and sets the 'BaseManagerTMLAI' as their platoon AI function
--- Also copies over the platoon data, which we require to determine if the unit's BaseManager is allowed to use the TML
---@param platoon Platoon
function BaseManagerTMLPlatoon(platoon)
    local aiBrain = platoon:GetBrain()
    local TMLs = platoon:GetPlatoonUnits()
	
	if not aiBrain.BaseManagers[platoon.PlatoonData.BaseName] then
        aiBrain:DisbandPlatoon(platoon)
    end
	
	for _, launcher in TMLs do
		if not launcher.Dead then
			local launcherPlatoon = aiBrain:MakePlatoon('', '')
            aiBrain:AssignUnitsToPlatoon(launcherPlatoon, {launcher}, 'Attack', 'None')
			launcherPlatoon:SetPlatoonData(platoon.PlatoonData)
            launcherPlatoon:ForkAIThread(BaseManagerTMLAI)
		end
	end

	aiBrain:DisbandPlatoon(platoon)
end

---@param platoon Platoon
function BaseManagerTMLAI(platoon)
    local aiBrain = platoon:GetBrain()
	local baseName = platoon.PlatoonData.BaseName
    local unit = platoon:GetPlatoonUnits()[1]

    if not unit then return end

    platoon:Stop()
	local maxRadius = unit.Blueprint.Weapon[1].MaxRadius
	local unitPosition = unit:GetPosition()

    local simpleTargetting = true
    if ScenarioInfo.Options.Difficulty == 3 then
        simpleTargetting = false
    end

    unit:SetAutoMode(true)

    platoon:SetPrioritizedTargetList('Attack', {
        categories.COMMAND,
        categories.EXPERIMENTAL,
        categories.ENERGYPRODUCTION,
        categories.STRUCTURE,
        categories.TECH3 * categories.MOBILE,
		categories.TECH2 * categories.MOBILE
		}
	)

    while aiBrain:PlatoonExists(platoon) do
        if BMBC.TMLsEnabled(aiBrain, baseName) then
            local target = nil
            while unit:GetTacticalSiloAmmoCount() < 1 or not target do
				target = target or platoon:FindPrioritizedUnit('Attack', 'Enemy', true, unitPosition, maxRadius)
				
				if target and unit:GetTacticalSiloAmmoCount() >= 1 then
					break
				end
				
				WaitSeconds(5)
				
				if not aiBrain:PlatoonExists(platoon) then
                    return
                end
            end
            if not target.Dead then
                if EntityCategoryContains(categories.STRUCTURE, target) or simpleTargetting then
                    IssueTactical({unit}, target)
                else
                    local targPos = SUtils.LeadTarget(platoon, target)
                    if targPos then
                        IssueTactical({unit}, targPos)
                    end
                end
            end
        end
        WaitSeconds(5)
    end
end

--- Assigns the units of the given platoon into new single unit platoons, and sets the 'BaseManagerNukeAI' as their platoon AI function
--- Also copies over the platoon data, which we require to determine if the unit's BaseManager is allowed to use the SML
---@param platoon Platoon
function BaseManagerNukePlatoon(platoon)
    local aiBrain = platoon:GetBrain()
    local SMLs = platoon:GetPlatoonUnits()
	
	if not aiBrain.BaseManagers[platoon.PlatoonData.BaseName] then
        aiBrain:DisbandPlatoon(platoon)
    end
	
	for _, silo in SMLs do
		if not silo.Dead then
			local siloPlatoon = aiBrain:MakePlatoon('', '')
            aiBrain:AssignUnitsToPlatoon(siloPlatoon, {silo}, 'Support', 'None')
            siloPlatoon:SetPlatoonData(platoon.PlatoonData)
            siloPlatoon:ForkAIThread(BaseManagerNukeAI)
		end
	end

	aiBrain:DisbandPlatoon(platoon)
end

---@param platoon Platoon
function BaseManagerNukeAI(platoon)
	local aiBrain = platoon:GetBrain()
	local baseName = platoon.PlatoonData.BaseName
    local unit = platoon:GetPlatoonUnits()[1]
	
	if not unit then return end
	
	platoon:Stop()
	
	unit:SetAutoMode(true)
    while aiBrain:PlatoonExists(platoon) do
		if BMBC.NukesEnabled(aiBrain, baseName) then
			while unit:GetNukeSiloAmmoCount() < 1 do
				WaitSeconds(15)
				if not aiBrain:PlatoonExists(platoon) then
					return
				end
			end

			nukePos = AIBehaviors.GetHighestThreatClusterLocation(aiBrain, unit)
			if nukePos then
				IssueNuke({unit}, nukePos)
				WaitSeconds(15)
				IssueToUnitClearCommands(unit)
			end
		end
		WaitSeconds(10)
    end
end

--- Utility function that unlocks the AttackManager platoon to be built again if the remaining units in it reach the specified Ratio
--- Ie., if the platoon has 7 out of the 10 original units alive, and the ratio is 0.8, the AI can build this platoon again
---@param platoon Platoon
function AMUnlockRatio(platoon)
	-- platoon:GetPlatoonUnits() can return with dead units as well, gotta loop through each unit to check its state
	local count = 0
    for k, v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            count = count + 1
        end
    end
	
    platoon.MaxUnits = count
    platoon.LivingUnits = count
    platoon.Locked = true
	
    local callback = function(unit)
        platoon.LivingUnits = platoon.LivingUnits - 1
        if platoon.Locked and platoon.PlatoonData.Ratio > (platoon.LivingUnits / platoon.MaxUnits) then
			ScenarioInfo.AMLockTable[platoon.PlatoonData.PlatoonName] = false
			platoon.Locked = false
        end
    end
	
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            v.PlatoonHandle = platoon
            TriggerFile.CreateUnitDestroyedTrigger(callback, v)
        end
    end
end

--- Utility function that unlocks the AttackManager platoon to be built again if the remaining units in it reach the specified Ratio, with an added delay
--- Ie., if the platoon has 7 out of the 10 original units alive, and the ratio is 0.8, the AI can build this platoon again after the specified time has passsed
---@param platoon Platoon
function AMUnlockRatioTimer(platoon)
	-- platoon:GetPlatoonUnits() can return with dead units as well, gotta loop through each unit to check its state
	local count = 0
    for k, v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            count = count + 1
        end
    end
	
    platoon.MaxUnits = count
    platoon.LivingUnits = count
    platoon.Locked = true
    local callback = function(unit)
        platoon.LivingUnits = platoon.LivingUnits - 1
        if platoon.Locked and platoon.PlatoonData.Ratio > (platoon.LivingUnits / platoon.MaxUnits) then
            ForkThread(AMPlatoonHelperFunctions.UnlockTimer, platoon.PlatoonData.LockTimer, platoon.PlatoonData.PlatoonName)
            platoon.Locked = false
        end
    end
	
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead then
            v.PlatoonHandle = platoon
            TriggerFile.CreateUnitDestroyedTrigger(callback, v)
        end
    end
end

--- Generates a table of random, but pathable locations for use by scouting units, inside the playable area
---@param bManager BaseManager
---@param unit Unit
---@return Vector[]
function GetBaseManagerScoutingPath(bManager, unit)
    local mapInfo = ScenarioInfo.MapData.PlayableRect or {0, 0, ScenarioInfo.size[1], ScenarioInfo.size[2]}

    local pathablePoints = {}
    local possiblePoints = {}
    if EntityCategoryContains(categories.AIR, unit) and bManager:GetDefaultAirScoutPatrolChain() then
        -- Do air thing
        pathablePoints = ScenarioUtils.ChainToPositions(bManager:GetDefaultAirScoutPatrolChain())
    elseif EntityCategoryContains(categories.LAND, unit) and bManager:GetDefaultLandScoutPatrolChain() then
        -- Do land thing
        pathablePoints = ScenarioUtils.ChainToPositions(bManager:GetDefaultLandScoutPatrolChain())
    else
        local startX = mapInfo[1]
        local startY = mapInfo[2]
        local currX = startX
        -- Create a table of possible points by increasing x and y vals
        while currX < mapInfo[3] do
            local currY = startY
            while currY < mapInfo[4] do
                local useY = currY
                local useX = currX
                -- Check if the coords are the map boundaries and move them in if they are
                if currX == mapInfo[1] then
                    useX = currX + 8
                end
                if currY == mapInfo[2] then
                    useY = currY + 8
                end
                if currX == mapInfo[3] then
                    useX = currX - 8
                end
                if currY == mapInfo[4] then
                    useY = currY - 8
                end
                TableInsert(possiblePoints, { useX, 0, useY })
                currY = currY + 48
            end
            currX = currX + 48
        end
        -- Determine which points the unit can actually path to
        for k, v in possiblePoints do
            if AIUtils.CheckUnitPathingEx(v, unit:GetPosition(), unit) then
                TableInsert(pathablePoints, v)
            end
        end
    end
    return pathablePoints
end

--- Generates a table of random, but pathable locations for use by scouting units, inside the playable area
---@param unit Unit
---@return Vector[]
function GetScoutingPath(unit)
    local mapInfo = ScenarioInfo.MapData.PlayableRect or {0, 0, ScenarioInfo.size[1], ScenarioInfo.size[2]}

    local pathablePoints = {}
    local possiblePoints = {}

    local startX = mapInfo[1]
    local startY = mapInfo[2]
    local currX = startX
	
    -- Create a table of possible points by increasing x and y vals
    while currX < mapInfo[3] do
        local currY = startY
        while currY < mapInfo[4] do
            local useY = currY
            local useX = currX
            -- Check if the coords are the map boundaries and move them in if they are
            if currX == mapInfo[1] then
                useX = currX + 8
            end
            if currY == mapInfo[2] then
                useY = currY + 8
            end
            if currX == mapInfo[3] then
                useX = currX - 8
            end
            if currY == mapInfo[4] then
                useY = currY - 8
            end
            TableInsert(possiblePoints, { useX, 0, useY })
            currY = currY + 48
        end
        currX = currX + 48
    end
    -- Determine which points the unit can actually path to
    for k, v in possiblePoints do
        if AIUtils.CheckUnitPathingEx(v, unit:GetPosition(), unit) then
            TableInsert(pathablePoints, v)
        end
    end
    return pathablePoints
end

--- Sends each individual platoon unit on a randomized path, used for scouting
---@param platoon Platoon
function BaseManagerScoutingAI(platoon)
    local aiBrain = platoon:GetBrain()
    local bManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]

    -- Set up move orders to up to 10 points for each individual unit
    while aiBrain:PlatoonExists(platoon) do
		for Index, Unit in platoon:GetPlatoonUnits() do
			if not Unit.Dead then
				-- Get new points every time so if the area changes we are on it
				local pathablePoints = GetBaseManagerScoutingPath(bManager, Unit)
				local numPoints = TableGetn(pathablePoints)
				if numPoints > 0 then
					IssueToUnitClearCommands(Unit)
					local count = 0
					
					while count < 10 do
						local pickNum = Random(1, numPoints)
						IssueToUnitMove(Unit, pathablePoints[pickNum])
						count = count + 1
					end
				end
			end
		end
		WaitTicks(300)
    end
end

--- Sends each individual platoon unit on a randomized path, used for scouting
---@param platoon Platoon
function ScoutingAI(platoon)
    local aiBrain = platoon:GetBrain()

    -- Set up move orders to up to 10 points for each individual unit
    while aiBrain:PlatoonExists(platoon) do
		for Index, Unit in platoon:GetPlatoonUnits() do
			if not Unit.Dead then
				-- Get new points every time so if the area changes we are on it
				local pathablePoints = GetScoutingPath(Unit)
				local numPoints = TableGetn(pathablePoints)
				if numPoints > 0 then
					IssueToUnitClearCommands(Unit)
					local count = 0
					
					while count < 10 do
						local pickNum = Random(1, numPoints)
						IssueToUnitMove(Unit, pathablePoints[pickNum])
						count = count + 1
					end
				end
			end
		end
		WaitTicks(300)
    end
end

---@param unit Unit
function UnitUpgradeThread(platoon, UpgradeName)
	local unit = platoon:GetPlatoonUnits()[1]
    local aiBrain = platoon:GetBrain()

	-- Update the BM as needed
	local BaseName = unit.CDRData.BaseName
	local bManager = aiBrain.BaseManagers[BaseName]

    if bManager and UpgradeName and not unit.Dead and aiBrain:PlatoonExists(platoon) and not unit:IsUnitState('Building') then
        -- Remove the unit from the builders list
        if bManager:IsConstructionUnit(unit) then
            bManager:RemoveConstructionEngineer(unit)
        end

        local order = {
            TaskName = "EnhanceTask",
            Enhancement = UpgradeName
        }
        IssueStop({unit})
        IssueToUnitClearCommands(unit)
        IssueScript({unit}, order)

        repeat
            WaitTicks(15)
            if unit.Dead or not aiBrain:PlatoonExists(platoon) then
                return
            end
        until unit:IsIdleState()
    else
		WARN("AI WARNING: Couldn't upgrade Command Unit type for base: " .. tostring(BaseName))
	end
end

--- Sets up the thread and necessary data for the Engineer platoon to upgrade when higher tier ones can be built
---@param platoon Platoon
function EngineerUpgradeBehavior(platoon)
	for Index, Unit in platoon:GetPlatoonUnits() do
		if not Unit.Dead then
			-- Always update the Engineer data, in case the Engineer is reassigned for whatever reason
			if platoon.PlatoonData then
				Unit.EngineerData = table.deepcopy(platoon.PlatoonData)
			end
	
			-- Add the upgrade thread only once, since it'll run until the Engineer is dead
			if not Unit.UpgradeThread then
				Unit.UpgradeThread = Unit:ForkThread(EngineerUpgradeThread)
			end
		end
	end
end

--- Main thread for BM Engineers that will self-destruct them if the BM can build higher tier Engineers
--- The name is misleading, however the intent is really to replace lower tier Engineers with higher tier ones
---@param unit Unit
---@param unit Unit
function EngineerUpgradeThread(unit)
	-- Locals for performance
    local aiBrain = unit.Brain
	local BaseManagers = aiBrain.BaseManagers
	local TechLevel = nil

    -- Determine the tier of the unit, if it's not T1 or T2, terminate the thread
    if EntityCategoryContains(categories.TECH1, unit) then
        TechLevel = 1
    elseif EntityCategoryContains(categories.TECH2, unit) then
        TechLevel = 2
    else
		return
	end
	
    while not unit.Dead do
		-- Update the BM as needed
		local BaseName = unit.EngineerData.BaseName
		local bManager = BaseManagers[BaseName]
		-- Self-destruct if we can build higher tier Engineers, and the current Engineer platoon is not building anything
        if bManager then
            if BMBC.HighestFactoryLevelGreater(aiBrain, TechLevel, BaseName) and not unit:IsUnitState('Building') then
                unit:Kill()
				return
            end
        else
			WARN("No BaseManager detected for: " .. tostring(aiBrain.Name) .. ", for base: " .. tostring(BaseName))
		end
		WaitTicks(15)
    end
end