-- Transportutilities.lua --
-- This module is a core module of The LOUD Project and the work in it, is a creative work of Alexander W.G. Brown
-- Please feel free to use it, but please respect and preserve all the 'LOUD' references within

--- HOW IT WORKS --
-- By creating a 'pool' (TransportPool) just for transports - we can quickly find - and assemble - platoons of transports
-- A platoon of transports will be used to move platoons of units - the two entities remaining entirely separate from each other

-- Every transport created has a callback added that will return it back to the transport pool after a unit detach event
-- This 'ReturnTransportsToPool' process will separate out those which need fuel/repair - and return both groups to the nearest base
-- Transports which do not require fuel/repair are returned to the TransportPool
-- Transports which require fuel/repair will be assigned to the 'Refuel Pool' until that task is accomplished
-- The 'Refuel Pool' functionality (ProcessAirUnits) is NOT included in this module.  See LOUDUTILITIES for that.

local import = import

local TableCopy = table.copy
local EntityContains = EntityCategoryContains
local MathFloor = math.floor
local TableGetn = table.getn
local TableInsert = table.insert
local TableSort = table.sort
local ForkTo = ForkThread
local tostring = tostring
local type = type
local VDist2 = VDist2
local VDist3 = VDist3
local WaitTicks = coroutine.yield

local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
local GetFuelRatio = moho.unit_methods.GetFuelRatio
local GetFractionComplete = moho.entity_methods.GetFractionComplete
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetPosition = moho.entity_methods.GetPosition
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local IsBeingBuilt = moho.unit_methods.IsBeingBuilt
local IsIdleState = moho.unit_methods.IsIdleState
local IsUnitState = moho.unit_methods.IsUnitState
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local NavUtils = import("/lua/sim/navutils.lua")

local AIRTRANSPORTS = categories.AIR * categories.TRANSPORTFOCUS
local ENGINEERS = categories.ENGINEER
local TransportDialog = true

--  This routine should get transports on the way back to an existing base 
--  BEFORE marking them as not 'InUse' and adding them to the Transport Pool
function ReturnTransportsToPool( aiBrain, units, move )


    local RandomLocation = import('/lua/ai/aiutilities.lua').RandomLocation
    local VDist3 = VDist3
    local unitcount = 0
    local baseposition, reason, returnpool, safepath, unitposition

    -- cycle thru the transports, insure unloaded and assign to correct pool
    for k,v in units do
        if IsBeingBuilt(v) then     -- ignore under construction
            units[v] = nil
            continue
        end
        if not v.Dead and TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." transport "..v.EntityId.." "..v:GetBlueprint().Description.." Returning to Pool  InUse is "..repr(v.InUse) )
        end
        if v.WatchLoadingThread then
            KillThread( v.WatchLoadingThread)
            v.WatchLoadingThread = nil
        end
        if v.WatchTravelThread then
            KillThread( v.WatchTravelThread)
            v.WatchTravelThread = nil
        end
        if v.WatchUnloadThread then
            KillThread( v.WatchUnloadThread)
            v.WatchUnloadThread = nil
        end
        if v.Dead then
            if TransportDialog then
                LOG("*AI DEBUG "..aiBrain.Nickname.." transport "..v.EntityId.." dead during Return to Pool")
            end
            units[v] = nil
            continue
        end
        
        unitcount = unitcount + 1

		-- unload any units it might have and process for repair/refuel
		if EntityCategoryContains( categories.TRANSPORTFOCUS + categories.uea0203, v ) then
            if TableGetn(v:GetCargo()) > 0 then
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." transport "..v.EntityId.." has unloaded units")
                end
                local unloadedlist = v:GetCargo()
                IssueTransportUnload(v, v:GetPosition())
                WaitTicks(3)
                for _,unloadedunit in unloadedlist do
                    ForkTo( ReturnUnloadedUnitToPool, aiBrain, unloadedunit )
                end
            end
            v.InUse = nil
            v.Assigning = nil
            -- if the transport needs refuel/repair - remove it from further processing
            if ProcessAirUnits( v, aiBrain) then
                units[k] = nil
            end
        end
    end

    -- process whats left, getting them moving, and assign back to correct pool
	if unitcount > 0 and move then
		units = aiBrain:RebuildTable(units)     -- remove those sent for repair/refuel 
		for k,v in units do
			if v and not v.Dead and (not v.InUse) and (not v.Assigning) then
                returnpool = aiBrain:MakePlatoon('TransportRTB'..tostring(v.EntityId), 'none')
                returnpool.BuilderName = 'TransportRTB'..tostring(v.EntityId)
                returnpool.PlanName = returnpool.BuilderName
                AssignUnitsToPlatoon( aiBrain, returnpool, {v}, 'Unassigned', '')
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..returnpool.BuilderName.." Transport "..v.EntityId.." assigned" )
                end
                v.PlatoonHandle = returnpool
                unitposition = v:GetPosition()
				baseposition = aiBrain:PBMFindClosestBuildLocation(unitposition)
				local x, z
				if baseposition then
					x = baseposition[1]
					z = baseposition[3]
				else
					x, z = aiBrain:GetArmyStartPos()
				end
				
                if not (x and z) then
                    return
                end
                baseposition = RandomLocation(x,z)
                IssueClearCommands( {v} )
                if VDist3( baseposition, unitposition ) > 100 then
                    -- this requests a path for the transport with a threat allowance of 20 - which is kinda steep sometimes
					local safePath, reason = NavUtils.PathToWithThreatThreshold('Air', unitposition, baseposition, aiBrain, NavUtils.ThreatFunctions.AntiAir, 50, aiBrain.IMAPConfig.Rings)
                    if safePath then
                        if TransportDialog then
                            LOG("*AI DEBUG "..aiBrain.Nickname.." "..returnpool.BuilderName.." Transport "..v.EntityId.." gets RTB path of "..repr(safePath))
                        end
                        -- use path
                        for _,p in safePath do
                            IssueMove( {v}, p )
                        end
                    else
                        if TransportDialog then
                            LOG("*AI DEBUG "..aiBrain.Nickname.." "..returnpool.BuilderName.." Transport "..v.EntityId.." no safe path for RTB -- home -- after drop - going direct")
                        end
                        -- go direct -- possibly bad
                        IssueMove( {v}, baseposition )
                    end
                else
                    IssueMove( {v}, baseposition)
                end

				-- move the unit to the correct pool - pure transports to Transport Pool
				-- all others -- including temporary transports (UEF T2 gunship) to Army Pool
				if not v.Dead then
					if EntityContains( categories.TRANSPORTFOCUS - categories.uea0203, v ) then
                        if v.PlatoonHandle != aiBrain.TransportPool then
                            if TransportDialog then
                                LOG("*AI DEBUG "..aiBrain.Nickname.." "..v.PlatoonHandle.BuilderName.." transport "..v.EntityId.." now in the Transport Pool  InUse is "..repr(v.InUse))
                            end
                            AssignUnitsToPlatoon( aiBrain, aiBrain.TransportPool, {v}, 'Support', '' )
                            v.PlatoonHandle = aiBrain.TransportPool
                            v.InUse = false
                            v.Assigning = false                            
                        end
					else
                        if TransportDialog then
                            LOG("*AI DEBUG "..aiBrain.Nickname.." "..v.PlatoonHandle.BuilderName.." assigned unit "..v.EntityId.." "..v:GetBlueprint().Description.." to the Army Pool" )
                        end
						AssignUnitsToPlatoon( aiBrain, aiBrain.ArmyPool, {v}, 'Unassigned', '' )
						v.PlatoonHandle = aiBrain.ArmyPool
       					v.InUse = false
                        v.Assigning = false
					end
				end
			end
		end
	end
	if not aiBrain.CheckTransportPoolThread then
		aiBrain.CheckTransportPoolThread = ForkThread( CheckTransportPool, aiBrain )
	end
