-- hook\lua\ui\controls\worldview.lua
do
    local catchButtonRelease = false
    local oldWorldView = WorldView
    WorldView = ClassUI(oldWorldView) {
        --- Intercept right click for ping mode and cancel it instead.
        --- Called whenever the mouse moves and clicks in the world view. If it returns false then the engine further processes the event for orders
        ---@param self WorldView
        ---@param event { Type: string, Modifiers: EventModifiers }
        ---@return boolean
        HandleEvent = function(self, event)
            local ret = oldWorldView.HandleEvent(self, event)

            if event.Type == 'ButtonPress' and event.Modifiers.Right then
                local CM = import('/lua/ui/game/commandmode.lua')
                local mode = CM.GetCommandMode()[1]
                if mode == 'ping' then
                    CM.EndCommandMode(true) -- has to be true for the ping end behavior to not do the ping
                    catchButtonRelease = true
                    return true
                end

            -- release of right mouse button causes the last given right click order to be re-issued, so we need to catch the release too
            elseif event.Type == "ButtonRelease" and catchButtonRelease then
                catchButtonRelease = false
                return true
            end

            return ret
        end,
    }
end


--- This causes errors
--[[do
    local catchButtonRelease = false
    local oldWorldViewHandleEvent = WorldView.HandleEvent
    WorldView.HandleEvent = function(self, event)
        local ret = oldWorldViewHandleEvent(self, event)

        if event.Type == 'ButtonPress' and event.Modifiers.Right then
			local CM = import('/lua/ui/game/commandmode.lua')
            local mode = CM.GetCommandMode()[1]
            if mode == 'ping' then
                CM.EndCommandMode(true) -- has to be true for the ping end behavior to not do the ping
                catchButtonRelease = true
                return true
            end

        -- release of right mouse button causes the last given right click order to be re-issued, so we need to catch the release too
        elseif event.Type == "ButtonRelease" and catchButtonRelease then
            catchButtonRelease = false
            return true
        end

        return ret
    end
end]]