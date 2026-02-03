--
-- MouseSteeringVehicle
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- name of the mod
local modName = g_currentModName

MouseSteeringVehicle = {}

---Checks if all prerequisite specializations are loaded
-- @param specializations table specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function MouseSteeringVehicle.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Drivable, specializations)
      and not SpecializationUtil.hasSpecialization(Locomotive, specializations)
end

---Initializes specialization XML schema
function MouseSteeringVehicle.initSpecialization()
  local schemaSavegame = Vehicle.xmlSchemaSavegame
  schemaSavegame:register(XMLValueType.STRING, "vehicles.vehicle(?)." .. modName .. ".mouseSteeringVehicle#uniqueId", "Unique vehicle identifier")
end

---Register all functions from the specialization that can be called on vehicle level
-- @param vehicleType table vehicle type
function MouseSteeringVehicle.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "updateMouseSteeringHUD", MouseSteeringVehicle.updateMouseSteeringHUD)
  SpecializationUtil.registerFunction(vehicleType, "updateMouseSteeringState", MouseSteeringVehicle.updateMouseSteeringState)
  SpecializationUtil.registerFunction(vehicleType, "getIsMouseSteeringUsed", MouseSteeringVehicle.getIsMouseSteeringUsed)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringUniqueId", MouseSteeringVehicle.getMouseSteeringUniqueId)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringAxisSide", MouseSteeringVehicle.getMouseSteeringAxisSide)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringControlled", MouseSteeringVehicle.setMouseSteeringControlled)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringUsed", MouseSteeringVehicle.setMouseSteeringUsed)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringSaved", MouseSteeringVehicle.setMouseSteeringSaved)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringSteeringPaused", MouseSteeringVehicle.setMouseSteeringSteeringPaused)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringCameraRotating", MouseSteeringVehicle.setMouseSteeringCameraRotating)
  SpecializationUtil.registerFunction(vehicleType, "setCameraRotationActive", MouseSteeringVehicle.setCameraRotationActive)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringHUD", MouseSteeringVehicle.setMouseSteeringHUD)
  SpecializationUtil.registerFunction(vehicleType, "calculateAxisAndSteering", MouseSteeringVehicle.calculateAxisAndSteering)
  SpecializationUtil.registerFunction(vehicleType, "synchronizeMouseSteeringAxisSide", MouseSteeringVehicle.synchronizeMouseSteeringAxisSide)
end

---Register all function overwritings
-- @param vehicleType table vehicle type
function MouseSteeringVehicle.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "setSteeringInput", MouseSteeringVehicle.setSteeringInput)
end

---Register event listeners
-- @param vehicleType table vehicle type
function MouseSteeringVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onReadStream", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", MouseSteeringVehicle)
end

---Called on load
-- @param savegame table savegame
function MouseSteeringVehicle:onLoad(savegame)
  self.spec_mouseSteeringVehicle = self[("spec_%s.mouseSteeringVehicle"):format(modName)]
  local spec = self.spec_mouseSteeringVehicle

  -- initialize core components
  spec.controller = MouseSteeringController.new()
  spec.mouseSteering = g_currentMission.mouseSteering
  spec.settings = spec.mouseSteering.settings

  -- initialize state flags
  spec.isUsed = false
  spec.isSteeringPaused = false
  spec.isCameraRotating = false
  spec.cameraRotationActive = true
  spec.isHUDForcedVisible = nil
  spec.wasUserToggled = false

  -- initialize steering values
  spec.inputValue = 0
  spec.axisSide = 0

  -- store steering state for transitions
  spec.axisSideOnLeave = 0
  spec.inputValueOnLeave = 0

  -- load UI text strings
  spec.enabledTexts = {
    activate = g_i18n:getText("mouseSteering_modeSteering_activate"),
    deactivate = g_i18n:getText("mouseSteering_modeSteering_deactivate"),
  }

  -- initialize AI tracking
  spec.aiSteeringWasActive = false
  spec.aiSteeringLastEnableTime = -math.huge

  -- camera rotation controller
  spec.cameraRotation = MouseSteeringCameraRotation.new(self)

  -- create unique identifier
  spec.uniqueId = self:getUniqueId()

  -- restore saved unique ID
  if savegame ~= nil then
    spec.uniqueId = savegame.xmlFile:getValue(savegame.key .. "." .. modName .. ".mouseSteeringVehicle#uniqueId", spec.uniqueId)
  end

  -- register for message events
  g_messageCenter:subscribe(MouseSteeringMessageType.SETTING_CHANGED.DEFAULT, MouseSteeringVehicle.onDefaultSettingChanged, self)
  g_messageCenter:subscribe(MouseSteeringMessageType.VEHICLE_TOGGLE, MouseSteeringVehicle.onVehicleToggle, self)
