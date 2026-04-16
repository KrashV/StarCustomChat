require "/scripts/messageutil.lua"
require "/scripts/scctimer.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/interface/StarboundTextboxInterface/animatedWidgets.lua"
require "/interface/scripted/starcustomchat/base/chat_class.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/interface/scripted/starcustomchat/base/contextmenu/contextmenu.lua"
require "/interface/scripted/starcustomchat/base/dmtab/dmtab.lua"

local handlerCutter = nil

ICChatTimer = TimerKeeper.new()
function init()

  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")
  self.isOSBXSB = self.isOpenSB or xsb
  
  self.chatFunctionCallback = function(message)
    self.customChat:addMessage(message)
  end
  
  if not self.isOSBXSB then
    require("/scripts/starextensions/lib/chat_callback.lua")
    handlerCutter = setChatMessageHandler(self.chatFunctionCallback)
    starcustomchat.utils.setSharedValue("dismissPane", pane.dismiss)
  else
    self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")
  end

  self.canvasName = "chatLog"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.chatWindowWidth = widget.getSize("saScrollArea")[1]

  self.availableCommands = root.assetJson("/interface/scripted/starcustomchat/base/commands.config")

  local chatConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")

  self.chatUUID = nil

  local plugins = {}
  local localePluginConfig = {}
  local availableLocales = root.assetJson("/interface/scripted/starcustomchat/locales/locales.json")
  for _, localeConfig in ipairs(availableLocales) do
    localePluginConfig[localeConfig.code] = root.assetJson(string.format("/interface/scripted/starcustomchat/locales/%s.json", localeConfig.code))
  end


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

    if pluginConfig.commands then
      self.availableCommands = sb.jsonMerge(self.availableCommands, {pluginName = root.assetJson(pluginConfig.commands)})
    end

    for _, localeConfig in ipairs(availableLocales) do 
      local locale = localeConfig.code
      local localeFile = string.format("/interface/scripted/starcustomchat/plugins/%s/locales/%s.json", pluginName, locale)
      if root.assetOrigin(localeFile) then
        local translations = root.assetJson(localeFile)
        localePluginConfig[locale] = sb.jsonMerge(localePluginConfig[locale], translations)
      else
        sb.logWarn("The %s localization file is missing", localeFile)
      end
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

  starcustomchat.utils.buildLocale(localePluginConfig)

  chatConfig.fontSize = root.getConfiguration("icc_font_size") or chatConfig.fontSize
  local expanded = root.getConfiguration("icc_is_expanded", false) or config.getParameter("expanded") or false
  

  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.fontSize)

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())

  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end

  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  self.customChat = StarCustomChat:create(self.canvasName, "cnvBackgroundCanvas", self.highlightCanvasName,
    chatConfig, storedMessages, self.chatMode,
    expanded, config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"), maxCharactersAllowed, 
    sb.jsonMerge(config.getParameter("defaultColors"), root.getConfiguration("scc_custom_colors") or {}), self.runCallbackForPlugins)


  self.runCallbackForPlugins("init", self.customChat)
  localeChat()
  setSizes(expanded, chatConfig)

  self.lastCommand = root.getConfiguration("icc_last_command")

  self.savedCommandSelection = 0

  self.selectedMessage = nil
  self.sentMessages = root.getConfiguration("icc_my_messages") or jarray()
  self.sentMessagesLimit = 15
  self.currentSentMessage = nil

  contextMenu_init(config.getParameter("contextMenuButtons"))

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    self.customChat:setText(lastText)
    self.customChat:focusInput()
  end

  local currentMessageMode = config.getParameter("currentMessageMode") or root.getConfiguration("scc_message_mode")

  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
    widget.setFontColor("rgChatMode." .. currentMessageMode, chatConfig.modeColors[widget.getData("rgChatMode." .. currentMessageMode).mode])
  else
    widget.setSelectedOption("rgChatMode", 1)
    widget.setFontColor("rgChatMode.1", chatConfig.modeColors[widget.getData("rgChatMode.1").mode])
  end

  createPromiseFunction()

  self.customChat:drawBackground()
  self.customChat:processQueue()

  local storedHiddenMessages = config.getParameter("storedMessages") or {}

  for _, message in pairs(storedHiddenMessages) do 
    self.customChat:addMessage(message)
  end

  if config.getParameter("forceFocus") then
    self.customChat:focusInput()
  end

  self.customChat:setTextColor(self.customChat:getColor("chattext"))

  -- Apparently, we don't know on init if we're admin or not.
  ICChatTimer:add(0.2, disableAdminModes)


  if pane.setPosition then
    widget.setVisible("btnMoveChat", true)
    ICChatTimer:add(0.1, function()
      local newPosition = root.getConfiguration("scc_chat_position") or {3, 5}
      pane.setPosition(newPosition)
    end)
  end

  if widget.getScrollOffset then
    widget.setButtonEnabled("lytLeftMenu.btnUp", true)
    widget.setButtonEnabled("lytLeftMenu.btnDown", true)
  end

  self.settingsInterface = buildSettingsInterface()

  self.DMTab = DMTab:new(self.customChat)
  self.DMTab:checkDMs(config.getParameter("DMingPlayerID"))
