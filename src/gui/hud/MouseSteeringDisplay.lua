--
-- MouseSteeringDisplay
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringDisplay = {}

local MouseSteeringDisplay_mt = Class(MouseSteeringDisplay, HUDDisplayElement)

function MouseSteeringDisplay.new(hudAtlasPath)
  local backgroundOverlay = MouseSteeringDisplay.createBackground(hudAtlasPath)
  local self = MouseSteeringDisplay:superClass().new(backgroundOverlay, nil, MouseSteeringDisplay_mt)

  self.vehicle = nil
  self.uiScale = 1

  self.sliderElements = nil
  self.textVisible = true

  self:applyValues(1)
  self:createComponents(hudAtlasPath)

  return self
end

function MouseSteeringDisplay:delete()
  MouseSteeringDisplay:superClass().delete(self)
end

function MouseSteeringDisplay:setVehicle(vehicle)
  if vehicle ~= nil and vehicle.getAxisSide == nil then
    vehicle = nil
  end

  self.vehicle = vehicle

  if not self:getVisible() then
    self:setVisible(true, true)
  end
end

function MouseSteeringDisplay:update(dt)
  MouseSteeringDisplay:superClass().update(self, dt)

  if self.vehicle == nil and self:getVisible() and self.animation:getFinished() then
    self:setVisible(false, true)
  end

  if self.vehicle ~= nil and self.vehicle.spec_motorized ~= nil then
    self:updateSlider(dt)
  end
end

function MouseSteeringDisplay:draw()
  if self.vehicle == nil and not self:getVisible() then
    return
  end

  MouseSteeringDisplay:superClass().draw(self)

  if self.overlay.visible then
    self.overlay:render()

    for _, child in ipairs(self.children) do
      if child ~= self.overlay then
        child:draw()
      end
    end
  end

  if self.vehicle ~= nil and self:getVisible() and self.textVisible then
    self:drawAngleText()
  end
end

function MouseSteeringDisplay:setScale(uiScale)
  MouseSteeringDisplay:superClass().setScale(self, uiScale)

  self.uiScale = uiScale
  local currentVisibility = self:getVisible()

  self:setVisible(true, false)

  local width, _ = self:scalePixelToScreenVector(MouseSteeringDisplay.SIZE.SELF)
  local posX, posY = MouseSteeringDisplay.getBackgroundPosition(uiScale, width)

  self:setPosition(posX, posY)
  self:storeOriginalPosition()
  self:setVisible(currentVisibility, false)

  -- Recalculate the offset values
  self:applyValues(uiScale)
end

function MouseSteeringDisplay:applyValues(uiScale)
  local textOffsetX, textOffsetY = getNormalizedScreenValues(unpack(MouseSteeringDisplay.POSITION.TEXT_OFFSET))
  local _, textSize = getNormalizedScreenValues(0, MouseSteeringDisplay.SIZE.TEXT)

  self.textOffsetX = textOffsetX * uiScale
  self.textOffsetY = textOffsetY * uiScale
  self.textSize = textSize * uiScale
end

function MouseSteeringDisplay.getBackgroundPosition(uiScale, width)
  local offX, offY = getNormalizedScreenValues(unpack(MouseSteeringDisplay.POSITION.SELF))

  return 0.5 - width * 0.5 + offX * uiScale, g_safeFrameOffsetY + offY * uiScale
end

function MouseSteeringDisplay.createBackground(hudAtlasPath)
  local width, height = getNormalizedScreenValues(unpack(MouseSteeringDisplay.SIZE.BACKGROUND))
  local posX, posY = MouseSteeringDisplay.getBackgroundPosition(1, width)
  local background = Overlay.new(hudAtlasPath, posX, posY, width, height)

  background:setUVs(GuiUtils.getUVs(MouseSteeringDisplay.UV.BACKGROUND))
  background:setColor(unpack(MouseSteeringDisplay.COLOR.BACKGROUND))

  return background
end

function MouseSteeringDisplay:getBasePosition()
  local offX, offY = getNormalizedScreenValues(unpack(MouseSteeringDisplay.POSITION.BACKGROUND))
  local selfX, selfY = self:getPosition()

  return selfX + offX, selfY + offY
end

function MouseSteeringDisplay:createComponents(hudAtlasPath)
  local baseX, baseY = self:getBasePosition()

  self.sliderElements = self:createSlider(hudAtlasPath, baseX, baseY)

  -- Center the slider elements relative to the background
  self:centerElement(self.sliderElements, self)
end

function MouseSteeringDisplay:createSlider(hudAtlasPath, baseX, baseY)
  local posX, posY = getNormalizedScreenValues(unpack(MouseSteeringDisplay.POSITION.SLIDER))
  local width, height = getNormalizedScreenValues(unpack(MouseSteeringDisplay.SIZE.SLIDER))

  local spacerWidth, spacerHeight = getNormalizedScreenValues(unpack(MouseSteeringDisplay.SIZE.SPACER))
  local thumbWidth, thumbHeight = getNormalizedScreenValues(unpack(MouseSteeringDisplay.SIZE.THUMB))

  local background = Overlay.new(nil, posX, posY, width, height)
  local element = HUDElement.new(background)

  self:addChild(element)

  local range = Overlay.new(hudAtlasPath, baseX + posX, baseY + posY, width, height)
  range:setUVs(GuiUtils.getUVs(MouseSteeringDisplay.UV.RANGE))
  range:setColor(unpack(MouseSteeringDisplay.COLOR.RANGE))

  self.range = HUDElement.new(range)

  element:addChild(self.range)

  local spacerPosX = posX + width - spacerWidth

  local spacer = Overlay.new(hudAtlasPath, baseX + spacerPosX, baseY + posY, spacerWidth, spacerHeight)
  spacer:setUVs(GuiUtils.getUVs(MouseSteeringDisplay.UV.SPACER))

  self.spacer = HUDElement.new(spacer)

  element:addChild(self.spacer)

  local thumbPosX = posX + width * 0.5 - thumbWidth * 0.5
  local thumbPosY = posY + height * 0.5 - thumbHeight * 0.5

  local thumb = Overlay.new(hudAtlasPath, baseX + thumbPosX, baseY + thumbPosY, thumbWidth, thumbHeight)
  thumb:setUVs(GuiUtils.getUVs(MouseSteeringDisplay.UV.THUMB))

  self.thumb = HUDElement.new(thumb)

  element:addChild(self.thumb)

  return element
