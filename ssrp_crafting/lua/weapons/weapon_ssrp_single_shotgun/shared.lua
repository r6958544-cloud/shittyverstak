SWEP.Base = "weapon_base"
SWEP.PrintName = "Однозарядное ружьё"
SWEP.Author = "SSRP Crafting"
SWEP.Instructions = "ЛКМ — выстрел, R — зарядить один патрон"
SWEP.Category = "SSRP | Оружейная мастерская"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_shotgun.mdl"
SWEP.WorldModel = "models/weapons/w_shotgun.mdl"
SWEP.HoldType = "shotgun"
SWEP.Slot = 3
SWEP.SlotPos = 8
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false

SWEP.Primary = {
    ClipSize = 1,
    DefaultClip = 1,
    Automatic = false,
    Ammo = "Buckshot",
    Delay = 1.15
}

SWEP.Secondary = {
    ClipSize = -1,
    DefaultClip = -1,
    Automatic = false,
    Ammo = "none"
}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    if self:Clip1() <= 0 then
        owner:EmitSound("Weapon_Pistol.Empty")
        return
    end

    self:SetClip1(0)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    owner:EmitSound("Weapon_Shotgun.Single", 80, 96, 1, CHAN_WEAPON)
    if SERVER then
        owner:LagCompensation(true)
        owner:FireBullets({
            Num = 8,
            Src = owner:GetShootPos(),
            Dir = owner:GetAimVector(),
            Spread = Vector(0.105, 0.105, 0),
            Tracer = 1,
            Force = 5,
            Damage = 6,
            AmmoType = "Buckshot"
        })
        owner:LagCompensation(false)
    end
end

function SWEP:Reload()
    local owner = self:GetOwner()
    if not IsValid(owner) or self:Clip1() > 0 or owner:GetAmmoCount("Buckshot") <= 0 then return end
    if self.SSRP_Reloading then return end
    self.SSRP_Reloading = true
    self:SetNextPrimaryFire(CurTime() + 1.2)
    self:SetNextSecondaryFire(CurTime() + 1.2)
    self:SendWeaponAnim(ACT_VM_RELOAD)
    owner:EmitSound("Weapon_Shotgun.Reload")
    timer.Simple(1.05, function()
        if not IsValid(self) then return end
        self.SSRP_Reloading = false
        local ply = self:GetOwner()
        if not IsValid(ply) or self:Clip1() > 0 or ply:GetAmmoCount("Buckshot") <= 0 then return end
        ply:RemoveAmmo(1, "Buckshot")
        self:SetClip1(1)
    end)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
end