end

---Called on delete
function MouseSteeringVehicle:onDelete()
  g_messageCenter:unsubscribe(MouseSteeringMessageType.SETTING_CHANGED.DEFAULT, self)
  g_messageCenter:unsubscribe(MouseSteeringMessageType.VEHICLE_TOGGLE, self)
end

---Saves vehicle data to XML file
-- @param xmlFile any XML file instance
-- @param key string XML key path
-- @param usedModNames table used mod names
function MouseSteeringVehicle:saveToXMLFile(xmlFile, key, usedModNames)
  local spec = self.spec_mouseSteeringVehicle
  xmlFile:setValue(key .. "#uniqueId", spec.uniqueId)
end

---Called on client side on join
-- @param streamId number stream id
-- @param connection any connection instance
function MouseSteeringVehicle:onReadStream(streamId, connection)
  local spec = self.spec_mouseSteeringVehicle
  spec.uniqueId = streamReadString(streamId)
end

---Called on server side on join
-- @param streamId number stream id
-- @param connection any connection instance
function MouseSteeringVehicle:onWriteStream(streamId, connection)
  local spec = self.spec_mouseSteeringVehicle
  streamWriteString(streamId, spec.uniqueId)
end

---Called on update
-- @param dt number delta time since last call in ms
-- @param isActiveForInput boolean true if vehicle is active for input
-- @param isActiveForInputIgnoreSelection boolean true if vehicle is active for input ignoring selection
-- @param isSelected boolean true if vehicle is selected
function MouseSteeringVehicle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
  local spec = self.spec_mouseSteeringVehicle

  local isEntered = self.getIsEntered ~= nil and self:getIsEntered()
  local isControlled = self.getIsControlled ~= nil and self:getIsControlled()

  -- track AI steering state
  local aiState = (self.getAIAutomaticSteeringState ~= nil) and self:getAIAutomaticSteeringState() or nil
  local isSteeringAssist = self.getAIModeSelection ~= nil and self:getAIModeSelection() == AIModeSelection.MODE.STEERING_ASSIST

  -- record AI transitions
  if isSteeringAssist and AIAutomaticSteering ~= nil and aiState ~= nil then
    local nowActive = aiState == AIAutomaticSteering.STATE.ACTIVE

    if not spec.aiSteeringWasActive and nowActive then
      spec.aiSteeringLastEnableTime = g_time
    end

    spec.aiSteeringWasActive = nowActive
  elseif not isSteeringAssist then
    spec.aiSteeringWasActive = false
  end

  -- passenger rotation camera
  spec.isCameraRotating = true

  if isEntered and isControlled then
    local isAIActive = (AIAutomaticSteering ~= nil and aiState == AIAutomaticSteering.STATE.ACTIVE) or false

    if spec.isUsed then
      local inputBinding = g_inputBinding
      local isUiVisible = inputBinding:getShowMouseCursor() or g_gui:getIsGuiVisible()

      if isUiVisible and spec.isSteeringPaused then
        self:setMouseSteeringSteeringPaused(false)
      end

      -- check for active combos
      local inputDisplayManager = g_inputDisplayManager
      local useGamepadButtons = (inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD)
      local hasCombos = next(inputDisplayManager:getComboHelpElements(useGamepadButtons)) ~= nil

      local isComboActive = false
      if hasCombos then
        local pressedComboMaskGamepad, pressedComboMaskMouse = inputBinding:getComboCommandPressedMask()
        local currentPressedMask = useGamepadButtons and pressedComboMaskGamepad or pressedComboMaskMouse
        isComboActive = currentPressedMask ~= 0
      end

      local isPaused = spec.isSteeringPaused or isUiVisible or isComboActive
      local isPowered = self.getIsPowered == nil or self:getIsPowered()
      local movedSide = spec.mouseSteering:getMovedSide()

      if isPowered then
        local speedKmh = (self.getLastSpeed ~= nil) and self:getLastSpeed() or 0

        -- update controller with new input values
        local newRawInput, newAxisValue = spec.controller:update({
          inputValue = spec.inputValue,
          axisSide = spec.axisSide,
          settings = spec.settings,
          movedSide = movedSide,
          isPaused = isPaused,
          speedKmh = speedKmh,
        }, dt)

        -- update input values
        spec.inputValue = newRawInput
        spec.axisSide = newAxisValue
      else
        local mouseMoved = movedSide ~= 0 and not isPaused

        if mouseMoved then
          local warning = self:getCanMotorRun() and g_i18n:getText("warning_motorNotStarted") or self:getMotorNotAllowedWarning()
          if warning ~= nil then
            g_currentMission:showBlinkingWarning(warning, 2000)
          end
        end
      end

      -- cancel AI steering if threshold exceeded
      if isSteeringAssist and isAIActive and spec.settings.steeringAssist then
        local configuredThreshold = spec.settings.steeringAssistThreshold
        local uiThreshold = configuredThreshold or 0.0
        local aiThreshold = uiThreshold * 0.045 + 0.004
        aiThreshold = math.clamp(aiThreshold, 0.004, 0.05)

        if math.abs(movedSide) > aiThreshold then
          local isLockoutEnabled = spec.settings.steeringAssistLockout ~= false
          local timeSinceEnabled = g_time - (spec.aiSteeringLastEnableTime or -math.huge)

          local shouldCancelAI = not isLockoutEnabled or timeSinceEnabled > 2500

          if shouldCancelAI and self.setAIAutomaticSteeringEnabled ~= nil then
            self:setAIAutomaticSteeringEnabled(false)
            isAIActive = false
          end
        end
      end

      -- apply steering input to vehicle
      if self.setSteeringInput ~= nil then
        self:setSteeringInput(spec.axisSide, true, InputDevice.CATEGORY.WHEEL)
      end
    else
      self:synchronizeMouseSteeringAxisSide(false, false)
    end

    -- update HUD and camera
    self:updateMouseSteeringHUD()

    local isPlayerControlled = self:getIsVehicleControlledByPlayer()
    local ignoreSelectionIgnoreAI = self.isActiveForInputIgnoreSelectionIgnoreAI == true

    local shouldDisableRotation = (isAIActive and spec.settings.steeringAssist and isSteeringAssist) or (ignoreSelectionIgnoreAI and isPlayerControlled and not isAIActive)

    self:setMouseSteeringCameraRotating(not shouldDisableRotation)

    if isAIActive or (spec.isCameraRotating and spec.isUsed) then
      self:synchronizeMouseSteeringAxisSide(false, false)
    end

    -- update camera rotation following steering and centering
    local camera = self:getActiveCamera()
    local camIndex = self.spec_enterable and self.spec_enterable.camIndex or 0

    spec.cameraRotation:setSettings(spec.settings, spec.cameraRotationActive)
    spec.cameraRotation:update(dt, camera, camIndex, spec.isSteeringPaused)
  end
