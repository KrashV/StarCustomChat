require "/scripts/messageutil.lua"
require "/scripts/icctimer.lua"
require "/scripts/util.lua"
require "/scripts/irden/chat/chat_class.lua"
require "/interface/scripted/irdencustomchat/icchatutils.lua"
require "/tech/doubletap.lua"

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

ICChatTimer = TimerKeeper.new()
function init()

  shared.chatIsOpen = true
  localeChat()
  self.stagehandName = "irdencustomchat"
  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.commandPreviewCanvasName = "lytCommandPreview.cnvCommandsCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]

  self.availableCommands = root.assetJson("/interface/scripted/irdencustomchat/commands.config")

  self.chatmonster = root.assetJson("/monsters/unsorted/chattingmonster/chatmonster.json")
  self.chatting = nil

  local chatConfig = config.getParameter("config")
  local expanded = config.getParameter("expanded")
  setSizes(expanded, chatConfig, config.getParameter("currentSizes"))

  self.fightQuestName = chatConfig.fightQuestName
  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.font.baseSize)
  
  self.localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", icchat.utils.getLocale()))

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())
  
  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end


  self.irdenChat = IrdenChat:create(self.canvasName, self.highlightCanvasName, self.commandPreviewCanvasName, self.stagehandName, chatConfig, player.id(), 
    storedMessages, self.chatMode, root.getConfiguration("icc_proximity_radius") or 100, expanded, config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"))
  
  self.lastCommand = root.getConfiguration("icc_last_command")
  self.contacts = {}
  self.tooltipFields = {}

  self.receivedMessageFromStagehand = false

  self.savedCommandSelection = 0

  self.sentMessages = root.getConfiguration("icc_my_messages",{}) or {}
  self.sentMessagesLimit = 15
  self.currentSentMessage = #self.sentMessages

  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

  self.DMTimer = 2
  checkDMs()
  self.irdenChat:processQueue()

  -- Debind chat opening
  removeChatBindings()

  self.doubleTap = DoubleTap:new({"iccLeftMouseButton", "iccRightMouseButton"}, chatConfig.maximumDoubleTapTime, function(doubleTappedKey)
    if doubleTappedKey == "iccRightMouseButton" then
      local message = self.irdenChat:selectMessage()
      if message then
        clipboard.setText(message.text)
        icchat.utils.alert("chat.alerts.copied_to_clipboard")
      end
    end
  end)

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    widget.setText("tbxInput", lastText)
    widget.focus("tbxInput")
  end

  local currentMessageMode = config.getParameter("currentMessageMode")
  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
  end

  registerCallbacks()

end

function registerCallbacks()
  shared.setMessageHandler("newChatMessage", localHandler(function(message)
    self.irdenChat:addMessage(message)
  end))

  shared.setMessageHandler("icc_sendToUser", simpleHandler(function(message)
    self.irdenChat:addMessage(message)
  end))

  shared.setMessageHandler("icc_is_chat_open", localHandler(function(message)
    return true
  end))

  shared.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  shared.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.irdenChat:updatePortrait(data)
  end))

  shared.setMessageHandler( "icc_reset_settings", localHandler(function(data)
    self.irdenChat:resetChat(message)
  end))

  shared.setMessageHandler( "icc_clear_history", localHandler(function(data)
    self.irdenChat:clearHistory(message)
  end))
end

function removeChatBindings()
  local bindings = root.getConfiguration("bindings")
  bindings["ChatBegin"] = jarray()
  bindings["ChatBeginCommand"] = jarray()
  bindings["ChatNextLine"] = jarray()
  bindings["ChatPageDown"] = jarray()
  bindings["ChatPageUp"] = jarray()
  bindings["ChatPreviousLine"] = jarray()
  bindings["ChatSendLine"] = jarray()
  root.setConfiguration("bindings", bindings)
end

function createTotallyFakeWidgets(wrapWidthFullMode, wrapWidthCompactMode, fontSize)
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthFullMode,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabelFullMode")
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthCompactMode,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabelCompactMode")
end

function findButtonByMode(mode)
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do 
    if button.data.mode == mode then
      return i - 2
    end
  end
  return -1
end

function localeChat()
  
  self.chatMode = root.getConfiguration("iccMode") or "full"
  self.localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", icchat.utils.getLocale()))
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do 
    widget.setText("rgChatMode." .. i - 2, icchat.utils.getTranslation("chat.modes." .. button.data.mode))
  end

  -- Unfortunately, to reset HINT we have to recreate the textbox
  local standardTbx = config.getParameter("gui")["tbxInput"]
  standardTbx.hint = icchat.utils.getTranslation("chat.textbox.hint")

  pane.removeWidget("tbxInput")
  pane.addWidget(standardTbx, "tbxInput")
