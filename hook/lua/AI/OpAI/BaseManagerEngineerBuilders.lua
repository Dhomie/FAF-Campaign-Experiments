local AIBuildUnits = import("/lua/ai/aibuildunits.lua")
local AIUtils = import("/lua/ai/aiutilities.lua")
local TemplateNames = import("/lua/templatenames.lua").TemplateNames

local BBTmplFile = '/lua/basetemplates.lua'
local BuildingTmpl = 'BuildingTemplates'
local BaseTmpl = 'BaseTemplates'
local ExBaseTmpl = 'ExpansionBaseTemplates'
local Adj2x2Tmpl = 'Adjacency2x2'
local UCBC = '/lua/editor/unitcountbuildconditions.lua'
local MIBC = '/lua/editor/miscbuildconditions.lua'
local MABC = '/lua/editor/markerbuildconditions.lua'
local OAUBC = '/lua/editor/otherarmyunitcountbuildconditions.lua'
local EBC = '/lua/editor/economybuildconditions.lua'
local PCBC = '/lua/editor/platooncountbuildconditions.lua'
local BMBC = '/lua/editor/basemanagerbuildconditions.lua'
local SAI = '/lua/scenarioplatoonai.lua'
local PlatoonFile = '/lua/platoon.lua'

local CommanderInitialPlatoonList = {
	{
        BuilderName = 'ACU Initial Build',
        --PlatoonAddBehaviors = { 'CDROverchargeBehavior', 'CDRRunAwayBehavior', 'CDRGiveUpBehavior', 'CDRLeash', 'CDRCallForHelp', },
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { UCBC, 'HaveLessThanUnitsWithCategory', {1, categories.FACTORY * categories.LAND}},
            --{ MIBC, 'NotPreBuilt', {}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1AirFactory',
                }
            }
        }
    },
    {
        BuilderName = 'CDR Single T1Resource',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { EBC, 'LessThanEconStorageRatio', { 0.1, 1.0}},
            { MABC, 'MarkerLessThanDistance',  {'Mass', 36, 0, 0, 1}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1Resource',
                },
                --Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'CDR T1 Energy',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
                { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', {1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'LessThanEconStorageRatio', { 1.0, 0.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T1EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'CDR Assist Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 800,
        BuildConditions = {
                { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
                { EBC, 'GreaterThanEconStorageRatio', {0.2, 0.2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Assist = {
                AssistRange = 90,
                BeingBuiltCategories = {'FACTORY -NAVAL', 'ALLUNITS'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'CDR Assist Mass Extractor Upgrade',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 900,
        BuildConditions = {
                { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', {0, (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'MASSEXTRACTION'},
                Time = 30,
            },
        }
    },
    {
        BuilderName = 'CDR T1 Land Factory',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.COMMAND}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.FACTORY * categories.LAND}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.7}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
                --Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'CDR T1 AirFactory',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 750,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.COMMAND}},
                --{ UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.TECH2 * categories.MASSEXTRACTION}},
                --{ UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.TECH2 * categories.MASSEXTRACTION}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.FACTORY * categories.AIR}},
                { EBC, 'GreaterThanEconTrend', { 0.3, 0.7}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
                --Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'CDR Base D',
        PlatoonTemplate = 'CommanderBuilder',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.COMMAND}},
                { MABC, 'MarkerLessThanDistance',  { 'Rally Point', 50, -5, 5, 0}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.5, 0.5}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BaseTemplate = ExBaseTmpl,
                BuildClose = false,
                NearMarkerType = 'Rally Point',
                ThreatMin = -5,
                ThreatMax = 5,
                ThreatRings = 0,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                }
            }
        }
    },
    
}

