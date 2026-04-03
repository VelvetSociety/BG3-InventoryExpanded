-- Inventory Expanded — Server Entry Point

Ext.Require("Server/InventoryCollector.lua")
Ext.Require("Server/ItemMover.lua")
Ext.Require("Server/NetHandlers.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    _P("[InventoryExpanded] Server loaded")
end)
