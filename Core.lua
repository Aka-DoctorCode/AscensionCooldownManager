-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Core.lua
-- Version: 06
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
-- Initialize AceAddon
local AQT = LibStub("AceAddon-3.0"):NewAddon("AscensionQuestTracker", "AceEvent-3.0", "AceConsole-3.0")
ns.AQT = AQT 

local defaults = {
    profile = {
        -- Global / Layout
        position = { point = "RIGHT", relativePoint = "RIGHT", x = -50, y = 0 },
        scale = 1.0,
        locked = false,
        hideOnBoss = true,
        autoSuperTrack = false,
        testMode = false,
        hideBlizzardTracker = true,
        maxHeight = 600,
        width = 260,
        sectionSpacing = 15,
        
        -- Granular Styles
        styles = {
            scenarios =    { headerSize = 14, textSize = 12, barHeight = 10, lineSpacing = 6 },
            quests =       { headerSize = 13, textSize = 10, barHeight = 4,  lineSpacing = 6 },
            worldQuests =  { headerSize = 12, textSize = 10, barHeight = 4,  lineSpacing = 6 },
            achievements = { headerSize = 12, textSize = 10, barHeight = 4,  lineSpacing = 6 },
        }
    }
}

function AQT:OnInitialize()
    -- Initialize DB with "Default" profile
    self.db = LibStub("AceDB-3.0"):New("AscensionQuestTrackerDB", defaults, true)
    
    -- Register Profile Callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset",  "RefreshConfig")

    -- Compatibilidad legacy
    _G.AscensionQuestTrackerDB = self.db.profile 
end

-- New Function to handle profile switches
function AQT:RefreshConfig()
    -- Re-apply layout settings (Position, Scale, Lock)
    self:UpdateLayout()
    -- Re-apply visual settings and content (Fonts, Spacing, Mock Data)
    self:FullUpdate()
end

function AQT:OnEnable()
    self:CreateUI()
    if self.SetupOptions then self:SetupOptions() end
    self:RegisterEvents()
    self:InitializeBlizzardHider()
    self:UpdateBlizzardTrackerVisibility()
    self:FullUpdate()
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------
function AQT:CreateUI()
    -- Main Container
    local Container = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)
    Container:SetClampedToScreen(true)
    Container:SetMovable(true)
    Container:RegisterForDrag("LeftButton")
    
    -- ScrollFrame
    local ScrollFrame = CreateFrame("ScrollFrame", nil, Container)
    ScrollFrame:SetPoint("TOPLEFT", 0, 0)
    ScrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    ScrollFrame:EnableMouseWheel(true)
    
    -- Content Frame (Donde se dibujan las lineas)
    local Content = CreateFrame("Frame", nil, ScrollFrame)
    Content:SetSize(260, 100)
    ScrollFrame:SetScrollChild(Content)
    
    -- Mouse Wheel
    ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local new = current - (delta * 30)
        if new < 0 then new = 0 end
        local max = self:GetVerticalScrollRange()
        if new > max then new = max end
        self:SetVerticalScroll(new)
    end)
    
    -- Drag Logic
    Container:SetScript("OnDragStart", function(self)
        if not AQT.db.profile.locked then self:StartMoving() end
    end)
    Container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        AQT.db.profile.position = { point = point, relativePoint = rel, x = x, y = y }
    end)
    
    -- Guardamos las referencias en AQT para usarlas en los módulos
    self.Container = Container
    self.ScrollFrame = ScrollFrame
    self.Content = Content -- IMPORTANTE: Aquí es donde anclaremos las líneas
    
    self:UpdateLayout()
end

function AQT:UpdateLayout()
    local db = self.db.profile
    self.Container:SetScale(db.scale)
    self.Container:EnableMouse(not db.locked)
    
    if db.position then
        self.Container:ClearAllPoints()
        self.Container:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    end
end

-- ASSETS
local ASSETS_FALLBACK = {
    font = "Fonts\\FRIZQT__.TTF", fontHeaderSize = 13, fontTextSize = 10,
    barTexture = "Interface\\Buttons\\WHITE8x8", barHeight = 4, padding = 10, spacing = 15,
    colors = { header = {r=1,g=0.9,b=0.5} }, animations = { fadeInDuration = 0.4, slideX = 20 }
}
ns.ASSETS = ns.Themes and ns.Themes.Default or ASSETS_FALLBACK

-- POOLS
AQT.lines = {}
AQT.bars = {}
AQT.itemButtons = {}

