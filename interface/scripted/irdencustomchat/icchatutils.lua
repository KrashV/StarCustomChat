icchat = {
  utils = {}
}
function icchat.utils.cleanNickname(nick)
  return string.gsub(nick, ".*<(.*)",  "%1")
end

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

function icchat.utils.alert(message)
  interface.queueMessage(message)
end

function icchat.utils.saveMessage(message)
  table.insert(self.sentMessages, message)

  if #self.sentMessages > self.sentMessagesLimit then
    table.remove(self.sentMessages, 1)
  end
  self.currentSentMessage = #self.sentMessages
end

function icchat.utils.getCommands(allCommands, substr)
  local availableCommands = {}

  for type, commlist in pairs(allCommands) do 
    for _, comm in ipairs(commlist) do
      if type ~= "admin" or (type == "admin" and player.isAdmin()) then
        if string.find(comm, substr) then
          table.insert(availableCommands, comm)
        end
      end
    end
  end

  table.sort(availableCommands, function(a, b) return a:upper() < b:upper() end)
  return availableCommands
end

function icchat.utils.sendMessageToStagehand(stagehandType, message, data, callback)
  local radius = 20

  local function findStagehand(stagehandType, r)
    if world.entityPosition(player.id()) then
      for _, sId in ipairs( world.entityQuery(world.entityPosition(player.id()), r, {
        includedTypes = {"stagehand"}
      })) do 
        if world.stagehandType(sId) == stagehandType then
          return sId
        end
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
    if pcall(world.spawnStagehand(world.entityPosition(player.id()), stagehandType)) then
      promises:add(fakePromise, findStagehandAndSendData, function() 
        promises:add(fakePromise, findStagehandAndSendData) 
      end)
      return 0
    else
      icchat.utils.alert(icchat.utils.getTranslation("chat.alerts.stagehand_not_found"))
      return 1
    end
  end
end