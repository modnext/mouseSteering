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

---Reads the initial state payload and applies only server-authoritative data
-- @param streamId number the stream id
-- @param connection table the connection instance
function MouseSteeringConnectToServerEvent:readStream(streamId, connection)
  local isFromServer = connection ~= nil and connection:getIsServer()
  g_currentMission.mouseSteering:readStream(streamId, connection, isFromServer)

  self:run(connection)
end

---Writes the initial state payload
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
