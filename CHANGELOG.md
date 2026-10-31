# Changelog

All notable changes to Trovekeeper are documented here.

## [1.0.1] - 2026-10-31

### Added
- Donate link in the addon list (`X-Donate`)

## [1.0.0] - 2026-10-31

Initial release.

### Added
- Sturdy Chest locations for all **12 Midnight delves**, each tied to its own
  *Discoveries* achievement - together the *Midnight: Leave No Treasure Unfound*
  meta and the *Treasure Seeker* title.
- World map pins on the delve map, drawn through a native map-canvas data
  provider so they also work on instance maps.
- Minimap pins while inside the delve, via HereBeDragons-2.0.
- Entrance pins on the zone maps. Three are absent pending in-game
  verification: both Voidstorm delves, whose zone spans two map ids, and
  Twilight Crypts, for which no source gives coordinates.
- A movable, semi-transparent list window in two blocks, each with its own
  heading: the bountiful delves, and the chests of the delve you are standing
  in, with their distance and the achievement progress. A block with nothing to
  say takes no height, so the chest block only appears inside a delve. The
  window widens while the bountiful block is on show, by what the longest delve
  name and status label measure in the client's own font.
- Click a chest - in the list, on the map or on the minimap - to set a TomTom
  waypoint. Clicking the list header waypoints every outstanding chest at once.
- Right-click a chest to mark it found or not found by hand.
- Automatic detection of each delve's map id the first time you step inside, so
  no unpublished map id has to be hardcoded - by map name, and otherwise by the
  entrance you came through, which holds up in every client language.
- Automatic correction of chest coordinates from the game's own vignettes, and
  recording of any chest the shipped data did not know about.
- Per-chest found markers learned from the achievement criteria, shared across
  the whole account.
- Minimap button, and options in the game's own settings panel - with author,
  version, copyright and credits shown in the panel itself.
- The window remembers its position and whether it was open, across sessions,
  and can be dragged by any part of itself.
- Optional ElvUI skinning of the list window, on by default.
- Its own icon - a gold chest on dark - for the addon list and the minimap
  button, with the vector sources and the design canvas kept in `brand/`.
- German and English localisation.
- `/tk` with `map`, `setmap`, `entrance`, `reset`, `export`, `diag` and
  `options`.
- A **Bountiful Delves** block at the top of the list window: the delves the game
  is running bountiful right now, grouped by zone, each one clickable for a
  waypoint. Read off the game's own area POIs - the `delves-bountiful` atlas is
  the test, and the delve name, its position, its zone and even the words
  "Bountiful Delve" all come from the client, so the block covers delves this
  addon holds no other data for and needs no translation of the term.
- The bountiful heading counts what is **left** rather than the total, and a delve already
  run this week is greyed out. That comes from its `Delver's Call` quest, whose
  id is learned in-game rather than shipped: by quest title, by which delve you
  are standing in once the localised prefix is known, and by hand with
  `/tk setquest` or a ctrl-click on the row.
- The War Within's twelve delves, known by name so the bountiful list can place
  them. They carry no chest coordinates, no achievement and no map pins.
- `/tk pois`, which prints the map POIs the bountiful scan sees together with
  their atlas names and descriptions, so a renamed atlas can be found rather
  than guessed at. `/tk pois all` prints every POI.
- `hideDoneBountiful` option: hide the bountiful delves already run.
