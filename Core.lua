-- Lua functions
local _G = _G
local ipairs = ipairs
local pairs = pairs
local select = select
local tinsert = tinsert
local tonumber = tonumber

-- WoW API / Variables
local UnitFactionGroup = UnitFactionGroup
local C_ContributionCollector_GetState = C_ContributionCollector.GetState
local C_TaskQuest_GetQuestTimeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes
local Enum_ContributionState = Enum.ContributionState
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local EJ_GetEncounterInfo = EJ_GetEncounterInfo
local IsQuestFlaggedCompleted = IsQuestFlaggedCompleted
local GetAchievementInfo = GetAchievementInfo
local RequestRaidInfo = RequestRaidInfo
local GetNumSavedInstances = GetNumSavedInstances
local GetSavedInstanceInfo = GetSavedInstanceInfo
local GetSavedInstanceChatLink = GetSavedInstanceChatLink
local GetSavedInstanceEncounterInfo = GetSavedInstanceEncounterInfo
local GetDifficultyInfo = GetDifficultyInfo
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local GameTooltip = GameTooltip

local RAID_INFO_WORLD_BOSS = RAID_INFO_WORLD_BOSS
local BOSS_DEAD = BOSS_DEAD
local BOSS_ALIVE = BOSS_ALIVE
local QUEUE_TIME_UNAVAILABLE = QUEUE_TIME_UNAVAILABLE
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local AddOnName, AddOn = ...
_G[AddOnName] = AddOn

-- local function debug(v)
--   if type(v) == "string" then
--     print("|cff00aeff["..AddOnName.."]:|r "..v)
--   elseif type(v) == "table" then
--     LoadAddOn("Blizzard_DebugTools")
--     print("|cff00aeff["..AddOnName.."]:|r ")
--     DevTools_Dump(v)
--   end
-- end

function AddOn:RequestWarfrontInfo()
  local stromgardeState, darkshoreState

  if UnitFactionGroup("player") == "Horde" then
    self.worldBosses[5].encounters[4].encounterID = 2212
    self.worldBosses[5].encounters[4].questID = 52848
    self.worldBosses[5].encounters[8].encounterID = 2329
    self.worldBosses[5].encounters[8].questID = 54896

    stromgardeState = C_ContributionCollector_GetState(116)
    darkshoreState = C_ContributionCollector_GetState(117)
  else
    self.worldBosses[5].encounters[4].encounterID = 2213
    self.worldBosses[5].encounters[4].questID = 52847
    self.worldBosses[5].encounters[8].encounterID = 2345
    self.worldBosses[5].encounters[8].questID = 54895

    stromgardeState = C_ContributionCollector_GetState(11)
    darkshoreState = C_ContributionCollector_GetState(118)
  end

  self.isStromgardeAvailable = false
  self.isDarkshoreAvailable = false

  if (stromgardeState == Enum_ContributionState.Building or stromgardeState == Enum_ContributionState.Active) and (darkshoreState == Enum_ContributionState.Building or darkshoreState == Enum_ContributionState.Active) then
    self.isStromgardeAvailable = true
    self.isDarkshoreAvailable = true
    self.worldBosses[5].numEncounters = 3
  elseif stromgardeState == Enum_ContributionState.Building or stromgardeState == Enum_ContributionState.Active then
    self.isStromgardeAvailable = true
    self.worldBosses[5].numEncounters = 2
  elseif darkshoreState == Enum_ContributionState.Building or darkshoreState == Enum_ContributionState.Active then
    self.isDarkshoreAvailable = true
    self.worldBosses[5].numEncounters = 2
  end
end

