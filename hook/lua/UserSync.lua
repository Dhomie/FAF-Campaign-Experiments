--- Allow for UI ping groups to be updated
do
	local CampaignOnSync = OnSync
	OnSync = function()
		CampaignOnSync()
		if Sync.UpdatePingGroups then
			import('/lua/ui/game/objectives2.lua').UpdatePingGroups(Sync.UpdatePingGroups)
		end
	end
end