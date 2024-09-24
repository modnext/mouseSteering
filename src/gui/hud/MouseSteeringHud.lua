--
-- MouseSteeringHud
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringHud = {}

local MouseSteeringHud_mt = Class(MouseSteeringHud)

function MouseSteeringHud.new(customMt, modDirectory, mission, gui, i18n)
  local self = setmetatable({}, customMt or MouseSteeringHud_mt)

  self.modDirectory = modDirectory
  self.mission = mission
  self.gui = gui
  self.i18n = i18n

  self.displayComponents = {}

  self.hudExtension = HUDExtension.new(nil, mission, gui, i18n)

  return self
end

function MouseSteeringHud:load()
  local uiScale = g_gameSettings:getValue("uiScale")

  self:createDisplayComponents(uiScale)
  self.hudExtension:load()
end

function MouseSteeringHud:createDisplayComponents(uiScale)
  local hudAtlasPath = Utils.getFilename("data/gui/images/hud_elements.png", self.modDirectory)

  self.mouseSteeringDisplay = MouseSteeringDisplay.new(hudAtlasPath)

  self.mouseSteeringDisplay:setScale(uiScale)
  self.mouseSteeringDisplay:setVisible(false, false)

  table.insert(self.displayComponents, self.mouseSteeringDisplay)
end

function MouseSteeringHud:drawControlledEntityHUD()
  self.mouseSteeringDisplay:draw()
end

function MouseSteeringHud:setControlledVehicle(vehicle, animated)
  self.mouseSteeringDisplay:setVehicle(vehicle, animated)
end

function MouseSteeringHud:update(dt)
  self.mouseSteeringDisplay:update(dt)
end

function MouseSteeringHud:getHudVisible()
  return self.mouseSteeringDisplay:getVisible()
end

function MouseSteeringHud:setTextVisible(visible)
  self.mouseSteeringDisplay:setTextVisible(visible)
end