---@param instanceIndex number
---@return string, number, boolean, string, number, number, number
---instanceName, instanceID, locked, difficultyName, numEncounters, numCompleted, difficulty
function AddOn:GetSavedWorldBossInfo(instanceIndex)
  local instanceID = self.worldBosses[instanceIndex].instanceID
  local instanceName = EJ_GetInstanceInfo(instanceID)
  local difficulty = 2
  local locked = false
  local difficultyName = RAID_INFO_WORLD_BOSS
  local numEncounters = self.worldBosses[instanceIndex].numEncounters
  local numCompleted = 0

  self:RequestWarfrontInfo()

  for encounterIndex, encounter in ipairs(self.worldBosses[instanceIndex].encounters) do
    local isDefeated = IsQuestFlaggedCompleted(encounter.questID)
    if instanceIndex == 5 and encounterIndex == 4 then
      isDefeated = isDefeated and self.isStromgardeAvailable
    elseif instanceIndex == 5 and encounterIndex == 8 then
      isDefeated = isDefeated and self.isDarkshoreAvailable
    end
    if isDefeated then
      locked = true
      numCompleted = numCompleted + 1
    end
  end

  return instanceName, instanceID, locked, difficultyName, numEncounters, numCompleted, difficulty
end

---@param instanceIndex number
---@param encounterIndex number
---@return string, boolean
---bossName, isKilled
function AddOn:GetSavedWorldBossEncounterInfo(instanceIndex, encounterIndex)
  if encounterIndex > #self.worldBosses[instanceIndex].encounters then return end

  local bossName
  local isKilled = IsQuestFlaggedCompleted(self.worldBosses[instanceIndex].encounters[encounterIndex].questID)

  if self.worldBosses[instanceIndex].encounters[encounterIndex].name == " " then
    bossName = (select(2, GetAchievementInfo(7333))) -- "The Four Celestials"
  elseif not self.worldBosses[instanceIndex].encounters[encounterIndex].name then
    bossName = EJ_GetEncounterInfo(self.worldBosses[instanceIndex].encounters[encounterIndex].encounterID)
  end

  return bossName, isKilled
end

function AddOn:UpdateSavedInstances()
  self.instancesLockouts = {}

  local savedInstances = GetNumSavedInstances()
  local savedWorldBosses = #self.worldBosses
  local instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, numCompleted, difficulty
  local playerFaction = UnitFactionGroup("player")

  for instanceIndex = 1, savedInstances + savedWorldBosses do
    local encounters = {}
    local encounterIndex = 1

    if instanceIndex <= savedInstances then
      instanceName, instanceID, instanceReset, instanceDifficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, numCompleted = GetSavedInstanceInfo(instanceIndex)
      instanceID = self.instances[tonumber(GetSavedInstanceChatLink(instanceIndex):match(":(%d+)"))]

      if instanceID == 777 then -- Fixes wrong encounters count for Assault on Violet Hold
        numEncounters = 3
      elseif instanceID == 1023 then -- Fixes https://github.com/Meivyn/AdventureGuideLockouts/issues/1
        numEncounters = 4
      end

      local _, _, isHeroic, _, displayHeroic, displayMythic, _, isLFR = GetDifficultyInfo(instanceDifficulty)
      difficulty = 2

      if displayMythic then
        difficulty = 4
      elseif isHeroic or displayHeroic then
        difficulty = 3
      elseif isLFR then
        difficulty = 1
      end

      while GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex) do
        if instanceID == 1023 then -- Fixes https://github.com/Meivyn/AdventureGuideLockouts/issues/1
          if playerFaction == "Alliance" and encounterIndex == 1 or playerFaction == "Horde" and encounterIndex == 2 then
            encounterIndex = encounterIndex + 1
          end
        end
        local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
        tinsert(encounters, {
          bossName = bossName,
          isKilled = isKilled
        })
        encounterIndex = encounterIndex + 1
      end
    else
      instanceName, instanceID, locked, difficultyName, numEncounters, numCompleted, difficulty = self:GetSavedWorldBossInfo(instanceIndex - savedInstances)

      while self:GetSavedWorldBossEncounterInfo(instanceIndex - savedInstances, encounterIndex) do
        local bossName, isKilled = self:GetSavedWorldBossEncounterInfo(instanceIndex - savedInstances, encounterIndex)
        local isAvailable = nil
        if instanceIndex - savedInstances == 5 and encounterIndex == 4 then
          isAvailable = self.isStromgardeAvailable
          isKilled = isKilled and isAvailable
        elseif instanceIndex - savedInstances == 5 and encounterIndex == 8 then
          isAvailable = self.isDarkshoreAvailable
          isKilled = isKilled and isAvailable
        elseif instanceIndex - savedInstances == 5 then
          isAvailable = C_TaskQuest_GetQuestTimeLeftMinutes(self.worldBosses[instanceIndex - savedInstances].encounters[encounterIndex].questID) ~= nil
        end
        tinsert(encounters, {
          bossName = bossName,
          isKilled = isKilled,
          isAvailable = isAvailable
        })
        encounterIndex = encounterIndex + 1
      end
    end

    if locked or extended then
      self.instancesLockouts[instanceID] = self.instancesLockouts[instanceID] or {}
      tinsert(self.instancesLockouts[instanceID], {
        encounters = encounters,
        instanceName = instanceName,
        difficulty = difficulty,
        difficultyName = difficultyName,
        numEncounters = numEncounters,
        numCompleted = numCompleted,
        progress = numCompleted.."/"..numEncounters,
        complete = numCompleted == numEncounters
      })
    end
  end
