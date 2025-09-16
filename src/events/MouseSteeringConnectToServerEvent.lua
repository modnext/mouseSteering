--
-- MouseSteeringConnectToServerEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) Mod Next, All Rights Reserved.
--

MouseSteeringConnectToServerEvent = {}

local MouseSteeringConnectToServerEvent_mt = Class(MouseSteeringConnectToServerEvent, Event)

InitEventClass(MouseSteeringConnectToServerEvent, "MouseSteeringConnectToServerEvent")

---Create instance of Event class
-- @return table self instance of class event
function MouseSteeringConnectToServerEvent.emptyNew()
  local self = Event.new(MouseSteeringConnectToServerEvent_mt)

  return self
end

---Create new instance of event
-- @return table self instance of class event
function MouseSteeringConnectToServerEvent.new()
  local self = MouseSteeringConnectToServerEvent.emptyNew()

  return self
end

---Called on client side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteeringConnectToServerEvent:readStream(streamId, connection)
  g_currentMission.mouseSteering:readStream(streamId, connection)

  self:run(connection)
end

---Called on server side on join
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteeringConnectToServerEvent:writeStream(streamId, connection)
  g_currentMission.mouseSteering:writeStream(streamId, connection)
end

---Run action on receiving side
-- @param connection table the connection instance
function MouseSteeringConnectToServerEvent:run(connection)
  --
end
