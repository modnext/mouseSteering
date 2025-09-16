--
-- MouseSteeringIndicatorDisplay
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringIndicatorDisplay = {}

local MouseSteeringIndicatorDisplay_mt = Class(MouseSteeringIndicatorDisplay, HUDDisplay)

---Creates a new instance of MouseSteeringIndicatorDisplay
function MouseSteeringIndicatorDisplay.new()
  local self = MouseSteeringIndicatorDisplay:superClass().new(MouseSteeringIndicatorDisplay_mt)

  self.vehicle = nil
  self.isVehicleDrawSafe = false

  -- create overlays using g_overlayManager
  self.background = g_overlayManager:createOverlay("mouseSteering.indicatorBackground", 0, 0, 0, 0)
  self.bar = ThreePartOverlay.new()
  self.bar:setLeftPart("mouseSteering.indicatorBar_left", 0, 0)
  self.bar:setMiddlePart("mouseSteering.indicatorBar_middle", 0, 0)
  self.bar:setRightPart("mouseSteering.indicatorBar_right", 0, 0)
  self.textBg = g_overlayManager:createOverlay("mouseSteering.indicatorTextBackground", 0, 0, 0, 0)

  -- set initial colors
  self.background:setColor(unpack(MouseSteeringIndicatorDisplay.COLOR.BACKGROUND))
  self.bar:setColor(unpack(MouseSteeringIndicatorDisplay.COLOR.BAR))
  self.textBg:setColor(unpack(MouseSteeringIndicatorDisplay.COLOR.TEXT_BG))

  self.textVisible = true
  self.axisSide = 0

  return self
end

---Deletes indicator display
function MouseSteeringIndicatorDisplay:delete()
  self.background:delete()
  self.bar:delete()
  self.textBg:delete()

  MouseSteeringIndicatorDisplay:superClass().delete(self)
end

---Calculates and stores scaled values for positioning and sizing the indicator display
function MouseSteeringIndicatorDisplay:storeScaledValues()
  self:setPosition(0.5, g_hudAnchorBottom)

  -- apply offset for positioning
  local offsetX, offsetY = self:scalePixelValuesToScreenVector(unpack(MouseSteeringIndicatorDisplay.POSITION.SELF))
  local currentX, currentY = self:getPosition()
  self:setPosition(currentX + offsetX, currentY + offsetY)

  -- scale background dimensions
  local bgWidth, bgHeight = self:scalePixelValuesToScreenVector(unpack(MouseSteeringIndicatorDisplay.SIZE.BACKGROUND))
  self.background:setDimension(bgWidth, bgHeight)

  -- scale bar using ThreePartOverlay parts (4px caps -> middle scales)
  local barWidth, barHeight = self:scalePixelValuesToScreenVector(unpack(MouseSteeringIndicatorDisplay.SIZE.BAR))
  local leftPartWidth = self:scalePixelToScreenWidth(MouseSteeringIndicatorDisplay.SIZE.BAR_CAP)
  local rightPartWidth = self:scalePixelToScreenWidth(MouseSteeringIndicatorDisplay.SIZE.BAR_CAP)
  local middlePartWidth = math.max(0, barWidth - leftPartWidth - rightPartWidth)
  self.bar:setLeftPart(nil, leftPartWidth, barHeight)
  self.bar:setMiddlePart(nil, middlePartWidth, barHeight)
  self.bar:setRightPart(nil, rightPartWidth, barHeight)
  self.barLeftPartWidth = leftPartWidth
  self.barRightPartWidth = rightPartWidth
  self.barMiddleMaxWidth = middlePartWidth

  -- calculate positions
  local bgPosX, bgPosY = self:getPosition()
  self.background:setPosition(bgPosX - bgWidth * 0.5, bgPosY)

  -- store background position for text calculations
  self.bgPosX = bgPosX
  self.bgPosY = bgPosY
  self.bgWidth = bgWidth
  self.bgHeight = bgHeight

  -- position bar in center of background
  local barPosX = bgPosX - bgWidth * 0.5 + (bgWidth - barWidth) * 0.5
  local barPosY = bgPosY + (bgHeight - barHeight) * 0.5
  self.bar:setPosition(barPosX, barPosY)

  -- store bar geometry for drawing
  self.barPosX = barPosX
  self.barPosY = barPosY
  self.barWidth = barWidth
  self.barHeight = barHeight

  -- text positioning
  self.textOffsetX, self.textOffsetY = self:scalePixelValuesToScreenVector(unpack(MouseSteeringIndicatorDisplay.POSITION.TEXT_OFFSET))
  self.textSize = self:scalePixelToScreenHeight(MouseSteeringIndicatorDisplay.SIZE.TEXT)

  -- scale text background and store dimensions for drawing
  local textBgWidth, textBgHeight = self:scalePixelValuesToScreenVector(unpack(MouseSteeringIndicatorDisplay.SIZE.TEXT_BG))
  self.textBg:setDimension(textBgWidth, textBgHeight)
  self.textBgWidth = textBgWidth
  self.textBgHeight = textBgHeight

  -- marker and tick metrics for the new indicator look
  self.tickHeightShort = self:scalePixelToScreenHeight(MouseSteeringIndicatorDisplay.SIZE.TICK_HEIGHT_SHORT)
  self.tickOffsets = { 0.25, 0.75 }
