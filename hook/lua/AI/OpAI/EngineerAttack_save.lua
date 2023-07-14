----------------------------------------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/EngineerAttack_save.lua
-- Summary  : Engineer platoon builder templates, along with transports, and its build conditions
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
----------------------------------------------------------------------------------------------------

--- Some context information:
--- AttackManager -> AM for short
--- PlatoonBuildManager -> PBM for short
--- 'Master' platoons -> AM platoons, formed from multiple 'Child' platoons
--- 'Child' platoons -> PBM platoons that are built by factories

--- Generic Child platoon count build condition that returns true if the amount of child platoons existing is less 1.
--- AKA 'Do we need an Engineer platoon ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@return boolean
function EngineerAttackChildCount(aiBrain, master)
    local ScenarioFramework = import("/lua/scenarioframework.lua")
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)
	
	return counter < 1
end

--- Generic Master platoon count build condition that returns true if the amount of master platoons existing is 1 or more.
--- AKA 'Do we have the PBM Engineer platoon(s) to form the AM platoon ?'
---@param aiBrain AIBrain default_brain
---@param master string
---@return boolean
function EngineerAttackMasterCount(aiBrain, master)
    local ScenarioFramework = import("/lua/scenarioframework.lua")
    local counter = ScenarioFramework.AMPlatoonCounter(aiBrain, master)

	return counter >= 1
end

--- Checks if the OpAI platoon's origin base's unique transport pool has less than 2 transports
--- AKA 'Do we have enough transports to assume we can transport our Engineer platoon ?'
---@param aiBrain AIBrain default_brain
---@param master string default_master
---@param locationName string default_location_type
---@return boolean
function NeedEngineerTransports(aiBrain, masterName, locationName)
	local poolName = 'TransportPool'
	
	if locationName then
		poolName = locationName .. '_TransportPool'
	end
	
    local transportPool = aiBrain:GetPlatoonUniquelyNamed(poolName)

    return not (transportPool and table.getn(transportPool:GetPlatoonUnits()) > 2)
end