end

-- This gets called whenever a unit failed to unload properly - rare
-- Self-destruct the unit for coop
function ReturnUnloadedUnitToPool( aiBrain, unit )

	local attached = true
	
	if not unit.Dead then
		unit:Kill()
	end
	return
end

-- Find enough transports and move the platoon to its destination 
    -- destination - the destination location
    -- attempts - how many tries will be made to get transport
    -- bSkipLastMove - make drop at closest safe marker rather than at destination
    -- platoonpath - source platoon can optionally feed it's current travel path in order to provide additional alternate drop points if the destination is not good
function SendPlatoonWithTransports(aiBrain, platoon, destination, attempts, bSkipLastMove, platoonpath )

    -- destination must be in playable areas --
    if not InPlayableArea(destination) then
        return false
    end

	if (not platoon.MovementLayer) then
        import("/lua/ai/aiattackutilities.lua").GetMostRestrictiveLayer(platoon)
    end

    local MovementLayer = platoon.MovementLayer    

	if MovementLayer == 'Land' or MovementLayer == 'Amphibious' then
		local AIGetMarkersAroundLocation = import('/lua/ai/aiutilities.lua').AIGetMarkersAroundLocation
        local CalculatePlatoonThreat = moho.platoon_methods.CalculatePlatoonThreat
        local GetPlatoonPosition = GetPlatoonPosition
        local GetPlatoonUnits = GetPlatoonUnits
        local GetSurfaceHeight = GetSurfaceHeight
        local GetTerrainHeight = GetTerrainHeight
        local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
		local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
        local PlatoonCategoryCount = moho.platoon_methods.PlatoonCategoryCount
        local PlatoonExists = PlatoonExists

        local TableCat = table.cat
        local TableCopy = TableCopy
        local TableEqual = table.equal
        local MathFloor = MathFloor
        local MathLog10 = math.log10
        local VDist2Sq = VDist2Sq
        local VDist3 = VDist3
        local WaitTicks = WaitTicks

        local surthreat = 0
        local airthreat = 0
        local counter = 0
		local bUsedTransports = false
		local transportplatoon = false    

		local IsEngineer = PlatoonCategoryCount( platoon, ENGINEERS ) > 0

        local ALLUNITS = categories.ALLUNITS
        local TESTUNITS = ALLUNITS - categories.FACTORY - categories.ECONOMIC - categories.SHIELD - categories.WALL

		local airthreat, airthreatMax, Defense, markerrange, mythreat, path, reason, pathlength, surthreat, transportcount,units, transportLocation

		-- prohibit LAND platoons from traveling to water locations
		if MovementLayer == 'Land' then
			if GetTerrainHeight(destination[1], destination[3]) < GetSurfaceHeight(destination[1], destination[3]) - 1 then 
                if TransportDialog then	
                    LOG("*AI DEBUG "..aiBrain.Nickname.." SendPlatWTrans "..repr(platoon.BuilderName).." "..repr(platoon.BuilderInstance).." trying to go to WATER destination "..repr(destination) )
                end
				return false
			end
		end

		-- make the requested number of attempts to get transports - 12 second delay between attempts
		for counter = 1, attempts do
			if PlatoonExists( aiBrain, platoon ) then
				-- check if we can get enough transport and how many transports we are using
				-- this call will return the # of units transported (true) or false, if true, the platoon holding the transports or false
				bUsedTransports, transportplatoon = GetTransports( platoon, aiBrain )
				if bUsedTransports or counter == attempts then
					break
				end
				WaitTicks(120)
			end
		end

		-- if we didnt use transports
		if (not bUsedTransports) then
			if transportplatoon then
				ForkTo( ReturnTransportsToPool, aiBrain, GetPlatoonUnits(transportplatoon), true)
			end
			return false
		end
			
			-- a local function to get the real surface and air threat at a position based on known units rather than using the threat map
			-- we also pull the value from the threat map so we can get an idea of how often it's a better value
			-- I'm thinking of mixing the two values so that it will error on the side of caution
			local GetRealThreatAtPosition = function( position, range )
                
				local IMAPblocks = aiBrain.IMAPConfig.Rings or 1
				local sfake = GetThreatAtPosition( aiBrain, position, IMAPblocks, true, 'AntiSurface' )
				local afake = GetThreatAtPosition( aiBrain, position, IMAPblocks, true, 'AntiAir' )
                airthreat = 0
                surthreat = 0
				local eunits = GetUnitsAroundPoint( aiBrain, TESTUNITS, position, range,  'Enemy')
				if eunits then
					for _,u in eunits do
						if not u.Dead then
                            Defense = u.Blueprint.Defense
							airthreat = airthreat + Defense.AirThreatLevel
							surthreat = surthreat + Defense.SurfaceThreatLevel
						end
					end
                end
				
                -- if there is IMAP threat and it's greater than what we actually see
                -- use the sum of both * .5
				if sfake > 0 and sfake > surthreat then
					surthreat = (surthreat + sfake) * .5
				end
				
				if afake > 0 and afake > airthreat then
					airthreat = (airthreat + afake) * .5
				end
                
                return surthreat, airthreat
			end

			-- a local function to find an alternate Drop point which satisfies both transports and platoon for threat and a path to the goal
			local FindSafeDropZoneWithPath = function( platoon, transportplatoon, markerTypes, markerrange, destination, threatMax, airthreatMax, threatType, layer)
				
				local markerlist = {}
                local atest, stest
                local landpath,  landpathlength, landreason, lastlocationtested, path, pathlength, reason
				-- locate the requested markers within markerrange of the supplied location	that the platoon can safely land at
				for _,v in markerTypes do
					markerlist = TableCat( markerlist, AIGetMarkersAroundLocation(aiBrain, v, destination, markerrange, 0, threatMax, 0, 'AntiSurface') )
				end
				-- sort the markers by closest distance to final destination
				TableSort( markerlist, function(a,b) local VDist2Sq = VDist2Sq return VDist2Sq( a.Position[1],a.Position[3], destination[1],destination[3] ) < VDist2Sq( b.Position[1],b.Position[3], destination[1],destination[3] )  end )

				-- loop thru each marker -- see if you can form a safe path on the surface 
				-- and a safe path for the transports -- use the first one that satisfies both
				for _, v in markerlist do
                    if lastlocationtested and TableEqual(lastlocationtested, v.Position) then
                        continue
                    end

                    lastlocationtested = TableCopy( v.Position )
					-- test the real values for that position
					stest, atest = GetRealThreatAtPosition( lastlocationtested, 80 )
			
                    if TransportDialog then                    
                        LOG("*AI DEBUG "..aiBrain.Nickname.." "..transportplatoon.BuilderName.." examines position "..repr(v.Name).." "..repr(lastlocationtested).."  Surface threat "..stest.." -- Air threat "..atest)
                    end
		
					if stest <= threatMax and atest <= airthreatMax then
                        landpath = false
                        landpathlength = 0
						-- can the platoon path safely from this marker to the final destination 
						landpath, landreason, landpathlength = NavUtils.PathToWithThreatThreshold(layer, destination, lastlocationtested, aiBrain, NavUtils.ThreatFunctions.AntiAir, threatMax, aiBrain.IMAPConfig.Rings)
						-- can the transports reach that marker ?
						if landpath then
                            path = false
                            pathlength = 0
                            path, reason, pathlength = NavUtils.PathToWithThreatThreshold('Air', lastlocationtested, GetPlatoonPosition(platoon), aiBrain, NavUtils.ThreatFunctions.AntiAir, airthreatMax, aiBrain.IMAPConfig.Rings)
							if path then
                                if TransportDialog then
                                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." gets path to "..repr(destination).." from landing at "..repr(lastlocationtested).." path length is "..pathlength.." using threatmax of "..threatMax)
                                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." path reason "..landreason.." route is "..repr(landpath))
                                end
								return lastlocationtested, v.Name
							else
                                if TransportDialog then
                                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." got transports but they cannot find a safe drop point")
                                end
                            end
						end
                        if platoonpath then
                            lastlocationtested = false
                            for k,v in platoonpath do
                                stest, atest = GetRealThreatAtPosition( v, 80 )
                                if stest <= threatMax and atest <= airthreatMax then
                                    lastlocationtested = TableCopy(v)
                                end
                            end
                            if lastlocationtested then
                                if TransportDialog then
                                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." using platoon path position "..repr(v) )
                                end
                                return lastlocationtested, 'booga'
                            end
                        end
					end
				end
				return false, nil
			end
	

		-- FIND A DROP ZONE FOR THE TRANSPORTS
		-- this is based upon the enemy threat at the destination and the threat of the unit platoon and the transport platoon

		-- a threat value for the transports based upon the number of transports
		transportcount = TableGetn( GetPlatoonUnits(transportplatoon))
		airthreatMax = transportcount * 5
		airthreatMax = airthreatMax + ( airthreatMax * MathLog10(transportcount))

        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." "..transportplatoon.BuilderName.." with "..transportcount.." airthreatMax = "..repr(airthreatMax).." extra calc was "..math.log10(transportcount).." seeking dropzone" )
        end

		-- this is the desired drop location
		transportLocation = TableCopy(destination)

		-- the threat of the unit platoon
		mythreat = CalculatePlatoonThreat( platoon, 'Surface', ALLUNITS)

		if not mythreat or mythreat < 5 then 
			mythreat = 5
		end

		-- get the real known threat at the destination within 80 grids
		surthreat, airthreat = GetRealThreatAtPosition( destination, 80 )

		-- if the destination doesn't look good, use alternate or false
		if surthreat > mythreat or airthreat > airthreatMax then
            if (mythreat * 1.5) > surthreat then
                -- otherwise we'll look for a safe drop zone at least 50% closer than we already are
                markerrange = VDist3( GetPlatoonPosition(platoon), destination ) * .5
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." carried by "..transportplatoon.BuilderName.." seeking alternate landing zone within "..markerrange.." of destination "..repr(destination))
                end
                transportLocation = false
                -- If destination is too hot -- locate the nearest movement marker that is safe
                if MovementLayer == 'Amphibious' then
                    transportLocation = FindSafeDropZoneWithPath( platoon, transportplatoon, {'Amphibious Path Node','Land Path Node','Transport Marker'}, markerrange, destination, mythreat, airthreatMax, 'AntiSurface', MovementLayer)
                else
                    transportLocation = FindSafeDropZoneWithPath( platoon, transportplatoon, {'Land Path Node','Transport Marker'}, markerrange, destination, mythreat, airthreatMax, 'AntiSurface', MovementLayer)
                end
                if transportLocation then
                    if TransportDialog then
                        if surthreat > mythreat then
                            LOG("*AI DEBUG "..aiBrain.Nickname.." "..transportplatoon.BuilderName.." finds alternate landing position at "..repr(transportLocation).." surthreat is "..surthreat.." vs. mine "..mythreat)
                        else
                            LOG("*AI DEBUG "..aiBrain.Nickname.." "..transportplatoon.BuilderName.." finds alternate landing position at "..repr(transportLocation).." AIRthreat is "..airthreat.." vs. my max of "..airthreatMax)
                        end
                    end
                end
            else
                transportLocation = false
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." says simply too much threat for me - "..surthreat.." vs "..mythreat.." - aborting transport call")
                end
            end
        end

		-- if no alternate, or either platoon has died, return the transports and abort transport
		if not transportLocation or (not PlatoonExists(aiBrain, platoon)) or (not PlatoonExists(aiBrain,transportplatoon)) then
			if PlatoonExists(aiBrain,transportplatoon) then
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(platoon.BuilderName).." "..transportplatoon.BuilderName.." cannot find safe transport position to "..repr(destination).." - "..MovementLayer.." - transport request denied")
                end
				ForkTo( ReturnTransportsToPool, aiBrain, GetPlatoonUnits(transportplatoon), true)
			end

            if PlatoonExists(aiBrain,platoon) then
                platoon.UsingTransport = false
            end
			return false
		end

		-- correct drop location for surface height
		transportLocation[2] = GetSurfaceHeight(transportLocation[1], transportLocation[3])

		if platoon.MoveThread then
			platoon:KillMoveThread()
		end

		-- LOAD THE TRANSPORTS AND DELIVER --
		-- we stay in this function until we load, move and arrive or die
		-- we'll get a false return if then entire unit platoon cannot be transported
		-- note how we pass the IsEngineer flag -- alters the behaviour of the transport
		bUsedTransports = UseTransports( aiBrain, transportplatoon, transportLocation, platoon, IsEngineer )

		-- if platoon died or we couldn't use transports -- exit
		if (not platoon) or (not PlatoonExists(aiBrain, platoon)) or (not bUsedTransports) then
			-- if transports RTB them --
			if PlatoonExists(aiBrain,transportplatoon) then
				ForkTo( ReturnTransportsToPool, aiBrain, GetPlatoonUnits(transportplatoon), true)
			end
			return false
		end

		-- PROCESS THE PLATOON AFTER LANDING --
		-- if we used transports then process any unlanded units
		-- seriously though - UseTransports should have dealt with that
		-- anyhow - forcibly detach the unit and re-enable standard conditions
		units = GetPlatoonUnits(platoon)

		for _,v in units do
			if not v.Dead and IsUnitState( v, 'Attached' ) then
				v:DetachFrom()
				v:SetCanTakeDamage(true)
				v:SetDoNotTarget(false)
				v:SetReclaimable(true)
				v:SetCapturable(true)
				v:ShowBone(0, true)
				v:MarkWeaponsOnTransport(v, false)
			end
		end
		
		-- set path to destination if we landed anywhere else but the destination
		-- All platoons except engineers (which move themselves) get this behavior
		if (not IsEngineer) and GetPlatoonPosition(platoon) != destination then
			if not PlatoonExists( aiBrain, platoon ) or not GetPlatoonPosition(platoon) then
				return false
			end

			-- path from where we are to the destination - use inflated threat to get there --
			path = NavUtils.PathToWithThreatThreshold(MovementLayer, GetPlatoonPosition(platoon), destination, aiBrain, NavUtils.ThreatFunctions.AntiSurface,  mythreat * 1.25, aiBrain.IMAPConfig.Rings)

			if PlatoonExists( aiBrain, platoon ) then
				-- if no path then fail otherwise use it
				if not path and destination != nil then
					return false
				elseif path then
					platoon.MoveThread = platoon:ForkThread( platoon.MovePlatoon, path, 'AttackFormation', true )
				end
			end
		end
	end
    
	return PlatoonExists( aiBrain, platoon )
    