end

---Action event handler for centering camera
function MouseSteeringVehicle.actionEventCenterCamera(self, actionName, inputValue, callbackState, isAnalog)
  if inputValue ~= 1 then
    return
  end

  local spec = self.spec_mouseSteeringVehicle

  if not spec.isUsed then
    return
  end

  local camera = self:getActiveCamera()
  spec.cameraRotation:centerCamera(camera)
end

---Updates HUD display visibility and content
function MouseSteeringVehicle:updateMouseSteeringHUD()
  local spec = self.spec_mouseSteeringVehicle
  local activeCamera = self:getActiveCamera()

  if activeCamera == nil then
    return
  end

  local currentMission = g_currentMission
  local ingameMessage = currentMission.hud.ingameMessage
  local contextActionDisplay = currentMission.hud.contextActionDisplay

  -- check for HUD obstruction
  local isObstructed = ingameMessage:getVisible() or contextActionDisplay:getVisible()
  local isVisible = true

  if not spec.isUsed or isObstructed or not self:getIsMotorStarted() or self:getIsAIActive() or not self:getIsControlled() then
    isVisible = false
  else
    -- handle visibility mode
    local hudSetting = tostring(spec.settings.indicatorMode)
    local hudVisibility = {
      ["both"] = true,
      ["inside"] = activeCamera.isInside,
      ["outside"] = not activeCamera.isInside,
    }

    isVisible = hudVisibility[hudSetting] or false

    -- check backwards view inside cabin
    if isVisible and spec.settings.indicatorLookBackInside and activeCamera.isInside then
      local rotY = math.deg(activeCamera.rotY - activeCamera.origRotY) % 360
      isVisible = (rotY >= 120 and rotY <= 240)
    end
  end

  -- apply forced visibility
  local finalVisibility = isVisible
  if spec.isHUDForcedVisible ~= nil then
    finalVisibility = spec.isHUDForcedVisible
  end

  -- update HUD state
  if finalVisibility ~= spec.mouseSteering:getHudVisible() then
    spec.mouseSteering:setControlledVehicle(finalVisibility and self or nil)
  end

  -- update text visibility
  spec.mouseSteering:setIndicatorTextVisible(spec.settings.indicatorText)
