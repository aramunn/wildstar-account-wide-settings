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

--filters
local strFilterSearch = ""
local bFilterShowCarbine = false
local bFilterShowCustom = true
local bFilterShowSelected = true
local bFilterShowUnselected = true

--enums
local eColumns = {
  Checkmark = 1,
  Name      = 2,
  Author    = 3,
}
local eSortPrefix = {
  Selected    = "1",
  Unselected  = "2",
}
local eSprite = {
  Selected    = "CRB_DialogSprites:sprDialog_Icon_Check",
  Unselected  = "CRB_DialogSprites:sprDialog_Icon_DisabledCheck",
}

-------------------
-- addon parsing --
-------------------

local function InsertAddonInfo(tAddonList, strAddonName)
  if not strAddonName then return end
  local tAddon = Apollo.GetAddon(strAddonName)
  if tAddon and tAddon.OnSave then
    tAddonAllInfo = Apollo.GetAddonInfo(strAddonName)
    if not tAddonAllInfo then return end
    table.insert(tAddonList, {
      strName = strAddonName,
      strAuthor = tAddonAllInfo.strAuthor,
      bCarbine = tAddonAllInfo.bCarbine,
    })
  end
end

local function GetAddonsListFromXml(tAddonXML, strWildstarDir, strSeperator)
  local tAddonList = {}
  for idx, tElement in pairs(tAddonXML) do
    if tElement.__XmlNode == "Addon" then
      local strAddonName
      if tElement.Carbine == "1" then
        strAddonName = tElement.Folder
      else
        local xmlTOC = XmlDoc.CreateFromFile(
          strWildstarDir..strSeperator.."Addons"..strSeperator..tElement.Folder..strSeperator.."toc.xml"
        )
        if xmlTOC then strAddonName = xmlTOC:ToTable().Name end
      end
      InsertAddonInfo(tAddonList, strAddonName)
    end
  end
  return tAddonList
end

local function GetAddonsList()
  local strAssetFolder = Apollo.GetAssetFolder()
  if not strAssetFolder then
    Print("AWS: failed to get asset folder")
    return nil
  end
  local strWildstarDir, strSeperator = string.match(strAssetFolder, "(.-)([\\/])[Aa][Dd][Dd][Oo][Nn][Ss]")
  if not strWildstarDir or not strSeperator then
    Print("AWS: failed to parse path ("..strAssetFolder..")")
    return nil
  end
  local strAddonsXml = strWildstarDir..strSeperator.."Addons.xml"
  local xmlAddons = XmlDoc.CreateFromFile(strAddonsXml)
  local tAddonsXML = xmlAddons and xmlAddons:ToTable() or nil
  if not tAddonsXML then
    Print("AWS: failed to find Addons.xml")
    return nil
  end
  return GetAddonsListFromXml(tAddonsXML, strWildstarDir, strSeperator)
end

-------------
-- display --
-------------

local function SetupRow(wndGrid, tAddonInfo)
  local nRow = wndGrid:AddRow(tAddonInfo.strName)
  wndGrid:SetCellText(      nRow, eColumns.Checkmark, ""                                          )
  wndGrid:SetCellLuaData(   nRow, eColumns.Checkmark, false                                       )
  wndGrid:SetCellImage(     nRow, eColumns.Checkmark, eSprite.Unselected                          )
  wndGrid:SetCellSortText(  nRow, eColumns.Checkmark, eSortPrefix.Unselected..tAddonInfo.strName  )
  wndGrid:SetCellText(      nRow, eColumns.Name,      "   "..tAddonInfo.strName                   )
  wndGrid:SetCellLuaData(   nRow, eColumns.Name,      tAddonInfo.strName                          )
  wndGrid:SetCellText(      nRow, eColumns.Author,    "   "..tAddonInfo.strAuthor                 )
end

function AccountWideSettings:LoadMainWindow()
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Invoke()
    return
  end
  self.tAddonList = self.tAddonList or GetAddonsList()
  if not self.tAddonList then return end
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "Main", nil, self)
  local wndGrid = self.wndMain:FindChild("Grid")
  for idx, tAddonInfo in ipairs(self.tAddonList) do
    SetupRow(wndGrid, tAddonInfo)
  end
end

---------------
-- ui events --
---------------

function AccountWideSettings:OnGridSelChanged(wndHandler, wndControl, nRow, nCol)
  if nCol ~= eColumns.Checkmark then return end
  local bSelected = not wndControl:GetCellData(nRow, eColumns.Checkmark)
  local strSprite = bSelected and eSprite.Selected or eSprite.Unselected
  local strSortPrefix = bSelected and eSortPrefix.Selected or eSortPrefix.Unselected
  local strAddon = wndControl:GetCellText(nRow, eColumns.Name) or ""
  wndControl:SetCellLuaData(  nRow, eColumns.Checkmark, bSelected               )
  wndControl:SetCellImage(    nRow, eColumns.Checkmark, strSprite               )
  wndControl:SetCellSortText( nRow, eColumns.Checkmark, strSortPrefix..strAddon )
end

------------------
-- data storage --
------------------

function AccountWideSettings:OnSave(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return nil end
  return self.tSave
end

function AccountWideSettings:OnRestore(eLevel, tSave)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then return end
  self.tSave = tSave
end

----------
-- init --
----------

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
  local tData = {"AccountWideSettingsInterfaceMenu", "", "CRB_CurrencySprites:sprCashPlatinum"} --TODO
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "AccountWideSettings", tData)
end

local AccountWideSettingsInst = AccountWideSettings:new()
AccountWideSettingsInst:Init()
