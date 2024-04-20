--------------------
-- Cheat Utilities
--------------------

---@param aiBrain AIBrain
---@param cheatBool boolean
function SetupCampaignCheat(aiBrain, cheatBool)
    if cheatBool then
        aiBrain.CampaignCheatEnabled = true

        local buffDef = Buffs['CheatBuildRate']
        local buffAffects = buffDef.Affects
        buffAffects.BuildRate.Mult = tonumber(ScenarioInfo.Options.CampaignBuildMult)

        buffDef = Buffs['CheatIncome']
        buffAffects = buffDef.Affects
        buffAffects.EnergyProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)
        buffAffects.MassProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)

        local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        for _, v in pool:GetPlatoonUnits() do
            -- Apply build rate and income buffs
            ApplyCampaignCheatBuffs(v)
        end
    end
end

---@param unit Unit
function ApplyCampaignCheatBuffs(unit)
    Buff.ApplyBuff(unit, 'CheatIncome')
    Buff.ApplyBuff(unit, 'CheatBuildRate')
	
	-- "Update" the multipliers every time a unit is created
	-- Certain maps use map script to change the multipliers during the middle of the mission, so we gotta change them back
	local buffDef = Buffs['CheatBuildRate']
	local buffAffects = buffDef.Affects
    buffAffects.BuildRate.Mult = tonumber(ScenarioInfo.Options.CampaignBuildMult)

    buffDef = Buffs['CheatIncome']
    buffAffects = buffDef.Affects
    buffAffects.EnergyProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)
    buffAffects.MassProduction.Mult = tonumber(ScenarioInfo.Options.CampaignCheatMult)
	
	-- Flag the unit as buffed, to avoid duplicate buff applications on maps that manually buff units via map script
	unit.EcoBuffed = true
	unit.BuildBuffed = true
end