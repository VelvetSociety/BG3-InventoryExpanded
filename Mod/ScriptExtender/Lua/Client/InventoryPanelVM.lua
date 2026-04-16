--- ViewModel bridge between DataStore and the XAML InventoryPanel.
-- @module InventoryPanelVM
--
-- Architecture:
--   Widget found at ContentRoot.Children[18] ("InventoryPanel") after ~10s.
--   Fresh VM created and set as DataContext immediately (prevents Noesis GC).
--   Lua proxy to VM expires, but Noesis keeps it alive via widget.DataContext.
--   We re-find the widget and re-acquire the VM every time we need it.

local InventoryPanelVM = {}

local isRegistered = false
local isBound = false

--- Register VM types with SE.
local function RegisterTypes()
    if isRegistered then return end

    -- Shared wrapper type used by both InventoryPanel (item list) and ArmoryPanel (item list + equipped slots sidebar).
    -- InventoryPanel item list: only NativeObject/NativeHandle/IsEquipped/IsGhost/ItemIcon used — Template.Item handles visuals.
    -- ArmoryPanel equipped slots sidebar: also uses Rarity, StackSize, ShowStack, SlotIcon, HasItem for EquippedSlotStyle.
    Ext.UI.RegisterType("INVRW_SlotWrapper", {
        NativeSlot      = { Type = "Object", Notify = true },
        NativeObject    = { Type = "Object", Notify = true },
        NativeHandle    = { Type = "Object", Notify = true },
        Rarity          = { Type = "String", Notify = true },
        StackSize       = { Type = "Int32",  Notify = true },
        ShowStack       = { Type = "Bool",   Notify = true },
        SlotIcon        = { Type = "String", Notify = true },
        HasItem         = { Type = "Bool",   Notify = true },
        ItemIcon        = { Type = "String", Notify = true },
        IsGhost         = { Type = "Bool",   Notify = true },
        IsEquipped      = { Type = "Bool",   Notify = true },
    })

    Ext.UI.RegisterType("INVRW_InventoryPanelVM", {
        PanelVisible   = { Type = "Bool", Notify = true },
        RootVisibility = { Type = "String", Notify = true },
        StatusText     = { Type = "String", Notify = true },
        NativeSlots    = { Type = "Collection" },  -- Raw VMInventorySlot objects for native tooltip ListBox
        ToggleCommand      = { Type = "Command" },
        RefreshCommand     = { Type = "Command" },
        ShowMenuCommand    = { Type = "Command" },
        HideMenuCommand    = { Type = "Command" },
        UseItemCommand     = { Type = "Command" },
        EquipItemCommand   = { Type = "Command" },
        DropItemCommand    = { Type = "Command" },
        SendToCampCommand  = { Type = "Command" },
        SelectedItemName   = { Type = "String", Notify = true },
        SelectedIndex      = { Type = "Int32", Notify = true },
        MenuX              = { Type = "Int32", Notify = true },
        MenuY              = { Type = "Int32", Notify = true },
        SelectedChar   = { Type = "Object", Notify = true },  -- SelectedCharacter VM for TooltipExtender.Owner on parent container
        CurrentPlayer          = { Type = "Object", Notify = true },  -- Native CurrentPlayer VM for ContextMenuFillBehavior.Player
        ContextActionMenuFill  = { Type = "Object", Notify = true },  -- Native fill command for ContextMenuFillBehavior.FillCommand
        ContextActionPressed   = { Type = "Object", Notify = true },  -- Native execute command for ContextMenuItem.Command dispatch
        SearchQuery        = { Type = "String", Notify = true },
        HasSearchQuery     = { Type = "Bool", Notify = true },
        SearchCommand      = { Type = "Command" },
        SearchFocusCommand = { Type = "Command" },
        ClearSearchCommand = { Type = "Command" },
        PanelHeight         = { Type = "Int32", Notify = true },
        PanelWidth          = { Type = "Int32", Notify = true },
        ResizeGrowCommand   = { Type = "Command" },
        ResizeShrinkCommand = { Type = "Command" },
        WidenCommand        = { Type = "Command" },
        NarrowCommand       = { Type = "Command" },

        -- Filter panel
        FilterPanelVisible       = { Type = "Bool", Notify = true },
        ActiveFilterCount        = { Type = "String", Notify = true },
        ToggleFilterPanelCommand = { Type = "Command" },
        ClearAllFiltersCommand   = { Type = "Command" },

        -- Type filters (String "True"/"False" so XAML Tag triggers match)
        FilterType_Weapon     = { Type = "String", Notify = true },
        FilterType_Armor      = { Type = "String", Notify = true },
        FilterType_Scroll     = { Type = "String", Notify = true },
        FilterType_Misc       = { Type = "String", Notify = true },
        ToggleType_Weapon     = { Type = "Command" },
        ToggleType_Armor      = { Type = "Command" },
        ToggleType_Scroll     = { Type = "Command" },
        ToggleType_Misc       = { Type = "Command" },

        -- Rarity filters (String "True"/"False" so XAML Tag triggers match)
        FilterRarity_Common    = { Type = "String", Notify = true },
        FilterRarity_Uncommon  = { Type = "String", Notify = true },
        FilterRarity_Rare      = { Type = "String", Notify = true },
        FilterRarity_VeryRare  = { Type = "String", Notify = true },
        FilterRarity_Legendary = { Type = "String", Notify = true },
        ToggleRarity_Common    = { Type = "Command" },
        ToggleRarity_Uncommon  = { Type = "Command" },
        ToggleRarity_Rare      = { Type = "Command" },
        ToggleRarity_VeryRare  = { Type = "Command" },
        ToggleRarity_Legendary = { Type = "Command" },

        -- Slot filters (String "True"/"False" so XAML Tag triggers match)
        FilterSlot_Helmet   = { Type = "String", Notify = true },
        FilterSlot_Chest    = { Type = "String", Notify = true },
        FilterSlot_Cloak    = { Type = "String", Notify = true },
        FilterSlot_Gloves   = { Type = "String", Notify = true },
        FilterSlot_Boots    = { Type = "String", Notify = true },
        FilterSlot_Amulet   = { Type = "String", Notify = true },
        FilterSlot_Ring     = { Type = "String", Notify = true },
        FilterSlot_MainHand = { Type = "String", Notify = true },
        FilterSlot_OffHand  = { Type = "String", Notify = true },
        FilterSlot_Ranged   = { Type = "String", Notify = true },
        ToggleSlot_Helmet   = { Type = "Command" },
        ToggleSlot_Chest    = { Type = "Command" },
        ToggleSlot_Cloak    = { Type = "Command" },
        ToggleSlot_Gloves   = { Type = "Command" },
        ToggleSlot_Boots    = { Type = "Command" },
        ToggleSlot_Amulet   = { Type = "Command" },
        ToggleSlot_Ring     = { Type = "Command" },
        ToggleSlot_MainHand = { Type = "Command" },
        ToggleSlot_OffHand  = { Type = "Command" },
        ToggleSlot_Ranged   = { Type = "Command" },

        -- Equipped mode filter (radio: Both / Equipped / Unequipped)
        FilterEquipMode_Both       = { Type = "String", Notify = true },
        FilterEquipMode_Equipped   = { Type = "String", Notify = true },
        FilterEquipMode_Unequipped = { Type = "String", Notify = true },
        SetEquipMode_Both          = { Type = "Command" },
        SetEquipMode_Equipped      = { Type = "Command" },
        SetEquipMode_Unequipped    = { Type = "Command" },

        -- Sort
        SortField              = { Type = "String", Notify = true },
        SortAscending          = { Type = "Bool", Notify = true },
        SortByNameCommand      = { Type = "Command" },
        SortByValueCommand     = { Type = "Command" },
        SortByWeightCommand    = { Type = "Command" },
        SortByRarityCommand    = { Type = "Command" },
        -- Per-field sort state: "" (off), "Desc" (high→low), "Asc" (low→high)
        SortState_Name         = { Type = "String", Notify = true },
        SortState_Value        = { Type = "String", Notify = true },
        SortState_Weight       = { Type = "String", Notify = true },
        SortState_Rarity       = { Type = "String", Notify = true },
    })

    isRegistered = true
    _P("[InventoryExpanded] InventoryPanelVM types registered")
