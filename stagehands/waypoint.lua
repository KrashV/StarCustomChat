require "/scripts/messageutil.lua"
require "/stagehands/irden/irdencustomchathandler.lua"

function init()
  local broadcastArea = config.getParameter("broadcastArea")
  message.setHandler("broadcastArea", function() return broadcastArea end)
  
  local waypointName = config.getParameter("waypoint")
  if waypointName and not storage.setWaypoint then
    local waypoints = world.getProperty("waypoints") or {}
    waypoints[waypointName] = waypoints[waypointName] or {}
    table.insert(waypoints[waypointName], entity.position())
    world.setProperty("waypoints", waypoints)
    storage.setWaypoint = true
  end

  -- That's new
  iccstagehand_init()
end

function update(dt)
  iccstagehand_update(dt)
end