starcustomchat = {
  utils = {},
  locale = {},
  currentLocale = "en"
}

function starcustomchat.utils.cleanNickname(nick)
  return string.gsub(nick, "^.*<.*;(.*)%^reset;$",  "%1")
end

function starcustomchat.utils.getLocale()
  return root.getConfiguration("iccLocale") or "en"
end

function starcustomchat.utils.buildLocale(localePluginConfig)
  local addLocaleKeys = copy(localePluginConfig or {})

  local locale = root.getConfiguration("iccLocale") or "en"
  starcustomchat.currentLocale = locale
  
  for key, translates in pairs(addLocaleKeys) do 
    if type(translates) == "table" then 
      addLocaleKeys[key] = translates[locale]
    end
  end

  -- Get base locale
  starcustomchat.locale = root.assetJson(string.format("/interface/scripted/starcustomchat/languages/%s.json", locale))
  -- Merge the plugin locale on top of it
  starcustomchat.locale = sb.jsonMerge(starcustomchat.locale, addLocaleKeys)
end

function starcustomchat.utils.getTranslation(key)
  if not starcustomchat.locale[key] then
    sb.logError("Can't get transaction of key: %s", key)
    return "???"
  else
    return starcustomchat.locale[key]
  end
end

function starcustomchat.utils.alert(key, format)
  local text = starcustomchat.utils.getTranslation(key)
  interface.queueMessage(format and string.format(text, format) or text)
end

function starcustomchat.utils.saveMessage(message)
  table.insert(self.sentMessages, message)

  if #self.sentMessages > self.sentMessagesLimit then
    table.remove(self.sentMessages, 1)
  end
  self.currentSentMessage = #self.sentMessages
end

function starcustomchat.utils.getCommands(allCommands, substr)
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

function starcustomchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)
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