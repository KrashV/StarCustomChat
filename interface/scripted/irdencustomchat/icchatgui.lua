require "/scripts/messageutil.lua"
require "/scripts/timer.lua"
require "/scripts/util.lua"
require "/scripts/irden/chat/chat_class.lua"
require "/interface/scripted/irdencustomchat/icchatutils.lua"

function init()
  player.setProperty("irdenCustomChatIsOpen", true)

  self.stagehandName = "irdencustomchat"
  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]
  self.charactersListWidth = widget.getSize("lytCharactersToDM.background")[1]
  local chatConfig = config.getParameter("config")
  createTotallyFakeWidget(chatConfig.wrapWidth, chatConfig.font.baseSize)

  self.localeConfig = root.assetJson(string.format("/interface/scripted/irdencustomchat/languages/%s.json", icchat.utils.getLocale()))
  
  self.irdenChat = IrdenChat:create(self.canvasName, self.highlightCanvasName, self.stagehandName, chatConfig, player.id())
  self.irdenChat:createMessageQueue()
  self.contacts = {}
  self.tooltipFields = {}

  widget.setSize("backgroundImage", {self.chatWindowWidth, self.irdenChat.config.expandedBodyHeight})  
  widget.setSize("lytCharactersToDM.background", {self.charactersListWidth, self.irdenChat.config.expandedBodyHeight})
  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

  localeChat()
  --setMode(_, {mode = "Local"})

  timers:add(1, checkDMs)
  self.irdenChat:processQueue()
end

function createTotallyFakeWidget(wrapWidth, fontSize)
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidth,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabel")
end

function localeChat()
  widget.setText("rgChatMode.-1", icchat.utils.getTranslation("chat.modes.local"))
  widget.setText("rgChatMode.0", icchat.utils.getTranslation("chat.modes.party"))
  widget.setText("rgChatMode.1", icchat.utils.getTranslation("chat.modes.private"))
  widget.setText("rgChatMode.2", icchat.utils.getTranslation("chat.modes.fight"))
  widget.setText("rgChatMode.3", icchat.utils.getTranslation("chat.modes.broadcast"))

  -- Unfortunately, to reset HINT we have to recreate the textbox
  local standardTbx = config.getParameter("gui")["tbxInput"]
  standardTbx.hint = icchat.utils.getTranslation("chat.textbox.hint")

  pane.removeWidget("tbxInput")
  pane.addWidget(standardTbx, "tbxInput")
end

function update()
  timers:update()
  promises:update()
  self.irdenChat:clearHighlights()
  checkGroup()
  checkTyping()
  processButtonEvents()
end

function checkTyping()
  --[[
  if widget.hasFocus("tbxInput") then
    effectsAnimator.setAnimationState("busy", "chatting")
  else
    effectsAnimator.setAnimationState("busy", "none")
  end
  ]]
end

function checkGroup()
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode.0", false)
    widget.setFontColor("lblParty", self.irdenChat.config.disabledModeColor)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", -1)
      widget.setFontColor("lblParty", self.irdenChat.config.unselectedModeColor)
    end
  else
    widget.setButtonEnabled("rgChatMode.0", true)
  end
end

function checkDMs()
  if widget.active("lytCharactersToDM") then
    populateList()
  end
  timers:add(1, checkDMs)
end

function populateList() --edited to use the state players keep in their deployment
  icchat.utils.sendMessageToStagehand(self.stagehandName, "icc_getAllPlayers", _, function(players)  
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

  end)
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
    if event.type == "MouseWheel" then 
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

  if string.sub(message, 1, 1) == "/" then
    self.irdenChat:processCommand(message)
  elseif widget.getSelectedData("rgChatMode").mode == "Whisper" then
    local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
    if not li then interface.queueMessage(icchat.utils.getTranslation("chat.alerts.dm_not_specified")) return end

    local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
    if (not world.entityExists(data.id) and index(self.contacts, data.id) == 0) then interface.queueMessage(icchat.utils.getTranslation("chat.alerts.dm_not_found")) return end

    self.irdenChat:processCommand("/w " .. widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).displayText .. " " .. message)

  else
    self.irdenChat:sendMessage(message, widget.getSelectedData("rgChatMode").mode)
  end
  widget.setText(widgetName, "")
  widget.blur(widgetName)
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
  player.setProperty("irdenCustomChatIsOpen", nil)
end