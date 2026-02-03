--
-- MouseSteeringCameraRotation
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringCameraRotation = {}

---
MouseSteeringCameraRotation.INTENSITY_VALUES = {
  off = 0,
  subtle = 0.5,
  normal = 1,
  strong = 1.5,
  max = 2
}

local MouseSteeringCameraRotation_mt = Class(MouseSteeringCameraRotation)

---Creates a new instance of MouseSteeringCameraRotation
function MouseSteeringCameraRotation.new(vehicle)
  local self = setmetatable({}, MouseSteeringCameraRotation_mt)

  self.vehicle = vehicle
  self.settings = nil
  self.isActive = false

  -- steering follow state
  self.rotationFactor = 0
  self.baseRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = nil
  self.lastIsPaused = false
  self.lastIsActive = false

  -- per-camera position storage (key = camIndex, value = {rotYOffset, followSteering, preservePosition})
  -- rotYOffset is relative to camera.origRotY (forward direction)
  self.savedCameraStates = {}

  -- centering state
  self.centering = false
  self.centerTargetRotY = nil
  self.centerTargetRotX = nil
  self.centeringWithSteering = false
  self.centerSteeringOffset = 0
  self.lastCenterRotY = nil
  self.lastCenterRotX = nil
  self.centeringRotX = false

  return self
end

---Sets the settings reference and active state
-- @param settings table Settings table reference
-- @param isActive boolean Whether camera follow steering is active
function MouseSteeringCameraRotation:setSettings(settings, isActive)
  self.settings = settings
  self.isActive = isActive or false
end

---Gets intensity value from current settings
-- @return number intensity value (0 if disabled or no settings)
function MouseSteeringCameraRotation:getIntensity()
  if not self.isActive or not self.settings then
    return 0
  end

  local state = self.settings.cameraRotationInside or "off"
  return MouseSteeringCameraRotation.INTENSITY_VALUES[state] or 0
end

---Gets deadzone value from current settings
-- @return number deadzone in degrees
function MouseSteeringCameraRotation:getDeadzoneDegrees()
  if not self.settings then
    return 0
  end
  return self.settings.cameraRotationDeadZone or 0
end

---Gets whether vertical centering is enabled
-- @return boolean centerVertical
function MouseSteeringCameraRotation:getCenterVertical()
  if not self.settings then
    return false
  end
  return self.settings.cameraRotationCenterVertical or false
end

---Checks if camera is valid and inside
function MouseSteeringCameraRotation:isValidInsideCamera(camera)
  return camera ~= nil and camera.isInside == true
end

---Normalizes angle difference to shortest path (-pi to pi)
function MouseSteeringCameraRotation:normalizeAngleDiff(diff)
  while diff > math.pi do
    diff = diff - 2 * math.pi
  end
  while diff < -math.pi do
    diff = diff + 2 * math.pi
  end
  return diff
end

---Calculates time-adjusted delta for smooth interpolation
function MouseSteeringCameraRotation:calculateSmoothDelta(diff, smoothingFactor, dt)
  local targetFrameTime = 16.666
  return diff * smoothingFactor * (dt / targetFrameTime)
end

---Gets sign of a number (1 for positive/zero, -1 for negative)
function MouseSteeringCameraRotation:getSign(value)
  return value >= 0 and 1 or -1
end

---Gets CabView rotation limits if mod is active
function MouseSteeringCameraRotation:getCabViewLimits(camera)
  if not self:isValidInsideCamera(camera) then
    return nil, nil
  end

  if not g_modIsLoaded.FS25_CabView then
    return nil, nil
  end

  local vehicle = self.vehicle
  if vehicle == nil then
    return nil, nil
  end

  local cabViewSpec = vehicle["spec_FS25_CabView.cabView"]
  if cabViewSpec == nil or cabViewSpec.rotationOffset == nil then
    return nil, nil
  end

  local cabViewMinRotBase = -0.1 * math.pi
  local cabViewMaxRotBase = 2.1 * math.pi

  local offset = cabViewSpec.rotationOffset
  return cabViewMinRotBase + offset, cabViewMaxRotBase + offset
end

---Calculates shortest angle difference respecting CabView limits
function MouseSteeringCameraRotation:getAngleDiff(from, to, camera)
  local minRot, maxRot = self:getCabViewLimits(camera)

  if minRot ~= nil and maxRot ~= nil then
    -- CabView active - clamp target and calculate direct difference
    local targetClamped = math.clamp(to, minRot, maxRot)
    return targetClamped - from
  else
    -- no CabView - use shortest path
    return self:normalizeAngleDiff(to - from)
  end
