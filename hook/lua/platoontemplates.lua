------------------------------------------------------------------------------
--  File     :  /lua/platoontemplates.lua
--  Author(s):	Gas Powered Games, Inc.
--	Edited by: Dhomie
--
--  Summary  :	Platoon templates for the skirmish AI edited to sit
--					a lot less in their bases, and actually attack stuff
--
--  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------------------
------------------------------
-- Platoons & Squads Templates 
------------------------------

-- Hard reference to all necessary unit IDs
local ChildrenTypes = {
	-- 'Any' category gets picked by the first available factory type, or defaults to 'Land', unless specified
	-- "OpAI.LoadAnyAsFactoryType" is used to set factory type as well
	
	---------------------
	-- Construction Units
	---------------------
		-- Engineers
		ArmoredCommandUnits = {U='uel0001', A='ual0001', c='url0001', A='xsl0001'},
		T1Engineers = {U='uel0105', A='ual0105', C='urb0105', S='xsl0105'},
		T2Engineers = {U='uel0208', A='ual0208', C='url0208', S='xsl0208'},
		T3Engineers = {U='uel0309', A='ual0309', C='url0309', S='xsl0309'},
		SupportCommandUnit = {U='uel0301', A='ual0301', C='url0301', S='xsl0301'},
		
		-- Faction specific types
		T2CombatEngineers = {U='xel0209'},	-- UEF T2 Combat Engineer
	
	------------
	-- Air Units
	------------
		-- T1
		AirScouts = {U='uea0101', A='uaa0101', C='ura0101', S='xsa0101'},
		Bombers = {U='uea0103', A='uaa0103', C='ura0103', S='xsa0103'},
		Interceptors = {U='uea0102', A='uaa0102', C='ura0102', S='xsa0102'},
		T1Transports = {U='uea0107', A='uaa0107', C='ura0107', S='xsa0107'},
		-- T2
		CombatFighters = {U='dea0202', A='xaa0202', C='dra0202', S='xsa0202'},
		Gunships = {U='uea0203', A='uaa0203', C='ura0203', S='xsa0203'},
		TorpedoBombers = {U='uea0204', A='uaa0204', C='ura0204', S='xsa0204'},
		T2Transports = {U='uea0104', A='uaa0104', C='ura0104', S='xsa0104'},
		-- T3
		SpyPlanes = {U='uea0302', A='uaa0302', C='ura0302', S='xsa0302'},
		AirSuperiority = {U='uea0303', A='uaa0303', C='ura0303', S='xsa0303'},
		StratBombers = {U='uea0304', A='uaa0304', C='ura0304', S='xsa0304'},
		
		-- Faction specific types
		GuidedMissiles = {A='daa0206'},								-- Aeon T2 Mercy
		HeavyGunships = {U='uea0305', A='xaa0305', C='xra0305'},	-- UEF, Aeon, Cybran T3 Gunships
		HeavyTorpedoBombers = {A='xaa0306'},						-- Aeon T3 Torpedo Bomber
		LightGunships = {C='xra0105'},								-- Cybran T1 Gunship
		T3Transports = {U='xea0306'},								-- UEF T3 Transport
	-------------
	-- Land Units
	-------------
		-- T1
		LandScouts = {U='uel0101', A='ual0101', C='url0101', S='xsl0101'},
		LightArtillery = {U='uel0103', A='ual0103', C='url0103', S='xsl0103'},
		LightTanks = {U='uel0201', A='ual0201', C='url0107', S='xsl0201'},			-- I'm classifying the Cybran T1 Assault Bot as a tank too
		MobileAntiAir = {U='uel0104', A='ual0104', C='url0104', S='xsl0104'},
		-- T2
		AmphibiousTanks = {U='uel0203', A='xal0203', C='url0203', S='xsl0203'},
		HeavyTanks = {U='uel0202', A='ual0202', C='url0202', S='xsl0303'},			-- Seraphim variant is the T3 Siege Tank
		MobileFlak = {U='uel0205', A='ual0205', C='url0205', S='xsl0205'},
		MobileMissiles = {U='uel0111', A='ual0111', C='url0111', S='xsl0111'},
		-- T3
		SiegeBots = {U='uel0303', A='ual0303', C='url0303', S='xsl0202'},			-- Seraphim variant is the T2 Assault Bot (AKA the 'chicken')
		HeavyBots = {U='xel0305', A='xal0305', C='xrl0305', S='xsl0305'},
		MobileHeavyArtillery = {U='uel0304', A='ual0304', C='url0304', S='xsl0304'},
		HeavyMobileAntiAir = {U='delk002', A='dalk003', C='drlk001', S='dslk004'},	-- Whoever came up with the IDs for the T3 MAAs deserves a slap
		
		-- Faction specific types
		LightBots = {U='uel0106', A='ual0106', C='url0106'},		-- UEF, Aeon, Cybran T1 LABs
		MobileBombs = {C='xrl0302'}, 								-- Cybran T2 Mobile Bomb
		MobileMissilePlatforms = {U='xel0306'},						-- UEF T3 Mobile Missile Launcher
		MobileShields = {U='uel0307', A='ual0307', S='xsl0307'},	-- UEF, Aeon, and Seraphim Mobile Shields
		MobileStealth = {C='url0306'},								-- Cybran T2 Mobile Stealth
		MobileAntiShields = {A='dal0310'}, 							-- Aeon T3 Shield Disruptor
		RangeBots = {U='del0204', C='drl0204'},						-- Cybran, and UEF T2 Bots (Mongoose and Hoplite)
		
	--------------
	-- Naval Units
	--------------
		-- T1
		Frigates = {U='ues0103', A='uas0103', C='urs0103', S='xss0103'},
		Submarines = {U='ues0203', A='uas0203', C='urs0203', S='xss0203'},
		-- T2
		Destroyers = {U='ues0201', A='uas0201', C='urs0201', S='xss0201'},
		Cruisers = {U='ues0202', A='uas0202', C='urs0202', S='xss0202'},
		-- T3
		Battleships = {U='ues0302', A='uas0302', C='urs0302', S='xss0302'},

		-- Faction specific types
		AABoats = {A='uas0102'},									-- Aeon T1 AA Boat
		Carriers = {A='uas0303', C='urs0303', S='xss0303'},			-- Aeon, Cybran, and Seraphim T3 Carriers
		MissileShips = {A='xas0306'},								-- Aeon T3 Missile Ship
		NukeSubmarines = {U='ues0304', A='uas0304', C='urs0304'},	-- UEF, Aeon, Cybran T3 Nuclear Submarines
		T2Submarines = {A='xas0204', C='xrs0204'},					-- Aeon, and Cybran T2 Submarine Hunters
		T3Submarines = {S='xss0304'}, 								-- Seraphim T3 Submarine Hunter
		TorpedoBoats = {U='xes0102'},								-- UEF T2 Torpedo Boat
		UtilityBoats = {U='xes0205', C='xrs0205'},					-- UEF, and Cybran T2 Utility boats (Shield boat, and Stealth Field boat)
		
	------------------
	-- Structure Units
	------------------
}



