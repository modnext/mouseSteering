--
-- MouseSteeringGui
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringGui = {}

local MouseSteeringGui_mt = Class(MouseSteeringGui)

function MouseSteeringGui.new(customMt, modDirectory, mission, gui, i18n)
  local self = setmetatable({}, customMt or MouseSteeringGui_mt)

  self.gui = gui
  self.modDirectory = modDirectory

  -- Registers the gui elements that should be accessible via script
  self.mouseSteeringMenu = MouseSteeringMenu.new(nil, customMt, gui, i18n)
  self.mouseSteeringVehiclesDialog = MouseSteeringVehiclesDialog.new(nil, customMt, gui, i18n)
  self.inGameMenuGeneralSettingsFrameExtension = InGameMenuGeneralSettingsFrameExtension.new(customMt, mission, gui, i18n)

  return self
end

function MouseSteeringGui:load()
  self:setupConfiguration()
  self:loadProfiles()
  self:loadGui()

  self.inGameMenuGeneralSettingsFrameExtension:load()
end

function MouseSteeringGui:setupConfiguration()
  local mapping = Gui.CONFIGURATION_CLASS_MAPPING
  local element = Gui.ELEMENT_PROCESSING_FUNCTIONS

  mapping.mouseSteeringSlider = MouseSteeringSliderElement
  element.mouseSteeringSlider = Gui.assignPlaySampleCallback
end

function MouseSteeringGui:setNewFilename(filename)
  local path = "data/gui/images/gui_elements.png"
  local uiFilename = "g_mouseSteeringUIFilename"

  if filename == uiFilename or (filename and filename:sub(1, 5) == "data/") then
    local fileToUse = filename == uiFilename and path or filename

    return Utils.getFilename(fileToUse, self.modDirectory)
  end

  return filename
end

function MouseSteeringGui:loadProfiles()
  local profilesPath = Utils.getFilename("data/gui/guiProfiles.xml", self.modDirectory)
  self.gui:loadProfiles(profilesPath)

  for _, profile in pairs(self.gui.profiles) do
    local values = profile.values

    values.imageFilename = self:setNewFilename(values.imageFilename)
    values.iconFilename = self:setNewFilename(values.iconFilename)
    values.videoFilename = self:setNewFilename(values.videoFilename)
  end
end

function MouseSteeringGui:loadGui()
  local menuXmlPath = Utils.getFilename("data/gui/MouseSteeringMenu.xml", self.modDirectory)
  self.gui:loadGui(menuXmlPath, "MouseSteeringMenu", self.mouseSteeringMenu)

  local vehiclesXmlPath = Utils.getFilename("data/gui/dialogs/MouseSteeringVehiclesDialog.xml", self.modDirectory)
  self.gui:loadGui(vehiclesXmlPath, "MouseSteeringVehiclesDialog", self.mouseSteeringVehiclesDialog)
end

function MouseSteeringGui:showVehiclesDialog(args)
  local dialog = self.gui:showDialog("MouseSteeringVehiclesDialog")

  if dialog ~= nil and args ~= nil then
    dialog.target:setCallback(args.callback, args.target, args.args)
  end
end
