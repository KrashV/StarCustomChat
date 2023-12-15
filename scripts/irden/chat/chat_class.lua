--[[
  Chat Class instance

  TODO:
    2. Store chat messages
    3. Handle Irden-Specific messages
    5. Showcase commands
    6. Set avatar: image and offset
    7. Whisper should show the author / recepient
    8. On message receive play a sound
    9. Collapse long messages
    10. Time on message
    11. Weather
    12. Fight chat
]]

require "/scripts/irden/chat/message_class.lua"
require "/scripts/vec2.lua"
require "/interface/scripted/irdencustomchat/icchatutils.lua"


IrdenChat = {
  messages = jarray(),
  drawnMessageIndexes = jarray(),
  author = 0,
  lineOffset = 0,
  stagehandType = "",
  canvas = nil,
  highlightCanvas = nil,
  commandPreviewCanvas = nil,
  totalHeight = 0,
  config = {},
  expanded = false,
  chatMode = "full",
  savedPortraits = {},
  connectionToUuid = {},
  proximityRadius = 100,

  queueTimer = 0.5,
  queueTime = 0,
  lastWhisper = nil
}

IrdenChat.__index = IrdenChat

function IrdenChat:create (canvasWid, highlightCanvasWid, commandPreviewWid, stagehandType, config, playerId, messages, chatMode, proximityRadius, expanded, savedPortraits, connectionToUuid, lineOffset)
  local o = {}
  setmetatable(o, self)
  self.__index = self

  o.messages = messages
  o.stagehandType = stagehandType
  o.author = playerId
  o.canvas = widget.bindCanvas(canvasWid)
  o.highlightCanvas = widget.bindCanvas(highlightCanvasWid)
  o.commandPreviewCanvas = widget.bindCanvas(commandPreviewWid)
  o.config = config
  o.chatMode = chatMode
  o.proximityRadius = proximityRadius
  o.expanded = expanded
  o.savedPortraits = savedPortraits or {}
  o.connectionToUuid = connectionToUuid or {}
  o.lineOffset = lineOffset or 0
  return o
end

function IrdenChat:addMessage(msg)

  function formatMessage(message)
    local text = message.text
    
    if message.connection == 0 then

      local fightPattern = "^%[%^red;(.-)%^reset;%]"
      local discordPattern = "<%^orange;(.-)%^reset;> (.+)$"

      local ismCurrentRollMode = player.getProperty("icc_current_roll_mode") or ""
      if string.find(text, "%[%^orange;DC%^reset;%]") then
        local username, restOfText = string.match(text, discordPattern)
  
        if username and restOfText then
          message.mode = "Broadcast"
          message.nickname = username
          message.text = restOfText
          message.portrait = self.config.icons.discord
        end
      elseif player.hasActiveQuest(self.config.fightQuestName) and player.getProperty("irdenfightName") and string.match(text, fightPattern) and ismCurrentRollMode == "Fight" then 
        local fightName = player.getProperty("irdenfightName")
        -- Use string.match to extract the text
        local result = string.match(text, fightPattern)
        
        if result and fightName == result then
          message.mode = "Fight"
          message.nickname = fightName
          message.portrait = self.config.icons.fight
        end
      else
        for substr, settings in pairs(self.config.serverTextSpecific) do 
          if string.find(text, substr) then
            if settings.icon then
              message.portrait = settings.icon
            end
            if settings.nickname then
              message.nickname = icchat.utils.getTranslation(settings.nickname)
            end
            break
          end
        end
      end
    else

      if message.mode == "Whisper" and self.lastWhisper and message.text == self.lastWhisper.text then
        message.nickname = string.format("%s -> %s", message.nickname, self.lastWhisper.recepient)
        self.lastWhisper = nil
      end

      local entityId = message.connection * -65536
      local uuid = world.entityUniqueId(entityId) or self.connectionToUuid[tostring(message.connection)]

      if uuid and not self.savedPortraits[uuid] then
        if entityId and world.entityExists(entityId) and world.entityPortrait(entityId, "full") then
          self.connectionToUuid[tostring(message.connection)] = uuid
          self.savedPortraits[uuid] = {
            portrait = world.entityPortrait(entityId, "full"),
            cropArea = self.config.portraitCropArea
          }
          self:processQueue()
        end
        icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_requestAsyncPortrait", {entityId= entityId, author = player.id() })
      else
        icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_requestAsyncPortrait", {entityId= entityId, author = player.id() })
      end
      
    end
    return message
  end

  if msg.connection then
    msg = formatMessage(msg)
    table.insert(self.messages, msg)
    if #self.messages > self.config.chatHistoryLimit then
      table.remove(self.messages, 1)
    end
  end

  self:processQueue()
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
  localeChat()
  self.chatMode = root.getConfiguration("iccMode") or "full"
  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or 100
  icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_savePortrait", {
    entityId = player.id(),
    portrait = nil,
    cropArea = player.getProperty("icc_portrait_frame",  self.config.portraitCropArea)
  })
  self:processQueue()
end

function IrdenChat:getMessages ()
  return self.messages
end

function IrdenChat:processCommand(text)
  local test = chat.command(text)
  for _, line in ipairs(test) do 
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
    fight = player.getProperty("irdenfightName") or nil,
    proximityRadius = self.proximityRadius,
    nickname = player.name()
  }

  if mode == "Broadcast" or mode == "Local" or mode == "Party" then
    chat.send(data.text, mode)
  elseif mode == "Proximity" or mode == "Fight" then
    icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_sendMessage", data)
    player.say(text)
  end
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
  }, self.config.font.previewCommandSize)
end

