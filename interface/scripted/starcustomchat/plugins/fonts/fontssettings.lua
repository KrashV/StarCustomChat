require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

fonts = SettingsPluginClass:new(
  { name = "fonts" }
)


-- Settings
function fonts:init(chat)
  self:_loadConfig()
  self.chat = chat

  self.fonts = self:getFonts()

  local currentFont = root.getConfiguration("scc_font") or "hobo"

  Combobox:bind(self.layoutWidget .. "." .. "btnSelectFont", function(data)
    self:selectedCombobox(data)
  end, self.fonts, currentFont, true)

  
  self.widget.setText("btnSelectFont", currentFont)

end


local function getFontName(fontPath)
  local name = fontPath:match("([^/]+)%.%w+$") or fontPath:match("([^/]+)%.%w+$")
  return name or fontPath
end

function fonts:getFonts()

  local woff2 = root.assetsByExtension("woff2") or {}
  local ttf = root.assetsByExtension("ttf") or {}

  local fontTable = {
    woff2, ttf
  }

  local allFonts = {}

  for _, tbl in ipairs(fontTable) do
      for _, value in ipairs(tbl) do
          table.insert(allFonts, getFontName(value))
      end
  end

  return allFonts
end

function fonts:isAvailable()
  return root.assetsByExtension
end


function fonts:selectedCombobox(newFont)
  self.widget.setText("btnSelectFont", newFont)
  root.setConfiguration("scc_font", newFont)
  save()
end

function fonts:uninit()

end