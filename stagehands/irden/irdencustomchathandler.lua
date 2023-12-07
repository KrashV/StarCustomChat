require "/scripts/messageutil.lua"
require "/scripts/irden/chat/stagehand_class.lua"

function init()
  self.stagehand = IrdenChatStagehand:create("irdencustomchat", 300)
  
  message.setHandler( "icc_sendMessage", simpleHandler(handleMessage) )
  message.setHandler( "icc_requestPortrait", simpleHandler(requestPortrait) )
end

function handleMessage(data)
  local author = data.connection * -65536
  if data.mode == "Proximity" then
    local authorPos = world.entityPosition(author)
    for _, pId in ipairs(world.players()) do 
      local distance = world.magnitude(authorPos, world.entityPosition(pId))
      if distance <= self.stagehand.proximityRadius then
        self.stagehand:sendDataToPlayer(pId, data)
      end
    end
  elseif data.mode == "Announcement" then 
    self.stagehand:sendDataToAllPlayers(data)
  end
end

function requestPortrait(entityId)
  if world.entityExists(entityId) then 
    return world.entityPortrait(entityId, "bust")
  else
    return nil
  end
end

function update()

end

function uninit()
end