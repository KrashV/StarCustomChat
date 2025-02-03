require "/scripts/messageutil.lua"
require "/scripts/scctimer.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/interface/scripted/starcustomchat/base/chat_class.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/interface/scripted/starcustomchat/base/contextmenu/contextmenu.lua"
require "/interface/scripted/starcustomchat/base/dmtab/dmtab.lua"


local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

local handlerCutter = nil

ICChatTimer = TimerKeeper.new()
function init()

  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  if self.isOpenSB then shared.setMessageHandler = nil end
  
  self.chatFunctionCallback = function(message)
    self.customChat:addMessage(message)
  end
  
  if not self.isOpenSB then
    require("/scripts/starextensions/lib/chat_callback.lua")
    ICChatTimer:add(2, checkUUID)
    handlerCutter = setChatMessageHandler(self.chatFunctionCallback)
  else
    self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")
  end

  shared.chatIsOpen = true
  self.canvasName = "chatLog"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.chatWindowWidth = widget.getSize("saScrollArea")[1]

  self.availableCommands = root.assetJson("/interface/scripted/starcustomchat/base/commands.config")

  local chatConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")

  self.chatUUID = sb.makeUuid()

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
  local expanded = root.getConfiguration("icc_is_expanded", false) or config.getParameter("expanded") or false
  
  setSizes(expanded, chatConfig, config.getParameter("currentSizes"))

  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.fontSize)

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())

  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end

  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  self.customChat = StarCustomChat:create(self.canvasName, "cnvBackgroundCanvas", self.highlightCanvasName, "lytCommandPreview.cnvCommandsCanvas",
    chatConfig, storedMessages, self.chatMode,
    expanded, config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"), maxCharactersAllowed, 
    sb.jsonMerge(config.getParameter("defaultColors"), root.getConfiguration("scc_custom_colors") or {}), self.runCallbackForPlugins)

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

  contextMenu_init(config.getParameter("contextMenuButtons"))

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    widget.setText("tbxInput", lastText)
    widget.focus("tbxInput")
  end

  local currentMessageMode = config.getParameter("currentMessageMode") or root.getConfiguration("scc_message_mode")

  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
    widget.setFontColor("rgChatMode." .. currentMessageMode, chatConfig.modeColors[widget.getData("rgChatMode." .. currentMessageMode).mode])
  else
    widget.setSelectedOption("rgChatMode", 1)
    widget.setFontColor("rgChatMode.1", chatConfig.modeColors[widget.getData("rgChatMode.1").mode])
  end

  ICChatTimer:add(1, prepareForCallbacks)
  requestPortraits()

  self.customChat:drawBackground()
  self.customChat:processQueue()

  local storedHiddenMessages = config.getParameter("storedMessages") or {}

  for _, message in pairs(storedHiddenMessages) do 
    self.customChat:addMessage(message)
  end

  if config.getParameter("forceFocus") then
    widget.focus("tbxInput")
  end

  checkDMs(config.getParameter("DMingPlayerID"))
  widget.setFontColor("tbxInput", self.customChat:getColor("chattext"))

end

function prepareForCallbacks()
  -- Reinitialize the shared table if necessary
  shared = getmetatable('').shared
  if type(shared) ~= "table" then
    shared = {}
    getmetatable('').shared = shared
  end

  local calbacksReady = registerCallbacks(shared)

  if not calbacksReady or world.type() == "Nowhere" or not player.id() then
    ICChatTimer:add(0.5, prepareForCallbacks)
  end
end

function checkUUID()
  if player.id() then
    world.sendEntityMessage(player.id(), "scc_check_uuid", self.chatUUID)
  end
  ICChatTimer:add(2, checkUUID)
end

