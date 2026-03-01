--
-- MouseSteeringSpeedControl
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- name of the mod
local modName = g_currentModName

MouseSteeringSpeedControl = {}

---Checks if all prerequisite specializations are loaded
-- @param specializations table specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function MouseSteeringSpeedControl.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Drivable, specializations)
      and not SpecializationUtil.hasSpecialization(Locomotive, specializations)
end

---Register all functions from the specialization that can be called on vehicle level
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlIsActive", MouseSteeringSpeedControl.getIsActive)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlDisplayInfo", MouseSteeringSpeedControl.getDisplayInfo)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringSpeedControlEnabled", MouseSteeringSpeedControl.getSpeedControlEnabled)
end

---Register all function overwritings
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerOverwrittenFunctions(vehicleType)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCruiseControlDisplayInfo", MouseSteeringSpeedControl.getCruiseControlDisplayInfo)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "setCruiseControlState", MouseSteeringSpeedControl.setCruiseControlState)
  SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", MouseSteeringSpeedControl.updateVehiclePhysics)
end

---Register event listeners
-- @param vehicleType table vehicle type
function MouseSteeringSpeedControl.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", MouseSteeringSpeedControl)
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

  -- initialize state flags
  spec.isActive = false
  spec.targetSpeedKmh = 0
  spec.speedInterpolated = nil
  spec.pedalHeldOnActivation = false
end

---Called when leaving a vehicle
-- @param wasEntered boolean true if the vehicle was entered
function MouseSteeringSpeedControl:onLeaveVehicle(wasEntered)
  local spec = self.spec_mouseSteeringSpeedControl

  MouseSteeringSpeedControl.deactivate(spec)
end

---Activates speed control at the given target speed
-- @param spec table The specialization spec
-- @param speedKmh number target speed in km/h
function MouseSteeringSpeedControl.activate(spec, speedKmh)
  spec.isActive = true
  spec.targetSpeedKmh = speedKmh
end

---Deactivates speed control
-- @param spec table The specialization spec
function MouseSteeringSpeedControl.deactivate(spec)
  spec.isActive = false
  spec.targetSpeedKmh = 0
  spec.speedInterpolated = nil
  spec.pedalHeldOnActivation = false
end

---Gets whether speed control is enabled in settings
-- @return boolean isSpeedControlEnabled true if speed control is enabled
function MouseSteeringSpeedControl:getSpeedControlEnabled()
  local spec = self.spec_mouseSteeringSpeedControl

  local speedControlState = spec.settings.speedControl

  -- default to false if not set
  if speedControlState == nil then
    speedControlState = false
  end

  return speedControlState
end

---Gets whether speed control is active
-- @return boolean isSpeedControlActive true if speed control is active
function MouseSteeringSpeedControl:getIsActive()
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()

  return speedControlEnabled and spec.isActive
end

---Gets display info for HUD
-- @return number speed in km/h
-- @return boolean isActive is active
function MouseSteeringSpeedControl:getDisplayInfo()
  local spec = self.spec_mouseSteeringSpeedControl

  -- return 0 if inactive
  if not spec.isActive then
    return 0, false
  end

  -- return absolute target speed
  return math.abs(spec.targetSpeedKmh), true
end

---Processes a scroll wheel tick
-- @param spec table The specialization spec
-- @param vehicle table the vehicle
-- @param direction number scroll direction (+1 or -1)
function MouseSteeringSpeedControl.onScrollWheel(spec, vehicle, direction)
  local motor = vehicle:getMotor()

  if motor == nil then
    return
  end

  local wasInactive = not spec.isActive

  if wasInactive then
    -- activate at current vehicle speed
    local currentSpeedKmh = 0

    if vehicle.getLastSpeed ~= nil then
      local movingDir = vehicle.movingDirection or 0
      local reverserDir = vehicle:getReverserDirection()
      currentSpeedKmh = vehicle:getLastSpeed() * movingDir * reverserDir
    end

    -- eliminate physical jitter at standstill
    if math.abs(currentSpeedKmh) < 0.5 then
      currentSpeedKmh = 0
    end

    -- round toward scroll direction so ±1 always produces a visible change
    local roundedSpeed = direction > 0 and math.floor(currentSpeedKmh) or math.ceil(currentSpeedKmh)
    MouseSteeringSpeedControl.activate(spec, roundedSpeed)
  end

  -- always adjust by direction
  spec.targetSpeedKmh = spec.targetSpeedKmh + direction

  -- clamp to vehicle speed limits
  local maxForward = math.ceil(motor:getMaximumForwardSpeed() * 3.6)
  local maxReverse = math.ceil(motor:getMaximumBackwardSpeed() * 3.6)
  local isManualDirection = vehicle.getIsManualDirectionChangeActive ~= nil and vehicle:getIsManualDirectionChangeActive()
  local minSpeed = isManualDirection and 0 or -maxReverse

  spec.targetSpeedKmh = math.clamp(spec.targetSpeedKmh, minSpeed, maxForward)

  -- cancel activation if scroll had no effect (e.g. standing still, scrolling down in manual mode)
  if wasInactive and spec.targetSpeedKmh == 0 then
    MouseSteeringSpeedControl.deactivate(spec)
  end
