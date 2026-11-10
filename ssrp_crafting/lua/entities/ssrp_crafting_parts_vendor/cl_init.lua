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
    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 450 * 450 then return end
    local ang = LocalPlayer():EyeAngles()
    ang = Angle(0, ang.y - 90, 90)
    local pos = self:GetPos() + Vector(0, 0, 79)
    cam.Start3D2D(pos, ang, 0.09)
        draw.RoundedBox(8, -112, -28, 224, 48, Color(15, 19, 24, 225))
        surface.SetDrawColor(218, 174, 86, 190)
        surface.DrawOutlinedRect(-112, -28, 224, 48, 1)
        draw.SimpleText("ПОСТАВЩИК ДЕТАЛЕЙ", "NYUI.Small", 0, -10, Color(242, 231, 208), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("оружейные компоненты", "NYUI.Small", 0, 8, Color(184, 190, 196), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
