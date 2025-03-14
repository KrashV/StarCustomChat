require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

afk = SettingsPluginClass:new(
  { name = "afk" }
)


-- Settings
function afk:init()
  self:_loadConfig()

  self.settingsTimer = root.getConfiguration("scc_afk_timer") or 0
  widget.setText(self.layoutWidget .. ".lblAfkTimer", self.settingsTimer)
  widget.setData(self.layoutWidget .. ".lblAfkTimer", self.settingsTimer)

  widget.setData(self.layoutWidget .. ".afkTimerSpinner.up", widget.getData(self.layoutWidget .. ".afkTimerSpinner"))
  widget.setData(self.layoutWidget .. ".afkTimerSpinner.down", widget.getData(self.layoutWidget .. ".afkTimerSpinner"))

  widget.setChecked(self.layoutWidget .. ".btnDisableAfkButton", root.getConfiguration("scc_afk_button_disabled"))

  local effect = root.getConfiguration("scc_afk_effect") or "starchatafk"

  for _, btn in ipairs(config.getParameter("gui")["lytPluginSettings"].children[self.name].children["rgAfkModes"].buttons) do
    if btn.data.effect == effect then
      widget.setSelectedOption(self.layoutWidget .. ".rgAfkModes", btn.id)
      return
    end
  end
end

afk.afkTimerSpinner = {}

function afk.afkTimerSpinner.up(self)
  local mins = tonumber(widget.getData(self.layoutWidget .. ".lblAfkTimer")) or 0
  mins = math.min(mins + 1, 5)
  widget.setText(self.layoutWidget .. ".lblAfkTimer", mins)
  widget.setData(self.layoutWidget .. ".lblAfkTimer", mins)
  root.setConfiguration("scc_afk_timer", tonumber(widget.getData(self.layoutWidget .. ".lblAfkTimer")) or 0)
  save()
end

function afk.afkTimerSpinner.down(self)
  local mins = tonumber(widget.getData(self.layoutWidget .. ".lblAfkTimer")) or 0
  mins = math.max(mins - 1, 0)
  widget.setText(self.layoutWidget .. ".lblAfkTimer", mins)
  widget.setData(self.layoutWidget .. ".lblAfkTimer", mins)
  root.setConfiguration("scc_afk_timer", tonumber(widget.getData(self.layoutWidget .. ".lblAfkTimer")) or 0)
  save()
end

function afk:disableAFKButton()
  root.setConfiguration("scc_afk_button_disabled", widget.getChecked(self.layoutWidget .. ".btnDisableAfkButton"))
  save()
end

function afk:selectAfkMode()
  local mode = widget.getSelectedData(self.layoutWidget .. ".rgAfkModes").effect
  root.setConfiguration("scc_afk_effect", mode)
  save()
end