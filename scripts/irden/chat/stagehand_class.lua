--[[
  Stagehand Class instance
]]

IrdenChatStagehand = {
  uuid = "",
  proximityRadius = 100,
  portraits = {}
}

function IrdenChatStagehand:create (stagehandUUID, proximityRadius)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self


  o.uuid = stagehandUUID
  o.proximityRadius = proximityRadius
  o.portraits = {}
  --stagehand.setUniqueId(stagehandUUID)
  return o
end

function IrdenChatStagehand:sendDataToAllPlayers(data, message)
  local players = world.players()
  for _, pId in ipairs(players) do 
    world.sendEntityMessage(pId, message or "icc_sendToUser", data)
  end
end

function IrdenChatStagehand:sendDataToPlayers(players, data, message)
  for _, pId in ipairs(players) do 
    world.sendEntityMessage(pId, message or "icc_sendToUser", data)
  end
end

function IrdenChatStagehand:sendDataToPlayer(pId, data, message)
  world.sendEntityMessage(pId, message or "icc_sendToUser", data)
end