end

---@param instanceButton frame
---@param difficulty number
---@return frame
---statusFrame
function AddOn:CreateStatusFrame(instanceButton, difficulty)
  local statusFrame = CreateFrame("Frame", nil, instanceButton)
  statusFrame:SetSize(38, 46)
  statusFrame:SetScript("OnEnter", function()
    local info = statusFrame.instanceInfo
    GameTooltip:SetOwner(statusFrame, "ANCHOR_RIGHT")
    if info.numCompleted > 0 then
      GameTooltip:SetText(info.instanceName.." ("..info.difficultyName..")")
      for _, encounter in ipairs(info.encounters) do
        if encounter.isKilled then
          GameTooltip:AddDoubleLine(encounter.bossName, BOSS_DEAD, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
        elseif not encounter.isAvailable and encounter.isAvailable ~= nil then
          GameTooltip:AddDoubleLine(encounter.bossName, QUEUE_TIME_UNAVAILABLE, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        else
          GameTooltip:AddDoubleLine(encounter.bossName, BOSS_ALIVE, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
        end
      end
    end
    GameTooltip:Show()
  end)
  statusFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  statusFrame.texture = statusFrame:CreateTexture(nil, "ARTWORK")
  statusFrame.texture:SetPoint("CENTER")
  statusFrame.texture:SetTexture("Interface\\Minimap\\UI-DungeonDifficulty-Button")
  statusFrame.texture:SetSize(64, 46)

  if difficulty == 4 then
    statusFrame.texture:SetTexCoord(0.25, 0.5, 0.0703125, 0.4296875)
  elseif difficulty == 3 then
    statusFrame.texture:SetTexCoord(0, 0.25, 0.0703125, 0.4296875)
  else
    statusFrame.texture:SetTexCoord(0, 0.25, 0.5703125, 0.9296875)
  end

  local completeFrame = CreateFrame("Frame", nil, statusFrame)
  completeFrame:SetSize(16, 16)

  completeFrame.texture = completeFrame:CreateTexture(nil, "ARTWORK", "GreenCheckMarkTemplate")
  completeFrame.texture:ClearAllPoints()
  completeFrame.texture:SetPoint("CENTER")

  local progressFrame = statusFrame:CreateFontString(nil, nil, "GameFontNormalSmallLeft")

  if difficulty == 1 or difficulty == 2 then
    completeFrame:SetPoint("CENTER", statusFrame, 0, -1)
    progressFrame:SetPoint("CENTER", statusFrame, 0, 5)
  else
    completeFrame:SetPoint("CENTER", statusFrame, 0, -12)
    progressFrame:SetPoint("CENTER", statusFrame, 0, -9)
  end

  statusFrame.completeFrame = completeFrame
  statusFrame.progressFrame = progressFrame

  self.statusFrames[instanceButton:GetName()] = self.statusFrames[instanceButton:GetName()] or {}
  self.statusFrames[instanceButton:GetName()][difficulty] = statusFrame

  return statusFrame
end


---@param instanceButton frame
function AddOn:UpdateStatusFramePosition(instanceButton)
  local savedFrames = self.statusFrames[instanceButton:GetName()]
  local lfrVisible = savedFrames and savedFrames[1] and savedFrames[1]:IsVisible()
  local normalVisible = savedFrames and savedFrames[2] and savedFrames[2]:IsVisible()
  local heroicVisible = savedFrames and savedFrames[3] and savedFrames[3]:IsVisible()
  local mythicVisible = savedFrames and savedFrames[4] and savedFrames[4]:IsVisible()

  if mythicVisible then
    savedFrames[4]:SetPoint("BOTTOMRIGHT", instanceButton, 4, -12)
  end

  if heroicVisible then
    if mythicVisible then
      savedFrames[3]:SetPoint("BOTTOMRIGHT", instanceButton, -28, -12)
    else
      savedFrames[3]:SetPoint("BOTTOMRIGHT", instanceButton, 4, -12)
    end
  end

  if normalVisible then
    if heroicVisible and mythicVisible then
      savedFrames[2]:SetPoint("BOTTOMRIGHT", instanceButton, -60, -23)
    elseif heroicVisible or mythicVisible then
      savedFrames[2]:SetPoint("BOTTOMRIGHT", instanceButton, -28, -23)
    else
      savedFrames[2]:SetPoint("BOTTOMRIGHT", instanceButton, 4, -23)
    end
  end

  if lfrVisible then
    if normalVisible and heroicVisible and mythicVisible then
      savedFrames[1]:SetPoint("BOTTOMRIGHT", instanceButton, -92, -23)
    elseif heroicVisible and mythicVisible or heroicVisible and normalVisible or mythicVisible and normalVisible then
      savedFrames[1]:SetPoint("BOTTOMRIGHT", instanceButton, -60, -23)
    elseif normalVisible or heroicVisible or mythicVisible then
      savedFrames[1]:SetPoint("BOTTOMRIGHT", instanceButton, -28, -23)
    else
      savedFrames[1]:SetPoint("BOTTOMRIGHT", instanceButton, 4, -23)
    end
  end
end

---@param instanceButton frame
function AddOn:UpdateInstanceStatusFrame(instanceButton)
  self.statusFrames = self.statusFrames or {}

  if self.statusFrames[instanceButton:GetName()] then
    for _, frame in pairs(self.statusFrames[instanceButton:GetName()]) do
      frame:Hide()
    end
  end

  local instances = self.instancesLockouts[instanceButton.instanceID]
  if instances == nil then return end

  for _, instance in ipairs(instances) do
    local frame = (self.statusFrames[instanceButton:GetName()] and self.statusFrames[instanceButton:GetName()][instance.difficulty]) or self:CreateStatusFrame(instanceButton, instance.difficulty)
    if instance.complete then
      frame.completeFrame:Show()
      frame.progressFrame:Hide()
      frame:Show()
    elseif instance.progress then
      frame.completeFrame:Hide()
      frame.progressFrame:SetText(instance.progress)
      frame.progressFrame:Show()
      frame:Show()
    else
      frame:Hide()
    end

    frame.instanceInfo = instance
  end
  self:UpdateStatusFramePosition(instanceButton)
end

function AddOn:UpdateFrames()
  local b1 = _G.EncounterJournalInstanceSelectScrollFrameScrollChildInstanceButton1
  if b1 then
    self:UpdateInstanceStatusFrame(b1)
  end
  for i = 1, 100 do
    local b = _G["EncounterJournalInstanceSelectScrollFrameinstance"..i]
    if b then
      self:UpdateInstanceStatusFrame(b)
    end
  end
end

AddOn.eventFrame = CreateFrame("Frame")
AddOn.eventFrame:RegisterEvent("ADDON_LOADED")
AddOn.eventFrame:RegisterEvent("BOSS_KILL")
AddOn.eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
AddOn.eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
  if event == "ADDON_LOADED" and arg1 == "Blizzard_EncounterJournal" then
    self:UnregisterEvent(event)
    _G.EncounterJournal:HookScript("OnShow", function() AddOn:UpdateFrames() end)
    hooksecurefunc("EncounterJournal_ListInstances", function() AddOn:UpdateFrames() end)
  elseif event == "BOSS_KILL" then
    RequestRaidInfo()
  elseif event == "UPDATE_INSTANCE_INFO" then
    AddOn:UpdateSavedInstances()
    AddOn:UpdateFrames()
  end
end)