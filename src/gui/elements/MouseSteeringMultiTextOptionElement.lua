--
-- MouseSteeringMultiTextOptionElement
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringMultiTextOptionElement = {}

local MouseSteeringMultiTextOptionElement_mt = Class(MouseSteeringMultiTextOptionElement, MultiTextOptionElement)

---Creates a new instance of MouseSteeringMultiTextOptionElement
function MouseSteeringMultiTextOptionElement.new(target, custom_mt)
  local self = MultiTextOptionElement.new(target, custom_mt or MouseSteeringMultiTextOptionElement_mt)

  -- setting values for the element
  self.settingValues = {}

  return self
end

---
function MouseSteeringMultiTextOptionElement:loadFromXML(xmlFile, key)
  MouseSteeringMultiTextOptionElement:superClass().loadFromXML(self, xmlFile, key)

  -- load custom configuration
  local textsString = Utils.getNoNil(getXMLString(xmlFile, key .. "#texts"), "")

  if textsString ~= "" then
    local textParts = textsString:split("|")

    if textParts ~= nil then
      for _, textPart in ipairs(textParts) do
        local settingValue = textPart:match("_ui_([%w_]+)")

        if settingValue ~= nil then
          table.insert(self.settingValues, settingValue)
        end
      end
    end
  end

  -- ensure we have at least one valid state
  if #self.settingValues == 0 then
    if #self.texts == 0 then
      table.insert(self.texts, g_i18n:getText("ui_off"))
    end

    table.insert(self.settingValues, "off")
  end
end

---
function MouseSteeringMultiTextOptionElement:copyAttributes(src)
  MouseSteeringMultiTextOptionElement:superClass().copyAttributes(self, src)

  self.settingValues = {}

  -- copy setting values if source has them
  if src.settingValues and #src.settingValues > 0 then
    for _, value in ipairs(src.settingValues) do
      if type(value) == "string" then
        table.insert(self.settingValues, value)
      else
        table.insert(self.settingValues, tostring(value))
      end
    end
  end
end

---
function MouseSteeringMultiTextOptionElement:setState(stateOrValue, forceEvent)
  local stateToSet = 1

  if type(stateOrValue) == "string" and self.settingValues ~= nil then
    for i, value in ipairs(self.settingValues) do
      if value == stateOrValue then
        stateToSet = i
        break
      end
    end
  elseif type(stateOrValue) == "number" then
    stateToSet = stateOrValue
  end

  MouseSteeringMultiTextOptionElement:superClass().setState(self, stateToSet, forceEvent)
end

---Gets the raw string value for the current state, used for settings
-- @return string The raw string value for the current state
function MouseSteeringMultiTextOptionElement:getSettingValue()
  if self.settingValues ~= nil and self.settingValues[self.state] ~= nil then
    return self.settingValues[self.state]
  end

  -- fallback to state index if no setting value is found
  return tostring(self.state)
end

---Programmatically sets the display texts and their corresponding setting values
-- @param displayTexts table The array of display texts
-- @param settingValues table|nil The array of corresponding setting values
function MouseSteeringMultiTextOptionElement:setValues(displayTexts, settingValues)
  if displayTexts == nil then
    return
  end

  MouseSteeringMultiTextOptionElement:superClass().setTexts(self, displayTexts)
  self.settingValues = settingValues or {}

  -- ensure state is valid after setting new values
  if self.state ~= nil then
    self.state = math.max(1, math.min(self.state, #self.texts))
    self:updateContentElement()
    self:notifyIndexChange(self.state, #self.texts)
  end
end

---Overrides the base setTexts method to prevent desynchronization
-- @param texts table The array of texts to set
function MouseSteeringMultiTextOptionElement:setTexts(texts)
  MouseSteeringMultiTextOptionElement:superClass().setTexts(self, texts)
  self.settingValues = {}
end

---Overrides the base addText method to prevent desynchronization
-- @param text string The text to add
-- @param i number|nil The index to add the text at
function MouseSteeringMultiTextOptionElement:addText(text, i)
  MouseSteeringMultiTextOptionElement:superClass().addText(self, text, i)
end
