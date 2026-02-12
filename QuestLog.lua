-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: QuestLog.lua
-- Version: 06
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

-- Reusable tables to reduce Garbage Collection
local pooled_watchedIDs = {}
local pooled_quests = {}

function AQT:RenderQuests(startY, lineIdx, barIdx, itemIdx, style)
    local ASSETS = ns.ASSETS
    -- 1. Apply Granular Style (or fallback)
    local s = style or { headerSize = 13, textSize = 10, barHeight = 4, lineSpacing = 6 }
    local font = ASSETS.font
    
    -- Boss Hide Check
    local shouldHide = self.db.profile.hideOnBoss
    if shouldHide and self.inBossCombat then return startY, lineIdx, barIdx, itemIdx end

    -- Pre-calculate heights
    local hHead = s.headerSize + (s.lineSpacing or 6)
    local hText = s.textSize + (s.lineSpacing or 6)
    local hSub  = (s.textSize - 1) + (s.lineSpacing or 6)
    local width = self.db.profile.width or 260
    local yOffset = startY

    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then return yOffset, lineIdx, barIdx, itemIdx end

    -- 2. Data Gathering
    local campaignQuests = {}
    local sideQuests = {}
    local sideQuestsZoneOrder = {}
    
    table.wipe(pooled_watchedIDs)
    table.wipe(pooled_quests)

    -- Gather Watched Quests
    local numWatches = C_QuestLog.GetNumQuestWatches()
    for i = 1, numWatches do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i) 
        if id then table.insert(pooled_watchedIDs, id) end
    end

    -- Gather Zone/Task Quests (Auto-add)
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if currentMapID and C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        local tasks = C_TaskQuest.GetQuestsOnMap(currentMapID)
        if tasks then
            for _, taskInfo in ipairs(tasks) do
                local qID = taskInfo.questID
                -- Check for duplicates
                local exists = false
                for _, v in ipairs(pooled_watchedIDs) do if v == qID then exists = true; break end end
                if not exists then table.insert(pooled_watchedIDs, qID) end
            end
        end
    end

    -- 3. Process Quests
    for _, qID in ipairs(pooled_watchedIDs) do
        -- Skip if it's a World Quest (Handled by WorldQuests.lua now)
        local isWQ = false
        if C_QuestLog.IsWorldQuest then isWQ = C_QuestLog.IsWorldQuest(qID) end
        
        if not isWQ then
            local info = nil
            local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)
    
            if logIdx then
                info = C_QuestLog.GetInfo(logIdx)
            else
                -- Fallback if not in log (e.g. Bonus Objectives sometimes)
                local title = C_QuestLog.GetTitleForQuestID(qID)
                if title and title ~= "" then
                    info = { title = title, questID = qID, isHeader = false, isHidden = false, campaignID = 0, mapID = 0 }
                    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then info.mapID = C_TaskQuest.GetQuestZoneID(qID) or 0 end
                end
            end
    
            if info and not info.isHidden then
                local isCampaign = info.campaignID and info.campaignID > 0
                local data = { id = qID, info = info, logIdx = logIdx }
    
                if isCampaign then
                    table.insert(campaignQuests, data)
                else
                    local mapID = info.mapID or 0
                    if not sideQuests[mapID] then
                        sideQuests[mapID] = {}
                        table.insert(sideQuestsZoneOrder, mapID)
                    end
                    table.insert(sideQuests[mapID], data)
                end
            end
        end
    end

    -- 4. Render Function
    local function RenderSection(headerTitle, headerIconAtlas, quests, isSubHeader)
        if #quests == 0 then return end

        -- Header
        if headerTitle then
            local hLine = self:GetLine(lineIdx)
            hLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

            hLine.text:SetFont(font, s.headerSize, "OUTLINE")
            
            if isSubHeader then
                 -- Zone Name (Yellow/Gold)
                 local cZone = ASSETS.colors.zone or {r=1, g=0.8, b=0}
                 hLine.text:SetTextColor(cZone.r, cZone.g, cZone.b)
                 self.SafelySetText(hLine.text, "  " .. headerTitle)
                 yOffset = yOffset - hHead
            else
                 -- Main Header (Campaign/Quests)
                 local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
                 hLine.text:SetTextColor(cHead.r, cHead.g, cHead.b)
                 self.SafelySetText(hLine.text, "  " .. string.upper(headerTitle))
                 if hLine.separator then hLine.separator:Show() end
                 yOffset = yOffset - (hHead + 4)
            end

            hLine:Show()
            lineIdx = lineIdx + 1
        end

        -- Quests
        for _, qData in ipairs(quests) do
            local qID = qData.id
            local info = qData.info
            local logIdx = qData.logIdx
            local isComplete = C_QuestLog.IsComplete(qID)

            local l = self:GetLine(lineIdx)
            l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

            -- Icon
            if l.icon then
                l.icon:Show()
                if isComplete then
                    l.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                    l.icon:SetVertexColor(0.2, 1, 0.2)
                else
                    l.icon:SetTexture("Interface\\Buttons\\UI-MicroButton-Quest-Up")
                    l.icon:SetVertexColor(1, 1, 1)
                end
                l.icon:SetSize(s.textSize + 2, s.textSize + 2)
            end

            -- Color
            local color = ASSETS.colors.quest or {r=1, g=1, b=1}
            if isComplete then color = ASSETS.colors.complete or {r=0, g=1, b=0} end
            l.text:SetTextColor(color.r, color.g, color.b)
            l.text:SetFont(font, s.textSize, "OUTLINE")

            -- Title
            local titleText = info.title
            if isComplete then titleText = titleText .. " |cff00ff00(Ready)|r" end
            self.SafelySetText(l.text, "  " .. titleText)
            l:Show()

            -- Item Button Logic
            if not InCombatLockdown() then
                local itemLink, itemIcon, itemCount, showItemWhenComplete
                if logIdx then
                    itemLink, itemIcon, itemCount, showItemWhenComplete = GetQuestLogSpecialItemInfo(logIdx)
                end

                if itemIcon and (not isComplete or showItemWhenComplete) then
                    local iBtn = self:GetItemButton(itemIdx)
                    local textWidth = l.text:GetStringWidth()
                    
                    iBtn:ClearAllPoints()
                    -- Position right of the text
                    iBtn:SetPoint("RIGHT", l, "RIGHT", -textWidth - 10, 0)

                    iBtn.icon:SetTexture(itemIcon)
                    iBtn.icon:SetVertexColor(1, 1, 1)
                    iBtn.count:SetText(itemCount and itemCount > 1 and itemCount or "")

                    -- Secure Attributes
                    iBtn:SetAttribute("type", nil) 
                    iBtn.itemLink = itemLink
                    iBtn:SetAttribute("type", "item")
                    iBtn:SetAttribute("item", itemLink)
                    iBtn:SetAttribute("questLogIndex", logIdx)

                    iBtn:SetFrameLevel(l:GetFrameLevel() + 5)
                    iBtn:Show()
                    itemIdx = itemIdx + 1
                end
            end

            -- Click Logic (Map / Context Menu)
            l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            l:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    if IsShiftKeyDown() then
                        local link = GetQuestLink(qID)
                        if link then ChatEdit_InsertLink(link) end
                    else
                        if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(qID) end
                    end
                elseif button == "RightButton" then
                     if MenuUtil and MenuUtil.CreateContextMenu then
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle(info.title)
                            rootDescription:CreateButton("Focus / SuperTrack", function() C_SuperTrack.SetSuperTrackedQuestID(qID) end)
                            rootDescription:CreateButton("Open Map", function() QuestMapFrame_OpenToQuestDetails(qID) end)
                            if C_QuestLog.IsPushableQuest(qID) and IsInGroup() then
                                rootDescription:CreateButton("Share", function() C_QuestLog.ShareQuest(qID) end)
                            end
                            rootDescription:CreateButton("|cffff4444Abandon|r", function() QuestMapFrame_AbandonQuest(qID) end)
                            rootDescription:CreateButton("Stop Tracking", function() 
                                C_QuestLog.RemoveQuestWatch(qID) 
                                if AQT.FullUpdate then AQT:FullUpdate() end
                            end)
                        end)
                    else
                        C_QuestLog.RemoveQuestWatch(qID)
                        if AQT.FullUpdate then AQT:FullUpdate() end
                    end
                end
            end)
            
            yOffset = yOffset - hText
            lineIdx = lineIdx + 1

            -- Objectives
            if not isComplete then
                local objectives = C_QuestLog.GetQuestObjectives(qID)
                if objectives then
                    for _, obj in ipairs(objectives) do
                        if obj.text and not obj.finished then
                            local oLine = self:GetLine(lineIdx)
                            oLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

                            oLine.text:SetFont(font, s.textSize - 1)
                            oLine.text:SetTextColor(0.7, 0.7, 0.7)
                            self.SafelySetText(oLine.text, "    " .. obj.text)
                            oLine:Show()
                            yOffset = yOffset - hSub
                            lineIdx = lineIdx + 1

                             if obj.numRequired and obj.numRequired > 0 then
                                local bar = self:GetBar(barIdx)
                                bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                                bar:SetSize(width - 40, s.barHeight)
                                bar:SetValue(obj.numFulfilled / obj.numRequired)
                                local cSide = ASSETS.colors.sideQuest or {r=0, g=0.7, b=1}
                                bar:SetStatusBarColor(cSide.r, cSide.g, cSide.b)
                                bar:Show()
                                yOffset = yOffset - (s.barHeight + 4)
                                barIdx = barIdx + 1
                            end
                        end
                    end
                end
            end
            
            yOffset = yOffset - 2
        end
        yOffset = yOffset - (s.lineSpacing or 6)
    end

    -- 5. Final Render Calls
    RenderSection("Campaign", nil, campaignQuests, false)

    if #sideQuestsZoneOrder > 0 then
        local hLine = self:GetLine(lineIdx)
        hLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        hLine.text:SetFont(font, s.headerSize, "OUTLINE")
        hLine.text:SetTextColor(1, 1, 1)
        self.SafelySetText(hLine.text, "  QUESTS") -- Generic Header
        hLine:Show()
        yOffset = yOffset - (hHead + 4)
        lineIdx = lineIdx + 1

        for _, mapID in ipairs(sideQuestsZoneOrder) do
            local mapInfo = C_Map.GetMapInfo(mapID)
            local zoneName = (mapInfo and mapInfo.name) or "Unknown Zone"
            RenderSection(zoneName, nil, sideQuests[mapID], true)
        end
    end

    return yOffset, lineIdx, barIdx, itemIdx
end