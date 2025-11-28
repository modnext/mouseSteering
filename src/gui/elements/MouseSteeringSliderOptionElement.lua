--
-- MouseSteeringSliderOptionElement
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringSliderOptionElement = {}

local MouseSteeringSliderOptionElement_mt = Class(MouseSteeringSliderOptionElement, OptionSliderElement)

---Creates a new instance of MouseSteeringSliderOptionElement
function MouseSteeringSliderOptionElement.new(target, custom_mt)
  local self = OptionSliderElement.new(target, custom_mt or MouseSteeringSliderOptionElement_mt)

  -- default configuration values
  self.minValue = 0
  self.maxValue = 1
  self.stepSize = 0.01

  self.textElement = nil
  self.formatter = nil

  -- colors for dynamic contrast depending on filling bar overlap
  self.defaultTextColor = { 1, 1, 1, 1 }
  self.overlapTextColor = { 0, 0, 0, 1 }

  return self
end

---
function MouseSteeringSliderOptionElement:loadFromXML(xmlFile, key)
  MouseSteeringSliderOptionElement:superClass().loadFromXML(self, xmlFile, key)

  self.minValue = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#minValue"), self.minValue)
  self.maxValue = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#maxValue"), self.maxValue)
  self.stepSize = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#stepSize"), self.stepSize)
  self.defaultTextColor = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#defaultTextColor"), self.defaultTextColor)
  self.overlapTextColor = GuiUtils.getColorArray(getXMLString(xmlFile, key .. "#overlapTextColor"), self.overlapTextColor)

  -- generate texts from values
  self:generateTexts()
end

---
function MouseSteeringSliderOptionElement:loadProfile(profile, applyProfile)
  MouseSteeringSliderOptionElement:superClass().loadProfile(self, profile, applyProfile)

  self.minValue = profile:getNumber("minValue", self.minValue)
  self.maxValue = profile:getNumber("maxValue", self.maxValue)
  self.stepSize = profile:getNumber("stepSize", self.stepSize)
  self.defaultTextColor = GuiUtils.getColorArray(profile:getValue("defaultTextColor"), self.defaultTextColor)
  self.overlapTextColor = GuiUtils.getColorArray(profile:getValue("overlapTextColor"), self.overlapTextColor)

  -- generate texts from values
  self:generateTexts()
end

---
function MouseSteeringSliderOptionElement:copyAttributes(src)
  MouseSteeringSliderOptionElement:superClass().copyAttributes(self, src)

  self.minValue = src.minValue
  self.maxValue = src.maxValue
  self.stepSize = src.stepSize
  self.defaultTextColor = src.defaultTextColor
  self.overlapTextColor = src.overlapTextColor
end

---
function MouseSteeringSliderOptionElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
  if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) or Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
    return eventUsed
  end

  local used = MouseSteeringSliderOptionElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)

  self:updateTextContrastByFill()
  self:adjustFillingBarCaps(self:updateFillingBarEndCapWidths())

  return used
end

---Sets the configuration values for the slider
-- @param minValue number The minimum value for the slider
-- @param maxValue number The maximum value for the slider
-- @param stepSize number The step size for the slider
function MouseSteeringSliderOptionElement:setConfig(minValue, maxValue, stepSize)
  self.minValue = minValue
  self.maxValue = maxValue
  self.stepSize = stepSize

  self:generateTexts()
end

---Generates the display texts for the slider values
function MouseSteeringSliderOptionElement:generateTexts()
  local numberOfSteps = self:calculateNumberOfSteps()

  -- generate text for each step value
  local texts = {}
  for stepIndex = 1, numberOfSteps do
    local stepValue = self:getValueFromIndex(stepIndex)
    texts[stepIndex] = self:formatValueForDisplay(stepValue)
  end

  self:setTexts(texts)
end

---Calculates the number of steps between min and max values
-- @return number The number of steps (minimum 2)
function MouseSteeringSliderOptionElement:calculateNumberOfSteps()
  local precision = 100000

  local minValueScaled = math.floor(self.minValue * precision + 0.5)
  local maxValueScaled = math.floor(self.maxValue * precision + 0.5)
  local stepSizeScaled = math.floor(self.stepSize * precision + 0.5)

  local rangeScaled = maxValueScaled - minValueScaled
  local stepsCount = math.floor(rangeScaled / stepSizeScaled) + 1

  -- ensure at least 2 steps for proper slider functionality
  return math.max(stepsCount, 2)
end

---Formats a numeric value for display as text
-- @param value number The numeric value to format
-- @return string The formatted text representation
function MouseSteeringSliderOptionElement:formatValueForDisplay(value)
  if self.formatter ~= nil then
    return self.formatter(value)
  end

  -- determine decimal places based on step size precision
  -- local decimalPlaces = (self.stepSize >= 0.1) and 1 or 2
  -- return string.format("%." .. decimalPlaces .. "f", value)
  return string.format("%.2f", value)
end

