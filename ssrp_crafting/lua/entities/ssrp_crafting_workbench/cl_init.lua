NYUI = NYUI or {}
if not NYUI.BahnschriftFontLoaded then
    surface.CreateFont("NYUI.Title", {font = "Bahnschrift", size = 24, weight = 700, antialias = true, extended = true})
    surface.CreateFont("NYUI.Body", {font = "Bahnschrift", size = 16, weight = 500, antialias = true, extended = true})
    surface.CreateFont("NYUI.Small", {font = "Bahnschrift", size = 13, weight = 500, antialias = true, extended = true})
    surface.CreateFont("NYUI.Icon", {font = "Bahnschrift", size = 20, weight = 700, antialias = true, extended = true})
    NYUI.BahnschriftFontLoaded = true
end

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 700 * 700 then return end
    local pos = self:GetPos() + Vector(0, 0, 58)
    cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.07)
        draw.RoundedBox(7, -150, -22, 300, 44, Color(16, 20, 26, 228))
        surface.SetDrawColor(218, 174, 86, 160)
        surface.DrawOutlinedRect(-150, -22, 300, 44, 1)
        draw.SimpleText("ОРУЖЕЙНЫЙ ВЕРСТАК", "NYUI.Small", 0, -5, Color(243, 239, 228), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЧЕРТЕЖИ  •  СБОРКА", "NYUI.Small", 0, 12, Color(205, 176, 111), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