end

-- This function actually loads and moves units on transports using a safe path to the location desired
-- Just a personal note - this whole transport thing is a BITCH
-- This was one of the first tasks I tackled and years later I still find myself coming back to it again and again - argh
function UseTransports( aiBrain, transports, location, UnitPlatoon, IsEngineer )

	local TableCopy = TableCopy
	local EntityContains = EntityContains
	local TableGetn = TableGetn
	local TableInsert = TableInsert

	local WaitTicks = WaitTicks
	
	local PlatoonExists = PlatoonExists
	local GetBlueprint = moho.entity_methods.GetBlueprint
    local GetPlatoonPosition = GetPlatoonPosition
    local GetPlatoonUnits = GetPlatoonUnits

    local transportTable = {}	
	local counter = 0
	
	-- check the transport platoon and count - load the transport table
	-- process any toggles (stealth, etc.) the transport may have
	if PlatoonExists( aiBrain, transports ) then

		for _,v in GetPlatoonUnits(transports) do
			if not v.Dead then
				if v:TestToggleCaps('RULEUTC_StealthToggle') then
					v:SetScriptBit('RULEUTC_StealthToggle', false)
				end
				if v:TestToggleCaps('RULEUTC_CloakToggle') then
					v:SetScriptBit('RULEUTC_CloakToggle', false)
				end
				if v:TestToggleCaps('RULEUTC_IntelToggle') then
					v:SetScriptBit('RULEUTC_IntelToggle', false)
				end
			
				local slots = TableCopy( aiBrain.TransportSlotTable[v.UnitId] )
				counter = counter + 1
				transportTable[counter] = {	Transport = v, LargeSlots = slots.Large, MediumSlots = slots.Medium, SmallSlots = slots.Small, Units = { ["Small"] = {}, ["Medium"] = {}, ["Large"] = {} } }
			end
		end
	end
	
	if counter < 1 then
    
        UnitPlatoon.UsingTransport = false
        
		return false
    end

	-- This routine allocates the units to specific transports
	-- Units are injected on a TransportClass basis ( 3 - 2 - 1 )
	-- As each unit is assigned - the transport has its remaining slot count
	-- reduced & the unit is added to the list assigned to that transport
	local function SortUnitsOnTransports( transportTable, unitTable )
        
		local leftoverUnits = {}
        local count = 0
	
		for num, unit in unitTable do
			local transSlotNum = 0
			local remainingLarge = 0
			local remainingMed = 0
			local remainingSml = 0
			local TransportClass = 	unit.Blueprint.Transport.TransportClass
			
			-- pick the transport with the greatest number of appropriate slots left
			for tNum, tData in transportTable do
				if tData.LargeSlots >= remainingLarge and TransportClass == 3 then
					transSlotNum = tNum
					remainingLarge = tData.LargeSlots
					remainingMed = tData.MediumSlots
					remainingSml = tData.SmallSlots
				elseif tData.MediumSlots >= remainingMed and TransportClass == 2 then
					transSlotNum = tNum
					remainingLarge = tData.LargeSlots
					remainingMed = tData.MediumSlots
					remainingSml = tData.SmallSlots
				elseif tData.SmallSlots >= remainingSml and TransportClass == 1 then
					transSlotNum = tNum
					remainingLarge = tData.LargeSlots
					remainingMed = tData.MediumSlots
					remainingSml = tData.SmallSlots
				end
			end
			if transSlotNum > 0 then
				-- assign the large units
				-- notice how we reduce the count of the lower slots as we use up larger ones
				-- and we do the same to larger slots as we use up smaller ones - this was not the 
				-- case before - and caused errors leaving units unassigned - or over-assigned
				if TransportClass == 3 and remainingLarge >= 1.0 then
					transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - 1.0
					transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 0.25
					transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 0.50
					-- add the unit to the Large list for this transport
					TableInsert( transportTable[transSlotNum].Units.Large, unit )
				elseif TransportClass == 2 and remainingMed >= 1.0 then
					transportTable[transSlotNum].LargeSlots = transportTable[transSlotNum].LargeSlots - 0.1
					transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 1.0
					transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 0.34
					-- add the unit to the Medium list for this transport
					TableInsert( transportTable[transSlotNum].Units.Medium, unit )
				elseif TransportClass == 1 and remainingSml >= 1.0 then
					transportTable[transSlotNum].MediumSlots = transportTable[transSlotNum].MediumSlots - 0.1	-- yes .1 - for UEF T2 gunships
					transportTable[transSlotNum].SmallSlots = transportTable[transSlotNum].SmallSlots - 1
					-- add the unit to the list for this transport
					TableInsert( transportTable[transSlotNum].Units.Small, unit )
				else
					count = count + 1
					leftoverUnits[count] = unit
				end
			else
                count = count + 1
				leftoverUnits[count] = unit
			end
		end
		return transportTable, leftoverUnits
	end	

	-- tables that hold those units which are NOT loaded yet
	-- broken down by their TransportClass size
    local remainingSize3 = {}
    local remainingSize2 = {}
    local remainingSize1 = {}
	
	counter = 0

	-- check the unit platoon, load the unit remaining tables, and count
	if PlatoonExists( aiBrain, UnitPlatoon) then
		-- load the unit remaining tables according to TransportClass size
		for k, v in GetPlatoonUnits(UnitPlatoon) do
			if v and not v.Dead then
				counter = counter + 1
				if v.Blueprint.Transport.TransportClass == 3 then
					TableInsert( remainingSize3, v )
				elseif v.Blueprint.Transport.TransportClass == 2 then
					TableInsert( remainingSize2, v )
				elseif v.Blueprint.Transport.TransportClass == 1 then
					TableInsert( remainingSize1, v )
				else
					WARN("*AI DEBUG "..aiBrain.Nickname.." Cannot transport "..GetBlueprint(v).Description)
					counter = counter - 1  -- take it back
					
				end
				if IsUnitState( v, 'Attached') then
					--LOG("*AI DEBUG unit "..v:GetBlueprint().Description.." is attached at "..repr(v:GetPosition()))
					v:DetachFrom()
					v:SetCanTakeDamage(true)
					v:SetDoNotTarget(false)
					v:SetReclaimable(true)
					v:SetCapturable(true)
					v:ShowBone(0, true)
					v:MarkWeaponsOnTransport(v, false)
				end
			end
		end
	end

	-- if units were assigned - sort them and tag them for specific transports
	if counter > 0 then
	
		-- flag the unit platoon as busy
		UnitPlatoon.UsingTransport = true
		local leftoverUnits = {}
		local currLeftovers = {}
        counter = 0
	
		-- assign the large units - note how we come back with leftoverunits here
		transportTable, leftoverUnits = SortUnitsOnTransports( transportTable, remainingSize3 )
		-- assign the medium units - but this time we come back with currleftovers
		transportTable, currLeftovers = SortUnitsOnTransports( transportTable, remainingSize2 )
		-- and we move any currleftovers into the leftoverunits table
		for k,v in currLeftovers do
		
			if not v.Dead then
                counter = counter + 1
				leftoverUnits[counter] = v
			end
		end
		
		currLeftovers = {}
	
		-- assign the small units - again coming back with currleftovers
		transportTable, currLeftovers = SortUnitsOnTransports( transportTable, remainingSize1 )
	
		-- again adding currleftovers to the leftoverunits table
		for k,v in currLeftovers do
		
			if not v.Dead then
                counter = counter + 1
				leftoverUnits[counter] = v
			end
		end
		
		currLeftovers = {}
	
		if leftoverUnits[1] then
			transportTable, currLeftovers = SortUnitsOnTransports( transportTable, leftoverUnits )
		end
	
		-- Self-destruct any leftovers
		if currLeftovers[1] then
			for _,v in currLeftovers do
				v:Kill()
			end
		end
	end

	remainingSize3 = nil
    remainingSize2 = nil
    remainingSize1 = nil

	-- At this point all units should be assigned to a given transport or dismissed
	local loading = false
    local loadissued, unitstoload, transport
	
	-- loop thru the transports and order the units to load onto them	
    for k, data in transportTable do
		loadissued = false
		unitstoload = false
		counter = 0
		-- look for dead/missing units in this transports unit list
		-- and those that may somehow be attached already
        for size,unitlist in data.Units do
			for u,v in unitlist do
				if v and not v.Dead then
					if not unitstoload then
						unitstoload = {}
					end
					counter = counter + 1					
					unitstoload[counter] = v
				else
					data.Units[size][u] = nil
				end
			end
		end

		-- if units are assigned to this transport
        if data.Units["Large"][1] then
            IssueClearCommands( data.Units["Large"] )
			loadissued = true
		end
		
		if data.Units["Medium"][1] then
            IssueClearCommands( data.Units["Medium"] )
			loadissued = true
		end
		
		if data.Units["Small"][1] then
            IssueClearCommands( data.Units["Small"] )
			loadissued = true
		end
		
		if not loadissued or not unitstoload then
            if TransportDialog then
                LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." transport "..data.Transport.EntityId.." no load issued or units to load")
            end
			-- RTP any transport with nothing to load
			ForkTo( ReturnTransportsToPool, aiBrain, {data.Transport}, true )
		else
			transport = data.Transport
			transport.InUse = true
            transport.Assigning = false
			transport.WatchLoadingThread = transport:ForkThread( WatchUnitLoading, unitstoload, aiBrain, UnitPlatoon )
			loading = true
		end
    end
	
	-- if loading has been issued watch it here
	if loading then
        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." loadwatch begins" )
        end    
		if UnitPlatoon.WaypointCallback then
			KillThread( UnitPlatoon.WaypointCallback )
			UnitPlatoon.WaypointCallback = nil
            if UnitPlatoon.MovingToWaypoint then
                --LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(UnitPlatoon.BuilderInstance).." MOVINGTOWAYPOINT cleared by transport ")
                UnitPlatoon.MovingToWaypoint = nil
            end
		end
	
		local loadwatch = true	
		
		while loadwatch do
			WaitTicks(8)
			loadwatch = false
			if PlatoonExists( aiBrain, transports) then
				for _,t in GetPlatoonUnits(transports) do
					if not t.Dead and t.Loading then
						loadwatch = true
					else
                        if t.WatchLoadingThread then
                            KillThread (t.WatchLoadingThread)
                            t.WatchLoadingThread = nil
                        end
                    end
				end
			end
		end
	end

    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." loadwatch complete")
	end

	if not PlatoonExists(aiBrain, transports) then
        UnitPlatoon.UsingTransport = false
		return false
	end

	-- Any units that failed to load send back to pool thru RTB
    -- this one really only occurs when an inbound transport is killed
	if PlatoonExists( aiBrain, UnitPlatoon ) then
		local returnpool = false
		for k,v in GetPlatoonUnits(UnitPlatoon) do
			if v and (not v.Dead) then
				if not IsUnitState( v, 'Attached') then
					v:Kill()
				end
			end
		end
	end

	counter = 0
	
	-- count number of loaded transports and send empty ones home
	if PlatoonExists( aiBrain, transports ) then
		for k,v in GetPlatoonUnits(transports) do
			if v and (not v.Dead) and TableGetn(v:GetCargo()) == 0 then
				ForkTo( ReturnTransportsToPool, aiBrain, {v}, true )
				transports[k] = nil
			else
				counter = counter + 1
			end
		end	
	end

	-- plan the move and send them on their way
	if counter > 0 then
		local platpos = GetPlatoonPosition(transports) or false
		if platpos then
			local airthreatMax = counter * 4.2
			airthreatMax = airthreatMax + ( airthreatMax * math.log10(counter))
            local safePath, reason, pathlength = NavUtils.PathToWithThreatThreshold('Air', platpos, location, aiBrain, NavUtils.ThreatFunctions.AntiAir,  airthreatMax, aiBrain.IMAPConfig.Rings)
            if TransportDialog then
                if not safePath then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." no safe path to "..repr(location).." using threat of "..airthreatMax)
                else
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." has path to "..repr(location).." - length "..repr(pathlength).." - reason "..reason)
                end
            end
		
			if PlatoonExists( aiBrain, transports) then
				IssueClearCommands( GetPlatoonUnits(transports) )
				IssueMove( GetPlatoonUnits(transports), GetPlatoonPosition(transports))
				if safePath then 
					local prevposition = GetPlatoonPosition(transports) or false
                    local Direction
					for _,p in safePath do
						if prevposition then
							local base = Vector( 0, 0, 1 )
                            local direction = import('/lua/utilities.lua').GetDirectionVector(Vector(prevposition[1], prevposition[2], prevposition[3]), Vector(p[1], p[2], p[3]))
							Direction = import('/lua/utilities.lua').GetAngleCCW( base, direction )
							IssueFormMove( GetPlatoonUnits(transports), p, 'AttackFormation', Direction)
							prevposition = p
						end
					end
                    
				else
					if TransportDialog then
                        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." goes direct to "..repr(location))
                    end
					-- go direct ?? -- what ?
					local base = Vector( 0, 0, 1 )
					local transPos = GetPlatoonPosition(transports)
                    local direction = import('/lua/utilities.lua').GetDirectionVector(Vector(transPos[1], transPos[2], transPos[3]), Vector(location[1], location[2], location[3]))
					IssueFormMove( GetPlatoonUnits(transports), location, 'AttackFormation', import('/lua/utilities.lua').GetAngleCCW( base, direction )) 
				end

				if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." starts travelwatch to "..repr(location))
                end
			
				for _,v in GetPlatoonUnits(transports) do
					if not v.Dead then
						v.WatchTravelThread = v:ForkThread(WatchTransportTravel, location, aiBrain, UnitPlatoon)		
					end
                end
			end
            
		end
	end
	
	local transporters = GetPlatoonUnits(transports) or false
	
	-- if there are loaded, moving transports, watch them while traveling
	if transporters and TableGetn(transporters) != 0 then
		-- this sets up the transports platoon ability to call for help and to detect major threats to itself
		-- we'll also use it to signal an 'abort transport' capability using the DistressCall field
        -- threat trigger is based on number of transports
		transports:ForkThread( transports.PlatoonCallForHelpAI, aiBrain, TableGetn(transporters) )
		transports.AtGoal = false -- flag to allow unpathed unload of the platoon
		local travelwatch = true
		-- loop here until all transports signal travel complete
		-- each transport should be running the WatchTravel thread
		-- until it dies, the units it is carrying die or it gets to target
		while travelwatch and PlatoonExists( aiBrain, transports ) do
			travelwatch = false
			WaitTicks(4)
			for _,t in GetPlatoonUnits(transports) do
				if t.Travelling and not t.Dead then
					travelwatch = true
				end
			end
		end

        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." travelwatch complete")
        end
    end

	transporters = GetPlatoonUnits(transports) or false
	
	-- watch the transports until they signal unloaded or dead
	if transporters and TableGetn(transporters) != 0 then
    
        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." unloadwatch begins")
        end    
		
		local unloadwatch = true
        local unloadcount = 0 
		
		while unloadwatch do
			WaitTicks(5)
            unloadcount = unloadcount + .4
			unloadwatch = false
			for _,t in GetPlatoonUnits(transports) do
				if t.Unloading and not t.Dead then
					unloadwatch = true
                else
                    if t.WatchUnloadThread then
                        KillThread(t.WatchUnloadThread)
                        t.WatchUnloadThread = nil
                    end
				end
			end
		end

        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..repr(transports.BuilderName).." unloadwatch complete after "..unloadcount.." seconds")
        end
        
        for _,t in GetPlatoonUnits(transports) do
            if not t.EventCallbacks['OnTransportDetach'] then
                ForkTo( ReturnTransportsToPool, aiBrain, {t}, true )
            end
        end
    end
	
	if not PlatoonExists(aiBrain,UnitPlatoon) then
        return false
    end
	
	UnitPlatoon.UsingTransport = false

    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." Transport complete ")
    end
	
	return true