end

---Called on update
function MouseSteeringSpeedControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()

  -- force-disable speed control when setting is off
  if not speedControlEnabled then
    if spec.isActive then
      MouseSteeringSpeedControl.deactivate(spec)
    end

    return
  end

  if self.isClient and (self.getIsEntered ~= nil and self:getIsEntered()) and not g_gui:getIsGuiVisible() then
    if self.isActiveForInputIgnoreSelectionIgnoreAI then
      if self:getIsVehicleControlledByPlayer() then
        -- track if gas/brake is held when scrolling
        local drivable = self.spec_drivable
        local pedalActive = drivable ~= nil and math.abs(drivable.axisForward) > 0.01

        local scrolled = false

        -- block speed control if camera rotation is currently active
        local isCameraRotating = self.getIsMouseSteeringSteeringPaused ~= nil and self:getIsMouseSteeringSteeringPaused()

        if not isCameraRotating then
          if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
            MouseSteeringSpeedControl.onScrollWheel(spec, self, 1)
            scrolled = true
          end

          if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
            MouseSteeringSpeedControl.onScrollWheel(spec, self, -1)
            scrolled = true
          end
        end

        -- if just activated while pedal was held, mark it
        if scrolled and spec.isActive and pedalActive then
          spec.pedalHeldOnActivation = true
        end
      end
    end
  end
end

---Overrides cruise control display to show speed control info
function MouseSteeringSpeedControl:getCruiseControlDisplayInfo(superFunc)
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()

  -- show speed control info when active
  if speedControlEnabled and spec.isActive then
    return math.abs(spec.targetSpeedKmh), true
  end

  return superFunc(self)
end

---Overrides cruise control state to deactivate speed control when CC is activated
function MouseSteeringSpeedControl:setCruiseControlState(superFunc, state, noEventSend)
  local spec = self.spec_mouseSteeringSpeedControl
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()

  -- force-disable speed control when setting is off
  if not speedControlEnabled and spec.isActive then
    MouseSteeringSpeedControl.deactivate(spec)
  end

  -- deactivate speed control when built-in cruise control is turned on
  if spec.isActive and state ~= Drivable.CRUISECONTROL_STATE_OFF then
    MouseSteeringSpeedControl.deactivate(spec)
  end

  return superFunc(self, state, noEventSend)
end

---Overrides updateVehiclePhysics to set motor speed limit when speed control is active
function MouseSteeringSpeedControl:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
  local spec = self.spec_mouseSteeringSpeedControl
  local motor = self:getMotor()
  local speedControlEnabled = self:getMouseSteeringSpeedControlEnabled()

  -- force-disable speed control when setting is off
  if not speedControlEnabled then
    if spec.isActive then
      MouseSteeringSpeedControl.deactivate(spec)
    end

    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
  end

  -- skip if speed control is not active or no motor
  if not spec.isActive or motor == nil then
    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
  end

  -- detect user pedal input
  local hasPedalInput = math.abs(axisForward) > 0.01

  -- ignore first pedal release if pedal was held during activation
  if spec.pedalHeldOnActivation then
    if not hasPedalInput then
      spec.pedalHeldOnActivation = false
    end
    hasPedalInput = false
  end

  local targetSpeed = math.abs(spec.targetSpeedKmh)

  -- deactivate if user presses pedal or vehicle is stopped with 0 target speed
  if hasPedalInput or (targetSpeed == 0 and self:getLastSpeed() < 1) then
    MouseSteeringSpeedControl.deactivate(spec)
  else
    -- interpolate speed limit towards target
    spec.speedInterpolated = spec.speedInterpolated or targetSpeed

    if targetSpeed ~= spec.speedInterpolated then
      local diff = targetSpeed - spec.speedInterpolated
      local dir = math.sign(diff)
      local limit = dir == 1 and math.min or math.max

      spec.speedInterpolated = limit(spec.speedInterpolated + dt * 0.0025 * math.max(1, math.abs(diff)) * dir, targetSpeed)
    end

    -- apply motor speed limit and override forward axis
    motor:setSpeedLimit(math.min(spec.speedInterpolated, motor:getSpeedLimit()))
    axisForward = spec.targetSpeedKmh == 0 and 0 or (spec.targetSpeedKmh >= 0 and 1 or -1)
  end

  return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end
