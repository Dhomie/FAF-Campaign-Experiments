Changelog
#v12 (03.09.2023
- Added a **testing** version for the OpAI overhaul, see BaseOpAI.lua

# v11 (30.08.2023)
- Fixed (hopefully for the last time) the BaseManager's structure upgrade method, it's using unit build callbacks now.
- Recoded the BaseManager's Engineer build function thread via unit build callbacks as well, they'll pick new structures to build faster once their current structure is finished, added a lobby option to set the delay for it.
- Misc code cleanups, probably.

# v10 (04.08.2023)
- Code cleanups in preparation for the upcoming FAF patch, some of the mod's changes are included in the patch.
- Attempt at fixing the BaseManager's structure upgrade method.

# v9 (04.08.2023)
- Code cleanups, adjustments.
- Added FormCallbacks for OpAI ConditionalBuilds.
- Other misc stuff I guess.

# v8 (16.07.2023)
- Fixed non-reworked SC1 campaign maps' AIs building infinite amount of transports
- Slightly adjusted the amount of units the AIs need to form platoons for non-reworked SC1 campaign maps.
- Further cleaned up the files found in the lua/AI/OpAI folder that were used by non-reworked SC1 campaign maps.
- Misc. changes, code cleanups.

# v7 (14.07.2023)
- Added an option to allow AIs to use T3 Strategic Missile Launcher structures. This can mess with SMLs that are controlled via map script, so enable it at your own risk!
- BaseManager now assigns TMLs and SMLs into new platoons, allowing it to use any number inside the base's radius.
- Added AI functionality for SMLs, which can be enabled/disabled any time via the corresponding BaseManager funcionality
- Cleaned up the files found in the lua/AI/OpAI folder that were used by non-reworked SC1 campaign maps.
- Fixed non-reworked SC1 campaign maps' AIs not working properly (caused by some platoon AI function rewrites)
- Misc. changes, code cleanups, bug fixes.

# v6 (09.07.2023)
- Added economy, and build power cheat options for AIs, they are applied to all AI armies, including allied ones.
- Cleaned up the most commonly used *save.lua* files found in the lua/AI/OpAI folder, they contained a lot of duplicate data that weren't even used.

# v5 (04.07.2023)
- Fixed the BaseManager messing up ACU upgrades, for real this time
- Fixed the BaseManager not considering its Engineers as dead if they were either reclaimed or captured.
- AttackManager and PBM now cache their formed platoons' origin base.
- With that, AIs should now only use transports to pick up land platoons units if their origin bases match.
- Added the option to create unique transport platoons, and land platoons to pick unique transport platoons as well, just specify the 'BaseName' in PlatoonData
- Added default transport platoons to the BaseManager, courtesy of 4z0t for the idea, and execution.
- Added new build conditions for the above, also added build conditions to check the unit count of specific platoons.
- Misc. changes, code cleanups.

# v4 (29.06.2023)
- Code cleanups, leftover removals

# v3 (29.06.2023)
- Fixed the BaseManager messing up ACU upgrades that have prerequisites
- AttackManager.lua has been documented  to explain its purpose for campaign

# v2 (06.2023)
- Rewrote most commonly used build conditions, however this is pending a review
- Slightly altered logic how the AI forms random air platoons, it can now pick up to 3 times a single unit type
- AI will build/rebuild structures from their lowest available tech level, freeing up engineers faster
- AI will upgrade its structures more reliably, especially its factories
- AI will self-destruct any leftover units from transport attacks that didn't get loaded in time.

# v1 (06.2023)
- Initial tests with forming platoons
- Added missing child type for the UEF 'Spreadhead' T3 MML
