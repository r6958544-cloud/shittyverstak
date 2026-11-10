NYUI = NYUI or {}
if not NYUI.BahnschriftFontLoaded then
    surface.CreateFont("NYUI.Title", {font = "Bahnschrift", size = 24, weight = 700, antialias = true, extended = true})
    surface.CreateFont("NYUI.Body", {font = "Bahnschrift", size = 16, weight = 500, antialias = true, extended = true})
    surface.CreateFont("NYUI.Small", {font = "Bahnschrift", size = 13, weight = 500, antialias = true, extended = true})
    surface.CreateFont("NYUI.Icon", {font = "Bahnschrift", size = 20, weight = 700, antialias = true, extended = true})
    NYUI.BahnschriftFontLoaded = true
end

local shopItems = {}
local workbenchParts = {}
local personalParts = {}
local ownedBlueprints = {}
local shopFrame
local blueprintFrame
local craftFrame
local partsFrame
local OpenPartsFrame
local craftTask
local craftSessionID
local craftStep
local craftToken
local craftReadyAt = 0
local craftProcessing = false
local craftStatusLabel
local craftCancelButton
local craftProcessingEnd = 0
local craftProcessingDuration = 0
local partsScrollOffsets = {}
local workbenchOutputs = {}
local outputFrame

surface.CreateFont("SSRP_Craft_Title", {
    font = "Bahnschrift",
    size = 22,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("SSRP_Craft_Label", {
    font = "Bahnschrift",
    size = 16,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("SSRP_Craft_Item", {
    font = "Bahnschrift",
    size = 18,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("SSRP_Craft_Big", {
    font = "Bahnschrift",
    size = 31,
    weight = 700,
    antialias = true,
    extended = true
})

surface.CreateFont("SSRP_Craft_Tiny", {
    font = "Bahnschrift",
    size = 16,
    weight = 400,
    antialias = true,
    extended = true
})

surface.CreateFont("SSRP_Money_Value", {
    font = "Bahnschrift",
    size = 20,
    weight = 700,
    antialias = true,
    extended = true
})

local function PaintBlack(panel, width, height)
    draw.RoundedBox(15, 0, 0, width, height, Color(77, 65, 43, 255))
    draw.RoundedBox(13, 2, 2, width - 4, height - 4, Color(15, 19, 24, 250))
end

local function MakeFrame(title, width, height)
    local frame = vgui.Create("DFrame")
    width = math.min(width, math.max(360, ScrW() - 32))
    height = math.min(height, math.max(300, ScrH() - 32))
    frame:SetSize(width, height)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        PaintBlack(self, w, h)
        draw.RoundedBoxEx(13, 2, 2, w - 4, 62, Color(24, 30, 38, 255), true, true, false, false)
        surface.SetDrawColor(218, 174, 86, 115)
        surface.DrawRect(24, 60, w - 48, 1)
    end

    local close = vgui.Create("DButton", frame)
    close:SetSize(36, 30)
    close:SetPos(frame:GetWide() - 48, 10)
    close:SetText("×")
    close:SetFont("SSRP_Craft_Title")
    close:SetTextColor(Color(180, 180, 185))
    close.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(55, 55, 60))
        end
    end
    close.DoClick = function()
        frame:Close()
    end

    local label = vgui.Create("DLabel", frame)
    label:SetPos(24, 13)
    label:SetSize(width - 96, 34)
    label:SetFont("SSRP_Craft_Title")
    label:SetText(title)
    label:SetTextColor(Color(242, 242, 245))

    return frame
end

local function CreateIcon(parent, iconPath, className)
    local class = string.lower(tostring(className or ""))
    if string.sub(class, 1, 10) == "ssrp_ammo_" then
        local cartridge = vgui.Create("DPanel", parent)
        cartridge:SetSize(68, 68)
        cartridge:Dock(LEFT)
        cartridge:DockMargin(8, 5, 10, 5)
        cartridge:SetMouseInputEnabled(false)
        cartridge:SetTooltip("Снаряжённый патрон")
        cartridge.Paint = function(self, w, h)
            local x, y = (w - 24) * 0.5, (h - 48) * 0.5
            -- Пуля и латунная гильза на прозрачном фоне.
            draw.NoTexture()
            surface.SetDrawColor(193, 128, 57, 255)
            surface.DrawPoly({{x=x+12,y=y},{x=x+19,y=y+11},{x=x+19,y=y+31},{x=x+5,y=y+31},{x=x+5,y=y+11}})
            draw.RoundedBoxEx(3, x + 5, y + 25, 14, 22, Color(198, 151, 76), false, false, true, true)
            draw.RoundedBox(2, x + 3, y + 43, 18, 4, Color(127, 91, 54))
            surface.SetDrawColor(240, 205, 130, 210)
            surface.DrawLine(x + 7, y + 30, x + 17, y + 30)
            surface.DrawLine(x + 7, y + 40, x + 17, y + 40)
        end
        return cartridge
    end

    -- Используем изображения самих SWEP Z-City. Они уже подготовлены для HUD:
    -- DImage рисует альфа-канал материала, поэтому фон и чужие силуэты не добавляются.
    local image = vgui.Create("DImage", parent)
    image:SetSize(68, 68)
    image:Dock(LEFT)
    image:DockMargin(8, 5, 10, 5)
    image:SetMouseInputEnabled(false)
    image:SetKeepAspect(true)

    local weapon = weapons.GetStored(tostring(className or ""))
    local material = weapon and (weapon.WepSelectIcon2 or weapon.WepSelectIcon)
    if material and isfunction(material.GetName) and material:GetName() ~= "" then
        image:SetMaterial(material)
    elseif weapon and isstring(weapon.IconOverride) and weapon.IconOverride ~= "" then
        image:SetImage(weapon.IconOverride)
    elseif isstring(iconPath) and iconPath ~= "" then
        local path = iconPath
        if not string.EndsWith(string.lower(path), ".png") then path = path .. ".png" end
        image:SetImage(path)
    end

    return image
end

local function CreateShopRow(parent, item)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 8)
    row:SetTall(78)
    CreateIcon(row, item.icon, item.class)

    row.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, self:IsHovered() and Color(31, 38, 46) or Color(23, 29, 36))
        draw.RoundedBox(2, 0, 12, 3, h - 24, Color(218, 174, 86, 170))
        draw.SimpleText(item.name, "SSRP_Craft_Item", 88, 27, Color(235, 235, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(item.recipe or "Чертёж и список деталей", "SSRP_Craft_Tiny", 88, 52, Color(164, 172, 181), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    row:SetTooltip(item.name .. "\n" .. (item.recipe or "") .. "\nЧертёж бесплатный; материалы списываются со склада.")

    local buy = vgui.Create("DButton", row)
    buy:Dock(RIGHT)
    buy:DockMargin(0, 17, 12, 17)
    buy:SetWide(145)
    buy:SetText(item.unlocked and "ИЗУЧЕНО" or "ИЗУЧИТЬ")
    buy:SetFont("SSRP_Craft_Label")
    buy:SetTextColor(Color(235, 235, 238))
    buy.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h,
            item.unlocked and Color(46, 67, 54) or (self:IsHovered() and Color(231, 196, 119) or Color(186, 145, 68)))
    end
    buy:SetEnabled(not item.unlocked)
    buy.DoClick = function()
        net.Start("SSRP_Crafting_ShopAction")
            net.WriteString(item.class)
        net.SendToServer()
    end
end

local function RequestParts(inventoryOnly)
    net.Start("SSRP_Crafting_PartsRequest")
        net.WriteUInt(inventoryOnly == true and 1 or 2, 2)
    net.SendToServer()
    if IsValid(shopFrame) then shopFrame:Close() end
end

local function RequestWorkbenchOutputs()
    net.Start("SSRP_Crafting_OutputsRequest")
    net.SendToServer()
end

local function OpenShop()
    if IsValid(shopFrame) then shopFrame:Remove() end

    shopFrame = MakeFrame("ОРУЖЕЙНАЯ МАСТЕРСКАЯ", 1360, 800)
    local frame = shopFrame

    local subtitle = vgui.Create("DLabel", frame)
    subtitle:SetPos(24, 36)
    subtitle:SetSize(frame:GetWide() - 48, 22)
    subtitle:SetFont("SSRP_Craft_Label")
    subtitle:SetText("РЕЦЕПТЫ  /  СКЛАД ВЕРСТАКА  /  ВАШ ИНВЕНТАРЬ")
    subtitle:SetTextColor(Color(196, 202, 210))

    local actions = vgui.Create("DPanel", frame)
    actions:SetPos(18, 67)
    actions:SetSize(frame:GetWide() - 36, 38)
    actions:SetTall(38)
    actions.Paint = function() end

    local function addAction(text, width, callback)
        local button = vgui.Create("DButton", actions)
        button:Dock(RIGHT)
        button:DockMargin(8, 2, 0, 2)
        button:SetWide(width)
        button:SetText(text)
        button:SetFont("SSRP_Craft_Tiny")
        button:SetTextColor(Color(250, 239, 216))
        button.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
        end
        button.DoClick = callback
    end

    addAction("ГОТОВЫЕ ЗАКАЗЫ", 150, RequestWorkbenchOutputs)
    addAction("ЗАБРАТЬ СО СКЛАДА", 150, function()
        net.Start("SSRP_Crafting_TransferAllParts")
            net.WriteUInt(1, 1)
        net.SendToServer()
    end)
    addAction("ЗАГРУЗИТЬ ВСЁ", 130, function()
        net.Start("SSRP_Crafting_TransferAllParts")
            net.WriteUInt(0, 1)
        net.SendToServer()
    end)

    local body = vgui.Create("DPanel", frame)
    body:SetPos(18, 114)
    body:SetSize(frame:GetWide() - 36, frame:GetTall() - 132)
    body.Paint = function() end

    local function makeColumn(title, fraction, dock)
        local panel = vgui.Create("DPanel", body)
        panel:Dock(dock or LEFT)
        panel:DockMargin(0, 0, 10, 0)
        panel:SetWide(math.floor((body:GetWide() > 0 and body:GetWide() or frame:GetWide() - 48) * fraction))
        panel.Paint = function(self, w, h)
            draw.RoundedBox(9, 0, 0, w, h, Color(14, 18, 23, 245))
            surface.SetDrawColor(218, 174, 86, 105)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local heading = vgui.Create("DLabel", panel)
        heading:Dock(TOP)
        heading:DockMargin(14, 8, 10, 2)
        heading:SetTall(30)
        heading:SetFont("SSRP_Craft_Item")
        heading:SetText(title)
        heading:SetTextColor(Color(241, 226, 197))
        local list = vgui.Create("DScrollPanel", panel)
        list:Dock(FILL)
        list:DockMargin(8, 2, 8, 10)
        local bar = list:GetVBar()
        bar:SetWide(4)
        bar.Paint = function() end
        bar.btnUp.Paint = function() end
        bar.btnDown.Paint = function() end
        bar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(186, 145, 68)) end
        return panel, list
    end

    local recipeColumn, recipeList = makeColumn("РЕЦЕПТЫ КРАФТА", 0.39)
    local stockColumn, stockList = makeColumn("СКЛАД ВЕРСТАКА", 0.30)
    stockColumn:DockMargin(0, 0, 10, 0)
    local personalColumn, personalList = makeColumn("ВАШ ИНВЕНТАРЬ", 0.30)
    personalColumn:DockMargin(0, 0, 0, 0)
    body.PerformLayout = function(self, w, h)
        local gap = 10
        local available = w - gap * 2
        local leftWidth = math.floor(available * 0.39)
        local middleWidth = math.floor(available * 0.30)
        recipeColumn:SetWide(leftWidth)
        stockColumn:SetWide(middleWidth)
        personalColumn:SetWide(available - leftWidth - middleWidth)
    end

    local function paintRow(row, accent)
        row.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, self:IsHovered() and Color(30, 37, 45) or Color(22, 28, 35))
            draw.RoundedBox(2, 0, 8, 3, h - 16, accent or Color(218, 174, 86, 170))
        end
    end

    for _, data in ipairs(shopItems) do
        local item = data
        local row = vgui.Create("DPanel", recipeList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(68)
        paintRow(row)
        local name = vgui.Create("DLabel", row)
        name:SetPos(12, 8)
        name:SetSize(270, 24)
        name:SetFont("SSRP_Craft_Item")
        name:SetText(item.name)
        name:SetTextColor(Color(239, 239, 241))
        local recipe = vgui.Create("DLabel", row)
        recipe:SetPos(12, 34)
        recipe:SetSize(270, 27)
        recipe:SetFont("SSRP_Craft_Tiny")
        recipe:SetText(item.recipe or "Состав по рецепту")
        recipe:SetTextColor(Color(164, 172, 181))
        row.PerformLayout = function(self, w)
            local labelWidth = math.max(100, w - 124)
            name:SetSize(labelWidth, 24)
            recipe:SetSize(labelWidth, 27)
        end
        local action = vgui.Create("DButton", row)
        action:Dock(RIGHT)
        action:DockMargin(5, 16, 8, 16)
        action:SetWide(92)
        action:SetText(item.unlocked and "СОБРАТЬ" or "ИЗУЧИТЬ")
        action:SetFont("SSRP_Craft_Tiny")
        action:SetTextColor(Color(250, 239, 216))
        action.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
        end
        action.DoClick = function()
            if item.unlocked then
                net.Start("SSRP_Crafting_Start")
                    net.WriteString(item.class)
                net.SendToServer()
            else
                net.Start("SSRP_Crafting_ShopAction")
                    net.WriteString(item.class)
                net.SendToServer()
            end
        end
    end

    local function addInventoryRows(list, inventory, direction)
        local visible = 0
        for _, item in ipairs(inventory) do
            if item.amount > 0 then
                visible = visible + 1
                local row = vgui.Create("DPanel", list)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 6)
                row:SetTall(58)
                paintRow(row, direction == 0 and Color(75, 150, 225, 210) or Color(235, 170, 58, 210))
                local name = vgui.Create("DLabel", row)
                name:SetPos(12, 7)
                name:SetSize(225, 22)
                name:SetFont("SSRP_Craft_Label")
                name:SetText(item.name)
                name:SetTextColor(Color(235, 235, 238))
                local count = vgui.Create("DLabel", row)
                count:SetPos(12, 30)
                count:SetSize(220, 20)
                count:SetFont("SSRP_Craft_Tiny")
                count:SetText("Количество: " .. item.amount)
                count:SetTextColor(Color(175, 184, 192))
                local move = vgui.Create("DButton", row)
                move:Dock(RIGHT)
                move:DockMargin(4, 14, 7, 14)
                move:SetWide(48)
                move:SetText(direction == 0 and "←" or "→")
                move:SetFont("SSRP_Craft_Item")
                move:SetTextColor(Color(250, 239, 216))
                move:SetTooltip(direction == 0 and "Загрузить на верстак" or "Забрать в личный запас")
                move.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
                end
                move.DoClick = function()
                    net.Start("SSRP_Crafting_TransferPart")
                        net.WriteString(item.id)
                        net.WriteUInt(direction, 1)
                    net.SendToServer()
                end
            end
        end
        if visible == 0 then
            local empty = vgui.Create("DLabel", list)
            empty:Dock(TOP)
            empty:DockMargin(8, 24, 8, 0)
            empty:SetTall(60)
            empty:SetFont("SSRP_Craft_Label")
            empty:SetText(direction == 0 and "На складе пока пусто" or "Личный запас пуст")
            empty:SetTextColor(Color(133, 142, 151))
            empty:SetContentAlignment(5)
        end
    end

    addInventoryRows(stockList, workbenchParts, 1)
    addInventoryRows(personalList, personalParts, 0)
end

local function OpenWorkbenchOutputs()
    if IsValid(outputFrame) then outputFrame:Remove() end
    if IsValid(partsFrame) then partsFrame:Close() end
    if IsValid(shopFrame) then shopFrame:SetVisible(false) end
    if IsValid(blueprintFrame) then blueprintFrame:Close() end
    outputFrame = MakeFrame("ПОЛКА ГОТОВЫХ ЗАКАЗОВ", 780, 540)
    local frame = outputFrame
    frame.OnClose = function()
        if IsValid(shopFrame) then
            shopFrame:SetVisible(true)
            shopFrame:MakePopup()
        end
    end
    local returnButton = vgui.Create("DButton", frame)
    returnButton:SetPos(frame:GetWide() - 220, 17)
    returnButton:SetSize(155, 30)
    returnButton:SetText("К ВЕРСТАКУ")
    returnButton:SetFont("SSRP_Craft_Tiny")
    returnButton:SetTextColor(Color(250, 239, 216))
    returnButton.Paint = function(self, w, h)
        draw.RoundedBox(7, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
    end
    returnButton.DoClick = function() frame:Close() end
    local subtitle = vgui.Create("DLabel", frame)
    subtitle:Dock(TOP)
    subtitle:DockMargin(25, 0, 60, 12)
    subtitle:SetTall(24)
    subtitle:SetFont("SSRP_Craft_Label")
    subtitle:SetText("Заказ появляется здесь после сборки. Забрать его может только создатель.")
    subtitle:SetTextColor(Color(169, 176, 184))

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(18, 0, 18, 18)
    local bar = scroll:GetVBar()
    bar:SetWide(5)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(186, 145, 68)) end

    if #workbenchOutputs == 0 then
        local empty = vgui.Create("DLabel", scroll)
        empty:Dock(TOP)
        empty:SetTall(76)
        empty:SetFont("SSRP_Craft_Label")
        empty:SetText("Полка пока пуста. Закончи сборку, чтобы оставить здесь готовый заказ.")
        empty:SetTextColor(Color(158, 165, 173))
        empty:SetContentAlignment(5)
        return
    end

    for _, output in ipairs(workbenchOutputs) do
        local item = output
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetTall(78)
        CreateIcon(row, "", item.class)
        row.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(23, 29, 36))
            draw.RoundedBox(2, 0, 12, 3, h - 24, Color(218, 174, 86, 170))
            draw.SimpleText(item.name, "SSRP_Craft_Item", 88, 27, Color(235, 235, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Заказ: " .. item.owner, "SSRP_Craft_Tiny", 88, 52, Color(164, 172, 181), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local claim = vgui.Create("DButton", row)
        claim:Dock(RIGHT)
        claim:DockMargin(8, 20, 12, 20)
        claim:SetWide(145)
        claim:SetFont("SSRP_Craft_Label")
        claim:SetTextColor(Color(244, 235, 215))
        claim.Paint = function(self, w, h)
            local fill = not item.canClaim and Color(47, 51, 56) or (self:IsEnabled() and self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
            draw.RoundedBox(7, 0, 0, w, h, fill)
        end
        claim.Think = function(self)
            if not item.canClaim then self:SetText("ЧУЖОЙ ЗАКАЗ") self:SetEnabled(false) return end
            local seconds = math.ceil(item.readyAt - CurTime())
            if seconds > 0 then self:SetText("СБОРКА · " .. seconds .. " СЕК") self:SetEnabled(false)
            else self:SetText(item.kind == "attachment" and "УСТАНОВИТЬ" or "ЗАБРАТЬ") self:SetEnabled(true) end
        end
        claim.DoClick = function()
            net.Start("SSRP_Crafting_OutputClaim")
                net.WriteUInt(item.id, 32)
            net.SendToServer()
        end
    end
end

OpenPartsFrame = function(mode, items)
    if IsValid(partsFrame) then
        local oldMode = partsFrame.SSRP_Mode
        local oldScroll = partsFrame.SSRP_Scroll
        if oldMode ~= nil and IsValid(oldScroll) then partsScrollOffsets[oldMode] = oldScroll:GetVBar():GetScroll() end
        partsFrame:Remove()
    end
    local title = mode == 0 and "ПОСТАВЩИК ДЕТАЛЕЙ" or (mode == 1 and "ИНВЕНТАРЬ ВЕРСТАКА" or "ЛИЧНЫЙ ИНВЕНТАРЬ")
    partsFrame = MakeFrame(title, 920, 650)
    partsFrame.SSRP_Mode = mode

    local subtitle = vgui.Create("DLabel", partsFrame)
    subtitle:SetPos(25, 66)
    subtitle:SetSize(partsFrame:GetWide() - 50, 24)
    subtitle:SetFont("SSRP_Craft_Label")
    subtitle:SetText(mode == 0 and "Выберите детали и количество. Покупки попадут в личный запас; патроны собираются из гильзы, пороха, пули и капсюля." or
        (mode == 1 and "Общий запас мастерской. Верстак сам спишет компоненты, нужные для выбранного чертежа." or "Твои детали. Загрузи весь запас на верстак одним нажатием."))
    subtitle:SetTextColor(Color(169, 176, 184))

    local searchBox
    if mode == 0 then
        searchBox = vgui.Create("DTextEntry", partsFrame)
        searchBox:SetPos(18, 96)
        searchBox:SetSize(partsFrame:GetWide() - 36, 36)
        searchBox:SetTall(34)
        searchBox:SetFont("SSRP_Craft_Label")
        searchBox:SetPlaceholderText("Поиск детали: гильза, ствол, пружина…")
        searchBox:SetUpdateOnType(true)
        searchBox.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(24, 29, 35))
            surface.SetDrawColor(218, 174, 86, 80)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self:DrawTextEntryText(Color(235, 235, 238), Color(218, 174, 86), Color(235, 235, 238))
        end
    end

    if mode == 1 or mode == 2 then
        local transfer = vgui.Create("DButton", partsFrame)
        transfer:SetPos(partsFrame:GetWide() - 248, 17)
        transfer:SetSize(230, 32)
        transfer:SetText(mode == 1 and "ЗАБРАТЬ ВЕСЬ ЗАПАС" or "ЗАГРУЗИТЬ ВЕСЬ ЗАПАС")
        transfer:SetFont("SSRP_Craft_Label")
        transfer:SetTextColor(Color(250, 239, 216))
        transfer.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
        end
        transfer.DoClick = function()
            net.Start("SSRP_Crafting_TransferAllParts")
                net.WriteUInt(mode == 2 and 0 or 1, 1)
            net.SendToServer()
        end
    end

    local scroll = vgui.Create("DScrollPanel", partsFrame)
    partsFrame.SSRP_Scroll = scroll
    scroll:SetPos(18, mode == 0 and 142 or 98)
    scroll:SetSize(partsFrame:GetWide() - 36, partsFrame:GetTall() - (mode == 0 and 160 or 116))
    local bar = scroll:GetVBar()
    bar:SetWide(5)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(186, 145, 68)) end
    timer.Simple(0.1, function()
        if IsValid(scroll) then scroll:GetVBar():SetScroll(partsScrollOffsets[mode] or 0) end
    end)

    local partCodes = {
        steel = "ST", spring = "SP", receiver = "FR", barrel = "BR", polymer = "PL",
        wood = "WD", fastener = "PIN", trigger = "TR", slide = "SL", magazine = "MAG",
        sights = "SIG", cylinder = "CYL", bolt = "BLT", pump = "PMP",
        brass_case = "BRASS", gunpowder = "POW", bullet = "BUL", primer = "CAP",
        optic_glass = "GLASS", optic_body = "OPT", carbon = "CMP", tube = "TUBE", rubber = "RUB"
    }

    if mode == 0 then
        local vendorRows = {}
        for _, item in ipairs(items or {}) do
            local rowItem = item
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(100)
            row:SetTooltip(rowItem.name .. "\n" .. (rowItem.detail or "") .. "\nЦена: $" .. rowItem.price .. " за штуку.")
            row.Paint = function(self, w, h)
                draw.RoundedBox(10, 0, 0, w, h, self:IsHovered() and Color(31, 38, 46) or Color(23, 29, 36))
                draw.RoundedBox(2, 0, 12, 3, h - 24, Color(218, 174, 86, 170))
                draw.RoundedBox(10, 15, 21, 48, 48, Color(54, 48, 38))
                surface.SetDrawColor(218, 174, 86, 105)
                surface.DrawOutlinedRect(15, 21, 48, 48, 1)
                draw.SimpleText(partCodes[rowItem.id] or "PT", "SSRP_Craft_Tiny", 39, 45, Color(235, 197, 118), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                local textWidth = math.max(120, w - 370)
                draw.SimpleText(rowItem.name, "SSRP_Craft_Item", 76, 27, Color(245, 246, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, textWidth)
                draw.SimpleText(rowItem.detail or "Оружейный компонент", "SSRP_Craft_Tiny", 76, 53, Color(192, 199, 207), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, textWidth)
                draw.SimpleText("У вас: " .. tostring(rowItem.amount) .. "    Цена: $" .. string.Comma(rowItem.price) .. " за штуку", "SSRP_Craft_Tiny", 76, 79, Color(223, 225, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, textWidth)
            end
            for _, amount in ipairs({10, 5, 1}) do
                local button = vgui.Create("DButton", row)
                button:Dock(RIGHT)
                button:DockMargin(5, 28, 8, 28)
                button:SetWide(82)
                button:SetText("×" .. amount .. "  $" .. string.Comma(rowItem.price * amount))
                button:SetTooltip("Купить " .. amount .. " шт. за $" .. (rowItem.price * amount))
                button:SetFont("SSRP_Craft_Label")
                button:SetTextColor(Color(244, 235, 215))
                button.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(231, 196, 119) or Color(126, 96, 48))
                end
                button:SetEnabled(true)
                button.DoClick = function()
                    net.Start("SSRP_Crafting_PartsPurchase")
                        net.WriteString(rowItem.id)
                        net.WriteUInt(amount, 4)
                    net.SendToServer()
                end
            end
            vendorRows[#vendorRows + 1] = {panel = row, item = rowItem}
        end
        if IsValid(searchBox) then
            searchBox.OnValueChange = function(self, value)
                local needle = string.Trim(string.lower(value or ""))
                for _, entry in ipairs(vendorRows) do
                    local haystack = string.lower(entry.item.name .. " " .. (entry.item.detail or "") .. " " .. entry.item.id)
                    entry.panel:SetVisible(needle == "" or string.find(haystack, needle, 1, true) ~= nil)
                end
                if IsValid(scroll) then scroll:GetCanvas():InvalidateLayout(true) end
            end
        end
    else
        local grid = vgui.Create("DGrid", scroll)
        grid:Dock(TOP)
        grid:SetCols(2)
        grid:SetColWide(360)
        grid:SetRowHeight(90)
        for _, item in ipairs(items or {}) do
            local cardItem = item
            local card = vgui.Create("DPanel")
            card:SetSize(350, 78)
            card.Paint = function(self, w, h)
                draw.RoundedBox(9, 0, 0, w, h, Color(23, 29, 36))
                draw.RoundedBox(2, 0, 12, 3, h - 24, Color(218, 174, 86, 170))
                draw.RoundedBox(9, 12, 15, 48, 48, Color(54, 48, 38))
                surface.SetDrawColor(218, 174, 86, 105)
                surface.DrawOutlinedRect(12, 15, 48, 48, 1)
                draw.SimpleText(partCodes[cardItem.id] or "PT", "SSRP_Craft_Tiny", 36, 39, Color(235, 197, 118), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(cardItem.name, "SSRP_Craft_Item", 72, 28, Color(235, 235, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Количество: " .. tostring(cardItem.amount), "SSRP_Craft_Tiny", 72, 51, Color(190, 197, 203), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            grid:AddItem(card)
        end
    end
end

local function CreateBlueprintRow(parent, item)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 8)
    row:SetTall(78)
    CreateIcon(row, item.icon, item.class)

    row.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, self:IsHovered() and Color(31, 38, 46) or Color(23, 29, 36))
        draw.RoundedBox(2, 0, 12, 3, h - 24, Color(218, 174, 86, 170))
        draw.SimpleText(item.name .. "  •  Чертёж изучен", "SSRP_Craft_Item", 88, 27, Color(235, 235, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(item.recipe or "", "SSRP_Craft_Tiny", 88, 52, Color(164, 172, 181), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local craft = vgui.Create("DButton", row)
    craft:Dock(RIGHT)
    craft:DockMargin(0, 17, 12, 17)
    craft:SetWide(120)
    craft:SetText("СОБРАТЬ")
    craft:SetFont("SSRP_Craft_Label")
    craft:SetTextColor(Color(235, 235, 238))
    craft.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h,
            self:IsHovered() and Color(231, 196, 119) or Color(186, 145, 68))
    end
    craft.DoClick = function()
        net.Start("SSRP_Crafting_Start")
            net.WriteString(item.class)
        net.SendToServer()
    end
end

local function OpenBlueprints()
    if IsValid(blueprintFrame) then blueprintFrame:Remove() end

    blueprintFrame = MakeFrame("МОИ ЧЕРТЕЖИ", 700, 520)

    local subtitle = vgui.Create("DLabel", blueprintFrame)
    subtitle:Dock(TOP)
    subtitle:DockMargin(25, 0, 60, 12)
    subtitle:SetTall(20)
    subtitle:SetFont("SSRP_Craft_Label")
    subtitle:SetText("Сначала изучи чертёж в каталоге, купи детали у поставщика и загрузи их на верстак. Затем собирай здесь.")
    subtitle:SetTextColor(Color(169, 176, 184))

    local scroll = vgui.Create("DScrollPanel", blueprintFrame)
    scroll:Dock(FILL)
    scroll:DockMargin(18, 0, 18, 18)

    if #ownedBlueprints == 0 then
        local empty = vgui.Create("DLabel", scroll)
        empty:Dock(TOP)
        empty:SetTall(60)
        empty:SetFont("SSRP_Craft_Label")
        empty:SetText("У тебя пока нет чертежей")
        empty:SetTextColor(Color(100, 100, 105))
        empty:SetContentAlignment(5)
    else
        for _, item in ipairs(ownedBlueprints) do
            CreateBlueprintRow(scroll, item)
        end
    end
end

local function SendStep(answer, a, b, c)
    if not craftTask or craftProcessing then return end
    net.Start("SSRP_Crafting_StepV2")
        net.WriteUInt(craftSessionID, 32)
        net.WriteUInt(craftStep, 4)
        net.WriteUInt(craftToken, 32)
        net.WriteString(tostring(answer or ""))
        net.WriteFloat(tonumber(a) or 0)
        net.WriteFloat(tonumber(b) or 0)
        net.WriteFloat(tonumber(c) or 0)
    net.SendToServer()
end

local function CancelCrafting()
    net.Start("SSRP_Crafting_Cancel")
    net.SendToServer()

    if IsValid(craftFrame) then
        craftFrame:Close()
    end
end

local function AddTaskButton(parent, text, callback)
    local button = vgui.Create("DButton", parent)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 8)
    button:SetTall(42)
    button:SetText(text)
    button:SetMouseInputEnabled(true)
    button:SetFont("SSRP_Craft_Label")
    button:SetTextColor(Color(235, 235, 238))
    button.Paint = function(self, w, h)
        draw.RoundedBox(9, 0, 0, w, h,
            self:IsHovered() and Color(65, 65, 70) or Color(37, 37, 41))
    end
    button.DoClick = callback
    return button
end

local function BuildTaskContent(parent, task)
    local info = vgui.Create("DLabel", parent)
    info:Dock(TOP)
    info:SetTall(56)
    info:SetWrap(true)
    info:SetAutoStretchVertical(true)
    info:SetFont("SSRP_Craft_Label")
    local instruction = task.text
    if task.type == 1 then
        instruction = "ПОДГОНКА СПУСКА · Нажми клавишу " .. math.floor(task.a) .. " — " .. math.floor(task.b) .. " раз"
    elseif task.type == 2 then
        instruction = "МАРКИРОВКА · Вбей серийный номер механизма без ошибок"
    elseif task.type == 3 then
        instruction = "ФИКСИРУЮЩИЙ ШТИФТ · Выбери метку " .. ({"●", "◆", "■", "▲"})[math.floor(task.a)] .. " — " .. math.floor(task.b) .. " раз"
    elseif task.type == 4 then
        instruction = "ФИНИШНАЯ ОБРАБОТКА · Повтори траекторию: " .. task.text
    elseif task.type == 5 then
        instruction = "КОМПОНОВКА УЗЛОВ · Расставь четыре детали по своим местам"
    elseif task.type == 6 then
        instruction = "НАСТРОЙКА ПРИЦЕЛА · Выставь угол " .. math.floor(task.a) .. "° и зафиксируй его " .. math.floor(task.b) .. " раза"
    elseif task.type == 7 then
        instruction = "ЦЕНТРОВКА МУШКИ · Перетащи деталь в контрольную зону трижды"
    elseif task.type == 8 then
        instruction = "ВОЗВРАТНЫЙ МЕХАНИЗМ · Повтори порядок деталей: " .. task.text
    elseif task.type == 9 then
        instruction = "КРЕПЁЖ · Затяни " .. math.floor(task.a) .. " винтов до упора"
    elseif task.type == 10 then
        instruction = "ПРИЁМОЧНАЯ ПРОВЕРКА · Введи контрольный код: " .. task.text
    end

    info:SetText(instruction)
    info:SetTextColor(Color(190, 190, 198))
    info:SetContentAlignment(5)

    if task.type == 1 then
        local current = 0
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(34)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("0 / " .. math.floor(task.b))
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        local keyGrid = vgui.Create("DPanel", parent)
        keyGrid:Dock(TOP)
        keyGrid:SetTall(142)
        keyGrid.Paint = function() end
        for i = 1, 9 do
            local keyNumber = i
            local button = vgui.Create("DButton", keyGrid)
            button:SetSize(52, 38)
            button:SetPos(0, 0)
            button.Think = function(self)
                local totalWidth = 3 * 52 + 2 * 8
                local left = math.max(0, (keyGrid:GetWide() - totalWidth) * 0.5)
                self:SetPos(left + ((keyNumber - 1) % 3) * 60, 8 + math.floor((keyNumber - 1) / 3) * 44)
            end
            button:SetText(tostring(keyNumber))
            button:SetMouseInputEnabled(true)
            button:SetFont("SSRP_Craft_Label")
            button:SetTextColor(Color(235, 235, 238))
            button.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(37, 37, 41))
            end
            button.DoClick = function()
                if keyNumber == math.floor(task.a) then
                    current = math.min(current + 1, math.floor(task.b))
                else
                    current = 0
                end

                progress:SetText(current .. " / " .. math.floor(task.b))

                if current >= math.floor(task.b) then
                    SendStep(task.a, current)
                end
            end
        end
    elseif task.type == 2 then
        local sequence = vgui.Create("DLabel", parent)
        sequence:Dock(TOP)
        sequence:SetTall(65)
        sequence:SetFont("SSRP_Craft_Big")
        sequence:SetText(task.text)
        sequence:SetTextColor(Color(245, 245, 245))
        sequence:SetContentAlignment(5)

        local entry = vgui.Create("DTextEntry", parent)
        entry:Dock(TOP)
        entry:DockMargin(100, 0, 100, 8)
        entry:SetTall(36)
        entry:SetFont("SSRP_Craft_Item")
        entry:SetTextColor(Color(235, 235, 238))
        entry:SetPlaceholderText("Введи последовательность")

        AddTaskButton(parent, "ПРОВЕРИТЬ", function()
            SendStep(entry:GetValue())
        end)
    elseif task.type == 3 then
        local symbols = {"●", "◆", "■", "▲"}
        local current = 0
        local required = math.floor(task.b)
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(34)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("0 / " .. required)
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        for i, symbol in ipairs(symbols) do
            local symbolIndex = i
            local button = vgui.Create("DButton", parent)
            button:SetTall(36)
            button:SetWide(110)
            button:DockMargin(6, 3, 6, 3)
            button:SetText(symbol)
            button:SetFont("SSRP_Craft_Item")
            button:SetTextColor(Color(235, 235, 238))
            button.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(65, 65, 70) or Color(37, 37, 41))
            end
            button.Think = function(self)
                local col = (symbolIndex - 1) % 2
                local row = math.floor((symbolIndex - 1) / 2)
                self:SetPos(parent:GetWide() * 0.5 - 116 + col * 122, 96 + row * 44)
            end
            button.DoClick = function()
                if symbolIndex == math.floor(task.a) then
                    current = math.min(current + 1, required)
                else
                    current = 0
                end

                progress:SetText(current .. " / " .. required)

                if current >= required then
                    SendStep(task.a, current)
                end
            end
        end
    elseif task.type == 4 then
        local current = ""
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(38)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("—")
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        local function press(key)
            current = current .. key
            progress:SetText(current)
            if #current >= #task.text then
                SendStep(current)
            end
        end

        for i, key in ipairs({"W", "A", "S", "D"}) do
            local directionKey = key
            local buttonIndex = i
            local button = vgui.Create("DButton", parent)
            button:SetTall(36)
            button:SetWide(110)
            button:SetText(directionKey)
            button:SetFont("SSRP_Craft_Item")
            button:SetTextColor(Color(235, 235, 238))
            button.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(65, 65, 70) or Color(37, 37, 41))
            end
            button.Think = function(self)
                local col = (buttonIndex - 1) % 2
                local row = math.floor((buttonIndex - 1) / 2)
                self:SetPos(parent:GetWide() * 0.5 - 116 + col * 122, 98 + row * 44)
            end
            button.DoClick = function() press(directionKey) end
        end
    elseif task.type == 5 then
        local area = vgui.Create("DPanel", parent)
        area:Dock(TOP)
        area:DockMargin(35, 15, 35, 10)
        area:SetTall(180)

        local placed = {}
        local dragging = nil
        local pieceColors = {
            Color(210, 85, 85),
            Color(85, 150, 220),
            Color(220, 175, 70),
            Color(150, 95, 205)
        }

        local function getTargetPosition(index)
            local spacing = area:GetWide() / 5
            return spacing * index - 23, 48
        end

        local startPositions = {0.16, 0.38, 0.60, 0.82}
        local function getStartPosition(index)
            return area:GetWide() * startPositions[index] - 23, area:GetTall() - 52
        end

        area.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(18, 18, 21))
            draw.SimpleText("ПЕРЕТАЩИ ДЕТАЛИ В ПРАВИЛЬНЫЕ МЕСТА", "SSRP_Craft_Tiny", w * 0.5, 15, Color(175, 175, 182), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local spacing = w / 5
            for i = 1, 4 do
                local targetX = spacing * i - 23
                local targetColor = placed[i] and Color(70, 175, 100) or Color(55, 55, 62)
                draw.RoundedBox(8, targetX, 48, 46, 46, targetColor)
                draw.SimpleText("МЕСТО " .. i, "SSRP_Craft_Tiny", targetX + 23, 101, Color(145, 145, 152), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end

        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(30)
        progress:SetFont("SSRP_Craft_Label")
        progress:SetText("Деталей собрано: 0 / 4")
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        for i = 1, 4 do
            local pieceIndex = i
            local piece = vgui.Create("DButton", area)
            piece:SetSize(46, 46)
            piece:SetText(tostring(pieceIndex))
            piece:SetFont("SSRP_Craft_Big")
            piece:SetTextColor(Color(245, 245, 248))
            piece:SetCursor("hand")
            piece.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, pieceColors[pieceIndex])
                draw.SimpleText("ДЕТАЛЬ", "SSRP_Craft_Tiny", w * 0.5, h + 3, Color(180, 180, 188), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            local function resetPiece()
                local x, y = getStartPosition(pieceIndex)
                piece:SetPos(x, y)
            end

            resetPiece()

            piece.OnMousePressed = function(self)
                if placed[pieceIndex] then return true end
                dragging = self
                self:MouseCapture(true)
                return true
            end

            piece.Think = function(self)
                if dragging ~= self then return end
                local x, y = area:ScreenToLocal(gui.MouseX(), gui.MouseY())
                self:SetPos(math.Clamp(x - 23, 0, area:GetWide() - 46), math.Clamp(y - 23, 0, area:GetTall() - 46))
            end

            piece.OnMouseReleased = function(self)
                if dragging ~= self then return end
                dragging = nil
                self:MouseCapture(false)

                local targetX, targetY = getTargetPosition(pieceIndex)
                local x, y = self:GetPos()
                local distance = math.sqrt((x - targetX) ^ 2 + (y - targetY) ^ 2)

                if distance <= 32 then
                    placed[pieceIndex] = true
                    self:SetPos(targetX, targetY)
                    self:SetEnabled(false)
                else
                    resetPiece()
                end

                local count = 0
                for index = 1, 4 do
                    if placed[index] then count = count + 1 end
                end

                progress:SetText("Деталей собрано: " .. count .. " / 4")
                if count >= 4 then
                    -- Дополнительные значения сохраняют совместимость со старыми сессиями.
                    SendStep("1234", tonumber(task.a) or 0, tonumber(task.b) or 0)
                end
            end
        end
    elseif task.type == 6 then
        local slider = vgui.Create("DNumSlider", parent)
        slider:Dock(TOP)
        slider:DockMargin(35, 25, 35, 10)
        slider:SetTall(42)
        slider:SetMinMax(0, 359)
        slider:SetDecimals(0)
        slider:SetText("Угол")
        slider:SetValue(180)

        local current = 0
        local required = math.floor(task.b)
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(30)
        progress:SetFont("SSRP_Craft_Label")
        progress:SetText("Фиксаций: 0 / " .. required)
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        AddTaskButton(parent, "ЗАФИКСИРОВАТЬ УГОЛ", function()
            local value = slider:GetValue()
            local difference = math.abs((value - task.a + 180) % 360 - 180)

            if difference <= 14 then
                current = math.min(current + 1, required)
            else
                current = 0
            end

            progress:SetText("Фиксаций: " .. current .. " / " .. required)
            slider:SetValue(math.random(0, 359))

            if current >= required then
                SendStep(tostring(current), value)
            end
        end)
    elseif task.type == 7 then
        local area = vgui.Create("DPanel", parent)
        area:Dock(TOP)
        area:DockMargin(50, 10, 50, 10)
        area:SetTall(150)
        area.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(18, 18, 21))
            draw.RoundedBox(8, task.a * w - 18, task.b * h - 18, 36, 36, Color(190, 190, 198))
        end

        local piece = vgui.Create("DButton", area)
        piece:SetSize(28, 28)
        piece:SetPos(8, 8)
        piece:SetText("")
        piece:SetCursor("hand")
        piece.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(225, 225, 230))
        end

        local dragging = false
        local current = 0
        local required = math.floor(task.c)
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(30)
        progress:SetFont("SSRP_Craft_Label")
        progress:SetText("Попаданий: 0 / " .. required)
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        piece.OnMousePressed = function()
            dragging = true
        end
        piece.Think = function(self)
            if not dragging then return end
            local x, y = area:ScreenToLocal(gui.MouseX(), gui.MouseY())
            self:SetPos(math.Clamp(x - 14, 0, area:GetWide() - 28), math.Clamp(y - 14, 0, area:GetTall() - 28))
        end
        piece.OnMouseReleased = function(self)
            if not dragging then return end
            dragging = false
            local x, y = self:GetPos()
            local normalizedX = (x + 14) / area:GetWide()
            local normalizedY = (y + 14) / area:GetTall()
            local distance = math.sqrt((normalizedX - task.a) ^ 2 + (normalizedY - task.b) ^ 2)

            if distance <= 0.12 then
                current = math.min(current + 1, required)
            else
                current = 0
            end

            progress:SetText("Попаданий: " .. current .. " / " .. required)
            self:SetPos(8, 8)

            if current >= required then
                SendStep(tostring(current), normalizedX, normalizedY)
            end
        end
    elseif task.type == 8 then
        local current = ""
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(34)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("—")
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        for i = 1, 3 do
            local sequenceNumber = i
            AddTaskButton(parent, "УЗЕЛ " .. sequenceNumber, function()
                current = current .. tostring(sequenceNumber)
                progress:SetText(current .. " / " .. #task.text)

                if #current >= #task.text then
                    SendStep(current)
                end
            end)
        end
    elseif task.type == 9 then
        local required = math.floor(task.a)
        local current = 0
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(38)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("0 / " .. required)
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        AddTaskButton(parent, "ЗАКРУТИТЬ КРЕПЛЕНИЕ", function()
            current = math.min(required, current + 1)
            progress:SetText(current .. " / " .. required)
            if current >= required then
                SendStep(required)
            end
        end)
    elseif task.type == 10 then
        local current = ""
        local progress = vgui.Create("DLabel", parent)
        progress:Dock(TOP)
        progress:SetTall(38)
        progress:SetFont("SSRP_Craft_Big")
        progress:SetText("—")
        progress:SetTextColor(Color(235, 235, 238))
        progress:SetContentAlignment(5)

        local order = {"1", "2", "3"}
        for i = #order, 2, -1 do
            local j = math.random(i)
            order[i], order[j] = order[j], order[i]
        end

        for _, value in ipairs(order) do
            local codeDigit = value
            AddTaskButton(parent, codeDigit, function()
                current = current .. codeDigit
                progress:SetText(current)
                if #current >= #task.text then
                    SendStep(current)
                end
            end)
        end
    end
end

local function OpenCraftTask()
    if IsValid(craftFrame) then craftFrame:Remove() end

    craftFrame = MakeFrame("СБОРКА · МАСТЕРСКАЯ", 560, 520)

    local stepLabel = vgui.Create("DLabel", craftFrame)
    craftStatusLabel = stepLabel
    craftProcessing = false
    stepLabel:Dock(TOP)
    stepLabel:DockMargin(25, 0, 60, 8)
    stepLabel:SetTall(22)
    stepLabel:SetFont("SSRP_Craft_Label")
    stepLabel:SetText("Операция " .. craftStep .. " из 4")
    stepLabel:SetTextColor(Color(145, 145, 152))

    local content = vgui.Create("DPanel", craftFrame)
    content:Dock(FILL)
    content:DockMargin(25, 0, 25, 50)
    content.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(12, 12, 14))
    end

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:Dock(FILL)
    scroll:DockMargin(18, 15, 18, 15)
    BuildTaskContent(scroll:GetCanvas(), craftTask)

    local cancel = vgui.Create("DButton", craftFrame)
    craftCancelButton = cancel
    cancel:Dock(BOTTOM)
    cancel:DockMargin(25, 0, 25, 16)
    cancel:SetTall(36)
    cancel:SetText("ОТМЕНА")
    cancel:SetFont("SSRP_Craft_Label")
    cancel:SetTextColor(Color(235, 235, 238))
    cancel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(65, 65, 70) or Color(37, 37, 41))
    end
    cancel.DoClick = CancelCrafting
    craftFrame.Think = function()
        if craftProcessing then
            local left = math.max(0, math.ceil(craftProcessingEnd - CurTime()))
            if IsValid(stepLabel) then stepLabel:SetText("Идёт обработка на верстаке · " .. left .. " сек") end
            if IsValid(cancel) then cancel:SetEnabled(false) cancel:SetText("ИЗГОТОВЛЕНИЕ") end
        end
    end
end

net.Receive("SSRP_Crafting_Shop", function()
    surface.PlaySound("buttons/button15.wav")
    shopItems = {}
    local count = net.ReadUInt(8)

    for i = 1, count do
        shopItems[i] = {
            class = net.ReadString(),
            name = net.ReadString(),
            price = net.ReadUInt(32),
            icon = net.ReadString(),
            unlocked = net.ReadBool(),
            recipe = net.ReadString()
        }
    end

    workbenchParts, personalParts = {}, {}
    local partCount = net.ReadUInt(5)
    for i = 1, partCount do
        local item = {
            id = net.ReadString(),
            name = net.ReadString(),
            detail = net.ReadString(),
            price = net.ReadUInt(16),
            stock = net.ReadUInt(16),
            personal = net.ReadUInt(16)
        }
        if item.stock > 0 then
            workbenchParts[#workbenchParts + 1] = {id = item.id, name = item.name, detail = item.detail, amount = item.stock}
        end
        if item.personal > 0 then
            personalParts[#personalParts + 1] = {id = item.id, name = item.name, detail = item.detail, amount = item.personal}
        end
    end

    OpenShop()
end)

net.Receive("SSRP_Crafting_BlueprintsV2", function()
    surface.PlaySound("buttons/button15.wav")
    ownedBlueprints = {}
    local count = net.ReadUInt(8)

    for i = 1, count do
        ownedBlueprints[i] = {
            class = net.ReadString(),
            name = net.ReadString(),
            amount = net.ReadUInt(8),
            icon = net.ReadString(),
            recipe = net.ReadString()
        }
    end

    OpenBlueprints()
end)

net.Receive("SSRP_Crafting_PartsData", function()
    surface.PlaySound("buttons/button15.wav")
    local mode = net.ReadUInt(2)
    local count = net.ReadUInt(5)
    local items = {}
    for i = 1, count do
        items[i] = {
            id = net.ReadString(),
            name = net.ReadString(),
            detail = net.ReadString(),
            price = net.ReadUInt(16),
            amount = net.ReadUInt(16)
        }
    end
    if OpenPartsFrame then OpenPartsFrame(mode, items) end
end)

net.Receive("SSRP_Crafting_TaskV2", function()
    surface.PlaySound("buttons/button15.wav")
    if IsValid(blueprintFrame) then blueprintFrame:Close() end
    craftSessionID = net.ReadUInt(32)
    craftStep = net.ReadUInt(4)
    local taskType = net.ReadUInt(4)
    craftToken = net.ReadUInt(32)

    craftTask = {
        type = taskType,
        a = net.ReadFloat(),
        b = net.ReadFloat(),
        c = net.ReadFloat(),
        duration = net.ReadFloat(),
        text = net.ReadString()
    }

    craftReadyAt = CurTime() + craftTask.duration

    OpenCraftTask()
end)

net.Receive("SSRP_Crafting_ProcessingV2", function()
    local duration = net.ReadFloat()
    craftProcessing = true
    craftProcessingDuration = math.max(1, duration)
    craftProcessingEnd = CurTime() + duration

    if not IsValid(craftFrame) then
        craftFrame = MakeFrame("ИЗГОТОВЛЕНИЕ ПАТРОНОВ", 500, 270)
        craftStatusLabel = vgui.Create("DLabel", craftFrame)
        craftStatusLabel:Dock(TOP)
        craftStatusLabel:DockMargin(24, 0, 24, 8)
        craftStatusLabel:SetTall(42)
        craftStatusLabel:SetFont("SSRP_Craft_Item")
        craftStatusLabel:SetTextColor(Color(235, 235, 238))
        craftStatusLabel:SetContentAlignment(5)

        local progress = vgui.Create("DPanel", craftFrame)
        progress:Dock(FILL)
        progress:DockMargin(24, 4, 24, 24)
        progress.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(12, 12, 14))
            draw.SimpleText("Верстак собирает пачку патронов", "SSRP_Craft_Label", w * 0.5, h * 0.30,
                Color(190, 190, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local fraction = 1 - math.Clamp((craftProcessingEnd - CurTime()) / craftProcessingDuration, 0, 1)
            draw.RoundedBox(6, w * 0.12, h * 0.58, w * 0.76, 14, Color(38, 42, 47))
            draw.RoundedBox(6, w * 0.12, h * 0.58, w * 0.76 * fraction, 14, Color(218, 174, 86))
        end
        craftFrame.Think = function()
            if not craftProcessing or not IsValid(craftStatusLabel) then return end
            craftStatusLabel:SetText("Осталось " .. math.max(0, math.ceil(craftProcessingEnd - CurTime())) .. " сек.")
        end
    end

    if IsValid(craftStatusLabel) then
        craftStatusLabel:SetText("Осталось " .. math.ceil(duration) .. " сек.")
    end
end)

net.Receive("SSRP_Crafting_ResultV2", function()
    local success = net.ReadBool()
    local text = net.ReadString()
    surface.PlaySound(success and "buttons/button17.wav" or "buttons/button10.wav")

    if IsValid(craftFrame) then
        craftFrame:Close()
    end

    chat.AddText(
        success and Color(110, 220, 140) or Color(220, 110, 110),
        "[Крафт] ",
        Color(235, 235, 238),
        text
    )

    craftTask = nil
    craftProcessing = false
    craftStatusLabel = nil
    craftCancelButton = nil
    craftProcessingEnd = 0
    craftProcessingDuration = 0
end)

net.Receive("SSRP_Crafting_OutputsData", function()
    workbenchOutputs = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        local id = net.ReadUInt(32)
        local class = net.ReadString()
        local name = net.ReadString()
        local owner = net.ReadString()
        local readyIn = net.ReadUInt(6)
        local canClaim = net.ReadBool()
        workbenchOutputs[i] = {
            id = id,
            class = class,
            name = name,
            owner = owner,
            readyAt = CurTime() + readyIn,
            canClaim = canClaim,
            kind = string.sub(class, 1, 15) == "ssrp_attachment"
                and "attachment" or (string.sub(class, 1, 10) == "ssrp_ammo_" and "ammo" or "weapon")
        }
    end
    OpenWorkbenchOutputs()
end)

net.Receive("SSRP_Crafting_PurchaseFeedback", function()
    local success = net.ReadBool()
    net.ReadString() -- Текст уже выводится обычным уведомлением.

    if success then
        surface.PlaySound("buttons/button15.wav")
    else
        surface.PlaySound("buttons/button10.wav")
    end
end)

net.Receive("SSRP_Crafting_Notify", function()
    chat.AddText(Color(180, 180, 185), "[Чертежи] ", Color(235, 235, 238), net.ReadString())
end)

hook.Add("HUDPaint", "SSRP_Crafting_WorkbenchHint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local target = ply:GetEyeTrace().Entity
    if not IsValid(target) or target:GetClass() ~= "ssrp_crafting_workbench"
        or ply:GetPos():DistToSqr(target:GetPos()) > 150 * 150 then return end
    local w, h = 244, 30
    local x, y = (ScrW() - w) * 0.5, ScrH() * 0.72
    draw.RoundedBox(8, x, y, w, h, Color(14, 18, 23, 225))
    surface.SetDrawColor(218, 174, 86, 95)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.RoundedBox(4, x + 5, y + 5, 24, 20, Color(86, 66, 34, 225))
    draw.SimpleText("E", "SSRP_Craft_Label", x + 17, y + 15, Color(245, 226, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("ОРУЖЕЙНЫЙ ВЕРСТАК", "SSRP_Craft_Label", x + 38, y + 15, Color(220, 221, 222), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDPaint", "SSRP_Crafting_VendorHint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local target = ply:GetEyeTrace().Entity
    if not IsValid(target) or target:GetClass() ~= "ssrp_crafting_parts_vendor"
        or ply:GetPos():DistToSqr(target:GetPos()) > 150 * 150 then return end
    local w, h = 224, 30
    local x, y = (ScrW() - w) * 0.5, ScrH() * 0.72
    draw.RoundedBox(8, x, y, w, h, Color(14, 18, 23, 225))
    surface.SetDrawColor(218, 174, 86, 95)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.RoundedBox(4, x + 5, y + 5, 24, 20, Color(86, 66, 34, 225))
    draw.SimpleText("E", "SSRP_Craft_Label", x + 17, y + 15, Color(245, 226, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("ПОСТАВЩИК ДЕТАЛЕЙ", "SSRP_Craft_Label", x + 38, y + 15, Color(220, 221, 222), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

