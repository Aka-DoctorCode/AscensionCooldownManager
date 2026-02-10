local addonName, ns = ...

-- Create Main Container (Holds everything and handles positioning)
local Container = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)
Container:SetClampedToScreen(true)

-- Create ScrollFrame (Handles masking and scrolling)
local ScrollFrame = CreateFrame("ScrollFrame", nil, Container)
ScrollFrame:SetPoint("TOPLEFT", 0, 0)
ScrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
ScrollFrame:EnableMouseWheel(true)

-- Create Content Frame (Holds the lines and bars)
local AQT = CreateFrame("Frame", nil, ScrollFrame)
AQT:SetSize(260, 100) -- Initial dummy size
ScrollFrame:SetScrollChild(AQT)

-- Mouse Wheel Handler
ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local new = current - (delta * 30) -- Scroll speed
    if new < 0 then new = 0 end
    
    -- El rango se calcula automáticamente (Contenido - AlturaVisible)
    local max = self:GetVerticalScrollRange()
    if new > max then new = max end
    self:SetVerticalScroll(new)
end)

-- Shared reference
ns.AQT = AQT 

--------------------------------------------------------------------------------
-- THEME LOADING & FALLBACK PROTECTION
--------------------------------------------------------------------------------
local ASSETS = nil
if ns.Themes and ns.Themes.Default then
    ASSETS = ns.Themes.Default
else
    -- Fallback theme defined here if Themes.lua fails
    ASSETS = {
        font = "Fonts\\FRIZQT__.TTF",
        fontHeaderSize = 13,
        fontTextSize = 10,
        barTexture = "Interface\\Buttons\\WHITE8x8",
        barHeight = 4,
        padding = 10,
        spacing = 15,
        colors = { header = {r=1,g=0.9,b=0.5} }, -- (Simplified fallback)
        animations = { fadeInDuration = 0.4, slideX = 20 }
    }
end
ns.ASSETS = ASSETS

--------------------------------------------------------------------------------
-- UI OBJECT POOLS
--------------------------------------------------------------------------------
AQT.lines = {}
AQT.bars = {}
AQT.itemButtons = {}
AQT.inBossCombat = false

function AQT:CreateAnimationGroup(frame)
    if frame.animGroup then return end
    local ag = frame:CreateAnimationGroup()
    ag:SetScript("OnFinished", function() frame:SetAlpha(1) end)
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.4); fade:SetOrder(1)
    local slide = ag:CreateAnimation("Translation")
    slide:SetOffset(20, 0); slide:SetDuration(0.4); slide:SetOrder(1)
    frame.animGroup = ag
end

function AQT:GetLine(index)
    if not self.lines[index] then
        local f = CreateFrame("Button", nil, self)
        f:SetSize(260, 16)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetAllPoints(f)
        f.text:SetJustifyH("RIGHT") 
        f.text:SetWordWrap(true)
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:CreateAnimationGroup(f)
        self.lines[index] = f
    end
    local line = self.lines[index]
    line:EnableMouse(false)
    line:SetScript("OnClick", nil)
    line:SetScript("OnEnter", nil)
    line:SetScript("OnLeave", nil)
    line:SetAlpha(1)
    if line.icon then line.icon:Hide() end
    if line.indentLine then line.indentLine:Hide() end
    return line
end

function AQT:GetBar(index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self, "BackdropTemplate")
        b:SetStatusBarTexture(ASSETS.barTexture or "Interface\\Buttons\\WHITE8x8")
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ASSETS.barTexture or "Interface\\Buttons\\WHITE8x8")
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    if self.bars[index].bg then self.bars[index].bg:Show() end
    return self.bars[index]
end

--------------------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------------------
function AQT.SafelySetText(fontString, text)
    if fontString then fontString:SetText(text or "") end
end

function AQT.FormatTime(seconds)
    if not seconds then return "00:00" end
    return string.format("%02d:%02d", math.floor(seconds/60), math.floor(seconds%60))
end

