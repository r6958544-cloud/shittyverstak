AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local model = "models/ammoworkbench.mdl"
    if not util.IsValidModel(model) then model = "models/props_c17/FurnitureWorkbench001a.mdl" end
    if not util.IsValidModel(model) then model = "models/props_c17/FurnitureTable001a.mdl" end
    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local physics = self:GetPhysicsObject()
    if IsValid(physics) then physics:EnableMotion(false) end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not SSRP_OpenCraftingShop then return end
    SSRP_OpenCraftingShop(activator, self)
end