local CommanderEnhancementList = {
	--------------------------------------------------------------------
    --  CDR Enhancements
    --------------------------------------------------------------------
        ----------
        --  UEF
        ----------
    {
        BuilderName = 'UEF CDR Upgrade AdvEng - Pods',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', {1, categories.FACTORY - categories.TECH1}},
			{ UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', false }}
            { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
            { MIBC, 'FactionIndex', {1}},
        },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = {'AdvancedEngineering', 'LeftPod', 'RightPod', 'ResourceAllocation'},
        },
        PlatoonAddBehaviors = {'BuildOnceAI'},
    },
    {
        BuilderName = 'UEF CDR Upgrade T3 Eng - Shields',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
                { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', {4, categories.FACTORY - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', {0.8, 0.8}},
				{ UCBC, 'CmdrHasUpgrade', {'T3Engineering', false}}
                { MIBC, 'FactionIndex', {1}},
            },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = {'T3Engineering', 'RightPodRemove', 'Shield', 'ShieldGeneratorField'},
        },
        PlatoonAddBehaviors = {'BuildOnceAI'},
    },
        ----------
        --  Aeon
        ----------
    {
        BuilderName = 'Aeon CDR Upgrade AdvEng - Shield - Crysalis',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', {1, categories.FACTORY - categories.TECH1}},
            { EBC, 'GreaterThanEconEfficiency', {0.6, 0.6}},
			{ UCBC, 'CmdrHasUpgrade', {'AdvancedEngineering', false}}
            { MIBC, 'FactionIndex', {2}},
        },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = {'AdvancedEngineering', 'Shield', 'CrysalisBeam'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
    {
        BuilderName = 'Aeon CDR Upgrade T3 Eng - ShieldHeavy',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', {4, categories.FACTORY - categories.TECH1}},
            { EBC, 'GreaterThanEconEfficiency', {0.8, 0.8}},
			{ UCBC, 'CmdrHasUpgrade', {'T3Engineering', false}}
            { MIBC, 'FactionIndex', {2}},
        },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'T3Engineering', 'ShieldHeavy', 'FAF_CrysalisBeamAdvanced', 'HeatSink'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
        ----------
        --  Cybran
        ----------
    {
        BuilderName = 'Cybran CDR Upgrade AdvEng - Laser Gen',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
            { BMBC, 'NumUnitsGreaterOrEqualNearBase', {'LocationType', 1, categories.COMMAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', {1, categories.FACTORY - categories.TECH1}},
            { EBC, 'GreaterThanEconEfficiency', {0.6, 0.6}},
			{ UCBC, 'CmdrHasUpgrade', {'AdvancedEngineering', false}}
            { MIBC, 'FactionIndex', {3}},
        },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'AdvancedEngineering', 'MicrowaveLaserGenerator'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
    {
        BuilderName = 'Cybran CDR Upgrade T3 Eng - ResourceAllocation',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
            { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.FACTORY - categories.TECH1}},
            { EBC, 'GreaterThanEconEfficiency', { 0.8, 0.8}},
			{ UCBC, 'CmdrHasUpgrade', {'T3Engineering', false}}
            { MIBC, 'FactionIndex', {3, 3}},
        },
        Priority = 800,
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'T3Engineering', 'ResourceAllocation'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
}

--- LocationType will be replaced or outright set to nil when we load them, right now they just serve as standardized templates to be used via functions
local PlatoonList = {
	--------------------------------------------------------------------
    --  Engineers
    --------------------------------------------------------------------
        ----------
        --  Tech 1
        ----------
    {
        BuilderName = 'T1 Engineer Disband - Init',
        PlatoonTemplate = 'EngineerOnlyBuild',
        Priority = 950,
        BuildConditions = {
            { BMBC, 'NumUnitsLessNearBase', {'LocationType' 5, categories.ENGINEER * categories.TECH1}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Engineer Disband - Init',
        PlatoonTemplate = 'T2EngineerOnlyBuild',
        Priority = 950,
        BuildConditions = {
            { BMBC, 'NumUnitsLessNearBase', {'LocationType' 7, categories.ENGINEER * categories.TECH2}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Engineer Disband - Init',
        PlatoonTemplate = 'T3EngineerOnlyBuild',
        Priority = 950,
        BuildConditions = {
            { BMBC, 'NumUnitsLessNearBase', {'LocationType' 9, categories.ENGINEER * categories.TECH3}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        ExpansionExclude = {'Sea'},
        RequiresConstruction = true,
    },
    ----------------------------------------
    --  ECONOMY CONSTRUCTION
    ----------------------------------------
    {
        BuilderName = 'Engineer T1 Land Factory - Additional Factories',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
				{ BMBC, 'NumUnitsLessNearBase', { 'LocationType', categories.FACTORY * categories.LAND * categories.STRUCTURE, 8}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
                Location = 'LocationType',
            }
        }
    },
	{
        BuilderName = 'Engineer T1 Air Factory - Additional Factories',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
                { BMBC, 'NumUnitsLessNearBase', { 'LocationType', categories.FACTORY * categories.LAND * categories.STRUCTURE, 8}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 T1Resource Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 1000,
        InstanceCount = 2,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER - categories.TECH1 - categories.COMMAND}},
            --{ MABC, 'MarkerLessThanDistance',  { 'Mass', 10000, 0, 0, 0}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T2 T2Resource Engineer',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH3}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 500, 0, 0, 0}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T3 T3Resource Engineer',
        PlatoonTemplate = 'T3EngineerGenericSingle',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 500, 0, 0, 0}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Hydrocarbon Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 975,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.HYDROCARBON}},
                { MABC, 'MarkerLessThanDistance',  { 'Hydrocarbon', 210}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Power Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 30, categories.TECH1 * categories.ENERGYPRODUCTION}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T1EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 Engineer Reclaim',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'ReclaimAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
		InstanceCount = 3,
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            NotPartOfAttackForce = true,
        },
    },
    {
        BuilderName = 'T1 Engineer Reclaim Enemy Walls',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'ReclaimUnitsAI',
        Priority = 975,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.WALL, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Radius = 1000,
            Categories = {'WALL'},
            ThreatMin = -10,
            ThreatMax = 10000,
            ThreatRings = 1,
            NotPartOfAttackForce = true,
        },
    },
    {
        BuilderName = 'T2 Engineer Capture',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'CaptureAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.ENERGYPRODUCTION * categories.TECH2, 'Enemy'}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.DEFENSE, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Radius = 500,
            Categories = {'ENERGYPRODUCTION, MASSPRODUCTION, ARTILLERY, FACTORY'},
            ThreatMin = 1,
            ThreatMax = 1,
            ThreatRings = 1,
            NotPartOfAttackForce = true,
        },
    },
    {
        BuilderName = 'T2 Power Engineer 2',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.TECH2 * categories.ENERGYPRODUCTION}},
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T2EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Engineer Patrol',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'PatrolBaseVectorsAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio', { 0.5, 1.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            NotPartOfAttackForce = true,
        },
    },
    {
        BuilderName = 'T3 Power Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.TECH3 * categories.ENERGYPRODUCTION}},
                --{ EBC, 'LessThanEconTrend', { 1000, 2000}},
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T3EnergyProduction',
                    --'T3EnergyProduction',
                    --'T3EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Mass Ext Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.TECH3 * categories.MASSEXTRACTION}},
                { EBC, 'LessThanEconTrend', { 40, 100000}},
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                --{ EBC, 'LessThanEconStorageRatio', { 0.8, 1.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3MassExtraction',
                    --'T3MassExtraction',
                }
            }
        }
    },
    {
        BuilderName = 'T3 Mass Fab Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.TECH3 * categories.MASSFABRICATION}},
                { EBC, 'LessThanEconTrend', { 40, 100000}},
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                --{ EBC, 'LessThanEconStorageRatio', { 0.8, 1.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
				AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                    --'T3MassCreation',
                    --'T3MassCreation',
                    --'T3MassCreation',
                },
                Location = 'LocationType',
            }
        }
    },

    ----------------------------------------
    --  BASE CONSTRUCTION
    ----------------------------------------
    {
        BuilderName = 'T1 Radar Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.RADAR * categories.STRUCTURE}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.OMNI * categories.STRUCTURE}},
                --{ EBC, 'GreaterThanEconIncome',  { 1, 10}},
                --{ EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1Radar',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Air Staging Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 25, categories.AIR}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.AIRSTAGINGPLATFORM}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Artillery Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ARTILLERY * categories.STRUCTURE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2Artillery',
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Gate Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.GATE * categories.TECH3 * categories.STRUCTURE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.7, 0.7}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3QuantumGate',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Artillery Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ARTILLERY * categories.STRUCTURE * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome', {7.5, 100}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Nuke Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 825,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconIncome', {7.5, 100}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Land Exp1 Engineer 1',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Rally Point',
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Land Exp2 Engineer 1',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 825,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Rally Point',
                BuildStructures = {
                    'T4LandExperimental2',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Air Exp1 Engineer 1',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Protected Experimental Construction',
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Land Exp1 Engineer 2',
        PlatoonTemplate = 'T3EngineerBuilderBig',
        Priority = 900,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Rally Point',
                BuildStructures = {
                    'T4LandExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Land Exp2 Engineer 2',
        PlatoonTemplate = 'T3EngineerBuilderBig',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Rally Point',
                BuildStructures = {
                    'T4LandExperimental2',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Air Exp1 Engineer 2',
        PlatoonTemplate = 'T3EngineerBuilderBig',
        Priority = 900,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Protected Experimental Construction',
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    ----------------------------------------
    --  BASE DEFENSE CONSTRUCTION
    ----------------------------------------
    {
        BuilderName = 'T1 Base D Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 700,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.DEFENSE * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1GroundDefense',
                    --'T1GroundDefense',
                    --'T1GroundDefense',
                    --'T1GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 Base D AA Engineer - Response',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.DEFENSE * categories.TECH1 * categories.ANTIAIR}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.AIR, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                    --'T1AADefense',
                    --'T1GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 Base D AA Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.DEFENSE * categories.TECH1 * categories.ANTIAIR}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                    --'T1AADefense',
                    --'T1GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Base D Engineer',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 16, categories.DEFENSE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Base D Anti-TML Engineer - Response',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.DEFENSE * categories.TECH2}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 2, categories.STRATEGIC * categories.TECH2, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2MissileDefense',
                    --'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Base D Engineer - Response',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 24, categories.DEFENSE * categories.TECH2}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 50, categories.MOBILE * categories.LAND, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    --'T2MissileDefense',
                    --'T2AADefense',
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Base D AA Engineer - Response',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.MOBILE * categories.AIR, 'Enemy'}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    --'T2AADefense',
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Base D AA Engineer',
        PlatoonTemplate = 'T2EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    --'T2AADefense',
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Shield D Engineer Energy Production',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SHIELD * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'ENERGYPRODUCTION',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T2ShieldDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Counter Intel Near Factory',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.COUNTERINTELLIGENCE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.4}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T2RadarJammer',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T2 Shield D Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SHIELD * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'DEFENSE DIRECTFIRE',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T2ShieldDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Anti-Nuke Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ANTIMISSILE * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome', { 2.5, 100}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                AdjacencyCategory = 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3',
                AdjacencyDistance = 100,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Anti-Nuke Engineer 2',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ANTIMISSILE * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.25}},
                { EBC, 'GreaterThanEconIncome', { 2.5, 100}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                AdjacencyCategory = 'ENERGYPRODUCTION TECH2, ENERGYPRODUCTION TECH3',
                AdjacencyDistance = 100,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Anti-Nuke Engineer 3',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ANTIMISSILE * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.25}},
                { EBC, 'GreaterThanEconIncome', { 2.5, 100}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                AdjacencyCategory = 'SHIELD',
                AdjacencyDistance = 100,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Base D Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.DEFENSE * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.01, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Shield D Engineer Energy Adj',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SHIELD * categories.TECH3}},
                { MIBC, 'FactionIndex', {1, 2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'ENERGYPRODUCTION',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T3ShieldDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Shield D Engineer Mass Fab Adj',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SHIELD * categories.TECH3}},
                { MIBC, 'FactionIndex', {1, 2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'MASSFABRICATION',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T3ShieldDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Shield D Engineer Factory Adj',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.SHIELD * categories.TECH3}},
                { MIBC, 'FactionIndex', {1, 2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'TECH3 FACTORY',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'T3ShieldDefense',
                },
                Location = 'LocationType',
            }
        }
    },


    ----------------------------------------
    -- EMERGENCY BUILDING TECH 1
    ----------------------------------------

    {
        BuilderName = 'T1 Emergency Mass Extraction Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 700,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.0}},
                { EBC, 'LessThanEconTrend', { 0, 100000}},
                { MABC, 'MarkerLessThanDistance',  { 'Mass', 1000}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Emergency Mass Creation Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * (categories.TECH2 + categories.TECH3)}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MASSFABRICATION * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1MassCreation',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 Emergency Power Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 850,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.1}},
                { EBC, 'LessThanEconTrend', { 100000, 0}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T1EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T1 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.TECH1 * categories.MASSSTORAGE}},	--20 mass storages should be enough in total
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                --{ MABC, 'MarkerLessThanDistance',  { 'Mass', 180, -3, 0, 0}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'MASSPRODUCTION',
                AdjacencyDistance = 100,
                --[[ABuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,]]
                BuildStructures = {
                    'MassStorage',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Mass Adjacency Defense Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 750,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.1}},
                { MABC, 'MarkerLessThanDistance',  { 'Mass', 210, -3, 0, 0}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'MASSEXTRACTION',
                AdjacencyDistance = 200,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'T1GroundDefense',
                    --'T1GroundDefense',
                    'T1AADefense',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Energy Storage Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 8, categories.TECH1 * categories.ENERGYSTORAGE}},	--8 energy storages should be enough in total
                --{ EBC, 'GreaterThanEconStorageRatio', { 0.4, 0.6}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'ENERGYPRODUCTION',
                AdjacencyDistance = 100,
                BuildClose = false,
                BuildStructures = {
                    'EnergyStorage',
                },
                Location = 'LocationType',
            }
        }
    },

    ----------------------------------------
    -- EMERGENCY BUILDING TECH 2
    ----------------------------------------
    {
        BuilderName = 'T2 Power Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH2}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.3}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T2EnergyProduction',
                    --'T2EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },

    ----------------------------------------
    -- EMERGENCY BUILDING TECH 3
    ----------------------------------------
    {
        BuilderName = 'T3 Emergency Power Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.5}},
                { EBC, 'LessThanEconTrend', { 100000, 0}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T3EnergyProduction',
                    --'T3EnergyProduction',
                    --'T3EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Emergency Mass Fab Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
                { EBC, 'LessThanEconTrend', { 0, 100000}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                    --'T3MassCreation',
                    --'T3MassCreation',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T3 Extra Power Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                { EBC, 'LessThanEconTrend', { 1000, 30}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                AdjacencyCategory = 'FACTORY -NAVAL',
                AdjacencyDistance = 100,
                BuildClose = true,
                BuildStructures = {
                    'T3EnergyProduction',
                    --'T3EnergyProduction',
                    --'T3EnergyProduction',
                },
                Location = 'LocationType',
            }
        }
    },

    ----------------------------------------
    -- FORWARD BASE BUILDING
    ----------------------------------------
    {
        BuilderName = 'T1 Defensive Point Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                -- Most paramaters freaking ever Build Condition -- All the threat ones are optional
                ----                                                 MarkerType   MarkerRadius  LocationType
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20,         'LocationType',
                -- LocationRadius  UnitCount    UnitCategory
                       200,           5,     'DEFENSE TECH1'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'LocationType'
                ThreatMin = -100,
                ThreatMax = 3,
                ThreatRings = 1,
                MarkerUnitCount = 5,
                MarkerUnitCategory = 'DEFENSE TECH1',
                BuildStructures = {
                    'T1AADefense',
                    'T1GroundDefense',
                },
            },
        },
    },
    {
        BuilderName = 'T1 Defensive Point Engineer 2',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.AIR, 'Enemy'}},
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20, 'LocationType', 200, 5, 'DEFENSE TECH1'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'LocationType'
                ThreatMin = -100,
                ThreatMax = 3,
                ThreatRings = 1,
                MarkerUnitCount = 5,
                MarkerUnitCategory = 'DEFENSE TECH1',
                BuildStructures = {
                    'T1AADefense',
                    'T1GroundDefense',
                },
            },
        },
    },
    {
        BuilderName = 'T2 Defensive Point Engineer 3',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.DEFENSE * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20, 'LocationType', 200, 10, 'DEFENSE TECH2'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'LocationType'
                ThreatMin = -100,
                ThreatMax = 3,
                ThreatRings = 1,
                MarkerUnitCount = 10,
                MarkerUnitCategory = 'DEFENSE TECH2',
                BuildStructures = {
                    'T2GroundDefense',
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2Artillery',
                    'T2StrategicMissile',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Expansion Area Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                ExpansionRadius = 60,
                ExpansionTypes = { 'Land', 'Air' },
                NearMarkerType = 'Expansion Area',
                ThreatMin = -100,
                ThreatMax = 5,
                ThreatRings = 0,
                BuildStructures = {
                    'T1LandFactory',
					'T1AirFactory',
                    'T1GroundDefense',
					'T1GroundDefense',
                    'T1AADefense',
					'T1AADefense',
                }
            }
        }
    },
	
    {
        BuilderName = 'T2 Expansion Area Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconTrend',  { 0.1, 0.5}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
				ExpansionBase = true,
                ExpansionRadius = 60,
                NearMarkerType = 'Expansion Area',
                ThreatMin = -100,
                ThreatMax = 10,
                ThreatRings = 1,
                BuildStructures = {
					'T1LandFactory',
					'T1AirFactory',
                    'T2Artillery',
					'T2Artillery',
                    'T2GroundDefense',
					'T2GroundDefense',
					'T2GroundDefense',
                    'T2AADefense',
					'T2AADefense',
                    --'T2StrategicMissile',
                    'T2ShieldDefense',
                }
            }
        }
    },
	{
        BuilderName = 'T3 Expansion Area Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconTrend',  { 0.1, 0.5}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
				ExpansionBase = true,
                ExpansionRadius = 60,
                NearMarkerType = 'Expansion Area',
                ThreatMin = -100,
                ThreatMax = 15,
                ThreatRings = 1,
                BuildStructures = {
					'T1LandFactory',
					'T1AirFactory',
                    'T2Artillery',
					'T2Artillery',
                    'T2GroundDefense',
					'T2GroundDefense',
					'T2GroundDefense',
                    'T3AADefense',
					'T3AADefense',
                    --'T2StrategicMissile',
                    'T2ShieldDefense',
                }
            }
        }
    },
    --------------------------------------------------------------------
    --  ENGINEER ASSIST
    --------------------------------------------------------------------
    {
        BuilderName = 'T1 Engineer Assist',
        PlatoonTemplate = 'EngineerAssist',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'FACTORY -NAVAL', 'ENGINEER'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T1 Engineer Assist Mass Upgrade',
        PlatoonTemplate = 'EngineerAssist',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.TECH2 * categories.MASSEXTRACTION}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'MASSEXTRACTION'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T2 Engineer Assist',
        PlatoonTemplate = 'T2EngineerAssist',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'FACTORY -NAVAL', 'ENGINEER'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T2 Engineer Assist Experimental',
        PlatoonTemplate = 'T3EngineerAssist',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'EXPERIMENTAL'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3 Engineer Assist Factory/Engineer',
        PlatoonTemplate = 'T3EngineerAssist',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'FACTORY -NAVAL', 'ENGINEER'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3 Engineer Assist Experimental',
        PlatoonTemplate = 'T3EngineerAssist',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'EXPERIMENTAL'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3 Engineer Assist Build Nuke',
        PlatoonTemplate = 'T3EngineerAssist',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.STRUCTURE * categories.NUKE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'NUKE'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3 Engineer Assist Nuke Missile',
        PlatoonTemplate = 'T3EngineerAssist',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.NUKE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'NUKE'},
                Time = 60,
            },
        }
    },
    
    ----------------------------------------
    -- NAVAL BASE BUILDING
    ----------------------------------------
    {
        BuilderName = 'T1 Naval Builder',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.FACTORY * categories.NAVAL}},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 200}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                ExpansionRadius = 50,
                ExpansionTypes = { 'Sea' },
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T1SeaFactory',
                    'T1AADefense',
                    'T1NavalDefense',
                    'T1Sonar',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Naval Builder 2',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION * categories.TECH3}},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 200}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},


                -- Most paramaters freaking ever Build Condition -- All the threat ones are optional
                ----                                                 MarkerType   MarkerRadius  LocationType
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Naval Area', 20,         'LocationType',
                -- LocationRadius  UnitCount    UnitCategory
                       150,           4,     'FACTORY NAVAL'} },



                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'LocationType',
                NearMarkerType = 'Naval Area',
                ExpansionBase = true,
                ExpansionRadius = 40,
                ExpansionTypes = { 'Sea' },
                MarkerRadius = 20,
                LocationType = 'LocationType'
                MarkerUnitCount = 4,
                MarkerUnitCategory = 'FACTORY NAVAL',
                BuildStructures = {
                    'T1SeaFactory',
                    'T1AADefense',
                    'T1NavalDefense',
                },
            },
        },
    },
    {
        BuilderName = 'T1 Naval Factory Builder',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { MIBC, 'GreaterThanMapWaterRatio',  { 0.3 }},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 500}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconIncome', { 1.5, 10}},
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Naval Area', 20, 'LocationType', 500, 4, 'FACTORY NAVAL'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'LocationType',
                NearMarkerType = 'Naval Area',
                MarkerRadius = 20,
                LocationRadius = 500,
                LocationType = 'LocationType'
                MarkerUnitCount = 4,
                MarkerUnitCategory = 'FACTORY NAVAL',
                BuildStructures = {
                    'T1SeaFactory',
                },
            },
        },
    },
    {
        BuilderName = 'CDR T1 Sea Factory',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.COMMAND}},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 20}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.FACTORY * categories.NAVAL}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.TECH2 * categories.MASSEXTRACTION}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.7}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T1SeaFactory',
                }
            }
        }
    },
    {
        BuilderName = 'T1 Naval D Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 700,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.DEFENSE * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1NavalDefense',
                },
            }
        }
    },
    {
        BuilderName = 'T1 Base D Naval AA Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 750,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.DEFENSE * categories.TECH1 * categories.ANTIAIR}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.AIR, 'Enemy'}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                    'T1AADefense',
                },
            }
        }
    },
    {
        BuilderName = 'T2 Naval D Engineer',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 750,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.DEFENSE * categories.TECH2 * categories.ANTINAVY}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.NAVAL, 'Enemy'}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2NavalDefense',
                    'T2NavalDefense',
                },
            }
        }
    },
    {
        BuilderName = 'T1 Sonar Upgrade',
        PlatoonTemplate = 'T1SonarUpgrade',
        Priority = 200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SONAR * categories.TECH1}},
                { EBC, 'GreaterThanEconIncome',  { 5, 15}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
    },
    {
        BuilderName = 'T2 Sonar Upgrade',
        PlatoonTemplate = 'T2SonarUpgrade',
        Priority = 300,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.SONAR * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.SONAR * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome',  { 10, 600}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
    },
     {
        BuilderName = 'T1 Sea Factory Upgrade',
        PlatoonTemplate = 'T1SeaFactoryUpgrade',
        Priority = 200,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1 * categories.NAVAL}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MOBILE * categories.NAVAL}},
                { EBC, 'GreaterThanEconIncome',  { 8, 40}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
            },
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
    },
    {
        BuilderName = 'T2 Sea Factory Upgrade',
        PlatoonTemplate = 'T2SeaFactoryUpgrade',
        Priority = 300,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH2 * categories.NAVAL}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, categories.MOBILE * categories.NAVAL}},
                { EBC, 'GreaterThanEconIncome',  { 16, 80}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
            },
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
    },
    {
        BuilderName = 'T4 Sea Exp1 Engineer',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 400}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    {
        BuilderName = 'T4 Sea Exp1 Engineer - Lots of Water',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { MABC, 'MarkerLessThanDistance',  { 'Naval Area', 400}},
                { MIBC, 'GreaterThanMapWaterRatio',  { 0.3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'LocationType',
            }
        }
    },
    --------------------------------------------------------------------
    --  SEA ATTACK
    --------------------------------------------------------------------
        ----------
        --  Tech 1
        ----------
    {
        BuilderName = 'T1 Naval Sub',
        PlatoonTemplate = 'T1SeaSub1',
        Priority = 1000,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T1 Naval Frigate',
        PlatoonTemplate = 'T1SeaFrigate1',
        Priority = 1000,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T1 Naval Anti-Air',
        PlatoonTemplate = 'T1SeaFrigate2',
        Priority = 1050,
        InstanceCount = 1,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.MOBILE * categories.AIR, 'Enemy'}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
        ----------
        --  Tech 2
        ----------
    {
        BuilderName = 'T2 Naval Destroyer UEF Aeon',
        PlatoonTemplate = 'T2SeaDestroyer1',
        Priority = 1100,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL - categories.TECH1}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { MIBC, 'FactionIndex', {1, 2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T2 Naval Destroyer Cybran',
        PlatoonTemplate = 'T2SeaDestroyer1',
        PlatoonAIPlan = 'AttackForceAI',
        Priority = 1100,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL - categories.TECH1}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { MIBC, 'FactionIndex', {3, 3}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T2 Naval Cruiser',
        PlatoonTemplate = 'T2SeaCruiser1',
        PlatoonAddBehaviors = { 'AirLandToggle' },
        Priority = 1100,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL - categories.TECH1}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
        ----------
        --  Tech 3
        ----------
    {
        BuilderName = 'T3 Naval Battleship',
        PlatoonTemplate = 'T3SeaBattleship1',
        Priority = 1200,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL * categories.TECH3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T3 Naval Nuke Sub',
        PlatoonTemplate = 'T3SeaNukeSub1',
        Priority = 1200,
        InstanceCount = 1,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL * categories.TECH3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T3 Naval Carrier',
        PlatoonTemplate = 'T3SeaNukeSub1',
        Priority = 1200,
        InstanceCount = 1,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.NAVAL * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 20, categories.MOBILE * categories.AIR}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T4 Exp Sea',
        PlatoonTemplate = 'T4ExperimentalSea',
        PlatoonAddPlans = {'NameUnits'},
        PlatoonAddBehaviors = { 'TempestBehavior' },
        PlatoonAIPlan = 'StrikeForceAI',
        Priority = 1300,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.NAVAL * categories.EXPERIMENTAL}},
            },
        PlatoonType = 'Sea',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL', 'EXPERIMENTAL', 'MASSPRODUCTION', 'STRUCTURE' }, -- list in order
        },
    },


    --Drew, have at it below here.
    {
        BuilderName = 'T2 Artillery Structure',
        PlatoonTemplate = 'T2ArtilleryStructure',
        Priority = 1,
        InstanceCount = 10,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
    },
    {
        BuilderName = 'T3 Artillery Structure',
        PlatoonTemplate = 'T3ArtilleryStructure',
        Priority = 1,
        InstanceCount = 5,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
    },
    {
        BuilderName = 'T4 Artillery Structure',
        PlatoonTemplate = 'T4ArtilleryStructure',
        Priority = 1,
        InstanceCount = 5,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
    },
    {
        BuilderName = 'T1 Wall Builder',
        PlatoonTemplate = 'EngineerGenericSingle',
        PlatoonAIPlan = 'EngineerBuildAI',
        Priority = 800,
        InstanceCount = 2,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        BuildConditions = {
            { UCBC, 'HaveAreaWithUnitsFewWalls', { 'LocationType', 100, 5, 'STRUCTURE - WALL', false, false, false } },
        },
        PlatoonData = {
            Construction = {
                BuildStructures = { 'Wall' },
                LocationType = 'LocationType'
                Wall = true,
                MarkerRadius = 100,
                MarkerUnitCount = 5,
                MarkerUnitCategory = 'STRUCTURE - WALL',
            },
        },
    },
}

