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
  return SpecializationUtil.hasSpecialization(Drivable, specializations) and not SpecializationUtil.hasSpecialization(Locomotive, specializations)
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
  SpecializationUtil.registerFunction(vehicleType, "getIsMouseSteeringSteeringPaused", MouseSteeringVehicle.getIsMouseSteeringSteeringPaused)
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
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsVehicleControlledByPlayer", MouseSteeringVehicle.getIsVehicleControlledByPlayer)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "setSteeringInput", MouseSteeringVehicle.setSteeringInput)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateSteeringAngle", MouseSteeringVehicle.updateSteeringAngle)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", MouseSteeringVehicle.updateVehiclePhysics)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateSteeringWheel", MouseSteeringVehicle.updateSteeringWheel)
end

---Register event listeners
-- @param vehicleType table vehicle type
function MouseSteeringVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onLoadEnd", MouseSteeringVehicle)
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
  spec.lastIsPaused = false
  spec.isCameraRotating = false
  spec.cameraRotationActive = true
  spec.isHUDForcedVisible = nil
  spec.wasUserToggled = false

  -- initialize steering values
  spec.inputValue = 0
  spec.axisSide = 0

  -- load UI text strings
  spec.enabledTexts = {
    activate = g_i18n:getText("mouseSteering_modeSteering_activate"),
    deactivate = g_i18n:getText("mouseSteering_modeSteering_deactivate"),
  }

  -- initialize AI tracking
  spec.aiSteeringWasActive = false
  spec.lastIsAIActive = false
  spec.aiSteeringLastEnableTime = -math.huge

  -- camera rotation controller
  spec.cameraRotation = MouseSteeringCameraRotation.new(self)

  -- double-click detection for center/look-back camera
  spec.centerCameraLastClickTime = 0

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

---Resolves and caches the vehicle identifier once the base vehicle has one
-- @param vehicle table vehicle instance
-- @return string|nil uniqueId resolved vehicle identifier
function MouseSteeringVehicle.resolveUniqueId(vehicle)
  local spec = vehicle.spec_mouseSteeringVehicle
  local uniqueId = spec.uniqueId

  if type(uniqueId) ~= "string" or string.isNilOrWhitespace(uniqueId) then
    uniqueId = vehicle:getUniqueId()

    if type(uniqueId) == "string" and not string.isNilOrWhitespace(uniqueId) then
      spec.uniqueId = uniqueId
    else
      uniqueId = nil
    end
  end

  return uniqueId
end

---Called after the base vehicle has been added to VehicleSystem
function MouseSteeringVehicle:onLoadEnd()
  MouseSteeringVehicle.resolveUniqueId(self)
end

---Saves vehicle data to XML file
-- @param xmlFile any XML file instance
-- @param key string XML key path
-- @param usedModNames table used mod names
function MouseSteeringVehicle:saveToXMLFile(xmlFile, key, _)
  local uniqueId = MouseSteeringVehicle.resolveUniqueId(self)

  if uniqueId ~= nil then
    xmlFile:setValue(key .. "#uniqueId", uniqueId)
  end
end

---Checks whether a value is a finite number
-- @param value any value to validate
-- @return boolean isFinite true when the value is a finite number
function MouseSteeringVehicle.isFiniteNumber(value)
  return type(value) == "number" and MathUtil.isFinite(value)
end

---Returns a finite steering rotation value within the vehicle limits
-- @param vehicle table vehicle instance
-- @param value any steering rotation value
-- @return number rotatedTime sanitized steering rotation value
function MouseSteeringVehicle.sanitizeRotatedTime(vehicle, value)
  if not MouseSteeringVehicle.isFiniteNumber(value) then
    return 0
  end

  local minRotTime = vehicle.minRotTime
  local maxRotTime = vehicle.maxRotTime

  if MouseSteeringVehicle.isFiniteNumber(minRotTime) and MouseSteeringVehicle.isFiniteNumber(maxRotTime) and minRotTime <= maxRotTime then
    return math.clamp(value, minRotTime, maxRotTime)
  end

  return value
end