end

-- Ok -- this routine allowed me to get some control over the reliability of loading units onto transport
-- I have to say, the lack of a GETUNITSTATE function really made this tedious but here is the jist of what I've found
-- Some transports will randomly report false to TransportHasSpaceFor even when completely empty -- causing them to fail to load units
-- just to note, the same also seems to apply to AIRSTAGINGPLATFORMS

-- I was eventually able to determine that two states are most important in this process --
-- TransportLoading for the transports
-- WaitingForTransport for the units 

-- Essentially if the transport isn't Moving or TransportLoading then something is wrong
-- If a unit is not WaitingForTransport then it too has had loading interrupted 
-- however - I have noticed that transports will continue to report 'loading' even when all the units to be loaded are dead 
function WatchUnitLoading( transport, units, aiBrain, UnitPlatoon)
	
	local unitsdead = true
	local loading = false
	local reloads = 0
	local reissue = 0
	local newunits = TableCopy(units)
	local GetPosition = GetPosition
	local watchcount = 0
    transport.Loading = true

	IssueStop( {transport} )
    
    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." transport "..transport.EntityId.." moving to "..repr(units[1]:GetPosition()).." for pickup - distance "..VDist3( transport:GetPosition(), units[1]:GetPosition()))
    end
	
    -- At this point we really should safepath to the position
    -- and we should probably use a movement thread 
	IssueMove( {transport}, GetPosition(units[1]) )
	WaitTicks(5)
	
	for _,u in newunits do
		if not u.Dead then
			unitsdead = false
			loading = true
			-- here is where we issue the Load command to the transport --
			safecall("Unable to IssueTransportLoad units are "..repr(units), IssueTransportLoad, newunits, transport )
			break
		end
	end

	local tempunits = {}
	local counter = 0
	
    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." begins loading")
    end
    
	-- loop here while the transport is alive and loading is underway
	-- there is another trigger (watchcount) which will force loading
	-- to false after 210 seconds
	while (not unitsdead) and loading do
		watchcount = watchcount + 1.3
		if watchcount > 210 then
            WARN("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." ABORTING LOAD - watchcount "..watchcount)
			loading = false
            transport.Loading = nil
            ForkTo ( ReturnTransportsToPool, aiBrain, {transport}, true )
			break
		end
		
		WaitTicks(14)
		
		tempunits = {}
		counter = 0

        -- check for death of transport - and verify that units are still awaiting load
		if (not transport.Dead) and transport.Loading and ( not IsUnitState(transport,'Moving') or IsUnitState(transport,'TransportLoading') ) then
			unitsdead = true
			loading = false
			-- loop thru the units and pick out those that are not yet 'attached'
			-- also detect if all units to be loaded are dead
			for _,u in newunits do
				if not u.Dead then
					-- we have some live units
					unitsdead = false
					if not IsUnitState( u, 'Attached') then
						loading = true
						counter = counter + 1
						tempunits[counter] = u
					end
				end
			end
		
			-- if all dead or all loaded or unit platoon no longer exists, RTB the transport
			if unitsdead or (not loading) or reloads > 20 then
				if unitsdead then
                    transport.Loading = nil
					ForkTo ( ReturnTransportsToPool, aiBrain, {transport}, true )
                    return
				end
				
				loading = false
			end
		end

		-- issue reloads to unloaded units if transport is not moving and not loading units
		if (not transport.Dead) and (loading and not (IsUnitState( transport, 'Moving') or IsUnitState( transport, 'TransportLoading'))) then

			reloads = reloads + 1
			reissue = reissue + 1
			newunits = false
			counter = 0
			
			for k,u in tempunits do
				if (not u.Dead) and not IsUnitState( u, 'Attached') then
					-- if the unit is not attached and the transport has space for it or it's a UEF Gunship (TransportHasSpaceFor command is unreliable)
					if (not transport.Dead) and transport:TransportHasSpaceFor(u) then
						IssueStop({u})
						if reissue > 1 then
							if TransportDialog then
                                LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport"..transport.EntityId.." Warping unit "..u.EntityId.." to transport ")
							end
							Warp( u, GetPosition(transport) )
							reissue = 0
						end
						if not newunits then
							newunits = {}
						end
						counter = counter + 1						
						newunits[counter] = u
					-- if the unit is not attached and the transport does NOT have space for it - turn off loading flag and clear the tempunits list
					elseif (not transport.Dead) and (not transport:TransportHasSpaceFor(u)) and (not EntityCategoryContains(categories.uea0203,transport)) then
						loading = false
						newunits = false
						break
					elseif (not transport.Dead) and EntityCategoryContains(categories.uea0203,transport) then
						loading = false
						newunits = false
						break
					end	
				end
			end
			
			if newunits and counter > 0 then
				if reloads > 1 and TransportDialog then
					LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." Reloading "..counter.." units - reload "..reloads)
				end
				IssueStop( newunits )
				IssueStop( {transport} )
				local goload = safecall("Unable to IssueTransportLoad", IssueTransportLoad, newunits, transport )
				if goload and TransportDialog then
					LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." reloads is "..reloads.." goload is "..repr(goload).." for "..transport:GetBlueprint().Description)
				end
			else
				loading = false
			end
		end
	end

    if TransportDialog then
        if transport.Dead then
            -- at this point we should find a way to reprocess the units this transport was responsible for
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." Transport "..transport.EntityId.." dead during WatchLoading")
        else
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." completes load in "..watchcount)
        end
    end

    if transport.InUse then
        IssueStop( {transport} )
        if (not transport.Dead) then
            if not unitsdead then
                -- have the transport guard his loading spot until everyone else has loaded up
                IssueGuard( {transport}, GetPosition(transport) )
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." begins to loiter after load")
                end
            else
                transport.Loading = nil
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." aborts load - unitsdead is "..repr(unitsdead).." watchcount is "..watchcount)
                end
                ForkTo ( ReturnTransportsToPool, aiBrain, {transport}, true )
                return
            end
        end
    end
	transport.Loading = nil
