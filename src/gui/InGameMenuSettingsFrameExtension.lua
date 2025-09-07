--
-- InGameMenuSettingsFrameExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

InGameMenuSettingsFrameExtension = {}

local InGameMenuSettingsFrameExtension_mt = Class(InGameMenuSettingsFrameExtension)

---Creates a new instance of InGameMenuSettingsFrameExtension
function InGameMenuSettingsFrameExtension.new(customMt, mission, gui, i18n)
  local self = setmetatable({}, customMt or InGameMenuSettingsFrameExtension_mt)

  self.mission = mission
  self.gui = gui
  self.i18n = i18n

  self.isCreated = false

  return self
end

---Loads the in-game menu settings frame extension
function InGameMenuSettingsFrameExtension:load()
  if not self.isCreated then
    local frame = g_inGameMenu.pageSettings

    self:createButton(frame)
    self.isCreated = true
  end
end

---Creates and configures the mouse steering settings button
-- @param frame table The settings frame element to add the button to
function InGameMenuSettingsFrameExtension:createButton(frame)
  local button = frame.buttonPauseGame:clone(frame)

  button.onClickCallback = function()
    local dialogCallback = function(confirmed)
      if not confirmed then
        return
      end
    end

    MouseSteeringSettingsDialog.show(dialogCallback, nil, nil, true)
  end

  if button.parent ~= nil then
    button.parent:removeElement(button)
  end

  -- create container and configure
  local buttonContainer = frame.checkAutoHelp.parent
  local buttonFrame = buttonContainer:clone(frame)

  buttonFrame:removeElement(buttonFrame.elements[1])
  buttonFrame:removeElement(buttonFrame.elements[2])
  buttonFrame:addElement(button)

  -- configure button properties
  buttonFrame.elements[1]:setText(g_i18n:getText("mouseSteering_ui_extensionTitle"))
  buttonFrame.elements[2]:setText(g_i18n:getText("mouseSteering_ui_extensionOpenSettings"))

  buttonFrame.elements[2].focusId = nil
  buttonFrame.elements[2].id = "buttonMenu"
  buttonFrame.elements[2]:applyProfile(InGameMenuSettingsFrameExtension.PROFILE.BUTTON_MENU)
  buttonFrame.elements[2]:onFocusLeave()

  -- insert into UI and setup focus
  if buttonFrame.parent ~= nil then
    buttonFrame.parent:removeElement(buttonFrame)
  end

  local parentElements = buttonContainer.parent.elements
  local index = table.find(parentElements, buttonContainer)
  table.insert(parentElements, index, buttonFrame)
  buttonFrame.parent = buttonContainer.parent

  -- setup focus management
  local currentGui = FocusManager.currentGui
  FocusManager:setGui("ingameMenuSettings")
  FocusManager:loadElementFromCustomValues(buttonFrame.elements[2])
  FocusManager:setGui(currentGui)
end

---
InGameMenuSettingsFrameExtension.PROFILE = {
  BUTTON_MENU = "mouseSteeringSettingsMenuButton",
}