---Called on client side on join
-- @param streamId number stream id
function MouseSteeringVehicle:onReadStream(streamId, connection)
  if connection.isServer then
    local spec = self.spec_mouseSteeringVehicle
    local networkUniqueId = streamReadString(streamId)

    if type(networkUniqueId) == "string" and not string.isNilOrWhitespace(networkUniqueId) then
      spec.uniqueId = networkUniqueId
    else
      MouseSteeringVehicle.resolveUniqueId(self)
    end

    -- Wheels resets the steering interpolator while reading the initial stream
    local rotatedTime = MouseSteeringVehicle.sanitizeRotatedTime(self, streamReadFloat32(streamId))
    self.rotatedTime = rotatedTime

    local interpolator = self.rotatedTimeInterpolator
    if interpolator ~= nil then
      interpolator:setValue(rotatedTime)
    end

    self:synchronizeMouseSteeringAxisSide()
    self.spec_drivable.axisSide = spec.axisSide
  end
end

---Called on server side on join
-- @param streamId number stream id
function MouseSteeringVehicle:onWriteStream(streamId, connection)
  if not connection.isServer then
    streamWriteString(streamId, MouseSteeringVehicle.resolveUniqueId(self) or "")

    -- preserve the physical steering state without axis quantization
    streamWriteFloat32(streamId, MouseSteeringVehicle.sanitizeRotatedTime(self, self.rotatedTime))
  end
end

---Uses the full-precision local steering axis for the first-person steering wheel
-- @param superFunc function original steering wheel update function
-- @param steeringWheel table|nil steering wheel configuration
-- @param dt number delta time since last call in ms
-- @param direction number steering wheel rotation direction
function MouseSteeringVehicle:updateSteeringWheel(superFunc, steeringWheel, dt, direction)
  local spec = self.spec_mouseSteeringVehicle
  local drivableSpec = self.spec_drivable

  local isLocalVehicle = self.isClient and g_localPlayer ~= nil and g_localPlayer:getCurrentVehicle() == self
  local camera = isLocalVehicle and self:getActiveCamera() or nil
  local isLocalFirstPerson = camera ~= nil and camera.isInside and not camera.isPassengerCamera
  local visualRotatedTime

  if isLocalFirstPerson and spec.isUsed then
    local isAIActive = self:getIsAIActive()

    if not isAIActive and AIAutomaticSteering ~= nil and self.getAIAutomaticSteeringState ~= nil then
      isAIActive = self:getAIAutomaticSteeringState() == AIAutomaticSteering.STATE.ACTIVE
    end

    local axisSide = drivableSpec.axisSide
    if drivableSpec.idleTurningAllowed and drivableSpec.idleTurningActive and MouseSteeringVehicle.isFiniteNumber(spec.axisSide) then
      axisSide = spec.axisSide
    end

    local steeringDirection = self:getSteeringDirection()
    local minRotTime = self.minRotTime
    local maxRotTime = self.maxRotTime

    if not isAIActive and MouseSteeringVehicle.isFiniteNumber(axisSide) and MouseSteeringVehicle.isFiniteNumber(steeringDirection) and steeringDirection ~= 0 and MouseSteeringVehicle.isFiniteNumber(minRotTime) and MouseSteeringVehicle.isFiniteNumber(maxRotTime) and minRotTime ~= 0 and maxRotTime ~= 0 then
      axisSide = math.clamp(axisSide, -1, 1) * steeringDirection

      if axisSide < 0 then
        visualRotatedTime = math.min(-maxRotTime * axisSide, maxRotTime)
      else
        visualRotatedTime = math.max(minRotTime * axisSide, minRotTime)
      end
    end
  end

  if visualRotatedTime ~= nil then
    local networkRotatedTime = self.rotatedTime
    self.rotatedTime = MouseSteeringVehicle.sanitizeRotatedTime(self, visualRotatedTime)
    superFunc(self, steeringWheel, dt, direction)
    self.rotatedTime = networkRotatedTime
  else
    superFunc(self, steeringWheel, dt, direction)
  end
end

