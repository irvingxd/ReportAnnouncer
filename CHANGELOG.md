# Changelog

## 2.1.0

- Mouseover tally added
- Minor fixes to performance

## 2.0.1

- Shorter share strings (old ones still import)
- Statistics can include community numbers
- Faster community count when someone joins your group

## 2.0.0

New:

- Share your list
- Imported Lists
- Statistics
- Community tally (opt-in, off by default)
- and more little things

## 1.14.0

- Reports of players who are not in your party or raid are announced in `/say` instead of group chat; group chat is only used when the reported player is in the group.

## 1.13.0

- New `/reportannouncer` slash command (matches the addon name); `/reportannounce` still works.

## 1.12.0

- Announces in `/say`, `/party`, `/raid` (or instance chat) when you report a player:
  category, reasons and your details text.
- Minimap button opening a history of everyone you reported (name, reasons, details, zone, date).
- "Reported by you" summary in the mouseover tooltip of reported players (global on/off switch).
- Per-channel switches for announcing (`/say`, `/party`, `/raid`).
- Opt-in callout in party/raid chat when a player you reported is in your group.
- Players are matched by GUID; names are only a fallback for entries without an ID.
- History window hides during combat and can't be opened in combat.
- "Are you sure?" confirmation on **Clear all**.