end

---Calculates normalized steering factor for camera rotation
-- Returns value between -1 and 1 with deadzone applied
function MouseSteeringCameraRotation:calculateSteeringFactor(cameraRotationDeadZoneDegrees)
  local vehicle = self.vehicle
  if vehicle == nil then
    return 0
  end

  local rotatedTime = vehicle.rotatedTime or 0
  if rotatedTime == 0 then
    return 0
  end

  -- calculate raw steering factor
  local steerFactor = 0
  if rotatedTime > 0 then
    local maxRotTime = vehicle.maxRotTime
    if maxRotTime and maxRotTime > 0 then
      steerFactor = rotatedTime / maxRotTime
    end
  else
    local minRotTime = vehicle.minRotTime
    if minRotTime and minRotTime < 0 then
      steerFactor = -(rotatedTime / minRotTime)
    end
  end

  -- steering factor calculation parameters
  local steerFactorThreshold = 0.1
  local steerFactorMultiplier = 1.524
  local steerFactorExponent = 2
  local maxSteeringAngleDegrees = 50.0

  -- apply threshold deadzone
  local absSteer = math.abs(steerFactor)
  if absSteer < steerFactorThreshold then
    return 0
  end

  -- apply exponential curve for smoother response
  local steerSign = self:getSign(steerFactor)
  local normalizedSteer = absSteer - steerFactorThreshold
  local curvedSteer = steerSign * steerFactorMultiplier * (normalizedSteer ^ steerFactorExponent)

  -- apply camera rotation dead zone
  local cameraDeadZone = cameraRotationDeadZoneDegrees / maxSteeringAngleDegrees
  local absCurved = math.abs(curvedSteer)

  if absCurved < cameraDeadZone then
    return 0
  end

  -- remap from [deadZone, 1.0] to [0, 1.0]
  local remappedSteer = (absCurved - cameraDeadZone) / (1.0 - cameraDeadZone)
  return steerSign * remappedSteer
end

---Calculates steering offset for given steering factor and intensity
function MouseSteeringCameraRotation:calculateSteeringOffset(steeringFactor, intensity)
  local steerOffsetScale = 0.5
  return steeringFactor * steerOffsetScale * intensity
end

---Saves current camera state for later restoration
function MouseSteeringCameraRotation:saveCameraState(camIndex, camera, rotYOffset, followSteering, preservePosition)
  if camIndex == nil or camera == nil then
    return
  end

  self.savedCameraStates[camIndex] = {
    rotYOffset = rotYOffset,
    followSteering = followSteering,
    preservePosition = preservePosition or false
  }
end

---Gets saved camera state for given index
function MouseSteeringCameraRotation:getSavedCameraState(camIndex)
  return self.savedCameraStates[camIndex]
end

