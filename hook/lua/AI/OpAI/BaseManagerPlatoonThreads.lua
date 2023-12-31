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

local EngineerBuildDelay = tonumber(ScenarioInfo.Options.EngineerBuildDelay) or 10

--- Split the platoon into single unit platoons
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
            -- Make sure current base manager isnt at capacity of engineers
            if EntityCategoryContains(categories.ENGINEER, v) and bManager.EngineerQuantity > bManager.CurrentEngineerCount then
                if bManager.EngineerBuildRateBuff then
                    Buff.ApplyBuff(v, bManager.EngineerBuildRateBuff)
                end

                local engPlat = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(engPlat, {v}, 'Support', 'None')
                engPlat.PlatoonData = table.deepcopy(platoon.PlatoonData)
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

--- Callback function when an engineering unit starts building something
--- If that 'something' is a named unit (structure) the engineer was told to build, then it caches the necessary data on the named unit
--- Also resets the unit name we cached on the Engineer, so if any mishaps happen, the engineer can just build something else afterwards
---@param unit Unit
function EngineerOnStartBuild(unit, unitBeingBuilt)
	-- We cached the name of the unit we want to build, and the engineer's BaseManager, 1st when we ordered the engineer to build, 2nd when the engineer's platoon was formed
	local unitName = unit.BuildingUnitName
	local bManager = unit.Brain.BaseManagers[unit.BaseName]
	
	-- Things like the AI brains and army indexes are cached on the unit, we don't need to use engine calls to get them
	-- Make sure the engineer was told to build a specific named unit, its BaseManager exists, and the named unit is a structure
	if unitName and bManager and EntityCategoryContains(categories.STRUCTURE, unitBeingBuilt) then
		--LOG('Building started construction named: ' .. repr(unit.BuildingUnitName))
		unitBeingBuilt.UnitName = unitName
		unitBeingBuilt.BaseName = unit.BaseName
		bManager.UnfinishedBuildings[unitName] = true
		
		ScenarioInfo.UnitNames[unit.Army][unitName] = unitBeingBuilt
		unit.BuildingUnitName = nil
		
		if not unitBeingBuilt.AddedCompletionCallback then
			unitBeingBuilt:AddUnitCallback(StructureOnStopBeingBuilt, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedCompletionCallback = true
		end
	end
end

--- Callback function when an engineering unit failed to build something, this is called in several cases
--- Resets the unit name we assigned to the engineer, so in case it's still alive, it can start building something else
---@param unit Unit
function EngineerOnFailedToBuild(unit)
	if unit.BuildingUnitName then
		--LOG('Building failed construction named: ' .. repr(unit.BuildingUnitName))
		unit.BuildingUnitName = nil
	end
end

--- Callback function when a (preferably) structure is finished building
--- Marks the unit as finished for the unit's BaseManager, so Engineers won't try to finish it (infinite loop of repair orders on a full health unit), and decrements the amount of times it can be rebuilt
---@param unit Unit
function StructureOnStopBeingBuilt(unit)
	local bManager = unit.Brain.BaseManagers[unit.BaseName]
	
	if bManager.UnfinishedBuildings[unit.UnitName] then
		--LOG('Building finished construction named: ' .. repr(unit.UnitName))
		bManager.UnfinishedBuildings[unit.UnitName] = nil
		bManager:DecrementUnitBuildCounter(unit.UnitName)
	end
end

--- Main function for base manager engineers
---@param platoon Platoon
function BaseManagerSingleEngineerPlatoon(platoon)
    platoon.PlatoonData.DontDisband = true

    local aiBrain = platoon:GetBrain()
    local baseName = platoon.PlatoonData.BaseName
    local bManager = aiBrain.BaseManagers[baseName]
    local unit = platoon:GetPlatoonUnits()[1]
    local canPermanentAssist = EntityCategoryContains(categories.ENGINEER - (categories.COMMAND + categories.SUBCOMMANDER), unit)
    local commandUnit = EntityCategoryContains(categories.COMMAND + categories.SUBCOMMANDER, unit)
    unit.BaseName = baseName
	
	-- Add build callbacks for these engineers
	-- NOTE: Directly hooking individual units seem to be volatile, and can result in hard crashes if used too much!
	if not unit.AddedBuildCallback then
		-- The universal function doesn't work for OnStartBuild, unit.unitBeingBuilt is only accessable after the DoUnitCallback has been executed
		unit:AddOnStartBuildCallback(EngineerOnStartBuild)
		unit:AddUnitCallback(EngineerOnFailedToBuild, "OnFailedToBuild")
		unit.AddedBuildCallback = true
	end
	
    while aiBrain:PlatoonExists(platoon) do
        if BMBC.BaseEngineersEnabled(aiBrain, baseName) then
            -- Move to expansion base
            if not commandUnit and BMBC.ExpansionBasesEnabled(aiBrain, baseName) and BMBC.ExpansionBasesNeedEngineers(aiBrain, baseName) then
                ExpansionEngineer(platoon)

            elseif canPermanentAssist and bManager.ConditionalBuildData.Unit and not bManager.ConditionalBuildData.Unit.Dead and bManager.ConditionalBuildData.NeedsMoreBuilders() then
                AssistConditionalBuild(platoon)

            -- If we can do a conditional build here, then do it
            elseif canPermanentAssist and CanConditionalBuild(platoon) then
                DoConditionalBuild(platoon)

            -- Try to build buildings
            elseif BMBC.NeedAnyStructure(aiBrain, baseName) and bManager:GetConstructionEngineerCount() < bManager:GetConstructionEngineerMaximum() then
                bManager:AddConstructionEngineer(unit)
                TriggerFile.CreateUnitDestroyedTrigger(ConstructionUnitDeath, unit)
                BaseManagerEngineerThread(platoon)
                bManager:RemoveConstructionEngineer(unit)

            -- Permanent Assist - Assist factories until the unit dies
            elseif canPermanentAssist and bManager:NeedPermanentFactoryAssist() then
                bManager:IncrementPermanentAssisting()
                PermanentFactoryAssist(platoon)

            -- Finish unfinished buildings
            elseif BMBC.UnfinishedBuildingsCheck(aiBrain, baseName) then
                BuildUnfinishedStructures(platoon)

            -- Reclaim nearby wreckage/trees/rocks/people; never do this right now dont want to destroy props and stuff
            elseif false and BMBC.BaseReclaimEnabled(aiBrain, baseName) and MIBC.ReclaimablesInArea(aiBrain, baseName) then
                BaseManagerReclaimThread(platoon)

            -- Try to assist
            elseif BMBC.CategoriesBeingBuilt(aiBrain, baseName, {'MOBILE LAND', 'ALLUNITS' }) or(bManager:ConstructionNeedsAssister()) then
                BaseManagerAssistThread(platoon)

            -- Try to patrol
            elseif BMBC.BasePatrollingEnabled(aiBrain, baseName) and not unit:IsUnitState('Patrolling') then
                BaseManagerEngineerPatrol(platoon)
            end
        end
        WaitSeconds(5)
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
        if bManager.ConditionalBuildData.Unit.Dead then
            local selectedBuild = bManager.ConditionalBuildTable[bManager.ConditionalBuildData.Index]
            -- If we're not supposed to retry, then remove from the conditional build list
            if not selectedBuild.data.Retry then
                table.remove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
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
    if table.empty(bManager.ConditionalBuildTable) then
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
    local aiBrain = conditionalUnit:GetAIBrain()
    local bManager = aiBrain.BaseManagers[conditionalUnit.BaseName]
    local selectedBuild = conditionalUnit.ConditionalBuild
    -- Reinsert the conditional build (for one of these units)
    table.insert(bManager.ConditionalBuildTable, {
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
    local aiBrain = conditionalUnit:GetAIBrain()
    local bManager = aiBrain.BaseManagers[conditionalUnit.BaseName]
    local selectedBuild = bManager.ConditionalBuildTable[bManager.ConditionalBuildData.Index]

    -- Assign AI
    local newPlatoon = aiBrain:MakePlatoon('', '')
    aiBrain:AssignUnitsToPlatoon(newPlatoon, {conditionalUnit}, 'Attack', 'None')
    newPlatoon:StopAI()
    newPlatoon:SetPlatoonData(selectedBuild.data.PlatoonData)

    if selectedBuild.data.PlatoonAIFunction then
        newPlatoon:ForkAIThread(import(selectedBuild.data.PlatoonAIFunction[1])[selectedBuild.data.PlatoonAIFunction[2]])
    end
	
	if selectedBuild.data.FormCallbacks then
        for _, callback in selectedBuild.data.FormCallbacks do
            if type(callback) == "function" then
                newPlatoon:ForkThread(callback)
            else
                newPlatoon:ForkThread(import(callback[1])[callback[2]])
            end
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
        table.remove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
    elseif selectedBuild.data.Amount > 0 then
        -- Decrement the amount left to build
        selectedBuild.data.Amount = selectedBuild.data.Amount - 1

        -- If none are left to build, remove from the build table
        if selectedBuild.data.Amount == 0 then
            table.remove(bManager.ConditionalBuildTable, bManager.ConditionalBuildData.Index)
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
    IssueClearCommands({engineer})
    IssueRepair({engineer}, bManager.ConditionalBuildData.Unit)

    -- Super loop
    while aiBrain:PlatoonExists(singleEngineerPlatoon) do
        WaitSeconds(3)

        if engineer:IsIdleState() then
            break
        end
    end

    IssueClearCommands({engineer})
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
    local unitToBuild
    if type(selectedBuild.name) == 'table' then
        unitToBuild = ScenarioUtils.FindUnit(selectedBuild.name[math.random(1, table.getn(selectedBuild.name))], Scenario.Armies[aiBrain.Name].Units)
        if not unitToBuild then error('Unit with name "' .. selectedBuild.name .. '" could not be found for conditional building.') return end
    else
        unitToBuild = ScenarioUtils.FindUnit(selectedBuild.name, Scenario.Armies[aiBrain.Name].Units)
        if not unitToBuild then error('Unit with name "' .. selectedBuild.name .. '" could not be found for conditional building.') return end
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
    IssueClearCommands({engineer})
    local result = aiBrain:BuildStructure(engineer, unitToBuild.type, {unitToBuild.Position[1], unitToBuild.Position[3], 0})

    -- Enter build monitoring loop
    local unitInstance = false
    while aiBrain:PlatoonExists(singleEngineerPlatoon) do
        if not unitInstance then
            unitInstance = engineer.UnitBeingBuilt
            if unitInstance then
                -- Store the unit
                bManager.ConditionalBuildData.Unit = unitInstance

                -- If were supposed to keep a certain number of these guys in the field, store the info on him so he can reinsert
                -- himself in the conditional build table when he bites it.
                if selectedBuild.data.KeepAlive then
                    unitInstance.KeepAlive = true
                    unitInstance.ConditionalBuild = selectedBuild
                    unitInstance.ConditionalBuildData = bManager.ConditionalBuildData

                    -- register rebuild callback
                    TriggerFile.CreateUnitDestroyedTrigger(ConditionalBuildDied, unitInstance)
                end

                -- Tell the unit the name of this base manager
                unitInstance.BaseName = baseName

                -- Set variables so other engineers can see whats going on
                bManager.ConditionalBuildData.IsInitiated = false
                bManager.ConditionalBuildData.IsBuilding = true

                -- Register callbacks
                TriggerFile.CreateUnitStopBeingBuiltTrigger(ConditionalBuildSuccessful, unitInstance)
            end
        end
        if engineer:IsIdleState() then
            break
        end
        WaitTicks(10)
    end
    IssueClearCommands({engineer})
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
        for _, v in facs do
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
        WaitSeconds(15)
    end
end

--- Assist units that are building structures and units
---@param platoon Platoon
function BaseManagerAssistThread(platoon)
    platoon:Stop()

    local unit = platoon:GetPlatoonUnits()[1]
    local aiBrain = platoon:GetBrain()
    local bManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]
    local assistData = platoon.PlatoonData.Assist
    local assistee = false
    local assistingBool = false
    local beingBuiltCategories = assistData.BeingBuiltCategories

    if not beingBuiltCategories then
        beingBuiltCategories = {'MASSEXTRACTION', 'MASSPRODUCTION', 'ENERGYPRODUCTION', 'FACTORY', 'EXPERIMENTAL', 'DEFENSE', 'MOBILE LAND', 'ALLUNITS'}
    end

    local assistRange = assistData.AssistRange or bManager.Radius
    local counter = 0
    while counter < (assistData.Time or 200) and aiBrain:PlatoonExists(platoon) do
		local GuardedUnit = unit:GetGuardedUnit()
        -- If the engineer is assisting a construction unit that is building, or we don't need assisters, or we are a construction unit, break out and do nothing
        if not GuardedUnit or (not GuardedUnit:IsUnitState('Building') and not bManager:ConstructionNeedsAssister() and not bManager:IsConstructionUnit(GuardedUnit)) then
            if bManager:ConstructionNeedsAssister() then
                local consUnits = bManager.ConstructionEngineers
                local lowNum = 100000
                local highNum = 0
                local currLow = false
                for _, v in consUnits do
                    local guardNum = table.getn(v:GetGuards())
                    if not v.Dead and guardNum < lowNum then
                        currLow = v
                        lowNum = table.getn(v:GetGuards())
                    end
                    if guardNum > highNum then
                        highNum = guardNum
                    end
                end
                if GuardedUnit then
                    if GuardedUnit.Dead or EntityCategoryContains(categories.FACTORY, GuardedUnit) or
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
                local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
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
                                if not EntityCategoryContains(categories.FACTORY, constructionUnit) or aiBrain:PBMFactoryLocationCheck(constructionUnit, platoon.PlatoonData.BaseName) then
                                    -- make sure unit is within valid assist range
                                    local unitPos = constructionUnit:GetPosition()
									local platoonPos = platoon:GetPlatoonPosition()
                                    if unitPos and platoonPos and VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3]) < assistRange then
                                        assistee = constructionUnit
                                        break
                                    end
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
            if assistee and not assistee.Dead and EntityCategoryContains(categories.FACTORY, assistee) then
                platoon:Stop()
                local guardee = assistee:GetGuardedUnit()
                if guardee and not guardee.Dead and EntityCategoryContains(categories.FACTORY, guardee) then
                    local factories = AIUtils.AIReturnAssistingFactories(guardee)
                    table.insert(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoon:GetPlatoonUnits(), factories)
                    assistingBool = true
                elseif not table.empty(assistee:GetGuards()) then
                    local factories = AIUtils.AIReturnAssistingFactories(assistee)
                    table.insert(factories, assistee)
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
        local waitTime = 25
        WaitTicks(waitTime)

        counter = counter + waitTime
    end
