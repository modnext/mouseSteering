--
-- VehicleCameraExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

VehicleCameraExtension = {}

local VehicleCameraExtension_mt = Class(VehicleCameraExtension)

function VehicleCameraExtension.new(customMt)
  local self = setmetatable({}, customMt or VehicleCameraExtension_mt)

  self.movedSide = 0

  return self
end

function VehicleCameraExtension:load()
  self:overwriteGameFunctions()
end

function VehicleCameraExtension:overwriteFunction(class, funcName, newFunc)
  local oldFunc = class[funcName]

  if oldFunc ~= nil then
    class[funcName] = function(...)
      return newFunc(self, oldFunc, ...)
    end
  end
end

function VehicleCameraExtension:canSteerWithMouse(isMouse, camera)
  if isMouse == nil or camera == nil or camera.vehicle == nil then
    return true
  end

  local spec = camera.vehicle.spec_mouseSteeringVehicle
  return not (spec ~= nil and spec.enabled and not spec.paused)
end

function VehicleCameraExtension:actionEventLookLeftRight(superFunc, object, actionName, inputValue, callbackState, isAnalog, isMouse)
  if self:canSteerWithMouse(isMouse, object) then
    return superFunc(object, actionName, inputValue, callbackState, isAnalog, isMouse)
  end

  self.movedSide = inputValue * (1 / 60)
end

function VehicleCameraExtension:actionEventLookUpDown(superFunc, object, actionName, inputValue, callbackState, isAnalog, isMouse)
  if self:canSteerWithMouse(isMouse, object) then
    return superFunc(object, actionName, inputValue, callbackState, isAnalog, isMouse)
  end
end

function VehicleCameraExtension:overwriteGameFunctions()
  self:overwriteFunction(VehicleCamera, "actionEventLookLeftRight", self.actionEventLookLeftRight)
  self:overwriteFunction(VehicleCamera, "actionEventLookUpDown", self.actionEventLookUpDown)
end
