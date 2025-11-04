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
  local specialization = modName .. ".mouseSteeringVehicle"

  -- add mouse steering specialization to drivable vehicles (except locomotives)
  for typeName, typeEntry in pairs(self:getTypes()) do
    local hasDrivable = SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations)
    local hasLocomotive = SpecializationUtil.hasSpecialization(Locomotive, typeEntry.specializations)
    local hasMouseSteering = SpecializationUtil.hasSpecialization(specialization, typeEntry.specializations)

    if hasDrivable and not hasLocomotive and not hasMouseSteering then
      self:addSpecialization(typeName, specialization)
    end
  end
end
