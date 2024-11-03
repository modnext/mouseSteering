--
-- MouseSteeringVehicle
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modName = g_currentModName

MouseSteeringVehicle = {}

function MouseSteeringVehicle.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function MouseSteeringVehicle.initSpecialization()
  local schemaSavegame = Vehicle.xmlSchemaSavegame

  schemaSavegame:register(XMLValueType.STRING, "vehicles.vehicle(?)." .. modName .. ".mouseSteeringVehicle#id", "ID of the vehicle")
end

function MouseSteeringVehicle.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "isMouseSteeringHudVisible", MouseSteeringVehicle.isMouseSteeringHudVisible)
  SpecializationUtil.registerFunction(vehicleType, "updateMouseSteeringControl", MouseSteeringVehicle.updateMouseSteeringControl)
  SpecializationUtil.registerFunction(vehicleType, "updateMouseSteeringHudDisplay", MouseSteeringVehicle.updateMouseSteeringHudDisplay)
  SpecializationUtil.registerFunction(vehicleType, "updateMouseSteeringControlledVehicle", MouseSteeringVehicle.updateMouseSteeringControlledVehicle)
  SpecializationUtil.registerFunction(vehicleType, "syncMouseSteeringAxis", MouseSteeringVehicle.syncMouseSteeringAxis)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringAxisSide", MouseSteeringVehicle.getMouseSteeringAxisSide)
  SpecializationUtil.registerFunction(vehicleType, "getMouseSteeringVehicleId", MouseSteeringVehicle.getMouseSteeringVehicleId)
end

function MouseSteeringVehicle.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onDelete", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onReadStream", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", MouseSteeringVehicle)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", MouseSteeringVehicle)
end

function MouseSteeringVehicle:onLoad(savegame)
  self.spec_mouseSteeringVehicle = self[("spec_%s.mouseSteeringVehicle"):format(modName)]
  local spec = self.spec_mouseSteeringVehicle

  spec.mouseSteering = g_currentMission.mouseSteering
  spec.settings = spec.mouseSteering.settings

  spec.enabled, spec.paused, spec.isRotating = false, false, false
  spec.steerRaw, spec.axisSide = 0, 0

  -- Generate a unique identifier for the vehicle if it doesn't have one yet
  spec.vehicleId = string.format("%05x", math.random(0, 0xfffff)) or "unknown"

  if savegame ~= nil then
    spec.vehicleId = savegame.xmlFile:getValue(savegame.key .. "." .. modName .. ".mouseSteeringVehicle#id", spec.vehicleId)
  end
end

function MouseSteeringVehicle:saveToXMLFile(xmlFile, key, usedModNames)
  local spec = self.spec_mouseSteeringVehicle

  xmlFile:setValue(key .. "#id", spec.vehicleId)
end

function MouseSteeringVehicle:onDelete()
  local spec = self.spec_mouseSteeringVehicle

  spec.mouseSteering, spec.settings = nil, nil
end

function MouseSteeringVehicle:onReadStream(streamId, connection)
  local spec = self.spec_mouseSteeringVehicle

  spec.vehicleId = streamReadString(streamId)
end

function MouseSteeringVehicle:onWriteStream(streamId, connection)
  local spec = self.spec_mouseSteeringVehicle

  streamWriteString(streamId, spec.vehicleId)
end

function MouseSteeringVehicle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
  local spec = self.spec_mouseSteeringVehicle

  spec.isRotating = true

  if not (self.getIsEntered ~= nil and self:getIsEntered()) then
    return
  end

  if self.getIsControlled ~= nil and self:getIsControlled() then
    self:updateMouseSteeringControl(dt)
    self:updateMouseSteeringHudDisplay()

    if self.isActiveForInputIgnoreSelectionIgnoreAI and self:getIsVehicleControlledByPlayer() then
      spec.isRotating = false
    elseif spec.isRotating and spec.enabled then
      self:syncMouseSteeringAxis()
    end
  end
end

function MouseSteeringVehicle:updateMouseSteeringControl(dt)
  local spec = self.spec_mouseSteeringVehicle

  if not spec.enabled then
    self:syncMouseSteeringAxis()

    return
  end

  if not g_inputBinding:getShowMouseCursor() then
    local isMotorStarted = self.getIsMotorStarted ~= nil and self:getIsMotorStarted()
    local mouseMoved = spec.mouseSteering:getMovedSide() ~= 0 and not spec.paused

    if isMotorStarted then
      if not spec.paused then
        local invertMultiplier = spec.settings.invertXAxis and -1 or 1
        local mousePosY = spec.mouseSteering:getMovedSide() * invertMultiplier

        spec.steerRaw = spec.mouseSteering:normalizeAxis(spec.steerRaw, mousePosY, spec.settings.sensitivity)
      end

      local linearity = spec.mouseSteering:applyLinearity(spec.steerRaw, {
        linearity = spec.settings.linearity,
        deadzone = spec.settings.deadzone,
      })

      spec.axisSide = spec.mouseSteering:applySmoothness(spec.axisSide, linearity, spec.settings.smoothness, dt)
    elseif not isMotorStarted and mouseMoved then
      local warning = self:getCanMotorRun() and g_i18n:getText("warning_motorNotStarted") or self:getMotorNotAllowedWarning()

      if warning ~= nil then
        g_currentMission:showBlinkingWarning(warning, 2000)
      end
    end
  end

  if self.setSteeringInput ~= nil then
    self:setSteeringInput(spec.axisSide, true, InputDevice.CATEGORY.WHEEL)
  end
end

