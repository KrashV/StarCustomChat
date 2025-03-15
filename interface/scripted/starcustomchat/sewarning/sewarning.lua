function init()
  self.reason = config.getParameter("reason")
  local locales = root.assetJson("/interface/scripted/starcustomchat/locales/locales.json")
  self.selectedLocale = 1
  self.localeConfigs = {}
  for loc, conf in pairs(locales) do 
    table.insert(self.localeConfigs, root.assetJson(string.format("/interface/scripted/starcustomchat/locales/%s.json", loc)))
  end

  setTexts()
end

function setTexts()
  widget.setText("btnChangeLocale", self.localeConfigs[self.selectedLocale]["name"])
  widget.setText("close", self.localeConfigs[self.selectedLocale]["greeting.close"])
  widget.setText("text", self.localeConfigs[self.selectedLocale]["greeting." .. self.reason] or self.localeConfigs[self.selectedLocale]["greetings.unknown"])
end

function changeLocale()
  self.selectedLocale = self.selectedLocale % #self.localeConfigs + 1
  setTexts()
end