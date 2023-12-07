icchat = {
  utils = {}
}

function icchat.utils.getLocale()
  return root.getConfiguration("iccLocale") or "en"
end

function icchat.utils.getTranslation(key)
  if not self.localeConfig[key] then
    sb.logError("Can't get transaction of key: %s", key)
    return "???"
  else
    return self.localeConfig[key] 
  end
end

function icchat.utils.sendMessageToStagehand(stagehandType, message, data, callback)
  local radius = 50

  local function findStagehand(stagehandType, r)
    for _, sId in ipairs( world.entityQuery(world.entityPosition(player.id()), r, {
      includedTypes = {"stagehand"}
    })) do 
      if world.stagehandType(sId) == stagehandType then
        return sId
      end
    end
  end

  local fakePromise = {
    succeeded = function() return findStagehand(stagehandType, radius) end,
    finished = function()
      return true
    end,
    result = function() end,
    error = function() end
  }

  local function findStagehandAndSendData()
    local sId = findStagehand(stagehandType, radius)
    if sId then
      promises:add(world.sendEntityMessage(sId, message, data), function(result)
        if callback then 
          callback(result)
        end
      end)
      return true
    end
  end

  if not findStagehandAndSendData() then
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)
    promises:add(fakePromise, findStagehandAndSendData, function() 
      promises:add(fakePromise, findStagehandAndSendData) 
    end)
  end
end