end

---Sets the controlled vehicle for mouse steering
-- @param isEntering boolean true if player is entering vehicle
function MouseSteeringVehicle:setMouseSteeringControlled(isEntering)
  local spec = self.spec_mouseSteeringVehicle

  if spec.mouseSteering:getHudVisible() then
    spec.mouseSteering:setControlledVehicle(isEntering and self or nil)
  end
end

---Called when entering a vehicle
function MouseSteeringVehicle:onEnterVehicle()
  local spec = self.spec_mouseSteeringVehicle

  -- apply default/saved only if user hasn't toggled in this session
  if not spec.wasUserToggled then
    spec.isUsed = spec.settings.default or spec.mouseSteering:isVehicleSaved(self)
  end

  -- update action events and controlled vehicle
  MouseSteeringVehicle.updateActionEvents(self)
  self:setMouseSteeringControlled(true)

  -- sync axis when enabled
  if spec.isUsed then
    if self.isClient then
      self:synchronizeMouseSteeringAxisSide(true, true)
    else
      self:synchronizeMouseSteeringAxisSide(false, false)
    end
  end

  -- initialize camera rotation for first frame
  if spec.cameraRotation ~= nil and self.spec_enterable ~= nil then
    local enterableSpec = self.spec_enterable
    local camIndex = enterableSpec.camIndex
    local camera = enterableSpec.cameras[camIndex]
    
    if camera ~= nil and camera.isInside then
      local intensity = spec.cameraRotation:getIntensity()
      local deadzoneDegrees = spec.cameraRotation:getDeadzoneDegrees()
      
      if intensity > 0 then
        spec.cameraRotation:initializeCamera(camera, camIndex, deadzoneDegrees, intensity)
      end
    end
  end
end

---Called when leaving a vehicle
function MouseSteeringVehicle:onLeaveVehicle()
  local spec = self.spec_mouseSteeringVehicle

  -- store current axis values
  if spec.isUsed then
    spec.axisSideOnLeave = spec.axisSide
    spec.inputValueOnLeave = spec.inputValue
  end

  -- save camera state on leave
  if spec.cameraRotation ~= nil then
    spec.cameraRotation:resetState(nil)
  end

  -- update controlled vehicle
  self:setMouseSteeringControlled(false)
end

---Updates mouse steering state based on current conditions
-- @param updateControlledVehicle boolean if true, also update controlled vehicle status
function MouseSteeringVehicle:updateMouseSteeringState(updateControlledVehicle)
  local spec = self.spec_mouseSteeringVehicle

  -- update state
  local wasEnabled = spec.isUsed
  if not spec.wasUserToggled then
    spec.isUsed = spec.settings.default or spec.mouseSteering:isVehicleSaved(self)
  end

  -- sync axis when enabled
  if spec.isUsed and not wasEnabled then
    self:synchronizeMouseSteeringAxisSide(false, false)
  end

  -- update controlled vehicle if requested
  if updateControlledVehicle then
    if spec.isUsed then
      self:setMouseSteeringControlled(true)
    elseif not spec.isUsed and wasEnabled then
      self:setMouseSteeringControlled(false)
    end
  end

  -- refresh action events text/visibility based on current state
  MouseSteeringVehicle.updateActionEvents(self)
