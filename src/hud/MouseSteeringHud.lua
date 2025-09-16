--
-- MouseSteeringHud
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringHud = {}

local MouseSteeringHud_mt = Class(MouseSteeringHud)

---Creates a new instance of MouseSteeringHud
function MouseSteeringHud.new(customMt, modDirectory, mission, gui, i18n)
  local self = setmetatable({}, customMt or MouseSteeringHud_mt)

  self.modDirectory = modDirectory
  self.mission = mission
  self.gui = gui
  self.i18n = i18n

  -- create display components list
  self.displayComponents = {}

  return self
end

---Initializes the HUD system and subscribes to UI scale changes
function MouseSteeringHud:load()
  local uiScale = g_gameSettings:getValue(GameSettings.SETTING.UI_SCALE)

  -- create display components
  self:createDisplayComponents(uiScale)

  -- subscribe to UI scale changes
  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.UI_SCALE], self.onUIScaleChanged, self)
end

---Cleans up the HUD system and unsubscribes from all messages
function MouseSteeringHud:delete()
  g_messageCenter:unsubscribeAll(self)

  -- delete all display components
  for _, component in pairs(self.displayComponents) do
    if component then
      component:delete()
    end
  end

  -- clear components list
  self.displayComponents = {}
end

---Creates and initializes display components for the HUD
-- @param uiScale number The current UI scale factor
function MouseSteeringHud:createDisplayComponents(uiScale)
  -- create mouse steering indicator display
  self.mouseSteeringIndicatorDisplay = MouseSteeringIndicatorDisplay.new()
  self.mouseSteeringIndicatorDisplay:setScale(uiScale)
  self.mouseSteeringIndicatorDisplay:setVisible(false)

  -- add to display components list
  table.insert(self.displayComponents, self.mouseSteeringIndicatorDisplay)
end

---Draws the HUD for the controlled entity
function MouseSteeringHud:drawControlledEntityHUD()
  self.mouseSteeringIndicatorDisplay:draw()
end

---Sets the controlled vehicle for the HUD display
-- @param vehicle table The vehicle to control
function MouseSteeringHud:setControlledVehicle(vehicle)
  self.mouseSteeringIndicatorDisplay:setVehicle(vehicle)
end

---Updates the HUD state
-- @param dt number Delta time for the update cycle
function MouseSteeringHud:update(dt)
  self.mouseSteeringIndicatorDisplay:update(dt)
end

---Gets the visibility state of the HUD
-- @return boolean True if HUD is visible, false otherwise
function MouseSteeringHud:getHudVisible()
  return self.mouseSteeringIndicatorDisplay:getVisible()
end

---Sets the visibility of text elements in the HUD
-- @param visible boolean Whether text should be visible
function MouseSteeringHud:setTextVisible(visible)
  self.mouseSteeringIndicatorDisplay:setTextVisible(visible)
end

---Sets the scale for all display components
-- @param uiScale number The UI scale factor to apply
function MouseSteeringHud:setScale(uiScale)
  for _, component in pairs(self.displayComponents) do
    if component.setScale ~= nil then
      component:setScale(uiScale)
    end
  end
end

---Handles UI scale changes and updates component scales accordingly
-- @param uiScale number The new UI scale factor
function MouseSteeringHud:onUIScaleChanged(uiScale)
  self:setScale(uiScale)
end
