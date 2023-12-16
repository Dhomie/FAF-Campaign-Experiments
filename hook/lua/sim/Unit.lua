do

local CampaignUnit = Unit

Unit = Class(CampaignUnit) {
	---@param self Unit
    OnCreate = function(self)
		CampaignUnit.OnCreate(self)
		
		if self.Brain.CampaignCheatEnabled then
			import("/lua/ai/aiutilities.lua").ApplyCampaignCheatBuffs(self)
		end
	end,
}
end