function AQT:GetLine(index)
    if not self.lines[index] then
        local f = CreateFrame("Button", nil, self.Content) -- Parent = self.Content
        f:SetSize(260, 16)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetAllPoints(f)
        f.text:SetJustifyH("RIGHT") 
        f.text:SetWordWrap(true)
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.lines[index] = f
    end
    local line = self.lines[index]
    line:EnableMouse(false)
    line:SetScript("OnClick", nil); line:SetScript("OnEnter", nil); line:SetScript("OnLeave", nil)
    line:SetAlpha(1)
    if line.icon then line.icon:Hide() end
    if line.indentLine then line.indentLine:Hide() end
    return line
end

function AQT:GetBar(index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self.Content, "BackdropTemplate")
        b:SetStatusBarTexture(ns.ASSETS.barTexture)
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.ASSETS.barTexture)
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    if self.bars[index].bg then self.bars[index].bg:Show() end
    return self.bars[index]
end

-- Secure Item Button Pool
function AQT:GetItemButton(index)
    if not self.itemButtons[index] then
        local name = "AQTItemButton" .. index
        -- Create a SecureActionButton so it can trigger items/spells
        local b = CreateFrame("Button", name, self.Container, "SecureActionButtonTemplate")
        b:SetSize(22, 22)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        
        -- Click handlers: Use AnyUp/AnyDown for better responsiveness
        b:RegisterForClicks("AnyUp", "AnyDown")
        
        -- Tooltip logic
        b:SetScript("OnEnter", function(self)
            local questLogIndex = self:GetAttribute("questLogIndex")
            if questLogIndex then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetQuestLogSpecialItem(questLogIndex)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Hook for Shift-Click Chat Link (Preserves SecureActionButton logic)
        b:HookScript("OnClick", function(self)
            if IsShiftKeyDown() and self.itemLink then
                ChatEdit_InsertLink(self.itemLink)
            end
        end)
        
        self.itemButtons[index] = b
    end
    return self.itemButtons[index]
end

function AQT.SafelySetText(fontString, text)
    if fontString then fontString:SetText(text or "") end
end

function AQT:FullUpdate()
    if not self.db then return end
    local db = self.db.profile
    local ASSETS = ns.ASSETS
    
    -- Sync Global Settings to ASSETS (Fallback)
    ASSETS.spacing = db.sectionSpacing
    -- Note: We no longer sync generic font sizes here because modules use specific styles now.
    -- But we keep them in ASSETS for safety or non-granular parts.
    ASSETS.padding = 10

    -- 1. Hide all elements
    for _, l in ipairs(self.lines) do l:Hide() end
    for _, b in ipairs(self.bars) do b:Hide() end
    if self.itemButtons and not InCombatLockdown() then
        for _, btn in ipairs(self.itemButtons) do btn:Hide() end
    end

    local y = -ASSETS.padding
    local lIdx = 1
    local bIdx = 1
    local itemIdx = 1
    
    -- Styles for this update
    local styles = db.styles

    if db.testMode then
        y, lIdx, bIdx = self:RenderMock(y, lIdx, bIdx)
    else
        -- 1. Scenarios
        if self.RenderScenario then
            y, lIdx, bIdx = self:RenderScenario(y, lIdx, bIdx, styles.scenarios)
        end

        -- 2. Widgets (Timer/Durability) - Uses Scenarios style or Quests style? Let's use Scenarios.
        if self.RenderWidgets then 
            y, lIdx, bIdx = self:RenderWidgets(y, lIdx, bIdx, styles.scenarios) 
        end

        -- 3. Quests
        if self.RenderQuests then
            y, lIdx, bIdx, itemIdx = self:RenderQuests(y, lIdx, bIdx, itemIdx, styles.quests)
        end
        
        -- 4. World Quests (If separated, otherwise RenderQuests handles it. 
        -- If you have a separate RenderWorldQuests, pass styles.worldQuests)
        if self.RenderWorldQuests then
            y, lIdx, bIdx, itemIdx = self:RenderWorldQuests(y, lIdx, bIdx, itemIdx, styles.worldQuests)
        end
        
        -- 5. Achievements
        if self.RenderAchievements then
            y, lIdx = self:RenderAchievements(y, lIdx, styles.achievements)
        end
    end

    -- Resize Container
    local h = math.abs(y) + ASSETS.padding
    self.Content:SetHeight(h < 50 and 50 or h)
    
    local finalHeight = math.min(h, db.maxHeight)
    if finalHeight < 50 then finalHeight = 50 end
    self.Container:SetSize(db.width, finalHeight)
    
    if self.ScrollFrame.UpdateScrollChildRect then self.ScrollFrame:UpdateScrollChildRect() end
end

--------------------------------------------------------------------------------
-- MOCK RENDER (Test Mode)
--------------------------------------------------------------------------------
function AQT:RenderMock(startY, lineIdx, barIdx)
    local ASSETS = ns.ASSETS
    local styles = self.db.profile.styles -- Get the new styles
    local width = self.db.profile.width or 260
    local font = ASSETS.font
    local sectSp = self.db.profile.sectionSpacing or 15
    
    local yOffset = startY

    -- 1. SCENARIO MOCK (Uses Scenario Style)
    local s = styles.scenarios
    local hHead, hText, lineSp = s.headerSize, s.textSize, s.lineSpacing

    -- Header
    local h = self:GetLine(lineIdx)
    h:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    h.text:SetFont(font, hHead, "OUTLINE")
    local c = ASSETS.colors.header or {r=1, g=1, b=1}
    h.text:SetTextColor(c.r, c.g, c.b)
    self.SafelySetText(h.text, "Test Dungeon (Mythic)")
    h:Show()
    yOffset = yOffset - (hHead + lineSp); lineIdx = lineIdx + 1

    -- Stage
    local l = self:GetLine(lineIdx)
    l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    l.text:SetFont(font, hText, "OUTLINE")
    l.text:SetTextColor(1, 0.8, 0) -- Gold
    self.SafelySetText(l.text, "Stage 2: The Test")
    l:Show()
    yOffset = yOffset - (hText + lineSp); lineIdx = lineIdx + 1

    -- Boss 1
    l = self:GetLine(lineIdx)
    l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    l.text:SetFont(font, hText, "OUTLINE")
    l.text:SetTextColor(0, 1, 0) -- Green
    self.SafelySetText(l.text, "- Boss 1 (Done)")
    l:Show()
    yOffset = yOffset - (hText + lineSp); lineIdx = lineIdx + 1
    
    yOffset = yOffset - sectSp

    -- 2. WORLD QUEST MOCK (Uses WQ Style)
    s = styles.worldQuests
    hHead, hText, lineSp = s.headerSize, s.textSize, s.lineSpacing

    -- Header
    h = self:GetLine(lineIdx)
    h:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    h.text:SetFont(font, hHead, "OUTLINE")
    c = ASSETS.colors.zone or {r=1, g=0.8, b=0}
    h.text:SetTextColor(c.r, c.g, c.b)
    self.SafelySetText(h.text, "Azsuna")
    h:Show()
    yOffset = yOffset - (hHead + lineSp); lineIdx = lineIdx + 1

    -- Quest
    l = self:GetLine(lineIdx)
    l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    l.text:SetFont(font, hText, "OUTLINE")
    self.SafelySetText(l.text, "[23h] Test World Quest")
    l:Show()
    yOffset = yOffset - (hText + lineSp); lineIdx = lineIdx + 1

    yOffset = yOffset - sectSp

    -- 3. QUEST MOCK (Uses Quest Style)
    s = styles.quests
    hHead, hText, lineSp = s.headerSize, s.textSize, s.lineSpacing

    -- Header
    h = self:GetLine(lineIdx)
    h:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    h.text:SetFont(font, hHead, "OUTLINE")
    c = ASSETS.colors.zone or {r=1, g=0.8, b=0}
    h.text:SetTextColor(c.r, c.g, c.b)
    self.SafelySetText(h.text, "Elwynn Forest")
    h:Show()
    yOffset = yOffset - (hHead + lineSp); lineIdx = lineIdx + 1

    -- Quest 1
    l = self:GetLine(lineIdx)
    l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    l.text:SetFont(font, hText, "OUTLINE")
    self.SafelySetText(l.text, "Test Quest 1")
    l:Show()
    yOffset = yOffset - (hText + lineSp); lineIdx = lineIdx + 1

    -- Objective with Bar
    l = self:GetLine(lineIdx)
    l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    l.text:SetFont(font, hText - 1, "OUTLINE")
    l.text:SetTextColor(0.8, 0.8, 0.8)
    self.SafelySetText(l.text, "Items Collected: 3/12")
    l:Show()
    yOffset = yOffset - ((hText - 1) + lineSp); lineIdx = lineIdx + 1

    local b = self:GetBar(barIdx)
    b:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    b:SetSize(width - 40, s.barHeight)
    b:SetValue(0.25)
    b:SetStatusBarColor(0, 0.7, 1)
    b:Show()
    yOffset = yOffset - (s.barHeight + lineSp + 2); barIdx = barIdx + 1

    return yOffset, lineIdx, barIdx
end
--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------
function AQT:FullUpdate()
    if not self.db then return end
    local db = self.db.profile
    local ASSETS = ns.ASSETS
    
    -- Sync Global Settings
    ASSETS.spacing = db.sectionSpacing
    ASSETS.padding = 10 -- Hardcoded or added to config if you wish

    -- 1. Hide all elements
    for _, l in ipairs(self.lines) do l:Hide() end
    for _, b in ipairs(self.bars) do b:Hide() end
    if self.itemButtons and not InCombatLockdown() then
        for _, btn in ipairs(self.itemButtons) do btn:Hide() end
    end

    local y = -ASSETS.padding
    local lIdx = 1
    local bIdx = 1
    local itemIdx = 1
    
    -- Get Styles
    local styles = db.styles

    if db.testMode then
        y, lIdx, bIdx = self:RenderMock(y, lIdx, bIdx)
    else
        -- 1. Scenarios
        if self.RenderScenario then
            y, lIdx, bIdx = self:RenderScenario(y, lIdx, bIdx, styles.scenarios)
        end

        -- 2. Widgets (Timer/Durability)
        if self.RenderWidgets then 
            y, lIdx, bIdx = self:RenderWidgets(y, lIdx, bIdx, styles.scenarios) 
        end

        -- 3. Quests
        if self.RenderQuests then
            y, lIdx, bIdx, itemIdx = self:RenderQuests(y, lIdx, bIdx, itemIdx, styles.quests)
        end
        
        -- 4. World Quests
        if self.RenderWorldQuests then
            y, lIdx, bIdx, itemIdx = self:RenderWorldQuests(y, lIdx, bIdx, itemIdx, styles.worldQuests)
        end
        
        -- 5. Achievements
        if self.RenderAchievements then
            y, lIdx = self:RenderAchievements(y, lIdx, styles.achievements)
        end
    end

    -- Resize Container
    local h = math.abs(y) + ASSETS.padding
    self.Content:SetHeight(h < 50 and 50 or h)
    
    local finalHeight = math.min(h, db.maxHeight)
    if finalHeight < 50 then finalHeight = 50 end
    self.Container:SetSize(db.width, finalHeight)
    
    if self.ScrollFrame.UpdateScrollChildRect then self.ScrollFrame:UpdateScrollChildRect() end
end

--------------------------------------------------------------------------------
-- BLIZZARD TRACKER VISIBILITY
--------------------------------------------------------------------------------
function AQT:InitializeBlizzardHider()
    -- Identify the frame (Retail vs Classic compatibility)
    if not self.BlizzTracker then
        self.BlizzTracker = ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame
    end
    
    if self.BlizzTracker and not self.BlizzTracker.isHooked then
        -- Hook OnShow to enforce hiding if enabled
        self.BlizzTracker:HookScript("OnShow", function(tracker)
            if self.db.profile.hideBlizzardTracker then
                tracker:Hide()
            end
        end)
        self.BlizzTracker.isHooked = true
    end
end

function AQT:UpdateBlizzardTrackerVisibility()
    if not self.BlizzTracker then self:InitializeBlizzardHider() end
    if not self.BlizzTracker then return end
    
    if self.db.profile.hideBlizzardTracker then
        self.BlizzTracker:Hide()
    else
        self.BlizzTracker:Show()
    end
end

function AQT:RegisterEvents()
    self:RegisterEvent("PLAYER_LOGIN", "FullUpdate")
    self:RegisterEvent("QUEST_LOG_UPDATE", "FullUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "FullUpdate")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "FullUpdate")
    self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE", "FullUpdate")
    self:RegisterEvent("SCENARIO_UPDATE", "FullUpdate")
    self:RegisterEvent("ENCOUNTER_START", function() self.inBossCombat = true; self:FullUpdate() end)
    self:RegisterEvent("ENCOUNTER_END", function() self.inBossCombat = false; self:FullUpdate() end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "FullUpdate")
    self:RegisterEvent("QUEST_TURNED_IN", "FullUpdate")
    self:RegisterEvent("QUEST_ACCEPTED", "FullUpdate")
    self:RegisterEvent("QUEST_REMOVED", "FullUpdate")
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "FullUpdate")
    self:RegisterEvent("UPDATE_UI_WIDGET", "FullUpdate")
end