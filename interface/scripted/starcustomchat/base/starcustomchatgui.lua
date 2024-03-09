require "/scripts/messageutil.lua"
require "/scripts/icctimer.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/interface/scripted/starcustomchat/base/chat_class.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/interface/scripted/starcustomchat/base/contextmenu/contextmenu.lua"
require "/interface/scripted/starcustomchat/base/dmtab/dmtab.lua"
require("/scripts/starextensions/lib/chat_callback.lua")

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

local handlerCutter = nil

ICChatTimer = TimerKeeper.new()
function init()
  shared.chatIsOpen = true
  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.commandPreviewCanvasName = "lytCommandPreview.cnvCommandsCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]

  self.availableCommands = root.assetJson("/interface/scripted/starcustomchat/base/commands.config")

  local chatConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")

  local plugins = {}
  self.localePluginConfig = {}

  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.script then
      require(pluginConfig.script)

      if not _ENV[pluginName] then
        sb.logError("Failed to load plugin %s", pluginName)
      else
        local classInstance = _ENV[pluginName]:new()
        table.insert(plugins, classInstance)
      end
    end

    if pluginConfig.baseConfigValues then
      chatConfig = sb.jsonMerge(chatConfig, pluginConfig.baseConfigValues)
    end

    if pluginConfig.localeKeys then
      self.localePluginConfig = sb.jsonMerge(self.localePluginConfig, pluginConfig.localeKeys)
    end
  end

  self.runCallbackForPlugins = function(method, ...)
    -- The logic here is actually strange and might need some more customisation
    local result = nil
    for _, plugin in ipairs(plugins) do 
      result = plugin[method](plugin, ...) or result
    end
    return result
  end

  localeChat(self.localePluginConfig)

  chatConfig.fontSize = root.getConfiguration("icc_font_size") or chatConfig.fontSize
  local expanded = config.getParameter("expanded")
  root.setConfiguration("icc_is_expanded", expanded)
  setSizes(expanded, chatConfig, config.getParameter("currentSizes"))

  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.fontSize)

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())

  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end

  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  self.customChat = StarCustomChat:create(self.canvasName, self.highlightCanvasName, self.commandPreviewCanvasName,
    chatConfig, player.id(), storedMessages, self.chatMode,
    expanded, config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"), maxCharactersAllowed, self.runCallbackForPlugins)

  self.runCallbackForPlugins("init", self.customChat)

  self.lastCommand = root.getConfiguration("icc_last_command")
  self.contacts = {}
  self.tooltipFields = {}

  self.receivedMessageFromStagehand = false

  self.savedCommandSelection = 0

  self.selectedMessage = nil
  self.sentMessages = root.getConfiguration("icc_my_messages",{}) or {}
  self.sentMessagesLimit = 15
  self.currentSentMessage = nil

  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

  self.DMTimer = 2
  contextMenu_init(config.getParameter("contextMenuButtons"))
  checkDMs()

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    widget.setText("tbxInput", lastText)
    widget.focus("tbxInput")
  end

  local currentMessageMode = config.getParameter("currentMessageMode")

  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
    widget.setFontColor("rgChatMode." .. currentMessageMode, chatConfig.modeColors[widget.getData("rgChatMode." .. currentMessageMode).mode])
  else
    widget.setSelectedOption("rgChatMode", 1)
    widget.setFontColor("rgChatMode.1", chatConfig.modeColors[widget.getData("rgChatMode.1").mode])
  end

  self.chatFunctionCallback = function(message)
    self.customChat:addMessage(message)
  end

  registerCallbacks()

  requestPortraits()
  self.customChat:processQueue()

  ICChatTimer:add(0.5, registerCallbacks)
end


function registerCallbacks()

  handlerCutter = setChatMessageHandler(self.chatFunctionCallback)
  shared.setMessageHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and world.entityExists(player.id()) then
      return {
        portrait =  starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = player.id() // -65536,
        settings = player.getProperty("icc_portrait_settings") or {
          offset = self.customChat.config.defaultPortraitOffset,
          scale = self.customChat.config.defaultPortraitScale
        },
        uuid = player.uniqueId()
      }
    end
  end))

  shared.setMessageHandler("icc_sendToUser", simpleHandler(function(message)
    self.customChat:addMessage(message)
  end))

  shared.setMessageHandler("icc_is_chat_open", localHandler(function(message)
    return true
  end))

  shared.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  shared.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.customChat:updatePortrait(data)
  end))

  shared.setMessageHandler( "icc_reset_settings", localHandler(function(data)
    createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, self.customChat.config.wrapWidthCompactMode, root.getConfiguration("icc_font_size") or self.customChat.config.fontSize)
    self.runCallbackForPlugins("onSettingsUpdate", data)
    
    localeChat(self.localePluginConfig)
    self.customChat:resetChat()
  end))

  shared.setMessageHandler( "icc_clear_history", localHandler(function(data)
    self.customChat:clearHistory(message)
  end))

  self.runCallbackForPlugins("registerMessageHandlers", shared)

  return true
