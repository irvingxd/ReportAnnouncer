# Changelog

## 2.0.0

- **Sharing:** Export your list as an encoded string (`RA1:...`) and Import lists other people shared. Strings carry a checksum, so damaged or edited ones are rejected, and imported text is sanitised.
- **Imported Lists** are kept separate from your own list and are never used for tooltips or group callouts.
- **Statistics** tab: what people get reported for (categories, reasons), where, and repeat offenders; optionally including imported lists.
- The window now has side tabs: Personal List, Imported Lists, Statistics, Options. All settings (chat switches, tooltips, callout, message) moved into the Options tab; the Game Menu entry just opens it.
- Custom message: variables `{name}` (required), `{category}`, `{reasons}`, `{details}`, `{zone}`, `{date}`, optional `[ ... ]` parts, live preview and reset.
- New commands: `/reportannouncer stats`, `export`, `import`.
- **Clear all** moved to the left, **Close** on the right.
- Needs a full game restart after updating (new files).

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
