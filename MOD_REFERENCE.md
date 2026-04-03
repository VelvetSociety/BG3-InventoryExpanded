# Inventory Expanded - Mod Reference

This document is the current feature and implementation reference for the mod. It covers what the mod does now, how the ViewModels are shaped, and the engine quirks that matter when you touch this code.

---

## Features

### Inventory Panel

Toggled via MCM keybinding (`inventory_panel_key`, default `F10`).

- Unified grid of party inventory items
- Native BG3 tooltips for supported native slots
- Camp chest items are pulled from the UI camp chest path; ghost wrappers are only a fallback when no matching native slot exists
- Filter panel with Type, Rarity, Slot, and Equipped state
- Sort by Name, Value, Weight, and Rarity with a 3-state cycle: off -> Desc -> Asc
- Search with buffered typing, Enter to apply, Escape to cancel
- Context menu actions: Use, Equip, Drop, Send to Camp
- Resize controls for height and width in 96px steps
- Status bar shows `Total X` or `Total X / Y (filtered)`

### Armory Panel

Toggled via MCM keybinding (`armory_panel_key`, default `F11`).

- Left panel shows 12 equipment slots with equipped item icons and native tooltips
- Right panel shows items that match the selected slot
- Slot categories cover Weapons, Armor, Accessories, and All
- Filter panel with Rarity, Damage Dice, Damage Type, Armor Type, and Equipped state
- Weapon-only and armor-only filter sections hide when they do not apply to the active slot category
- Sort by Name, Value, Weight, and Rarity
- Search works the same way as the inventory panel
- Double-click equip timing is controlled by MCM `double_click_ms` and defaults to `600`
- Character change detection polls every 2 seconds while the panel is open, then refreshes shortly after a switch is detected
- Two-handed weapons show a faded offhand ghost when needed

### MCM Settings

| Key | Type | Purpose |
|---|---|---|
| `inventory_panel_key` | Keybinding | Toggle inventory panel |
| `armory_panel_key` | Keybinding | Toggle armory panel |
| `double_click_ms` | Slider | Double-click equip threshold in milliseconds |

### Dev Console Commands

| Command | Effect |
|---|---|
| `!invrw_reload` | Re-init and rebind both VMs |
| `!invrw_dump` | Print DataStore item, owner, type, and rarity counts |
| `!invrw_open inventory\|armory` | Force-toggle a panel |
| `!invrw_status` | Print binding state and live VM properties |

---

## ViewModel Types

### `INVRW_InventoryPanelVM`

```text
PanelVisible        Bool       Panel open/closed
RootVisibility      String     "Visible"/"Collapsed" workaround for Canvas binding
StatusText          String     Status bar text
NativeSlots         Collection Raw VMInventorySlot wrappers for the native tooltip ListBox

ToggleCommand       Command
RefreshCommand      Command    Sends the net request only; OnDataUpdated handles populate
ShowMenuCommand     Command    Opens the context menu at grid position
HideMenuCommand     Command    Closes the context menu
UseItemCommand      Command
EquipItemCommand    Command
DropItemCommand     Command
SendToCampCommand   Command

SelectedIndex       Int32      0-based selected slot in NativeSlots
SelectedItemName    String
MenuX, MenuY        Int32      Context menu position

SelectedChar        Object     SelectedCharacter VM for LSTooltipExtender.Owner
CurrentPlayer       Object     CurrentPlayer VM for ContextMenuFillBehavior.Player
ContextActionMenuFill  Object  Native fill command for ContextMenuFillBehavior.FillCommand
ContextActionPressed   Object  Native execute command for ContextMenuItem.Command

SearchQuery         String
HasSearchQuery      Bool
SearchCommand       Command
SearchFocusCommand  Command
ClearSearchCommand  Command

PanelHeight         Int32      Default 1128
PanelWidth          Int32      Default 1492
ResizeGrowCommand   Command    +96px height
ResizeShrinkCommand Command    -96px height
WidenCommand        Command    +96px width
NarrowCommand       Command    -96px width

FilterPanelVisible       Bool
ActiveFilterCount        String    "" when zero, "N" when N active filters
ToggleFilterPanelCommand Command
ClearAllFiltersCommand   Command

FilterType_Weapon, Armor, Scroll, Misc
ToggleType_*

FilterRarity_Common, Uncommon, Rare, VeryRare, Legendary
ToggleRarity_*

FilterSlot_Helmet, Chest, Cloak, Gloves, Boots, Amulet, Ring, MainHand, OffHand, Ranged
ToggleSlot_*

FilterEquipMode_Both, Equipped, Unequipped
SetEquipMode_Both, Equipped, Unequipped

SortState_Name, Value, Weight, Rarity
SortField       String
SortAscending   Bool
SortByNameCommand, SortByValueCommand, SortByWeightCommand, SortByRarityCommand
```

### `INVRW_SlotWrapper`

Used by both panels for the native tooltip ListBox. Each entry wraps one `VMInventorySlot`.

