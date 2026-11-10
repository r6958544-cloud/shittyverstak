if not SERVER then return end

AddCSLuaFile("autorun/client/ssrp_crafting_cl.lua")
AddCSLuaFile("autorun/client/ssrp_crafting_zcity_compat.lua")
AddCSLuaFile("weapons/weapon_ssrp_single_shotgun/shared.lua")

-- Модель оружейного верстака из Workshop 2866027579 и её материалы.
for _, path in ipairs({
    "models/ammoworkbench.mdl", "models/ammoworkbench.phy", "models/ammoworkbench.vvd",
    "models/ammoworkbench.dx80.vtx", "models/ammoworkbench.dx90.vtx", "models/ammoworkbench.sw.vtx",
    "materials/models/gonets/instrumenti.vmt", "materials/models/gonets/instrumenti.vtf",
    "materials/models/gonets/meloch.vmt", "materials/models/gonets/meloch.vtf",
    "materials/models/gonets/samstol.vmt", "materials/models/gonets/samstol.vtf",
    "materials/models/gonets/wireworkbench.vmt", "materials/models/gonets/wireworkbench.vtf"
}) do
    resource.AddFile(path)
end

util.AddNetworkString("SSRP_Crafting_Shop")
util.AddNetworkString("SSRP_Crafting_ShopAction")
util.AddNetworkString("SSRP_Crafting_BlueprintsV2")
util.AddNetworkString("SSRP_Crafting_Blueprints")
util.AddNetworkString("SSRP_Crafting_Start")
util.AddNetworkString("SSRP_Crafting_TaskV2")
util.AddNetworkString("SSRP_Crafting_StepV2")
util.AddNetworkString("SSRP_Crafting_Cancel")
util.AddNetworkString("SSRP_Crafting_ResultV2")
util.AddNetworkString("SSRP_Crafting_ProcessingV2")
util.AddNetworkString("SSRP_Crafting_Notify")
util.AddNetworkString("SSRP_Crafting_PurchaseFeedback")
util.AddNetworkString("SSRP_Crafting_PartsRequest")
util.AddNetworkString("SSRP_Crafting_PartsData")
util.AddNetworkString("SSRP_Crafting_PartsPurchase")
util.AddNetworkString("SSRP_Crafting_VendorOpen")
util.AddNetworkString("SSRP_Crafting_DepositParts")
util.AddNetworkString("SSRP_Crafting_WithdrawParts")
util.AddNetworkString("SSRP_Crafting_TransferAllParts")
util.AddNetworkString("SSRP_Crafting_OutputsRequest")
util.AddNetworkString("SSRP_Crafting_OutputsData")
util.AddNetworkString("SSRP_Crafting_OutputClaim")
util.AddNetworkString("SSRP_Crafting_TransferPart")

-- Garry's Mod exposes sql.Query(), but not QueryRow() on all builds.
-- A missing row returns nil; successful SELECTs return an array of rows.
local function QueryRow(statement)
    local rows = sql.Query(statement)
    if istable(rows) then return rows[1] end
    return nil
end

local BLUEPRINT_KEY = "ssrp_crafting_blueprints_v1"
local STORAGE_CLASS = "ssrp_crafting_workbench"
local BLUEPRINT_WEAPON = "weapon_ssrp_blueprint"
local MAX_BLUEPRINTS_PER_CLASS = 99

-- Доступ проверяется через профессию из character_professions.
SSRP_CraftingConfig = SSRP_CraftingConfig or {}
SSRP_CraftingConfig.RequiredProfession = SSRP_CraftingConfig.RequiredProfession or "gunsmith"
SSRP_CraftingConfig.RequiredDarkRPJob = SSRP_CraftingConfig.RequiredDarkRPJob or "gunsmith"

local PARTS = {
    steel = {name = "Стальная заготовка", short = "Сталь", detail = "Металл для подвижных и несущих узлов", price = 28},
    spring = {name = "Возвратная пружина", short = "Пружина", detail = "Возвращает затвор или ударный механизм", price = 18},
    receiver = {name = "Рамка / основа", short = "Рамка", detail = "Несущая основа оружия", price = 80},
    barrel = {name = "Нарезной ствол", short = "Ствол", detail = "Стволовая группа под конкретный класс оружия", price = 95},
    polymer = {name = "Полимерные накладки", short = "Полимер", detail = "Рукоять и внешние накладки", price = 20},
    wood = {name = "Деревянные накладки", short = "Дерево", detail = "Приклад или щёчки рукояти", price = 18},
    fastener = {name = "Комплект штифтов и крепежа", short = "Крепёж", detail = "Штифты, винты и мелкая фурнитура", price = 6},
    trigger = {name = "Спусковая группа", short = "Спуск", detail = "Спуск, шептало и ударные детали", price = 35},
    slide = {name = "Затворная группа", short = "Затвор", detail = "Затвор и его направляющие", price = 75},
    magazine = {name = "Магазин", short = "Магазин", detail = "Корпус магазина с подавателем и пружиной", price = 35},
    sights = {name = "Комплект прицельных приспособлений", short = "Прицел", detail = "Мушка и целик", price = 14},
    cylinder = {name = "Барабан револьвера", short = "Барабан", detail = "Каморы барабана и ось", price = 55},
    bolt = {name = "Затворная рама", short = "Затворная рама", detail = "Затворная группа пистолета-пулемёта", price = 82},
    pump = {name = "Помповый механизм", short = "Помпа", detail = "Цевьё, тяги и запирание помпового ружья", price = 48},
    brass_case = {name = "Латунная гильза", short = "Гильза", detail = "Гильза подходящего типа для сборки патрона", price = 1},
    gunpowder = {name = "Пороховой заряд", short = "Порох", detail = "Отмеренный заряд для одного патрона", price = 1},
    bullet = {name = "Пуля", short = "Пуля", detail = "Снаряд подходящего типа для патрона", price = 2},
    primer = {name = "Капсюль", short = "Капсюль", detail = "Капсюль-воспламенитель для одного патрона", price = 1},
    optic_glass = {name = "Оптическое стекло", short = "Стекло", detail = "Линза для прицельного модуля", price = 48},
    optic_body = {name = "Корпус оптики", short = "Корпус", detail = "Защищённый корпус прицела", price = 55},
    carbon = {name = "Композитный материал", short = "Композит", detail = "Лёгкий материал для внешних модулей", price = 35},
    tube = {name = "Стальная трубка", short = "Трубка", detail = "Заготовка для внешнего насадного модуля", price = 42},
    rubber = {name = "Резиновая накладка", short = "Резина", detail = "Амортизирующая рукоять и накладка", price = 16}
}

