--
-- MouseSteering
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

---
MouseSteering = {
  MAX_VEHICLES = 100,
  MAX_VEHICLE_SELLS = 50,
  NOTIFICATION_DURATION = 4000,
  CURRENT_REVISION = 1,
}

local MouseSteering_mt = Class(MouseSteering)

---Creates a new instance of MouseSteering
function MouseSteering.new(modName, modDirectory, modSettingsDirectory, mission, i18n, gui)
  local self = setmetatable({}, MouseSteering_mt)

  self.modName = modName
  self.modDirectory = modDirectory
  self.modSettingsDirectory = modSettingsDirectory

  self.isServer = mission:getIsServer()
  self.isClient = mission:getIsClient()
  self.mission = mission
  self.i18n = i18n

  self.settings = {}
  self.vehicles = {}

  -- initialize vehicle sells tracking
  self.vehicleSells = {}

  -- initialize camera extensions
  self.vehicleCamera = VehicleCameraExtension.new()

  -- initialize gui menu and hud
  self.gui = MouseSteeringGui.new(nil, modDirectory, mission, gui, i18n)
  self.hud = MouseSteeringHud.new(nil, modDirectory, mission, gui, i18n)

  -- subscribe to network messages
  g_messageCenter:subscribe(MouseSteeringMessageType.VEHICLE_SOLD, self.onVehicleSoldNetworkMessage, self)

  -- create mod settings directory
  createFolder(self.modSettingsDirectory)

  return self
end

---Called on delete
function MouseSteering:delete()
  g_messageCenter:unsubscribeAll(self)

  self.hud:delete()
  self.vehicleCamera:delete()
end

---Called on load
function MouseSteering:load()
  self:loadSettingsFromXMLFile()
  self:loadVehicleFromXMLFile()
end

---Called when the mission is loaded
-- @param mission table the loaded mission
function MouseSteering:onMissionLoaded(mission)
  self.vehicleCamera:load()

  -- load settings and vehicles
  self:load()

  -- load gui and hud
  self.gui:load()
  self.hud:load()
end

---Called when connection to server is finished loading
-- @param connection table the connection instance
function MouseSteering:onConnectionFinishedLoading(connection)
  connection:sendEvent(MouseSteeringConnectToServerEvent.new())
end

---Draws HUD elements
function MouseSteering:draw()
  local isNotMenuVisible = not self.mission.hud.isMenuVisible

  if self.isClient and isNotMenuVisible and not g_noHudModeEnabled then
    self.hud:drawControlledEntityHUD()
  end
end

---Called on client side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteering:readStream(streamId, connection)
  local numVehicleSells = streamReadUInt8(streamId)
  self.vehicleSells = {}

  -- read vehicle sells from stream
  for _ = 1, numVehicleSells do
    local vehicleUniqueId = streamReadString(streamId)
    local farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self:addSoldVehicle(vehicleUniqueId, farmId)
  end

  -- cleanup if limit exceeded after loading from stream
  self:cleanupVehicleSellsIfNeeded()
end

