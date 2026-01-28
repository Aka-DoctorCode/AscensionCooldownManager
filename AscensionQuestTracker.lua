--------------------------------------------------------------------------------
-- NAMESPACE & CONSTANTS
--------------------------------------------------------------------------------
local addonName, addonTable = ...
local AQT = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)

-- NOTE: AscensionQuestTrackerDB is the SavedVariable (Global)

-- VISUAL ASSETS (Static configuration that doesn't change via Menu)
local ASSETS = {
    font = "Fonts\\FRIZQT__.TTF",
    fontHeaderSize = 13,
    fontTextSize = 10,
    barTexture = "Interface\\Buttons\\WHITE8x8",
    barHeight = 4,
    padding = 10,
    spacing = 15,
    
    colors = {
        header = {r = 1, g = 0.9, b = 0.5},
        timerHigh = {r = 1, g = 1, b = 1},
        timerLow = {r = 1, g = 0.2, b = 0.2},
        campaign = {r = 1, g = 0.5, b = 0.25},
        quest = {r = 1, g = 0.85, b = 0.3},
        wq = {r = 0.3, g = 0.7, b = 1},
        bonus = {r = 0.7, g = 0.3, b = 1},
    }
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function SafelySetText(fontString, text)
    if not fontString or type(fontString) ~= "table" then return end
    fontString:SetText(text or "")
end

local function FormatTime(seconds)
    if not seconds or type(seconds) ~= "number" then return "00:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

--------------------------------------------------------------------------------
-- UI OBJECT POOLS
--------------------------------------------------------------------------------

AQT.lines = {}
AQT.bars = {}
AQT.inBossCombat = false

-- Get or Create a FontString (Recycling System)
AQT.GetLine = function(self, index)
    if not self.lines[index] then
        local f = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f:SetJustifyH("RIGHT")
        f:SetWordWrap(true)
        f:SetShadowColor(0, 0, 0, 1)
        f:SetShadowOffset(1, -1)
        self.lines[index] = f
    end
    return self.lines[index]
end

-- Get or Create a StatusBar (Recycling System)
AQT.GetBar = function(self, index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self, "BackdropTemplate")
        b:SetStatusBarTexture(ASSETS.barTexture)
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ASSETS.barTexture)
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    return self.bars[index]
end

--------------------------------------------------------------------------------
-- RENDER MODULES
--------------------------------------------------------------------------------

-- Renders Mythic+, Delves, Scenarios (Always Visible)
local function RenderScenario(startY, lineIdx, barIdx)
    local yOffset = startY
    if not C_Scenario or not C_Scenario.IsInScenario() then return yOffset, lineIdx, barIdx end

    -- Mythic+ Timer Logic
    local timerID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID()
    if timerID then
        local level, _, _ = C_ChallengeMode.GetActiveKeystoneInfo()
        local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(timerID)
        local _, elapsedTime = GetWorldElapsedTime(1)
        local timeRem = (timeLimit or 0) - (elapsedTime or 0)

        -- Keystone Level Header
        local header = AQT:GetLine(lineIdx)
        header:SetFont(ASSETS.font, ASSETS.fontHeaderSize + 2, "OUTLINE")
        header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        SafelySetText(header, string.format("+%d Keystone", level or 0))
        header:Show()
        yOffset = yOffset - 18
        lineIdx = lineIdx + 1

        -- Timer Text
        local timerLine = AQT:GetLine(lineIdx)
        timerLine:SetFont(ASSETS.font, 18, "OUTLINE")
        timerLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        SafelySetText(timerLine, FormatTime(timeRem))
        timerLine:Show()
        yOffset = yOffset - 22
        lineIdx = lineIdx + 1

        -- Timer Bar
        local timeBar = AQT:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        -- Retrieve width from DB or default to 260
        local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        -- Color logic for timer
        if timeRem < 60 then
            timeBar:SetStatusBarColor(ASSETS.colors.timerLow.r, ASSETS.colors.timerLow.g, ASSETS.colors.timerLow.b)
        else
            timeBar:SetStatusBarColor(ASSETS.colors.timerHigh.r, ASSETS.colors.timerHigh.g, ASSETS.colors.timerHigh.b)
        end
        
        timeBar:Show()
        yOffset = yOffset - 12
        barIdx = barIdx + 1
    end
    
    -- Scenario Criteria (Delves, Torghast, Stages)
    -- We limit to 10 criteria for safety
    for i = 1, 10 do
        local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(i)
        if criteriaInfo and criteriaInfo.description and criteriaInfo.description ~= "" and not criteriaInfo.completed then
            local line = AQT:GetLine(lineIdx)
            line:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
            line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            
            -- Calculate percentage if weighted
            local text = criteriaInfo.description
            if criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 0 then
                if criteriaInfo.isWeightedProgress then
                     local percent = math.floor((criteriaInfo.quantity / criteriaInfo.totalQuantity) * 100)
                     text = string.format("%s: %d%%", text, percent)
                else
                     text = string.format("%s: %d/%d", text, criteriaInfo.quantity, criteriaInfo.totalQuantity)
                end
            end
            
            SafelySetText(line, text)
            line:Show()
            yOffset = yOffset - 12
            lineIdx = lineIdx + 1
            
            -- Progress Bar for Scenario Criteria
            if criteriaInfo.totalQuantity and criteriaInfo.totalQuantity > 0 then
                 local bar = AQT:GetBar(barIdx)
                 bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                 local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
                 bar:SetSize(width - 20, ASSETS.barHeight)
                 bar:SetMinMaxValues(0, 1)
                 bar:SetValue(criteriaInfo.quantity / criteriaInfo.totalQuantity)
                 bar:SetStatusBarColor(ASSETS.colors.barEnemy.r, ASSETS.colors.barEnemy.g, ASSETS.colors.barEnemy.b)
                 bar:Show()
                 yOffset = yOffset - 8
                 barIdx = barIdx + 1
            end
        end
    end
    
    return yOffset - ASSETS.spacing, lineIdx, barIdx
end

-- Renders Quests, Campaign, WQs (Can be hidden on Boss)
local function RenderQuests(startY, lineIdx, barIdx)
    -- Logic Check: Should we hide quests?
    local shouldHide = AscensionQuestTrackerDB and AscensionQuestTrackerDB.hideOnBoss
    if shouldHide and AQT.inBossCombat then 
        return startY, lineIdx, barIdx 
    end

    local yOffset = startY
    -- Nil check for QuestLog API
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return yOffset, lineIdx, barIdx end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        
        -- Valid quest check
        if info and not info.isHeader and not info.isHidden then
            -- Is it tracked?
            if C_QuestLog.GetQuestWatchType(info.questID) ~= nil then
                
                -- Determine Color
                local color = ASSETS.colors.quest
                if info.campaignID and info.campaignID > 0 then color = ASSETS.colors.campaign end
                if C_QuestLog.IsWorldQuest(info.questID) then color = ASSETS.colors.wq end
                
                -- Title
                local title = AQT:GetLine(lineIdx)
                title:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
                title:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                title:SetTextColor(color.r, color.g, color.b)
                SafelySetText(title, C_QuestLog.GetTitleForQuestID(info.questID))
                title:Show()
                yOffset = yOffset - 14
                lineIdx = lineIdx + 1

                -- Objectives
                local objectives = C_QuestLog.GetQuestObjectives(info.questID)
                if objectives then
                    for _, obj in ipairs(objectives) do
                        if obj and obj.text and not obj.finished then
                            local objLine = AQT:GetLine(lineIdx)
                            objLine:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                            objLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                            SafelySetText(objLine, obj.text)
                            objLine:Show()
                            yOffset = yOffset - 12
                            lineIdx = lineIdx + 1

                            -- Objective Bar
                            if obj.numRequired and obj.numRequired > 0 then
                                local bar = AQT:GetBar(barIdx)
                                bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                                bar:SetSize(width - 20, ASSETS.barHeight)
                                bar:SetValue(obj.numFulfilled / obj.numRequired)
                                bar:SetStatusBarColor(color.r, color.g, color.b)
                                bar:Show()
                                yOffset = yOffset - 8
                                barIdx = barIdx + 1
                            end
                        end
                    end
                end
                yOffset = yOffset - 5
            end
        end
    end
    return yOffset, lineIdx, barIdx
end

--------------------------------------------------------------------------------
-- CORE LOGIC & INITIALIZATION
--------------------------------------------------------------------------------

-- Public function to trigger updates (called from Config)
function AQT:FullUpdate()
    -- Clear everything
    for _, l in ipairs(AQT.lines) do l:Hide() end
    for _, b in ipairs(AQT.bars) do b:Hide() end
    
    local y, lIdx, bIdx = RenderScenario(-ASSETS.padding, 1, 1)
    RenderQuests(y, lIdx, bIdx)
    
    -- Resize background frame
    local totalH = math.abs(y) + ASSETS.padding
    if totalH < 50 then totalH = 50 end
    AQT:SetHeight(totalH)
end

local function Initialize()
    -- Initialize Database if missing (Safety check)
    if not AscensionQuestTrackerDB then 
        AscensionQuestTrackerDB = { scale = 1, width = 260, hideOnBoss = true, locked = false } 
    end
    
    local db = AscensionQuestTrackerDB
    
    -- Apply DB Settings
    AQT:SetSize(db.width or 260, 100)
    AQT:SetScale(db.scale or 1)
    
    -- Restore Position
    if db.position then
        AQT:ClearAllPoints()
        AQT:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    else
        AQT:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end

    -- Setup Dragging
    AQT:SetMovable(true)
    AQT:EnableMouse(not db.locked) 
    AQT:RegisterForDrag("LeftButton")
    
    -- Drag Stop: Save Position
    AQT:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        AscensionQuestTrackerDB.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y
        }
    end)
    
    -- Drag Start: Check Lock
    AQT:SetScript("OnDragStart", function(self)
        if not AscensionQuestTrackerDB.locked then
            self:StartMoving()
        end
    end)

    -- Hide Blizzard Tracker
    if ObjectiveTrackerFrame then
        ObjectiveTrackerFrame:Hide()
        hooksecurefunc(ObjectiveTrackerFrame, "Show", function(s) s:Hide() end)
    end
    
    AQT:FullUpdate()
    print("|cff00ff00Ascension Quest Tracker:|r v1.2 Initialized.")
end

--------------------------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------------------------

AQT:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Wait a moment for SavedVariables to fully load
        C_Timer.After(0.1, Initialize)
    elseif event == "ENCOUNTER_START" then 
        AQT.inBossCombat = true
        AQT:FullUpdate()
    elseif event == "ENCOUNTER_END" then 
        AQT.inBossCombat = false
        AQT:FullUpdate()
    else
        AQT:FullUpdate()
    end
end)

AQT:RegisterEvent("PLAYER_LOGIN")
AQT:RegisterEvent("QUEST_LOG_UPDATE")
AQT:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
AQT:RegisterEvent("SCENARIO_UPDATE")
AQT:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
-- Combat Events for auto-hide
AQT:RegisterEvent("ENCOUNTER_START")
AQT:RegisterEvent("ENCOUNTER_END")

-- Timer Loop for M+ (Optimized)
local timeSinceLast = 0
AQT:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLast = timeSinceLast + elapsed
    -- Update every 1s only if in Challenge Mode or Scenario
    if timeSinceLast > 1.0 then 
        if (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID()) then
            AQT:FullUpdate()
        end
        timeSinceLast = 0
    end
end)