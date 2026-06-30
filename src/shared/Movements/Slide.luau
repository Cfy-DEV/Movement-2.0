local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local trove = require(ReplicatedStorage.Packages.trove)
local localPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local module = {
	SlideSpeed = 12,
	TurningSpeed = 120,
	Gravity = workspace.Gravity * 1.3,
	Friction = 0.4,
}

local velocity
local newTrove = trove.new()
local started = tick()

function applyFriction(velocity, frictionCoeff, dt)
	return velocity * math.exp(-frictionCoeff * dt)
end

local function projectVectorOnPlane(vector: Vector3, planeNormal: Vector3): Vector3
	local normal = planeNormal.Unit
	local projectionOnNormal = normal * vector:Dot(normal)

	return vector - projectionOnNormal
end

local function projectPointOnPlane(p: Vector3, plane_origin: Vector3, plane_normal: Vector3)
	local to_point = p - plane_origin
	local scalar = to_point:Dot(plane_normal)
	local projected = p - (scalar * plane_normal)

	return projected
end

local function getReflection(incidentVector: Vector3, surfaceNormal: Vector3): Vector3
	local unitNormal = surfaceNormal.Unit

	return incidentVector - 2 * (incidentVector:Dot(unitNormal)) * unitNormal
end

function module.Init()
	if not RunService:IsClient() then
		return
	end
	local char = localPlayer.Character
	if not char then
		return
	end
	local hum: BasePart = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local hrs: BasePart = char:FindFirstChild("HumanoidRootPart")
	if not hrs then
		return
	end

	hrs.Anchored = true

	local rayLenght = 2.5 + (hrs.Size.Y / 2)
	local lastTimeOnGround = tick() - started
	velocity = hrs.CFrame.LookVector.Unit
		* math.max(module.SlideSpeed, hrs.AssemblyLinearVelocity.Magnitude)
	local param = RaycastParams.new()
	param.FilterType = Enum.RaycastFilterType.Exclude
	param.FilterDescendantsInstances = { char }

	local function bounce(dir, rayCast2, distance)
		local reflection = getReflection(dir, rayCast2.Normal.Unit)
		return reflection.Unit
	end

	newTrove:Add(RunService.RenderStepped:Connect(function(deltaTime: number)
		local diff2 = tick() - lastTimeOnGround
		local rayOrigin = hrs.Position
		local rayDir = -hrs.CFrame.UpVector * (rayLenght * 1.05)
		local nextPos
		local rayCast = workspace:Raycast(rayOrigin, rayDir, param)

		if rayCast then
			lastTimeOnGround = tick()
			local dir1 = Vector3.new(velocity.Unit.X, 0, velocity.Unit.Z)

			local dir2 = CFrame.lookAt(
				CurrentCamera.CFrame.Position,
				Vector3.new(
					CurrentCamera.CFrame.Position.X + CurrentCamera.CFrame.LookVector.X,
					CurrentCamera.CFrame.Position.Y,
					CurrentCamera.CFrame.Position.Z + CurrentCamera.CFrame.LookVector.Z
				)
			).LookVector -- Neutral camera rotation

			local dir3 = (dir1:Lerp(dir2, (module.TurningSpeed / 100) * deltaTime)) -- slight and FINAL rotation.
			local posOnPlane = projectPointOnPlane(rayOrigin, rayCast.Position, rayCast.Normal)

			nextPos = posOnPlane + rayCast.Normal * rayLenght
			velocity = projectVectorOnPlane(dir3, rayCast.Normal).Unit * velocity.Magnitude

			local gravity = Vector3.yAxis * -module.Gravity
			local gravityAlongSlope = gravity - rayCast.Normal * gravity:Dot(rayCast.Normal)

			velocity += gravityAlongSlope * deltaTime
			velocity = applyFriction(velocity, module.Friction, deltaTime)
		else
			velocity = velocity - Vector3.yAxis * (module.Gravity * deltaTime)
			nextPos = rayOrigin
		end

		local distance = velocity.Magnitude * deltaTime
		local rayCast2 = workspace:Raycast(nextPos, velocity.Unit * distance, param) -- Checking for any "bumps"

		if rayCast2 then
			velocity = bounce(velocity.Unit, rayCast2, distance) * velocity.Magnitude
		end

		hrs.CFrame = CFrame.new(nextPos, nextPos + velocity.Unit) * CFrame.new(0, 0, -distance)
	end))
end

module.End = function()
	if not RunService:IsClient() then
		return
	end
	local char = localPlayer.Character
	if not char then
		return
	end
	local hum: BasePart = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local hrs: BasePart = char:FindFirstChild("HumanoidRootPart")
	if not hrs then
		return
	end
	hrs.Anchored = false
	hrs.AssemblyLinearVelocity = velocity
	velocity = Vector3.zero
	newTrove:Clean()
end

return module