---Sets the slider value
function MouseSteeringSliderOptionElement:setValue(value)
  value = math.max(self.minValue, math.min(self.maxValue, value or self.minValue))

  -- find index
  local precision = 100000
  local minVal = math.floor(self.minValue * precision + 0.5)
  local stepVal = math.floor(self.stepSize * precision + 0.5)
  local val = math.floor(value * precision + 0.5)

  local index = math.floor((val - minVal) / stepVal + 0.5) + 1
  index = math.max(1, math.min(#self.texts, index))

  self:setState(index)

  -- update display
  local currentVal = self:getCurrentValue()
  local text = self:formatValueForDisplay(currentVal)
  self:setText(text)
end

---Sets the display text for the slider element
-- @param text string The text to display
function MouseSteeringSliderOptionElement:setText(text)
  if self.textElement ~= nil then
    self.textElement:setText(text)
  end
end

---Updates text contrast
function MouseSteeringSliderOptionElement:updateTextContrastByFill()
  if self.textElement ~= nil and self.useFillingBar and self.fillingBarElement ~= nil then
    -- init color
    if self.textElement.textColor ~= nil and (self.defaultTextColor == nil or type(self.defaultTextColor) ~= "table") then
      self.defaultTextColor = self.textElement.textColor
    end

    -- calc text pos
    local textContent = self.textElement:getText() or ""
    local textSize = self.textElement.textSize or 0.016
    local textWidth = getTextWidth(textSize, textContent) or 0
    local textAreaLeft = self.textElement.absPosition[1]
    local textAreaWidth = self.textElement.absSize[1]
    local textLeft = textAreaLeft + math.max((textAreaWidth - textWidth) * 0.5, 0)
    local textRight = textLeft + math.min(textWidth, textAreaWidth)

    -- calc fill pos
    local fillBarLeft = self.fillingBarElement.absPosition[1]
    local fillBarRight = fillBarLeft + self.fillingBarElement.absSize[1]

    -- check overlap
    local isOverlapping = fillBarRight >= textRight
    local selectedColor = isOverlapping and self.overlapTextColor or self.defaultTextColor

    -- apply color
    if selectedColor ~= nil and self.textElement.setTextColor ~= nil then
      self.textElement:setTextColor(selectedColor[1] or 1, selectedColor[2] or 1, selectedColor[3] or 1, selectedColor[4] or 1)
    end
  end
end

---Updates the slider and related visual elements
function MouseSteeringSliderOptionElement:updateSlider()
  MouseSteeringSliderOptionElement:superClass().updateSlider(self)

  self:updateTextContrastByFill()
  self:adjustFillingBarCaps(self:updateFillingBarEndCapWidths())
end

---Sets the value formatter function for display
-- @param formatter function The formatter function to use for value display
function MouseSteeringSliderOptionElement:setFormatter(formatter)
  self.formatter = formatter
  self:generateTexts()

  local currentValue = self:getCurrentValue()
  if currentValue ~= nil then
    self:setText(self:formatValueForDisplay(currentValue))
  end
end

---Updates the filling bar end cap widths
-- @return number|nil The calculated width for the filling bar
function MouseSteeringSliderOptionElement:updateFillingBarEndCapWidths()
  if not self.useFillingBar or self.fillingBarElement == nil then
    return nil
  end

  local totalWidth = self.absSize[1] or 0
  local sliderOffset = self.sliderOffset or 0

  if #self.texts > 1 then
    return (self.state - 1) / (#self.texts - 1) * (totalWidth - sliderOffset * 2) + sliderOffset
  else
    return totalWidth - sliderOffset
  end
end

---Adjusts the filling bar end cap sizes based on available width
-- @param currentWidth number|nil The available width for the filling bar
function MouseSteeringSliderOptionElement:adjustFillingBarCaps(currentWidth)
  if self.fillingBarElement ~= nil and self.useFillingBar then
    local bar = self.fillingBarElement

    -- ensure the bar has valid size arrays
    if bar.startSize ~= nil and bar.endSize ~= nil then
      -- initialize maximum cap sizes if not already set
      self:initializeCapMaxSizes(bar)

      -- get the available width (ensure non-negative)
      local availableWidth = math.max(currentWidth or 0, 0)

      -- get maximum allowed sizes for each cap
      local maxStartCapWidth = self.fillingBarCapMaxStart[1] or 0
      local maxEndCapWidth = self.fillingBarCapMaxEnd[1] or 0

      -- allocate width to start cap (left side), respecting its maximum
      local startCapWidth = math.min(maxStartCapWidth, availableWidth)
      local remainingWidth = math.max(0, availableWidth - startCapWidth)

      -- allocate remaining width to end cap (right side), respecting its maximum
      local endCapWidth = math.min(maxEndCapWidth, remainingWidth)

      -- apply the calculated sizes to the bar
      bar.startSize[1] = startCapWidth
      bar.endSize[1] = endCapWidth
    end
  end
end

---Initializes the maximum cap sizes for the filling bar if not already set
-- @param bar table The filling bar element containing startSize and endSize arrays
function MouseSteeringSliderOptionElement:initializeCapMaxSizes(bar)
  -- initialize maximum size for the start cap (left side of filling bar)
  if self.fillingBarCapMaxStart == nil then
    self.fillingBarCapMaxStart = {
      (bar.startSize and bar.startSize[1]) or 0, -- width
      (bar.startSize and bar.startSize[2]) or 0, -- height
    }
  end

  -- initialize maximum size for the end cap (right side of filling bar)
  if self.fillingBarCapMaxEnd == nil then
    self.fillingBarCapMaxEnd = {
      (bar.endSize and bar.endSize[1]) or 0, -- width
      (bar.endSize and bar.endSize[2]) or 0, -- height
    }
  end
end

---Gets the value corresponding to a given index
-- @param index number The index to get the value for
-- @return number The value corresponding to the index
function MouseSteeringSliderOptionElement:getValueFromIndex(index)
  local precision = 100000

  -- scale values to integers for precision
  local minValueInt = math.floor(self.minValue * precision + 0.5)
  local stepSizeInt = math.floor(self.stepSize * precision + 0.5)

  -- convert index and calculate value
  local indexOffset = index - 1
  local valueInt = minValueInt + indexOffset * stepSizeInt
  local value = valueInt / precision

  -- clamp to valid range
  value = math.max(self.minValue, math.min(self.maxValue, value))

  return value
end

---Gets the current value of the slider
-- @return number The current value of the slider
function MouseSteeringSliderOptionElement:getCurrentValue()
  local index = self:getState()
  return self:getValueFromIndex(index)
end
