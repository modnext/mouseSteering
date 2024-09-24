--
-- MouseSteeringMenu
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringMenu = {}

local MouseSteeringMenu_mt = Class(MouseSteeringMenu, ScreenElement)

MouseSteeringMenu.CONTROLS = {
  "background",
  "boxLayout",
  "version",
  "sensitivity",
  "linearity",
  "smoothness",
  "vehicleCountDisplay",
  "autoSaveVehicle",
  "invertXAxis",
  "deadzone",
  "hud",
  "hudText",
  "hudLookBackInside",
}

function MouseSteeringMenu.new(target, customMt, gui, i18n)
  local self = MouseSteeringMenu:superClass().new(target, customMt or MouseSteeringMenu_mt)

  self.gui = gui
  self.i18n = i18n

  -- registers the gui elements that should be accessible via script
  self:registerControls(MouseSteeringMenu.CONTROLS)

  return self
end

function MouseSteeringMenu:delete()
  MouseSteeringMenu:superClass().delete(self)
end

function MouseSteeringMenu.createFromExistingGui(gui, guiName)
  local newGui = MouseSteeringMenu.new(nil, nil, gui.gui, gui.i18n)

  g_gui.guis[gui.name].target:delete()
  g_gui.guis[gui.name]:delete()

  g_gui:loadGui(gui.xmlFilename, guiName, newGui)

  return newGui
end

function MouseSteeringMenu:copyAttributes(src)
  MouseSteeringMenu:superClass().copyAttributes(self, src)

  self.gui = src.gui
  self.i18n = src.i18n
end

function MouseSteeringMenu:setBlurApplied(blurApplied)
  if blurApplied then
    local x, y = self.background.absPosition[1], self.background.absPosition[2]
    local width, height = self.background.absSize[1], self.background.absSize[2]

    g_depthOfFieldManager:pushArea(x, y, width, height)
  else
    g_depthOfFieldManager:popArea()
  end

  self.blurApplied = blurApplied
end

function MouseSteeringMenu:onOpen()
  MouseSteeringMenu:superClass().onOpen(self)

  self.boxLayout:invalidateLayout()

  if FocusManager:getFocusedElement() == nil then
    self:setSoundSuppressed(true)
    FocusManager:setFocus(self.boxLayout)
    self:setSoundSuppressed(false)
  end

  self:setBlurApplied(true)
  self:disableInputForDuration(250)
  self:updateTexts()
end

function MouseSteeringMenu:setData(data)
  self.sensitivity:setValue(data.sensitivity)
  self.sensitivity:setText(string.format("%.2f", data.sensitivity))

  self.linearity:setValue(data.linearity)
  self.linearity:setText(string.format("%.2f", data.linearity))

  local textSmoothness = data.smoothness == 0 and self.i18n:getText("ui_off") or string.format("%.2f", data.smoothness)
  self.smoothness:setValue(data.smoothness)
  self.smoothness:setText(textSmoothness)

  self.autoSaveVehicle:setState(data.autoSaveVehicle and 2 or 1)
  self.invertXAxis:setState(data.invertXAxis and 2 or 1)

  local textDeadzone = data.smoothness == 0 and self.i18n:getText("ui_off") or string.format("%.2f", data.deadzone)
  self.deadzone:setValue(data.deadzone)
  self.deadzone:setText(textDeadzone)

  self.hud:setState(data.hud)
  self.hudText:setState(data.hudText and 2 or 1)
  self.hudLookBackInside:setState(data.hudLookBackInside and 2 or 1)
end

function MouseSteeringMenu:onGuiSetupFinished()
  MouseSteeringMenu:superClass().onGuiSetupFinished(self)

  self.mouseSteering = g_currentMission.mouseSteering
  self:setData(self.mouseSteering.settings)

  self.version:setText(string.format("v%s", self.mouseSteering.modDesc.version))
end

function MouseSteeringMenu:updateTexts()
  self.vehicleCountDisplay:setText(string.format("%s / %s", self.mouseSteering.vehicles.count, MouseSteering.MAX_VEHICLES))
end

function MouseSteeringMenu:onSliderSensitivity(slider, value)
  if slider ~= self.sensitivity then
    return
  end

  local settings = self.mouseSteering.settings

  settings.sensitivity = value
  self.sensitivity:setValue(value)
  self.sensitivity:setText(string.format("%.2f", value))
end

function MouseSteeringMenu:onSliderSmoothness(slider, value)
  if slider ~= self.smoothness then
    return
  end

  local smoothness = value
  self.mouseSteering.settings.smoothness = smoothness

  local text = smoothness == 0 and self.i18n:getText("ui_off") or string.format("%.2f", smoothness)
  self.smoothness:setValue(smoothness)
  self.smoothness:setText(text)
end

function MouseSteeringMenu:onSliderLinearity(slider, value)
  if slider ~= self.linearity then
    return
  end

  local settings = self.mouseSteering.settings

  settings.linearity = value
  self.linearity:setValue(value)
  self.linearity:setText(string.format("%.2f", value))
end

function MouseSteeringMenu:onClickAutoSaveVehicle()
  local settings = self.mouseSteering.settings

  settings.autoSaveVehicle = self.autoSaveVehicle.state == 2 and true or false
end

function MouseSteeringMenu:onClickOpenVehiclesDialog()
  self.mouseSteering.gui:showVehiclesDialog({
    callback = self.onVehicles,
    target = self,
  })
end

function MouseSteeringMenu:onVehicles(yes)
  if not yes then
    return
  end

  self:updateTexts()
end

function MouseSteeringMenu:onClickInvertXAxis()
  local settings = self.mouseSteering.settings

  settings.invertXAxis = self.invertXAxis.state == 2 and true or false
end

function MouseSteeringMenu:onSliderDeadzone(slider, value)
  if slider ~= self.deadzone then
    return
  end

  local deadzone = value
  self.mouseSteering.settings.deadzone = deadzone

  local text = deadzone == 0 and self.i18n:getText("ui_off") or string.format("%.2f", deadzone)
  self.deadzone:setValue(deadzone)
  self.deadzone:setText(text)
end

function MouseSteeringMenu:onClickHud()
  local settings = self.mouseSteering.settings

  settings.hud = self.hud.state
end

function MouseSteeringMenu:onClickHudText()
  local settings = self.mouseSteering.settings

  settings.hudText = self.hudText.state == 2 and true or false
end

function MouseSteeringMenu:onClickHudLookBackInside()
  local settings = self.mouseSteering.settings

  settings.hudLookBackInside = self.hudLookBackInside.state == 2 and true or false
end

function MouseSteeringMenu:save()
  self.mouseSteering:saveSettingsToXMLFile()
end

function MouseSteeringMenu:onClickReset()
  self.gui:showYesNoDialog({
    text = self.i18n:getText("ui_loadDefaultSettings"),
    title = self.i18n:getText("button_reset"),
    dialogType = DialogElement.TYPE_WARNING,
    callback = self.onYesNoResetSettings,
    target = self,
  })
end

function MouseSteeringMenu:onYesNoResetSettings(yes)
  if not yes then
    return
  end

  self.mouseSteering:reset()

  self.gui:showInfoDialog({
    dialogType = DialogElement.TYPE_INFO,
    text = self.i18n:getText("ui_loadedDefaultSettings"),
  })

  self:setData(self.mouseSteering.settings)
  self:updateTexts()
end

function MouseSteeringMenu:onClickBack()
  MouseSteeringMenu:superClass().onClickBack(self)

  self:setBlurApplied(false)
  self:changeScreen(nil)

  self:save()
end
