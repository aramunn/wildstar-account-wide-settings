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

--window selection
local bShowSaveWindow = true

--filters
local strFilterAddonSearch = ""
local bFilterShowCustom = true
local bFilterShowCarbine = false
local strFilterRestoreSearch = ""

--enums
local eColumns = {
  Checkmark = 1,
  Name      = 2,
  Author    = 3,
  
  Title = 1,
  Info = 2,
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

local function InsertAddonInfo(tAddonsList, strAddonName)
  if not strAddonName then return end
  local tAddon = Apollo.GetAddon(strAddonName)
  if tAddon and tAddon.OnSave then
    tAddonInfo = Apollo.GetAddonInfo(strAddonName)
    if not tAddonInfo then return end
    table.insert(tAddonsList, {
      strName = strAddonName,
      strAuthor = tAddonInfo.strAuthor,
      bCarbine = tAddonInfo.bCarbine,
      bSelected = false,
    })
  end
end

local function GetAddonsListFromXml(tAddonsXML, strWildstarDir, strSeperator)
  local tAddonsList = {}
  for idx, tElement in pairs(tAddonsXML) do
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
      InsertAddonInfo(tAddonsList, strAddonName)
    end
  end
  return tAddonsList
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

-------------------
-- display saver --
-------------------

local function SkipAddonRow(tAddonInfo)
  if not bFilterShowCarbine and tAddonInfo.bCarbine then return true end
  if not bFilterShowCustom and not tAddonInfo.bCarbine then return true end
  local strRegex = ".*"..string.lower(strFilterAddonSearch)..".*"
  local strAddonName = string.lower(tAddonInfo.strName)
  if not string.find(strAddonName, strRegex) then return true end
  return false
end

local function AddAddonRow(wndGrid, nIndex, tAddonInfo)
  if SkipAddonRow(tAddonInfo) then return end
  local strAddonName = tAddonInfo.strName
  local strAddonAuthor = tAddonInfo.strAuthor
  local bSelected = tAddonInfo.bSelected
  local strSprite = bSelected and eSprite.Selected or eSprite.Unselected
  local strSortPrefix = bSelected and eSortPrefix.Selected or eSortPrefix.Unselected
  local nRow = wndGrid:AddRow(strAddonName)
  wndGrid:SetCellText(      nRow, eColumns.Checkmark, ""                          )
  wndGrid:SetCellLuaData(   nRow, eColumns.Checkmark, nIndex                      )
  wndGrid:SetCellImage(     nRow, eColumns.Checkmark, strSprite                   )
  wndGrid:SetCellSortText(  nRow, eColumns.Checkmark, strSortPrefix..strAddonName )
  wndGrid:SetCellText(      nRow, eColumns.Name,      "   "..strAddonName         )
  wndGrid:SetCellText(      nRow, eColumns.Author,    "   "..strAddonAuthor       )
end

local function UpdateSaverGrid(wndGrid, tSaverList)
  wndGrid:DeleteAll()
  for idx, tAddonInfo in ipairs(tSaverList) do
    AddAddonRow(wndGrid, idx, tAddonInfo)
  end
end

--------------------
-- display loader --
--------------------

local function SkipRestoreRow(tRestoreInfo)
  local strRegex = ".*"..string.lower(strFilterRestoreSearch)..".*"
  local strRestoreTitle = string.lower(tRestoreInfo.strTitle)
  if not string.find(strRestoreTitle, strRegex) then return true end
  return false
end

local function GenerateRestoreDetails(tRestoreInfo)
  local strDetails = "Addons in set:"
  for idx, tAddonInfo in ipairs(tRestoreInfo.tAddons) do
    strDetails = strDetails.."\n  "..tAddonInfo.strName
  end
  return strDetails
end

local function AddRestoreRow(wndGrid, idx, tRestoreInfo)
  if SkipRestoreRow(tRestoreInfo) then return end
  local strRestoreTitle = tRestoreInfo.strTitle
  local strRestoreInfo = tostring(#tRestoreInfo.tAddons)
  local strRestoreDetails = GenerateRestoreDetails(tRestoreInfo)
  local nRow = wndGrid:AddRow(strRestoreTitle)
  wndGrid:SetCellText(    nRow, eColumns.Title, "   "..strRestoreTitle  )
  wndGrid:SetCellText(    nRow, eColumns.Info, "   "..strRestoreInfo    )
  wndGrid:SetCellLuaData( nRow, eColumns.Info, strRestoreDetails        )
end

local function UpdateLoaderGrid(wndGrid, tLoaderList)
  wndGrid:DeleteAll()
  for idx, tRestoreInfo in ipairs(tLoaderList) do
    AddRestoreRow(wndGrid, idx, tRestoreInfo)
  end
end

---------------------
-- display general --
---------------------

function AccountWideSettings:UpdateDisplay()
  if bShowSaveWindow then
    UpdateSaverGrid(self.wndSaveGrid, self.tAddonsList)
  else
    UpdateLoaderGrid(self.wndLoadGrid, self.tSave)
  end
end

function AccountWideSettings:LoadMainWindow()
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Invoke()
  else
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "Main", nil, self)
    self.wndMain:FindChild("OpenSaveWindow"):SetCheck(bShowSaveWindow)
    self.wndMain:FindChild("OpenLoadWindow"):SetCheck(not bShowSaveWindow)
    self.wndSaveGrid = self.wndMain:FindChild("SaveWindow:Grid")
    self.wndMain:FindChild("ShowCustom"):SetCheck(bFilterShowCustom)
    self.wndMain:FindChild("ShowCarbine"):SetCheck(bFilterShowCarbine)
    self.wndLoadGrid = self.wndMain:FindChild("LoadWindow:Grid")
    self.tAddonsList = self.tAddonsList or GetAddonsList() or {}
    self.tSave = self.tSave or {}
  end
  self:UpdateDisplay()
end

---------------
-- ui events --
---------------

function AccountWideSettings:OnSaveWindowSelect(wndHandler, wndControl)
  self.wndMain:FindChild("SaveWindow"):Show(true, true)
  self.wndMain:FindChild("LoadWindow"):Show(false, true)
  bShowSaveWindow = true
  self:UpdateDisplay()
end

function AccountWideSettings:OnLoadWindowSelect(wndHandler, wndControl)
  self.wndMain:FindChild("SaveWindow"):Show(false, true)
  self.wndMain:FindChild("LoadWindow"):Show(true, true)
  bShowSaveWindow = false
  self:UpdateDisplay()
end

function AccountWideSettings:OnSaveGridSelChanged(wndHandler, wndControl, nRow, nCol)
  if nCol ~= eColumns.Checkmark then return end
  local nIndex = wndControl:GetCellData(nRow, eColumns.Checkmark)
  local bSelected = not self.tAddonsList[nIndex].bSelected
  local strSprite = bSelected and eSprite.Selected or eSprite.Unselected
  local strSortPrefix = bSelected and eSortPrefix.Selected or eSortPrefix.Unselected
  local strAddon = self.tAddonsList[nIndex].strName
  wndControl:SetCellLuaData(  nRow, eColumns.Checkmark, bSelected               )
  wndControl:SetCellImage(    nRow, eColumns.Checkmark, strSprite               )
  wndControl:SetCellSortText( nRow, eColumns.Checkmark, strSortPrefix..strAddon )
  self.tAddonsList[nIndex].bSelected = bSelected
end

function AccountWideSettings:OnSaveSearchChanged(wndHandler, wndControl, strText)
  strFilterAddonSearch = strText or ""
  self:UpdateDisplay()
end

function AccountWideSettings:OnShowCustomChange(wndHandler, wndControl)
  bFilterShowCustom = wndControl:IsChecked()
  self:UpdateDisplay()
end

function AccountWideSettings:OnShowCarbineChange(wndHandler, wndControl)
  bFilterShowCarbine = wndControl:IsChecked()
  self:UpdateDisplay()
end

function AccountWideSettings:OnLoadGridSelChanged(wndHandler, wndControl, nRow, nCol)
end

function AccountWideSettings:OnLoadGridGenerateTooltip(wndHandler, wndControl, eType, iRow, iColumn)
  local strTooltip = ""
  if iColumn + 1 == eColumns.Info then
    strTooltip = self.wndLoadGrid:GetCellData(iRow + 1, eColumns.Info)
  end
  wndHandler:SetTooltip(strTooltip)
end

function AccountWideSettings:OnLoadSearchChanged(wndHandler, wndControl, strText)
  strFilterRestoreSearch = strText or ""
  self:UpdateDisplay()
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
  local tData = {"AccountWideSettingsInterfaceMenu", "", "BK3:sprHolo_Friends_Account"}
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "AccountWideSettings", tData)
end

local AccountWideSettingsInst = AccountWideSettings:new()
AccountWideSettingsInst:Init()