end

---Called when default setting is changed
-- @param value any new value
function MouseSteeringVehicle:onDefaultSettingChanged(value)
  if self.getIsEntered ~= nil and self:getIsEntered() then
    self:updateMouseSteeringState(false)

    -- update action event activity
    MouseSteeringVehicle.updateActionEvents(self)
  end
end

---Called when vehicle is toggled
-- @param vehicle table the vehicle that was added/removed
function MouseSteeringVehicle:onVehicleToggle(vehicle)
  if vehicle == self then
    self:updateMouseSteeringState(true)
  end
end

---
function MouseSteeringVehicle.actionEventSteering(self, actionName, inputValue, callbackState, isAnalog)
  if inputValue ~= 1 then
    return
  end

  self:setMouseSteeringUsed()
end

---Enables or disables mouse steering
function MouseSteeringVehicle:setMouseSteeringUsed()
  local spec = self.spec_mouseSteeringVehicle

  spec.isUsed = not spec.isUsed
  spec.wasUserToggled = true

  -- check if auto-save is enabled
  if spec.settings.autoSave then
    if spec.isUsed then
      spec.mouseSteering:addVehicle(self)
    else
      spec.mouseSteering:removeVehicle(self)
    end
    spec.mouseSteering:saveVehicleToXMLFile()
  end

  -- update action event text
  MouseSteeringVehicle.updateActionEvents(self)

  -- show motor warning if needed
  local warning = self:getMotorNotAllowedWarning()
  if warning ~= nil then
    g_currentMission:showBlinkingWarning(warning, 2000)
  end
end

---
function MouseSteeringVehicle.actionEventCameraFollow(self, actionName, inputValue, callbackState, isAnalog)
  if inputValue ~= 1 then
    return
  end

  self:setCameraRotationActive()
end

---Enables or disables camera follow steering for current vehicle
function MouseSteeringVehicle:setCameraRotationActive()
  local spec = self.spec_mouseSteeringVehicle

  -- check if camera rotation is enabled in settings
  local cameraRotationState = spec.settings.cameraRotationInside or "off"

  -- if trying to enable but global setting is off, show warning
  if not spec.cameraRotationActive and cameraRotationState == "off" then
    local warning = g_i18n:getText("mouseSteering_warning_cameraFollowDisabled")
    if warning ~= nil then
      g_currentMission:showBlinkingWarning(warning, 2500)
    end
    return
  end

  spec.cameraRotationActive = not spec.cameraRotationActive
end

---
function MouseSteeringVehicle.actionEventSaveSteering(self, actionName, inputValue, callbackState, isAnalog)
  if inputValue ~= 1 then
    return
  end

  self:setMouseSteeringSaved()
end

---Saves or removes the vehicle from the saved vehicles list
function MouseSteeringVehicle:setMouseSteeringSaved()
  local spec = self.spec_mouseSteeringVehicle
  local isSaved = spec.mouseSteering:isVehicleSaved(self)
  local isMaxVehiclesReached = spec.mouseSteering:isMaxVehiclesReached()

  -- determine action and notification
  local action = isSaved and "removeVehicle" or "addVehicle"
  local notification
  if isSaved then
    notification = "vehicleRemoved"
  elseif not isMaxVehiclesReached then
    notification = "vehicleAdded"
  end

  -- show notification if applicable
  if notification ~= nil then
    local notificationType = notification == "vehicleAdded" and FSBaseMission.INGAME_NOTIFICATION_OK or FSBaseMission.INGAME_NOTIFICATION_CRITICAL
    spec.mouseSteering:showNotification("mouseSteering_notification_" .. notification, notificationType)
  end

  -- execute action and save
  spec.mouseSteering[action](spec.mouseSteering, self)
  spec.mouseSteering:saveVehicleToXMLFile()
end

---
function MouseSteeringVehicle.actionEventRotateCamera(self, actionName, inputValue, callbackState, isAnalog)
  self:setMouseSteeringSteeringPaused(inputValue == 1)
