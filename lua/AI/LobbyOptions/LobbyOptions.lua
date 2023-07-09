AIOpts = {
    {
        default = 1,
        label = "Enable/Disable Campaign AI cheats",
        help = "Enable, or disable Campaign AI cheats, they are applied to all AI armies, including allied ones.",
        key = 'CampaignAICheat',
        values = {
            {
                text = "Disabled",
                help = "Campaign AIs will not receive any cheat modifiers.",
                key = 1,
            },
            {
                text = "Enabled",
                help = "Campaign AIs will receive cheat modifiers.",
                key = 2,
            },
        },
    },
	{
        default = 1,
        label = "Economy Cheat Rates:",
        help = "Set the Economy cheat multiplier for the Campaign AIs, only relevant if the cheats are enabled. 1.0 rate is no change, in case you want to apply just 1 type of cheat.",
        key = 'CampaignCheatMult',
		value_text = "%s",
        value_help = "Cheat multiplier of %s",
        values = {
            '1.0', '1.25', '1.5', '1.75', '2.0', '2.25', '2.5', '2.75', '3.0', '3.25', '3.5', '3.75', '4.0',
        },
    },
	{
        default = 1,
        label = "Build Power Cheat Rates:",
        help = "Set the Build Power cheat multiplier for the Campaign AIs, only relevant if the cheats are enabled. 1.0 rate is no change, in case you want to apply just 1 type of cheat.",
		key = 'CampaignBuildMult',
		value_text = "%s",
        value_help = "Cheat multiplier of %s",
        values = {
			'1.0', '1.25', '1.5', '1.75', '2.0', '2.25', '2.5', '2.75', '3.0', '3.25', '3.5', '3.75', '4.0',
        },
    },
}
