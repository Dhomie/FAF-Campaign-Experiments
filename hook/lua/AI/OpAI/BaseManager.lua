---------------------------------------------------------------------------------------------
--- File     :	/lua/AI/OpAI/BaseManager.lua
--- Summary  : Base Manager fixes, additions for campaign/coop
---
--- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
---------------------------------------------------------------------------------------------

--- Changelog:
--- 	- More reliable structure upgrade checks
---		- Most structures now upgrade from their lowest available tech variants
---		- Rebuilds are infinite for all difficulties
---		- Fixed ACUs and sACUs removing prerequisite enhancements
---		- Added default transport platoons, along with the corresponding BaseManager functionality, courtesy of 4z0t for the idea

local BaseManagerTemplate = BaseManager
local Factions = import('/lua/factions.lua').Factions

--- Failsafe callback function when a structure marked for needing an upgrade starts building something
--- If that 'something' is the upgrade itself, create a callback for the upgrade
---@param@ unit Unit
---@param unitBeingBuilt Unit
function FailSafeStructureOnStartBuild(unit, unitBeingBuilt)
	-- If we are in the upgrading state, then it's the upgrade we want under normal circumstances.
	-- We don't use different upgrades paths for coop, only that of the original SCFA (no Support Factory upgrade paths whatsoever)
	-- If you decide to mess around with AI armies in cheat mode, and order a newly added upgrade path instead anyway, then any mishaps happening afterwards is on you!
	if unit:IsUnitState('Upgrading') then
		--LOG('Structure building upgrade named: ' .. tostring(unit.UnitName))
		unitBeingBuilt.UnitName = unit.UnitName
		unitBeingBuilt.BaseName = unit.BaseName

		-- Add callback when the upgrade is finished
		if not unitBeingBuilt.AddedFinishedCallback then
			unitBeingBuilt:AddUnitCallback(FailSafeUpgradeOnStopBeingBuilt, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedFinishedCallback = true
		end
	end
end

--- Failsafe function that will upgrade factories, radar, etc. to next level
---@param unit Unit
---@param upgradeID Upgrade Blueprint
function FailSafeUpgradeBaseManagerStructure(unit, upgradeID)
	-- Add callback when the structure starts building something
	if not unit.AddedUpgradeCallback then
		unit:AddOnStartBuildCallback(FailSafeStructureOnStartBuild)
		unit.AddedUpgradeCallback = true
	end

    IssueUpgrade({unit}, upgradeID)
	unit.SetToUpgrade = true
end

--- Failsafe callback function when a structure upgrade is finished building
--- Updates the ScenarioInfo.UnitNames table with the new unit, and upgrades further if needed
---@param unit Unit
function FailSafeUpgradeOnStopBeingBuilt(unit)
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
					FailSafeUpgradeBaseManagerStructure(unit, upgradeID)
				end
			end
		end
	end
end

---@class BaseManager
---@field Trash TrashBag
---@field AIBrain AIBrain
BaseManager = Class(BaseManagerTemplate) {
	--- Introduces all the relevant fields to the base manager, internally called by the engine
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return nil
    Create = function(self)
		BaseManagerTemplate.Create(self)
		
		self.MaximumConstructionEngineers = (ScenarioInfo.Options.Difficulty or 3) * 2
		
		-- Default to no transports needed
		self.TransportsNeeded = 0
		self.TransportsTech = 1
		
		-- Commented out unused states
		self.FunctionalityStates = {
            --AirAttacks = true,
            AirScouting = false,
            AntiAir = true,
            Artillery = true,
            BuildEngineers = true,
            CounterIntel = true,
            --EngineerReclaiming = true,
            Engineers = true,
            ExpansionBases = false,
            Fabrication = true,
            GroundDefense = true,
            Intel = true,
            --LandAttacks = true,
            LandScouting = false,
            Nukes = false,
            Patrolling = true,
            --SeaAttacks = true,
            Shields = true,
            TMLs = true,
            Torpedos = true,
			Transports = false,
            Walls = true,

            --Custom = {},
        }
    end,
	
	--- Initialises the base manager. 
    ---@see See the functions StartNonZeroBase, StartDifficultyBase, StartBase or StartEmptyBase to the initial state of the base
    ---@param self BaseManager          # An instance of the BaseManager class
    ---@param brain AIBrain             # An instance of the Brain class that we're managing a base for
    ---@param baseName UnitGroup        # Name reference to a unit group as defined in the map that represnts the base, usually appended with _D1, _D2 or _D3 
    ---@param markerName Marker         # Name reference to a marker as defined in the map that represents the center of the base
    ---@param radius number             # Radius of the base - any structure that is within this distance to the center of the base is considered part of the base
    ---@param levelTable any            # A table of { { UnitGroup, Priority } } that represents the priority of various sections of the base
    ---@param diffultySeparate any      # Flag that indicates we have a base that expands based on difficulty
    ---@return nil
    Initialize = function(self, brain, baseName, markerName, radius, levelTable, diffultySeparate)
		BaseManagerTemplate.Initialize(self, brain, baseName, markerName, radius, levelTable, diffultySeparate)
		self:LoadDefaultBaseTransports()
    end,
	
	---@param self BaseManager
    ---@param groupName string
    ---@param addName string
    AddToBuildingTemplate = function(self, groupName, addName)
        local tblUnit = ScenarioUtils.AssembleArmyGroup(self.AIBrain.Name, groupName)
        local factionIndex = self.AIBrain:GetFactionIndex()
        local template = self.AIBrain.BaseTemplates[addName].Template
        local list = self.AIBrain.BaseTemplates[addName].List
        local unitNames = self.AIBrain.BaseTemplates[addName].UnitNames
        local buildCounter = self.AIBrain.BaseTemplates[addName].BuildCounter
        if not tblUnit then
            error('*AI DEBUG - Group: ' .. tostring(name) .. ' not found for Army: ' .. tostring(army), 2)
        else
            -- Convert building to the proper type to be built if needed (ex: T2 and T3 factories to T1)
            for i, unit in tblUnit do
                for k, unitId in StructureTemplates.RebuildStructuresTemplate[factionIndex] do
                    if unit.type == unitId[1] then
                        table.insert(self.UpgradeTable, { FinalUnit = unit.type, UnitName = i, })
                        unit.buildtype = unitId[2]
                        break
                    end
                end
                if not unit.buildtype then
                    unit.buildtype = unit.type
                end
            end
            for i, unit in tblUnit do
                self:StoreStructureName(i, unit, unitNames)
                for j, buildList in StructureTemplates.BuildingTemplates[factionIndex] do -- BuildList[1] is type ("T1LandFactory"); buildList[2] is unitId (ueb0101)
                    local unitPos = { unit.Position[1], unit.Position[3] }
                    if unit.buildtype == buildList[2] and buildList[1] ~= 'T3Sonar' then -- If unit to be built is the same id as the buildList unit it needs to be added
                        self:StoreBuildCounter(buildCounter, buildList[1], buildList[2], unitPos, i)

                        local inserted = false
                        for k, section in template do -- Check each section of the template for the right type
                            if section[1][1] == buildList[1] then
                                table.insert(section, unitPos) -- Add position of new unit if found
                                inserted = true
                                break
                            end
                        end
                        if not inserted then -- If section doesn't exist create new one
                            table.insert(template, { { buildList[1] }, unitPos }) -- add new build type to list with new unit
                            list[unit.buildtype] = { StructureType = buildList[1], StructureCategory = unit.buildtype }
                        end
                        break
                    end
                end
            end
        end
    end,

	--- Overwrite to return -1 --> building can be rebuilt indefinitely
    BuildingCounterDifficultyDefault = function(self, buildingType)
        return -1
    end,
	
	--- Retrieves the amount of engineers that are building
	--- This variable is not updated if the Engineers are killed BEFORE they could be formed into platoons (ie.: during roloff, construction)
	--- I've added a failsafe check that will actually check if there are Engineers being built
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return integer              # Amount of engineers that are building
    GetEngineersBuilding = function(self)
		-- If there are Engineering units being built, return with the proper number, otherwise there are obviously none being built, return 0
		--if import(BMBC).CategoriesBeingBuilt(self.AIBrain, self.BaseName, {'ENGINEER'}) then
			return self.EngineersBuilding
		--else
			--return 0
		--end
    end,
	
	--- Adds or subtracts from the number of engineers that are building
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@param count integer         # Amount to add or subtract
    SetEngineersBuilding = function(self, count)
		self.EngineersBuilding = self.EngineersBuilding + count
    end,
	
	---@param self BaseManager
    ---@param location Vector
    ---@param buildCounter number
    ---@return boolean
    CheckUnitBuildCounter = function(self, location, buildCounter)
        for xVal, xData in buildCounter do
            if xVal == location[1] then
                for yVal, yData in xData do
                    if yVal == location[2] then
						return (yData.Counter > 0 or yData.Counter == -1)
                    end
                end
            end
        end

        return false
    end,
	
	--- Failsafe thread that will periodically loop through existing units that have been converted to lower tech level units so they can be built (ie. HQ factories)
	--- If their unit IDs don't match the one set in the save.lua file, a failsafe function will be called to check if they are idle, so an upgrade can be started
	---@param self BaseManager
    UpgradeCheckThread = function(self)
        local armyIndex = self.AIBrain:GetArmyIndex()
        while true do
            if self.Active then
                for k, v in self.UpgradeTable do
                    local unit = ScenarioInfo.UnitNames[armyIndex][v.UnitName]
					-- Check if the structure exists, and needs to upgrade
                    if unit and not unit.Dead and unit.UnitId ~= v.FinalUnit then
                        --self:ForkThread(self.BaseManagerUpgrade, unit, v.UnitName)
						self:BaseManagerUpgrade(unit, v.UnitName)
                    end
                end
            end
            WaitSeconds(15)
        end
    end,
	
	--- Failsafe function that will upgrade factories, radar, etc. to next level if the initial upgrade order executed via build callbacks failed somehow
	---@param self BaseManager
    ---@param unit Unit
    ---@param unitName string
	BaseManagerUpgrade = function(self, unit, unitName)
		-- If we were set to upgrade, and we're being built, or busy building something, return
		if unit.SetToUpgrade and (unit:IsUnitState('Upgrading') or unit:IsUnitState('Building') or unit:IsUnitState('BeingBuilt') or unit:GetNumBuildOrders(categories.ALLUNITS) > 0) then
			return
		end
		
		local aiBrain = self.AIBrain
		local factionIndex = aiBrain:GetFactionIndex()
		local upgradeID = aiBrain:FindUpgradeBP(unit.UnitId, UpgradeTemplates.StructureUpgradeTemplates[factionIndex])
		
		if upgradeID then
			FailSafeUpgradeBaseManagerStructure(unit, upgradeID)
		else
			WARN("BM Failsafe upgrade error: Couldn't find valid upgrade ID for unit named: " .. tostring(unitName) .. ", part of: " .. tostring(unit.BaseName))
		end
    end,
	
	ActivationFunctions = {
        ShieldsActive = function(self, val)
            local shields = AIUtils.GetOwnUnitsAroundPoint(self.AIBrain, categories.SHIELD * categories.STRUCTURE,
                self.Position, self.Radius)
            for k, v in shields do
                if val then
                    v:OnScriptBitSet(0) -- If turning on shields
                else
                    v:OnScriptBitClear(0) -- If turning off shields
                end
            end
            self.FunctionalityStates.Shields = val
        end,

        FabricationActive = function(self, val)
            local fabs = AIUtils.GetOwnUnitsAroundPoint(self.AIBrain, categories.MASSFABRICATION * categories.STRUCTURE,
                self.Position, self.Radius)
            for k, v in fabs do
                if val then
                    v:OnScriptBitClear(4) -- If turning on
                else
                    v:OnScriptBitSet(4) -- If turning off
                end
            end
            self.FunctionalityStates.Fabrication = val
        end,

        IntelActive = function(self, val)
            local intelUnits = AIUtils.GetOwnUnitsAroundPoint(self.AIBrain,
                (categories.RADAR + categories.SONAR + categories.OMNI) * categories.STRUCTURE, self.Position,
                self.Radius)
            for k, v in intelUnits do
                if val then
                    v:OnScriptBitClear(3) -- If turning on
                else
                    v:OnScriptBitSet(3) -- If turning off
                end
            end
            self.FunctionalityStates.Intel = val
        end,

        CounterIntelActive = function(self, val)
            local intelUnits = AIUtils.GetOwnUnitsAroundPoint(self.AIBrain,
                categories.COUNTERINTELLIGENCE * categories.STRUCTURE, self.Position, self.Radius)
            for k, v in intelUnits do
                if val then
                    v:OnScriptBitClear(3) -- If turning on intel
                else
                    v:OnScriptBitSet(2) -- If turning off intel
                end
            end
            self.FunctionalityStates.CounterIntel = val
        end,

        TMLActive = function(self, val)
            self.FunctionalityStates.TMLs = val
        end,

        NukeActive = function(self, val)
            self.FunctionalityStates.Nukes = val
        end,

        PatrolActive = function(self, val)
            self.FunctionalityStates.Patrolling = val
        end,

        ReclaimActive = function(self, val)
            self.FunctionalityStates.EngineerReclaiming = val
        end,
		
		TransportsActive = function(self, val)
			self.FunctionalityStates.Transports = val
		end,

        LandScoutingActive = function(self, val)
            self.FunctionalityStates.LandScouting = val
        end,

        AirScoutingActive = function(self, val)
            self.FunctionalityStates.AirScouting = val
        end,
    },
	
	---@param self BaseManager
	---@param val number
	SetTransportsNeeded = function(self, val)
		self.TransportsNeeded = val
	end,
	
	---@param self BaseManager
	---@param val number
	SetTransportsTech = function(self, val)
		self.TransportsTech = val
	end,
	
	---@param self BaseManager
    LoadDefaultBaseEngineers = function(self)
        local defaultBuilder
        -- The Engineer AI thread for already built Engineers
        for i = 1, 3 do
            defaultBuilder = {
                BuilderName = 'T' .. i .. 'BaseManaqer_EngineersWork_' .. self.BaseName,
                PlatoonTemplate = self:CreateEngineerPlatoonTemplate(i),
                Priority = 1,
                PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerEngineerPlatoonSplit' },
                BuildConditions = {
                    { BMBC, 'BaseManagerNeedsEngineers', { self.BaseName } },
                    { BMBC, 'BaseActive', { self.BaseName } },
                },
                PlatoonData = {
                    BaseName = self.BaseName,
                },
                PlatoonType = 'Land',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
                RequiresConstruction = false,
                LocationType = self.BaseName,
            }
            self.AIBrain:PBMAddPlatoon(defaultBuilder)
        end

        -- Transfer platoons - Engineers that are built by the base
        for i = 1, 3 do
            for j = 1, 5 do
                for num, pType in { 'Air', 'Land', 'Sea' } do
                    defaultBuilder = {
                        BuilderName = 'T' .. i .. 'BaseManagerEngineerDisband_' .. j .. 'Count_' .. self.BaseName,
                        --PlatoonAIPlan = 'DisbandAI',
                        PlatoonTemplate = self:CreateEngineerPlatoonTemplate(i, j),
                        Priority = 300 * i,
						PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerEngineerPlatoonSplit' },
                        PlatoonType = pType,
                        RequiresConstruction = true,
                        LocationType = self.BaseName,
                        PlatoonData = {
                            NumBuilding = j,
                            BaseName = self.BaseName,
                        },
                        BuildConditions = {
                            { BMBC, 'BaseEngineersEnabled', { self.BaseName } },
                            { BMBC, 'BaseBuildingEngineers', { self.BaseName } },
                            { BMBC, 'HighestFactoryLevel', { i, self.BaseName } },
                            { BMBC, 'FactoryCountAndNeed', { i, j, pType, self.BaseName } },
                            { BMBC, 'BaseActive', { self.BaseName } },
                        },
                        PlatoonBuildCallbacks = { { BMBC, 'BaseManagerEngineersStarted' }, },
                        InstanceCount = 1,
                        BuildTimeOut = 5, -- Timeout really fast because they dont need to really finish
                    }
                    self.AIBrain:PBMAddPlatoon(defaultBuilder)
                end
            end
        end
    end,
	
	---@param self BaseManager
    LoadDefaultBaseCDRs = function(self)
        -- CDR Build
        local defaultBuilder = {
            BuilderName = 'BaseManager_CDRPlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateCommanderPlatoonTemplate(),
            Priority = 1,
            PlatoonType = 'Gate',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAddFunctions = {
                -- {'/lua/ai/opai/OpBehaviors.lua', 'CDROverchargeBehavior'}, -- TODO: Re-add once it doesnt interfere with BM engineer thread
				{ BMPT, 'EnableCDRAutoOvercharge'}, -- Enables auto-overcharge for ACUs
                { BMPT, 'UnitUpgradeBehavior' },
            },
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerSingleEngineerPlatoon' },
            BuildConditions = {
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,

    ---@param self BaseManager
    LoadDefaultBaseSupportCDRs = function(self)
        -- sCDR Build
        local defaultBuilder = {
            BuilderName = 'BaseManager_sCDRPlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateSupportCommanderPlatoonTemplate(),
            Priority = 1,
            PlatoonType = 'Gate',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAddFunctions = {
                { BMPT, 'UnitUpgradeBehavior' },
            },
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerSingleEngineerPlatoon' },
            BuildConditions = {
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)

        -- Disband platoon
        defaultBuilder = {
            BuilderName = 'BaseManager_sACUDisband_' .. self.BaseName,
            PlatoonAIPlan = 'DisbandAI',
            PlatoonTemplate = self:CreateSupportCommanderPlatoonTemplate(),
            Priority = 900,
            PlatoonType = 'Gate',
            RequiresConstruction = true,
            LocationType = self.BaseName,
            BuildConditions = {
                { BMBC, 'BaseEngineersEnabled', { self.BaseName } },
                { BMBC, 'NumUnitsLessNearBase',
                    { self.BaseName, ParseEntityCategory('SUBCOMMANDER'), self.BaseName .. '_sACUNumber' } },
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            InstanceCount = 1,
            BuildTimeOut = 5, -- Timeout really fast because they dont need to really finish
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,
	
	---@param self BaseManager
    LoadDefaultScoutingPlatoons = function(self)
        -- Land Scouts
        local defaultBuilder = {
            BuilderName = 'BaseManager_LandScout_' .. self.BaseName,
            PlatoonTemplate = self:CreateLandScoutPlatoon(),
            Priority = 500,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerScoutingAI' },
            BuildConditions = {
                { BMBC, 'LandScoutingEnabled', { self.BaseName, } },
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
            PlatoonType = 'Land',
            RequiresConstruction = true,
            LocationType = self.BaseName,
            InstanceCount = 1,
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)

        -- T1 Air Scouts
        defaultBuilder = {
            BuilderName = 'BaseManager_T1AirScout_' .. self.BaseName,
            PlatoonTemplate = self:CreateAirScoutPlatoon(1),
            Priority = 500,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerScoutingAI' },
            BuildConditions = {
                { BMBC, 'HighestFactoryLevelType', { 1, self.BaseName, 'Air' } },
                { BMBC, 'AirScoutingEnabled', { self.BaseName, } },
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
            PlatoonType = 'Air',
            RequiresConstruction = true,
            LocationType = self.BaseName,
            InstanceCount = 1,
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)

        -- T3 Air Scouts
        defaultBuilder = {
            BuilderName = 'BaseManager_T3AirScout_' .. self.BaseName,
            PlatoonTemplate = self:CreateAirScoutPlatoon(3),
            Priority = 1000,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerScoutingAI' },
            BuildConditions = {
                { BMBC, 'HighestFactoryLevelType', { 3, self.BaseName, 'Air' } },
                { BMBC, 'AirScoutingEnabled', { self.BaseName, } },
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
            PlatoonType = 'Air',
            RequiresConstruction = true,
            LocationType = self.BaseName,
            InstanceCount = 1,
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,
	
	 ---@param self BaseManager
    LoadDefaultBaseTMLs = function(self)
        local defaultBuilder = {
            BuilderName = 'BaseManager_TMLPlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateTMLPlatoonTemplate(),
            Priority = 300,
            PlatoonType = 'Land',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerTMLPlatoon' },
            BuildConditions = {
                { BMBC, 'BaseActive', { self.BaseName } },
                { BMBC, 'TMLsEnabled', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,

    ---@param self BaseManager
    LoadDefaultBaseNukes = function(self)
        local defaultBuilder = {
            BuilderName = 'BaseManager_NukePlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateNukePlatoonTemplate(),
            Priority = 400,
            PlatoonType = 'Land',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerNukePlatoon' },
            BuildConditions = {
                { BMBC, 'BaseActive', { self.BaseName } },
                { BMBC, 'NukesEnabled', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,
	
	---@param self BaseManager
    LoadDefaultBaseTransports = function(self)
        local faction = self.AIBrain:GetFactionIndex()
		local factionName = Factions[faction].Key
		
        for tech = 1, 2 do
            self.AIBrain:PBMAddPlatoon {
                BuilderName = 'BaseManager_TransportPlatoon_' .. self.BaseName .. factionName .. tech,
                PlatoonTemplate = self:CreateTransportPlatoonTemplate(tech, faction),
                Priority = 200 * tech,
                PlatoonType = 'Air',
                RequiresConstruction = true,
                LocationType = self.BaseName,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'TransportPool' },
                BuildConditions = {
                    { BMBC, 'TransportsEnabled', { self.BaseName } },
                    { BMBC, 'TransportsTechAllowed', { self.BaseName, tech } },
                    { BMBC, 'NeedTransports', { self.BaseName } },
                },
                PlatoonData = {
                    BaseName = self.BaseName,
                },
            }
        end
        if faction ~= 1 then return end
        self.AIBrain:PBMAddPlatoon {
            BuilderName = 'BaseManager_TransportPlatoon_' .. self.BaseName .. "UEF3",
            PlatoonTemplate = {
                'TransportTemplate',
                'NoPlan',
                { "xea0306", -1, 1, 'Attack', 'None' },
            },
            Priority = 600,
            PlatoonType = 'Air',
            RequiresConstruction = true,
            LocationType = self.BaseName,
            PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'TransportPool' },
            BuildConditions = {
                { BMBC, 'TransportsEnabled', { self.BaseName } },
                { BMBC, 'TransportsTechAllowed', { self.BaseName, 3 } },
                { BMBC, 'NeedTransports', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
    end,
	
	--- Note: When the platoon template's individual unit number's required minimum is *-1*, the PBM will automatically build as many factories are capable of building the unit in a base.
	--- In the below case, if the base has 6 Land Factories, the PBM will build 6 T1 Land Scounts
	---@param self BaseManager
    ---@return any
    CreateLandScoutPlatoon = function(self)
        local faction = self.AIBrain:GetFactionIndex()
        local template = {
            'LandScoutTemplate',
            'NoPlan',
            { 'uel0101', -1, 1, 'Scout', 'None' },
        }
        template = ScenarioUtils.FactionConvert(template, faction)

        return template
    end,
	
	
	--- Note: When the platoon template's individual unit number's required minimum is *-1*, the PBM will automatically build as many factories are capable of building the unit in a base.
	--- In the below case, if the base has 6 T3 Air Factories, the PBM will build 6 T3 Air Scouts
	---@param self BaseManager
    ---@param techLevel number
    ---@return any
    CreateAirScoutPlatoon = function(self, techLevel)
        local faction = self.AIBrain:GetFactionIndex()
        local template = {
            'AirScoutTemplate',
            'NoPlan',
            { 'uea', -1, 1, 'Scout', 'None' },
        }

        if techLevel == 3 then
            template[3][1] = template[3][1] .. '0302'
        else
            template[3][1] = template[3][1] .. '0101'
        end

        template = ScenarioUtils.FactionConvert(template, faction)

        return template
    end,
	
	--- Note: When the platoon template's individual unit number's required minimum is *-1*, the PBM will automatically build as many factories are capable of building the unit in a base.
	--- In the below case, if the base has 6 T3 Air Factories, the PBM will build 6 Transports
	---@param self BaseManager
	---@param techLevel number
	---@param faction number
    CreateTransportPlatoonTemplate = function(self, techLevel, faction)
        faction = faction or self.AIBrain:GetFactionIndex()
        local template = {
            'TransportTemplate',
            'NoPlan',
            {'uea', -1, 1, 'Attack', 'None'},
        }
        if techLevel == 1 then
            template[3][1] = template[3][1] .. '0107'
        elseif techLevel == 2 then
            template[3][1] = template[3][1] .. '0104'
        end
        template = ScenarioUtils.FactionConvert(template, faction)
        return template
    end,
}