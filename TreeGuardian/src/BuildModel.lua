-- Tree Guardian Boss builder.
-- Run this in Roblox Studio's Command Bar (View > Command Bar). It builds the rigged,
-- blocky Tree Guardian in Workspace, adds the animation + AI scripts to it, and saves
-- editable KeyframeSequences for the Animation Editor in ServerStorage.RBX_ANIMSAVES.

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local ANIMATIONS_SOURCE = nil -- @bundle src/GuardianAnimations.lua
local BRAIN_SOURCE = nil -- @bundle src/GuardianBrain.server.lua

local COLORS = {
	Wood = Color3.fromRGB(124, 80, 46),
	WoodDark = Color3.fromRGB(88, 56, 33),
	WoodLight = Color3.fromRGB(152, 104, 62),
	Stone = Color3.fromRGB(78, 80, 90),
	StoneDark = Color3.fromRGB(52, 54, 62),
	Leaves = Color3.fromRGB(62, 145, 48),
	LeavesDark = Color3.fromRGB(42, 112, 38),
	LeavesLight = Color3.fromRGB(98, 180, 64),
	Glow = Color3.fromRGB(150, 255, 95),
	Vines = Color3.fromRGB(48, 92, 38),
	Mouth = Color3.fromRGB(30, 20, 14),
}

local M = Enum.Material
local rad = math.rad

local model = Instance.new("Model")
model.Name = "TreeGuardian"
model.Parent = workspace -- parented early so require() below works; nothing moves in edit mode

local function styleParts(p, color, material)
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Main body part (one per joint), positioned in world space with feet on y = 0.
local parts = {}
local function body(name, size, position, color, material, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position)
	styleParts(p, color, material)
	p.CanCollide = canCollide
	p.Parent = model
	parts[name] = p
	return p
end

