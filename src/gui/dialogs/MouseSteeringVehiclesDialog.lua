--
-- MouseSteeringVehiclesDialog
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringVehiclesDialog = {
  CONTROLS = {
    "backButton",
    "toggleButton",
    "deleteAllButton",
    "syncButton",
    "smoothListLayout",
    "vehiclesList",
    "messageBackground",
  },
}

local MouseSteeringVehiclesDialog_mt = Class(MouseSteeringVehiclesDialog, MessageDialog)

function MouseSteeringVehiclesDialog.new(target, customMt, gui, i18n)
  local self = MouseSteeringVehiclesDialog:superClass().new(target, customMt or MouseSteeringVehiclesDialog_mt)

  self.gui = gui
  self.i18n = i18n

  -- Registers the gui elements that should be accessible via script
  self:registerControls(MouseSteeringVehiclesDialog.CONTROLS)

  return self
end

function MouseSteeringVehiclesDialog:onCreate()
  MouseSteeringVehiclesDialog:superClass().onCreate(self)

  self.defaultBackText = self.backButton.text
  self.defaultToggleText = self.toggleButton.text
  self.defaultDeleteAllText = self.deleteAllButton.text
  self.defaultSyncText = self.syncButton.text
end

function MouseSteeringVehiclesDialog:onGuiSetupFinished()
  MouseSteeringVehiclesDialog:superClass().onGuiSetupFinished(self)

  self.mouseSteering = g_currentMission.mouseSteering
  self.vehiclesList:setDataSource(self)
end

function MouseSteeringVehiclesDialog:onOpen()
  MouseSteeringVehiclesDialog:superClass().onOpen(self)

  self:rebuildTables()

  FocusManager:setFocus(self.vehiclesList)
end

function MouseSteeringVehiclesDialog:isValidVehicle(vehicle)
  if vehicle ~= nil and not vehicle.isDeleted and not vehicle.isDeleting and vehicle.getIsControlled ~= nil and vehicle.getSellPrice ~= nil and vehicle.price ~= nil and vehicle.price > 0 and self:isProperty(vehicle) and self:isType(vehicle) then
    local mission = self.mouseSteering.mission

    if mission ~= nil and mission.accessHandler ~= nil and mission.accessHandler:canPlayerAccess(vehicle) then
      return true
    end
  end

  return false
end

function MouseSteeringVehiclesDialog:isProperty(vehicle)
  local propertyStates = {
    [Vehicle.PROPERTY_STATE_OWNED] = true,
    [Vehicle.PROPERTY_STATE_LEASED] = true,
    [Vehicle.PROPERTY_STATE_MISSION] = true,
  }

  return propertyStates[vehicle.propertyState] or false
end

function MouseSteeringVehiclesDialog:isType(vehicle)
  local invalidTypes = {
    pallet = true,
    locomotive = true,
    conveyorBelt = true,
    pickupConveyorBelt = true,
  }

  local specializations = {
    Rideable = true,
  }

  return not invalidTypes[vehicle.typeName] and not specializations[vehicle.spec_attachable]
end

function MouseSteeringVehiclesDialog:rebuildTables()
  local mission = g_currentMission.mouseSteering.mission

  self.vehicles = {}

  if mission ~= nil and mission.player ~= nil then
    for _, vehicle in ipairs(mission.vehicles) do
      if self:isValidVehicle(vehicle) then
        table.insert(self.vehicles, vehicle)
      end
    end
  end

  self:updateButtons()
  self.vehiclesList:reloadData()
end

function MouseSteeringVehiclesDialog:updateButtons()
  local maxVehiclesReached = self.mouseSteering:isMaxVehiclesReached()
  self:setButtonDisabled(self.mouseSteering and maxVehiclesReached or false)
end

function MouseSteeringVehiclesDialog:getNumberOfItemsInSection(list, section)
  return #self.vehicles
end

function MouseSteeringVehiclesDialog:getVehicleAndState(index)
  local vehicle = self.vehicles[index]
  local isVehicleSaved = self:isVehicleSaved(vehicle)

  return vehicle, isVehicleSaved
end

function MouseSteeringVehiclesDialog:isVehicleSaved(vehicle)
  return self.mouseSteering:isVehicleSaved(vehicle)
end

function MouseSteeringVehiclesDialog:populateCellForItemInSection(list, section, index, cell)
  local vehicle, isVehicleSaved = self:getVehicleAndState(index)
  local iconProfile = isVehicleSaved and "mouseSteeringVehiclesDialogItemIconActive" or "mouseSteeringVehiclesDialogItemIcon"

  cell:getAttribute("icon"):applyProfile(iconProfile)
  cell:getAttribute("name"):setText(vehicle:getFullName())

  local licensePlateText = "-"

  local licensePlatesData = vehicle:getLicensePlatesData()
  if licensePlatesData and licensePlatesData.characters then
    licensePlateText = table.concat(licensePlatesData.characters):gsub("_", "")
  end

  cell:getAttribute("licensePlate"):setText(licensePlateText)
