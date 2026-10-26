-- GuardianBrain (Script inside the TreeGuardian model)
-- Simple boss AI: walks toward the nearest player, slams the ground when close, and
-- summons every so often. Settings live in the model's Attributes.
--
-- Hook your own effects in with the BindableEvents this creates:
--   model.Attacked.Event:Connect(function(impactPosition) ... end)
--   model.Summoned.Event:Connect(function() ... end) -- e.g. spawn minions here

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local model = script.Parent
local humanoid = model:WaitForChild("Humanoid")
local root = model:WaitForChild("HumanoidRootPart")
local GuardianAnimations = require(model:WaitForChild("GuardianAnimations"))

local anims = GuardianAnimations.new(model)

local attackedEvent = Instance.new("BindableEvent")
attackedEvent.Name = "Attacked"
attackedEvent.Parent = model
local summonedEvent = Instance.new("BindableEvent")
summonedEvent.Name = "Summoned"
summonedEvent.Parent = model

local GLOW_COLOR = Color3.fromRGB(150, 255, 95)

local function setting(name, default)
	local value = model:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

pcall(function()
	root:SetNetworkOwner(nil) -- the server moves the boss, so it never stutters
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { model }

local function groundBelow(position)
	local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), rayParams)
	if hit then
		return hit.Position
	end
	return Vector3.new(position.X, root.Position.Y - humanoid.HipHeight - root.Size.Y / 2, position.Z)
end

local function findTarget()
	local best, bestDistance = nil, setting("AggroRange", 90)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			local distance = (hrp.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = hrp, distance
			end
		end
	end
	return best, bestDistance
end

local function face(position)
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function tweenThenDestroy(part, info, goal, lifetime)
	TweenService:Create(part, info, goal):Play()
	Debris:AddItem(part, lifetime)
end

local function effectPart(size, cframe, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Parent = workspace
	return p
end

---------------------------------------------------------------------------
-- Attack: ground slam shockwave
---------------------------------------------------------------------------
local function shockwave()
	local front = root.CFrame * CFrame.new(0, 0, -5)
	local center = groundBelow(front.Position)
	local radius = setting("ShockwaveRadius", 16)

	-- Damage and knock back everyone in range (once each).
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model }
	local hitHumanoids = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, overlap)) do
		local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
		if hum and not hitHumanoids[hum] and hum.Health > 0 then
			hitHumanoids[hum] = true
			hum:TakeDamage(setting("AttackDamage", 30))
			local hrp = hum.Parent:FindFirstChild("HumanoidRootPart")
			if hrp then
				local away = hrp.Position - center
				away = Vector3.new(away.X, 0, away.Z)
				away = away.Magnitude > 0.1 and away.Unit or root.CFrame.LookVector
				hrp.AssemblyLinearVelocity = away * 60 + Vector3.new(0, 45, 0)
			end
		end
	end

	-- Glowing ring that expands and fades.
	local ring = effectPart(Vector3.new(0.4, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), GLOW_COLOR, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	tweenThenDestroy(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}, 0.6)

	-- Chunks of rock popping out of the ground.
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(3, 7)
		local size = math.random(10, 18) / 10
		local rock = effectPart(Vector3.new(size, size, size), CFrame.new(center + offset) * CFrame.Angles(math.random(), math.random(), math.random()), Color3.fromRGB(78, 80, 90), Enum.Material.Slate)
		tweenThenDestroy(rock, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = rock.CFrame + Vector3.new(0, size * 1.5, 0),
			Transparency = 1,
		}, 0.8)
	end

	attackedEvent:Fire(center)
end

---------------------------------------------------------------------------
-- Summon: runes flare and glowing roots burst out of the ground around the boss
---------------------------------------------------------------------------
local function summonEffect()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Glow") then
			local original = d.Color
			d.Color = Color3.new(1, 1, 1)
			TweenService:Create(d, TweenInfo.new(1.2), { Color = original }):Play()
		elseif d:IsA("PointLight") then
			local original = d.Brightness
			d.Brightness = original * 4
			TweenService:Create(d, TweenInfo.new(1.2), { Brightness = original }):Play()
		end
	end

	local center = groundBelow(root.Position)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 10
		local height = math.random(5, 8)
		local startCFrame = CFrame.new(spot - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, math.rad(math.random(-15, 15)))
		local pillar = effectPart(Vector3.new(1.2, height, 1.2), startCFrame, Color3.fromRGB(88, 56, 33), Enum.Material.Wood)
		local tip = effectPart(Vector3.new(0.6, 0.6, 0.6), startCFrame * CFrame.new(0, height / 2, 0), GLOW_COLOR, Enum.Material.Neon)
		local rise = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(pillar, rise, { CFrame = startCFrame + Vector3.new(0, height, 0) }):Play()
		TweenService:Create(tip, rise, { CFrame = startCFrame * CFrame.new(0, height / 2, 0) + Vector3.new(0, height, 0) }):Play()
		task.delay(1.6, function()
			local sink = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(pillar, sink, { CFrame = startCFrame, Transparency = 1 }):Play()
			TweenService:Create(tip, sink, { CFrame = startCFrame, Transparency = 1 }):Play()
		end)
		Debris:AddItem(pillar, 2.3)
		Debris:AddItem(tip, 2.3)
	end

	summonedEvent:Fire()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local busy = false
local lastAttack = 0
local lastSummon = os.clock()

local function doAction(animName, onMarker)
	busy = true
	humanoid:MoveTo(root.Position)
	local length = anims:Play(animName, 0.15, onMarker)
	task.wait(length)
	busy = false
end

local function attack(target)
	face(target.Position)
	lastAttack = os.clock()
	doAction("Attack", function(marker)
		if marker == "Hit" then
			shockwave()
		end
	end)
end

local function summon()
	lastSummon = os.clock()
	doAction("Summon", function(marker)
		if marker == "Summon" then
			summonEffect()
		end
	end)
end

-- Walk animation follows actual movement.
task.spawn(function()
	while humanoid.Parent and humanoid.Health > 0 do
		local velocity = root.AssemblyLinearVelocity
		local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1 and not busy
		if moving and not anims:IsPlaying("Walk") then
			anims:Play("Walk", 0.2)
		elseif not moving and anims:IsPlaying("Walk") then
			anims:Stop("Walk", 0.25)
		end
		task.wait(0.1)
	end
end)

humanoid.Died:Connect(function()
	anims:Destroy()
	Debris:AddItem(model, 8)
end)

-- Main loop.
while humanoid.Parent and humanoid.Health > 0 do
	local target, distance = findTarget()
	if target and not busy then
		local attackRange = setting("AttackRange", 13)
		if os.clock() - lastSummon >= setting("SummonCooldown", 14) then
			face(target.Position)
			summon()
		elseif distance <= attackRange and os.clock() - lastAttack >= setting("AttackCooldown", 3) then
			attack(target)
		elseif distance > attackRange * 0.7 then
			humanoid:MoveTo(target.Position)
		else
			humanoid:MoveTo(root.Position)
			face(target.Position)
		end
	elseif not target and not busy then
		humanoid:MoveTo(root.Position)
	end
	task.wait(0.2)
end
