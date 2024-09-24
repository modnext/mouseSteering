--
-- MouseSteeringSliderElement
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringSliderElement = {}

local MouseSteeringSliderElement_mt = Class(MouseSteeringSliderElement, SliderElement)

function MouseSteeringSliderElement.new(target, custom_mt)
  local self = SliderElement.new(target, custom_mt or MouseSteeringSliderElement_mt)

  self.trackOverlay = {}

  return self
end

function MouseSteeringSliderElement:delete()
  GuiOverlay.deleteOverlay(self.trackOverlay)

  MouseSteeringSliderElement:superClass().delete(self)
end

function MouseSteeringSliderElement:loadFromXML(xmlFile, key)
  MouseSteeringSliderElement:superClass().loadFromXML(self, xmlFile, key)

  GuiOverlay.loadOverlay(self, self.trackOverlay, "trackImage", self.imageSize, nil, xmlFile, key)
  GuiOverlay.createOverlay(self.trackOverlay)
end

function MouseSteeringSliderElement:loadProfile(profile, applyProfile)
  MouseSteeringSliderElement:superClass().loadProfile(self, profile, applyProfile)

  GuiOverlay.loadOverlay(self, self.trackOverlay, "trackImage", self.imageSize, profile, nil, nil)
end

function MouseSteeringSliderElement:copyAttributes(src)
  MouseSteeringSliderElement:superClass().copyAttributes(self, src)

  GuiOverlay.copyOverlay(self.trackOverlay, src.trackOverlay)
end

function MouseSteeringSliderElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
  if not self:getIsActive() then
    return eventUsed
  end

  if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) or Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
    return eventUsed
  end

  if MouseSteeringSliderElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
    eventUsed = true
  end

  if GuiUtils.checkOverlayOverlap(posX, posY, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2]) then
    self:handleMouseEnter(isDown, button)
  else
    self:handleMouseLeave()
  end

  return eventUsed
end

function MouseSteeringSliderElement:handleMouseEnter(isDown, button)
  local isLeftClick = isDown and button == Input.MOUSE_BUTTON_LEFT

  if isLeftClick and self.handleFocus ~= nil and self:getOverlayState() ~= GuiOverlay.STATE_FOCUSED then
    FocusManager:setFocus(self)
  end

  if not self.mouseEntered then
    if self:getOverlayState() == GuiOverlay.STATE_NORMAL then
      FocusManager:setHighlight(self)
    end

    self.mouseEntered = true
  end
end

function MouseSteeringSliderElement:handleMouseLeave()
  self:restoreOverlayState()
  self.mouseEntered = false

  FocusManager:unsetHighlight(self)
end

function MouseSteeringSliderElement:callOnChanged()
  self:raiseCallback("onChangedCallback", self, self.currentValue)
end

function MouseSteeringSliderElement:addElement(element)
  MouseSteeringSliderElement:superClass().addElement(self, element)

  if element.name == "text" then
    self.textElement = element
  end
end

function MouseSteeringSliderElement:draw(clipX1, clipY1, clipX2, clipY2)
  local overlayState = self:getOverlayState()

  local trackWidth = self.direction == SliderElement.DIRECTION_X and (self.sliderPosition[1] - self.absPosition[1]) or self.size[1]
  local trackHeight = self.direction ~= SliderElement.DIRECTION_X and (self.sliderPosition[2] - self.absPosition[2]) or self.size[2]

  GuiOverlay.renderOverlay(self.overlay, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2], overlayState, clipX1, clipY1, clipX2, clipY2)
  GuiOverlay.renderOverlay(self.trackOverlay, self.absPosition[1], self.absPosition[2], trackWidth, trackHeight, overlayState, clipX1, clipY1, clipX2, clipY2)

  MouseSteeringSliderElement:superClass().draw(self, clipX1, clipY1, clipX2, clipY2)
end

function MouseSteeringSliderElement:setValue(newValue, doNotUpdateDataElement, immediateMode)
  SliderElement.setValue(self, newValue, doNotUpdateDataElement, immediateMode)

  self:setSoundSuppressed(true)
  self:playSample(GuiSoundPlayer.SOUND_SAMPLES.HOVER)
  self:setSoundSuppressed(false)
end

function MouseSteeringSliderElement:setText(value)
  if self.textElement ~= nil and type(self.textElement) == "table" and self.textElement.setText ~= nil then
    self.textElement:setText(tostring(value))
  end

  self:updateSliderButtons()
end

function MouseSteeringSliderElement:setTrackImageFilename(filename)
  self.trackOverlay = GuiOverlay.createOverlay(self.trackOverlay, filename)
end
