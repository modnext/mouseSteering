--
-- AdditionalSpecialization
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

local modName = g_currentModName

AdditionalSpecialization = {}

function AdditionalSpecialization.finalizeTypes(self)
  if self.typeName ~= "vehicle" then
    return
  end

  -- Compose the full specialization name using the mod's name
  local specialization = modName .. ".mouseSteeringVehicle"

  for typeName, typeEntry in pairs(self:getTypes()) do
    local hasDrivable = SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations)
    local hasMouseSteering = SpecializationUtil.hasSpecialization(specialization, typeEntry.specializations)

    if hasDrivable and not hasMouseSteering then
      self:addSpecialization(typeName, specialization)
    end
  end
end
