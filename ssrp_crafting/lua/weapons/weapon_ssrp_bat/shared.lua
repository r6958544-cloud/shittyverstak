SWEP.Base = "weapon_base"
SWEP.PrintName = "Бейсбольная бита"
SWEP.Author = "SSRP Crafting"
SWEP.Instructions = "ЛКМ — удар"
SWEP.Category = "SSRP | Оружейная мастерская"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.HoldType = "melee2"
SWEP.Slot = 0
SWEP.SlotPos = 8
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.Primary = {
    ClipSize = -1,
    DefaultClip = -1,
    Automatic = false,
    Ammo = "none",
    Delay = 0.8
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
    self:SendWeaponAnim(ACT_VM_HITCENTER)
    owner:SetAnimation(PLAYER_ATTACK1)
    owner:EmitSound("Weapon_Crowbar.Single", 70, math.random(94, 106), 0.8, CHAN_WEAPON)

    if not SERVER then return end
    owner:LagCompensation(true)
    local trace = util.TraceHull({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 68,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        filter = owner,
        mask = MASK_SHOT_HULL
    })
    owner:LagCompensation(false)
    if not trace.Hit then return end
    self:EmitSound("Weapon_Crowbar.Melee_Hit", 70, 100, 0.8, CHAN_WEAPON)
    if IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:IsNPC() or trace.Entity:GetClass() == "prop_ragdoll") then
        local damage = DamageInfo()
        damage:SetAttacker(owner)
        damage:SetInflictor(self)
        damage:SetDamage(35)
        damage:SetDamageType(DMG_CLUB)
        damage:SetDamageForce(owner:GetAimVector() * 1800)
        damage:SetDamagePosition(trace.HitPos)
        trace.Entity:TakeDamageInfo(damage)
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
end
