--
-- MouseSteeringInputController
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringInputController = {}

local MouseSteeringInputController_mt = Class(MouseSteeringInputController)

---Creates the mouse steering input controller
-- @param table owner mouse steering system
-- @param table|nil customMt custom metatable
-- @return table self input controller
function MouseSteeringInputController.new(owner, customMt)
  local self = setmetatable({}, customMt or MouseSteeringInputController_mt)

  self.owner = owner
  self.originalMouseButtonPressed = nil
  self.mouseButtonPressedWrapper = nil
  self.allowMouseButtonInput = false

  return self
end

---Installs the mouse-wheel input filter
function MouseSteeringInputController:load()
  if self.owner == nil or not self.owner.isClient then
    return
  end

  if self.originalMouseButtonPressed == nil then
    local originalMouseButtonPressed = Input.isMouseButtonPressed

    self.originalMouseButtonPressed = originalMouseButtonPressed
    self.mouseButtonPressedWrapper = function(button)
      return self:isMouseButtonPressed(originalMouseButtonPressed, button)
    end

    Input.isMouseButtonPressed = self.mouseButtonPressedWrapper
  end
end

---Removes the mouse-wheel input filter
function MouseSteeringInputController:delete()
  if Input ~= nil and Input.isMouseButtonPressed == self.mouseButtonPressedWrapper then
    Input.isMouseButtonPressed = self.originalMouseButtonPressed
  end

  self.owner = nil
  self.originalMouseButtonPressed = nil
  self.mouseButtonPressedWrapper = nil
  self.allowMouseButtonInput = false
end

---Gets whether camera-rotation input is currently held
-- @param table vehicle locally controlled vehicle
-- @return boolean isPressed true when camera rotation input is held
function MouseSteeringInputController:getIsCameraRotationInputPressed(vehicle)
  local action = g_inputBinding:getActionByName(InputAction.TOGGLE_MOUSE_STEERING_ROTATE_CAMERA)

  if action ~= nil then
    local activeBindings = action:getActiveBindings()

    for _, binding in ipairs(activeBindings) do
      if binding.isPressed then
        return true
      end
    end

    if #activeBindings > 0 then
      return false
    end
  end

  return vehicle.getIsMouseSteeringSteeringPaused ~= nil and vehicle:getIsMouseSteeringSteeringPaused()
end

---Reads the current mouse-wheel direction for speed control
-- @return number direction +1 for up, -1 for down, 0 without scroll input
function MouseSteeringInputController:getScrollDirection()
  local previousAllowState = self.allowMouseButtonInput
  local direction = 0

  self.allowMouseButtonInput = true

  if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
    direction = 1
  elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
    direction = -1
  end

  self.allowMouseButtonInput = previousAllowState

  return direction
end

---Gets whether the mouse wheel is reserved for speed control
-- @return boolean isCaptured true when other mouse-wheel actions should be blocked
function MouseSteeringInputController:getIsSpeedControlInputCaptured()
  local owner = self.owner
  local vehicle = g_localPlayer ~= nil and g_localPlayer:getCurrentVehicle() or nil

  if owner == nil or owner.mission ~= g_currentMission or vehicle == nil or vehicle.getMotor == nil or vehicle.getMouseSteeringSpeedControlEnabled == nil or vehicle.getIsMouseSteeringUsed == nil then
    return false
  end

  local passengerSpec = vehicle.spec_enterablePassenger

  return not (passengerSpec ~= nil and passengerSpec.passengerEntered == true) and not g_gui:getIsGuiVisible() and g_inputBinding:getContextName() == Vehicle.INPUT_CONTEXT_NAME and vehicle:getIsActiveForInput(true) and vehicle:getMotor() ~= nil and vehicle:getMouseSteeringSpeedControlEnabled() and vehicle:getIsMouseSteeringUsed() and not self:getIsCameraRotationInputPressed(vehicle)
end

---Filters direct mouse-wheel polling used by other scripts
-- @param function superFunc original mouse button function
-- @param number button mouse button identifier
-- @return boolean isPressed true when the button is available to the caller
function MouseSteeringInputController:isMouseButtonPressed(superFunc, button)
  local isPressed = superFunc(button)
  local shouldBlockInput = isPressed and not self.allowMouseButtonInput and InputBinding.MOUSE_WHEEL[button] == true and self:getIsSpeedControlInputCaptured()

  if shouldBlockInput then
    return false
  end

  return isPressed
end