end

---Updates the indicator display state
-- @param dt number Delta time for the update cycle
function MouseSteeringIndicatorDisplay:update(dt)
  MouseSteeringIndicatorDisplay:superClass().update(self, dt)

  -- mark vehicle draw as safe after update
  self.isVehicleDrawSafe = true
end

---Sets the vehicle for the indicator display
-- @param vehicle table The vehicle to display steering for, or nil to hide
function MouseSteeringIndicatorDisplay:setVehicle(vehicle)
  if vehicle ~= nil and vehicle.getMouseSteeringAxisSide == nil then
    vehicle = nil
  end

  -- update vehicle state
  self.vehicle = vehicle
  self:setVisible(self.vehicle ~= nil)
  self.isVehicleDrawSafe = false
end

---Renders the steering indicator display on screen
function MouseSteeringIndicatorDisplay:draw()
  if self.vehicle == nil or not self.isVehicleDrawSafe then
    return
  end

  -- compute latest steering values inline (like SpeedMeterDisplay)
  local vehicle = self.vehicle
  self.axisSide = vehicle:getMouseSteeringAxisSide()

  -- render base background bar
  self.background:render()

  -- render track (bar background, full width)
  local yBase = self.barPosY
  if g_pixelSizeY ~= nil then
    yBase = math.floor(yBase / g_pixelSizeY + 0.5) * g_pixelSizeY
  end
  self.bar:setColor(unpack(MouseSteeringIndicatorDisplay.COLOR.BAR))
  self.bar:setLeftPart(nil, self.barLeftPartWidth, self.barHeight)
  self.bar:setMiddlePart(nil, self.barMiddleMaxWidth, self.barHeight)
  self.bar:setRightPart(nil, self.barRightPartWidth, self.barHeight)
  self.bar:setPosition(self.barPosX, yBase)
  self.bar:render()

  -- render fill from center to one side (current steering)
  local halfBarWidth = self.barWidth * 0.5
  local fillWidth = math.abs(self.axisSide * halfBarWidth)
  local centerX = self.barPosX + halfBarWidth
  local y = yBase

  local capMaxLeft = self.barLeftPartWidth or 0
  local capMaxRight = self.barRightPartWidth or 0
  local usedLeft, usedRight, usedMiddle

  if self.axisSide >= 0 then
    usedLeft = math.min(capMaxLeft, fillWidth)
    usedRight = math.min(capMaxRight, math.max(0, fillWidth - usedLeft))
    usedMiddle = math.max(0, fillWidth - usedLeft - usedRight)
    self.bar:setLeftPart(nil, usedLeft, self.barHeight)
    self.bar:setMiddlePart(nil, usedMiddle, self.barHeight)
    self.bar:setRightPart(nil, usedRight, self.barHeight)
    self.bar:setPosition(centerX, y)
  else
    usedRight = math.min(capMaxRight, fillWidth)
    usedLeft = math.min(capMaxLeft, math.max(0, fillWidth - usedRight))
    usedMiddle = math.max(0, fillWidth - usedLeft - usedRight)
    self.bar:setLeftPart(nil, usedLeft, self.barHeight)
    self.bar:setMiddlePart(nil, usedMiddle, self.barHeight)
    self.bar:setRightPart(nil, usedRight, self.barHeight)
    self.bar:setPosition(centerX - (usedLeft + usedMiddle + usedRight), y)
  end

  -- set constant fill color and render the current value
  local r, g, b, a = unpack(HUD.COLOR.ACTIVE)
  self.bar:setColor(r, g, b, a)
  self.bar:render()

  -- draw center marker and ticks for new indicator look
  local centerMarkerHalf = self:scalePixelToScreenWidth(1)
  local centerMarkerWidth = centerMarkerHalf * 2
  local centerMarkerHeight = self.barHeight
  drawFilledRect(centerX - centerMarkerHalf, y, centerMarkerWidth, centerMarkerHeight, 0, 0, 0, 0.6)

  -- draw tick marks at 25% and 75% positions
  for _, frac in ipairs(self.tickOffsets) do
    local tickXLeft = self.barPosX + self.barWidth * frac - centerMarkerHalf
    local tickXRight = self.barPosX + self.barWidth * (1 - frac) - centerMarkerHalf
    drawFilledRect(tickXLeft, y + (self.barHeight - self.tickHeightShort) * 0.5, centerMarkerWidth, self.tickHeightShort, 0, 0, 0, 0.4)
    drawFilledRect(tickXRight, y + (self.barHeight - self.tickHeightShort) * 0.5, centerMarkerWidth, self.tickHeightShort, 0, 0, 0, 0.4)
  end

  -- draw angle text if visible
  if self.textVisible then
    self:drawAngleText(self.axisSide)
  end