end

---Pauses or unpauses mouse steering
-- @param isPaused boolean true to pause, false to unpause
function MouseSteeringVehicle:setMouseSteeringSteeringPaused(isPaused)
  local spec = self.spec_mouseSteeringVehicle

  if spec.isUsed then
    spec.isSteeringPaused = isPaused
  end
end

---Sets rotating state flag used by camera/steering logic
-- @param isRotating boolean true if camera rotation is in progress, false otherwise
function MouseSteeringVehicle:setMouseSteeringCameraRotating(isRotating)
  local spec = self.spec_mouseSteeringVehicle

  if spec.isUsed then
    spec.isCameraRotating = isRotating
  end
end

---Sets the HUD visibility state
-- @param isVisible boolean true to show HUD, false to hide HUD, nil to use automatic mode
function MouseSteeringVehicle:setMouseSteeringHUD(isVisible)
  local spec = self.spec_mouseSteeringVehicle

  -- set forced visibility
  spec.isHUDForcedVisible = isVisible

  -- update HUD immediately
  if isVisible then
    spec.mouseSteering:setControlledVehicle(self)
  else
    spec.mouseSteering:setControlledVehicle(nil)
  end
end

---Register action events for mouse steering controls
-- @param isActiveForInput boolean true if active for input
-- @param isActiveForInputIgnoreSelection boolean true if active for input ignoring selection
function MouseSteeringVehicle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if self.isClient then
    local spec = self.spec_mouseSteeringVehicle

    self:clearActionEventsTable(spec.actionEvents)

    -- register when player in vehicle and AI not active
    if self:getIsActiveForInput(true, true) and self:getIsEntered() and not self:getIsAIActive() then
      local binding = g_inputBinding

      -- always register toggle mouse steering (visibility controlled separately)
      local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_MOUSE_STEERING_CONTROL, self, MouseSteeringVehicle.actionEventSteering, false, true, false, true, nil)
      binding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)

      -- always register save/delete vehicle (always hidden)
      _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_MOUSE_STEERING_SAVE_DELETE_VEHICLE, self, MouseSteeringVehicle.actionEventSaveSteering, false, true, false, true, nil)
      binding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
      binding:setActionEventTextVisibility(actionEventId, false)

      -- always register rotate camera (visibility controlled separately)
      _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_MOUSE_STEERING_ROTATE_CAMERA, self, MouseSteeringVehicle.actionEventRotateCamera, true, true, false, true, nil)
      binding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
      binding:setActionEventText(actionEventId, g_i18n:getText("mouseSteering_rotateCamera"))

      -- register camera follow toggle (always hidden)
      _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_MOUSE_STEERING_CAMERA_FOLLOW, self, MouseSteeringVehicle.actionEventCameraFollow, false, true, false, true, nil)
      binding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
      binding:setActionEventTextVisibility(actionEventId, false)

      -- register center camera (always hidden)
      _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_MOUSE_STEERING_CENTER_CAMERA, self, MouseSteeringVehicle.actionEventCenterCamera, false, true, false, true, nil)
      binding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
      binding:setActionEventTextVisibility(actionEventId, false)

      -- update activity based on settings
      MouseSteeringVehicle.updateActionEvents(self)
    end
  end
end

---Updates action events activity based on current settings
-- @param self table The vehicle instance
function MouseSteeringVehicle.updateActionEvents(self)
  local spec = self.spec_mouseSteeringVehicle
  local binding = g_inputBinding

  if spec.actionEvents ~= nil then
    -- toggle mouse steering
    local toggleAction = spec.actionEvents[InputAction.TOGGLE_MOUSE_STEERING_CONTROL]
    if toggleAction ~= nil then
      binding:setActionEventActive(toggleAction.actionEventId, true)
      local textKey = spec.isUsed and spec.enabledTexts.deactivate or spec.enabledTexts.activate
      local text = string.format(g_i18n:getText("mouseSteering_mode_format"), textKey)
      binding:setActionEventText(toggleAction.actionEventId, text)
    end

    -- rotate camera
    local rotateAction = spec.actionEvents[InputAction.TOGGLE_MOUSE_STEERING_ROTATE_CAMERA]
    if rotateAction ~= nil then
      binding:setActionEventActive(rotateAction.actionEventId, true)
      binding:setActionEventTextVisibility(rotateAction.actionEventId, spec.isUsed)
    end
  end
