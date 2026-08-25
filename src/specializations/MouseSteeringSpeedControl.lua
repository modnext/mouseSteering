--
-- MouseSteeringSpeedControl
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- name of the mod
local modName = g_currentModName

MouseSteeringSpeedControl = {
  MODE_TARGET_SPEED = "targetSpeed",
  MODE_PEDAL_PERCENT = "pedalPercent",
}

---Checks if all prerequisite specializations are loaded
-- @param specializations table specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function MouseSteeringSpeedControl.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Drivable, specializations) and not SpecializationUtil.hasSpecialization(Locomotive, specializations)
end

---Register all functions from the specialization that can be called on vehicle level
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlIsActive", MouseSteeringSpeedControl.getIsActive)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlDisplayInfo", MouseSteeringSpeedControl.getDisplayInfo)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlEnabled", MouseSteeringSpeedControl.getSpeedControlEnabled)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlMode", MouseSteeringSpeedControl.getControlMode)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringSpeedControlState", MouseSteeringSpeedControl.setMouseSteeringSpeedControlState)
  SpecializationUtil.registerFunction(vehicleType, "setMouseSteeringSpeedControlModeState", MouseSteeringSpeedControl.setMouseSteeringSpeedControlModeState)
end

---Register all function overwritings
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCruiseControlDisplayInfo", MouseSteeringSpeedControl.getCruiseControlDisplayInfo)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "setCruiseControlState", MouseSteeringSpeedControl.setCruiseControlState)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAxisForward", MouseSteeringSpeedControl.getPedalAxisValue)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAccelerationAxis", MouseSteeringSpeedControl.getPedalAxisValue)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDecelerationAxis", MouseSteeringSpeedControl.getPedalAxisValue)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAcDecelerationAxis", MouseSteeringSpeedControl.getPedalAxisValue)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", MouseSteeringSpeedControl.updateVehiclePhysics)
end

---Register event listeners
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", MouseSteeringSpeedControl)
  SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", MouseSteeringSpeedControl)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MouseSteeringSpeedControl)
  SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", MouseSteeringSpeedControl)
end

---Called on load
-- @param savegame table savegame
function MouseSteeringSpeedControl:onLoad(savegame)
  self.spec_mouseSteeringSpeedControl = self[string.format("spec_%s.mouseSteeringSpeedControl", modName)]
  local spec = self.spec_mouseSteeringSpeedControl

  -- initialize variables
  spec.mouseSteering = g_currentMission.mouseSteering
  spec.settings = spec.mouseSteering.settings

  -- initialize state
  spec.isActive = false
  spec.activeMode = MouseSteeringSpeedControl.MODE_TARGET_SPEED
  spec.targetSpeedKmh = 0
  spec.targetPedalPercent = 0
  spec.lastAppliedPedalAxis = nil
  spec.speedInterpolated = nil
  spec.ignoredPedalDirection = 0
  spec.ignoredPedalDirectionObserved = false
  spec.ignoredPedalGraceTime = 0
end

---Called when entering a vehicle
-- @param isControlling boolean true for the locally controlled player (unused)
function MouseSteeringSpeedControl:onEnterVehicle(_)
  if self.isServer then
    MouseSteeringSpeedControl.requestDeactivation(self)
  end
end

---Called when leaving a vehicle
-- @param wasEntered boolean true if the vehicle was entered
function MouseSteeringSpeedControl:onLeaveVehicle(wasEntered)
  MouseSteeringSpeedControl.requestDeactivation(self)
end

---Sets the legacy target-speed state and synchronizes it over the network
-- @param boolean isActive whether speed control is active
-- @param number targetSpeedKmh target speed in km/h
-- @param boolean noEventSend if true, skip network event
function MouseSteeringSpeedControl:setMouseSteeringSpeedControlState(isActive, targetSpeedKmh, noEventSend)
  self:setMouseSteeringSpeedControlModeState(isActive, MouseSteeringSpeedControl.MODE_TARGET_SPEED, targetSpeedKmh, 0, noEventSend)
end

