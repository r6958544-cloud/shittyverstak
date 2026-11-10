SWEP.PrintName = "Каталог чертежей"
SWEP.Author = "Serbia Side RP"
SWEP.Instructions = "ПКМ у оружейного верстака — открыть чертежи"
SWEP.Category = "Профессии — оружейник"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.UseHands = true
SWEP.DrawViewModel = false
SWEP.DrawWorldModel = false
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = "models/props_c17/BriefCase001a.mdl"
SWEP.HoldType = "normal"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 6
SWEP.SlotPos = 6
SWEP.AllowDrop = false

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
    if SERVER and SSRP_SendCraftingBlueprints then
        SSRP_SendCraftingBlueprints(self:GetOwner())
    end
end
