--[[
  Chat message instance
]]

IrdenMessage = {
  lines = {},
  authorId = 0,
  portrait = "/assetmissing.png"
}

IrdenMessage.__index = IrdenMessage

function IrdenMessage:create (text, authorId)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self

  o.lines = {text}
  o.authorId = authorId
  return o
end

function IrdenMessage:toJson()
  return {
    lines = self.lines,
    authorId = self.authorId,
    portrait = self.portrait
  }
end

function IrdenMessage:fromJson(json)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self

  o.lines = json.lines
  o.authorId = json.authorId
  o.portrait = json.portrait
  return o
end