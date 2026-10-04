local TweenService = game:GetService("TweenService")

while true do
	local tween = TweenService:Create(script.Parent, TweenInfo.new(1), {
		Offset = Vector2.new(0.3 * math.sin(time()), 0)
	})
	tween:Play()
	wait()

end
