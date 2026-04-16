-- Inventory Expanded — Client Entry Point

Ext.Require("Client/DataStore.lua")
Ext.Require("Client/FilterEngine.lua")
Ext.Require("Client/NetHandlers.lua")
Ext.Require("Client/InventoryPanelVM.lua")
Ext.Require("Client/ArmoryPanelVM.lua")
Ext.Require("Client/DevCommands.lua")

-- Force both panels hidden whenever an area starts loading, so BG3's UI state
-- restore cannot resurface them as ghost windows with no bound context.
Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.ToState == "LoadSession" or e.ToState == "PrepareRunning" then
        pcall(function() Mods.InventoryExpanded.InventoryPanelVM.ForceHide() end)
        pcall(function() Mods.InventoryExpanded.ArmoryPanelVM.ForceHide() end)
    end
end)

Ext.Events.SessionLoaded:Subscribe(function()
    _P("[InventoryExpanded] Client loaded")

    -- Initialize InventoryPanel ViewModel after UI settles
    Ext.Timer.WaitFor(2000, function()
        local ok, err = pcall(Mods.InventoryExpanded.InventoryPanelVM.Init)
        if ok then
            pcall(Mods.InventoryExpanded.InventoryPanelVM.TryBind)
        else
            _P("[InventoryExpanded] InventoryPanelVM.Init failed: " .. tostring(err))
        end

        local ok2, err2 = pcall(Mods.InventoryExpanded.ArmoryPanelVM.Init)
        if ok2 then
            pcall(Mods.InventoryExpanded.ArmoryPanelVM.TryBind)
        else
            _P("[InventoryExpanded] ArmoryPanelVM.Init failed: " .. tostring(err2))
        end
    end)

    -- Register MCM keybinding callbacks
    -- Cooldown prevents keyboard-repeat events from stacking rapid toggles.
    local TOGGLE_COOLDOWN_MS = 300
    local _lastInvToggleTime = 0
    local _lastArmToggleTime = 0

    pcall(function()
        MCM.Keybinding.SetCallback("inventory_panel_key", function()
            local now = 0
            pcall(function() now = Ext.Utils.MonotonicTime() end)
            if (now - _lastInvToggleTime) < TOGGLE_COOLDOWN_MS then return end
            _lastInvToggleTime = now
            pcall(Mods.InventoryExpanded.InventoryPanelVM.TryBind)
            Mods.InventoryExpanded.InventoryPanelVM.Toggle()
        end)
        MCM.Keybinding.SetCallback("armory_panel_key", function()
            local now = 0
            pcall(function() now = Ext.Utils.MonotonicTime() end)
            if (now - _lastArmToggleTime) < TOGGLE_COOLDOWN_MS then return end
            _lastArmToggleTime = now
            pcall(Mods.InventoryExpanded.ArmoryPanelVM.TryBind)
            Mods.InventoryExpanded.ArmoryPanelVM.Toggle()
        end)
        _P("[InventoryExpanded] MCM keybindings registered")
    end)
end)
