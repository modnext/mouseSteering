--
-- MouseSteeringController
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringController = {}

local MouseSteeringController_mt = Class(MouseSteeringController)

---Creates a new instance of MouseSteeringController
function MouseSteeringController.new()
  local self = setmetatable({}, MouseSteeringController_mt)

  -- bezier curve parameters for smooth linearity transitions
  self.bezierPoints = { p0 = 0, p1 = 0.02, p2 = 0.08, p3 = 1 }

  -- linearity exponent bounds
  self.minLinearityExponent = 0.25
  self.maxLinearityExponent = 3

  -- reverse linearity calculation settings
  self.reverseLinearityThreshold = 1e-5
  self.reverseLinearityPrecision = 1e-4
  self.reverseLinearityMaxIterations = 16

  -- smoothness system bounds
  self.minSmoothness = 0.65
  self.maxSmoothness = 0.85
  self.smoothingDecayFactor = 0.06

  -- deadzone scale for GUI settings
  self.deadzoneScale = 0.6

  -- unified sensitivity parameters
  self.referenceSpeedKmh = 40
  self.minSensitivity = 0.05
  self.maxSensitivity = 1.0

  return self
end

---Calculates Bezier curve value for given control points and parameter t
function MouseSteeringController:bezier(t, p0, p1, p2, p3)
  local u = 1 - t
  return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
end

---Applies smoothstep interpolation function
function MouseSteeringController:smoothstep(x)
  local t = math.clamp(x, 0, 1)
  return t * t * (3 - 2 * t)
end

---Applies linearity transformation to input axis value
---Linearity values: < 1.0 = more sensitive at low inputs, > 1.0 = less sensitive at low inputs
function MouseSteeringController:applyLinearity(axis, linearity)
  if not axis or not linearity then
    return 0
  end

  -- prepare values
  local inputSign = (axis >= 0) and 1 or -1
  local absAxis = math.clamp(math.abs(axis), 0, 1)
  local exponent = math.clamp(linearity, self.minLinearityExponent, self.maxLinearityExponent)

  -- apply transformation
  local transformedValue
  if exponent == 1.0 then
    transformedValue = absAxis
  else
    local bezierParameter = math.pow(absAxis, exponent)
    local bezierValue = self:bezier(bezierParameter, self.bezierPoints.p0, self.bezierPoints.p1, self.bezierPoints.p2, self.bezierPoints.p3)
    transformedValue = math.clamp(bezierValue, 0, 1)
  end

  return inputSign * transformedValue
end

---Reverses linearity transformation to get original input value
function MouseSteeringController:reverseLinearity(axis, linearity)
  local absAxis = math.abs(axis)
  if absAxis < self.reverseLinearityThreshold then
    return 0
  end

  -- prepare parameters
  local exponent = math.clamp(linearity, self.minLinearityExponent, self.maxLinearityExponent)
  local sign = (axis >= 0) and 1 or -1

  -- linear case: simple inverse
  if exponent == 1 then
    return sign * absAxis
  end

  -- non-linear case: binary search
  local searchMin = 0
  local searchMax = 1
  local bezierPoints = self.bezierPoints

  for _ = 1, self.reverseLinearityMaxIterations do
    local candidate = (searchMin + searchMax) * 0.5
    local transformedValue = self:bezier(math.pow(candidate, exponent), bezierPoints.p0, bezierPoints.p1, bezierPoints.p2, bezierPoints.p3)

    if math.abs(searchMax - searchMin) <= self.reverseLinearityPrecision then
      break
    end

    if transformedValue < absAxis then
      searchMin = candidate
    else
      searchMax = candidate
    end
  end

  return sign * searchMin
end

