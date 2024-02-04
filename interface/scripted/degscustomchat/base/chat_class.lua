--[[
  Chat Class instance

  TODO:
    6. Set avatar: image
]]

require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/interface/scripted/degscustomchat/base/starcustomchatutils.lua"


IrdenChat = {
  messages = jarray(),
  drawnMessageIndexes = jarray(),
  author = 0,
  lineOffset = 0,
  canvas = nil,
  highlightCanvas = nil,
  commandPreviewCanvas = nil,
  totalHeight = 0,
  config = {},
  expanded = false,
  chatMode = "modern",
  savedPortraits = {},
  connectionToUuid = {},

  queueTimer = 0.5,
  queueTime = 0,
  lastWhisper = nil,
  maxCharactersAllowed = 0,
  callbackPlugins = function() end
}

IrdenChat.__index = IrdenChat

function IrdenChat:create (canvasWid, highlightCanvasWid, commandPreviewWid, config, playerId, messages, 
  chatMode, expanded, savedPortraits, connectionToUuid, lineOffset, maxCharactersAllowed, callbackPlugins)

  local o = {}
  setmetatable(o, self)
  self.__index = self

  o.messages = messages
  o.author = playerId
  o.canvas = widget.bindCanvas(canvasWid)
  o.highlightCanvas = widget.bindCanvas(highlightCanvasWid)
  o.commandPreviewCanvas = widget.bindCanvas(commandPreviewWid)
  o.config = config
  o.chatMode = chatMode
  o.expanded = expanded
  o.savedPortraits = savedPortraits or {}
  o.connectionToUuid = connectionToUuid or {}
  o.lineOffset = lineOffset or 0
  o.maxCharactersAllowed = maxCharactersAllowed
  o.callbackPlugins = callbackPlugins
  return o
end

function IrdenChat:addMessage(msg)
  function formatMessage(message)

    if message.mode == "RadioMessage" and message.portrait then
      message.portrait = message.portrait .. self.config.radioMessageCropDirective
    end

    message.time = message.time or (message.nickname and message.nickname:match("%^%a+;(%d+:%d+)%^reset;")) or message.text:match("%^%a+;(%d+:%d+)%^reset;")

    if message.nickname then
      message.nickname = starcustomchat.utils.cleanNickname(message.nickname)
    end

    message = self.callbackPlugins("formatIncomingMessage", message)

    if not message.text or message.text == "" then return nil end

    if message.connection == 0 then
      for _, settings in ipairs(self.config.serverTextSpecific) do 
        if string.find(message.text, settings.text) then
          if settings.icon then
            message.portrait = settings.icon
          end
          if settings.nickname then
            message.nickname = starcustomchat.utils.getTranslation(settings.nickname)
          end
          break
        end
      end
    else
      if message.mode == "Whisper" then
        if self.lastWhisper and message.text == self.lastWhisper.text then
          message.recepient = self.lastWhisper.recepient
          self.lastWhisper = nil
        else
          pane.playSound(self.config.notificationSound)
        end
      end

      self:requestPortrait(message.connection)
      
    end
    return message
  end

  if msg.connection then
    msg = formatMessage(msg)
    if msg then
      table.insert(self.messages, msg)
      if #self.messages > self.config.chatHistoryLimit then
        table.remove(self.messages, 1)
      end
      self.callbackPlugins("onReceiveMessage", msg)
      self:processQueue()
    end
  end
end

function IrdenChat:requestPortrait(connection)
  local entityId = connection * -65536
  local uuid = world.entityUniqueId(entityId) or self.connectionToUuid[tostring(connection)]

  if uuid and not self.savedPortraits[uuid] then
    if entityId and world.entityExists(entityId) then
      promises:add(world.sendEntityMessage(entityId, "icc_request_player_portrait"), function(data)
        self.savedPortraits[data.uuid] = {
          portrait = data.portrait,
          cropArea = data.cropArea
        }
        self.connectionToUuid[tostring(connection)] = uuid
        self:processQueue()
      end, function()
        self.connectionToUuid[tostring(connection)] = uuid
        self.savedPortraits[uuid] = {
          portrait = world.entityExists(entityId) and world.entityPortrait(entityId, "full") or {},
          cropArea = self.config.portraitCropArea
        }
        self:processQueue()
      end)
    end
  end