end

function MouseSteeringVehiclesDialog:onListSelectionChanged(list, section, index)
  self.lastSelectedList = list

  local _, isVehicleSaved = self:getVehicleAndState(index)
  local buttonTextKey = isVehicleSaved and "mouseSteering_button_delete" or "mouseSteering_button_save"

  self.toggleButton:setText(self.i18n:getText(buttonTextKey))
end

function MouseSteeringVehiclesDialog:onDoubleClickVehiclesListItem(list, section, index, element)
  local vehicle, isVehicleSaved = self:getVehicleAndState(index)
  self.mouseSteering[isVehicleSaved and "removeVehicle" or "addVehicle"](self.mouseSteering, vehicle)

  self:rebuildTables()
end

function MouseSteeringVehiclesDialog:onClickToggle()
  local index = self.vehiclesList.selectedIndex

  if index > 0 then
    self:onDoubleClickVehiclesListItem(self.vehiclesList, nil, index, nil)
  end
end

function MouseSteeringVehiclesDialog:onClickDeleteAll()
  self.gui:showYesNoDialog({
    text = self.i18n:getText("mouseSteering_ui_youWantToDeleteAllVehicles"),
    title = self.i18n:getText("mouseSteering_button_deleteAll"),
    dialogType = DialogElement.TYPE_QUESTION,
    callback = self.onYesNoDeleteVehicle,
    target = self,
  })
end

function MouseSteeringVehiclesDialog:onYesNoDeleteVehicle(yes)
  if not yes then
    return
  end

  for index = 1, #self.vehicles do
    local vehicle = self.vehicles[index]

    if self:isVehicleSaved(vehicle) then
      self.mouseSteering:removeVehicle(vehicle)
    end
  end

  self.gui:showInfoDialog({
    dialogType = DialogElement.TYPE_INFO,
    text = self.i18n:getText("mouseSteering_ui_allVehiclesDeleted"),
  })

  self:rebuildTables()
end

function MouseSteeringVehiclesDialog:onClickSync()
  self.gui:showYesNoDialog({
    text = self.i18n:getText("mouseSteering_ui_youWantToSyncVehicles"),
    title = self.i18n:getText("mouseSteering_button_sync"),
    dialogType = DialogElement.TYPE_QUESTION,
    callback = self.onYesNoSyncVehicle,
    target = self,
  })
end

function MouseSteeringVehiclesDialog:onYesNoSyncVehicle(yes)
  if not yes then
    return
  end

  local vehiclesToKeep = {}

  for i = 1, #self.vehicles do
    local vehicle, isVehicleSaved = self:getVehicleAndState(i)

    if isVehicleSaved then
      local vehicleKey = self.mouseSteering:getVehicleKey(vehicle)

      vehiclesToKeep[vehicleKey] = true
    end
  end

  for vehicleKey in pairs(self.mouseSteering.vehicles.data) do
    if not vehiclesToKeep[vehicleKey] then
      self.mouseSteering:removeVehicle(vehicleKey)
    end
  end

  self.gui:showInfoDialog({
    dialogType = DialogElement.TYPE_INFO,
    text = self.i18n:getText("mouseSteering_ui_vehiclesSynced"),
  })

  self:rebuildTables()
end

function MouseSteeringVehiclesDialog:sendCallback(value)
  if self.callbackFunc ~= nil then
    if self.target ~= nil then
      self.callbackFunc(self.target, value)
    else
      self.callbackFunc(value)
    end
  end
end

function MouseSteeringVehiclesDialog:setCallback(callbackFunc, target, args)
  self.callbackFunc = callbackFunc
  self.target = target
  self.callbackArgs = args
end

function MouseSteeringVehiclesDialog:onClickBack()
  g_currentMission.mouseSteering:saveVehicleToXMLFile()

  self:sendCallback(true)
  self:close()
end

function MouseSteeringVehiclesDialog:setButtonTexts(backText, toggleText, deleteAllText, syncText)
  self.backButton:setText(Utils.getNoNil(backText, self.defaultBackText))
  self.toggleButton:setText(Utils.getNoNil(toggleText, self.defaultToggleText))
  self.deleteAllButton:setText(Utils.getNoNil(deleteAllText, self.defaultDeleteAllText))
  self.syncButton:setText(Utils.getNoNil(syncText, self.defaultSyncText))
end

function MouseSteeringVehiclesDialog:setButtonDisabled(disabled)
  self.messageBackground:setVisible(disabled)
  -- self.toggleButton:setDisabled(disabled)
end