CampaignStructurePlatoonTemplates = {
	------------------------------
	-- Structure Platoon Templates
	------------------------------
	
	--- UEF
    {
		-- FACTORIES
        {
            'T1LandFactoryInfiniteBuild',
            'LandFactoryInfiniteBuild',
            { 'ueb0101', 1, 1, 'Support', 'None' },
        },
        {
            'T1LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0101',1, 1, 'Support',  'None' },
        },
        {
            'T1AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0102',1, 1, 'Support',  'None' },
        },
        {
            'T1SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0103',1, 1, 'Support',  'None' },
        },
        {
            'T2LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0201',1, 1, 'Support',  'None' },
        },
        {
            'T2AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0202',1, 1, 'Support',  'None' },
        },
        {
            'T2SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'ueb0203',1, 1, 'Support',  'None' },
        },
        -- MASS EXTRACTORS
        {
            'T1MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'ueb1103',1, 1, 'Support',  'None' },
        },
        {
            'T2MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'ueb1202',1, 1, 'Support',  'None' },
        },
        -- RADAR
        {
            'T1RadarUpgrade',
            'UnitUpgradeAI',
            { 'ueb3101',1, 1, 'Support',  'None' },
        },
        {
            'T2RadarUpgrade',
            'UnitUpgradeAI',
            { 'ueb3201',1, 1, 'Support',  'None' },
        },
        -- SONAR
        {
            'T1SonarUpgrade',
            'UnitUpgradeAI',
            { 'ueb3102',1, 1, 'Support',  'None' },
        },
        {
            'T2SonarUpgrade',
            'UnitUpgradeAI',
            { 'ueb3202',1, 1, 'Support',  'None' },
        },
        -- MISC STRUCTURES
        {
            'T3Nuke',
            'NukeAI',
            { 'ueb2305',1, 1, 'Attack',  'None' },
        },
        {
            'T3AntiNuke',
            'AntiNukeAI',
            { 'ueb4302',1, 1, 'Attack',  'None' },
        },
        {
            'T2TacticalLauncher',
            'TacticalAI',
            { 'ueb2108', 1, 1, 'Attack', 'None' },
        },
        {
            'T2ArtilleryStructure',
            'ArtilleryAI',
            { 'ueb2303', 1, 1, 'Artillery', 'None' },
        },
        {
            'T3ArtilleryStructure',
            'ArtilleryAI',
            { 'ueb2302', 1, 1, 'Artillery', 'None' },
        },
        {
            'T4ArtilleryStructure',
            'ArtilleryAI',
            { 'ueb2401', 1, 1, 'Artillery', 'None' },
        },
        {
            'T2Shield',
            'UnitUpgradeAI',
            { 'ueb4202', 1, 1, 'Support', 'None' },
        },
        {
            'T2Shield1',
            'UnitUpgradeAI',
            { 'ueb4202', 1, 1, 'Support', 'None' },
        },
        {
            'T2Shield2',
            'UnitUpgradeAI',
            { 'ueb4202', 1, 1, 'Support', 'None' },
        },
        {
            'T2Shield3',
            'UnitUpgradeAI',
            { 'ueb4202', 1, 1, 'Support', 'None' },
        },
        {
            'T2Shield4',
            'UnitUpgradeAI',
            { 'ueb4202', 1, 1, 'Support', 'None' },
        },
        {
            'T1MassFabricator',
            'PauseAI',
            { 'ueb1104', 1, 1, 'Support', 'None' },
        },
        {
            'T3MassFabricator',
            'PauseAI',
            { 'ueb1303', 1, 1, 'Support', 'None' },
        },

    },
	
	--- Aeon
	{
		-- FACTORIES
        {
            'T1LandFactoryInfiniteBuild',
            'LandFactoryInfiniteBuild',
            { 'uab0101', 1, 1, 'Support', 'None' },
        },
        {
            'T1LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0101',1, 1, 'Support',  'None' },
        },
        {
            'T1AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0102',1, 1, 'Support',  'None' },
        },
        {
            'T1SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0103',1, 1, 'Support',  'None' },
        },
        {
            'T2LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0201',1, 1, 'Support',  'None' },
        },
        {
            'T2AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0202',1, 1, 'Support',  'None' },
        },
        {
            'T2SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'uab0203',1, 1, 'Support',  'None' },
        },
        -- MASS EXTRACTORS
        {
            'T1MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'uab1103',1, 1, 'Support',  'None' },
        },
                {
            'T2MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'uab1202',1, 1, 'Support',  'None' },
        },
        -- RADAR
        {
            'T1RadarUpgrade',
            'UnitUpgradeAI',
            { 'uab3101',1, 1, 'Support',  'None' },
        },
        {
            'T2RadarUpgrade',
            'UnitUpgradeAI',
            { 'uab3201',1, 1, 'Support',  'None' },
        },
        -- SONAR
        {
            'T1SonarUpgrade',
            'UnitUpgradeAI',
            { 'uab3102',1, 1, 'Support',  'None' },
        },
        {
            'T2SonarUpgrade',
            'UnitUpgradeAI',
            { 'uab3202',1, 1, 'Support',  'None' },
        },
        -- MISC STRUCTURES
        {
            'T3Nuke',
            'NukeAI',
            { 'uab2305',1, 1, 'Attack',  'None' },
        },
        {
            'T3AntiNuke',
            'AntiNukeAI',
            { 'uab4302',1, 1, 'Attack',  'None' },
        },
        {
            'T2TacticalLauncher',
            'TacticalAI',
            { 'uab2108', 1, 1, 'Attack', 'None' },
        },
        {
            'T2ArtilleryStructure',
            'ArtilleryAI',
            { 'uab2303', 1, 1, 'Artillery', 'None' },
        },
        {
            'T3ArtilleryStructure',
            'ArtilleryAI',
            { 'uab2302', 1, 1, 'Artillery', 'None' },
        },
        {
            'T4ArtilleryStructure',
            'ArtilleryAI',
            { 'uab2302', 1, 1, 'Artillery', 'None' },
        },
        {
            'T2Shield',
            'DummyAI',
            { 'uab4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield1',
            'DummyAI',
            { 'uab4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield2',
            'DummyAI',
            { 'uab4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield3',
            'DummyAI',
            { 'uab4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield4',
            'DummyAI',
            { 'uab4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T1MassFabricator',
            'PauseAI',
            { 'uab1104', 1, 1, 'Support', 'None' },
        },
        {
            'T3MassFabricator',
            'PauseAI',
            { 'uab1303', 1, 1, 'Support', 'None' },
        },
	},
	
	--- Cybran
	{
		-- FACTORIES
        {
            'T1LandFactoryInfiniteBuild',
            'LandFactoryInfiniteBuild',
            { 'urb0101', 1, 1, 'Support', 'None' },
        },
        {
            'T1LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0101',1, 1, 'Support',  'None' },
        },
        {
            'T1AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0102',1, 1, 'Support',  'None' },
        },
        {
            'T1SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0103',1, 1, 'Support',  'None' },
        },
        {
            'T2LandFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0201',1, 1, 'Support',  'None' },
        },
        {
            'T2AirFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0202',1, 1, 'Support',  'None' },
        },
        {
            'T2SeaFactoryUpgrade',
            'UnitUpgradeAI',
            { 'urb0203',1, 1, 'Support',  'None' },
        },
        -- MASS EXTRACTORS
        {
            'T1MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'urb1103',1, 1, 'Support',  'None' },
        },
        {
            'T2MassExtractorUpgrade',
            'UnitUpgradeAI',
            { 'urb1202',1, 1, 'Support',  'None' },
        },

        -- RADAR
        {
            'T1RadarUpgrade',
            'UnitUpgradeAI',
            { 'urb3101',1, 1, 'Support',  'None' },
        },
        {
            'T2RadarUpgrade',
            'UnitUpgradeAI',
            { 'urb3201',1, 1, 'Support',  'None' },
        },
        -- SONAR
        {
            'T1SonarUpgrade',
            'UnitUpgradeAI',
            { 'urb3102',1, 1, 'Support',  'None' },
        },
        {
            'T2SonarUpgrade',
            'UnitUpgradeAI',
            { 'urb3202',1, 1, 'Support',  'None' },
        },
        -- MISC STRUCTURES
        {
            'T3Nuke',
            'NukeAI',
            { 'urb2305',1, 1, 'Attack',  'None' },
        },
        {
            'T3AntiNuke',
            'AntiNukeAI',
            { 'urb4302',1, 1, 'Attack',  'None' },
        },
        {
            'T2TacticalLauncher',
            'TacticalAI',
            { 'urb2108', 1, 1, 'Attack', 'None' },
        },
        {
            'T2ArtilleryStructure',
            'ArtilleryAI',
            { 'urb2303', 1, 1, 'Artillery', 'None' },
        },
        {
            'T3ArtilleryStructure',
            'ArtilleryAI',
            { 'urb2302', 1, 1, 'Artillery', 'None' },
        },
        {
            'T4ArtilleryStructure',
            'ArtilleryAI',
            { 'urb2302', 1, 1, 'Artillery', 'None' },
        },
        {
            'T2Shield',
            'UnitUpgradeAI',
            { 'urb4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield1',
            'UnitUpgradeAI',
            { 'urb4202', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield2',
            'UnitUpgradeAI',
            { 'urb4204', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield3',
            'UnitUpgradeAI',
            { 'urb4205', 1, 1, 'Attack', 'None' },
        },
        {
            'T2Shield4',
            'UnitUpgradeAI',
            { 'urb4206', 1, 1, 'Attack', 'None' },
        },
        {
            'T1MassFabricator',
            'PauseAI',
            { 'urb1104', 1, 1, 'Support', 'None' },
        },
        {
            'T3MassFabricator',
            'PauseAI',
            { 'urb1303', 1, 1, 'Support', 'None' },
        },
	},
}

function PlatoonTemplateFindIndex( faction, name )
    for i, u in PlatoonTemplates[faction] do
        if name == u[1] then
            return i
        end
    end
    LOG('===== AI DEBUG: Error Matching template name ', name, 'in template for faction ', faction, '=====')
    return 1
end