--------------------------------------------------------------------------------
-- MAIN UPDATE LOGIC (Fixed Scroll Crash)
--------------------------------------------------------------------------------
function AQT:FullUpdate()
    -- 1. Sync Visual Settings from DB
    if AscensionQuestTrackerDB then
        local db = AscensionQuestTrackerDB
        if ns.ASSETS then
            ns.ASSETS.fontHeaderSize = db.fontHeaderSize or 13
            ns.ASSETS.fontTextSize = db.fontTextSize or 10
            ns.ASSETS.lineSpacing = db.lineSpacing or 6
            ns.ASSETS.spacing = db.sectionSpacing or 15
        end
    end
    local ASSETS = ns.ASSETS -- Refresh local ref

    if not InCombatLockdown() then
        for _, itm in ipairs(self.itemButtons) do itm:Hide() end
    end
    
    local y, lIdx, bIdx = -ASSETS.padding, 1, 1
    
    -- Render Modules
    if self.RenderScenario then y, lIdx, bIdx = self:RenderScenario(y, lIdx, bIdx) end
    if self.RenderWidgets then y, lIdx, bIdx = self:RenderWidgets(y, lIdx, bIdx) end
    local itemIdx = 1
    if self.RenderQuests then y, lIdx, bIdx, itemIdx = self:RenderQuests(y, lIdx, bIdx, itemIdx) end
    if self.RenderAchievements then y, lIdx = self:RenderAchievements(y, lIdx) end
    
    -- Hide unused
    for i = lIdx, #self.lines do if self.lines[i] then self.lines[i]:Hide() end end
    for i = bIdx, #self.bars do if self.bars[i] then self.bars[i]:Hide() end end
    
    -- HEIGHT & SCROLL CALCULATION
    local contentHeight = math.abs(y) + ASSETS.padding
    local db = AscensionQuestTrackerDB or {}
    local maxWidth = db.width or 260
    local maxHeight = db.maxHeight or 600
    
    -- 1. Redimensionar el contenido (ScrollChild)
    self:SetSize(maxWidth, contentHeight)
    
    -- 2. Redimensionar el Contenedor (Ventana visible)
    local finalHeight = contentHeight
    if finalHeight > maxHeight then finalHeight = maxHeight end
    if finalHeight < 50 then finalHeight = 50 end
    
    Container:SetSize(maxWidth, finalHeight)
    
    -- [FIX] Eliminada la llamada a SetVerticalScrollRange que causaba el crash.
    -- El ScrollFrame actualiza su rango automáticamente al cambiar el tamaño del hijo.
    if ScrollFrame.UpdateScrollChildRect then
        ScrollFrame:UpdateScrollChildRect()
    end
end

-- Wrapper para llamadas externas
function Container:FullUpdate()
    AQT:FullUpdate()
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
local function Initialize()
    if not AscensionQuestTrackerDB then 
        AscensionQuestTrackerDB = { scale = 1, width = 260, hideOnBoss = true, locked = false, maxHeight = 600 } 
    end
    local db = AscensionQuestTrackerDB
    
    Container:SetScale(db.scale or 1)
    if db.position then
        Container:ClearAllPoints()
        Container:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    else
        Container:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end

    Container:SetMovable(true)
    Container:EnableMouse(not db.locked) 
    Container:RegisterForDrag("LeftButton")
    
    Container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        AscensionQuestTrackerDB.position = { point = point, relativePoint = rel, x = x, y = y }
    end)
    Container:SetScript("OnDragStart", function(self)
        if not AscensionQuestTrackerDB.locked then self:StartMoving() end
    end)
    
    AQT:FullUpdate()
    print("|cff00ff00Ascension Quest Tracker:|r Loaded (Scroll Fix Applied).")
end

AQT:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.1, Initialize)
    elseif event == "ENCOUNTER_START" then 
        AQT.inBossCombat = true; self.isDirty = true
    elseif event == "ENCOUNTER_END" then 
        AQT.inBossCombat = false; self.isDirty = true
    elseif event == "QUEST_TURNED_IN" then
        if SOUNDKIT and SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED then pcall(PlaySound, SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED) end
        self.isDirty = true
    else
        self.isDirty = true
    end
end)

AQT:RegisterEvent("PLAYER_LOGIN")
AQT:RegisterEvent("QUEST_LOG_UPDATE")
AQT:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
AQT:RegisterEvent("SUPER_TRACKING_CHANGED")
AQT:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
AQT:RegisterEvent("SCENARIO_UPDATE")
AQT:RegisterEvent("ENCOUNTER_START")
AQT:RegisterEvent("ENCOUNTER_END")
AQT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
AQT:RegisterEvent("QUEST_TURNED_IN")
AQT:RegisterEvent("QUEST_ACCEPTED")
AQT:RegisterEvent("QUEST_REMOVED")
AQT:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
AQT:RegisterEvent("UPDATE_UI_WIDGET")

local t = 0
AQT.isDirty = true 
AQT:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if self.isDirty then self:FullUpdate(); self.isDirty = false; t = 0; return end
    if t > 1.0 then self:FullUpdate(); t = 0 end
end)