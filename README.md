# Inventory Expanded

`Inventory Expanded` is a Baldur's Gate 3 UI mod built with Noesis XAML and BG3 Script Extender Lua.

This is currently a beta release. The core panels are usable, but the mod is still being iterated on and some rough edges are expected.

The mod adds two custom panels:

- a shared inventory view for party gear and camp chest items
- an armory view for browsing equipment by slot and quickly swapping items around

This repo is also a decent reference if you are building your own BG3 UI mod and want a working example of how to split Lua, networking, ViewModels, and XAML without everything turning into a mess.

## What It Does

- Inventory panel with party-wide item browsing
- Native BG3 tooltips for supported items
- Search, filters, and sort options
- Armory panel with slot-based equipment browsing
- MCM keybinds for opening each panel
- Configurable double-click timing for quick equip in the armory

More detailed feature notes and VM docs live in [`MOD_REFERENCE.md`](./MOD_REFERENCE.md).

## Repo Layout

- `Mod/` contains the actual mod files
- `Mod/GUI/` contains XAML pages, resources, and state machines
- `Mod/ScriptExtender/Lua/Client/` contains client-side UI logic, filtering, and bindings
- `Mod/ScriptExtender/Lua/Server/` contains inventory collection, item actions, and server net handlers
- `MOD_REFERENCE.md` contains feature notes, ViewModel types, and implementation details

## Start Here

If you're using this repo as a reference, read these first:

1. [`README.md`](./README.md)
2. [`MOD_REFERENCE.md`](./MOD_REFERENCE.md)

After that, the main entry points are the bootstrap files:

- `Mod/ScriptExtender/Lua/BootstrapClient.lua`
- `Mod/ScriptExtender/Lua/BootstrapServer.lua`

## How It's Split Up

- Server Lua gathers and normalizes data from the game
- Net messages move snapshots and actions between server and client
- Client Lua manages local state, filtering, sorting, and ViewModel bindings
- XAML handles layout and presentation

That separation is the part that's most worth reusing. The feature itself is specific to this mod, but the structure is portable.

## Working On It

Lua workflow: make a change, reload in game, then check logs.

XAML workflow: make a change, restart as needed, then check logs again.

There isn't any fancy automation in here. It's a pretty direct modding workflow.