end

function requestPortraits()
  local messages = self.customChat:getMessages()
  local authors = {}

  -- First, gather the unique connetcions
  for _, msg in ipairs(messages) do
    local conn = msg.connection
    if conn and conn ~= 0 and not authors[conn] then
      authors[conn] = true
    end
  end

  for conn, _ in pairs(authors) do 
    self.customChat:requestPortrait(conn)
  end
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
      return i
    end
  end
  return -1
end

function localeChat(localePluginConfig)
  starcustomchat.utils.buildLocale(localePluginConfig)

  local savedText = widget.getText("tbxInput")
  local hasFocus = widget.hasFocus("tbxInput")
  self.chatMode = root.getConfiguration("iccMode") or "modern"
  if self.chatMode ~= "compact" then self.chatMode = "modern" end

  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    widget.setText("rgChatMode." .. i, starcustomchat.utils.getTranslation("chat.modes." .. button.data.mode))
  end

  local hint = starcustomchat.utils.getTranslation("chat.textbox.hint")

  if not savedText or savedText == "" then
    widget.setText("lblTextboxHint", hint)
  end

  self.runCallbackForPlugins("onLocaleChange")

  if hasFocus then
    widget.focus("tbxInput")
  end
end

function update(dt)

  shared.chatIsOpen = true
  
  ICChatTimer:update(dt)
  promises:update()

  self.customChat:clearHighlights()
  widget.setVisible("lytContext", false)

  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)

  if not player.id() or not world.entityExists(player.id()) then
    shared.chatIsOpen = false
    pane.dismiss()
  end

  self.runCallbackForPlugins("update", dt)
end

function cursorOverride(screenPosition)
  processEvents(screenPosition)
  processContextMenu(screenPosition)

  self.runCallbackForPlugins("onCursorOverride", screenPosition)
end