end

function WatchTransportTravel( transport, destination, aiBrain, UnitPlatoon )

	local unitsdead = false
	local watchcount = 0
	local GetPosition = GetPosition
    local VDist2 = VDist2
    local WaitTicks = WaitTicks
	
	transport.StuckCount = 0
	transport.LastPosition = TableCopy(GetPosition(transport))
    transport.Travelling = true
    
    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." starts travelwatch")
    end
	
	while (not transport.Dead) and (not unitsdead) and transport.Travelling do
			-- major distress call -- 
			if transport.PlatoonHandle.DistressCall then
				-- reassign destination and begin immediate drop --
				-- this really needs to be sensitive to the platoons layer
				-- and find an appropriate marker to drop at -- 
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." DISTRESS ends travelwatch after "..watchcount)
                end
				destination = GetPosition(transport)
                break
			end
			
			-- someone in transport platoon is close - begin the drop -
			if transport.PlatoonHandle.AtGoal then
                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." signals ARRIVAL after "..watchcount)
                end
				break
			end
        
			unitsdead = true

			for _,u in transport:GetCargo() do
				if not u.Dead then
					unitsdead = false
					break
				end
			end

			-- if all dead except UEF Gunship RTB the transport
			if unitsdead and not EntityCategoryContains(categories.uea0203,transport) then
				transport.StuckCount = nil
				transport.LastPosition = nil
				transport.Travelling = false

                if TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." UNITS DEAD ends travelwatch after "..watchcount)
                end

				ForkTo( ReturnTransportsToPool, aiBrain, {transport}, true )
                return
			end
		
			-- is the transport still close to its last position bump the stuckcount
			if transport.LastPosition then
				if VDist2(transport.LastPosition[1], transport.LastPosition[3], GetPosition(transport)[1],GetPosition(transport)[3]) < 6 then
					transport.StuckCount = transport.StuckCount + 0.5
				else
					transport.StuckCount = 0
				end
			end

			if ( IsIdleState(transport) or transport.StuckCount > 8 ) then
				if transport.StuckCount > 8 then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." StuckCount in WatchTransportTravel to "..repr(destination) )				
					transport.StuckCount = 0
				end

				IssueClearCommands( {transport} )
				IssueMove( {transport}, destination )
			end
		
			-- this needs some examination -- it should signal the entire transport platoon - not just itself --
			if VDist2(GetPosition(transport)[1], GetPosition(transport)[3], destination[1],destination[3]) < 100 then
				transport.PlatoonHandle.AtGoal = true
			else
                transport.LastPosition = TableCopy(transport:GetPosition())
            end
    
            if not transport.PlatoonHandle.AtGoal then
                WaitTicks(11)
                watchcount = watchcount + 1
            end

	end

	if not transport.Dead then
		IssueClearCommands( {transport} )
		if not transport.Dead then
            if TransportDialog then
                LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." ends travelwatch ")
            end
		
			transport.StuckCount = nil
			transport.LastPosition = nil
			transport.Travelling = nil

			transport.WatchUnloadThread = transport:ForkThread( WatchUnitUnload, transport:GetCargo(), destination, aiBrain, UnitPlatoon )
		end
	end
	
