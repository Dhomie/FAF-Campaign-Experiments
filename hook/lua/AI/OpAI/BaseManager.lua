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
---		- TMLs and SMLs are now used if they are inside the radius of a base that has their functionalities enabled

local BaseManagerTemplate = BaseManager
local Factions = import('/lua/factions.lua').Factions

-- Default rebuild numbers for buildings based on type; -1 is infinite
local BuildingCounterDefaultValues = {
    -- Difficulty 1
    {
        Default = -1,
    },

    -- Difficulty 2
    {
        Default = -1,
    },

    -- Difficulty 3
    {
        Default = -1,
    },
}

--- Callback function when a structure marked for needing an upgrade starts building something
--- If that 'something' is and upgrade itself, create a callback for the upgrade
---@param@ unit Unit
---@param unitBeingBuilt Unit being constructed
function StructureOnStartBuild(unit, unitBeingBuilt)
	-- If we are in the upgrading state, then it's the upgrade we want under normal circumstances.
	-- We don't use different upgrades paths for coop, only that of the original SCFA (no Support Factory upgrade paths whatsoever)
	-- If you decide to mess around with AI armies in cheat mode, and order a newly added upgrade path instead anyway, then any mishaps happening afterwards is on you!
	if unit:IsUnitState('Upgrading') then
		--LOG('Structure building upgrade named: ' .. repr(unit.UnitName))
		unitBeingBuilt.BuildingUpgrade = true
		unitBeingBuilt.UnitName = unit.UnitName

		-- Add callback when the upgrade is finished
		if not unitBeingBuilt.AddedFinishedCallback then
			unitBeingBuilt:AddUnitCallback(UpgradeOnStopBeingBuilt, 'OnStopBeingBuilt')
			unitBeingBuilt.AddedFinishedCallback = true
		end
	end
end

--- Callback function when a (preferably) structure upgrade is finished building
--- Updates the ScenarioInfo.UnitNames table with the new unit
---@param unit Unit
function UpgradeOnStopBeingBuilt(unit)
	--LOG('Structure finished upgrade named: ' .. repr(unit.UnitName))
	ScenarioInfo.UnitNames[unit.Army][unit.UnitName] = unit
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
		
		self.FunctionalityStates = {
            AirAttacks = true,
            AirScouting = false,
            AntiAir = true,
            Artillery = true,
            BuildEngineers = true,
            CounterIntel = true,
            EngineerReclaiming = true,
            Engineers = true,
            ExpansionBases = false,
            Fabrication = true,
            GroundDefense = true,
            Intel = true,
            LandAttacks = true,
            LandScouting = false,
            Nukes = false,
            Patrolling = true,
            SeaAttacks = true,
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

    BuildingCounterDifficultyDefault = function(self, buildingType)
        local diff = ScenarioInfo.Options.Difficulty or 1

        return BuildingCounterDefaultValues[diff].Default
    end,
	
	---@param self BaseManager
    UpgradeCheckThread = function(self)
        local armyIndex = self.AIBrain:GetArmyIndex()
        while true do
            if self.Active then
                for k, v in self.UpgradeTable do
                    local unit = ScenarioInfo.UnitNames[armyIndex][v.UnitName]
                    if unit and not unit.Dead then
                        -- Check if the structure needs to upgrade
                        if unit.UnitId ~= v.FinalUnit then
                            self:ForkThread(self.BaseManagerUpgrade, unit, v.UnitName)
                        end
                    end
                end
            end
            WaitSeconds(5)
        end
    end,
	
	--- Function that will upgrade factories, radar, etc. to next level
	--- Recoded to use unit build callbacks instead of threads
	--- It should handle most common cases of unexpected situations (like players switching to the AI's army and messing up the orders given to it)
	--- The upgrade is added to the structure's build queue when it's first detected that it needs to upgrade
	--- If for some unexpected reason the upgrade didn't happen, and the unit is practically idle (guarding a factory and not building anything also counts as idle), then try again
    ---@param self BaseManager
    ---@param unit Unit
    ---@param unitName string
    BaseManagerUpgrade = function(self, unit, unitName)
		
		-- If we were set to upgrade, and we're busy building something, return
		-- A factory is practically idle when it's assisting another factory, and not building anything, in that case the unit is in the 'Guarding' state, and not the 'Idle' state
		--if unit.SetToUpgrade and ((unit:IsUnitState('Upgrading') or unit:IsUnitState('Building')) or (unit:IsUnitState('Guarding') and unit:IsUnitState('Building')) or unit:IsUnitState('AssistingCommander')) then
		if unit.SetToUpgrade and (unit:IsUnitState('Upgrading') or unit:IsUnitState('Building') or unit:IsUnitState('AssistingCommander')) then
			return
		end
		
		-- Safety check in case unit namings got messed up.
		-- We rely on the cached name on the unit itself to determine what unit exists or needs to exist from the map's save.lua file
		if not unit.UnitName or unit.UnitName ~= unitName then
			WARN('Overwriting either non-existant, or mismatching unit name for structure named: ' .. repr(UnitName))
			unit.UnitName = unitName
		end
		
		-- Add callback when the structure starts building something
		if not unit.AddedUpgradeCallback then
			unit:AddOnStartBuildCallback(StructureOnStartBuild)
			unit.AddedUpgradeCallback = true
		end
		
        local aiBrain = unit.Brain
        local factionIndex = aiBrain:GetFactionIndex()
        local upgradeID = aiBrain:FindUpgradeBP(unit.UnitId, UpgradeTemplates.StructureUpgradeTemplates[factionIndex])
		
        if upgradeID then
            IssueUpgrade({unit}, upgradeID)
			-- Set the unit as upgrading, in case we got units to build before the upgrade command
			unit.SetToUpgrade = true
        else
			WARN('Structure upgrade thread for ' .. repr(unitName) .. ' aborted, couldn\'t find a valid upgrade ID!')
			return
		end
		
		return
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