end

---@param brain AIBrain
---@param platoon Platoon
function ExpansionPlatoonDestroyed(brain, platoon)
    local aiBrain = platoon:GetBrain()
    local bManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]

    for num, eData in bManager.ExpansionBaseData do
        if eData.BaseName == platoon.PlatoonData.ExpansionBase then
            eData.IncomingEngineers = eData.IncomingEngineers - 1
        end
    end
end

--- Move a unit to a new location
---@param platoon Platoon
---@param finalLocation Vector
---@return PlatoonCommand|boolean
function TransportUnitsToLocation(platoon, finalLocation)
    local units = platoon:GetPlatoonUnits()
    if AIUtils.CheckUnitPathingEx(finalLocation, units[1]:GetPosition(), units[1]) then
        local cmd = platoon:MoveToLocation(finalLocation, false)
        return cmd
    end

    if not AIUtils.GetTransports(platoon) then
        return false
    end
    AIUtils.UseTransports(units, platoon:GetSquadUnits('Scout'), finalLocation)

    return true
end

--- Engineer build structures
---@param platoon Platoon
function BaseManagerEngineerThread(platoon)
    platoon:Stop()

    local aiBrain = platoon:GetBrain()
	local armyIndex = aiBrain:GetArmyIndex()
    local eng

    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and EntityCategoryContains(categories.CONSTRUCTION, v) then
            if not eng then
                eng = v
            else
                IssueClearCommands({v})
                IssueGuard({v}, eng)
            end
        end
    end

    if not eng or eng.Dead then
        aiBrain:DisbandPlatoon(platoon)
        return
    end

    if not platoon.PlatoonData.BaseName or not aiBrain.BaseManagers[platoon.PlatoonData.BaseName] then
        error('*AI DEBUG: Missing Base Name or invalid base name for base manager engineer thread', 2)
    end

    local structurePriorities = platoon.PlatoonData.StructurePriorities
	
    if not structurePriorities then
        structurePriorities = {
			'T3Resource', 'T2Resource', 'T1Resource', 'T3EnergyProduction', 'T2EnergyProduction', 'T1EnergyProduction', 'T3MassCreation',
            'T2EngineerSupport', 'T3SupportLandFactory', 'T3SupportAirFactory', 'T3SupportSeaFactory', 'T2SupportLandFactory', 'T2SupportAirFactory', 'T2SupportSeaFactory', 'T1LandFactory', 'T1AirFactory', 'T1SeaFactory',
			'T4LandExperimental1', 'T4LandExperimental2', 'T4AirExperimental1', 'T4SeaExperimental1',
			'T3ShieldDefense', 'T2ShieldDefense', 'T3StrategicMissileDefense', 'T3Radar', 'T2Radar', 'T1Radar',
            'T3AADefense', 'T3GroundDefense', 'T3NavalDefense', 'T2AADefense', 'T2MissileDefense', 'T2GroundDefense', 'T2NavalDefense', 'ALLUNITS'
		}
    end

    local retBool, unitName
    local baseManager = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]
	
    for dNum, levelData in baseManager.LevelNames do
        if levelData.Priority > 0 then
            for _, v in structurePriorities do
                local unitType = false
                if v ~= 'ALLUNITS' then
                    unitType = v
                end

                repeat
					if not aiBrain:PlatoonExists(platoon) then
						return
					end
					
                    retBool, unitName = BuildBaseManagerStructure(aiBrain, aiBrain.BaseManagers[platoon.PlatoonData.BaseName], levelData.Name, unitType, platoon)
                    if retBool and unitName then
						eng.BuildingUnitName = unitName
						
                        repeat
							WaitTicks(EngineerBuildDelay)
                           
                            if not aiBrain:PlatoonExists(platoon) then
                                return
                            end
                        until eng.Dead or eng:IsIdleState()
					end
                until not retBool
            end
        end
    end
    local tempPos = aiBrain.BaseManagers[platoon.PlatoonData.BaseName]:GetPosition()
	
	platoon:MoveToLocation(tempPos, false)
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
function BuildBaseManagerStructure(aiBrain, baseManager, levelName, buildingType, platoon)
	local aiBrain = platoon:GetBrain()
    local buildTemplate = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].Template
    local buildList = aiBrain.BaseTemplates[baseManager.BaseName .. levelName].List
	local eng = platoon:GetPlatoonUnits()[1]
	
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
                local closest = false
                -- Iterate through build locations
                for num, location in v do
                    -- Check if it can be built and then build
                    if num > 1 and aiBrain:CanBuildStructureAt(category, {location[1], 0, location[2]}) and baseManager:CheckUnitBuildCounter(location, buildCounter) then
                        if not closest or (VDist2(location[1], location[3], engineerPos[1], engineerPos[3]) < VDist2(closest[1], closest[3], engineerPos[1], engineerPos[3])) then
                            closest = location
                        end
                    end
                end

                if closest then
                    -- Removed transport call as the pathing check was creating problems with base manager rebuilding
                    -- TODO: develop system where base managers more easily rebuild in far away or hard to reach locations
                    -- and TransportUnitsToLocation(platoon, {closest[1], 0, closest[2]}) then
                    IssueClearCommands({eng})
                    aiBrain:BuildStructure(eng, category, closest, false)

                    local unitName = false
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
            launcherPlatoon.PlatoonData = table.deepcopy(platoon.PlatoonData)
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
        categories.TECH3 * categories.MOBILE}
	)

    while aiBrain:PlatoonExists(platoon) do
        if BMBC.TMLsEnabled(aiBrain, baseName) then
            local target = false
            while unit:GetTacticalSiloAmmoCount() < 1 or not target do
                WaitSeconds(5)
                target = false
                while not target do
                    target = platoon:FindPrioritizedUnit('Attack', 'Enemy', true, unit:GetPosition(), maxRadius)

                    if target then
                        break
                    end

                    WaitSeconds(5)

                    if not aiBrain:PlatoonExists(platoon) then
                        return
                    end
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
            siloPlatoon.PlatoonData = table.deepcopy(platoon.PlatoonData)
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
				IssueClearCommands({unit})
			end
		end
		WaitSeconds(10)
    end
end

---@param platoon Platoon
function AMUnlockRatio(platoon)
	local count = table.getn(platoon:GetPlatoonUnits())
	
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
            --v.PlatoonHandle = platoon
            TriggerFile.CreateUnitDestroyedTrigger(callback, v)
        end
    end
end

---@param platoon Platoon
function AMUnlockRatioTimer(platoon)
	local count = table.getn(platoon:GetPlatoonUnits())
	
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
            --v.PlatoonHandle = platoon
            TriggerFile.CreateUnitDestroyedTrigger(callback, v)
        end
    end
end

-- kept for mod compatibility, as they may depend on these
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