end

---Calculates axis value and steering input from vehicle state
-- @param spec table The specialization spec
-- @return number axisValue The calculated axis value
-- @return number steerRaw The calculated raw steering input
function MouseSteeringVehicle:calculateAxisAndSteering(spec)
  local rotatedTime = self.rotatedTime or 0
  local steeringDirection = (self.getSteeringDirection ~= nil) and self:getSteeringDirection() or 1

  -- calculate normalized axis value
  local axisValue = 0
  if self.maxRotTime ~= nil and self.minRotTime ~= nil and self.maxRotTime ~= 0 and self.minRotTime ~= 0 then
    if rotatedTime < 0 then
      axisValue = rotatedTime / -self.maxRotTime / steeringDirection
    else
      axisValue = rotatedTime / self.minRotTime / steeringDirection
    end
  end

  -- get settings and controller
  local settings = spec.settings
  local controller = spec.controller

  -- calculate deadzone and apply transformations
  local deadzoneThreshold = controller:calculateEffectiveDeadzone(settings)
  local normalizedValue = controller:reverseLinearity(axisValue, settings.linearity or 1.0)
  local steerRaw = controller:reverseDeadzone(normalizedValue, deadzoneThreshold)

  return axisValue, steerRaw
end

---Synchronizes the mouse steering axis with the vehicle's steering
-- @param useConservativeThreshold boolean If true, uses higher threshold (for vehicle entry)
-- @param useStoredLeaveState boolean If true, compares with stored leave state when available
-- @return boolean updated True if values were updated, false if filtered out
function MouseSteeringVehicle:synchronizeMouseSteeringAxisSide(useConservativeThreshold, useStoredLeaveState)
  local spec = self.spec_mouseSteeringVehicle

  -- calculate axis value and steering input
  local axisValue, steerRaw = self:calculateAxisAndSteering(spec)

  -- get comparison values
  local currentAxisSide = spec.axisSide
  local axisSideOnLeave = useStoredLeaveState and spec.axisSideOnLeave or 0

  -- determine comparison value
  local comparisonValue = (axisSideOnLeave ~= 0 and axisSideOnLeave) or currentAxisSide
  local updateThreshold = useConservativeThreshold and 0.01 or 0.001

  -- check if update needed
  if math.abs(axisValue - comparisonValue) > updateThreshold then
    -- update values when significant change
    spec.axisSide = axisValue
    spec.inputValue = steerRaw

    -- clear leave state if used
    if useStoredLeaveState then
      spec.axisSideOnLeave = 0
      spec.inputValueOnLeave = 0
    end

    return true
  end

  -- no significant change
  return false
end

---Overrides steering input to handle mouse steering
function MouseSteeringVehicle:setSteeringInput(superFunc, inputValue, isAnalog, deviceCategory)
  local spec = self.spec_mouseSteeringVehicle

  if not spec.isUsed then
    return superFunc(self, inputValue, isAnalog, deviceCategory)
  end

  -- update drivable spec directly when mouse steering enabled
  local drivable = self.spec_drivable
  drivable.lastInputValues.axisSteer = inputValue

  if inputValue ~= 0 then
    drivable.lastInputValues.axisSteerIsAnalog = isAnalog
    drivable.lastInputValues.axisSteerDeviceCategory = deviceCategory
  end
end

---Gets the current mouse steering axis value
-- @return number axis value
function MouseSteeringVehicle:getMouseSteeringAxisSide()
  local spec = self.spec_mouseSteeringVehicle
  return spec.axisSide
end

---Gets the unique identifier for this vehicle
-- @return string uniqueId vehicle unique identifier
function MouseSteeringVehicle:getMouseSteeringUniqueId()
  return self.spec_mouseSteeringVehicle.uniqueId
end

---Gets whether mouse steering is currently used/enabled
-- @return boolean isUsed true if mouse steering is enabled
function MouseSteeringVehicle:getIsMouseSteeringUsed()
  local spec = self.spec_mouseSteeringVehicle
  return spec.isUsed
end
