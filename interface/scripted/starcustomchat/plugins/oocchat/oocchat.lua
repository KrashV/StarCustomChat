require "/interface/scripted/starcustomchat/plugin.lua"

oocchat = PluginClass:new(
  { name = "oocchat" }
)

function oocchat:init()
  self:_loadConfig()
end

function oocchat:formatIncomingMessage(message)
  if message.text:find("^%s*%^?g?r?a?y?;?%(%(") and (message.text:find("^%s*%^?g?r?a?y?;?%(%b()%)%^?r?e?s?e?t?;?$") or not message.text:find("%)%)")) then
    if message.mode == "Broadcast" or message.mode == "Local" then
      message.mode = "OOC"
    end
  end

  if message.text:find("%(%(") then
    if message.mode ~= "OOC" then
      message.text = string.gsub(message.text, "%(%(.-%)%)", "^gray;%1^reset;")
      message.text = string.gsub(message.text, "(.*)%(%((.-)$", "%1^gray;((%2")
    end
  end
  return message
end

function oocchat:formatOutcomingMessage(message)
  if message.mode == "OOC" then
    message.text = string.format("((%s))", message.text)
    message.mode = "Broadcast"
  end
  return message
end