```text
NativeSlot      Object    VMInventorySlot passed to the item template
NativeObject    Object    slot.Object (VMItem) passed to LSEntityObject.DataContext
NativeHandle    Object    VMItem.EntityHandle passed to LSEntityObject.EntityRef
Rarity          String    Used for rarity border styling
IsEquipped      Bool      Equipped state from DataStore
StackSize       Int32
ShowStack       Bool      True when StackSize > 1
StackVisibility String    "Visible"/"Collapsed"
SlotIcon        String    pack:// URI for empty slot background
HasItem         Bool
ItemIcon        String    pack:// URI for item icon
IsGhost         Bool      True when no matching native VMInventorySlot exists
GhostName       String    Display name for ghost items
GhostDesc       String    Currently unused
```

### `INVRW_ArmoryPanelVM`

```text
PanelVisible    Bool
RootVisibility  String
StatusText      String
SelectedChar    Object     For LSTooltipExtender.Owner
CharacterName   String     Resolved from the most common OwnerName in native matches

EquippedSlots   Collection INVRW_SlotWrapper for the left panel
FilteredItems   Collection INVRW_SlotWrapper for the right panel
ActiveSlotLabel String     Current slot label

EquipSelectedCommand      Command
HoverItemCommand          Command    Updates hover tracking for double-click detection
EquippedSlotClickCommand  Command
ToggleCommand             Command
RefreshCommand            Command
EquippedSlotIndex         Int32

SelectSlot_Helmet, Chest, Cloak, Gloves, Boots, Amulet, MainHand, OffHand, Ranged, RangedOff, Ring, Ring2, All
SlotActive_*               String "True"/"False"

FilterPanelVisible         Bool
ActiveFilterCount          String
ToggleFilterPanelCommand   Command
ClearAllFiltersCommand     Command

FilterSection_DamageDice   String "True"/"False"
FilterSection_DamageType   String "True"/"False"
FilterSection_ArmorType    String "True"/"False"

FilterEquipMode_Both, Equipped, Unequipped   String "True"/"False"
SetEquipMode_*

FilterRarity_Common, Uncommon, Rare, VeryRare, Legendary
ToggleRarity_*

SortState_Name, Value, Weight, Rarity
SortByNameCommand, SortByValueCommand, SortByWeightCommand, SortByRarityCommand

FilterDice_1d4, 1d6, 1d8, 1d10, 1d12, 2d6
ToggleDice_*

FilterDmgType_Slashing, Piercing, Bludgeoning, Fire, Cold, Lightning, Thunder, Poison, Acid, Necrotic, Radiant, Force, Psychic
ToggleDmgType_*

FilterArmorType_Clothing, Light, Medium, Heavy
ToggleArmorType_*

SearchQuery, HasSearchQuery, SearchFocusCommand, SearchCommand, ClearSearchCommand

SlotPickerVisible, SlotPickerTitle, SlotPickerOpt1, SlotPickerOpt2
SlotPickerOpt1Command, SlotPickerOpt2Command, SlotPickerCancelCommand
```

---

## Key Implementation Decisions

**`NativeSlots` is the only real display path.** The inventory panel is driven by raw VM inventory slots so native BG3 tooltips keep working. Older display paths are gone.

**Camp chest items usually have native tooltips now.** Camp chest VMInventorySlots are collected from `cp.UIData.CampChests -> Inventories[k].Slots` and treated like party slots. Ghost wrappers are only a fallback when DataStore has a camp item that the native UI path does not expose.

**Filter booleans are strings, not bools.** XAML `Trigger` checks on `Tag="True"` only behave reliably when the VM property is a string value of `"True"` or `"False"`.

**`Data.PartyCharacters` is the working party list path.** The flat list on `dc.Data.PartyCharacters` is the path this mod uses for party character access.

**Deduplication uses `Inventories` pointer strings.** `SelectedCharacter` is added first. Other characters are skipped if `tostring(char.Inventories)` matches `tostring(cp.SelectedCharacter.Inventories)`.

**`EquippedInSlot` matters more than `Slot` for dual-wield.** Both dual-wield weapons can report `Slot = "MeleeMainHand"`. `EquippedInSlot` is derived from the physical equipment container index and is the reliable slot identity for display logic.

**Equipped detection mixes Osiris and container fallback.** `Osi.GetEquippedItem` works for some slots but misses weapon cases. The equipment container path fills the gaps.

**Use `ItemIcon` strings, not `NativeObject.Icon`.** The native image brush proxy goes stale between calls. Icon rendering should use the constructed pack URI string from DataStore icon names.

**Never double-populate.** `RefreshCommand` should only request data. `OnDataUpdated` is the populate step. Triggering both population paths in one flow can freeze or crash the UI.

**Character name is resolved indirectly.** The armory panel does not have a clean UUID bridge from the Noesis selected character VM, so it resolves the active character name from the most common matching `OwnerName`.

---

## Known Constraints

- Ghost wrappers are still possible, but only as a fallback for camp chest items with no matching native slot
- Armory character change detection polls every 2 seconds and then refreshes after a short delay
- Equip actions use a short `_equipBusy` lockout to avoid rapid-click crashes
- No drag-and-drop
- Panel position and size are not persisted across restarts
- `InventoryMember.EquipmentSlot` is not an equipped flag; it is a container slot index and is always `>= 0`