--- Builders used for expansions specifically
local ExpansionPlatoonList = {
}

--- Builders used by any base that grabs them first (no LocationType defined)
--- Used for attack platoons
local SharedPlatoonList = {
	----------------------
    --  STRUCTURE UPGRADES
    ----------------------
    {
        BuilderName = 'T1 Mass Extractor Upgrade',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        Priority = 200,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', {3, categories.MASSEXTRACTION * categories.TECH1}},
            { EBC, 'GreaterThanEconIncome',  {2, 40}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
	{
        BuilderName = 'T1 Mass Extractor Upgrade - Big Econ',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 3,
        Priority = 200,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {6, 120}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Land Factory Upgrade',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 200,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {10, 250}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.2, 0.2}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Land Factory Upgrade - Big Econ',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 200,
        InstanceCount = 2,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1 * categories.LAND}},
            { EBC, 'GreaterThanEconIncome',  {18, 400}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.35, 0.35}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Air Factory Upgrade',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 200,
        InstanceCount = 1,
        BuildConditions = {
				--{ UCBC, 'HaveGreaterThanUnitsWithCategory', {3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconIncome',  {10, 250}},
                { EBC, 'GreaterThanEconStorageRatio',  {0.2, 0.2}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Air Factory Upgrade - Big Econ',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 200,
        InstanceCount = 2,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1 * categories.AIR}},
            { EBC, 'GreaterThanEconIncome',  {18, 400}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.35, 0.35}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Mass Extractor Upgrade',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {9, 180}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
	{
        BuilderName = 'T2 Mass Extractor Upgrade - Big Econ',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 3,
        Priority = 200,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {27, 450}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Land Factory Upgrade',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {30, 750}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.3, 0.3}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Air Factory Upgrade',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {30, 750}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.3, 0.3}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Radar Upgrade',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 200,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.RADAR * categories.TECH1}},
            { EBC, 'GreaterThanEconIncome',  {5, 250}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.2, 0.2}},
            { EBC, 'GreaterThanEconEfficiency', {0.75, 0.75}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Radar Upgrade',
        PlatoonTemplate = 'T2RadarUpgrade',
        Priority = 300,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {15, 1500}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.2, 0.2}},
            { EBC, 'GreaterThanEconEfficiency', {0.75, 0.75}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 TML Silo',
        PlatoonTemplate = 'T2TacticalLauncher',
        Priority = 5,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {15, 1500}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.2, 0.2}},
            { EBC, 'GreaterThanEconEfficiency', {0.75, 0.75}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield Cybran 1',
        PlatoonTemplate = 'T2Shield1',
        Priority = 5,
        InstanceCount = 3,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {10, 200}},
            { MIBC, 'FactionIndex', {3}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield Cybran 2',
        PlatoonTemplate = 'T2Shield2',
        Priority = 5,
        InstanceCount = 3,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {15, 300}},
            { MIBC, 'FactionIndex', {3}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield Cybran 3',
        PlatoonTemplate = 'T2Shield3',
        Priority = 5,
        InstanceCount = 3,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {20, 400}},
            { MIBC, 'FactionIndex', {3}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield Cybran 4',
        PlatoonTemplate = 'T2Shield4',
        Priority = 5,
        InstanceCount = 3,
        BuildConditions = {
                { EBC, 'GreaterThanEconIncome',  {25, 500}},
                { MIBC, 'FactionIndex', {3}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield UEF and Aeon',
        PlatoonTemplate = 'T2Shield',
        Priority = 5,
        InstanceCount = 1,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {10, 150}},
            { MIBC, 'FactionIndex', {1},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Nuke Silo',
        PlatoonTemplate = 'T3Nuke',
        Priority = 5,
        BuildConditions = {
            { EBC, 'GreaterThanEconIncome',  {30, 2000}},
            { EBC, 'GreaterThanEconStorageRatio',  {0.25, 0.25}},
			{ EBC, 'GreaterThanEconEfficiency', {0.8, 0.8}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Mass Fabricator Pause',
        PlatoonTemplate = 'T1MassFabricator',
        Priority = 300,
        InstanceCount = 5,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSFABRICATION * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio',  {1.0, 0.05}},
            },
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'}        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Mass Fabricator Pause',
        PlatoonTemplate = 'T3MassFabricator',
        Priority = 300,
        InstanceCount = 5,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSFABRICATION * categories.TECH3}},
            { EBC, 'LessThanEconStorageRatio',  {1.0, 0.05}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
	
	--------------------------------------------------------------------
    --  LAND ATTACK
    --------------------------------------------------------------------
        ----------
        --  Tech 1
        ----------
    {
        BuilderName = 'T1 Land Scout',
        PlatoonTemplate = 'T1LandScout1',
        Priority = 750,
        BuildTimeOut = 600,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
                { UCBC, 'HaveEqualToUnitsWithCategory', { 0, categories.LAND * categories.SCOUT * categories.TECH1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Light Tanks - Mass Hunter',
        PlatoonTemplate = 'T1LandDFTank1',
        PlatoonAIPlan = 'MassExtractorHunterAI',
        Priority = 700,
        BuildTimeOut = 600,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Light Assault Bot',
        PlatoonTemplate = 'T1LandDFBot1',
        Priority = 500,
        BuildTimeOut = 600,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T1 Light Tank',
        PlatoonTemplate = 'T1LandDFTank1',
        Priority = 500,
        BuildTimeOut = 600,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T1 Mobile AA - Response',
        PlatoonTemplate = 'T1LandAA1',
        Priority = 550,
        BuildTimeOut = 600,
        PlatoonAddBehaviors = { 'AirLandToggle' },
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.AIR, 'Enemy'}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T1 Mobile AA 2',
        PlatoonTemplate = 'T1LandAA1',
        PlatoonAddBehaviors = { 'AirLandToggle' },
        Priority = 525,
        BuildTimeOut = 600,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T1 Mortar',
        PlatoonTemplate = 'T1LandArtillery1',
        Priority = 500,
        BuildTimeOut = 600,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.DEFENSE, 'Enemy'}},
--                { EBC, 'GreaterThanEconTrend', { -0.2, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
        ----------
        --  Tech 2
        ----------
    {
        BuilderName = 'T2 Tank',
        PlatoonTemplate = 'T2LandDFTank1',
        Priority = 600,
        BuildTimeOut = 900,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND - categories.TECH1}},
--                { EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T2 MML',
        PlatoonTemplate = 'T2LandArtillery1',
        Priority = 600,
        BuildTimeOut = 900,
        InstanceCount = 4,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND - categories.TECH1}},
--                { EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T2 Mobile Flak  Response',
        PlatoonTemplate = 'T2LandAA1',
        Priority = 650,
        BuildTimeOut = 900,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND - categories.TECH1}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.MOBILE * categories.AIR, 'Enemy'}},
--                { EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T2 Mobile Flak 2',
        PlatoonTemplate = 'T2LandAA1',
        Priority = 600,
        BuildTimeOut = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND - categories.TECH1}},
--                { EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T2 Amphibious Tank',
        PlatoonTemplate = 'T2LandAmphibious1',
        Priority = 600,
        BuildTimeOut = 900,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND - categories.TECH1}},
