-- GuardianAnimations (ModuleScript)
-- Holds the Tree Guardian's three animations (Walk, Attack, Summon) and plays them.
--
-- Two ways to play:
--   1. Procedural (default): poses the Motor6D joints straight from the keyframe data
--      below. Works right away, no uploading needed.
--   2. Roblox animations: publish the KeyframeSequences the builder made (see README),
--      then put the IDs in the model's WalkAnimationId / AttackAnimationId /
--      SummonAnimationId attributes. When all three are set, the real Animator is used.
--
-- Usage:
--   local GuardianAnimations = require(model.GuardianAnimations)
--   local anims = GuardianAnimations.new(model)
--   anims:Play("Walk")
--   anims:Play("Attack", 0.15, function(marker) if marker == "Hit" then ... end end)
--   anims:Stop("Walk")

local RunService = game:GetService("RunService")

local GuardianAnimations = {}
GuardianAnimations.__index = GuardianAnimations

-- Every Motor6D in the rig. Parents come before children.
GuardianAnimations.Joints = {
	{ Name = "Root", Part0 = "HumanoidRootPart", Part1 = "LowerTorso" },
	{ Name = "Waist", Part0 = "LowerTorso", Part1 = "UpperTorso" },
	{ Name = "Neck", Part0 = "UpperTorso", Part1 = "Head" },
	{ Name = "LeftShoulder", Part0 = "UpperTorso", Part1 = "LeftUpperArm" },
	{ Name = "LeftElbow", Part0 = "LeftUpperArm", Part1 = "LeftLowerArm" },
	{ Name = "LeftWrist", Part0 = "LeftLowerArm", Part1 = "LeftHand" },
	{ Name = "RightShoulder", Part0 = "UpperTorso", Part1 = "RightUpperArm" },
	{ Name = "RightElbow", Part0 = "RightUpperArm", Part1 = "RightLowerArm" },
	{ Name = "RightWrist", Part0 = "RightLowerArm", Part1 = "RightHand" },
	{ Name = "LeftHip", Part0 = "LowerTorso", Part1 = "LeftUpperLeg" },
	{ Name = "LeftKnee", Part0 = "LeftUpperLeg", Part1 = "LeftLowerLeg" },
	{ Name = "LeftAnkle", Part0 = "LeftLowerLeg", Part1 = "LeftFoot" },
	{ Name = "RightHip", Part0 = "LowerTorso", Part1 = "RightUpperLeg" },
	{ Name = "RightKnee", Part0 = "RightUpperLeg", Part1 = "RightLowerLeg" },
	{ Name = "RightAnkle", Part0 = "RightLowerLeg", Part1 = "RightFoot" },
}

local PRIORITY_ORDER = { Idle = 0, Movement = 1, Action = 2 }

---------------------------------------------------------------------------
-- Animation data
-- A pose is { rx, ry, rz } rotation in degrees plus optional { x, y, z } offset in
-- studs, relative to the joint's rest pose. The rig faces -Z, so:
--   rx > 0 swings a limb forward (arms up / legs forward) and leans the torso back
--   knees bend with rx < 0, elbows bend with rx > 0
--   rz < 0 lifts the left arm out sideways, rz > 0 lifts the right arm
-- Joints left out of a keyframe go back to rest.
---------------------------------------------------------------------------

local function mirror(poses)
	local out = {}
	for jointName, p in pairs(poses) do
		local name = jointName
		if string.sub(name, 1, 4) == "Left" then
			name = "Right" .. string.sub(name, 5)
		elseif string.sub(name, 1, 5) == "Right" then
			name = "Left" .. string.sub(name, 6)
		end
		out[name] = {
			rx = p.rx,
			ry = p.ry and -p.ry,
			rz = p.rz and -p.rz,
			x = p.x and -p.x,
			y = p.y,
			z = p.z,
		}
	end
	return out
end