end

function update(dt)
  shared.chatIsOpen = true
  ICChatTimer:update(dt)
  promises:update()
  
  self.irdenChat:clearHighlights()
  
  checkGroup()
  checkFight()
  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)

  if not player.id() or not world.entityExists(player.id()) then
    pane.dismiss()
  end
end

function checkCommandsPreview()
  local text = widget.getText("tbxInput")

  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    local availableCommands = icchat.utils.getCommands(self.availableCommands, text)

    if #availableCommands > 0 then
      self.savedCommandSelection = math.max(self.savedCommandSelection % (#availableCommands + 1), 1)
      widget.setVisible("lytCommandPreview", true)
      widget.setText("lblCommandPreview", availableCommands[self.savedCommandSelection])
      widget.setData("lblCommandPreview", availableCommands[self.savedCommandSelection])
      self.irdenChat:previewCommands(availableCommands, self.savedCommandSelection)
    else
      widget.setVisible("lytCommandPreview", false)
      widget.setText("lblCommandPreview", "")
      widget.setData("lblCommandPreview", nil)
      self.savedCommandSelection = 0
    end
  else
    widget.setVisible("lytCommandPreview", false)
    widget.setText("lblCommandPreview", "")
    widget.setData("lblCommandPreview", nil)
    self.savedCommandSelection = 0
  end
end

function checkTyping()
  if widget.hasFocus("tbxInput") then
    if self.chatting == nil then
      self.chatmonster.parentEntity = player.id()
      self.chatting = world.spawnMonster("punchy", world.entityPosition(player.id()), self.chatmonster)
    end
  else
    if self.chatting ~= nil then
      world.sendEntityMessage(self.chatting, "dieplz")
      self.chatting = nil
    end
  end
end

function checkGroup()
  local id = findButtonByMode("Party")
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", -1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
  end
end

function checkFight()
  local id = findButtonByMode("Fight")
  if not player.hasActiveQuest(self.fightQuestName) then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    if widget.getSelectedData("rgChatMode").mode == "Fight" then
      widget.setSelectedOption("rgChatMode", -1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
  end
end

function checkDMs()
  if widget.active("lytCharactersToDM") then
    populateList()
  end
  ICChatTimer:add(self.DMTimer, checkDMs)
end

function populateList()
  local function drawCharacters(players, toRemovePlayers)
    local mode = #players > 7 and "letter" or "avatar"

    local idTable = {}  -- This table will store only the 'id' values

    for _, player in ipairs(players) do
      table.insert(idTable, player.id)

      if index(self.contacts, player.id) == 0 and player.data then
        local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
        if mode == "letter" then
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", string.sub(player.name, 1, 2))
        elseif player.data.portrait then
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", player.data.portrait)
        end

        widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
          id = player.id,
          displayText = player.name
        })
        self.tooltipFields["lytCharactersToDM.saPlayers.lytPlayers." .. li] = player.name
        table.insert(self.contacts, player.id)
      end
    end


    if toRemovePlayers then
      for i, id in ipairs(self.contacts) do
        if index(idTable, id) == 0 then
          widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i - 1)
          table.remove(self.contacts, i)
        end
      end
    end
  end

  local playersAround = {}

  if player.id() and world.entityPosition(player.id()) then
    for _, player in ipairs(world.playerQuery(world.entityPosition(player.id()), 40)) do 
      table.insert(playersAround, {
        id = player,
        name = world.entityName(player),
        data = {
          portrait = world.entityPortrait(player, "full")
        }
      })
    end
  end

  drawCharacters(playersAround, not self.receivedMessageFromStagehand)


  icchat.utils.sendMessageToStagehand(self.stagehandName, "icc_getAllPlayers", _, function(players)
    self.receivedMessageFromStagehand = true
    drawCharacters(players, true)
  end)
end

function drawIcon(canvasName, args)
	local playerCanvas = widget.bindCanvas(canvasName)
  playerCanvas:clear()
  
  if type(args) == "number" then
    local playerPortrait = world.entityPortrait(args, "full")
    for _, layer in ipairs(playerPortrait) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "table" then
    for _, layer in ipairs(args) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "string" and string.len(args) == 2 then
    playerCanvas:drawText(args, {
      position = {8, 3},
      horizontalAnchor = "mid", -- left, mid, right
      verticalAnchor = "bottom", -- top, mid, bottom
      wrapWidth = nil -- wrap width in pixels or nil
    }, self.irdenChat.config.font.nameSize)
  elseif type(args) == "string" then
    playerCanvas:drawImage(args, {-1, 0})
  end
end

