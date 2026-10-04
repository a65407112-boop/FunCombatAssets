
while true do
	local serveruptime = workspace.DistributedGameTime 
	local serversecuptime = math.floor(serveruptime)
	local serverminuptime = math.floor(serversecuptime / 60)
	local serverhouruptime = math.floor(serverminuptime / 60)
	serversecuptime = serversecuptime - (serverminuptime * 60)
	serverminuptime = serverminuptime - (serverhouruptime * 60)
	wait()
	script.Parent.Text = "Server UpTime: "..serverhouruptime.."h - "..serverminuptime.. "m - ".. serversecuptime.."s"
end