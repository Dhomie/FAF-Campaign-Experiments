local Utilities = import("/lua/utilities.lua")

------------------------------------------------------------------------------------------------------------------------
--- This is the AttackManager class that is used for campaign/coop
--- Vanilla Supreme Commander (refered to as *SC1* from now on) used this along with the PBM for its skirmish AI as well
--- A quick rundown how it works in practice:
---		- It's used by the "BaseOpAI.lua", with platoons created via the BaseManager
---		- The BaseManager builds a bunch of PBM platoons, then combines them into an AM platoon
---		- The PBM platoons are defined in the many *save.lua files in "lua/AI/OpAI"
---		- Platoons containing the 'Child' name are the ones to be combined
---		- Platoons containing the 'Master' name are the ones to be converted to AM Platoons
---		- This allows for easier creation of mixed platoon compositions
---		- The AM is capable of forming random platoon compositions this way
---		- It's also less likely to leave units sitting at bases, since it combines existing platoons into a new one
---		- The loading of platoons is handled in "ScenarioUtilities.lua", in the 'OSB' related functions
-------------------------------------------------------------------------------------------------------------------------
--- An example of the Attack Manager platoon 'builder' template:
---
---    Platoons = 
---		{
---        {
---            PlatoonName = string,
---            AttackConditions = { function, {args} },
---            AIThread = function, -- If AMPlatoon needs a specific function
---            AIName = string, -- AIs from platoon.lua
---            Priority = num,
---            PlatoonData = table,
---            OverrideFormation = string, -- formation to use for the attack platoon
---            FormCallbacks = table, -- table of functions called when an AM Platoon forms
---            DestroyCallbacks = table, -- table of functions called when the platoon is destroyed
---            LocationType = string, -- location from PBM -- used if you want to get units from pool
---            PlatoonType = string, -- 'Air', 'Sea', 'Land' -- MUST BE SET IF UsePool IS TRUE
---            UsePool = bool, -- bool to use pool or not
---        },
---    },

--- Example how to pick the master platoon - within PlatoonData
	--- PlatoonData = {
	---     AMPlatoons = { AMPlatoonName, AMPlatoonName, etc },
	--- },
--- Example how to set a master platoon - within PlatoonData
	--- PlatoonData = {
	---     AMMasterPlatoon = true,
	--- },