--                { EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
        ----------
        --  Tech 3
        ----------
    {
        BuilderName = 'T3 Siege Assault Bot',
        PlatoonTemplate = 'T3LandBot1',
        Priority = 700,
        BuildTimeOut = 1200,
        InstanceCount = 6,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND * categories.TECH3}},
--                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T3 Mobile Heavy Artillery',
        PlatoonTemplate = 'T3LandArtillery1',
        Priority = 700,
        BuildTimeOut = 1200,
        InstanceCount = 4,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.LAND * categories.TECH3}},
--                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'LocationType'
        },
    },
    {
        BuilderName = 'T3 Sub Commander',
        PlatoonTemplate = 'T3LandSubCommander1',
        PlatoonAIPlan = 'StrikeForceAI',
        Priority = 700,
        BuildTimeOut = 1200,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.GATE * categories.TECH3}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'LocationType'
        PlatoonType = 'Gate',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            PrioritizedCategories = { 'MASSPRODUCTION', 'FACTORY -NAVAL', 'COMMAND', 'ENERGYPRODUCTION', 'EXPERIMENTAL', 'STRUCTURE' }, -- list in order
        },
    },
    {
        BuilderName = 'T4 Exp Land 1',
        PlatoonTemplate = 'T4ExperimentalLand1',
        PlatoonAddPlans = {'NameUnits'},
        PlatoonAddBehaviors = { 'FatBoyBehavior', },
        Priority = 800,
        InstanceCount = 3,
        BuildTimeOut = 1200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            UseMoveOrder = true,
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL','EXPERIMENTAL', 'MASSPRODUCTION', 'STRUCTURE -NAVAL' }, -- list in order
        },
    },
    {
        BuilderName = 'T4 Exp Land 2',
        PlatoonTemplate = 'T4ExperimentalLand2',
        PlatoonAddPlans = {'NameUnits'},
        PlatoonAddBehaviors = { 'FatBoyBehavior', },
        Priority = 800,
        InstanceCount = 3,
        BuildTimeOut = 1200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            UseMoveOrder = true,
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL','EXPERIMENTAL', 'MASSPRODUCTION', 'STRUCTURE -NAVAL' }, -- list in order
        },
    },


    --------------------------------------------------------------------
    --  AIR ATTACK
    --------------------------------------------------------------------
        ----------
        --  Tech 1
        ----------

    {
        BuilderName = 'T1 Air Scout',
        PlatoonTemplate = 'T1AirScout1',
        InstanceCount = 2,
        Priority = 650,
        LocationType = 'LocationType'
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
		-- Transports are of giga importance, so they should be prioritized at all times
        BuilderName = 'T1 Air Transport',
        PlatoonTemplate = 'T1AirTransport1',
        Priority = 850,
        BuildTimeOut = 2400,
        BuildConditions = {
			{ UCBC, 'HaveLessThanUnitsWithCategory', {6, categories.TRANSPORTATION * categories.TECH1} },
        },
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
        ----------
        --  Tech 2
        ----------
    {
        BuilderName = 'T2 Air Transport',
        PlatoonTemplate = 'T2AirTransport1',
        Priority = 850,
        InstanceCount = 1,
        BuildTimeOut = 2400,
        BuildConditions = {
            { EBC, 'GreaterThanEconEfficiency', { 0.25, 0.25}},
			{ UCBC, 'HaveLessThanUnitsWithCategory', {8, categories.TRANSPORTATION * categories.TECH2} },
        },
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
        ----------
        --  Tech 3
        ----------
    {
        BuilderName = 'T3 Air Scout',
        PlatoonTemplate = 'T3AirScout1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 750,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
            { EBC, 'GreaterThanEconTrend', { -1, -2}},
        },
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    
    ----------------------------------------
    -- AIR SCOUT WITHOUT CONSTRUCTION
    ----------------------------------------
    {
        BuilderName = 'T1 Air Scout - No Build',
        PlatoonTemplate = 'T1AirScout1',
        Priority = 100,
        InstanceCount = 1,
        PlatoonType = 'Air',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air Scout - No Build',
        PlatoonTemplate = 'T3AirScout1',
        Priority = 100,
        InstanceCount = 1,
        PlatoonType = 'Air',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
}

Builders = {
    ------------------------------------------------
    ------ ECONOMY BUILDERS ------
    ------------------------------------------------
    {
        BuilderName = 'T1ResourceEngineer',
        TemplateName = 'T1EngineerBuilder',
        -- AI Function
        Priority = 1000,
        InstanceCount = 2,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
            { BMBC, 'NeedStructure', { 'T1Resource', 'BASENAME'}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T2ResourceEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
            { BMBC, 'NeedStructure', { 'T2Resource', 'BASENAME'}},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T3ResourceEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
            { BMBC, 'NeedStructure', { 'T3Resource', 'BASENAME' }},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T1HydrocarbonEngineer',
        TemplateName = 'T1EngineerBuilder',
        Priority = 975,
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
            { BMBC, 'NeedStructure', { 'T1HydroCarbon', 'BASENAME' }},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1HydroCarbon',
                }
            }
        }
    },
    {
        BuilderName = 'T1PowerEngineer',
        Priority = 950,
        TemplateName = 'T1EngineerBuilder',
        BuildConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.TECH1 * categories.ENERGYPRODUCTION}},
            { BMBC, 'NeedStructure', { 'T1EnergyProduction', 'BASENAME' }},
        },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
