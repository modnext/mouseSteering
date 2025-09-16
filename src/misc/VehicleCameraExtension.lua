--
-- VehicleCameraExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

VehicleCameraExtension = {}

local VehicleCameraExtension_mt = Class(VehicleCameraExtension)

---Creates a new instance of VehicleCameraExtension
function VehicleCameraExtension.new(customMt)
  local self = setmetatable({}, customMt or VehicleCameraExtension_mt)

  self.overwrittenFunctions = {}
  self.movedSide = 0

  return self
end

---
function VehicleCameraExtension:delete()
  for i = #self.overwrittenFunctions, 1, -1 do
    local funcInfo = self.overwrittenFunctions[i]
    funcInfo.object[funcInfo.funcName] = funcInfo.oldFunc
    self.overwrittenFunctions[i] = nil
  end
end

---Load the camera extension
function VehicleCameraExtension:load()
  self:overwriteGameFunctions()
end

---Safely overwrites a function in a class with a wrapper function
function VehicleCameraExtension:overwriteFunction(class, funcName, newFunc)
  local oldFunc = class[funcName]

  if oldFunc ~= nil then
    class[funcName] = function(...)
      return newFunc(self, oldFunc, ...)
    end

    -- store information about the overwritten function for cleanup
    table.insert(self.overwrittenFunctions, {
      object = class,
      funcName = funcName,
      oldFunc = oldFunc,
    })
  end
end

---Determines if mouse steering should be allowed for camera control
-- @param isMouse boolean True if input is from mouse
-- @param object table The camera object being controlled
-- @return boolean True if normal camera control should be used, false if mouse steering should take over
function VehicleCameraExtension:canSteerWithMouse(isMouse, object)
  if isMouse == nil or object == nil or object.vehicle == nil then
    return true -- use normal camera control if parameters are invalid
  end

  -- check if mouse steering is active
  local spec = object.vehicle.spec_mouseSteeringVehicle
  local isMouseSteeringActive = spec ~= nil and spec.isUsed and not spec.isSteeringPaused and not spec.isCameraRotating

  return not isMouseSteeringActive
end

---
function VehicleCameraExtension:actionEventLookLeftRight(superFunc, object, actionName, inputValue, callbackState, isAnalog, isMouse)
  if self:canSteerWithMouse(isMouse, object) then
    return superFunc(object, actionName, inputValue, callbackState, isAnalog, isMouse)
  end

  self.movedSide = inputValue * 0.001 * 16.666
end

---
function VehicleCameraExtension:actionEventLookUpDown(superFunc, object, actionName, inputValue, callbackState, isAnalog, isMouse)
  if self:canSteerWithMouse(isMouse, object) then
    return superFunc(object, actionName, inputValue, callbackState, isAnalog, isMouse)
  end

  -- no action needed if mouse steering is not allowed
end

---Overwrites the original VehicleCamera functions with mouse steering versions
function VehicleCameraExtension:overwriteGameFunctions()
  self:overwriteFunction(VehicleCamera, "actionEventLookLeftRight", self.actionEventLookLeftRight)
  self:overwriteFunction(VehicleCamera, "actionEventLookUpDown", self.actionEventLookUpDown)
end

---Retrieves and resets the accumulated camera movement side displacement
function VehicleCameraExtension:getMovedSide()
  -- reset after read to process movement only once per frame
  local currentMovement = self.movedSide
  self.movedSide = 0

  return currentMovement
end
