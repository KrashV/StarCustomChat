require "/scripts/messageutil.lua"
require "/scripts/irden/chat/stagehand_class.lua"

function iccstagehand_init()
  self.stagehand = IrdenChatStagehand:create("irdencustomchat", 100)
  
  message.setHandler( "icc_sendMessage", simpleHandler(handleMessage) )
  message.setHandler( "icc_requestPortrait", simpleHandler(requestPortrait) )
  message.setHandler( "icc_getAllPlayers", simpleHandler(getAllPlayers) )
  message.setHandler( "icc_savePortrait", simpleHandler(savePortrait) )

  self.debug = config.getParameter("debug") or false
  self.aliveTime = 10
  self.aliveTimer = 0
end

function handlerWithReset(fun)
  self.aliveTimer = 0
  simpleHandler(fun)
end

function handleMessage(data)
  local author = data.connection * -65536

  if data.mode == "Proximity" and data.proximityRadius then
    local authorPos = world.entityPosition(author)
    for _, pId in ipairs(world.players()) do 
      local distance = world.magnitude(authorPos, world.entityPosition(pId))
      if distance <= data.proximityRadius then
        self.stagehand:sendDataToPlayer(pId, data)
      end
    end
  elseif data.mode == "Fight" and data.fight then
    promises:add(world.sendEntityMessage("irdenfighthandler_" .. data.fight, "getFight"), function(fight) 
      if fight and not fight.done then
        for uuid, player in pairs(fight.players) do
          self.stagehand:sendDataToPlayer(uuid, data)
        end
      end
    end)
  end
  return true
end

function getAllPlayers()
  local players = {}
  for _, player in ipairs(world.players()) do 
    table.insert(players, {
      id = player,
      name = world.entityName(player),
      data = requestPortrait(player)
    })
  end
  return players
end

function getPortraitSafely(entityId)
  local portrait
  if pcall(function()
    portrait = world.entityPortrait(entityId, "full")
  end) then 
    return portrait 
  else
    if self.debug  then
      sb.logError("PORTRAIT ERROR! " .. world.entityName(entityId) .. " has broken hair!")
    end
  end
end

function requestPortrait(entityId)
  if world.entityExists(entityId) then
    local uuid = world.entityUniqueId(entityId)

    if uuid then
      if self.stagehand.portraits[uuid] then
        return self.stagehand.portraits[uuid]
      elseif world.entityExists(entityId) and getPortraitSafely(entityId) then 
        self.stagehand.portraits[uuid] = {
          portrait = getPortraitSafely(entityId),
          cropArea = cropArea,
          uuid = uuid
        }
        return self.stagehand.portraits[uuid]
      else
        return nil
      end
    end
  end
end

function savePortrait(request)
  if world.entityExists(request.entityId) and getPortraitSafely(request.entityId) then 
    local uuid = world.entityUniqueId(request.entityId)
    self.stagehand.portraits[uuid] = {
      portrait = request.portrait or getPortraitSafely(request.entityId),
      cropArea = request.cropArea,
      uuid = uuid
    }
    return true
  else
    return nil
  end
end

function iccstagehand_update(dt)
  promises:update()
  self.aliveTimer = self.aliveTimer + dt 
  if self.aliveTimer > self.aliveTime then
    stagehand.die()
  end
end

function uninit()

end