end

function selectPlayer(...)
  return self.DMTab and self.DMTab:selectPlayer(...)
end

function disableAdminModes()
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    if button.data.admin then
      widget.setButtonEnabled("rgChatMode." .. i, player.isAdmin())
    end
  end
end

function createPromiseFunction()
  -- Since in OSB chat is ready before the other scripts, we should pool ourself before we can actually use it
  function pullPromise()
    starcustomchat.utils.runWhenPlayerReady(function()
      promises:add(world.sendEntityMessage(player.id(), "scc_uuid"), function(uuid)
          if not self.chatUUID or self.chatUUID ~= uuid then
            prepareForCallbacks()
            self.chatUUID = uuid
          end
          pullPromise()
      end, function() 
        self.chatUUID = nil
        pullPromise()
      end)
    end)
  end
  
  pullPromise()
end

function prepareForCallbacks()
  local calbacksReady = registerCallbacks()
  
  if not calbacksReady then
    ICChatTimer:add(0.5, prepareForCallbacks)
    starcustomchat.utils.resetShared()
  end
end

function registerCallbacks()

  if not starcustomchat.utils.setMessageHandler then
    return false
  end
  
  starcustomchat.utils.setMessageHandler( "scc_reload_callbacks", localHandler(prepareForCallbacks))
  starcustomchat.utils.setMessageHandler( "scc_is_open", localHandler(function() return true end))


  starcustomchat.utils.setMessageHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and player.uniqueId() and world.entityExists(player.id()) then
      local portraitTable = player.getProperty("icc_custom_portrait")
      local portraitSelected = player.getProperty("icc_custom_portrait_selected")
      local portrait = nil
      local frameTable = root.getConfiguration("scc_custom_frames") or {}
      local frameSelected = player.getProperty("scc_custom_frame_selected")

      if portraitTable then
        if type(portraitTable) == "table" then
          portrait = portraitSelected and portraitSelected ~= 0 and portraitTable[portraitSelected or #portraitTable] or nil
        end
      end

      return {
        portrait = portrait or starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = starcustomchat.utils.entityIdToConnection(player.id()),
        settings = player.getProperty("icc_portrait_settings") or {
          offset = self.customChat.config.defaultPortraitOffset,
          scale = self.customChat.config.defaultPortraitScale
        },
        uuid = player.uniqueId(),
        frame = frameTable[frameSelected]
      }
    end
  end))

  starcustomchat.utils.setMessageHandler("scc_add_message", simpleHandler(function(message)
    self.customChat:addMessage(message)
  end))

  starcustomchat.utils.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  starcustomchat.utils.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.customChat:updatePortrait(data)
  end))

  starcustomchat.utils.setMessageHandler("scc_check_uuid", localHandler(function(uuid)
    if self.chatUUID ~= uuid then
      pane.dismiss()
    end
  end))

  starcustomchat.utils.setMessageHandler( "scc_reset_settings", localHandler(function(data)
    starcustomchat.utils.getLocale()
    createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, self.customChat.config.wrapWidthCompactMode, root.getConfiguration("icc_font_size") or self.customChat.config.fontSize)
    self.runCallbackForPlugins("onSettingsUpdate", data)
    
    localeChat()
    self.customChat:resetChat()
  end))

  starcustomchat.utils.setMessageHandler( "scc_clear_history", localHandler(function(data)
    self.customChat:clearHistory()
  end))

  starcustomchat.utils.setMessageHandler( "/clearchat", localHandler(function(data)
    self.customChat:clearHistory()
  end))

  starcustomchat.utils.setMessageHandler( "/filter", localHandler(function(data)
    self.customChat:setFilter(data)
  end))

  starcustomchat.utils.setMessageHandler("scc_edit_message", function(_, _, data)
    local msgInd = self.customChat:findMessageByUUID(data.uuid)
    if msgInd then
      data.edited = true
      data = self.customChat.callbackPlugins("editMessage", data)
      local message = self.customChat.messages[msgInd]
      message.text = data.text
      message.mode = data.mode
      message.textHeight = nil

      if not message.edited then
        message.time = "^set;^lightgray;(" .. starcustomchat.utils.getTranslation("chat.message.edited") .. ")^reset; "
          .. (message.time or "")
        message.edited = true
        message.forceAvatar = true
      end

      local newUUID = self.customChat:calculateUUID(data)
      local oldUUID = message.uuid
      self.customChat:replaceUUID(oldUUID, newUUID)

      self.customChat:processQueue()
    end
  end)

  starcustomchat.utils.setMessageHandler("scc_stagehand_allowed_messages", simpleHandler(function(messageTypes)
    if messageTypes then
      self.runCallbackForPlugins("registerStagehandHandlers", starcustomchat.utils.listToSet(messageTypes))
    end
  end))

  self.runCallbackForPlugins("registerMessageHandlers")
  self.runCallbackForPlugins("_requestStagehandHandlers")

  -- We should request the portraits (ours too) only after we are ready to accept them
  requestPortraits()
  return true
