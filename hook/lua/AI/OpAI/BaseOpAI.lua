----------------------------------------------------------------------------*
--	File     :  /lua/ai/OpAI/BaseOpAI.lua
--	Author(s): Dru Staltman
--	Summary  : Base manager for operations
--
--	Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------------------

local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local AIUtils = import("/lua/ai/aiutilities.lua")

local UCBC = '/lua/editor/unitcountbuildconditions.lua'
local BMBC = '/lua/editor/basemanagerbuildconditions.lua'
local MIBC = '/lua/editor/miscbuildconditions.lua'
local BMPT = '/lua/ai/opai/basemanagerplatoonthreads.lua'
local TableInsert = table.insert

-- Save the old OpAI for the Naval generator for now
CampaignOpAI = OpAI

function CreateOldOpAI(brain, location, builderType, name, builderData)
    local OldopAI = CampaignOpAI()
    brain:PBMEnableRandomSamePriority()
    OldopAI:Create(brain, location, builderType, name, builderData)
    return OldopAI
end

---@param platoon Platoon
function RebuildPlatoonTemplate(platoon)
	local aiBrain = platoon:GetBrain()
	local Name = platoon.PlatoonData.OpAIName
	if aiBrain.OpAIs[Name] then
		aiBrain.OpAIs[Name]:OverridePlatoonTemplate()
	end
end

