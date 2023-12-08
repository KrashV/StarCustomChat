require "/scripts/messageutil.lua"
require "/scripts/irden/chat/stagehand_class.lua"

function init()
  local broadcastArea = config.getParameter("broadcastArea")
  message.setHandler("broadcastArea", function() return broadcastArea end)
  
  local waypointName = config.getParameter("waypoint")
  if waypointName and not storage.setWaypoint then
    local waypoints = world.getProperty("waypoints") or {}
    waypoints[waypointName] = waypoints[waypointName] or {}
    table.insert(waypoints[waypointName], entity.position())
    world.setProperty("waypoints", waypoints)
    storage.setWaypoint = true
  end

  -- That's new
  self.stagehand = IrdenChatStagehand:create("irdencustomchat", 300)
  
  message.setHandler( "icc_sendMessage", simpleHandler(handleMessage) )
  message.setHandler( "icc_requestPortrait", simpleHandler(requestPortrait) )
  message.setHandler( "icc_getAllPlayers", simpleHandler(getAllPlayers) )
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

function getAllPlayers()
  local players = {}
  for _, player in ipairs(world.players()) do 
    if world.entityName(player) and world.entityPortrait(player, "bust") then
      table.insert(players, {
        id = player,
        name = world.entityName(player),
        portrait = requestPortrait(player)
      })
    end
  end
  return players
end

function requestPortrait(entityId)
  if world.entityExists(entityId) and world.entityPortrait(entityId, "bust") then 
    return world.entityPortrait(entityId, "bust")
  else
    return nil
  end
end