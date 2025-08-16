-------------------------------------------------------------
--- Temporary fix for the UI until the FAF hotfix is released
--- Date: 2025.08.16
-------------------------------------------------------------

--- This might cause errors
do
	--- NOTE: Overwrites the original to fix an issue with the latest FAF patch, this will be deprecated once the next FAF hotfix is released
	--- Defines the animation of the announcement, and specifically of the background. Returns the a lazy variable that we can use to progress the animation.
    ---@param self UIAbstractAnnouncement
    ---@param control Control
    ---@return LazyVar
    AbstractAnnouncement.SetupBackgroundAnimation = function(self, control)
        -- local scope for performance
        local background = self.Background
        local content = self.ContentArea

        ---@type LazyVar
        local animationProgress = CreateLazyVar(0)
		
		-- TODO: Remove this once the FAF hotfix is released
        -- use last known position of control if it is destroyed, this happens when you fail an objective. 
        -- we can't initialize it with the position of the control as it may not be layout correctly yet.
        local controlTopValue = 0
        local controlBottomValue = 0
        local controlLeftValue = 0
        local controlRightValue = 0

        background.Top:Set(
            function()
                -- determine or use last known position of control
                controlTopValue = control.Top and control.Top() or controlTopValue

                local percentage = animationProgress()
                return percentage * content.Top() + (1 - percentage) * controlTopValue
            end
        )

        background.Bottom:Set(
            function()
                -- determine or use last known position of control
                controlBottomValue = control.Bottom and control.Bottom() or controlBottomValue

                local percentage = animationProgress()
                return percentage * content.Bottom() + (1 - percentage) * controlBottomValue
            end
        )

        background.Left:Set(
            function()
                -- determine or use last known position of control
                controlLeftValue = control.Left and control.Left() or controlLeftValue

                local percentage = animationProgress()
                return percentage * content.Left() + (1 - percentage) * controlLeftValue
            end
        )

        background.Right:Set(
            function()
                -- determine or use last known position of control
                controlRightValue = control.Right and control.Right() or controlRightValue

                local percentage = animationProgress()
                return percentage * content.Right() + (1 - percentage) * controlRightValue
            end
        )

        -- define width and height by top/bottom and left/right values
        Layouter(background)
            :ResetWidth()
            :ResetHeight()
            :End()

        return animationProgress
    end
end