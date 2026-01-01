-- CombatHitHandler.client.lua
-- FINAL – Robust hit sender (MUGEN SAFE)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")
local AttackRemote = CombatRemotes:WaitForChild("Attack")

local CombatHitHandler = {}
CombatHitHandler.__index = CombatHitHandler

function CombatHitHandler.new(context, animationController)
	local self = setmetatable({}, CombatHitHandler)

	self.context = context
	self.animationController = animationController
	self.connections = {}

	self:_bindAnimationSignals()
	print("[CombatHitHandler] Connected to AnimationController")

	return self
end

function CombatHitHandler:_bindAnimationSignals()
	if not self.animationController then return end

	table.insert(
		self.connections,
		self.animationController.animationPlayedSignal.Event:Connect(
			function(slotName, track)
				if not string.find(slotName, "Slash") then return end

				local ok, signal = pcall(function()
					return track:GetMarkerReachedSignal("Hit")
				end)
				if not ok or not signal then return end

				signal:Connect(function()
					self:_onHit()
				end)
			end
		)
	)
end

-- =====================
-- TARGET RESOLUTION
-- =====================
function CombatHitHandler:_resolveTargetEntityId()
	local tr = self.context.TargetResolver
	if tr and tr.GetLockedTarget then
		local model = tr:GetLockedTarget()
		if model and model:GetAttribute("EntityId") then
			return model:GetAttribute("EntityId")
		end
	end

	local root = self.context.Root
	if not root then return nil end

	local closest, dist = nil, math.huge
	for _, model in pairs(Workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EntityId") then
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - root.Position).Magnitude
				if d < 8 and d < dist then
					dist = d
					closest = model:GetAttribute("EntityId")
				end
			end
		end
	end

	return closest
end

-- =====================
-- SEND HIT
-- =====================
function CombatHitHandler:_onHit()
	local targetEntityId = self:_resolveTargetEntityId()
	if not targetEntityId then
		warn("[CombatHitHandler] No target")
		return
	end

	local comboIndex = self.context.comboIndex or 1

	AttackRemote:FireServer({
		targetEntityId = targetEntityId,
		weapon = self.context.weapon and { Name = self.context.weapon.Name } or {},
		comboIndex = comboIndex,
	})

	print("[CombatHitHandler] HIT sent", targetEntityId, comboIndex)
end

return CombatHitHandler