--    {
--        BuilderName = 'T1 Engineer Reclaim',
--        PlatoonAIPlan = 'ReclaimAI',
--        Priority = 975,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--                { MIBC, 'ReclaimablesInArea', { 'LocationType', }},
--            },
--        PlatoonType = 'Land',
--        RequiresConstruction = false,
--        PlatoonData = {
--            NotPartOfAttackForce = true,
--        },
--    },
--    {
--        BuilderName = 'T1 Engineer Reclaim Enemy Walls',
--        PlatoonAIPlan = 'ReclaimUnitsAI',
--        Priority = 975,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.WALL, 'Enemy'}},
--            },
--        PlatoonType = 'Land',
--        RequiresConstruction = false,
--        PlatoonData = {
--            Radius = 1000,
--            Categories = {'WALL'},
--            ThreatMin = -10,
--            ThreatMax = 10000,
--            ThreatRings = 1,
--            NotPartOfAttackForce = true,
--        },
--    },
--    {
--        BuilderName = 'T2 Engineer Capture',
--        PlatoonAIPlan = 'CaptureAI',
--        Priority = 900,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.ENERGYPRODUCTION * categories.TECH2, 'Enemy'}},
--                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.DEFENSE, 'Enemy'}},
--            },
--        PlatoonType = 'Land',
--        RequiresConstruction = false,
--        PlatoonData = {
--            Radius = 300,
--            Categories = {'ENERGYPRODUCTION, MASSPRODUCTION, ARTILLERY, FACTORY'},
--            ThreatMin = 1,
--            ThreatMax = 1,
--            ThreatRings = 1,
--            NotPartOfAttackForce = true,
--        },
--    },
    {
        BuilderName = 'T2PowerEngineer2',
        TemplateName = 'T2EngineerBuilder',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.TECH2 * categories.ENERGYPRODUCTION}},
                { BMBC, 'NeedStructure', { 'T2EnergyProduction', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2EnergyProduction',
                    'T2EnergyProduction',
                    'T2EnergyProduction',
                },
            }
        }
    },
