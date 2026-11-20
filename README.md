# Neoclassical City (`neoclassical_city`)

A standalone Luanti / Minetest mod adapted from the **Amenaza** city mapgen. Build a 19th-century European neoclassical city (Grand Central Plaza & Colonnade, Grand Spa Park, tree-lined boulevards, roundabouts, historic cobblestone alleys, sandstone facades, and optional data center landmark) manually anywhere in any standard Minetest / Luanti world via a chat command.

## Features

- **On-demand city builder** — Generate the city centered at your current position using `/build_city` (runs asynchronously in 64×64 VoxelManip tiles so the server stays responsive).
- **Steady & blinking lanterns** — Both non-blinking (`neoclassical_city:lantern_steady`, `neoclassical_city:lantern_off`) and blinking (`neoclassical_city:lantern_blinking`) street lanterns are available as buildable nodes and as a `/build_city` option.
- **Non-blinking windows by default** — Generated city buildings use non-blinking windows (`neoclassical_city:window_lit` and `neoclassical_city:window_dark`). A separate `neoclassical_city:window_blinking` node is provided if you want to build blinking windows manually.
- **Pure city mod** — No compass, no sounds, no NPCs, no sky/HUD overrides, and all architectural blocks are normal diggable/buildable nodes for standard Luanti / Minetest worlds.

## Chat Commands

Requires the `neoclassical_city` privilege (granted automatically in singleplayer and to admins).

- `/build_city [radius] [steady|blinking]` (alias: `/neoclassical_city`)
  - Builds the neoclassical city centered at your current position.
  - `radius`: optional integer from `16` to `500` (default: `120`, creating a 241×241 area).
    - `120` includes the Grand Central Plaza, Neoclassical Colonnade, surrounding boulevards/blocks, and the western edge of the Grand Spa Park.
    - `250` includes the entire Grand Spa Park and surrounding boulevards/roundabouts.
    - `450` also includes the Data Center landmark to the northwest.
  - `steady` / `blinking`: optional street lantern mode (default: `steady`).
- `/build_city_cancel`
  - Cancels an in-progress city build.

### Examples

```text
/build_city
/build_city 200
/build_city 160 blinking
/build_city blinking
```

## Installation

Copy or clone this directory into your Luanti/Minetest `mods/` folder as `neoclassical_city` and enable it for your world.

## License

- Source code: MIT License
- Textures: CC BY-SA 4.0 (adapted from Amenaza by `ronrob-lu`)