-- Walk: heavy stomping stride. Left foot lands, right leg swings through, then mirrored.
local walkContact = {
	Root = { y = -0.35, ry = -6 },
	Waist = { ry = 10, rx = -4 },
	Neck = { ry = -4 },
	LeftHip = { rx = 28 },
	LeftKnee = { rx = -6 },
	LeftAnkle = { rx = -12 },
	RightHip = { rx = -22 },
	RightKnee = { rx = -18 },
	RightAnkle = { rx = 22 },
	LeftShoulder = { rx = -20, rz = -6 },
	LeftElbow = { rx = 10 },
	RightShoulder = { rx = 24, rz = 6 },
	RightElbow = { rx = 22 },
}
local walkPassing = {
	Root = { y = 0.05 },
	Waist = { rx = -6 },
	LeftHip = { rx = -2 },
	RightHip = { rx = 12 },
	RightKnee = { rx = -48 },
	RightAnkle = { rx = 16 },
	LeftShoulder = { rz = -6 },
	LeftElbow = { rx = 12 },
	RightShoulder = { rz = 6 },
	RightElbow = { rx = 12 },
}

local Data = {}

Data.Walk = {
	Length = 1.4,
	Looped = true,
	Priority = "Movement",
	Keyframes = {
		{ Time = 0, Poses = walkContact },
		{ Time = 0.35, Poses = walkPassing },
		{ Time = 0.7, Poses = mirror(walkContact) },
		{ Time = 1.05, Poses = mirror(walkPassing) },
		{ Time = 1.4, Poses = walkContact },
	},
}

-- Attack: both fists raised overhead, then slammed into the ground. "Hit" fires on impact.
local slamCrouch = {
	LeftHip = { rx = 40 },
	RightHip = { rx = 40 },
	LeftKnee = { rx = -75 },
	RightKnee = { rx = -75 },
	LeftAnkle = { rx = 35 },
	RightAnkle = { rx = 35 },
}
local function withCrouch(poses)
	for k, v in pairs(slamCrouch) do
		poses[k] = v
	end
	return poses
end

Data.Attack = {
	Length = 1.6,
	Looped = false,
	Priority = "Action",
	Keyframes = {
		{ Time = 0, Poses = {} },
		{
			Time = 0.45,
			Poses = {
				Root = { y = 0.2 },
				Waist = { rx = 18 },
				Neck = { rx = -8 },
				LeftShoulder = { rx = 165, rz = -12 },
				RightShoulder = { rx = 165, rz = 12 },
				LeftElbow = { rx = 35 },
				RightElbow = { rx = 35 },
				LeftWrist = { rx = 20 },
				RightWrist = { rx = 20 },
				LeftHip = { rx = -6 },
				RightHip = { rx = -6 },
			},
		},
		{
			Time = 0.6,
			Poses = {
				Root = { y = 0.3 },
				Waist = { rx = 22 },
				Neck = { rx = -10 },
				LeftShoulder = { rx = 172, rz = -10 },
				RightShoulder = { rx = 172, rz = 10 },
				LeftElbow = { rx = 45 },
				RightElbow = { rx = 45 },
				LeftWrist = { rx = 25 },
				RightWrist = { rx = 25 },
				LeftHip = { rx = -8 },
				RightHip = { rx = -8 },
			},
		},
		{
			Time = 0.8,
			Marker = "Hit",
			Poses = withCrouch({
				Root = { y = -0.8 },
				Waist = { rx = -40 },
				Neck = { rx = 20 },
				LeftShoulder = { rx = 60, rz = 10 },
				RightShoulder = { rx = 60, rz = -10 },
				LeftElbow = { rx = 5 },
				RightElbow = { rx = 5 },
			}),
		},
		{
			Time = 1.05,
			Poses = withCrouch({
				Root = { y = -0.7 },
				Waist = { rx = -36 },
				Neck = { rx = 18 },
				LeftShoulder = { rx = 58, rz = 12 },
				RightShoulder = { rx = 58, rz = -12 },
				LeftElbow = { rx = 10 },
				RightElbow = { rx = 10 },
			}),
		},
		{ Time = 1.6, Poses = {} },
	},
}