function IrdenChat:drawIcon(target, nickname, messageOffset, color, mode)
  local function drawModeIcon(offset)
    local frameSize = root.imageSize(self.config.icons.frame)
    local squareSize = self.config.modeIndicatorSize
    self.canvas:drawRect({offset[1] + frameSize[1] - squareSize , offset[2] + frameSize[1] - squareSize , offset[1] + frameSize[1] - 1, offset[2] + frameSize[1] - 1}, color)
  end

  local function drawImage(image, offset)
    local frameSize = root.imageSize(image)

    self.canvas:drawImageRect(image, {0, 0, frameSize[1], frameSize[2]}, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[2]})
  end

  local function drawPortrait(portrait, messageOffset, cropArea, color)
    local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)

    for _, layer in ipairs(portrait) do
      self.canvas:drawImageRect(layer.image, cropArea or self.config.portraitCropArea, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[2]})
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
  
  self.canvas:drawText(icchat.utils.cleanNickname(nickname), {
    position = vec2.add(self.config.nameOffset, messageOffset),
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "bottom" -- top, mid, bottom
  }, self.config.font.nameSize, (color or self.config.colors.default))
end


--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:offsetCanvas(offset)
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


function IrdenChat:selectMessage()
  local pos = self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
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
    if mode == "Party" or mode == "Whisper" or mode == "Fight"
      or (mode == "Local" and widget.getChecked("btnCkLocal")) 
      or (mode == "Broadcast" and widget.getChecked("btnCkBroadcast")) 
      or (mode == "Proximity" and widget.getChecked("btnCkProximity"))
      or (mode == "RadioMessage" and widget.getChecked("btnCkRadioMessage"))
      or (mode == "CommandResult" and widget.getChecked("btnCkCommandResult"))
    then
      table.insert(drawnMessageIndexes, i)
    end
  end
  return drawnMessageIndexes
end

function createNameForCompactMode(name, color, text)
  return "<^" .. color .. ";" .. icchat.utils.cleanNickname(name) .."^reset;>: "  .. text
end

--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0

  self.drawnMessageIndexes = filterMessages(self.messages)
  
  local function isInsideChat(message, messageOffset, addSpacing, canvasSize)
    return (self.chatMode == "full" and message.avatar) and (messageOffset + message.height + addSpacing >= 0 and messageOffset <= canvasSize[2]) 
      or (messageOffset + message.height >= 0 and messageOffset <= canvasSize[2])
  end


  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    local messageMode = message.mode

    local icon
    local name
    if messageMode == "CommandResult" then
      icon = self.config.icons.console
      name = "Console"         
    elseif messageMode == "RadioMessage" then
      icon = message.portrait or "/ai/portraits/humanportrait.png:idle"
      name = message.nickname or "Server"
    elseif messageMode == "Whisper" or messageMode == "Proximity" or messageMode == "Local" or messageMode == "Broadcast" or messageMode == "Party" or messageMode == "Fight" then
      if message.connection == 0 then
        icon = message.portrait or self.config.icons.server
        name = message.nickname or "Server"
      else
        icon = message.portrait ~= "" and message.portrait or message.connection
        name = message.nickname
      end
    end

    -- If the message should contain an avatar and name:
    local prevDrawnMessage = self.messages[self.drawnMessageIndexes[i - 1]]
    message.avatar = i == 1 or (message.connection ~= prevDrawnMessage.connection or message.mode ~= prevDrawnMessage.mode or message.nickname ~= prevDrawnMessage.nickname)

    -- Get amount of lines in the message and its length
    local labelToCheck = self.chatMode == "full" and "totallyFakeLabelFullMode" or "totallyFakeLabelCompactMode"
    local text = self.chatMode == "full" and message.text or createNameForCompactMode(name, self.config.nameColors[messageMode] or self.config.nameColors.default, message.text)
    widget.setText(labelToCheck, text)
    local sizeOfText = widget.getSize(labelToCheck)
    message.n_lines = (sizeOfText[2] + self.config.spacings.lines) // (self.config.font.baseSize + self.config.spacings.lines)
    message.height = sizeOfText[2]
    widget.setText(labelToCheck, "")

    -- Calculate message offset
    local messageOffset = self.lineOffset * (self.config.font.baseSize + self.config.spacings.lines)

    if i ~= #self.drawnMessageIndexes then
      messageOffset = self.messages[self.drawnMessageIndexes[i + 1]].offset + self.messages[self.drawnMessageIndexes[i + 1]].height + self.config.spacings.messages
    end

    local offset = {0, messageOffset + message.height + self.config.spacings.name}


    -- Draw the actual message unless it's outside of drawing area
    if self.chatMode == "full" then
      if isInsideChat(message, messageOffset, self.config.spacings.name + self.config.font.nameSize, self.canvas:size()) then
        self.canvas:drawText(message.text, {
          position = vec2.add(self.config.textOffsetFullMode, {0, messageOffset}),
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
        }, self.config.font.baseSize, self.config.colors[messageMode] or self.config.colors.default)

        if message.avatar then
          self:drawIcon(icon, name, offset, self.config.nameColors[messageMode], messageMode)
          message.height = message.height + self.config.spacings.name + self.config.font.nameSize
        end
      end
    
    else -- compact mode
      if isInsideChat(message, messageOffset, 0, self.canvas:size()) then
        self.canvas:drawText(createNameForCompactMode(name, self.config.nameColors[messageMode] or self.config.nameColors.default, message.text), {
          position = vec2.add(self.config.textOffsetCompactMode, {0, messageOffset}),
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
        }, self.config.font.baseSize, self.config.colors[messageMode] or self.config.colors.default)
      end
    end
    
    message.offset = messageOffset
    self.totalHeight = self.totalHeight + message.height
    self.messages[self.drawnMessageIndexes[i]] = message
  end
end