---Sets the active control mode and synchronizes it over the network
-- @param boolean isActive whether speed control is active
-- @param string mode active control mode
-- @param number targetValue target speed in km/h or pedal position in percent
-- @param number ignoredPedalDirection physical pedal direction held during activation
-- @param boolean noEventSend if true, skip network event
function MouseSteeringSpeedControl:setMouseSteeringSpeedControlModeState(isActive, mode, targetValue, ignoredPedalDirection, noEventSend)
  local spec = self.spec_mouseSteeringSpeedControl
  local motor = self:getMotor()

  -- normalize mode and target before changing authoritative state
  if mode ~= MouseSteeringSpeedControl.MODE_PEDAL_PERCENT then
    mode = MouseSteeringSpeedControl.MODE_TARGET_SPEED
  end

  local isPedalMode = mode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT

  isActive = isActive == true and motor ~= nil
  targetValue = MathUtil.roundToStep(tonumber(targetValue) or 0, 1)

  if isActive then
    local isManualDirection = self:getIsManualDirectionChangeActive()

    if isPedalMode then
      local minPedalPercent = isManualDirection and 0 or -100

      targetValue = math.clamp(targetValue, minPedalPercent, 100)
      isActive = targetValue ~= 0
    else
      local maxForward = math.ceil(motor:getMaximumForwardSpeed() * 3.6)
      local maxReverse = math.ceil(motor:getMaximumBackwardSpeed() * 3.6)
      local minSpeed = isManualDirection and 0 or -maxReverse

      targetValue = math.clamp(targetValue, minSpeed, maxForward)
    end
  end

  if not isActive then
    targetValue = 0
  end

  local modeChanged = spec.activeMode ~= mode

  spec.isActive = isActive
  spec.activeMode = mode
  spec.targetSpeedKmh = isPedalMode and 0 or targetValue
  spec.targetPedalPercent = isPedalMode and targetValue or 0

  if not isActive or not isPedalMode then
    spec.lastAppliedPedalAxis = nil
  end

  spec.ignoredPedalDirection = isActive and math.clamp(math.sign(tonumber(ignoredPedalDirection) or 0), -1, 1) or 0
  spec.ignoredPedalDirectionObserved = false
  spec.ignoredPedalGraceTime = spec.ignoredPedalDirection ~= 0 and 250 or 0

  if not isActive or modeChanged or isPedalMode then
    spec.speedInterpolated = nil
  end

  -- send normalized state over the network
  if noEventSend ~= true then
    local event = SetMouseSteeringSpeedControlStateEvent.new(self, spec.isActive, spec.activeMode, targetValue, spec.ignoredPedalDirection)

    if self.isServer then
      local ownerConnection = self:getOwnerConnection()

      if ownerConnection ~= nil then
        ownerConnection:sendEvent(event)
      end
    elseif g_client ~= nil then
      g_client:getServerConnection():sendEvent(event)
    end
  end
end

---Requests synchronized deactivation if the control is active
-- @param vehicle table vehicle instance
function MouseSteeringSpeedControl.requestDeactivation(vehicle)
  local spec = vehicle.spec_mouseSteeringSpeedControl

  if spec ~= nil and spec.isActive then
    vehicle:setMouseSteeringSpeedControlModeState(false, spec.activeMode, 0, 0)
  end
end

---Clears the temporary physical-pedal handoff state
-- @param spec table speed-control specialization state
function MouseSteeringSpeedControl.clearIgnoredPedalState(spec)
  spec.ignoredPedalDirection = 0
  spec.ignoredPedalDirectionObserved = false
  spec.ignoredPedalGraceTime = 0
end

---Gets whether speed control is enabled in settings
-- @return boolean isSpeedControlEnabled true if speed control is enabled
function MouseSteeringSpeedControl:getSpeedControlEnabled()
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlState = spec.settings.speedControl

  return speedControlState == true
end

---Gets the configured control mode
-- @return string mode configured control mode
function MouseSteeringSpeedControl:getControlMode()
  local spec = self.spec_mouseSteeringSpeedControl
  local mode = spec.settings.speedControlMode

  if mode ~= MouseSteeringSpeedControl.MODE_PEDAL_PERCENT then
    mode = MouseSteeringSpeedControl.MODE_TARGET_SPEED
  end

  return mode
end

---Gets whether speed control is active
-- @return boolean isSpeedControlActive true if speed control is active
function MouseSteeringSpeedControl:getIsActive()
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()
  local isMouseSteeringUsed = self.getIsMouseSteeringUsed ~= nil and self:getIsMouseSteeringUsed()

  return speedControlEnabled and isMouseSteeringUsed and spec.isActive
