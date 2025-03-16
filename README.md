# Custom chat
Starbound mod for replacing an old and boring chat with a flashy new and customazible piece of experience.
Brought to you with love by Degranon


# Functionality

Custom chat provides you with several in-built functions like these:

 - Localization: currently supports English and Russian languages
 - Two Discord inspired modes: full and compact
 - Quick and easy DM tab
 - Collapsing of long messages
 - Ability to copy messages
 - Message channel filtration
 - Command autofill (press **TAB** to scroll through)
 - Plugin system that allows you to expand the functionality even more!
![Full avatar mode](https://i.imgur.com/yLO8qWg.png)
![Short mode with disabled commands showcase](https://i.imgur.com/oXtXDp7.png)
# Prerequirements
This mod requires [StarExtensions](https://github.com/StarExtensions/StarExtensions) v.1.9.24+ by Kae, [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound) 0.1.8+ or [xStarbound](https://github.com/xStarbound/xStarbound) v3.5.2.1+ by FezzedOne.

# Controls

 - **Mousewheel**: scroll chat up / down
 - **Ctrl** + **Mousewheel**: change font size
 - **Shift** + **Mousewheel**: scroll up / down twice as fast
 - **Shift** + **Up**/**Down**: scroll through last sent messages
 - **P** (default, change in /binds): repeat last command

# Plugins
The base mod already includes several plugins within. They are disabled by default and require patching the **/scripts/starcustomchat/enabledplugins.json** file. For example:

    [  {"op": "add", "path": "/-", "value": "oocchat" },   { "op": "add", "path": "/-", "value": "proximitychat" } ]
If you want to create your own plugins - which I strongly recommend you to do! - you can look at the configuration there.


### Stagehand configuration

#### Patch files
Several plugins can benefit from creating a server-side stagehand to log the messages, change them, filter etc etc.

First, you need to create a server-specific patch for your own server and distribute it among your players. The patch could be a simple mod that has patch files like the following:

| Plugin                  | Patch Path                                                                        | Stagehand Message Type Data | Player Message Handler |
|-------------------------|-----------------------------------------------------------------------------------|-----------------------------|------------------------|
| Edit Message (SCCRRP)   | /interface/scripted/starcustomchat/plugins/editmessage/editmessage.json.patch     | editMessage                 | scc_edit_message       |
| Proximity Chat (SCCRRP) | /interface/scripted/starcustomchat/plugins/proximitychat/proximitychat.json.patch | sendProxyMessage            | scc_add_message        |
| Reactions               | /interface/scripted/starcustomchat/plugins/reactions/reactions.json.patch         | addReaction                 | scc_add_reaction       |
| Reply                   | /interface/scripted/starcustomchat/plugins/reply/reply.json.patch                 | addReply                    | scc_add_relpy          |
| Stickers                | /interface/scripted/starcustomchat/plugins/stickers/stickers.json.patch           | sendSticker                 | scc_add_message        |
| Languages               | /interface/scripted/starcustomchat/plugins/languages/languages.json               | retrieveLanguages           | scc_rp_languages       |

The contains of the patch files are identical:

```diff
[
  { "op": "replace", "path": "/parameters/stagehandType", "value": "STAGEHAND_NAME"}
]
```

#### Stagehand scripts

Since we only want to send the data and forgive about it, there's no need to spawn a long-living stagehand. Instead, we create a new stagehand with some data in its config.
For example, when we send the proximity chat message, we create a new stagehand with `stagehandType` type and the following data:

```json
{
  "message": "sendProxyMessage",
  "data": {
    "proximityRadius": "<Proximity radius set by the user>",
    "time": "<Planet time>",
    // Common message data
  }
}
```

Each `message` sent to the stagehand usually means that we'll hope that the stagehand will send us the entity message described in the far right column of the table above - and then die, since it's done its purpose. For example:

```lua
function init()
  local purpose = config.getParameter("message")
  local data = config.getParameter("data")

  if purpose == "sendProxyMessage" then
    logProximityMessage()
    sendProximityMessage(data, data.proximityRadius)
  elseif

    -- All the other stuff
  end
  stagehand.die() -- We don't need it anymore
end
```

# Contributors

* @Degranon - main author
* @Novaenia - OpenStarbound support
* @FezzedOne - xStarbound suppport

# Contact me
If you have bug reports, suggestions or other ideas, you can contact me on Discord (@Degranon) or join [my Discord server](https://discord.gg/gnu8xRjS9p)
