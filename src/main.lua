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
  -- gui
  "src/gui/dialogs/MouseSteeringSettingsDialog.lua",
  "src/gui/elements/MouseSteeringMultiTextOptionElement.lua",
  "src/gui/elements/MouseSteeringSliderOptionElement.lua",
  "src/gui/InGameMenuSettingsFrameExtension.lua",
  "src/gui/MouseSteeringGui.lua",
  -- hud
  "src/hud/MouseSteeringHud.lua",
  "src/hud/MouseSteeringIndicatorDisplay.lua",
  -- misc
  "src/misc/AdditionalSpecialization.lua",
  "src/misc/MouseSteeringCameraRotation.lua",
  "src/misc/MouseSteeringController.lua",
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
local function onConnectionFinishedLoading(mission, superFunc, connection, x, y, z, viewDistanceCoeff)
  if not isLoaded() then
    return superFunc(mission, connection, x, y, z, viewDistanceCoeff)
  end

  superFunc(mission, connection, x, y, z, viewDistanceCoeff)
  modEnvironment:onConnectionFinishedLoading(connection)
end

---Called when vehicle is sold in shop
local function shopControllerSellVehicle(shopController, superFunc, vehicle, isDirectSell)
  if g_currentMission ~= nil and g_currentMission.mouseSteering ~= nil then
    g_currentMission.mouseSteering:onVehicleSellDirect(vehicle, isDirectSell)
  end

  return superFunc(shopController, vehicle, isDirectSell)
end

---Called when drawing vehicle name in HUD
local function hudDrawVehicleName(hud, superFunc)
  local isMouseSteering = g_currentMission.mouseSteering ~= nil and g_currentMission.mouseSteering:getHudVisible()

  if isMouseSteering then
    return
  end

  return superFunc(hud)
end

-- Init the mod
local function init()
  FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
  Mission00.load = Utils.prependedFunction(Mission00.load, load)
  Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
  FSBaseMission.onConnectionFinishedLoading = Utils.overwrittenFunction(FSBaseMission.onConnectionFinishedLoading, onConnectionFinishedLoading)
  TypeManager.finalizeTypes = Utils.appendedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)

  ShopController.sellVehicle = Utils.overwrittenFunction(ShopController.sellVehicle, shopControllerSellVehicle)
  HUD.drawVehicleName = Utils.overwrittenFunction(HUD.drawVehicleName, hudDrawVehicleName)
end

-- Load the mod
init()
