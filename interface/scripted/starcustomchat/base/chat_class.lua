--[[
  Chat Class instance

  TODO:
    6. Set avatar: image
]]

require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"


StarCustomChat = {
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

StarCustomChat.__index = StarCustomChat

function StarCustomChat:create (canvasWid, highlightCanvasWid, commandPreviewWid, config, playerId, messages, 
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
  

  o.isOSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  o.colorTable = root.getConfiguration("scc_custom_colors") or {}
  return o
end

function StarCustomChat:addMessage(msg)
  function formatMessage(message)

    if message.mode == "RadioMessage" and message.portrait then
      message.portrait = message.portrait .. self.config.radioMessageCropDirective
    end
    message.time = message.time or (message.nickname and message.nickname:match("%^%a+;(%d+:%d+)%^reset;")) or message.text:match("%^%a+;(%d+:%d+)%^reset;")

    message = self.callbackPlugins("formatIncomingMessage", message)

    if not message or ((not message.text or message.text == "") and not message.image) then return nil end

    if not message.nickname then
      message.nickname = "Unknown"
    end

    if not message.portrait or message.portrait == '' then
      message.portrait = self.config.icons.unknown
    end

    if not message.text or message.text == "" and not message.image then return nil end

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
          message.recipient = self.lastWhisper.recipient
          self.lastWhisper = nil
        else
          if message.nickname ~= player.name() then
            if type(self.config.notificationSound) == "table" then
              pane.playSound(self.config.notificationSound[math.random(1, #self.config.notificationSound)])
            else
              pane.playSound(self.config.notificationSound)
            end
          end
        end
      end

      self:requestPortrait(message.connection)
      
    end
    return message
  end

  if msg.connection then
    msg.uuid = util.hashString(msg.connection .. (msg.text or ""))
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

function StarCustomChat:getColor(type)
  return self.colorTable[type] and "#" .. self.colorTable[type] or self.config.defaultColor
end

function StarCustomChat:findMessageByUUID(uuid)
  for i = #self.messages, 1, -1 do 
    if self.messages[i].uuid and self.messages[i].uuid == uuid then 
      return i 
    end
  end
end

function StarCustomChat:replaceUUID(oldUUID, newUUID)
  if oldUUID and newUUID then
    local oldMessageInd = self:findMessageByUUID(oldUUID)
    for i, message in ipairs(self.messages) do 
      if message.replyUUID == oldUUID then
        self.messages[i].replyUUID = newUUID
      end
    end
    self.messages[oldMessageInd].uuid = newUUID
  end
end

function StarCustomChat:deleteMessage(uuid)
  local ind = self:findMessageByUUID(uuid)
  if ind then
    table.remove(self.messages, ind)
    self:processQueue()
  end
end

function StarCustomChat:setSubMenuTexts(hint, text)
  widget.setText("lytSubMenu.lblHint", hint)
  widget.setPosition("lytSubMenu.lblText", vec2.add(widget.getPosition("lytSubMenu.lblHint"), {widget.getSize("lytSubMenu.lblHint")[1] + 3, 0}))
  widget.setText("lytSubMenu.lblText", text)
end

function StarCustomChat:openSubMenu(type, hint, text)
  if not widget.active("lytSubMenu") then
    local size = {0, widget.getSize("lytSubMenu")[2]}
    widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), size))
    widget.setPosition("cnvChatCanvas", vec2.add(widget.getPosition("cnvChatCanvas"), size))
    widget.setPosition("cnvHighlightCanvas", vec2.add(widget.getPosition("cnvHighlightCanvas"), size))
  else
    self.callbackPlugins("onSubMenuReopen", type)
  end
  self:setSubMenuTexts(hint, text)
  widget.setVisible("lytSubMenu", true)
end

function StarCustomChat:closeSubMenu()
  if widget.active("lytSubMenu") then
    widget.setVisible("lytSubMenu", false)
    local size = {0, widget.getSize("lytSubMenu")[2]}
    widget.setPosition("lytCommandPreview", vec2.sub(widget.getPosition("lytCommandPreview"), size))
    widget.setPosition("cnvChatCanvas", vec2.sub(widget.getPosition("cnvChatCanvas"), size))
    widget.setPosition("cnvHighlightCanvas", vec2.sub(widget.getPosition("cnvHighlightCanvas"), size))
  end
end

function StarCustomChat:requestPortrait(connection)
  local entityId = connection * -65536
  local uuid = world.entityUniqueId(entityId) or self.connectionToUuid[tostring(connection)]

  if uuid and not self.savedPortraits[uuid] then
    if entityId and world.entityExists(entityId) then
      promises:add(world.sendEntityMessage(entityId, "icc_request_player_portrait"), function(data)
        self.savedPortraits[data.uuid] = {
          portrait = starcustomchat.utils.clearPortraitFromInvisibleLayers(data.portrait),
          cropArea = data.cropArea,
          settings = data.settings
        }
        self.connectionToUuid[tostring(connection)] = uuid
        self:processQueue()
      end, function()
        self.connectionToUuid[tostring(connection)] = uuid
        self.savedPortraits[uuid] = {
          portrait = world.entityExists(entityId) and starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(entityId, "full")) or {},
          settings = {
            offset = self.config.defaultPortraitOffset,
            scale = self.config.defaultPortraitScale
          }
        }
        self:processQueue()
      end)
    end
  end
end

function StarCustomChat:updatePortrait(data)
  self.savedPortraits[data.uuid] = data
  self.savedPortraits[data.uuid].portrait = starcustomchat.utils.clearPortraitFromInvisibleLayers(self.savedPortraits[data.uuid].portrait)

  self.connectionToUuid[tostring(data.connection)] = data.uuid
  self:processQueue()
end

function StarCustomChat:clearHistory()
  self.messages = jarray()
  self:processQueue()
end

function StarCustomChat:resetChat()
  local newChatSize = root.getConfiguration("icc_font_size") or self.config.fontSize
  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0
  local newChatMode = root.getConfiguration("iccMode") or "modern"
  
  if newChatSize ~= self.config.fontSize or maxCharactersAllowed ~= self.maxCharactersAllowed or self.chatMode ~= newChatMode then
    self.recalculateHeight = true
  end

  self.chatMode = newChatMode
  self.config.fontSize = newChatSize
  self.maxCharactersAllowed  = maxCharactersAllowed
  self.colorTable = root.getConfiguration("scc_custom_colors") or {}
  widget.setFontColor("tbxInput", self:getColor("chattext"))

  if player.uniqueId() and player.id() and self.savedPortraits[player.uniqueId()] then
    self.savedPortraits[player.uniqueId()] = {
      portrait = player.getProperty("icc_custom_portrait") or starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
      settings = player.getProperty("icc_portrait_settings") or {
        offset = self.config.defaultPortraitOffset,
        scale = self.config.defaultPortraitScale
      }
    }
  end

  self:processQueue()
end

function StarCustomChat:getMessages ()
  return self.messages
end

function StarCustomChat:processCommand(text)
  if not self.callbackPlugins("onProcessCommand", text) then
    local commandResult = chat.command(text) or {}

      for _, line in ipairs(commandResult) do 
        if self.isOSB then
          self:addMessage({
            connection = 0,
            mode = "CommandResult",
            text = line
          })
        else
          chat.addMessage(line)
          table.insert(self.messages, {
            text = line
          })
          if #self.messages > self.config.chatHistoryLimit then
            table.remove(self.messages, 1)
          end
        end
    end
  end
end

function StarCustomChat:sendMessage(text, mode)
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

function StarCustomChat:previewCommands(commands, selected)
  self.commandPreviewCanvas:clear()

  local result = ""
  for i, command in ipairs(commands) do 
    result = result .. "^" .. (i == selected and self:getColor(command.color or "commandselecttext") or self:getColor("chattext")) .. ";" .. command.name .. " "
  end

  self.commandPreviewCanvas:drawText(result, {
    position = {0, 0},
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "bottom" -- top, mid, bottom
  }, self.config.previewCommandFontSize)
end

function StarCustomChat:drawIcon(target, nickname, messageOffset, color, time, recipient)
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

  local function drawPortrait(portrait, messageOffset, cropArea, portraitSettings, color)
    local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    local size = portraitSizeFromBaseFont(self.config.fontSize)

    if type(portrait) == "string" then
      drawImage(portrait, offset)
    else
      for _, layer in ipairs(portrait) do
        if portraitSettings then
          local currentScale = portraitSettings.scale * (size / 70)
          local currentOffset = vec2.floor(vec2.mul(portraitSettings.offset, (size / 70)))
          local imageSize = root.imageSize(layer.image)
  
          -- This monstrocity exists because drawImageRect can't be fixed
          local imageOffset = {0, 0}
  
          local cropX1, cropX2, cropY1, cropY2 = 0, imageSize[1], 0, imageSize[2]
          
          if portraitSettings.scale > 1 then
            cropX2 = 70 // portraitSettings.scale
            cropY2 = 70 // portraitSettings.scale
          end
  
          if portraitSettings.offset[1] > 0 then
            imageOffset[1] = portraitSettings.offset[1] / portraitSettings.scale
            cropX2 = math.floor(cropX2 - portraitSettings.offset[1] / portraitSettings.scale)
          else
            cropX1 = - portraitSettings.offset[1] // portraitSettings.scale
            cropX2 = math.min(math.floor(cropX2 - portraitSettings.offset[1] / portraitSettings.scale), imageSize[2])
          end
  
          if portraitSettings.offset[2] > 0 then
            imageOffset[2] = portraitSettings.offset[2] / portraitSettings.scale
            cropY2 = math.floor(cropY2 - portraitSettings.offset[2] / portraitSettings.scale)
          else
            cropY1 = - portraitSettings.offset[2] // portraitSettings.scale
            cropY2 = math.min(math.floor(cropY2 - portraitSettings.offset[2] / portraitSettings.scale), imageSize[2])
          end
  
          if (cropX2 - cropX1 > 0 and cropY2 - cropY1 > 0) then
            self.canvas:drawImage(layer.image .. string.format("?crop;%d;%d;%d;%d", 
                cropX1, 
                cropY1, 
                cropX2, 
                cropY2
              ), 
              vec2.add(offset, imageOffset), currentScale)
          end
        else
          self.canvas:drawImageRect(layer.image, cropArea or self.config.portraitCropArea, {offset[1], offset[2], offset[1] + size, offset[2] + size})
        end
      end
    end
    drawModeIcon(offset)
    drawImage(self.config.icons.frame, offset)
  end



  if type(target) == "number" then
    local entityId = target * -65536

    local uuid = (world.entityExists(entityId) and world.entityUniqueId(entityId)) or self.connectionToUuid[tostring(target)]

    if uuid and self.savedPortraits[uuid] then
      drawPortrait(self.savedPortraits[uuid].portrait, messageOffset, self.savedPortraits[uuid].cropArea, self.savedPortraits[uuid].settings, color)
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

  self.canvas:drawText(recipient and "-> " .. recipient or nickname, {
    position = nameOffset,
    horizontalAnchor = "left", -- left, mid, right
    verticalAnchor = "top" -- top, mid, bottom
  }, self.config.fontSize + 1, (color or self:getColor("chattext")))

  if time then
    local timePosition = {self.canvas:size()[1] - self.config.timeOffset[1], nameOffset[2] + self.config.timeOffset[2]}
    self.canvas:drawText(time, {
      position = timePosition,
      horizontalAnchor = "right", -- left, mid, right
      verticalAnchor = "top" -- top, mid, bottom
    }, self.config.fontSize - 1, self:getColor("timetext"))
  end
end


--TODO: instead of all messages we need to look at the messages that are drawn
function StarCustomChat:offsetCanvas(offset)
  if not offset then return end
  
  if #self.drawnMessageIndexes > 0 and self.messages[self.drawnMessageIndexes[1]].offset + self.messages[self.drawnMessageIndexes[1]].height - 20 < 0 and offset < 0 then
    return
  else
    self.lineOffset = math.min(self.lineOffset + offset, 0)
    self:processQueue()    
  end
end

function StarCustomChat:scrollToMessage(ind)
  local message = self.messages[ind]
  if message and not self:isInsideChat(message, message.offset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
    self:offsetCanvas((self:selectMessage().offset - message.offset) / (self.config.spacings.name + self.config.fontSize + 1))
  end
end

  
function StarCustomChat:isInsideChat(message, messageOffset, addSpacing, canvasSize)
  return (self.chatMode == "modern" and message.avatar) and (messageOffset + message.height + addSpacing >= 0 and messageOffset <= canvasSize[2]) 
    or (messageOffset + message.height >= 0 and messageOffset <= canvasSize[2])
end

function StarCustomChat:resetOffset()
  self.lineOffset = 0
  self:processQueue()
end

function StarCustomChat:highlightMessage(message, color)
  for i = #self.drawnMessageIndexes, 1, -1 do 
    if message.uuid == self.messages[self.drawnMessageIndexes[i]].uuid then
      local y1, y2 = message.offset, message.offset + message.height + self.config.spacings.messages
      self.highlightCanvas:drawRect({2, y1, self.highlightCanvas:size()[1] - 2, y2}, color or self.config.highlightColor)
      return
    end
  end
end

function StarCustomChat:clearHighlights()
  self.highlightCanvas:clear()
end

function StarCustomChat:collapseMessage(position)
  local pos = position or self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self.messages[self.drawnMessageIndexes[i]].collapsed = not self.messages[self.drawnMessageIndexes[i]].collapsed
      self.messages[self.drawnMessageIndexes[i]].textHeight = nil
      self:processQueue()
    end
  end
end

function StarCustomChat:selectMessage(position)
  local pos = position or self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self:highlightMessage(message)
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
  local formattedString = string.format(" %s^reset;<^%s;%s^reset;>: %s", timeString, color, name, text)

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

function StarCustomChat:getTextSize(text)
  -- Get amount of lines in the message and its length
  local labelToCheck = self.chatMode == "modern" and "totallyFakeLabelFullMode" or "totallyFakeLabelCompactMode"
  widget.setText(labelToCheck, text)
  local sizeOfText = widget.getSize(labelToCheck)
  widget.setText(labelToCheck, "")
  return sizeOfText
end

function StarCustomChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0
  self.drawnMessageIndexes = filterMessages(self.messages)

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    local messageMode = message.mode

    if not message.nickname then
      message.nickname = "Unknown"
    end

    if not message.portrait or message.portrait == '' then
      message.portrait = self.config.icons.unknown
    end
    
    -- If the message should contain an avatar and name:
    local prevDrawnMessage = self.messages[self.drawnMessageIndexes[i - 1]]
    message.avatar = i == 1 or (message.connection ~= prevDrawnMessage.connection or message.mode ~= prevDrawnMessage.mode or message.nickname ~= prevDrawnMessage.nickname or message.portrait ~= prevDrawnMessage.portrait)


    local text = self.chatMode == "modern" and message.text 
      or createNameForCompactMode(message.nickname, 
        self.config.modeColors[messageMode] or self.config.modeColors.default, 
        message.text, message.time, self:getColor("timetext"))

    if self.maxCharactersAllowed ~= 0 then
      local toCheckLength = message.collapsed == nil and true or message.collapsed
      text, message.isLong, message.collapsed = cutStringFromEnd(toCheckLength, text, self.maxCharactersAllowed)
      if toCheckLength then
        message.textHeight = nil
      end
    else
      message.collapsed = nil
    end

    if not message.textHeight or self.recalculateHeight then
      local sizeOfText = message.imageSize and vec2.div(message.imageSize, 10 / self.config.fontSize) or self:getTextSize(text)

      if not sizeOfText then return end 
        message.n_lines = (sizeOfText[2] + self.config.spacings.lines) // (self.config.fontSize + self.config.spacings.lines)
        message.height = sizeOfText[2]
        message.textHeight = message.height
      else
        message.height = message.textHeight
      end

    -- Calculate message offset
    local messageOffset = self.lineOffset * (self.config.fontSize + self.config.spacings.lines)

    if i ~= #self.drawnMessageIndexes then
      messageOffset = self.messages[self.drawnMessageIndexes[i + 1]].offset + self.messages[self.drawnMessageIndexes[i + 1]].height + self.config.spacings.messages
    end

    local reactionOffset = 0

    -- Reactions
    if message.reactions and next(message.reactions) then
      local size = portraitSizeFromBaseFont(self.config.fontSize)
      local xOffset = self.chatMode == "modern" and self.config.nameOffset[1] + size or self.config.textOffsetCompactMode[1]

      local emojiStartOffset = vec2.add({xOffset, messageOffset}, self.config.emotesOffset)
      for ind, reactObj in ipairs(message.reactions) do 
        local reaction = reactObj.reaction

        self.canvas:drawImage(string.format("/emotes/%s.emote.png", reaction), 
          emojiStartOffset, 1 / 16 * self.config.fontSize)

        local myNameInd = index(reactObj.nicknames, player.name()) ~= 0 -- if we have emoted

        self.canvas:drawText(#reactObj.nicknames, {
          position = vec2.add(emojiStartOffset, {self.config.emoteNumberSpace * self.config.fontSize / 10, 0}),
          horizontalAnchor = "left", -- left, mid, right
          verticalAnchor = "bottom", -- top, mid, bottom
          wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
        }, self.config.fontSize - 1, myNameInd and "cornflowerblue" or self:getColor("chattext"))

        message.reactions[ind].position = copy(emojiStartOffset)
        emojiStartOffset[1] = emojiStartOffset[1] + self.config.emoteSpacing * self.config.fontSize / 10
      end

      reactionOffset = self.config.emotePanelHeight * self.config.fontSize / 10
      message.height = message.height + reactionOffset
    end

    -- Draw the actual message unless it's outside of drawing area
    if self.chatMode == "modern" then
      if self:isInsideChat(message, messageOffset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
        local size = portraitSizeFromBaseFont(self.config.fontSize)
        local nameOffset = vec2.add(self.config.nameOffset, {size, size})


        if message.image then
          self.canvas:drawImage(message.image, {nameOffset[1], messageOffset + reactionOffset}, 1 / 10 * self.config.fontSize)
        else
          self.canvas:drawText(text, {
            position = {nameOffset[1], messageOffset + reactionOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"))
        end



        if message.avatar then
          local offset = {0, messageOffset + self.config.textOffsetFullMode[2] + message.height - self.config.fontSize}
          self:drawIcon(message.portrait, message.nickname, offset, self.config.modeColors[messageMode], 
            message.time, message.recipient)
          message.height = message.height + self.config.spacings.name + self.config.fontSize + 1
        end
      end
    
    else -- compact mode
      if self:isInsideChat(message, messageOffset, 0, self.canvas:size()) then
        local offset = vec2.add(self.config.textOffsetCompactMode, {0, messageOffset})        
        
        if not message.image then
          self.canvas:drawText(text, {
            position = {offset[1], offset[2] + reactionOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"))

        else
          local text = createNameForCompactMode(message.nickname, 
          self.config.modeColors[messageMode] or self.config.modeColors.default, 
            "", message.time, self:getColor("timetext"))
          
          self.canvas:drawText(text, {
            position = {offset[1], offset[2] + reactionOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"))

          local nameWidth = self:getTextSize("<" .. message.nickname .. ">: ")
          self.canvas:drawImage(message.image, {offset[1] + nameWidth[1], offset[2] + reactionOffset}, 1 / 10 * self.config.fontSize)
        end

        if message.avatar then
          local squareSize = self.config.modeIndicatorSize
          local iconOffset = vec2.add(offset, {-1, message.height + self.config.spacings.name - 1})
          self.canvas:drawRect({iconOffset[1], iconOffset[2], iconOffset[1] + squareSize, iconOffset[2] - self.config.fontSize + 2}, self.config.modeColors[messageMode])
        end
      end
    end

    local replyOffset = 0
    local prevMessage = message.replyUUID and self:findMessageByUUID(message.replyUUID)
    if prevMessage then
      replyOffset = self.config.replyOffsetHeight * self.config.fontSize / 10

      local size = portraitSizeFromBaseFont(self.config.fontSize)
      local xOffset = self.chatMode == "modern" and self.config.nameOffset[1] + size or self.config.textOffsetCompactMode[1]

      local replyStartOffset = vec2.add({xOffset, messageOffset + message.height}, self.config.replyImageOffset)
      self.canvas:drawImage("/interface/scripted/starcustomchat/plugins/reply/reply.png", 
        replyStartOffset, 1 / 8 * self.config.fontSize)
        
      self.canvas:drawText(string.format("%s: %s", self.messages[prevMessage].nickname, starcustomchat.utils.cropMessage(self.messages[prevMessage].text, self.canvas:size()[1] // 10) ), {
        position = vec2.add(replyStartOffset, {size / 2, 0}),
        horizontalAnchor = "left", -- left, mid, right
        verticalAnchor = "bottom" -- top, mid, bottom
      }, self.config.fontSize / 1.2, self:getColor("replytext"))
        
      message.height = message.height + replyOffset
    end
    
    message.offset = messageOffset
    self.totalHeight = self.totalHeight + message.height
    self.messages[self.drawnMessageIndexes[i]] = message
  end

  self.recalculateHeight = nil
end