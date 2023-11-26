--[[
  Stagehand Class instance
]]

IrdenChatStagehand = {
  uuid = "",
  proximityRadius = 100
}

function IrdenChatStagehand:create (stagehandUUID, proximityRadius)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self


  o.uuid = stagehandUUID
  o.proximityRadius = proximityRadius
  --stagehand.setUniqueId(stagehandUUID)
  return o
end

function IrdenChatStagehand:sendDataToAllPlayers(data)
  local players = world.players()
  for _, pId in ipairs(players) do 
    world.sendEntityMessage(pId, "icc_sendToUser", data)
  end
end

function IrdenChatStagehand:sendDataToPlayers(players, data)
  for _, pId in ipairs(players) do 
    world.sendEntityMessage(pId, "icc_sendToUser", data)
  end
end

function IrdenChatStagehand:sendDataToPlayer(pId, data)
  world.sendEntityMessage(pId, "icc_sendToUser", data)
end