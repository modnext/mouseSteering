--
-- MouseSteeringGui
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringGui = {}

local MouseSteeringGui_mt = Class(MouseSteeringGui)

---Creates a new instance of MouseSteeringGui
function MouseSteeringGui.new(customMt, modDirectory, mission, gui, i18n)
  local self = setmetatable({}, customMt or MouseSteeringGui_mt)

  self.gui = gui
  self.modDirectory = modDirectory

  -- setup texture configuration for the mod
  self:setupTextureConfig()

  -- initialize GUI components
  self.mouseSteeringSettingsDialog = MouseSteeringSettingsDialog.new(nil, customMt, gui, i18n)
  self.inGameMenuSettingsFrameExtension = InGameMenuSettingsFrameExtension.new(customMt, mission, gui, i18n)

  return self
end

---Sets up GUI texture config
function MouseSteeringGui:setupTextureConfig()
  local guiPath = Utils.getFilename("data/gui/gui.xml", self.modDirectory)
  g_overlayManager:addTextureConfigFile(guiPath, "mouseSteering")
end

---Loads GUI components
function MouseSteeringGui:load()
  -- register custom GUI elements for mouse steering settings
  Gui.registerGuiElement("MouseSteeringSliderOption", MouseSteeringSliderOptionElement)
  Gui.registerGuiElementProcFunction("MouseSteeringSliderOption", Gui.assignPlaySampleCallback)

  Gui.registerGuiElement("MouseSteeringMultiTextOption", MouseSteeringMultiTextOptionElement)
  Gui.registerGuiElementProcFunction("MouseSteeringMultiTextOption", Gui.assignPlaySampleCallback)

  -- load GUI profiles configuration
  local profilesPath = Utils.getFilename("data/gui/guiProfiles.xml", self.modDirectory)
  self.gui:loadProfiles(profilesPath)

  -- load the main settings dialog GUI
  local settingModeXmlPath = Utils.getFilename("data/gui/dialogs/MouseSteeringSettingsDialog.xml", self.modDirectory)
  self.gui:loadGui(settingModeXmlPath, "MouseSteeringSettingsDialog", self.mouseSteeringSettingsDialog)

  -- store reference to the dialog instance
  MouseSteeringSettingsDialog.INSTANCE = self.mouseSteeringSettingsDialog

  -- load the in-game menu settings frame extension
  self.inGameMenuSettingsFrameExtension:load()
end
