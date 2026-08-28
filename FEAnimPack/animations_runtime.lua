local raw = loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/animations.lua"))()
local function matrix(v)
 if not v then return nil end
 local cf = CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0) * CFrame.Angles(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
 return {cf:GetComponents()}
end
for _,a in ipairs(raw) do
 a.name=a.n; a.category=a.c; a.looped=a.l; a.duration=a.d; a.frames=a.f
 for _,fr in ipairs(a.frames) do
  local p=fr.p
  p.Root=matrix(p.R); p.Torso=matrix(p.T); p.Head=matrix(p.H)
  p.RightArm=matrix(p.RA); p.LeftArm=matrix(p.LA); p.RightLeg=matrix(p.RL); p.LeftLeg=matrix(p.LL)
 end
end
return raw
