require "/interface/scripted/starcustomchat/plugin.lua"

afk = PluginClass:new(
  { name = "afk" }
)

function afk:init()
  self:_loadConfig()

  self.timer = (root.getConfiguration("icc_afk_timer") or 0) * 60
  self.afkTime = self.timer
  self.afkActive = false
  self.forcedAfkTimer = 0
  -- On init, deactivate AFK by force
  self:deactivateAFK(true)
end

function afk:update(dt)
  widget.setVisible("btnStartAfk", self.timer ~= 0)
  if self.forcedAfkTimer > 0 then
    self.forcedAfkTimer = math.max(self.forcedAfkTimer - dt, 0)
  else
    if self.timer == 0 or #input.events() > 0 then
      self.afkTime = self.timer
      self:deactivateAFK()
    else
      self.afkTime = math.max(self.afkTime - dt, 0)
      if self.afkTime <= 0 then
        self:activateAFK()
      end
    end
  end
end

function afk:onCustomButtonClick(btnName, data)
  if btnName == "btnStartAfk" then
    self.forcedAfkTimer = self.forcedAfkTimer == 0 and self.afkIgnoreTime or 0
    self.afkTime = self.timer
    self:activateAFK()
  end
end

function afk:activateAFK()
  if not self.afkActive then
    if self.mode == "effect" then
      status.addPersistentEffect("starchatafk", self.effect)
    end
    player.emote("sleep")
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
  self.timer = (root.getConfiguration("icc_afk_timer") or 0) * 60
end