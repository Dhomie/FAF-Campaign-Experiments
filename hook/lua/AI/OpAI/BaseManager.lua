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
		
		-- Add needed data to track Support Armored Command Units
		self.SupportACUQuantity = 1
		self.CurrentSupportACUCount = 0
		self.SupportACUsBuilding = 0
		
		-- Default to no transports needed
		self.TransportsNeeded = 0
		self.TransportsTech = 1
		
		-- Commented out unused states
		self.FunctionalityStates = {
            AirScouting = false,
            AntiAir = true,
            Artillery = true,
            BuildEngineers = true,
			BuildSupportACUs = true,
            CounterIntel = true,
            Engineers = true,
            ExpansionBases = false,
            Fabrication = true,
            GroundDefense = true,
            Intel = true,
            LandScouting = false,
            Nukes = false,
            Patrolling = true,
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
	---@param self BaseManager
    ---@param buildingType string
    BuildingCounterDifficultyDefault = function(self, buildingType)
        return -1
    end,
	
	
	--- Retrieves the Engineer blueprint ID of the given tech level
	--- In case of modded factions and units, the retrival will default to the T1 UEF Engineer
	---@param self BaseManager
    ---@param techLevel Integer
	---@return String
	GetEngineerBlueprintID = function (self, techLevel)
		-- Default to T1 UEF starting prefix
		local FactionIndex = self.AIBrain:GetFactionIndex()
		local IDPrefix = 'ue'
		local IDNumbers = '0105'
		
		if FactionIndex == 2 then
			IDPrefix = 'ua'
		elseif FactionIndex == 3 then
			IDPrefix 'ur'
		elseif FactionIndex == 4 then
			IDPrefix = 'xs'
		end
		
		if techLevel == 2 then
			IDNumbers = '0208'
		elseif techlevel == 3 then
			IDNumbers = '0309'
		end
		
		-- Combine the 2 together and return it
		return IDPrefix .. IDNumbers
	end,
	
	--- Add to the sACU count, useful when gifting the base sACUs.
    ---@param self BaseManager  # An instance of the BaseManager class
    ---@param num integer       # Amount to add to the engineer count.
    AddCurrentSupportACU = function(self, num)
        self.CurrentSupportACUCount = self.CurrentSupportACUCount + (num or 1)
    end,

    --- Subtract from the sACU count
    ---@param self BaseManager  # An instance of the BaseManager class
    ---@param num integer       # Amount to subtract from the engineer count.
    SubtractCurrentSupportACU = function(self, num)
        self.CurrentSupportACUCount = self.CurrentSupportACUCount - (num or 1)
    end,

    --- Retrieve the sACU count
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return integer              # Number of active engineers
    GetCurrentSupportACUCount = function(self)
        return self.CurrentSupportACUCount
    end,

    --- Retrieve the maximum number of sACUs, the base manager won't build more engineers than this
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return integer              # Maximum number of engineers for this base manager
    GetMaximumSupportACUs = function(self)
        return self.SupportACUQuantity
    end,
	
	--- Retrieves the amount of sACUs that are building
	--- This variable is normally not updated if the sACUs are killed BEFORE they could be formed into platoons (ie.: during roloff, construction)
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return integer              # Amount of engineers that are building
    GetSupportACUsBuilding = function(self)		
		return self.SupportACUsBuilding
    end,
	
	--- Adds or subtracts from the number of sACUs that are building
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@param count integer         # Amount to add or subtract
    SetSupportACUsBuilding = function(self, count)
		self.SupportACUsBuilding = self.SupportACUsBuilding + count
    end,
	
	--- Defines the number of support command units this base manager should maintain
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@param count number          # Number of support command units
    SetSupportACUCount = function(self, count)
		self.SupportACUQuantity = count
        ScenarioInfo.VarTable[self.BaseName .. '_sACUNumber'] = count
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
	
	--- Checks if the base has higher tier factories compared to param techLevel
	--- Can return false positives if unit restrictions are applied
	---@param self BaseManager
    ---@param unitType String
    ---@return boolean
	CanUpgradeEngineers = function(self, techLevel)
		
	end,
	
	--- Determines if a specific unit needs upgrades, returns name of upgrade if needed
    --- Works with up to 3-level enhancement paths
    --- TODO: Make a check that can deal with any number of prerequisites, like a 4-5-6 level enhancement path, example: ('Shield -> 'ShieldHeavy' -> 'ShieldVeryHeavy' ->'ShieldUltraHeavy' -> 'ShieldUltraBigHeavy')
    ---@param self BaseManager
    ---@param unit Unit
    ---@param unitType string
    ---@return string|boolean
    UnitNeedsUpgrade = function(self, unit, unitType)
        if unit.Dead then
            return false
        end

        -- Find appropriate data about unit upgrade info
		local key = unitType or unit.UnitName
        local upgradeTable = self.UnitUpgrades[key]

        if not upgradeTable then
            return false
        end

        local allEnhancements = unit.Blueprint.Enhancements
        if not allEnhancements then
            return false
        end
			
        for index, upgradeName in upgradeTable do
            -- Find the upgrade in the unit's bp
            local bpUpgrade = allEnhancements[upgradeName]
            if bpUpgrade then
                if not unit:HasEnhancement(upgradeName) then
                    -- Check if we already have an enhancement on the slot our desired enhancement wants to occupy
                    if SimUnitEnhancements and SimUnitEnhancements[unit.EntityId] and SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] then
                        -- Account for 3-level enhancements, like the Cybran ACU's recent *Stealth -> Self-Repair -> Cloak* enhancement path, if we want 'Cloak', check for 'Stealth' 
                        -- Check for the prerequisite's prerequisite, and return it
                        if bpUpgrade.Prerequisite and allEnhancements[bpUpgrade.Prerequisite].Prerequisite and (SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] == allEnhancements[bpUpgrade.Prerequisite].Prerequisite) then
                            return bpUpgrade.Prerequisite
                        -- If it's a direct prerequisite enhancement, return upgrade name
                        elseif bpUpgrade.Prerequisite and (SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] == bpUpgrade.Prerequisite) then
                            return upgradeName
                        -- It's not a prerequisite, remove the enhancement
                        else
                            return SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] .. 'Remove'
                        end
                    -- Check if our desired enhancement's prerequisite has any prerequisites, and return its name (Prerequisiteception)
                    elseif bpUpgrade.Prerequisite and allEnhancements[bpUpgrade.Prerequisite].Prerequisite and not unit:HasEnhancement(allEnhancements[bpUpgrade.Prerequisite].Prerequisite) then
                        return allEnhancements[bpUpgrade.Prerequisite].Prerequisite
                    -- Check if our desired enhancement has any prerequisites, and return its name
                    elseif bpUpgrade.Prerequisite and not unit:HasEnhancement(bpUpgrade.Prerequisite) then
                        return bpUpgrade.Prerequisite
                    -- No requirement and no enhancement occupying our desired slot, return the upgrade name
                    else
                        return upgradeName
                    end
                end
            else
                error('*Base Manager Error: ' .. self.BaseName .. ', enhancement: ' .. upgradeName .. ' was not found in the unit\'s bp.')
            end
        end

        return false
    end,
	
	--- General purpose failsafe thread that will periodically perform certain actions
	--- It will periodically loop through existing units that have been converted to lower tech level units so they can be built (ie. HQ factories)
	--- If their unit IDs don't match the one set in the save.lua file, a failsafe function will be called to check if they are idle, so an upgrade can be started
	--- Also contains a check that will periodically reduce the amount of Engineers and sACUs being built by 1 if we can't detect any queued one
	--- This is related to a bug where if the Engineers are killed during rolloff (before their platoons are formed), the AI won't reduce the EngineersBuilding attribute
	--- You can practically cheese a base out of its Engineers via this over time, as the base will think it has Engineers under construction, while that is not the case
	---@param self BaseManager
    UpgradeCheckThread = function(self)
        local armyIndex = self.AIBrain:GetArmyIndex()
        while true do
		
            if self.Active then
				-- Engineer count failsafe
				local Factories = self:GetAllBaseFactories()
				local BuildOrdersExist = nil
		
				-- Check if we have at least 1 busy factory with an engineering unit
				for Index, Factory in Factories do
					if not Factory.Dead and Factory:GetNumBuildOrders(categories.ENGINEER) > 0 then
						BuildOrdersExist = true
						break
					end
				end
	
				-- If there are no busy factories, and the variable is at least 1, reduce the variable by 1
				-- We can safely assume there are no engineers/sACUs under construction
				if not BuildOrdersExist then
					if self.EngineersBuilding > 0 then
						self.EngineersBuilding = self.EngineersBuilding - 1
					end
					
					if self.SupportACUsBuilding > 0 then
						self.SupportACUsBuilding = self.SupportACUsBuilding - 1
					end
				end
				
			
				-- Upgrade failsafe loop
                for k, v in self.UpgradeTable do
                    local unit = ScenarioInfo.UnitNames[armyIndex][v.UnitName]
					-- Check if the structure exists, and needs to upgrade
                    if unit and not unit.Dead and unit.UnitId ~= v.FinalUnit then
                        --self:ForkThread(self.BaseManagerUpgrade, unit, v.UnitName)
						self:BaseManagerUpgrade(unit, v.UnitName)
                    end
                end
            end
            WaitSeconds(10)
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
	
	BuildFunctions = {
        BuildEngineers = function(self, val)
            self.FunctionalityStates.BuildEngineers = val
        end,
		
		BuildSupportACUs = function(self, val)
			self.FunctionalityStates.BuildSupportACUs = val
		end,

        BuildAntiAir = function(self, val)
            self.BuildTable['T1AADefense'] = val
            self.BuildTable['T2AADefense'] = val
            self.BuildTable['T3AADefense'] = val
        end,

        BuildGroundDefense = function(self, val)
            self.BuildTable['T1GroundDefense'] = val
            self.BuildTable['T2GroundDefense'] = val
            self.BuildTable['T3GroundDefense'] = val
        end,

        BuildTorpedo = function(self, val)
            self.BuildTable['T1NavalDefense'] = val
            self.BuildTable['T2NavalDefense'] = val
            self.BuildTable['T3NavalDefense'] = val
        end,

        BuildAirFactories = function(self, val)
            self.BuildTable['T1AirFactory'] = val
            self.BuildTable['T2AirFactory'] = val
            self.BuildTable['T3AirFactory'] = val
        end,

        BuildLandFactories = function(self, val)
            self.BuildTable['T1LandFactory'] = val
            self.BuildTable['T2LandFactory'] = val
            self.BuildTable['T3LandFactory'] = val
        end,

        BuildSeaFactories = function(self, val)
            self.BuildTable['T1Seafactory'] = val
            self.BuildTable['T2Seafactory'] = val
            self.BuildTable['T3Seafactory'] = val
        end,

        BuildFactories = function(self, val)
            self.BuildFunctions['BuildAirFactories'](self, val)
            self.BuildFunctions['BuildSeaFactories'](self, val)
            self.BuildFunctions['BuildLandFactories'](self, val)
        end,

        BuildMissileDefense = function(self, val)
            self.BuildTable['T1StrategicMissileDefense'] = val
            self.BuildTable['T2StrategicMissileDefense'] = val
            self.BuildTable['T3StrategicMissileDefense'] = val
            self.BuildTable['T1MissileDefense'] = val
            self.BuildTable['T2MissileDefense'] = val
            self.BuildTable['T3MissileDefense'] = val
        end,

        BuildShields = function(self, val)
            self.BuildTable['T3ShieldDefense'] = val
            self.BuildTable['T2ShieldDefense'] = val
            self.BuildTable['T1ShieldDefense'] = val
        end,

        BuildArtillery = function(self, val)
            self.BuildTable['T3Artillery'] = val
            self.BuildTable['T2Artillery'] = val
            self.BuildTable['T1Artillery'] = val
        end,

        BuildExperimentals = function(self, val)
            self.BuildTable['T4LandExperimental1'] = val
            self.BuildTable['T4LandExperimental2'] = val
            self.BuildTable['T4AirExperimental1'] = val
            self.BuildTable['T4SeaExperimental1'] = val
        end,

        BuildWalls = function(self, val)
            self.BuildTable['Wall'] = val
        end,

        BuildDefenses = function(self, val)
            self.BuildFunctions['BuildAntiAir'](self, val)
            self.BuildFunctions['BuildGroundDefense'](self, val)
            self.BuildFunctions['BuildTorpedo'](self, val)
            self.BuildFunctions['BuildArtillery'](self, val)
            self.BuildFunctions['BuildShields'](self, val)
            self.BuildFunctions['BuildWalls'](self, val)
        end,

        BuildJammers = function(self, val)
            self.BuildTable['T1RadarJammer'] = val
            self.BuildTable['T2RadarJammer'] = val
            self.BuildTable['T3RadarJammer'] = val
        end,

        BuildRadar = function(self, val)
            self.BuildTable['T3Radar'] = val
            self.BuildTable['T2Radar'] = val
            self.BuildTable['T1Radar'] = val
        end,

        BuildSonar = function(self, val)
            self.BuildTable['T3Sonar'] = val
            self.BuildTable['T2Sonar'] = val
            self.BuildTable['T1Sonar'] = val
        end,

        BuildIntel = function(self, val)
            self.BuildFunctions['BuildSonar'](self, val)
            self.BuildFunctions['BuildRadar'](self, val)
            self.BuildFunctions['BuildJammers'](self, val)
        end,

        BuildMissiles = function(self, val)
            self.BuildTable['T3StrategicMissile'] = val
            self.BuildTable['T2StrategicMissile'] = val
            self.BuildTable['T1StrategicMissile'] = val
        end,

        BuildFabrication = function(self, val)
            self.BuildTable['T3MassCreation'] = val
            self.BuildTable['T2MassCreation'] = val
            self.BuildTable['T1MassCreation'] = val
        end,

        BuildAirStaging = function(self, val)
            self.BuildTable['T1AirStagingPlatform'] = val
            self.BuildTable['T2AirStagingPlatform'] = val
            self.BuildTable['T3AirStagingPlatform'] = val
        end,

        BuildMassExtraction = function(self, val)
            self.BuildTable['T1Resource'] = val
            self.BuildTable['T2Resource'] = val
            self.BuildTable['T3Resource'] = val
        end,

        BuildEnergyProduction = function(self, val)
            self.BuildTable['T1EnergyProduction'] = val
            self.BuildTable['T2EnergyProduction'] = val
            self.BuildTable['T3EnergyProduction'] = val
            self.BuildTable['T1HydroCarbon'] = val
            self.BuildTable['T2HydroCarbon'] = val
            self.BuildTable['T3HydroCarbon'] = val
        end,

        BuildStorage = function(self, val)
            self.BuildTable['MassStorage'] = val
            self.BuildTable['EnergyStorage'] = val
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
                Priority = 600 * i,
                PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerEngineerPlatoonSplit' },
                BuildConditions = {
                    { BMBC, 'BaseManagerNeedsEngineers', { self.BaseName } },
                    { BMBC, 'BaseActive', { self.BaseName } },
                },
                PlatoonData = {
                    BaseName = self.BaseName,
                },
				PlatoonAddFunctions = {
					{ BMPT, 'EngineerUpgradeBehavior' }
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
                        PlatoonAIPlan = 'DisbandAI',
                        PlatoonTemplate = self:CreateEngineerPlatoonTemplate(i, j),
                        Priority = 500 * i,
						--PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerEngineerPlatoonSplit' },
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
                        BuildTimeOut = 60, -- Increased timeout from 5 to 60, to avoid Engineers cluttering up in bases
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
            Priority = 5,
            PlatoonType = 'Gate',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAddFunctions = {
				{ BMPT, 'EnableCDRAutoOvercharge'}, -- Enables auto-overcharge for ACUs
            },
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerSingleACUPlatoon' },
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
            PlatoonTemplate = self:CreateSupportCommanderPlatoonTemplate(3),
            Priority = 5,
            PlatoonType = 'Gate',	-- Don't use 'Any', these don't need to be built, and we don't need to add this builder to ALL 3 major factory types
            RequiresConstruction = false,
            LocationType = self.BaseName,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerSupportACUPlatoonSplit' },
            BuildConditions = {
                { BMBC, 'BaseActive', { self.BaseName } },
				{ BMBC, 'BaseManagerNeedsSupportACUs', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)

        -- Disband platoon
		for i = 1, 3 do
			defaultBuilder = {
				BuilderName = 'BaseManager_sCDRDisband_' .. i .. '_' .. self.BaseName,
				PlatoonAIPlan = 'DisbandAI',
				PlatoonTemplate = self:CreateSupportCommanderPlatoonTemplate(i),
				Priority = 500 * i,
				PlatoonType = 'Gate',
				RequiresConstruction = true,
				LocationType = self.BaseName,
				BuildConditions = {
					{ BMBC, 'BaseEngineersEnabled', { self.BaseName } },
					{ BMBC, 'BaseActive', { self.BaseName } },
					{ BMBC, 'BaseManagerFunctionalityEnabled', { self.BaseName, 'BuildSupportACUs' } },
					{ BMBC, 'GateCountAndNeed', { i, self.BaseName } },
					{ BMBC, 'BaseActive', { self.BaseName } },
				},
				BuildTimeOut = 5, -- Timeout really fast because they dont need to really finish
				PlatoonData = {
                    NumBuilding = i,
                    BaseName = self.BaseName,
                },
				PlatoonBuildCallbacks = { { BMBC, 'BaseManagerSupportACUsStarted' }, },
			}
			self.AIBrain:PBMAddPlatoon(defaultBuilder)
		end
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
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)

        -- T1 Air Scouts
        defaultBuilder = {
            BuilderName = 'BaseManager_T1AirScout_' .. self.BaseName,
            PlatoonTemplate = self:CreateAirScoutPlatoon(1),
            Priority = 500,
            PlatoonAIFunction = { '/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerScoutingAI' },
            BuildConditions = {
                { BMBC, 'HighestFactoryLevelTypeLessOrEqual', { 2, self.BaseName, 'Air' } },	-- Build them if we either have up to T2, or T1 Air Factories
                { BMBC, 'AirScoutingEnabled', { self.BaseName, } },
                { BMBC, 'BaseActive', { self.BaseName } },
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
            PlatoonType = 'Air',
            RequiresConstruction = true,
            LocationType = self.BaseName,
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
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
    end,

	---@param self BaseManager
    LoadDefaultBaseTMLs = function(self)
        local defaultBuilder = {
            BuilderName = 'BaseManager_TMLPlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateTMLPlatoonTemplate(),
            Priority = 5,
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
            Priority = 5,
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
	
	---@param self BaseManager
    ---@return any
    CreateSupportCommanderPlatoonTemplate = function(self, platoonSize)
		local size = platoonSize or 1
        local faction = self.AIBrain:GetFactionIndex()
        local template = {
            'CommanderTemplate',
            'NoPlan',
            { 'uel0301', 1, size, 'Support', 'None' },
        }
        template = ScenarioUtils.FactionConvert(template, faction)

        return template
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

--- WIP, a different approach for the default Base Manager module, it's meant to build structures dynamically as per specified amounts, with no static base template defined
AdvancedBaseManager = Class(BaseManager) {
	Create = function(self)
		
	end,
	
	Initialize = function(self, brain, baseName, markerName, radius, baseTable)
		self.DesiredStructures = {
			
		}
		self.Structures = {
			--T3Resource = 0,			-- T3 Mex
			--T2Resource = 0,			-- T2 Mex
			T1Resource = 0,				-- T1 Mex
			T3EnergyProduction = 0,
			T2EnergyProduction = 0,
			T1EnergyProduction = 0,
			T1HydroCarbon = 0,
			T3MassCreation = 0,			-- T3 Mass Fabricator
			T1MassCreation = 0,			-- T2 Mass Fabricator, this is a legacy naming from SC1, which wasn't changed to avoid coding issues
			T2EngineerSupport = 0,		-- T2 Engineering Station
			T3SupportLandFactory = 0,
			T3SupportAirFactory = 0,	
			T3SupportSeaFactory = 0,	
			T2SupportLandFactory = 0,	
			T2SupportAirFactory = 0,	
			T2SupportSeaFactory = 0,	
			T1LandFactory = 0,			
			T1AirFactory = 0,
			T1SeaFactory = 0,
			--T3ShieldDefense = 0,
			T2ShieldDefense = 0,
			T2StrategicMissile = 0,		-- TML
			T3StrategicMissile = 0,		-- SML
			T3StrategicMissileDefense = 0,
			--T3Radar = 0,
			--T2Radar = 0,
			T1Radar = 0,
			--T3Sonar = 0,
			--T2Sonar = 0,
			T1Sonar = 0,
			T2AirStagingPlatform = 0,
			T3AADefense = 0,
			T2AADefense = 0,
			T1AADefense = 0,
			T3GroundDefense = 0,
			T2GroundDefense = 0, 
			T1GroundDefense = 0, 
			T3NavalDefense = 0,
			T2NavalDefense = 0,
			T1NavalDefense = 0,
			T2MissileDefense = 0,
			Wall = 0,
			
			-- Experimentals, these usually default to a previous unit if no corresponding experimental exists
			T4LandExperimental1 = 0,	-- Fatboy, Galactic Colossus Monkeylord, Ythotha
			T4LandExperimental2 = 0,	-- Scathis
			T4LandExperimental3 = 0,	-- Megalith
			T4AirExperimental1 = 0,		-- Czar, Soulripper, Ahwassa
			T4SeaExperimental1 = 0,		-- Atlantis,
			T4EconExperimental = 0,		-- Paragon
			T3RapidArtillery = 0,		-- Aeon Experimental Artillery
		}
		
		self.StructureUpgrades = {
			T3Resource = 0,
			T2Resource = 0,
			T2LandFactory = 0,			
			T2AirFactory = 0,
			T2SeaFactory = 0,
			T3LandFactory = 0,			
			T3AirFactory = 0,
			T3SeaFactory = 0,
			T3ShieldDefense = 0,
			T3Radar = 0,
			T2Radar = 0,
			T3Sonar = 0,
			T2Sonar = 0,
		}
		
		self.Builders = {}
	end,
}