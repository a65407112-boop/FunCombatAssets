local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PLACEHOLDER_IMAGE = "rbxassetid://0" -- replace with placeholder image

-- fetch the thumbnail
local userId = player.UserId
local thumbType = Enum.ThumbnailType.HeadShot
local thumbSize = Enum.ThumbnailSize.Size420x420
local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)

-- set the ImageLabel's content to the user thumbnail
local imageLabel = script.Parent
imageLabel.Image = (isReady and content) or PLACEHOLDER_IMAGE