end

---Gets display info for HUD
-- @return number value target speed in km/h or pedal position in percent
-- @return boolean isActive is active
-- @return string mode active control mode
function MouseSteeringSpeedControl:getDisplayInfo()
  local spec = self.spec_mouseSteeringSpeedControl

  if not spec.isActive then
    return 0, false, spec.activeMode
  end

  if spec.activeMode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT then
    return spec.targetPedalPercent, true, spec.activeMode
  end

  return math.abs(spec.targetSpeedKmh), true, spec.activeMode
end

---Calculates a target-speed change for one scroll-wheel tick
-- @param vehicle table vehicle instance
-- @param direction number scroll direction (+1 or -1)
-- @return number|nil targetSpeedKmh adjusted target or nil when activation has no effect
function MouseSteeringSpeedControl.getAdjustedTargetSpeed(vehicle, direction)
  local spec = vehicle.spec_mouseSteeringSpeedControl
  local motor = vehicle:getMotor()

  if motor == nil then
    return nil
  end

  local wasInactive = not spec.isActive
  local targetSpeedKmh = spec.targetSpeedKmh

  if wasInactive then
    -- activate at current vehicle speed
    local movingDir = vehicle.movingDirection or 0
    local reverserDir = vehicle:getReverserDirection()
    local isManualDir = vehicle:getIsManualDirectionChangeActive()
    local currentDir = isManualDir and (motor.currentDirection or 1) or 1
    local currentSpeedKmh = vehicle:getLastSpeed() * movingDir * reverserDir * currentDir

    -- eliminate physical jitter at standstill
    if math.abs(currentSpeedKmh) < 0.5 then
      currentSpeedKmh = 0
    end

    -- round toward scroll direction so ±1 always produces a visible change
    targetSpeedKmh = direction > 0 and math.floor(currentSpeedKmh) or math.ceil(currentSpeedKmh)
  end

  targetSpeedKmh = targetSpeedKmh + direction

  -- clamp to vehicle speed limits
  local maxForward = math.ceil(motor:getMaximumForwardSpeed() * 3.6)
  local maxReverse = math.ceil(motor:getMaximumBackwardSpeed() * 3.6)
  local isManualDirection = vehicle:getIsManualDirectionChangeActive()
  local minSpeed = isManualDirection and 0 or -maxReverse

  targetSpeedKmh = math.clamp(targetSpeedKmh, minSpeed, maxForward)

  if wasInactive and targetSpeedKmh == 0 then
    return nil
  end

  return targetSpeedKmh
end

---Calculates a pedal-position change for one scroll-wheel tick
-- @param vehicle table vehicle instance
-- @param direction number scroll direction (+1 or -1)
-- @param pedalAxis number current physical pedal input
-- @return number|nil targetPedalPercent adjusted target or nil when activation has no effect
function MouseSteeringSpeedControl.getAdjustedPedalPercent(vehicle, direction, pedalAxis)
  local spec = vehicle.spec_mouseSteeringSpeedControl
  local wasInactive = not spec.isActive
  local isManualDirection = vehicle:getIsManualDirectionChangeActive()
  local targetPedalPercent = spec.targetPedalPercent
  local pedalStep = 5

  pedalAxis = math.clamp(tonumber(pedalAxis) or 0, -1, 1)

  if wasInactive then
    if pedalAxis < -0.01 then
      return nil
    end

    local currentPedalPercent = (isManualDirection and math.max(pedalAxis, 0) or pedalAxis) * 100

    if math.abs(currentPedalPercent) < 1 then
      currentPedalPercent = 0
    end

    -- start from the physical pedal and move to the next visible 5% step
    targetPedalPercent = direction > 0
      and math.floor(currentPedalPercent / pedalStep) * pedalStep
      or math.ceil(currentPedalPercent / pedalStep) * pedalStep
  end

  targetPedalPercent = targetPedalPercent + direction * pedalStep
  targetPedalPercent = math.clamp(targetPedalPercent, isManualDirection and 0 or -100, 100)

  if wasInactive and targetPedalPercent == 0 then
    return nil
  end

  return targetPedalPercent
end