--    {
--        BuilderName = 'T2EngineerPatrol',
--        TemplateName = 'T2EngineerGenericSingle',
--        PlatoonAIPlan = 'ReclaimAI',
--        Priority = 975,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--            },
--        PlatoonType = 'Land',
--        RequiresConstruction = false,
--        PlatoonData = {
--            NotPartOfAttackForce = true,
--        },
--    },
    {
        BuilderName = 'T3PowerEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 950,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 25, categories.TECH3 * categories.ENERGYPRODUCTION}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.2}},
                { BMBC, 'NeedStructure', { 'T3EnergyProduction', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3EnergyProduction',
                    'T3EnergyProduction',
                    'T3EnergyProduction',
                },
            }
        }
    },
    {
        BuilderName = 'T3MassFabEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 950,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.TECH3 * categories.MASSFABRICATION}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.2}},
                { BMBC, 'NeedStructure', { 'T3MassCreation', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                    'T3MassCreation',
                },
            }
        }
    },

    --------------------------------------------------------------------------------
    ----  BASE CONSTRUCTION
    --------------------------------------------------------------------------------
    {
        BuilderName = 'T1RadarEngineer',
        TemplateName = 'EngineerBuilder',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.RADAR}},
                { EBC, 'GreaterThanEconIncome',  { 0.5, 15}},
                { BMBC, 'NeedStructure', { 'T1Radar', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Radar',
                },
            }
        }
    },
    {
        BuilderName = 'T2AirStagingEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 25, categories.AIR}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.AIRSTAGINGPLATFORM}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { BMBC, 'NeedStructure', { 'T2AirStagingPlatform', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
            }
        }
    },
    {
        BuilderName = 'T2ArtilleryEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.ARTILLERY * categories.STRUCTURE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T2Artillery', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2Artillery',
                    'T2Artillery',
                },
            }
        }
    },
    {
        BuilderName = 'T2MissileEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.ARTILLERY * categories.STRUCTURE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T2StrategicMissile', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2StrategicMissile',
                    'T2StrategicMissile',
                },
            }
        }
    },
    {
        BuilderName = 'T3GateEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.FACTORY * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.GATE * categories.TECH3 * categories.STRUCTURE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.7, 0.7}},
                { BMBC, 'NeedStructure', { 'T3QuantumGate', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3QuantumGate',
                },
            }
        }
    },
    {
        BuilderName = 'T3ArtilleryEngineer',
        TemplateName = 'T3EngineerBuilderBig',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 8, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, categories.TECH3 * categories.ARTILLERY}},
                { EBC, 'GreaterThanEconIncome', {15, 100}},
                { BMBC, 'NeedStructure', { 'T3Artillery', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3Artillery', 
                },
            }
        }
    },
    {
        BuilderName = 'T3NukeEngineer',
        TemplateName = 'T3EngineerBuilderBig',
        Priority = 875,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 8, categories.ENGINEER * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome', {15, 100}},
                { BMBC, 'NeedStructure', { 'T3StrategicMissile', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3StrategicMissile', 
                },
            }
        }
    },
    --------------------------------------------------------------------------------
    ----  BASE DEFENSE CONSTRUCTION
    --------------------------------------------------------------------------------
    {
        BuilderName = 'T1BaseDEngineerGround',
        TemplateName = 'EngineerGenericSingle',
        Priority = 700,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.DEFENSE * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { BMBC, 'NeedStructure', { 'T1GroundDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1GroundDefense',
                    'T1GroundDefense',
                    'T1GroundDefense',
                    'T1GroundDefense',
                },
            }
        }
    },
    {
        BuilderName = 'T1BaseDEngineerAA',
        TemplateName = 'EngineerGenericSingle',
        Priority = 700,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.DEFENSE * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { BMBC, 'NeedStructure', { 'T1AADefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1AADefense',
                    'T1AADefense',
                    'T1AADefense',
                    'T1AADefense',
                },
            }
        }
    },
    {
        BuilderName = 'T2BaseDEngineerGround',
        TemplateName = 'T2EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.DEFENSE * categories.TECH2}},
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T2GroundDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2GroundDefense',
                    'T2GroundDefense',
                },
            }
        }
    },
    {
        BuilderName = 'T2BaseDEngineerAA',
        TemplateName = 'T2EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 15, categories.DEFENSE * categories.TECH2}},
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T2AADefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2AADefense', 
                    'T2AADefense',
                },
            }
        }
    },
    {
        BuilderName = 'T2BaseDEngineerMissile',
        TemplateName = 'T2EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T2MissileDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2MissileDefense', 
                    'T2MissileDefense',
                },
            }
        }
    },
    {
        BuilderName = 'T2ShieldDEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.4}},
                { BMBC, 'NeedStructure', { 'T2ShieldDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2ShieldDefense', 
                },
            }
        }
    },
    {
        BuilderName = 'T2CounterIntel',
        TemplateName = 'T2EngineerBuilder',
        Priority = 850,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.COUNTERINTELLIGENCE * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.4}},
                { BMBC, 'NeedStructure', { 'T2RadarJammer', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2RadarJammer',
                },
            }
        }
    },
    {
        BuilderName = 'T3Anti-NukeEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 850,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 8, categories.ENGINEER * categories.TECH3}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ANTIMISSILE * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome', { 2.5, 100}},
                { BMBC, 'NeedStructure', { 'T3StrategicMissileDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3StrategicMissileDefense', 
                },
            }
        }
    },
    {
        BuilderName = 'T3BaseDEngineerAA',
        TemplateName = 'T3EngineerGenericSingle',
        Priority = 875,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 8, categories.ENGINEER * categories.TECH3}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.DEFENSE * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { BMBC, 'NeedStructure', { 'T3AADefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3AADefense',
                    'T3AADefense',
                },
            }
        }
    },
    {
        BuilderName = 'T3ShieldDEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 875,
        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 8, categories.ENGINEER * categories.TECH3}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.SHIELD * categories.TECH3}},
                { MIBC, 'FactionIndex', {1, 2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.2}},
                { BMBC, 'NeedStructure', { 'T3ShieldDefense', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3ShieldDefense', 
                },
            }
        }
    },


    --------------------------------------------------------------------------------
    ---- EMERGENCY BUILDING TECH 1
    --------------------------------------------------------------------------------
    
    {
        BuilderName = 'T1EmergencyMassExtractionEngineer',
        TemplateName = 'EngineerBuilder',
        Priority = 700,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.0}},
                { EBC, 'LessThanEconTrend', { 0, 100000}},
                { BMBC, 'NeedStructure', { 'T1Resource', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    {
        BuilderName = 'T1EmergencyMassCreationEngineer',
        TemplateName = 'EngineerBuilder',
        Priority = 850,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
                { BMBC, 'NeedStructure', { 'T1MassCreation', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1MassCreation',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    {
        BuilderName = 'T1 Emergency Power Engineer',
        TemplateName = 'EngineerBuilder',
        Priority = 850,
        InstanceCount = 2,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.1}},
                { EBC, 'LessThanEconTrend', { 100000, 0}},
                { BMBC, 'NeedStructure', { 'T1EnergyProduction', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    {
        BuilderName = 'T1MassStorage',
        TemplateName = 'EngineerBuilder',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.1}},
                { BMBC, 'NeedStructure', { 'MassStorage', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                    'MassStorage',
                }
            }
        }
    },
    {
        BuilderName = 'T1EnergyStorageEngineer',
        TemplateName = 'EngineerBuilder',
        Priority = 750,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.5, 0.9}},
                { BMBC, 'NeedStructure', { 'EnergyStorage', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'EnergyStorage',
                },
                Location = 'LocationType',
            }
        }
    },
    
    --------------------------------------------------------------------------------
    ---- EMERGENCY BUILDING TECH 2
    --------------------------------------------------------------------------------
    {
        BuilderName = 'T2PowerEngineer',
        TemplateName = 'T2EngineerBuilder',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH2}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.3}},
                { BMBC, 'NeedStructure', { 'T2EnergyProduction', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    
    --------------------------------------------------------------------------------
    ---- EMERGENCY BUILDING TECH 3
    --------------------------------------------------------------------------------
    {
        BuilderName = 'T3EmergencyPowerEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 975,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.5}},
                { EBC, 'LessThanEconTrend', { 100000, 0}},
                { BMBC, 'NeedStructure', { 'T3EnergyProduction', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    {
        BuilderName = 'T3EmergencyMassFabEngineer',
        TemplateName = 'T3EngineerBuilder',
        Priority = 975,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
                { EBC, 'LessThanEconTrend', { 0, 100000}},
                { BMBC, 'NeedStructure', { 'T3MassCreation', 'BASENAME' }},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T3MassCreation',
                },
            }
        }
    },
    
    
    
    
    
    ------------------------------------------------------------------------------
    ------------ COMMANDER STUFF --------------------------------
    ------------------------------------------------------------------------------
--    {
--        BuilderName = 'EngineerT1LandFactory-HaveNone',
--        TemplateName = 'CommanderBuilder',
--        Priority = 500,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.COMMAND}},
--                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.FACTORY * categories.LAND}},
--            },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        RequiresConstruction = false,
--        ExpansionExclude = {'Sea'},
--        PlatoonData = {
--            Construction = {
--                BuildClose = true,
--                BuildStructures = {
--                    'T1LandFactory',
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
    




    ------------------------------------------------------------------
    -------- EXPERIMENTAL BUILDERS ------------
    ------------------------------------------------------------------
--    {
--        BuilderName = 'T3 Land Exp1 Engineer 1',
--        TemplateName = 'T3EngineerBuilder',
--        Priority = 875,
--        InstanceCount = 1,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--        },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                BaseTemplate = ExBaseTmpl,
--                NearMarkerType = 'Rally Point',
--                BuildStructures = {
--                    'T4LandExperimental1', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
--    {
--        BuilderName = 'T3 Land Exp2 Engineer 1',
--        TemplateName = 'T3EngineerBuilder',
--        Priority = 825,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
--            },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                BaseTemplate = ExBaseTmpl,
--                NearMarkerType = 'Rally Point',
--                BuildStructures = {
--                    'T4LandExperimental2', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
--    {
--        BuilderName = 'T3 Air Exp1 Engineer 1',
--        TemplateName = 'T3EngineerBuilder',
--        Priority = 875,
--        InstanceCount = 1,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--            },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                NearMarkerType = 'Protected Experimental Construction',
--                BuildStructures = {
--                    'T4AirExperimental1', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
--    {
--        BuilderName = 'T3 Land Exp1 Engineer 2',
--        TemplateName = 'T3EngineerBuilderBig',
--        Priority = 900,
--        InstanceCount = 2,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--        },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                BaseTemplate = ExBaseTmpl,
--                NearMarkerType = 'Rally Point',
--                BuildStructures = {
--                    'T4LandExperimental1', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
--    {
--        BuilderName = 'T3 Land Exp2 Engineer 2',
--        TemplateName = 'T3EngineerBuilderBig',
--        Priority = 850,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.LAND * categories.EXPERIMENTAL}},
--            },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                BaseTemplate = ExBaseTmpl,
--                NearMarkerType = 'Rally Point',
--                BuildStructures = {
--                    'T4LandExperimental2', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },
--    {
--        BuilderName = 'T3 Air Exp1 Engineer 2',
--        TemplateName = 'T3EngineerBuilderBig',
--        Priority = 900,
--        InstanceCount = 3,
--        BuildConditions = {
--                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH3}},
--            },
--        LocationType = 'LocationType'
--        PlatoonType = 'Land',
--        --PlatoonAddPlans = {'PlatoonCallForHelpAI'},
--        ExpansionExclude = {'Sea'},
--        RequiresConstruction = false,
--        PlatoonData = {
--            Construction = {
--                BuildClose = false,
--                NearMarkerType = 'Protected Experimental Construction',
--                BuildStructures = {
--                    'T4AirExperimental1', 
--                },
--                Location = 'LocationType',
--            }
--        }
--    },




    ----------------------------------------------------------------------------
    -------- ENGINEERS ASSISTING --------------------------
    ----------------------------------------------------------------------------
    {
        BuilderName = 'T1EngineerAssistAttack',
        --PlatoonTemplate = 'EngineerAssist',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.MOBILE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = { 'MOBILE' },
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T1EngineerAssistDefense',
        --PlatoonTemplate = 'EngineerAssist',
        Priority = 950,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENGINEER * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.DEFENSE}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'DEFENSE'}, 
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T2EngineerAssistAttack',
        --PlatoonTemplate = 'T2EngineerAssist',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.MOBILE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'MOBILE'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T2EngineerAssistExperimental',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 850,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH2}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'EXPERIMENTAL'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3EngineerAssistAttack',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 850,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.MOBILE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'MOBILE'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3EngineerAssistArtillery',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 850,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.ARTILLERY}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'ARTILLERY'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3EngineerAssistExperimental',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 900,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.EXPERIMENTAL}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'EXPERIMENTAL'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3EngineerAssistBuildNuke',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 850,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.STRUCTURE * categories.NUKE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'NUKE'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'T3EngineerAssistNukeMissile',
        --PlatoonTemplate = 'T3EngineerAssist',
        Priority = 850,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.NUKE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.5}},
            },
        PlatoonType = 'Land',
        RequiresConstruction = false,
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BuilderCategories = {'NUKE'},
                Time = 60,
            },
        }
    },
}