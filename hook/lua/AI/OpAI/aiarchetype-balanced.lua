--****************************************************************************
--**
--**  File     :  /lua/AI/aiarchetype-balanced.lua
--**  Author(s): John Comes
--**
--**  Summary  : Balanced Archetype AI
--**
--**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************

local AIBuildUnits = import('/lua/ai/aibuildunits.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local PlatoonTemplates = import('/lua/platoontemplates.lua').PlatoonTemplates

local BBTmplFile = '/lua/basetemplates.lua'
local BuildingTmpl = 'BuildingTemplates'
local BaseTmpl = 'BaseTemplates'
local ExBaseTmpl = 'ExpansionBaseTemplates'
local Adj2x2Tmpl = 'Adjacency2x2'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local OAUBC = '/lua/editor/OtherArmyUnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local PCBC = '/lua/editor/PlatoonCountBuildConditions.lua'
local SAI = '/lua/ScenarioPlatoonAI.lua'
local PlatoonFile = '/lua/platoon.lua'


function EvaluatePlan( aiBrain )
    local per = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
    if not per then return 1 end
    if per == 'random' then
        return Random(1, 100)
    elseif per != 'balanced' and per != 'hard' and per != '' then
        return 1
    elseif per == 'balanced' then
        return 150
    end

    local mapSizeX, mapSizeZ = GetMapSize()
    local isIsland = false
    local startX, startZ = aiBrain:GetArmyStartPos()
    local islandMarker = AIUtils.AIGetClosestMarkerLocation(aiBrain, 'Island', startX, startZ)
    if islandMarker then
        isIsland = true
    end
    --If we're playing on an island map, do not use this plan
    if isIsland then
        return 0
    --If we're playing on a 256 map, do no go balanced
    elseif mapSizeX < 500 and mapSizeZ < 500 then
        return 0
    --If we're playing on a 512 map, possibly go rush, possibly go balanced
    elseif mapSizeX > 500 and mapSizeZ > 500 and mapSizeX < 1000 and mapSizeZ < 1000 then
        return Random(50, 52)
    --If we're playing on a 1024 or bigger, turtling is best.
    elseif mapSizeX > 1000 and mapSizeZ > 1000 then
        return Random(50, 60)
    elseif mapSizeX > 2000 and mapSizeZ > 2000 then
        return 10
    end
end

local PlatoonList = {
    --------------------------------------------------------------------
    --  Commander
    --------------------------------------------------------------------
    {
        BuilderName = 'CDR Initial',
        PlatoonAddBehaviors = { 'CDROverchargeBehavior', 'CDRRunAwayBehavior', 'CDRGiveUpBehavior', 'CDRLeash', 'CDRCallForHelp', },
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.FACTORY * categories.LAND}},
                { MIBC, 'NotPreBuilt', {}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        BuilderName = 'CDR Initial PreBuilt',
        PlatoonAddBehaviors = { 'CDROverchargeBehavior', 'CDRRunAwayBehavior', 'CDRGiveUpBehavior', 'CDRLeash', 'CDRCallForHelp', },
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 1000,
        BuildConditions = {
                { MIBC, 'PreBuiltBase', {}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        PlatoonData = {
            Construction = {
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1AADefense',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1AirFactory',
                    'T1GroundDefense',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1LandFactory',
                    'T1AADefense',
                    'T1GroundDefense',
                }
            }
        }
    },
    {
        BuilderName = 'CDR Single T1Resource',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
                { MABC, 'MarkerLessThanDistance',  { 'Mass', 30, 0, 0, 1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1Resource',
                },
                Location = 'MAIN',
            }
        }
    },
    {
        BuilderName = 'CDR Mass Fab CDR',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MASSFABRICATION * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.MASSEXTRACTION * categories.TECH2}},
                { EBC, 'LessThanEconStorageRatio', { 0.1, 1.1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1MassCreation',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
                Location = 'MAIN',
            }
        }
    },
    {
        BuilderName = 'CDR T1 Energy',
        PlatoonTemplate = 'CommanderBuilder',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'LessThanEconStorageRatio', { 1.1, 0.1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
            }
        }
    },
    {
        BuilderName = 'CDR Assist Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 800,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Assist = {
                AssistRange = 80,
                BeingBuiltCategories = {'FACTORY -NAVAL', 'ENGINEER'},
                Time = 60,
            },
        }
    },
    {
        BuilderName = 'CDR Assist Mass Extractor Upgrade',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 900,
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuilt', { 0, categories.TECH2 * categories.MASSEXTRACTION}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {1, 1}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'AdvancedEngineering', 'LeftPod', 'RightPod', 'ResourceAllocation'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
    {
        BuilderName = 'UEF CDR Upgrade T3 Eng - Shields',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {1, 1}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'T3Engineering', 'RightPodRemove', 'Shield', 'ShieldGeneratorField'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
        ----------
        --  Aeon
        ----------
    {
        BuilderName = 'Aeon CDR Upgrade AdvEng - Shield - Crysalis',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {2, 2}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'AdvancedEngineering', 'Shield', 'CrysalisBeam'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
    {
        BuilderName = 'Aeon CDR Upgrade T3 Eng - ShieldHeavy',
        PlatoonTemplate = 'CommanderEnhance',
        BuildConditions = {
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {2, 2}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'T3Engineering', 'ShieldHeavy'},
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
                { UCBC, 'HaveEqualToUnitsWithCategory', { 1, categories.COMMAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {3, 3}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.MASSEXTRACTION - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION - categories.TECH1}},
                { EBC, 'GreaterThanEconEfficiency', { 0.6, 0.6}},
                { MIBC, 'FactionIndex', {3, 3}},
            },
        Priority = 800,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Enhancement = { 'T3Engineering', 'ResourceAllocation'},
			--Enhancement = {'T3Engineering'},
        },
        PlatoonAddBehaviors = { 'BuildOnceAI' },
    },
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
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 5, categories.ENGINEER * categories.TECH1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Engineer Disband - Filler',
        PlatoonTemplate = 'EngineerOnlyBuild',
        Priority = 920,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 20, categories.MOBILE}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 10, categories.ENGINEER * categories.TECH1}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.25}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Engineer Disband - Init',
        PlatoonTemplate = 'T2EngineerOnlyBuild',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 6, categories.ENGINEER * categories.TECH2}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Engineer Disband - Filler',
        PlatoonTemplate = 'T2EngineerOnlyBuild',
        Priority = 930,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY - categories.TECH1}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 40, categories.MOBILE}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER * categories.TECH2}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        ExpansionExclude = {'Sea'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T3 Engineer Disband - Init',
        PlatoonTemplate = 'T3EngineerOnlyBuild',
        Priority = 950,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 12, categories.ENGINEER * categories.TECH3}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        ExpansionExclude = {'Sea'},
        RequiresConstruction = true,
    },
    {
        BuilderName = 'T3 Engineer Disband - Filler',
        PlatoonTemplate = 'T3EngineerOnlyBuild',
        Priority = 940,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH3}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 24, categories.ENGINEER * categories.TECH3}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 60, categories.MOBILE}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.1}},
            },
        LocationType = 'MAIN',
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
                --{ UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.FACTORY * categories.LAND * categories.STRUCTURE}},
				{ UCBC, 'NumUnitsLessNearBase', { 'MAIN', categories.FACTORY * categories.LAND * categories.STRUCTURE, 8}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
                Location = 'MAIN',
            }
        }
    },
	{
        BuilderName = 'Engineer T1 Air Factory - Additional Factories',
        PlatoonTemplate = 'EngineerGenericSingle',
        Priority = 900,
        BuildConditions = {
                --{ UCBC, 'HaveLessThanUnitsWithCategory', { 9, categories.FACTORY * categories.AIR * categories.STRUCTURE}},
				{ UCBC, 'NumUnitsLessNearBase', { 'MAIN', categories.FACTORY * categories.AIR * categories.STRUCTURE, 8}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.25, 0.5}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
                { MIBC, 'ReclaimablesInArea', { 'MAIN', }},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
		InstanceCount = 3,
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1Radar',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AirStagingPlatform',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2Artillery',
                    'T2StrategicMissile',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3QuantumGate',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3Artillery',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3StrategicMissile',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Protected Experimental Construction',
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Protected Experimental Construction',
                BuildStructures = {
                    'T4AirExperimental1',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2MissileDefense',
                    --'T2MissileDefense',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    --'T2AADefense',
                    'T2AADefense',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    --'T2AADefense',
                    'T2AADefense',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                Location = 'MAIN',
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
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20,         'MAIN',
                -- LocationRadius  UnitCount    UnitCategory
                       200,           5,     'DEFENSE TECH1'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
        },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'MAIN',
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'MAIN',
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
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20, 'MAIN', 200, 5, 'DEFENSE TECH1'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'MAIN',
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'MAIN',
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
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Defensive Point', 20, 'MAIN', 200, 10, 'DEFENSE TECH2'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                NearMarkerType = 'Defensive Point',
                MarkerRadius = 20,
                LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
    --------------------------------------------------------------------
    --  STRUCTURES
    --------------------------------------------------------------------
    {
        BuilderName = 'T1 Mass Extractor Upgrade',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * categories.TECH1}},
                { EBC, 'GreaterThanEconIncome',  {1, 10}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
	{
        BuilderName = 'T1 Mass Extractor Upgrade - Big Econ',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 3,
        Priority = 200,
        BuildConditions = {
                { EBC, 'GreaterThanEconIncome',  {5, 100}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Land Factory Upgrade',
        PlatoonTemplate = 'T1LandFactoryUpgrade',
        Priority = 200,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1 * categories.LAND}},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconIncome',  {6, 60}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.15, 0.15}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { EBC, 'GreaterThanEconIncome',  {12, 120}},
                { EBC, 'GreaterThanEconStorageRatio',  {0.25, 0.25}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Air Factory Upgrade',
        PlatoonTemplate = 'T1AirFactoryUpgrade',
        Priority = 200,
        InstanceCount = 1,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH1 * categories.AIR}},
				{ UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
                { EBC, 'GreaterThanEconIncome',  {6, 60}},
                { EBC, 'GreaterThanEconStorageRatio',  {0.15, 0.15}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { EBC, 'GreaterThanEconIncome',  {12, 120}},
                { EBC, 'GreaterThanEconStorageRatio',  {0.25, 0.25}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Mass Extractor Upgrade',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION * categories.TECH2}},
                { EBC, 'GreaterThanEconIncome',  { 6, 120}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
	{
        BuilderName = 'T2 Mass Extractor Upgrade - Big Econ',
        PlatoonTemplate = 'T2MassExtractorUpgrade',
        InstanceCount = 3,
        Priority = 200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION * categories.TECH2}},
                { EBC, 'GreaterThanEconIncome',  { 18, 360}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Land Factory Upgrade',
        PlatoonTemplate = 'T2LandFactoryUpgrade',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH2 * categories.LAND}},
                { EBC, 'GreaterThanEconIncome',  { 25, 500}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.3, 0.3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Air Factory Upgrade',
        PlatoonTemplate = 'T2AirFactoryUpgrade',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.TECH2 * categories.AIR}},
                { EBC, 'GreaterThanEconIncome',  { 25, 500}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.3, 0.3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Radar Upgrade',
        PlatoonTemplate = 'T1RadarUpgrade',
        Priority = 200,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.RADAR * categories.TECH1}},
                { EBC, 'GreaterThanEconIncome',  { 5, 15}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Radar Upgrade',
        PlatoonTemplate = 'T2RadarUpgrade',
        Priority = 300,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.RADAR * categories.TECH2}},
                { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.RADAR * categories.TECH3}},
                { EBC, 'GreaterThanEconIncome',  { 10, 600}},
                { EBC, 'GreaterThanEconStorageRatio',  { 0.2, 0.2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 TML Silo',
        PlatoonTemplate = 'T2TacticalLauncher',
        Priority = 5,
        InstanceCount = 10,
        BuildConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', {5, categories.STRUCTURE * categories.TECH2 * categories.TACTICALMISSILEPLATFORM}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { MIBC, 'FactionIndex', {3, 3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { MIBC, 'FactionIndex', {3, 3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { MIBC, 'FactionIndex', {3, 3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { MIBC, 'FactionIndex', {3, 3}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Shield UEF and Aeon',
        PlatoonTemplate = 'T2Shield',
        Priority = 5,
        InstanceCount = 1,
        BuildConditions = {
                { EBC, 'GreaterThanEconIncome',  {7, 100}},
                { MIBC, 'FactionIndex', {1, 1}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Nuke Silo',
        PlatoonTemplate = 'T3Nuke',
        Priority = 5,
        InstanceCount = 5,
        BuildConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', {1, categories.STRUCTURE * categories.TECH3 * categories.NUKE}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Anti Nuke Silo',
        PlatoonTemplate = 'T3AntiNuke',
        Priority = 5,
        InstanceCount = 10,
        BuildConditions = {
                { UCBC, 'HaveLessThanUnitsWithCategory', {2, categories.STRUCTURE * categories.TECH3 * categories.ANTIMISSILE}},
            },
        BuildTimeOut = 120,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Mass Fabricator Pause',
        PlatoonTemplate = 'T1MassFabricator',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSFABRICATION * categories.TECH1}},
                { EBC, 'LessThanEconStorageRatio',  { 1.0, 0.05}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Mass Fabricator Pause',
        PlatoonTemplate = 'T3MassFabricator',
        Priority = 300,
        InstanceCount = 3,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSFABRICATION * categories.TECH3}},
                { EBC, 'LessThanEconStorageRatio',  { 1.0, 0.05}},
            },
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Land',
        PlatoonAddPlans = {'DistressResponseAI', 'PlatoonCallForHelpAI'},
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Air Bomber',
        PlatoonTemplate = 'T1AirBomber1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 500,
        InstanceCount = 5,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR}},
                --{ EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T1 Air Fighter',
        PlatoonTemplate = 'T1AirFighter1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 550,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 5, categories.MOBILE * categories.AIR, 'Enemy'}},
                --{ EBC, 'GreaterThanEconTrend', { -0.5, -1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
		--Transports are of giga importance, so they should be prioritized at all times
        BuilderName = 'T1 Air Transport',
        PlatoonTemplate = 'T1AirTransport1',
        Priority = 850,
        InstanceCount = 4,
        BuildTimeOut = 2400,
        BuildConditions = {
                --{ MIBC, 'ArmyNeedsTransports', {} },
				{ UCBC, 'HaveLessThanUnitsWithCategory', {4, categories.TRANSPORTATION * categories.TECH1} },
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
        ----------
        --  Tech 2
        ----------
    -- Make sure we continue to build scouts at T2
    {
        BuilderName = 'T2 Air Scout',
        PlatoonTemplate = 'T1AirScout1',
        Priority = 750,
        InstanceCount = 1,
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Air Scout - Lower Pri',
        PlatoonTemplate = 'T1AirScout1',
        Priority = 550,
        InstanceCount = 1,
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Air Gunship',
        PlatoonTemplate = 'T2AirGunship1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 600,
        InstanceCount = 6,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR - categories.TECH1}},
                { EBC, 'GreaterThanEconTrend', { -0.8, -1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T2 Air CDR Strike Force Gunship',
        PlatoonTemplate = 'T2AirGunship1',
        PlatoonAIPlan = 'StrikeForceAI',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 600,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR - categories.TECH1}},
                { EBC, 'GreaterThanEconTrend', { -0.8, -1}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL', 'EXPERIMENTAL', 'ENERGYPRODUCTION', 'STRUCTURE' }, -- list in order
        },
    },
    {
        BuilderName = 'T2 Air Transport',
        PlatoonTemplate = 'T2AirTransport1',
        Priority = 850,
        InstanceCount = 6,
        BuildTimeOut = 2400,
        BuildConditions = {
                --{ MIBC, 'ArmyNeedsTransports', {} },
                { EBC, 'GreaterThanEconEfficiency', { 0.25, 0.25}},
				{ UCBC, 'HaveLessThanUnitsWithCategory', {6, categories.TRANSPORTATION * categories.TECH2} },
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
        ----------
        --  Tech 3
        ----------
    {
        BuilderName = 'T3 Air Gunship',
        PlatoonTemplate = 'T3AirGunship1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 700,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air Scout',
        PlatoonTemplate = 'T3AirScout1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 750,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air Fighter',
        PlatoonTemplate = 'T3AirFighter1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 725,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR * categories.TECH3}},
                { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.MOBILE * categories.AIR, 'Enemy'}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air Bomber',
        PlatoonTemplate = 'T3AirBomber1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 700,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air CDR Strike Force Bomber',
        PlatoonTemplate = 'T3AirBomber1',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        PlatoonAIPlan = 'StrikeForceAI',
        Priority = 800,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL', 'EXPERIMENTAL', 'ENERGYPRODUCTION', 'STRUCTURE' }, -- list in order
        },
    },
    {
        BuilderName = 'T3 Air CDR Strike Force Gunship',
        PlatoonTemplate = 'T3AirGunship2',
        PlatoonAIPlan = 'StrikeForceAI',
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        Priority = 800,
        InstanceCount = 2,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR * categories.TECH3}},
                { EBC, 'GreaterThanEconStorageRatio', { 0.3, 0.3}},
                { EBC, 'GreaterThanEconTrend', { -1, -2}},
            },
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = true,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            PrioritizedCategories = { 'COMMAND', 'FACTORY -NAVAL', 'EXPERIMENTAL', 'ENERGYPRODUCTION', 'STRUCTURE' }, -- list in order
        },
    },
    {
        BuilderName = 'T4 Exp Air',
        PlatoonTemplate = 'T4ExperimentalAir',
        PlatoonAddPlans = {'NameUnits'},
        PlatoonAIPlan = 'StrikeForceAI',
        Priority = 800,
        InstanceCount = 3,
        BuildTimeOut = 2400,
        BuildConditions = {
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.AIR * categories.EXPERIMENTAL}},
                { MIBC, 'FactionIndex', {2, 3}},
            },
        PlatoonType = 'Air',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
        PlatoonData = {
            PrioritizedCategories = { 'COMMAND', 'ANTIAIR', 'EXPERIMENTAL', 'FACTORY -NAVAL', 'STRUCTURE' }, -- list in order
        },
    },
    
    
    
    ----------------------------------------
    -- AIR SCOUT WITHOUT CONSTRUCTION
    ----------------------------------------
    {
        BuilderName = 'T1 Air Scout - No Build',
        PlatoonTemplate = 'T1AirScout1',
        Priority = 650,
        InstanceCount = 1,
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
    },
    {
        BuilderName = 'T3 Air Scout - No Build',
        PlatoonTemplate = 'T3AirScout1',
        Priority = 750,
        PlatoonAddBehaviors = { 'AirUnitRefit' },
        InstanceCount = 1,
        LocationType = 'MAIN',
        PlatoonType = 'Air',
        RequiresConstruction = false,
        ExpansionExclude = {'Sea'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Naval Area', 20,         'MAIN',
                -- LocationRadius  UnitCount    UnitCategory
                       150,           4,     'FACTORY NAVAL'} },



                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'MAIN',
                NearMarkerType = 'Naval Area',
                ExpansionBase = true,
                ExpansionRadius = 40,
                ExpansionTypes = { 'Sea' },
                MarkerRadius = 20,
                LocationType = 'MAIN',
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
                { UCBC, 'HaveLessThanUnitsAroundMarkerCategory', { 'Naval Area', 20, 'MAIN', 500, 4, 'FACTORY NAVAL'} },
                { EBC, 'GreaterThanEconStorageRatio', { 0.1, 0.25}},
                { EBC, 'GreaterThanEconEfficiency', { 0.75, 0.75}},
        },
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        ExpansionExclude = {'Sea'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                Location = 'MAIN',
                NearMarkerType = 'Naval Area',
                MarkerRadius = 20,
                LocationRadius = 500,
                LocationType = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
        RequiresConstruction = false,
        PlatoonData = {
            Construction = {
                BuildClose = false,
                NearMarkerType = 'Naval Area',
                BuildStructures = {
                    'T4SeaExperimental1',
                },
                Location = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        LocationType = 'MAIN',
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
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
    },
    {
        BuilderName = 'T3 Artillery Structure',
        PlatoonTemplate = 'T3ArtilleryStructure',
        Priority = 1,
        InstanceCount = 5,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
    },
    {
        BuilderName = 'T4 Artillery Structure',
        PlatoonTemplate = 'T4ArtilleryStructure',
        Priority = 1,
        InstanceCount = 5,
        RequiresConstruction = false,
        PlatoonType = 'Any',
        PlatoonAddPlans = {'PlatoonCallForHelpAI'},
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
            { UCBC, 'HaveAreaWithUnitsFewWalls', { 'MAIN', 100, 5, 'STRUCTURE - WALL', false, false, false } },
        },
        PlatoonData = {
            Construction = {
                BuildStructures = { 'Wall' },
                LocationType = 'MAIN',
                Wall = true,
                MarkerRadius = 100,
                MarkerUnitCount = 5,
                MarkerUnitCategory = 'STRUCTURE - WALL',
            },
        },
    },
}

