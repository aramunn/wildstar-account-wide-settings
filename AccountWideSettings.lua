require "Window"

local AccountWideSettings = {}

--selection
local bShowSaveWindow = true
local nSaverNumSelected = 0
local nLoaderIndex = 0

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
  Info  = 2,
}
local eSortPrefix = {
  Selected    = "1",
  Unselected  = "2",
}
local eSprite = {
  Selected    = "CRB_DialogSprites:sprDialog_Icon_Check",
  Unselected  = "CRB_DialogSprites:sprDialog_Icon_DisabledCheck",
}

---------------
-- the magic --
---------------

local function GetAddonSaveData(strAddonName)
  local addon = Apollo.GetAddon(strAddonName)
  local tData = {}
  for _, eLevel in pairs(GameLib.CodeEnumAddonSaveLevel) do
    tData[eLevel] = addon:OnSave(eLevel)
  end
  return tData
end

local function SetAddonSaveData(strAddonName)
  local addon = Apollo.GetAddon(strAddonName)
  if not addon then return false end
  addon.OnSave = function(ref, eLevel)
    return tAddonInfo.tData[eLevel]
  end
  return true
end

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

local function AddRestoreRow(wndGrid, nIndex, tRestoreInfo)
  if SkipRestoreRow(tRestoreInfo) then return end
  local strRestoreTitle = tRestoreInfo.strTitle
  local strRestoreInfo = tostring(#tRestoreInfo.tAddons)
  local strRestoreDetails = GenerateRestoreDetails(tRestoreInfo)
  local nRow = wndGrid:AddRow(strRestoreTitle)
  wndGrid:SetCellText(    nRow, eColumns.Title, "   "..strRestoreTitle  )
  wndGrid:SetCellLuaData( nRow, eColumns.Title, nIndex                  )
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

function AccountWideSettings:InitializeReferences()
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "Main", nil, self)
  self.wndSaveGrid = self.wndMain:FindChild("SaveWindow:Grid")
  self.wndCreateButton = self.wndMain:FindChild("SaveWindow:CreateSet")
  self.wndNaming = self.wndCreateButton:FindChild("NamingWindow")
  self.wndLoadGrid = self.wndMain:FindChild("LoadWindow:Grid")
  self.wndDeleteButton = self.wndMain:FindChild("LoadWindow:DeleteSet")
  self.wndRestoreButton = self.wndMain:FindChild("LoadWindow:RestoreSet")
  self.wndConfirm = self.wndMain:FindChild("ConfirmWindow")
  self.wndConfirmButton = self.wndConfirm:FindChild("Confirm")
  self.wndConfirmText = self.wndConfirm:FindChild("Text")
  self.wndConfirmGrid = self.wndConfirm:FindChild("Grid")
  self.wndDetails = self.wndMain:FindChild("DetailsWindow")
  self.tAddonsList = self.tAddonsList or GetAddonsList() or {}
  self.tSave = self.tSave or {}
end

function AccountWideSettings:InitializeStates()
  self.wndMain:FindChild("OpenSaveWindow"):SetCheck(bShowSaveWindow)
  self.wndMain:FindChild("OpenLoadWindow"):SetCheck(not bShowSaveWindow)
  self.wndMain:FindChild("ShowCustom"):SetCheck(bFilterShowCustom)
  self.wndMain:FindChild("ShowCarbine"):SetCheck(bFilterShowCarbine)
  self.wndCreateButton:Enable(nSaverNumSelected > 0)
  self.wndDeleteButton:Enable(nLoaderIndex > 0)
  self.wndRestoreButton:Enable(nLoaderIndex > 0)
  self.wndNaming:FindChild("SaveSetName"):SetPrompt("Enter a name for this Save Set")
end

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
    self:InitializeReferences()
    self:InitializeStates()
  end
  self:UpdateDisplay()
end

-----------------------
-- general ui events --
-----------------------

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

---------------------
-- saver ui events --
---------------------