-- Summon: raises both hands to the sky, holds, then brings them back down.
-- "Summon" fires at the peak.
Data.Summon = {
	Length = 2.4,
	Looped = false,
	Priority = "Action",
	Keyframes = {
		{ Time = 0, Poses = {} },
		{
			Time = 0.7,
			Poses = {
				Root = { y = 0.3 },
				Waist = { rx = 14 },
				Neck = { rx = 22 },
				LeftShoulder = { rx = 150, rz = -28 },
				RightShoulder = { rx = 150, rz = 28 },
				LeftElbow = { rx = 5 },
				RightElbow = { rx = 5 },
				LeftWrist = { rx = -15 },
				RightWrist = { rx = -15 },
			},
		},
		{
			Time = 1.1,
			Marker = "Summon",
			Poses = {
				Root = { y = 0.45 },
				Waist = { rx = 20 },
				Neck = { rx = 30 },
				LeftShoulder = { rx = 170, rz = -22 },
				RightShoulder = { rx = 170, rz = 22 },
				LeftElbow = { rx = 2 },
				RightElbow = { rx = 2 },
				LeftWrist = { rx = -20 },
				RightWrist = { rx = -20 },
			},
		},
		{
			Time = 1.7,
			Poses = {
				Root = { y = 0.4 },
				Waist = { rx = 18 },
				Neck = { rx = 26 },
				LeftShoulder = { rx = 165, rz = -25 },
				RightShoulder = { rx = 165, rz = 25 },
				LeftElbow = { rx = 4 },
				RightElbow = { rx = 4 },
				LeftWrist = { rx = -18 },
				RightWrist = { rx = -18 },
			},
		},
		{ Time = 2.4, Poses = {} },
	},
}

GuardianAnimations.Data = Data

-- Precompute a CFrame per joint per keyframe, and which joints each animation uses.
local function toCFrame(p)
	if not p then
		return CFrame.new()
	end
	return CFrame.new(p.x or 0, p.y or 0, p.z or 0)
		* CFrame.Angles(math.rad(p.rx or 0), math.rad(p.ry or 0), math.rad(p.rz or 0))
end

for _, anim in pairs(Data) do
	anim.UsedJoints = {}
	anim.Markers = {}
	for _, kf in ipairs(anim.Keyframes) do
		for jointName in pairs(kf.Poses) do
			anim.UsedJoints[jointName] = true
		end
		if kf.Marker then
			table.insert(anim.Markers, { Name = kf.Marker, Time = kf.Time })
		end
	end
	for _, kf in ipairs(anim.Keyframes) do
		kf.CFrames = {}
		for jointName in pairs(anim.UsedJoints) do
			kf.CFrames[jointName] = toCFrame(kf.Poses[jointName])
		end
	end
end

-- Pose of one joint in one keyframe (used by the builder to make KeyframeSequences).
function GuardianAnimations.GetKeyframePose(animName, keyframeIndex, jointName)
	return Data[animName].Keyframes[keyframeIndex].CFrames[jointName] or CFrame.new()
end