local BLUEPRINTS = {
    weapon_tumberahui = {name = "Тумбера", price = 0, parts = {steel = 2, spring = 1, receiver = 1, barrel = 2, wood = 2, fastener = 5, trigger = 2, sights = 1}},
    weapon_dupletlong = {name = "Дуплет", price = 0, parts = {steel = 3, spring = 2, receiver = 1, barrel = 2, wood = 2, fastener = 6, trigger = 2, sights = 1}},
    weapon_bechowiec = {name = "Беховец", price = 0, parts = {steel = 2, spring = 1, receiver = 1, bolt = 1, barrel = 1, polymer = 2, magazine = 1, fastener = 5, trigger = 1, sights = 1}},
    weapon_blyskawichka = {name = "Блыскавица", price = 0, parts = {steel = 3, spring = 1, receiver = 1, bolt = 1, barrel = 1, polymer = 2, magazine = 1, fastener = 5, trigger = 1, sights = 1}},
    weapon_mat49 = {name = "MAT-49", price = 0, parts = {steel = 3, spring = 1, receiver = 1, bolt = 1, barrel = 1, polymer = 2, magazine = 1, fastener = 6, trigger = 1, sights = 1}},
    weapon_ssdagger = {name = "Боевой кинжал", price = 0, parts = {steel = 3, polymer = 1, fastener = 1}},
    weapon_buck200knife = {name = "Нож Buck 120", price = 0, parts = {steel = 3, wood = 1, fastener = 1}},
    weapon_hg_crowbar = {name = "Монтировка", price = 0, parts = {steel = 4, fastener = 1}},
    weapon_sogknife = {name = "Нож SOG Seal", price = 0, parts = {steel = 3, polymer = 1, fastener = 1}},
    weapon_pocketknife = {name = "Складной нож", price = 0, parts = {steel = 2, spring = 1, fastener = 2}},
    weapon_pm9 = {name = "PM-9", price = 0, parts = {steel = 1, spring = 1, receiver = 1, slide = 1, barrel = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2, trigger = 1}},
    weapon_hkp7 = {name = "HK P7", price = 0, parts = {steel = 1, spring = 1, receiver = 1, slide = 1, barrel = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2, trigger = 1}},
    weapon_glock17 = {name = "Glock 17", price = 0, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    ssrp_attachment_suppressor = {name = "Глушитель Z-City", kind = "attachment", attachment = "supressor4", price = 0, parts = {tube = 1, steel = 1, fastener = 2, carbon = 1}},
    ssrp_attachment_holo = {name = "Коллиматор Z-City", kind = "attachment", attachment = "holo16", price = 0, parts = {optic_glass = 1, optic_body = 1, fastener = 2, steel = 1}},
    ssrp_attachment_scope = {name = "Оптический прицел Z-City", kind = "attachment", attachment = "optic12", price = 0, parts = {optic_glass = 2, optic_body = 1, fastener = 3, steel = 2}},
    weapon_ssrp_single_shotgun = {name = "Однозарядное ружьё", kind = "weapon", price = 0, parts = {steel = 3, receiver = 1, barrel = 2, wood = 2, trigger = 1, spring = 1, sights = 1, fastener = 4}},
    weapon_bat = {name = "Бейсбольная бита", kind = "weapon", price = 0, parts = {wood = 3, steel = 1, rubber = 1, fastener = 2}}
}
local AMMO_BLUEPRINTS = {}

local WEAPON_FAMILIES = {
    {id = "glock17", name = "Glock 17", exact = {"weapon_glock17"}, match = {"glock17", "glock_17"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "glock19", name = "Glock 19", exact = {"weapon_glock19", "weapon_glock_19"}, match = {"glock19", "glock_19"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "glock26", name = "Glock 26", exact = {"weapon_glock26", "weapon_glock_26"}, match = {"glock26", "glock_26"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "makarov", name = "Пистолет Макарова", exact = {"weapon_makarov", "weapon_pm", "weapon_pm_makarov"}, match = {"weapon_makarov", "weapon_pm_makarov", "makarov", "макар", "Макар", "МАКАР", "пм", "ПМ"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "beretta_m9", name = "Beretta M9", exact = {"weapon_m9beretta", "weapon_beretta_m9", "weapon_beretta", "weapon_m9"}, match = {"berettam9", "beretta_m9", "weapon_beretta", "weapon_m9", "beretta"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 3}},
    {id = "kingcobra", name = "Colt King Cobra", exact = {"weapon_colt_kingcobra", "weapon_kingcobra", "weapon_king_cobra"}, match = {"kingcobra", "king_cobra", "coltkingcobra", "colt_kingcobra"}, parts = {receiver = 1, cylinder = 1, barrel = 1, spring = 1, trigger = 1, wood = 1, sights = 1, fastener = 3}},
    {id = "tt33", name = "ТТ-33", exact = {"weapon_tt33", "weapon_tt_33", "weapon_tokarev"}, match = {"weapon_tt33", "weapon_tt_33", "weapon_tokarev", "tt33", "tokarev", "тт33", "тт-33", "ТТ33", "ТТ-33"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, wood = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "mini_magnum", name = "Mini Magnum", exact = {"weapon_minimagnum", "weapon_mini_magnum"}, match = {"minimagnum", "mini_magnum", "minimag", "мини-магнум"}, parts = {receiver = 1, cylinder = 1, barrel = 1, spring = 1, trigger = 1, wood = 1, sights = 1, fastener = 2}},
    {id = "mp8013t", name = "МР-80-13Т", exact = {"weapon_mp8013t", "weapon_mp_80_13t", "weapon_mp80_13t"}, match = {"mp8013t", "mp_80_13t", "mp80_13t", "mr8013t", "mp80", "мр80", "мр-80", "мр 80", "МР-80-13Т", "МР-80", "МР80"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "fiveseven", name = "FN Five-seveN", exact = {"weapon_fiveseven", "weapon_five_seven", "weapon_fn57"}, match = {"fiveseven", "five_seven", "fn57"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 2, magazine = 1, sights = 1, fastener = 2}},
    {id = "colt1911", name = "Colt 1911", exact = {"weapon_colt1911", "weapon_colt_1911", "weapon_1911", "weapon_m1911"}, match = {"colt1911", "colt_1911", "m1911", "1911"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, wood = 1, magazine = 1, sights = 1, fastener = 3}},
    {id = "sigp365", name = "SIG Sauer P365", exact = {"weapon_p365", "weapon_sigp365"}, match = {"p365", "sigp365"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "sigp226", name = "SIG Sauer P226", exact = {"weapon_p226", "weapon_sigp226"}, match = {"p226", "sigp226"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 3}},
    {id = "sw5946", name = "Smith & Wesson 5946", exact = {"weapon_sw5946", "weapon_smith_wesson_5946"}, match = {"5946", "smithwesson5946", "sw5946"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 3}},
    {id = "xds", name = "Springfield XD-S", exact = {"weapon_xds", "weapon_springfield_xds"}, match = {"xds", "springfieldxds", "springfield_xds"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "shield", name = "Smith & Wesson M&P Shield", exact = {"weapon_mpshield", "weapon_mp_shield", "weapon_shield"}, match = {"mpshield", "mp_shield"}, parts = {receiver = 1, slide = 1, barrel = 1, spring = 1, trigger = 1, polymer = 1, magazine = 1, sights = 1, fastener = 2}},
    {id = "mossberg590", name = "Mossberg 590", exact = {"weapon_mossberg590", "weapon_m590"}, match = {"mossberg590", "mossberg_590", "m590"}, parts = {receiver = 1, barrel = 2, spring = 1, trigger = 1, wood = 2, pump = 1, sights = 1, fastener = 5}},
    {id = "ithaca37", name = "Ithaca 37", exact = {"weapon_ithaca37", "weapon_ithaca_37"}, match = {"ithaca37", "ithaca_37"}, parts = {receiver = 1, barrel = 2, spring = 1, trigger = 1, wood = 2, pump = 1, sights = 1, fastener = 5}}
}

local SHOP_ENTITY_DISTANCE = 180 * 180
local shopCooldown = {}
local sessions = {}
local nextSessionID = 0

sql.Query([[CREATE TABLE IF NOT EXISTS ssrp_crafting_workbenches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    map_name TEXT NOT NULL,
    pos_x REAL NOT NULL, pos_y REAL NOT NULL, pos_z REAL NOT NULL,
    ang_p REAL NOT NULL DEFAULT 0, ang_y REAL NOT NULL DEFAULT 0, ang_r REAL NOT NULL DEFAULT 0
)]] )
sql.Query([[CREATE TABLE IF NOT EXISTS ssrp_crafting_workbench_parts (
    workbench_id INTEGER NOT NULL,
    part_id TEXT NOT NULL,
    amount INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (workbench_id, part_id)
)]])
sql.Query([[CREATE TABLE IF NOT EXISTS ssrp_crafting_player_parts (
    steamid64 TEXT NOT NULL, part_id TEXT NOT NULL, amount INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (steamid64, part_id)
)]])
sql.Query([[CREATE TABLE IF NOT EXISTS ssrp_crafting_parts_vendors (
    id INTEGER PRIMARY KEY AUTOINCREMENT, map_name TEXT NOT NULL,
    pos_x REAL NOT NULL, pos_y REAL NOT NULL, pos_z REAL NOT NULL,
    ang_p REAL NOT NULL DEFAULT 0, ang_y REAL NOT NULL DEFAULT 0, ang_r REAL NOT NULL DEFAULT 0
)]])
sql.Query([[CREATE TABLE IF NOT EXISTS ssrp_crafting_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    craft_token TEXT NOT NULL UNIQUE,
    workbench_id INTEGER NOT NULL,
    owner_steamid64 TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    item_class TEXT NOT NULL,
    item_name TEXT NOT NULL,
    ready_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
)]])

local function ClearWorkbenchStorage(workbenchID)
    workbenchID = math.floor(tonumber(workbenchID) or 0)
    if workbenchID <= 0 then return end
    sql.Query("DELETE FROM ssrp_crafting_workbench_parts WHERE workbench_id = " .. workbenchID)
    sql.Query("DELETE FROM ssrp_crafting_outputs WHERE workbench_id = " .. workbenchID)
end

hook.Add("EntityRemoved", "SSRP_Crafting_ClearRemovedWorkbench", function(entity)
    if IsValid(entity) and entity:GetClass() == STORAGE_CLASS then
        ClearWorkbenchStorage(entity:GetWorkbenchID())
    end
end)

local function Notify(ply, text)
    if not IsValid(ply) then return end

    net.Start("SSRP_Crafting_Notify")
        net.WriteString(text)
    net.Send(ply)
end

local function GetMoney(ply)
    if not IsValid(ply) or not isfunction(SSRP_GetMoney) then return 0 end
    local ok, amount = pcall(SSRP_GetMoney, ply)
    return ok and math.max(0, math.floor(tonumber(amount) or 0)) or 0
end

local function TakeMoney(ply, amount, reason)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 or not IsValid(ply) then return false end
    if MoneySystem and isfunction(MoneySystem.TakeMoney) then
        local ok, result = pcall(MoneySystem.TakeMoney, ply, amount, reason or "crafting_purchase")
        if ok and result ~= false then GetMoney(ply) return true end
        return false
    end
    if MoneySystem and isfunction(MoneySystem.AddMoney) then
        local ok, result = pcall(MoneySystem.AddMoney, ply, -amount, reason or "crafting_purchase")
        if ok and result ~= false then GetMoney(ply) return true end
    end
    return false
end

local function GetBlueprintIcon(class)
    local info = weapons.GetStored(class)
    if not info then return "" end

    -- Берём тот же приоритет, что меню оружия Z-City: WepSelectIcon2,
    -- затем IconOverride. Путь остаётся внутри материалов Z-City.
    local icon = info.WepSelectIcon2
    if icon and isfunction(icon.GetName) then
        local name = icon:GetName()
        if isstring(name) and name ~= "" then
            if not string.EndsWith(string.lower(name), ".png") then name = name .. ".png" end
            return name
        end
    end

    return isstring(info.IconOverride) and info.IconOverride or ""
end

local function LoadBlueprints(ply)
    local raw = ply:GetPData(BLUEPRINT_KEY, "")
    if raw == "" then return {} end

    local decoded = util.JSONToTable(raw)
    if not istable(decoded) then return {} end

    local result = {}

    for class, count in pairs(decoded) do
        if BLUEPRINTS[class] or AMMO_BLUEPRINTS[class] then
            count = math.Clamp(math.floor(tonumber(count) or 0), 0, MAX_BLUEPRINTS_PER_CLASS)
            if count > 0 then
                result[class] = count
            end
        end
    end

    return result
end

local function SaveBlueprints(ply, blueprints)
    if not IsValid(ply) then return end
    ply:SetPData(BLUEPRINT_KEY, util.TableToJSON(blueprints, false))
end

local function HasCraftingJob(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if IDProfessions and isfunction(IDProfessions.Get) then
        local professionID = IDProfessions.Get(ply)
        return professionID == SSRP_CraftingConfig.RequiredProfession
    end
    return ply:GetNW2String("IDCardProfession", "") == SSRP_CraftingConfig.RequiredProfession
        or ply.job == SSRP_CraftingConfig.RequiredDarkRPJob
end

local function FindNearbyWorkbench(ply)
    if not IsValid(ply) then return nil end
    for _, bench in ipairs(ents.FindByClass(STORAGE_CLASS)) do
        if IsValid(bench) and ply:GetPos():DistToSqr(bench:GetPos()) <= SHOP_ENTITY_DISTANCE then
            return bench
        end
    end
end

local function EnsureWorkbenchID(bench)
    if not IsValid(bench) or bench:GetClass() ~= STORAGE_CLASS then return 0 end
    local id = math.floor(tonumber(bench:GetWorkbenchID()) or 0)
    if id > 0 then return id end

    local pos, ang = bench:GetPos(), bench:GetAngles()
    sql.Query("INSERT INTO ssrp_crafting_workbenches (map_name, pos_x, pos_y, pos_z, ang_p, ang_y, ang_r) VALUES (" ..
        sql.SQLStr(game.GetMap()) .. ", " .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ", " .. ang.p .. ", " .. ang.y .. ", " .. ang.r .. ")")
    local row = QueryRow("SELECT last_insert_rowid() AS id")
    id = math.floor(tonumber(row and row.id) or 0)
    if id > 0 then bench:SetWorkbenchID(id) end
    return id
end

local function GetPlayerWorkbench(ply)
    if not IsValid(ply) then return nil end
    local current = ply.SSRP_CraftingWorkbench
    if IsValid(current) and current:GetClass() == STORAGE_CLASS
        and ply:GetPos():DistToSqr(current:GetPos()) <= SHOP_ENTITY_DISTANCE then
        EnsureWorkbenchID(current)
        return current
    end
    current = FindNearbyWorkbench(ply)
    if IsValid(current) then
        EnsureWorkbenchID(current)
        ply.SSRP_CraftingWorkbench = current
    end
    return current
end

local function IsNearShop(ply)
    if not HasCraftingJob(ply) or not ply:Alive() then return false end
    local bench = ply.SSRP_CraftingWorkbench
    return IsValid(bench) and bench:GetClass() == STORAGE_CLASS
        and ply:GetPos():DistToSqr(bench:GetPos()) <= SHOP_ENTITY_DISTANCE
end

local function RecipeDescription(recipe)
    local lines = {}
    for partID, amount in pairs(recipe or {}) do
        local part = PARTS[partID]
        if part then lines[#lines + 1] = part.name .. " ×" .. amount end
    end
    table.sort(lines)
    return table.concat(lines, "  •  ")
end

local function GetPartAmount(workbenchID, partID)
    local row = QueryRow("SELECT amount FROM ssrp_crafting_workbench_parts WHERE workbench_id = " ..
        math.floor(tonumber(workbenchID) or 0) .. " AND part_id = " .. sql.SQLStr(partID))
    return math.max(0, math.floor(tonumber(row and row.amount) or 0))
end

local function AddPartAmount(workbenchID, partID, amount)
    workbenchID = math.floor(tonumber(workbenchID) or 0)
    amount = math.floor(tonumber(amount) or 0)
    if workbenchID <= 0 or not PARTS[partID] or amount <= 0 then return false end
    local current = GetPartAmount(workbenchID, partID)
    if current + amount > 2000000000 then return false end
    local expected = current + amount
    sql.Query("INSERT OR REPLACE INTO ssrp_crafting_workbench_parts (workbench_id, part_id, amount) VALUES (" ..
        workbenchID .. ", " .. sql.SQLStr(partID) .. ", " .. expected .. ")")
    return GetPartAmount(workbenchID, partID) == expected
end

local function HasRecipeParts(workbenchID, recipe)
    for partID, amount in pairs(recipe or {}) do
        if GetPartAmount(workbenchID, partID) < amount then return false, partID end
    end
    return true
end

local function ChangeRecipeParts(workbenchID, recipe, direction)
    for partID, amount in pairs(recipe or {}) do
        if direction < 0 then
            local current = GetPartAmount(workbenchID, partID)
            local left = math.max(0, current - amount)
            sql.Query("INSERT OR REPLACE INTO ssrp_crafting_workbench_parts (workbench_id, part_id, amount) VALUES (" ..
                math.floor(tonumber(workbenchID) or 0) .. ", " .. sql.SQLStr(partID) .. ", " .. left .. ")")
        else
            AddPartAmount(workbenchID, partID, amount)
        end
    end
end

local function GetPersonalPartAmount(ply, partID)
    local row = QueryRow("SELECT amount FROM ssrp_crafting_player_parts WHERE steamid64 = " ..
        sql.SQLStr(ply:SteamID64()) .. " AND part_id = " .. sql.SQLStr(partID))
    return math.max(0, math.floor(tonumber(row and row.amount) or 0))
end

local function SetPersonalPartAmount(ply, partID, amount)
    sql.Query("INSERT OR REPLACE INTO ssrp_crafting_player_parts (steamid64, part_id, amount) VALUES (" ..
        sql.SQLStr(ply:SteamID64()) .. ", " .. sql.SQLStr(partID) .. ", " .. math.Clamp(math.floor(amount), 0, 9999) .. ")")
end

local function SendPartsData(ply, mode)
    mode = math.Clamp(math.floor(tonumber(mode) or 0), 0, 2)
    if not HasCraftingJob(ply) then Notify(ply, "Детали доступны только оружейнику.") return end
    local bench = GetPlayerWorkbench(ply)
    if mode ~= 0 and not IsValid(bench) then Notify(ply, "Подойди к оружейному верстаку.") return end
    if mode == 0 then
        local nearVendor = false
        for _, vendor in ipairs(ents.FindByClass("ssrp_crafting_parts_vendor")) do
            if IsValid(vendor) and ply:GetPos():DistToSqr(vendor:GetPos()) <= 150 * 150 then nearVendor = true break end
        end
        if not nearVendor then return end
    end
    if IsValid(bench) then ply.SSRP_CraftingWorkbench = bench end
    net.Start("SSRP_Crafting_PartsData")
        net.WriteUInt(mode, 2)
        net.WriteUInt(table.Count(PARTS), 5)
        for partID, part in SortedPairs(PARTS) do
            net.WriteString(partID)
            net.WriteString(part.name)
            net.WriteString(part.detail or "Оружейный компонент")
            net.WriteUInt(part.price, 16)
            local amount = mode == 0 and GetPersonalPartAmount(ply, partID) or GetPartAmount(bench:GetWorkbenchID(), partID)
            if mode == 2 then amount = GetPersonalPartAmount(ply, partID) end
            net.WriteUInt(math.Clamp(amount, 0, 65535), 16)
        end
    net.Send(ply)
end

local function RefreshWeaponFamilies()
    local availableClasses, foundFamilies = {}, {}
    local allWeapons = weapons.GetList()
    table.sort(allWeapons, function(a, b)
        return tostring(a.ClassName or a.Class or "") < tostring(b.ClassName or b.Class or "")
    end)

    for _, family in ipairs(WEAPON_FAMILIES) do
        local chosen
        for _, preferred in ipairs(family.exact) do
            if not string.find(string.lower(preferred), "barret", 1, true) and weapons.GetStored(preferred) then
                chosen = preferred
                break
            end
        end
        if not chosen then
            for _, info in ipairs(allWeapons) do
                local rawClass = string.lower(tostring(info.ClassName or info.Class or ""))
                local rawPrinted = string.lower(tostring(info.PrintName or ""))
                local class = string.gsub(rawClass, "[^%w]", "")
                local printed = string.gsub(rawPrinted, "[^%w]", "")
                for _, token in ipairs(family.match) do
                    if string.find(rawClass, "barret", 1, true) or string.find(rawPrinted, "barret", 1, true) then break end
                    local rawToken = string.lower(token)
                    local cleanToken = string.gsub(rawToken, "[^%w]", "")
                    local rawMatch = rawToken ~= "" and (string.find(rawClass, rawToken, 1, true)
                        or string.find(rawPrinted, rawToken, 1, true))
                    local cleanMatch = cleanToken ~= "" and (string.find(class, cleanToken, 1, true)
                        or string.find(printed, cleanToken, 1, true))
                    if rawMatch or cleanMatch then
                        chosen = info.ClassName or info.Class
                        break
                    end
                end
                if chosen then break end
            end
        end
        if chosen and weapons.GetStored(chosen) then
            local recipe = table.Copy(family.parts)
            if family.id == "glock19" then recipe.barrel = 1 end
            BLUEPRINTS[chosen] = {name = family.name, price = 0, parts = recipe}
            availableClasses[chosen] = true
            foundFamilies[#foundFamilies + 1] = {id = family.id, class = chosen, name = family.name, data = BLUEPRINTS[chosen]}
        end
    end

    return availableClasses, foundFamilies
end

local function RefreshAmmoBlueprints(familyWeapons)
    table.Empty(AMMO_BLUEPRINTS)
    local seenAmmo, blueprints = {}, {}
    local ammoNames = {
        pistol = "Пистолетные патроны (тип Pistol)",
        nine = "Патроны 9×19 мм",
        ninex19 = "Патроны 9×19 мм",
        ninex19mm = "Патроны 9×19 мм",
        ninex18 = "Патроны 9×18 мм",
        ninex18mm = "Патроны 9×18 мм",
        makarov = "Патроны 9×18 мм",
        fortyfive = "Патроны .45 ACP",
        fortyfiveacp = "Патроны .45 ACP",
        acp45 = "Патроны .45 ACP",
        threefiftyseven = "Патроны .357 Magnum",
        threefiftysevenmagnum = "Патроны .357 Magnum",
        fiftysevenx28 = "Патроны 5.7×28 мм"
    }
    -- Add common numeric ammo aliases using bracket notation.
    ammoNames["9mm"] = "Патроны 9×19 мм"
    ammoNames["9x19"] = "Патроны 9×19 мм"
    ammoNames["9x19mm"] = "Патроны 9×19 мм"
    ammoNames["9x18"] = "Патроны 9×18 мм"
    ammoNames["9x18mm"] = "Патроны 9×18 мм"
    ammoNames["357"] = "Патроны .357 Magnum"
    ammoNames["357magnum"] = "Патроны .357 Magnum"
    ammoNames["45acp"] = "Патроны .45 ACP"
    ammoNames["45"] = "Патроны .45 ACP"
    ammoNames["57x28"] = "Патроны 5.7×28 мм"
    ammoNames["57x28mm"] = "Патроны 5.7×28 мм"
    ammoNames["762x25"] = "Патроны 7.62×25 мм"
    ammoNames["762x25mm"] = "Патроны 7.62×25 мм"

    local function GetWeaponAmmoType(class)
        local visited = {}
        for _ = 1, 8 do
            if not class or class == "" or visited[class] then break end
            visited[class] = true
            local info = (weapons.Get and weapons.Get(class)) or weapons.GetStored(class) or {}
            local ammo = info.Primary and info.Primary.Ammo
            if ammo and tostring(ammo) ~= "" then return tostring(ammo) end
            class = info.Base
        end
        return ""
    end

    for _, entry in ipairs(familyWeapons or {}) do
        if entry.id ~= "mossberg590" and entry.id ~= "ithaca37" then
            local ammoType = string.Trim(GetWeaponAmmoType(entry.class))
            local normalized = string.gsub(string.lower(ammoType), "[^%w]", "")
            if normalized == "" and ammoType ~= "" then normalized = "custom" .. util.CRC(ammoType) end
            if ammoType ~= "" and normalized ~= "none" and normalized ~= "grenade" then
                local key = string.lower(ammoType)
                if not seenAmmo[key] then
                    seenAmmo[key] = true
                    local id = "ssrp_ammo_" .. normalized
                    local rounds = string.find(normalized, "357", 1, true) and 6 or 12
                    local displayName = ammoNames[normalized]
                    if not displayName then
                        if string.find(normalized, "9x19", 1, true) or string.find(normalized, "9mm", 1, true) then
                            displayName = "Патроны 9×19 мм"
                        elseif string.find(normalized, "9x18", 1, true) then
                            displayName = "Патроны 9×18 мм"
                        elseif string.find(normalized, "45acp", 1, true) then
                            displayName = "Патроны .45 ACP"
                        elseif string.find(normalized, "57x28", 1, true) then
                            displayName = "Патроны 5.7×28 мм"
                        elseif string.find(normalized, "762x25", 1, true) then
                            displayName = "Патроны 7.62×25 мм"
                        else
                            displayName = "Патроны: " .. ammoType
                        end
                    end
                    local data = {
                        kind = "ammo",
                        name = displayName,
                        ammoType = ammoType,
                        rounds = rounds,
                        price = 0,
                        parts = {brass_case = rounds, gunpowder = rounds, bullet = rounds, primer = rounds}
                    }
                    AMMO_BLUEPRINTS[id] = data
                    blueprints[#blueprints + 1] = {class = id, name = displayName, data = data}
                end
            end
        end
    end
    table.sort(blueprints, function(a, b) return a.name < b.name end)
    return blueprints
end

local function SendShop(ply)
    local familyClasses, familyWeapons = RefreshWeaponFamilies()
    for class, data in pairs(BLUEPRINTS) do
        local key = string.lower(class .. " " .. tostring(data.name or ""))
        if not string.find(key, "barret", 1, true) and data.kind == "weapon" and weapons.GetStored(class) then
            familyWeapons[#familyWeapons + 1] = {id = "craftable_weapon", class = class, name = data.name, data = data}
        end
    end
    local ammoBlueprints = RefreshAmmoBlueprints(familyWeapons)
    local ownedBlueprints = LoadBlueprints(ply)
    local available = {}
    for class, data in pairs(BLUEPRINTS) do
        local isAttachment = data.kind == "attachment"
        local hasAttachmentAPI = hg and isfunction(hg.AddAttachmentForce)
        local key = string.lower(class .. " " .. tostring(data.name or ""))
        if not string.find(key, "barret", 1, true) and ((weapons.GetStored(class) and not familyClasses[class])
            or (isAttachment and hasAttachmentAPI)) then
            available[#available + 1] = {class = class, data = data}
        end
    end
    for _, entry in ipairs(familyWeapons) do
        available[#available + 1] = {class = entry.class, data = entry.data}
    end
    for _, entry in ipairs(ammoBlueprints) do
        available[#available + 1] = {class = entry.class, data = entry.data}
    end
    table.sort(available, function(a, b) return a.data.name < b.data.name end)
    local bench = GetPlayerWorkbench(ply)
    local workbenchID = IsValid(bench) and bench:GetWorkbenchID() or 0
    net.Start("SSRP_Crafting_Shop")
        net.WriteUInt(math.min(#available, 255), 8)

        for _, entry in ipairs(available) do
            local class, data = entry.class, entry.data
            net.WriteString(class)
            net.WriteString(data.name)
            net.WriteUInt(0, 32)
            net.WriteString(GetBlueprintIcon(class))
            net.WriteBool((ownedBlueprints[class] or 0) > 0)
            local recipeText = RecipeDescription(data.parts)
            if data.kind == "ammo" then
                recipeText = "Выход: " .. data.rounds .. " шт.  •  " .. recipeText
            end
            net.WriteString(recipeText)
        end
        net.WriteUInt(table.Count(PARTS), 5)
        for partID, part in SortedPairs(PARTS) do
            net.WriteString(partID)
            net.WriteString(part.name)
            net.WriteString(part.detail or "")
            net.WriteUInt(part.price, 16)
            net.WriteUInt(math.Clamp(IsValid(bench) and GetPartAmount(workbenchID, partID) or 0, 0, 65535), 16)
            net.WriteUInt(math.Clamp(GetPersonalPartAmount(ply, partID), 0, 65535), 16)
        end
    net.Send(ply)
end

local function SendBlueprints(ply)
    local _, familyWeapons = RefreshWeaponFamilies()
    for class, data in pairs(BLUEPRINTS) do
        if data.kind == "weapon" and weapons.GetStored(class) then
            familyWeapons[#familyWeapons + 1] = {id = "craftable_weapon", class = class, name = data.name, data = data}
        end
    end
    RefreshAmmoBlueprints(familyWeapons)
    local blueprints = LoadBlueprints(ply)
    local count = 0

    for class, amount in pairs(blueprints) do
        local data = BLUEPRINTS[class] or AMMO_BLUEPRINTS[class]
        if data and amount > 0 then
            count = count + 1
        end
    end

    net.Start("SSRP_Crafting_BlueprintsV2")
        net.WriteUInt(math.min(count, 255), 8)

        for class, amount in pairs(blueprints) do
            local data = BLUEPRINTS[class] or AMMO_BLUEPRINTS[class]
            if data and amount > 0 then
                net.WriteString(class)
                net.WriteString(data.name)
                net.WriteUInt(amount, 8)
                net.WriteString(GetBlueprintIcon(class))
                local recipeText = RecipeDescription(data.parts)
                if data.kind == "ammo" then
                    recipeText = "Выход: " .. data.rounds .. " шт.  •  " .. recipeText
                end
                net.WriteString(recipeText)
            end
        end
    net.Send(ply)
end

local function SendWorkbenchOutputs(ply)
    if not IsValid(ply) or not HasCraftingJob(ply) then return end
    local bench = GetPlayerWorkbench(ply)
    if not IsValid(bench) then Notify(ply, "Подойди к оружейному верстаку, чтобы открыть полку готовых заказов.") return end
    local _, ammoSources = RefreshWeaponFamilies()
    for class, data in pairs(BLUEPRINTS) do
        if data.kind == "weapon" and weapons.GetStored(class) then
            ammoSources[#ammoSources + 1] = {id = "craftable_weapon", class = class, name = data.name, data = data}
        end
    end
    RefreshAmmoBlueprints(ammoSources)
    local rows = sql.Query("SELECT id, owner_steamid64, owner_name, item_class, item_name, ready_at FROM ssrp_crafting_outputs WHERE workbench_id = " ..
        math.floor(bench:GetWorkbenchID()) .. " ORDER BY ready_at ASC, id ASC") or {}
    net.Start("SSRP_Crafting_OutputsData")
        net.WriteUInt(math.min(#rows, 255), 8)
        for i = 1, math.min(#rows, 255) do
            local row = rows[i]
            local readyAt = math.max(0, math.floor(tonumber(row.ready_at) or 0))
            net.WriteUInt(math.max(0, math.floor(tonumber(row.id) or 0)), 32)
            net.WriteString(row.item_class or "")
            net.WriteString(row.item_name or "Изделие")
            net.WriteString(row.owner_name or "Оружейник")
            net.WriteUInt(math.Clamp(readyAt - os.time(), 0, 63), 6)
            net.WriteBool(tostring(row.owner_steamid64 or "") == ply:SteamID64())
        end
    net.Send(ply)
end

net.Receive("SSRP_Crafting_OutputsRequest", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    SendWorkbenchOutputs(ply)
end)

net.Receive("SSRP_Crafting_OutputClaim", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not HasCraftingJob(ply) then return end
    local outputID = net.ReadUInt(32)
    local bench = GetPlayerWorkbench(ply)
    if not IsValid(bench) or outputID <= 0 then return end
    local row = QueryRow("SELECT * FROM ssrp_crafting_outputs WHERE id = " .. outputID ..
        " AND workbench_id = " .. math.floor(bench:GetWorkbenchID()) .. " AND owner_steamid64 = " .. sql.SQLStr(ply:SteamID64()))
    if not row then Notify(ply, "Этот заказ принадлежит другому оружейнику или уже забран.") SendWorkbenchOutputs(ply) return end
    if (tonumber(row.ready_at) or 0) > os.time() then Notify(ply, "Заказ ещё обрабатывается.") return end

    local class = tostring(row.item_class or "")
    local data = BLUEPRINTS[class] or AMMO_BLUEPRINTS[class]
    if not data then Notify(ply, "Не удалось определить изделие. Заказ оставлен на полке.") return end
    if data.kind == "attachment" then
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or not weapon.Primary or not weapon.Primary.Ammo
            or weapon.Primary.Ammo == "" or weapon.Primary.Ammo == "none" then
            Notify(ply, "Возьми в руки совместимое оружие, затем забери обвес с полки.")
            return
        end
        if not hg or not isfunction(hg.AddAttachmentForce) then
            Notify(ply, "Система креплений Z-City сейчас недоступна; обвес остался на полке.")
            return
        end
    elseif data.kind == "ammo" then
        -- Свободное место проверяется после временного удаления записи; если партия
        -- не помещается целиком, выданные патроны откатываются, а заказ возвращается.
    elseif ply:HasWeapon(class) then
        Notify(ply, "У тебя уже есть это оружие. Заказ остался на полке.")
        return
    end

    -- Сначала атомарно забираем строку с полки. Повторный пакет с тем же ID уже
    -- не сможет выдать вторую копию, даже если клиент отправит его дважды.
    sql.Query("DELETE FROM ssrp_crafting_outputs WHERE id = " .. outputID .. " AND workbench_id = " ..
        math.floor(bench:GetWorkbenchID()) .. " AND owner_steamid64 = " .. sql.SQLStr(ply:SteamID64()))
    if QueryRow("SELECT id FROM ssrp_crafting_outputs WHERE id = " .. outputID) then
        Notify(ply, "Не удалось заблокировать заказ. Попробуй ещё раз.")
        return
    end

    local function RestoreOutput()
        sql.Query("INSERT OR IGNORE INTO ssrp_crafting_outputs (id, craft_token, workbench_id, owner_steamid64, owner_name, item_class, item_name, ready_at, created_at) VALUES (" ..
            outputID .. ", " .. sql.SQLStr(row.craft_token or ("restored:" .. outputID)) .. ", " ..
            math.floor(tonumber(row.workbench_id) or bench:GetWorkbenchID()) .. ", " ..
            sql.SQLStr(row.owner_steamid64 or ply:SteamID64()) .. ", " .. sql.SQLStr(row.owner_name or ply:Nick()) .. ", " ..
            sql.SQLStr(class) .. ", " .. sql.SQLStr(row.item_name or data.name) .. ", " ..
            math.floor(tonumber(row.ready_at) or os.time()) .. ", " .. math.floor(tonumber(row.created_at) or os.time()) .. ")")
    end

    if data.kind == "attachment" then
        local weapon = ply:GetActiveWeapon()
        local ok, result = pcall(hg.AddAttachmentForce, ply, weapon, data.attachment)
        if not ok or result == false then
            RestoreOutput()
            Notify(ply, "Z-City не смог установить этот обвес на выбранное оружие; заказ возвращён на полку.")
            return
        end
        Notify(ply, data.name .. " установлен на " .. (weapon.PrintName or weapon:GetClass()) .. ".")
    elseif data.kind == "ammo" then
        local given = ply:GiveAmmo(data.rounds, data.ammoType, false)
        if given ~= data.rounds then
            if given and given > 0 then ply:RemoveAmmo(given, data.ammoType) end
            RestoreOutput()
            Notify(ply, "Нет места под эту партию патронов. Освободи запас и попробуй снова.")
            return
        end
        Notify(ply, data.name .. " забраны: " .. data.rounds .. " шт.")
    else
        local weapon = ply:Give(class, true)
        if not IsValid(weapon) and not ply:HasWeapon(class) then
            RestoreOutput()
            Notify(ply, "Не удалось выдать оружие; заказ возвращён на полку.")
            return
        end
        Notify(ply, data.name .. " забрано с полки верстака.")
    end
    SendWorkbenchOutputs(ply)
end)

function SSRP_SendCraftingBlueprints(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not HasCraftingJob(ply) or not GetPlayerWorkbench(ply) then
        Notify(ply, "Чертежи доступны оружейнику только у верстака.")
        return
    end
    SendBlueprints(ply)
end

function SSRP_OpenCraftingShop(ply, entity)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not IsValid(entity) or entity:GetClass() ~= STORAGE_CLASS then return end

    if not HasCraftingJob(ply) then
        Notify(ply, "Только оружейник может работать у верстака.")
        return
    end

    if ply:GetPos():DistToSqr(entity:GetPos()) > SHOP_ENTITY_DISTANCE then return end
    EnsureWorkbenchID(entity)
    ply.SSRP_CraftingWorkbench = entity
    SendShop(ply)
end

function SSRP_OpenPartsVendor(ply, entity)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    if not IsValid(entity) or entity:GetClass() ~= "ssrp_crafting_parts_vendor" then return end
    if not HasCraftingJob(ply) then Notify(ply, "Поставщик работает только с оружейниками.") return end
    if ply:GetPos():DistToSqr(entity:GetPos()) > 150 * 150 then return end
    ply.SSRP_CraftingPartsVendor = entity
    SendPartsData(ply, 0)
end

local function PurchaseFeedback(ply, success, text)
    if not IsValid(ply) then return end

    net.Start("SSRP_Crafting_PurchaseFeedback")
        net.WriteBool(success)
        net.WriteString(text)
    net.Send(ply)
end

net.Receive("SSRP_Crafting_ShopAction", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsNearShop(ply) then return end
    if (shopCooldown[ply] or 0) > CurTime() then return end

    shopCooldown[ply] = CurTime() + 0.2

    local class = net.ReadString()
    local data = BLUEPRINTS[class] or AMMO_BLUEPRINTS[class]

    if not data then return end
    if data.kind ~= "ammo" and data.kind ~= "attachment" and not weapons.GetStored(class) then
        Notify(ply, "Это оружие не найдено на сервере.")
        return
    end
    if data.kind == "attachment" and (not hg or not isfunction(hg.AddAttachmentForce)) then
        Notify(ply, "Чертежи обвесов требуют загруженную систему креплений Z-City.")
        return
    end

    local blueprints = LoadBlueprints(ply)
    local current = blueprints[class] or 0

    if current > 0 then
        Notify(ply, "Этот чертёж уже изучен.")
        return
    end

    blueprints[class] = 1
    SaveBlueprints(ply, blueprints)
    local message = "Чертёж изучен бесплатно и сохранён: " .. data.name .. "."
    Notify(ply, message)
    PurchaseFeedback(ply, true, message)
    SendShop(ply)
end)

net.Receive("SSRP_Crafting_PartsRequest", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    SendPartsData(ply, net.ReadUInt(2))
end)

net.Receive("SSRP_Crafting_PartsPurchase", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not HasCraftingJob(ply) then return end
    if (shopCooldown[ply] or 0) > CurTime() then return end
    shopCooldown[ply] = CurTime() + 0.2
    local partID = net.ReadString()
    local amount = math.Clamp(net.ReadUInt(4), 1, 10)
    local part = PARTS[partID]
    local atVendor = false
    for _, vendor in ipairs(ents.FindByClass("ssrp_crafting_parts_vendor")) do
        if IsValid(vendor) and ply:GetPos():DistToSqr(vendor:GetPos()) <= 150 * 150 then atVendor = true break end
    end
    if not atVendor or not part then return end
    if GetPersonalPartAmount(ply, partID) + amount > 9999 then
        Notify(ply, "В личном запасе недостаточно места для этой партии.")
        SendPartsData(ply, 0)
        return
    end
    local total = part.price * amount
    if GetMoney(ply) < total then
        Notify(ply, "Недостаточно денег для покупки деталей.")
        SendPartsData(ply, 0)
        return
    end
    if not TakeMoney(ply, total, "crafting_parts_purchase") then
        Notify(ply, "Не удалось списать деньги за детали.")
        return
    end
    SetPersonalPartAmount(ply, partID, GetPersonalPartAmount(ply, partID) + amount)
    Notify(ply, "Куплено: " .. part.name .. " ×" .. amount .. ". Загрузи их на верстак.")
    PurchaseFeedback(ply, true, "Детали добавлены в личный запас.")
    SendPartsData(ply, 0)
end)

net.Receive("SSRP_Crafting_DepositParts", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not IsNearShop(ply) then return end
    local partID = net.ReadString()
    local amount = math.Clamp(net.ReadUInt(4), 1, 10)
    local part, bench = PARTS[partID], GetPlayerWorkbench(ply)
    if not part or not IsValid(bench) then return end
    local personal = GetPersonalPartAmount(ply, partID)
    local workbenchID = bench:GetWorkbenchID()
    local room = math.max(0, 9999 - GetPartAmount(workbenchID, partID))
    local moved = math.min(amount, personal, room)
    if moved <= 0 then
        Notify(ply, room == 0 and "Этот вид деталей на верстаке заполнен. Забери часть со склада или израсходуй её." or "В личном запасе недостаточно деталей.")
        SendPartsData(ply, 2)
        return
    end
    if not AddPartAmount(workbenchID, partID, moved) then SendPartsData(ply, 2) return end
    SetPersonalPartAmount(ply, partID, personal - moved)
    Notify(ply, "Загружено на верстак: " .. part.name .. " ×" .. moved .. ".")
    SendPartsData(ply, 2)
end)

net.Receive("SSRP_Crafting_WithdrawParts", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not IsNearShop(ply) then return end
    local partID = net.ReadString()
    local part = PARTS[partID]
    local bench = GetPlayerWorkbench(ply)
    if not part or not IsValid(bench) then return end

    local workbenchID = bench:GetWorkbenchID()
    local stock = GetPartAmount(workbenchID, partID)
    local personal = GetPersonalPartAmount(ply, partID)
    local amount = math.min(stock, 9999 - personal)
    if amount <= 0 then
        Notify(ply, personal >= 9999 and "Личный запас этой детали тоже заполнен." or "На складе этой детали нет.")
        SendPartsData(ply, 1)
        return
    end

    sql.Query("INSERT OR REPLACE INTO ssrp_crafting_workbench_parts (workbench_id, part_id, amount) VALUES (" ..
        math.floor(tonumber(workbenchID) or 0) .. ", " .. sql.SQLStr(partID) .. ", " .. (stock - amount) .. ")")
    SetPersonalPartAmount(ply, partID, personal + amount)
    Notify(ply, "В личный запас перемещено: " .. part.name .. " ×" .. amount .. ".")
    SendPartsData(ply, 1)
end)

net.Receive("SSRP_Crafting_TransferAllParts", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not IsNearShop(ply) then return end
    local direction = net.ReadUInt(1) -- 0: личный запас -> верстак; 1: верстак -> личный запас
    local bench = GetPlayerWorkbench(ply)
    if not IsValid(bench) then return end

    local movedTypes, movedItems = 0, 0
    for partID, part in pairs(PARTS) do
        local personal = GetPersonalPartAmount(ply, partID)
        local stock = GetPartAmount(bench:GetWorkbenchID(), partID)
        local amount
        if direction == 0 then
            amount = math.min(personal, math.max(0, 2000000000 - stock))
            if amount > 0 then
                if AddPartAmount(bench:GetWorkbenchID(), partID, amount) then
                    SetPersonalPartAmount(ply, partID, personal - amount)
                else
                    amount = 0
                end
            end
        else
            amount = math.min(stock, math.max(0, 9999 - personal))
            if amount > 0 then
                sql.Query("INSERT OR REPLACE INTO ssrp_crafting_workbench_parts (workbench_id, part_id, amount) VALUES (" ..
                    math.floor(tonumber(bench:GetWorkbenchID()) or 0) .. ", " .. sql.SQLStr(partID) .. ", " .. (stock - amount) .. ")")
                SetPersonalPartAmount(ply, partID, personal + amount)
            end
        end
        if amount and amount > 0 then movedTypes = movedTypes + 1 movedItems = movedItems + amount end
    end

    if movedItems == 0 then
        Notify(ply, direction == 0 and "В личном запасе нет деталей или на складе нет места." or "На складе нет деталей или личный инвентарь заполнен.")
    else
        if direction == 0 then
            Notify(ply, "Детали загружены в верстак: " .. movedItems .. " шт., " .. movedTypes .. " видов. Открыт склад верстака.")
        else
            Notify(ply, "Детали возвращены в личный запас: " .. movedItems .. " шт. (" .. movedTypes .. " видов). Открыт личный инвентарь.")
        end
    end
    -- После загрузки показываем именно склад, куда попали детали;
    -- после изъятия — личный запас игрока.
    SendShop(ply)
end)

net.Receive("SSRP_Crafting_TransferPart", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not IsNearShop(ply) then return end
    if (shopCooldown[ply] or 0) > CurTime() then return end
    shopCooldown[ply] = CurTime() + 0.15

    local partID = net.ReadString()
    local direction = net.ReadUInt(1) -- 0: в верстак, 1: из верстака
    if not PARTS[partID] then return end

    local bench = GetPlayerWorkbench(ply)
    if not IsValid(bench) then return end
    local workbenchID = bench:GetWorkbenchID()
    local personal = GetPersonalPartAmount(ply, partID)
    local stock = GetPartAmount(workbenchID, partID)
    local moved = 0

    if direction == 0 then
        moved = math.min(personal, math.max(0, 9999 - stock))
        if moved > 0 and AddPartAmount(workbenchID, partID, moved) then
            SetPersonalPartAmount(ply, partID, personal - moved)
        else
            moved = 0
        end
    else
        moved = math.min(stock, math.max(0, 9999 - personal))
        if moved > 0 then
            sql.Query("INSERT OR REPLACE INTO ssrp_crafting_workbench_parts (workbench_id, part_id, amount) VALUES (" ..
                workbenchID .. ", " .. sql.SQLStr(partID) .. ", " .. (stock - moved) .. ")")
            if GetPartAmount(workbenchID, partID) == stock - moved then
                SetPersonalPartAmount(ply, partID, personal + moved)
            else
                moved = 0
            end
        end
    end

    if moved <= 0 then
        Notify(ply, direction == 0 and "В личном запасе нет этой детали или склад заполнен." or "На складе нет этой детали или личный запас заполнен.")
    else
        Notify(ply, (direction == 0 and "На верстак загружено: " or "В личный запас перемещено: ") .. PARTS[partID].name .. " ×" .. moved .. ".")
    end
    SendShop(ply)
end)

net.Receive("SSRP_Crafting_VendorOpen", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not HasCraftingJob(ply) then return end
    local vendor = net.ReadEntity()
    if not IsValid(vendor) or vendor:GetClass() ~= "ssrp_crafting_parts_vendor" or ply:GetPos():DistToSqr(vendor:GetPos()) > 150 * 150 then return end
    SendPartsData(ply, 0)
end)

net.Receive("SSRP_Crafting_BlueprintsV2", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not HasCraftingJob(ply) or not GetPlayerWorkbench(ply) then
        Notify(ply, "Подойди к оружейному верстаку, чтобы посмотреть чертежи.")
        return
    end
    SendBlueprints(ply)
end)

-- Совместимость с уже выданной старой версией Чертежной.
net.Receive("SSRP_Crafting_Blueprints", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not HasCraftingJob(ply) or not GetPlayerWorkbench(ply) then
        Notify(ply, "Подойди к оружейному верстаку, чтобы посмотреть чертежи.")
        return
    end
    SendBlueprints(ply)
end)

local function NewTask(session)
    local taskType = ((session.step - 1) % 4) + 1
    local task = {
        type = taskType,
        token = math.random(100000, 2147483647),
        a = 0,
        b = 0,
        c = 0,
        text = "",
        minTime = 0.45
    }

    if taskType == 1 then
        task.a = math.random(1, 9)
        task.b = math.random(5, 8)
        task.text = "ПОДГОНКА СПУСКА: нажми отмеченную клавишу ровно " .. task.b .. " раз"
    elseif taskType == 2 then
        for _ = 1, 8 do
            task.text = task.text .. tostring(math.random(0, 9))
        end
    elseif taskType == 3 then
        task.a = math.random(1, 4)
        task.b = math.random(4, 6)
        task.text = "УСТАНОВКА ФИКСИРУЮЩЕГО ШТИФТА: выбери нужную метку " .. task.b .. " раз"
    elseif taskType == 4 then
        local keys = {"W", "A", "S", "D"}
        for _ = 1, 8 do
            task.text = task.text .. keys[math.random(1, #keys)]
        end
    elseif taskType == 5 then
        -- Четыре детали нужно собрать и разложить по своим местам.
        task.text = "КОМПОНОВКА УЗЛОВ: расставь детали по местам"
    elseif taskType == 6 then
        task.a = math.random(0, 359)
        task.b = 3
        task.text = "НАСТРОЙКА ПРИЦЕЛА: выставь угол " .. task.a .. "° и зафиксируй трижды"
    elseif taskType == 7 then
        task.a = math.Rand(0.2, 0.8)
        task.b = math.Rand(0.25, 0.75)
        task.c = 3
        task.text = "ЦЕНТРОВКА МУШКИ: перетащи деталь в контрольную зону трижды"
    elseif taskType == 8 then
        for _ = 1, 5 do
            task.text = task.text .. tostring(math.random(1, 3))
        end
    elseif taskType == 9 then
        task.a = math.random(10, 14)
        task.text = "КРЕПЁЖ: затяни " .. task.a .. " винтов до упора"
    elseif taskType == 10 then
        for _ = 1, 6 do
            task.text = task.text .. tostring(math.random(1, 3))
        end
    end

    session.task = task
    session.stepStarted = CurTime()

    net.Start("SSRP_Crafting_TaskV2")
        net.WriteUInt(session.id, 32)
        net.WriteUInt(session.step, 4)
        net.WriteUInt(task.type, 4)
        net.WriteUInt(task.token, 32)
        net.WriteFloat(task.a)
        net.WriteFloat(task.b)
        net.WriteFloat(task.c)
        net.WriteFloat(task.minTime)
        net.WriteString(task.text)
    net.Send(session.ply)
end

local function FinishCrafting(ply, session, processingSeconds)
    local blueprints = LoadBlueprints(ply)
    local count = blueprints[session.class] or 0

    if count <= 0 then
        Notify(ply, "Доступ к этому чертежу отозван.")
        return false
    end

    local data = BLUEPRINTS[session.class] or AMMO_BLUEPRINTS[session.class]
    if not data then return false end
    local owner = ply:SteamID64()
    local token = owner .. ":" .. tostring(session.id) .. ":" .. tostring(os.time()) .. ":" .. tostring(math.random(100000, 999999))
    sql.Query("INSERT OR IGNORE INTO ssrp_crafting_outputs (craft_token, workbench_id, owner_steamid64, owner_name, item_class, item_name, ready_at, created_at) VALUES (" ..
        sql.SQLStr(token) .. ", " .. math.floor(session.workbenchID) .. ", " .. sql.SQLStr(owner) .. ", " ..
        sql.SQLStr(string.sub(ply:Nick(), 1, 64)) .. ", " .. sql.SQLStr(session.class) .. ", " ..
        sql.SQLStr(data.name) .. ", " .. (os.time() + math.max(1, math.floor(tonumber(processingSeconds) or 20))) .. ", " .. os.time() .. ")")
    local row = QueryRow("SELECT id FROM ssrp_crafting_outputs WHERE craft_token = " .. sql.SQLStr(token))
    if not row or not tonumber(row.id) then
        Notify(ply, "Не удалось сохранить заказ на полке. Детали возвращены.")
        return false
    end
    session.outputID = tonumber(row.id)
    session.outputName = data.name
    return true
end

local function BeginWorkbenchProcessing(ply, session, duration)
    duration = math.max(1, tonumber(duration) or 20)
    local soundPatch
    if IsValid(session.workbench) then
        soundPatch = CreateSound(session.workbench, "ambient/machines/machine3.wav")
        if soundPatch then soundPatch:PlayEx(0.42, 100) end
    end

    net.Start("SSRP_Crafting_ProcessingV2")
        net.WriteFloat(duration)
    net.Send(ply)

    timer.Simple(duration, function()
        if soundPatch then soundPatch:FadeOut(0.6) end
        local finished = QueryRow("SELECT id FROM ssrp_crafting_outputs WHERE id = " .. math.floor(session.outputID or 0))
        if not finished or not IsValid(ply) then return end
        Notify(ply, "Готово: " .. tostring(session.outputName or "заказ") .. ". Изделие ждёт на полке верстака.")
        net.Start("SSRP_Crafting_ResultV2")
            net.WriteBool(true)
            net.WriteString("Изделие готово и сохранено на полке верстака. Открой «Готовые заказы» и забери его.")
        net.Send(ply)
    end)
end

local function RefundReservedParts(session)
    if not session or not session.partsReserved then return end
    local recipe = BLUEPRINTS[session.class] or AMMO_BLUEPRINTS[session.class]
    if recipe and session.workbenchID then ChangeRecipeParts(session.workbenchID, recipe.parts, 1) end
    session.partsReserved = false
end

net.Receive("SSRP_Crafting_Start", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
    local workbench = GetPlayerWorkbench(ply)
    if not HasCraftingJob(ply) or not IsValid(workbench) then
        Notify(ply, "Собирать оружие можно только оружейнику у верстака.")
        return
    end

    -- Если предыдущая сборка зависла или осталась после обновления аддона,
    -- сбрасываем её и разрешаем начать новую.
    if sessions[ply] then
        RefundReservedParts(sessions[ply])
        sessions[ply] = nil
    end

    local class = net.ReadString()
    local data = BLUEPRINTS[class] or AMMO_BLUEPRINTS[class]
    local blueprints = LoadBlueprints(ply)

    if not data or not blueprints[class] or blueprints[class] <= 0 then
        Notify(ply, "У тебя нет этого чертежа.")
        return
    end

    if data.kind ~= "ammo" and data.kind ~= "attachment" and not weapons.GetStored(class) then
        Notify(ply, "Оружие этого чертежа не найдено на сервере.")
        return
    end
    if data.kind == "attachment" and (not hg or not isfunction(hg.AddAttachmentForce)) then
        Notify(ply, "Система креплений Z-City не загружена; чертёж сейчас недоступен.")
        return
    end

    local hasParts, missingPart = HasRecipeParts(workbench:GetWorkbenchID(), data.parts)
    if not hasParts then
        local part = PARTS[missingPart]
        local missingAmount = math.max(0, (data.parts[missingPart] or 0) - GetPartAmount(workbench:GetWorkbenchID(), missingPart))
        Notify(ply, "На складе не хватает: " .. tostring(part and part.name or missingPart) .. " ×" .. missingAmount .. ".")
        return
    end

    local activeOrder = QueryRow("SELECT id FROM ssrp_crafting_outputs WHERE workbench_id = " .. math.floor(workbench:GetWorkbenchID()) ..
        " AND ready_at > " .. os.time() .. " LIMIT 1")
    if activeOrder then
        Notify(ply, "Верстак занят: дождись завершения текущего заказа.")
        return
    end
    local outputCount = QueryRow("SELECT COUNT(*) AS amount FROM ssrp_crafting_outputs WHERE workbench_id = " .. math.floor(workbench:GetWorkbenchID()))
    if tonumber(outputCount and outputCount.amount or 0) >= 100 then
        Notify(ply, "Полка заполнена. Забери готовые изделия перед новым заказом.")
        return
    end

    ChangeRecipeParts(workbench:GetWorkbenchID(), data.parts, -1)

    nextSessionID = (nextSessionID + 1) % 2147483647
    if nextSessionID <= 0 then nextSessionID = 1 end

    sessions[ply] = {
        ply = ply,
        id = nextSessionID,
        class = class,
        workbench = workbench,
        workbenchID = workbench:GetWorkbenchID(),
        partsReserved = true,
        step = 1,
        stepStarted = CurTime()
    }

    if data.kind == "ammo" then
        local session = sessions[ply]
        local success = FinishCrafting(ply, session, 40)
        if success then
            session.partsReserved = false
            sessions[ply] = nil
            BeginWorkbenchProcessing(ply, session, 40)
        else
            RefundReservedParts(session)
            sessions[ply] = nil
            net.Start("SSRP_Crafting_ResultV2")
                net.WriteBool(false)
                net.WriteString("Не удалось сохранить заказ; компоненты возвращены на склад.")
            net.Send(ply)
        end
        return
    end

    NewTask(sessions[ply])
end)

local function ValidateTask(session, answer, a, b, c)
    local task = session.task
    if not task then return false end
    if task.type == 1 then
        return tonumber(answer) == math.floor(task.a)
            and tonumber(a) >= math.floor(task.b)
    elseif task.type == 2 then
        return answer == task.text
    elseif task.type == 3 then
        return tonumber(answer) == math.floor(task.a)
            and tonumber(a) >= math.floor(task.b)
    elseif task.type == 4 then
        return string.upper(answer) == task.text
    elseif task.type == 5 then
        -- Для нового этапа правильный результат — собрать детали 1, 2, 3, 4.
        return answer == "1234" or answer == task.text
    elseif task.type == 6 then
        local attempts = tonumber(answer) or 0
        local angle = tonumber(a) or -999
        local difference = math.abs((angle - task.a + 180) % 360 - 180)
        return attempts >= math.floor(task.b) and difference <= 14
    elseif task.type == 7 then
        local attempts = tonumber(answer) or 0
        local x = tonumber(a) or -999
        local y = tonumber(b) or -999
        return attempts >= math.floor(task.c)
            and math.sqrt((x - task.a) ^ 2 + (y - task.b) ^ 2) <= 0.12
    elseif task.type == 8 then
        return answer == task.text
    elseif task.type == 9 then
        return tonumber(answer) == math.floor(task.a)
    elseif task.type == 10 then
        return answer == task.text
    end

    return false
end

net.Receive("SSRP_Crafting_StepV2", function(_, ply)
    local session = sessions[ply]
    if not session then return end

    if not HasCraftingJob(ply) or not IsValid(session.workbench)
        or ply:GetPos():DistToSqr(session.workbench:GetPos()) > SHOP_ENTITY_DISTANCE then
        RefundReservedParts(session)
        sessions[ply] = nil
        Notify(ply, "Сборка остановлена: нужно оставаться у верстака оружейника.")
        net.Start("SSRP_Crafting_ResultV2")
            net.WriteBool(false)
            net.WriteString("Подойди к верстаку и начни этап заново. Чертёж сохранён.")
        net.Send(ply)
        return
    end

    local sessionID = net.ReadUInt(32)
    local step = net.ReadUInt(4)
    local token = net.ReadUInt(32)
    local answer = net.ReadString()
    local a = net.ReadFloat()
    local b = net.ReadFloat()
    local c = net.ReadFloat()

    if sessionID ~= session.id or step ~= session.step or token ~= session.task.token then
        return
    end

    if session.processing then
        return
    end

    local valid = ValidateTask(session, answer, a, b, c)

    if not valid then
        RefundReservedParts(session)
        net.Start("SSRP_Crafting_ResultV2")
            net.WriteBool(false)
            net.WriteString("Мини-игра провалена. Чертёж сохранён.")
        net.Send(ply)
        sessions[ply] = nil
        return
    end

    session.step = session.step + 1

    if session.step > 4 then
        local success = FinishCrafting(ply, session)
        if success then session.partsReserved = false else RefundReservedParts(session) end
        sessions[ply] = nil
        if success then
            BeginWorkbenchProcessing(ply, session, 20)
        else
            net.Start("SSRP_Crafting_ResultV2")
                net.WriteBool(false)
                net.WriteString("Не удалось сохранить заказ; компоненты возвращены на склад.")
            net.Send(ply)
        end
        return
    end

    -- Обработка детали отключена: после успешного этапа сразу открываем следующий.
    -- Это исключает зависание на бесконечном processing.
    session.processing = false
    session.processingUntil = nil
    NewTask(session)
end)

net.Receive("SSRP_Crafting_Cancel", function(_, ply)
    local session = sessions[ply]
    if session then
        timer.Remove("SSRP_Crafting_NextStep_" .. session.id)
        RefundReservedParts(session)
        sessions[ply] = nil
        Notify(ply, "Сборка отменена. Чертёж сохранён.")
    end
end)

hook.Add("PlayerDeath", "SSRP_Crafting_CancelOnDeath", function(ply)
    if sessions[ply] then
        timer.Remove("SSRP_Crafting_NextStep_" .. sessions[ply].id)
        RefundReservedParts(sessions[ply])
    end
    sessions[ply] = nil
end)

hook.Add("PlayerDisconnected", "SSRP_Crafting_Cleanup", function(ply)
    shopCooldown[ply] = nil
    ply.SSRP_CraftingWorkbench = nil
    if sessions[ply] then
        timer.Remove("SSRP_Crafting_NextStep_" .. sessions[ply].id)
        RefundReservedParts(sessions[ply])
    end
    sessions[ply] = nil
end)

local function SpawnWorkbench(position, angle, id)
    local entity = ents.Create(STORAGE_CLASS)
    if not IsValid(entity) then return end
    local storageID = math.floor(tonumber(id) or 0)
    entity:SetPos(position)
    entity:SetAngles(angle)
    entity:Spawn()
    entity:SetWorkbenchID(storageID)
    entity:CallOnRemove("SSRP_Crafting_ClearStoredContents", function()
        ClearWorkbenchStorage(storageID)
    end)
    return entity
end

hook.Add("InitPostEntity", "SSRP_Crafting_RestoreWorkbenches", function()
    -- Remove the previous fixed-position NPC from the old version.
    for _, old in ipairs(ents.FindByClass("ssrp_crafting_npc")) do old:Remove() end
    -- Workbenches are temporary map objects. Older versions saved their
    -- positions and recreated them on every server start; remove any map-saved
    -- copies and clear their stored materials and ready orders.
    local storedBenches = sql.Query("SELECT id FROM ssrp_crafting_workbenches WHERE map_name = " .. sql.SQLStr(game.GetMap())) or {}
    for _, row in ipairs(storedBenches) do ClearWorkbenchStorage(row.id) end
    for _, bench in ipairs(ents.FindByClass(STORAGE_CLASS)) do
        ClearWorkbenchStorage(bench:GetWorkbenchID())
        bench:Remove()
    end
    timer.Simple(1, function()
        local vendorRows = sql.Query("SELECT id, pos_x, pos_y, pos_z, ang_p, ang_y, ang_r FROM ssrp_crafting_parts_vendors WHERE map_name = " .. sql.SQLStr(game.GetMap())) or {}
        for _, row in ipairs(vendorRows) do
            local vendor = ents.Create("ssrp_crafting_parts_vendor")
            if IsValid(vendor) then
                vendor:SetPos(Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0))
                vendor:SetAngles(Angle(tonumber(row.ang_p) or 0, tonumber(row.ang_y) or 0, tonumber(row.ang_r) or 0))
                vendor:Spawn()
                vendor:SetVendorID(tonumber(row.id) or 0)
            end
        end
    end)
end)

local function IsWorkbenchAdmin(ply)
    if not IsValid(ply) or ply:IsAdmin() then return true end
    ply:ChatPrint("Ставить оружейные верстаки может только администратор.")
    return false
end

concommand.Add("ssrp_crafting_spawn_workbench", function(ply)
    if not IsWorkbenchAdmin(ply) then return end
    if not IsValid(ply) then print("[SSRP Crafting] Выполните команду из игры, наведясь на место установки.") return end
    local trace = ply:GetEyeTrace()
    if not trace.Hit then ply:ChatPrint("Наведитесь на пол в месте установки верстака.") return end
    local position = trace.HitPos + Vector(0, 0, 3)
    local floor = util.TraceLine({start = position + Vector(0, 0, 96), endpos = position - Vector(0, 0, 384), filter = ply})
    if floor.Hit and floor.HitNormal.z > 0.7 then position = floor.HitPos + Vector(0, 0, 3) end
    local angle = Angle(0, ply:EyeAngles().y, 0)
    local mapName = sql.SQLStr(game.GetMap())
    local savedRows = sql.Query("SELECT id FROM ssrp_crafting_workbenches WHERE map_name = " .. mapName .. " ORDER BY id") or {}
    local activeIDs = {}
    for _, activeBench in ipairs(ents.FindByClass(STORAGE_CLASS)) do
        activeIDs[math.floor(tonumber(activeBench:GetWorkbenchID()) or 0)] = true
    end

    -- Reuse a storage ID without reusing its old world position. This keeps
    -- the warehouse and ready orders available when staff place a new bench.
    local workbenchID
    for _, row in ipairs(savedRows) do
        local candidateID = math.floor(tonumber(row.id) or 0)
        if candidateID > 0 and not activeIDs[candidateID] then
            workbenchID = candidateID
            break
        end
    end

    if workbenchID then
        sql.Query("UPDATE ssrp_crafting_workbenches SET pos_x = " .. position.x .. ", pos_y = " .. position.y ..
            ", pos_z = " .. position.z .. ", ang_p = " .. angle.p .. ", ang_y = " .. angle.y .. ", ang_r = " ..
            angle.r .. " WHERE id = " .. workbenchID .. " AND map_name = " .. mapName)
    else
        sql.Query("INSERT INTO ssrp_crafting_workbenches (map_name, pos_x, pos_y, pos_z, ang_p, ang_y, ang_r) VALUES (" ..
            mapName .. ", " .. position.x .. ", " .. position.y .. ", " .. position.z .. ", " .. angle.p .. ", " .. angle.y .. ", " .. angle.r .. ")")
        local row = QueryRow("SELECT last_insert_rowid() AS id")
        workbenchID = math.floor(tonumber(row and row.id) or 0)
    end

    local entity = SpawnWorkbench(position, angle, workbenchID)
    if not IsValid(entity) then ply:ChatPrint("Не удалось создать верстак.") return end
    ply:ChatPrint("Оружейный верстак установлен до перезапуска сервера. ID склада: " .. entity:GetWorkbenchID() .. ".")
end)

concommand.Add("ssrp_crafting_remove_workbench", function(ply, _, args)
    if not IsWorkbenchAdmin(ply) then return end
    local id = tonumber(args[1])
    if id then
        id = math.floor(id)
        for _, entity in ipairs(ents.FindByClass(STORAGE_CLASS)) do
            if entity:GetWorkbenchID() == id then entity:Remove() end
        end
        ClearWorkbenchStorage(id)
        sql.Query("DELETE FROM ssrp_crafting_workbenches WHERE id = " .. id .. " AND map_name = " .. sql.SQLStr(game.GetMap()))
        if IsValid(ply) then ply:ChatPrint("Верстак " .. id .. " удалён.") end
        return
    end
    if not IsValid(ply) then print("Использование: ssrp_crafting_remove_workbench <ID>") return end
    local target = ply:GetEyeTrace().Entity
    if not IsValid(target) or target:GetClass() ~= STORAGE_CLASS then
        ply:ChatPrint("Наведитесь на верстак или укажите ID: ssrp_crafting_remove_workbench <ID>.")
        return
    end
    local benchID = target:GetWorkbenchID()
    target:Remove()
    ClearWorkbenchStorage(benchID)
    if benchID and benchID > 0 then
        sql.Query("DELETE FROM ssrp_crafting_workbenches WHERE id = " .. math.floor(benchID) .. " AND map_name = " .. sql.SQLStr(game.GetMap()))
    end
    ply:ChatPrint("Оружейный верстак удалён.")
end)

local function SpawnPartsVendor(position, angle, id)
    local vendor = ents.Create("ssrp_crafting_parts_vendor")
    if not IsValid(vendor) then return end
    vendor:SetPos(position)
    vendor:SetAngles(angle)
    vendor:Spawn()
    vendor:SetVendorID(tonumber(id) or 0)
    return vendor
end

concommand.Add("ssrp_crafting_spawn_parts_vendor", function(ply)
    if not IsWorkbenchAdmin(ply) then return end
    if not IsValid(ply) then print("[SSRP Crafting] Выполните команду из игры, наведясь на место поставщика.") return end
    local trace = ply:GetEyeTrace()
    if not trace.Hit then ply:ChatPrint("Наведитесь на пол в месте установки поставщика.") return end
    local position = trace.HitPos + Vector(0, 0, 2)
    local floor = util.TraceLine({start = position + Vector(0, 0, 96), endpos = position - Vector(0, 0, 384), filter = ply})
    if floor.Hit and floor.HitNormal.z > 0.7 then position = floor.HitPos + Vector(0, 0, 2) end
    local angle = Angle(0, ply:EyeAngles().y, 0)
    local vendor = SpawnPartsVendor(position, angle, 0)
    if not IsValid(vendor) then ply:ChatPrint("Не удалось создать поставщика.") return end
    sql.Query("INSERT INTO ssrp_crafting_parts_vendors (map_name, pos_x, pos_y, pos_z, ang_p, ang_y, ang_r) VALUES (" ..
        sql.SQLStr(game.GetMap()) .. ", " .. position.x .. ", " .. position.y .. ", " .. position.z .. ", " .. angle.p .. ", " .. angle.y .. ", " .. angle.r .. ")")
    local row = QueryRow("SELECT last_insert_rowid() AS id")
    vendor:SetVendorID(tonumber(row and row.id) or 0)
    ply:ChatPrint("Поставщик деталей установлен и сохранён. ID: " .. vendor:GetVendorID() .. ".")
end)

concommand.Add("ssrp_crafting_remove_parts_vendor", function(ply, _, args)
    if not IsWorkbenchAdmin(ply) then return end
    local id = tonumber(args[1])
    if id then
        id = math.floor(id)
        for _, vendor in ipairs(ents.FindByClass("ssrp_crafting_parts_vendor")) do
            if vendor:GetVendorID() == id then vendor:Remove() end
        end
        sql.Query("DELETE FROM ssrp_crafting_parts_vendors WHERE id = " .. id .. " AND map_name = " .. sql.SQLStr(game.GetMap()))
        if IsValid(ply) then ply:ChatPrint("Поставщик " .. id .. " удалён.") end
        return
    end
    if not IsValid(ply) then print("Использование: ssrp_crafting_remove_parts_vendor <ID>") return end
    local target = ply:GetEyeTrace().Entity
    if not IsValid(target) or target:GetClass() ~= "ssrp_crafting_parts_vendor" then
        ply:ChatPrint("Наведитесь на поставщика или укажите его ID.")
        return
    end
    local vendorID = target:GetVendorID()
    target:Remove()
    sql.Query("DELETE FROM ssrp_crafting_parts_vendors WHERE id = " .. math.floor(vendorID) .. " AND map_name = " .. sql.SQLStr(game.GetMap()))
    ply:ChatPrint("Поставщик деталей удалён.")
end)

print("[SSRP Crafting] Blueprint shop and crafting system loaded.")

