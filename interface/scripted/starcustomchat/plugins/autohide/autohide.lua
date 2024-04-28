require "/interface/scripted/starcustomchat/plugin.lua"

autohide = PluginClass:new(
  { name = "autohide" }
)

function autohide:init()
  self:_loadConfig()

  self.timer = (root.getConfiguration("scc_autohide_timer") or 0)
  self.autohideTime = self.timer
  self.ignoreServerMessages = root.getConfiguration("scc_autohide_ignore_server_messages") or false
end

function autohide:onCursorOverride()
  self.autohideTime = self.timer
end

function autohide:update(dt)
  if self.timer > 0 and self.autohideTime <= 0 then
    closeChat()
  end
  self.autohideTime = widget.hasFocus("tbxInput") and self.timer or math.max(self.autohideTime - dt, 0)
end

function autohide:onReceiveMessage(message)
  if message.connection and (message.connection == 0 and not self.ignoreServerMessages) or message.connection ~= 0 then
    self.autohideTime = self.timer
  end
end

function autohide:onSettingsUpdate(data)
  self.timer = (root.getConfiguration("scc_autohide_timer") or 0)
  self.autohideTime = self.timer
  self.ignoreServerMessages = root.getConfiguration("scc_autohide_ignore_server_messages") or false
end