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
  self.manualRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = nil
  self.lastIsPaused = false
  self.lastIsActive = false

  -- per-camera position storage
  self.savedCameraStates = {}

  -- centering state
  self.centering = false
  self.centeringCamera = nil
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
  self.isActive = isActive == true
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
  return self.settings.cameraRotationCenterVertical == true
end

---Gets whether steering follow should gradually center manual camera adjustments
-- @return boolean autoCenter
function MouseSteeringCameraRotation:getAutoCenter()
  return self.settings ~= nil and self.settings.cameraRotationAutoCenter == true
end

---Checks if camera is valid and inside
function MouseSteeringCameraRotation:isValidInsideCamera(camera)
  return camera ~= nil and camera.isInside == true
end

---Normalizes an angle difference to the shortest path (-pi to pi)
function MouseSteeringCameraRotation:normalizeAngleDiff(diff)
  return MathUtil.getValidLimit(diff)
end

---Calculates a frame-rate independent delta for smooth interpolation
function MouseSteeringCameraRotation:calculateSmoothDelta(diff, smoothingFactor, dt)
  if dt <= 0 or diff == 0 then
    return 0
  end

  local FRAME_DURATION_MS = 1000 / 60
  local smoothingAmount = 1 - math.pow(1 - smoothingFactor, dt / FRAME_DURATION_MS)
  return diff * smoothingAmount
end

---Gets the CabView specialization for this vehicle, when available
function MouseSteeringCameraRotation:getCabViewSpec()
  if self.vehicle == nil or g_modIsLoaded == nil or not g_modIsLoaded.FS25_CabView then
    return nil
  end

  local CAB_VIEW_SPEC_NAME = "spec_FS25_CabView.cabView"
  return self.vehicle[CAB_VIEW_SPEC_NAME]
end

---Gets CabView rotation limits if mod is active
function MouseSteeringCameraRotation:getCabViewLimits(camera)
  if not self:isValidInsideCamera(camera) then
    return nil, nil
  end

  local cabViewSpec = self:getCabViewSpec()
  if cabViewSpec == nil or cabViewSpec.rotationOffset == nil or cabViewSpec.isInsideCamera ~= true then
    return nil, nil
  end

  local CAB_VIEW_MIN_ROTATION = -0.1 * math.pi
  local CAB_VIEW_MAX_ROTATION = 2.1 * math.pi
  local offset = cabViewSpec.rotationOffset
  return CAB_VIEW_MIN_ROTATION + offset, CAB_VIEW_MAX_ROTATION + offset
end

---Calculates shortest angle difference respecting CabView limits
function MouseSteeringCameraRotation:getAngleDiff(from, to, camera)
  local minRot, maxRot = self:getCabViewLimits(camera)

  if minRot ~= nil and maxRot ~= nil then
    -- CabView active - clamp target and calculate direct difference
    local targetClamped = math.clamp(to, minRot, maxRot)
    return targetClamped - from
  end

  -- no CabView - use the shortest path provided by the game API
  return self:normalizeAngleDiff(to - from)
end