function AIAC(aiBrain, num)
    local mobUnitsT1 = aiBrain:GetCurrentUnits(categories.MOBILE * categories.LAND - categories.ENGINEER * categories.TECH1)
    local mobUnitsT2 = aiBrain:GetCurrentUnits(categories.MOBILE * categories.LAND - categories.ENGINEER * categories.TECH2)
    local mobUnitsT3 = aiBrain:GetCurrentUnits(categories.MOBILE * categories.LAND - categories.ENGINEER * categories.TECH3)
    mobUnitsT2 = mobUnitsT2 * 2
    mobUnitsT3 = mobUnitsT3 * 4
    local mobUnits = mobUnitsT1 + mobUnitsT2 + mobUnitsT3
    local enemyDefensesDF = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.STRUCTURE * categories.DIRECTFIRE, Vector(0,0,0), 100000, 'Enemy')
    local enemyDefensesIF = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.STRUCTURE * categories.INDIRECTFIRE, Vector(0,0,0), 100000, 'Enemy')
    local enemyMobileDF = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.DIRECTFIRE, Vector(0,0,0), 100000, 'Enemy')
    local returnVal = false
    local enemyDefenses = enemyDefensesDF + enemyDefensesIF
    if mobUnits > enemyDefenses * 2 then
        returnVal = true
    elseif mobUnits > enemyMobileDF * 1.5 then
        returnVal = true
    elseif mobUnits > 100 then
        returnVal = true
    end
    return returnVal
