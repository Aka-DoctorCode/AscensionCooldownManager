-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Scenarios.lua
-- Version: 06
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

function AQT:RenderScenario(startY, lineIdx, barIdx, style)
    local ASSETS = ns.ASSETS
    -- 1. Apply Granular Style (or fallback)
    local s = style or { headerSize = 14, textSize = 12, barHeight = 10, lineSpacing = 6 }
    local font = ASSETS.font
    local padding = ASSETS.padding or 10
    
    local yOffset = startY
    local width = self.db.profile.width or 260
    
    if not C_Scenario or not C_Scenario.IsInScenario() then return yOffset, lineIdx, barIdx end

    ----------------------------------------------------------------------------
    -- A. CHALLENGE MODE (M+) TIMER
    ----------------------------------------------------------------------------
    local timerID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if timerID then
        local level = (C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo())
        local _, _, timeLimit = (C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(timerID))
        local _, elapsedTime = GetWorldElapsedTime(1)
        local timeRem = (timeLimit or 0) - (elapsedTime or 0)

        -- Keystone Level Header
        local header = self:GetLine(lineIdx)
        header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        header.text:SetFont(font, s.headerSize + 2, "OUTLINE")
        local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
        header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
        
        local levelStr = level or 0
        self.SafelySetText(header.text, string.format("+%d Keystone", levelStr))
        header:Show()
        yOffset = yOffset - (s.headerSize + 4)
        lineIdx = lineIdx + 1

        -- Timer Text
        local timerLine = self:GetLine(lineIdx)
        timerLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        timerLine.text:SetFont(font, 18, "OUTLINE") 
        
        local m = math.floor(timeRem / 60)
        local sec = math.floor(timeRem % 60)
        self.SafelySetText(timerLine.text, string.format("%02d:%02d", m, sec))
        
        if timeRem < 60 then
            timerLine.text:SetTextColor(1, 0.2, 0.2) 
        else
            timerLine.text:SetTextColor(1, 1, 1)
        end
        timerLine:Show()
        yOffset = yOffset - 22
        lineIdx = lineIdx + 1

        -- Timer Bar
        local timeBar = self:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        if timeRem < 60 then
            timeBar:SetStatusBarColor(1, 0.2, 0.2)
        else
            timeBar:SetStatusBarColor(1, 1, 1)
        end
        timeBar:Show()
        yOffset = yOffset - 12
        barIdx = barIdx + 1
    end
    
    ----------------------------------------------------------------------------
    -- B. SCENARIO OBJECTIVES
    ----------------------------------------------------------------------------
    if C_Scenario and C_Scenario.GetInfo then
         local name, currentStage, numStages = C_Scenario.GetInfo()
         
         if name then
             -- Scenario Name Header
             local header = self:GetLine(lineIdx)
             header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
             header.text:SetFont(font, s.headerSize, "OUTLINE")
             local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
             header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
             self.SafelySetText(header.text, name)
             header:Show()
             
             yOffset = yOffset - (s.headerSize + s.lineSpacing)
             lineIdx = lineIdx + 1
             
             -- Stage Info
             local stageName, stageDesc, numCriteria, _, _, _, _, _, weightedProgress = C_Scenario.GetStepInfo()
             
             if stageName and stageName ~= "" and stageName ~= name then
                 local sLine = self:GetLine(lineIdx)
                 sLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                 sLine.text:SetFont(font, s.textSize, "OUTLINE")
                 
                 local cStage = ASSETS.colors.zone or {r=1, g=0.8, b=0}
                 sLine.text:SetTextColor(cStage.r, cStage.g, cStage.b)
                 
                 self.SafelySetText(sLine.text, stageName)
                 sLine:Show()
                 yOffset = yOffset - (s.textSize + s.lineSpacing)
                 lineIdx = lineIdx + 1
             end
             
             -- 1. Main Bar (Weighted Progress)
             if weightedProgress and type(weightedProgress) == "number" then
                 local pLine = self:GetLine(lineIdx)
                 pLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                 pLine.text:SetFont(font, s.textSize, "OUTLINE")
                 pLine.text:SetTextColor(1, 1, 1)
                 
                 self.SafelySetText(pLine.text, string.format("%s (%d%%)", stageDesc or stageName, weightedProgress))
                 pLine:Show()
                 yOffset = yOffset - (s.textSize + 4)
                 lineIdx = lineIdx + 1
                 
                 local bar = self:GetBar(barIdx)
                 bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                 bar:SetSize(width - 20, s.barHeight)
                 bar:SetMinMaxValues(0, 100)
                 bar:SetValue(weightedProgress)
                 
                 local cBar = ASSETS.colors.quest or {r=1, g=0.8, b=0}
                 bar:SetStatusBarColor(cBar.r, cBar.g, cBar.b)
                 bar:Show()
                 
                 yOffset = yOffset - (s.barHeight + s.lineSpacing)
                 barIdx = barIdx + 1
             else
                 -- 2. Individual Criteria (ROBUST API CHECK)
                 local cnt = numCriteria or 0
                 for i = 1, cnt do
                    local criteriaString, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress
                    
                    -- Priority 1: C_ScenarioInfo (Modern Retail 11.0+)
                    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
                        local info = C_ScenarioInfo.GetCriteriaInfo(i)
                        if info then
                            criteriaString = info.description
                            completed = info.completed
                            quantity = info.quantity
                            totalQuantity = info.totalQuantity
                            isWeightedProgress = info.isWeightedProgress
                        end
                    end

                    -- Priority 2: C_Scenario.GetCriteriaInfo (Legacy/Table Support)
                    if (not criteriaString) and C_Scenario.GetCriteriaInfo then
                        -- Check if it returns a table or list
                        local status, res = pcall(C_Scenario.GetCriteriaInfo, i)
                        if status then
                            if type(res) == "table" then
                                criteriaString = res.description
                                completed = res.completed
                                quantity = res.quantity
                                totalQuantity = res.totalQuantity
                                isWeightedProgress = res.isWeightedProgress
                            else
                                -- Fallback for very old API returns
                                criteriaString, _, completed, quantity, totalQuantity, flags, _, _, _, _, _, _, isWeightedProgress = C_Scenario.GetCriteriaInfo(i)
                            end
                        end
                    end

                    -- Priority 3: C_Scenario.GetStepCriteriaInfo (Ultimate Fallback)
                    if (not criteriaString) and C_Scenario.GetStepCriteriaInfo then
                         criteriaString, _, completed, quantity, totalQuantity, flags, _, _, _, _, _, _, isWeightedProgress = C_Scenario.GetStepCriteriaInfo(i)
                    end
                    
                    if criteriaString and criteriaString ~= "" then
                        local line = self:GetLine(lineIdx)
                        line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                        line.text:SetFont(font, s.textSize, "OUTLINE")
                        
                        local text = "- " .. criteriaString
                        if totalQuantity and totalQuantity > 0 then
                            text = string.format("- %s: %d/%d", criteriaString, quantity, totalQuantity)
                        end
                        if isWeightedProgress then
                             text = string.format("- %s: %d%%", criteriaString, quantity)
                        end
                        
                        -- Color Logic
                        if completed then
                            local cComp = ASSETS.colors.complete or {r=0.2, g=1, b=0.2}
                            line.text:SetTextColor(cComp.r, cComp.g, cComp.b)
                        else
                            line.text:SetTextColor(1, 1, 1)
                        end
                        
                        self.SafelySetText(line.text, text)
                        line:Show()
                        
                        -- Progress Bar check
                        local showBar = false
                        local barMax = totalQuantity
                        local barVal = quantity
                        
                        if not completed and (isWeightedProgress or (totalQuantity and totalQuantity > 1)) then
                            showBar = true
                            if isWeightedProgress then barMax = 100 end
                        end

                        if showBar then
                            yOffset = yOffset - (s.textSize + 2)
                            
                            local bar = self:GetBar(barIdx)
                            bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                            bar:SetSize(width - 20, s.barHeight)
                            bar:SetMinMaxValues(0, barMax)
                            bar:SetValue(barVal)
                            
                            local cBar = ASSETS.colors.quest or {r=1, g=0.8, b=0}
                            bar:SetStatusBarColor(cBar.r, cBar.g, cBar.b)
                            bar:Show()
                            
                            yOffset = yOffset - (s.barHeight + s.lineSpacing)
                            barIdx = barIdx + 1
                            lineIdx = lineIdx + 1
                        else
                            yOffset = yOffset - (s.textSize + s.lineSpacing)
                            lineIdx = lineIdx + 1
                        end
                    end
                 end
             end
         end
    end
    
    -- Add section spacing
    yOffset = yOffset - (ASSETS.spacing or 15)
    
    return yOffset, lineIdx, barIdx
end