end

function requestPortraits()
  local messages = self.customChat:getMessages()
  local authors = {}

  -- First, gather the unique connections
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
  pane.removeWidget("totallyFakeLabelFullMode")
  pane.removeWidget("totallyFakeLabelCompactMode")

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

function localeChat()
  local hasFocus = self.customChat:hasFocusInput()

  self.chatMode = root.getConfiguration("sccMode") or "modern"
  if self.chatMode ~= "compact" then self.chatMode = "modern" end

  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    local name = starcustomchat.utils.getTranslation("chat.modes." .. button.data.mode)
    widget.setText("rgChatMode." .. i, name)
  end

  
  local hint = starcustomchat.utils.getTranslation("chat.textbox.hint")
  self.customChat:setHint(hint)

  self.runCallbackForPlugins("onLocaleChange")


  if hasFocus then
    self.customChat:focusInput()
  end
end

function update(dt)

  ICChatTimer:update(dt)
  promises:update()
  animatedWidgets:update(dt)
  
  if self.drawingCanvas then self.drawingCanvas:clear() end

  self.customChat:clearHighlights()
  widget.setVisible("lytContext", false)

  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)
  processLeftMenuButtons()

  if self.toggleMoveChat then
    local cursorPosition = vec2.sub(self.drawingCanvas:mousePosition(), vec2.div(widget.getSize("btnMoveChat"), 2))
    pane.setPosition(vec2.sub(cursorPosition, widget.getPosition("btnMoveChat")))
  end

  self.runCallbackForPlugins("update", dt)
end

function cursorOverride(screenPosition)
  processEvents(screenPosition)
  processContextMenu(screenPosition)

  self.runCallbackForPlugins("onCursorOverride", screenPosition)
end

function textboxCallback()
  self.runCallbackForPlugins("onTextboxCallback", self.customChat:getText())
end

