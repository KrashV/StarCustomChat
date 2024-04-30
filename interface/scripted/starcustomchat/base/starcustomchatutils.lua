starcustomchat = {
  utils = {},
  locale = {},
  currentLocale = "en"
}

function starcustomchat.utils.getLocale()
  return root.getConfiguration("iccLocale") or "en"
end

function starcustomchat.utils.clearNick(nick)
  return string.gsub(nick, "%^#?%w+;", "")
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

function starcustomchat.utils.alert(key, ...)
  local text = starcustomchat.utils.getTranslation(key)
  interface.queueMessage(... and string.format(text, ...) or text)
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
          table.insert(availableCommands, {
            name = comm,
            color = nil
          })
        end
      end
    end
  end

  self.runCallbackForPlugins("addCustomCommandPreview", availableCommands, substr)

  table.sort(availableCommands, function(a, b) return a.name:upper() < b.name:upper() end)
  return availableCommands
end

function starcustomchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)

  local ensureSending = function ()
    promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
      if callback then
        callback(result)
      end
    end, ensureSending)
  end

  local ensureSpawning = function()
    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end

  promises:add(world.findUniqueEntity(stagehandType), ensureSending, function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end)
end

function starcustomchat.utils.createStagehandWithData(stagehandType, data)
  world.spawnStagehand(world.entityPosition(player.id()), stagehandType, {data = data})
end

function starcustomchat.utils.utf8Substring(inputString, startPos, endPos)
    -- Check if startPos is within the valid range
  startPos = math.min(startPos, endPos)
  
  endPos = math.min(endPos, utf8.len(inputString))

  -- Calculate the byte offsets for the start and end positions
  local byteStart = utf8.offset(inputString, startPos)
  local byteEnd = utf8.offset(inputString, endPos + 1) - 1

  -- Extract the substring
  local result = string.sub(inputString, byteStart, byteEnd)

  return result
end

function starcustomchat.utils.clearPortraitFromInvisibleLayers(portrait)
  if portrait and type(portrait) == "table" then
    local filteredPortrait = {}
    for _, layer in ipairs(portrait) do 
      local imageSize = root.imageSize(layer.image)
      if layer.image and not vec2.eq(imageSize, {0, 0}) and not string.find(layer.image, "?crop.?0;0;0") and not string.find(layer.image, "?multiply.?000") then
        
        -- Set the idle emote
        if string.find(layer.image, "/emote.png") then
          layer.image = string.gsub(layer.image, ":%w+%.%d", ":idle.1")
        end

        if vec2.eq(imageSize, {85, 85}) then
          layer.image = layer.image .. "?crop;21;21;85;85"
        end
        table.insert(filteredPortrait, layer)
      end
    end

    return filteredPortrait
  end

  return portrait
end