function AccountWideSettings:OnSaveGridSelChanged(wndHandler, wndControl, nRow, nCol)
  if nCol ~= eColumns.Checkmark then return end
  local nIndex = wndControl:GetCellData(nRow, eColumns.Checkmark)
  local bSelected = not self.tAddonsList[nIndex].bSelected
  local strSprite = bSelected and eSprite.Selected or eSprite.Unselected
  local strSortPrefix = bSelected and eSortPrefix.Selected or eSortPrefix.Unselected
  local strAddon = self.tAddonsList[nIndex].strName
  wndControl:SetCellImage(    nRow, eColumns.Checkmark, strSprite               )
  wndControl:SetCellSortText( nRow, eColumns.Checkmark, strSortPrefix..strAddon )
  self.tAddonsList[nIndex].bSelected = bSelected
  nSaverNumSelected = nSaverNumSelected + (bSelected and 1 or -1)
  self.wndCreateButton:Enable(nSaverNumSelected > 0)
end

function AccountWideSettings:OnSaveGridDoubleClick(wndHandler, wndControl, nRow, nCol)
  local nIndex = wndControl:GetCellData(nRow, eColumns.Checkmark)
  local strAddonName = self.tAddonsList[nIndex].strName
  self:ShowDetailsWindow(strAddonName)
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

function AccountWideSettings:OnCreateSaveSet(wndHandler, wndControl)
  self.wndNaming:Show(true, true)
  self.wndNaming:FindChild("SaveSetName"):SetFocus()
end

function AccountWideSettings:OnSaveSetNamingEscape(wndHandler, wndControl)
  self.wndNaming:Show(false, true)
end

function AccountWideSettings:OnSaveSetNamingReturn(wndHandler, wndControl, strText)
  if not strText or strText == "" then
    self:OnCreateSaveSet()
    return
  end
  self.wndNaming:Show(false, true)
  self:ShowConfirmCreate(strText)
end

----------------------
-- loader ui events --
----------------------

function AccountWideSettings:OnLoadGridSelChanged(wndHandler, wndControl, nRow, nCol)
  nLoaderIndex = wndControl:GetCellData(nRow, eColumns.Title)
  self.wndDeleteButton:Enable(nLoaderIndex > 0)
  self.wndRestoreButton:Enable(nLoaderIndex > 0)
end

function AccountWideSettings:OnLoadGridGenerateTooltip(wndHandler, wndControl, eType, iRow, iColumn)
  local strTooltip = ""
  if iColumn + 1 == eColumns.Info then
    strTooltip = self.wndLoadGrid:GetCellData(iRow + 1, eColumns.Info) or ""
  end
  wndHandler:SetTooltip(strTooltip)
end

function AccountWideSettings:OnLoadSearchChanged(wndHandler, wndControl, strText)
  nLoaderIndex = 0
  strFilterRestoreSearch = strText or ""
  self:UpdateDisplay()
end

function AccountWideSettings:OnDeleteSaveSet(wndHandler, wndControl)
  self:ShowConfirmDelete(nLoaderIndex)
end

function AccountWideSettings:OnRestoreSaveSet(wndHandler, wndControl)
  self:ShowConfirmRestore(nLoaderIndex)
end

-----------------------
-- confirm ui events --
-----------------------

function AccountWideSettings:OnConfirmGridDoubleClick(wndHandler, wndControl, nRow, nCol)
  local tActionData = self.wndConfirmButton:GetData()
  if not tActionData or not tActionData.tData.tAddons then return end
  local tAddonInfo = tActionData.tData.tAddons[nRow]
  local strAddonName = tAddonInfo.strName
  local tData = tAddonInfo.tData
  self:ShowDetailsWindow(strAddonName, tData)
end

function AccountWideSettings:SetConfirmDetails(strAction, strTitle, tAddons)
  local strText = strAction.." Save Set \""..strTitle.."\" that contains the following addons?"
  self.wndConfirmText:SetText(strText)
  self.wndConfirmGrid:DeleteAll()
  for idx, tAddonInfo in ipairs(tAddons) do
    self.wndConfirmGrid:AddRow(tAddonInfo.strName)
  end
end

