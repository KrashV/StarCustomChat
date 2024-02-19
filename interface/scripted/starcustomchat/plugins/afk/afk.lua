require "/interface/scripted/starcustomchat/plugin.lua"

afk = PluginClass:new(
  { name = "afk" }
)

function afk:init()
  self:_loadConfig()

  self.afkTime = 0
  self.afkActive = false

  self.enabled = root.getConfiguration("icc_afk_enabled") or false
  -- On init, deactivate AFK by force
  self:deactivateAFK(true)
end

function afk:update(dt)
  if not self.enabled or #input.events() > 0 then
    self.afkTime = 0
    self:deactivateAFK()
  else
    self.afkTime = math.min(self.afkTime + dt, self.timer)
    if self.afkTime >= self.timer then
      self:activateAFK()
      player.emote("sleep")
    end
  end
end

function afk:activateAFK()
  if not self.afkActive then
    if self.mode == "effect" then
      status.addPersistentEffect("starchatafk", self.effect)
    end
    self.afkActive = true
  end
end

function afk:deactivateAFK(force)
  if self.afkActive or force then
    if self.mode == "effect" then
      status.clearPersistentEffects("starchatafk")
      player.emote("idle")
    end
    self.afkActive = false
  end
end

function afk:onSettingsUpdate(data)
  self.enabled = root.getConfiguration("icc_afk_enabled")
end

function afk:settings_init(localeConfig)
  widget.setText("lblAfk", localeConfig["settings.afk_mode"])
  widget.setChecked("chbAFKMode", root.getConfiguration("icc_afk_enabled") or false)
end

function afk:settings_onSave(localeConfig)
  widget.setText("lblAfk", localeConfig["settings.afk_mode"])
end

function turnOnAFK()
  root.setConfiguration("icc_afk_enabled", widget.getChecked("chbAFKMode"))
  save()
end