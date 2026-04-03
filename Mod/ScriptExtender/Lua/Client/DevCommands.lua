--- Dev-only SE console commands for InventoryExpanded.
-- Loaded unconditionally — commands fire only when explicitly typed.
-- @module DevCommands

-- ---------------------------------------------------------------------------
-- !invrw_reload
-- Re-runs Init + TryBind + OnDataUpdated on both VMs.
-- Faster than full `reset` when iterating on ViewModel logic.
-- ---------------------------------------------------------------------------
Ext.RegisterConsoleCommand("invrw_reload", function()
    _P("[InventoryExpanded][Dev] Reloading VMs...")

    local invVM  = Mods.InventoryExpanded.InventoryPanelVM
    local armVM  = Mods.InventoryExpanded.ArmoryPanelVM

    if invVM then
        local ok, err = pcall(invVM.Init)
        if ok then
            pcall(invVM.TryBind)
            pcall(invVM.OnDataUpdated)
            _P("[InventoryExpanded][Dev] InventoryPanelVM reloaded OK")
        else
            _P("[InventoryExpanded][Dev] InventoryPanelVM.Init failed: " .. tostring(err))
        end
    else
        _P("[InventoryExpanded][Dev] InventoryPanelVM not found")
    end

    if armVM then
        local ok, err = pcall(armVM.Init)
        if ok then
            pcall(armVM.TryBind)
            pcall(armVM.OnDataUpdated)
            _P("[InventoryExpanded][Dev] ArmoryPanelVM reloaded OK")
        else
            _P("[InventoryExpanded][Dev] ArmoryPanelVM.Init failed: " .. tostring(err))
        end
    else
        _P("[InventoryExpanded][Dev] ArmoryPanelVM not found")
    end
end)

-- ---------------------------------------------------------------------------
-- !invrw_dump
-- Prints DataStore summary: total items, unique owners, type breakdown,
-- rarity breakdown.
-- ---------------------------------------------------------------------------
Ext.RegisterConsoleCommand("invrw_dump", function()
    local DS = Mods.InventoryExpanded.DataStore
    if not DS then
        _P("[InventoryExpanded][Dev] DataStore not available")
        return
    end

    local total   = DS.GetItemCount()
    local owners  = DS.GetOwners()
    local types   = DS.GetTypes()
    local rars    = DS.GetRarities()

    _P("[InventoryExpanded][Dev] ── DataStore Dump ──────────────────────")
    _P("[InventoryExpanded][Dev] Total items : " .. total)
    _P("[InventoryExpanded][Dev] Owners      : " .. #owners)
    for _, o in ipairs(owners) do
        local count = #DS.GetItemsByOwner(o)
        -- Try to get a display name from the first item owned
        local uuids = DS.GetItemsByOwner(o)
        local ownerName = o
        if uuids[1] then
            local item = DS.GetItem(uuids[1])
            if item and item.OwnerName then ownerName = item.OwnerName end
        end
        _P("[InventoryExpanded][Dev]   " .. ownerName .. " : " .. count .. " items")
    end

    _P("[InventoryExpanded][Dev] Types :")
    for _, t in ipairs(types) do
        _P("[InventoryExpanded][Dev]   " .. tostring(t) .. " : " .. #DS.GetItemsByType(t))
    end

    _P("[InventoryExpanded][Dev] Rarities :")
    for _, r in ipairs(rars) do
        _P("[InventoryExpanded][Dev]   " .. tostring(r) .. " : " .. #DS.GetItemsByRarity(r))
    end
    _P("[InventoryExpanded][Dev] ────────────────────────────────────────")
end)

-- ---------------------------------------------------------------------------
-- !invrw_open <panel>
-- Force-opens a panel by calling its ToggleCommand (if not already visible).
-- Usage: !invrw_open inventory   or   !invrw_open armory
-- ---------------------------------------------------------------------------
Ext.RegisterConsoleCommand("invrw_open", function(_, panel)
    local target = (panel or ""):lower()
    if target == "inventory" then
        local vm = Mods.InventoryExpanded.InventoryPanelVM
        if vm and vm.Toggle then
            pcall(vm.Toggle)
            _P("[InventoryExpanded][Dev] InventoryPanel toggled")
        else
            _P("[InventoryExpanded][Dev] InventoryPanelVM.Toggle not available (VM not bound?)")
        end
    elseif target == "armory" then
        local vm = Mods.InventoryExpanded.ArmoryPanelVM
        if vm and vm.Toggle then
            pcall(vm.Toggle)
            _P("[InventoryExpanded][Dev] ArmoryPanel toggled")
        else
            _P("[InventoryExpanded][Dev] ArmoryPanelVM.Toggle not available (VM not bound?)")
        end
    else
        _P("[InventoryExpanded][Dev] Usage: !invrw_open inventory|armory")
    end
end)

-- ---------------------------------------------------------------------------
-- !invrw_status
-- Prints binding state of both VMs: bound/unbound, item count, active
-- filters, sort state.
-- ---------------------------------------------------------------------------
Ext.RegisterConsoleCommand("invrw_status", function()
    local DS    = Mods.InventoryExpanded.DataStore
    local invVM = Mods.InventoryExpanded.InventoryPanelVM
    local armVM = Mods.InventoryExpanded.ArmoryPanelVM

    _P("[InventoryExpanded][Dev] ── Status ──────────────────────────────")

    -- DataStore
    if DS then
        _P("[InventoryExpanded][Dev] DataStore: " .. DS.GetItemCount() .. " items")
    else
        _P("[InventoryExpanded][Dev] DataStore: NOT LOADED")
    end

    -- InventoryPanelVM — probe the Noesis VM for live state
    if invVM and invVM.GetVM then
        local vm = invVM.GetVM()
        if vm then
            local visible = tostring(vm.PanelVisible or false)
            local status  = tostring(vm.StatusText or "")
            local filters = tostring(vm.ActiveFilterCount or "0")
            _P("[InventoryExpanded][Dev] InventoryPanelVM: BOUND")
            _P("[InventoryExpanded][Dev]   PanelVisible    = " .. visible)
            _P("[InventoryExpanded][Dev]   StatusText      = " .. status)
            _P("[InventoryExpanded][Dev]   ActiveFilters   = " .. filters)
        else
            _P("[InventoryExpanded][Dev] InventoryPanelVM: registered but VM proxy nil (not yet bound or widget missing)")
        end
    else
        _P("[InventoryExpanded][Dev] InventoryPanelVM: NOT LOADED")
    end

    -- ArmoryPanelVM
    if armVM and armVM.GetVM then
        local vm = armVM.GetVM()
        if vm then
            local visible = tostring(vm.PanelVisible or false)
            local status  = tostring(vm.StatusText or "")
            local slot    = tostring(vm.ActiveSlotLabel or "")
            _P("[InventoryExpanded][Dev] ArmoryPanelVM: BOUND")
            _P("[InventoryExpanded][Dev]   PanelVisible    = " .. visible)
            _P("[InventoryExpanded][Dev]   StatusText      = " .. status)
            _P("[InventoryExpanded][Dev]   ActiveSlot      = " .. slot)
        else
            _P("[InventoryExpanded][Dev] ArmoryPanelVM: registered but VM proxy nil (not yet bound or widget missing)")
        end
    else
        _P("[InventoryExpanded][Dev] ArmoryPanelVM: NOT LOADED")
    end

    _P("[InventoryExpanded][Dev] ────────────────────────────────────────")
end)
