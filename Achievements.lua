-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Achievements.lua
-- Version: 06
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

function AQT:RenderAchievements(startY, lineIdx, style)
    local ASSETS = ns.ASSETS
    -- 1. Apply Granular Style (or fallback)
    local s = style or { headerSize = 12, textSize = 10, barHeight = 4, lineSpacing = 6 }
    local font = ASSETS.font
    local padding = ASSETS.padding
    local yOffset = startY
    
    -- 2. Get Tracked Achievements
    -- Ensure function exists (Classic vs Retail compat)
    if not GetTrackedAchievements then return yOffset, lineIdx end
    
    local tracked = { GetTrackedAchievements() }
    if #tracked == 0 then return yOffset, lineIdx end

    -- 3. Calculate Dimensions
    local hHead = s.headerSize + (s.lineSpacing or 6)
    local hText = s.textSize + (s.lineSpacing or 6)
    local width = self.db.profile.width or 260

    -- 4. Main Section Header
    local header = self:GetLine(lineIdx)
    -- [FIX] Use self.Content as parent anchor, not self
    header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
    
    header.text:SetFont(font, s.headerSize, "OUTLINE")
    local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
    header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
    
    self.SafelySetText(header.text, "ACHIEVEMENTS")
    header:Show()
    
    yOffset = yOffset - (hHead + 4)
    lineIdx = lineIdx + 1

    -- 5. Render Each Achievement
    for _, achID in ipairs(tracked) do
        local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(achID)
        
        if id and not completed then
            -- Achievement Title
            local line = self:GetLine(lineIdx)
            line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
            
            line.text:SetFont(font, s.textSize + 1, "OUTLINE") -- Slightly larger than objective text
            local cAch = ASSETS.colors.zone or {r=1, g=0.8, b=0} -- Gold color for achievement title
            line.text:SetTextColor(cAch.r, cAch.g, cAch.b)
            
            self.SafelySetText(line.text, name)
            line:Show()
            
            -- Interaction (Click Logic)
            line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            line:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    -- Stop Tracking
                    if RemoveTrackedAchievement then 
                        RemoveTrackedAchievement(achID) 
                        if AQT.FullUpdate then AQT:FullUpdate() end
                    end
                else
                    -- Open Frame
                    if not AchievementFrame then AchievementFrame_LoadUI() end
                    if AchievementFrame_SelectAchievement then
                        AchievementFrame_SelectAchievement(achID)
                    end
                end
            end)
            
            -- Tooltip
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetAchievementByID(achID)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            yOffset = yOffset - hText
            lineIdx = lineIdx + 1
            
            -- Achievement Criteria (Objectives)
            local numCriteria = GetAchievementNumCriteria(achID)
            for i = 1, numCriteria do
                local cName, cType, cComp, cQty, cReq = GetAchievementCriteriaInfo(achID, i)
                
                -- Only show incomplete criteria
                if not cComp then 
                    local cLine = self:GetLine(lineIdx)
                    cLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                    
                    cLine.text:SetFont(font, s.textSize, "OUTLINE")
                    cLine.text:SetTextColor(0.8, 0.8, 0.8) -- Gray for objectives
                    
                    local cText = cName
                    -- If it's a counter (e.g. 5/10), format it
                    if cReq and cReq > 1 then 
                        cText = string.format("- %s: %d/%d", cName, cQty, cReq) 
                    else
                        cText = "- " .. cName
                    end
                    
                    self.SafelySetText(cLine.text, cText)
                    cLine:Show()
                    
                    yOffset = yOffset - hText
                    lineIdx = lineIdx + 1
                end
            end
            
            yOffset = yOffset - 6 -- Gap between achievements
        end
    end
    
    -- Section Spacing
    yOffset = yOffset - (ASSETS.spacing or 10)

    return yOffset, lineIdx
end