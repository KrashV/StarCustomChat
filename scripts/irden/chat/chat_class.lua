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
  messages = {},
  drawnMessages = {},
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
  entityToUuid = {},
  proximityRadius = 100,

  queueTimer = 0.5,
  queueTime = 0
}

IrdenChat.__index = IrdenChat

function IrdenChat:create (canvasWid, highlightCanvasWid, commandPreviewWid, stagehandType, config, playerId, messages, chatMode, proximityRadius)
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

  return o
end

function IrdenChat:createMessageQueue()
  -- Local promise chain to retrieve incoming messages

  -- Create fake RPCPromise. Basically wait until we are able to find ourselves again lmao
  local fakePromise = {
    succeeded = function()
      return world.entityExists(player.id())
    end,
    finished = function()
      return true
    end,
    result = function() end,
    error = function() end,
    onSuccess = addMessagesToQueue,
    onError = function() promises:add(fakePromise) end
  }

  function formatMessage(message)
    local text = message.text
    
    if message.connection == 0 then
      local fightPattern = "^%[%^red;(.-)%^reset;%]"
      local discordPattern = "<%^orange;(.-)%^reset;> (.+)$"
  
      if message.mode == "RadioMessage" then message.mode = "Broadcast" end

      if string.find(text, "%[%^orange;DC%^reset;%]") then
        local username, restOfText = string.match(text, discordPattern)
  
        if username and restOfText then
          message.mode = "Broadcast"
          message.nickname = username
          message.text = restOfText
          message.portrait = self.config.icons.discord
        end
      elseif player.hasActiveQuest(self.config.fightQuestName) and player.getProperty("irdenfightName") and string.match(text, fightPattern) then 
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
      local entityId = message.connection * -65536
      local uuid = world.entityUniqueId(entityId)

      if uuid and not self.savedPortraits[uuid] then
        if entityId and world.entityExists(entityId) and world.entityPortrait(entityId, "full") then
          self.entityToUuid[entityId] = uuid
          self.savedPortraits[uuid] = {
            portrait = world.entityPortrait(entityId, "full"),
            cropArea = self.config.portraitCropArea
          }
          self:processQueue()
        end
      end
      icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_requestPortrait", entityId, function(data) 
        if data then
          self.savedPortraits[data.uuid] = data
          self.entityToUuid[entityId] = data.uuid
          self:processQueue()
        end
      end)
    end
    return message
  end



  local function addMessagesToQueue(queue)
    self.queueTime = 0
    if queue then
      for _, msg in ipairs(queue) do
        if type(msg) == "string" then
          if msg == "RESET_CHAT" then
            localeChat()
            self.chatMode = root.getConfiguration("iccMode") or "full"
            self.proximityRadius = root.getConfiguration("icc_proximity_radius") or 100
            icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_savePortrait", {
              entityId = player.id(),
              portrait = nil,
              cropArea = player.getProperty("icc_portrait_frame",  self.config.portraitCropArea)
            })
          elseif msg == "CLEAR_HISTORY" then
            self.messages = {}
          end
        else
          msg = formatMessage(msg)
          table.insert(self.messages, msg)
          if #self.messages > self.config.chatHistoryLimit then
            table.remove(self.messages, 1)
          end
        end
        self:processQueue()
      end
    end
    
    if world.entityExists(player.id()) then
      promises:add(world.sendEntityMessage(player.id(), "icc_getMessageQueue"), addMessagesToQueue)
    else
      promises:add(fakePromise, addMessagesToQueue)
    end
  end

  if world.entityExists(player.id()) then
    promises:add(world.sendEntityMessage(player.id(), "icc_getMessageQueue"), addMessagesToQueue)
  else
    promises:add(fakePromise, addMessagesToQueue)
  end
end

-- Wheck that we run the queue at least once per second
function IrdenChat:checkMessageQueue(dt)
  self.queueTime = self.queueTime + dt 

  if self.queueTime > self.queueTimer then
    self:createMessageQueue()
    self.queueTime = 0
  end
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

