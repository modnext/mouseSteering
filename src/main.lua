--
-- Main
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- Directory where the currently loaded mod resides
local modDirectory = g_currentModDirectory or ""
-- Directory where the settings of the currently loaded mod resides
local modSettingsDirectory = g_currentModSettingsDirectory or ""
-- Name of the currently loaded mod
local modName = g_currentModName or "unknown"
-- Environment associated with the currently loaded mod
local modEnvironment

-- List of files to be loaded
local sourceFiles = {
  -- Misc
  "src/misc/AdditionalSpecialization.lua",
  "src/misc/VehicleCameraExtension.lua",
  -- Gui
  "src/gui/MouseSteeringGui.lua",
  "src/gui/MouseSteeringMenu.lua",
  "src/gui/InGameMenuGeneralSettingsFrameExtension.lua",
  "src/gui/elements/MouseSteeringSliderElement.lua",
  "src/gui/dialogs/MouseSteeringVehiclesDialog.lua",
  -- Hud
  "src/gui/hud/MouseSteeringHud.lua",
  "src/gui/hud/MouseSteeringDisplay.lua",
  "src/gui/hud/HUDExtension.lua",
  -- Main
  "src/MouseSteeringStore.lua",
  "src/MouseSteering.lua",
}

-- Load the mod's source files
for _, file in ipairs(sourceFiles) do
  source(modDirectory .. file)
end

-- Check if the mod is loaded
local function isLoaded()
  return modEnvironment ~= nil and g_modIsLoaded[modName]
end

-- Load the mod
local function load(mission)
  assert(modEnvironment == nil)

  modEnvironment = MouseSteering.new(modName, modDirectory, modSettingsDirectory, mission, g_i18n, g_gui)
  mission.mouseSteering = modEnvironment
  addModEventListener(modEnvironment)
end

-- Called when the mission is loaded
local function loadedMission(mission, node)
  if not isLoaded() then
    return
  end

  if mission.cancelLoading then
    return
  end

  modEnvironment:onMissionLoaded(mission)
end

-- Unload the mod
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

-- Init the mod
local function init()
  FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

  Mission00.load = Utils.prependedFunction(Mission00.load, load)
  Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)

  TypeManager.finalizeTypes = Utils.appendedFunction(TypeManager.finalizeTypes, AdditionalSpecialization.finalizeTypes)
end

-- Load the mod
init()