end

function IrdenChat:updatePortrait(data)
  self.savedPortraits[data.uuid] = data
  self.connectionToUuid[tostring(data.connection)] = data.uuid
  self:processQueue()
end

function IrdenChat:clearHistory()
  self.messages = jarray()
  self:processQueue()
end

function IrdenChat:resetChat()
  self.chatMode = root.getConfiguration("iccMode") or "modern"
  self.config.fontSize = root.getConfiguration("icc_font_size") or self.config.fontSize
  self.maxCharactersAllowed  = root.getConfiguration("icc_max_allowed_characters") or 0
  
  --[[
    starcustomchat.utils.sendMessageToStagehand(self.stagehandType, "icc_savePortrait", {
    entityId = player.id(),
    portrait = nil,
    cropArea = player.getProperty("icc_portrait_frame",  self.config.portraitCropArea)
  })
  --]]

  if player.uniqueId() and player.id() and self.savedPortraits[player.uniqueId()] then
    self.savedPortraits[player.uniqueId()] = {
      portrait = world.entityPortrait(player.id(), "bust"),
      cropArea = player.getProperty("icc_portrait_frame") or self.config.portraitCropArea
    }
  end

  self:processQueue()
end

function IrdenChat:getMessages ()
  return self.messages
end

function IrdenChat:processCommand(text)
  local commandResult = chat.command(text)
  for _, line in ipairs(commandResult) do 
    chat.addMessage(line)
    table.insert(self.messages, {
      text = line
    })
    if #self.messages > self.config.chatHistoryLimit then
      table.remove(self.messages, 1)
    end
  end
end

function IrdenChat:sendMessage(text, mode)
  if text == "" then return end

  local data = {
    text = text,
    connection = self.author // -65536,
    portrait = "", --TODO: Add portrait,
    mode = mode,
    nickname = player.name()
  }

  self.callbackPlugins("onSendMessage", data)
end

function portraitSizeFromBaseFont(font)
  return math.floor(font * 2.5)
end

function IrdenChat:previewCommands(commands, selected)
  self.commandPreviewCanvas:clear()

  local result = ""
  for i, command in ipairs(commands) do 
    result = result .. "^" .. (i == selected and self.config.commandPreviewSelectedColor or self.config.commandPreviewColor) .. ";" .. command .. " "
  end

  self.commandPreviewCanvas:drawText(result, {
    position = {0, 0},
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "bottom" -- top, mid, bottom
  }, self.config.previewCommandFontSize)
end

