while true do
	wait()
	local Players = game:GetService('Players')
	local PlayerInServer = #Players:GetPlayers()
	script.Parent.Text = "Players in Server: "..PlayerInServer
end