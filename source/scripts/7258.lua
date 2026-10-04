player = script.Parent.Parent.Parent.Parent.Parent
item = script.Parent["Orange Cat"]

function Click(mouse)
     
	item.Parent = player.Backpack
	script.Parent.Parent.Visible = false
	script.Parent.Parent.Parent.Frame.Visible = false

end


script.Parent.MouseButton1Down:connect(Click)