function checkCommandsPreview()
  local function setCommandPreviewData(entries)
    if #entries > 0 then
      self.savedCommandSelection = math.max(self.savedCommandSelection % (#entries + 1), 1)
      widget.setVisible("lytCommandPreview", true)
      widget.setText("lblCommandPreview", entries[self.savedCommandSelection].name)
      widget.setData("lblCommandPreview", entries[self.savedCommandSelection].name)
      self.customChat:previewCommands(entries, self.savedCommandSelection)
    else
      widget.setVisible("lytCommandPreview", false)
      widget.setText("lblCommandPreview", "")
      widget.setData("lblCommandPreview", nil)
      self.savedCommandSelection = 0
    end
  end

  local text = self.customChat:getText()

  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    local availableCommands = starcustomchat.utils.getCommands(self.availableCommands, text)
    setCommandPreviewData(availableCommands)
    
  elseif utf8.len(text) >= 1 and string.sub(text, 1, 1) == "@" then
    if not self.pingUsersAround then
      self.pingUsersAround = {}
      for _, pl in ipairs(starcustomchat.utils.playersInRadius(nil, true, true)) do
        table.insert(self.pingUsersAround, {
          command = "@" .. world.entityName(pl),
          description = "chat.alerts.ping_user"
        })
      end
    end

    local playersAround = starcustomchat.utils.getCommands({playerNames = self.pingUsersAround}, text)
    setCommandPreviewData(playersAround)

  else
    widget.setVisible("lytCommandPreview", false)
    widget.setText("lblCommandPreview", "")
    widget.setData("lblCommandPreview", nil)
    self.savedCommandSelection = 0
    self.pingUsersAround = nil
  end
end

function checkTyping()
  local text = self.customChat:getText()

  if not widget.setHint then
    widget.setVisible("lblTextboxHint", text == "")
  end

  if self.customChat:hasFocusInput() or text ~= "" and not status.getPersistentEffects("starchatdots") then
    status.addPersistentEffect("starchatdots", "starchatdots")
  else
    status.clearPersistentEffects("starchatdots")
    self.currentSentMessage = nil
  end
end

function getSizes(expanded, chatParameters)
  local canvasSize = widget.getSize(self.canvasName)
  local dmPlayersSize = widget.getSize("lytCharactersToDM.background")

  local fullHeight = chatParameters.expandedBodyHeight
  local collapsedDiff = chatParameters.expandedBodyHeight - chatParameters.bodyHeight
  local modeHeight = expanded and fullHeight or (fullHeight - collapsedDiff)

  local submenuHeight = (widget.active("lytSubMenu") and widget.getSize("lytSubMenu")[2]) or 0
  local textboxHeight = widget.getSize("imgTextbox")[2]

  local bodyHeight = math.max(modeHeight - submenuHeight - textboxHeight)

  local buttonsSize = root.imageSize("/interface/scripted/starcustomchat/base/images/tabmodes/chatmode1.png")[2]

  return {
    fullHeight = {canvasSize[1], fullHeight + 2},
    canvasSize = {canvasSize[1], bodyHeight + 2},
    dmPlayersSize = {dmPlayersSize[1], math.max(modeHeight - widget.getPosition("lytCharactersToDM")[2], 1)},
    dmPlayersSASize = {dmPlayersSize[1] + 10, math.max(modeHeight - widget.getPosition("lytCharactersToDM")[2], 1)},
    submenuHeight = submenuHeight,
    textboxHeight = textboxHeight,
    fullSize = {pane.getSize()[1], bodyHeight + submenuHeight + textboxHeight + buttonsSize + 2}
  }
end

function setSizes(expanded, chatParameters, smooth)
  local sizes = getSizes(expanded, chatParameters)
  local speed = self.customChat.config.chatSizeChangeSpeed

  if self.isOSBXSB then
    if smooth then
      animatedWidgets:add(AnimatedWidget:setPaneSize(sizes.fullSize, speed))
    else
      pane.setSize(sizes.fullSize)
    end
  end

  widget.setPosition("lytSubMenu", vec2.add(widget.getPosition("imgTextbox"), {0, widget.getSize("imgTextbox")[2]}))
  widget.setPosition(self.canvasName, vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))
  widget.setPosition("saScrollArea", vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))
  widget.setPosition(self.highlightCanvasName, vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))
  widget.setPosition("backgroundImage", vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))
  widget.setPosition("background", vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))
  widget.setPosition("frameImage", vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))

  widget.setSize(self.canvasName, sizes.fullHeight)
  widget.setSize(self.highlightCanvasName, sizes.fullHeight)
  widget.setSize("saScrollArea", sizes.fullHeight)

  if smooth then
    animatedWidgets:add(AnimatedWidget:bind("background"):setSize(sizes.canvasSize, speed))
    animatedWidgets:add(AnimatedWidget:bind("frameImage"):setSize(sizes.canvasSize, speed), function()
        widget.setSize(self.canvasName, sizes.canvasSize)
        widget.setSize(self.highlightCanvasName, sizes.canvasSize)
    end)
    
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM"):setSize(sizes.dmPlayersSASize, speed))
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM.saPlayers"):setSize(sizes.dmPlayersSASize, speed))
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM.background"):setSize(sizes.dmPlayersSize, speed))
  else
    widget.setSize("background", sizes.canvasSize)
    widget.setSize("backgroundImage", sizes.canvasSize)
    widget.setSize("frameImage", sizes.canvasSize)
    widget.setSize("lytCharactersToDM", sizes.dmPlayersSASize)
    widget.setSize("lytCharactersToDM.background", sizes.dmPlayersSize)
    widget.setSize("lytCharactersToDM.saPlayers", sizes.dmPlayersSASize)
  end

