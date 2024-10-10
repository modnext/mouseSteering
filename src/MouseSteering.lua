--
-- MouseSteering
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteering = {
  MAX_VEHICLES = 100,
}

local MouseSteering_mt = Class(MouseSteering)

function MouseSteering.new(modName, modDirectory, modSettingsDirectory, mission, i18n, gui)
  local self = setmetatable({}, MouseSteering_mt)

  self.modName = modName
  self.modDirectory = modDirectory
  self.modSettingsDirectory = modSettingsDirectory

  self.isServer = mission:getIsServer()
  self.isClient = mission:getIsClient()
  self.mission = mission
  self.i18n = i18n

  self.modDesc = {}
  self.settings = {}

  -- store and camera extensions
  self.store = MouseSteeringStore.new()
  self.camera = VehicleCameraExtension.new()

  -- gui menu and hud
  self.gui = MouseSteeringGui.new(nil, modDirectory, mission, gui, i18n)
  self.hud = MouseSteeringHud.new(nil, modDirectory, mission, gui, i18n)

  return self
end

function MouseSteering:delete() end

function MouseSteering:load()
  self:loadFromXMLFiles()

  self.camera:load()
  self.gui:load()
  self.hud:load()
end

function MouseSteering:draw()
  local isNotMenuVisible = not self.mission.hud.isMenuVisible
  local isNotFading = not self.mission.hud:getIsFading()

  if self.isClient and isNotMenuVisible and not g_noHudModeEnabled and isNotFading then
    self.hud:drawControlledEntityHUD()
  end
end

function MouseSteering:onMissionLoaded(mission)
  self:load()
end

function MouseSteering:update(dt)
  self.hud:update(dt)
end

function MouseSteering:loadFromXMLFiles()
  self:loadModDescFromXMLFile()
  self:loadSettingsFromXMLFile()
  self:loadVehicleFromXMLFile()
end

function MouseSteering:loadModDescFromXMLFile()
  local xmlFile = XMLFile.loadIfExists("modDesc", self.modDirectory .. "modDesc.xml")

  if xmlFile == nil then
    Logging.error(string.format("Mouse Steering: Failed to load modDesc from (%s) path!", self.modDirectory .. "modDesc.xml"))

    return
  end

  local version = xmlFile:getString("modDesc.version")

  if version ~= nil then
    local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")

    if major and minor and patch then
      self.modDesc.version = string.format("%s.%s.%s", major, minor, patch)
    end
  end

  xmlFile:delete()
end

function MouseSteering:loadConfigFile(file, defaultPath)
  local path = self.modSettingsDirectory .. file .. ".xml"

  createFolder(self.modSettingsDirectory)
  copyFile(defaultPath, path, false)

  if not fileExists(path) then
    path = defaultPath
  end

  return path
end

function MouseSteering:loadSettingsFromXMLFile()
  local xmlFilename = self:loadConfigFile("settings", Utils.getFilename("data/settings.xml", self.modDirectory))
  local xmlFile = XMLFile.loadIfExists("MouseSteeringXML", xmlFilename)

  if xmlFile == nil then
    Logging.error(string.format("Mouse Steering: Failed to load settings from (%s) path!", xmlFilename))

    return false
  end

  xmlFile:iterate("settings.setting", function(_, key)
    local name = xmlFile:getString(key .. "#name")
    local value = self:getXMLSetting(xmlFile, key)

    if name ~= nil and value ~= nil then
      self.settings[name] = value
    end
  end)

  xmlFile:delete()

  return true
end

function MouseSteering:saveSettingsToXMLFile()
  local xmlFile = XMLFile.create("MouseSteeringXML", self.modSettingsDirectory .. "settings.xml", "settings")

  if xmlFile == nil then
    Logging.error("Mouse Steering: Something went wrong while trying to save settings!")

    return
  end

  local i = 0

  for name, value in pairs(self.settings) do
    local key = string.format("settings.setting(%d)", i)

    self:setXMLSetting(xmlFile, key, {
      name = name,
      value = value,
    })

    i = i + 1
  end

  xmlFile:save()
  xmlFile:delete()
end

function MouseSteering:reset()
  self.store:clearVehicles()

  if fileExists(self.modSettingsDirectory .. "settings.xml") then
    deleteFolder(self.modSettingsDirectory)
  end

  self:loadSettingsFromXMLFile()
end

function MouseSteering:getXMLSetting(xmlFile, key)
  local types = {
    integer = xmlFile.getInt,
    boolean = xmlFile.getBool,
    float = xmlFile.getFloat,
    string = xmlFile.getString,
  }

  for typeName, getFunction in pairs(types) do
    local value = getFunction(xmlFile, key .. "#" .. typeName)

    if value ~= nil then
      return value
    end
  end

  return nil
