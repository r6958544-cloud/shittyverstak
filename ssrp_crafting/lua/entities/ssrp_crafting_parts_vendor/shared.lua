ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Поставщик оружейных деталей"
ENT.Category = "Профессии — оружейник"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "VendorID")
end
