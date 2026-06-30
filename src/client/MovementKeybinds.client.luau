local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keybinds = require(ReplicatedStorage.Config.Keybinds)
local Movements = ReplicatedStorage.Movements

for name, info in pairs(Keybinds) do
	local find = Movements:FindFirstChild(name)
	if not find then
		continue
	end
	local req = require(find)
	assert(req.Init, ("%s module does not have the Init method"):format(name))
	assert(req.End, ("%s module does not have the End method"):format(name))
	ContextActionService:BindAction(name, function(_, inputState: Enum.UserInputState, inputObject: InputObject)
		if inputState == Enum.UserInputState.Begin then
			req.Init()
		else
			req.End()
		end
	end, true, info.Bind)
end
