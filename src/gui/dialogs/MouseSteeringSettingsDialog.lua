--
-- MouseSteeringSettingsDialog
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

---
MouseSteeringSettingsDialog = {
  COLUMN_ICON = 1,
  COLUMN_NAME = 2,
  COLUMN_LICENSE_PLATE = 3,
  STATUS_BAR_LOW = 0.2,
  STATUS_BAR_HIGH = 0.8,
}

---
MouseSteeringSettingsDialog.SUB_CATEGORY = {
  GENERAL_SETTINGS = 1,
  HUD_SETTINGS = 2,
  MANAGE_SETTINGS = 3,
}

---
MouseSteeringSettingsDialog.VEHICLE_FILTER = {
  ALL = 1,
  SAVED = 2,
  UNSAVED = 3,
}

local MouseSteeringSettingsDialog_mt = Class(MouseSteeringSettingsDialog, MessageDialog)

---
function MouseSteeringSettingsDialog.show(callback, target, callbackArgs, disableOpenSound)
  local dialog = MouseSteeringSettingsDialog.INSTANCE

  if dialog ~= nil then
    dialog:setCallback(callback, target, callbackArgs)
    dialog:setDisableOpenSound(disableOpenSound)

    g_gui:showDialog("MouseSteeringSettingsDialog")
  end

  return dialog
end

---Creates a new instance of MouseSteeringSettingsDialog
function MouseSteeringSettingsDialog.new(target, customMt, gui, i18n)
  local self = MouseSteeringSettingsDialog:superClass().new(target, customMt or MouseSteeringSettingsDialog_mt)

  self.gui = gui
  self.i18n = i18n

  -- initialize empty tables
  self.vehicles = {}
  self.visibleVehicles = {}

  -- initialize dialog state variables
  self.vehiclesFilterState = MouseSteeringSettingsDialog.VEHICLE_FILTER.ALL
  self.showWelcomeDialogOnNextUpdate = false
  self.lastSelectedList = nil

  return self
end

---
function MouseSteeringSettingsDialog:onCreate()
  MouseSteeringSettingsDialog:superClass().onCreate(self)

  self.defaultResetText = self.resetButton.text
  self.defaultToggleText = self.toggleButton.text
  self.viewDetailText = self.viewDetailButton.text
  self.defaultBackText = self.backButton.text
end

---
function MouseSteeringSettingsDialog:onGuiSetupFinished()
  MouseSteeringSettingsDialog:superClass().onGuiSetupFinished(self)

  local mission = g_currentMission
  self.mouseSteering = mission.mouseSteering
  self.settings = self.mouseSteering.settings

  -- apply data source to vehicles list
  self.vehiclesList:setDataSource(self)

  -- setup tabs
  self:setupTabs(self.subCategoryTabs, self.pageSelector, self.subCategoryBox)
  self:setupTabs(self.filterSelectorTab, self.filterSelector, self.filterBox)
end

---Called when the dialog is opened to setup the UI and components
function MouseSteeringSettingsDialog:onOpen()
  local mission = g_currentMission

  -- setup display
  self.vehicleDetailMap:setIngameMap(mission.hud:getIngameMap())
  MouseSteeringSettingsDialog:superClass().onOpen(self)

  -- setup ui
  local currentState = self.pageSelector:getState()
  self:updateSubCategoryPages(currentState)
  self:updateUISettings()
  self:updateModeSettingsText()

  -- setup input and filter
  self:registerInput()
  if self.customFilter ~= nil then
    self.ingameMapBase:applyCustomFilter(self.customFilter)
  end

  self.showWelcomeDialogOnNextUpdate = true
end

---Updates the dialog each frame
-- @param dt number The delta time since the last update
function MouseSteeringSettingsDialog:update(dt)
  MouseSteeringSettingsDialog:superClass().update(self, dt)

  -- handle welcome dialog display on first update
  if self.showWelcomeDialogOnNextUpdate then
    self.showWelcomeDialogOnNextUpdate = false
    self:onClickShowWelcomeDialog()
  end
end

