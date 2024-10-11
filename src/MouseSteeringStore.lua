--
-- MouseSteeringStore
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringStore = {
  MAX_VEHICLES = 100,
}

local MouseSteeringStore_mt = Class(MouseSteeringStore)

function MouseSteeringStore.new(customMt)
  local self = setmetatable({}, customMt or MouseSteeringStore_mt)

  self.vehicles = {}

  return self
end

function MouseSteeringStore:loadFromXMLFile(path)
  local xmlFile = XMLFile.loadIfExists("MouseSteeringStoreXML", path, "vehicles")

  if xmlFile == nil then
    return
  end

  xmlFile:iterate("vehicles.vehicle", function(_, key)
    local id = xmlFile:getString(key .. "#id")
    local xmlFilename = xmlFile:getString(key .. "#xmlFilename")

    if id ~= nil and xmlFilename ~= nil then
      local vehicleKey = id .. ":" .. xmlFilename

      self.vehicles[vehicleKey] = true
    end
  end)

  xmlFile:delete()
end

function MouseSteeringStore:saveToXMLFile(path)
  local xmlFile = XMLFile.create("MouseSteeringStoreXML", path, "vehicles")

  if xmlFile == nil then
    Logging.error("MouseSteeringStore: Failed to save vehicles to path: %s", path)

    return
  end

  local i = 0

  for vehicleKey in pairs(self.vehicles) do
    local id, xmlFilename = vehicleKey:match("([^:]+):(.+)")

    if id ~= nil and xmlFilename ~= nil then
      local key = string.format("vehicles.vehicle(%d)", i)

      xmlFile:setString(key .. "#id", id)
      xmlFile:setString(key .. "#xmlFilename", xmlFilename)

      i = i + 1
    end
  end

  xmlFile:save()
  xmlFile:delete()
end

function MouseSteeringStore:addVehicle(param)
  local vehicleKey = type(param) == "table" and self:getVehicleKey(param) or param

  if self.vehicles[vehicleKey] == nil and not self:isMaxVehiclesReached() then
    self.vehicles[vehicleKey] = true

    return true
  end

  return false
end

function MouseSteeringStore:removeVehicle(param)
  local vehicleKey = type(param) == "table" and self:getVehicleKey(param) or param

  if self.vehicles[vehicleKey] ~= nil then
    self.vehicles[vehicleKey] = nil

    return true
  end

  return false
end

function MouseSteeringStore:isVehicleSaved(vehicle)
  local vehicleKey = self:getVehicleKey(vehicle)
  return self.vehicles[vehicleKey] ~= nil
end

function MouseSteeringStore:isMaxVehiclesReached()
  return self:getVehicleCount() >= self.MAX_VEHICLES
end

function MouseSteeringStore:getVehicleKey(vehicle)
  local vehicleId = vehicle:getVehicleId()
  local configFileName = vehicle.configFileName

  return vehicleId .. ":" .. configFileName
end

function MouseSteeringStore:getVehicleCount()
  local count = 0

  for _ in pairs(self.vehicles) do
    count = count + 1
  end

  return count
end

function MouseSteeringStore:getVehicles()
  return self.vehicles
end

function MouseSteeringStore:clearVehicles()
  self.vehicles = {}
end
