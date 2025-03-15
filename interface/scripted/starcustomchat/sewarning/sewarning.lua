function init()
  self.reason = config.getParameter("reason")
  local locales = root.assetJson("/interface/scripted/starcustomchat/languages/locales.json")
  self.selectedLocale = 1
  self.localeConfigs = {}
  for loc, conf in ipairs(locales) do 
    table.insert(self.localeConfigs, root.assetJson(string.format("/interface/scripted/starcustomchat/languages/%s.json", loc)))
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