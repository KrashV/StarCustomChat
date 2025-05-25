require "/interface/scripted/starcustomchat/plugin.lua"
require "/interface/scripted/combobox/combobox.class.lua"

fonts = PluginClass:new(
  { name = "fonts" }
)

function fonts:init(chat)
  self:_loadConfig()
  self.customChat = chat
end

function fonts:onSettingsUpdate()
  local newFont = root.getConfiguration("scc_font") or "hobo"
  self.customChat:setFont(newFont)
end

function fonts:uninit()

end