---Keeps the source idle-turning wheel geometry while mouse steering is active
-- @param superFunc function original steering angle update function
-- @param wheel table wheel data
-- @param dt number delta time since last call in ms
-- @param steeringAngle number regular steering angle
-- @return number steeringAngle adjusted steering angle
function MouseSteeringVehicle:updateSteeringAngle(superFunc, wheel, dt, steeringAngle)
  steeringAngle = superFunc(self, wheel, dt, steeringAngle)

  local spec = self.spec_mouseSteeringVehicle
  local drivableSpec = self.spec_drivable
  local isLocallyControlled = self.getIsEnteredForInput ~= nil and self:getIsEnteredForInput()

  if spec ~= nil and drivableSpec ~= nil and spec.isUsed and isLocallyControlled and drivableSpec.idleTurningActive then
    local isAIActive = self.getIsAIActive ~= nil and self:getIsAIActive()
    if not isAIActive and AIAutomaticSteering ~= nil and self.getAIAutomaticSteeringState ~= nil then
      isAIActive = self:getAIAutomaticSteeringState() == AIAutomaticSteering.STATE.ACTIVE
    end

    local axisSide = MouseSteeringVehicle.isFiniteNumber(spec.axisSide) and spec.axisSide or drivableSpec.axisSide
    local idleTurningWheels = drivableSpec.idleTurningWheels
    if not isAIActive and idleTurningWheels ~= nil and math.abs(axisSide or 0) > 0.0001 then
      for _, wheelData in ipairs(idleTurningWheels) do
        if wheel.repr == wheelData.wheelNode or wheel.driveNode == wheelData.wheelNode then
          -- Fixed idle-turning geometry prevents forward creep at partial input.
          return wheelData.steeringAngle + (wheelData.inverted and math.pi or 0)
        end
      end
    end
  end

  return steeringAngle
end

---Synchronizes idle-turning input with mouse steering and virtual pedal control
-- @param vehicle table vehicle instance
-- @param axisForward number forward/reverse input
-- @param axisSide number steering input
-- @return number axisForward synchronized forward/reverse input
-- @return number axisSide synchronized steering input
-- @return boolean isPedalControlActive true when idle turning was replaced by virtual pedal input
function MouseSteeringVehicle.synchronizeIdleTurningState(vehicle, axisForward, axisSide)
  local drivableSpec = vehicle.spec_drivable
  if not drivableSpec.idleTurningActive then
    return axisForward, axisSide, false
  end

  local spec = vehicle.spec_mouseSteeringVehicle
  local speedControlSpec = vehicle.spec_mouseSteeringSpeedControl
  local isPedalControlActive = speedControlSpec ~= nil and speedControlSpec.isActive and speedControlSpec.activeMode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT
  local isLocallyControlled = vehicle.getIsEnteredForInput ~= nil and vehicle:getIsEnteredForInput()
  local idleTurningActive = true

  if isPedalControlActive then
    if isLocallyControlled and MouseSteeringVehicle.isFiniteNumber(spec.axisSide) then
      axisSide = spec.axisSide
    else
      local steeringDirection = math.sign(drivableSpec.axisForward) * math.sign(drivableSpec.idleTurningDirection or 0)
      axisSide = steeringDirection == 0 and axisSide or math.abs(axisSide) * steeringDirection
    end

    axisForward = 0
    idleTurningActive = false
  elseif spec.isUsed and isLocallyControlled then
    local steeringAxis = MouseSteeringVehicle.isFiniteNumber(axisSide) and axisSide or spec.axisSide
    axisForward = math.sign(axisForward or 0) * math.clamp(math.abs(steeringAxis or 0), 0, 1)
  end

  if axisForward ~= drivableSpec.axisForward or axisSide ~= drivableSpec.axisSide or idleTurningActive ~= drivableSpec.idleTurningActive then
    drivableSpec.axisForward = axisForward
    drivableSpec.axisForwardSend = axisForward
    drivableSpec.axisSide = axisSide
    drivableSpec.axisSideSend = axisSide
    drivableSpec.idleTurningActive = idleTurningActive
    drivableSpec.idleTurningActiveSend = idleTurningActive
    vehicle:raiseDirtyFlags(drivableSpec.dirtyFlag)
  end

  return axisForward, axisSide, isPedalControlActive
