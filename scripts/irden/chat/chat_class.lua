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
  expanded = true,
  savedPortraits = {},

  queueTimer = 1,
  queueTime = 0
}

IrdenChat.__index = IrdenChat

function IrdenChat:create (canvasWid, highlightCanvasWid, commandPreviewWid, stagehandType, config, playerId)
  local o = {}
  setmetatable(o, self)
  self.__index = self

  o.stagehandType = stagehandType
  o.author = playerId
  o.canvas = widget.bindCanvas(canvasWid)
  o.highlightCanvas = widget.bindCanvas(highlightCanvasWid)
  o.commandPreviewCanvas = widget.bindCanvas(commandPreviewWid)
  o.config = config

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


  local function addMessagesToQueue(queue)
    self.queueTime = 0
    if queue then
      for _, msg in ipairs(queue) do
        table.insert(self.messages, msg)
        if #self.messages > self.config.chatHistoryLimit then
          table.remove(self.messages, 1)
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
    nickname = player.name()
  }

  if mode == "Broadcast" or mode == "Local" or mode == "Party" then
    chat.send(data.text, mode)
  elseif mode == "Proximity" then
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
  local function cleanNickname(nick)
    return string.gsub(nick, ".*<(.*)",  "%1")
  end

  local function drawPortrait(portrait, messageOffset)
    for _, layer in ipairs(portrait) do
      local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
      self.canvas:drawImageRect(layer.image, self.config.portraitCropArea, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[1]})
    end
  end

  if type(target) == "number" then
    if world.entityExists(target) then
      local portrait = world.entityPortrait(target, "bust")
      drawPortrait(portrait, messageOffset)
      self.savedPortraits[target] = portrait
    else
      if self.savedPortraits[target] then
        drawPortrait(self.savedPortraits[target], messageOffset)
      else
        self.canvas:drawImage(self.config.icons.unknown, vec2.add(self.config.iconImageOffset, messageOffset), self.config.iconScale)
        icchat.utils.sendMessageToStagehand(self.stagehandType, "icc_requestPortrait", target, function(portrait) 
          if portrait then
            self.savedPortraits[target] = portrait
            drawPortrait(portrait, messageOffset)
          end
        end)
      end
    end
  elseif type(target) == "string" then
    local offset = vec2.add(self.config.iconImageOffset, messageOffset)
    self.canvas:drawImageRect(target, {0, 0, table.unpack(root.imageSize(target))}, {offset[1], offset[2], offset[1] + self.config.portraitSize[1], offset[2] + self.config.portraitSize[1]})
  end
  
  self.canvas:drawText(cleanNickname(nickname), {
    position = vec2.add(self.config.nameOffset, messageOffset),
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "bottom" -- top, mid, bottom
  }, self.config.font.nameSize, (color or self.config.defaultColor))
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

--TODO: instead of all messages we need to look at the messages that are drawn
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

--TODO: instead of all messages we need to look at the messages that are drawn
function IrdenChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0
  self.drawnMessages = filterMessages(self.messages)

  for i = #self.drawnMessages, 1, -1 do 
    local message = self.drawnMessages[i]
    local messageMode = message.mode
    
    local entityId = message.connection * -65536
    -- If the message should contain an avatar and name:
    self.drawnMessages[i].avatar = i == 1 or (message.connection ~= self.drawnMessages[i-1].connection or message.mode ~= self.drawnMessages[i-1].mode)

    -- Get amount of lines in the message and its length
    widget.setText("totallyFakeLabel", message.text)
    local sizeOfText = widget.getSize("totallyFakeLabel")
    self.drawnMessages[i].n_lines = (sizeOfText[2] + self.config.spacings.lines) // (self.config.font.baseSize + self.config.spacings.lines)
    self.drawnMessages[i].height = sizeOfText[2]
    widget.setText("totallyFakeLabel", "")

    -- Calculate message offset
    local messageOffset = self.lineOffset * (self.config.font.baseSize + self.config.spacings.lines)

    if i ~= #self.drawnMessages then
      messageOffset = self.drawnMessages[i + 1].offset + self.drawnMessages[i + 1].height + self.config.spacings.messages
    end

    -- Draw the actual message unless it's outside of drawing area
    if messageOffset + self.drawnMessages[i].height >= 0 and messageOffset <= self.canvas:size()[2] then
      self.canvas:drawText(message.text, {
        position = vec2.add(self.config.textOffset, {0, messageOffset}),
        horizontalAnchor = "left", -- left, mid, right
        verticalAnchor = "bottom", -- top, mid, bottom
        wrapWidth = self.config.wrapWidth -- wrap width in pixels or nil
      }, self.config.font.baseSize, self.config.colors[messageMode] or self.config.defaultColor)
    end
    
    -- If it's an avatar, draw the avatar and add it to height
    if self.drawnMessages[i].avatar then
      if messageOffset + self.drawnMessages[i].height >= 0 and messageOffset <= self.canvas:size()[2] then
        if messageMode == "CommandResult" then
          self:drawIcon(self.config.icons.console, "Console", {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.nameColors[messageMode])
        elseif messageMode == "RadioMessage" then
          self:drawIcon(message.portrait or "/ai/portraits/humanportrait.png:idle", message.nickname or "Server", {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.nameColors[messageMode])
        elseif messageMode == "Whisper" or messageMode == "Proximity" or messageMode == "Local" or messageMode == "Broadcast" or messageMode == "Party" then
          if message.connection == 0 then
            self:drawIcon(self.config.icons.server, "Server", {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.nameColors[messageMode])
          else
            self:drawIcon(message.portrait ~= "" and message.portrait or entityId, message.nickname, {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.nameColors[messageMode])
          end
        elseif messageMode == "Announcement" then
          if message.connection == 0 then
            self:drawIcon(self.config.icons.server, "Server", {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.colors[messageMode])
          else
            self:drawIcon(entityId, message.nickname, {0, messageOffset + self.drawnMessages[i].height + self.config.spacings.name}, self.config.nameColors[messageMode] )
          end
        end
      end

      self.drawnMessages[i].height = self.drawnMessages[i].height + self.config.spacings.name + self.config.font.nameSize
    end

    self.drawnMessages[i].offset = messageOffset
    self.totalHeight = self.totalHeight + self.drawnMessages[i].height

    -- Modes: "CommandResult", "Broadcast", "Whisper", "Party", "Local", "World", "RadioMessage", "Proximity"
  end
end