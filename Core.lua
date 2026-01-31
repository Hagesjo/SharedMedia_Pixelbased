local ADDON, ns = ...

-- ================== Config ==================
local DEFAULT_BREAK_MINUTES = 10      -- used if BigWigs line has no minutes
local PREFIX = "PixelMemes"           -- our addon comm prefix
local GAP = 10

-- SavedVariables defaults
PixelMemesDB = PixelMemesDB or {
  scale = 1.0,
  point = nil,
}

-- ---- Sizes ----
local IMAGE_SIZE  = 520
local FRAME_W, FRAME_H = IMAGE_SIZE, IMAGE_SIZE

local function PlayerName()
  local n = UnitName("player")
  return n
end

local function GetGroupChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  elseif IsInRaid() then
    return "RAID"
  elseif IsInGroup() then
    return "PARTY"
  end
  return nil
end

-- Try to extract minutes from arbitrary chat lines
local function ExtractMinutesFromMessage(msg)
  if not msg or msg == "" then return nil end
  local s = msg:lower()
  return tonumber(s:match("break%W+for%W+(%d+)"))
      or tonumber(s:match("(%d+)%s*minutes"))
      or tonumber(s:match("(%d+)%s*minute"))
      or tonumber(s:match("(%d+)%s*mins"))
      or tonumber(s:match("(%d+)%s*min"))
      or tonumber(s:match("in%W+(%d+)%s*min"))
      or tonumber(s:match("(%d+)%s*%f[%a]m%f[%A]"))
end

-- ================== UI ==================
local f = CreateFrame("Frame", "PixelMemesFrame", UIParent, "BackdropTemplate")
f:SetSize(FRAME_W, FRAME_H)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:Hide()

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, relPoint, x, y = self:GetPoint(1)
  PixelMemesDB.point = {point, relPoint, x, y}
end)

local function ApplySavedLayout()
  f:ClearAllPoints()
  if PixelMemesDB.point then
    local p, rp, x, y = unpack(PixelMemesDB.point)
    f:SetPoint(p, UIParent, rp, x, y)
  else
    f:SetPoint("CENTER")
  end
  f:SetScale(PixelMemesDB.scale or 1.0)
end

-- Image texture fills the frame
local tex = f:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints(f)
tex:SetTexCoord(0, 1, 0, 1)

-- Title above image
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("BOTTOM", tex, "TOP", 0, 40)
title:SetJustifyH("CENTER")
title:SetText("Break Time!")
do
  local font, _, flags = title:GetFont()
  title:SetFont(font, 45, flags)
end

-- Timer just below title
local timerText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
timerText:SetPoint("TOP", title, "BOTTOM", 0, -5)
timerText:SetJustifyH("CENTER")
timerText:SetText("")
do
  local font, _, flags = timerText:GetFont()
  timerText:SetFont(font, 30, flags)
end

-- Close button
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)

-- Scale slider
local slider = CreateFrame("Slider", "PixelMemesScaleSlider", UIParent, "OptionsSliderTemplate")
slider:SetWidth(300)
slider:SetMinMaxValues(0.5, 2.0)
slider:SetValueStep(0.05)
slider:SetObeyStepOnDrag(true)
slider:SetPoint("TOP", f, "BOTTOM", 0, -20)
slider:Hide()
_G[slider:GetName().."Low"]:SetText("0.5x")
_G[slider:GetName().."High"]:SetText("2.0x")
_G[slider:GetName().."Text"]:SetText("Scale")

slider:SetScript("OnValueChanged", function(self, value)
  value = math.max(0.5, math.min(2.0, tonumber(value) or 1))
  f:SetScale(value)
  PixelMemesDB.scale = value
end)

f:HookScript("OnShow", function()
  slider:SetValue(PixelMemesDB.scale or 1.0)
  slider:Show()
end)
f:HookScript("OnHide", function() slider:Hide() end)

f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function(self, delta)
  if IsControlKeyDown() then
    local v = (PixelMemesDB.scale or 1.0) + (delta > 0 and 0.05 or -0.05)
    v = math.max(0.5, math.min(2.0, v))
    slider:SetValue(v)
  end
end)

-- ================== Logic ==================
local endTime, running = 0, false

