require "/interface/scripted/starcustomchat/plugin.lua"

images = PluginClass:new(
  { name = "images" }
)

function images:init()
  self:_loadConfig()
end

function images:preventTextboxCallback(message)
  local image = message.text
  if image and image ~= "" and string.find(image, "^/%w+%.png") then
    if pcall(function() root.imageSize(image) end) then
      local imageSize = root.imageSize(image)
      if imageSize[1] > 64 or imageSize[2] > 64 then
        starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
        blurTextbox("tbxInput")
        return true
      else

        local message = {
          image = image,
          mode = widget.getSelectedData("rgChatMode").mode,
          connection = player.id() // -65536,
          nickname = player.name(),
          text = ""
        }

        for _, pl in ipairs(world.playerQuery(world.entityPosition(player.id()), 100)) do 
          world.sendEntityMessage(pl, "icc_sendToUser", message)
        end
      end
    else
      starcustomchat.utils.alert("settings.mainchat.alerts.image_error")
      blurTextbox("tbxInput")
      return true
    end
    blurTextbox("tbxInput")
    return true
  end
  return false
end

function images:onReceiveMessage(message)
  if message and message.image and string.find(message.image, "^/%w+%.png") then
    local imageSize = root.imageSize(message.image)
    if imageSize[1] > 64 or imageSize[2] > 64 then
      starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
      message.text = ""
    else
      message.text = ""
      message.imageSize = imageSize
    end
  end
end

function images:afterTextboxPressed(message)
  if message.image then
    player.say(" ")
  end
end