do

-- upvalue scope for performance
local TableInsert = table.insert
local TableRandom = table.random
local TableEmpty = table.empty
local TableRemove = table.remove

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
		
		-- Initialize the IMAP
		self:IMAPConfiguration()
		-- 1 -> Disabled; 2 -> Enabled
		if ScenarioInfo.Options.CampaignAICheat and ScenarioInfo.Options.CampaignAICheat == 2 then
			LOG('Campaign AI cheats have been enabled, setting up cheat modifiers for use.')
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
					--[[{
						Location,
						Radius,
						LocType, ('MAIN', 'EXPANSION')
						PrimaryFactories = {Air = X, Land = Y, Sea = Z}
						UseCenterPoint, - Bool
                    }]]
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
			
			-- Create a global table that will act as a pointer/reference to the actual builders stored in the AI brain
			-- Keying is done via the plan, which should be the path to the AI plan, which is in 99% of the cases : "/lua/ai/OpAI/DefaultBlankPlan.lua"
			-- This should mean that all builder references for all AIs can be found inside a single entry
			ScenarioInfo.BuilderTable[self.CurrentPlan] = {Air = {}, Sea = {}, Land = {}, Gate = {}}
			-- Create a table in the brain that will store the builders proper
			self.PBM.Platoons = {Air = {}, Sea={}, Land = {}, Gate = {}}
        end
    end,
	
	--- Adds a new build location
	--- TODO: Key these according to their actual names, currently they lack any keys to access them, and require a loop to check each ones' LocationType
    ---@param self CampaignAIBrain
    ---@param loc Vector
    ---@param radius number
    ---@param locType string
    ---@param useCenterPoint? boolean
    ---@return boolean
    PBMAddBuildLocation = function(self, loc, radius, locType, useCenterPoint)
        if not radius or not loc or not locType then
            error('*AI ERROR: INVALID BUILD LOCATION FOR PBM', 2)
            return false
        end
        if type(loc) == 'string' then
            loc = ScenarioUtils.MarkerToPosition(loc)
        end

        useCenterPoint = useCenterPoint or false
        local spec = {
            Location = loc,
            Radius = radius,
            LocationType = locType,
            PrimaryFactories = {Air = nil, Land = nil, Sea = nil, Gate = nil},
            UseCenterPoint = useCenterPoint,
        }

        local found = false
        for num, loc in self.PBM.Locations do
            if loc.LocationType == spec.LocationType then
                found = true
                break
            end
        end

        if not found then
            TableInsert(self.PBM.Locations, spec)
        else
            error('*AI  ERROR: Attempting to add a build location with a duplicate name: '..spec.LocationType, 2)
            return false
        end
    end,
	
	--- Primary function that loads in platoon builders into the AI brain
	--- GPG created the "ScenarioInfo.BuilderTable" to point/reference the original param builder, while partial data of the param builder is copied to the brain
	--- We'll use the same idea, but instead of using the original builder, we load the entire param builder into the brain, and reference/point at that, avoiding unnecessary data duplication
	--- Any alterations to the builder thus remains functional like before
	---@param self CampaignAIBrain
    ---@param pltnTable PlatoonTable
    PBMAddPlatoon = function(self, pltnTable)
        if not pltnTable.PlatoonTemplate then
            error('*AI ERROR: INVALID PLATOON LIST IN '.. self.CurrentPlan.. ' - MISSING TEMPLATE IN BUILDER ' .. pltnTable.BuilderName, 1)
        end

        if pltnTable.RequiresConstruction == nil then
            error('*AI ERROR: INVALID PLATOON LIST IN ' .. self.CurrentPlan .. ' - MISSING RequiresConstruction IN BUILDER' .. pltnTable.BuilderName, 1)
        end

        if not pltnTable.Priority then
            error('*AI ERROR: INVALID PLATOON LIST IN ' .. self.CurrentPlan .. ' - MISSING PRIORITY IN BUILDER' .. pltnTable.BuilderName, 1)
        end
		
		if not (pltnTable.PlatoonType == 'Air' or pltnTable.PlatoonType == 'Land' or pltnTable.PlatoonType == 'Gate' or pltnTable.PlatoonType == 'Sea' or pltnTable.PlatoonType == 'Any') then
			error ('*AI ERROR: INVALID PLATOON LIST IN ' .. self.CurrentPlan ..' - INVALID OR MISSING PLATOON TYPE IN BUILDER ' .. pltnTable.BuilderName, 1)
		end

        pltnTable.BuildConditions = pltnTable.BuildConditions or {}

        if not pltnTable.BuildTimeOut or pltnTable.BuildTimeOut == 0 then
            pltnTable.GenerateTimeOut = true
        end

        local num = 1
        if pltnTable.InstanceCount and pltnTable.InstanceCount > 1 then
            num = pltnTable.InstanceCount
        end
		
		-- Local instances of some variables
		local PlatoonType = pltnTable.PlatoonType
		local BuilderName = pltnTable.BuilderName
		local PBMPlatoonBuilder		-- Set to reference the loaded builder later

        -- Sanity safety check
        ScenarioInfo.BuilderTable[self.CurrentPlan] = ScenarioInfo.BuilderTable[self.CurrentPlan] or {Air = {}, Sea = {}, Land = {}, Gate = {}}
		
		-- Insert the builder into the corresponding type, 'Any' is a special case
		if pltnTable.PlatoonType != 'Any' then
			-- Simple reference for easy access, and fewer table operations
			local PlatoonTypeBuilderTable = self.PBM.Platoons[pltnTable.PlatoonType]
			
			-- Handle cases of duplication
			if ScenarioInfo.BuilderTable[self.CurrentPlan][PlatoonType][BuilderName] and not ScenarioInfo.BuilderTable[self.CurrentPlan][PlatoonType][BuilderName].Inserted then
				error('AI DEBUG: BUILDER DUPLICATE NAME FOUND - ' .. BuilderName, 2)
			end
	
			-- Insert the builder into the brain
			TableInsert(PlatoonTypeBuilderTable, pltnTable)
			self.PBM.NeedSort[PlatoonType] = true
			
			-- At this point we handled duplicates, repeat the same process, but assign a global reference to it instead
			-- ScenarioInfo.BuilderTable is a GPG thing, and is used in the 'lua/AI/OpAI/BaseOpAI.lua' file to alter the original builder
			for index, builder in PlatoonTypeBuilderTable do
				if builder.BuilderName == BuilderName then
					-- Local reference
					PBMPlatoonBuilder = builder
					-- Global reference
					ScenarioInfo.BuilderTable[self.CurrentPlan][PlatoonType][BuilderName] = builder
					-- We found our builder, break out
					break
				end
			end
			
			-- Finally, insert the handles that will keep track of how many platoons of this type exists, and are being built
			PBMPlatoonBuilder.PlatoonHandles = {}
			for i = 1, num do
                TableInsert(PBMPlatoonBuilder.PlatoonHandles, false)
            end
        else
			-- Insert for all 3 major factory types
            local PlatoonTypes = {'Air', 'Land', 'Sea'}
			
            for index, pType in PlatoonTypes do
				-- Simple reference for easy access, and fewer table operations
				local PlatoonTypeBuilderTable = self.PBM.Platoons[pType]
				-- Reset the reference to nil
				PBMPlatoonBuilder = nil

				-- Handle cases of duplication, the same builder name can be used in a different platoon type
				if ScenarioInfo.BuilderTable[self.CurrentPlan][pType][BuilderName] and not ScenarioInfo.BuilderTable[self.CurrentPlan][pType][BuilderName].Inserted then
					error('AI DEBUG: BUILDER DUPLICATE NAME FOUND - ' .. BuilderName .. ' - FOR PLATOON TYPE - ' .. pType, 2)
				end

				-- Insert the builder into the brain
				TableInsert(PlatoonTypeBuilderTable, pltnTable)
				self.PBM.NeedSort[pType] = true
			
				-- At this point we handled duplicates, repeat the same process, but assign a global reference to it instead
				-- ScenarioInfo.BuilderTable is a GPG thing, and is used in the 'lua/AI/OpAI/BaseOpAI.lua' file to alter the original builder
				for index, builder in PlatoonTypeBuilderTable do
					if builder.BuilderName == BuilderName then
						-- Local reference
						PBMPlatoonBuilder = builder
						-- Global reference
						ScenarioInfo.BuilderTable[self.CurrentPlan][pType][BuilderName] = builder
						-- We found our builder, break out
						break
					end
				end

				-- Finally, insert the handles that will keep track of how many platoons of this type exists, and are being built
				PBMPlatoonBuilder.PlatoonHandles = {}
				for i = 1, num do
					TableInsert(PBMPlatoonBuilder.PlatoonHandles, false)
				end
            end
        end

        self.HasPlatoonList = true
    end,

    ---@param self CampaignAIBrain
    ---@param builderName string
    PBMRemoveBuilder = function(self, builderName)
        for pType, builders in self.PBM.Platoons do
            for num, data in builders do
                if data.BuilderName == builderName then
                    self.PBM.Platoons[pType][num] = nil
                    ScenarioInfo.BuilderTable[self.CurrentPlan][pType][builderName] = nil
                    break
                end
            end
        end
    end,

	---@param self CampaignAIBrain
    ---@param factories Unit
    ---@param primary Unit
    PBMAssistGivenFactory = function(self, factories, primary)
        for _, v in factories do
            if not v.Dead and not (v:IsUnitState('Building') or v:IsUnitState('Upgrading')) then
                local guarded = v:GetGuardedUnit()
                if not guarded or guarded.EntityId ~= primary.EntityId then
                    IssueToUnitClearCommands(v)
                    IssueFactoryAssist({v}, primary)
                end
            end
        end
    end,
	
	---@param self CampaignAIBrain
    PBMCheckBusyFactories = function(self)
        local busyPlat = self:GetPlatoonUniquelyNamed('BusyFactories')
        if not busyPlat then
            busyPlat = self:MakePlatoon('', '')
            busyPlat:UniquelyNamePlatoon('BusyFactories')
        end

        local poolPlat = self:GetPlatoonUniquelyNamed('ArmyPool')
        local poolTransfer = {}
        for _, v in poolPlat:GetPlatoonUnits() do
            if not v.Dead and EntityCategoryContains(categories.FACTORY - categories.EXTERNALFACTORYUNIT - categories.MOBILE, v) and (v:IsUnitState('Building') or v:IsUnitState('Upgrading')) then
                TableInsert(poolTransfer, v)
            end
        end

        local busyTransfer = {}
        for _, v in busyPlat:GetPlatoonUnits() do
            if not v.Dead and (v:IsUnitState('Building') or v:IsUnitState('Upgrading')) then
                TableInsert(busyTransfer, v)
            end
        end

        self:AssignUnitsToPlatoon(poolPlat, busyTransfer, 'Unassigned', 'None')
        self:AssignUnitsToPlatoon(busyPlat, poolTransfer, 'Unassigned', 'None')
    end,
	
	--- Main building and forming platoon thread for the Platoon Build Manager
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
			--self:PBMClearBuildConditionsCache()
            -- Go through the different types of platoons
            for typek, typev in self.PBM.PlatoonTypes do
                -- First go through the list of locations and see if we can build stuff there.
                for k, v in self.PBM.Locations do
                    -- See if we have platoons to build in that type
                    if not TableEmpty(platoonList[typev]) then
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
                            if not priFac.Dead then
                                numBuildOrders = priFac:GetNumBuildOrders(categories.ALLUNITS)
                                if numBuildOrders == 0 then
                                    local guards = priFac:GetGuards()
                                    if guards and not TableEmpty(guards) then
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
                                for index, builder in platoonList[typev] do
                                    -- Don't try to build things that are higher pri than 0
                                    -- This platoon requires construction and isn't just a form-only platoon.
                                    if priorityLevel and (builder.Priority ~= priorityLevel or not self.PBM.RandomSamePriority) then
                                            break
                                    elseif (not priorityLevel or priorityLevel == builder.Priority) and builder.Priority > 0 and builder.RequiresConstruction
                                            -- The location we're looking at is an allowed location
                                           and (builder.LocationType == v.LocationType or not builder.LocationType)
                                            -- Make sure there is a handle slot available
                                           and (self:PBMHandleAvailable(builder)) then
                                        -- Fix up the primary factories to fit the proper table required by CanBuildPlatoon
                                        local suggestedFactories = {v.PrimaryFactories[typev]}
                                        local factories = self:CanBuildPlatoon(builder.PlatoonTemplate, suggestedFactories)
                                        if factories and self:PBMCheckBuildConditions(builder) then
                                            priorityLevel = builder.Priority
                                            for i = 1, self:PBMNumHandlesAvailable(builder) do
                                                TableInsert(possibleTemplates, {Builder = builder, Index = index})
                                            end
                                        end
                                    end
                                end
                                if priorityLevel then
                                    local builderData = TableRandom(possibleTemplates)
                                    local Builder = builderData.Builder
                                    local Index = builderData.Index
                                    local suggestedFactories = {v.PrimaryFactories[typev]}
                                    local factories = self:CanBuildPlatoon(Builder.PlatoonTemplate, suggestedFactories)
									-- This is an altered version of the platoon template, so we gotta cache it on the builder, so we can form it later
									Builder.BuildTemplate = self:PBMBuildNumFactories(Builder.PlatoonTemplate, v, typev, factories)
									local template = Builder.BuildTemplate
									
                                    -- Check all the requirements to build the platoon
                                    -- The Primary Factory can actually build this platoon
                                    -- The platoon build condition has been met
									local ptnSize = personality:GetPlatoonSize()
                                    -- Finally, build the platoon.
                                    self:BuildPlatoon(template, factories, ptnSize)
                                    self:PBMSetHandleBuilding(self.PBM.Platoons[typev][Index])
                                    if Builder.GenerateTimeOut then
                                        Builder.BuildTimeOut = self:PBMGenerateTimeOut(Builder, factories, v, typev)
                                    else
                                        Builder.BuildTimeOut = Builder.BuildTimeOut
                                    end
                                    Builder.PlatoonTimeOutThread = self:ForkThread(self.PBMPlatoonTimeOutThread, Builder)
                                    if Builder.PlatoonBuildCallbacks then
                                        for cbk, cbv in Builder.PlatoonBuildCallbacks do
                                            import(cbv[1])[cbv[2]](self, Builder.PlatoonData)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                WaitTicks(1)
            end
            -- Do it all over again in 10 seconds.
            WaitSeconds(self.PBM.BuildCheckInterval or 10)
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
                if guards and not TableEmpty(guards) then
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
        for index, builder in platoonList[platoonType] do
            -- To build we need to accept the following:
            -- The platoon is required to be in the building state and it is
            -- or The platoon doesn't have a handle and either doesn't require to be building state or doesn't require construction
            -- all that and passes it's build condition function.
            if builder.Priority > 0 and (requireBuilding and self:PBMCheckHandleBuilding(builder)
					and numBuildOrders and numBuildOrders == 0
					and (not builder.LocationType or builder.LocationType == location.LocationType))
                    or (((self:PBMHandleAvailable(builder)) and (not requireBuilding or not builder.RequiresConstruction))
					and (not builder.LocationType or builder.LocationType == location.LocationType)
					and self:PBMCheckBuildConditions(builder)) then
                local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
                local formIt = false
                local template = builder.BuildTemplate or builder.PlatoonTemplate

                local flipTable = {}
                local squadNum = 3
                while squadNum <= TableGetn(template) do
                    if template[squadNum][2] < 0 then
                        TableInsert(flipTable, {Squad = squadNum, Value = template[squadNum][2]})
                        template[squadNum][2] = 1
                    end
                    squadNum = squadNum + 1
                end
				
				local ptnSize = personality:GetPlatoonSize()
                if location.Location and location.Radius and builder.LocationType then
                    formIt = poolPlatoon:CanFormPlatoon(template, ptnSize, location.Location, location.Radius)
                elseif not builder.LocationType then
                    formIt = poolPlatoon:CanFormPlatoon(template, ptnSize)
                end

                if formIt then
                    local hndl
                    if location.Location and location.Radius and builder.LocationType then
                        hndl = poolPlatoon:FormPlatoon(template, ptnSize, location.Location, location.Radius)
                        self:PBMStoreHandle(hndl, builder)
                        if builder.PlatoonTimeOutThread then
                            builder.PlatoonTimeOutThread:Destroy()
                        end
                    elseif not builder.LocationType then
                        hndl = poolPlatoon:FormPlatoon(template, ptnSize)
                        self:PBMStoreHandle(hndl, builder)
                        if builder.PlatoonTimeOutThread then
                            builder.PlatoonTimeOutThread:Destroy()
                        end
                    end
                    hndl.PlanName = template[2]

                    -- If we have specific AI, fork that AI thread
                    if builder.PlatoonAIFunction then
                        hndl:StopAI()
                        hndl:ForkAIThread(import(builder.PlatoonAIFunction[1])[builder.PlatoonAIFunction[2]])
                    end
					
					-- If we have an AI from "platoon.lua", use that
                    if builder.PlatoonAIPlan then
                        hndl:SetAIPlan(builder.PlatoonAIPlan)
                    end

                    -- If we have additional threads to fork on the platoon, do that as well.
					-- Note: These are platoon AI functions from "platoon.lua"
                    if builder.PlatoonAddPlans then
                        for papk, papv in builder.PlatoonAddPlans do
                            hndl:ForkThread(hndl[papv])
                        end
                    end
					
					-- If we have additional functions to fork on the platoon, do that as well
                    if builder.PlatoonAddFunctions then
                        for pafk, pafv in builder.PlatoonAddFunctions do
                            hndl:ForkThread(import(pafv[1])[pafv[2]])
                        end
                    end
					
					-- If we have additional behaviours to fork on the platoon, do that as well
					-- Note: These are platoon AI functions from "AIBehaviors.lua"
                    if builder.PlatoonAddBehaviors then
                        for pafk, pafv in builder.PlatoonAddBehaviors do
                            hndl:ForkThread(Behaviors[pafv])
                        end
                    end

					-- Global counter on how many platoons exists, defaults to (0 + 1) if this is the first time forming
                    if builder.BuilderName then
						self.PlatoonNameCounter[builder.BuilderName] = (self.PlatoonNameCounter[builder.BuilderName] or 0) + 1
                    end
					
                    hndl:AddDestroyCallback(self.PBMPlatoonDestroyed)
                    hndl.BuilderName = builder.BuilderName
					
					-- Set the platoon data
					-- Also set the platoon to be part of the attack force if specified in the platoon data, used for AttackManager platoon forming
                    if builder.PlatoonData then
                        hndl:SetPlatoonData(builder.PlatoonData)
						-- Set builder name as well so the global counter is actually decremented, and isn't increased indefinitely
						hndl.PlatoonData.BuilderName = builder.BuilderName
                        if builder.PlatoonData.AMPlatoons and not TableEmpty(builder.PlatoonData.AMPlatoons) then
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
	
	---Set number of units to be built as the number of factories in a location
    ---@param self CampaignAIBrain
    ---@param template any
    ---@param location Vector
    ---@param pType PlatoonType
    ---@param factory Unit
    ---@return table
    PBMBuildNumFactories = function (self, template, location, pType, factory)
        local retTemplate = table.deepcopy(template)
        local assistFacs = factory[1]:GetGuards()
        TableInsert(assistFacs, factory[1])
        local facs = {T1 = 0, T2 = 0, T3 = 0}
        for _, v in assistFacs do
            if EntityCategoryContains(categories.TECH3 * categories.FACTORY, v) then
                facs.T3 = facs.T3 + 1
            elseif EntityCategoryContains(categories.TECH2 * categories.FACTORY, v) then
                facs.T2 = facs.T2 + 1
            elseif EntityCategoryContains(categories.FACTORY, v) then
                facs.T1 = facs.T1 + 1
            end
        end
		
		-- Example of a template:
		-- {
        --     "T1AirBomber2",
        --     "HuntAI",
        --     {"uaa0103", -1, 5, "attack", "GrowthFormation"}
        -- },
		
		-- Handle any squads with a specified build quantity
        local squad = 3
        while squad <= TableGetn(retTemplate) do
			local element = retTemplate[squad]
            if element[2] > 0 then
                local bp = self:GetUnitBlueprint(element[1])
                local buildLevel = AIBuildUnits.UnitBuildCheck(bp)
                local remaining = element[3]
                while buildLevel <= 3 do
                    if facs['T'..buildLevel] > 0 then
                        if facs['T'..buildLevel] < remaining then
                            remaining = remaining - facs['T'..buildLevel]
                            facs['T'..buildLevel] = 0
                            buildLevel = buildLevel + 1
                        else
                            facs['T'..buildLevel] = facs['T'..buildLevel] - remaining
                            buildLevel = 10
                        end
                    else
                        buildLevel = buildLevel + 1
                    end
                end
            end
            squad = squad + 1
        end

        -- Handle squads with programatic build quantity
        squad = 3
        local remainingIds = {T1 = {}, T2 = {}, T3 = {}}
        while squad <= TableGetn(retTemplate) do
            if retTemplate[squad][2] < 0 then
                TableInsert(remainingIds['T'..AIBuildUnits.UnitBuildCheck(self:GetUnitBlueprint(retTemplate[squad][1])) ], retTemplate[squad][1])
            end
            squad = squad + 1
        end
        local rTechLevel = 3
        while rTechLevel >= 1 do
            for num, unitId in remainingIds['T'..rTechLevel] do
                for tempRow = 3, TableGetn(retTemplate) do
                    if retTemplate[tempRow][1] == unitId and retTemplate[tempRow][2] < 0 then
                        retTemplate[tempRow][3] = 0
                        for fTechLevel = rTechLevel, 3 do
                            retTemplate[tempRow][3] = retTemplate[tempRow][3] + (facs['T'..fTechLevel] * math.abs(retTemplate[tempRow][2]))
                            facs['T'..fTechLevel] = 0
                        end
                    end
                end
            end
            rTechLevel = rTechLevel - 1
        end

        -- Remove any IDs with 0 as a build quantity.
        for i = 1, TableGetn(retTemplate) do
            if i >= 3 then
                if retTemplate[i][3] == 0 then
                    TableRemove(retTemplate, i)
                end
            end
        end

        return retTemplate
    end,
	
	--- PBM platoon DestroyedCallback type, called when the platoon is either completely killed off (excluding uniquely named ones), or is disbanded
	---@param self CampaignAIBrain
    ---@param platoon Platoon
    PBMPlatoonDestroyed = function(self, platoon)
        self:PBMRemoveHandle(platoon)
		local PlatoonData = platoon.PlatoonData
        if platoon.PlatoonData.BuilderName then
            self.PlatoonNameCounter[PlatoonData.BuilderName] = self.PlatoonNameCounter[PlatoonData.BuilderName] - 1
        end
    end,
	
	--- Checks the build conditions of the given platoon builder
	---	Sets a flag that we'll use as a cache data, so we don't need to check BCs both in the main thread, and when we actually form platoons
	---@param self CampaignAIBrain
    ---@param builder table | Platoon builder table
    ---@return boolean
    PBMCheckBuildConditions = function(self, builder)
		-- If all BCs were met previously, return true
		--if builder.BuildConditionsMet then
			--return true
		--end
		
		local BuildConditions = builder.BuildConditions
		-- Contents of a BC table: [1] => file path; [2] => function name; [3] => table of parameters
		for index, condition in BuildConditions do
			-- Remove the param "default_brain" from BCs, this is a leftover from GPG when they made their SC1 save.lua files either for maps, or for the ones in 'lua/AI/OpAI'
			-- They probably had an internal editor that made these, and changed how the AI handles BCs after said editor was already in use, and/or they moved AI functionalities from the engine to Lua
			-- GPG removed them when checking BCs, and we'll do the same, we gotta do it here because new BCs can be added after the builder was loaded into the brain
			if condition[3][1] == "default_brain" then
				TableRemove(condition[3], 1)
			end
			
			-- ALL conditions must be met at the same time
			-- If any of the conditions is false, set the cache as nil, and return false
			if not import(condition[1])[condition[2]](self, unpack(condition[3])) then
				--builder.BuildConditionsMet = nil
				return false
			end
		end
	
		-- All conditions are true, cache the result in the builder table, and return true
		--builder.BuildConditionsMet = true
        return true
    end,
	
	--- Sets all cached BC flag to nil, this is done for each platoon builder
	---@param self CampaignAIBrain
    PBMClearBuildConditionsCache = function(self)
		-- Local reference to the platoon types table
		local PlatoonTypes = self.PBM.PlatoonTypes
		local PlatoonBuilders = self.PBM.Platoons
		
		-- Loop through each builder type, and builder
		-- Reset each builders' BC cache to nil
		for indexType, platoonType in PlatoonTypes do
			for indexBuilder, platoonBuilder in PlatoonBuilders[platoonType] do
				platoonBuilder.BuildConditionsMet = nil
			end
		end
    end,
	
	---@param self CampaignAIBrain
    ---@param loc Vector
    ---@return Vector | false
    PBMGetLocationCoords = function(self, loc)
        if not loc then
            return false
        end
        if self.HasPlatoonList then
            for _, v in self.PBM.Locations do
                if v.LocationType == loc then
                    local height = GetTerrainHeight(v.Location[1], v.Location[3])
                    if GetSurfaceHeight(v.Location[1], v.Location[3]) > height then
                        height = GetSurfaceHeight(v.Location[1], v.Location[3])
                    end
                    return {v.Location[1], height, v.Location[3]}
                end
            end
        end
        return false
    end,

    ---@param self CampaignAIBrain
    ---@param loc Vector
    ---@return boolean
    PBMGetLocationRadius = function(self, loc)
        if not loc then
            return false
        end
        if self.HasPlatoonList then
            for k, v in self.PBM.Locations do
                if v.LocationType == loc then
                   return v.Radius
                end
            end
        end
        return false
    end,
	
	--- Checks if the factory provided is inside the location's base radius
	---@param self CampaignAIBrain
    ---@param factory Unit
    ---@param location Vector
    ---@return boolean
    PBMFactoryLocationCheck = function(self, factory, location)
		-- If the factory is an external one, return false right away
		if EntityCategoryContains(categories.EXTERNALFACTORYUNIT, factory) then
			return false
		end
		
        -- If passed in a PBM Location table or location type name
        local LocationName = location
        if type(location) == 'table' then
            LocationName = location.LocationType
        end
		factory.PBMData = factory.PBMData or {}

        -- Calculate distance to a location type if it doesn't exist yet
        if not factory.PBMData[LocationName] then
            -- Location of the factory
            local FactoryPosition = factory:GetPosition()
			local LocationPosition
            -- Find location of the PBM Location Type
            if type(location) == 'table' then
                LocationPosition = location.Location
            else
                LocationPosition = self:PBMGetLocationCoords(LocationName)
            end
            factory.PBMData[LocationName] = VDist2(LocationPosition[1], LocationPosition[3], FactoryPosition[1], FactoryPosition[3])
        end

        local Closest, Distance
        for Location, Data in factory.PBMData do
            if not Distance or Data < Distance then
                Distance = Data
                Closest = Location
            end
        end

        return Closest and Closest == LocationName
    end,
	
	---@param self CampaignAIBrain
    ---@param location Vector
    ---@param pType PlatoonType
    ---@return integer
    PBMGetNumFactoriesAtLocation = function(self, location, pType)
        local airFactories = {}
        local landFactories = {}
        local seaFactories = {}
        local gates = {}
        local factories = self:GetAvailableFactories(location.Location, location.Radius)
        local numFactories = 0
        for ek, ev in factories do
            if EntityCategoryContains(categories.FACTORY * categories.AIR - categories.EXTERNALFACTORYUNIT, ev) then
                TableInsert(airFactories, ev)
            elseif EntityCategoryContains(categories.FACTORY * categories.LAND - categories.EXTERNALFACTORYUNIT, ev) then
                TableInsert(landFactories, ev)
            elseif EntityCategoryContains(categories.FACTORY * categories.NAVAL - categories.EXTERNALFACTORYUNIT, ev) then
                TableInsert(seaFactories, ev)
            elseif EntityCategoryContains(categories.FACTORY * categories.GATE - categories.EXTERNALFACTORYUNIT, ev) then
                TableInsert(gates, ev)
            end
        end

        local retFacs = {}
        if pType == 'Air' then
            numFactories = TableGetn(airFactories)
        elseif pType == 'Land' then
            numFactories = TableGetn(landFactories)
        elseif pType == 'Sea' then
            numFactories = TableGetn(seaFactories)
        elseif pType == 'Gate' then
            numFactories = TableGetn(gates)
        end

        return numFactories
    end,
	
	--- Initializes, or adjusts the IMAP layout for the AI depending on the map size
	--- The IMAP grid is used by the AI extensively to get basic data on what threats are where, and originates from the engine side, but some things can be messed with on the Lua side
	--- AIs assign several different threat values for each IMAP grid according to what intel they have
	---@param self CampaignAIBrain
	IMAPConfiguration = function(self)
        -- Used to configure imap values, used for setting threat ring sizes depending on map size to try and get a somewhat decent radius
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
		
		-- Define the actual table if it doesn't exist yet
		self.IMAPConfig = self.IMAPConfig or {}
		
		-- Configure the imap attributes depending on the map size
        if maxmapdimension == 256 then
            self.IMAPConfig.OgridRadius = 22.5
            self.IMAPConfig.IMAPSize = 32
            self.IMAPConfig.Rings = 2
        elseif maxmapdimension == 512 then
            self.IMAPConfig.OgridRadius = 22.5
            self.IMAPConfig.IMAPSize = 32
            self.IMAPConfig.Rings = 2
        elseif maxmapdimension == 1024 then
            self.IMAPConfig.OgridRadius = 45.0
            self.IMAPConfig.IMAPSize = 64
            self.IMAPConfig.Rings = 1
        elseif maxmapdimension == 2048 then
            self.IMAPConfig.OgridRadius = 89.5
            self.IMAPConfig.IMAPSize = 128
            self.IMAPConfig.Rings = 0
        else
            self.IMAPConfig.OgridRadius = 180.0
            self.IMAPConfig.IMAPSize = 256
            self.IMAPConfig.Rings = 0
        end
    end,
	
	-----------------------
	-- OpAI Template Thread
	-----------------------
	--- Thread that will update OpAI templates that were set to only generate buildable templates
	--- Due to primary factories are being grabbed periodically by the brain, and their state can change as the game goes on (destroyed, upgraded, etc.), the templates can become unbuildable
	--- To fix this, we check if any only-buildable OpAI templates are invalid, and update them as needed via this thread
	BrainUpdateOpAITemplates = function(self)
		while self.AllowUpdateTemplates do
			local OpAITable = self.OpAIs or {}	-- OpAI instances are stored inside the AI brains' "OpAIs" table
			-- If the OpAI instance was set to generate only buildable templates check if there's a valid primary factory, and if it can't build the current template
			for index, OpAI in OpAITable do
				if OpAI.GenerateOnlyBuildableTemplates then
					local PrimaryFactory = OpAI:GetPrimaryFactory()
					-- "CanBuildPlatoon()" needs a table of factories
					if PrimaryFactory and not self:CanBuildPlatoon(OpAI:GetPlatoonTemplate(), {PrimaryFactory}) then
						OpAI:OverridePlatoonTemplate()
					end
				end
			end
			
			WaitSeconds(25)
		end
	end,

}
end