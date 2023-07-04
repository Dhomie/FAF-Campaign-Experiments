Changelog

# v5 (04.07.2023)
- Fixed the BaseManager messing up ACU upgrades, for real this time
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
- Initial tests with platoon forming platoons
- Added missing child type for the UEF 'Spreadhead' T3 MML