end

function MouseSteeringDisplay:updateSlider(dt)
  local axisSide = self.vehicle.rotatedTime / -self.vehicle.maxRotTime / self.vehicle:getSteeringDirection()

  --- Thumb update
  local rangePosX, _ = self.range:getPosition()

  local halfRangeWidth = self.range:getWidth() * 0.5
  local halfThumbWidth = self.thumb:getWidth() * 0.5

  local newThumbPosX = rangePosX + halfRangeWidth + (axisSide * halfRangeWidth) - halfThumbWidth

  self.thumb:setPosition(newThumbPosX, nil)

  --- Spacer update
  local newSpacerWidth = math.abs(axisSide * halfRangeWidth)
  local newSpacerPosX = rangePosX + halfRangeWidth

  if axisSide < 0 then
    newSpacerPosX = newSpacerPosX - newSpacerWidth
  end

  self.spacer:setPosition(newSpacerPosX, nil)
  self.spacer:setDimension(newSpacerWidth, nil)

  -- Update UVS
  local uvs = GuiUtils.getUVs(MouseSteeringDisplay.UV.SPACER)
  local uvScaleFactor = newSpacerWidth / halfRangeWidth

  uvs[3] = uvs[1] + (uvs[3] - uvs[1]) * uvScaleFactor
  uvs[5] = uvs[1] + (uvs[5] - uvs[1]) * uvScaleFactor
  uvs[7] = uvs[1] + (uvs[7] - uvs[1]) * uvScaleFactor

  if axisSide < 0 then
    GuiUtils.rotateUVs(uvs, 180)
  end

  self.spacer:setUVs(uvs)

  -- Update thumb color
  local colors = {
    { 0.024, 0.533, 0.851, 1 },
    { 0, 0.376, 0.725, 1 },
    { 0.427, 0.157, 0.851, 1 },
  }

  local absAxisSide = math.abs(axisSide)
  local index = absAxisSide <= 0.5 and 1 or 2
  local t = (absAxisSide - 0.5 * (index - 1)) * 2

  local color = self:interpolateColor(colors[index], colors[index + 1], t)

  self.thumb:setColor(unpack(color))
end

function MouseSteeringDisplay:interpolateColor(color1, color2, t)
  local t1 = 1 - t

  local r = color1[1] * t1 + color2[1] * t
  local g = color1[2] * t1 + color2[2] * t
  local b = color1[3] * t1 + color2[3] * t

  local a = 1

  return { r, g, b, a }
end

function MouseSteeringDisplay:centerElement(element, refElement)
  local refWidth, refHeight = refElement:getWidth(), refElement:getHeight()
  local elemWidth, elemHeight = element:getWidth(), element:getHeight()

  local centerX = (refWidth - elemWidth) / 2
  local centerY = (refHeight - elemHeight) / 2

  element:setPosition(centerX, centerY)
end

function MouseSteeringDisplay:drawAngleText()
  local axisSide = self.vehicle.rotatedTime / -self.vehicle.maxRotTime / self.vehicle:getSteeringDirection()
  local rotationAngle = axisSide * math.deg(self.vehicle.maxRotation)

  local baseX, baseY = self:getBasePosition()
  local posX = baseX + self:getWidth() * 0.5
  local posY = baseY + self:getHeight() - self.textOffsetY

  local textSize = self.textSize
  local text = string.format("%.1f", math.abs(rotationAngle))

  setTextColor(unpack(MouseSteeringDisplay.COLOR.ANGLE_TEXT))
  setTextBold(false)
  setTextAlignment(RenderText.ALIGN_CENTER)

  renderText(posX, posY, textSize, text)

  -- Reset text rendering properties to their defaults
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextColor(1, 1, 1, 1)
end

function MouseSteeringDisplay:setTextVisible(visible)
  self.textVisible = visible
end

MouseSteeringDisplay.UV = {
  BACKGROUND = { 2, 46, 111, 111 },
  THUMB = { 2, 34, 2, 8 },
  RANGE = { 2, 2, 492, 12 },
  SPACER = { 2, 18, 246, 12 },
}

MouseSteeringDisplay.POSITION = {
  BACKGROUND = { 0, 0 },
  SELF = { 0, -21 },
  TEXT_OFFSET = { 0, 25 },
  THUMB = { 0, 0 },
  SLIDER = { 0, 0 },
}

MouseSteeringDisplay.SIZE = {
  BACKGROUND = { 640, 74 },
  SELF = { 640, 75 },
  TEXT = 17,
  THUMB = { 2, 8 },
  SLIDER = { 492, 2 },
  SPACER = { 246, 2 },
}

MouseSteeringDisplay.COLOR = {
  BACKGROUND = { 0, 0, 0, 0.45 },
  THUMB = { 0.024, 0.533, 0.851, 1 },
  RANGE = { 0.7, 0.7, 0.7, 0.3 },
  ANGLE_TEXT = { 1, 1, 1, 0.75 },
}
