--
-- MouseSteeringVehicleSoldEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringVehicleSoldEvent = {}

local MouseSteeringVehicleSoldEvent_mt = Class(MouseSteeringVehicleSoldEvent, Event)

InitEventClass(MouseSteeringVehicleSoldEvent, "MouseSteeringVehicleSoldEvent")

---Create instance of Event class
-- @return table self instance of class event
function MouseSteeringVehicleSoldEvent.emptyNew()
  local self = Event.new(MouseSteeringVehicleSoldEvent_mt)

  return self
end

---Create new instance of event
-- @param string vehicleUniqueId unique vehicle identifier
-- @param number farmId farm identifier
-- @return table self instance of class event
function MouseSteeringVehicleSoldEvent.new(vehicleUniqueId, farmId)
  local self = MouseSteeringVehicleSoldEvent.emptyNew()

  self.vehicleUniqueId = vehicleUniqueId
  self.farmId = farmId

  return self
end

---Called on client side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteeringVehicleSoldEvent:readStream(streamId, connection)
  self.vehicleUniqueId = streamReadString(streamId)
  self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

  self:run(connection)
end

---Called on server side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteeringVehicleSoldEvent:writeStream(streamId, connection)
  streamWriteString(streamId, self.vehicleUniqueId)
  streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end

---Run action on receiving side
-- @param connection table the connection instance
function MouseSteeringVehicleSoldEvent:run(connection)
  g_messageCenter:publish(MouseSteeringMessageType.VEHICLE_SOLD, self.vehicleUniqueId, self.farmId)
end