-- Decoration welded onto a body part. offset is relative to that part's center.
local function deco(parent, name, size, offset, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = parent.CFrame * offset
	styleParts(p, color, material)
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = parent
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = parent
	return p
end

local function glow(parent, name, size, offset)
	local p = deco(parent, name, size, offset, COLORS.Glow, M.Neon)
	p:SetAttribute("Glow", true)
	return p
end

local function at(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

local function light(parent, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = COLORS.Glow
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

---------------------------------------------------------------------------
-- Body (about 15 studs tall, faces -Z)
---------------------------------------------------------------------------
local root = body("HumanoidRootPart", Vector3.new(4, 1.8, 2.2), Vector3.new(0, 5.9, 0), COLORS.Wood, M.SmoothPlastic, false)
root.Transparency = 1

local lowerTorso = body("LowerTorso", Vector3.new(4.4, 1.6, 2.6), Vector3.new(0, 5.7, 0), COLORS.Wood, M.Wood, true)
local upperTorso = body("UpperTorso", Vector3.new(5.2, 3.6, 3), Vector3.new(0, 8.2, 0), COLORS.Wood, M.Wood, true)
local head = body("Head", Vector3.new(2.6, 2.6, 2.4), Vector3.new(0, 11.2, -0.1), COLORS.Wood, M.Wood, true)

for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
	local s, x = side[1], side[2]
	body(s .. "UpperArm", Vector3.new(1.9, 2.4, 1.9), Vector3.new(3.7 * x, 8.6, 0), COLORS.Wood, M.Wood, false)
	body(s .. "LowerArm", Vector3.new(2.2, 2.4, 2.2), Vector3.new(3.7 * x, 6.2, 0), COLORS.Wood, M.Wood, false)
	body(s .. "Hand", Vector3.new(2.6, 2.1, 2.6), Vector3.new(3.7 * x, 3.95, 0), COLORS.Stone, M.Slate, false)
	body(s .. "UpperLeg", Vector3.new(2.1, 2.2, 2.1), Vector3.new(1.3 * x, 4, 0), COLORS.Wood, M.Wood, false)
	body(s .. "LowerLeg", Vector3.new(1.8, 2.2, 1.8), Vector3.new(1.3 * x, 2, 0), COLORS.Wood, M.Wood, false)
	body(s .. "Foot", Vector3.new(2.2, 1, 3), Vector3.new(1.3 * x, 0.5, -0.3), COLORS.Stone, M.Slate, false)
end

---------------------------------------------------------------------------
-- Joints (R15 names, so the Animation Editor understands the rig)
---------------------------------------------------------------------------
local jointPositions = {
	Root = Vector3.new(0, 5.7, 0),
	Waist = Vector3.new(0, 6.5, 0),
	Neck = Vector3.new(0, 10, 0),
	LeftShoulder = Vector3.new(-3.7, 9.4, 0),
	LeftElbow = Vector3.new(-3.7, 7.4, 0),
	LeftWrist = Vector3.new(-3.7, 5, 0),
	RightShoulder = Vector3.new(3.7, 9.4, 0),
	RightElbow = Vector3.new(3.7, 7.4, 0),
	RightWrist = Vector3.new(3.7, 5, 0),
	LeftHip = Vector3.new(-1.3, 5, 0),
	LeftKnee = Vector3.new(-1.3, 3, 0),
	LeftAnkle = Vector3.new(-1.3, 1, 0),
	RightHip = Vector3.new(1.3, 5, 0),
	RightKnee = Vector3.new(1.3, 3, 0),
	RightAnkle = Vector3.new(1.3, 1, 0),
}

local animationsModule = Instance.new("ModuleScript")
animationsModule.Name = "GuardianAnimations"
animationsModule.Source = ANIMATIONS_SOURCE
animationsModule.Parent = model
local GuardianAnimations = require(animationsModule)

for _, joint in ipairs(GuardianAnimations.Joints) do
	local part0, part1 = parts[joint.Part0], parts[joint.Part1]
	local jointCFrame = CFrame.new(jointPositions[joint.Name])
	local motor = Instance.new("Motor6D")
	motor.Name = joint.Name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * jointCFrame
	motor.C1 = part1.CFrame:Inverse() * jointCFrame
	motor.Parent = part1
end

---------------------------------------------------------------------------
-- Details
---------------------------------------------------------------------------

-- Upper torso: bark, chest plate and the glowing rune
for i, x in ipairs({ -2.05, -1.0, 1.0, 2.05 }) do
	local color = (i % 2 == 0) and COLORS.WoodLight or COLORS.WoodDark
	deco(upperTorso, "Bark", Vector3.new(0.9, 3.3 - (i % 2) * 0.4, 0.3), at(x, -0.1, -1.55), color, M.Wood)
end
deco(upperTorso, "ChestPlate", Vector3.new(2.8, 2.8, 0.45), at(0, 0.1, -1.6), COLORS.Wood, M.Wood)
deco(upperTorso, "ChestPlateRim", Vector3.new(2.2, 0.35, 0.5), at(0, -1.35, -1.55), COLORS.WoodDark, M.Wood)
local runeStem = glow(upperTorso, "RuneStem", Vector3.new(0.32, 1.5, 0.15), at(0, -0.15, -1.85))
glow(upperTorso, "RuneLeft", Vector3.new(0.3, 1.15, 0.15), at(-0.45, 0.8, -1.85, 0, 0, 32))
glow(upperTorso, "RuneRight", Vector3.new(0.3, 1.15, 0.15), at(0.45, 0.8, -1.85, 0, 0, -32))
glow(upperTorso, "RuneMiddle", Vector3.new(0.26, 0.7, 0.15), at(0, 0.95, -1.85))
glow(upperTorso, "RuneBase", Vector3.new(0.7, 0.22, 0.15), at(0, -0.85, -1.85))
light(runeStem, 14, 2)

deco(upperTorso, "BackBark", Vector3.new(4.6, 3.2, 0.3), at(0, 0, 1.6), COLORS.WoodDark, M.Wood)
deco(upperTorso, "BackBarkStrip", Vector3.new(0.8, 3.4, 0.35), at(-1.2, 0, 1.7), COLORS.WoodLight, M.Wood)
deco(upperTorso, "BackBarkStrip", Vector3.new(0.8, 3.0, 0.35), at(1.3, 0.1, 1.7), COLORS.Wood, M.Wood)
for _, x in ipairs({ -1, 1 }) do
	deco(upperTorso, "SideBark", Vector3.new(0.3, 3.2, 2.6), at(2.65 * x, 0, 0), COLORS.WoodDark, M.Wood)
	deco(upperTorso, "ShoulderMoss", Vector3.new(1.7, 0.8, 2.4), at(1.75 * x, 1.95, 0), COLORS.Leaves, M.Grass)
	deco(upperTorso, "ShoulderMoss", Vector3.new(1.1, 0.7, 1.2), at(0.85 * x, 2.0, 0.7), COLORS.LeavesDark, M.Grass)
	deco(upperTorso, "ShoulderMoss", Vector3.new(0.9, 0.6, 0.9), at(1.6 * x, 1.9, -1.35), COLORS.LeavesLight, M.Grass)
end
-- Hanging vines on the chest and back
local vineSpots = { { -2.0, -1.75 }, { 1.85, -1.75 }, { -0.9, 1.8 }, { 2.0, 1.8 } }
for i, spot in ipairs(vineSpots) do
	local x, z = spot[1], spot[2]
	local length = 2.2 + (i % 2) * 0.8
	deco(upperTorso, "Vine", Vector3.new(0.22, length, 0.22), at(x, 1.6 - length / 2, z), COLORS.Vines, M.Grass)
	for j = 1, 3 do
		local y = 1.4 - j * (length / 3.5)
		local leafX = x + ((j % 2 == 0) and 0.3 or -0.3)
		deco(upperTorso, "VineLeaf", Vector3.new(0.6, 0.5, 0.15), at(leafX, y, z + (z < 0 and -0.12 or 0.12), 0, 0, (j % 2 == 0) and -25 or 25), COLORS.Leaves, M.Grass)
	end
end

-- Lower torso: bark belt and moss
deco(lowerTorso, "Belt", Vector3.new(4.6, 0.55, 2.8), at(0, 0.3, 0), COLORS.WoodDark, M.Wood)
deco(lowerTorso, "Moss", Vector3.new(1.2, 0.6, 0.4), at(-1.2, -0.25, -1.4), COLORS.Leaves, M.Grass)
deco(lowerTorso, "Moss", Vector3.new(0.9, 0.5, 0.4), at(1.4, -0.3, 1.4), COLORS.LeavesDark, M.Grass)
deco(lowerTorso, "Vine", Vector3.new(0.2, 1.8, 0.2), at(0.9, -0.9, -1.45), COLORS.Vines, M.Grass)

-- Head: angry brows, glowing eyes, branches and a leafy canopy
deco(head, "Face", Vector3.new(2.4, 2.0, 0.3), at(0, -0.2, -1.3), COLORS.Wood, M.Wood)
deco(head, "Nose", Vector3.new(0.5, 1.3, 0.55), at(0, -0.45, -1.5), COLORS.WoodDark, M.Wood)
deco(head, "Mouth", Vector3.new(1.0, 0.15, 0.1), at(0, -1.0, -1.47), COLORS.Mouth, M.SmoothPlastic)
deco(head, "LeftBrow", Vector3.new(1.4, 0.4, 0.55), at(-0.65, 0.4, -1.5, 0, 0, -20), COLORS.WoodDark, M.Wood)
deco(head, "RightBrow", Vector3.new(1.4, 0.4, 0.55), at(0.65, 0.4, -1.5, 0, 0, 20), COLORS.WoodDark, M.Wood)
local leftEye = glow(head, "LeftEye", Vector3.new(0.6, 0.25, 0.15), at(-0.6, 0.0, -1.5, 0, 0, -15))
glow(head, "RightEye", Vector3.new(0.6, 0.25, 0.15), at(0.6, 0.0, -1.5, 0, 0, 15))
light(leftEye, 8, 1.5)

for _, x in ipairs({ -1, 1 }) do
	-- x = -1 is the guardian's left. Angles tilt each branch outward.
	deco(head, "Branch", Vector3.new(0.55, 3.4, 0.55), at(1.9 * x, 1.7, 0, 0, 0, -45 * x), COLORS.WoodDark, M.Wood)
	deco(head, "Branch", Vector3.new(0.4, 1.8, 0.4), at(3.6 * x, 2.75, 0, 0, 0, -75 * x), COLORS.WoodDark, M.Wood)
	deco(head, "Branch", Vector3.new(0.4, 1.6, 0.4), at(3.2 * x, 3.9, 0, 0, 0, -10 * x), COLORS.WoodDark, M.Wood)
	deco(head, "Branch", Vector3.new(0.35, 1.2, 0.35), at(2.4 * x, 2.9, 0.2, 0, 0, 15 * x), COLORS.Wood, M.Wood)
	deco(head, "BranchLeaves", Vector3.new(0.9, 0.9, 0.9), at(3.3 * x, 4.75, 0), COLORS.LeavesLight, M.Grass)
	deco(head, "BranchLeaves", Vector3.new(0.7, 0.7, 0.7), at(4.4 * x, 3.0, 0.1), COLORS.Leaves, M.Grass)
end
deco(head, "Branch", Vector3.new(0.4, 1.8, 0.4), at(0.4, 1.9, 1.2, 30, 0, 0), COLORS.WoodDark, M.Wood)

deco(head, "Canopy", Vector3.new(3.6, 1.4, 3.2), at(0, 2.1, 0.3), COLORS.Leaves, M.Grass)
deco(head, "Canopy", Vector3.new(2.8, 1.1, 2.6), at(0, 3.1, 0.3), COLORS.LeavesDark, M.Grass)
local leafColors = { COLORS.Leaves, COLORS.LeavesDark, COLORS.LeavesLight }
local rng = Random.new(7)
for i = 1, 18 do
	local s = rng:NextNumber(0.9, 1.6)
	-- Kept above and behind the brows so the face stays visible.
	local offset = at(rng:NextNumber(-2.0, 2.0), rng:NextNumber(2.2, 3.8), rng:NextNumber(-1.0, 1.9))
	deco(head, "Leaves", Vector3.new(s, s, s), offset, leafColors[(i % 3) + 1], M.Grass)
end

-- Arms, hands, legs, feet
for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
	local s, x = side[1], side[2]
	local upperArm, lowerArm, hand = parts[s .. "UpperArm"], parts[s .. "LowerArm"], parts[s .. "Hand"]
	local upperLeg, lowerLeg, foot = parts[s .. "UpperLeg"], parts[s .. "LowerLeg"], parts[s .. "Foot"]

	deco(upperArm, "ShoulderPad", Vector3.new(2.6, 1.2, 2.6), at(0.1 * x, 1.0, 0), COLORS.WoodDark, M.Wood)
	deco(upperArm, "ShoulderMoss", Vector3.new(2.2, 0.7, 2.2), at(0.2 * x, 1.85, 0), COLORS.Leaves, M.Grass)
	deco(upperArm, "ShoulderMoss", Vector3.new(1.2, 0.6, 1.2), at(0.6 * x, 2.35, 0.3), COLORS.LeavesLight, M.Grass)
	deco(upperArm, "Bark", Vector3.new(0.3, 2.0, 1.6), at(1.0 * x, -0.3, 0), COLORS.WoodLight, M.Wood)

	deco(lowerArm, "BarkRing", Vector3.new(2.4, 0.45, 2.4), at(0, 0.9, 0), COLORS.WoodDark, M.Wood)
	deco(lowerArm, "Bark", Vector3.new(0.3, 1.6, 1.4), at(1.15 * x, -0.2, 0.2), COLORS.WoodDark, M.Wood)
	glow(lowerArm, "ArmRune", Vector3.new(0.14, 1.3, 0.28), at(1.33 * x, -0.2, -0.35))
	glow(lowerArm, "ArmRuneBranch", Vector3.new(0.14, 0.6, 0.24), at(1.33 * x, 0.25, 0.05, 40, 0, 0))
	deco(lowerArm, "Moss", Vector3.new(0.9, 0.6, 0.9), at(0.7 * x, -0.95, -0.85), COLORS.Leaves, M.Grass)

	deco(hand, "Cuff", Vector3.new(2.4, 0.5, 2.4), at(0, 1.05, 0), COLORS.WoodDark, M.Wood)
	for i = 0, 3 do
		deco(hand, "Knuckle", Vector3.new(0.55, 0.7, 0.6), at(-0.9 + i * 0.6, -1.15, -0.75), COLORS.StoneDark, M.Slate)
	end
	deco(hand, "Thumb", Vector3.new(0.6, 0.9, 0.7), at(-1.4 * x, -0.2, -0.6), COLORS.StoneDark, M.Slate)
	deco(hand, "Moss", Vector3.new(1.2, 0.4, 1.0), at(0.2 * x, 0.9, 0.7), COLORS.LeavesDark, M.Grass)

	deco(upperLeg, "MossBand", Vector3.new(2.3, 0.6, 2.3), at(0, 0.6, 0), COLORS.LeavesDark, M.Grass)
	deco(upperLeg, "Bark", Vector3.new(1.4, 1.5, 0.3), at(0, -0.3, -1.1), COLORS.WoodDark, M.Wood)

	deco(lowerLeg, "KneeStone", Vector3.new(1.4, 0.9, 0.5), at(0, 0.8, -0.95), COLORS.Stone, M.Slate)
	deco(lowerLeg, "Vine", Vector3.new(0.2, 1.8, 0.2), at(0.95 * x, -0.1, -0.5), COLORS.Vines, M.Grass)

	deco(foot, "AnkleCap", Vector3.new(1.9, 0.4, 1.9), at(0, 0.6, 0.3), COLORS.WoodDark, M.Wood)
	for _, toeX in ipairs({ -0.65, 0, 0.65 }) do
		deco(foot, "Toe", Vector3.new(0.6, 0.6, 0.7), at(toeX, -0.2, -1.65), COLORS.StoneDark, M.Slate)
	end
end

---------------------------------------------------------------------------
-- Humanoid, settings and scripts
---------------------------------------------------------------------------
local humanoid = Instance.new("Humanoid")
humanoid.RigType = Enum.HumanoidRigType.R15
humanoid.AutomaticScalingEnabled = false
humanoid.HipHeight = 5 -- ground to the bottom of HumanoidRootPart
humanoid.WalkSpeed = 10
humanoid.MaxHealth = 2000
humanoid.Health = 2000
humanoid.DisplayName = "Tree Guardian"
Instance.new("Animator").Parent = humanoid
humanoid.Parent = model

model.PrimaryPart = root

-- Boss settings: change these in the model's Properties > Attributes.
model:SetAttribute("AggroRange", 90)
model:SetAttribute("AttackRange", 13)
model:SetAttribute("AttackDamage", 30)
model:SetAttribute("AttackCooldown", 3)
model:SetAttribute("ShockwaveRadius", 16)
model:SetAttribute("SummonCooldown", 14)
-- Leave these empty to use the built-in procedural animations.
model:SetAttribute("WalkAnimationId", "")
model:SetAttribute("AttackAnimationId", "")
model:SetAttribute("SummonAnimationId", "")

local brain = Instance.new("Script")
brain.Name = "GuardianBrain"
brain.Source = BRAIN_SOURCE
brain.Parent = model

---------------------------------------------------------------------------
-- KeyframeSequences for the Animation Editor (ServerStorage.RBX_ANIMSAVES)
---------------------------------------------------------------------------
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
if not saves then
	saves = Instance.new("Model")
	saves.Name = "RBX_ANIMSAVES"
	saves.Parent = ServerStorage
end
local rigSaves = Instance.new("ObjectValue")
rigSaves.Name = model.Name
rigSaves.Value = model
rigSaves.Parent = saves

for _, animName in ipairs({ "Walk", "Attack", "Summon" }) do
	local anim = GuardianAnimations.Data[animName]
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "TreeGuardian_" .. animName
	sequence.Loop = anim.Looped
	sequence.Priority = Enum.AnimationPriority[anim.Priority]

	for index, kf in ipairs(anim.Keyframes) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = kf.Time
		local poses = {}
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 0
		rootPose.Parent = keyframe
		poses.HumanoidRootPart = rootPose
		for _, joint in ipairs(GuardianAnimations.Joints) do
			local pose = Instance.new("Pose")
			pose.Name = joint.Part1
			pose.CFrame = GuardianAnimations.GetKeyframePose(animName, index, joint.Name)
			pose.Weight = anim.UsedJoints[joint.Name] and 1 or 0
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			pose.Parent = poses[joint.Part0]
			poses[joint.Part1] = pose
		end
		if kf.Marker then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = kf.Marker
			keyframe:AddMarker(marker)
		end
		keyframe.Parent = sequence
	end
	sequence.Parent = rigSaves
end

---------------------------------------------------------------------------
-- Place it in front of the camera, standing on whatever is below.
---------------------------------------------------------------------------
local camera = workspace.CurrentCamera
local spawnAt = Vector3.new(0, 0, 0)
if camera then
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		flat = flat.Unit
	else
		flat = Vector3.new(0, 0, -1)
	end
	local guess = camera.CFrame.Position + flat * 35
	local hit = workspace:Raycast(guess + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0))
	spawnAt = hit and hit.Position or Vector3.new(guess.X, 0, guess.Z)
	-- Face the camera. The pivot is HumanoidRootPart, which sits 5.9 studs above the feet.
	local facing = CFrame.lookAt(spawnAt, Vector3.new(camera.CFrame.Position.X, spawnAt.Y, camera.CFrame.Position.Z))
	model:PivotTo(facing + Vector3.new(0, root.Position.Y, 0))
end

Selection:Set({ model })
ChangeHistoryService:SetWaypoint("Built Tree Guardian")
print("Tree Guardian built! Press Play to see it walk, attack and summon.")
