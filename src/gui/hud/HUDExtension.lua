--
-- HUDExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

HUDExtension = {}

local HUDExtension_mt = Class(HUDExtension)

function HUDExtension.new(customMt, mission, gui, i18n)
  local self = setmetatable({}, customMt or HUDExtension_mt)

  self.mission = mission
  self.gui = gui
  self.i18n = i18n

  return self
end

function HUDExtension:load()
  self:overwriteGameFunctions()
end

function HUDExtension:drawVehicleName(superFunc)
  local hasVehicle = self.currentVehicleName ~= nil
  local isObstructed = self.popupMessage:getVisible() or self.contextActionDisplay:getVisible()
  local isMouseSteering = g_currentMission.mouseSteering:getHudVisible()

  if not self.isMenuVisible and hasVehicle and not isObstructed and not isMouseSteering then
    local displayDelayTicks = (self.displayDelayTicks or 0) + 1

    if displayDelayTicks >= 4 then
      self.vehicleNameDisplay:draw()
    end

    self.displayDelayTicks = displayDelayTicks
  else
    self.displayDelayTicks = 0
  end
end

function HUDExtension:overwriteGameFunctions()
  HUD.drawVehicleName = Utils.overwrittenFunction(HUD.drawVehicleName, self.drawVehicleName)
end