end

---Adjusts idle-turning physics for mouse steering and virtual pedal input
-- @param superFunc function original vehicle physics update function
-- @param axisForward number forward/reverse input
-- @param axisSide number steering input
-- @param doHandbrake boolean handbrake state
-- @param dt number delta time since last call in ms
function MouseSteeringVehicle:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
  local synchronizedAxisForward, synchronizedAxisSide, isPedalControlActive = MouseSteeringVehicle.synchronizeIdleTurningState(self, axisForward, axisSide)

  if isPedalControlActive then
    axisSide = synchronizedAxisSide
  else
    axisForward = synchronizedAxisForward
  end

  return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end

---Called on update
-- @param dt number delta time since last call in ms
-- @param isActiveForInput boolean true if vehicle is active for input
-- @param isActiveForInputIgnoreSelection boolean true if vehicle is active for input ignoring selection
-- @param isSelected boolean true if vehicle is selected
function MouseSteeringVehicle:onUpdate(dt, _, _, _)
  local spec = self.spec_mouseSteeringVehicle

  if not self:getIsEntered() then
    return
  end

  -- track AI steering state
  local aiState
  if self.getAIAutomaticSteeringState ~= nil then
    aiState = self:getAIAutomaticSteeringState()
  end

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

  if self:getIsControlled() then
    local isAIActive = AIAutomaticSteering ~= nil and aiState == AIAutomaticSteering.STATE.ACTIVE
    local isWorkerAIActive = self:getIsAIActive()

    -- track AI transitions
    local currentAIActive = isAIActive or isWorkerAIActive
    if spec.lastIsAIActive and not currentAIActive and spec.isUsed then
      self:synchronizeMouseSteeringAxisSide()
    end
    spec.lastIsAIActive = currentAIActive

    if spec.isUsed then
      local inputBinding = g_inputBinding
      local isUiVisible = inputBinding:getShowMouseCursor() or g_gui.currentGui ~= nil

      if isUiVisible and spec.isSteeringPaused then
        self:setMouseSteeringSteeringPaused(false)
      end

      local isPaused = spec.isSteeringPaused or isUiVisible

      -- check for active combos only if not already paused
      if not isPaused then
        local inputDisplayManager = g_inputDisplayManager
        local useGamepadButtons = (inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD)
        local hasCombos = next(inputDisplayManager:getComboHelpElements(useGamepadButtons)) ~= nil

        if hasCombos then
          local pressedComboMaskGamepad, pressedComboMaskMouse = inputBinding:getComboCommandPressedMask()
          local currentPressedMask = useGamepadButtons and pressedComboMaskGamepad or pressedComboMaskMouse

          if currentPressedMask ~= 0 then
            isPaused = true
          end
        end
      end

      -- track pause transition (from paused to unpaused) to freeze wheel position
      if spec.lastIsPaused and not isPaused then
        self:synchronizeMouseSteeringAxisSide()
      end
      spec.lastIsPaused = isPaused

      local isPowered, powerWarning = self:getIsPowered()
      local movedSide = spec.mouseSteering:getMovedSide()

      if isPowered then
        local speedKmh = 0

        -- vehicle speed only affects newly integrated mouse movement
        if spec.settings.speedBasedSteering and movedSide ~= 0 and not isPaused then
          speedKmh = self:getLastSpeed()
        end

        -- update controller and store both steering representations
        spec.inputValue, spec.axisSide = spec.controller:update(spec.inputValue, spec.axisSide, spec.settings, movedSide, isPaused, speedKmh, dt)
      elseif movedSide ~= 0 and not isPaused then
        if powerWarning == nil then
          powerWarning = self:getCanMotorRun() and g_i18n:getText("warning_motorNotStarted") or self:getMotorNotAllowedWarning()
        end

        if powerWarning ~= nil then
          g_currentMission:showBlinkingWarning(powerWarning, 2000)
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

      -- keep the cached player input aligned with the physical steering while AI is in control
      if isAIActive or isWorkerAIActive then
        self:synchronizeMouseSteeringAxisSide()
      end

      -- apply steering input to vehicle
      self:setSteeringInput(spec.axisSide, true, InputDevice.CATEGORY.WHEEL)

      -- Keep idle-turning state compatible with mouse steering and virtual pedal input.
      local drivableSpec = self.spec_drivable
      local wasIdleTurningActive = drivableSpec.idleTurningActive
      MouseSteeringVehicle.synchronizeIdleTurningState(self, drivableSpec.axisForward, drivableSpec.axisSide)

      -- Drivable skips the steering-wheel animation during idle turning when configured in XML.
      if drivableSpec.idleTurningAllowed and wasIdleTurningActive and not drivableSpec.idleTurningUpdateSteeringWheel and drivableSpec.steeringWheel ~= nil then
        self:updateSteeringWheel(drivableSpec.steeringWheel, dt, 1)
      end
    end

    -- update HUD and camera
    self:updateMouseSteeringHUD()

    local isActiveForInput = self.isActiveForInputIgnoreSelectionIgnoreAI == true
    local shouldCaptureMouse = isActiveForInput and self:getIsEnteredForInput() and not isWorkerAIActive

    if shouldCaptureMouse and isAIActive then
      shouldCaptureMouse = spec.settings.steeringAssist and isSteeringAssist
    end

    self:setMouseSteeringCameraRotating(not shouldCaptureMouse)

    -- update camera rotation following steering and centering
    local camera = self:getActiveCamera()
    local camIndex = self.spec_enterable.camIndex

    local isCameraFollowAllowed = spec.isUsed and spec.cameraRotationActive and not isWorkerAIActive and (not isAIActive or spec.settings.steeringAssist == true)
    spec.cameraRotation:setSettings(spec.settings, isCameraFollowAllowed)
    spec.cameraRotation:update(dt, camera, camIndex, spec.isSteeringPaused)
  end
