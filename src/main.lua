--
-- Main
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

---Directory where the currently loaded mod resides
local modDirectory = g_currentModDirectory or ""
---Directory where the settings of the currently loaded mod resides
local modSettingsDirectory = g_currentModSettingsDirectory or ""
---Name of the currently loaded mod
local modName = g_currentModName or "unknown"
---Environment associated with the currently loaded mod
local modEnvironment

---List of files to be loaded
local sourceFiles = {
  --events
  "src/events/MouseSteeringConnectToServerEvent.lua",
  "src/events/MouseSteeringVehicleSoldEvent.lua",
  "src/events/SetMouseSteeringSpeedControlStateEvent.lua",
  -- gui
  "src/gui/dialogs/MouseSteeringSettingsDialog.lua",
  "src/gui/elements/MouseSteeringMultiTextOptionElement.lua",
  "src/gui/elements/MouseSteeringSliderOptionElement.lua",
  "src/gui/InGameMenuSettingsFrameExtension.lua",
  "src/gui/MouseSteeringGui.lua",
  -- hud
  "src/hud/MouseSteeringHud.lua",
  "src/hud/MouseSteeringIndicatorDisplay.lua",
  "src/hud/SpeedMeterDisplayExtension.lua",
  -- misc
  "src/misc/AdditionalSpecialization.lua",
  "src/misc/MouseSteeringCameraRotation.lua",
  "src/misc/MouseSteeringController.lua",
  "src/misc/MouseSteeringInputController.lua",
  "src/misc/MouseSteeringMessageTypes.lua",
  "src/misc/VehicleCameraExtension.lua",
  -- main
  "src/MouseSteering.lua",
}

---Load the mod's source files
for _, file in ipairs(sourceFiles) do
  source(modDirectory .. file)
end

---Check if the mod is loaded
local function isLoaded()
  return modEnvironment ~= nil and g_modIsLoaded[modName]
end

---Load the mod
local function load(mission)
  assert(modEnvironment == nil)

  modEnvironment = MouseSteering.new(modName, modDirectory, modSettingsDirectory, mission, g_i18n, g_gui)
  mission.mouseSteering = modEnvironment
  addModEventListener(modEnvironment)
end

---Called when the mission is loaded
local function loadedMission(mission, node)
  if not isLoaded() then
    return
  end

  if mission.cancelLoading then
    return
  end

  modEnvironment:onMissionLoaded(mission)
end

---Unload the mod
local function unload()
  if not isLoaded() then
    return
  end

  if modEnvironment ~= nil then
    modEnvironment:delete()
    modEnvironment = nil

    if g_currentMission ~= nil then
      g_currentMission.mouseSteering = nil
    end
  end
end

---Called when connection loading is finished
local function onConnectionFinishedLoading(mission, superFunc, connection, ...)
  superFunc(mission, connection, ...)

  if modEnvironment ~= nil then
    modEnvironment:onConnectionFinishedLoading(connection)
  end
end

---Records a vehicle only after the server authoritatively completes its sale
local function sellVehicleEventRun(event, superFunc, connection, ...)
  local saleContext

  if connection ~= nil and not connection:getIsServer() and modEnvironment ~= nil and modEnvironment.isServer then
    local vehicle = event.vehicle

    if vehicle ~= nil and vehicle.getMouseSteeringUniqueId ~= nil and vehicle.getOwnerFarmId ~= nil and vehicle.getIsBeingDeleted ~= nil then
      saleContext = {
        mouseSteering = modEnvironment,
        vehicle = vehicle,
        uniqueId = vehicle:getMouseSteeringUniqueId(),
        ownerFarmId = vehicle:getOwnerFarmId(),
        wasBeingDeleted = vehicle:getIsBeingDeleted(),
      }
    end
  end

  local result = superFunc(event, connection, ...)

  if saleContext ~= nil and modEnvironment == saleContext.mouseSteering and not saleContext.wasBeingDeleted and saleContext.vehicle:getIsBeingDeleted() and not string.isNilOrWhitespace(saleContext.uniqueId) and saleContext.ownerFarmId ~= nil then
    saleContext.mouseSteering:onVehicleSold(saleContext.uniqueId, saleContext.ownerFarmId)
  end

  return result
end

---Called when drawing vehicle name in HUD
local function hudDrawVehicleName(hud, superFunc, ...)
  if modEnvironment ~= nil and modEnvironment:getHudVisible() then
    return
  end

  return superFunc(hud, ...)
end

-- Init the mod
local function init()
  FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
  Mission00.load = Utils.prependedFunction(Mission00.load, load)
  Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
  FSBaseMission.onConnectionFinishedLoading = Utils.overwrittenFunction(FSBaseMission.onConnectionFinishedLoading, onConnectionFinishedLoading)
  TypeManager.finalizeTypes = Utils.appendedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)

  SellVehicleEvent.run = Utils.overwrittenFunction(SellVehicleEvent.run, sellVehicleEventRun)
  HUD.drawVehicleName = Utils.overwrittenFunction(HUD.drawVehicleName, hudDrawVehicleName)
end

-- Load the mod
init()
