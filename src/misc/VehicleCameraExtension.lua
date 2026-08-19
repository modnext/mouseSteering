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

---Checks if the camera is currently used by the local passenger
function VehicleCameraExtension:getIsPassengerCamera(object)
  local isPassengerCamera = object ~= nil and object.isPassengerCamera == true

  if not isPassengerCamera and object ~= nil and object.vehicle ~= nil then
    local spec = object.vehicle.spec_enterablePassenger
    isPassengerCamera = spec ~= nil and spec.passengerEntered == true
  end

  return isPassengerCamera
end

---Determines if mouse steering should be allowed for camera control
-- @param isMouse boolean True if input is from mouse
-- @param object table The camera object being controlled
-- @return boolean True if normal camera control should be used, false if mouse steering should take over
function VehicleCameraExtension:canSteerWithMouse(isMouse, object)
  local vehicle = object ~= nil and object.vehicle or nil
  local canUseCamera = true

  if isMouse ~= nil and vehicle ~= nil and not self:getIsPassengerCamera(object) then
    local spec = vehicle.spec_mouseSteeringVehicle
    local isMouseSteeringActive = spec ~= nil and spec.isUsed and not spec.isSteeringPaused and not spec.isCameraRotating

    canUseCamera = not isMouseSteeringActive
  end

  return canUseCamera
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
end

---
function VehicleCameraExtension:zoomSmoothly(superFunc, object, offset)
  local vehicle = object ~= nil and object.vehicle or nil
  local isPassengerCamera = self:getIsPassengerCamera(object)

  if isPassengerCamera or (vehicle ~= nil and vehicle:getIsAIActive()) then
    return superFunc(object, offset)
  elseif self:canSteerWithMouse(true, object) then
    local spec = vehicle ~= nil and vehicle.spec_mouseSteeringVehicle or nil

    -- check if mouse steering is active
    if spec and spec.isUsed and spec.settings.speedControl and not spec.isSteeringPaused then
      return
    end

    return superFunc(object, offset)
  end
end

---Applies function hooks to VehicleCamera class
function VehicleCameraExtension:overwriteGameFunctions()
  self:overwriteFunction(VehicleCamera, "actionEventLookLeftRight", self.actionEventLookLeftRight)
  self:overwriteFunction(VehicleCamera, "actionEventLookUpDown", self.actionEventLookUpDown)
  self:overwriteFunction(VehicleCamera, "zoomSmoothly", self.zoomSmoothly)
end

---Retrieves and resets the accumulated camera movement side displacement
function VehicleCameraExtension:getMovedSide()
  -- reset after read to process movement only once per frame
  local currentMovement = self.movedSide
  self.movedSide = 0

  return currentMovement
end
