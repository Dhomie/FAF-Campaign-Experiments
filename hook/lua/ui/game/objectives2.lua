--*****************************************************************************
--* File: lua/modules/ui/game/objectives2.lua
--*
--* Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

-- The objectives table should be an array whose order mirrors the order in which you wish the objectives to display
-- The format of each entry is as follows:
-- {
--    type = 'primary'                                        -- values are 'primary', 'secondary' and 'bonus'
--    complete = 'incomplete'                                 -- status of objective - 'complete' 'incomplete' 'failed'
--    title = 'Short Description'                             -- text shown in the list of objectives
--    description = 'Long Description'                        -- text shown in the extended description box
--    targets = { blipId1, Vector(10,10,10), blipId2, ... }   -- objective is a list of target unit(s) and/or location(s)
-- }

local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")
local GameMain = import("/lua/ui/game/gamemain.lua")
local Group = import("/lua/maui/group.lua").Group
local Button = import("/lua/maui/button.lua").Button
local Checkbox = import("/lua/maui/checkbox.lua").Checkbox
local Bitmap = import("/lua/maui/bitmap.lua").Bitmap
local GameCommon = import("/lua/ui/game/gamecommon.lua")
local Announcement = import("/lua/ui/game/announcement.lua").CreateAnnouncement
local cmdMode = import("/lua/ui/game/commandmode.lua")
local UIPing = import("/lua/ui/game/ping.lua")
local Tooltip = import("/lua/ui/game/tooltip.lua")

local gameSpeed = 0
local lastUnitWarning = 0
local unitWarningUsed = false
local objectives = {}
local objectivesArrows = {}

local needsObjectiveLayoutPostNIS = false
local needsSquadLayoutPostNIS = false
local preCreationQueue = {}
local preCreationWaitThread = false

controls = import("/lua/ui/controls.lua").Get()
controls.objItems = controls.objItems or {}

function CreateUI(inParent)
    controls.parent = inParent
    controls.bg = Group(controls.parent)

    controls.bg.bracketTop = Bitmap(controls.bg)
    controls.bg.bracketBottom = Bitmap(controls.bg)
    controls.bg.bracketStretch = Bitmap(controls.bg)

    controls.objectiveContainer = Group(controls.bg)
    controls.objectiveContainer.LeftBG = Bitmap(controls.objectiveContainer)
    controls.objectiveContainer.RightBG = Bitmap(controls.objectiveContainer)
    controls.objectiveContainer.StretchBG = Bitmap(controls.objectiveContainer)
    controls.objectiveContainer:Hide()

    controls.squadContainer = Group(controls.bg)
    controls.squadContainer.LeftBG = Bitmap(controls.squadContainer)
    controls.squadContainer.RightBG = Bitmap(controls.squadContainer)
    controls.squadContainer.StretchBG = Bitmap(controls.squadContainer)
    controls.squadContainer:Hide()

    controls.infoContainer = Group(controls.bg)
    controls.infoContainer.LeftBG = Bitmap(controls.infoContainer)
    controls.infoContainer.RightBG = Bitmap(controls.infoContainer)
    controls.infoContainer.StretchBG = Bitmap(controls.infoContainer)

    controls.timeIcon = Bitmap(controls.bg)
    controls.time = UIUtil.CreateText(controls.bg, '0', 14, UIUtil.bodyFont)
    controls.time:SetColor('ff00dbff')
    controls.unitIcon = Bitmap(controls.bg)
    controls.units = UIUtil.CreateText(controls.bg, '0', 14, UIUtil.bodyFont)
    controls.units:SetColor('ffff9900')

    controls.bg:DisableHitTest(true)

    controls.collapseArrow = Checkbox(controls.parent)
    controls.collapseArrow.OnCheck = function(self, checked)
        ToggleObjectives(not checked)
    end
    Tooltip.AddCheckboxTooltip(controls.collapseArrow, 'objectives_collapse')

    SetLayout()

    function EndBehavior(mode, data)
		-- We check if the ping group is active here as well, just to be sure
		-- Unfortunately the param data can be outdated with more than 1 players
		--	There's a 3rd check in *lua/SimPingGroup.lua*, that checks the active state when the callbacks are meant to be executed
        if mode == 'ping' and data.groupID and not data.isCancel and data.Active then
            UIPing.DoPing(data.pingtype)
            local position = GetMouseWorldPos()
			-- Check to make sure all of the pings are numbers (happens if the user clicks off the map somewhere)
            for _, v in position do
                local var = v
                if var ~= v then
                    return
                end
            end
            local data = {ID = data.groupID, Location = position, OriginArmy = data.OriginArmy}
            SimCallback({Func = 'PingGroupClick', Args = data})
		end
    end
    cmdMode.AddEndBehavior(EndBehavior)

    GameMain.AddBeatFunction(_OnBeat)
    controls.bg.OnDestroy = function(self)
        GameMain.RemoveBeatFunction(_OnBeat)
    end