end

---Action event handler for centering camera (single click) and look-back (double click)
function MouseSteeringVehicle.actionEventCenterCamera(self, _, inputValue, _, _)
  if inputValue == 1 then
    local spec = self.spec_mouseSteeringVehicle

    if spec.isUsed then
      -- detect double click
      local now = g_time
      local doubleClickThreshold = 300
      local isDoubleClick = (now - spec.centerCameraLastClickTime) < doubleClickThreshold
      spec.centerCameraLastClickTime = now

      local camera = self:getActiveCamera()

      -- center camera or look back
      if isDoubleClick then
        local centerVertical = spec.cameraRotation:getCenterVertical()
        spec.cameraRotation:lookBack(camera, centerVertical)
      else
        spec.cameraRotation:centerCamera(camera)
      end
    end
  end
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

  -- check conditions
  local isVisible = true

  if not spec.isUsed or not self:getIsControlled() or self:getIsAIActive() or not self:getIsMotorStarted() then
    isVisible = false
  else
    local isObstructed = ingameMessage:getVisible() or contextActionDisplay:getVisible()

    if isObstructed then
      isVisible = false
    else
      local hudSetting = tostring(spec.settings.indicatorMode)

      if hudSetting == "both" then
        isVisible = true
      elseif hudSetting == "inside" then
        isVisible = activeCamera.isInside
      elseif hudSetting == "outside" then
        isVisible = not activeCamera.isInside
      else
        isVisible = false
      end

      -- check backwards view inside cabin
      if isVisible and spec.settings.indicatorLookBackInside and activeCamera.isInside then
        local rotY = math.deg(activeCamera.rotY - activeCamera.origRotY) % 360
        isVisible = (rotY >= 120 and rotY <= 240)
      end
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
-- @param isControlling boolean true for the locally controlled player
function MouseSteeringVehicle:onEnterVehicle(isControlling)
  if not isControlling then
    return
  end

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
    self:synchronizeMouseSteeringAxisSide(self.spec_drivable.axisSide)

    -- prime Drivable before its first update after entering
    self:setSteeringInput(spec.axisSide, true, InputDevice.CATEGORY.WHEEL)
  end

  -- initialize camera rotation for first frame
  local isWorkerAIActive = self:getIsAIActive()
  local isCameraFollowAllowed = spec.isUsed and spec.cameraRotationActive and not isWorkerAIActive
  spec.cameraRotation:setSettings(spec.settings, isCameraFollowAllowed)

  local camIndex = self.spec_enterable.camIndex
  local camera = self:getActiveCamera()

  if camera ~= nil and camera.isInside then
    local intensity = spec.cameraRotation:getIntensity()

    if intensity > 0 then
      local deadzoneDegrees = spec.cameraRotation:getDeadzoneDegrees()
      spec.cameraRotation:initializeCamera(camera, camIndex, deadzoneDegrees, intensity)
    end
  end