---Processes a scroll-wheel tick
-- @param vehicle table vehicle instance
-- @param direction number scroll direction (+1 or -1)
-- @param pedalAxis number current physical pedal input
-- @return boolean stateChanged true when the target was changed
function MouseSteeringSpeedControl.onScrollWheel(vehicle, direction, pedalAxis)
  local spec = vehicle.spec_mouseSteeringSpeedControl
  local wasInactive = not spec.isActive
  local mode = wasInactive and vehicle:getMouseSteeringSpeedControlMode() or spec.activeMode
  local targetValue

  direction = direction >= 0 and 1 or -1
  pedalAxis = tonumber(pedalAxis) or 0

  if mode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT then
    targetValue = MouseSteeringSpeedControl.getAdjustedPedalPercent(vehicle, direction, pedalAxis)
  else
    mode = MouseSteeringSpeedControl.MODE_TARGET_SPEED
    targetValue = MouseSteeringSpeedControl.getAdjustedTargetSpeed(vehicle, direction)
  end

  if targetValue == nil then
    return false
  end

  local ignoredPedalDirection = spec.ignoredPedalDirection

  if wasInactive and math.abs(pedalAxis) > 0.01 then
    ignoredPedalDirection = math.sign(pedalAxis)
  end

  local isActive = mode == MouseSteeringSpeedControl.MODE_TARGET_SPEED or targetValue ~= 0

  vehicle:setMouseSteeringSpeedControlModeState(isActive, mode, targetValue, ignoredPedalDirection)

  return true
end

---Called on update
function MouseSteeringSpeedControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
  if not self.isClient or self.getIsEntered == nil or not self:getIsEntered() then
    return
  end

  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()
  local isMouseSteeringUsed = self.getIsMouseSteeringUsed ~= nil and self:getIsMouseSteeringUsed()
  local configuredMode = self:getMouseSteeringSpeedControlMode()

  -- client settings gate activation; the server executes the synchronized runtime state
  if not speedControlEnabled or not isMouseSteeringUsed or (spec.isActive and spec.activeMode ~= configuredMode) then
    MouseSteeringSpeedControl.requestDeactivation(self)
    return
  end

  if not self:getIsVehicleControlledByPlayer() then
    MouseSteeringSpeedControl.requestDeactivation(self)
    return
  end

  local drivable = self.spec_drivable
  -- idle turning generates axisForward internally; it is not physical pedal input
  local pedalAxis = drivable.idleTurningActive and 0 or drivable.axisForward
  local pedalActive = math.abs(pedalAxis) > 0.01

  -- stop ignoring the activation input after release or an opposite pedal input
  if spec.ignoredPedalDirection ~= 0 and (not pedalActive or math.sign(pedalAxis) ~= spec.ignoredPedalDirection) then
    MouseSteeringSpeedControl.clearIgnoredPedalState(spec)
  end

  local inputController = spec.mouseSteering.inputController
  local scrollDirection = inputController:getScrollDirection()

  if scrollDirection ~= 0 and inputController:getIsSpeedControlInputCaptured() then
    MouseSteeringSpeedControl.onScrollWheel(self, scrollDirection, pedalAxis)
  end
end

---Overrides cruise-control display info to show the active mouse-wheel target
function MouseSteeringSpeedControl:getCruiseControlDisplayInfo(superFunc)
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()
  local isMouseSteeringUsed = self.getIsMouseSteeringUsed ~= nil and self:getIsMouseSteeringUsed()

  if speedControlEnabled and isMouseSteeringUsed and spec.isActive then
    local value, _, mode = self:getMouseSteeringSpeedControlDisplayInfo()

    if mode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT and g_i18n ~= nil then
      local unitFactor = g_i18n:getSpeed(1)

      if unitFactor ~= 0 then
        -- keep integer percentages stable after the HUD applies its unit conversion
        local displayEpsilon = value >= 0 and 0.001 or -0.001

        value = (value + displayEpsilon) / unitFactor
      end
    end

    return value, true
  end

  return superFunc(self)
end

---Overrides cruise-control state to deactivate mouse-wheel control when CC is activated
function MouseSteeringSpeedControl:setCruiseControlState(superFunc, state, noEventSend)
  local spec = self.spec_mouseSteeringSpeedControl

  if spec.isActive and state ~= Drivable.CRUISECONTROL_STATE_OFF then
    MouseSteeringSpeedControl.requestDeactivation(self)
  end

  return superFunc(self, state, noEventSend)