end

function GetCurrentObjectiveTable()
    return objectives
end

function SetLayout()
    if controls.bg then
        import(UIUtil.GetLayoutFilename('objectives2')).SetLayout()
        LayoutObjectiveItems()
        LayoutSquads()
    end
end

function _OnBeat()
    controls.time:SetText(string.format("%s (%+d / %+d)", GetGameTime(), gameSpeed, GetSimRate()))
    local scoreData = import("/lua/ui/game/score.lua").currentScores
    local armyId = GetFocusArmy()
    if scoreData[armyId].general then
        SetUnitText(scoreData[armyId].general.currentunits, scoreData[armyId].general.currentcap)
    end
end

function NoteGameSpeedChanged(newSpeed)
    gameSpeed = newSpeed
end

function SetUnitText(current, cap)
    if not (current and cap) then return end
    controls.units:SetText(string.format("%d/%d", current, cap))
    if current == cap then
        if (not lastUnitWarning or GameTime() - lastUnitWarning > 60) and not unitWarningUsed then
            LOG('>>>>>>>>>>> current: ', current, ' cap: ', cap)
            import("/lua/ui/game/announcement.lua").CreateAnnouncement(LOC('<LOC score_0002>Unit Cap Reached'), controls.units)
            lastUnitWarning = GameTime()
            unitWarningUsed = true
        end
    else
        unitWarningUsed = false
    end
end

function WaitThread()
    while not controls.bg do
        WaitTicks(1)
    end
    for _, item in preCreationQueue do
        if item.action == 'add' then
            AddObjectives(item.data, true)
        elseif item.action == 'addping' then
            AddPingGroups(item.data, true)
		elseif item.action == 'update' then
            UpdateObjectivesTable(item.data, true)
		elseif item.action == 'removeping' then
            RemovePingGroups(item.data, true)
		elseif item.action == 'updateping' then
			UpdatePingGroups(item.data, true)
        end
    end
    UpdateObjectiveItems(true)
    LayoutSquads(true)
end

function AddObjectives(objTable, onLoad)
    if not controls.bg then
        table.insert(preCreationQueue, 1, {action = 'add', data = objTable})
        preCreationWaitThread = preCreationWaitThread or ForkThread(WaitThread)
        return
    end
    for tag, objectiveData in objTable do
        --LOG('Adding objective: ', repr(objectiveData))
        objectives[tag] = objectives[tag] or objectiveData
    end
    if not onLoad then
        UpdateObjectiveItems()
    end
end

function UpdateObjectivesTable(updateTable, onLoad)
    if not controls.bg then
        table.insert(preCreationQueue, 1, {action = 'update', data = updateTable})
        preCreationWaitThread = preCreationWaitThread or ForkThread(WaitThread)
        return
    end
    local needsLayoutUpdate = false
    for _, update in updateTable do
        if objectives[update.tag] and objectives[update.tag][update.updateField] then
            if update.updateField == 'complete' and not onLoad then
                objectives[update.tag].EndTime = GetGameTimeSeconds()
                needsLayoutUpdate = true
            end
            objectives[update.tag][update.updateField] = update.updateData
        elseif update.updateField == 'target' and update.updateField ~= 'timer' then
            if controls.objItems[update.tag] then
                if update.updateData.TargetTag == 1 then
                    if not controls.objItems[update.tag].ImageLocked and update.updateData.BlueprintId and DiskGetFileInfo('/textures/ui/common/icons/units/'..update.updateData.BlueprintId..'_icon.dds') then
                        if not onLoad then
                            controls.objItems[update.tag].icon:SetTexture('/textures/ui/common/icons/units/'..update.updateData.BlueprintId..'_icon.dds')
                            objectives[update.tag].actionImage = '/textures/ui/common/icons/units/'..update.updateData.BlueprintId..'_icon.dds'
                            controls.objItems[update.tag].ImageLocked = true
                        end
                    end
                end
                if update.updateData.Type == 'Position' then
                    if not controls.objItems[update.tag].data.unitPositions then
                        controls.objItems[update.tag].data.unitPositions = {}
                    end
                    controls.objItems[update.tag].data.unitPositions[update.updateData.TargetTag] = update.updateData.Value
                end
            end
        elseif controls.objItems[update.tag] and update.updateField == 'timer' then
            if not onLoad then
                controls.objItems[update.tag].data.targets.Time = update.updateData.Time
            end
        end
    end
    if not onLoad then
        UpdateObjectiveItems()
    end
