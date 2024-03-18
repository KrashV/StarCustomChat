require "/interface/scripted/starcustomchat/plugin.lua"

oocchat = PluginClass:new(
  { name = "oocchat" }
)

function oocchat:init()
  self:_loadConfig()
  local colors = root.getConfiguration("scc_custom_colors") or {}
  self.OOCcolor = colors["occtext"] or self.defaultColor
end

function oocchat:formatIncomingMessage(message)
  if message.text:find("^%s*%(%(") and (message.text:find("^%s*%(%b()%)%s*$") or not message.text:find("%)%)")) then
    if message.mode == "Broadcast" or message.mode == "Local" then
      message.mode = "OOC"
    end
  end

  if message.text:find("%(%(") then
    message.text = string.gsub(message.text, "%(%(.-%)%)", "^#" .. self.OOCcolor .. ";%1^reset;")
    message.text = string.gsub(message.text, "(.*)%(%((.-)$", "%1^#" .. self.OOCcolor .. ";((%2")
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