end

---Evaluates a native Drivable axis getter against the active pedal target
-- @param superFunc function original getter
-- @return number pedalValue native getter result
function MouseSteeringSpeedControl:getPedalAxisValue(superFunc)
  local spec = self.spec_mouseSteeringSpeedControl

  if not spec.isActive or spec.activeMode ~= MouseSteeringSpeedControl.MODE_PEDAL_PERCENT then
    return superFunc(self)
  end

  local drivableSpec = self.spec_drivable
  local previousAxisForward = drivableSpec.axisForward

  drivableSpec.axisForward = spec.targetPedalPercent / 100
  local pedalValue = superFunc(self)
  drivableSpec.axisForward = previousAxisForward

  return pedalValue
end

---Overrides vehicle physics to apply the active target-speed or pedal-position mode
function MouseSteeringSpeedControl:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
  local spec = self.spec_mouseSteeringSpeedControl

  if not spec.isActive then
    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
  end

  local drivableSpec = self.spec_drivable
  local isPedalMode = spec.activeMode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT

  -- idle turning and the previously mirrored target are not physical pedal input
  local hasPedalInput = not drivableSpec.idleTurningActive and math.abs(axisForward) > 0.01

  if hasPedalInput and spec.lastAppliedPedalAxis ~= nil then
    hasPedalInput = math.abs(axisForward - spec.lastAppliedPedalAxis) > 0.01
  end

  if spec.ignoredPedalDirection ~= 0 then
    spec.ignoredPedalGraceTime = math.max((spec.ignoredPedalGraceTime or 0) - dt, 0)
    local isIgnoredPedal = hasPedalInput
      and math.sign(axisForward) == spec.ignoredPedalDirection
      and (spec.ignoredPedalDirectionObserved or spec.ignoredPedalGraceTime > 0)

    if isIgnoredPedal then
      spec.ignoredPedalDirectionObserved = true
      hasPedalInput = false
    elseif hasPedalInput or spec.ignoredPedalDirectionObserved or spec.ignoredPedalGraceTime == 0 then
      MouseSteeringSpeedControl.clearIgnoredPedalState(spec)
    end
  end

  if isPedalMode then
    local hasInvalidDirection = self:getIsManualDirectionChangeActive() and spec.targetPedalPercent < 0
    local isMotorUnavailable = not self:getIsMotorStarted() or not self:getCanMotorRun()

    if hasPedalInput or doHandbrake or hasInvalidDirection or isMotorUnavailable then
      self:setMouseSteeringSpeedControlModeState(false, spec.activeMode, 0, 0)
    else
      axisForward = spec.targetPedalPercent / 100
    end
  else
    local motor = self:getMotor()
    local targetSpeed = math.abs(spec.targetSpeedKmh)

    if hasPedalInput or (targetSpeed == 0 and self:getLastSpeed() < 1) then
      self:setMouseSteeringSpeedControlModeState(false, spec.activeMode, 0, 0)
    else
      -- preserve the existing smooth target-speed behavior
      spec.speedInterpolated = spec.speedInterpolated or targetSpeed

      if targetSpeed ~= spec.speedInterpolated then
        local diff = targetSpeed - spec.speedInterpolated
        local dir = math.sign(diff)

        spec.speedInterpolated = (dir == 1 and math.min or math.max)(spec.speedInterpolated + dt * 0.0025 * math.max(1, math.abs(diff)) * dir, targetSpeed)
      end

      motor:setSpeedLimit(math.min(spec.speedInterpolated, motor:getSpeedLimit()))
      axisForward = math.sign(spec.targetSpeedKmh)
    end
  end

  local acceleration = superFunc(self, axisForward, axisSide, doHandbrake, dt)

  if spec.isActive and isPedalMode then
    -- expose the target through Drivable for animation and the update stream
    spec.lastAppliedPedalAxis = axisForward

    if drivableSpec.axisForward ~= axisForward or drivableSpec.axisForwardSend ~= axisForward then
      drivableSpec.axisForward = axisForward
      drivableSpec.axisForwardSend = axisForward
      self:raiseDirtyFlags(drivableSpec.dirtyFlag)
    end
  end

  return acceleration
end