end

function UpdateObjectiveItems(skipAnnounce)
    local function CreateObjectiveItem(data)
        local group = Group(controls.bg)
        group.bg = Bitmap(group, UIUtil.SkinnableFile('/game/objective-icons/panel-icon_bmp.dds'))
        group.bg:DisableHitTest()
        LayoutHelpers.AtCenterIn(group.bg, group)

        if data.type == 'primary' then
            group.bgRing = Bitmap(group.bg, UIUtil.UIFile('/game/objective-icons/primary-ring_bmp.dds'))
            group.primary = true
        elseif data.type == 'secondary' then
            group.bgRing = Bitmap(group.bg, UIUtil.UIFile('/game/objective-icons/secondary-ring_bmp.dds'))
            group.secondary = true
        elseif data.type == 'bonus' then
            group.bgRing = Bitmap(group.bg, UIUtil.UIFile('/game/objective-icons/bonus-ring_bmp.dds'))
            group.bonus = true
        end
        if group.bgRing then
            LayoutHelpers.AtCenterIn(group.bgRing, group.bg, -6)
            group.bgRing:DisableHitTest()
        end
        if data.targetImage then
            group.icon = Bitmap(group.bg, data.targetImage)
            group.ImageLocked = true
        elseif data.targets.Type == 'Timer' then
            group.ImageLocked = true
            group.icon = Bitmap(group.bg, UIUtil.UIFile('/game/unit-over/icon-clock_large_bmp.dds'))
            local time = string.format("%02d:%02d", math.floor(data.targets.Time/60), math.floor(math.mod(data.targets.Time, 60)))
            group.timer = UIUtil.CreateText(group, time, 10, UIUtil.bodyFont)
            LayoutHelpers.AtBottomIn(group.timer, group, 3)
            LayoutHelpers.AtHorizontalCenterIn(group.timer, group)
            group.startTime = data.targets.Time
        elseif not table.empty(data.targets) then
            local texture = false
            for _, v in data.targets do
                if v.BlueprintId and DiskGetFileInfo(UIUtil.UIFile('/icons/units/'..v.BlueprintId..'_icon.dds')) then
                    texture = UIUtil.UIFile('/icons/units/'..v.BlueprintId..'_icon.dds')
                elseif v.Type == 'Area' then
                    group.ImageLocked = true
                    if data.actionImage and DiskGetFileInfo('/textures/ui/common'..data.actionImage) then
                        texture = '/textures/ui/common'..data.actionImage
                    else
                        texture = UIUtil.UIFile('/game/target-area/target-area_bmp.dds')
                    end
                end
                if texture then
                    group.icon = Bitmap(group.bg, texture)
                    break
                end
            end
        elseif data.actionImage and DiskGetFileInfo('/textures/ui/common'..data.actionImage) then
            group.icon = Bitmap(group.bg, '/textures/ui/common'..data.actionImage)
        else
            group.icon = Bitmap(group.bg, UIUtil.UIFile('/dialogs/objective-unit/help-lg-graphics_bmp.dds'))
        end
        LayoutHelpers.AtCenterIn(group.icon, group.bg, -6, -1)
        LayoutHelpers.SetDimensions(group.icon, 40, 40)
        group.icon:DisableHitTest()

        group.icon.flash = Bitmap(group.icon, UIUtil.UIFile('/game/units_bmp/glow.dds'))
        group.icon.flash:SetAlpha(0)
        LayoutHelpers.AtCenterIn(group.icon.flash, group.icon)
        group.icon.flash:DisableHitTest()
        group.icon.flash.cycles = 0
        group.icon.flash.dir = 1
        group.icon.flash.OnFrame = function(self, delta)
            newAlpha = self:GetAlpha() + (delta * 2 * self.dir)
            if newAlpha > .5 then
                newAlpha = .5
                self.dir = -1
            end
            if newAlpha < 0 then
                newAlpha = 0
                self.dir = 1
                self.cycles = self.cycles + 1
                if self.cycles > 5 then
                    self:SetNeedsFrameUpdate(false)
                end
            end
            self:SetAlpha(newAlpha)
        end

        group.Height:Set(group.bg.Height)
        group.Width:Set(group.bg.Width)
        group.data = data
        group.HandleEvent = function(self, event)
            if event.Type == 'MouseEnter' then
                CreateTooltip(self, self.data, controls.objectiveContainer)
                PlaySound(Sound({Bank = 'Interface', Cue = 'UI_Diplomacy_Open'}))
            elseif event.Type == 'MouseExit' then
                DestroyTooltip()
            elseif event.Type == 'ButtonPress' then
                PlaySound(Sound({Bank = 'Interface', Cue = 'UI_IG_Camera_Move'}))
                local targets = self.data.targets
                local positions = self.data.unitPositions
                if targets and not table.empty(targets) then
                    local max = table.getn(targets)
                    local desiredTarget = math.mod(self.TargetFocus or 0, table.getn(targets)) + 1

                    for idx,target in targets do
                        if idx == desiredTarget then
                            if target.Type == 'Position' then
                                local rect = Rect(target.Value[1] - 20,
                                                  target.Value[3] - 20,
                                                  target.Value[1] + 20,
                                                  target.Value[3] + 20)
                                GetCamera("WorldCamera"):MoveToRegion(rect, 1.0)
                            elseif target.Type == 'Area' then
                                GetCamera("WorldCamera"):MoveToRegion(target.Value, 1.0)
                            end
                            self.TargetFocus = idx
                        end
                    end
                elseif positions and not table.empty(positions) then
                    local max = table.getsize(positions)
                    local desiredTarget = math.mod(self.TargetFocus or 0, table.getsize(positions)) + 1

                    for idx,target in positions do
                        if idx >= desiredTarget then
                            local rect = Rect(target[1] - 20,
                                              target[3] - 20,
                                              target[1] + 20,
                                              target[3] + 20)
                            GetCamera("WorldCamera"):MoveToRegion(rect, 1.0)
                            self.TargetFocus = idx
                        end
                    end
                end
            end
        end

        group.Update = function(self, newData)
            self.data = newData
            if self.timer then
                if math.floor(self.data.targets.Time) > 0 then
                    local time = string.format("%02d:%02d", math.floor(self.data.targets.Time/60), math.floor(math.mod(self.data.targets.Time, 60)))
                    self.timer:SetText(time)
                    if controls.tooltip and controls.tooltip.ID == self.data.tag then
                        controls.tooltip:Update(self, self.data)
                    end
                else
                    self.timer:SetText('')
                end
            end
        end

        group.Flash = function(self, flash)
            self.icon.flash:SetNeedsFrameUpdate(flash)
            self.icon.flash:SetAlpha(0)
            self.icon.time = 0
        end

        return group
    end
    for tag, objData in objectives do
        if objData.hidden then
            if objData.complete == 'complete' then
                if not skipAnnounce and not objData.announced then
                    objData.announced = true
                    Announcement(LOC('<LOC objectives_0000>Objective Completed'), controls.bg, LOC(objData.title))
                end
            end
        else
            if objData.complete == 'complete' or objData.complete == 'failed' then
                if controls.objItems[tag] and not skipAnnounce and not objData.announced then
                    local objTag = tag
                    objData.announced = true
                    local announceStr = '<LOC objectives_0000>Objective Completed'
                    if objData.complete == 'failed' then
                        announceStr = '<LOC objectives_0001>Objective Failed'
                    end
                    Announcement(LOC(announceStr), controls.objItems[objTag], LOC(controls.objItems[objTag].data.title),
                        function()
                            if controls.objItems[objTag] then
                                controls.objItems[objTag]:Destroy()
                                controls.objItems[objTag] = false
                                if controls.tooltip and controls.tooltip.ID == objTag then
                                    DestroyTooltip()
                                end
                                LayoutObjectiveItems()
                            end
                        end)
                else
                    if controls.objItems[tag] then
                        controls.objItems[tag]:Destroy()
                        controls.objItems[tag] = false
                    end
                end
                continue
            end
            if not controls.objItems[tag] then
                controls.objItems[tag] = CreateObjectiveItem(objData)
                if not skipAnnounce then
                    Announcement(LOC('<LOC objectives_0002>Objective Added'), controls.objItems[tag])
                    controls.objItems[tag]:Flash(true)
                end
            else
                controls.objItems[tag]:Update(objData)
            end
        end
    end
    LayoutObjectiveItems()