function checkCommandsPreview()
  local text = widget.getText("tbxInput")

  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    local availableCommands = starcustomchat.utils.getCommands(self.availableCommands, text)

    if #availableCommands > 0 then
      self.savedCommandSelection = math.max(self.savedCommandSelection % (#availableCommands + 1), 1)
      widget.setVisible("lytCommandPreview", true)
      widget.setText("lblCommandPreview", availableCommands[self.savedCommandSelection])
      widget.setData("lblCommandPreview", availableCommands[self.savedCommandSelection])
      self.customChat:previewCommands(availableCommands, self.savedCommandSelection)
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
  local text = widget.getText("tbxInput")

  widget.setText("lblTextboxHint", text ~= "" and "" or starcustomchat.utils.getTranslation("chat.textbox.hint"))

  if widget.hasFocus("tbxInput") or text ~= "" then
    status.addPersistentEffect("starchatdots", "starchatdots")
  else
    status.clearPersistentEffects("starchatdots")
    self.currentSentMessage = nil
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
    playersSaSize = expanded and {saPlayersSize[1], chatParameters.expandedBodyHeight - 15} or {saPlayersSize[1], chatParameters.bodyHeight - 15},
    playersDMBackground = expanded and {charactersListWidth, chatParameters.expandedBodyHeight - 15} or {charactersListWidth, chatParameters.bodyHeight- 15}
  }
end

function setSizes(expanded, chatParameters, currentSizes)
  local defaultSizes = getSizes(expanded, chatParameters)
  widget.setSize(self.canvasName, currentSizes and currentSizes.canvasSize or defaultSizes.canvasSize)
  widget.setSize("saScrollArea", currentSizes and currentSizes.canvasSize or defaultSizes.canvasSize)
  widget.setSize(self.highlightCanvasName, currentSizes and currentSizes.highligtCanvasSize or defaultSizes.highligtCanvasSize)
  widget.setSize("lytCharactersToDM.background", currentSizes and currentSizes.playersDMBackground or defaultSizes.playersDMBackground)
  widget.setSize("backgroundImage", currentSizes and currentSizes.bgStretchImageSize or defaultSizes.bgStretchImageSize)
  widget.setSize("saFakeScrollArea", currentSizes and currentSizes.scrollAreaSize or defaultSizes.scrollAreaSize)
  widget.setSize("lytCharactersToDM.saPlayers", currentSizes and currentSizes.playersSaSize or defaultSizes.playersSaSize)
end

function canvasClickEvent(position, button, isButtonDown)
  if button == 0 and isButtonDown then
    self.customChat.expanded = not self.customChat.expanded

    if not self.reopening then
      
      local chatParameters = getSizes(self.customChat.expanded, self.customChat.config)
      saveEverythingDude()
      pane.dismiss()

      local chatConfig = buildChatInterface()
      chatConfig["gui"]["background"]["fileBody"] = string.format("/interface/scripted/starcustomchat/base/%s.png", self.customChat.expanded and "body" or "shortbody")
      chatConfig.expanded = self.customChat.expanded
      chatConfig.currentSizes = chatParameters
      chatConfig.lastInputMessage = widget.getText("tbxInput")
      chatConfig.portraits = self.customChat.savedPortraits
      chatConfig.connectionToUuid =  self.customChat.connectionToUuid
      chatConfig.currentMessageMode =  widget.getSelectedOption("rgChatMode")
      chatConfig.chatLineOffset = self.customChat.lineOffset
      chatConfig.reopened = true
      chatConfig.selectedModes = {}
      for _, mode in ipairs(chatConfig["chatModes"]) do 
        if widget.active("btnCk" .. mode) then
          chatConfig.selectedModes["btnCk" .. mode] = widget.getChecked("btnCk" .. mode)
        end
      end

      chatConfig = self.runCallbackForPlugins("onBackgroundChange", chatConfig)

      player.interact("ScriptPane", chatConfig)
      self.reopening = true
    end
  end

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do
    if event.type == "MouseWheel" and widget.inMember("backgroundImage", screenPosition) then
      if input.key("LCtrl") then
        self.customChat.config.fontSize = math.min(math.max(self.customChat.config.fontSize + event.data.mouseWheel, 6), 10)
        root.setConfiguration("icc_font_size", self.customChat.config.fontSize)
        createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, self.customChat.config.wrapWidthCompactMode, self.customChat.config.fontSize)
        self.customChat:processQueue()
      else
        self.customChat:offsetCanvas(event.data.mouseWheel * -1 * (input.key("LShift") and 2 or 1))
      end
    elseif event.type == "KeyDown" then
      if event.data.key == "PageUp" then
        self.customChat:offsetCanvas(self.customChat.expanded and - self.customChat.config.pageSkipExpanded or - self.customChat.config.pageSkip)
      elseif event.data.key == "PageDown" then
        self.customChat:offsetCanvas(self.customChat.expanded and self.customChat.config.pageSkipExpanded or self.customChat.config.pageSkip)
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
            self.currentSentMessage = self.currentSentMessage and math.max(self.currentSentMessage - 1, 1) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        elseif event.data.key == "Down" and event.data.mods and event.data.mods.LShift then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.min(self.currentSentMessage + 1, #self.sentMessages) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        end
      end
    end
  end


  if input.bindDown("starcustomchat", "repeatcommand") and self.lastCommand then
    self.customChat:processCommand(self.lastCommand)
  end
end

function escapeTextbox(widgetName)

  if not self.runCallbackForPlugins("onTextboxEscape") then
    blurTextbox(widgetName)
  end
end

function blurTextbox(widgetName)
  widget.setText(widgetName, "")
  widget.blur(widgetName)
end

function textboxEnterKey(widgetName)
  local text = widget.getText(widgetName)

  if text == "" then
    blurTextbox(widgetName)
    return
  end

  local message = {
    text = text,
    mode = widget.getSelectedData("rgChatMode").mode
  }

  if string.sub(text, 1, 1) == "/" then
    if string.len(text) == 1 then
      blurTextbox(widgetName)
      return
    end

    if string.sub(text, 1, 2) == "//" then
      starcustomchat.utils.alert("chat.alerts.cannot_start_two_slashes")
      return
    end

    if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" and widget.getData("lblCommandPreview") ~= text then
      widget.setText(widgetName, widget.getData("lblCommandPreview") .. " ")
      return
    else
      processCommand(text)
      self.lastCommand = text
      starcustomchat.utils.saveMessage(text)
    end
  elseif not self.runCallbackForPlugins("onTextboxEnter", message) then 
    if message.mode == "Whisper" then
      local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
      if not li then starcustomchat.utils.alert("chat.alerts.dm_not_specified") return end

      local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
      if not world.entityExists(data.id) then starcustomchat.utils.alert("chat.alerts.dm_not_found") return end

      whisperName = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).tooltipMode
  
      local whisper = string.find(whisperName, "%s") and "/w \"" .. whisperName .. "\" " .. message.text 
        or "/w " .. whisperName .. " " .. message.text
  
      self.customChat:processCommand(whisper)
      self.customChat.lastWhisper = {
        recipient = whisperName,
        text = message.text
      }
      starcustomchat.utils.saveMessage(whisper)
    else
      starcustomchat.utils.saveMessage(message.text)
      message = self.runCallbackForPlugins("formatOutcomingMessage", message)
      sendMessage(message)
    end
  end
  blurTextbox(widgetName)