---Calculates normalized steering factor for camera rotation
-- Returns a signed curved factor with the configured deadzone applied
function MouseSteeringCameraRotation:calculateSteeringFactor(cameraRotationDeadZoneDegrees)
  local STEERING_FACTOR_THRESHOLD = 0.1
  local STEERING_FACTOR_MULTIPLIER = 1.524
  local STEERING_FACTOR_EXPONENT = 2
  local MAX_STEERING_ANGLE_DEGREES = 50

  local vehicle = self.vehicle
  if vehicle == nil or vehicle.getMouseSteeringAxisSide == nil then
    return 0
  end

  local drivableSpec = vehicle.spec_drivable
  local axisSide = drivableSpec.axisSide
  if drivableSpec.idleTurningActive then
    axisSide = vehicle:getMouseSteeringAxisSide()
  end

  local steeringDirection = vehicle:getSteeringDirection()
  local isAxisValid = type(axisSide) == "number" and MathUtil.isFinite(axisSide)
  local isDirectionValid = type(steeringDirection) == "number" and MathUtil.isFinite(steeringDirection)
  if not isAxisValid or not isDirectionValid then
    return 0
  end

  -- Drivable reverses the steering axis when converting it to rotatedTime.
  -- Use the original mouse axis because idle turning gives both directions the same wheel angle.
  local steerFactor = -math.clamp(axisSide * steeringDirection, -1, 1)

  -- apply threshold deadzone
  local absSteer = math.abs(steerFactor)
  if absSteer < STEERING_FACTOR_THRESHOLD then
    return 0
  end

  -- apply exponential curve for smoother response
  local steerSign = steerFactor >= 0 and 1 or -1
  local normalizedSteer = absSteer - STEERING_FACTOR_THRESHOLD
  local curvedSteer = steerSign * STEERING_FACTOR_MULTIPLIER * (normalizedSteer ^ STEERING_FACTOR_EXPONENT)

  -- apply camera rotation dead zone
  local cameraDeadZone = math.clamp((cameraRotationDeadZoneDegrees or 0) / MAX_STEERING_ANGLE_DEGREES, 0, 0.99)
  local absCurved = math.abs(curvedSteer)

  if absCurved < cameraDeadZone then
    return 0
  end

  -- remap from [deadZone, 1.0] to [0, 1.0]
  local remappedSteer = (absCurved - cameraDeadZone) / (1.0 - cameraDeadZone)
  return steerSign * math.min(remappedSteer, 1)
end

---Calculates steering offset for given steering factor and intensity
function MouseSteeringCameraRotation:calculateSteeringOffset(steeringFactor, intensity)
  local STEERING_OFFSET_SCALE = 0.5
  return steeringFactor * STEERING_OFFSET_SCALE * intensity
end

---Calculates the current steering-driven Y rotation offset
function MouseSteeringCameraRotation:getCurrentSteeringOffset(cameraRotationDeadZoneDegrees, intensity)
  if intensity == nil or intensity <= 0 then
    return 0
  end

  local steeringFactor = self:calculateSteeringFactor(cameraRotationDeadZoneDegrees)
  return self:calculateSteeringOffset(steeringFactor, intensity)
end