end

---Draws the angle percentage text for the steering indicator
-- @param axisSide number The steering axis value (-1 to 1)
function MouseSteeringIndicatorDisplay:drawAngleText(axisSide)
  local posX = self.bgPosX
  local posY = self.bgPosY + self.bgHeight - self.textOffsetY

  -- format steering angle as percentage
  local percent = math.floor(math.abs(axisSide) * 100 + 0.5)
  local text = string.format("%d", percent)

  -- draw background behind the text (centered around text position)
  local textBgPosX = posX - (self.textBgWidth or 0) * 0.5
  -- compensate that posY is a text baseline by shifting background up by ~35% of text size
  local textCenterY = posY + (self.textSize or 0) * 0.35
  local textBgPosY = textCenterY - (self.textBgHeight or 0) * 0.5
  if g_pixelSizeY ~= nil then
    textBgPosY = math.floor(textBgPosY / g_pixelSizeY + 0.5) * g_pixelSizeY
  end
  self.textBg:setPosition(textBgPosX, textBgPosY)
  self.textBg:render()

  -- set text rendering properties
  setTextColor(unpack(MouseSteeringIndicatorDisplay.COLOR.ANGLE_TEXT))
  setTextBold(false)
  setTextAlignment(RenderText.ALIGN_CENTER)

  -- render the percentage text
  renderText(posX, posY, self.textSize, text)

  -- reset text rendering properties to their defaults
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextColor(1, 1, 1, 1)
end

---Sets the visibility of the angle text display
-- @param visible boolean Whether the angle text should be visible
function MouseSteeringIndicatorDisplay:setTextVisible(visible)
  self.textVisible = visible
end

---
MouseSteeringIndicatorDisplay.POSITION = {
  SELF = { 0, 0 },
  BACKGROUND = { 0, 0 },
  TEXT_OFFSET = { 0, -10 },
}

---
MouseSteeringIndicatorDisplay.SIZE = {
  SELF = { 640, 75 },
  BACKGROUND = { 326, 10 },
  BAR = { 320, 4 },
  BAR_CAP = 4,
  TEXT = 16,
  TEXT_BG = { 40, 17 },
  TICK_HEIGHT_SHORT = 4,
}

---
MouseSteeringIndicatorDisplay.COLOR = {
  BACKGROUND = { 0, 0, 0, 0.3 },
  BAR = { 0, 0, 0, 1 },
  ANGLE_TEXT = { 1, 1, 1, 0.75 },
  TEXT_BG = { 0, 0, 0, 0.5 },
}
