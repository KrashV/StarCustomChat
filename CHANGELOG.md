## Bugfixes
Fixed hightlighting messages when the cursor is not at the chat pane.
Fixed the portraits not being requested on join.
Fixed the DM character icon being misplaced if sprites are not 43x43.
Moved the language button in settings lower in z level.
Cleaned up the Fonts layouts.
Fixed the command preview layout overlapping with the submenu.
Fixed the commands from one mod overriding the other one.
Fixed the 'edited' label always showing up as '???' if SCCRP is not installed.

## Features
MULTILINE TEXTBOX!! Thanks D.
CHAT RESIZING
Added the /filter command to filter the messages in the chat by text.
CommandPreview now enlarges to fit the longer descriptions.
Deleted BiggerChat.
Added the emojies window (left menu button).
The sent messages are now trimmed from the beginning and the end. Does not remove spaces in between.
Last message scroll is now triggered by Alt + Up/Down.
Smoothed out the change of the chat size.
Font names are now sorted by name.
Added the /afk command. Does the same as the corresponding button.
CharacterVoice: Added volume slider
CharacterVoice: The sounds are now picked from the list of all the sounds
ModeSounds: The sounds are now picked from the list of all the sounds

## API
New functions to set, get text and focus of the input textbox.
New plugin method for editting the messages.
Moved the settings images to a separate folder.
The server can now pass a list of its supported commands dynamically.
Moved the images around internally.