end

function MouseSteering:setXMLSetting(xmlFile, key, setting)
  local name, value = setting.name, setting.value
  xmlFile:setString(key .. "#name", name)

  if type(value) == "number" then
    if value % 1 == 0 then
      xmlFile:setInt(key .. "#integer", math.floor(value))
    else
      xmlFile:setFloat(key .. "#float", value)
    end
  elseif type(value) == "boolean" then
    xmlFile:setBool(key .. "#boolean", value)
  end
end

function MouseSteering:loadVehicleFromXMLFile()
  local path = self.modSettingsDirectory .. "vehicles.xml"

  self.store:loadFromXMLFile(path)
end

function MouseSteering:saveVehicleToXMLFile()
  local path = self.modSettingsDirectory .. "vehicles.xml"

  self.store:saveToXMLFile(path)
end

function MouseSteering:addVehicle(param)
  local result = self.store:addVehicle(param)

  if result ~= nil and self.store:isMaxVehiclesReached() then
    self:showNotification("mouseSteering_notification_vehicleLimit", true)
  end

  return result
end

function MouseSteering:removeVehicle(param)
  return self.store:removeVehicle(param)
end

function MouseSteering:getVehicleKey(vehicle)
  return self.store:getVehicleKey(vehicle)
end

function MouseSteering:isVehicleSaved(vehicle)
  return self.store:isVehicleSaved(vehicle)
end

function MouseSteering:isMaxVehiclesReached()
  return self.store:isMaxVehiclesReached()
end

function MouseSteering:getVehicleCount()
  return self.store:getVehicleCount()
end

function MouseSteering:getVehicles()
  return self.store:getVehicles()
end

function MouseSteering:setControlledVehicle(vehicle)
  self.hud:setControlledVehicle(vehicle, true)
end

function MouseSteering:showNotification(textKey, ...)
  local config = {
    type = FSBaseMission.INGAME_NOTIFICATION_INFO,
    duration = 4000,
    sound = GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION,
  }

  local text = self.i18n:getText(textKey):format(...)
  self.mission.hud:addSideNotification(config.type, text, config.duration, config.sound)
end

function MouseSteering:normalizeAxis(axis, input, sensitivity)
  return math.min(math.max(axis + input * sensitivity, -1), 1)
end

function MouseSteering:bezier(t, p0, p1, p2, p3)
  local u = 1 - t
  return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
end

function MouseSteering:applyLinearity(axis, params)
  local linearity = params.linearity
  local deadzone = params.deadzone

  if math.abs(axis) < deadzone then
    return 0
  end

  local sign = (axis > 0) and 1 or -1
  local adjustedAxis = (math.abs(axis) - deadzone) / (1 - deadzone)

  if linearity == 1 then
    return sign * adjustedAxis
  end

  local exponent = math.min(math.max(linearity, 0.25), 5)
  local result = self:bezier(adjustedAxis ^ exponent, 0, 0.05, 0.15, 1)

  return sign * math.min(1, math.max(0, result))
end

function MouseSteering:reverseLinearity(axis, params)
  if math.abs(axis) < 1e-6 then
    return 0
  end

  local sign = (axis > 0) and 1 or -1
  local absAxis = math.abs(axis)

  local linearity = params.linearity
  local deadzone = params.deadzone

  if linearity == 1 then
    return sign * (absAxis * (1 - deadzone) + deadzone)
  end

  local exponent = math.min(math.max(linearity, 0.25), 5)
  local low, high = 0, 1

  while (high - low) > 1e-8 do
    local mid = (low + high) / 2
    local value = self:bezier(mid ^ exponent, 0, 0.05, 0.15, 1)

    if value < absAxis then
      low = mid
    else
      high = mid
    end
  end

  return sign * (low * (1 - deadzone) + deadzone)
end

function MouseSteering:applySmoothness(current, target, smoothness, dt)
  if smoothness <= 0 then
    return target
  end

  smoothness = math.min(math.max(smoothness, 0.65), 0.85)
  local smoothingFactor = (1 - smoothness) ^ 2
  local decay = -dt / 16.67
  local smoothing = 1 - math.exp(smoothingFactor * decay)

  return current + (target - current) * smoothing
end

function MouseSteering:getHudVisible()
  return self.hud:getHudVisible()
end

function MouseSteering:setHudTextVisible(visible)
  self.hud:setTextVisible(visible)
end

function MouseSteering:getMovedSide()
  return self.camera.movedSide
end
