---------------------------------------------------------------------------------------------
---- File     :	/lua/AI/OpAI/BaseManager.lua
---- Summary  : Base Manager edit for coop
---- Changelog: 	- Slight edit to Factory upgrade checks
----				- Shields and mexes now upgrade from their lowest available tech variants
----				- Rebuilds are infinite for all difficulties
----				- TMLs and SMLs only receive 1 ammo after spawning
---- Edited by: Dhomie42
---- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
---------------------------------------------------------------------------------------------

---@alias SaveFile "AirAttacks" | "AirScout" | "BasicLandAttack" | "BomberEscort" | "HeavyLandAttack" | "LandAssualt" | "LeftoverCleanup" | "LightAirAttack" | "NavalAttacks" | "NavalFleet"

-- types that originate from the map

---@class MarkerChain: string                   # Name reference to a marker chain as defined in the map
---@class Area: string                          # Name reference to a area as defined in the map
---@class Marker: string                        # Name reference to a marker as defined in the map
---@class UnitGroup: string                     # Name reference to a unit group as defined in the map

-- types commonly used in repository

---@class FileName: string
---@class FunctionName: string

---@class BuildCondition
---@field [1] FileName
---@field [2] FunctionName
---@field [3] any

---@class FileFunctionRef
---@field [1] FileName
---@field [2] FunctionName

---@class BuildGroup                       
---@field Name UnitGroup
---@field Priority number

-- types used by AddOpAI

---@class MasterPlatoonFunction
---@field [1] FileName
---@field [2] FunctionName

---@class PlatoonData
---@field TransportReturn Marker                # Location for transports to return to
---@field PatrolChains MarkerChain[]            # Selection of patrol chains to guide the constructed units
---@field PatrolChain MarkerChain               # Patrol chain to guide the construced units
---@field AttackChain MarkerChain               # Attack chain to guide the constructed units
---@field LandingChain MarkerChain              # Landing chain to guide the transports carrying the constructed units
---@field Area Area                             # An area, use depends on master platoon function
---@field Location Marker                       # A location, use depends on master platoon function

---@class AddOpAIData
---@field MasterPlatoonFunction FileFunctionRef     # Behavior of instances upon completion
---@field PlatoonData PlatoonData                   # Parameters of the master platoon function
---@field Priority number                           # Priority over other builders

-- types used by AddUnitAI

---@class AddUnitAIData                         
---@field Amount number                         # Number of engineers that can assist building
---@field KeepAlive boolean                     # ??
---@field BuildCondition BuildCondition[]       # Build conditions that must be met before building can start, can be empty
---@field PlatoonAIFunction FileFunctionRef     # A { file, function } reference to the platoon AI function
---@field MaxAssist number                      # Number of engineers that can assist construction
---@field Retry boolean                         # Flag that allows the AI to retry
---@field PlatoonData PlatoonData               # Parameters of the platoon AI function

local BaseManagerTemplate = import('/lua/ai/opai/basemanager.lua').BaseManager
local AIUtils = import('/lua/ai/aiutilities.lua')

local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')

local StructureTemplates = import("/lua/buildingtemplates.lua")
local UpgradeTemplates = import("/lua/upgradetemplates.lua")

local Buff = import('/lua/sim/Buff.lua')

local BaseOpAI = import('/lua/ai/opai/baseopai.lua')
local ReactiveAI = import('/lua/ai/opai/ReactiveAI.lua')
local NavalOpAI = import('/lua/ai/opai/NavalOpAI.lua')

