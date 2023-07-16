----------------------------------------------------------------------------*
--	File     :  /lua/ai/OpAI/BaseOpAI.lua
--	Author(s): Dru Staltman
--	Summary  : Base manager for operations
--
--	Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
------------------------------------------------------------------------------

local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")

local UCBC = '/lua/editor/unitcountbuildconditions.lua'
local BMBC = '/lua/editor/basemanagerbuildconditions.lua'
local MIBC = '/lua/editor/miscbuildconditions.lua'
local BMPT = '/lua/ai/opai/basemanagerplatoonthreads.lua'

do

local CampaignOpAI = OpAI

---@class OpAI
OpAI = Class(CampaignOpAI) {

	---@param self OpAI
	---@param funcName string
	---@param bool boolean
	SetFunctionStatus = function(self,funcName,bool)
        ScenarioInfo.OSPlatoonCounter[self.MasterName..'_'..funcName] = bool
    end,
	
	--- TODO: make a system out of this.  Derive functionality per override per OpAI type
	---@param self OpAI
	---@param functionData table
    MasterPlatoonFunctionalityChange = function(self, functionData)
        if functionData[2] == 'LandAssaultWithTransports' then
			LOG('Enabling default transports for OpAI named: ' .. repr(self.MasterName))
            self:SetFunctionStatus('Transports', true)
        end
    end,
}

end