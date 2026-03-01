--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- name of the mod
local modName = g_currentModName

AdditionalSpecialization = {}

---Finalizes vehicle types
-- @param self table self
function AdditionalSpecialization.finalizeTypes(self)
  if self.typeName ~= "vehicle" then
    return
  end

  -- compose the full specialization name using the mod's name
  local mouseSteeringSpecialization = modName .. ".mouseSteeringVehicle"
  local mouseSteeringSpeedControlSpecialization = modName .. ".mouseSteeringSpeedControl"

  -- iterate types and attach custom specializations
  for typeName, typeEntry in pairs(self:getTypes()) do
    local hasDrivable = SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations)
    local hasLocomotive = SpecializationUtil.hasSpecialization(Locomotive, typeEntry.specializations)

    -- attach mouse steering to drivable vehicles (except locomotives)
    if hasDrivable and not hasLocomotive then
      local hasMouseSteering = SpecializationUtil.hasSpecialization(mouseSteeringSpecialization, typeEntry.specializations)
      if not hasMouseSteering then
        self:addSpecialization(typeName, mouseSteeringSpecialization)
      end
    end

    -- attach speed control to drivable vehicles (except locomotives)
    if hasDrivable and not hasLocomotive then
      local hasMouseSteeringSpeedControl = SpecializationUtil.hasSpecialization(mouseSteeringSpeedControlSpecialization, typeEntry.specializations)
      if not hasMouseSteeringSpeedControl then
        self:addSpecialization(typeName, mouseSteeringSpeedControlSpecialization)
      end
    end
  end
end
