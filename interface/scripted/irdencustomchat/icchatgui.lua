require "/scripts/messageutil.lua"
require "/scripts/timer.lua"
require "/scripts/util.lua"
require "/scripts/irden/chat/chat_class.lua"
require "/interface/scripted/irdencustomchat/icchatutils.lua"

function init()
  self.stagehandName = "irdencustomchat"
  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.commandPreviewCanvasName = "lytCommandPreview.cnvCommandsCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]
  self.charactersListWidth = widget.getSize("lytCharactersToDM.background")[1]

  self.availableCommands = root.assetJson("/interface/scripted/irdencustomchat/commands.config")

  self.chatmonster = root.assetJson("/interface/chattingmonster/chatmonster.json")
  self.chatting = nil

  local chatConfig = config.getParameter("config")
  createTotallyFakeWidget(chatConfig.wrapWidth, chatConfig.font.baseSize)
  
  self.localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", icchat.utils.getLocale()))

  local storedMessages = root.getConfiguration("icc_last_messages", {})
  self.irdenChat = IrdenChat:create(self.canvasName, self.highlightCanvasName, self.commandPreviewCanvasName, self.stagehandName, chatConfig, player.id(), storedMessages)
  self.irdenChat:createMessageQueue()
  self.lastCommand = root.getConfiguration("icc_last_command")
  self.contacts = {}
  self.tooltipFields = {}

  self.savedCommandSelection = 0

  self.sentMessages = {}
  self.sentMessagesLimit = 15
  self.currentSentMessage = 0

  widget.setSize("backgroundImage", {self.chatWindowWidth, self.irdenChat.config.expandedBodyHeight})  
  widget.setSize("lytCharactersToDM.background", {self.charactersListWidth, self.irdenChat.config.expandedBodyHeight})
  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

  localeChat()
  --setMode(_, {mode = "Local"})

  timers:add(1, checkDMs)
  self.irdenChat:processQueue()

  -- Debind chat opening
  removeChatBindings()
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

function createTotallyFakeWidget(wrapWidth, fontSize)
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidth,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabel")
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
  timers:update(dt)
  promises:update()
  self.irdenChat:clearHighlights()
  checkGroup()
  checkFight()
  checkTyping()
  checkCommandsPreview()
  processButtonEvents()
  self.irdenChat:checkMessageQueue(dt)
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
  if not player.hasActiveQuest("irdeninitiative") then
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
  timers:add(1, checkDMs)
end

function populateList()
  if not self.cannotUse then
    self.cannotUse = icchat.utils.sendMessageToStagehand(self.stagehandName, "icc_getAllPlayers", _, function(players)  
      --online is either provided by list_loop or fetched.
      --then add online players
      local idTable = {}  -- This table will store only the 'id' values

      for _, player in ipairs(players) do
        table.insert(idTable, player.id)

        if index(self.contacts, player.id) == 0 then
          local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", player.portrait)
          widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
            id = player.id,
            displayText = player.name
          })
          self.tooltipFields["lytCharactersToDM.saPlayers.lytPlayers." .. li] = player.name
          table.insert(self.contacts, player.id)
        end
      end


      for i, id in ipairs(self.contacts) do
        if index(idTable, id) == 0 then
          widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i - 1)
          table.remove(self.contacts, i)
        end
      end

    end) ~= 0
  end
end

function drawIcon(canvasName, args)
	local playerCanvas = widget.bindCanvas(canvasName)
  playerCanvas:clear()
  
  if type(args) == "number" then
    local playerPortrait = world.entityPortrait(args, "bust")
    for _, layer in ipairs(playerPortrait) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "table" then
    for _, layer in ipairs(args) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  else
    playerCanvas:drawImage(args, {-1, 0})
  end
end

function canvasClickEvent(position, button, isButtonDown)
  if button == 0 and isButtonDown then
    self.irdenChat.expanded = not self.irdenChat.expanded
    local canvasSize = self.irdenChat.canvas:size()
    local saPlayersSize = widget.getSize("lytCharactersToDM.saPlayers")
    if self.irdenChat.expanded then
      widget.setSize(self.canvasName, {canvasSize[1], self.irdenChat.config.expandedBodyHeight})
      widget.setSize(self.highlightCanvasName, {canvasSize[1], self.irdenChat.config.expandedBodyHeight - self.irdenChat.config.spacings.messages})
      widget.setSize("backgroundImage", {self.chatWindowWidth, self.irdenChat.config.expandedBodyHeight})
      widget.setSize("saScrollArea", {canvasSize[1], self.irdenChat.config.expandedBodyHeight})
      widget.setSize("lytCharactersToDM.background", {self.charactersListWidth, self.irdenChat.config.expandedBodyHeight})  
      widget.setSize("lytCharactersToDM.saPlayers", {saPlayersSize[1], self.irdenChat.config.expandedBodyHeight - 15})  
    else
      widget.setSize(self.canvasName, {canvasSize[1], self.irdenChat.config.bodyHeight - self.irdenChat.config.spacings.messages})
      widget.setSize(self.highlightCanvasName, {canvasSize[1], self.irdenChat.config.bodyHeight - self.irdenChat.config.spacings.messages})
      widget.setSize("backgroundImage", {self.chatWindowWidth, self.irdenChat.config.bodyHeight})
      widget.setSize("saScrollArea", {canvasSize[1], self.irdenChat.config.bodyHeight })
      widget.setSize("lytCharactersToDM.background", {self.charactersListWidth, self.irdenChat.config.bodyHeight})  
      widget.setSize("lytCharactersToDM.saPlayers", {saPlayersSize[1], self.irdenChat.config.bodyHeight})  
    end
    self.irdenChat:processQueue()
  end

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do 
    if event.type == "MouseWheel" and widget.inMember("backgroundImage", screenPosition) then 
      self.irdenChat:offsetCanvas(event.data.mouseWheel * -1)
    end
  end
end

function processButtonEvents()
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
    if not li then icchat.utils.alert(icchat.utils.getTranslation("chat.alerts.dm_not_specified")) return end

    local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
    if (not world.entityExists(data.id) and index(self.contacts, data.id) == 0) then icchat.utils.alert(icchat.utils.getTranslation("chat.alerts.dm_not_found")) return end

    local whisper = "/w " .. widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).displayText .. " " .. message
    self.irdenChat:processCommand(whisper)
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
      return wData.displayText
    end
  end
end


function uninit()
  if self.chatting ~= nil then
    world.sendEntityMessage(self.chatting, "dieplz")
  end
  -- Save messages and last command
  local messages = self.irdenChat:getMessages()
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
end