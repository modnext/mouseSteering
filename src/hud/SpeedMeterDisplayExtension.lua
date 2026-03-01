--
-- SpeedMeterDisplayExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

SpeedMeterDisplayExtension = {}

local SpeedMeterDisplayExtension_mt = Class(SpeedMeterDisplayExtension)

---Creates a new instance of SpeedMeterDisplayExtension
function SpeedMeterDisplayExtension.new(customMt)
  local self = setmetatable({}, customMt or SpeedMeterDisplayExtension_mt)

  self.isCreated = false

  return self
end

---Loads the speed meter display extension
function SpeedMeterDisplayExtension:load()
  if not self.isCreated then
    self:overwriteGameFunctions()

    self.isCreated = true
  end
end

---Deletes the speed meter display extension
function SpeedMeterDisplayExtension:delete()
  self.isCreated = false
end

---Applies function hooks to SpeedMeterDisplay class
function SpeedMeterDisplayExtension:overwriteGameFunctions()
  local extension = self

  -- overwrite standard speed meter drawing function
  SpeedMeterDisplay.drawSpeedMeter = Utils.overwrittenFunction(SpeedMeterDisplay.drawSpeedMeter,
    function(speedMeterDisplay, superFunc, centerX, centerY)
      local vehicle = speedMeterDisplay.vehicle
      local isScrollActive = false

      -- check if custom mouse steering speed control is active
      if vehicle ~= nil and vehicle.getMouseSteeringSpeedControlIsActive ~= nil then
        isScrollActive = vehicle:getMouseSteeringSpeedControlIsActive()
      end

      if isScrollActive then
        -- display custom speed control icon
        extension:setOverlaySliceWithTexture(speedMeterDisplay.cruiseControl, "mouseSteering.icon_speedControl")
      end

      -- call the original function
      superFunc(speedMeterDisplay, centerX, centerY)

      if isScrollActive then
        -- restore the original cruise control icon
        extension:setOverlaySliceWithTexture(speedMeterDisplay.cruiseControl, "gui.icon_tempomat")
      end
    end)
end

---Sets overlay slice and switches image texture when needed
-- @param overlay table The overlay element to update
-- @param sliceId string The identifier of the slice to use
-- @return boolean isSuccess true if texture was switched successfully
function SpeedMeterDisplayExtension:setOverlaySliceWithTexture(overlay, sliceId)
  local isSuccess = false

  if overlay ~= nil then
    local slice = g_overlayManager:getSliceInfoById(sliceId)

    if slice ~= nil then
      -- keep current tint color because setImage() recreates overlay and resets runtime color state
      local r, g, b, a = overlay.r, overlay.g, overlay.b, overlay.a

      -- setSliceId() only updates UVs; when switching to a slice from another
      -- texture config we must also switch the overlay image file
      overlay:setImage(slice.filename)
      overlay:setSliceId(sliceId)

      -- restore tint color if overlay has a valid ID
      if overlay.overlayId ~= 0 then
        setOverlayColor(overlay.overlayId, r or 1, g or 1, b or 1, a or 1)
      end

      isSuccess = true
    end
  end

  return isSuccess
end
