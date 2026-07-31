require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"

reactions = PluginClass:new(
  { name = "reactions" }
)

function reactions:init(chat)
  PluginClass.init(self, chat)

  self.stagehandEnabled = false
end

function reactions:registerStagehandHandlers(handlers)
  self.stagehandEnabled = handlers and handlers["addReaction"]
end

function reactions:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "add_reacton" then
    return selectedMessage.mode ~= "CommandResult"
  end
end

function reactions:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler( "scc_add_reaction", function(_, _, data)
    local msgInd = self.customChat:findMessageByUUID(data.uuid)
    local reaction = data.reaction

    if msgInd and data.source then
      -- Obfuscate the name if needed
      data.source.name = self.customChat.callbackPlugins("resolvePlayerData", data.source).name

      local message = self.customChat.messages[msgInd]
      message.reactions = message.reactions or {}

      for rInd, reactObj in ipairs(message.reactions) do
        if reactObj.reaction == reaction then
          reactObj.sources = reactObj.sources or {}

          local ind = 0
          -- Find if this react already has this source
          for sId, source in ipairs(reactObj.sources) do 
            if source.uuid == data.source.uuid then
              ind = sId
              break
            end
          end


          if ind ~= 0 then
            table.remove(message.reactions[rInd].sources, ind)
            if #message.reactions[rInd].sources == 0 then
              table.remove(message.reactions, rInd)
            end
          else
            data.source.name = self.customChat.callbackPlugins("resolvePlayerData", data.source).name
            table.insert(message.reactions[rInd].sources, data.source)
          end

          self.customChat:processQueue()
          return
        end
      end

      -- If it's a first reaction
      table.insert(message.reactions, {
        reaction = reaction,
        sources = {data.source}
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
    selectEmojiPane.stagehandType = self.stagehandEnabled and self.stagehandType
    selectEmojiPane.textboxHint = starcustomchat.utils.getTranslation("settings.search")
    selectEmojiPane.allLabel = starcustomchat.utils.getTranslation("reactions.reactselect.all")
    selectEmojiPane.recentLabel = starcustomchat.utils.getTranslation("reactions.reactselect.recent")

    player.interact("ScriptPane", selectEmojiPane)
  end
end

function reactions:onCreateTooltip(screenPosition)
  local selectedMessage = self.customChat:selectMessage(screenPosition)
  if selectedMessage and selectedMessage.reactions then

    for _, reactObj in ipairs (selectedMessage.reactions) do 
      if rect.contains(rect.withSize(reactObj.position, {16, 16}), self.customChat.topCanvas:mousePosition()) then
        local text = ":^yellow;" .. reactObj.reaction .. "^reset;: " 
        for i, source in ipairs(reactObj.sources) do
            text = text .. source.name
            if i < #reactObj.sources then
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
    local selectedMessage = self.customChat:selectMessage(screenPosition, true)
    if selectedMessage and selectedMessage.reactions then
      
      for _, reactObj in ipairs (selectedMessage.reactions) do 
        if rect.contains(rect.withSize(reactObj.position, {16, 16}), screenPosition) then
          local data = {
            reaction = reactObj.reaction,
            uuid = selectedMessage.uuid,
            source = {
              name = player.name(),
              uuid = player.uniqueId()
            }
          }
      
          if self.stagehandEnabled and self.stagehandType and self.stagehandType ~= "" then
            starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "addReaction", data = data})
          else
            for _, pl in ipairs(starcustomchat.utils.playersInRadius()) do 
              world.sendEntityMessage(pl, "scc_add_reaction", data)
            end
          end
          return true
        end
      end
    end
  end
end