---Calculates current rotation state as offset from forward direction
-- Returns manualOffset (user's manual camera adjustment) and followSteering flag
function MouseSteeringCameraRotation:calculateCurrentState(camera)
  local epsilon = 0.001

  local origRotY = camera.origRotY or 0
  -- manualOffset is only the user's manual adjustment, not including steering follow
  local manualOffset = (self.baseRotY or origRotY) - origRotY
  local followSteering = math.abs(self.rotationFactor) > epsilon

  return manualOffset, followSteering
end

---Finalizes centering and updates internal state
function MouseSteeringCameraRotation:finalizeCentering(camera)
  if self.centeringWithSteering then
    self.baseRotY = camera.origRotY or 0
    self.rotationFactor = self.centerSteeringOffset or 0
  else
    self.baseRotY = self.centerTargetRotY
    self.rotationFactor = 0
  end

  -- save state for current camera
  if self.lastCamIndex ~= nil then
    local rotYOffset, followSteering = self:calculateCurrentState(camera)
    self:saveCameraState(self.lastCamIndex, camera, rotYOffset, self.centeringWithSteering, false)
  end
end

---Cancels active centering operation
function MouseSteeringCameraRotation:cancelCentering()
  self.centering = false
  self.lastCenterRotY = nil
  self.lastCenterRotX = nil
  self.centeringRotX = false
end

---Resets camera rotation tracking state
function MouseSteeringCameraRotation:resetState(camIndex)
  -- finalize centering if active
  if self.centering and self.centerTargetRotY ~= nil and self.lastInsideCamera ~= nil then
    self:finalizeCentering(self.lastInsideCamera)
  end

  -- clear centering state
  self.centering = false
  self.centerTargetRotY = nil
  self.lastCenterRotY = nil

  -- save state for previous camera
  if self.lastCamIndex ~= nil and self.baseRotY ~= nil and self.lastInsideCamera ~= nil then
    local rotYOffset, followSteering = self:calculateCurrentState(self.lastInsideCamera)
    local preservePosition = self:isLookingBackwards(self.lastInsideCamera)
    self:saveCameraState(self.lastCamIndex, self.lastInsideCamera, rotYOffset, followSteering, preservePosition)
  end

  -- reset internal state
  self.baseRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = camIndex
  self.rotationFactor = 0
end

---Updates saved camera states when going to outside camera
-- For cameras that are not looking backwards, enable steering follow
-- so they will track steering when returning to inside
function MouseSteeringCameraRotation:updateStatesForOutsideCamera()
  for idx, state in pairs(self.savedCameraStates) do
    if not state.preservePosition then
      -- not looking backwards - enable steering follow but keep position offset
      state.followSteering = true
    end
  end
end

---Requests camera centering to forward or steering-follow position (internal use)
-- @param camera table Active camera
-- @param intensity number Rotation intensity setting
-- @param deadzoneDegrees number Dead zone in degrees
-- @param centerVertical boolean Whether to also center vertical (X) rotation
function MouseSteeringCameraRotation:requestCenter(camera, intensity, deadzoneDegrees, centerVertical)
  if camera == nil then
    return
  end

  local baseRotY = camera.origRotY or 0

  -- determine centering target based on intensity and camera type
  if intensity > 0 and camera.isInside then
    local steeringFactor = self:calculateSteeringFactor(deadzoneDegrees)
    local steeringOffset = self:calculateSteeringOffset(steeringFactor, intensity)

    self.centerTargetRotY = baseRotY + steeringOffset
    self.centeringWithSteering = true
    self.centerSteeringOffset = steeringOffset
  else
    self.centerTargetRotY = baseRotY
    self.centeringWithSteering = false
    self.centerSteeringOffset = 0
  end

  -- setup vertical (X) rotation centering if enabled
  self.centeringRotX = centerVertical or false
  if self.centeringRotX then
    self.centerTargetRotX = camera.origRotX or 0
    self.lastCenterRotX = camera.rotX
  else
    self.centerTargetRotX = nil
    self.lastCenterRotX = nil
  end

  self.centering = true
  self.lastCenterRotY = camera.rotY
end

---Requests camera centering using current settings
-- @param camera table Active camera
function MouseSteeringCameraRotation:centerCamera(camera)
  local intensity = self:getIntensity()
  local deadzoneDegrees = self:getDeadzoneDegrees()
  local centerVertical = self:getCenterVertical()

  self:requestCenter(camera, intensity, deadzoneDegrees, centerVertical)
end

---Requests camera centering to original position (no steering follow)
-- Used when camera follow steering is disabled
-- @param camera table Active camera
-- @param centerVertical boolean Whether to also center vertical (X) rotation
function MouseSteeringCameraRotation:requestCenterToOrigin(camera, centerVertical)
  if camera == nil then
    return
  end

  self.centerTargetRotY = camera.origRotY or 0
  self.centeringWithSteering = false
  self.centerSteeringOffset = 0

  -- setup vertical (X) rotation centering if enabled
  self.centeringRotX = centerVertical or false
  if self.centeringRotX then
    self.centerTargetRotX = camera.origRotX or 0
    self.lastCenterRotX = camera.rotX
  else
    self.centerTargetRotX = nil
    self.lastCenterRotX = nil
  end

  self.centering = true
  self.lastCenterRotY = camera.rotY
end

---Updates camera centering with smooth transition to target
function MouseSteeringCameraRotation:updateCentering(dt, camera, intensity, cameraRotationDeadZoneDegrees)
  if not self.centering then
    return
  end

  -- validate state
  if camera == nil or self.centerTargetRotY == nil then
    self:cancelCentering()
    return
  end

  local epsilon = 0.001
  local centeringSmoothingFactor = 0.05

  -- detect manual camera movement by user (horizontal Y axis)
  if self.lastCenterRotY ~= nil then
    local userMovementY = math.abs(camera.rotY - self.lastCenterRotY)
    if userMovementY > epsilon then
      self:cancelCentering()
      return
    end
  end

  -- detect manual camera movement by user (vertical X axis)
  if self.centeringRotX and self.lastCenterRotX ~= nil then
    local userMovementX = math.abs(camera.rotX - self.lastCenterRotX)
    if userMovementX > epsilon then
      self:cancelCentering()
      return
    end
  end

  -- update target dynamically if centering with steering follow
  if self.centeringWithSteering and intensity and intensity > 0 then
    local baseRotY = camera.origRotY or 0
    local steeringFactor = self:calculateSteeringFactor(cameraRotationDeadZoneDegrees)
    local steeringOffset = self:calculateSteeringOffset(steeringFactor, intensity)

    self.centerTargetRotY = baseRotY + steeringOffset
    self.centerSteeringOffset = steeringOffset
  end

  -- calculate differences
  local diffY = self:getAngleDiff(camera.rotY, self.centerTargetRotY, camera)
  local diffX = 0
  if self.centeringRotX and self.centerTargetRotX ~= nil then
    diffX = self.centerTargetRotX - camera.rotX
  end

  -- check if target reached (both axes if rotX centering is enabled)
  local reachedY = math.abs(diffY) < epsilon
  local reachedX = not self.centeringRotX or math.abs(diffX) < epsilon

  if reachedY and reachedX then
    camera.rotY = self.centerTargetRotY
    if self.centeringRotX and self.centerTargetRotX ~= nil then
      camera.rotX = self.centerTargetRotX
    end
    self:finalizeCentering(camera)
    self:cancelCentering()
  else
    -- ease-out interpolation for Y axis
    if not reachedY then
      local deltaY = self:calculateSmoothDelta(diffY, centeringSmoothingFactor, dt)
      camera.rotY = camera.rotY + deltaY
    else
      camera.rotY = self.centerTargetRotY
    end
    self.lastCenterRotY = camera.rotY

    -- ease-out interpolation for X axis
    if self.centeringRotX and not reachedX then
      local deltaX = self:calculateSmoothDelta(diffX, centeringSmoothingFactor, dt)
      camera.rotX = camera.rotX + deltaX
      self.lastCenterRotX = camera.rotX
    elseif self.centeringRotX and self.centerTargetRotX ~= nil then
      camera.rotX = self.centerTargetRotX
      self.lastCenterRotX = camera.rotX
    end
  end
end

---Checks if player is manually looking backwards (more than 90 degrees from forward)
-- Only checks manual camera rotation, excluding automatic steering follow
function MouseSteeringCameraRotation:isLookingBackwards(camera)
  if camera == nil or camera.origRotY == nil then
    return false
  end

  local backwardsThreshold = math.pi / 2

  local referenceRotY = self.baseRotY or camera.rotY
  local diff = self:getAngleDiff(camera.origRotY, referenceRotY, camera)

  return math.abs(diff) > backwardsThreshold
end

---Detects and applies user manual camera adjustments
-- Returns the movement amount applied to baseRotY
function MouseSteeringCameraRotation:applyUserMovement(camera)
  if self.baseRotY == nil then
    return 0
  end

  local epsilon = 0.001

  local expectedRotY = self.baseRotY + self.rotationFactor
  local userMovement = camera.rotY - expectedRotY

  if math.abs(userMovement) > epsilon then
    self.baseRotY = self.baseRotY + userMovement
    return userMovement
  end

  return 0
end

---Initializes camera state for a new or restored camera
function MouseSteeringCameraRotation:initializeCamera(camera, camIndex, cameraRotationDeadZoneDegrees, intensity)
  self.lastCamIndex = camIndex
  self.lastInsideCamera = camera

  local steeringFactor = self:calculateSteeringFactor(cameraRotationDeadZoneDegrees)
  local currentOffset = self:calculateSteeringOffset(steeringFactor, intensity)

  local savedState = self:getSavedCameraState(camIndex)

  if savedState ~= nil then
    local origRotY = camera.origRotY or 0
    local manualOffset = savedState.rotYOffset

    if savedState.preservePosition then
      -- looking backwards - restore exact position, no steering follow
      self.rotationFactor = 0
      self.baseRotY = origRotY + manualOffset
    elseif savedState.followSteering then
      -- restore with steering follow from manual offset position
      self.baseRotY = origRotY + manualOffset
      self.rotationFactor = currentOffset
    else
      -- restore exact position without steering follow
      self.rotationFactor = 0
      self.baseRotY = origRotY + manualOffset
    end
  else
    -- first time on this camera - start with steering follow active
    local origRotY = camera.origRotY or 0
    self.rotationFactor = currentOffset
    self.baseRotY = origRotY
  end

  -- set camera.rotY for immediate effect
  camera.rotY = self.baseRotY + self.rotationFactor
end

---Updates camera rotation to follow wheel steering
-- @param dt number Delta time in milliseconds
-- @param camera table Active camera
-- @param camIndex number Current camera index
-- @param isPaused boolean Whether steering is paused (alt key held)
function MouseSteeringCameraRotation:update(dt, camera, camIndex, isPaused)
  -- get settings values
  local intensity = self:getIntensity()
  local deadzoneDegrees = self:getDeadzoneDegrees()
  local centerVertical = self:getCenterVertical()

  -- handle camera change
  if self.lastCamIndex ~= nil and self.lastCamIndex ~= camIndex then
    self:resetState(camIndex)
  end

  -- handle active state changes (toggle camera follow steering)
  local wasActive = self.lastIsActive
  local justActivated = self.isActive and not wasActive
  local justDeactivated = not self.isActive and wasActive
  self.lastIsActive = self.isActive

  -- when activating, cancel any pending operations and start centering to steering follow
  if justActivated then
    if self.centering then
      self:cancelCentering()
    end
    -- start centering to steering follow position
    if camera ~= nil and self:isValidInsideCamera(camera) and intensity > 0 then
      self:requestCenter(camera, intensity, deadzoneDegrees, centerVertical)
    end
  end

  -- when deactivating, just freeze current position (no centering)
  if justDeactivated then
    if self.centering then
      self:cancelCentering()
    end
    -- freeze current position
    if self.baseRotY ~= nil and camera ~= nil then
      camera.rotY = self.baseRotY + self.rotationFactor
    end
    self:resetState(camIndex)
  end

  -- if not active, do nothing
  if not self.isActive then
    return
  end

  -- from here on, isActive is true

  -- handle pause state changes (alt key)
  local pauseStarted = isPaused and not self.lastIsPaused
  local pauseEnded = not isPaused and self.lastIsPaused
  self.lastIsPaused = isPaused

  -- when entering pause, cancel any automatic camera movement
  if pauseStarted then
    if self.centering then
      self:cancelCentering()
    end
  end

  -- when paused, do nothing - let game control camera
  if isPaused then
    return
  end

  -- when exiting pause, take current camera position as manual offset
  -- camera will continue steering follow from this position
  if pauseEnded then
    if camera ~= nil and self:isValidInsideCamera(camera) then
      local steeringFactor = self:calculateSteeringFactor(deadzoneDegrees)
      local currentSteeringOffset = self:calculateSteeringOffset(steeringFactor, intensity)

      -- set baseRotY so that baseRotY + currentSteeringOffset = camera.rotY
      -- this means camera stays exactly where it is
      self.baseRotY = camera.rotY - currentSteeringOffset
      self.rotationFactor = currentSteeringOffset
    end
    return
  end

  -- process centering (for manual center requests)
  self:updateCentering(dt, camera, intensity, deadzoneDegrees)
  if self.centering then
    return
  end

  -- validate preconditions
  if intensity <= 0 or not self:isValidInsideCamera(camera) then
    self:resetState(camIndex)
    -- update saved camera states for outside camera
    -- cameras not looking backwards will follow steering when returning
    self:updateStatesForOutsideCamera()
    return
  end

  -- initialize if needed
  if self.lastCamIndex ~= camIndex or self.baseRotY == nil then
    self:initializeCamera(camera, camIndex, deadzoneDegrees, intensity)
    return
  end

  -- handle backwards looking (disable follow but maintain position)
  if self:isLookingBackwards(camera) then
    self:applyUserMovement(camera)
    camera.rotY = self.baseRotY + self.rotationFactor
    return
  end

  -- camera rotation parameters
  local rotationSmoothingFactor = 0.06
  local rotationMaxDeltaPerMs = 0.002

  -- normal steering follow update
  local steeringFactor = self:calculateSteeringFactor(deadzoneDegrees)
  local targetOffset = self:calculateSteeringOffset(steeringFactor, intensity)

  -- apply user adjustments
  self:applyUserMovement(camera)

  -- smooth transition to target offset
  local diff = targetOffset - self.rotationFactor
  local delta = self:calculateSmoothDelta(diff, rotationSmoothingFactor, dt)

  -- clamp to max speed
  local maxDelta = rotationMaxDeltaPerMs * dt
  delta = math.clamp(delta, -maxDelta, maxDelta)

  self.rotationFactor = self.rotationFactor + delta
  camera.rotY = self.baseRotY + self.rotationFactor
end