---@class AttackManager
---@field brain AI Brain
---@field PlatoonCount
---@field AttackCheckInterval How often the AM should attempt to form platoons
---@field Platoons Table of platoons belonging to the AI
---@field AttackManagerState Either 'ACTIVE' or 'PAUSED', used to check if the AM is active for an AI
---@field AttackManagerThread Bool, used to check if the main AM thread is already running
AttackManager = ClassSimple {
    brain = nil,
    NeedSort = false,
    PlatoonCount = { DefaultGroupAir = 0, DefaultGroupLand = 0, DefaultGroupSea = 0, },

    __init = function(self, brain, attackDataTable)
        self.Trash = TrashBag()
        self.brain = brain
        self:Initialize(table)
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
	
	---@param self AttackManager
    ---@param attackDataTable table
    Initialize = function(self, attackDataTable)
        self:AddDefaultPlatoons(attackDataTable.AttackConditions)
        if attackDataTable then
            self.AttackCheckInterval = attackDataTable.AttackCheckInterval or 15
            if attackDataTable.Platoons then
                self:AddPlatoonsTable(attackDataTable.Platoons)
            end
        elseif not self.AttackCheckInterval then
            self.AttackCheckInterval = 15
        end
        self['AttackManagerState'] = 'ACTIVE'
        self['AttackManagerThread'] = self:ForkThread(self.AttackManagerThread)
    end,
	
	--- The thread that forms the AM platoons periodically
	---@param self AttackManager
    AttackManagerThread = function(self)
        while true do
            WaitSeconds(self.AttackCheckInterval)
            if self.AttackManagerState == 'ACTIVE' and self.Platoons then
                self:AttackManageAttackVectors()
                self:FormAttackPlatoon()
            end
        end
    end,
	
	--- Loads the default AM platoons, these aren't formed in coop/campaign, they were used by SC1's skirmish AIs
	---@param self AttackManager
    ---@param AttackConds table | table of conditions that return with either true or false
    AddDefaultPlatoons = function(self, AttackConds)
        if not AttackConds then
            AttackConds = {
                { '/lua/editor/MiscBuildConditions.lua', 'False', {'default_brain'}},
            }
        end

        local platoons = {
            {
                PlatoonName = 'DefaultGroupAir',
                AttackConditions = AttackConds,
                AIName = 'HuntAI',
                Priority = 1,
                PlatoonType = 'Air',
                UsePool = true,
            },
            {
                PlatoonName = 'DefaultGroupLand',
                AttackConditions = AttackConds,
                AIName = 'AttackForceAI',
                Priority = 1,
                PlatoonType = 'Land',
                UsePool = true,
				PlatoonData = {
					UseFormation = 'GrowthFormation',
				}
            },
            {
                PlatoonName = 'DefaultGroupSea',
                AttackConditions = AttackConds,
                AIName = 'HuntAI',
                Priority = 1,
                PlatoonType = 'Sea',
                UsePool = true,
            },
        }

        self:AddPlatoonsTable(platoons)
    end,

	---@param self AttackManager
	---@param platoons table | table of platoons
    AddPlatoonsTable = function(self, platoons)
        for k,v in platoons do
            self:AddPlatoon(v)
        end
    end,
	
	---@param self AttackManager
	---@param pltnTable table | table of a platoon instance
    AddPlatoon = function(self, pltnTable)
        if not pltnTable.AttackConditions then
            error('*AI WARNING: INVALID ATTACK MANAGER PLATOON LIST - Missing AttackConditions', 2)
            return
        end
        if not pltnTable.AIThread and not pltnTable.AIName then
            error('*AI WARNING: INVALID ATTACK MANAGER PLATOON LIST - Mission either AIName or AIThread', 2)
            return
        end
        if not pltnTable.Priority then
            error('*AI WARNING: INVALID ATTACK MANAGER PLATOON LIST - Missing Priority', 2)
            return
        end
        if not pltnTable.UsePool then
            pltnTable.UsePool = false
        end
        if not self then
            self = {}
        end
        if not self.Platoons then
            self.Platoons = {}
        end
        self.NeedSort = true
        table.insert(self.Platoons, pltnTable)
    end,

	---@param self AttackManager
    ClearPlatoonList = function(self)
        self.Platoons = {}
        self.NeedSort = false
    end,
	
	---@param self AttackManager
	---@param interval number
    SetAttackCheckInterval = function(self, interval)
        self.AttackCheckInterval = interval
    end,
	
	---@param self AttackManager
	---@param pltnInfo table | table of a platoon instance
    CheckAttackConditions = function(self, pltnInfo)
        for k, v in pltnInfo.AttackConditions do
            if v[3][1] == "default_brain" then
                table.remove(v[3], 1)
            end
            if iscallable(v[1]) then
                if not v[1](self.brain, unpack(v[2])) then
                    return false
                end
            else
                if not import(v[1])[v[2]](self.brain, unpack(v[3])) then
                    return false
                end
            end
        end
        return true
    end,
	
	---@param self AttackManager
	---@param builderName string
	---@param priority number
    SetPriority = function(self, builderName, priority)
        for k,v in self.Platoons do
            if v.PlatoonName == builderName then
                v.Priority = priority
            end
        end
    end,
	
	---@param self AttackManager
    SortPlatoonsViaPriority = function(self)
        local sortedList = {}
        --Simple selection sort, this can be made faster later if we decide we need it.
        if self.Platoons then
            for i = 1, table.getn(self.Platoons) do
                local highest = 0
                local key, value
                for k, v in self.Platoons do
                    if v.Priority > highest then
                        highest = v.Priority
                        value = v
                        key = k
                    end
                end
                sortedList[i] = value
                table.remove(self.Platoons, key)
            end
            self.Platoons = sortedList
        end
        self.NeedSort = false
        return sortedList
    end,

	--- The main function that forms the AM platoons
	---@param self AttackManager
    FormAttackPlatoon = function(self)
        local poolPlatoon = self.brain:GetPlatoonUniquelyNamed('ArmyPool')

        if self.NeedSort then
            self:SortPlatoonsViaPriority()
        end
		
		--Loop through all of the AM platoons
        for k,v in self.Platoons do
            if self:CheckAttackConditions(v) then
                local combineList = {}
                local platoonList = self.brain:GetPlatoonsList()
				
				-- Loop through all of the platoons the AI has, check if it's part of the attack force
				-- The PBM platoons are the ones set to be part of the attack force, if they have 'AMPlatoons' platoon data set, this is handled by the "PBMFormPlatoons()" function
				-- If it's part of it, check the PlatoonData for the name of the 'master' platoon it belongs to, and if it matches, insert this platoon to the combineList
				-- These are defined in the lua/AI/OpAI *save.lua files, containing all of the default platoons
                for j, platoon in platoonList do
                    if platoon:IsPartOfAttackForce() then
                        for i, name in platoon.PlatoonData.AMPlatoons do
                            if name == v.PlatoonName then
                                table.insert(combineList, platoon)
                            end
                        end
                    end
                end
				
				-- If the combineList is not empty, it will form the AM platoon
				-- Usually platoons inside the combineList are PBM ones
				-- If UsePool is true, it can cause some wonky behaviour, it can additionally grab units from the ArmyPool, but will mess up the actual unit counts defined in the platoon templates
				-- This can result in platoons not forming properly, thus units sitting at their bases cluttering up
				-- By default it's practically not used at all
                if not table.empty(combineList) or v.UsePool then
                    local tempPlatoon
                    if self.Platoons[k].AIName then
                        tempPlatoon = self.brain:CombinePlatoons(combineList, v.AIName)
                    else
                        tempPlatoon = self.brain:CombinePlatoons(combineList)
                    end
                    local formation = 'GrowthFormation'
					
                    if v.PlatoonData.OverrideFormation then
                        tempPlatoon:SetPlatoonFormationOverride(v.PlatoonData.OverrideFormation)
                    elseif v.PlatoonType == 'Air' and not v.UsePool then
                        tempPlatoon:SetPlatoonFormationOverride('GrowthFormation')
                    end
					
					-- This section is only relevant if we want the AM platoon to grab from the ArmyPool, it was used for SC1's skirmish AI
					-- I've added additional categories to be filtered out, we don't want land platoons to grab unassigned transports or such in case we ever decide to make use of the ArmyPool
                    if v.UsePool then
                        local checkCategory
						--Only T1-T3 aerial combat units
                        if v.PlatoonType == 'Air' then
                            checkCategory = categories.AIR * categories.MOBILE - categories.TRANSPORTATION - categories.EXPERIMENTAL - categories.SCOUT
						--Only T1-T3 surface combat units
                        elseif v.PlatoonType == 'Land' then
                            checkCategory = categories.LAND * categories.MOBILE - categories.ENGINEER - categories.EXPERIMENTAL - categories.SCOUT
						--Only T1-T3 naval combat units
                        elseif v.PlatoonType == 'Sea' then
                            checkCategory = categories.NAVAL * categories.MOBILE - categories.EXPERIMENTAL
						--Only T1-T3 combined-arms combat units
                        elseif v.PlatoonType == 'Any' then
                            checkCategory = categories.MOBILE - categories.ENGINEER - categories.TRANSPORTATION - categories.EXPERIMENTAL - categories.SCOUT
                        else
                            error('*AI WARNING: Invalid Platoon Type - ' .. v.PlatoonType, 2)
                            break
                        end
						
                        local poolPlatoon = self.brain:GetPlatoonUniquelyNamed('ArmyPool')
                        local poolUnits = poolPlatoon:GetPlatoonUnits()
                        local addUnits = {}
						
						-- If the AM platoon has a base of origin, it will only grab ArmyPool units from near it
                        if v.LocationType then
                            local location = false
                            for locNum, locData in self.brain.PBM.Locations do
                                if v.LocationType == locData.LocationType then
                                    location = locData
                                    break
                                end
                            end
                            if not location then
                                SPEW('*AI WARNING: No EngineerManager present at location - ' .. v.LocationType, '[FormAttackPlatoon]')
                                break
                            end
                            for i,unit in poolUnits do
                                if Utilities.GetDistanceBetweenTwoVectors(unit:GetPosition(), location.Location) <= location.Radius and EntityCategoryContains(checkCategory, unit) then
                                    table.insert(addUnits, unit)
                                end
                            end
						-- If there's no base of origin, grab ArmyPool units from anywhere
                        else
                            for i,unit in poolUnits do
                                if EntityCategoryContains(checkCategory, unit) then
                                    table.insert(addUnits, unit)
                                end
                            end
                        end
                        self.brain:AssignUnitsToPlatoon(tempPlatoon, addUnits, 'Attack', formation)
                    end
					
					-- Set the platoon's data
                    if v.PlatoonData then
                        tempPlatoon:SetPlatoonData(v.PlatoonData)
                    else
                        tempPlatoon.PlatoonData = {}
                    end
					-- Set the platoon's name
                    tempPlatoon.PlatoonData.PlatoonName = v.PlatoonName
					--LOG('*AI DEBUG: ARMY ' .. repr(self.brain:GetArmyIndex()) .. ': AM Master Platoon formed - ' .. repr(v.BuilderName))
					
					-- Cache the origin base into the platoon
					if v.LocationType then
						tempPlatoon.LocationType = v.LocationType
						--LOG('*AI DEBUG: ARMY ' .. repr(self.brain:GetArmyIndex()) .. ': AM Master Platoon originates from base: ' .. repr(tempPlatoon.LocationType))
					end
					
					-- Set the platoon AI function
                    if v.AIThread then
                        tempPlatoon:ForkAIThread(import(v.AIThread[1])[v.AIThread[2]])
                        --LOG('*AM DEBUG: AM Master Platoon using AI Thread: ', repr(v.AIThread[2]), ' Builder named: ', repr(v.BuilderName))
					end
					
					-- Add callbacks when the platoon is destroyed
                    if v.DestroyCallbacks then
                        for dcbNum, destroyCallback in v.DestroyCallbacks do
                            tempPlatoon:AddDestroyCallback(import(destroyCallback[1])[destroyCallback[2]])
                            --LOG('*AM DEBUG: AM Master Platoon adding destroy callback: ', destroyCallback[2], ' Builder named: ', repr(v.BuilderName))
                        end
                    end
					
					-- Call for the specified callbacks, since we were just formed
                    if v.FormCallbacks then
                        for cbNum, callback in v.FormCallbacks do
                            if type(callback) == 'function' then
                                self.Trash:Add(ForkThread(callback, tempPlatoon))
                            else
                                self.Trash:Add(ForkThread(import(callback[1])[callback[2]], tempPlatoon))
                            end
                            --LOG('*AM DEBUG: AM Master Platoon Form callback: ', repr(callback[2]), ' Builder Named: ', repr(v.BuilderName))
                        end
                    end
                end
            end
        end
    end,
	
	--- Completely removes the AM thread
	---@param self AttackManager
    DestroyAttackManager = function(self)
        if self.AttackManagerThread then
            self.AttackManagerThread:Destroy()
            self.AttackManagerThread = nil
        end
    end,
	
	--- Pauses the AM thread
	---@param self AttackManager
    PauseAttackManager = function(self)
        self.AttackManagerState = 'PAUSED'
    end,
	
	--- Re-enables the AM thread
	---@param self AttackManager
    UnPauseAttackManager = function(self)
        self.AttackManagerState = 'ACTIVE'
    end,
	
	--- Checks if the AttackManager has been enabled
	---@param self AttackManager
	---@return boolean
    IsAttackManagerActive = function(self)
        if self and self.AttackManagerThread and self.AttackManagerState == 'ACTIVE' then
            return true
        end
        return false
    end,
	
	--- Returns with the number of platoons part of the attack force
	---@param self AttackManager
	---@return result number
    GetNumberAttackForcePlatoons = function(self)
        local platoonList = self.brain:GetPlatoonsList()
        local result = 0
        for k, v in platoonList do
            if v:IsPartOfAttackForce() then
                result = result + 1
            end
        end
        --Add in pool platoon, pool platoon is always used.
        result = result + 1
        return result
    end,
	
	---@param self AttackManager
    AttackManageAttackVectors = function(self)
        local enemyBrain = self.brain:GetCurrentEnemy()
        if enemyBrain then
            self.brain:SetUpAttackVectorsToArmy()
        end
    end,
	
    -- XXX: refactor this later, artifact from moving AttackManager from aibrain
	---@param brain AIBrain
	---@param platoon Platoon
    DecrementCount = function(brain, platoon)
        local AM = brain.AttackManager
        local data = platoon.PlatoonData
        for k,v in data.AMPlatoons do
            AM.PlatoonCount[v] = AM.PlatoonCount[v] - 1
        end
    end
}