---Applies exponential smoothing to a value over time
function MouseSteeringController:applySmoothness(current, target, smoothness, dt)
  if smoothness <= 0 then
    return target
  end

  if math.abs(target - current) < 1e-6 then
    return target
  end

  -- clamp smoothness to valid range
  smoothness = math.clamp(smoothness, self.minSmoothness, self.maxSmoothness)

  -- calculate exponential smoothing factor
  local oneMinusSmooth = 1 - smoothness
  local smoothingFactor = oneMinusSmooth * oneMinusSmooth
  local decayRate = -dt * self.smoothingDecayFactor
  local smoothingAmount = 1 - math.exp(smoothingFactor * decayRate)

  -- ensure result stays within reasonable bounds
  smoothingAmount = math.clamp(smoothingAmount, 0, 1)

  return current + (target - current) * smoothingAmount
end

---Computes effective sensitivity based on vehicle speed and steering angle
---Returns sensitivity factor between 0.05 and 1.0 (higher = more sensitive)
function MouseSteeringController:computeEffectiveSensitivity(settings, vehicleSpeedKmh, steeringAngle)
  if not settings or not settings.speedBasedSteering then
    return 1.0
  end

  -- validate and clamp inputs
  local speedKmh = math.max(0, vehicleSpeedKmh or 0)
  local steeringAngleNormalized = math.clamp(steeringAngle or 0, 0, 1)
  local rawSensitivity = self:computeUnifiedSensitivity(speedKmh, steeringAngleNormalized)
  local finalSensitivity = math.clamp(rawSensitivity, 0.05, 1.0)

  return finalSensitivity
end

---Computes unified sensitivity combining speed and angle factors
---At low speeds: higher sensitivity, at high speeds: lower sensitivity
function MouseSteeringController:computeUnifiedSensitivity(speedKmh, steeringAngle)
  local LOW_SPEED_TARGET_ANGLE = 0.60 -- steering angle ratio at 0 km/h
  local HIGH_SPEED_TARGET_ANGLE = 0.30 -- steering angle ratio at 40+ km/h
  local LOW_SPEED_BASE_FLOOR = 0.5 -- base sensitivity at 0 km/h
  local HIGH_SPEED_BASE_FLOOR = 0.05 -- base sensitivity at 40+ km/h

  -- calculate speed ratio and speed-dependent parameters
  local vehicleSpeed = math.max(0, speedKmh or 0)
  local speedRatio = math.clamp(vehicleSpeed / self.referenceSpeedKmh, 0, 1)
  local targetSteeringAngle = LOW_SPEED_TARGET_ANGLE + (HIGH_SPEED_TARGET_ANGLE - LOW_SPEED_TARGET_ANGLE) * speedRatio
  local baseSensitivityFloor = LOW_SPEED_BASE_FLOOR + (HIGH_SPEED_BASE_FLOOR - LOW_SPEED_BASE_FLOOR) * speedRatio

  -- calculate steering angle ratio and apply smooth transition
  local steeringAngleRatio = targetSteeringAngle > 1e-6 and math.clamp(steeringAngle / targetSteeringAngle, 0, 1) or 0
  local smoothCurveValue = self:smoothstep(steeringAngleRatio)
  local calculatedSensitivity = baseSensitivityFloor + (1 - baseSensitivityFloor) * smoothCurveValue

  return math.clamp(calculatedSensitivity, self.minSensitivity, self.maxSensitivity)
end

---Validates update parameters and extracts values from context
function MouseSteeringController:validateUpdateParameters(context, dt)
  local steerRaw = context.inputValue
  local axisSide = context.axisSide
  local settings = context.settings

  -- validate input parameters
  if not settings then
    return false, steerRaw, axisSide
  end

  -- ensure delta time is reasonable
  if dt and dt < 0 then
    return false, steerRaw, axisSide
  end

  return true, steerRaw, axisSide
end

---Applies deadzone to an input value, returning 0 if within deadzone
function MouseSteeringController:applyDeadzone(inputValue, deadzone)
  local absValue = math.abs(inputValue)

  if absValue <= deadzone then
    return 0
  end

  -- normalize the value outside the deadzone
  local sign = inputValue >= 0 and 1 or -1
  return sign * (absValue - deadzone) / (1 - deadzone)
