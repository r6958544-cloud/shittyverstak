if not CLIENT then return end

local function PatchZCityWeaponSelector()
    if not hg or not hg.WeaponSelector then return false end

    local WS = hg.WeaponSelector
    if WS.SSRPCraftingSafeTable then return true end

    WS.GetWeaponTable = function(ply)
        if not IsValid(ply) or not ply:Alive() then return end

        local weapons = ply:GetWeapons()
        local formatted = {
            [0] = {},
            [1] = {},
            [2] = {},
            [3] = {},
            [4] = {},
            [5] = {}
        }

        table.sort(weapons, function(a, b)
            return (tonumber(a.SlotPos) or 0) > (tonumber(b.SlotPos) or 0)
        end)

        for _, weapon in ipairs(weapons) do
            if IsValid(weapon) then
                -- ZCity хранит только слоты 0–5. Всё нестандартное
                -- безопасно отправляем в последний слот.
                local slot = math.floor(tonumber(weapon.Slot) or 0)
                slot = math.Clamp(slot, 0, 5)

                local slotTable = formatted[slot]
                local wantedPosition = math.floor(tonumber(weapon.SlotPos) or 1) - 1
                wantedPosition = math.max(wantedPosition, 0)

                while slotTable[wantedPosition] do
                    wantedPosition = wantedPosition + 1
                end

                slotTable[wantedPosition] = weapon
            end
        end

        return formatted
    end

    WS.SSRPCraftingSafeTable = true
    return true
end

PatchZCityWeaponSelector()

timer.Create("SSRP_Crafting_ZCitySelectorPatch", 0.5, 0, function()
    if PatchZCityWeaponSelector() then
        timer.Remove("SSRP_Crafting_ZCitySelectorPatch")
    end
end)
