---@param buildName string
---@param strArmy string
---@param builderData table
function LoadOSB(buildName, strArmy, builderData)
    local buildNameNew, location, globalName, childPart
    local saveFile

    if type(buildName) == 'table' then
        saveFile = { Scenario = buildName }

        buildNameNew = 'OSB_' .. saveFile.Scenario.Name
        globalName = saveFile.Scenario.Name
        location = false --string.gsub(builderData.LocationType, '_', '')
        childPart = false
    else
        buildNameNew, location, globalName, childPart = SplitOSBName(buildName)
        local fileName = '/lua/ai/opai/' .. globalName .. '_save.lua'
        saveFile = import(fileName)
    end

    local platoons = saveFile.Scenario.Platoons
    local aiBrain = GetArmyBrain(strArmy)
    if not aiBrain.OSBuilders then
        aiBrain.OSBuilders = {}
    end
    local factionIndex = aiBrain:GetFactionIndex()
    local builders = saveFile.Scenario.Armies['ARMY_1'].PlatoonBuilders.Builders
    local basePriority = builders['OSB_Master_' .. globalName].Priority
    local amMasterName = 'OSB_Master_' .. globalName .. '_' .. strArmy
    if location then
        amMasterName = amMasterName .. '_' .. location
    end
    if not builders then
        error('*OpAI ERROR: No OpAI Global named: ' .. globalName, 2)
    end
    for k, v in builders do
        local spec = {}
        local insert = true

        local pData = RebuildDataTable(v.PlatoonData)
        spec.PlatoonData = {}

        -- Store builder name
        if location then
            spec.BuilderName = k .. '_' .. strArmy .. '_' .. location
            spec.PlatoonData.BuilderName = k .. '_' .. strArmy .. '_' .. location
        else
            spec.BuilderName = k .. '_' .. strArmy
            spec.PlatoonData.BuilderName = k .. '_' .. strArmy
        end

        if ScenarioInfo.OSPlatoonCounter[spec.BuilderName] then
            UpdateOSB(spec.BuilderName, strArmy, builderData)
        else
            if string.sub(k, 1, 11) == 'OSB_Master_' then
                for name, data in builderData.PlatoonData do
                    if name ~= 'PlatoonMultiplier' and name ~= 'TransportCount' and name ~= 'PlatoonSize' then
                        spec.PlatoonData[name] = data
                    end
                end
            end
            if pData.AMPlatoons then
                spec.PlatoonData.AMPlatoons = {}
                for name, pName in pData.AMPlatoons do
                    local appendString = ''
                    if string.sub(name, 1, 6) == 'APPEND' then
                        appendString = string.sub(name, 7)
                    end
                    if location then
                        table.insert(spec.PlatoonData.AMPlatoons, pName .. '_' .. strArmy .. '_' ..
                            location .. appendString)
                    else
                        table.insert(spec.PlatoonData.AMPlatoons, pName .. '_' .. strArmy .. appendString)
                    end
                end
            end


            -- Set priority
            if builderData.Priority < 0 then
                insert = false
                spec.Priority = builderData.Priority
            elseif builderData.Priority ~= 0 then
                spec.Priority = builderData.Priority - (basePriority - v.Priority)
                if spec.Priority <= 0 then
                    spec.Priority = 1
                end
            else
                spec.Priority = v.Priority
            end
            if spec.LocationType ~= 'ALL' then
                spec.LocationType = builderData.LocationType
                spec.PlatoonData.LocationType = builderData.LocationType
            end
            spec.PlatoonType = v.PlatoonType

            -- Set platoon template
            if Scenario.Platoons['OST_' .. string.sub(spec.BuilderName, 5)] then
                spec.PlatoonTemplate = FactionConvert(table.deepcopy(Scenario.Platoons[
                    'OST_' .. string.sub(spec.BuilderName, 5)]), factionIndex)
            elseif Scenario.Platoons[v.PlatoonTemplate] then
                if type(buildName) ~= "table" then
                    spec.PlatoonTemplate = FactionConvert(table.deepcopy(Scenario.Platoons[v.PlatoonTemplate]),
                        factionIndex)
                else
                    spec.PlatoonTemplate = table.deepcopy(Scenario.Platoons[v.PlatoonTemplate])
                end
            else
                if type(buildName) ~= "table" then
                    spec.PlatoonTemplate = FactionConvert(table.deepcopy(platoons[v.PlatoonTemplate]), factionIndex)
                else
                    spec.PlatoonTemplate = table.deepcopy(platoons[v.PlatoonTemplate])
                end


            end
            if builderData.PlatoonData.PlatoonMultiplier then
                local squadNum = 3
                while squadNum <= table.getn(spec.PlatoonTemplate) do
                    spec.PlatoonTemplate[squadNum][2] = spec.PlatoonTemplate[squadNum][2] *
                        builderData.PlatoonData.PlatoonMultiplier
                    spec.PlatoonTemplate[squadNum][3] = spec.PlatoonTemplate[squadNum][3] *
                        builderData.PlatoonData.PlatoonMultiplier
                    squadNum = squadNum + 1
                end
            end
            if builderData.PlatoonData.PlatoonSize then
                local squadNum = 3
                while squadNum <= table.getn(spec.PlatoonTemplate) do
                    spec.PlatoonTemplate[squadNum][2] = 1
                    spec.PlatoonTemplate[squadNum][3] = builderData.PlatoonData.PlatoonSize
                    squadNum = squadNum + 1
                end
            end

            -- Set buildout to
            if (v.BuildTimeOut and v.BuildTimeOut < 0) or (spec.PlatoonTemplate[3] and spec.PlatoonTemplate[3][2] < 0) then
                spec.GenerateTimeOut = true
            end
            spec.BuildTimeOut = v.BuildTimeOut

            -- Add AI Function to OSB global if needed
            if string.sub(k, 1, 11) == 'OSB_Master_' and builderData.PlatoonAIFunction then
                spec.PlatoonAIFunction = builderData.PlatoonAIFunction
            elseif v.PlatoonAIFunction then
                spec.PlatoonAIFunction = v.PlatoonAIFunction
            end

            -- Add Build Conditions
            spec.BuildConditions = {}
            if v.BuildConditions then
                for num, bCond in v.BuildConditions do
                    local addCond = table.deepcopy(bCond)
                    for sNum, pVal in addCond[3] do
                        if pVal == 'OSB_Master_' .. string.sub(buildNameNew, 5) then
                            pVal = amMasterName
                        elseif pVal == 'default_master' then
                            addCond[3][sNum] = amMasterName
                        elseif pVal == 'default_army' then
                            addCond[3][sNum] = strArmy
                        elseif pVal == 'default_location' and location then
                            addCond[3][sNum] = location
                        elseif pVal == 'default_location_type' then
                            addCond[3][sNum] = spec.LocationType
                        elseif pVal == 'default_builder_name' then
                            addCond[3][sNum] = spec.BuilderName
						elseif pVal == 'default_pool' then
							addCond[3][sNum] = spec.LocationType .. '_TransportPool'
                        elseif pVal == 'default_transport_count' then
                            if builderData.PlatoonData.TransportCount then
                                addCond[3][sNum] = builderData.PlatoonData.TransportCount
                            end
                        end
                    end
                    table.insert(spec.BuildConditions, addCond)
                end
            end
            -- Add build/form conditions to ALL builders
            if builderData.BuildConditions then
                for num, bCond in builderData.BuildConditions do
                    if bCond[3][1] == 'Remove' then
                        for bcNum, bcData in spec.BuildConditions do
                            if bcData[2] == bCond[2] then
                                table.remove(spec.BuildConditions, bcNum)
                            end
                        end
                    else
                        local addCond = table.deepcopy(bCond)
                        for sNum, pVal in addCond[3] do
                            if pVal == buildNameNew then
                                pVal = amMasterName
                            elseif pVal == 'default_master' then
                                addCond[3][sNum] = amMasterName
                            elseif pVal == 'default_army' then
                                addCond[3][sNum] = strArmy
                            elseif pVal == 'default_location' and location then
                                addCond[3][sNum] = location
                            elseif pVal == 'default_location_type' then
                                addCond[3][sNum] = spec.LocationType
                            elseif pVal == 'default_builder_name' then
                                addCond[3][sNum] = spec.BuilderName
							elseif pVal == 'default_transport_pool' then
								addCond[3][sNum] = spec.LocationType .. '_TransportPool'
                            elseif pVal == 'default_transport_count' then
                                if builderData.PlatoonData.TransportCount then
                                    addCond[3][sNum] = builderData.PlatoonData.TransportCount
                                end
                            end
                        end
                        table.insert(spec.BuildConditions, addCond)
                    end
                end
            end
            -- Check for faction specific builders
            for num, cond in spec.BuildConditions do
                if cond[2] == 'FactionIndex' then
                    local params = {}
                    for subNum, val in cond[3] do
                        table.insert(params, val)
                    end
                    table.remove(params, 1)
                    insert = import(cond[1])[ cond[2] ](aiBrain, unpack(params))
                end
            end

            -- Add BuildCallbacks
            spec.PlatoonBuildCallbacks = {}
            if v.PlatoonBuildCallbacks then
                for num, pbCallback in v.PlatoonBuildCallbacks do
                    table.insert(spec.PlatoonBuildCallbacks, pbCallback)
                end
            end
            -- Add DestroyCallbacks to Masters
            if builderData.PlatoonBuildCallbacks and string.sub(k, 1, 11) == 'OSB_Master_' then
                FilterFunctions(spec.PlatoonBuildCallbacks, builderData.PlatoonBuildCallbacks)
            end

            -- Add AddFunctions (Har!)
            spec.PlatoonAddFunctions = {}
            if v.PlatoonAddFunctions then
                for fNum, fData in v.PlatoonAddFunctions do
                    table.insert(spec.PlatoonAddFunctions, fData)
                end
            end
            if builderData.PlatoonAddFunctions and string.sub(k, 1, 11) == 'OSB_Master_' then
                FilterFunctions(spec.PlatoonAddFunctions, builderData.PlatoonAddFunctions)
            end


            -- Masters
            if pData.AMMasterPlatoon and insert then
                if string.sub(k, 1, 26) == 'OSB_Master_LeftoverCleanup' then
                    spec.PlatoonName = spec.LocationType .. '_LeftoverUnits'
                else
                    spec.PlatoonName = spec.BuilderName
                end

                -- Add data to Masters
                if builderData.PlatoonData and string.sub(k, 1, 11) == 'OSB_Master_' then
                    if aiBrain.AttackData['AttackManagerState'] ~= 'ACTIVE' then
                        aiBrain:InitializeAttackManager()
                    end
                end

                spec.AttackConditions = spec.BuildConditions
                spec.DestroyCallbacks = spec.PlatoonBuildCallbacks
                spec.FormCallbacks = spec.PlatoonAddFunctions
                spec.AIThread = spec.PlatoonAIFunction

                if pData.AIName then
                    spec.AIName = pData.AIName
                end
                if spec.PlatoonTemplate and not spec.AIName then
                    if spec.PlatoonTemplate[2] ~= '' then
                        spec.AIName = spec.PlatoonTemplate[2]
                    end
                end

                -- Set if needed to draw from pool
                if pData.UsePool ~= nil then
                    spec.UsePool = pData.UsePool
                end
                aiBrain:AMAddPlatoon(spec)

                -- Children
            elseif insert then
                spec.RequiresConstruction = v.RequiresConstruction

                -- Add spec to brain
                spec.InstanceCount = v.InstanceCount
                aiBrain:PBMAddPlatoon(spec)
            end
        end
    end
end