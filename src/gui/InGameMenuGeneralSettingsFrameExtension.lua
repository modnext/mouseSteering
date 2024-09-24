--
-- InGameMenuGeneralSettingsFrameExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

InGameMenuGeneralSettingsFrameExtension = {}

local InGameMenuGeneralSettingsFrameExtension_mt = Class(InGameMenuGeneralSettingsFrameExtension)

function InGameMenuGeneralSettingsFrameExtension.new(customMt, mission, gui, i18n)
  local self = setmetatable({}, customMt or InGameMenuGeneralSettingsFrameExtension_mt)

  self.mission = mission
  self.gui = gui
  self.i18n = i18n

  self.isCreated = false

  return self
end

function InGameMenuGeneralSettingsFrameExtension:load()
  local oldFunc = InGameMenuGeneralSettingsFrame.onFrameOpen

  local function newFunc(superFunc, frame)
    superFunc(frame)

    if not self.isCreated then
      self:createButton(frame)
      self.isCreated = true
    end
  end

  InGameMenuGeneralSettingsFrame.onFrameOpen = function(...)
    return newFunc(oldFunc, ...)
  end
end

function InGameMenuGeneralSettingsFrameExtension:createButton(frame)
  local pageSettingsGame = self.mission.inGameMenu.pageSettingsGame
  local button = pageSettingsGame.buttonPauseGame:clone(pageSettingsGame.boxLayout)

  button.onClickCallback = function()
    self.gui:showGui("MouseSteeringMenu")
  end

  if button.parent then
    button.parent:removeElement(button)
  end

  local buttonFrame = frame.checkColorBlindMode:clone(frame.boxLayout)

  -- Remove the cloned elements
  buttonFrame:removeElement(buttonFrame.elements[1])
  buttonFrame:removeElement(buttonFrame.elements[1])
  buttonFrame:removeElement(buttonFrame.elements[1])
  buttonFrame:removeElement(buttonFrame.elements[2])

  -- Add the cloned button to the button frame
  buttonFrame:addElement(button)

  -- Set text for remaining elements
  buttonFrame.elements[1]:setText(self.i18n:getText("mouseSteering_ui_title"))
  buttonFrame.elements[2]:setText(self.i18n:getText("mouseSteering_ui_toolTip"))
  buttonFrame.elements[3]:setText(self.i18n:getText("input_MENU"))
  buttonFrame.elements[3]:applyProfile("mouseSteeringOpenMenuButton")

  if buttonFrame.parent then
    buttonFrame.parent:removeElement(buttonFrame)
  end

  -- Insert buttonFrame at the correct position
  local parentElements = frame.checkWoodHarvesterAutoCut.parent.elements
  local index = #parentElements + 1

  for i, element in ipairs(parentElements) do
    if element == frame.checkWoodHarvesterAutoCut then
      index = i + 1

      break
    end
  end

  table.insert(parentElements, index, buttonFrame)
  buttonFrame.parent = frame.checkWoodHarvesterAutoCut.parent

  -- No need to check if parent exists since we just set it
  frame.boxLayout:invalidateLayout()
end
