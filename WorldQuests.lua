-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: WorldQuests.lua
-- Version: 06 (Updated for Granular Config)
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

-- Helper to check if a quest is a World Quest
function AQT:IsWorldQuest(qID)
    if not C_QuestLog.IsWorldQuest then return false end
    return C_QuestLog.IsWorldQuest(qID)
end

-- Gets the time remaining in minutes for a World Quest
function AQT:GetWorldQuestTimeRemaining(qID)
    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
        return C_TaskQuest.GetQuestTimeLeftMinutes(qID) or 0
    end
    return 0
end

-- Formats the title with the time remaining if applicable
function AQT:FormatWorldQuestTitle(title, minutes)
    if minutes > 0 and minutes < 1440 then -- Less than 24h
        local timeStr = ""
        if minutes < 60 then
            timeStr = string.format("|cffff4444[%dm]|r", minutes) -- Red if < 1h
        else
            local h = math.floor(minutes / 60)
            local m = minutes % 60
            timeStr = string.format("[%d:%02dh]", h, m)
        end
        return string.format("%s %s", timeStr, title)
    end
    return title
end

--------------------------------------------------------------------------------
-- RENDER WORLD QUESTS
--------------------------------------------------------------------------------
function AQT:RenderWorldQuests(startY, lineIdx, barIdx, itemIdx, style)
    -- 1. Setup Style (Use passed style or fallback)
    local s = style or { headerSize = 12, textSize = 10, barHeight = 4, lineSpacing = 6 }
    local font = ASSETS.font
    local padding = ASSETS.padding
    
    local y = startY
    local hasHeader = false
    local headerY = y

    -- 2. Iterate Quest Watch List
    local numEntries = C_QuestLog.GetNumQuestWatches()
    
    for i = 1, numEntries do
        local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        
        -- ONLY process if it IS a World Quest
        if qID and self:IsWorldQuest(qID) then
            
            -- Render Header (Only once)
            if not hasHeader then
                local h = self:GetLine(lineIdx)
                h:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
                h.text:SetFont(font, s.headerSize, "OUTLINE")
                local c = ASSETS.colors.zone or {r=1, g=1, b=1}
                h.text:SetTextColor(c.r, c.g, c.b)
                self.SafelySetText(h.text, "World Quests")
                h:Show()
                
                y = y - (s.headerSize + s.lineSpacing)
                lineIdx = lineIdx + 1
                hasHeader = true
            end

            -- Get Info
            local title = C_QuestLog.GetTitleForQuestID(qID)
            
            -- Add Timer to Title
            local minutes = self:GetWorldQuestTimeRemaining(qID)
            title = self:FormatWorldQuestTitle(title, minutes)

            -- Render Title
            local l = self:GetLine(lineIdx)
            l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
            l.text:SetFont(font, s.textSize, "OUTLINE")
            local c = ASSETS.colors.wq or {r=1, g=0.8, b=1}
            l.text:SetTextColor(c.r, c.g, c.b)
            self.SafelySetText(l.text, title)
            l:Show()
            
            -- Context Menu / Click Logic
            l:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                     -- World Quest Context Menu (Cannot abandon WQs usually, but can Stop Tracking)
                     if MenuUtil and MenuUtil.CreateContextMenu then
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle("World Quest")
                            rootDescription:CreateButton("Open Map", function() QuestMapFrame_OpenToQuestDetails(qID) end)
                            rootDescription:CreateButton("Stop Tracking", function() 
                                C_QuestLog.RemoveQuestWatch(qID) 
                                if AQT.FullUpdate then AQT:FullUpdate() end
                            end)
                        end)
                     else
                        C_QuestLog.RemoveQuestWatch(qID)
                        if AQT.FullUpdate then AQT:FullUpdate() end
                     end
                else
                    if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(qID) end
                end
            end)

            y = y - (s.textSize + s.lineSpacing)
            lineIdx = lineIdx + 1

            -- Render Objectives (Simple % for WQ usually)
            local objectives = C_QuestLog.GetQuestObjectives(qID)
            if objectives then
                for _, obj in pairs(objectives) do
                    if obj.text and obj.text ~= "" then
                        local l_obj = self:GetLine(lineIdx)
                        l_obj:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
                        l_obj.text:SetFont(font, s.textSize - 1, "OUTLINE") -- Slightly smaller
                        l_obj.text:SetTextColor(0.8, 0.8, 0.8)
                        self.SafelySetText(l_obj.text, "- " .. obj.text)
                        l_obj:Show()
                        y = y - (s.textSize + s.lineSpacing)
                        lineIdx = lineIdx + 1
                    end
                end
            end
            
            -- Render Bar (If progress exists)
            local pct = C_TaskQuest.GetQuestProgressBarInfo(qID)
            if pct then
                local b = self:GetBar(barIdx)
                b:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
                b:SetSize(self.db.profile.width - 40, s.barHeight)
                b:SetMinMaxValues(0, 100)
                b:SetValue(pct)
                b:SetStatusBarColor(c.r, c.g, c.b)
                b:Show()
                y = y - (s.barHeight + s.lineSpacing + 4)
                barIdx = barIdx + 1
            end
            
            y = y - 6 -- Tiny extra gap between quests
        end
    end

    -- Add Section Spacing only if we rendered something
    if hasHeader then
        y = y - ASSETS.spacing
    end

    return y, lineIdx, barIdx, itemIdx
end