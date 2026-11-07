# Report Announcer

A World of Warcraft addon that announces who you reported and why, keeps a history of
everyone you have reported, and warns you when one of them shows up again.

Works with the report dialog ("WoW Customer Support") on retail and the Classic clients
that share it (including Classic Forever).

## Features

- **Chat announcement** when you press *Report*: `/raid` if you're in a raid, `/party`
  if you're in a party (instance chat in LFG groups), otherwise `/say`. Reports of players who are not in your group go to `/say` instead:

  `Rutio Argento was reported for Cheating, the reason: Hacking, Botting. Details: botting forever fishing`

- **Share your list:** *Export* gives an encoded string (`RA1:...`) you can send to others; *Import* adds a list someone sent you. Imported lists are kept separate and never appear in tooltips or callouts. Strings are checksummed (this is encoding, not encryption).
- **Community tally (opt-in):** guild, group, one chosen channel and friends (character + Battle.net) who run the addon share just a report count (no names); the total shows in Statistics.
- **Statistics tab:** what people get reported for, reasons, zones and repeat offenders.
- **Side tabs:** Personal List, Imported Lists, Statistics, Options.
- **Custom messages:** in the Messages tab, edit the report message and the group callout, and add more variants with **+** (one is picked at random). Variables: `{name}`, `{category}`, `{reason}`, `{details}`, `{zone}`, `{date}`; empty variables drop their own words.
- **Minimap button** that opens your report history: name, category and reasons, your
  details, the zone (including sub-zone) and the date.
- **Tooltip summary** ("Reported by you") when you mouse over a player you reported.
- **Group callout (opt-in):** if a player you reported is in your party or raid, a notice is
  posted in party/raid chat, including your details.
- **Switches** for the tooltip, the callout and each chat channel (`/say`, `/party`, `/raid`).
- Players are matched by **GUID**; names are only a fallback for old entries without an ID.
- The window closes when combat starts and can't be opened in combat.

## Install

- **CurseForge:** install with the CurseForge app.
- **Manually:** copy the `ReportAnnouncer` folder into
  `World of Warcraft/_retail_/Interface/AddOns/` (or `_classic_`, `_classic_era_`, ...).
  Restart the game after adding or changing files listed in the `.toc`.

## Commands

| Command | What it does |
| --- | --- |
| `/reportannouncer` (or `/reportannounce`) | Turn all chat announcing on/off (history is still recorded) |
| `/reportannouncer history` | Open the history window |
| `/reportannouncer minimap` | Show/hide the minimap button |
| `/reportannouncer options` | Open the options (settings) |
| `/reportannouncer stats` | Open the Statistics tab |
| `/reportannouncer export` / `import` | Share your list / import someone else's |
| `/reportannouncer test` | Send a sample message |
| `/reportannouncer check` | Run the group callout check now and explain the result |

## Notes

- Posting names publicly can be seen as harassment. The callout is **off by default** and
  every channel can be switched off.
- `/say` from an addon is only allowed on a player click; the addon sends its message on the
  *Report* button's own click for that reason.

## Development

```
npm install --no-save luaparse@0.3.1
node .github/scripts/check-lua.js   # syntax-checks every .lua file and the .toc file list
```

Pull requests opened by the repo owner are squash-merged automatically once the
**Lua syntax check** passes. A `v*` tag (for example `v1.13.0`) builds a package with the
[BigWigs packager](https://github.com/BigWigsMods/packager) and uploads it to CurseForge:

1. Create the CurseForge project and add `## X-Curse-Project-ID: <id>` to `ReportAnnouncer.toc`.
2. Add the repository secret `CF_API_KEY` (a CurseForge API token).
3. `git tag v1.13.0 && git push origin v1.13.0`

## License

MIT
