require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"

reactions = PluginClass:new(
  { name = "reactions" }
)

function reactions:init(chat)
  self:_loadConfig()

  self.customChat = chat
end

function reactions:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "add_reacton" then
    return selectedMessage.mode ~= "CommandResult"
  end
end

function reactions:registerMessageHandlers(shared)
  shared.setMessageHandler( "scc_add_reaction", function(_, _, data)
    local msgInd = self.customChat:findMessageByUUID(data.uuid)
    local reaction = data.reaction

    if msgInd then
      local message = self.customChat.messages[msgInd]
      message.reactions = message.reactions or {}

      for rInd, reactObj in ipairs(message.reactions) do
        if reactObj.reaction == reaction then
          local ind = index(reactObj.nicknames, data.nickname)
          if ind and ind ~= 0 then
            table.remove(message.reactions[rInd].nicknames, ind)
            if #message.reactions[rInd].nicknames == 0 then
              table.remove(message.reactions, rInd)
            end
          else
            table.insert(message.reactions[rInd].nicknames, data.nickname)
          end

          self.customChat:processQueue()
          return
        end
      end

      table.insert(message.reactions, {
        reaction = reaction,
        nicknames = {data.nickname}
      })
      self.customChat:processQueue()
    end
  end)
end

function reactions:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and selectedMessage.uuid and buttonName == "add_reacton" then
    local selectEmojiPane = root.assetJson("/interface/scripted/starcustomchat/plugins/reactions/reactionselect/reactionselect.json")
    selectEmojiPane.messageUUID = selectedMessage.uuid
    selectEmojiPane.text = selectedMessage.text
    selectEmojiPane.nickname = selectedMessage.nickname

    player.interact("ScriptPane", selectEmojiPane)
  end
end

function reactions:onCreateTooltip(screenPosition)
  local selectedMessage = self.customChat:selectMessage()
  if selectedMessage and selectedMessage.reactions then

    local currentPos = vec2.sub(vec2.sub(screenPosition, widget.getPosition("cnvHighlightCanvas") ), config.getParameter("gui")["panefeature"]["offset"])

    for _, reactObj in ipairs (selectedMessage.reactions) do 
      if rect.contains(rect.withSize(reactObj.position, {16, 16}), currentPos) then
        local text = ":^yellow;" .. reactObj.reaction .. "^reset;: " 
        for i, nick in ipairs(reactObj.nicknames) do
            text = text .. nick
            if i < #reactObj.nicknames then
                text = text .. ", "
            end
        end
        return text
        
      end
    end
  end
end

function reactions:onCanvasClick(screenPosition, button, isButtonDown)
  if button == 0 and isButtonDown then
    local selectedMessage = self.customChat:selectMessage()
    if selectedMessage and selectedMessage.reactions then
      
      for _, reactObj in ipairs (selectedMessage.reactions) do 
        if rect.contains(rect.withSize(reactObj.position, {16, 16}), screenPosition) then
          local data = {
            nickname = player.name(),
            reaction = reactObj.reaction,
            uuid = selectedMessage.uuid
          }
      
          for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
            world.sendEntityMessage(pl, "scc_add_reaction", data)
          end      
          return true
        end
      end
    end
  end
end