end

---Removes deadzone effect from a normalized value, converting back to raw input range
function MouseSteeringController:reverseDeadzone(normalizedValue, deadzone)
  if normalizedValue == 0 then
    return 0
  end

  -- convert back to raw input range
  local sign = normalizedValue >= 0 and 1 or -1
  local rawValue = math.abs(normalizedValue) * (1 - deadzone) + deadzone
  return sign * rawValue
end

---Calculates the effective deadzone value from GUI settings
function MouseSteeringController:calculateEffectiveDeadzone(settings)
  if not settings then
    return 0, 1
  end

  local guiDeadzone = settings.deadzone or 0
  local effectiveDeadzone = math.clamp(guiDeadzone * (self.deadzoneScale or 1), 0, 1)
  local maxInputRange = 1 + effectiveDeadzone

  return effectiveDeadzone, maxInputRange
end

---Applies deadzone compensation for sensitivity calculations
---Creates smooth transition from deadzone edge to full sensitivity
function MouseSteeringController:applyDeadzoneCompensation(currentValue, deadzone, sensitivityScale, rawDelta)
  local absCurrentValue = math.abs(currentValue)

  if absCurrentValue >= deadzone or deadzone <= 0 then
    return rawDelta * sensitivityScale
  end

  -- apply smooth transition from deadzone edge
  local proximityToEdge = math.clamp(absCurrentValue / deadzone, 0, 1)
  local transitionFactor = self:smoothstep(proximityToEdge)
  local effectiveSensitivity = (1 - transitionFactor) + transitionFactor * sensitivityScale

  return rawDelta * effectiveSensitivity
end

---Updates the steering controller with new input values and applies all transformations
function MouseSteeringController:update(context, dt)
  local isValid, steerRaw, axisSide = self:validateUpdateParameters(context, dt)
  if not isValid then
    return steerRaw, axisSide
  end

  local settings = context.settings
  local movedSide = context.movedSide
  local vehicleSpeedKmh = context.speedKmh
  local isPaused = context.isPaused

  -- calculate deadzone parameters
  local deadzoneThreshold, maxInputRange = self:calculateEffectiveDeadzone(settings)

  -- apply sensitivity and input integration
  if not isPaused then
    local currentSteeringAngle = math.abs(axisSide)
    local effectiveSensitivityFactor = self:computeEffectiveSensitivity(settings, vehicleSpeedKmh, currentSteeringAngle)

    local baseSensitivity = settings.sensitivity or 1.0
    local finalSensitivity = math.max(baseSensitivity * effectiveSensitivityFactor, 0.001)

    local invertMultiplier = settings.invertXAxis and -1 or 1
    local rawInputDelta = (movedSide or 0) * invertMultiplier

    local compensatedDelta = self:applyDeadzoneCompensation(steerRaw, deadzoneThreshold, finalSensitivity, rawInputDelta)
    steerRaw = math.clamp(steerRaw + compensatedDelta, -maxInputRange, maxInputRange)
  end

  -- apply linearity transformation
  local linearitySetting = settings.linearity or 1.0
  local processedSteeringValue

  if deadzoneThreshold > 0 then
    local normalizedWithoutDeadzone = self:applyDeadzone(steerRaw, deadzoneThreshold)
    processedSteeringValue = self:applyLinearity(normalizedWithoutDeadzone, linearitySetting)
  else
    local normalizedInput = math.clamp(steerRaw, -1, 1)
    processedSteeringValue = self:applyLinearity(normalizedInput, linearitySetting)
  end

  -- apply smoothing
  local smoothingSetting = settings.smoothness or 0
  axisSide = self:applySmoothness(axisSide, processedSteeringValue, smoothingSetting, dt or 0)

  return steerRaw, axisSide
end