function MouseSteeringVehicle:isMouseSteeringHudVisible(spec, isInside, activeCamera)
  local isObstructed = g_currentMission.hud.popupMessage:getVisible() or g_currentMission.hud.contextActionDisplay:getVisible()

  if not spec.enabled or isObstructed or not self:getIsMotorStarted() or self:getIsAIActive() or not self:getIsControlled() then
    return false
  end

  local hudVisibility = {
    [1] = true, -- outside and inside
    [2] = isInside, -- inside
    [3] = not isInside, -- outside
  }

  local showHud = hudVisibility[spec.settings.hud] or false

  if showHud and spec.settings.hudLookBackInside and activeCamera and activeCamera.isInside then
    local rotY = math.deg(activeCamera.rotY - activeCamera.origRotY) % 360
    showHud = rotY >= 120 and rotY <= 240
  end

  return showHud
end

function MouseSteeringVehicle:updateMouseSteeringHudDisplay()
  local spec = self.spec_mouseSteeringVehicle
  local activeCamera = self:getActiveCamera()

  if not activeCamera then
    return
  end

  local isVisible = self:isMouseSteeringHudVisible(spec, activeCamera.isInside, activeCamera)
  local currentlyVisible = spec.mouseSteering:getHudVisible()

  if isVisible ~= currentlyVisible then
    spec.mouseSteering:setControlledVehicle(isVisible and self or nil)
  end

  local hudTextVisible = spec.settings.hudText
  spec.mouseSteering:setHudTextVisible(hudTextVisible and isVisible)
end

function MouseSteeringVehicle:updateMouseSteeringControlledVehicle(isEntering)
  local spec = self.spec_mouseSteeringVehicle

  if spec.mouseSteering:getHudVisible() then
    spec.mouseSteering:setControlledVehicle(isEntering and self or nil)
  end
end

function MouseSteeringVehicle:onEnterVehicle()
  local spec = self.spec_mouseSteeringVehicle

  spec.enabled = spec.mouseSteering:isVehicleSaved(self)
  self:updateMouseSteeringControlledVehicle(true)

  if spec.enabled then
    self:syncMouseSteeringAxis()
  end
end

function MouseSteeringVehicle:onLeaveVehicle()
  self:updateMouseSteeringControlledVehicle(false)
end

function MouseSteeringVehicle:actionEventToggleSteering(actionName, inputValue)
  if inputValue ~= 1 then
    return
  end

  local spec = self.spec_mouseSteeringVehicle
  spec.enabled = not spec.enabled

  if spec.settings.autoSaveVehicle then
    local action = spec.enabled and "addVehicle" or "removeVehicle"

    spec.mouseSteering[action](spec.mouseSteering, self)
    spec.mouseSteering:saveVehicleToXMLFile()
  end

  local warning = self:getMotorNotAllowedWarning()
  if warning ~= nil then
    g_currentMission:showBlinkingWarning(warning, 2000)
  end
end

function MouseSteeringVehicle:actionEventSaveSteering(actionName, inputValue)
  if inputValue ~= 1 then
    return
  end

  local spec = self.spec_mouseSteeringVehicle
  local isSaved = spec.mouseSteering:isVehicleSaved(self)
  local isMaxVehiclesReached = spec.mouseSteering:isMaxVehiclesReached()

  local action = isSaved and "removeVehicle" or "addVehicle"
  local notification = isSaved and "vehicleRemoved" or (not isMaxVehiclesReached and "vehicleAdded")

  if notification then
    spec.mouseSteering:showNotification("mouseSteering_notification_" .. notification)
  end

  spec.mouseSteering[action](spec.mouseSteering, self)
  spec.mouseSteering:saveVehicleToXMLFile()
end

function MouseSteeringVehicle:actionEventPauseSteering(actionName, inputValue)
  local spec = self.spec_mouseSteeringVehicle

  if spec.enabled then
    spec.paused = (inputValue == 1)
  end
end

function MouseSteeringVehicle:actionEventShowMenu(actionName, inputValue)
  g_gui:showGui("MouseSteeringMenu")
end

function MouseSteeringVehicle:syncMouseSteeringAxis()
  local spec = self.spec_mouseSteeringVehicle
  local drivable = self.spec_drivable

  local linearity = spec.mouseSteering:reverseLinearity(drivable.axisSide, {
    linearity = spec.settings.linearity,
    deadzone = spec.settings.deadzone,
  })

  spec.steerRaw = linearity
  spec.axisSide = drivable.axisSide
end

function MouseSteeringVehicle:getMouseSteeringAxisSide()
  return self.spec_mouseSteeringVehicle.axisSide
end

function MouseSteeringVehicle:getMouseSteeringVehicleId()
  return self.spec_mouseSteeringVehicle.vehicleId
end

function MouseSteeringVehicle:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if not self.isClient then
    return
  end

  local spec = self.spec_mouseSteeringVehicle
  self:clearActionEventsTable(spec.actionEvents)

  if self:getIsActiveForInput(true, true) and self:getIsEntered() and not self:getIsAIActive() then
    local actions = {
      { InputAction.MS_TOGGLE, MouseSteeringVehicle.actionEventToggleSteering },
      { InputAction.MS_SAVE, MouseSteeringVehicle.actionEventSaveSteering },
      { InputAction.MS_PAUSE, MouseSteeringVehicle.actionEventPauseSteering, true },
      { InputAction.MS_SHOW_MENU, MouseSteeringVehicle.actionEventShowMenu },
    }

    for _, action in ipairs(actions) do
      local _, actionEventId = self:addActionEvent(spec.actionEvents, action[1], self, action[2], action[3] or false, true, false, true, nil)
      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
      g_inputBinding:setActionEventTextVisibility(actionEventId, false)
    end
  end
end