function IrdenChat:drawIcon(target, nickname, messageOffset, color)
  local function drawImage(image, offset)
    local frameSize = root.imageSize(image)

    self.canvas:drawImageRect(image, {0, 0, frameSize[1], frameSize[2]}, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[2]})
  end

  local function drawPortrait(portrait, messageOffset, cropArea)
    local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    for _, layer in ipairs(portrait) do
      self.canvas:drawImageRect(layer.image, cropArea or self.config.portraitCropArea, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[2]})
    end
    drawImage(self.config.icons.frame, offset)
  end

  if type(target) == "number" then
    local entityId = target * -65536

    if self.entityToUuid[entityId] and self.savedPortraits[self.entityToUuid[entityId]] then
      drawPortrait(self.savedPortraits[self.entityToUuid[entityId]].portrait, messageOffset, self.savedPortraits[self.entityToUuid[entityId]].cropArea)
    else
      local offset = vec2.add(self.config.iconImageOffset, messageOffset)
      drawImage(self.config.icons.empty, offset)
      drawImage(self.config.icons.unknown, offset)
      drawImage(self.config.icons.frame, offset)
    end
  elseif type(target) == "string" then
    local offset = vec2.add(self.config.iconImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    drawImage(target, offset)
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
  if #self.drawnMessages > 0 and self.drawnMessages[1].offset + self.drawnMessages[1].height - 20 < 0 and offset < 0 then
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
  for i = #self.drawnMessages, 1, -1 do 
    local message = self.drawnMessages[i]
    if pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self:highlightMessage(message.offset, message.offset + message.height + self.config.spacings.messages)
    end
  end
end

function filterMessages(messages)
  local drawnMessages = {}

  for _, message in ipairs(messages) do 
    --filter messages by mode availability
    local mode = message.mode
    if mode == "CommandResult" or mode == "Party" or mode == "Whisper" or mode == "RadioMessage" or mode == "Fight"
      or (mode == "Local" and widget.getChecked("btnCkLocal")) 
      or (mode == "Broadcast" and widget.getChecked("btnCkBroadcast")) 
      or (mode == "Proximity" and widget.getChecked("btnCkProximity"))
    then
      table.insert(drawnMessages, message)
    end
  end
  return drawnMessages
end

function createNameForCompactMode(name, color, text)
  return "<^" .. color .. ";" .. icchat.utils.cleanNickname(name) .."^reset;>: "  .. text
end

--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0
  self.drawnMessages = filterMessages(self.messages)

  local function isInsideChat(message, messageOffset, addSpacing, canvasSize)
    return (self.chatMode == "full" and message.avatar) and (messageOffset + message.height + addSpacing >= 0 and messageOffset <= canvasSize[2]) 
      or (messageOffset + message.height >= 0 and messageOffset <= canvasSize[2])
  end


  for i = #self.drawnMessages, 1, -1 do 
    local message = self.drawnMessages[i]
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
    self.drawnMessages[i].avatar = i == 1 or (message.connection ~= self.drawnMessages[i-1].connection or message.mode ~= self.drawnMessages[i-1].mode or message.nickname ~= self.drawnMessages[i-1].nickname)

    -- Get amount of lines in the message and its length
    local labelToCheck = self.chatMode == "full" and "totallyFakeLabelFullMode" or "totallyFakeLabelCompactMode"
    local text = self.chatMode == "full" and message.text or createNameForCompactMode(name, self.config.nameColors[messageMode] or self.config.nameColors.default, message.text)
    widget.setText(labelToCheck, text)
    local sizeOfText = widget.getSize(labelToCheck)
    self.drawnMessages[i].n_lines = (sizeOfText[2] + self.config.spacings.lines) // (self.config.font.baseSize + self.config.spacings.lines)
    self.drawnMessages[i].height = sizeOfText[2]
    widget.setText(labelToCheck, "")

    -- Calculate message offset
    local messageOffset = self.lineOffset * (self.config.font.baseSize + self.config.spacings.lines)

    if i ~= #self.drawnMessages then
      messageOffset = self.drawnMessages[i + 1].offset + self.drawnMessages[i + 1].height + self.config.spacings.messages
    end

    local offset = {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}


    -- Draw the actual message unless it's outside of drawing area
    if self.chatMode == "full" then
      if isInsideChat(self.drawnMessages[i], messageOffset, self.config.spacings.name + self.config.font.nameSize, self.canvas:size()) then
        self.canvas:drawText(message.text, {
          position = vec2.add(self.config.textOffsetFullMode, {0, messageOffset}),
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
        }, self.config.font.baseSize, self.config.colors[messageMode] or self.config.colors.default)

        if self.drawnMessages[i].avatar then
          self:drawIcon(icon, name, offset, self.config.nameColors[messageMode])
          self.drawnMessages[i].height = self.drawnMessages[i].height + self.config.spacings.name + self.config.font.nameSize
        end
      end
    
    else -- compact mode
      if isInsideChat(self.drawnMessages[i], messageOffset, 0, self.canvas:size()) then
        self.canvas:drawText(createNameForCompactMode(name, self.config.nameColors[messageMode] or self.config.nameColors.default, message.text), {
          position = vec2.add(self.config.textOffsetCompactMode, {0, messageOffset}),
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
        }, self.config.font.baseSize, self.config.colors[messageMode] or self.config.colors.default)
      end
    end
    
    self.drawnMessages[i].offset = messageOffset
    self.totalHeight = self.totalHeight + self.drawnMessages[i].height
  end
end