Scenario = {
    Platoons = {
        ['OST_BLANK_TEMPLATE'] = {
            'OST_BLANK_TEMPLATE',
            '',
        },

        ['OST_EngineerAttack_T2Engineers'] = {
            'OST_EngineerAttack_T2Engineers',
            '',
            { 'uel0208', 0, 4, 'attack', 'None' },
            { 'uel0307', 0, 2, 'attack', 'None' },
        },
        ['OST_EngineerAttack_T2Transport'] = {
            'OST_EngineerAttack_T2Transport',
            '',
            { 'uea0104', 0, 1, 'support', 'None' },
        },

        ['OST_EngineerAttack_T2EngineersShieldsSeraphim'] = {
            'OST_EngineerAttack_T2EngineersShieldsSeraphim',
            '',
            { 'uel0208', 0, 6, 'attack', 'None' },
            { 'uel0307', 0, 2, 'attack', 'None' },
        },
        ['OST_EngineerAttack_T2EngineersSeraphim'] = {
            'OST_EngineerAttack_T2EngineersSeraphim',
            '',
            { 'uel0208', 0, 8, 'attack', 'None' },
        },
        ['OST_EngineerAttack_T1Engineers'] = {
            'OST_EngineerAttack_T1Engineers',
            '',
            { 'uel0105', 0, 2, 'attack', 'None' },
        },
        ['OST_EngineerAttack_T1Transport'] = {
            'OST_EngineerAttack_T1Transport',
            '',
            { 'uea0107', 0, 1, 'support', 'None' },
        },


        ['OST_EngineerAttack_T3Engineers'] = {
            'OST_EngineerAttack_T3Engineers',
            '',
            { 'uel0309', 0, 4, 'attack', 'None' },
            { 'uel0307', 0, 4, 'attack', 'None' },
        },
        ['OST_EngineerAttack_T3Transport'] = {
            'OST_EngineerAttack_T3Transport',
            '',
            { 'xea0306', 0, 1, 'support', 'None' },
        },
        ['OST_EngineerAttack_T2CombatEngineers'] = {
            'OST_EngineerAttack_T2CombatEngineers',
            '',
            { 'xel0209', 0, 1, 'attack', 'None'},
        },
    },

    Armies = {
        ARMY_1 = {
            PlatoonBuilders = {
                Builders = {
                    ['OSB_Child_EngineerAttack_T3Transport'] ={
                        PlatoonTemplate = 'OST_EngineerAttack_T3Transport',
                        Priority = 550,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Air',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'TransportPool', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'NeedEngineerTransports', {'default_brain','default_master', 'default_location_type'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 1 } },
                        },
                        PlatoonData = {
                        },
                        ChildrenType = {'T3Transports'},
                    },

                    ['OSB_Child_EngineerAttack_T2Transport'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T2Transport',
                        Priority = 545,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Air',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'TransportPool', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'NeedEngineerTransports', {'default_brain','default_master', 'default_location_type'} },
                        },
                        PlatoonData = {
                        },
                        ChildrenType = {'T2Transports'},
                    },

                    ['OSB_Child_EngineerAttack_T1Transport'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T1Transport',
                        Priority = 540,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Air',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'TransportPool', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'NeedEngineerTransports', {'default_brain','default_master', 'default_location_type'} },
                        },
                        PlatoonData = {
                        },
                        ChildrenType = {'T1Transports'},
                    },

                    ------------------------------------------------------------------------------------------------
                    ------------------------------------------------------------------------------------------------

                    ['OSB_Child_EngineerAttack_T3Engineers'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T3Engineers',
                        Priority = 525,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 1 } },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'T3Engineers'},
                    },

                    ['OSB_Child_EngineerAttack_T2Engineers'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T2Engineers',
                        Priority = 520,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 1, 2, 3 } },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'T2Engineers'},
                    },

                    ['OSB_Child_EngineerAttack_T2CombatEngineers'] ={
                        PlatoonTemplate = 'OST_EngineerAttack_T2CombatEngineers',
                        Priority = 520,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 1 } },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'CombatEngineers'},
                    },

                    ['OSB_Child_EngineerAttack_T2EngineersSeraphim'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T2EngineersSeraphim',
                        Priority = 516,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 4 } },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'T2Engineers'},
                    },

                    ['OSB_Child_EngineerAttack_T1Engineers'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T1Engineers',
                        Priority = 516,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'T1Engineers'},
                    },

                    ['OSB_Child_EngineerAttack_T2EngineersShieldsSeraphim'] = {
                        PlatoonTemplate = 'OST_EngineerAttack_T2EngineersShieldsSeraphim',
                        Priority = 516,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Land',
                        RequiresConstruction = true,
                        PlatoonAIFunction = {'/lua/ScenarioPlatoonAI.lua', 'DefaultOSBasePatrol', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackChildCount', {'default_brain','default_master'} },
                            {'/lua/editor/miscbuildconditions.lua', 'FactionIndex', {'default_brain', 4 } },
                        },
                        PlatoonData = {
                            {
                                type = 5,
                                name = 'AMPlatoons',
                                value =
                                {
                                    {
                                        type = 2,
                                        name = 'String_0',
                                        value = 'OSB_Master_EngineerAttack'
                                    },
                                }
                            },
                        },
                        ChildrenType = {'MobileShields', 'T2Engineers'},
                    },

                    ------------------------------------------------------------------------------------------------
                    ------------------------------------------------------------------------------------------------

                    ['OSB_Master_EngineerAttack'] = {
                        PlatoonTemplate = 'OST_BLANK_TEMPLATE',
                        Priority = 500,
                        InstanceCount = 1,
                        LocationType = 'MAIN',
                        BuildTimeOut = -1,
                        PlatoonType = 'Any',
                        RequiresConstruction = true,
                        PlatoonAIFunction =
                        {'/lua/ScenarioPlatoonAI.lua', 'PlatoonAttackHighestThreat', {'default_platoon'} },
                        BuildConditions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMCheckPlatoonLock', {'default_brain','default_master'} },
                            {'/lua/ai/opai/EngineerAttack_save.lua', 'EngineerAttackMasterCount', {'default_brain','default_master'} },
                        },
                        PlatoonBuildCallbacks = {
							{'/lua/editor/amplatoonhelperfunctions.lua', 'AMUnlockPlatoon', {'default_brain','default_platoon'} }, 
						},
                        PlatoonAddFunctions = {
                            {'/lua/editor/amplatoonhelperfunctions.lua', 'AMLockPlatoon', {'default_platoon'} },
                        },
                        PlatoonData = {
                            {type = 3, name = 'AMMasterPlatoon',  value = true},
                            {type = 3, name = 'UsePool', value = false},
                        },
                    },-- OSB_Master_EngineerAttack
                }, --Builders
            }, --Platoon Builders
        }, --ARMY_1
    }, --Armies
} --Scenario
