--
-- MouseSteeringCameraRotation
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringCameraRotation = {}

local MouseSteeringCameraRotation_mt = Class(MouseSteeringCameraRotation)

---Creates a new instance of MouseSteeringCameraRotation
function MouseSteeringCameraRotation.new(vehicle)
  local self = setmetatable({}, MouseSteeringCameraRotation_mt)

  self.vehicle = vehicle

  -- calculation constants
  self.epsilon = 0.001
  self.targetFrameTime = 16.666

  -- steering factor calculation constants
  self.steerFactorThreshold = 0.1
  self.steerFactorMultiplier = 1.524
  self.steerFactorExponent = 2
  self.steerOffsetScale = 0.5

  -- centering constants
  self.centeringSmoothingFactor = 0.05

  -- rotation update constants
  self.rotationMaxDeltaPerMs = 0.002

  -- steering follow state
  self.rotationFactor = 0
  self.baseRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = nil

  -- centering state
  self.centering = false
  self.centerTargetRotY = nil
  self.centeringWithSteering = false
  self.centerSteeringOffset = 0
  self.lastCenterRotY = nil

  return self
end

---Gets CabView rotation limits if mod is active
-- @param camera table active camera
-- @return number|nil minRot, number|nil maxRot rotation limits or nil if CabView not active
function MouseSteeringCameraRotation:getCabViewLimits(camera)
  if camera == nil or not camera.isInside then
    return nil, nil
  end

  -- check for CabView mod compatibility
  if not g_modIsLoaded.FS25_CabView then
    return nil, nil
  end

  local vehicle = self.vehicle
  if vehicle == nil then
    return nil, nil
  end

  -- get specialization data
  local cabViewSpec = vehicle["spec_FS25_CabView.cabView"]
  if cabViewSpec == nil or cabViewSpec.rotationOffset == nil then
    return nil, nil
  end

  -- calculate limits based on offset
  local minRot = -0.1 * math.pi + cabViewSpec.rotationOffset
  local maxRot = 2.1 * math.pi + cabViewSpec.rotationOffset

  return minRot, maxRot
end

---Calculates shortest angle difference respecting CabView limits
-- @param from number current angle
-- @param to number target angle
-- @param camera table active camera
-- @return number angle difference (shortest path within limits)
function MouseSteeringCameraRotation:getAngleDiff(from, to, camera)
  local diff = to - from
  local minRot, maxRot = self:getCabViewLimits(camera)

  if minRot ~= nil and maxRot ~= nil then
    -- CabView is active - don't allow crossing limits
    local targetClamped = math.clamp(to, minRot, maxRot)
    return targetClamped - from
  else
    -- No CabView - use normal shortest path
    while diff > math.pi do
      diff = diff - 2 * math.pi
    end
    while diff < -math.pi do
      diff = diff + 2 * math.pi
    end
    return diff
  end
end

---Calculates normalized steering factor for camera rotation
-- @return number normalized steering factor (-1 to 1) with deadzone applied
function MouseSteeringCameraRotation:calculateSteeringFactor()
  local vehicle = self.vehicle
  local rotatedTime = vehicle.rotatedTime or 0

  if rotatedTime == 0 then
    return 0
  end

  -- calculate raw factor based on steering time
  local steerFactor = 0
  if rotatedTime > 0 and vehicle.maxRotTime and vehicle.maxRotTime > 0 then
    steerFactor = rotatedTime / vehicle.maxRotTime
  elseif rotatedTime < 0 and vehicle.minRotTime and vehicle.minRotTime < 0 then
    steerFactor = -(rotatedTime / vehicle.minRotTime)
  end

  -- apply deadzone threshold
  local absSteer = math.abs(steerFactor)
  if absSteer < self.steerFactorThreshold then
    return 0
  end

  -- apply exponential curve for smoother response
  local sign = steerFactor >= 0 and 1 or -1
  return sign * self.steerFactorMultiplier * (absSteer - self.steerFactorThreshold) ^ self.steerFactorExponent
end

---Resets camera rotation tracking state
-- @param camIndex number current camera index
function MouseSteeringCameraRotation:resetState(camIndex)
  if self.baseRotY ~= nil and self.lastInsideCamera ~= nil then
    self.lastInsideCamera.rotY = self.baseRotY
  end

  -- reset internal state
  self.baseRotY = nil
  self.lastInsideCamera = nil
  self.lastCamIndex = camIndex
  self.rotationFactor = 0
