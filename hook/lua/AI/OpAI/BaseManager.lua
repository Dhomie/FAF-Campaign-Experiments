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
        local upgradeTable = false
        if unitType then
            upgradeTable = self.UnitUpgrades[unitType]
        else
            upgradeTable = self.UnitUpgrades[unit.UnitName]
        end

        if not upgradeTable then
            return false
        end

        local allEnhancements = unit:GetBlueprint().Enhancements
        if not allEnhancements then
            return false
        end
			
        for _, upgradeName in upgradeTable do
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

    UpgradeCheckThread = function(self)
        local armyIndex = self.AIBrain:GetArmyIndex()
        while true do
            if self.Active then
                for k, v in self.UpgradeTable do
                    local unit = ScenarioInfo.UnitNames[armyIndex][v.UnitName]
                    if unit and not unit.Dead then
						-- Structure upgrading should take priority, so the check for unit.UnitBeingBuilt is not needed. This check is a lot more reliable to get factories to upgrade
						if unit.UnitId ~= v.FinalUnit and not unit:IsBeingBuilt() and not unit:IsUnitState('Upgrading') then
                            self:ForkThread(self.BaseManagerUpgrade, unit, v.UnitName)
                        end
                    end
                end
            end
            local waitTime = Random(2, 4)
            WaitSeconds(waitTime)
        end
    end,

    -- Spawns a group, tracks number of times it has been built, gives nuke and anti-nukes ammo
    SpawnGroup = function(self, groupName, uncapturable, balance)
        local unitGroup = ScenarioUtils.CreateArmyGroup(self.AIBrain.Name, groupName, nil, balance)

        for _, v in unitGroup do
            if self.FactoryBuildRateBuff then
                Buff.ApplyBuff(v, self.FactoryBuildRateBuff)
            end
            if self.EngineerBuildRateBuff then
                Buff.ApplyBuff(v, self.EngineerBuildRateBuff)
            end
            if uncapturable then
                v:SetCapturable(false)
                v:SetReclaimable(false)
            end
            if EntityCategoryContains(categories.SILO, v) then
                v:GiveNukeSiloAmmo(1) --was 2, messes up platoon.NukeAI(self)
                v:GiveTacticalSiloAmmo(1) --was 2, messes up platoon.NukeAI(self)
            end
        end
    end,

    BuildingCounterDifficultyDefault = function(self, buildingType)
        local diff = ScenarioInfo.Options.Difficulty or 1

        return BuildingCounterDefaultValues[diff].Default
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
    LoadDefaultBaseTMLs = function(self)
        local defaultBuilder = {
            BuilderName = 'BaseManager_TMLPlatoon_' .. self.BaseName,
            PlatoonTemplate = self:CreateTMLPlatoonTemplate(),
            Priority = 300,
            PlatoonType = 'Any',
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
            PlatoonType = 'Any',
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
