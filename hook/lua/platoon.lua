--- Alterations of the main platoon class for campaign
CampaignPlatoon = Class(Platoon) {
	---@param self Platoon
    EnhanceAI = function(self)
        local aiBrain = self:GetBrain()
        local unit
        local data = self.PlatoonData
        for k, v in self:GetPlatoonUnits() do
            unit = v
            break
        end
        if unit then
            IssueStop({unit})
            IssueToUnitClearCommands(unit)
            for k,v in data.Enhancement do
                if not unit:HasEnhancement(v) then
                    local order = {
                        TaskName = "EnhanceTask",
                        Enhancement = v
                    }
                    LOG('*AI DEBUG: '..aiBrain.Nickname..' EnhanceAI Added Enhancement: '..v)
                    IssueScript({unit}, order)
                end
            end
            WaitSeconds(data.TimeBetweenEnhancements or 1)
            repeat
                WaitSeconds(5)
                LOG('*AI DEBUG: '..aiBrain.Nickname..' Com still upgrading ')
            until unit.Dead or unit:IsIdleState()
            LOG('*AI DEBUG: '..aiBrain.Nickname..' Com finished upgrading ')
        end
        self:DisbandPlatoon()
    end,
}