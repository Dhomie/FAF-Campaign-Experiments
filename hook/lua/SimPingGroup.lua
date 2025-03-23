-----------------------------------------------------------------
-- File       : /lua/SimPingGroup.lua
-- Author(s)  : Unknown, former GPG employees
-- Summary    : Sim side of UI ping groups from the campaign
-- Updated by : Dhomie42/Grandpa Sawyer
-- Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------
--- Add a ping chicklet for the user to click on
--- This function returns an ID of the ping group for use if you need to delete it later.

--- Data information:
-- Callback		- Function to be executed when the ping is issued by the user
-- Name			- String name that appears on the tooltip
-- Description	- String description that appears on the tooltip
-- BlueprintID	- Used to create the unit icon, defaults to one of the order icons depending on the ping type
-- Type			- Type of ping, can be "move", "alert", or "attack", defaults to the "Guard" icon (probably the "alert type ?)
-- Active		- Determines if the UI ping button can be clicked on at all, but the Sim also checks this value before attempting to do the callbacks, defaults to true

--- Table function information:
-- AddCallback				- Inserts a callback function to the ping group, the params these are called with are the ping's position, and the army index it was called by
-- RemoveCallback			- Removes a callback function from the ping group, either via a direct function, or index comparison
-- Destroy 					- Removes both the Sim, and UI data on the ping, sets the local PingGroups table entry of it to nil, BUT doesn't decrease the size of the table
-- SetActive				- Sets both Sim and UI attributes "Active" that determines if the players' LMB click on the map should do anything, the UI only does the ping, and Sim callback if it's active
-- UpdateData				- Updates both the Sim and UI for the name, icon, unit icon, and description elements, each are optional
-- UpdateUIDescription		- Updates the description on the UI tooltip WITHOUT overwriting the Sim one, so you can either add entirely new UI descriptions, or just add to the existing one

local PingGroups = {}
local idNum = 1
local TableInsert = table.insert

--- Creates the Ping Group, inserts it into the Sync table, and return the instance, see the above documentation for more detailed description
---@param name String | UI button name that appears on the tooltip
---@param blueprintID String | Used to create the unit icon, defaults to one of the order icons depending on the ping type
---@param type String | Type of ping, can be "move", "alert", or "attack", defaults to the "Guard" order (probably the "alert" type ?)
---@param description String | UI button Description that appears on the tooltip
---@return Table
function AddPingGroup(name, blueprintID, type, description)
    local PingGroup = {
        _id = idNum,
        Name = name,
        Description = description,
        BlueprintID = blueprintID,
        Type = type,
        _callbacks = {},
		Active = true,
		SyncPointer = nil,	-- Refernce to the later inserted data to the Sync table
		-- Adds a callback function
        AddCallback = function(self, cb)
            TableInsert(self._callbacks, cb)
        end,
		-- Removes a callback function, either via the same function, or the index of it as param
        RemoveCallback = function(self, cb)
			for Index, Callback in self_.callbacks do
				if (type(cb) == 'function' and Callback == cb) or (type(cb) == 'number' and cb == Index) then
					TableRemove(self._callbacks, Index)
				end
			end
        end,
		-- Destroys the ping group, both from the UI and Sim side
        Destroy = function(self)
            Sync.RemovePingGroups = Sync.RemovePingGroups or {}
            TableInsert(Sync.RemovePingGroups, self._id)
            PingGroups[self._id] = nil
        end,
		-- Sets the state of the ping group, which is also communicated to the UI, but can also be checked in the Sim
		SetActive = function(self, value)
			self.Active = value
			Sync.UpdatePingGroups = Sync.UpdatePingGroups or {}
			
			TableInsert(Sync.UpdatePingGroups, {ID = self._id, Name = self.Name, BlueprintID = self.BlueprintID, description = self.Description, Type = self.Type, Active = value})
		end,
		-- Updates string data types for both the Sim and UI components of the ping group
		UpdateData = function(self, data)
			Sync.UpdatePingGroups = Sync.UpdatePingGroups or {}
			-- Only accept string data
			for Index, Value in data do
				if type(Value) != 'string' then
					error("PING GROUP ERROR: UpdateData doesn't accept non-string type data: " .. tostring(type(Value)), 2)
				end
			end
			
			-- Update button name
			if data.Name then self.Name = data.Name end
			-- Update button icon
			if data.BlueprintID then self.BlueprintID = data.BlueprintID end
			-- Update button type
			if data.Type then self.Type = data.Type end
			-- Update button icon description
			if data.Description then self.Description = data.Description end
			
			-- Because of inconsistent naming, the UI uses lower case key for the "description" data
			TableInsert(Sync.UpdatePingGroups, {ID = self._id, Name = self.Name, BlueprintID = self.BlueprintID, description = self.Description, Type = self.Type, Active = self.Active})
		end,
		
		-- Updates the UI description without overwritting the Sim one
		UpdateUIDescription = function(self, description)
			Sync.UpdatePingGroups = Sync.UpdatePingGroups or {}
			TableInsert(Sync.UpdatePingGroups, {ID = self._id, Name = self.Name, BlueprintID = self.BlueprintID, description = description, Type = self.Type, Active = self.Active})
		end,
    }
	Sync.AddPingGroups = Sync.AddPingGroups or {}
	Sync.UpdatePingGroups = Sync.UpdatePingGroups or {}
    idNum = idNum + 1
	-- Insert it into the Sync table
    table.insert(Sync.AddPingGroups, {ID = PingGroup._id, Name = name, BlueprintID = blueprintID, description = description, Type = type, Active = true})
	
	-- Insert it into the local table
    PingGroups[PingGroup._id] = PingGroup
    return PingGroup
end

--- Creates the Ping Group, inserts it into the Sync table, and return the instance, see the above documentation for more detailed description
---@param name String | UI button name that appears on the tooltip
function OnClickCallback(data)
    -- Check to make sure all of the pings are numbers (happens if the user clicks off the map somewhere)
    for i, v in data.Location do
        if v != v then
            return
        end
    end
   
	-- Check if the ping exists, and is active, because once players are in the command mode, they can stay it in for awhile, and the data passed to it might be outdated
	-- Meaning the active state of the ping group passed to the command mode could be old data
	-- A single player doesn't warrant this thorough logic check (here and twice in the UI as well), but multiple players do
    if PingGroups[data.ID] and PingGroups[data.ID].Active then
        for _, callback in PingGroups[data.ID]._callbacks do
            if callback then callback(data.Location, data.OriginArmy) end
        end
    end
end

--- Basically by the engine, but this call originates from *lua/simInit.lua*, it forks the loading thread
function OnPostLoad()
    ForkThread(OnPostLoadThread)
end

--- The actual thread that loads in the saved data
--- The slight wait is probably there, because the UI tends to commit brain death if campaign UI ping groups are created as the map loads
--- I can only guess the reasons, maybe because the UI is still being set up when the engine calls *OnPopulate()* and *OnStart()* from the map's script?
function OnPostLoadThread()
    WaitSeconds(5)

    Sync.AddPingGroups = Sync.AddPingGroups or {}
    for _, PingGroup in PingGroups do
        table.insert(Sync.AddPingGroups, {ID = PingGroup._id, Name = PingGroup.Name, BlueprintID = PingGroup.BlueprintID, description = PingGroup.Description, Type = PingGroup.Type, Active = PingGroup.Active})
    end
end
