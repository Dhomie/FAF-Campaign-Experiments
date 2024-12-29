AIOpts = {
    {
        default = 1,
        label = "Campaign AI cheats",
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
        label = "Campaign AI T3 Nuke Launchers",
        help = "Enable, or disable Campaign AI T3 Nuke Launchers. This could mess with maps that use scripted methods of controlling Nuke Launchers. Enable this at your own risk!",
        key = 'CampaignAINukes',
        values = {
            {
                text = "Disabled",
                help = "Campaign AIs won't do anything new with T3 Nuke Launchers.",
                key = 1,
            },
            {
                text = "Enabled",
                help = "Campaign AIs will use T3 Nuke Launchers automatically, might mess up maps that use scripted methods of controlling Nuke Launchers.",
                key = 2,
            },
        },
    },
	{
        default = 1,
        label = "Campaign AI Economy Cheat Rates:",
        help = "Set the Economy cheat multiplier for the Campaign AIs, only relevant if the cheats are enabled. 1.0 rate is no change, in case you want to apply just 1 type of cheat.",
        key = 'CampaignCheatMult',
		value_text = "%s",
        value_help = "Cheat multiplier of %s",
        values = {
            '1.0', '1.25', '1.5', '1.75', '2.0', '2.25', '2.5', '2.75', '3.0', '3.25', '3.5', '3.75', '4.0', '4.5', '5.0', '5.5', '6.0', '6.5', '7.0', '7.5', '8.0',
        },
    },
	{
        default = 1,
        label = "Campaign AI Build Power Cheat Rates:",
        help = "Set the Build Power cheat multiplier for the Campaign AIs, only relevant if the cheats are enabled. 1.0 rate is no change, in case you want to apply just 1 type of cheat.",
		key = 'CampaignBuildMult',
		value_text = "%s",
        value_help = "Cheat multiplier of %s",
        values = {
			'1.0', '1.25', '1.5', '1.75', '2.0', '2.25', '2.5', '2.75', '3.0', '3.25', '3.5', '3.75', '4.0', '4.5', '5.0', '5.5', '6.0', '6.5', '7.0', '7.5', '8.0',
        },
    },
	{
        default = 1,
        label = "Campaign AI Construction Delay:",
        help = "Set the delay for AI Engineering units when to build another structure once it\'s current structure has been finished, in game ticks. 10 game ticks translates to 1 second, default is 5",
		key = 'EngineerBuildDelay',
		value_text = "%s",
        value_help = "Build delay of %s",
        values = {
			'5', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55', '60', '65', '70', '75', '80', '85', '90', '95', '100',
        },
    },
}