end

function LayoutObjectiveItems()
    if import("/lua/ui/game/gamemain.lua").IsNISMode() then
        needsObjectiveLayoutPostNIS = true
        return
    end
    local sortedControls = {}
    for _, item in controls.objItems do
        if item.bonus then
            table.insert(sortedControls, item)
        end
    end
    for _, item in controls.objItems do
        if item.secondary then
            table.insert(sortedControls, item)
        end
    end
    for _, item in controls.objItems do
        if item.primary then
            table.insert(sortedControls, item)
        end
    end
    if not table.empty(sortedControls) then
        local prevControl = false
        local objectiveWidth = 0
        for _, item in sortedControls do
            if prevControl then
                LayoutHelpers.LeftOf(item, prevControl)
            else
                LayoutHelpers.AtRightTopIn(item, controls.objectiveContainer, 10, 2)
            end
            objectiveWidth = objectiveWidth + item.Width()
            prevControl = item
        end
        controls.objectiveContainer.Width:Set(objectiveWidth + LayoutHelpers.ScaleNumber(20))
        controls.objectiveContainer:Show()
    else
        controls.objectiveContainer:Hide()
    end
    AdjustGroupSize()
end

function CreateTooltip(parentControl, objData, container)
    if controls.tooltip then
        if not controls.tooltip:IsHidden() then
            return
        end
        controls.tooltip:Show()
    else
        controls.tooltip = Bitmap(GetFrame(0), UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_m.dds'))
        controls.tooltip.Depth:Set(GetFrame(0):GetTopmostDepth()+1)

        controls.tooltip.text = {}

        controls.tooltip.text.title = UIUtil.CreateText(controls.tooltip, '', 16, UIUtil.bodyFont)
        LayoutHelpers.AtLeftTopIn(controls.tooltip.text.title, controls.tooltip)

        controls.tooltip.text.progress = UIUtil.CreateText(controls.tooltip, '', 12, UIUtil.bodyFont)
        LayoutHelpers.Below(controls.tooltip.text.progress, controls.tooltip.text.title)

        controls.tooltip.text.desc = {}
        controls.tooltip.text.desc[1] = UIUtil.CreateText(controls.tooltip, '', 12, UIUtil.bodyFont)

        controls.tooltip.bgTL = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ul.dds'))
        controls.tooltip.bgTL.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgTL.Bottom:Set(controls.tooltip.Top)
        controls.tooltip.bgTL.Right:Set(controls.tooltip.Left)

        controls.tooltip.bgTR = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ur.dds'))
        controls.tooltip.bgTR.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgTR.Bottom:Set(controls.tooltip.Top)
        controls.tooltip.bgTR.Left:Set(controls.tooltip.Right)

        controls.tooltip.bgLL = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ll.dds'))
        controls.tooltip.bgLL.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgLL.Top:Set(controls.tooltip.Bottom)
        controls.tooltip.bgLL.Right:Set(controls.tooltip.Left)

        controls.tooltip.bgLR = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_lr.dds'))
        controls.tooltip.bgLR.Top:Set(controls.tooltip.Bottom)
        controls.tooltip.bgLR.Left:Set(controls.tooltip.Right)

        controls.tooltip.bgT = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_horz_um.dds'))
        controls.tooltip.bgT.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgT.Bottom:Set(controls.tooltip.Top)
        controls.tooltip.bgT.Right:Set(controls.tooltip.Right)
        controls.tooltip.bgT.Left:Set(controls.tooltip.Left)

        controls.tooltip.bgB = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_lm.dds'))
        controls.tooltip.bgB.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgB.Top:Set(controls.tooltip.Bottom)
        controls.tooltip.bgB.Right:Set(controls.tooltip.Right)
        controls.tooltip.bgB.Left:Set(controls.tooltip.Left)

        controls.tooltip.bgL = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_vert_l.dds'))
        controls.tooltip.bgL.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgL.Top:Set(controls.tooltip.Top)
        controls.tooltip.bgL.Bottom:Set(controls.tooltip.Bottom)
        controls.tooltip.bgL.Right:Set(controls.tooltip.Left)

        controls.tooltip.bgR = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_vert_r.dds'))
        controls.tooltip.bgR.Depth:Set(controls.tooltip.Depth)
        controls.tooltip.bgR.Top:Set(controls.tooltip.Top)
        controls.tooltip.bgR.Bottom:Set(controls.tooltip.Bottom)
        controls.tooltip.bgR.Left:Set(controls.tooltip.Right)

        controls.tooltip.connector = Bitmap(controls.tooltip, UIUtil.SkinnableFile('/game/filter-ping-list-panel/energy-bar_bmp.dds'))
        controls.tooltip.connector.Depth:Set(controls.tooltip.Depth)
    end

    controls.tooltip.ID = objData.tag

    controls.tooltip.Update = function(self, parentControl, objData)
        if parentControl.primary then
            controls.tooltip.text.title:SetColor('ffff0000')
        elseif parentControl.secondary then
            controls.tooltip.text.title:SetColor('fffff700')
        elseif parentControl.bonus then
            controls.tooltip.text.title:SetColor('ffba00ff')
        else
            controls.tooltip.text.title:SetColor('ff00f7ff')
        end

        controls.tooltip.text.title:SetText(LOC(objData.title) or LOC(objData.Name))
        local progressStr = ''
        if objData.progress and objData.progress ~= '' then
            progressStr = LOC(objData.progress)
        elseif objData.targets.Type == 'Timer' and objData.targets.Time > 0 then
            progressStr = string.format("%02d:%02d", math.floor(objData.targets.Time/60), math.floor(math.mod(objData.targets.Time, 60)))
        end
        controls.tooltip.text.progress:SetText(progressStr)
        controls.tooltip.Width:Set(function() return math.max(LayoutHelpers.ScaleNumber(180), controls.tooltip.text.title.Width()) end)

        local curLine = 1
        local wrapped = import("/lua/maui/text.lua").WrapText(LOC(objData.description) or '', controls.tooltip.Width(),
            function(curText) return controls.tooltip.text.desc[1]:GetStringAdvance(curText) end)
        for index, line in wrapped do
            local i = index
            if not controls.tooltip.text.desc[i] then
                controls.tooltip.text.desc[i] = UIUtil.CreateText(controls.tooltip, line, 12, UIUtil.bodyFont)
                LayoutHelpers.Below(controls.tooltip.text.desc[i], controls.tooltip.text.desc[i-1])
            else
                controls.tooltip.text.desc[i]:SetText(line)
            end
            curLine = curLine + 1
        end
        while controls.tooltip.text.desc[curLine] do
            controls.tooltip.text.desc[curLine]:SetText('')
            curLine = curLine + 1
        end
        if controls.tooltip.text.progress:GetText() == '' then
            LayoutHelpers.Below(controls.tooltip.text.desc[1], controls.tooltip.text.title)
        else
            LayoutHelpers.Below(controls.tooltip.text.desc[1], controls.tooltip.text.progress)
        end
        controls.tooltip.Height:Set(function()
            local totHeight = 0
            for id, control in controls.tooltip.text do
                if id == 'desc' then
                    for _, line in control do
                        if line:GetText() ~= '' then
                            totHeight = totHeight + line.Height()
                        end
                    end
                elseif control:GetText() ~= '' then
                    totHeight = control.Height() + totHeight
                end
            end
            return totHeight
        end)
    end

    controls.tooltip:Update(parentControl, objData)

    controls.tooltip:DisableHitTest(true)
    LayoutHelpers.AtVerticalCenterIn(controls.tooltip.connector, container)
    LayoutHelpers.AnchorToLeft(controls.tooltip.connector, container, -7)
    LayoutHelpers.LeftOf(controls.tooltip, container, 32)
    LayoutHelpers.AtTopIn(controls.tooltip, container, 16)
end

function DestroyTooltip()
    if controls.tooltip then
        controls.tooltip:Hide()
    end
end

--- TODO: Refactor this to use *UpdatePingGroups()* to set the rest of the data
function AddPingGroups(groupData, onload)
    if not controls.bg then
        table.insert(preCreationQueue, 1, {action = 'addping', data = groupData})
        preCreationWaitThread = preCreationWaitThread or ForkThread(WaitThread)
        return
    end
    
	controls.squads = controls.squads or {}
    for groupIndex, pingGroup in groupData do
        local icon = UIUtil.UIFile('/game/orders/guard_btn_up.dds')
        if pingGroup.BlueprintID then
            icon = GameCommon.GetCachedUnitIconFileNames(__blueprints[pingGroup.BlueprintID])
        elseif pingGroup.Type == 'attack' then
            icon = UIUtil.UIFile('/game/orders/attack_btn_up.dds')
        elseif pingGroup.Type == 'move' then
            icon = UIUtil.UIFile('/game/orders/move_btn_up.dds')
        end
        pingGroup.tag = pingGroup.ID
        local id = pingGroup.ID
        controls.squads[id] = Bitmap(controls.bg, UIUtil.UIFile('/game/ping-icons/panel-icon_bmp.dds'))
        controls.squads[id].btn = Button(controls.squads[id], icon, icon, icon, icon)
        LayoutHelpers.AtCenterIn(controls.squads[id].btn, controls.squads[id])
        controls.squads[id].btn.Width:Set(function() return controls.squads[id].Width() - LayoutHelpers.ScaleNumber(16) end)
        controls.squads[id].btn.Height:Set(function() return controls.squads[id].Height() - LayoutHelpers.ScaleNumber(16) end)
        controls.squads[id].btn.Data = pingGroup
        controls.squads[id].btn.OnClick = function(self, modifiers)
			-- Localize the data table because we use it several times
			local Data = self.Data
			-- Only allow selection via LMB, and if the ping group is active to begin with
			if not modifiers.Left or not Data.Active then
				return
			end
			
			PlaySound(Sound({Bank = 'Interface', Cue = 'UI_IG_Camera_Move'}))
			local cursor = "RULEUCC_Guard"
			if Data.Type == 'attack' then
				cursor = "RULEUCC_Attack"
			elseif Data.Type == 'move' then
				cursor = "RULEUCC_Move"
			end
			local modeData = {
				name = "RULEUCC_Script",
				Cursor = cursor,
				pingtype = Data.Type,
				groupID = Data.ID,
                Active = Data.Active,	-- Set via the Sim, if you want the UI to change it, you'll need a Sim callback, as only the bool value is communicated to the UI
                OriginArmy = GetFocusArmy()	-- Get the army who sent the ping, because FAF coop supports up to 4 players, unlike in SCFA's single-player campaign
			}
			cmdMode.StartCommandMode("ping", modeData)
        end
		
		-- Internal update function to call, but probably unnecessary
		--[[controls.squads[id].btn.Update = function(self)
			local Tooltip = controls.tooltip
            if Tooltip and Tooltip.ID == self.Data.ID and not Tooltip:IsHidden() then
                Tooltip:Update(self, self.Data)
            end
        end]]
		
		-- Set to update the button periodically
		controls.squads[id].btn.OnFrame = function(self, delta)
			local Tooltip = controls.tooltip
            if Tooltip and Tooltip.ID == self.Data.ID and not Tooltip:IsHidden() then
                Tooltip:Update(self, self.Data)
            end
		end
		
		-- Handle intended functionality for controls
        controls.squads[id].btn.HandleEvent = function(self, event)
			--- Standard cursor event types: 'MouseEnter', 'MouseExit', 'MouseMotion'
            if event.Type == 'MouseEnter' then
                PlaySound(Sound({Bank = 'Interface', Cue = 'UI_Diplomacy_Open'}))
                CreateTooltip(self, self.Data, controls.squadContainer)
				-- Set the button to update
				controls.squads[id].btn:SetNeedsFrameUpdate(true)
            elseif event.Type == 'MouseExit' then
				-- Set the button to no longer update
				controls.squads[id].btn:SetNeedsFrameUpdate(false)
                DestroyTooltip()
            end
            return Button.HandleEvent(self, event)
        end
    end
    if not onload then
        LayoutSquads()
    end
end

function UpdatePingGroups(groupData, onload)
	if not controls.bg then
        table.insert(preCreationQueue, 1, {action = 'updateping', data = groupData})
        preCreationWaitThread = preCreationWaitThread or ForkThread(WaitThread)
        return
    end

	controls.squads = controls.squads or {}
	for groupIndex, pingGroup in groupData do
        local icon = UIUtil.UIFile('/game/orders/guard_btn_up.dds')
        if pingGroup.BlueprintID then
            icon = GameCommon.GetCachedUnitIconFileNames(__blueprints[pingGroup.BlueprintID])
        elseif pingGroup.Type == 'attack' then
            icon = UIUtil.UIFile('/game/orders/attack_btn_up.dds')
        elseif pingGroup.Type == 'move' then
            icon = UIUtil.UIFile('/game/orders/move_btn_up.dds')
        end
        pingGroup.tag = pingGroup.ID
        local id = pingGroup.ID
        controls.squads[id].btn:SetNewTextures(icon, icon, icon)
        controls.squads[id].btn.Data = pingGroup
    end
    if not onload then
        LayoutSquads()
    end
end

function RemovePingGroups(removeData, onload)
    if not controls.bg then
        table.insert(preCreationQueue, 1, {action = 'removeping', data = removeData})
        preCreationWaitThread = preCreationWaitThread or ForkThread(WaitThread)
        return
    end
    for _, groupID in removeData do
        if controls.squads[groupID] then
            if controls.tooltip and controls.tooltip.ID == groupID then
                DestroyTooltip()
            end
            controls.squads[groupID]:Destroy()
            controls.squads[groupID] = nil
        end
    end
    if not onload then
        LayoutSquads()
    end
end

function LayoutSquads()
    if import("/lua/ui/game/gamemain.lua").IsNISMode() then
        needsSquadLayoutPostNIS = true
        return
    end
    if not controls.squads then return end
    local prevControl = false
    local squadWidth = 10
    if not table.empty(controls.squads) then
        for _, item in controls.squads do
            if prevControl then
                LayoutHelpers.RightOf(item, prevControl)
            else
                LayoutHelpers.AtLeftTopIn(item, controls.squadContainer, 5)
            end
            prevControl = item
            squadWidth = squadWidth + item.Width()
        end
        controls.squadContainer.Width:Set(squadWidth)
        controls.squadContainer:Show()
    else
        controls.squadContainer:Hide()
    end
    AdjustGroupSize()
end

function AdjustGroupSize()
    controls.bg.Height:Set(function()
        local height = 0
        if not controls.infoContainer:IsHidden() then
            height = height + controls.infoContainer.Height()
        end
        if not controls.objectiveContainer:IsHidden() then
            height = height + controls.objectiveContainer.Height()
        end
        if not controls.squadContainer:IsHidden() then
            height = height + controls.squadContainer.Height()
            if controls.objectiveContainer:IsHidden() then
                controls.squadContainer.Top:Set(function() return controls.infoContainer.Bottom() end)
            else
                controls.squadContainer.Top:Set(function() return controls.objectiveContainer.Bottom() end)
            end
        end
        return height + 20
    end)
end

function ToggleObjectives(state)
    -- disable when in Screen Capture mode
    if import("/lua/ui/game/gamemain.lua").gameUIHidden then
        return
    end

    if UIUtil.GetAnimationPrefs() then
        if state or controls.bg:IsHidden() then
            PlaySound(Sound({Cue = "UI_Score_Window_Open", Bank = "Interface"}))
            controls.collapseArrow:SetCheck(false, true)
            controls.bg:Show()
            if controls.objItems and not table.empty(controls.objItems) then
                controls.objectiveContainer:Show()
            else
                controls.objectiveContainer:Hide()
            end
            if controls.squads and not table.empty(controls.squads) then
                controls.squadContainer:Show()
            else
                controls.squadContainer:Hide()
            end
            controls.bg:SetNeedsFrameUpdate(true)
            controls.bg.OnFrame = function(self, delta)
                local newRight = self.Right() - (1000*delta)
                if newRight < controls.parent.Right() - 3 then
                    newRight = controls.parent.Right() - 3
                    self:SetNeedsFrameUpdate(false)
                end
                self.Right:Set(newRight)
            end
        else
            PlaySound(Sound({Cue = "UI_Score_Window_Close", Bank = "Interface"}))
            controls.bg:SetNeedsFrameUpdate(true)
            controls.bg.OnFrame = function(self, delta)
                local newRight = self.Right() + (1000*delta)
                if newRight > controls.parent.Right() + self.Width() then
                    newRight = controls.parent.Right() + self.Width()
                    self:Hide()
                    self:SetNeedsFrameUpdate(false)
                end
                self.Right:Set(newRight)
            end
            controls.collapseArrow:SetCheck(true, true)
        end
    else
        if state or controls.bg:IsHidden() then
            controls.collapseArrow:SetCheck(false, true)
            controls.bg:Show()
            if controls.objItems and not table.empty(controls.objItems) then
                controls.objectiveContainer:Show()
            else
                controls.objectiveContainer:Hide()
            end
            if controls.squads and not table.empty(controls.squads) then
                controls.squadContainer:Show()
            else
                controls.squadContainer:Hide()
            end
        else
            controls.bg:Hide()
            controls.collapseArrow:SetCheck(true, true)
        end
    end
end

local preContractState = false
function Contract()
    if not controls.bg then
        return
    end
    if controls.tooltip then
        DestroyTooltip()
    end
    preContractState = controls.bg:IsHidden()
    controls.bg:Hide()
    controls.collapseArrow:Hide()
end

function Expand()
    if not controls.bg then
        return
    end
    controls.bg:SetHidden(preContractState)
    if not preContractState then
        if controls.objItems and not table.empty(controls.objItems) then
            controls.objectiveContainer:Show()
        else
            controls.objectiveContainer:Hide()
        end
        if controls.squads and not table.empty(controls.squads) then
            controls.squadContainer:Show()
        else
            controls.squadContainer:Hide()
        end
    end
    LayoutObjectiveItems()
    LayoutSquads()
    controls.collapseArrow:Show()
end