function IrdenChat:drawIcon(target, nickname, messageOffset, color, time, recepient)
  local function drawModeIcon(offset)
    local frameSize = root.imageSize(self.config.icons.frame)
    local squareSize = self.config.modeIndicatorSize
    self.canvas:drawRect({offset[1] - squareSize - 1, offset[2], offset[1] - 1, offset[2] + portraitSizeFromBaseFont(self.config.fontSize) - squareSize}, color)
  end

  local function drawImage(image, offset)
    local frameSize = root.imageSize(image)
    local size = portraitSizeFromBaseFont(self.config.fontSize)
    self.canvas:drawImageRect(image, {0, 0, frameSize[1], frameSize[2]}, {offset[1], offset[2], offset[1] + size, offset[2] + size})
  end

  local function drawPortrait(portrait, messageOffset, cropArea, color)
    local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    local size = portraitSizeFromBaseFont(self.config.fontSize)

    for _, layer in ipairs(portrait) do
      self.canvas:drawImageRect(layer.image, cropArea or self.config.portraitCropArea, {offset[1], offset[2], offset[1] + size, offset[2] + size})
    end
    drawModeIcon(offset)
    drawImage(self.config.icons.frame, offset)
  end



  if type(target) == "number" then
    local entityId = target * -65536

    local uuid = (world.entityExists(entityId) and world.entityUniqueId(entityId)) or self.connectionToUuid[tostring(target)]

    if uuid and self.savedPortraits[uuid] then
      drawPortrait(self.savedPortraits[uuid].portrait, messageOffset, self.savedPortraits[uuid].cropArea, color)
    else
      local offset = vec2.add(self.config.iconImageOffset, messageOffset)
      drawImage(self.config.icons.empty, offset)
      drawImage(self.config.icons.unknown, offset)
      drawModeIcon(offset)
      drawImage(self.config.icons.frame, offset)
    end
  elseif type(target) == "string" then
    local offset = vec2.add(self.config.iconImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    drawImage(target, offset)
    drawModeIcon(offset)
    drawImage(self.config.icons.frame, offset)
  end
  
  local size = portraitSizeFromBaseFont(self.config.fontSize)
  local nameOffset = vec2.add(self.config.nameOffset, {size, size})
  nameOffset = vec2.add(nameOffset, messageOffset)

  self.canvas:drawText(recepient and "-> " .. starcustomchat.utils.cleanNickname(recepient) or starcustomchat.utils.cleanNickname(nickname), {
    position = nameOffset,
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "top" -- top, mid, bottom
  }, self.config.fontSize + 1, (color or self.config.textColors.default))

  if time then
    timePosition = {self.canvas:size()[1] - self.config.timeOffset[1], nameOffset[2] + self.config.timeOffset[2]}
    self.canvas:drawText(time, {
      position = timePosition,
      horizontalAnchor = "right", -- left, mid, right
      verticalAnchor = "top" -- top, mid, bottom
    }, self.config.fontSize - 1, self.config.textColors.time)
  end
end


--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:offsetCanvas(offset)
  if not offset then return end
  
  if #self.drawnMessageIndexes > 0 and self.messages[self.drawnMessageIndexes[1]].offset + self.messages[self.drawnMessageIndexes[1]].height - 20 < 0 and offset < 0 then
    return
  else
    self.lineOffset = math.min(self.lineOffset + offset, 0)
    self:processQueue()    
  end
end

function IrdenChat:resetOffset()
  self.lineOffset = 0
  self:processQueue()
end

function IrdenChat:highlightMessage(y1, y2)
  self.highlightCanvas:drawRect({2, y1, self.highlightCanvas:size()[1] - 2, y2}, self.config.highlightColor)
end

function IrdenChat:clearHighlights()
  self.highlightCanvas:clear()
end

function IrdenChat:collapseMessage(position)
  local pos = position or self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self.messages[self.drawnMessageIndexes[i]].collapsed = not self.messages[self.drawnMessageIndexes[i]].collapsed
      self:processQueue()
    end
  end
end

function IrdenChat:selectMessage(position)
  local pos = position or self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self:highlightMessage(message.offset, message.offset + message.height + self.config.spacings.messages)
      return message
    end
  end
end

function filterMessages(messages)
  local drawnMessageIndexes = {}

  for i, message in ipairs(messages) do 
    --filter messages by mode availability
    local mode = message.mode
    
    if mode and (widget.active("btnCk" .. mode) == nil and true or widget.getChecked("btnCk"  .. mode)) then
      table.insert(drawnMessageIndexes, i)
    end
  end
  return drawnMessageIndexes
end

function createNameForCompactMode(name, color, text, time, timeColor)
  local timeString = time and string.format("^%s;[%s] ", timeColor, time) or ""
  local formattedString = string.format(" %s^reset;<^%s;%s^reset;>: %s", timeString, color, starcustomchat.utils.cleanNickname(name), text)

  return formattedString
end

function cutStringFromEnd(toCollapse, inputString, MAX)
  local is_long = utf8.len(inputString) > MAX
  if toCollapse and is_long then
      local offset = utf8.offset(inputString, MAX + 1)
      return string.sub(inputString, 1, offset - 1) .. "^gray;...", is_long, true
  else
      return inputString, is_long, false
  end
end

--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0

  self.drawnMessageIndexes = filterMessages(self.messages)
  
  local function isInsideChat(message, messageOffset, addSpacing, canvasSize)
    return (self.chatMode == "modern" and message.avatar) and (messageOffset + message.height + addSpacing >= 0 and messageOffset <= canvasSize[2]) 
      or (messageOffset + message.height >= 0 and messageOffset <= canvasSize[2])
  end


  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    local messageMode = message.mode

    if not message.nickname then
      message.nickname = "Unknown"
    end
    
    -- If the message should contain an avatar and name:
    local prevDrawnMessage = self.messages[self.drawnMessageIndexes[i - 1]]
    message.avatar = i == 1 or (message.connection ~= prevDrawnMessage.connection or message.mode ~= prevDrawnMessage.mode or message.nickname ~= prevDrawnMessage.nickname or message.portrait ~= prevDrawnMessage.portrait)

    -- Get amount of lines in the message and its length
    local labelToCheck = self.chatMode == "modern" and "totallyFakeLabelFullMode" or "totallyFakeLabelCompactMode"
    local text = self.chatMode == "modern" and message.text or createNameForCompactMode(message.nickname, self.config.modeColors[messageMode] or self.config.modeColors.default, message.text, message.time, self.config.textColors.time)

    if self.maxCharactersAllowed ~= 0 then
      local toCheckLength = message.collapsed == nil and true or message.collapsed
      text, message.isLong, message.collapsed = cutStringFromEnd(toCheckLength, text, self.maxCharactersAllowed)
    else
      message.collapsed = nil
    end

    widget.setText(labelToCheck, text)
    local sizeOfText = widget.getSize(labelToCheck)
    if not sizeOfText then return end 
    message.n_lines = (sizeOfText[2] + self.config.spacings.lines) // (self.config.fontSize + self.config.spacings.lines)
    message.height = sizeOfText[2]
    widget.setText(labelToCheck, "")

    -- Calculate message offset
    local messageOffset = self.lineOffset * (self.config.fontSize + self.config.spacings.lines)

    if i ~= #self.drawnMessageIndexes then
      messageOffset = self.messages[self.drawnMessageIndexes[i + 1]].offset + self.messages[self.drawnMessageIndexes[i + 1]].height + self.config.spacings.messages
    end


    -- Draw the actual message unless it's outside of drawing area
    if self.chatMode == "modern" then
      if isInsideChat(message, messageOffset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
        local size = portraitSizeFromBaseFont(self.config.fontSize)
        local nameOffset = vec2.add(self.config.nameOffset, {size, size})
        
        self.canvas:drawText(text, {
          position = {nameOffset[1], messageOffset},
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
        }, self.config.fontSize, self.config.textColors[messageMode] or self.config.textColors.default)

        if message.avatar then
          local offset = {0, messageOffset + self.config.textOffsetFullMode[2] + message.height - self.config.fontSize}
          self:drawIcon(message.portrait, message.nickname, offset, self.config.modeColors[messageMode], message.time, message.recepient)
          message.height = message.height + self.config.spacings.name + self.config.fontSize + 1
        end
      end
    
    else -- compact mode
      if isInsideChat(message, messageOffset, 0, self.canvas:size()) then
        local offset = vec2.add(self.config.textOffsetCompactMode, {0, messageOffset})
        self.canvas:drawText(text, {
          position = offset,
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
        }, self.config.fontSize, self.config.textColors[messageMode] or self.config.textColors.default)

        if message.avatar then
          local squareSize = self.config.modeIndicatorSize
          local iconOffset = vec2.add(offset, {-1, message.height + self.config.spacings.name - 1})
          self.canvas:drawRect({iconOffset[1], iconOffset[2], iconOffset[1] + squareSize, iconOffset[2] - self.config.fontSize + 2}, self.config.modeColors[messageMode])
        end
      end
    end
    
    message.offset = messageOffset
    self.totalHeight = self.totalHeight + message.height
    self.messages[self.drawnMessageIndexes[i]] = message
  end
end