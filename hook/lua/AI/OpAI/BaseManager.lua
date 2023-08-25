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
---		- TMLs and SMLs only receive 1 ammo after spawning
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

---@class BaseManager
---@field Trash TrashBag
---@field AIBrain AIBrain
BaseManager = Class(BaseManagerTemplate) {
	--- Introduces all the relevant fields to the base manager, internally called by the engine
    ---@param self BaseManager      # An instance of the BaseManager class
    ---@return nil
    Create = function(self)
		BaseManagerTemplate.Create(self)
		
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
	
	--- Thread that will upgrade factories, radar, etc. to next level
	--- Recoded to handle most common cases of unexpected situations (including players switching to the AI army and messing up the orders given to it)
    ---@param self BaseManager
    ---@param unit Unit
    ---@param unitName string
    BaseManagerUpgrade = function(self, unit, unitName)
	
		-- If we're already upgrading, or we got told to upgrade, but we are currently building something else, return
		if unit:IsUnitState('Upgrading') or (unit.SetToUpgrade and not unit:IsIdleState()) then
			return
		end
		
        local aiBrain = unit:GetAIBrain()
        local factionIndex = aiBrain:GetFactionIndex()
        local armyIndex = aiBrain:GetArmyIndex()
        local upgradeID = aiBrain:FindUpgradeBP(unit.UnitId, UpgradeTemplates.StructureUpgradeTemplates[factionIndex])
		
        if upgradeID then
            IssueUpgrade({unit}, upgradeID)
			-- Set the unit as upgrading, in case we got units to build before the upgrade command
			unit.SetToUpgrade = true
        else
			WARN('Structure upgrade thread for ' .. repr(unitName) .. ' aborted, couldn\'t find a valid upgrade ID!')
			return
		end
		
		-- Wait until the structure has finished building everything else
		while not unit.Dead and unit.UnitBeingBuilt and unit.UnitBeingBuilt.UnitId ~= upgradeID do
			WaitSeconds(3)
			SPEW('Structure waiting for unit being built ID to finish before upgrading: ' .. repr(unit.UnitBeingBuilt.UnitId))
		end
		
        local upgrading = true
        local newUnit = false
		
		-- While the unit exists, it's upgrading, only update the ScenarioInfo.UnitNames data if the upgrade finishes, and the new unit is the upgraded structure
        while not unit.Dead and upgrading do
			SPEW('Structure upgrade thread for ' .. repr(unitName) .. ' is running.')
            WaitSeconds(3)
			
            upgrading = false
			-- The original unit still exists, we haven't finished upgrading yet
            if unit and not unit.Dead then
				-- If we are not upgrading, and aren't under construction, return
				if not unit:IsUnitState('Upgrading') and not unit:IsBeingBuilt() then
					WARN('Structure upgrade thread for ' .. repr(unitName) .. ' aborted, unit isn\'t upgrading!')
					unit.SetToUpgrade = nil
					return
				end
				
				-- The upgrade might have been interrupted, (the new unit died, or got deleted), update newUnit as needed
                if not newUnit or newUnit.Dead then
					-- Make sure the current unit being built is the upgrade we want, we might have new build orders after our (interrupted) upgrade
					if unit.UnitBeingBuilt.UnitId == upgradeID then
						newUnit = unit.UnitBeingBuilt
					end
                end
                upgrading = true
            end
        end
		-- At this point the upgrade should be finished, update ScenarioInfo.UnitNames
        ScenarioInfo.UnitNames[armyIndex][unitName] = newUnit
		SPEW('Structure upgrade thread finished for: ' .. repr(unitName))
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
        for tech = 1, 2 do
            local factionName = Factions[faction].Key
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
                { "xea0306", 1, 2, 'Attack', 'None' },
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
	---@param techLevel number
	---@param faction number
    CreateTransportPlatoonTemplate = function(self, techLevel, faction)
        faction = faction or self.AIBrain:GetFactionIndex()
        local template = {
            'TransportTemplate',
            'NoPlan',
            { 'uea', 1, 3, 'Attack', 'None' },
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