function registerCallbacks(shared)

  if not shared.setMessageHandler then
    return false
  end

  shared.setMessageHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and player.uniqueId() and world.entityExists(player.id()) then
      return {
        portrait = player.getProperty("icc_custom_portrait") or starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
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

  shared.setMessageHandler("scc_set_message_bigchat", localHandler(function(text)
    widget.focus("tbxInput")
    if text and utf8.len(text) > 0 then
      widget.setText("tbxInput", text)
      textboxCallback()
    else
      if widget.getText("tbxInput") == "" then
        blurTextbox("tbxInput")
      end
    end
  end))

  shared.setMessageHandler("icc_sendToUser", simpleHandler(function(message)
    self.customChat:addMessage(message)
  end))

  shared.setMessageHandler("icc_is_chat_open", localHandler(function(message)
    return shared.chatIsOpen
  end))

  shared.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  shared.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.customChat:updatePortrait(data)
  end))

  shared.setMessageHandler("scc_check_uuid", localHandler(function(uuid)
    if self.chatUUID ~= uuid then
      pane.dismiss()
    end
  end))

  shared.setMessageHandler( "icc_reset_settings", localHandler(function(data)
    if shared.chatIsOpen then
      createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, self.customChat.config.wrapWidthCompactMode, root.getConfiguration("icc_font_size") or self.customChat.config.fontSize)
      self.runCallbackForPlugins("onSettingsUpdate", data)
      
      localeChat(self.localePluginConfig)
      self.customChat:resetChat()
    end
  end))

  shared.setMessageHandler( "icc_clear_history", localHandler(function(data)
    self.customChat:clearHistory()
  end))

  shared.setMessageHandler( "/clearchat", localHandler(function(data)
    self.customChat:clearHistory()
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
  widget.setText("lblTextboxHint", starcustomchat.utils.getTranslation("chat.textbox.hint"))

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
  
  if self.drawingCanvas then self.drawingCanvas:clear() end

  self.customChat:clearHighlights()
  widget.setVisible("lytContext", false)

  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)

  if not self.isOpenSB and (not player.id() or not world.entityExists(player.id()) or world.type() == "Nowhere") then
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

function textboxCallback()
  self.runCallbackForPlugins("onTextboxCallback")
end

function checkCommandsPreview()
  local text = widget.getText("tbxInput")

  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    local availableCommands = starcustomchat.utils.getCommands(self.availableCommands, text)

    if #availableCommands > 0 then
      self.savedCommandSelection = math.max(self.savedCommandSelection % (#availableCommands + 1), 1)
      widget.setVisible("lytCommandPreview", true)
      widget.setText("lblCommandPreview", availableCommands[self.savedCommandSelection].name)
      widget.setData("lblCommandPreview", availableCommands[self.savedCommandSelection].name)
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

  widget.setVisible("lblTextboxHint", text == "")

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

  if self.isOpenSB then
    pane.setSize(expanded and {pane.getSize()[1], chatParameters.expandedBodyHeight + 25} or {pane.getSize()[1], chatParameters.bodyHeight + 25})
    widget.setSize("background", expanded and {self.chatWindowWidth, chatParameters.expandedBodyHeight} or {self.chatWindowWidth, chatParameters.bodyHeight})
    widget.setSize(self.canvasName, currentSizes and vec2.add(currentSizes.canvasSize, {0,2}) or vec2.add(defaultSizes.canvasSize, {0,2}))
    widget.setSize("saScrollArea", currentSizes and vec2.add(currentSizes.highligtCanvasSize, {0,2}) or vec2.add(defaultSizes.highligtCanvasSize, {0,2}))
    widget.setSize(self.highlightCanvasName, currentSizes and vec2.add(currentSizes.highligtCanvasSize, {0,2}) or vec2.add(defaultSizes.highligtCanvasSize, {0,2}))
  end
end

function canvasClickEvent(position, button, isButtonDown)
  if self.runCallbackForPlugins("onCanvasClick", position, button, isButtonDown) then
    return
  end
  
  if button == 0 and isButtonDown then
    self.customChat.expanded = not self.customChat.expanded
    root.setConfiguration("icc_is_expanded", self.customChat.expanded)

    if self.isOpenSB then
      setSizes(self.customChat.expanded, self.customChat.config, config.getParameter("currentSizes"))
      self.customChat:processQueue()
    else
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
        chatConfig.DMingPlayerID = self.DMingPlayerID
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
  end

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do
    if event.type == "MouseWheel" and widget.inMember("saScrollArea", screenPosition) then

      self.runCallbackForPlugins("onChatScroll")

      if input.key("LCtrl") then
        local newChatSize = math.min(math.max(self.customChat.config.fontSize + event.data.mouseWheel, 6), 10)
        if newChatSize ~= self.customChat.config.fontSize then
          self.customChat.recalculateHeight = true
        end
        self.customChat.config.fontSize = newChatSize

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
      elseif event.data.key == "End" then
        self.customChat:resetOffset()
      end
    end
  end
end

function processButtonEvents(dt)

  -- StarExtensions only
  if not self.isOpenSB then
    if input.keyDown("Return") or input.keyDown("/") and not widget.hasFocus("tbxInput") then
      if input.keyDown("/") then
        widget.setText("tbxInput", "/")
      end
      widget.focus("tbxInput")
      chat.setInput("")
    end
  end

  if widget.hasFocus("tbxInput") then
    for _, event in ipairs(input.events()) do
      if event.type == "KeyDown" then
        local lShift = event.data.mods and (event.data.mods.LShift or index(event.data.mods, "LShift") ~= 0)
        local rShift = event.data.mods and (event.data.mods.RShift or index(event.data.mods, "RShift") ~= 0)
        local lCtrl = event.data.mods and (event.data.mods.LCtrl or index(event.data.mods, "LCtrl") ~= 0)
        local rCtrl = event.data.mods and (event.data.mods.RCtrl or index(event.data.mods, "RCtrl") ~= 0)
        local shiftPressed = lShift or rShift
        local ctrlPressed = lCtrl or rCtrl

        if event.data.key == "Tab" then
          self.savedCommandSelection = self.savedCommandSelection + 1
        elseif event.data.key == "Up" and shiftPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.max(self.currentSentMessage - 1, 1) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        elseif event.data.key == "Down" and shiftPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.min(self.currentSentMessage + 1, #self.sentMessages) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        elseif event.data.key == "V" and ctrlPressed then
          local textInClipboard = clipboard.getText()
          if textInClipboard and string.find(textInClipboard, '\n') then
            widget.setText("tbxInput", widget.getText("tbxInput") .. string.gsub(textInClipboard, "[\n\r]", " "))
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

function sendMessageToBeSent(text, mode)
  mode = mode or widget.getSelectedData("rgChatMode").mode

  local message = {
    text = text,
    mode = mode
  }

  if self.runCallbackForPlugins("preventTextboxCallback", message) then
    return
  end

  if string.sub(text, 1, 1) == "/" and not string.find(text, "^/%w+%.png") then
    if string.len(text) == 1 then
      blurTextbox("tbxInput")
      return
    end

    if string.sub(text, 1, 2) == "//" then
      starcustomchat.utils.alert("chat.alerts.cannot_start_two_slashes")
      return
    end

    if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" and widget.getData("lblCommandPreview") ~= text then
      widget.setText("tbxInput", widget.getData("lblCommandPreview") .. " ")
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
  blurTextbox("tbxInput")
  self.runCallbackForPlugins("afterTextboxPressed", message)
end

function textboxEnterKey(widgetName)

  local text = widget.getText(widgetName)

  if text == "" then
    blurTextbox(widgetName)
    return
  end

  sendMessageToBeSent(text, mode)
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
  root.setConfiguration("scc_message_mode", id)
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
      if widget.inMember(widgetName, screenPosition) and widget.active(widgetName) then
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

  return self.runCallbackForPlugins("onCreateTooltip", screenPosition)
end

function customButtonCallback(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick", buttonName, data)
end

function openBiggerChat()
  widget.focus("tbxInput")
  local biggerChat = root.assetJson("/interface/BiggerChat/biggerchatv2.json")
  biggerChat.initialText = widget.getText("tbxInput")
  biggerChat.fontColor = self.customChat:getColor("chattext")
  player.interact("ScriptPane", biggerChat)
end

function saveEverythingDude()
  -- Save messages and last command
  local messages = self.customChat:getMessages()
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", self.sentMessages)
end

function closeChat()
  if not self.isOpenSB then
    pane.dismiss()
    world.sendEntityMessage(player.id(), "scc_chat_hidden", widget.getSelectedOption("rgChatMode"))
  else
    pane.hide()
  end
end

-- OpenStarbound chat
function startChat()
  pane.show()
  widget.focus("tbxInput")
  chat.setInput("")
end

function startCommand()
  pane.show()
  widget.setText("tbxInput", "/")
  widget.focus("tbxInput")
  chat.setInput("")
end

function convertToChatMessage(oldMessage)
  local newMessage = {}
  newMessage.text = oldMessage.text
  newMessage.connection = oldMessage.fromConnection
  newMessage.mode = oldMessage.context.mode
  newMessage.nickname = oldMessage.fromNick
  newMessage.portrait = oldMessage.portrait
  return newMessage
end

function addMessages(messages, showPane) 
  for _, message in ipairs(messages) do
    self.customChat:addMessage(convertToChatMessage(message))
  end
end



function uninit()
  local text = widget.getText("tbxInput")
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end
  shared.chatIsOpen = false
  saveEverythingDude()

  if handlerCutter then
    handlerCutter()
  end
  status.clearPersistentEffects("starchatdots")
  self.runCallbackForPlugins("uninit")
end