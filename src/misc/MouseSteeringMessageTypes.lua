--
-- MouseSteeringMessageTypes
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringMessageType = {}

-- Message types for mouse steering communication
MouseSteeringMessageType.VEHICLE_TOGGLE = nextMessageTypeId()
MouseSteeringMessageType.VEHICLE_SOLD = nextMessageTypeId()
MouseSteeringMessageType.SETTING_CHANGED = {
  DEFAULT = nextMessageTypeId(),
}
