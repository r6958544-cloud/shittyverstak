if SERVER then
    AddCSLuaFile()

    -- Keep the requested compact models craftable on servers that only ship
    -- Z-City's Glock 17. A native Z-City version always takes priority.
    hook.Add("InitPostEntity", "SSRP_GlockCompactFallbacks", function()
        timer.Simple(1, function()
            local base = weapons.GetStored("weapon_glock17")
            if not base then return end

            local variants = {
                {class = "weapon_glock19", printName = "Glock 19", needle = "glock19"},
                {class = "weapon_glock26", printName = "Glock 26", needle = "glock26"}
            }
            local available = weapons.GetList()
            for _, variantInfo in ipairs(variants) do
                local exists = weapons.GetStored(variantInfo.class) ~= nil
                if not exists then
                    for _, info in ipairs(available) do
                        local class = string.gsub(string.lower(tostring(info.ClassName or info.Class or "")), "[^%w]", "")
                        local printed = string.gsub(string.lower(tostring(info.PrintName or "")), "[^%w]", "")
                        if string.find(class, variantInfo.needle, 1, true)
                            or string.find(printed, variantInfo.needle, 1, true) then
                            exists = true
                            break
                        end
                    end
                end

                if not exists then
                    local sw = table.Copy(base)
                    sw.Base = "weapon_glock17"
                    sw.PrintName = variantInfo.printName
                    sw.Author = "SSRP"
                    sw.Instructions = "Компактный служебный пистолет"
                    sw.Category = "SSRP | Оружейная мастерская"
                    sw.Spawnable = false
                    sw.AdminOnly = true
                    weapons.Register(sw, variantInfo.class)
                end
            end
        end)
    end)
end
