AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/Humans/Group03/male_07.mdl")
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
    self:DropToFloor()
    local sequence = self:LookupSequence("idle_subtle")
    if sequence and sequence >= 0 then self:ResetSequence(sequence) end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not SSRP_OpenPartsVendor then return end
    SSRP_OpenPartsVendor(activator, self)
end
