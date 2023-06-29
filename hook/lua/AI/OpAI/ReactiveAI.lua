------------------------------------------------------------------
-- File     :  /lua/ai/OpAI/ReactiveAI.lua
-- Summary  : OpAI that reacts to certain defaulted events
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------

local OpAI = import("/lua/ai/opai/baseopai.lua").OpAI

local UCBC = '/lua/editor/unitcountbuildconditions.lua'
local BMBC = '/lua/editor/basemanagerbuildconditions.lua'
local MIBC = '/lua/editor/miscbuildconditions.lua'
local BMPT = '/lua/ai/opai/basemanagerplatoonthreads.lua'

local CampaignReactiveAI = ReactiveAI

ReactiveAI = Class(CampaignReactiveAI) {
	--Changed old GPG era 'FighterBomber' children type to the correct renamed 'CombatFighters' type
    ReactionData = {
        -- This uses purely air to respond.  It is the easiest to implement and has the least chance of breaking
        AirRetaliation = {
            ExperimentalAir = { 
                OpAI = 'AirAttacks', 
                Children = { 'AirSuperiority', 'CombatFighters', 'Interceptors', },
                Priority = 1200,
                ChildCount = 4,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.ExperimentalAir,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 1, TrackingCategories.ExperimentalAir, '>=' } },
                },
            },
            ExperimentalLand = { 
                OpAI = 'AirAttacks', 
                Children = { 'HeavyGunships', 'Gunships', 'Bombers', 'CombatFighters', },
                Priority = 1200,
                ChildCount = 3,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.ExperimentalLand,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 1, TrackingCategories.ExperimentalLand, '>=' } },
                },
            },
            ExperimentalNaval = { 
                OpAI = 'AirAttacks', 
                Children = { 'TorpedoBombers', 'HeavyTorpedoBombers', },
                Priority = 1200,
                ChildCount = 3,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.ExperimentalNaval,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 1, TrackingCategories.ExperimentalNaval, '>=' } },
                },
            },
            Nuke = { 
                OpAI = 'AirAttacks', 
                Children = { 'StrategicBombers', 'HeavyGunships', 'Gunships', 'Bombers', },
                ChildCount = 1,
                Priority = 1200,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.Nuke,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 1, TrackingCategories.Nuke, '>=' } },
                },
            },
            HLRA = { 
                OpAI = 'AirAttacks', 
                Children = { 'StrategicBombers', 'HeavyGunships', 'Gunships', 'Bombers', },
                ChildCount = 1,
                Priority = 1200,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.HLRA,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 1, TrackingCategories.HLRA, '>=' } },
                },
           },
            MassedAir = { 
                OpAI = 'AirAttacks', 
                Children = { 'AirSuperiority', 'CombatFighters', 'Interceptors', },
                ChildCount = 4,
                Priority = 1200,
                PlatoonAIFunction = { '/lua/ScenarioPlatoonAI.lua', 'CategoryHunterPlatoonAI' },
                PlatoonData = {
                    CategoryList = TrackingCategories.MassedAir,
                },
                TriggeringBuildConditions = {
                    { '/lua/editor/OtherArmyUnitCountBuildConditions.lua', 'FocusBrainBeingBuiltOrActiveCategoryCompare',
                        { 40, TrackingCategories.MassedAir, '>=' } },
                },
            },
        },
        -- End of AirRetaliation block
    },
}


--[[
Types usable in ReactiveAI

ReactionTypes:
    AirRetaliation
    
    ** Following not implemented yet **
    Horde
    Combined
    Pinpoint
    

TriggeringEventType
    ExperimentalLand
    ExperimentalAir
    ExperimentalNaval
    Nuke
    HLRA
    MassedAir

]]--