function getSizes(expanded, chatParameters)
  local canvasSize = widget.getSize(self.canvasName)
  local saPlayersSize = widget.getSize("lytCharactersToDM.saPlayers")
  
  local charactersListWidth = widget.getSize("lytCharactersToDM.background")[1]

  return {
    canvasSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages - 4} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages - 4},
    highligtCanvasSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages - 4} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages - 4},
    bgStretchImageSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages},
    scrollAreaSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight} or {canvasSize[1], chatParameters.bodyHeight },
    playersSaSize = expanded and {saPlayersSize[1], chatParameters.expandedBodyHeight - 15} or {saPlayersSize[1], chatParameters.bodyHeight},
    playersDMBackground = expanded and {charactersListWidth, chatParameters.expandedBodyHeight - 15} or {charactersListWidth, chatParameters.bodyHeight} 
  }
end

function setSizes(expanded, chatParameters, currentSizes)
  local defaultSizes = getSizes(expanded, chatParameters)
  widget.setSize(self.canvasName, currentSizes and currentSizes.canvasSize or defaultSizes.canvasSize)
  widget.setSize(self.highlightCanvasName, currentSizes and currentSizes.highligtCanvasSize or defaultSizes.highligtCanvasSize)
  widget.setSize("lytCharactersToDM.background", currentSizes and currentSizes.playersDMBackground or defaultSizes.playersDMBackground)
  widget.setSize("backgroundImage", currentSizes and currentSizes.bgStretchImageSize or defaultSizes.bgStretchImageSize)
  widget.setSize("saScrollArea", currentSizes and currentSizes.scrollAreaSize or defaultSizes.scrollAreaSize)
  widget.setSize("lytCharactersToDM.saPlayers", currentSizes and currentSizes.playersSaSize or defaultSizes.playersSaSize)  
end

function canvasClickEvent(position, button, isButtonDown)
  if button == 0 and isButtonDown then
    self.irdenChat.expanded = not self.irdenChat.expanded

    local chatParameters = getSizes(self.irdenChat.expanded, self.irdenChat.config)
    saveEverythingDude()
    pane.dismiss()

    local chatConfig = root.assetJson("/interface/scripted/irdencustomchat/icchatgui.json")
    chatConfig["gui"]["background"]["fileBody"] = string.format("/interface/scripted/irdencustomchat/%s.png", self.irdenChat.expanded and "body" or "shortbody") 
    chatConfig.expanded = self.irdenChat.expanded
    chatConfig.currentSizes = chatParameters
    chatConfig.lastInputMessage = widget.getText("tbxInput")
    chatConfig.portraits = self.irdenChat.savedPortraits
    chatConfig.connectionToUuid =  self.irdenChat.connectionToUuid
    chatConfig.currentMessageMode =  widget.getSelectedOption("rgChatMode")
    chatConfig.chatLineOffset = self.irdenChat.lineOffset
    chatConfig.reopened = true
    chatConfig.selectedModes = {
      btnCkBroadcast = widget.getChecked("btnCkBroadcast"),
      btnCkLocal = widget.getChecked("btnCkLocal"),
      btnCkProximity = widget.getChecked("btnCkProximity"),
      btnCkRadioMessage = widget.getChecked("btnCkRadioMessage"),
    }

    self.reopening = true
    player.interact("ScriptPane", chatConfig)
  end

  self.doubleTap:update(script.updateDt(), {iccLeftMouseButton = button == 0 and isButtonDown,
    iccRightMouseButton = button == 2 and isButtonDown})

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do 
    if event.type == "MouseWheel" and widget.inMember("backgroundImage", screenPosition) then 
      self.irdenChat:offsetCanvas(event.data.mouseWheel * -1 * (input.key("LShift") and 2 or 1))
    elseif event.type == "KeyDown" then
      if event.data.key == "PageUp" then
        self.irdenChat:offsetCanvas(self.irdenChat.expanded and - self.irdenChat.config.pageSkipExpanded or - self.irdenChat.config.pageSkip)
      elseif event.data.key == "PageDown" then
        self.irdenChat:offsetCanvas(self.irdenChat.expanded and self.irdenChat.config.pageSkipExpanded or self.irdenChat.config.pageSkip)
      end
    end
  end
end

