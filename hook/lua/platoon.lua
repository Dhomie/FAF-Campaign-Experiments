--------------------------------------------------------------------------
--- File     :  mods/Coop_AI_Mod/hook/lua/platoon.lua
--- Summary  : Modifications for some of the platoon AI fuctions for coop
---
--- Copyright © 2007 Gas Powered Games, Inc.  All rights reserved.
--------------------------------------------------------------------------
local AIUtils = import("/lua/ai/aiutilities.lua")
local Utilities = import("/lua/utilities.lua")
local AIBuildStructures = import("/lua/ai/aibuildstructures.lua")
local UpgradeTemplates = import("/lua/upgradetemplates.lua")
local Behaviors = import("/lua/ai/aibehaviors.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local SPAI = import("/lua/scenarioplatoonai.lua")
local TransportUtils = import("/lua/ai/transportutilities.lua")

--for sorian AI
local SUtils = import("/lua/ai/sorianutilities.lua")

---@alias PlatoonSquads 'Attack' | 'Artillery' | 'Guard' | 'None' | 'Scout' | 'Support' | 'Unassigned'
local CampaignPlatoon = Platoon

Platoon = Class(CampaignPlatoon) {
	
	---@param self Platoon
    DisbandAI = function(self)
		local aiBrain = self:GetBrain()
		
        self:Stop()
        aiBrain:DisbandPlatoon(self)
    end,
	
	--- Function: NavalHuntAI
	--- Basic attack logic. Searches for a target unit, and attacks it, otherwise patrols Naval Area marker positions
	---@param self Platoon
    NavalHuntAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local cmd = false
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local atkPri = { 'STRUCTURE ANTINAVY', 'MOBILE NAVAL', 'STRUCTURE NAVAL', 'COMMAND', 'EXPERIMENTAL', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'ARTILLERY EXPERIMENTAL', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'STRUCTURE ANTIMISSILE SILO',
                            'STRUCTURE DEFENSE DIRECTFIRE', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'STRUCTURE', 'MOBILE', 'ALLUNITS' }
        local atkPriTable = {}
        for k,v in atkPri do
            table.insert(atkPriTable, ParseEntityCategory(v))
        end
        self:SetPrioritizedTargetList('Attack', atkPriTable)
        local maxRadius = 6000
        for k,v in self:GetPlatoonUnits() do

            if v.Dead then
                continue
            end

            if v.Layer == 'Sub' then
                continue
            end

            if v:TestCommandCaps('RULEUCC_Dive') and v.UnitId != 'uas0401' then
                IssueDive({v})
            end
        end
        WaitSeconds(5)
        while aiBrain:PlatoonExists(self) do
            target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius, atkPri)
            if target then
                self:Stop()
                cmd = self:AggressiveMoveToLocation(target:GetPosition())
            end
            WaitSeconds(5)
            if (not cmd or not self:IsCommandsActive(cmd)) then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
                if target then
                    self:Stop()
                    cmd = self:AggressiveMoveToLocation(target:GetPosition())
                else
                    local scoutPath = {}
                    scoutPath = AIUtils.AIGetSortedNavalLocations(self:GetBrain())
                    for k, v in scoutPath do
                        self:Patrol(v)
                    end
                end
            end
            WaitSeconds(20)
        end
    end,
	
	--- Function: NavalForceAI
    --- Basic attack logic for boats.  Searches for a good area to go attack, and will use a safe path (if available) to get there.
    ---@param self Platoon
    NavalForceAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()

        AIAttackUtils.GetMostRestrictiveLayer(self)

        local platoonUnits = self:GetPlatoonUnits()
        local numberOfUnitsInPlatoon = table.getn(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local stuckCount = 0

        self.PlatoonAttackForce = true
		
        -- Assign formation, defaults to 'GrowthFormation'
        local PlatoonFormation = self.PlatoonData.UseFormation or 'GrowthFormation' -- Valid formation types: 'AttackFormation', 'GrowthFormation', 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)

		-- Issue a dive for submarines if for some reason they are surfaced
        for k,v in self:GetPlatoonUnits() do
            if v.Dead then
                continue
            end

            if v.Layer != 'Sub' then
                continue
            end

            if v:TestCommandCaps('RULEUCC_Dive') then
                IssueDive({v})
            end
        end

        while aiBrain:PlatoonExists(self) do
            local pos = self:GetPlatoonPosition() -- Update positions; prev position done at end of loop so not done first time

            -- If we can't get a position, then we must be dead
            if not pos then
                break
            end

            -- Pick out the enemy
            if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy():IsDefeated() then
                aiBrain:PickEnemyLogic()
            end

            -- Rebuild formation
            platoonUnits = self:GetPlatoonUnits()
            numberOfUnitsInPlatoon = table.getn(platoonUnits)
            -- If we have a different number of units in our platoon, regather
            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) then
                self:StopAttack()
                self:SetPlatoonFormationOverride(PlatoonFormation)
            end
            oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k,v in self:GetPlatoonUnits() do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        table.insert(cmdQ, cmdVal)
                        break
                    end
                end
            end

            -- If we're on our final push through to the destination, and we find a unit close to our destination
            local closestTarget
            local NavalPriorities = {
                'ANTINAVY - MOBILE',
                'NAVAL MOBILE',
                'NAVAL FACTORY',
                'COMMAND',
                'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE',
                'EXPERIMENTAL LAND',
                'TECH3 ENERGYPRODUCTION STRUCTURE',
                'TECH2 ENERGYPRODUCTION STRUCTURE',
                'TECH3 MASSEXTRACTION STRUCTURE',
                'INTELLIGENCE STRUCTURE',
                'TECH3 SHIELD STRUCTURE',
                'TECH2 SHIELD STRUCTURE',
                'TECH2 MASSEXTRACTION STRUCTURE',
                'TECH3 FACTORY',
                'TECH2 FACTORY',
                'TECH1 FACTORY',
                'TECH1 MASSEXTRACTION STRUCTURE',
                'TECH3 STRUCTURE',
                'TECH2 STRUCTURE',
                'TECH1 STRUCTURE',
                'TECH3 MOBILE LAND',
            }

            local nearDest = false
            local oldPathSize = table.getn(self.LastAttackDestination)
            local maxRange = AIAttackUtils.GetNavalPlatoonMaxRange(aiBrain, self)
            if maxRange then maxRange = maxRange + 30 end --DUNCAN - added

            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < maxRange
            end

            for _, priority in NavalPriorities do
                closestTarget = self:FindClosestUnit('attack', 'enemy', true, ParseEntityCategory(priority))
                if closestTarget and VDist3(closestTarget:GetPosition(), pos) < maxRange then
                    --LOG('*AI DEBUG: Found Naval target: ' .. priority)
                    break
                end
            end

            -- If we're near our destination and we have a unit closeby to kill, kill it
            -- DUNCAN - dont worry about command queue "table.getn(cmdQ) <= 1 and"
            if closestTarget and VDist3(closestTarget:GetPosition(), pos) < maxRange and nearDest then
                self:StopAttack()
                if PlatoonFormation != 'No Formation' then
                    self:AttackTarget(closestTarget)
                    --IssueFormAttack(platoonUnits, closestTarget, PlatoonFormation, 0)
                else
                    self:AttackTarget(closestTarget)
                    --IssueAttack(platoonUnits, closestTarget)
                end
                cmdQ = {1}
            -- If we have nothing to do, try finding something to do
            elseif table.empty(cmdQ) then
                self:StopAttack()
                cmdQ = AIAttackUtils.AIPlatoonNavalAttackVector(aiBrain, self)
                stuckCount = 0
            -- If we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 100) then
                stuckCount = stuckCount + 1
                if stuckCount >= 2 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonNavalAttackVector(aiBrain, self)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos

            -- Wait a while if we're stuck so that we have a better chance to move
            WaitSeconds(5 + 2 * stuckCount)
        end
    end,
	
	--- Function: AttackForceAI
    --- Basic attack logic.  Searches for a good area to go attack, and will use a safe path (if available) to get there.
	--- Modified to never disband, or guard engineers whatsoever, for coop usage.
    --- See AIAttackUtils for the bulk of the logic
    ---@param self Platoon
    AttackForceAI = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()

        -- Setup the formation based on platoon functionality
        local enemy = aiBrain:GetCurrentEnemy()

        local platoonUnits = self:GetPlatoonUnits()
        local numberOfUnitsInPlatoon = table.getn(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local stuckCount = 0

        self.PlatoonAttackForce = true
		
        -- Assign formation, defaults to 'GrowthFormation'
        local PlatoonFormation = self.PlatoonData.UseFormation or 'GrowthFormation'	-- Valid formation types: 'AttackFormation', 'GrowthFormation', 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)

        while aiBrain:PlatoonExists(self) do
            local pos = self:GetPlatoonPosition() -- update positions; prev position done at end of loop so not done first time

            -- if we can't get a position, then we must be dead
            if not pos then
                break
            end

            -- if we're using a transport, wait for a while
            if self.UsingTransport then
                WaitSeconds(10)
                continue
            end

            -- pick out the enemy
            if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy():IsDefeated() then
                aiBrain:PickEnemyLogic()
            end

            -- rebuild formation
            platoonUnits = self:GetPlatoonUnits()
            numberOfUnitsInPlatoon = table.getn(platoonUnits)
            -- if we have a different number of units in our platoon, regather
            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) then
                self:StopAttack()
                self:SetPlatoonFormationOverride(PlatoonFormation)
            end
            oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k, v in platoonUnits do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        table.insert(cmdQ, cmdVal)
                        break
                    end
                end
            end

            -- if we're on our final push through to the destination, and we find a unit close to our destination
            local closestTarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS)
            local nearDest = false
            local oldPathSize = table.getn(self.LastAttackDestination)
            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < 20
            end

            -- if we're near our destination and we have a unit closeby to kill, kill it
            if table.getn(cmdQ) <= 1 and closestTarget and VDist3(closestTarget:GetPosition(), pos) < 20 and nearDest then
                self:StopAttack()
                if PlatoonFormation != 'NoFormation' then
                    IssueFormAttack(platoonUnits, closestTarget, PlatoonFormation, 0)
                else
                    IssueAttack(platoonUnits, closestTarget)
                end
                cmdQ = {1}
            -- if we have nothing to do, try finding something to do
            elseif table.empty(cmdQ) then
                self:StopAttack()
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVector(aiBrain, self)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 16) then
                stuckCount = stuckCount + 1
                if stuckCount >= 2 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVector(aiBrain, self)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos
			
            if table.empty(cmdQ) then
                WaitSeconds(5)
            else
				-- Wait a little longer if we're stuck so that we have a better chance to move
				WaitSeconds(5 + 2 * stuckCount)
			end
        end
    end,
	
	--- Assigns a platoon to the 'TransportPool' defined in "TransportUtilities.lua"
	---@param self Platoon
	AssignPlatoonToTransportPool = function(self)
		self:Stop()
		local aiBrain = self:GetBrain()
		
		for _, transport in self:GetPlatoonUnits() do
			if not transport.dead then
				TransportUtils.AssignTransportToPool(transport, aiBrain)
			end
		end
	end
}