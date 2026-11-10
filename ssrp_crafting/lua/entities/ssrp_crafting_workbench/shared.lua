ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Оружейный верстак"
ENT.Category = "Профессии — оружейник"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "WorkbenchID")
end
