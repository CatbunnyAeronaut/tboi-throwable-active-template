-- Throwable Active Creator Function
---Makes a defined item have all the functionality of a throwable active, with one simple touch!
---* mod: Your mod variable.
---* collectible: The ID of the modded item you want to make a throwable.
---* identifier: A unique string to internally track the active item's usage. Don't halfass the name, make it unique, otherwise, you may get conflicts with other mods that use this same template!
---* effect: A function you define which is what your active item will do when the firing keys are pressed. The player can be optionally passed as an argument in this function.
---* wispCount: Number of Book of Virtue wisps of the item it should spawn when fired. If you have REPENTOGON, this parameter is unnecessary as it is handled automatically.
---@param mod table
---@param collectible CollectibleType
---@param identifier string
---@param effect fun(player?: EntityPlayer)
---@param wispCount number?
local function MakeThrowableActive(mod, collectible, identifier, effect, wispCount)
    local itemUseIdentifier = "using" .. identifier
    local slotIdentifier = identifier .. "ActiveSlot"
    local heartChargeIdentifier = identifier .. "HeartChargeToSpend"

    mod:AddCallback(ModCallbacks.MC_USE_ITEM, function (_, itemUsed, _, player, useFlags, slot, _)
        if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
        local data = player:GetData()
        if not data[itemUseIdentifier] then
            data[itemUseIdentifier] = true
            data[slotIdentifier] = slot
            if player:NeedsCharge(slot) then    -- if the player is able to use their active item but also needs charge, they are playing as bethany
                local config = Isaac.GetItemConfig():GetCollectible(collectible)
                local maxcharges = config.ChargeType == 1 and 1 or config.MaxCharges
                data[heartChargeIdentifier] = math.max(maxcharges - player:GetActiveCharge(slot), 1)
            end
            player:AnimateCollectible(collectible, "LiftItem", "PlayerPickup")
        else
            data[itemUseIdentifier] = false
            player:AnimateCollectible(collectible, "HideItem", "PlayerPickup")
        end
        return {Discharge = false, Remove = false, ShowAnim = false}
    end, collectible)

    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function (_, player)
        local data = player:GetData()
        if data[itemUseIdentifier] then
            if player:GetAimDirection():Length() < 1 then
                return
            else
                data[itemUseIdentifier] = false

                effect(player)

                local slot = data[slotIdentifier]
                if slot ~= -1 then
                    if slot == ActiveSlot.SLOT_PRIMARY then -- Prevent possible cheese with Schoolbag
                        if player:GetActiveItem(slot) ~= collectible then
                            slot = ActiveSlot.SLOT_SECONDARY
                        else
                            if player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY) < Isaac.GetItemConfig():GetCollectible(collectible).MaxCharges then
                                slot = ActiveSlot.SLOT_SECONDARY
                            end
                        end
                    end
                    player:DischargeActiveItem(slot) -- Since the item was used successfully, actually discharge the item
                end
                if data[heartChargeIdentifier] then
                    local spendHearts = data[heartChargeIdentifier]
                    if player:GetPlayerType() == PlayerType.PLAYER_BETHANY then
                        player:AddSoulCharge(-1 * spendHearts)
                    elseif player:GetPlayerType() == PlayerType.PLAYER_BETHANY_B then
                        player:AddBloodCharge(-1 * spendHearts)
                    end
                    if player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
                        if REPENTOGON then
                            local wispXmlData = XMLData.GetEntryById(XMLNode.WISP, collectible)
                            if wispXmlData then
                                local count = wispXmlData.count or 1
                                for i = 1, count do
                                    player:AddWisp(collectible, player.Position)
                                end
                            end
                        else
                            for i = 1, wispCount do
                                player:AddWisp(collectible, player.Position)
                            end
                        end
                    end
                end
                player:AnimateCollectible(collectible, "HideItem", "PlayerPickup")
            end
        end
    end)
    
    -- Terminate held active item functions
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function (_, entity, _, _, _, _)
        local player = entity:ToPlayer()
        if not player then return end
        
        local data = player:GetData()
        if data[itemUseIdentifier] then
            data[itemUseIdentifier] = false
            player:AnimateCollectible(collectible, "HideItem", "PlayerPickup")
        end
    end)

    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function (_)
        for _, player in pairs(PlayerManager.GetPlayers()) do
            local data = player:GetData()
            if data[itemUseIdentifier] then
                data[itemUseIdentifier] = false
                player:AnimateCollectible(collectible, "HideItem", "PlayerPickup")
            end
        end
    end)
end
