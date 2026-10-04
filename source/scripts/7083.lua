
local Rain = require(script.Rain)
local isRaining = script:WaitForChild("IsRaining")

Rain:SetColor(Color3.fromRGB(script.Color.Value.x, script.Color.Value.y, script.Color.Value.z))
Rain:SetDirection(script.Direction.Value)

Rain:SetTransparency(script.Transparency.Value)
Rain:SetSpeedRatio(script.SpeedRatio.Value)
Rain:SetIntensityRatio(script.IntensityRatio.Value)
Rain:SetLightInfluence(script.LightInfluence.Value)
Rain:SetLightEmission(script.LightEmission.Value)

Rain:SetVolume(script.Volume.Value)

Rain:SetSoundId(script.SoundId.Value)
Rain:SetStraightTexture(script.StraightTexture.Value)
Rain:SetTopDownTexture(script.TopDownTexture.Value)
Rain:SetSplashTexture(script.SplashTexture.Value)

local threshold = script.TransparencyThreshold.Value
if script.TransparencyConstraint.Value and script.CanCollideConstraint.Value then
	Rain:SetCollisionMode(
		Rain.CollisionMode.Function,
		function(p)
			return p.Transparency <= threshold and p.CanCollide
		end
	)
elseif script.TransparencyConstraint.Value then
	Rain:SetCollisionMode(
		Rain.CollisionMode.Function,
		function(p)
			return p.Transparency <= threshold
		end
	)
elseif script.CanCollideConstraint.Value then
	Rain:SetCollisionMode(
		Rain.CollisionMode.Function,
		function(p)
			return p.CanCollide
		end
	)
end

while(true) do
	wait() 
	if(isRaining.Value == false) then
		Rain:Disable()
		script.Volume.Value = 0
	else
		Rain:Enable()
		script.Volume.Value = .2
	end
	task.wait(0) -- :3
end