end

---Requests camera centering
-- @param camera table active camera
-- @param intensity number rotation intensity setting
function MouseSteeringCameraRotation:requestCenter(camera, intensity)
  if camera == nil then
    return
  end

  local baseRotY = camera.origRotY or 0

  -- set target depending on whether we should center to steering offset or original center
  if intensity > 0 and camera.isInside then
    local steeringOffset = self:calculateSteeringFactor() * self.steerOffsetScale * intensity
    self.centerTargetRotY = baseRotY + steeringOffset
    self.centeringWithSteering = true
    self.centerSteeringOffset = steeringOffset
  else
    self.centerTargetRotY = baseRotY
    self.centeringWithSteering = false
  end

  -- activate centering state
  self.centering = true
  self.lastCenterRotY = camera.rotY
end

---Updates camera centering (smooth transition to target)
-- @param dt number delta time in milliseconds
-- @param camera table active camera
-- @param intensity number rotation intensity setting for dynamic target updates
function MouseSteeringCameraRotation:updateCentering(dt, camera, intensity)
  if not self.centering then
    return
  end

  -- validate state
  if camera == nil or self.centerTargetRotY == nil then
    self.centering = false
    self.lastCenterRotY = nil
    return
  end

  -- detect manual camera movement by user
  if self.lastCenterRotY ~= nil then
    local userMovement = camera.rotY - self.lastCenterRotY
    if math.abs(userMovement) > self.epsilon then
      -- user is manually moving camera, cancel centering
      self.centering = false
      self.lastCenterRotY = nil
      return
    end
  end

  -- update target dynamically if centering with steering follow
  if self.centeringWithSteering and intensity and intensity > 0 then
    local baseRotY = camera.origRotY or 0
    local currentSteeringOffset = self:calculateSteeringFactor() * self.steerOffsetScale * intensity
    self.centerTargetRotY = baseRotY + currentSteeringOffset
    self.centerSteeringOffset = currentSteeringOffset
  end

  local diff = self:getAngleDiff(camera.rotY, self.centerTargetRotY, camera)

  -- check if target reached
  if math.abs(diff) < self.epsilon then
    camera.rotY = self.centerTargetRotY
    self.centering = false
    self.lastCenterRotY = nil

    -- update base rotation state if we ended up with an offset
    if self.centeringWithSteering then
      self.baseRotY = camera.origRotY or 0
      self.rotationFactor = self.centerSteeringOffset or 0
    end
  else
    -- ease-out interpolation: speed is proportional to distance
    -- faster when far from center, slower when close to center
    local smoothingFactor = self.centeringSmoothingFactor
    local delta = diff * smoothingFactor * (dt / self.targetFrameTime)

    camera.rotY = camera.rotY + delta
    self.lastCenterRotY = camera.rotY
  end
end

---Updates camera rotation to follow wheel steering
-- @param dt number delta time in milliseconds
-- @param camera table active camera
-- @param camIndex number current camera index
-- @param intensity number rotation intensity setting
function MouseSteeringCameraRotation:update(dt, camera, camIndex, intensity)
  self:updateCentering(dt, camera, intensity)
  if self.centering then
    return
  end

  -- validate preconditions for rotation logic
  if intensity <= 0 or camera == nil or not camera.isInside then
    self:resetState(camIndex)
    return
  end

  local targetOffset = self:calculateSteeringFactor() * self.steerOffsetScale * intensity

  -- initialize tracking state if needed
  if self.lastCamIndex ~= camIndex or self.baseRotY == nil then
    self.lastCamIndex = camIndex
    self.lastInsideCamera = camera
    self.baseRotY = camera.rotY
    self.rotationFactor = targetOffset
    camera.rotY = self.baseRotY + self.rotationFactor
    return
  end

  -- detect and apply user manual adjustments
  local expectedRotY = self.baseRotY + self.rotationFactor
  local userMovement = camera.rotY - expectedRotY
  if math.abs(userMovement) > self.epsilon then
    self.baseRotY = self.baseRotY + userMovement
  end

  -- smooth transition to target offset
  local maxDelta = self.rotationMaxDeltaPerMs * dt
  local diff = targetOffset - self.rotationFactor
  self.rotationFactor = self.rotationFactor + math.clamp(diff, -maxDelta, maxDelta)

  -- apply final rotation
  camera.rotY = self.baseRotY + self.rotationFactor
end
