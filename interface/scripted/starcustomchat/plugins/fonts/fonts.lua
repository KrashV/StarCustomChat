require "/interface/scripted/starcustomchat/plugin.lua"
require "/interface/scripted/combobox/combobox.class.lua"

fonts = PluginClass:new(
  { name = "fonts" }
)

function fonts:init(chat)
  self:_loadConfig()
  self.customChat = chat

  self.allFontsTable = self:getFonts()
end

function fonts:getFonts()
  local function getFontName(fontPath)
    local name = fontPath:match("([^/]+)%.%w+$") or fontPath:match("([^/]+)%.%w+$")
    return name or fontPath
  end

  local allFonts = {}

  if root.assetsByExtension then
    local woff2 = root.assetsByExtension("woff2") or {}
    local ttf = root.assetsByExtension("ttf") or {}

    local fontTable = {
      woff2, ttf
    }

    for _, tbl in ipairs(fontTable) do
        for _, value in ipairs(tbl) do
          local fontName = getFontName(value)
          allFonts[fontName] = "^font=" .. fontName .. ";" .. fontName
        end
    end
  end

  return allFonts
end

function fonts:openSettings(settingsInterface)
  settingsInterface.allFontsTable = self.allFontsTable
end

function fonts:onSettingsUpdate()
  local customFonts = root.getConfiguration("scc_custom_fonts") or {}
  self.customChat:setFonts(customFonts)
end

function fonts:uninit()

end