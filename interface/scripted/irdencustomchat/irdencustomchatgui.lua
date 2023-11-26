require "/scripts/messageutil.lua"
require "/scripts/timer.lua"
require "/scripts/irden/chat/chat_class.lua"

function init()
  player.setProperty("irdenCustomChatIsOpen", true)

  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]
  self.charactersListWidth = widget.getSize("lytCharactersToDM.background")[1]
  local chatConfig = config.getParameter("config")
  createTotallyFakeWidget(chatConfig.wrapWidth, chatConfig.font.baseSize)
  self.irdenChat = IrdenChat:create(self.canvasName, self.highlightCanvasName, "irdencustomchat", chatConfig, player.id())
  self.irdenChat:createMessageQueue()
  self.contacts = {}
  self.tooltipFields = {}

  widget.setFontColor("lblLocal", self.irdenChat.config.selectedModeColor)
  widget.setFontColor("lblServer", self.irdenChat.config.disabledModeColor)
  widget.setSize("backgroundImage", {self.chatWindowWidth, self.irdenChat.config.expandedBodyHeight})  
  widget.setSize("lytCharactersToDM.background", {self.charactersListWidth, self.irdenChat.config.expandedBodyHeight})
  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

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

function update()
  timers:update()
  promises:update()
  self.irdenChat:clearHighlights()
  checkGroup()
  checkTyping()
end

function checkTyping()
  if widget.hasFocus("tbxInput") then
    effectsAnimator.setAnimationState("busy", "chatting")
  else
    effectsAnimator.setAnimationState("busy", "none")
  end
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

function populateList(online) --edited to use the state players keep in their deployment
	online = online or world.playerQuery(world.entityPosition(player.id()), 500, {boundMode = "position", order = "nearest"}) or {}
	--online is either provided by list_loop or fetched.
  --then add online players
	for _, id in ipairs(online) do
		local index = index(self.contacts, id)
		if index == 0 then
			local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
			drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", id)
			widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
        id = id,
        displayText = world.entityName(id)
      })
      self.tooltipFields["lytCharactersToDM.saPlayers.lytPlayers." .. li] = world.entityName(id)
			table.insert(self.contacts, id)
		end
	end
	
	-- Check if any player left
	for i, id in ipairs(self.contacts) do
		if index(online, id) == 0 then
			widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i)
			table.remove(self.contacts, i)
		end
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
    if not li then interface.queueMessage("Выбери персонажа, чтобы отправить текст") return end

    local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
    if not world.entityExists(data.id) then interface.queueMessage("Игрок не на планете") return end

    self.irdenChat:processCommand("/w " .. world.entityName(data.id) .. " " .. message)

  else
    self.irdenChat:sendMessage(message, widget.getSelectedData("rgChatMode").mode)
  end
  widget.setText(widgetName, "")
  widget.blur(widgetName)
end

function setMode(_, data)
  local modes = {"Local", "Broadcast", "Party", "Proximity", "Whisper", "Announcement"}
  for _, mode in ipairs(modes) do 
    widget.setFontColor("lbl" .. mode, self.irdenChat.config.unselectedModeColor)
  end
  widget.setFontColor("lbl" .. data.mode, self.irdenChat.config.selectedModeColor)

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