function AccountWideSettings:ShowConfirmCreate(strTitle)
  local tAddons = {}
  for idx, tAddonInfo in ipairs(self.tAddonsList) do
    if tAddonInfo.bSelected then
      local strAddonName = tAddonInfo.strName
      local tData = GetAddonSaveData(strAddonName)
      table.insert(tAddons, {
        strName = strAddonName,
        tData = tData,
      })
    end
  end
  if #tAddons == 0 then return end
  self:SetConfirmDetails("Create", strTitle, tAddons)
  self.wndConfirmButton:SetData({
    funcAction = self.OnConfirmCreate,
    tData = {
      strTitle = strTitle,
      tAddons = tAddons,
    },
  })
  self.wndConfirmButton:SetText("Confirm Create")
  self.wndConfirm:Show(true, true)
end

function AccountWideSettings:ShowConfirmDelete(nLoaderIndex)
  local tRestoreInfo = self.tSave[nLoaderIndex]
  self:SetConfirmDetails("Delete", tRestoreInfo.strTitle, tRestoreInfo.tAddons)
  self.wndConfirmButton:SetData({
    funcAction = self.OnConfirmDelete,
    tData = {
      nIndex = nLoaderIndex
    },
  })
  self.wndConfirmButton:SetText("Confirm Delete")
  self.wndConfirm:Show(true, true)
end

function AccountWideSettings:ShowConfirmRestore(nLoaderIndex)
  local tRestoreInfo = self.tSave[nLoaderIndex]
  self:SetConfirmDetails("Restore", tRestoreInfo.strTitle, tRestoreInfo.tAddons)
  self.wndConfirmButton:SetData({
    funcAction = self.OnConfirmRestore,
    tData = {
      nIndex = nLoaderIndex
    },
  })
  self.wndConfirmButton:SetText("Confirm Restore\n(Reloads UI)")
  self.wndConfirm:Show(true, true)
end

function AccountWideSettings:OnConfirmCancel(wndHandler, wndControl)
  self.wndConfirm:Show(false, true)
end

function AccountWideSettings:OnConfirmConfirm(wndHandler, wndControl)
  local tFuncData = wndControl:GetData()
  tFuncData.funcAction(self, tFuncData.tData)
  self:OnConfirmCancel()
end

function AccountWideSettings:OnConfirmCreate(tData)
  table.insert(self.tSave, tData)
end

function AccountWideSettings:OnConfirmDelete(tData)
  table.remove(self.tSave, tData.nIndex)
  self:UpdateDisplay()
end

function AccountWideSettings:OnConfirmRestore(tData)
  local tRestoreInfo = self.tSave[tData.nIndex]
  for idx, tAddonInfo in ipairs(tRestoreInfo.tAddons) do
    local strAddonName = tAddonInfo.strName
    if not SetAddonSaveData(strAddonName) then
      Print("AWS: Skipped "..strAddonName..". Is it installed/loaded?")
    end
  end
  RequestReloadUI()
end

-----------------------
-- details ui events --
-----------------------

local function DrillDown(wndTree, nodeBase, data)
  if type(data) ~= "table" then
    wndTree:AddNode(nodeBase, tostring(data))
    return
  end
  for k,v in pairs(data) do
    local node = wndTree:AddNode(nodeBase, tostring(k))
    DrillDown(wndTree, node, v)
  end
end

function AccountWideSettings:ShowDetailsWindow(strAddonName, tData)
  self.wndDetails:Show(true, true)
  tData = tData or GetAddonSaveData(strAddonName)
  local wndTree = self.wndDetails:FindChild("Details")
  wndTree:DeleteAll()
  local nodeBase = wndTree:AddNode(0, strAddonName)
  for strLevel, eLevel in pairs(GameLib.CodeEnumAddonSaveLevel) do
    if tData[eLevel] then
      local nodeLevel = wndTree:AddNode(nodeBase, strLevel)
      DrillDown(wndTree, nodeLevel, tData[eLevel])
    end
  end
end

function AccountWideSettings:OnDetailsClose(wndHandler, wndControl)
  self.wndDetails:Show(false, true)
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