local function sample(anim, t, jointName)
	local kfs = anim.Keyframes
	local last = kfs[#kfs]
	if t >= last.Time then
		return last.CFrames[jointName]
	end
	for i = 1, #kfs - 1 do
		local a, b = kfs[i], kfs[i + 1]
		if t <= b.Time then
			local span = b.Time - a.Time
			local alpha = span > 0 and (t - a.Time) / span or 1
			alpha = (1 - math.cos(alpha * math.pi)) / 2 -- ease in-out
			return a.CFrames[jointName]:Lerp(b.CFrames[jointName], alpha)
		end
	end
	return last.CFrames[jointName]
end

---------------------------------------------------------------------------
-- Controller
---------------------------------------------------------------------------

function GuardianAnimations.new(model)
	local self = setmetatable({}, GuardianAnimations)
	self.Model = model
	self.Tracks = {}

	local ids = {
		Walk = model:GetAttribute("WalkAnimationId"),
		Attack = model:GetAttribute("AttackAnimationId"),
		Summon = model:GetAttribute("SummonAnimationId"),
	}
	local allSet = true
	for _, id in pairs(ids) do
		if type(id) ~= "string" or id == "" then
			allSet = false
		end
	end

	if allSet then
		-- Real Roblox animations through the Humanoid's Animator.
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		self.RobloxTracks = {}
		for name, id in pairs(ids) do
			if not string.find(id, "rbxassetid://", 1, true) then
				id = "rbxassetid://" .. id
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Looped = Data[name].Looped
			track.Priority = Enum.AnimationPriority[Data[name].Priority]
			self.RobloxTracks[name] = track
		end
		return self
	end

	-- Procedural: drive Motor6D.C0 from the keyframe data.
	self.Motors = {}
	for _, joint in ipairs(GuardianAnimations.Joints) do
		local part1 = model:FindFirstChild(joint.Part1, true)
		local motor = part1 and part1:FindFirstChild(joint.Name)
		if motor and motor:IsA("Motor6D") then
			self.Motors[joint.Name] = { Motor = motor, BaseC0 = motor.C0 }
		else
			warn("[GuardianAnimations] Missing Motor6D: " .. joint.Name)
		end
	end

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	model.Destroying:Connect(function()
		self:Destroy()
	end)
	return self
end

-- Plays an animation. onMarker(markerName) is called for "Hit" / "Summon".
-- Returns the animation's length in seconds.
function GuardianAnimations:Play(name, fadeTime, onMarker)
	local anim = Data[name]
	assert(anim, "Unknown animation: " .. tostring(name))
	fadeTime = fadeTime or 0.15

	if self.RobloxTracks then
		local track = self.RobloxTracks[name]
		if self._markerConnections and self._markerConnections[name] then
			for _, c in ipairs(self._markerConnections[name]) do
				c:Disconnect()
			end
		end
		self._markerConnections = self._markerConnections or {}
		self._markerConnections[name] = {}
		if onMarker then
			for _, marker in ipairs(anim.Markers) do
				table.insert(
					self._markerConnections[name],
					track:GetMarkerReachedSignal(marker.Name):Connect(function()
						onMarker(marker.Name)
					end)
				)
			end
		end
		track:Play(fadeTime)
		return anim.Length
	end

	local existing = self.Tracks[name]
	self.Tracks[name] = {
		Anim = anim,
		Time = 0,
		Weight = existing and existing.Weight or 0,
		Target = 1,
		FadeTime = fadeTime,
		OnMarker = onMarker,
		NextMarker = 1,
	}
	return anim.Length
end

function GuardianAnimations:Stop(name, fadeTime)
	if self.RobloxTracks then
		self.RobloxTracks[name]:Stop(fadeTime or 0.2)
		return
	end
	local track = self.Tracks[name]
	if track then
		track.Target = 0
		track.FadeTime = fadeTime or 0.2
	end
end

function GuardianAnimations:IsPlaying(name)
	if self.RobloxTracks then
		return self.RobloxTracks[name].IsPlaying
	end
	local track = self.Tracks[name]
	return track ~= nil and track.Target > 0
end

function GuardianAnimations:GetLength(name)
	return Data[name].Length
end

function GuardianAnimations:_step(dt)
	-- Advance tracks, fire markers, handle fades.
	for name, track in pairs(self.Tracks) do
		local anim = track.Anim
		track.Time = track.Time + dt
		if anim.Looped then
			if track.Time >= anim.Length then
				track.Time = track.Time % anim.Length
				track.NextMarker = 1
			end
		elseif track.Time >= anim.Length then
			track.Time = anim.Length
			track.Target = 0
		end

		local marker = anim.Markers[track.NextMarker]
		while marker and track.Time >= marker.Time do
			if track.OnMarker then
				task.spawn(track.OnMarker, marker.Name)
			end
			track.NextMarker = track.NextMarker + 1
			marker = anim.Markers[track.NextMarker]
		end

		local step = track.FadeTime > 0 and dt / track.FadeTime or 1
		if track.Weight < track.Target then
			track.Weight = math.min(track.Target, track.Weight + step)
		elseif track.Weight > track.Target then
			track.Weight = math.max(track.Target, track.Weight - step)
		end
		if track.Target == 0 and track.Weight <= 0 then
			self.Tracks[name] = nil
		end
	end

	-- Layer tracks from lowest to highest priority.
	local ordered = {}
	for _, track in pairs(self.Tracks) do
		table.insert(ordered, track)
	end
	table.sort(ordered, function(a, b)
		return PRIORITY_ORDER[a.Anim.Priority] < PRIORITY_ORDER[b.Anim.Priority]
	end)

	for jointName, info in pairs(self.Motors) do
		local pose = CFrame.new()
		for _, track in ipairs(ordered) do
			if track.Anim.UsedJoints[jointName] and track.Weight > 0 then
				pose = pose:Lerp(sample(track.Anim, track.Time, jointName), track.Weight)
			end
		end
		info.Motor.C0 = info.BaseC0 * pose
	end
end

function GuardianAnimations:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

return GuardianAnimations