--- CHILDREN TYPES MEAN UNITS
-- Localized table that contains unit IDs by type, and in order of faction indexes: UEF, Aeon, Cybran, Seraphim
-- If a unit doesn't exist for a certain faction, then that element will be set to false
-- New unit IDs can be added as you see fit, including Nomad unit IDs as the 5th element
local ChildrenTypes = {
	-- 'Any' category gets picked by the first available factory type
	Any = {
		-- Emergency fallback unit type
		FallbackType =  {'uel0105', 'ual0105', 'urb0105', 'xsl0105'},
		-- Engineers
		T1Engineers = {'uel0105', 'ual0105', 'urb0105', 'xsl0105'},
		T1Transports = {'uea0107', 'uaa0107', 'ura0107', 'xsa0107'},
		T2Engineers = {'uel0208', 'ual0208', 'url0208', 'xsl0208'},
		T2Transports = {'uea0104', 'uaa0104', 'ura0104', 'xsa0104'},
		T3Engineers = {'uel0309', 'ual0309', 'url0309', 'xsl0309'},
		
		-- Faction specific types
		T2CombatEngineers = {'xel0209', false, false, false},	-- UEF T2 Combat Engineer
		T3Transports = {'xea0306', false, false, false},			-- UEF T3 Transport
	},
	Air = {
		-- Emergency fallback unit type
		FallbackType =  {'uea0101', 'uaa0101', 'ura0101', 'xsa0101'},
		-- T1
		AirScouts = {'uea0101', 'uaa0101', 'ura0101', 'xsa0101'},
		Bombers = {'uea0103', 'uaa0103', 'ura0103', 'xsa0103'},
		Interceptors = {'uea0102', 'uaa0102', 'ura0102', 'xsa0102'},
		-- T2
		CombatFighters = {'dea0202', 'xaa0202', 'dra0202', 'xsa0202'},
		Gunships = {'uea0203', 'uaa0203', 'urb0203', 'xsa0203'},
		TorpedoBombers = {'uea0204', 'uaa0204', 'ura0204', 'xsa0204'},
		-- T3
		SpyPlanes = {'uea0302', 'uaa0302', 'ura0302', 'xsa0302'},
		AirSuperiority = {'uea0303', 'uaa0303', 'ura0303', 'xsa0303'},
		StratBombers = {'uea0304', 'uaa0304', 'ura0304', 'xsa0304'},
		StrategicBombers = {'uea0304', 'uaa0304', 'ura0304', 'xsa0304'},	-- Only added because of inconsistency with naming in ReactiveAI.lua
		
		-- Faction specific types
		GuidedMissile = {false, 'daa0206', false, false},			-- Aeon T2 Mercy
		HeavyGunships = {'uea0305', 'xaa0305', 'xra0305', false},	-- UEF, Aeon, Cybran T3 Gunships
		HeavyTorpedoBombers = {false, 'xaa0306', false, false},		-- Aeon T3 Torpedo Bomber
		LightGunships = {false, false, 'xra0105', false},			-- Cybran T1 Gunship
	},
	Land = {
		-- Emergency fallback unit type
		FallbackType =  {'uel0101', 'ual0101', 'url0101', 'xsl0101'},
		-- T1
		LandScouts = {'uel0101', 'ual0101', 'url0101', 'xsl0101'},
		LightArtillery = {'uel0103', 'ual0103', 'url0103', 'xsl0103'},
		LightTanks = {'uel0201', 'ual0201', 'url0107', 'xsl0101'},			-- I'm classifying the Cybran T1 Assault Bot as a tank too
		MobileAntiAir = {'uel0104', 'ual0104', 'url0104', 'xsl0104'},
		-- T2
		AmphibiousTanks = {'uel0203', 'xal0203', 'url0203', 'xsl0203'},
		HeavyTanks = {'uel0202', 'ual0202', 'url0202', 'xsl0303'},			-- Seraphim variant is the T3 Siege Tank
		MobileFlak = {'uel0101', 'ual0205', 'url0205', 'xsl0205'},
		MobileMissiles = {'uel0111', 'ual0111', 'url0111', 'xsl0111'},
		-- T3
		SiegeBots = {'uel0303', 'ual0303', 'url0303', 'xsl0202'},			-- Seraphim variant is the T2 Assault Bot (AKA the 'chicken')
		HeavyBots = {'xel0305', 'xal0305', 'xrl0305', 'xsl0305'},
		MobileHeavyArtillery = {'uel0304', 'ual0304', 'url0304', 'xsl0304'},
		HeavyMobileAntiAir = {'delk002', 'dalk003', 'drlk001', 'dslk004'},	-- Whoever came up with the IDs for the T3 MAAs deserves a slap
		
		-- Faction specific types
		LightBots = {'uel0106', 'ual0106', 'url0106', false},	-- UEF, Aeon, Cybran T1 LABs
		MobileBombs = {false, false, 'xrl0302', false}, 		-- Cybran T2 Mobile Bomb
		MobileMissilePlatforms = {'xel0306', false, false, false},
		MobileShields = {'uel0307', 'ual0307', false, 'xsl0307'},		-- UEF, Aeon, and Seraphim Mobile Shields
		MobileStealth = {false, false, 'url0306', false},		-- Cybran T2 Mobile Stealth
		MobileAntiShield = {false, 'dal0310', false, false}, 	-- Aeon T3 Shield Disruptor
		RangeBots = {'del0204', false, 'drl0204', false},			-- Cybran, and UEF T2 Bots (Mongoose and Hoplite)
	},
	Sea = {
		-- Emergency fallback unit type
		FallbackType =  {'ues0103', 'uas0103', 'urs0103', 'xss0103'},
		-- T1
		Frigates = {'ues0103', 'uas0103', 'urs0103', 'xss0103'},
		Submarines = {'ues0203', 'uas0203', 'urs0203', 'xss0203'},
		-- T2
		Destroyers = {'ues0201', 'uas0201', 'urs0201', 'xss0201'},
		Cruisers = {'ues0202', 'uas0202', 'urs0202', 'xss0202'},
		-- T3
		Battleships = {'ues0302', 'uas0302', 'urs0302', 'xss0302'},
		
		-- Faction specific types
		AABoats = {false, 'uas0102', false, false},		-- Aeon T1 AA Boat
		Carriers = {false, 'uas0303', 'urs0303', 'xss0303'},		-- Aeon, Cybran, and Seraphim T3 Carriers
		MissileShips = {false, 'xas0306', false, false},	-- Aeon T3 Missile Ship
		NukeSubmarines = {'ues0304', 'uas0304', 'urs0304', false},	-- UEF, Aeon, Cybran T3 Nuclear Submarines
		T2Submarines = {false, 'xas0204', 'xrs0204', false},	-- Aeon, and Cybran T2 Submarine Hunters
		T3Submarines = {false, false, false, 'xss0304'}, 	-- Seraphim T3 Submarine Hunter
		TorpedoBoats = {'xes0102', false, false, false},	-- UEF T2 Torpedo Boat
		UtilityBoats = {'xes0205', false, 'xrs0205', false},	-- UEF, and Cybran T2 Utility boats (Shield boat, and Stealth Field boat)
		
	},
	Gate = {
		SupportCommandUnit = {'uel0301', 'ual0301', 'url0301', 'xsl0301'},
	},
}