end

function processCommand(command)
  self.customChat:processCommand(command)
end

function sendMessage(message)
  self.customChat:sendMessage(message.text, message.mode)
end

function setMode(id, data)
  local modeButtons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, btn in ipairs(modeButtons) do
    widget.setFontColor("rgChatMode." .. i, self.customChat.config.unselectedModeColor)
  end
  widget.setFontColor("rgChatMode." .. id, self.customChat.config.modeColors[data.mode])

  self.runCallbackForPlugins("onModeChange", data.mode)
end

function modeToggle(button, isChecked)
  self.runCallbackForPlugins("onModeToggle", button, widget.getChecked(button))
  self.customChat:processQueue()
end

function toBottom()
  self.customChat:resetOffset()
end

function openSettings()
  local chatConfigInterface = buildSettingsInterface()
  chatConfigInterface.enabledPlugins = config.getParameter("enabledPlugins", {})
  chatConfigInterface.chatConfig = self.customChat.config
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
    if wData and type(wData) == "table" then
      if wData.tooltipMode then
        return wData.mode and starcustomchat.utils.getTranslation("chat.modes." .. wData.mode) or wData.tooltipMode
      elseif wData.displayText then
        return starcustomchat.utils.getTranslation(wData.displayText)
      end
    end
  end
end

function customButtonCallback(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick", buttonName, data)
end

function saveEverythingDude()
  -- Save messages and last command
  local messages = self.customChat:getMessages()
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", self.sentMessages)
end

function uninit()
  local text = widget.getText("tbxInput")
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end

  saveEverythingDude()
  handlerCutter()
end