local function pickRandomMeme()
  if type(PixelMemes_List) ~= "table" or #PixelMemes_List == 0 then
    tex:SetTexture("Interface\\FriendsFrame\\Battlenet-Portrait")
    return
  end
  local idx = math.random(1, #PixelMemes_List)
  tex:SetTexture(PixelMemes_List[idx])
end

local function formatTime(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  local m = math.floor(sec / 60)
  local s = sec % 60
  return string.format("%02d:%02d", m, s)
end

local function StartBreak(minutes, startedBy)
  minutes = tonumber(minutes)
  if not minutes or minutes <= 0 then return end
  pickRandomMeme()
  ApplySavedLayout()
  f:Show()
  endTime = GetTime() + (minutes * 60)
  running = true
end

f:SetScript("OnUpdate", function(self)
  if running then
    local remaining = endTime - GetTime()
    if remaining <= 0 then
      running = false
      timerText:SetText("00:00")
      PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
      self:Hide()
    else
      timerText:SetText(formatTime(remaining))
    end
  end
end)

-- ================== Slash command ==================
SLASH_BREAKMEMES1 = "/bmeme"
SlashCmdList["BREAKMEMES"] = function(msg)
  local minutes = tonumber(msg)
  if not minutes or minutes <= 0 then
    return
  end
  StartBreak(minutes, PlayerName())

  local chan = GetGroupChannel()
  if chan and C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX) then
    C_ChatInfo.SendAddonMessage(PREFIX, tostring(minutes), chan)
  end
end

SLASH_BREAKMEMESHIDE1 = "/breakhide"
SlashCmdList["BREAKMEMESHIDE"] = function()
  f:Hide()
  running = false
end

-- ================== Hooks (if DBM/BigWigs are installed locally) ==================
local function SetupDBMHook()
  if not _G.DBM then return end
  if type(_G.DBM.RegisterCallback) == "function" then
    _G.DBM:RegisterCallback("DBM_TimerStart", function(_, id, label, timer)
      local txt = type(label) == "string" and label:lower() or ""
      if txt:find("%f[%a]break%f[%A]") then
        local mins = math.max(1, math.floor((tonumber(timer) or 0) / 60 + 0.5))
        StartBreak(mins, "DBM")
      end
    end)
  end
  if type(_G.DBM.CreateBreakTimer) == "function" then
    hooksecurefunc(_G.DBM, "CreateBreakTimer", function(_, mins)
      mins = tonumber(mins) or DEFAULT_BREAK_MINUTES
      if mins > 0 then
        StartBreak(mins, "DBM")
      end
    end)
  end
  if type(_G.DBM.CreatePizzaTimer) == "function" then
    hooksecurefunc(_G.DBM, "CreatePizzaTimer", function(_, seconds, text)
      local txt = type(text) == "string" and text:lower() or ""
      if txt:find("%f[%a]break%f[%A]") then
        local mins = math.max(1, math.floor((tonumber(seconds) or 0) / 60 + 0.5))
        StartBreak(mins, "DBM")
      end
    end)
  end
end

local function SetupBigWigsHook()
  local BW = _G.BigWigs
  if not BW or type(BW.RegisterMessage) ~= "function" then return end

  BW:RegisterMessage("BigWigs_StartBreak", function(_, _, seconds, nick)
    local secs = tonumber(seconds) or (DEFAULT_BREAK_MINUTES * 60)
    local mins = math.max(1, math.floor(secs / 60 + 0.5))
    StartBreak(mins, nick and nick:gsub("-.*","") or "BigWigs")
  end)

  BW:RegisterMessage("BigWigs_StopBreak", function()
    if running then running = false f:Hide() end
  end)

  BW:RegisterMessage("BigWigs_PluginComm", function(_, msg, seconds, sender)
    if msg == "Break" and seconds then
      local secs = tonumber(seconds)
      if secs then
        local mins = math.max(1, math.floor(secs / 60 + 0.5))
        StartBreak(mins, sender and sender:gsub("-.*","") or "BigWigs")
      end
    end
  end)
end

-- ================== Events (including chat + addon comm fallbacks) ==================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("CHAT_MSG_RAID")
ev:RegisterEvent("CHAT_MSG_RAID_WARNING")
ev:RegisterEvent("CHAT_MSG_PARTY")
ev:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
ev:RegisterEvent("CHAT_MSG_SAY")
ev:RegisterEvent("CHAT_MSG_YELL")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    ApplySavedLayout()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
      C_ChatInfo.RegisterAddonMessagePrefix("D4")
      C_ChatInfo.RegisterAddonMessagePrefix("D4C")
      C_ChatInfo.RegisterAddonMessagePrefix("D5")
      C_ChatInfo.RegisterAddonMessagePrefix("D5C")
      C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
    end
    SetupDBMHook()
    SetupBigWigsHook()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    SetupDBMHook()
    SetupBigWigsHook()
    return
  end

  if event == "ADDON_LOADED" then
    local name = ...
    if name == "DBM-Core" or name == "DBM" then
      SetupDBMHook()
    elseif name == "BigWigs" or name == "BigWigs_Core" then
      SetupBigWigsHook()
    end
    return
  end

  if event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    sender = sender and sender:gsub("-.*","") or "?"
    if not prefix or not message then return end

    if prefix == PREFIX then
      local m = tonumber(message)
      if m and m > 0 and sender ~= PlayerName() then
        StartBreak(m, sender)
      end
      return
    end

    if (prefix == "D4" or prefix == "D4C" or prefix == "D5" or prefix == "D5C") and message then
      local _, _, code, secs = strsplit("\t", message)
      if code == "BT" then
        local s = tonumber(secs)
        if s and s > 0 then
          local mins = math.max(1, math.floor(s / 60 + 0.5))
          StartBreak(mins, sender)
        end
      end
      return
    end

    if prefix == "BigWigs" and message then
      local msg, secs, nick = strsplit("\t", message)
      if msg == "Break" and secs then
        local s = tonumber(secs)
        if s and s > 0 then
          local mins = math.max(1, math.floor(s / 60 + 0.5))
          StartBreak(mins, (nick and nick:gsub("-.*","")) or sender)
        end
      end
      return
    end
    return
  end

  local msg, author = ...
  if not msg then return end
  local lower = msg:lower()
  if not lower:find("%f[%a]break%f[%A]") then return end

  local mins = ExtractMinutesFromMessage(msg)
  if mins and mins > 0 then
    author = author and author:gsub("-.*","") or author
    StartBreak(mins, author)
    return
  end

  if lower:find("bigwigs") and (lower:find("break timer") or lower:find("sending a break")) then
    author = author and author:gsub("-.*","") or author
    StartBreak(DEFAULT_BREAK_MINUTES, author)
    return
  end
  if lower:find("break") and (lower:find("started") or lower:find("initiated") or lower:find("timer")) then
    author = author and author:gsub("-.*","") or author
    StartBreak(DEFAULT_BREAK_MINUTES, author)
    return
  end
end)