---@class OpAI
OpAI = ClassSimple {
        -- Set up variables local to this OpAI instance
        PreCreate = function(self)
            if self.PreCreateFinished then
                return true
            end
            self.Trash = TrashBag()

            self.AIBrain = false
            self.LocationType = false

            self.MasterName = false
            self.BuilderType = false

            self.MasterData = false -- Set to builder later
            self.ChildrenHandles = false -- Set to table later

            self.PreCreateFinished = true
        end,

        FindMaster = function(self, force)
            if self.MasterData and not force then
                return true
            end
            for k,v in self.AIBrain.AttackData.Platoons do
                if v.PlatoonName == self.MasterName then
                    self.MasterData = v
                    return true
                end
            end
            return false
        end,

        FindChildren = function(self, force)
            if self.ChildrenHandles and not table.empty(self.ChildrenHandles) and not force then
                return true
            end
			
			-- Ok, this is causing me some headache, but I'll adjust anyhow
			-- ScenarioInfo.BuilderTable stores vital data like platoon function, and build conditions
			-- Some of the data is copied over to AIBrain.PBM.Platoons, including the platoon template
			-- As far as the actual platoon template is concerned, the PBM uses the copied over data inside AIBrain.PBM.Platoons
			-- So, I'm creating another handle to store the PBM platoon reference to modify the platoon templates
			-- I have no idea how this even worked before, since the original OpAI overrided the ScenarioInfo.BuilderTable platoon template
			-- Some GPG magic right there
			
            self.ChildrenHandles = {}
			local platoonType = self.BuilderType
			
            for name, builder in ScenarioInfo.BuilderTable[self.AIBrain.CurrentPlan][platoonType] do
                if self:ChildNameCheck(name) then
                    TableInsert(self.ChildrenHandles, {ChildBuilder = builder})
                end
            end
			
			self.ChildrenPlatoonTemplateHandles = {}
			for index, builder in self.AIBrain.PBM.Platoons[platoonType] do
				if self:ChildNameCheck(builder.BuilderName) then
					TableInsert(self.ChildrenPlatoonTemplateHandles, {ChildPlatoonTemplateBuilder = builder})
				end
			end
            return true
        end,
		
		--- Not 'exactly removing' per-say, simply disallows the children types provided as parameter to be picked for random platoon forming
		RemoveChildren = function(self, childrenType)
            if not self:FindChildren() then
                return false
            end
			
			local BuilderType = ChildrenTypes[self.BuilderType]
			
			if type(childrenType) == 'table' then
				for index, child in childrenType do
					local Type = BuilderType[child]
					local Unit = Type[self.FactionIndex]
					if not Unit then
						WARN('*OPAI WARNING: Attempted to disable a non-existant unit type for ' .. repr(self.AIBrain.Name) .. ' named: ' .. repr(child))
					else
						self.DisabledTypes[Unit] = true
					end
				end
			else
				local Type = BuilderType[childrenType]
				local Unit = Type[self.FactionIndex]
				if not Unit then
					WARN('*OPAI WARNING: Attempted to disable a non-existant unit type for ' .. repr(self.AIBrain.Name) .. ' named: ' .. repr(childrenType))
				else
					self.DisabledTypes[Unit] = true
				end
			end
			
			-- Rebuild the platoon template
			self:OverridePlatoonTemplate()
			SPEW('Template of platoon after children removal update for platoon named: ' .. self.MasterName .. ': ' .. repr(self.ChildrenPlatoonTemplateHandles[1].ChildPlatoonTemplateBuilder.PlatoonTemplate))
        end,

        ChildNameCheck = function(self, name)
            for k, v in self.ChildrenNames do
                --local found = string.find(v.BuilderName, name .. '_', 1, true)
                if v == name then
                    return true
                end
            end
            return false
        end,
		
		SetChildCount = function(self, number)
			self.ChildCount = number
		end,

        SetChildrenPlatoonAI = function(self, functionInfo, childType)
            if not self:FindChildren() then
                error('*AI DEBUG: No children for OpAI found')
            end
            for k, v in self.ChildrenHandles do
                v.ChildBuilder.PlatoonAIFunction = functionInfo
            end
        end,

        SetFormation = function(self, formationName)
            if not self:FindMaster() then
                return false
            end
            self.MasterData.PlatoonData.OverrideFormation = formationName
            return true
        end,

        SetFunctionStatus = function(self,funcName,bool)
            ScenarioInfo.OSPlatoonCounter[self.MasterName..'_' .. funcName] = bool
        end,

        -- TODO: make a system out of this.  Derive functionality per override per OpAI type
        MasterPlatoonFunctionalityChange = function(self, functionData)
            if functionData[2] == 'LandAssaultWithTransports' then
                self:SetFunctionStatus('Transports', true)
            end
        end,

        TargetCommanderLast = function(self, cat)
            return self:SetTargettingPriorities(
            {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE * categories.ECONOMIC,
                categories.MOBILE - categories.COMMAND,
                categories.ALLUNITS - categories.COMMAND,
                categories.COMMAND,

            }
            , cat)
        end,

        TargetCommanderNever = function(self, cat)
            return self:SetTargettingPriorities(
            {
                categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE * categories.ECONOMIC,
                categories.MOBILE - categories.COMMAND,
                categories.ALLUNITS - categories.COMMAND,
            }
            , cat)
        end,

        --categories is an optional parameter specifying a subset of the platoon we wish to set target priorities for.
        SetTargettingPriorities = function(self, priTable, categories)
            if not self:FindMaster() then
                return false
            end

            local priList = {unpack(priTable)}
            local defList = {'COMMAND', 'MOBILE', 'STRUCTURE DEFENSE', 'ALLUNITS',}

            if categories then
                -- Save the priorities for this category.
                if not self.MasterData.PlatoonData.CategoryPriorities then self.MasterData.PlatoonData.CategoryPriorities = {} end

                --NOTE: This should probably be a table.deepcopy if we're going to alter the original table in the future.
                self.MasterData.PlatoonData.CategoryPriorities[categories] = priList
            else
                for i, v in defList do
                    TableInsert(priList, v)
                end

                self.MasterData.PlatoonData.TargetPriorities = {}

                for i,v in priList do
                    TableInsert(self.MasterData.PlatoonData.TargetPriorities, v)
                end
            end

            TableInsert(self.MasterData.PlatoonAddFunctions, {'/lua/ai/opai/BaseManagerPlatoonThreads.lua', 'PlatoonSetTargetPriorities'})
            return true
        end,

        SetChildQuantity = function(self, childrenType, quantity)
            if not self:FindChildren() or not self:FindMaster() then
				WARN('Couldn\'t find children or master builder for OpAI!')
                return false
            end
			
			self.RandomizePlatoonTemplate = false
			-- The actual builder having the proper template reference
			local childBuilder = self.ChildrenPlatoonTemplateHandles[1].ChildPlatoonTemplateBuilder
			
			childBuilder.PlatoonTemplate = self:CreatePlatoonTemplate(childrenType)
            self:OverrideTemplateSize(quantity)
        end,

        OverrideTemplateSize = function(self, quantity)
			local childBuilder = self.ChildrenPlatoonTemplateHandles[1].ChildPlatoonTemplateBuilder
            if type(quantity) == 'table' then
                for sNum,sData in childBuilder.PlatoonTemplate do
                    if sNum >= 3 then
                        sData[2] = 1
                        sData[3] = quantity[sNum - 2] or 1
                    end
                end
            else
                local overrideNum = math.floor(quantity / (table.getn(childBuilder.PlatoonTemplate) - 2))
                for sNum,sData in childBuilder.PlatoonTemplate do
                    if sNum >= 3 then
                        sData[2] = 1
                        sData[3] = overrideNum
                    end
                end
            end
        end,
		
		OverridePlatoonTemplate = function(self)
			if self.RandomizePlatoonTemplate then
				local childBuilder = self.ChildrenPlatoonTemplateHandles[1].ChildPlatoonTemplateBuilder
				local OverrideTemplate = self:CreateRandomPlatoonTemplate()
				if OverrideTemplate then
					childBuilder.PlatoonTemplate = OverrideTemplate
				end
			end
		end,

        -- Build conditions for PBM; Attack Conditions for AM Platoons
        AddBuildCondition = function(self, fileName, funcName, parameters, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                local found

                if bName and v.ChildBuilder.BuilderName then
                    found = string.find(bName, v.ChildBuilder.BuilderName .. '_', 1, true)
                end

                if not bName or bName == v.ChildBuilder.BuilderName or found then
                    TableInsert(v.ChildBuilder.BuildConditions, { fileName, funcName, parameters })
                end
            end
            if not bName or bName == self.MasterName then
                TableInsert(self.MasterData.AttackConditions, { fileName, funcName, parameters })
            end
            return true
        end,

        RemoveBuildCondition = function(self, funcName, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                if not bName or bName == v.ChildBuilder.BuilderName then
                    for num,bc in v.ChildBuilder.BuildConditions do
                        if bc[2] == funcName then
                            v.ChildBuilder.BuildConditions[num] = nil
                        end
                    end
                end
            end
            if not bName or bName == self.MasterName then
                for num,ac in self.MasterData.AttackConditions do
                    if ac[2] == funcName then
                        self.MasterData.AttackConditions[num] = nil
                    end
                end
            end
            return true
        end,

        -- Add Functions for PBM Platoons; FormCallbacks for AM Platoons
        AddAddFunction = function(self, fileName, funcName, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                if not bName or bName == v.ChildBuilder.BuilderName then
                    TableInsert(v.ChildBuilder.PlatoonAddFunctions, { fileName, funcName })
                end
            end
            if not bName or bName == self.MasterName then
                if type(fileName) == 'function' then
                    TableInsert(self.MasterData.FormCallbacks, fileName)
                else
                    TableInsert(self.MasterData.FormCallbacks, { fileName, funcName })
                end
            end
            return true
        end,

        AddFormCallback = function(self,filename,funcName,bName)
            self:AddAddFunction(filename,funcName,self.MasterName)
        end,

        RemoveAddFunction = function(self, funcName, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                if not bName or bName == v.ChildBuilder.BuilderName then
                    for num,bc in v.ChildBuilder.PlatoonAddFunctions do
                        if bc[2] == funcName then
                            v.ChildBuilder.PlatoonAddFunctions[num] = nil
                        end
                    end
                end
            end
            if not bName or bName == self.MasterName then
                for num,ac in self.MasterData.FormCallbacks do
                    if ac[2] == funcName then
                        self.MasterData.FormCallbacks[num] = nil
                    end
                end
            end
            return true
        end,

        RemoveFormCallback = function(self,filename,funcName,bName)
            self:RemoveAddFunction(filename,funcName,bName)
        end,

        -- Add Build Callback for PBM Platoons; Death Callback for AM Platoons
        AddBuildCallback = function(self, fileName, funcName, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                if not bName or bName == v.ChildBuilder.BuilderName then
                    TableInsert(v.ChildBuilder.PlatoonBuildCallbacks, { fileName, funcName })
                end
            end
            if not bName or bName == self.MasterName then
                TableInsert(self.MasterData.DestroyCallbacks, { fileName, funcName })
            end
            return true
        end,

        AddDestroyCallback = function(self,fileName,funcName,bName)
            self:AddBuildCallback(fileName,funcName,bName)
        end,

        RemoveBuildCallback = function(self, funcName, bName)
            if not self:FindChildren() or not self:FindMaster() then
                return false
            end
            for k,v in self.ChildrenHandles do
                if not bName or bName == v.ChildBuilder.BuilderName then
                    for num,bc in v.ChildBuilder.PlatoonBuildCallbacks do
                        if bc[2] == funcName then
                            v.ChildBuilder.PlatoonBuildCallbacks[num] = nil
                        end
                    end
                end
            end
            if not bName or bName == self.MasterName then
                for num,ac in self.MasterData.FormCallbacks do
                    if ac[2] == funcName then
                        self.MasterData.FormCallbacks[num] = nil
                    end
                end
            end
            return true
        end,

        RemoveDestroyCallback = function(self,fileName,funcName,bName)
            self:RemoveBuildCallback(fileName,funcName,bName)
        end,

        MasterUsePool = function(self, val)
            if not self:FindMaster() then
                return false
            end
            self.MasterData.UsePool = val
            return true
        end,

        SetLockingStyle = function(self,lockType, lockData)
            if not(lockType == 'None' or lockType == 'DeathTimer' or lockType == 'BuildTimer' or lockType == 'DeathRatio' or lockType == 'RatioTimer') then
                error('*AI ERROR: Error adding lock style: valid types are "DeathTimer", "BuildTimer", "DeathRatio", or "None"', 2)
            end
            self:RemoveBuildCondition('AMCheckPlatoonLock')
            if lockType ~= 'None' then
                self:AddBuildCondition('/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {self.MasterName})
                self:RemoveDestroyCallback('AMUnlockPlatoon', self.MasterName)
                self:RemoveFormCallback('AMUnlockBuildTimer', self.MasterName)
                self:RemoveFormCallback('AMUnlockRatio', self.MasterName)
                if lockType == 'DeathTimer' then
                    if not lockData or not lockData.LockTimer then
                        error('*AI DEBUG: Death Timers require the data LockTimer', 2)
                    end
                    self:AddDestroyCallback('/lua/editor/amplatoonhelperfunctions.lua', 'AMUnlockPlatoon', self.MasterName)
                    self.MasterData.PlatoonData.LockTimer = lockData.LockTimer
                elseif lockType == 'BuildTimer' then
                    if not lockData or not lockData.LockTimer then
                        error('*AI DEBUG: Build Timers require the data LockTimer', 2)
                    end
                    self:AddFormCallback(BMPT, 'AMUnlockBuildTimer', self.MasterName)
                    self.MasterData.PlatoonData.LockTimer = lockData.LockTimer
                elseif lockType == 'DeathRatio' then
                    if not lockData or not lockData.Ratio then
                        error('*AI DEBUG: Death Ratio unlocking requires the data Ratio', 2)
                    end
                    self:AddFormCallback(BMPT, 'AMUnlockRatio', self.MasterName)
                    self.MasterData.PlatoonData.Ratio = lockData.Ratio
                elseif lockType == 'RatioTimer' then
                    if not lockData or not lockData.Ratio or not lockData.LockTimer then
                        error('*AI DEBUG: RatioTimer unlocking requires the data "Ratio" and "LockTimer"',2)
                    end
                    self:AddFormCallback(BMPT, 'AMUnlockRatioTimer', self.MasterName)
                    self.MasterData.PlatoonData.LockTimer = lockData.LockTimer
                    self.MasterData.PlatoonData.Ratio = lockData.Ratio
                end
            end
        end,

        SetChildrenActive = function(self, childrenTypes)
            if not self:FindChildren() then
                return false
            end
			
			-- Assume we need to disable every unit
			-- If 'All' was passed in, SetChildActive will overwrite it anyhow
			self.EnabledTypes['All'] = false

            for k, v in childrenTypes do
                self:SetChildActive(v, true)
            end
			
			-- Rebuild the platoon template so our actually allowed unit types will be picked
			self:OverridePlatoonTemplate()
        end,

        SetChildActive = function(self, cType, val)
            if not self:FindChildren() then
                return false
            end

            -- check against self.EnabledTypes

            if cType ~= 'All' then
				local Type = ChildrenTypes[self.BuilderType][cType]
				local Unit = Type[self.FactionIndex]
				if not Unit then
					WARN('*OPAI WARNING: Attempted to activate a non-existant unit type for ' .. repr(self.AIBrain.Name) .. ' named: ' .. repr(cType))
				else
					self.EnabledTypes[Unit] = val
				end
            else
                for k, v in self.EnabledTypes do
                    --self.EnabledTypes[k] = val
					v = val
                end
            end
            --[[-- Loop through children
            for k,v in self.ChildrenNames do
                -- Make sure this child has children types
                if v.ChildrenType then

                    -- We don't want to change by default
                    local change = false
                    -- if the type is 'All' or we find that this builder has this child type, we may want to change
                    for cNum, cName in v.ChildrenType do
                        if (cName == cType) or (cType == 'All') then
                            change = true
                        end
                    end

                    -- Need to change the children here
                    if change then
                        -- make sure that this builder's enabled types are all active
                        local changeVal = true
                        for cNum,cName in v.ChildrenType do
                            -- This child type is not enabled, we'll want to disable this child type
                            if not self.EnabledTypes[cName] then
                                changeVal = false
                                break
                            end
                        end
                        if changeVal then
                            if not self:AddBuildCondition(MIBC, 'True', {}, v.BuilderName) or
                                not self:RemoveBuildCondition('False', v.BuilderName) then
                                error('*AI ERROR: Error Adding build condition',2)
                            end
                        else
                            if not self:AddBuildCondition(MIBC, 'False', {}, v.BuilderName) or
                                not self:RemoveBuildCondition('True', v.BuilderName) then
                                error('*AI ERROR: Error Adding build condition',2)
                            end
                        end
                    end
               end
            end]]
        end,
		
		--- Function that returns the amount of factories present in a base
		---@param aiBrain AIBrain
		---@param techLevel number
		---@param engQuantity number
		---@param pType string
		---@param baseName string
		---@return boolean
		GetFactoryCount = function(self)
			local bManager = self.AIBrain.BaseManagers[self.LocationType]
			if not bManager then
				error('*OPAI ERROR: No BaseManager detected for OpAI Master Platoon named: ' .. repr(self.MasterName), 2)
			end
			
			local FactoryType = string.upper(self.BuilderType)
			
			if self.BuilderType == 'Sea' then
				FactoryType = 'NAVAL'
			end
			
			local FactoryCategory = ParseEntityCategory(FactoryType)
			local FactoryList = bManager:GetAllBaseFactories(FactoryCategory)
			return table.getn(FactoryList)
		end,
		
		CreateTableOfBuildableUnits = function(self)
			local FactoryType = self.BuilderType
			local Units = ChildrenTypes[FactoryType]
			local PBMLocation = self.AIBrain:PBMGetLocation(self.LocationType)
			local PrimaryFactory = PBMLocation.PrimaryFactories[FactoryType]
			local BuildableTable = {}
			
			if FactoryType == 'Any' then
				PrimaryFactory = PBMLocation.PrimaryFactories['Land'] or PBMLocation.PrimaryFactories['Air'] or PBMLocation.PrimaryFactories['Sea']
			end
			
			-- The following conditions need to be met to select a unit type:
			-- Blueprint must be buildable by the base's primary factory, it must be enabled, and it musn't be on the disabled list
			if PrimaryFactory and not PrimaryFactory.Dead then
				for Num, Type in Units do
					local UnitID = Type[self.FactionIndex]
					if UnitID and PrimaryFactory:CanBuild(UnitID) and (self.EnabledTypes['All'] or self.EnabledTypes[UnitID]) and (not self.DisabledTypes[UnitID]) then
						TableInsert(BuildableTable, Type[self.FactionIndex])
					end
				end
			end
			return BuildableTable
		end,
		
		--- Creates a specified platoon template
		---@param self OpAI
		---@param unitList Table of children type strings
		CreatePlatoonTemplate = function(self, unitList)
			local FactoryType = self.BuilderType
			local Units = ChildrenTypes[FactoryType]
			
			-- Dummy platoon template
			local PlatoonTemplate = {
				self.MasterName .. '_PlatoonTemplate',
				'',
			}
			
			if type(unitList) == 'string' then
				LOG('Received ChildType: ' .. repr(unitList))
				if not (Units[unitList] and Units[unitList][self.FactionIndex]) then
					error('*OPAI ERROR: Attempted to add non-existant unit type \''.. repr(unitList) .. ' for army: ' .. repr(self.AIBrain.Name), 2)
				end
				
				local unitID = Units[unitList][self.FactionIndex]
				PlatoonTemplate = {
					self.MasterName .. 'PlatoonTemplate',
					'',
					{unitID, 1, 1, 'Attack', 'GrowthFormation'},
				}
			elseif type(unitList) == 'table' then
				LOG('Received ChildrenType: ' .. repr(unitList))
				-- Platoon template element: {'', -1, 1, 'Attack', 'GrowthFormation'},
				for index, unitType in unitList do
					if not (Units[unitType] and Units[unitType][self.FactionIndex]) then
						error('*OPAI ERROR: Attempted to add non-existant unit type \''.. repr(unitType) .. ' for army: ' .. repr(self.AIBrain.Name), 2)
					end
					
					local unitID = Units[unitType][self.FactionIndex]
					local Element = {unitID, 1, 1, 'Attack', 'GrowthFormation'}
					TableInsert(PlatoonTemplate, Element)
				end
			end
			
			return PlatoonTemplate
		end,
		
		--- Creates a random platoon template, this is done after the initial was created
		--- If it can't be created, just return, and use the former template
		---@param self OpAI
		CreateRandomPlatoonTemplate = function(self)
			local UnitOptions = self:CreateTableOfBuildableUnits()
			if table.empty(UnitOptions) then
				return
			end
			
			local ChildCount = self.ChildCount
			local FactoryCount = self:GetFactoryCount()
			local MaxUnits = FactoryCount * 2
			
			-- If we have less available unit types to choose from than we want for the template, use what we have
			local NumUnitOptions = table.getn(UnitOptions)
			if ChildCount > NumUnitOptions then
				ChildCount = NumUnitOptions
			end
			
			-- Dummy platoon template
			local PlatoonTemplate = {
				self.MasterName .. '_PlatoonTemplate',
				'',
			}

			-- Platoon template element: {'', -1, 1, 'Attack', 'GrowthFormation'}
			for i = 1, ChildCount do
				local Element = {'', 1, 1, 'Attack', 'GrowthFormation'}
				-- Pick a random unit ID
				Element[1] = table.random(UnitOptions)
				-- Remove the unit ID so we won't pick it again
				for index, element in UnitOptions do
					if element == Element[1] then
						table.remove(UnitOptions, index)
					end
				end
				-- Pick a random amount from 1 to max factory count
				Element[3] = Random(1, MaxUnits)
				TableInsert(PlatoonTemplate, Element)
			end
			
			return PlatoonTemplate
		end,
		
		--- Creates the initial platoon template, if it can't be created, it'll loop every 5 seconds until it's done
		---@param self OpAI
		CreateInitialRandomPlatoonTemplate = function(self)
			local UnitOptions = self:CreateTableOfBuildableUnits()
			
			-- If we couldn't find any buildable units, just create a dummy T1 template with the first available unit
			if table.empty(UnitOptions) then
				--WARN('*OPAI WARNING: Couldn\'t create a random initial platoon template, creating a fallback dummy one instead for: ' .. repr(self.MasterName))
				
				local Units = ChildrenTypes[self.BuilderType]
				-- Dummy platoon template
				local PlatoonTemplate = {
					self.MasterName .. '_PlatoonTemplate',
					'',
					{Units['FallbackType'][self.FactionIndex], 1, 1, 'Attack', 'GrowthFormation'},
				}
				return PlatoonTemplate
			end
			
			local ChildCount = self.ChildCount
			local FactoryCount = self:GetFactoryCount()
			local MaxUnits = FactoryCount * 2
			
			-- If we have less available unit types to choose from than we want for the template, use what we have
			local NumUnitOptions = table.getn(UnitOptions)
			if ChildCount > NumUnitOptions then
				ChildCount = NumUnitOptions
			end
			
			-- Dummy platoon template
			local PlatoonTemplate = {
				self.MasterName .. '_PlatoonTemplate',
				'',
			}
			
			-- Platoon template element: {'', -1, 1, 'Attack', 'GrowthFormation'}
			for i = 1, ChildCount do
				local Element = {'', 1, 1, 'Attack', 'GrowthFormation'}
				-- Pick a random unit ID
				Element[1] = table.random(UnitOptions)
				-- Remove the unit ID so we won't pick it again
				for index, element in UnitOptions do
					if element == Element[1] then
						table.remove(UnitOptions, index)
					end
				end
				-- Pick a random amount from 1 to max factory count
				Element[3] = Random(1, MaxUnits)
				TableInsert(PlatoonTemplate, Element)
			end
			
			return PlatoonTemplate
		end,

        Create = function(self, brain, location, builderType, name, builderData)
			if self.PreCreateFinished then
				error('*OPAI ERROR: OpAI named: ' .. repr(name) .. ' has already been initalized.', 2)
			end
            self:PreCreate()

            -- local tables to this class instance
            --self.ChildrenNames = {}						-- Builder names of the PBM children platoon
            self.EnabledTypes = {All = true}
			self.DisabledTypes = {}	-- Overwrites EnabledTypes
		
            -- Store off local instances of some variables
            self.AIBrain = brain
            self.LocationType = location
			self.ChildCount = ScenarioInfo.Options.Difficulty or 3
            self.BuilderType = builderType
			self.FactionIndex = self.AIBrain:GetFactionIndex()
			self.MasterName = 'MasterPlatoon_' .. self.AIBrain.Name .. '_' .. self.BuilderType .. '_' .. name	-- MasterPlatoon_ArmyName_BaseName_ActualName --> Safety check to avoid duplicates
			self.PrimaryChildName = 'ChildPlatoon_' .. self.AIBrain.Name .. '_' .. self.BuilderType .. '_' .. name -- ChildPlatoon_ArmyName_BaseName_ActualName --> Safety check to avoid duplicates
			self.RandomizePlatoonTemplate = true
			
			-- Store OpAI in table, index it by the master platoon name
			if not self.AIBrain.OpAIs then
				self.AIBrain.OpAIs = {}
			end
			self.AIBrain.OpAIs[self.MasterName] = self

            -- Load all the platoon data info in the formation desired
            local platoonData = {}
            if not builderData then
                platoonData.Priority = 100
                platoonData.PlatoonData = {}
            else
                -- Set PlatoonData
                if builderData.PlatoonData then
                    platoonData.PlatoonData = builderData.PlatoonData
                else
                    platoonData.PlatoonData = {}
                end
                -- Set priority
                if builderData.Priority then
                    platoonData.Priority = builderData.Priority
                else
                    platoonData.Priority = 100	-- Default to 100 priority
                end
            end
            platoonData.LocationType = location

            if type(self.BuilderType) == "string" then
				-- Adjust previously used file paths to the factory types instead
				if self.BuilderType == 'AirAttacks' then
					self.BuilderType = 'Air'
				elseif self.BuilderType == 'BasicLandAttack' then
					self.BuilderType = 'Land'
				elseif self.BuilderType == 'NavalAttacks' then
					self.BuilderType = 'Sea'
				elseif self.BuilderType == 'EngineerAttack' then
					self.BuilderType = 'Any'
				else
					
				end
				
				-- Assemble a rough template for the PBM Builders
				-- We might need more (like for EngineerAttack an additional transport builder), so the PBMBuilders is going to be a table of element made out of builders
				-- We'll only need to modify the platoon templates, and fill the ChildrenType table afterwards
				local PBMBuilder = {
					BuilderName = self.PrimaryChildName,
					PlatoonTemplate = self:CreateInitialRandomPlatoonTemplate(),
					InstanceCount = 1,
					Priority = platoonData.Priority,
					BuildTimeOut = 240,		-- This could be a lobby option
					PlatoonType = self.BuilderType,
					RequiresConstruction = true,
					LocationType = platoonData.LocationType,
					BuildConditions = {
						{'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {self.MasterName}}
					},
					PlatoonData = platoonData.PlatoonData,
				}
				
				self.ChildrenNames = {self.PrimaryChildName}
				PBMBuilder.PlatoonData.AMPlatoons = {self.MasterName}
				
				-- Assemble a rough template for the AM Builder
				-- We only need one
				local AMBuilder = {
					PlatoonName = self.MasterName,
					AttackConditions = {
						{'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {self.MasterName}},
					},
					AIThread = builderData.MasterPlatoonFunction or {'/lua/ScenarioPlatoonAI.lua', 'PlatoonAttackHighestThreat', {'default_platoon'}},
					Priority = platoonData.Priority,
					PlatoonData = platoonData.PlatoonData,
					OverrideFormation = false, -- formation to use for the attack platoon
					FormCallbacks = {
                        {'/lua/editor/amplatoonhelperfunctions.lua', 'AMLockPlatoon', {'default_platoon'}},
						{'/lua/ai/opai/baseopai.lua', 'RebuildPlatoonTemplate', {'default_platoon'}},
                    },
					DestroyCallbacks = {
                        {'/lua/editor/amplatoonhelperfunctions.lua', 'AMUnlockPlatoon', {'default_platoon'}},
                    },
					LocationType = platoonData.LocationType, -- location from PBM -- used if you want to get units from pool
					PlatoonType = self.BuilderType, -- 'Air', 'Sea', 'Land' -- MUST BE SET IF UsePool IS TRUE
					UsePool = false, -- bool to use pool or not
				}
				
				-- Save the OpAI instance on the completed platoon as platoon data
				AMBuilder.PlatoonData.OpAIName = self.MasterName
				
				if self.AIBrain.AttackData['AttackManagerState'] ~= 'ACTIVE' then
                    self.AIBrain:InitializeAttackManager()
                end

				self.AIBrain:PBMAddPlatoon(PBMBuilder)
				self.AIBrain:AMAddPlatoon(AMBuilder)
			
				-- Make sure the platoons were loaded proper, and find them
				self:FindMaster()
				self:FindChildren()
			
				if builderData.MasterPlatoonFunction then
					if self:FindMaster() then
						self.MasterData.AIThread = builderData.MasterPlatoonFunction
						self:MasterPlatoonFunctionalityChange(builderData.MasterPlatoonFunction)
					end
				end

				self:AddBuildCondition(BMBC, 'BaseActive', {platoonData.LocationType})
			end
        end,
    }

function CreateOpAI(brain, location, builderType, name, builderData)
    local opAI = OpAI()
    brain:PBMEnableRandomSamePriority()
    opAI:Create(brain, location, builderType, name, builderData)
    return opAI
end