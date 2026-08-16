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
  return setmetatable({}, MouseSteeringController_mt)
end

---Applies the fixed cubic Bezier curve used by the linearity transformation
function MouseSteeringController:applyLinearityCurve(value)
  local controlPoint1 = 0.02
  local controlPoint2 = 0.08
  local inverseValue = 1 - value

  return 3 * inverseValue * inverseValue * value * controlPoint1 + 3 * inverseValue * value * value * controlPoint2 + value * value * value
end

---Gets the linearity exponent currently used by the controller
function MouseSteeringController:getEffectiveLinearity(settings)
  local minLinearityExponent = 0.25
  local maxLinearityExponent = 3

  if settings == nil or settings.speedBasedSteering then
    return 1
  end

  return math.clamp(settings.linearity or 1, minLinearityExponent, maxLinearityExponent)
end

---Applies linearity transformation to input axis value
function MouseSteeringController:applyLinearity(axis, linearity)
  if axis == nil or linearity == nil then
    return 0
  end

  local minLinearityExponent = 0.25
  local maxLinearityExponent = 3
  local inputSign = axis >= 0 and 1 or -1
  local absAxis = math.clamp(math.abs(axis), 0, 1)
  local exponent = math.clamp(linearity, minLinearityExponent, maxLinearityExponent)

  if exponent == 1 then
    return inputSign * absAxis
  end

  local curveParameter = math.pow(absAxis, exponent)
  local transformedValue = self:applyLinearityCurve(curveParameter)

  return inputSign * math.clamp(transformedValue, 0, 1)
end

---Reverses linearity transformation to get original input value
function MouseSteeringController:reverseLinearity(axis, linearity)
  if axis == nil or linearity == nil then
    return 0
  end

  local minLinearityExponent = 0.25
  local maxLinearityExponent = 3
  local zeroThreshold = 1e-5
  local searchPrecision = 1e-4
  local maxSearchIterations = 16
  local absAxis = math.clamp(math.abs(axis), 0, 1)

  if absAxis < zeroThreshold then
    return 0
  end

  local exponent = math.clamp(linearity, minLinearityExponent, maxLinearityExponent)
  local inputSign = axis >= 0 and 1 or -1

  if exponent == 1 or absAxis == 1 then
    return inputSign * absAxis
  end

  local searchMin = 0
  local searchMax = 1

  for _ = 1, maxSearchIterations do
    local candidate = (searchMin + searchMax) * 0.5
    local curveParameter = math.pow(candidate, exponent)
    local transformedValue = self:applyLinearityCurve(curveParameter)

    if transformedValue < absAxis then
      searchMin = candidate
    else
      searchMax = candidate
    end

    if searchMax - searchMin <= searchPrecision then
      break
    end
  end

  return inputSign * (searchMin + searchMax) * 0.5
end

---Applies exponential smoothing to a value over time
function MouseSteeringController:applySmoothness(current, target, smoothness, dt)
  smoothness = smoothness or 0

  if smoothness <= 0 then
    return target
  end

  if math.abs(target - current) < 1e-6 then
    return target
  end

  local minSmoothness = 0.65
  local maxSmoothness = 0.85
  local smoothingDecayFactor = 0.06
  local deltaTime = math.max(dt or 0, 0)
  local clampedSmoothness = math.clamp(smoothness, minSmoothness, maxSmoothness)

  local oneMinusSmooth = 1 - clampedSmoothness
  local smoothingFactor = oneMinusSmooth * oneMinusSmooth
  local smoothingAmount = 1 - math.exp(-smoothingFactor * deltaTime * smoothingDecayFactor)

  return MathUtil.lerp(current, target, math.clamp(smoothingAmount, 0, 1))
end

---Computes effective sensitivity based on vehicle speed and steering angle
function MouseSteeringController:computeEffectiveSensitivity(settings, vehicleSpeedKmh, steeringAngle)
  if settings == nil or not settings.speedBasedSteering then
    return 1
  end

  local speedKmh = math.max(0, vehicleSpeedKmh or 0)
  local normalizedSteeringAngle = math.clamp(steeringAngle or 0, 0, 1)

  return self:computeUnifiedSensitivity(speedKmh, normalizedSteeringAngle)
end

