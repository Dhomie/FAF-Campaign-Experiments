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
		
        --Default can remain 'NoFormation', but in 99% of the cases we always use formations for coop
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'	--Valid formation types: 'AttackFormation', 'GrowthFormation', 'NoFormation'
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