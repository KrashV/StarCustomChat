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

function icchat.utils.alert(key)
  local text = icchat.utils.getTranslation(key)
  interface.queueMessage(text)
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

function icchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)
  local n_attempts = 10
  local findStagehandResult = false

  promises:add(world.findUniqueEntity(stagehandType), function() 
    promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
      if callback then
        callback(result)
      end
    end, function (err)
      if errcallback then
        errcallback(err)
      end
    end)
  end, function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    promises:add(world.findUniqueEntity(stagehandType), function() 
      promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
        if callback then
          callback(result)
        end
      end, function (err)
        if errcallback then
          errcallback(err)
        end
      end)
    end)
  end)
end