end

function WatchUnitUnload( transport, unitlist, destination, aiBrain, UnitPlatoon )

    local WaitTicks = WaitTicks
	local unitsdead = false
	local unloading = true
    transport.Unloading = true
    
    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." unloadwatch begins at "..repr(destination) )
    end
	
	IssueTransportUnload( {transport}, destination)
    WaitTicks(4)
	local watchcount = 0.3

	while (not unitsdead) and unloading and (not transport.Dead) do
		unitsdead = true
		unloading = false
	
        if not transport.Dead then
			-- do we have loaded units
			for _,u in unitlist do
				if not u.Dead then
					unitsdead = false
					if IsUnitState( u, 'Attached') then
						unloading = true
						break
					end
				end
			end

            -- in this case unitsdead can mean that OR that we've unloaded - either way we're done
			if unitsdead or not unloading then
                if TransportDialog then
                    if not transport.Dead then
                        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." transport "..transport.EntityId.." unloadwatch complete after "..watchcount.." seconds")
                        --transport.InUse = false
                        transport.Unloading = nil
                        if not transport.EventCallbacks['OnTransportDetach'] then
                            ForkTo( ReturnTransportsToPool, aiBrain, {transport}, true )
                        end
                    else
                        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." transport "..transport.EntityId.." dead during unload")
                    end
                end
			end
            -- watch the count and try to force the unload
			if unloading and (not transport:IsUnitState('TransportUnloading')) then
				if watchcount >= 12 then
					LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." transport "..transport.EntityId.." FAILS TO UNLOAD after "..watchcount.." seconds")
					break			
				elseif watchcount >= 8 then
					LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." transport "..transport.EntityId.." watched unload for "..watchcount.." seconds")
					IssueTransportUnload( {transport}, GetPosition(transport))
				elseif watchcount > 4 then
					IssueTransportUnload( {transport}, GetPosition(transport))
				end
			end
		end
        
		WaitTicks(6)
		watchcount = watchcount + 0.5
    
        if TransportDialog then
            LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." unloadwatch cycles "..watchcount )
        end
	end
    
    if TransportDialog then
        LOG("*AI DEBUG "..aiBrain.Nickname.." "..repr(UnitPlatoon.BuilderName).." "..transport.PlatoonHandle.BuilderName.." Transport "..transport.EntityId.." unloadwatch ends" )
    end
    transport.Unloading = nil
end

-- Processes air units at the end of work. Note we dont have an AirUnitRefitThread that handles transport yet so it is disabled.
function ProcessAirUnits( unit, aiBrain )
	if (not unit.Dead) and (not IsBeingBuilt(unit)) then
        local fuel = GetFuelRatio(unit)
		if ( fuel > -1 and fuel < .75 ) or unit:GetHealthPercent() < .80 then
            if not unit.InRefit then
                if ScenarioInfo.TransportDialog then
                    LOG("*AI DEBUG "..aiBrain.Nickname.." Air Unit "..unit.Sync.id.." assigned to AirUnitRefitThread ")
                end
                -- and send it off to the refit thread --
                --unit:ForkThread( AirUnitRefitThread, aiBrain )
                return true
            else
                LOG("*AI DEBUG "..aiBrain.Nickname.." Air Unit "..unit.Sync.id.." "..unit:GetBlueprint().Description.." already in refit Thread")
            end
		end
	end
	return false    -- unit did not need processing
end

