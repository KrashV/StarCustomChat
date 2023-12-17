require "/scripts/messageutil.lua"
require "/scripts/irden/chat/stagehand_class.lua"

function iccstagehand_init()
  self.stagehand = IrdenChatStagehand:create("irdencustomchat", 100)
  
  message.setHandler( "icc_sendMessage", simpleHandler(handleMessage) )
  message.setHandler( "icc_requestPortrait", simpleHandler(requestPortrait) )
  message.setHandler( "icc_requestAsyncPortrait", simpleHandler(requestAsyncPortrait) )
  message.setHandler( "icc_getAllPlayers", simpleHandler(getAllPlayers) )
  message.setHandler( "icc_savePortrait", simpleHandler(savePortrait) )

  self.debug = config.getParameter("debug") or false

  stagehand.setUniqueId("irdencustomchat")
  self.alertedPlayers = {}
end

function handlerWithReset(fun)
  self.aliveTimer = 0
  simpleHandler(fun)
end

function handleMessage(data)
  local author = data.connection * -65536

  world.sendEntityMessage(author, "icc_log_message", {
    mode = data.mode,
    text = data.text,
    nickname = data.nickname,
    fight = data.fight
  })

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
      data = {} --requestPortrait(player)
    })
  end
  return players
end

function getPortraitSafely(entityId)
  local portrait
  if pcall(function()
    portrait = world.entityPortrait(entityId, "bust")
  end) then 
    return portrait 
  else
    local conn = tostring(entityId // -65536)
    if self.debug and not self.alertedPlayers[conn] then
      sb.logError("ICC PORTRAIT ERROR! " .. world.entityName(entityId) .. " has a broken portrait!")
      self.alertedPlayers[conn] = true
    end
  end
end

function requestPortrait(entityId)
  if world.entityExists(entityId) then
    local uuid = world.entityUniqueId(entityId)

    if uuid then
      --local portrait = getPortraitSafely(entityId)
      if world.entityExists(entityId) and portrait then

        return {
          portrait = portrait,
          cropArea = cropArea,
          uuid = uuid,
          entityId = entityId,
          connection = entityId // -65536
        }
      end
    end
  end
end

function requestAsyncPortrait(data)
  local entityId = data.entityId
  local author = data.author
  if world.entityExists(entityId) and world.entityExists(author) then
    local uuid = world.entityUniqueId(entityId)

    if uuid then
      promises:add(world.sendEntityMessage(entityId, "icc_request_player_portrait"), function(res_data)
        self.stagehand:sendDataToPlayer(author, res_data, "icc_send_player_portrait")
      end, function() 
        if world.entityExists(entityId) then
          --local portrait = getPortraitSafely(entityId)

          if portrait then
            local res_data = {
              type = "UPDATE_PORTRAIT",
              portrait = portrait,
              cropArea = cropArea,
              entityId = entityId,
              uuid = uuid,
              connection = entityId // -65536
            }
            self.stagehand:sendDataToPlayer(author, res_data, "icc_send_player_portrait")
          end
        end
      end)
    end
  end
end

function savePortrait(request)
  return true
end

function distortText(maincolor, originalText, distance, max_distance)
  -- Check if distance is beyond the maximum allowed distance
  if distance > max_distance then
      return nil
  end

  -- Calculate distortion factor based on distance (you can adjust this formula)
  local distortionFactor = distance / max_distance

  -- Function to distort a single character
  local function distortCharacter(char)
      local alpha = 255 * (1 - distortionFactor) -- Default alpha value

      -- Add some randomness to the alpha channel
      local randomOffset = math.random(- 50, 50)
      alpha = math.max(0, math.min(255, alpha + randomOffset))

      -- Calculate distorted alpha based on the distortion factor
      local distortedAlpha = math.floor(alpha)

      -- Convert the distorted alpha back to a hex value
      local distortedAlphaHex = string.format("%02X", distortedAlpha)

      -- Add the color directive before the character
      local distortedChar = maincolor ..distortedAlphaHex .. ";" .. char

      return distortedChar
  end

  -- Iterate through each character in the original text and distort it
  local distortedText = originalText:gsub(".", distortCharacter)

  return distortedText
end

function iccstagehand_update(dt)
  promises:update()
end

function uninit()

end