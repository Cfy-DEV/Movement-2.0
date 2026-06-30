local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local trove = require(ReplicatedStorage.Packages.trove)
local localPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local module = {
	SlideSpeed = 12,
	TurningSpeed = 35,
	Gravity = workspace.Gravity * 1.3,
	Friction = 0.4,
}

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

	local lastDir = Vector3.new(hrs.CFrame.LookVector.X, 0, hrs.CFrame.LookVector.Z)
	local rayLenght = 2.5 + (hrs.Size.Y / 2)
	local speed = math.clamp(hrs.AssemblyLinearVelocity.Magnitude, module.SlideSpeed, math.huge)
	local lastTimeOnGround = tick() - started

	local param = RaycastParams.new()
	param.FilterType = Enum.RaycastFilterType.Exclude
	param.FilterDescendantsInstances = { char }

	local function bounce(nextDir, rayCast2, distance)
		local reflection = getReflection(nextDir, rayCast2.Normal.Unit)
		hrs.CFrame = CFrame.new(rayCast2.Position, rayCast2.Position + reflection)
			* CFrame.new(0, 0, -(distance - rayCast2.Distance))
		lastDir = reflection.Unit
	end

	newTrove:Add(RunService.RenderStepped:Connect(function(deltaTime: number)
		local diff = tick() - started
		local diff2 = tick() - lastTimeOnGround
		local rayOrigin = hrs.Position
		local rayDir = -hrs.CFrame.UpVector * (rayLenght * 1.05)
		local nextPos
		local rayCast = workspace:Raycast(rayOrigin, rayDir, param)

		local nextDir

		if rayCast then
			if diff2 > 0.35 then
				bounce(nextDir, rayCast, speed * deltaTime)
				lastTimeOnGround = tick()
				return
			end
			lastTimeOnGround = tick()
			local dir1 = Vector3.new(lastDir.X, 0, lastDir.Z)

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
			nextDir = projectVectorOnPlane(dir3, rayCast.Normal)

			if nextDir.Magnitude > 1e-4 then
				nextDir = nextDir.Unit
			else
				nextDir = lastDir
			end

			local gravity = Vector3.new(0, -module.Gravity, 0)
			local accel = gravity:Dot(nextDir)

			speed = math.max(module.SlideSpeed, applyFriction(speed, module.Friction, deltaTime) + (accel * deltaTime))
		else
			speed += module.Gravity * diff2
			nextPos = rayOrigin
			nextDir = lastDir:Lerp(Vector3.new(lastDir.X, -1, lastDir.Z), module.Gravity * deltaTime)
		end

		local distance = speed * deltaTime
		local rayCast2 = workspace:Raycast(nextPos, nextDir * distance, param) -- Checking for any "bumps"

		if rayCast2 then
			bounce(nextDir, rayCast2, distance)
		else
			hrs.CFrame = CFrame.new(nextPos, nextPos + (nextDir * distance)) * CFrame.new(0, 0, -distance)
			lastDir = nextDir.Unit
		end
	end))
end

module.End = function() end

return module
