require "Window"

local AccountWideSettings = {}

local karrAddons = {
  "ChatLog",
  "CurrencyCount",
  "DarkMeter",
  "DiscoTelegraphs",
  "FrostMod_ThreatBall",
  "GotHUD",
  "Healie",
  "Interruptor",
  "OhmnaHelper",
  "PurchaseConfirmation",
  "TapThat",
  "tLoot",
  -- "Translator",
  "ZenScan",
}

-- function AccountWideSettings:Command(strCmd, strParam)
  -- if strParam == "save" then
    -- local tSave = {}
    -- for idx, strAddon in ipairs(karrAddons) do
      -- local addon = Apollo.GetAddon(strAddon)
      -- if not addon then
        -- Print("AWS: couldn't find \""..strAddon.."\"")
        -- return
      -- end
      -- tSave[strAddon] = {}
      -- for _, eLevel in pairs(GameLib.CodeEnumAddonSaveLevel) do
        -- tSave[strAddon][eLevel] = addon:OnSave(eLevel)
      -- end
    -- end
    -- self.tSave = tSave
    -- Print("AWS: saved")
  -- end
  -- if strParam == "load" then
    -- for idx, strAddon in ipairs(karrAddons) do
      -- local addon = Apollo.GetAddon(strAddon)
      -- addon.OnSave = function(ref, eLevel)
        -- return self.tSave[strAddon][eLevel]
      -- end
    -- end
    -- Print("AWS: loaded - reloadui to apply")
  -- end
-- end

function AccountWideSettings:LoadMainWindow()
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "Main", nil, self)
  local wndList = self.wndMain:FindChild("List")
  local wndItem = Apollo.LoadForm(self.xmlDoc, "Item", wndList, self)
  wndItem:FindChild("Name"):SetText("Blah Blah Blah")
end

function AccountWideSettings:OnSave(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return nil end
  return self.tSave
end

function AccountWideSettings:OnRestore(eLevel, tSave)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return end
  self.tSave = tSave
end

function AccountWideSettings:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function AccountWideSettings:Init()
  Apollo.RegisterAddon(self)
end

function AccountWideSettings:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("AccountWideSettings.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function AccountWideSettings:OnDocumentReady()
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuLoaded", self)
  Apollo.RegisterEventHandler("AccountWideSettingsInterfaceMenu", "LoadMainWindow", self)
  Apollo.RegisterSlashCommand("accountwidesettings", "LoadMainWindow", self)
  Apollo.RegisterSlashCommand("aws", "LoadMainWindow", self)
end

function AccountWideSettings:OnInterfaceMenuLoaded()
  local tData = {"AccountWideSettingsInterfaceMenu", "", "CRB_CurrencySprites:sprCashPlatinum"}
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "AccountWideSettings", tData)
end

local AccountWideSettingsInst = AccountWideSettings:new()
AccountWideSettingsInst:Init()