function processButtonEvents(dt)
  if input.keyDown("Return") or input.keyDown("/") and not widget.hasFocus("tbxInput") then
    if input.keyDown("/") then
      widget.setText("tbxInput", "/")
    end
    widget.focus("tbxInput")
    chat.setInput("")
  end


  if widget.hasFocus("tbxInput") then
    for _, event in ipairs(input.events()) do 
      if event.type == "KeyDown" then
        if event.data.key == "Tab" then 
          self.savedCommandSelection = self.savedCommandSelection + 1
        elseif event.data.key == "Up" and event.data.mods and event.data.mods.LShift then
          if #self.sentMessages > 0 then
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
            self.currentSentMessage = math.max(self.currentSentMessage - 1, 1)
          end
        elseif event.data.key == "Down" and event.data.mods and event.data.mods.LShift then
          if #self.sentMessages > 0 then
            self.currentSentMessage = math.min(self.currentSentMessage + 1, #self.sentMessages)
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        end
      end
    end
  end


  if input.bindDown("icchat", "repeatcommand") and self.lastCommand then
    self.irdenChat:processCommand(self.lastCommand)
  end
end

function cursorOverride(screenPosition)
  processEvents(screenPosition)

  if widget.inMember(self.highlightCanvasName, screenPosition) then
    self.irdenChat:selectMessage()
  end
end

function blurTextbox(widgetName)
  widget.setText(widgetName, "")
  widget.blur(widgetName)
end

function sendMessage(widgetName)
  local message = widget.getText(widgetName)

  if message == "" then 
    blurTextbox(widgetName)
    return 
  end

  if string.sub(message, 1, 1) == "/" then
    if string.len(message) == 1 then
      blurTextbox(widgetName)
      return
    end

    if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" then
      widget.setText(widgetName, widget.getData("lblCommandPreview") .. " ")
      return
    else
      self.irdenChat:processCommand(message)
      self.lastCommand = message
      icchat.utils.saveMessage(message)
    end
  elseif widget.getSelectedData("rgChatMode").mode == "Whisper" then
    local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
    if not li then icchat.utils.alert("chat.alerts.dm_not_specified") return end

    local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
    if (not world.entityExists(data.id) and index(self.contacts, data.id) == 0) then icchat.utils.alert("chat.alerts.dm_not_found") return end

    local whisperName = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).displayText
    local whisper = string.find(whisperName, "%s") and "/w \"" .. whisperName .. "\" " .. message or "/w " .. whisperName .. " " .. message
    self.irdenChat:processCommand(whisper)
    self.irdenChat.lastWhisper = {
      recepient = whisperName,
      text = message
    }
    icchat.utils.saveMessage(whisper)
  else
    self.irdenChat:sendMessage(message, widget.getSelectedData("rgChatMode").mode)
    icchat.utils.saveMessage(message)
  end
  blurTextbox(widgetName)
end


function setMode(_, data)
  local modeButtons = config.getParameter("gui")["rgChatMode"]["buttons"]
  local selectedMode = -1
  for i, btn in ipairs(modeButtons) do 
    widget.setFontColor("rgChatMode." .. i - 2, self.irdenChat.config.unselectedModeColor)
    selectedMode = data.mode == btn.data.mode and i or selectedMode
  end
  widget.setFontColor("rgChatMode." .. selectedMode - 2, self.irdenChat.config.selectedModeColor)

  widget.setVisible("lytCharactersToDM", data.mode == "Whisper")
end

function redrawChat()
  self.irdenChat:processQueue()
end

function toBottom()
  self.irdenChat:resetOffset()
end

function openSettings()
  local chatConfigInterface = root.assetJson("/interface/scripted/icchatsettings/icchatsettingsgui.json")
  chatConfigInterface.locale = icchat.utils.getLocale()
  chatConfigInterface.chatMode = self.chatMode
  chatConfigInterface.backImage = self.irdenChat.config.icons.empty
  chatConfigInterface.frameImage = self.irdenChat.config.icons.frame
  chatConfigInterface.proximityRadius = self.irdenChat.proximityRadius
  chatConfigInterface.defaultCropArea = self.irdenChat.config.portraitCropArea
  chatConfigInterface.portraitFrame = player.getProperty("icc_portrait_frame",  self.irdenChat.config.portraitCropArea)
  player.interact("ScriptPane", chatConfigInterface)
end

-- Utility function: return the index of a value in the given array
function index(tab, value)
  for k, v in ipairs(tab) do
    if v == value then return k end
  end
  return 0
end

function createTooltip(screenPosition)
  if self.tooltipFields then
    for widgetName, tooltip in pairs(self.tooltipFields) do
      if widget.inMember(widgetName, screenPosition) then
        return tooltip
      end
    end
  end
  
  if widget.getChildAt(screenPosition) then
    local w = widget.getChildAt(screenPosition)
    local wData = widget.getData(w:sub(2))
    if wData and type(wData) == "table" and wData.displayText then
      return wData.mode and icchat.utils.getTranslation("chat.modes." .. wData.mode) or wData.displayText
    end
  end
end


function saveEverythingDude()
  -- Save messages and last command
  local messages = self.irdenChat:getMessages()
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", self.sentMessages)
end

function uninit()
  if self.chatting ~= nil then
    world.sendEntityMessage(self.chatting, "dieplz")
  end

  local text = widget.getText("tbxInput")
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end

  saveEverythingDude()
end