---Saves current camera state for later restoration
function MouseSteeringCameraRotation:saveCameraState(camIndex, camera, rotYOffset, followSteering, preservePosition)
  if camIndex == nil or camera == nil then
    return
  end

  -- a rear view is restored without steering follow, so save its visible angle
  if preservePosition and self:getAutoCenter() then
    rotYOffset = camera.rotY - (camera.origRotY or 0)
  end

  self.savedCameraStates[camIndex] = {
    rotYOffset = rotYOffset,
    manualRotY = self.manualRotY,
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
  local origRotY = camera.origRotY or 0
  -- manualOffset is only the user's manual adjustment, not including steering follow
  local manualOffset = (self.baseRotY or origRotY) - origRotY
  local followSteering = not self:isLookingBackwards(camera)

  return manualOffset, followSteering
end

---Gets the centering correction within the same range as steering follow
function MouseSteeringCameraRotation:getCenteringOffset(camera, intensity)
  if not self:getAutoCenter() or intensity <= 0 or self.baseRotY == nil or self.manualRotY == nil or self:isLookingBackwards(camera) then
    return 0
  end

  return self:getAngleDiff(self.baseRotY, camera.origRotY or 0, camera)
end

---Takes the current camera rotation as the starting position for steering follow
function MouseSteeringCameraRotation:setCurrentCameraAsBase(camera, steeringOffset, centerAutomatically)
  local origRotY = camera.origRotY or 0
  local currentRotY = camera.rotY or 0
  local autoCenter = self:getAutoCenter() and centerAutomatically ~= false

  -- keep the range decision when Alt was held without changing the view
  if autoCenter and (self.baseRotY == nil or math.abs(self:getAngleDiff(self.baseRotY + self.rotationFactor, currentRotY, camera)) > 0.001) then
    self.manualRotY = currentRotY
  end

  -- retain the applied follow angle so steering changes cannot shift the manual range
  if not autoCenter then
    self.rotationFactor = steeringOffset or 0
    self.manualRotY = nil
  end
  self.baseRotY = currentRotY - self.rotationFactor

  return self:getAngleDiff(origRotY, self.baseRotY, camera)
end

---Preserves the current camera view as the base for steering follow
function MouseSteeringCameraRotation:preserveCurrentCamera(camera, camIndex, steeringOffset, followSteering, centerAutomatically)
  local manualOffset = self:setCurrentCameraAsBase(camera, steeringOffset, centerAutomatically)
  local preservePosition = self:isLookingBackwards(camera)

  self.lastCamIndex = camIndex
  self.lastInsideCamera = camera
  self:saveCameraState(camIndex, camera, manualOffset, followSteering == true, preservePosition)
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

  self.manualRotY = camera.rotY

  -- save state for current camera
  if self.lastCamIndex ~= nil then
    local rotYOffset = self:calculateCurrentState(camera)
    self:saveCameraState(self.lastCamIndex, camera, rotYOffset, self.centeringWithSteering, false)
  end
end

---Cancels active centering operation
function MouseSteeringCameraRotation:cancelCentering()
  self.centering = false
  self.centeringCamera = nil
  self.centerTargetRotY = nil
  self.centerTargetRotX = nil
  self.centeringWithSteering = false
  self.centerSteeringOffset = 0
  self.lastCenterRotY = nil
  self.lastCenterRotX = nil
  self.centeringRotX = false
end

---Starts a centering operation with a consistent state for both camera axes
function MouseSteeringCameraRotation:startCentering(camera, targetRotY, centerVertical, followSteering, steeringOffset)
  self.centering = true
  self.centeringCamera = camera
  self.centerTargetRotY = targetRotY
  self.centeringWithSteering = followSteering == true
  self.centerSteeringOffset = steeringOffset or 0
  self.lastCenterRotY = camera.rotY

  self.centeringRotX = centerVertical == true
  if self.centeringRotX then
    self.centerTargetRotX = camera.origRotX or 0
    self.lastCenterRotX = camera.rotX
  else
    self.centerTargetRotX = nil
    self.lastCenterRotX = nil
  end
end

---Resets camera rotation tracking state
function MouseSteeringCameraRotation:resetState(camIndex)
  local hadCameraState = self.centering or self.baseRotY ~= nil or self.lastInsideCamera ~= nil

  -- finalize centering if active
  if self.centering and self.centerTargetRotY ~= nil and self.centeringCamera == self.lastInsideCamera then
    self:finalizeCentering(self.lastInsideCamera)
  end

  -- clear centering state
  self:cancelCentering()

  -- save state for previous camera
  if self.lastCamIndex ~= nil and self.baseRotY ~= nil and self.lastInsideCamera ~= nil then
    local rotYOffset, followSteering = self:calculateCurrentState(self.lastInsideCamera)
    local preservePosition = self:isLookingBackwards(self.lastInsideCamera)
    self:saveCameraState(self.lastCamIndex, self.lastInsideCamera, rotYOffset, followSteering, preservePosition)
  end

  -- reset internal state
  self.baseRotY = nil
  self.manualRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = camIndex
  self.rotationFactor = 0

  return hadCameraState
end

---Updates saved camera states when going to outside camera
-- For cameras that are not looking backwards, enable steering follow
-- so they will track steering when returning to inside
function MouseSteeringCameraRotation:updateStatesForOutsideCamera()
  for _, state in pairs(self.savedCameraStates) do
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
  local targetRotY = baseRotY
  local followSteering = false
  local steeringOffset = 0

  -- determine centering target based on intensity and camera type
  if intensity > 0 and camera.isInside then
    steeringOffset = self:getCurrentSteeringOffset(deadzoneDegrees, intensity)
    targetRotY = baseRotY + steeringOffset
    followSteering = true
  end

  self:startCentering(camera, targetRotY, centerVertical, followSteering, steeringOffset)
end

---Requests camera centering using current settings
-- @param camera table Active camera
function MouseSteeringCameraRotation:centerCamera(camera)
  local intensity = self:getIntensity()
  local deadzoneDegrees = self:getDeadzoneDegrees()
  local centerVertical = self:getCenterVertical()

  self:requestCenter(camera, intensity, deadzoneDegrees, centerVertical)
end

---Requests camera rotation to look backwards
-- @param table camera Camera object to manipulate
-- @param boolean centerVertical Whether to center vertically
function MouseSteeringCameraRotation:lookBack(camera, centerVertical)
  if camera == nil then
    return
  end

  local baseRotY = camera.origRotY or 0
  local targetRotY

  -- check CabView limits
  local minRot, maxRot = self:getCabViewLimits(camera)
  -- look back over right shoulder to mod's rightmost limit
  if minRot ~= nil and maxRot ~= nil then
    targetRotY = minRot
  else
    targetRotY = baseRotY - math.pi
  end

  self:startCentering(camera, targetRotY, centerVertical, false, 0)
end

---Requests camera centering to original position (no steering follow)
-- Used when camera follow steering is disabled
-- @param camera table Active camera
-- @param centerVertical boolean Whether to also center vertical (X) rotation
function MouseSteeringCameraRotation:requestCenterToOrigin(camera, centerVertical)
  if camera == nil then
    return
  end

  self:startCentering(camera, camera.origRotY or 0, centerVertical, false, 0)
end

---Updates camera centering with smooth transition to target
function MouseSteeringCameraRotation:updateCentering(dt, camera, intensity, cameraRotationDeadZoneDegrees)
  local CENTERING_SMOOTHING_FACTOR = 0.05

  if not self.centering then
    return
  end

  -- cancel if the request no longer belongs to the active camera
  if camera == nil or camera ~= self.centeringCamera or self.centerTargetRotY == nil then
    self:cancelCentering()
    return
  end

  -- detect manual camera movement by user (horizontal Y axis)
  if self.lastCenterRotY ~= nil then
    local userMovementY = math.abs(camera.rotY - self.lastCenterRotY)
    if userMovementY > 0.001 then
      self:cancelCentering()
      return
    end
  end

  -- detect manual camera movement by user (vertical X axis)
  if self.centeringRotX and self.lastCenterRotX ~= nil then
    local userMovementX = math.abs(camera.rotX - self.lastCenterRotX)
    if userMovementX > 0.001 then
      self:cancelCentering()
      return
    end
  end

  -- update target dynamically if centering with steering follow
  if self.centeringWithSteering and intensity and intensity > 0 then
    local baseRotY = camera.origRotY or 0
    local steeringOffset = self:getCurrentSteeringOffset(cameraRotationDeadZoneDegrees, intensity)

    self.centerTargetRotY = baseRotY + steeringOffset
    self.centerSteeringOffset = steeringOffset
  end

  -- adjust target to shortest path if no CabView limits apply
  local minRot, maxRot = self:getCabViewLimits(camera)
  if minRot == nil or maxRot == nil then
    local shortestDiff = MathUtil.getAngleDifference(self.centerTargetRotY, camera.rotY)
    self.centerTargetRotY = camera.rotY + shortestDiff
  end

  -- the target has already been normalized or clamped, so a direct delta is safe
  local diffY = self.centerTargetRotY - camera.rotY
  local diffX = 0
  if self.centeringRotX and self.centerTargetRotX ~= nil then
    diffX = self.centerTargetRotX - camera.rotX
  end

  -- check if target reached (both axes if rotX centering is enabled)
  local reachedY = math.abs(diffY) < 0.001
  local reachedX = not self.centeringRotX or math.abs(diffX) < 0.001

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
      local deltaY = self:calculateSmoothDelta(diffY, CENTERING_SMOOTHING_FACTOR, dt)
      camera.rotY = camera.rotY + deltaY
    else
      camera.rotY = self.centerTargetRotY
    end
    self.lastCenterRotY = camera.rotY

    -- ease-out interpolation for X axis
    if self.centeringRotX and not reachedX then
      local deltaX = self:calculateSmoothDelta(diffX, CENTERING_SMOOTHING_FACTOR, dt)
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
  local BACKWARDS_ROTATION_THRESHOLD = math.pi / 2

  if camera == nil or camera.origRotY == nil then
    return false
  end

  local referenceRotY = self.baseRotY or camera.rotY
  if self:getAutoCenter() then
    -- automatic centering must not change whether the player chose to look backwards
    referenceRotY = self.manualRotY or camera.rotY
  end
  local diff = self:getAngleDiff(camera.origRotY, referenceRotY, camera)

  return math.abs(diff) > BACKWARDS_ROTATION_THRESHOLD
end

---Detects and applies user manual camera adjustments
-- Returns the movement amount applied to baseRotY
function MouseSteeringCameraRotation:applyUserMovement(camera)
  if self.baseRotY == nil then
    return 0
  end

  local expectedRotY = self.baseRotY + self.rotationFactor
  local userMovement = camera.rotY - expectedRotY

  if math.abs(userMovement) > 0.001 then
    self.baseRotY = self.baseRotY + userMovement
    self.manualRotY = camera.rotY
    return userMovement
  end

  return 0
end

---Initializes camera state for a new or restored camera
function MouseSteeringCameraRotation:initializeCamera(camera, camIndex, cameraRotationDeadZoneDegrees, intensity, preserveCurrentView)
  self.lastCamIndex = camIndex
  self.lastInsideCamera = camera

  local currentOffset = self:getCurrentSteeringOffset(cameraRotationDeadZoneDegrees, intensity)
  if preserveCurrentView then
    self:setCurrentCameraAsBase(camera, currentOffset, false)
  else
    local savedState = self:getSavedCameraState(camIndex)
    local origRotY = camera.origRotY or 0
    local manualOffset = savedState ~= nil and (savedState.rotYOffset or 0) or 0
    local shouldFollowSteering = savedState == nil or (savedState.followSteering and not savedState.preservePosition)

    self.baseRotY = origRotY + manualOffset
    self.rotationFactor = shouldFollowSteering and currentOffset or 0
    self.manualRotY = savedState ~= nil and savedState.manualRotY or nil

    -- a restored inside camera starts centered instead of resuming an old centering transition
    if self:getAutoCenter() and shouldFollowSteering then
      self.baseRotY = origRotY
      self.manualRotY = nil
    end
  end

  -- set camera.rotY for immediate effect
  camera.rotY = self.baseRotY + self.rotationFactor

  -- prevent CabView camera reset on vehicle enter
  local cabViewSpec = self:getCabViewSpec()
  if cabViewSpec ~= nil and cabViewSpec.resetView then
    cabViewSpec.resetView = false
  end
end

---Updates camera rotation to follow wheel steering
-- @param dt number Delta time in milliseconds
-- @param camera table Active camera
-- @param camIndex number Current camera index
-- @param isPaused boolean Whether steering is paused (alt key held)
function MouseSteeringCameraRotation:update(dt, camera, camIndex, isPaused)
  local ROTATION_SMOOTHING_FACTOR = 0.06
  local ROTATION_MAX_DELTA_PER_MS = 0.002

  -- get settings values
  local intensity = self:getIntensity()
  local deadzoneDegrees = self:getDeadzoneDegrees()
  local isInsideCamera = self:isValidInsideCamera(camera)
  isPaused = isPaused == true

  -- handle camera change
  local stateResetForCameraChange = false
  if self.lastCamIndex ~= nil and self.lastCamIndex ~= camIndex then
    stateResetForCameraChange = self:resetState(camIndex)
  end

  -- handle active state changes (toggle camera follow steering)
  local wasActive = self.lastIsActive
  local justActivated = self.isActive and not wasActive
  local justDeactivated = not self.isActive and wasActive
  self.lastIsActive = self.isActive

  -- preserve the current view so follow can resume without snapping
  if justActivated then
    if self.centering then
      self:cancelCentering()
    end

    if isInsideCamera then
      local steeringOffset = self:getCurrentSteeringOffset(deadzoneDegrees, intensity)
      self:preserveCurrentCamera(camera, camIndex, steeringOffset, intensity > 0, false)
    end
  end

  -- when deactivating, capture the current position without writing to the camera
  if justDeactivated then
    if self.centering then
      self:cancelCentering()
    end

    if self.baseRotY ~= nil and camera ~= nil then
      self.baseRotY = camera.rotY - self.rotationFactor
    end

    self:resetState(camIndex)
  end

  -- if not active, do nothing
  if not self.isActive and not self.centering then
    -- keep transition tracking synchronized while camera follow is disabled
    self.lastIsPaused = isPaused
    return
  end

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
    if isInsideCamera then
      local currentSteeringOffset = self:getCurrentSteeringOffset(deadzoneDegrees, intensity)

      -- keep the current camera position and continue from it
      self:preserveCurrentCamera(camera, camIndex, currentSteeringOffset, intensity > 0)
    end
    return
  end

  -- associate explicit center/look-back requests with the current inside camera
  if self.centering and self.centeringCamera == camera and isInsideCamera then
    self.lastCamIndex = camIndex
    self.lastInsideCamera = camera
  end

  -- process centering (only for explicit center/look-back requests)
  local wasCentering = self.centering
  self:updateCentering(dt, camera, intensity, deadzoneDegrees)
  if self.centering then
    return
  end

  -- if manual input cancelled centering before initialization, keep that new view
  if wasCentering and self.baseRotY == nil and isInsideCamera then
    local steeringOffset = self:getCurrentSteeringOffset(deadzoneDegrees, intensity)
    self:preserveCurrentCamera(camera, camIndex, steeringOffset, intensity > 0)
    return
  end

  -- validate preconditions
  if intensity <= 0 or not isInsideCamera then
    local hadCameraState = stateResetForCameraChange

    if self.centering or self.baseRotY ~= nil or self.lastInsideCamera ~= nil then
      hadCameraState = self:resetState(camIndex) or hadCameraState
    end

    if hadCameraState then
      -- cameras not looking backwards resume steering follow after tracking is suspended
      self:updateStatesForOutsideCamera()
    end

    return
  end

  -- initialize if needed
  if self.lastCamIndex ~= camIndex or self.baseRotY == nil then
    self:initializeCamera(camera, camIndex, deadzoneDegrees, intensity)
    return
  end

  local userMovement = self:applyUserMovement(camera)

  -- manual movement and looking backwards take priority over automatic follow
  if userMovement ~= 0 or self:isLookingBackwards(camera) then
    return
  end

  -- smooth manual centering and steering together, without changing the manual range
  local centeringOffset = self:getCenteringOffset(camera, intensity)
  local targetOffset = self:getCurrentSteeringOffset(deadzoneDegrees, intensity)
  local steeringDiff = targetOffset - self.rotationFactor
  local totalDiff = centeringOffset + steeringDiff
  local smoothingFactor = self:calculateSmoothDelta(1, ROTATION_SMOOTHING_FACTOR, dt)

  -- limit the combined camera movement, not each component separately
  if math.abs(totalDiff) > 0.001 then
    local maxDelta = ROTATION_MAX_DELTA_PER_MS * math.max(dt, 0)
    smoothingFactor = math.min(smoothingFactor, maxDelta / math.abs(totalDiff))
  end

  self.baseRotY = self.baseRotY + centeringOffset * smoothingFactor
  self.rotationFactor = self.rotationFactor + steeringDiff * smoothingFactor
  camera.rotY = self.baseRotY + self.rotationFactor
end