local BMBC = '/lua/editor/BaseManagerBuildConditions.lua'
local BMPT = '/lua/ai/opai/BaseManagerPlatoonThreads.lua'

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
BaseManager = Class(BaseManagerTemplate)
{

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
        self.Active = true
        if self.Initialized then
            error('*AI ERROR: BaseManager named "' .. baseName .. '" has already been initialized', 2)
        end

        self.Initialized = true
        if not brain.BaseManagers then
            brain.BaseManagers = {}
            brain:PBMRemoveBuildLocation(false, 'MAIN') -- Remove main since we dont use it in ops much
        end

        brain.BaseManagers[baseName] = self -- Store base in table, index by name of base
        self.AIBrain = brain
        self.Position = ScenarioUtils.MarkerToPosition(markerName)
        self.BaseName = baseName
        self.Radius = radius
        for groupName, priority in levelTable do
            if not diffultySeparate then
                self:AddBuildGroup(groupName, priority, false, true) -- Do not spawn units, do not sort
            else
                self:AddBuildGroupDifficulty(groupName, priority, false, true) -- Do not spawn units, do not sort
            end
        end

        self.AIBrain:PBMAddBuildLocation(markerName, radius, baseName) -- Add base to PBM
        self:LoadDefaultBaseCDRs() -- ACU things
        self:LoadDefaultBaseSupportCDRs() -- sACU things
		self:LoadDefaultBaseEngineers() -- All other Engs
		--self:LoadDefaultBaseTechLevelEngineers(3) -- Load in specific tech level engineers
        self:LoadDefaultScoutingPlatoons() -- Load in default scouts
        self:LoadDefaultBaseTMLs() -- TMLs
        self:LoadDefaultBaseNukes() -- Nukes
        self:SortGroupNames() -- Force sort since no sorting when adding groups earlier
        self:ForkThread(self.UpgradeCheckThread) -- Start the thread to see if any buildings need upgrades

        -- Check for a default chains for engineers' patrol and scouting
        if Scenario.Chains[baseName..'_EngineerChain'] then
            self:SetDefaultEngineerPatrolChain(baseName..'_EngineerChain')
        end

        if Scenario.Chains[baseName..'_AirScoutChain'] then
            self:SetDefaultAirScoutPatrolChain(baseName..'_AirScoutChain')
        end

        if Scenario.Chains[baseName..'_LandScoutChain'] then
            self:SetDefaultLandScoutPatrolChain(baseName..'_LandScoutChain')
        end
    end,
	
	-- Determines if a specific unit needs upgrades, returns name of upgrade if needed
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
		
		-- A brief explanation on what was messed up with this previously that messed up enhancements with prerequisites
			-- The first check is was what caused issues previously, it checks if there's already an upgrade on the slot our wanted enhancement wants to occupy	
			-- "SimUnitEnhancements" is a global table that's created in "lua/SimSync.lua", and stores unit enhancements using the following data structure:
			-- SimUnitEnhancements[unit.EntityId], an example of this:
			--------------------------------
			-- Unit: -LCH: Left arm upgrade
			--	 	 -Back: Back upgrade
			--		 -RCH: Right arm upgrade
			--------------------------------
	
			-- So, for example, SimUnitEnhancements[unit.EntityId]['LCH'] is the name of a left arm upgrade the unit currently has, or nil
			-- Previous iteration of this didn't check if the name of this enhancement was actually a prerequisite, so it just removed the enhancement, and then tried to recreate it,
			-- practically getting stuck in an infinite loop of upgrading
			-- For example: 'ShieldHeavy' 	-> our desired enhancement,
			--				'Shield' 		-> its prerequisite
			-- 'Shield' is created, then we need to create 'ShieldHeavy', however 'Shield' occupies the slot 'ShieldHeavy' wants, so we remove 'Shield'
			-- But we need 'Shield' for 'ShieldHeavy', so we create it again, etc. We end up in an infinite loop.
			
			--So, we check if the occupied slot has the prerequisite upgrade, if it has something else, ONLY then we remove it.
        for _, upgradeName in upgradeTable do
            -- Find the upgrade in the unit's bp
            local bpUpgrade = allEnhancements[upgradeName]
            if bpUpgrade then
                if not unit:HasEnhancement(upgradeName) then
					-- If we already have an enhancement at the desired slot, check if it's a prerequisite first
					if SimUnitEnhancements and SimUnitEnhancements[unit.EntityId] and SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] then
						-- If it's the prerequisite enhancement, return upgrade name
						if bpUpgrade.Prerequisite and (SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] == bpUpgrade.Prerequisite) then
							return upgradeName
						-- Remove the enhancement, it's not a prerequisite
						else
							return SimUnitEnhancements[unit.EntityId][bpUpgrade.Slot] .. 'Remove'
						end
					-- Check for required upgrades
					elseif bpUpgrade.Prerequisite and not unit:HasEnhancement(bpUpgrade.Prerequisite) then
                        return bpUpgrade.Prerequisite
                    -- No requirement and stop available, return upgrade name
                    else
                        return upgradeName
                    end
                end
            else
                error('*Base Manager Error: ' ..
                    self.BaseName .. ', enhancement: ' .. upgradeName .. ' was not found in the unit\'s bp.')
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
						--Structure upgrading should take priority, so the check for unit.UnitBeingBuilt is not needed. This check is a lot more reliable to get factories to upgrade
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
        local diff = ScenarioInfo.Options.Difficulty
        if not diff then diff = 1 end
        for k, v in BuildingCounterDefaultValues[diff] do
            if buildingType == k then
                return v
            end
        end

        return BuildingCounterDefaultValues[diff].Default
    end,

    --------------------------------------
    -- Specific builders for base managers
    --------------------------------------
	LoadDefaultBaseTechLevelEngineers = function(self, level)
		--Handle special case of non-existant tech level
		if not level or (level ~= 3 and level ~= 2 and level ~= 1) then
			error('BASEMANAGER ERROR: LoadBaseTechLevelEngineers(self, level) does not accept parameter:' .. repr(level) .. 'as a tech level, valid options are: 1, 2, or 3', 2)
		end
		
        -- The Engineer AI Thread
        local defaultBuilder = {
            BuilderName = 'Specific_T' .. level .. 'BaseManaqer_EngineersWork_' .. self.BaseName,
            PlatoonTemplate = self:CreateEngineerPlatoonTemplate(level),
            Priority = 1,
            PlatoonAIFunction = {'/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'BaseManagerEngineerPlatoonSplit'},
            BuildConditions = {
                {BMBC, 'BaseManagerNeedsEngineers', {self.BaseName}},
                {BMBC, 'BaseActive', {self.BaseName}},
            },
            PlatoonData = {
                BaseName = self.BaseName,
            },
            PlatoonType = 'Any',
            RequiresConstruction = false,
            LocationType = self.BaseName,
        }
        self.AIBrain:PBMAddPlatoon(defaultBuilder)
        
		-- Disbanding Engineer platoons, only the tech tier specified by 'level'
        for j = 1, 5 do
            for num, pType in {'Air', 'Land', 'Sea'} do
                defaultBuilder = {
                    BuilderName = 'Specific_T' .. level .. 'BaseManagerEngineerDisband_' .. j .. 'Count_' .. self.BaseName,
                    PlatoonAIPlan = 'DisbandAI',
                    PlatoonTemplate = self:CreateEngineerPlatoonTemplate(level, j),
                    Priority = 300 * j,
                    PlatoonType = pType,
                    RequiresConstruction = true,
                    LocationType = self.BaseName,
                    PlatoonData = {
                        NumBuilding = j,
                        BaseName = self.BaseName,
                    },
                    BuildConditions = {
                        {BMBC, 'BaseEngineersEnabled', {self.BaseName}},
                        {BMBC, 'BaseBuildingEngineers', {self.BaseName}},
                        {BMBC, 'HighestFactoryLevel', {level, self.BaseName}},
                        {BMBC, 'FactoryCountAndNeed', {level, j, pType, self.BaseName}},
                        {BMBC, 'BaseActive', {self.BaseName}},
                    },
                    PlatoonBuildCallbacks = {{BMBC, 'BaseManagerEngineersStarted'},},
                    InstanceCount = 2,
                    BuildTimeOut = 10, -- Timeout really fast because they dont need to really finish
                }
                self.AIBrain:PBMAddPlatoon(defaultBuilder)
            end
        end
    end,
}


