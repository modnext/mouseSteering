--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

-- name of the mod
local modName = g_currentModName

AdditionalSpecialization = {}

---Finalize vehicle types
-- @param table self the type manager
function AdditionalSpecialization.finalizeTypes(self)
  if self.typeName ~= "vehicle" then
    return
  end

  -- compose full specialization names
  local mouseSteeringSpecialization = modName .. ".mouseSteeringVehicle"
  local mouseSteeringSpeedControlSpecialization = modName .. ".mouseSteeringSpeedControl"

  -- iterate types and attach custom specializations
  for typeName, typeEntry in pairs(self:getTypes()) do
    local hasDrivable = SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations)
    local hasLocomotive = SpecializationUtil.hasSpecialization(Locomotive, typeEntry.specializations)

    -- attach specializations to drivable vehicles (except locomotives)
    if hasDrivable and not hasLocomotive then
      local hasMouseSteering = SpecializationUtil.hasSpecialization(mouseSteeringSpecialization, typeEntry.specializations)
      local hasMouseSteeringSpeedControl = SpecializationUtil.hasSpecialization(mouseSteeringSpeedControlSpecialization, typeEntry.specializations)

      if not hasMouseSteering then
        self:addSpecialization(typeName, mouseSteeringSpecialization)
      end

      if not hasMouseSteeringSpeedControl then
        self:addSpecialization(typeName, mouseSteeringSpeedControlSpecialization)
      end
    end
  end
end