end

--Shared area
function ExecutePlan(aiBrain)
    aiBrain:SetConstantEvaluate(false)
    WaitSeconds(2)
    if not aiBrain:PBMHasPlatoonList() then
        --LOG('*AI DEBUG: ARMY ', repr(aiBrain:GetArmyIndex()), ': Initiating Archetype Balanced AI')
        aiBrain:SetResourceSharing(true)
        aiBrain:PBMEnableRandomSamePriority()
        AIBuildUnits.AIExecutePlanUnitList(aiBrain, PlatoonList, PlatoonTemplates[aiBrain:GetFactionIndex()])
        aiBrain:PBMFormAllPlatoons('MAIN')
        ForkThread(UnitCapWatchThread, aiBrain)
    end
    if not aiBrain:AMIsAttackManagerActive() then
        local spec = {
            AttackCheckInterval = 60,
            AttackConditions = {
                    {AIAC, {4}}
                },
        }
        aiBrain:InitializeAttackManager(spec)
    end
    if not aiBrain.BaseMonitor then
        aiBrain:BaseMonitorInitialization()
        local plat = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.PoolDistressAI)
    end
    if not aiBrain.EnemyPickerThread then
        aiBrain.EnemyPickerThread = aiBrain:ForkThread(aiBrain.PickEnemy)
    end
--    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
--    aiBrain:GiveT1Resource('Energy', econ.EnergyMaxStored * 0.2)
--    aiBrain:GiveT1Resource('Mass', econ.MassMaxStored * 0.2)
end


function UnitCapWatchThread(aiBrain)
    KillPD = false
    while true do
        WaitSeconds(60)
        if GetArmyUnitCostTotal(aiBrain:GetArmyIndex()) > (GetArmyUnitCap(aiBrain:GetArmyIndex()) - 10) then
            if not KillPD then
                local units = aiBrain:GetListOfUnits(categories.TECH1 * categories.ENERGYPRODUCTION * categories.STRUCTURE, true)
                for k, v in units do
                    v:Kill()
                end
                KillPD = true
            else

                local units = aiBrain:GetListOfUnits(categories.TECH1 * categories.DEFENSE * categories.DIRECTFIRE * categories.STRUCTURE, true)
                for k, v in units do
                    v:Kill()
                end
                KillPD = false
            end
        end
    end
end