---Updates the subcategory pages based on the selected category
-- @param category number The category to display (GENERAL_SETTINGS, HUD_SETTINGS, or MANAGE_SETTINGS)
function MouseSteeringSettingsDialog:updateSubCategoryPages(category)
  for index, page in pairs(self.subCategoryPages) do
    page:setVisible(index == category)
  end

  -- set default button states
  self.resetButton:setVisible(category ~= MouseSteeringSettingsDialog.SUB_CATEGORY.MANAGE_SETTINGS)
  self.toggleButton:setVisible(category == MouseSteeringSettingsDialog.SUB_CATEGORY.MANAGE_SETTINGS)
  self.viewDetailButton:setVisible(category == MouseSteeringSettingsDialog.SUB_CATEGORY.MANAGE_SETTINGS)

  -- configure category-specific settings
  if category == MouseSteeringSettingsDialog.SUB_CATEGORY.GENERAL_SETTINGS then
    self.settingsSlider:setDataElement(self.generalSettingsLayout)
    FocusManager:linkElements(self.pageSelector, FocusManager.TOP, self.generalSettingsLayout.elements[#self.generalSettingsLayout.elements].elements[1])
    FocusManager:linkElements(self.pageSelector, FocusManager.BOTTOM, self.generalSettingsLayout:findFirstFocusable(true))
    self:removeBottomBorders(self.generalSettingsLayout)
  elseif category == MouseSteeringSettingsDialog.SUB_CATEGORY.HUD_SETTINGS then
    self.settingsSlider:setDataElement(self.hudSettingsLayout)
    FocusManager:linkElements(self.pageSelector, FocusManager.TOP, self.hudSettingsLayout.elements[#self.hudSettingsLayout.elements].elements[1])
    FocusManager:linkElements(self.pageSelector, FocusManager.BOTTOM, self.hudSettingsLayout:findFirstFocusable(true))
    self:removeBottomBorders(self.hudSettingsLayout)
  elseif category == MouseSteeringSettingsDialog.SUB_CATEGORY.MANAGE_SETTINGS then
    self.settingsSlider:setDataElement(self.vehiclesList)
    FocusManager:linkElements(self.pageSelector, FocusManager.TOP, self.vehiclesList)
    FocusManager:linkElements(self.pageSelector, FocusManager.BOTTOM, self.vehiclesList)
    FocusManager:linkElements(self.vehiclesList, FocusManager.LEFT, self.filterSelector)
    FocusManager:linkElements(self.vehiclesList, FocusManager.RIGHT, self.filterSelector)

    -- update vehicles
    self:updateVehicles()
    self:setVehicleDetailBoxVisible(self.vehicleDetailBox:getIsVisible())
    self:removeBottomBorders(self.manageSettingsLayout)

    -- set focus to vehicles list first
    if self.vehiclesList ~= nil then
      FocusManager:setFocus(self.vehiclesList)
    end
  end
end

---Updates all UI elements to reflect current settings values
function MouseSteeringSettingsDialog:updateUISettings()
  local settings = self.settings

  -- handle auto-save when default mode is enabled
  if settings.default and settings.autoSave then
    settings.autoSave = false
  end

  -- sliders
  self.sensitivity:setValue(settings.sensitivity)
  self.linearity:setValue(settings.linearity)
  self.smoothness:setValue(settings.smoothness)
  self.deadzone:setValue(settings.deadzone)
  self.steeringAssistThreshold:setValue(settings.steeringAssistThreshold)
  -- self.steeringAssistThreshold:setFormatter(function(value) return string.format("%.3f", value) end)

  -- switches
  self.invertXAxis:setIsChecked(settings.invertXAxis, true)
  self.speedBasedSteering:setIsChecked(settings.speedBasedSteering, true)
  self.steeringAssist:setIsChecked(settings.steeringAssist, true)
  self.steeringAssistLockout:setIsChecked(settings.steeringAssistLockout, true)
  self.autoSave:setIsChecked(settings.autoSave, true)
  self.default:setIsChecked(settings.default, true)
  self.indicatorLookBackInside:setIsChecked(settings.indicatorLookBackInside, true)

  -- binary options
  self.indicatorText:setIsChecked(settings.indicatorText, true)

  -- multi-text options
  self.indicatorMode:setState(settings.indicatorMode)

  -- indicators and controls
  self:updateVehiclesStatusIndicator()
  self:updateDynamicControls()
end

---Updates the mode settings text based on multiplayer status
function MouseSteeringSettingsDialog:updateModeSettingsText()
  local isMultiplayerSession = self.mouseSteering.isClient and not self.mouseSteering.isServer

  local modeLabelKey = isMultiplayerSession and "mouseSteering_ui_multiplayer" or "mouseSteering_ui_singleplayer"
  self.modeSettingsValue:setText(self.i18n:getText(modeLabelKey))
end

---Registers input event handlers for the dialog
function MouseSteeringSettingsDialog:registerInput()
  self:unregisterInput()
  g_inputBinding:registerActionEvent(InputAction.MENU_MAP_ACTION_1, self, self.onControlsAction1, false, true, false, true)
end

---Unregisters input event handlers for the dialog
function MouseSteeringSettingsDialog:unregisterInput()
  g_inputBinding:removeActionEventsByActionName(InputAction.MENU_MAP_ACTION_1)
end

---
function MouseSteeringSettingsDialog:onControlsAction1()
  self:onClickOpenPageSettingsControls()
end

---Updates the vehicle status indicator with current capacity information
function MouseSteeringSettingsDialog:updateVehiclesStatusIndicator()
  if self.vehicleStatusIndicator ~= nil then
    -- get current vehicle count and capacity
    local vehicleCount = self.mouseSteering:getVehicleCount()
    local maxCapacity = MouseSteering.MAX_VEHICLES

    -- update text display
    local fillLevelText = self.vehicleStatusIndicator:getDescendantByName("fillLevel")
    fillLevelText:setText(string.format("%d / %d", vehicleCount, maxCapacity))

    -- calculate fill ratio and update status bar
    local fillRatio = 0
    if maxCapacity >= 1 then
      fillRatio = vehicleCount / maxCapacity
    end

    local statusBar = self.vehicleStatusIndicator:getDescendantByName("bar")
    self:setStatusBarValue(statusBar, fillRatio, false)

    -- apply appropriate text color based on fill level
    if fillRatio > MouseSteeringSettingsDialog.STATUS_BAR_HIGH then
      fillLevelText:applyProfile(MouseSteeringSettingsDialog.PROFILES.STATUS_TEXT_DANGER)
    else
      fillLevelText:applyProfile(MouseSteeringSettingsDialog.PROFILES.STATUS_TEXT)
    end
  end
end

---Handles slider value changes and updates settings
-- @param index number The selected index from the slider
-- @param slider table The slider element that changed
function MouseSteeringSettingsDialog:onSliderChanged(index, slider)
  local selectedValue = slider:getValueFromIndex(index)
  self.settings[slider.id] = selectedValue

  -- apply the value to the slider
  slider:setValue(selectedValue)
end

---Handles toggle state changes and updates settings
-- @param index number The toggle index (unused)
-- @param toggle table The toggle element that changed
function MouseSteeringSettingsDialog:onToggleChanged(index, toggle)
  local previousValue = self.settings[toggle.id]
  local currentValue = toggle:getIsChecked()

  -- update the setting
  self.settings[toggle.id] = currentValue

  -- handle special case for default mode toggle
  if toggle.id == "default" and previousValue ~= currentValue then
    if currentValue then
      self.settings.autoSave = false
      if self.autoSave ~= nil then
        self.autoSave:setIsChecked(false, false)
      end
    end

    -- notify about default mode change
    g_messageCenter:publish(MouseSteeringMessageType.SETTING_CHANGED.DEFAULT, currentValue)
  end

  -- refresh dynamic control states
  self:updateDynamicControls()
end

---Handles multi-text option state changes and updates settings
-- @param state number The selected state index
-- @param element table The multi-text element that changed
function MouseSteeringSettingsDialog:onMultiChanged(state, element)
  local selectedValue = element.getSettingValue ~= nil and element:getSettingValue() or state
  self.settings[element.id] = selectedValue
end

---Updates the enabled/disabled state of dynamic controls based on current settings
function MouseSteeringSettingsDialog:updateDynamicControls()
  local currentSettings = self.settings

  -- auto-save is disabled when default mode is active (mutually exclusive)
  if self.autoSave ~= nil then
    local disableAutoSave = currentSettings.default == true
    self:setOptionDisabledWithIcon(self.autoSave, disableAutoSave)
  end

  -- steering assist lockout is disabled when steering assist is active
  if self.steeringAssistLockout ~= nil then
    local disableLockout = currentSettings.steeringAssist == false
    self:setOptionDisabledWithIcon(self.steeringAssistLockout, disableLockout)
  end

  -- steering assist threshold is disabled when either steering assist or lockout is active
  if self.steeringAssistThreshold ~= nil then
    local disableThreshold = currentSettings.steeringAssist == false
    self:setOptionDisabledWithIcon(self.steeringAssistThreshold, disableThreshold)
  end

  -- linearity is disabled when speed-dependent steering is enabled (forced to 1.0)
  if self.linearity ~= nil then
    local disableLinearity = currentSettings.speedBasedSteering == true
    self:setOptionDisabledWithIcon(self.linearity, disableLinearity)
  end
end

---Sets the disabled state of an option element and its associated icon
-- @param optionElement table The option element to modify
-- @param isDisabled boolean Whether the option should be disabled
-- @param iconName string|nil The name of the associated icon element (default: "iconDisabled")
function MouseSteeringSettingsDialog:setOptionDisabledWithIcon(optionElement, isDisabled, iconName)
  if optionElement == nil then
    return
  end

  -- set the disabled state of the option element
  optionElement:setDisabled(isDisabled)

  -- configure associated icon in the same container
  local parentContainer = optionElement.parent
  if parentContainer ~= nil then
    local iconElementName = iconName or "iconDisabled"
    local associatedIcon = parentContainer:getDescendantByName(iconElementName)

    if associatedIcon ~= nil then
      local shouldDisableIcon = not isDisabled
      associatedIcon:setDisabled(shouldDisableIcon)
    end
  end
end

---Sets the value and visual state of a status bar element
-- @param statusBar table The status bar element to update
-- @param currentValue number The current value (0-1 range)
-- @param useLowerThreshold boolean Whether to use lower threshold for danger state
function MouseSteeringSettingsDialog:setStatusBarValue(statusBar, currentValue, useLowerThreshold)
  local selectedProfile = MouseSteeringSettingsDialog.PROFILES.STATUS_BAR

  if useLowerThreshold then
    if currentValue < MouseSteeringSettingsDialog.STATUS_BAR_LOW then
      selectedProfile = MouseSteeringSettingsDialog.PROFILES.STATUS_BAR_DANGER
    end
  else
    if currentValue > MouseSteeringSettingsDialog.STATUS_BAR_HIGH then
      selectedProfile = MouseSteeringSettingsDialog.PROFILES.STATUS_BAR_DANGER
    end
  end

  -- apply the determined profile to the status bar
  statusBar:applyProfile(selectedProfile)

  -- calculate the available width for the bar
  local parentWidth = statusBar.parent.absSize[1]
  local marginWidth = statusBar.margin[1] * 2
  local availableWidth = parentWidth - marginWidth

  -- calculate minimum width to prevent bar from being too small
  local startSizeWidth = statusBar.startSize and statusBar.startSize[1] or 0
  local endSizeWidth = statusBar.endSize and statusBar.endSize[1] or 0
  local minimumWidth = startSizeWidth + endSizeWidth

  -- calculate the actual bar width based on current value
  local clampedValue = math.min(1, currentValue)
  local calculatedWidth = availableWidth * clampedValue
  local finalWidth = math.max(minimumWidth, calculatedWidth)

  -- apply the calculated width to the status bar
  statusBar:setSize(finalWidth, nil)
end

---Updates the list of vehicles available for mouse steering management
function MouseSteeringSettingsDialog:updateVehicles()
  self.vehicles = {}

  -- only process vehicles if we have a local player
  if g_localPlayer == nil then
    return
  end

  -- get references to commonly used objects
  local mission = g_currentMission
  local playerAccessHandler = mission.accessHandler
  local currentPlayerFarmId = g_localPlayer.farmId

  -- iterate through all vehicles in the mission
  for _, currentVehicle in ipairs(mission.vehicleSystem.vehicles) do
    -- check if player can access this vehicle
    local canAccessVehicle = playerAccessHandler:canPlayerAccess(currentVehicle)

    -- check if vehicle should be shown in overview and belongs to player's farm
    local shouldShowInOverview = currentVehicle:getShowInVehiclesOverview()
    local belongsToPlayerFarm = currentPlayerFarmId == currentVehicle:getOwnerFarmId()

    -- vehicle must meet all access criteria
    if canAccessVehicle and shouldShowInOverview and belongsToPlayerFarm then
      -- check if vehicle has mouse steering specialization
      if SpecializationUtil.hasSpecialization(MouseSteeringVehicle, currentVehicle.specializations) then
        -- determine vehicle save status for icon display
        local isSaved = self.mouseSteering:isVehicleSaved(currentVehicle)
        local iconDisplayProfile = isSaved and MouseSteeringSettingsDialog.PROFILES.VEHICLE_ICON_ACTIVE or MouseSteeringSettingsDialog.PROFILES.VEHICLE_ICON

        -- retrieve vehicle display information
        local vehicleDisplayName = currentVehicle:getFullName() or "NONE"
        local vehicleLicensePlate = LicensePlates.getSpecValuePlateText(nil, currentVehicle) or "-"

        -- build column data structure for table display
        local columnData = {}

        -- icon column with save status indicator
        columnData[MouseSteeringSettingsDialog.COLUMN_ICON] = {
          profile = iconDisplayProfile,
          isActive = isSaved,
        }

        -- vehicle name column
        columnData[MouseSteeringSettingsDialog.COLUMN_NAME] = {
          text = vehicleDisplayName,
          value = vehicleDisplayName,
        }

        -- license plate column
        columnData[MouseSteeringSettingsDialog.COLUMN_LICENSE_PLATE] = {
          text = vehicleLicensePlate,
          value = vehicleLicensePlate,
        }

        -- create complete vehicle entry
        local vehicleEntry = {
          vehicle = currentVehicle,
          columns = columnData,
        }

        -- add vehicle to the collection
        table.insert(self.vehicles, vehicleEntry)
      end
    end
  end

  -- apply any active filters and update the view
  self:applyVehiclesFilter()
  self:updateView()
end

---Applies the current filter to the vehicles list and updates the visible vehicles
function MouseSteeringSettingsDialog:applyVehiclesFilter()
  self.visibleVehicles = {}

  -- determine current filter state (default to ALL if not set)
  local currentFilter = self.vehiclesFilterState

  -- iterate through all vehicles and apply filter criteria
  for _, vehicleEntry in ipairs(self.vehicles) do
    local isVehicleSaved = self.mouseSteering:isVehicleSaved(vehicleEntry.vehicle)

    local shouldIncludeVehicle = true
    if currentFilter == MouseSteeringSettingsDialog.VEHICLE_FILTER.SAVED then
      -- only show saved vehicles
      shouldIncludeVehicle = isVehicleSaved
    elseif currentFilter == MouseSteeringSettingsDialog.VEHICLE_FILTER.UNSAVED then
      -- only show unsaved vehicles
      shouldIncludeVehicle = not isVehicleSaved
    end

    if shouldIncludeVehicle then
      table.insert(self.visibleVehicles, vehicleEntry)
    end
  end

  -- sort vehicles by ID in descending order for consistent display
  table.sort(self.visibleVehicles, function(first, second)
    return first.vehicle.id > second.vehicle.id
  end)
end

---Handles filter page changes and updates the vehicle list accordingly
-- @param state number The new filter state
-- @param element table The filter element that changed
function MouseSteeringSettingsDialog:updateFilterPages(state, element)
  self.vehiclesFilterState = state

  -- apply vehicles filter and reload data
  self:applyVehiclesFilter()
  self.vehiclesList:reloadData()

  -- reset vehicle details view based on filtered results
  if #self.visibleVehicles > 0 then
    self.vehiclesList:setSelectedItem(1, 1, true, true)
    self:updateItemAttributeData(1)
  else
    self:setVehicleDetailBoxVisible(false)
  end

  -- update button states
  self:updateButtons()
end

---Updates the overall view with current vehicle counts and refreshes UI elements
function MouseSteeringSettingsDialog:updateView()
  local totalVehicleCount = #self.vehicles

  -- count saved vehicles
  local savedVehicleCount = 0
  for index = 1, totalVehicleCount do
    local vehicleEntry = self.vehicles[index]
    local iconColumnData = vehicleEntry.columns[MouseSteeringSettingsDialog.COLUMN_ICON]
    if iconColumnData ~= nil and iconColumnData.isActive then
      savedVehicleCount = savedVehicleCount + 1
    end
  end

  -- update ui elements
  self:updateVehiclesSelectionText(savedVehicleCount, totalVehicleCount)
  table.sort(self.vehicles, function(firstVehicle, secondVehicle)
    return firstVehicle.vehicle.id > secondVehicle.vehicle.id
  end)

  -- refresh status and controls
  self:updateVehiclesStatusIndicator()
  self:updateButtons()
  self.vehiclesList:reloadData()
end

---Updates the vehicle selection text with current counts
-- @param savedCount number The number of saved vehicles
-- @param vehicleCount number The total number of vehicles
function MouseSteeringSettingsDialog:updateVehiclesSelectionText(savedCount, vehicleCount)
  local template = self.i18n:getText(MouseSteeringSettingsDialog.L10N_SYMBOL.VEHICLES_SELECTED)
  local displayText = template:format(savedCount, vehicleCount)
  self.vehiclesSelectionName:setText(displayText)
end

---Updates the enabled/disabled state of buttons based on current vehicle selection
-- @param selectedIndex number|nil The index of the selected vehicle (optional, uses current selection if not provided)
function MouseSteeringSettingsDialog:updateButtons(selectedIndex)
  local hasVisibleVehicles = #self.visibleVehicles > 0

  if not hasVisibleVehicles then
    self:setAllButtonsDisabled()
    self:setVehicleDetailBoxVisible(false)
    self:resetToggleButtonText()
    return
  end

  selectedIndex = selectedIndex or self.vehiclesList.selectedIndex

  if selectedIndex <= 0 or selectedIndex > #self.visibleVehicles then
    self:setAllButtonsDisabled()
    return
  end

  -- configure button states
  local selectedVehicle = self.visibleVehicles[selectedIndex].vehicle
  local isVehicleSaved = self.mouseSteering:isVehicleSaved(selectedVehicle)
  local isMaxVehiclesReached = self.mouseSteering:isMaxVehiclesReached()

  local shouldDisableToggle = not isVehicleSaved and isMaxVehiclesReached
  self.toggleButton:setDisabled(shouldDisableToggle)

  self.viewDetailButton:setDisabled(false)
  self.vehicleDetailEmptyText:setVisible(false)
end

---Disables all vehicle-related buttons and shows empty state text
function MouseSteeringSettingsDialog:setAllButtonsDisabled()
  self.toggleButton:setDisabled(true)
  self.viewDetailButton:setDisabled(true)

  -- show empty state text
  self.vehicleDetailEmptyText:setVisible(true)
end

---Sets the visibility of the vehicle detail box and updates button text accordingly
-- @param isVisible boolean Whether the vehicle detail box should be visible
function MouseSteeringSettingsDialog:setVehicleDetailBoxVisible(isVisible)
  self.vehicleDetailBox:setVisible(isVisible)

  -- update button text based on visibility state
  local buttonTextKey = isVisible and MouseSteeringSettingsDialog.L10N_SYMBOL.HIDE_DETAILS or MouseSteeringSettingsDialog.L10N_SYMBOL.VIEW_DETAILS

  self.viewDetailButton:setText(self.i18n:getText(buttonTextKey))
end

---Resets the toggle button text to the default "Save Vehicle" state
function MouseSteeringSettingsDialog:resetToggleButtonText()
  local saveText = self.i18n:getText(MouseSteeringSettingsDialog.L10N_SYMBOL.SAVE_VEHICLE)
  self.toggleButton:setText(saveText)
end

---Updates the vehicle detail information displayed in the detail box
-- @param index number|nil The index of the vehicle to display (optional, uses current selection if not provided)
function MouseSteeringSettingsDialog:updateItemAttributeData(index)
  local selectedIndex = index or self.vehiclesList.selectedIndex
  local selectedVehicleEntry = self.visibleVehicles[selectedIndex]
  local vehicleData = selectedVehicleEntry.vehicle

  -- check if vehicle has map hotspot for positioning
  if vehicleData ~= nil and vehicleData:getMapHotspot() ~= nil then
    -- position map on vehicle location
    local worldX, worldZ = vehicleData:getMapHotspot():getWorldPosition()
    self.vehicleDetailMap:setCenterToWorldPosition(worldX, worldZ)
    self.vehicleDetailMap:setMapZoom(7)
    self.vehicleDetailMap:setMapAlpha(1)

    -- update vehicle details if dialog is visible
    if self:getIsVisible() then
      local storeItem = g_storeManager:getItemByXMLFilename(vehicleData.configFileName)
      local displayItem = g_shopController:makeDisplayItem(storeItem, vehicleData, vehicleData.configurations)

      if displayItem ~= nil then
        -- update vehicle image display
        local hasStoreItem = displayItem.storeItem ~= nil
        self.vehicleDetailImage:setVisible(hasStoreItem)
        if displayItem.concreteItem ~= nil then
          local imageFilename = displayItem.concreteItem:getImageFilename()
          self.vehicleDetailImage:setImageFilename(imageFilename)
        end

        -- update license plate
        local licensePlateText = LicensePlates.getSpecValuePlateText(nil, vehicleData) or "-"
        self.licensePlate:setText(licensePlateText)

        -- update operating time
        local operatingTimeText = "-"
        if vehicleData.getOperatingTime ~= nil then
          operatingTimeText = Vehicle.getSpecValueOperatingTime(nil, vehicleData) or "-"
        end
        self.operatingTime:setText(operatingTimeText)

        -- update ownership status
        local statusText = "-"
        if vehicleData.propertyState == VehiclePropertyState.OWNED then
          statusText = self.i18n:getText("mouseSteering_ui_owned")
        elseif vehicleData.propertyState == VehiclePropertyState.LEASED then
          statusText = self.i18n:getText("mouseSteering_ui_leased")
        end
        self.status:setText(statusText)

        -- update vehicle condition
        local conditionText = "-"
        if SpecializationUtil.hasSpecialization(Wearable, vehicleData.specializations) then
          local damageAmount = vehicleData:getDamageAmount()
          local conditionPercent = math.ceil((1 - damageAmount) * 100)
          conditionText = g_i18n:formatNumber(conditionPercent, 0) .. " %"
        end
        self.damage:setText(conditionText)

        -- update last saved time
        local lastSavedText = self.mouseSteering:getLastSavedTime(vehicleData) or "-"
        self.lastSaved:setText(lastSavedText)

        -- refresh layout
        self.vehicleDetailAttributesLayout:invalidateLayout()
        return
      end
    end
  end

  -- hide detail box if no valid vehicle data
  self:setVehicleDetailBoxVisible(false)
end

---
function MouseSteeringSettingsDialog:getNumberOfItemsInSection(list, section)
  return #self.visibleVehicles
end

---
function MouseSteeringSettingsDialog:populateCellForItemInSection(list, section, index, cell)
  local vehicle = self.visibleVehicles[index]

  cell:getAttribute("icon"):applyProfile(vehicle.columns[MouseSteeringSettingsDialog.COLUMN_ICON].profile)
  cell:getAttribute("name"):setText(vehicle.columns[MouseSteeringSettingsDialog.COLUMN_NAME].text)
  cell:getAttribute("licensePlate"):setText(vehicle.columns[MouseSteeringSettingsDialog.COLUMN_LICENSE_PLATE].text)
end

---
function MouseSteeringSettingsDialog:onListSelectionChanged(list, section, index)
  self.lastSelectedList = list
  self.vehiclesList.selectedIndex = index

  local selectedVehicleEntry = self.visibleVehicles[index]
  local selectedVehicle = selectedVehicleEntry.vehicle

  -- configure button text based on vehicle save status
  local isVehicleSaved = self.mouseSteering:isVehicleSaved(selectedVehicle)
  local buttonTextKey = isVehicleSaved and self.L10N_SYMBOL.UNSAVE_VEHICLE or self.L10N_SYMBOL.SAVE_VEHICLE
  local localizedButtonText = self.i18n:getText(buttonTextKey)
  self.toggleButton:setText(localizedButtonText)

  self:updateButtons(index)
  self:updateItemAttributeData(index)
end

---
function MouseSteeringSettingsDialog:onDoubleClickVehiclesListItem(list, section, index, element)
  if index <= 0 or index > #self.visibleVehicles then
    return
  end

  local selectedVehicleEntry = self.visibleVehicles[index]
  local selectedVehicle = selectedVehicleEntry.vehicle

  -- determine vehicle save status
  local isVehicleSaved = self.mouseSteering:isVehicleSaved(selectedVehicle)

  if isVehicleSaved then
    self.mouseSteering:removeVehicle(selectedVehicle)
  else
    if not self.mouseSteering:isMaxVehiclesReached() then
      self.mouseSteering:addVehicle(selectedVehicle)
    end
  end

  -- refresh the vehicles list to reflect changes
  self:updateVehicles()
end

---Opens the map overview and navigates to the selected vehicle's location
function MouseSteeringSettingsDialog:onVehicleViewOnMap()
  local selectedIndex = self.vehiclesList:getSelectedIndexInSection()
  local selectedVehicleEntry = self.visibleVehicles[selectedIndex]

  -- open map overview and navigate to vehicle location
  local gameMenu = g_inGameMenu
  gameMenu:openMapOverview()

  local mapOverviewPage = gameMenu.pageMapOverview
  local vehicleHotspot = selectedVehicleEntry.vehicle:getMapHotspot()

  if vehicleHotspot ~= nil then
    mapOverviewPage:showMapHotspot(vehicleHotspot)
  end
end

---Sets the in-game map reference for the vehicle detail map
-- @param inGameMap table The in-game map instance
function MouseSteeringSettingsDialog:setInGameMap(inGameMap)
  self.vehicleDetailMap:setIngameMap(inGameMap)
  self.ingameMapBase = inGameMap

  -- create custom filter if map is available
  if inGameMap ~= nil then
    self.customFilter = inGameMap:createCustomFilter(true)
  end
end

---Sets up tab buttons and selector with proper selection handling
-- @param tabButtons table Array of tab button elements
-- @param selector table The selector element that controls tab states
-- @param containerBox table|nil The container box for sizing calculations
function MouseSteeringSettingsDialog:setupTabs(tabButtons, selector, containerBox)
  if tabButtons == nil or selector == nil then
    return
  end

  local tabLabels = {}

  -- configure each tab button to respond to selector state
  for tabIndex, tabButton in ipairs(tabButtons) do
    local buttonBackground = tabButton:getDescendantByName("background")

    -- create selection check function for this specific tab
    local function isTabSelected()
      return tabIndex == selector:getState()
    end

    -- apply selection function to background and button
    if buttonBackground ~= nil then
      buttonBackground.getIsSelected = isTabSelected
    end

    tabButton.getIsSelected = isTabSelected

    -- add tab label (using index as text)
    table.insert(tabLabels, tostring(tabIndex))
  end

  -- configure selector with tab labels and appropriate size
  if containerBox ~= nil then
    selector:setTexts(tabLabels)

    -- calculate selector width based on container size
    local containerWidth = containerBox.maxFlowSize or 0
    local selectorWidth = containerWidth + 140 * g_pixelSizeScaledX
    selector:setSize(selectorWidth)

    -- refresh container layout
    containerBox:invalidateLayout()
  else
    selector:setTexts(tabLabels)
  end
end

---Removes bottom borders from section elements to create cleaner visual separation
-- @param frame table The frame element containing sections to process
function MouseSteeringSettingsDialog:removeBottomBorders(frame)
  local lastVisibleElementInSection = nil
  local bottomBorderSide = GuiElement.FRAME_BOTTOM

  -- iterate through all frame elements
  for _, currentElement in ipairs(frame.elements) do
    if currentElement.name == "sectionHeader" then
      -- found section header - remove bottom border from last element in previous section
      if lastVisibleElementInSection ~= nil then
        lastVisibleElementInSection:toggleFrameSide(bottomBorderSide, false)
        lastVisibleElementInSection = nil
      end
    elseif currentElement:getIsVisible() then
      -- found visible element - track it as potential last element in current section
      lastVisibleElementInSection = currentElement
    end
  end

  -- remove bottom border from last element in final section (if any)
  if lastVisibleElementInSection ~= nil then
    lastVisibleElementInSection:toggleFrameSide(bottomBorderSide, false)
  end

  -- refresh frame layout after border changes
  frame:invalidateLayout()
end

---
function MouseSteeringSettingsDialog:onClickGeneral()
  self.pageSelector:setState(MouseSteeringSettingsDialog.SUB_CATEGORY.GENERAL_SETTINGS, true)
end

---
function MouseSteeringSettingsDialog:onClickHud()
  self.pageSelector:setState(MouseSteeringSettingsDialog.SUB_CATEGORY.HUD_SETTINGS, true)
end

---
function MouseSteeringSettingsDialog:onClickManage()
  self.pageSelector:setState(MouseSteeringSettingsDialog.SUB_CATEGORY.MANAGE_SETTINGS, true)
end

---
function MouseSteeringSettingsDialog:onClickFilterAll()
  self.filterSelector:setState(MouseSteeringSettingsDialog.VEHICLE_FILTER.ALL, true)
end

---
function MouseSteeringSettingsDialog:onClickFilterSaved()
  self.filterSelector:setState(MouseSteeringSettingsDialog.VEHICLE_FILTER.SAVED, true)
end

---
function MouseSteeringSettingsDialog:onClickFilterUnsaved()
  self.filterSelector:setState(MouseSteeringSettingsDialog.VEHICLE_FILTER.UNSAVED, true)
end

---Handles the toggle button click to save/remove the selected vehicle
function MouseSteeringSettingsDialog:onClickToggle()
  local selectedIndex = self.vehiclesList.selectedIndex

  if selectedIndex > 0 and selectedIndex <= #self.visibleVehicles then
    local selectedVehicleEntry = self.visibleVehicles[selectedIndex]
    local selectedVehicle = selectedVehicleEntry.vehicle
    local isVehicleSaved = self.mouseSteering:isVehicleSaved(selectedVehicle)

    -- toggle vehicle save state if possible (saved vehicles can always be removed, unsaved only if limit not reached)
    if isVehicleSaved or not self.mouseSteering:isMaxVehiclesReached() then
      self:onDoubleClickVehiclesListItem(self.vehiclesList, nil, selectedIndex, nil)
    end
  end
end

---Toggles the visibility of the vehicle detail box
function MouseSteeringSettingsDialog:onClickViewDetail()
  self:setVehicleDetailBoxVisible(not self.vehicleDetailBox:getIsVisible())
end

---
function MouseSteeringSettingsDialog:onClickOpenPageSettingsControls()
  self:onClickBack()

  -- open game settings and controls screens
  local inGameMenu = g_inGameMenu
  inGameMenu:openGameSettingsScreen()
  inGameMenu:openControlsScreen()

  -- if menu.pageSettings ~= nil and menu.pageSettings.pageSelector ~= nil then
  --   menu.pageSettings.pageSelector:setState(InGameMenuSettingsFrame.SUB_CATEGORY.CONTROLS, true)
  -- end

  -- validate controls list is available
  local controlsList = inGameMenu.pageSettings.controlsList
  if controlsList == nil or controlsList.delegate == nil or controlsList.delegate.controlsData == nil then
    return
  end

  -- find mouse steering mod in controls list
  local modName = g_modManager:getModByName(self.mouseSteering.modName)
  local modDisplayTitle = (modName and modName.title) or "Mouse Steering"

  -- locate and highlight the mouse steering controls entry
  for controlIndex, controlData in ipairs(controlsList.delegate.controlsData) do
    if controlData.name == modDisplayTitle then
      controlsList:makeCellVisible(controlIndex, 3, true)
      controlsList:setSelectedItem(controlIndex, 3)

      -- set focus to the first action button for better UX
      local targetCell = controlsList:getElementAtSectionIndex(controlIndex, 1)
      if targetCell ~= nil then
        FocusManager:setFocus(targetCell:getAttribute("actionButton1"))
      end

      break
    end
  end
end

---Shows a confirmation dialog to sync vehicles and removes invalid ones
function MouseSteeringSettingsDialog:onClickSyncVehicles()
  local syncCallback = function(confirmed)
    if not confirmed then
      return
    end

    -- sync vehicles and show result
    local removedCount = self.mouseSteering:syncVehicles()
    if removedCount > 0 then
      InfoDialog.show(string.format(self.i18n:getText("mouseSteering_ui_vehiclesSynced"), removedCount))
    else
      InfoDialog.show(self.i18n:getText("mouseSteering_ui_noVehiclesToSync"))
    end

    -- update vehicles list
    self:updateVehicles()
  end

  YesNoDialog.show(syncCallback, nil, self.i18n:getText("mouseSteering_ui_syncConfirmText"), self.i18n:getText("mouseSteering_ui_syncConfirmTitle"))
end

---Shows a confirmation dialog to reset all settings to default values
function MouseSteeringSettingsDialog:onClickReset()
  local resetCallback = function(confirmed)
    if not confirmed then
      return
    end

    -- preserve and restore welcome dialog state
    local welcomeDialogEnabled = self.settings.showWelcomeDialog

    self.mouseSteering:reset()
    self:updateUISettings()
    self.settings.showWelcomeDialog = welcomeDialogEnabled

    InfoDialog.show(self.i18n:getText("ui_loadedDefaultSettings"))
  end

  YesNoDialog.show(resetCallback, nil, self.i18n:getText("ui_loadDefaultSettings"), self.i18n:getText("button_reset"))
end

---Shows the welcome dialog if enabled in settings
function MouseSteeringSettingsDialog:onClickShowWelcomeDialog()
  local shouldShowWelcome = self.settings.showWelcomeDialog

  -- default to showing welcome dialog for new users
  if shouldShowWelcome == nil then
    shouldShowWelcome = true
  end

  if shouldShowWelcome then
    local welcomeDialogCallback = function(confirmed)
      if not confirmed then
        return
      end

      -- save updated user preference
      self.settings.showWelcomeDialog = false
      self.mouseSteering:saveSettingsToXMLFile()
    end

    -- display informational welcome dialog
    YesNoDialog.show(welcomeDialogCallback, nil, self.i18n:getText("mouseSteering_welcome_text"), self.i18n:getText("mouseSteering_welcome_title"), nil, nil, DialogElement.TYPE_INFO)
  end
end

---
function MouseSteeringSettingsDialog:setButtonTexts(resetText, toggleText, viewDetailText, backText)
  self.resetButton:setText(Utils.getNoNil(resetText, self.defaultResetText))
  self.toggleButton:setText(Utils.getNoNil(toggleText, self.defaultToggleText))
  self.viewDetailButton:setText(Utils.getNoNil(viewDetailText, self.viewDetailText))
  self.backButton:setText(Utils.getNoNil(backText, self.defaultBackText))
end

---
function MouseSteeringSettingsDialog:setCallback(callbackFunc, target, args)
  self.callbackFunc = callbackFunc
  self.target = target
  self.callbackArgs = args
end

---Handles the back button click to save settings and close the dialog
function MouseSteeringSettingsDialog:onClickBack()
  g_messageCenter:unsubscribeAll(self)

  self.mouseSteering:saveSettingsToXMLFile()
  self.mouseSteering:saveVehicleToXMLFile()

  -- clean up vehicle detail map and filters
  self.vehicleDetailMap:onClose()
  if self.customFilter ~= nil then
    self.ingameMapBase:removeCustomFilter(self.customFilter)
  end

  -- close the dialog
  self:close()
end

---
MouseSteeringSettingsDialog.L10N_SYMBOL = {
  SAVE_VEHICLE = "mouseSteering_button_save",
  UNSAVE_VEHICLE = "mouseSteering_button_unsave",
  VIEW_DETAILS = "mouseSteering_button_viewDetails",
  HIDE_DETAILS = "mouseSteering_button_hideDetails",
  VEHICLES_SELECTED = "mouseSteering_ui_vehiclesSelectionName",
}

---
MouseSteeringSettingsDialog.PROFILES = {
  STATUS_BAR = "mouseSteeringProgressBar",
  STATUS_BAR_DANGER = "mouseSteeringProgressBarDanger",
  STATUS_TEXT = "mouseSteeringSettingsDialogVehicleStatusFillLevel",
  STATUS_TEXT_DANGER = "mouseSteeringSettingsDialogVehicleStatusFillLevelDanger",
  VEHICLE_ICON = "mouseSteeringVehiclesDialogListItemIcon",
  VEHICLE_ICON_ACTIVE = "mouseSteeringVehiclesDialogListItemIconActive",
}