end

--- Find our widget in ContentRoot by scanning Children for name="InventoryPanel".
local function FindWidget()
    local root = Ext.UI.GetRoot()
    if not root then return nil end

    local contentRoot = nil
    pcall(function() contentRoot = root:Find("ContentRoot") end)
    if not contentRoot then return nil end

    local children = nil
    pcall(function() children = contentRoot.Children end)
    if not children then return nil end

    local count = 0
    pcall(function() count = children.Count or 0 end)
    if count == 0 then pcall(function() count = #children end) end

    for i = 1, count do
        local child = nil
        pcall(function() child = children[i] end)
        if child then
            local name = ""
            pcall(function() name = child.Name or "" end)
            if name == "InventoryPanel" then
                return child
            end
        end
    end

    return nil
end

--- Get contextual VM references from the game's Overlay DataContext.
--- Returns selectedChar, currentPlayer, contextActionMenuFill, contextActionPressed.
local function GetContextualVMRefs()
    local selectedChar = nil
    local currentPlayer = nil
    local contextActionMenuFill = nil
    local contextActionPressed = nil
    pcall(function()
        local root = Ext.UI.GetRoot()
        if not root then return end
        local contentRoot = root:Find("ContentRoot")
        if not contentRoot then return end

        local overlay = nil
        local children = contentRoot.Children
        for i = 0, 30 do
            pcall(function()
                local c = children[i]
                if c and c.Name == "Overlay" then overlay = c end
            end)
        end
        if not overlay or not overlay.DataContext then return end

        local dc = overlay.DataContext
        local cp = dc.CurrentPlayer
        if not cp then return end

        pcall(function() currentPlayer = cp end)
        pcall(function() selectedChar = cp.SelectedCharacter end)
        pcall(function() contextActionMenuFill = dc.ContextActionMenuFill end)
        pcall(function() contextActionPressed = dc.ContextActionPressed end)
    end)
    return selectedChar, currentPlayer, contextActionMenuFill, contextActionPressed
end

--- Get the VM by re-finding the widget and reading its DataContext.
--- Both widget and DataContext proxies are fresh each call (no caching).
local function GetVM()
    if not isBound then return nil end
    local widget = FindWidget()
    if not widget then return nil end
    local vm = nil
    local ok = pcall(function() vm = widget.DataContext end)
    if ok and vm then
        local ok2 = pcall(function() local _ = vm.StatusText end)
        if ok2 then return vm end
    end
    return nil
end

local function ForceClosed(widget, vm)
    if not widget then widget = FindWidget() end
    if not vm then vm = GetVM() end
    if vm then
        vm.PanelVisible = false
        vm.RootVisibility = "Collapsed"
    end
    if widget then
        pcall(function() widget.Visibility = "Collapsed" end)
    end
end

--- Clear a VM collection.
local function ClearCollection(collection)
    for i = #collection, 1, -1 do
        collection[i] = nil
    end
end

--- Count keys in a table.
function InventoryPanelVM._tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ══════════════════════════════════════════════════════════════
-- Filter state (module-level, survives across VM re-finds)
-- ══════════════════════════════════════════════════════════════
local filterState = {
    types    = {},  -- { Weapon=true, ... }
    rarities = {},  -- { Rare=true, ... }
    slots    = {},  -- { Helmet=true, ... }
    owners   = {},  -- { ownerUUID=true, ... }
    equipMode = "Both",  -- "Both", "Equipped", or "Unequipped"
    sortBy   = nil, -- nil = no sort (natural order), "Name"/"Value"/"Weight"/"Rarity"
    sortAscending = true,
}

--- Count active filter toggles for badge display.
local function CountActiveFilters()
    local n = 0
    for _ in pairs(filterState.types) do n = n + 1 end
    for _ in pairs(filterState.rarities) do n = n + 1 end
    for _ in pairs(filterState.slots) do n = n + 1 end
    for _ in pairs(filterState.owners) do n = n + 1 end
    if filterState.equipMode and filterState.equipMode ~= "Both" then n = n + 1 end
    return n
end

--- Update ActiveFilterCount on the VM.
local function UpdateFilterCount()
    pcall(function()
        local vm = GetVM()
        if not vm then return end
        local c = CountActiveFilters()
        vm.ActiveFilterCount = c > 0 and tostring(c) or ""
    end)
end

--- Factory: create a toggle handler for a filter category.
-- @param propName  VM Bool property name (e.g. "FilterType_Weapon")
-- @param stateSet  filterState sub-table (e.g. filterState.types)
-- @param key       key in the set (e.g. "Weapon")
local function MakeToggleHandler(propName, stateSet, key)
    return function()
        if stateSet[key] then
            stateSet[key] = nil
        else
            stateSet[key] = true
        end
        pcall(function()
            local vm = GetVM()
            if vm then vm[propName] = stateSet[key] and "True" or "False" end
        end)
        UpdateFilterCount()
        InventoryPanelVM.ApplyFiltersAndRefresh()
    end
end

--- Helper: update all SortState_* VM properties based on filterState.
local function UpdateSortIndicators()
    pcall(function()
        local vm = GetVM()
        if not vm then return end
        local fields = {"Name", "Value", "Weight", "Rarity"}
        for _, f in ipairs(fields) do
            local state = ""
            if filterState.sortBy == f then
                state = filterState.sortAscending and "Asc" or "Desc"
            end
            pcall(function() vm["SortState_" .. f] = state end)
        end
        vm.SortField = filterState.sortBy or ""
        vm.SortAscending = filterState.sortAscending
    end)
end

--- Factory: create a 3-state sort toggle handler.
-- Cycle: Off → Desc (high→low / Z→A) → Asc (low→high / A→Z) → Off
local function MakeSortHandler(field)
    return function()
        if filterState.sortBy == field then
            -- Already on this field — cycle
            if not filterState.sortAscending then
                -- Was Desc → go Asc
                filterState.sortAscending = true
            else
                -- Was Asc → turn off
                filterState.sortBy = nil
                filterState.sortAscending = true
            end
        else
            -- New field — start with Desc (high→low, Z→A)
            filterState.sortBy = field
            filterState.sortAscending = false
        end
        UpdateSortIndicators()
        InventoryPanelVM.ApplyFiltersAndRefresh()
    end
end

--- Apply filters and refresh the display.
-- Cannot cache Noesis proxies (they expire between calls), so this does a full rescan.
function InventoryPanelVM.ApplyFiltersAndRefresh()
    InventoryPanelVM.PopulateFromDataStore()
end

-- Throttled via coalescing: calls that arrive during an in-flight populate are
-- deferred into a single follow-up execution after the cooldown, not silently
-- dropped. The native UI tree traversal below is unsafe to run concurrently
-- with panel show/hide transitions, so we serialize via _populateBusy.
local _populateBusy    = false
local _populatePending = false
local _doPopulateFromDataStoreNow  -- forward-declared for timer callback

function InventoryPanelVM.PopulateFromDataStore()
    if _populateBusy then
        _populatePending = true
        return
    end
    _populateBusy    = true
    _populatePending = false
    _doPopulateFromDataStoreNow()
    pcall(function()
        Ext.Timer.WaitFor(250, function()
            _populateBusy = false
            if _populatePending then
                InventoryPanelVM.PopulateFromDataStore()
            end
        end)
    end)
end

--- Populate Items collection from DataStore. Internal - call PopulateFromDataStore().
_doPopulateFromDataStoreNow = function()
    local vm = GetVM()
    if not vm then
        _P("[InventoryExpanded] PopulateFromDataStore: cannot get VM")
        return
    end

    local DataStore = Mods.InventoryExpanded.DataStore
    if not DataStore then return end

    local allItems = DataStore.GetAllItems()
    local FilterEngine = Mods.InventoryExpanded.FilterEngine

    -- Set contextual VM references needed for native tooltips and context menu
    local selectedChar, currentPlayer, contextActionMenuFill, contextActionPressed = GetContextualVMRefs()
    if selectedChar then
        pcall(function() vm.SelectedChar = selectedChar end)
    end
    if currentPlayer then
        pcall(function() vm.CurrentPlayer = currentPlayer end)
    end
    if contextActionMenuFill then
        pcall(function() vm.ContextActionMenuFill = contextActionMenuFill end)
    end
    if contextActionPressed then
        pcall(function() vm.ContextActionPressed = contextActionPressed end)
    end

    -- Populate NativeSlots with raw VMInventorySlot objects from the game's inventory.
    -- Uses the native Container.xaml hierarchy (ListBox → ListBoxItem ControlTemplate →
    -- LSEntityObject → LSTooltip) so C++ engine fully populates VMTooltipItem.
    -- Collects from ALL party members including equipped items.
    -- Close context menu if open
    pcall(function()
        local w = FindWidget()
        if w then
            local mp = w:Find("ContextMenuPanel")
            if mp then mp.Visibility = "Collapsed" end
            local ml = w:Find("MenuLayer")
            if ml then ml.IsHitTestVisible = false end
        end
    end)

    -- Collect all native slots into temp arrays first, then filter by search query
    local _tempSlots = {}  -- { slot, uuid, name }
    local totalSlotCount = 0
    pcall(function()
        local root = Ext.UI.GetRoot()
        if not root then return end
        local contentRoot = root:Find("ContentRoot")
        if not contentRoot then return end

        local overlay = nil
        local children = contentRoot.Children
        for i = 0, 30 do
            pcall(function()
                local c = children[i]
                if c and c.Name == "Overlay" then overlay = c end
            end)
        end
        if not overlay or not overlay.DataContext then return end

        local cp = overlay.DataContext.CurrentPlayer
        if not cp then return end

        -- Helper: collect slots from an inventory into _tempSlots
        local function collectSlotsFrom(inv, label)
            if not inv then return end
            pcall(function()
                local slots = inv.Slots
                if not slots then return end
                local slotCount = #slots
                for j = 1, slotCount do
                    pcall(function()
                        local slot = slots[j]
                        if slot and slot.Object then
                            totalSlotCount = totalSlotCount + 1
                            -- Cache UUID + Name while proxy is fresh
                            local uuid, name = nil, "Unknown"
                            pcall(function() uuid = slot.Object.EntityUUID end)
                            -- Helper: detect localization handles (e.g. "ha248915ag9249g4fafg...")
                            local function isLocaHandle(s)
                                return s and s:match("^h[0-9a-f]+g[0-9a-f]+g")
                            end
                            -- Try to resolve a readable name
                            pcall(function()
                                local obj = slot.Object
                                -- Try DisplayName first, then Name
                                for _, prop in ipairs({"DisplayName", "Name", "ItemName"}) do
                                    pcall(function()
                                        local val = obj[prop]
                                        if val == nil then return end
                                        -- Try .Text sub-property (TransString)
                                        pcall(function()
                                            if val.Text and val.Text ~= "" and not isLocaHandle(val.Text) then
                                                name = val.Text
                                            end
                                        end)
                                        if name ~= "Unknown" then return end
                                        -- Try tostring
                                        local s = tostring(val)
                                        if s and s ~= "" and not s:match("^Noesis::") and not isLocaHandle(s) then
                                            name = s
                                        end
                                    end)
                                    if name ~= "Unknown" then return end
                                end
                            end)
                            -- Strip any LSTag markup from name
                            if name and name ~= "Unknown" then
                                name = name:gsub("<LSTag[^>]*>([^<]*)</LSTag>", "%1")
                                name = name:gsub("<[^>]+>", "")
                            end
                            -- Cross-reference with DataStore for a fallback name
                            if name == "Unknown" and uuid then
                                pcall(function()
                                    local DataStore = Mods.InventoryExpanded.DataStore
                                    if DataStore then
                                        local allItems = DataStore.GetAllItems()
                                        for _, item in ipairs(allItems) do
                                            if item.UUID == uuid then
                                                name = item.Name or "Unknown"
                                                return
                                            end
                                        end
                                    end
                                end)
                            end
                            local vmObj, entityH, nativeCount = nil, nil, nil
                            pcall(function()
                                -- Object must be read first and in the same pcall —
                                -- the slot proxy expires between separate pcall invocations.
                                local obj = slot.Object
                                if obj then
                                    vmObj = obj
                                    entityH = obj.EntityHandle
                                end
                                -- Probe count on the slot itself, then on slot.Object.
                                -- Use inner pcalls since Noesis throws on unknown properties.
                                local countCandidates = {"Count","Amount","StackAmount","StackCount","Quantity","ItemCount","ItemAmount","NumberOf"}
                                for _, pname in ipairs(countCandidates) do
                                    local ok2, val = pcall(function() return slot[pname] end)
                                    if ok2 and val ~= nil then
                                        local n = tonumber(val)
                                        if n and n > 1 then nativeCount = n break end
                                    end
                                end
                                -- Also probe on slot.Object if still no count found
                                if not nativeCount and obj then
                                    for _, pname in ipairs(countCandidates) do
                                        local ok2, val = pcall(function() return obj[pname] end)
                                        if ok2 and val ~= nil then
                                            local n = tonumber(val)
                                            if n and n > 1 then nativeCount = n break end
                                        end
                                    end
                                end
                            end)
                            _tempSlots[totalSlotCount] = {
                                slot = slot, uuid = uuid, name = name,
                                vmObject = vmObj, entityHandle = entityH,
                                nativeCount = nativeCount,
                            }
                        end
                    end)
                end
            end)
        end

        -- Helper: collect ALL inventories from a character VM (uses Inventories only,
        -- NOT Inventory, since Inventory == Inventories[1] and would cause duplicates)
        local function addAllFromChar(char, charLabel)
            local usedInventories = false
            pcall(function()
                local invs = char.Inventories
                if invs then
                    local invCount = #invs
                    if invCount > 0 then
                        usedInventories = true
                        for k = 1, invCount do
                            pcall(function()
                                collectSlotsFrom(invs[k], charLabel .. ".Inventories[" .. k .. "]")
                            end)
                        end
                    end
                end
            end)
            -- Fallback ONLY if Inventories wasn't available
            if not usedInventories then
                collectSlotsFrom(char.Inventory, charLabel .. ".Inventory")
            end
        end

        -- ALWAYS start with SelectedCharacter (guaranteed to work)
        if cp.SelectedCharacter then
            addAllFromChar(cp.SelectedCharacter, "SelectedChar")
        end

        -- Try Data.PartyCharacters (flat list of all party character VMs)
        -- Native XAML: PartyPanel.xaml binds to Data.PartyCharacters
        local dc = overlay.DataContext
        local partyChars = nil
        pcall(function() partyChars = dc.Data.PartyCharacters end)
        if partyChars then
            local pcCount = 0
            pcall(function() pcCount = #partyChars end)
            -- Track SelectedChar's Inventories pointer to skip duplicates
            local selectedInvPtr = nil
            pcall(function() selectedInvPtr = tostring(cp.SelectedCharacter.Inventories) end)
            for c = 1, pcCount do
                pcall(function()
                    local char = partyChars[c]
                    if not char then return end
                    -- Skip SelectedCharacter (already added) by comparing Inventories pointer
                    local thisInvPtr = nil
                    pcall(function() thisInvPtr = tostring(char.Inventories) end)
                    if thisInvPtr and thisInvPtr == selectedInvPtr then
                        return
                    end
                    local charName = "PartyChar" .. c
                    pcall(function() charName = tostring(char.Name or char.DisplayName or charName) end)
                    addAllFromChar(char, charName)
                end)
            end
        else
            -- Fallback: Data.Players[i].PartyGroups[j].Characters
            pcall(function()
                local players = dc.Data.Players
                if not players then
                    return
                end
                local playerCount = #players
                local selectedInvPtr = nil
                pcall(function() selectedInvPtr = tostring(cp.SelectedCharacter.Inventories) end)
                for p = 1, playerCount do
                    pcall(function()
                        local player = players[p]
                        if not player then return end
                        local groups = player.PartyGroups
                        if not groups then return end
                        for g = 1, #groups do
                            pcall(function()
                                local groupChars = groups[g].Characters
                                if not groupChars then return end
                                for c = 1, #groupChars do
                                    pcall(function()
                                        local char = groupChars[c]
                                        if not char then return end
                                        local thisInvPtr = nil
                                        pcall(function() thisInvPtr = tostring(char.Inventories) end)
                                        if thisInvPtr and thisInvPtr == selectedInvPtr then return end
                                        local charName = "P" .. p .. "G" .. g .. "C" .. c
                                        pcall(function() charName = tostring(char.Name or char.DisplayName or charName) end)
                                        addAllFromChar(char, charName)
                                    end)
                                end
                            end)
                        end
                    end)
                end
            end)
        end

        -- Collect from camp chests via CurrentPlayer.UIData.CampChests.
        -- CompanionsPanel (ContentRoot[23]) is always loaded, so UIData.CampChests is accessible
        -- even without the camp inventory panel being open.
        -- Each chest exposes Inventories[0].Slots (XAML 0-indexed → Lua index 1) as VMInventorySlot objects,
        -- giving full native tooltip support without any ghost wrapper fallback.
        pcall(function()
            local campChests = nil
            pcall(function() campChests = cp.UIData.CampChests end)
            if not campChests then
                return
            end
            local chestCount = 0
            pcall(function() chestCount = #campChests end)
            for i = 1, chestCount do
                pcall(function()
                    local chest = campChests[i]
                    if not chest then return end
                    local invs = chest.Inventories
                    if not invs then return end
                    local invCount = 0
                    pcall(function() invCount = #invs end)
                    for k = 1, invCount do
                        pcall(function()
                            collectSlotsFrom(invs[k], "CampChest[" .. i .. "].Inv[" .. k .. "]")
                        end)
                    end
                end)
            end
        end)

        _P("[InventoryExpanded] NativeSlots collected: " .. totalSlotCount .. " items")
    end)

    -- Build UUID → DataStore item map for metadata (rarity, type, name for filtering)
    local dsItemByUUID = {}
    for _, dsItem in ipairs(allItems) do
        if dsItem.UUID then
            dsItemByUUID[dsItem.UUID] = dsItem
        end
    end


    -- Build passing UUID set via FilterEngine.FilterMulti + sort
    local FilterEngine = Mods.InventoryExpanded.FilterEngine
    local searchQuery = (InventoryPanelVM._searchQuery or ""):lower()
    local filterSpec = {
        types    = filterState.types,
        rarities = filterState.rarities,
        slots    = filterState.slots,
        owners   = filterState.owners,
        search   = searchQuery ~= "" and InventoryPanelVM._searchQuery or nil,
        equipped = (filterState.equipMode and filterState.equipMode ~= "Both") and filterState.equipMode or nil,
    }

    local filteredItems = FilterEngine and FilterEngine.FilterMulti(allItems, filterSpec) or allItems
    -- Sort only if a sort field is active (nil = no sort, use natural order)
    if FilterEngine and filterState.sortBy then
        filteredItems = FilterEngine.Sort(filteredItems, filterState.sortBy, filterState.sortAscending)
    end

    local passingUUIDs = {}
    for _, item in ipairs(filteredItems) do
        if item.UUID then passingUUIDs[item.UUID] = true end
    end

    local anyFilterActive = next(filterState.types) or next(filterState.rarities)
        or next(filterState.slots) or next(filterState.owners)
        or (searchQuery ~= "")
        or (filterState.equipMode and filterState.equipMode ~= "Both")

    -- Build sort order from filtered DataStore items (when any sort is active)
    local uuidOrder = nil
    if filterState.sortBy then
        uuidOrder = {}
        for rank, item in ipairs(filteredItems) do
            if item.UUID then uuidOrder[item.UUID] = rank end
        end
    end

    -- Collect passing entries (proxies are still alive here — same call frame)
    local passingEntries = {}
    for i = 1, totalSlotCount do
        local entry = _tempSlots[i]
        if entry then
            local uuid = entry.uuid
            if uuid and passingUUIDs[uuid] then
                passingEntries[#passingEntries + 1] = entry
            elseif not uuid and not anyFilterActive then
                passingEntries[#passingEntries + 1] = entry
            end
        end
    end

    -- Sort entries if non-default sort is active
    if uuidOrder then
        table.sort(passingEntries, function(a, b)
            local oa = a.uuid and uuidOrder[a.uuid] or 999999
            local ob = b.uuid and uuidOrder[b.uuid] or 999999
            return oa < ob
        end)
    end

    -- Now build NativeSlots from passing entries (proxies still fresh)
    ClearCollection(vm.NativeSlots)
    InventoryPanelVM._slotMap = {}
    local filteredCount = 0

    local nativeUUIDs = {}
    for _, entry in ipairs(passingEntries) do
        local dsItem = entry.uuid and dsItemByUUID[entry.uuid] or nil
        filteredCount = filteredCount + 1
        local wrapper = Ext.UI.Instantiate("INVRW_SlotWrapper")
        pcall(function() wrapper.NativeSlot   = entry.slot end)
        pcall(function() wrapper.NativeObject = entry.vmObject end)
        pcall(function() wrapper.NativeHandle = entry.entityHandle end)
        -- Icon, rarity, and stack count all rendered by Template.Item natively.
        wrapper.IsEquipped = (dsItem and dsItem.Equipped == true) and true or false
        vm.NativeSlots[filteredCount] = wrapper
        InventoryPanelVM._slotMap[filteredCount] = {
            uuid = entry.uuid,
            name = (dsItem and dsItem.Name) or entry.name or "Unknown"
        }
        if entry.uuid then nativeUUIDs[entry.uuid] = true end
    end

    -- Add camp chest items as ghost wrappers (no native slot, shown via ItemIcon)
    local ghostCount = 0
    for _, dsItem in ipairs(filteredItems) do
        if dsItem.Source == "CampChest" and dsItem.UUID and not nativeUUIDs[dsItem.UUID] then
            filteredCount = filteredCount + 1
            ghostCount = ghostCount + 1
            local wrapper = Ext.UI.Instantiate("INVRW_SlotWrapper")
            wrapper.IsGhost = true
            wrapper.HasItem = true
            local iconName = dsItem.Icon or "Item_Unknown"
            wrapper.ItemIcon = "pack://application:,,,/Core;component/Assets/ControllerUIIcons/items_png/" .. iconName .. ".DDS"
            wrapper.Rarity = dsItem.Rarity or "Common"
            local stack = dsItem.StackSize or 1
            wrapper.StackSize = stack
            wrapper.ShowStack = stack > 1
            vm.NativeSlots[filteredCount] = wrapper
            InventoryPanelVM._slotMap[filteredCount] = {
                uuid = dsItem.UUID,
                name = dsItem.Name or "Unknown"
            }
        end
    end

    local hasFilters = anyFilterActive or (filterState.sortBy ~= nil)
    if hasFilters then
        vm.StatusText = "Total " .. filteredCount .. " / " .. totalSlotCount .. " (filtered)"
    else
        vm.StatusText = "Total " .. filteredCount
    end
    _P("[InventoryExpanded] Panel populated: " .. (filteredCount - ghostCount) .. " native + " .. ghostCount .. " camp ghost / " .. totalSlotCount .. " native slots"
       .. (hasFilters and " [filtered]" or ""))
end

--- Try to bind by creating a fresh VM and immediately setting it as DataContext.
function InventoryPanelVM.TryBind()
    if isBound then return end
    if not isRegistered then return end

    local widget = FindWidget()
    if not widget then return end

    _P("[INVRW Bind] Found InventoryPanel widget: " .. tostring(widget))

    -- Create fresh VM and immediately assign as DataContext (prevents Noesis GC)
    local freshVM = nil
    local createOk, createErr = pcall(function()
        freshVM = Ext.UI.Instantiate("INVRW_InventoryPanelVM")
    end)
    if not createOk or not freshVM then
        _P("[INVRW Bind] VM creation failed: " .. tostring(createErr))
        return
    end

    -- Wire command handlers
    pcall(function()
        freshVM.ToggleCommand:SetHandler(function()
            InventoryPanelVM.Toggle()
        end)
    end)
    pcall(function()
        freshVM.RefreshCommand:SetHandler(function()
            -- Only request fresh data from server; OnDataUpdated handles the repopulate.
            -- Calling PopulateFromDataStore here too causes a double rebuild race that crashes Noesis.
            Mods.InventoryExpanded.RequestRefresh()
        end)
    end)

    -- Item action commands
    -- Lua-side map: index → {uuid, name} built during PopulateFromDataStore
    InventoryPanelVM._slotMap = {}

    -- Helper: get selected character UUID for actions that need a target
    local function getSelectedCharUUID()
        local charUUID = nil
        pcall(function()
            local root = Ext.UI.GetRoot()
            local contentRoot = root:Find("ContentRoot")
            local overlay = nil
            local children = contentRoot.Children
            for i = 0, 30 do
                pcall(function()
                    local c = children[i]
                    if c and c.Name == "Overlay" then overlay = c end
                end)
            end
            if overlay and overlay.DataContext then
                local sc = overlay.DataContext.CurrentPlayer.SelectedCharacter
                local props = {"UniqueId", "UUID", "EntityUUID", "EntityHandle",
                               "CharacterUUID", "Id", "Guid", "Handle", "GuidString"}
                for _, pn in ipairs(props) do
                    pcall(function()
                        local val = sc[pn]
                        if val ~= nil and val ~= "" then
                            if not charUUID then charUUID = val end
                        end
                    end)
                end
            end
        end)
        return charUUID
    end

    -- Helper: show/hide the context menu overlay by finding it in the widget tree
    local function setMenuVisible(visible)
        pcall(function()
            local w = FindWidget()
            if not w then return end
            local menuPanel = w:Find("ContextMenuPanel")
            if menuPanel then
                menuPanel.Visibility = visible and "Visible" or "Collapsed"
            end
            -- Also toggle hit-testing on the menu layer
            local menuLayer = w:Find("MenuLayer")
            if menuLayer then
                menuLayer.IsHitTestVisible = visible
            end
        end)
    end

    -- Helper: resolve selected item UUID from VM.SelectedIndex + slotMap
    local function getSelectedItem()
        local idx = nil
        pcall(function()
            local vm = GetVM()
            if vm then idx = vm.SelectedIndex end
        end)
        if idx == nil or idx < 0 then return nil, nil end
        local info = InventoryPanelVM._slotMap[idx + 1]  -- 0-based → 1-based
        if info then
            pcall(function()
                local vm = GetVM()
                if vm then vm.SelectedItemName = info.name end
            end)
            return info.uuid, info.name
        end
        return nil, nil
    end

    -- ShowMenuCommand: right-click on item opens the context menu near the item
    pcall(function()
        freshVM.ShowMenuCommand:SetHandler(function()
            local uuid, name = getSelectedItem()
            if not uuid then
                return
            end

            -- Position menu next to the selected item based on grid index
            pcall(function()
                local vm = GetVM()
                if not vm then return end

                local idx = vm.SelectedIndex or 0

                -- Grid layout: 96px cells in WrapPanel, panel ~1252px wide
                local cellSize = 96
                local cols = 13  -- floor(1252 / 96)
                local row = math.floor(idx / cols)
                local col = idx % cols

                -- Position menu to the right of the clicked cell
                local localX = (col + 1) * cellSize + 4
                local localY = row * cellSize

                -- Prevent menu going off the right edge — shift left if needed
                if localX > 900 then
                    localX = col * cellSize - 240  -- put menu to the LEFT of the cell
                    if localX < 0 then localX = 0 end
                end

                vm.MenuX = localX
                vm.MenuY = localY
            end)

            setMenuVisible(true)
        end)
    end)

    -- HideMenuCommand: left-click on item or elsewhere closes the menu + deactivates search typing
    pcall(function()
        freshVM.HideMenuCommand:SetHandler(function()
            setMenuVisible(false)
            -- Deactivate search typing if clicking outside the search bar
            if InventoryPanelVM._searchTyping then
                InventoryPanelVM._searchTyping = false
                pcall(function()
                    local vm = GetVM()
                    if vm then
                        local q = InventoryPanelVM._searchBuffer or ""
                        vm.SearchQuery = q  -- remove cursor
                    end
                end)
            end
        end)
    end)

    -- Helper: execute action then close menu + schedule delayed refresh
    -- The game takes time to actually process item actions (consume, equip, drop).
    -- The server broadcasts inventory immediately but the game state hasn't changed yet.
    -- A delayed refresh catches the actual state change.
    local function doAction(actionName, handler)
        pcall(function()
            freshVM[actionName]:SetHandler(function()
                local uuid, name = getSelectedItem()
                if not uuid then
                    return
                end
                setMenuVisible(false)  -- close menu
                handler(uuid, name)
                -- Delayed refresh: game needs time to process the action
                pcall(function()
                    Ext.Timer.WaitFor(1200, function()
                        Mods.InventoryExpanded.RequestRefresh()
                    end)
                end)
            end)
        end)
    end

    doAction("UseItemCommand", function(uuid, name)
        local charUUID = getSelectedCharUUID()
        Ext.Net.PostMessageToServer("InvRework_UseItem",
            Ext.Json.Stringify({ itemUUID = uuid, charUUID = charUUID }))
    end)

    doAction("EquipItemCommand", function(uuid, name)
        local charUUID = getSelectedCharUUID()
        if not charUUID then _P("[InventoryExpanded] EquipItem: no selected char") return end
        Ext.Net.PostMessageToServer("InvRework_EquipItem",
            Ext.Json.Stringify({ itemUUID = uuid, targetCharUUID = charUUID }))
    end)

    doAction("DropItemCommand", function(uuid, name)
        local charUUID = getSelectedCharUUID()
        Ext.Net.PostMessageToServer("InvRework_DropItem",
            Ext.Json.Stringify({ itemUUID = uuid, charUUID = charUUID }))
    end)

    doAction("SendToCampCommand", function(uuid, name)
        Ext.Net.PostMessageToServer("InvRework_SendToCamp",
            Ext.Json.Stringify({ itemUUID = uuid }))
    end)

    -- Helper: sync HasSearchQuery bool from buffer content
    local function syncHasSearch()
        pcall(function()
            local vm = GetVM()
            if vm then
                vm.HasSearchQuery = (InventoryPanelVM._searchBuffer or "") ~= ""
            end
        end)
    end

    -- Search typing state
    InventoryPanelVM._searchTyping = false
    InventoryPanelVM._searchBuffer = ""

    -- SearchFocusCommand: clicking the search text area activates typing mode
    pcall(function()
        freshVM.SearchFocusCommand:SetHandler(function()
            InventoryPanelVM._searchTyping = true
            pcall(function()
                local vm = GetVM()
                if vm then
                    local buf = InventoryPanelVM._searchBuffer or ""
                    vm.SearchQuery = buf .. "|"
                end
            end)
            syncHasSearch()
        end)
    end)

    -- SearchCommand: execute search from button click
    pcall(function()
        freshVM.SearchCommand:SetHandler(function()
            pcall(function()
                InventoryPanelVM._searchTyping = false
                local vm = GetVM()
                if not vm then return end
                local q = InventoryPanelVM._searchBuffer or ""
                vm.SearchQuery = q
                InventoryPanelVM._searchQuery = q
                InventoryPanelVM.ApplyFiltersAndRefresh()
            end)
        end)
    end)

    -- ClearSearchCommand: clear query and re-populate
    pcall(function()
        freshVM.ClearSearchCommand:SetHandler(function()
            pcall(function()
                InventoryPanelVM._searchTyping = false
                InventoryPanelVM._searchBuffer = ""
                local vm = GetVM()
                if not vm then return end
                vm.SearchQuery = ""
                vm.HasSearchQuery = false
                InventoryPanelVM._searchQuery = ""
                InventoryPanelVM.ApplyFiltersAndRefresh()
            end)
        end)
    end)

    -- Resize commands: grow/shrink by one item row (96px) per click
    local ROW_STEP = 96
    local MIN_HEIGHT = 300
    local MAX_HEIGHT = 1400
    local COL_STEP = 96
    local MIN_WIDTH = 500
    local MAX_WIDTH = 1900
    pcall(function()
        freshVM.ResizeGrowCommand:SetHandler(function()
            local vm = GetVM()
            if not vm then return end
            local newH = math.min(MAX_HEIGHT, vm.PanelHeight + ROW_STEP)
            vm.PanelHeight = newH
        end)
    end)
    pcall(function()
        freshVM.ResizeShrinkCommand:SetHandler(function()
            local vm = GetVM()
            if not vm then return end
            local newH = math.max(MIN_HEIGHT, vm.PanelHeight - ROW_STEP)
            vm.PanelHeight = newH
        end)
    end)
    pcall(function()
        freshVM.WidenCommand:SetHandler(function()
            local vm = GetVM()
            if not vm then return end
            local newW = math.min(MAX_WIDTH, vm.PanelWidth + COL_STEP)
            vm.PanelWidth = newW
        end)
    end)
    pcall(function()
        freshVM.NarrowCommand:SetHandler(function()
            local vm = GetVM()
            if not vm then return end
            local newW = math.max(MIN_WIDTH, vm.PanelWidth - COL_STEP)
            vm.PanelWidth = newW
        end)
    end)

    -- ── Filter panel commands ────────────────────────────────────
    pcall(function()
        freshVM.ToggleFilterPanelCommand:SetHandler(function()
            pcall(function()
                local vm = GetVM()
                if vm then
                    vm.FilterPanelVisible = not vm.FilterPanelVisible
                end
            end)
        end)
    end)

    pcall(function()
        freshVM.ClearAllFiltersCommand:SetHandler(function()
            -- Reset all filter state
            filterState.types = {}
            filterState.rarities = {}
            filterState.slots = {}
            filterState.owners = {}
            filterState.equipMode = "Both"
            -- Reset all VM String properties to "False"
            pcall(function()
                local vm = GetVM()
                if not vm then return end
                for _, f in ipairs({"Weapon","Armor","Scroll","Misc"}) do
                    pcall(function() vm["FilterType_" .. f] = "False" end)
                end
                for _, f in ipairs({"Common","Uncommon","Rare","VeryRare","Legendary"}) do
                    pcall(function() vm["FilterRarity_" .. f] = "False" end)
                end
                for _, f in ipairs({"Helmet","Chest","Cloak","Gloves","Boots","Amulet","Ring","MainHand","OffHand","Ranged"}) do
                    pcall(function() vm["FilterSlot_" .. f] = "False" end)
                end
                pcall(function()
                    vm.FilterEquipMode_Both       = "True"
                    vm.FilterEquipMode_Equipped   = "False"
                    vm.FilterEquipMode_Unequipped = "False"
                end)
            end)
            UpdateFilterCount()
            InventoryPanelVM.ApplyFiltersAndRefresh()
        end)
    end)

    -- Wire type filter toggles (data-driven)
    local typeFilters = {
        {cmd="ToggleType_Weapon", prop="FilterType_Weapon", key="Weapon"},
        {cmd="ToggleType_Armor",  prop="FilterType_Armor",  key="Armor"},
        {cmd="ToggleType_Scroll", prop="FilterType_Scroll", key="Scroll"},
        {cmd="ToggleType_Misc",   prop="FilterType_Misc",   key="Misc"},
    }
    for _, f in ipairs(typeFilters) do
        pcall(function() freshVM[f.cmd]:SetHandler(MakeToggleHandler(f.prop, filterState.types, f.key)) end)
    end

    -- Wire rarity filter toggles
    local rarityFilters = {
        {cmd="ToggleRarity_Common",    prop="FilterRarity_Common",    key="Common"},
        {cmd="ToggleRarity_Uncommon",  prop="FilterRarity_Uncommon",  key="Uncommon"},
        {cmd="ToggleRarity_Rare",      prop="FilterRarity_Rare",      key="Rare"},
        {cmd="ToggleRarity_VeryRare",  prop="FilterRarity_VeryRare",  key="VeryRare"},
        {cmd="ToggleRarity_Legendary", prop="FilterRarity_Legendary", key="Legendary"},
    }
    for _, f in ipairs(rarityFilters) do
        pcall(function() freshVM[f.cmd]:SetHandler(MakeToggleHandler(f.prop, filterState.rarities, f.key)) end)
    end

    -- Wire slot filter toggles
    local slotFilters = {
        {cmd="ToggleSlot_Helmet",   prop="FilterSlot_Helmet",   key="Helmet"},
        {cmd="ToggleSlot_Chest",    prop="FilterSlot_Chest",    key="Breast"},       -- BG3 internal name
        {cmd="ToggleSlot_Cloak",    prop="FilterSlot_Cloak",    key="Cloak"},
        {cmd="ToggleSlot_Gloves",   prop="FilterSlot_Gloves",   key="Gloves"},
        {cmd="ToggleSlot_Boots",    prop="FilterSlot_Boots",    key="Boots"},
        {cmd="ToggleSlot_Amulet",   prop="FilterSlot_Amulet",   key="Amulet"},
        {cmd="ToggleSlot_Ring",     prop="FilterSlot_Ring",     key="Ring"},
        {cmd="ToggleSlot_MainHand", prop="FilterSlot_MainHand", key="MeleeMainHand"},
        {cmd="ToggleSlot_OffHand",  prop="FilterSlot_OffHand",  key="MeleeOffHand"},
        {cmd="ToggleSlot_Ranged",   prop="FilterSlot_Ranged",   key="Ranged MainHand"},
    }
    for _, f in ipairs(slotFilters) do
        pcall(function() freshVM[f.cmd]:SetHandler(MakeToggleHandler(f.prop, filterState.slots, f.key)) end)
    end

    -- Wire equip mode radio commands
    local function MakeEquipModeHandler(mode)
        return function()
            filterState.equipMode = mode
            pcall(function()
                local vm = GetVM()
                if not vm then return end
                vm.FilterEquipMode_Both       = mode == "Both"       and "True" or "False"
                vm.FilterEquipMode_Equipped   = mode == "Equipped"   and "True" or "False"
                vm.FilterEquipMode_Unequipped = mode == "Unequipped" and "True" or "False"
            end)
            UpdateFilterCount()
            InventoryPanelVM.ApplyFiltersAndRefresh()
        end
    end
    pcall(function() freshVM.SetEquipMode_Both:SetHandler(MakeEquipModeHandler("Both")) end)
    pcall(function() freshVM.SetEquipMode_Equipped:SetHandler(MakeEquipModeHandler("Equipped")) end)
    pcall(function() freshVM.SetEquipMode_Unequipped:SetHandler(MakeEquipModeHandler("Unequipped")) end)

    -- Wire sort commands
    pcall(function() freshVM.SortByNameCommand:SetHandler(MakeSortHandler("Name")) end)
    pcall(function() freshVM.SortByValueCommand:SetHandler(MakeSortHandler("Value")) end)
    pcall(function() freshVM.SortByWeightCommand:SetHandler(MakeSortHandler("Weight")) end)
    pcall(function() freshVM.SortByRarityCommand:SetHandler(MakeSortHandler("Rarity")) end)

    -- ── Initial property values ───────────────────────────────────
    freshVM.PanelVisible = false
    freshVM.RootVisibility = "Collapsed"
    freshVM.PanelHeight = 1128
    freshVM.PanelWidth = 1492
    freshVM.StatusText = "Connecting..."
    freshVM.SelectedItemName = "Click an item to select it"
    freshVM.SelectedIndex = -1
    freshVM.MenuX = 0
    freshVM.MenuY = 0
    freshVM.SearchQuery = ""
    freshVM.HasSearchQuery = false
    freshVM.FilterPanelVisible = false
    freshVM.ActiveFilterCount = ""
    freshVM.FilterEquipMode_Both       = "True"
    freshVM.FilterEquipMode_Equipped   = "False"
    freshVM.FilterEquipMode_Unequipped = "False"
    freshVM.SortField = ""
    freshVM.SortAscending = true
    freshVM.SortState_Name = ""
    freshVM.SortState_Value = ""
    freshVM.SortState_Weight = ""
    freshVM.SortState_Rarity = ""
    InventoryPanelVM._searchQuery = ""

    -- Set as DataContext IMMEDIATELY
    local setOk, setErr = pcall(function()
        widget.DataContext = freshVM
    end)

    if setOk then
        isBound = true
        ForceClosed(widget, freshVM)
        -- Re-acquire via FindWidget().DataContext to confirm it works
        local vm = GetVM()
        if vm then
            vm.StatusText = "Connected"
            _P("[INVRW Bind] SUCCESS! DataContext set and re-acquired OK")
        else
            _P("[INVRW Bind] SUCCESS! DataContext set but re-acquire failed")
        end
        _P("[INVRW Bind] ========================================")
        return
    end

    _P("[INVRW Bind] DataContext set FAILED: " .. tostring(setErr))
end

local function EnsureBound()
    local widget = FindWidget()
    if not widget then return nil end

    local vm = nil
    local ok = pcall(function() vm = widget.DataContext end)
    if ok and vm then
        local ok2 = pcall(function() local _ = vm.StatusText end)
        if ok2 then
            return vm
        end
    end

    isBound = false
    pcall(function() widget.Visibility = "Collapsed" end)
    pcall(function() widget.DataContext = nil end)
    pcall(InventoryPanelVM.TryBind)

    local reboundVM = GetVM()
    if reboundVM then
        ForceClosed(widget, reboundVM)
    end

    return reboundVM
end


--- Initialize the ViewModel.
function InventoryPanelVM.Init()
    RegisterTypes()
    _P("[InventoryExpanded] InventoryPanelVM initialized, waiting for widget...")

    -- Widget appears after ~10s. Check at increasing intervals.
    local delays = {8000, 10000, 12000, 15000, 20000, 30000}
    for _, delay in ipairs(delays) do
        pcall(function()
            Ext.Timer.WaitFor(delay, function()
                if not isBound then
                    pcall(InventoryPanelVM.TryBind)
                end
            end)
        end)
    end
end

--- Force the panel hidden (used on area loads to prevent ghost windows).
function InventoryPanelVM.ForceHide()
    ForceClosed(FindWidget(), GetVM())
end

--- Toggle panel visibility.
function InventoryPanelVM.Toggle()
    local vm = EnsureBound()
    if not vm then
        _P("[InventoryExpanded] Toggle: cannot get VM")
        return
    end
    vm.PanelVisible = not vm.PanelVisible
    local vis = vm.PanelVisible and "Visible" or "Collapsed"
    vm.RootVisibility = vis

    -- Also set widget visibility as secondary enforcement (BG3 state machine may override this)
    local widget = FindWidget()
    if widget then
        pcall(function() widget.Visibility = vis end)
    end

    if vm.PanelVisible then
        -- Do NOT call PopulateFromDataStore() here — calling it alongside RequestRefresh()
        -- creates a double rebuild race that crashes Noesis (same reason as RefreshCommand).
        -- Let OnDataUpdated (triggered by the server response) be the sole rebuild path.
        Mods.InventoryExpanded.RequestRefresh()
    end
end

--- Called when fresh data arrives from server.
function InventoryPanelVM.OnDataUpdated()
    if not isBound then return end
    -- Re-enforce visibility — BG3 state machine can reset UIWidget.Visibility;
    -- RootVisibility (bound to Canvas) is the authoritative source of truth.
    pcall(function()
        local w = FindWidget()
        local v = GetVM()
        if w and v then
            local vis = v.PanelVisible and "Visible" or "Collapsed"
            w.Visibility = vis
            v.RootVisibility = vis
        end
    end)
    InventoryPanelVM.PopulateFromDataStore()
end

--- Get the VM instance (public API).
function InventoryPanelVM.GetVM()
    return GetVM()
end

-- Search typing keyboard handler — captures keys when search box is focused
-- Maps SE key names to characters for text input
-- MUST be registered BEFORE F10/F9 so it can block them via the _searchTyping flag
-- Keys are userdata enums; tostring() gives UPPERCASE names like "A", "D0", "SPACE"
local _keyCharMap = {
    A="a", B="b", C="c", D="d", E="e", F="f", G="g", H="h", I="i",
    J="j", K="k", L="l", M="m", N="n", O="o", P="p", Q="q", R="r",
    S="s", T="t", U="u", V="v", W="w", X="x", Y="y", Z="z",
    D0="0", D1="1", D2="2", D3="3", D4="4", D5="5", D6="6", D7="7", D8="8", D9="9",
    NUMPAD0="0", NUMPAD1="1", NUMPAD2="2", NUMPAD3="3", NUMPAD4="4",
    NUMPAD5="5", NUMPAD6="6", NUMPAD7="7", NUMPAD8="8", NUMPAD9="9",
    SPACE=" ", OEMMINUS="-", OEMPLUS="+", OEMPERIOD=".", OEMCOMMA=",",
    OEM1=";", OEM2="/", OEM3="`", OEM4="[", OEM5="\\", OEM6="]", OEM7="'",
    -- Also keep mixed-case variants just in case
    Space=" ", OemMinus="-", OemPlus="+", OemPeriod=".", OemComma=",",
    NumPad0="0", NumPad1="1", NumPad2="2", NumPad3="3", NumPad4="4",
    NumPad5="5", NumPad6="6", NumPad7="7", NumPad8="8", NumPad9="9",
}

-- Helper: try all known methods to consume/block a key event from reaching the game
local function consumeKeyEvent(e)
    pcall(function() e:StopPropagation() end)
    pcall(function() e:PreventAction() end)
    pcall(function() e:Prevent() end)
    pcall(function() e.Handled = true end)
    pcall(function() e.Stopped = true end)
end

Ext.Events.KeyInput:Subscribe(function(e)
    if not InventoryPanelVM._searchTyping then return end
    if tostring(e.Event) ~= "KeyDown" then return end

    local key = e.Key

    -- Block ALL keys from reaching the game while typing
    consumeKeyEvent(e)

    local vm = nil
    pcall(function() vm = GetVM() end)
    if not vm then return end

    -- Keys are userdata enums — compare via tostring(), which gives UPPERCASE names
    local keyStr = tostring(key)

    -- Enter / Return — execute search
    if keyStr == "RETURN" or keyStr == "ENTER" or keyStr == "KP_ENTER" then
        InventoryPanelVM._searchTyping = false
        local q = InventoryPanelVM._searchBuffer or ""
        vm.SearchQuery = q
        pcall(function() vm.HasSearchQuery = q ~= "" end)
        InventoryPanelVM._searchQuery = q
        InventoryPanelVM.ApplyFiltersAndRefresh()
        return
    end

    -- Escape — cancel typing
    if keyStr == "ESCAPE" or keyStr == "ESC" then
        InventoryPanelVM._searchTyping = false
        local q = InventoryPanelVM._searchQuery or ""
        vm.SearchQuery = q  -- restore previous query (no cursor)
        return
    end

    -- Backspace / Delete — remove last character
    if keyStr == "BACK" or keyStr == "BACKSPACE" or keyStr == "DELETE" or keyStr == "DEL" then
        local buf = InventoryPanelVM._searchBuffer or ""
        if #buf > 0 then
            InventoryPanelVM._searchBuffer = buf:sub(1, -2)
        end
        vm.SearchQuery = InventoryPanelVM._searchBuffer .. "|"
        pcall(function() vm.HasSearchQuery = InventoryPanelVM._searchBuffer ~= "" end)
        return
    end

    -- Map key to character (keys come as uppercase: "A", "D0", etc.)
    local ch = _keyCharMap[keyStr]
    if ch then
        InventoryPanelVM._searchBuffer = (InventoryPanelVM._searchBuffer or "") .. ch
        vm.SearchQuery = InventoryPanelVM._searchBuffer .. "|"
        pcall(function() vm.HasSearchQuery = true end)
    end
end)

-- Export
Mods.InventoryExpanded = Mods.InventoryExpanded or {}
Mods.InventoryExpanded.InventoryPanelVM = InventoryPanelVM

return InventoryPanelVM
