local function normalize(A)
 for _,a in ipairs(A) do
  a.name=a.name or a.n; a.category=a.category or a.c; a.looped=(a.looped~=nil and a.looped or a.l); a.duration=a.duration or a.d; a.frames=a.frames or a.f
  for _,fr in ipairs(a.frames or {}) do
   local p=fr.p or {}
   p.Root=p.Root or p.R; p.Torso=p.Torso or p.T; p.Head=p.Head or p.H
   p.RightArm=p.RightArm or p.RA; p.LeftArm=p.LeftArm or p.LA; p.RightLeg=p.RightLeg or p.RL; p.LeftLeg=p.LeftLeg or p.LL
  end
 end
 return A
end
return normalize