end

---Called when leaving a vehicle
-- @param wasEntered boolean true for the locally controlled player
function MouseSteeringVehicle:onLeaveVehicle(wasEntered)
  if not wasEntered then
    return
  end

  local spec = self.spec_mouseSteeringVehicle

  -- preserve current steering and discard pending input
  if spec.isUsed then
    self:synchronizeMouseSteeringAxisSide()
  end

  self:setSteeringInput(0, true, InputDevice.CATEGORY.WHEEL)

  -- save camera state on leave
  spec.cameraRotation:resetState(nil)

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
    self:synchronizeMouseSteeringAxisSide()
  elseif not spec.isUsed and wasEnabled then
    self:setSteeringInput(0, true, InputDevice.CATEGORY.WHEEL)
  end

  -- update controlled vehicle if requested
  if updateControlledVehicle then
    if spec.isUsed then
      self:setMouseSteeringControlled(true)
    elseif wasEnabled then
      self:setMouseSteeringControlled(false)
    end
  end

  -- refresh action events text/visibility based on current state
  MouseSteeringVehicle.updateActionEvents(self)
end

---Called when default setting is changed
-- @param value any new value
function MouseSteeringVehicle:onDefaultSettingChanged(_)
  if self:getIsEntered() then
    self:updateMouseSteeringState(false)
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
function MouseSteeringVehicle.actionEventSteering(self, _, inputValue, _, _)
  if inputValue == 1 then
    self:setMouseSteeringUsed()
  end
end

---Enables or disables mouse steering
function MouseSteeringVehicle:setMouseSteeringUsed()
  local spec = self.spec_mouseSteeringVehicle

  spec.isUsed = not spec.isUsed
  spec.wasUserToggled = true

  -- sync axis immediately when enabled so wheels don't jump calculation
  if spec.isUsed then
    self:synchronizeMouseSteeringAxisSide()
  else
    self:setSteeringInput(0, true, InputDevice.CATEGORY.WHEEL)
  end

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
function MouseSteeringVehicle.actionEventCameraFollow(self, _, inputValue, _, _)
  if inputValue == 1 then
    self:setCameraRotationActive()
  end
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
  else
    spec.cameraRotationActive = not spec.cameraRotationActive
  end
end

