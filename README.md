# Trovekeeper

Shows the hidden **Sturdy Chests** of World of Warcraft: Midnight delves on the
world map, on the minimap and in a small list window. Click a chest anywhere and
Trovekeeper hands the position to TomTom as a waypoint.

Covers all **12 Midnight delves** and their *Discoveries* achievements, which
together make up *Midnight: Leave No Treasure Unfound* and the *Treasure Seeker*
title. The bountiful list covers whatever the game is running, Midnight or The
War Within.

![Interface](https://img.shields.io/badge/Interface-120100-blue) ![Version](https://img.shields.io/badge/Version-1.0.0-green)

## What it does

- **World map pins** on the delve's own map, numbered, greyed out once found.
- **Minimap pins** while you are inside the delve.
- **Entrance pins** on the zone maps, so you can find the delves themselves.
- **A list window** - semi-transparent, movable - in two blocks: the delves
  running **bountiful** right now, and the chests of the delve you are
  **standing in**. A block with nothing to say takes no space, so outside a
  delve the chest block is simply not there.
- **TomTom waypoints** on click. The list header waypoints every chest you still
  need in one go.
- **Found markers** taken from the achievement itself, account-wide.

## Installation

Download the zip of the latest release from
<https://github.com/lasse-tech/trovekeeper/releases> and unpack it into
`World of Warcraft/_retail_/Interface/AddOns`, so that the folder
`Interface/AddOns/Trovekeeper` holds `Trovekeeper_Mainline.toc`.

## Usage

| Action | Result |
| --- | --- |
| `/tk` | toggle the list window |
| `/tk map` | waypoint every chest you have not found yet |
| `/tk entrance` | waypoint the delve entrance |
| `/tk setmap` | bind the map you are standing on to this delve |
| `/tk reset` | forget learned positions and progress |
| `/tk export` | print the coordinates the addon currently holds |
| `/tk diag` | report the map id and whether minimap pins are possible here |
| `/tk pois` | print the map POIs the bountiful scan sees |
| `/tk calls` | show or hide the Delver's Call list |
| `/tk setquest <delve> [<id>]` | bind a quest to a delve by hand |
| `/tk options` | open the settings, credits and version |
| Click a chest | set a TomTom waypoint |
| Right-click a chest | mark it found or not found by hand |
| Click a bountiful delve | waypoint it |
| Ctrl-click one | bind the quest you are tracking to it |
| Click the Bountiful heading | scan the maps again |
| Shift-click the list | hide the window |
| Drag the list | move it |

The minimap button does the same: click to toggle the list, right-click for the
options. Author, version, copyright and the credits sit at the top and bottom of
the options panel.

The window remembers where you put it and whether you had it open, across
sessions. Drag it by any part of it - the header and the rows pass the drag
through to the window.

## How it knows where the chests are

Two different things, and it is worth knowing which is which.

**The coordinates** ship with the addon, taken from public delve guides that
agree with each other, and are then *sharpened in-game*: whenever the game puts
its own marker (a vignette) on a chest, Trovekeeper reads the exact position off
that marker and replaces the guide value. A chest no guide listed gets recorded
outright. `/tk export` prints whatever it currently holds, verified entries
marked as such, ready to paste back into `Core/Data.lua`.

**The delve's map id** is *not* shipped, because Blizzard does not publish it and
no guide lists one - the `#2512` that guides quote next to Gnarldor Isle's
chests is Coiled Isle, the outdoor zone the entrance sits in, not the delve
interior. Trovekeeper learns each one the first time you step inside, two ways:
by matching the map name while `IsInInstance()` is true, and - because names
like *Twilight Crypts* translate and *Gnarldor* does not - by which entrance you
walked in through, which works in every locale. `/tk setmap` binds one by hand
if both miss.

Until the map is known the list says so, and the world map pins have nowhere to
go. One trip into the delve settles it permanently.

The chest block only exists while you are **inside** a delve - outside one there
is no current delve to track, and the block takes no height at all.

Three entrances are missing on purpose: the two Voidstorm delves, because that
zone spans two map ids and no source says which the entrances are on, and
Twilight Crypts, for which no source gives coordinates at all. Their chests work
normally; only the entrance pin is absent.

## Bountiful delves

The top block lists the delves the game is running **bountiful** right now,
grouped by zone, and clicking one sets a waypoint on it.

Nothing about that set is shipped: it turns over on the daily reset, and the game
drops a delve from it once you have run the thing. Blizzard marks each one with
an area POI carrying the `delves-bountiful` atlas, and that atlas is the entire
detection - it is the half of a POI that is never translated. The POI also hands
over the delve's name in your own language, its exact position, and the game's
own wording for "Bountiful Delve", so the rows, the waypoints and their labels
need no name matching and no translation at all. That is why the block works for
delves this addon holds no other data for.

Every zone a delve sits in is scanned, and so is the continent each of those
hangs off, because the POIs turn up on either - Midnight's are on Quel'Thalas
and on no zone map. A delve found on a continent map is filed under its own zone
when its name can be matched, and under the continent when it cannot.

Where a bountiful delve's Delver's Call is already known, the row says where that
stands too, and the heading counts what is left.

If the block is missing, the game reported no bountiful POIs. `/tk pois` prints
what the client actually says: every POI that looks like a delve, on every map
scanned, with its atlas name and description. `/tk pois all` prints the lot.

## How it knows which ones you have already run

The bountiful heading counts what is **left**, not the total, and a delve you
have already run this week is greyed out. That answer comes from the delve's own
repeatable quest, `Delver's Call: <delve>`.

**The quest ids are not shipped**, for the same reason the interior map ids are
not: nothing publishes them, and a wrong id would report the wrong delve as done.
They are learned instead, in three widening steps:

1. **By title.** A `<prefix>: <delve>` quest whose part after the colon matches a
   delve is that delve's call. The prefix is remembered the first time this
   fires. On an English client this alone covers everything.
2. **By place.** Once the prefix is known, a quest carrying it that is accepted
   or handed in while you stand inside a known delve belongs to that delve. No
   name matching, so it holds up in every client language.
3. **By hand.** `/tk setquest <delve>` binds the quest you are tracking, and
   teaches the prefix outright. Ctrl-clicking a bountiful row does the same
   thing without the typing. One use is enough to unlock step 2 on a client
   whose language step 1 cannot read.

Until a delve's call is learned it counts as **outstanding** - unknown is not the
same as done, and saying otherwise would hide a delve still worth running. The
row simply shows no state.

The War Within's twelve delves are known to the addon by name for exactly this
purpose. Trovekeeper ships no chest coordinates for them.

## Requirements

- World of Warcraft: Midnight, interface 120100
- [TomTom](https://www.curseforge.com/wow/addons/tomtom) for waypoints. Without
  it everything else still works; only the waypoint is skipped.

Embedded: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 and
HereBeDragons-2.0.

## Building

```
make icon       rebuild Media/Icon.png and brand/*.png from the SVG sources
make lint       check the Lua, the XML, the TOC file list, the locale tables, the Python tools
make install    copy into the live WoW client
make debug      install, and turn the client's Lua error display on
make uninstall  remove it again, keeping SavedVariables
make dist       build dist/Trovekeeper-<version>.zip
make release    print the commands that tag and push v<version>
make public     build the public export of HEAD into dist/public
make clean      remove build output
make distclean  clean, plus the lint venv
```

`make help` lists every target and variable. `make lint` needs `python3` and
`ruff`; it installs `lupa` into a venv under `.build/` itself.

`make install` finds the client itself. Override with
`WOW_RETAIL_ADDON_FOLDER=/path/to/Interface/AddOns` or
`WOW_DIR=/path/to/World of Warcraft`.

On Windows use `Makefile.bat` with the same target names.

## A note on minimap pins

Minimap pins go through HereBeDragons, which needs a map to expose world
coordinates. Not every instance map does. Where that fails the pin is simply not
drawn - world map pins, the list and the waypoints are unaffected. `/tk diag`
says outright whether the current map supports them.

## Brand

`brand/` holds the icon: the SVG sources, the raster exports, and the Claude
Design canvas they came from. `make icon` regenerates every PNG, including the
`Media/Icon.png` the addon loads. See `brand/README.md`.

## Credits

- Waypoints: [TomTom](https://www.curseforge.com/wow/addons/tomtom) by Cladhaire
  and Ludovicus
- Map and minimap pins: HereBeDragons-2.0 by Nevcairiel
- Minimap button: LibDBIcon-1.0 and LibDataBroker-1.1
- Chest coordinates researched from public delve guides
  ([Method](https://www.method.gg/guides/gnarldor-isle-midnight-wow-delve-guide),
  [Sidestreet Sloots](https://www.sidestreetsloots.com/guides/delves-gnarldor-isle))
  and refined in-game

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is
not affiliated with Blizzard Entertainment.

## Licence

MIT — see [LICENSE](LICENSE). The embedded libraries keep their own licences.

Copyright 2026 lasse tech, Lars Gossard — <lars@lasse-tech.de>