end

function canvasClickEvent(position, button, isButtonDown)
  if self.runCallbackForPlugins("onCanvasClick", position, button, isButtonDown) then
    return
  end
  
  if button == 0 and isButtonDown then
    self.customChat.expanded = not self.customChat.expanded
    root.setConfiguration("icc_is_expanded", self.customChat.expanded)

    if self.isOSBXSB then
      setSizes(self.customChat.expanded, self.customChat.config, true)
      self.customChat:processQueue()

      if self.customChat:getText() ~= "" then
        self.customChat:focusInput()
      end
    else
      if not self.reopening then
        
        local chatParameters = getSizes(self.customChat.expanded, self.customChat.config)
        saveEverythingDude()
        pane.dismiss()

        local chatConfig = buildChatInterface()
        chatConfig["gui"]["background"]["fileBody"] = string.format("/interface/scripted/starcustomchat/base/images/%s.png", self.customChat.expanded and "body" or "shortbody")
        chatConfig.expanded = self.customChat.expanded
        chatConfig.currentSizes = chatParameters
        chatConfig.lastInputMessage = self.customChat:getText()
        chatConfig.portraits = self.customChat.savedPortraits
        chatConfig.connectionToUuid =  self.customChat.connectionToUuid
        chatConfig.currentMessageMode =  widget.getSelectedOption("rgChatMode")
        chatConfig.DMingPlayerID = self.DMTab:selectedPlayer() and self.DMTab:selectedPlayer().id or nil
        chatConfig.chatLineOffset = self.customChat.lineOffset
        chatConfig.reopened = true
        chatConfig.selectedModes = {}
        for _, mode in ipairs(chatConfig["chatModes"]) do 
          if widget.active("lytModeFilter.btnCk" .. mode) then
            chatConfig.selectedModes["btnCk" .. mode] = widget.getChecked("lytModeFilter.btnCk" .. mode)
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

      if not self.runCallbackForPlugins("onChatScroll", screenPosition) then
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
      end
    elseif event.type == "KeyDown" then
      if event.data.key == "PageUp" then
        self.customChat:offsetCanvas(self.customChat.expanded and - self.customChat.config.pageSkipExpanded or - self.customChat.config.pageSkip)
      elseif event.data.key == "PageDown" then
        self.customChat:offsetCanvas(self.customChat.expanded and self.customChat.config.pageSkipExpanded or self.customChat.config.pageSkip)
      elseif event.data.key == "End" then
        self.customChat:resetCanvasOffset()
      end
    end
  end
end