---
function MouseSteeringVehicle.actionEventSaveSteering(self, _, inputValue, _, _)
  if inputValue == 1 then
    self:setMouseSteeringSaved()
  end
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
function MouseSteeringVehicle.actionEventRotateCamera(self, _, inputValue, _, _)
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
function MouseSteeringVehicle:onRegisterActionEvents(_, _)
  if self.isClient then
    local spec = self.spec_mouseSteeringVehicle
    self:clearActionEventsTable(spec.actionEvents)

    -- register when player is controlling the vehicle and AI is inactive
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
-- @param axisOverride number|nil Optional normalized steering axis
-- @return number axisValue The calculated axis value
-- @return number steerRaw The calculated raw steering input
function MouseSteeringVehicle:calculateAxisAndSteering(spec, axisOverride)
  local axisValue = axisOverride
  local drivableSpec = self.spec_drivable

  if axisValue == nil then
    local rotatedTime = self.rotatedTime
    local maxRotTime = self.maxRotTime
    local minRotTime = self.minRotTime
    local steeringDirection = self:getSteeringDirection()

    if rotatedTime ~= nil and maxRotTime ~= nil and minRotTime ~= nil and maxRotTime ~= 0 and minRotTime ~= 0 and steeringDirection ~= nil and steeringDirection ~= 0 then
      if rotatedTime < 0 then
        axisValue = rotatedTime / -maxRotTime / steeringDirection
      else
        axisValue = rotatedTime / minRotTime / steeringDirection
      end
    else
      axisValue = drivableSpec.axisSide or 0
    end
  end

  if not MouseSteeringVehicle.isFiniteNumber(axisValue) then
    axisValue = drivableSpec.axisSide
  end

  if not MouseSteeringVehicle.isFiniteNumber(axisValue) then
    axisValue = 0
  end

  axisValue = math.clamp(axisValue, -1, 1)

  -- get settings and controller
  local settings = spec.settings
  local controller = spec.controller

  -- reverse the same transformations used by the controller update
  local deadzoneThreshold = controller:calculateEffectiveDeadzone(settings)
  local linearity = controller:getEffectiveLinearity(settings)
  local normalizedValue = controller:reverseLinearity(axisValue, linearity)
  local steerRaw = controller:reverseDeadzone(normalizedValue, deadzoneThreshold)

  return axisValue, steerRaw
end

---Synchronizes the mouse steering controller with the vehicle's steering
-- @param axisOverride number|nil Optional authoritative normalized steering axis
function MouseSteeringVehicle:synchronizeMouseSteeringAxisSide(axisOverride)
  local spec = self.spec_mouseSteeringVehicle
  spec.axisSide, spec.inputValue = self:calculateAxisAndSteering(spec, axisOverride)
end

---Keeps local mouse steering input active on vehicle types with AI job control
function MouseSteeringVehicle:getIsVehicleControlledByPlayer(superFunc)
  local spec = self.spec_mouseSteeringVehicle
  local isLocallyControlled = self.getIsEnteredForInput ~= nil and self:getIsEnteredForInput()
  local isWorkerAIActive = self.getIsAIActive ~= nil and self:getIsAIActive()

  if spec ~= nil and spec.isUsed and isLocallyControlled and not isWorkerAIActive then
    return true
  end

  if superFunc ~= nil then
    return superFunc(self)
  end

  return false
end

---Normalizes mouse steering input before passing it to Drivable
function MouseSteeringVehicle:setSteeringInput(superFunc, inputValue, isAnalog, deviceCategory)
  local spec = self.spec_mouseSteeringVehicle

  if not spec.isUsed then
    return superFunc(self, inputValue, isAnalog, deviceCategory)
  end

  local steeringInput = MouseSteeringVehicle.isFiniteNumber(inputValue) and math.clamp(inputValue, -1, 1) or 0

  if math.abs(steeringInput) < 0.0001 then
    steeringInput = 0

    local drivableSpec = self.spec_drivable
    if drivableSpec.idleTurningAllowed then
      drivableSpec.idleTurningActive = false
      drivableSpec.idleTurningDirection = 0
      drivableSpec.axisSide = 0
    end
  end

  return superFunc(self, steeringInput, isAnalog, deviceCategory)
end

---Gets the current mouse steering axis value
-- @return number axis value
function MouseSteeringVehicle:getMouseSteeringAxisSide()
  return self.spec_mouseSteeringVehicle.axisSide
end

---Gets the unique identifier for this vehicle
-- @return string uniqueId vehicle unique identifier
function MouseSteeringVehicle:getMouseSteeringUniqueId()
  return MouseSteeringVehicle.resolveUniqueId(self)
end

---Gets whether mouse steering is currently used/enabled
-- @return boolean isUsed true if mouse steering is enabled
function MouseSteeringVehicle:getIsMouseSteeringUsed()
  return self.spec_mouseSteeringVehicle.isUsed
end

---Gets whether mouse steering is currently paused (e.g., during camera rotation)
-- @return boolean isPaused true if mouse steering is paused
function MouseSteeringVehicle:getIsMouseSteeringSteeringPaused()
  local spec = self.spec_mouseSteeringVehicle
  return spec.isUsed and spec.isSteeringPaused
end