---Computes unified sensitivity combining speed and angle factors
function MouseSteeringController:computeUnifiedSensitivity(speedKmh, steeringAngle)
  local referenceSpeedKmh = 40
  local lowSpeedTargetAngle = 0.60
  local highSpeedTargetAngle = 0.30
  local lowSpeedSensitivityFloor = 0.50
  local highSpeedSensitivityFloor = 0.05
  local minSensitivity = 0.05
  local maxSensitivity = 1
  local vehicleSpeed = math.max(0, speedKmh or 0)
  local speedRatio = math.clamp(vehicleSpeed / referenceSpeedKmh, 0, 1)
  local targetSteeringAngle = MathUtil.lerp(lowSpeedTargetAngle, highSpeedTargetAngle, speedRatio)
  local baseSensitivityFloor = MathUtil.lerp(lowSpeedSensitivityFloor, highSpeedSensitivityFloor, speedRatio)
  local steeringAngleRatio = math.clamp((steeringAngle or 0) / targetSteeringAngle, 0, 1)
  local transitionFactor = MathUtil.smoothstep(0, 1, steeringAngleRatio)
  local calculatedSensitivity = MathUtil.lerp(baseSensitivityFloor, 1, transitionFactor)

  return math.clamp(calculatedSensitivity, minSensitivity, maxSensitivity)
end

---Applies deadzone to an input value, returning 0 if within deadzone
function MouseSteeringController:applyDeadzone(inputValue, deadzone)
  local absValue = math.abs(inputValue)

  if absValue <= deadzone then
    return 0
  end

  local availableRange = 1 - deadzone
  if availableRange <= 0 then
    return 0
  end

  local sign = inputValue >= 0 and 1 or -1
  return sign * (absValue - deadzone) / availableRange
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
  if settings == nil then
    return 0, 1
  end

  local deadzoneScale = 0.6
  local guiDeadzone = settings.deadzone or 0
  local effectiveDeadzone = math.clamp(guiDeadzone * deadzoneScale, 0, 1)
  local maxInputRange = 1 + effectiveDeadzone

  return effectiveDeadzone, maxInputRange
end

---Applies deadzone compensation for sensitivity calculations
function MouseSteeringController:applyDeadzoneCompensation(currentValue, deadzone, sensitivityScale, rawDelta)
  local absCurrentValue = math.abs(currentValue)

  if absCurrentValue >= deadzone or deadzone <= 0 then
    return rawDelta * sensitivityScale
  end

  local proximityToEdge = math.clamp(absCurrentValue / deadzone, 0, 1)
  local transitionFactor = MathUtil.smoothstep(0, 1, proximityToEdge)
  local effectiveSensitivity = MathUtil.lerp(1, sensitivityScale, transitionFactor)

  return rawDelta * effectiveSensitivity
end

---Updates the steering controller with new input values and applies all transformations
function MouseSteeringController:update(inputValue, axisSide, settings, movedSide, isPaused, speedKmh, dt)
  if settings == nil or (dt ~= nil and dt < 0) then
    return inputValue, axisSide
  end

  local steerRaw = inputValue
  local deadzoneThreshold, maxInputRange = self:calculateEffectiveDeadzone(settings)

  -- integrate only new mouse movement; smoothing still runs every frame below
  if not isPaused then
    if movedSide ~= nil and movedSide ~= 0 then
      local rawInputDelta = movedSide
      if settings.invertXAxis then
        rawInputDelta = -rawInputDelta
      end

      local currentSteeringAngle = math.abs(axisSide)
      local effectiveSensitivityFactor = self:computeEffectiveSensitivity(settings, speedKmh, currentSteeringAngle)
      local baseSensitivity = settings.sensitivity or 1
      local finalSensitivity = math.max(baseSensitivity * effectiveSensitivityFactor, 0.001)
      local compensatedDelta = self:applyDeadzoneCompensation(steerRaw, deadzoneThreshold, finalSensitivity, rawInputDelta)

      steerRaw = steerRaw + compensatedDelta
    end

    steerRaw = math.clamp(steerRaw, -maxInputRange, maxInputRange)
  end

  -- convert the raw accumulator into the normalized steering target
  local normalizedInput
  if deadzoneThreshold > 0 then
    normalizedInput = self:applyDeadzone(steerRaw, deadzoneThreshold)
  else
    normalizedInput = math.clamp(steerRaw, -1, 1)
  end

  local linearity = self:getEffectiveLinearity(settings)
  local targetAxis = self:applyLinearity(normalizedInput, linearity)
  local smoothingSetting = settings.smoothness or 0
  local smoothedAxis = self:applySmoothness(axisSide, targetAxis, smoothingSetting, dt)

  return steerRaw, smoothedAxis
end
