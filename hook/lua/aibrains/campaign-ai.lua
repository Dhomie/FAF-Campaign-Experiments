do

local AIUtils = import("/lua/ai/aiutilities.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local Behaviors = import("/lua/ai/aibehaviors.lua")
local AIBuildUnits = import("/lua/ai/aibuildunits.lua")

-- upvalue scope for performance
local TableGetn = table.getn

local CampaignAIBrain = AIBrain

--- A hook of the default FAF campaign AI brain with some modifications.
--- Added functions that are not included in the basic AI brain type, those are required for some of the platoon functions found in platoon.lua
---@class CampaignAIBrain: AIBrain
---@field PBM AiPlatoonBuildManager
---@field IMAPConfig
AIBrain = Class(CampaignAIBrain) {

	--- Called after `SetupSession` but before `BeginSession` - no initial units, props or resources exist at this point
    ---@param self CampaignAIBrain
    ---@param planName string
	OnCreateAI = function(self, planName)
		CampaignAIBrain.OnCreateAI(self, planName)
		
		-- 1 -> Disabled; 2 -> Enabled
		if self.BrainType == 'AI' and ScenarioInfo.Options.CampaignAICheat == 2 then
			LOG('Campaign AI cheats have been enabled, setting up cheat modifiers for use')
			AIUtils.SetupCampaignCheat(self, true)
		end
	end,
	
	-- Main building and forming platoon thread for the Platoon Build Manager
    ---@param self CampaignAIBrain
    PlatoonBuildManagerThread = function(self)
        local personality = self:GetPersonality()
        local armyIndex = self:GetArmyIndex()

        -- Split the brains up a bit so they aren't all doing the PBM thread at the same time
        if not self.PBMStartUnlocked then
            self:PBMUnlockStart()
        end

        while true do
            self:PBMCheckBusyFactories()
            if self.BrainType == 'AI' then
                self:PBMSetPrimaryFactories()
            end
            local platoonList = self.PBM.Platoons
            -- clear the cache so we can get fresh new responses!
            self:PBMClearBuildConditionsCache()
            -- Go through the different types of platoons
            for typek, typev in self.PBM.PlatoonTypes do
                -- First go through the list of locations and see if we can build stuff there.
                for k, v in self.PBM.Locations do
                    -- See if we have platoons to build in that type
                    if not table.empty(platoonList[typev]) then
                        -- Sort the list of platoons via priority
                        if self.PBM.NeedSort[typev] then
                            self:PBMSortPlatoonsViaPriority(typev)
                        end
                        -- FORM PLATOONS
                        self:PBMFormPlatoons(true, typev, v)
                        -- BUILD PLATOONS
                        -- See if our primary factory is busy.
                        if v.PrimaryFactories[typev] then
                            local priFac = v.PrimaryFactories[typev]
                            local numBuildOrders = nil
                            if priFac and not priFac.Dead then
                                numBuildOrders = priFac:GetNumBuildOrders(categories.ALLUNITS)
                                if numBuildOrders == 0 then
                                    local guards = priFac:GetGuards()
                                    if guards and not table.empty(guards) then
                                        for kg, vg in guards do
                                            numBuildOrders = numBuildOrders + vg:GetNumBuildOrders(categories.ALLUNITS)
                                            if numBuildOrders == 0 and vg:IsUnitState('Building') then
                                                numBuildOrders = 1
                                            end
                                            if numBuildOrders > 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if numBuildOrders and numBuildOrders == 0 then
                                local possibleTemplates = {}
                                local priorityLevel = false
                                -- Now go through the platoon templates and see which ones we can build.
                                for kp, vp in platoonList[typev] do
                                    -- Don't try to build things that are higher pri than 0
                                    -- This platoon requires construction and isn't just a form-only platoon.
                                    local globalBuilder = ScenarioInfo.BuilderTable[self.CurrentPlan][typev][vp.BuilderName]
                                    if priorityLevel and (vp.Priority ~= priorityLevel or not self.PBM.RandomSamePriority) then
                                            break
                                    elseif (not priorityLevel or priorityLevel == vp.Priority) and vp.Priority > 0 and globalBuilder.RequiresConstruction
                                            -- The location we're looking at is an allowed location
                                           and (vp.LocationType == v.LocationType or not vp.LocationType)
                                            -- Make sure there is a handle slot available
                                           and (self:PBMHandleAvailable(vp)) then
                                        -- Fix up the primary factories to fit the proper table required by CanBuildPlatoon
                                        local suggestedFactories = {v.PrimaryFactories[typev]}
                                        local factories = self:CanBuildPlatoon(vp.PlatoonTemplate, suggestedFactories)
                                        if factories and self:PBMCheckBuildConditions(globalBuilder.BuildConditions, armyIndex) then
                                            priorityLevel = vp.Priority
                                            for i = 1, self:PBMNumHandlesAvailable(vp) do
                                                table.insert(possibleTemplates, {Builder = vp, Index = kp, Global = globalBuilder})
                                            end
                                        end
                                    end
                                end
                                if priorityLevel then
                                    local builderData = possibleTemplates[ Random(1, TableGetn(possibleTemplates)) ]
                                    local vp = builderData.Builder
                                    local kp = builderData.Index
                                    local globalBuilder = builderData.Global
                                    local suggestedFactories = {v.PrimaryFactories[typev]}
                                    local factories = self:CanBuildPlatoon(vp.PlatoonTemplate, suggestedFactories)
                                    vp.BuildTemplate = self:PBMBuildNumFactories(vp.PlatoonTemplate, v, typev, factories)
                                    -- Check all the requirements to build the platoon
                                    -- The Primary Factory can actually build this platoon
                                    -- The platoon build condition has been met
                                    -- Finally, build the platoon.
                                    self:BuildPlatoon(vp.BuildTemplate, factories, personality:GetPlatoonSize())
                                    self:PBMSetHandleBuilding(self.PBM.Platoons[typev][kp])
                                    if globalBuilder.GenerateTimeOut then
                                        vp.BuildTimeOut = self:PBMGenerateTimeOut(globalBuilder, factories, v, typev)
                                    else
                                        vp.BuildTimeOut = globalBuilder.BuildTimeOut
                                    end
                                    vp.PlatoonTimeOutThread = self:ForkThread(self.PBMPlatoonTimeOutThread, vp)
                                    if globalBuilder.PlatoonBuildCallbacks then
                                        for cbk, cbv in globalBuilder.PlatoonBuildCallbacks do
                                            import(cbv[1])[cbv[2]](self, globalBuilder.PlatoonData)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- WaitSeconds(.1)
            end
            -- Do it all over again in 15 seconds.
            WaitSeconds(self.PBM.BuildCheckInterval or 15)
        end
    end,
    --- Form platoons
    --- Extracted as it's own function so you can call this to try and form platoons to clean up the pool
    ---@param self AIBrain
    ---@param requireBuilding boolean `true` = platoon must have `'BUILDING'` has its handle, `false` = it'll form any platoon it can
    ---@param platoonType PlatoonType Platoontype is just `'Air'/'Land'/'Sea'`, those are found in the platoon build manager table template.
    ---@param location Vector Location/Radius are where to do this.  If they aren't specified they will grab from anywhere.
    PBMFormPlatoons = function(self, requireBuilding, platoonType, location)
        local platoonList = self.PBM.Platoons
        local personality = self:GetPersonality()
        local armyIndex = self:GetArmyIndex()
        local numBuildOrders = nil
        if location.PrimaryFactories[platoonType] and not location.PrimaryFactories[platoonType].Dead then
            numBuildOrders = location.PrimaryFactories[platoonType]:GetNumBuildOrders(categories.ALLUNITS)
            if numBuildOrders == 0 then
                local guards = location.PrimaryFactories[platoonType]:GetGuards()
                if guards and not table.empty(guards) then
                    for kg, vg in guards do
                        numBuildOrders = numBuildOrders + vg:GetNumBuildOrders(categories.ALLUNITS)
                        if numBuildOrders == 0 and vg:IsUnitState('Building') then
                            numBuildOrders = 1
                        end
                        if numBuildOrders > 0 then
                            break
                        end
                    end
                end
            end
        end
        -- Go through the platoon list to form a platoon
        for kp, vp in platoonList[platoonType] do
            local globalBuilder = ScenarioInfo.BuilderTable[self.CurrentPlan][platoonType][vp.BuilderName]
            -- To build we need to accept the following:
            -- The platoon is required to be in the building state and it is
            -- or The platoon doesn't have a handle and either doesn't require to be building state or doesn't require construction
            -- all that and passes it's build condition function.
            if vp.Priority > 0 and (requireBuilding and self:PBMCheckHandleBuilding(vp) and numBuildOrders and numBuildOrders == 0 and (not vp.LocationType or vp.LocationType == location.LocationType))
                    or (((self:PBMHandleAvailable(vp)) and (not requireBuilding or not globalBuilder.RequiresConstruction)) and (not vp.LocationType or vp.LocationType == location.LocationType)
                    and self:PBMCheckBuildConditions(globalBuilder.BuildConditions, armyIndex)) then
                local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
                local formIt = false
                local template = vp.BuildTemplate
                if not template then
                    template = vp.PlatoonTemplate
                end

                local flipTable = {}
                local squadNum = 3
                while squadNum <= TableGetn(template) do
                    if template[squadNum][2] < 0 then
                        table.insert(flipTable, {Squad = squadNum, Value = template[squadNum][2]})
                        template[squadNum][2] = 1
                    end
                    squadNum = squadNum + 1
                end

                if location.Location and location.Radius and vp.LocationType then
                    formIt = poolPlatoon:CanFormPlatoon(template, personality:GetPlatoonSize(), location.Location, location.Radius)
                elseif not vp.LocationType then
                    formIt = poolPlatoon:CanFormPlatoon(template, personality:GetPlatoonSize())
                end

                if formIt then
                    local hndl
                    if location.Location and location.Radius and vp.LocationType then
                        hndl = poolPlatoon:FormPlatoon(template, personality:GetPlatoonSize(), location.Location, location.Radius)
                        self:PBMStoreHandle(hndl, vp)
                        if vp.PlatoonTimeOutThread then
                            vp.PlatoonTimeOutThread:Destroy()
                        end
                    elseif not vp.LocationType then
                        hndl = poolPlatoon:FormPlatoon(template, personality:GetPlatoonSize())
                        self:PBMStoreHandle(hndl, vp)
                        if vp.PlatoonTimeOutThread then
                            vp.PlatoonTimeOutThread:Destroy()
                        end
                    end
					--LOG('*PBM DEBUG: Platoon formed with: ', repr(TableGetn(hndl:GetPlatoonUnits())), ' Builder Named: ', repr(vp.BuilderName))
                    hndl.PlanName = template[2]

                    -- If we have specific AI, fork that AI thread
                    if globalBuilder.PlatoonAIFunction then
                        hndl:StopAI()
                        hndl:ForkAIThread(import(globalBuilder.PlatoonAIFunction[1])[globalBuilder.PlatoonAIFunction[2]])
                    end
					
					-- If we have an AI from "platoon.lua", use that
                    if globalBuilder.PlatoonAIPlan then
                        hndl:SetAIPlan(globalBuilder.PlatoonAIPlan)
                    end

                    -- If we have additional threads to fork on the platoon, do that as well.
					-- Note: These are platoon AI functions from "platoon.lua"
                    if globalBuilder.PlatoonAddPlans then
                        for papk, papv in globalBuilder.PlatoonAddPlans do
                            hndl:ForkThread(hndl[papv])
                        end
                    end
					
					-- If we have additional functions to fork on the platoon, do that as well
                    if globalBuilder.PlatoonAddFunctions then
                        for pafk, pafv in globalBuilder.PlatoonAddFunctions do
                            hndl:ForkThread(import(pafv[1])[pafv[2]])
                        end
                    end
					
					-- If we have additional behaviours to fork on the platoon, do that as well
					-- Note: These are platoon AI functions from "AIBehaviors.lua"
                    if globalBuilder.PlatoonAddBehaviors then
                        for pafk, pafv in globalBuilder.PlatoonAddBehaviors do
                            hndl:ForkThread(Behaviors[pafv])
                        end
                    end

                    if vp.BuilderName then
                        if self.PlatoonNameCounter[vp.BuilderName] then
                            self.PlatoonNameCounter[vp.BuilderName] = self.PlatoonNameCounter[vp.BuilderName] + 1
                        else
                            self.PlatoonNameCounter[vp.BuilderName] = 1
                        end
                    end
					
                    hndl:AddDestroyCallback(self.PBMPlatoonDestroyed)
                    hndl.BuilderName = vp.BuilderName
					
					-- Cache the origin base into the platoon
					if vp.LocationType then
						hndl.LocationType = vp.LocationType
					end
					
					-- Set the platoon data
					-- Also set the platoon to be part of the attack force if specified in the platoon data. used for AttackManager platoon forming
                    if globalBuilder.PlatoonData then
                        hndl:SetPlatoonData(globalBuilder.PlatoonData)
                        if globalBuilder.PlatoonData.AMPlatoons then
                            hndl:SetPartOfAttackForce()
                        end
                    end
                end

                for _, v in flipTable do
                    template[v.Squad][2] = v.Value
                end
            end
        end
    end,
	
	--- Goes through the location areas, finds the factories, sets a primary then tells all the others to guard.
    ---@param self CampaignAIBrain
    PBMSetPrimaryFactories = function(self)
        for _, v in self.PBM.Locations do
            local factories = self:GetAvailableFactories(v.Location, v.Radius)
            local airFactories = {}
            local landFactories = {}
            local seaFactories = {}
            local gates = {}
            for ek, ev in factories do
                if EntityCategoryContains(categories.FACTORY * categories.AIR, ev) and self:PBMFactoryLocationCheck(ev, v) then
                    table.insert(airFactories, ev)
                elseif EntityCategoryContains(categories.FACTORY * categories.LAND, ev) and self:PBMFactoryLocationCheck(ev, v) then
                    table.insert(landFactories, ev)
                elseif EntityCategoryContains(categories.FACTORY * categories.NAVAL, ev) and self:PBMFactoryLocationCheck(ev, v) then
                    table.insert(seaFactories, ev)
                elseif EntityCategoryContains(categories.FACTORY * categories.GATE, ev) and self:PBMFactoryLocationCheck(ev, v) then
                    table.insert(gates, ev)
                end
            end

            local afac, lfac, sfac, gatefac
            if not table.empty(airFactories) then
                if not v.PrimaryFactories.Air or v.PrimaryFactories.Air.Dead
                    or v.PrimaryFactories.Air:IsUnitState('Upgrading')
                    or self:PBMCheckHighestTechFactory(airFactories, v.PrimaryFactories.Air) then
                        afac = self:PBMGetPrimaryFactory(airFactories)
                        v.PrimaryFactories.Air = afac
                end
                self:PBMAssistGivenFactory(airFactories, v.PrimaryFactories.Air)
            end

            if not table.empty(landFactories) then
                if not v.PrimaryFactories.Land or v.PrimaryFactories.Land.Dead
                    or v.PrimaryFactories.Land:IsUnitState('Upgrading')
                    or self:PBMCheckHighestTechFactory(landFactories, v.PrimaryFactories.Land) then
                        lfac = self:PBMGetPrimaryFactory(landFactories)
                        v.PrimaryFactories.Land = lfac
                end
                self:PBMAssistGivenFactory(landFactories, v.PrimaryFactories.Land)
            end

            if not table.empty(seaFactories) then
                if not v.PrimaryFactories.Sea or v.PrimaryFactories.Sea.Dead
                    or v.PrimaryFactories.Sea:IsUnitState('Upgrading')
                    or self:PBMCheckHighestTechFactory(seaFactories, v.PrimaryFactories.Sea) then
                        sfac = self:PBMGetPrimaryFactory(seaFactories)
                        v.PrimaryFactories.Sea = sfac
                end
                self:PBMAssistGivenFactory(seaFactories, v.PrimaryFactories.Sea)
            end

            if not table.empty(gates) then
                if not v.PrimaryFactories.Gate or v.PrimaryFactories.Gate.Dead then
                    gatefac = self:PBMGetPrimaryFactory(gates)
                    v.PrimaryFactories.Gate = gatefac
                end
                self:PBMAssistGivenFactory(gates, v.PrimaryFactories.Gate)
            end

            if not v.RallyPoint or table.empty(v.RallyPoint) then
                self:PBMSetRallyPoint(airFactories, v, nil)
                self:PBMSetRallyPoint(landFactories, v, nil)
                self:PBMSetRallyPoint(seaFactories, v, nil, 'Naval Rally Point')
                self:PBMSetRallyPoint(gates, v, nil)
            end
        end
    end,

    ---@param self CampaignAIBrain
    ---@param factories Unit
    ---@param location Vector
    ---@param rallyLoc Vector
    ---@param markerType string
    ---@return boolean
    PBMSetRallyPoint = function(self, factories, location, rallyLoc, markerType)
        if not table.empty(factories) then
            local rally
            local position = factories[1]:GetPosition()
            for facNum, facData in factories do
                if facNum > 1 then
                    position[1] = position[1] + facData:GetPosition()[1]
                    position[3] = position[3] + facData:GetPosition()[3]
                end
            end

            position[1] = position[1] / TableGetn(factories)
            position[3] = position[3] / TableGetn(factories)
            if not rallyLoc and not location.UseCenterPoint then
                local pnt
				
                if not markerType then
                    pnt = AIUtils.AIGetClosestMarkerLocation(self, 'Rally Point', position[1], position[3])
                else
					--Check in case there are no Naval Rally Points on the map, and pick a generic Rally Point instead.
                    pnt = AIUtils.AIGetClosestMarkerLocation(self, markerType, position[1], position[3]) or AIUtils.AIGetClosestMarkerLocation(self, 'Rally Point', position[1], position[3])
                end			
				
                if pnt and TableGetn(pnt) == 3 then
                    rally = Vector(pnt[1], pnt[2], pnt[3])
                end
            elseif not rallyLoc and location.UseCenterPoint then
                rally = location.Location
            elseif rallyLoc then
                rally = rallyLoc
            else
                error('*ERROR: PBMSetRallyPoint - Missing Rally Location and Marker Type', 2)
                return false
            end

            if rally then
                for _, v in factories do
                    IssueClearFactoryCommands({v})
                    IssueFactoryRallyPoint({v}, rally)
                end
            end
        end
        return true
    end,
	
	--- Enemy Picker thread
    ---@param self CampaignAIBrain
    PickEnemy = function(self)
        while true do
            self:PickEnemyLogic()
            WaitSeconds(120)
        end
    end,
	
	---@param self CampaignAIBrain
    ---@param strengthTable table
    ---@return boolean
    GetAllianceEnemy = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        for k, v in strengthTable do
            -- It's an enemy, ignore
            if k ~= myIndex and not v.Enemy and not ArmyIsCivilian(k) and not v.Brain:IsDefeated() then
                -- Ally too weak
                if v.Strength < highStrength then
                    continue
                end
                -- If the brain has an enemy, it's our new enemy
                local enemy = v.Brain:GetCurrentEnemy()
                if enemy then
                    highStrength = v.Strength
                    returnEnemy = v.Brain:GetCurrentEnemy()
                end
            end
        end
        return returnEnemy
    end,
	
	---@param self CampaignAIBrain
    GetStartVector3f = function(self)
        local startX, startZ = self:GetArmyStartPos()
        return {startX, 0, startZ}
    end,
	
	---@param self CampaignAIBrain
    PickEnemyLogic = function(self)
        local armyStrengthTable = {}
        local selfIndex = self:GetArmyIndex()
        for _, v in ArmyBrains do
            local insertTable = {
                Enemy = true,
                Strength = 0,
                Position = false,
                Brain = v,
            }
            local armyIndex = v:GetArmyIndex()
            -- Share resources with friends but don't regard their strength
            if IsAlly(selfIndex, armyIndex) then
                self:SetResourceSharing(true)
                insertTable.Enemy = false
            elseif not IsEnemy(selfIndex, armyIndex) then
                insertTable.Enemy = false
            end

            if insertTable.Enemy then
                insertTable.Position, insertTable.Strength = self:GetHighestThreatPosition(self.IMAPConfig.Rings, true, 'Structures', armyIndex)
            else
                local startX, startZ = v:GetArmyStartPos()
                local ecoStructures = self:GetUnitsAroundPoint(categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                local ecoThreat = 0
                for _, v in ecoStructures do
                    ecoThreat = ecoThreat + v.Blueprint.Defense.EconomyThreatLevel
                end
                insertTable.Position = {startX, 0, startZ}
                insertTable.Strength = ecoThreat
            end
            armyStrengthTable[armyIndex] = insertTable
        end

        local allyEnemy = self:GetAllianceEnemy(armyStrengthTable)
        if allyEnemy  then
            self:SetCurrentEnemy(allyEnemy)
        else
            local findEnemy = false
            if not self:GetCurrentEnemy() then
                findEnemy = true
            else
                local cIndex = self:GetCurrentEnemy():GetArmyIndex()
                -- If our enemy has been defeated or has less than 20 strength, we need a new enemy
                if self:GetCurrentEnemy():IsDefeated() or armyStrengthTable[cIndex].Strength < 20 then
                    findEnemy = true
                end
            end
            if findEnemy then
                local enemyStrength = false
                local enemy = false

                for k, v in armyStrengthTable do
                    -- Dont' target self and ignore allies
                    if k ~= selfIndex and v.Enemy and not v.Brain:IsDefeated() then
                        
                        -- If we have a better candidate; ignore really weak enemies
                        if enemy and v.Strength < 20 then
                            continue
                        end

                        -- The closer targets are worth more because then we get their mass spots
                        local distanceWeight = 0.1
                        local distance = VDist3(self:GetStartVector3f(), v.Position)
                        local threatWeight = (1 / (distance * distanceWeight)) * v.Strength

                        if not enemy or threatWeight > enemyStrength then
                            enemy = v.Brain
                        end
                    end
                end

                if enemy then
                    self:SetCurrentEnemy(enemy)
                end
            end
        end
    end,
	
	---Used to get rid of nil table entries. Sorian ai function
    ---@param self BaseAIBrain
    ---@param oldtable table
    ---@return table
    RebuildTable = function(self, oldtable)
        local temptable = {}
        for k, v in oldtable do
            if v ~= nil then
                if type(k) == 'string' then
                    temptable[k] = v
                else
                    table.insert(temptable, v)
                end
            end
        end
        return temptable
    end,
	
	--- Returns the closest PBM build location to the given position, or nil
	---@param self BaseAIBrain
    ---@param position Vector
    ---@return Vector
    PBMFindClosestBuildLocation = function(self, position)
        local distance, closest
        for k, v in self.PBM.Locations do
            if position then
                if not closest then
                    distance = VDist3(position, v.Location)
                    closest = v.Location
                else
                    local tempDist = VDist3(position, v.Location)
                    if tempDist < distance then
                        distance = tempDist
                        closest = v.Location
                    end
                end
            end
        end
        return closest
    end,
	
	--- Courtesy of 4z0t, returns existing platoon with name, or creates if it doesn't exist yet
    ---@param self AIBrain
    ---@param name string
    ---@return Platoon
    GetPlatoonUniquelyNamedOrMake = function(self, name)
        local platoon = self:GetPlatoonUniquelyNamed(name)
        if not platoon then
            platoon = self:MakePlatoon("", "")
            platoon:UniquelyNamePlatoon(name)
        end
        return platoon
    end
}
end
