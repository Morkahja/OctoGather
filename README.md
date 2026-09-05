# Octo Gather

Octo Gather is a self-learning Herbalism map overlay for OctoWoW and Vanilla
WoW 1.12. Every time you successfully gather an herb, the add-on remembers its
location. Saved locations appear as difficulty-colored outlines on the minimap
and as herb icons with colored outlines on the world map.

Locations are saved account-wide in `OctoGatherDB`, so every character can use
the same database and the locations remain available after logout or `/reload`.

![Saved herbs on the Tanaris world map](Screenshots/world-map-tanaris.png)

## How it works

- Successfully gather an herb to teach Octo Gather its name and position.
- Gathering with a normal right-click or the
  [Interact](https://github.com/lookino/Interact) hotkey is supported.
- Each location records its main map zone and the smaller minimap subzone name.
- Marker colors are recalculated from the current character's Herbalism skill,
  so an orange location can later become yellow, green, and finally gray.
- Custom herbs can be learned when their tooltip includes a
  `Requires Herbalism (N)` line.

## Map markers

### Minimap

The minimap displays an empty colored outline at every saved location currently
in range. Move the mouse over an outline to see the herb name beside the cursor.

![A Firebloom marker and tooltip on the minimap](Screenshots/minimap-tooltip.png)

### World map

The selected zone's world map displays the herb's actual Vanilla icon inside
each colored outline. Move the mouse over a marker to see the herb name. Use the
**Octo Gather** checkbox in the upper-left corner of the world map to show or
hide the overlay; the setting is saved account-wide.

Nearby markers for the same herb merge into a larger rectangular marker when
their outlines overlap. Markers for different herbs remain separate and may
overlap, preventing unrelated locations from merging into oversized frames.

![Merged same-herb markers on the world map](Screenshots/world-map-merged-markers.png)

## Difficulty colors

The outline compares each herb's required skill with your current Herbalism:

| Color | Meaning |
| --- | --- |
| Red | You cannot gather it yet |
| Orange | Current skill through 24 points above the requirement |
| Yellow | 25-49 points above the requirement |
| Green | 50-99 points above the requirement |
| Gray | 100 or more points above the requirement |
| Purple | The herb's requirement is not known |

Gray markers use 50% opacity on both maps so low-value locations remain visible
without overwhelming the display. All other colors use full opacity.

## Commands

- `/ogather` or `/ogather count` — show the saved-node count and current skill.
- `/ogather on` — show minimap markers.
- `/ogather off` — hide minimap markers while continuing to learn locations.

## Installation

1. Extract or copy the `OctoGather` folder into `World of
   Warcraft\Interface\AddOns`.
2. Restart WoW or run `/reload` if the add-on was already installed.
3. Enable **Load out of date AddOns** on the character screen if the client asks
   for it.

No other add-on is required. Interact integration is enabled automatically when
Interact is installed.

## Important limitations

Octo Gather markers represent saved possible spawn locations. Blizzard's yellow
tracking dot still indicates whether a tracked herb is currently spawned; the
Vanilla 1.12 API does not reveal the identity of an individual live tracking
dot.

World-map markers appear on a specifically selected zone map, not on the full
continent view. Octo Gather includes minimap dimensions for the OctoWoW/Turtle
WoW 1.18.1 outdoor and event maps: Hyjal, Scarlet Enclave, Lapidis Isle,
Gillijim's Isle, Tel'Abim, Alah'Thalas, Gilneas, Icepoint Rock, Blackstone
Island, Thalassian Highlands, Winter Veil Vale, Grim Reaches, Balor, Northwind,
and Moonwhisper Coast. Custom areas inside an existing Vanilla zone, such as
Tirisfal Uplands, automatically use their parent map's dimensions.

![Herbalism markers in the custom Grim Reaches zone](Screenshots/world-map-grim-reaches.png)

## Credits

- Minimap coordinate scaling and bundled herb artwork are based on the original
  [Gatherer](https://github.com/jsb/Gatherer) project for Vanilla WoW.
- Grim Reaches dimensions use Turtle WoW map data from
  [MetaHunt](https://github.com/DuvelCorp/MetaHunt).