function processButtonEvents(dt)

  -- StarExtensions only
  if not self.isOSBXSB then
    if input.keyDown("Return") or input.keyDown("/") and not self.customChat:hasFocusInput() then
      if input.keyDown("/") then
        self.customChat:setText("/")
      end
      self.customChat:focusInput()
      chat.setInput("")
    end
  end

  if self.customChat:hasFocusInput() then
    for _, event in ipairs(input.events()) do
      if event.type == "KeyDown" then
        local lShift = event.data.mods and (event.data.mods.LShift or index(event.data.mods, "LShift") ~= 0)
        local rShift = event.data.mods and (event.data.mods.RShift or index(event.data.mods, "RShift") ~= 0)
        local lCtrl = event.data.mods and (event.data.mods.LCtrl or index(event.data.mods, "LCtrl") ~= 0)
        local rCtrl = event.data.mods and (event.data.mods.RCtrl or index(event.data.mods, "RCtrl") ~= 0)
        local lAlt = event.data.mods and (event.data.mods.LAlt or index(event.data.mods, "LAlt") ~= 0)
        local rAlt = event.data.mods and (event.data.mods.RAlt or index(event.data.mods, "RAlt") ~= 0)
        local shiftPressed = lShift or rShift
        local ctrlPressed = lCtrl or rCtrl
        local altPressed = lAlt or rAlt

        if event.data.key == "Tab" then
          self.savedCommandSelection = self.savedCommandSelection + 1
        elseif event.data.key == "Up" and altPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.max(self.currentSentMessage - 1, 1) or #self.sentMessages
            self.customChat:setText(self.sentMessages[self.currentSentMessage])
          end
          self.customChat:ignoreInputFrame()
        elseif event.data.key == "Down" and altPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.min(self.currentSentMessage + 1, #self.sentMessages) or #self.sentMessages
            self.customChat:setText(self.sentMessages[self.currentSentMessage])
          end
          self.customChat:ignoreInputFrame()
        end
      end
    end
  end


  if input.bindDown("starcustomchat", "repeatcommand") and self.lastCommand then
    self.customChat:processCommand(self.lastCommand)
  end
end

function processLeftMenuButtons()
  if widget.getScrollOffset and widget.getMaxScrollPosition then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")

    widget.setButtonEnabled("lytLeftMenu.btnDown", currentOffset[2] > 0)
    widget.setButtonEnabled("lytLeftMenu.btnUp", currentOffset[2] < widget.getMaxScrollPosition("lytLeftMenu.saButtons")[2])
  end
end

function scrollLeftMenuUp()
  if widget.getScrollOffset and widget.setScrollOffset then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")
    widget.setScrollOffset("lytLeftMenu.saButtons", vec2.add(currentOffset, {0, self.customChat.config.scrollAreaButtonMove}))
  end
end

function scrollLeftMenuDown()
  if widget.getScrollOffset and widget.setScrollOffset then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")
    widget.setScrollOffset("lytLeftMenu.saButtons", vec2.add(currentOffset, {0, -self.customChat.config.scrollAreaButtonMove}))
  end
end

function escapeTextbox()

  if not self.runCallbackForPlugins("onTextboxEscape") then
    self.customChat:setText("")
    self.customChat:blurInput()
  end
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
      self.customChat:setText("")
      self.customChat:blurInput()
      return
    end

    if string.sub(text, 1, 2) == "//" and not self.isOSBXSB then
      starcustomchat.utils.alert("chat.alerts.cannot_start_two_slashes")
      return
    end

    if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" and widget.getData("lblCommandPreview") ~= text then
      self.customChat:setText(widget.getData("lblCommandPreview") .. " ")
      self.savedCommandSelection = 0
      return
    else
      self.customChat:processCommand(text)
      self.lastCommand = text
      starcustomchat.utils.saveMessage(text)
    end
  elseif string.sub(text, 1, 1) == "@" and widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" and widget.getData("lblCommandPreview") ~= text then
    self.customChat:setText(widget.getData("lblCommandPreview") .. " ")
    self.savedCommandSelection = 0
    return
  
  elseif not self.runCallbackForPlugins("onTextboxEnter", message) then 
    if message.mode == "Whisper" then

      local data = message.whisperData or self.DMTab:selectedPlayer()
      if not data then starcustomchat.utils.alert("chat.alerts.dm_not_specified") return end


      local function sendWhisperToPlayer(targetName, targetId)
        
        -- Let's start sending SEMs by default
          message.connection = starcustomchat.utils.entityIdToConnection(player.id())
          message.nickname = player.name()
          message = self.runCallbackForPlugins("formatOutcomingMessage", message)
          self.runCallbackForPlugins("onSendMessage", message)
          
          promises:add(world.sendEntityMessage(targetId, "scc_add_message", message), function() 
            if targetId ~= player.id() then
              message.displayName = "-> " .. targetName
              world.sendEntityMessage(player.id(), "scc_add_message", message)
            end
          end, function() 
            local whisper = string.find(targetName, "%s") and "/w \"" .. targetName .. "\" " .. message.text 
              or "/w " .. targetName .. " " .. message.text

            self.customChat:processCommand(whisper)
            self.customChat.lastWhisper = {
              recipient = targetName,
              text = message.text
            }
          end)

      end

      if data.id then
        starcustomchat.utils.saveMessage(message.text)

        -- Player ID situation
        if type(data.id) == "number" then

          local whisperName = data.displayPlainText or ""
          sendWhisperToPlayer(whisperName, data.id)
        -- Party whisper
        elseif data.id == "PARTY" then
          for _, teamMember in ipairs(player.teamMembers()) do 
            if teamMember.entity ~= player.id() then
              sendWhisperToPlayer(teamMember.name, teamMember.entity)
            end
          end
        end
      end

    else
      starcustomchat.utils.saveMessage(message.text)
      message = self.runCallbackForPlugins("formatOutcomingMessage", message)
      sendMessage(message)
    end
  end
  self.customChat:setText("")
  self.customChat:blurInput()
  self.runCallbackForPlugins("afterTextboxPressed", message)
end

function textboxEnterKey()
  local text = self.customChat:getText()

  -- Add trim
  text = starcustomchat.utils.trim(text) 

  if text == "" then
    self.customChat:setText("")
    self.customChat:blurInput()
    return
  end

  sendMessageToBeSent(text, mode)
end

function sendMessage(message)
  self.customChat:sendMessage(message)
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
  self.customChat:resetCanvasOffset()
end

function openSettings()
  local chatConfigInterface = self.settingsInterface
  chatConfigInterface.enabledPlugins = config.getParameter("enabledPlugins", {})
  chatConfigInterface.chatConfig = self.customChat.config
  chatConfigInterface.localizationTable = starcustomchat.locale

  chatConfigInterface = self.runCallbackForPlugins("openSettings", chatConfigInterface)
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
  if widget.getChildAt(screenPosition) then
    local w = widget.getChildAt(screenPosition)

    local wData = widget.getData(w:sub(2))
    if wData and type(wData) == "table" then
      if wData.tooltipMode then
        return wData.mode and starcustomchat.utils.getTranslation("chat.modes." .. wData.mode) or wData.tooltipMode
      elseif wData.displayPlainText then
        return wData.displayPlainText
      elseif wData.displayText then
        return starcustomchat.utils.getTranslation(wData.displayText, wData.displayParams)
      end
    end
  end

  return self.runCallbackForPlugins("onCreateTooltip", screenPosition)
end

function customButtonCallback(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick", buttonName, data)
end

function closeSubMenu()
  self.customChat:closeSubMenu()
  self.runCallbackForPlugins("onSubMenuClose", buttonName, data)
  self.customChat:processQueue()
end

function toggleChatMovement()
  self.toggleMoveChat = widget.getChecked("btnMoveChat")
end


function saveEverythingDude()
  -- Save messages and last command
  local messages = self.customChat:getMessages()
  for _, message in ipairs(messages) do 
    self.runCallbackForPlugins("cleanMessage", message)
  end
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", util.toList(self.sentMessages))
  root.setConfiguration("scc_chat_position", pane.getPosition and pane.getPosition() or nil)
end

function closeChat()
  if not self.isOSBXSB then
    pane.dismiss()
    world.sendEntityMessage(player.id(), "scc_chat_hidden", widget.getSelectedOption("rgChatMode"))
  else
    pane.hide()
  end
end

-- OpenStarbound chat
function startChat()
  pane.show()
  self.customChat:focusInput()
  chat.setInput("")
end

function startCommand()
  pane.show()
  self.customChat:setText("/")
  self.customChat:focusInput()
  chat.setInput("")
end

function convertToChatMessage(oldMessage)
  local newMessage = {}
  newMessage.text = oldMessage.text
  newMessage.connection = oldMessage.fromConnection
  newMessage.mode = oldMessage.context.mode
  newMessage.nickname = oldMessage.fromNick
  newMessage.portrait = oldMessage.portrait
  newMessage.data = oldMessage.data
  return newMessage
end

function addMessages(messages, showPane) 
  for _, message in ipairs(messages) do
    local message = convertToChatMessage(message)
    self.customChat:addMessage(message)
  end
end

function uninit()
  local text = self.customChat:getText()
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end

  saveEverythingDude()
  widget.setSize("imgTextbox", self.customChat.config.textBoxDefaultSize)

  if handlerCutter then
    handlerCutter()
  end
  
  status.clearPersistentEffects("starchatdots")
  self.runCallbackForPlugins("uninit")
end


-- Required to be at the very bottom
require("/interface/StarboundTextboxInterface/textarea/scripts/textbox.lua")