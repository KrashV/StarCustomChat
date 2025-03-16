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
The base mod includes two exemplary plugins: for proximity based chat and OOC chat.
They are disabled by default and require patching the **/scripts/starcustomchat/enabledplugins.json** file. For example:

    [  {"op": "add", "path": "/-", "value": "oocchat" },   { "op": "add", "path": "/-", "value": "proximitychat" } ]
If you want to create your own plugins - which I strongly recommend you to do! - you can look at the configuration there.

# Contact me
If you have bug reports, suggestions or other ideas, you can contact me on Discord (@Degranon) or join [my Discord server](https://discord.gg/gnu8xRjS9p)
