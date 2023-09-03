do

local AIUtils = import("/lua/ai/aiutilities.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local Behaviors = import("/lua/ai/aibehaviors.lua")
local AIBuildUnits = import("/lua/ai/aibuildunits.lua")

-- upvalue scope for performance
local TableGetn = table.getn

local CampaignAIBrain = AIBrain

--- A hook of the default FAF campaign AI brain with some modifications.
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
		if ScenarioInfo.Options.CampaignAICheat and ScenarioInfo.Options.CampaignAICheat == 2 then
			LOG('Campaign AI cheats have been enabled, setting up cheat modifiers for use')
			AIUtils.SetupCampaignCheat(self, true)
		end
	end,
	
	--- AI PLATOON MANAGEMENT
    --- SC1's PlatoonBuildManager, used as its base AI even for skirmish, and also for FA's campaign
    --- This system is meant to be able to give some data about the platoon you want and have them built and formed into platoons at will.
    ---@param self CampaignAIBrain
    InitializePlatoonBuildManager = function(self)
        if not self.PBM then
            ---@class AiPlatoonBuildManager
            self.PBM = {
                BuildCheckInterval = nil,
                Platoons = {
                    Air = {},
                    Land = {},
                    Sea = {},
                    Gate = {},
                },
                Locations = {
                    -- {
                    --  Location,
                    --  Radius,
                    --  LocType, ('MAIN', 'EXPANSION')
                    --  PrimaryFactories = {Air = X, Land = Y, Sea = Z}
                    --  UseCenterPoint, - Bool
                    --}
                },
                PlatoonTypes = {'Air', 'Land', 'Sea', 'Gate'},
                NeedSort = {
                    ['Air'] = false,
                    ['Land'] = false,
                    ['Sea'] = false,
                    ['Gate'] = false,
                },
                RandomSamePriority = false,
                BuildConditionsTable = {},
            }
            -- Create basic starting area
            local strtX, strtZ = self:GetArmyStartPos()
            self:PBMAddBuildLocation({strtX, 20, strtZ}, 100, 'MAIN')

            -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
            local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
            if poolPlatoon then
                poolPlatoon:TurnOffPoolAI()
            end
            self.HasPlatoonList = false
            self:PBMSetEnabled(true)
			
			-- Create the global builder table where most of the builder data will be stored, I have no idea why this wasn't initalized here to begin with
			-- It was initalized in self:PBMAddPlatoon() for whatever reason
			ScenarioInfo.BuilderTable[self.CurrentPlan] = {Air = {}, Sea = {}, Land = {}, Gate = {}}
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
            -- Clear the cache so we can get fresh new responses!
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
                                    local builderData = table.random(possibleTemplates)
                                    local vp = builderData.Builder
                                    local kp = builderData.Index
                                    local globalBuilder = builderData.Global
                                    local suggestedFactories = {v.PrimaryFactories[typev]}
                                    local factories = self:CanBuildPlatoon(vp.PlatoonTemplate, suggestedFactories)
                                    vp.BuildTemplate = self:PBMBuildNumFactories(vp.PlatoonTemplate, v, typev, factories)
									local template = vp.BuildTemplate
									
                                    -- Check all the requirements to build the platoon
                                    -- The Primary Factory can actually build this platoon
                                    -- The platoon build condition has been met
									local ptnSize = personality:GetPlatoonSize()
                                    -- Finally, build the platoon.
                                    self:BuildPlatoon(template, factories, ptnSize)
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
                WaitTicks(1)
            end
            -- Do it all over again in 15 seconds.
            WaitSeconds(self.PBM.BuildCheckInterval or 15)
        end
    end,
    --- Form platoons
    --- Extracted as it's own function so you can call this to try and form platoons to clean up the pool
    ---@param self CampaignAIBrain
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
	
	
}
end
