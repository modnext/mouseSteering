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
-- @param string mode active control mode
-- @param number targetValue target speed in km/h or pedal position in percent
-- @param number ignoredPedalDirection physical pedal direction held during activation
function SetMouseSteeringSpeedControlStateEvent.new(vehicle, isActive, mode, targetValue, ignoredPedalDirection)
  local self = SetMouseSteeringSpeedControlStateEvent.emptyNew()

  self.vehicle = vehicle
  self.isActive = isActive
  self.mode = mode
  self.targetValue = targetValue
  self.ignoredPedalDirection = ignoredPedalDirection

  return self
end

---Called when event data is received
-- @param integer streamId streamId
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:readStream(streamId, connection)
  self.vehicle = NetworkUtil.readNodeObject(streamId)
  self.isActive = streamReadBool(streamId)
  self.mode = streamReadBool(streamId) and MouseSteeringSpeedControl.MODE_PEDAL_PERCENT or MouseSteeringSpeedControl.MODE_TARGET_SPEED
  self.targetValue = streamReadInt16(streamId)
  self.ignoredPedalDirection = streamReadUIntN(streamId, 2) - 1

  self:run(connection)
end

---Writes event data to the stream
-- @param integer streamId streamId
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:writeStream(streamId, connection)
  NetworkUtil.writeNodeObject(streamId, self.vehicle)
  streamWriteBool(streamId, self.isActive)
  streamWriteBool(streamId, self.mode == MouseSteeringSpeedControl.MODE_PEDAL_PERCENT)
  streamWriteInt16(streamId, self.targetValue)
  streamWriteUIntN(streamId, math.clamp(math.sign(self.ignoredPedalDirection or 0), -1, 1) + 1, 2)
end

---Applies an authorized state change
-- @param Connection connection connection
function SetMouseSteeringSpeedControlStateEvent:run(connection)
  local vehicle = self.vehicle
  local spec = vehicle ~= nil and vehicle.spec_mouseSteeringSpeedControl or nil

  if connection == nil or spec == nil or vehicle.getIsSynchronized == nil or not vehicle:getIsSynchronized() or vehicle.getOwnerConnection == nil or vehicle.setMouseSteeringSpeedControlModeState == nil then
    return
  end

  local isFromServer = connection:getIsServer()

  -- only the server or the connection controlling this vehicle may change its state
  if not isFromServer and vehicle:getOwnerConnection() ~= connection then
    return
  end

  -- client requests are normalized by the server and echoed to the owner
  vehicle:setMouseSteeringSpeedControlModeState(self.isActive, self.mode, self.targetValue, self.ignoredPedalDirection, isFromServer)
end
