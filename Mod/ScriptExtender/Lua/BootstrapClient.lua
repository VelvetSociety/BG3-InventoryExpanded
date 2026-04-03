-- Inventory Expanded — Client Entry Point

Ext.Require("Client/DataStore.lua")
Ext.Require("Client/FilterEngine.lua")
Ext.Require("Client/NetHandlers.lua")
Ext.Require("Client/InventoryPanelVM.lua")
Ext.Require("Client/ArmoryPanelVM.lua")
Ext.Require("Client/DevCommands.lua")

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
    pcall(function()
        MCM.Keybinding.SetCallback("inventory_panel_key", function()
            pcall(Mods.InventoryExpanded.InventoryPanelVM.TryBind)
            Mods.InventoryExpanded.InventoryPanelVM.Toggle()
        end)
        MCM.Keybinding.SetCallback("armory_panel_key", function()
            pcall(Mods.InventoryExpanded.ArmoryPanelVM.TryBind)
            Mods.InventoryExpanded.ArmoryPanelVM.Toggle()
        end)
        _P("[InventoryExpanded] MCM keybindings registered")
    end)
end)
