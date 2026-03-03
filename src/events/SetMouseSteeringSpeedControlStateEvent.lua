--
-- SetMouseSteeringSpeedControlStateEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

SetMouseSteeringSpeedControlStateEvent = {}

local SetMouseSteeringSpeedControlStateEvent_mt = Class(SetMouseSteeringSpeedControlStateEvent, Event)

InitEventClass(SetMouseSteeringSpeedControlStateEvent, "SetMouseSteeringSpeedControlStateEvent")

---Create instance of Event class
-- @return table self instance of class event
function SetMouseSteeringSpeedControlStateEvent.emptyNew()
  local self = Event.new(SetMouseSteeringSpeedControlStateEvent_mt)

  return self
end

---Create new instance of event
-- @param table vehicle vehicle
-- @param boolean isActive speed control active state
-- @param number targetSpeedKmh target speed in km/h
function SetMouseSteeringSpeedControlStateEvent.new(vehicle, isActive, targetSpeedKmh)
  local self = SetMouseSteeringSpeedControlStateEvent.emptyNew()

  self.vehicle = vehicle
  self.isActive = isActive
  self.targetSpeedKmh = targetSpeedKmh

  return self
end

---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:readStream(streamId, connection)
  self.vehicle = NetworkUtil.readNodeObject(streamId)
  self.isActive = streamReadBool(streamId)
  self.targetSpeedKmh = streamReadInt16(streamId)

  self:run(connection)
end

---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:writeStream(streamId, connection)
  NetworkUtil.writeNodeObject(streamId, self.vehicle)
  streamWriteBool(streamId, self.isActive)
  streamWriteInt16(streamId, self.targetSpeedKmh)
end

---Run action on receiving side
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:run(connection)
  if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
    self.vehicle:setMouseSteeringSpeedControlState(self.isActive, self.targetSpeedKmh, true)
  end
end
