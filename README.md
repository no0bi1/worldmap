# WorldMap

A standalone World of Warcraft 1.12 addon that changes the Blizzard World Map presentation and interaction.

## Features

- Resizes the World Map to 1024x768 at 0.8 scale and centers it.
- Keeps the map behind other windows.
- Makes the map click-through by default; hold **Shift** or **Ctrl** to interact with map POIs and notes.
- Adds a draggable title bar.
- Fades the map while the player is moving, except while on a flight path.
- Quick left-click zooms in; quick right-click zooms out.
- Keeps Escape able to close the map.
- Suspends the layout in party and raid instances.
- Does not take over the map when Cartographer or MetaMap is loaded.
- Can be enabled or disabled with slash commands.

## Installation

Copy the `WorldMap` folder into `Interface/AddOns/`.

## Commands

- `/worldmap on`
- `/worldmap off`
- `/worldmap toggle`
- `/wmap` toggles the addon.

The addon is independent: it does not load, inspect, or require Questie, and has its own SavedVariables (`WorldMapAddonDB`).

## Configuration

The addon is enabled by default. Its enabled state is stored in `WorldMapAddonDB`.
