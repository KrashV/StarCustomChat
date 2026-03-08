function patch(config)
  if assets.scan then
      local commandFiles = assets.scan(".starcustomchat.commands")
      for _, path in ipairs(commandFiles or {}) do 
        local metadata = assets.sourceMetadata(path)
        local groupName = metadata and metadata.name or "EXTERNAL"
        config[groupName] = config[groupName] or {}
        config[groupName] = sb.jsonMerge(config[groupName], assets.json(path))
      end
  end

  return config
end