---Called on server side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteering:writeStream(streamId, connection)
  local numVehicleSells = 0
  for _ in pairs(self.vehicleSells) do
    numVehicleSells = numVehicleSells + 1
  end

  streamWriteUInt8(streamId, numVehicleSells)

  -- write vehicle sells to stream
  for vehicleUniqueId, farmId in pairs(self.vehicleSells) do
    streamWriteString(streamId, vehicleUniqueId)
    streamWriteUIntN(streamId, farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
  end
end

---Called on update
-- @param dt number delta time
function MouseSteering:update(dt)
  self.hud:update(dt)
end

---Gets the base settings directory for current game mode
-- @return string the settings directory path
function MouseSteering:getModeSettingsDir()
  local slug = (self.isClient and not self.isServer) and "multiplayer" or "singleplayer"
  return self.modSettingsDirectory .. slug .. "/"
end

---Gets file path for map-specific data
-- @param file string the filename without extension
-- @return string the full file path
function MouseSteering:getMapFilePath(file)
  local missionInfo = self.mission.missionInfo
  local mapId = (missionInfo.mapId or "unknown_map"):gsub("[^%w_-]", "_")
  local baseDir = self:getModeSettingsDir()
  local mapDir = baseDir .. "maps/" .. mapId .. "/"

  -- create map directory
  createFolder(baseDir .. "maps/")
  createFolder(mapDir)

  return mapDir .. file .. ".xml"
end

---Loads config file or copies from default
-- @param file string the filename without extension
-- @param defaultPath string the default file path to copy from
-- @return string the path to the config file
function MouseSteering:loadConfigFile(file, defaultPath)
  local baseDir = self:getModeSettingsDir()
  local path = baseDir .. file .. ".xml"

  -- create base directory
  createFolder(baseDir)
  copyFile(defaultPath, path, false)

  -- check if file exists
  if not fileExists(path) then
    path = defaultPath
  end

  return path
end

---Loads user settings from XML file
-- @return boolean true if settings loaded successfully
function MouseSteering:loadSettingsFromXMLFile()
  local xmlFilename = self:loadConfigFile("settings", Utils.getFilename("data/settings.xml", self.modDirectory))
  local xmlFile = XMLFile.loadIfExists("MouseSteeringXML", xmlFilename)

  if xmlFile == nil then
    Logging.error(string.format("MouseSteering: Failed to load settings at path (%s)!", xmlFilename))

    return false
  end

  -- reset settings if missing revision or outdated
  local fileRevision = xmlFile:getInt("settings#revision") or 1
  local currentRevision = MouseSteering.CURRENT_REVISION

  if fileRevision < currentRevision then
    self:reset()
  end

  -- load and process settings
  local settings = self.settings
  local numChildren = xmlFile:getNumOfChildren("settings")

  for i = 0, numChildren - 1 do
    local name = xmlFile:getElementName(string.format("settings.*(%d)", i))
    local key = string.format("settings.%s", name)

    local value = xmlFile:getFloat(key)
    if value == nil then
      value = xmlFile:getBool(key)
    end
    if value == nil then
      value = xmlFile:getString(key)
    end

    if value ~= nil and name ~= nil then
      -- round float values to avoid rounding errors
      if type(value) == "number" then
        value = math.floor(value * 10000 + 0.5) / 10000
      end

      settings[name] = value
    end
  end

  xmlFile:delete()

  return true
end

---Saves settings to XML file
function MouseSteering:saveSettingsToXMLFile()
  local xmlFile = XMLFile.create("MouseSteeringXML", self:getModeSettingsDir() .. "settings.xml", "settings")

  if xmlFile == nil then
    Logging.error("Mouse Steering: Something went wrong while trying to save settings!")
    return
  end

  -- set the revision number for the settings file
  xmlFile:setInt("settings#revision", MouseSteering.CURRENT_REVISION)

  for name, value in pairs(self.settings) do
    local key = string.format("settings.%s", name)

    if type(value) == "boolean" then
      xmlFile:setBool(key, value)
    elseif type(value) == "number" then
      -- round float value before saving to avoid rounding errors
      local roundedValue = math.floor(value * 1000000 + 0.5) / 1000000
      xmlFile:setFloat(key, roundedValue)
    else
      xmlFile:setString(key, value)
    end
  end

  xmlFile:save()
  xmlFile:delete()
end

---Resets settings to defaults
function MouseSteering:reset()
  local baseDir = self:getModeSettingsDir()
  local path = baseDir .. "settings.xml"

  createFolder(baseDir)
  copyFile(Utils.getFilename("data/settings.xml", self.modDirectory), path, true)

  self:loadSettingsFromXMLFile()
end

---Loads vehicle configuration from XML file
function MouseSteering:loadVehicleFromXMLFile()
  local vehiclesPath = self:getMapFilePath("vehicles")
  local xmlFile = XMLFile.loadIfExists("MouseSteeringStoreXML", vehiclesPath, "vehicles")

  if xmlFile == nil then
    return
  end

  xmlFile:iterate("vehicles.vehicle", function(_, key)
    local uniqueId = xmlFile:getString(key .. "#uniqueId")

    if uniqueId ~= nil then
      local createdAt = xmlFile:getString(key .. "#createdAt")
      local farmId = xmlFile:getInt(key .. "#farmId")

      -- add vehicle to tracked list
      self.vehicles[uniqueId] = {
        createdAt = createdAt,
        farmId = farmId,
      }
    end
  end)

  xmlFile:delete()
end

---Saves vehicle configuration to XML file
function MouseSteering:saveVehicleToXMLFile()
  local vehiclesPath = self:getMapFilePath("vehicles")
  local xmlFile = XMLFile.create("MouseSteeringStoreXML", vehiclesPath, "vehicles")

  if xmlFile == nil then
    Logging.error(string.format("Mouse Steering: Failed to create vehicles XML file at '%s'.", vehiclesPath))
    return
  end

  local i = 0
  for uniqueId, data in pairs(self.vehicles) do
    local key = ("vehicles.vehicle(%d)"):format(i)

    xmlFile:setString(key .. "#uniqueId", uniqueId)
    xmlFile:setString(key .. "#createdAt", data.createdAt or "")
    xmlFile:setInt(key .. "#farmId", data.farmId)

    i = i + 1
  end

  xmlFile:save()
  xmlFile:delete()
end

---Adds vehicle to tracked list
-- @param param table|string the vehicle object or vehicle key
-- @return boolean true if vehicle was added successfully
function MouseSteering:addVehicle(param)
  local vehicleKey = self:getVehicleKey(param)

  if vehicleKey ~= nil and self.vehicles[vehicleKey] == nil then
    -- check if max vehicles reached before adding the vehicle
    if self:isMaxVehiclesReached() then
      self.mission:showBlinkingWarning(g_i18n:getText("mouseSteering_warning_vehicleLimit"), 2000)

      return false
    end

    -- get current date and farm id
    local createdAt = getDate("%Y-%m-%d %H:%M:%S")
    local farmId = g_localPlayer.farmId

    -- add vehicle to tracked list
    self.vehicles[vehicleKey] = {
      createdAt = createdAt,
      farmId = farmId,
    }

    -- notify all listeners that a vehicle was added
    g_messageCenter:publish(MouseSteeringMessageType.VEHICLE_TOGGLE, param)

    return true
  end

  return false
end

---Removes vehicle from tracked list
-- @param param table|string the vehicle object or vehicle key
-- @return boolean true if vehicle was removed successfully
function MouseSteering:removeVehicle(param)
  local vehicleKey = self:getVehicleKey(param)

  if vehicleKey ~= nil and self.vehicles[vehicleKey] ~= nil then
    self.vehicles[vehicleKey] = nil

    -- notify all listeners that a vehicle was removed
    g_messageCenter:publish(MouseSteeringMessageType.VEHICLE_TOGGLE, param)

    return true
  end

  return false
end

---Gets vehicle key from vehicle object or string
-- @param param table|string the vehicle object or vehicle key
-- @return string|nil the vehicle key or nil if invalid
function MouseSteering:getVehicleKey(param)
  if type(param) == "table" and param.getMouseSteeringUniqueId ~= nil then
    return param:getMouseSteeringUniqueId()
  elseif type(param) == "string" then
    return param
  end

  return nil
end

---Checks if vehicle is saved
-- @param vehicle table|string the vehicle object or vehicle key
-- @return boolean true if vehicle is saved
function MouseSteering:isVehicleSaved(vehicle)
  local vehicleKey = self:getVehicleKey(vehicle)
  return self.vehicles[vehicleKey] ~= nil
end

---Checks if maximum number of vehicles has been reached
-- @return boolean true if maximum vehicles reached
function MouseSteering:isMaxVehiclesReached()
  return self:getVehicleCount() >= self.MAX_VEHICLES
end

---Gets the number of tracked vehicles
-- @return number number of tracked vehicles
function MouseSteering:getVehicleCount()
  local count = 0

  for _ in pairs(self.vehicles) do
    count = count + 1
  end

  return count
end

---Gets all tracked vehicles
-- @return table table of tracked vehicles
function MouseSteering:getVehicles()
  return self.vehicles
end

---Synchronizes saved vehicles with current farm vehicles
-- @return number number of vehicles that were removed during sync
function MouseSteering:syncVehicles()
  if g_localPlayer == nil then
    return 0
  end

  local playerFarmId = g_localPlayer.farmId
  local savedVehicles = self:getVehicles()
  local removedCount = 0

  -- get current vehicles owned by the player's farm
  local currentFarmVehicles = self:getCurrentFarmVehicles(playerFarmId)

  -- process orphaned vehicles in one pass
  for vehicleKey in pairs(savedVehicles) do
    local vehicle = currentFarmVehicles[vehicleKey]

    -- vehicle is orphaned if it doesn't exist or is owned by a different farm
    if vehicle == nil or vehicle:getOwnerFarmId() ~= playerFarmId then
      if self:removeVehicle(vehicleKey) then
        -- if we're a client and the vehicle isn't already marked as sold, add it to vehicle sells
        if not self.isServer and not self:isVehicleSold(vehicleKey) then
          self:addSoldVehicle(vehicleKey, playerFarmId)
        end
        removedCount = removedCount + 1
      end
    end
  end

  return removedCount
end

---Gets all current vehicles owned by a specific farm
-- @param farmId number the farm id to get vehicles for
-- @return table lookup table of current farm vehicles (vehicleKey -> vehicle)
function MouseSteering:getCurrentFarmVehicles(farmId)
  assert(farmId ~= nil, "FarmId cannot be nil")

  local currentFarmVehicles = {}

  for _, vehicle in ipairs(self.mission.vehicleSystem.vehicles) do
    if vehicle:getOwnerFarmId() == farmId and vehicle.getMouseSteeringUniqueId ~= nil then
      currentFarmVehicles[vehicle:getMouseSteeringUniqueId()] = vehicle
    end
  end

  return currentFarmVehicles
end

---Gets the last saved time for a vehicle
-- @param vehicle table|string the vehicle object or vehicle key
-- @return string|nil the last saved time or nil if not found
function MouseSteering:getLastSavedTime(vehicle)
  local vehicleKey = self:getVehicleKey(vehicle)
  local data = self.vehicles[vehicleKey]
  return data and data.createdAt or nil
end

---Sets the currently controlled vehicle
-- @param vehicle table the vehicle object
function MouseSteering:setControlledVehicle(vehicle)
  self.hud:setControlledVehicle(vehicle, true)
end

---Shows a notification to the user
-- @param textKey string the i18n text key
-- @param ... any additional arguments for formatting
function MouseSteering:showNotification(textKey, ...)
  local config = {
    type = FSBaseMission.INGAME_NOTIFICATION_INFO,
    duration = MouseSteering.NOTIFICATION_DURATION,
    sound = GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION,
  }

  local text = self.i18n:getText(textKey):format(...)
  self.mission.hud:addSideNotification(config.type, text, config.duration, config.sound)
end

---Checks if HUD is currently visible
-- @return boolean true if HUD is visible
function MouseSteering:getHudVisible()
  return self.hud:getHudVisible()
end

---Sets indicator text visibility
-- @param visible boolean true to show indicator text
function MouseSteering:setIndicatorTextVisible(visible)
  self.hud:setTextVisible(visible)
end

---Gets the current mouse movement side value
-- @return number the moved side value
function MouseSteering:getMovedSide()
  return self.vehicleCamera:getMovedSide()
end

---Ensures vehicle sells table doesn't exceed the maximum limit
-- Removes oldest entries if limit is reached using existing class methods
function MouseSteering:cleanupVehicleSellsIfNeeded()
  local maxAllowedEntries = MouseSteering.MAX_VEHICLE_SELLS
  local allSoldVehicles = self:getSoldVehicles()
  local currentEntryCount = self:getVehicleSellsCount(allSoldVehicles)

  -- check if cleanup is needed
  if currentEntryCount < maxAllowedEntries then
    return -- no cleanup needed
  end

  -- calculate how many entries to remove
  local entriesToRemove = currentEntryCount - maxAllowedEntries + 1
  local vehiclesToRemove = self:selectVehiclesToRemove(allSoldVehicles, entriesToRemove)

  -- remove the selected vehicles
  self:removeVehicleSellEntries(vehiclesToRemove)
end

---Counts the number of entries in the sold vehicles table
-- @param soldVehicles table the sold vehicles lookup table
-- @return number count of sold vehicle entries
function MouseSteering:getVehicleSellsCount(soldVehicles)
  local count = 0
  for _ in pairs(soldVehicles) do
    count = count + 1
  end
  return count
end

---Selects which vehicles to remove based on FIFO strategy
-- @param soldVehicles table all sold vehicles
-- @param maxToRemove number maximum number of vehicles to select for removal
-- @return table list of vehicle IDs to remove
function MouseSteering:selectVehiclesToRemove(soldVehicles, maxToRemove)
  local vehiclesToRemove = {}
  local selectedCount = 0

  for vehicleId, _ in pairs(soldVehicles) do
    -- verify vehicle is still marked as sold (safety check)
    if self:isVehicleSold(vehicleId) then
      table.insert(vehiclesToRemove, vehicleId)
      selectedCount = selectedCount + 1

      -- stop when we have enough vehicles to remove
      if selectedCount >= maxToRemove then
        break
      end
    end
  end

  return vehiclesToRemove
end

---Removes the specified vehicle sell entries
-- @param vehicleIds table list of vehicle IDs to remove
-- @return number actual number of entries removed
function MouseSteering:removeVehicleSellEntries(vehicleIds)
  local removedCount = 0

  for _, vehicleId in ipairs(vehicleIds) do
    if self:removeSoldVehicle(vehicleId) then
      removedCount = removedCount + 1
    end
  end

  return removedCount
end

---Adds vehicle to sold vehicles tracking
-- @param vehicleUniqueId string unique identifier of the sold vehicle
-- @param farmId number the farm id that sold the vehicle
-- @param forceRemove boolean|nil optional parameter to force vehicle removal from self.vehicles
function MouseSteering:addSoldVehicle(vehicleUniqueId, farmId, forceRemove)
  assert(vehicleUniqueId ~= nil, "VehicleUniqueId cannot be nil")
  assert(farmId ~= nil, "FarmId cannot be nil")

  -- prevent duplicate processing - check if already sold (but allow force remove)
  if self:isVehicleSold(vehicleUniqueId) and not forceRemove then
    return -- already processed, skip
  end

  -- mark vehicle as sold
  self.vehicleSells[vehicleUniqueId] = farmId

  -- remove from saved vehicles if it exists
  if self.vehicles[vehicleUniqueId] ~= nil then
    self.vehicles[vehicleUniqueId] = nil
    self:saveVehicleToXMLFile()
  end

  -- cleanup old entries if limit exceeded
  self:cleanupVehicleSellsIfNeeded()

  -- broadcast to other clients if we're the server
  if self.isServer then
    g_server:broadcastEvent(MouseSteeringVehicleSoldEvent.new(vehicleUniqueId, farmId), false)
  end
end

---Removes vehicle from sold vehicles tracking
-- @param vehicleUniqueId string unique identifier of the vehicle to remove
-- @return boolean true if the vehicle was removed, false otherwise
function MouseSteering:removeSoldVehicle(vehicleUniqueId)
  assert(vehicleUniqueId ~= nil, "VehicleUniqueId cannot be nil")

  if self:isVehicleSold(vehicleUniqueId) then
    self.vehicleSells[vehicleUniqueId] = nil
    return true
  end

  return false
end

---Checks if vehicle has been sold
-- @param vehicleUniqueId string unique identifier of the vehicle to check
-- @param farmId number|nil optional farm id to check against
-- @return boolean true if the vehicle is sold (and matches farmId if specified)
function MouseSteering:isVehicleSold(vehicleUniqueId, farmId)
  assert(vehicleUniqueId ~= nil, "VehicleUniqueId cannot be nil")

  local soldFarmId = self.vehicleSells[vehicleUniqueId]

  if soldFarmId == nil then
    return false
  end

  -- if farmId is specified, check if it matches the sold farm
  if farmId ~= nil then
    return soldFarmId == farmId
  end

  return true
end

---Gets all sold vehicles
-- @return table table of sold vehicles (vehicleUniqueId -> farmId)
function MouseSteering:getSoldVehicles()
  return self.vehicleSells
end

---Gets sold vehicles for specific farm
-- @param farmId number the farm id to get sold vehicles for
-- @return table table of sold vehicles for the specified farm (vehicleUniqueId -> true)
function MouseSteering:getSoldVehiclesForFarm(farmId)
  assert(farmId ~= nil, "FarmId cannot be nil")

  local soldVehicles = {}

  for vehicleUniqueId, soldFarmId in pairs(self.vehicleSells) do
    if soldFarmId == farmId then
      soldVehicles[vehicleUniqueId] = true
    end
  end

  return soldVehicles
end

---Called on vehicle sold network message
-- @param vehicleUniqueId string unique identifier of the sold vehicle
-- @param farmId number the farm id that sold the vehicle
function MouseSteering:onVehicleSoldNetworkMessage(vehicleUniqueId, farmId)
  -- process vehicle sold notification from network
  self:addSoldVehicle(vehicleUniqueId, farmId, true)
end

---Called on direct vehicle sell
-- @param vehicle table the vehicle being sold
-- @param isDirectSell boolean whether this was a direct sell
function MouseSteering:onVehicleSellDirect(vehicle, isDirectSell)
  if vehicle ~= nil and vehicle.getMouseSteeringUniqueId ~= nil then
    local vehicleUniqueId = vehicle:getMouseSteeringUniqueId()
    local ownerFarmId = vehicle:getOwnerFarmId()

    if vehicleUniqueId ~= nil and ownerFarmId ~= nil then
      -- add to sold vehicles tracking immediately
      self:addSoldVehicle(vehicleUniqueId, ownerFarmId)

      -- if we're a client, send event to server so others update their lists too
      if not self.isServer then
        g_client:getServerConnection():sendEvent(MouseSteeringVehicleSoldEvent.new(vehicleUniqueId, ownerFarmId))
      end
    end
  end
end
