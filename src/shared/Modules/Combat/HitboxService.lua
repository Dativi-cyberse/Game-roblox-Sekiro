-- HitboxService.lua
-- Animation-driven hit detection using markers (HitStart, HitEnd)
-- WHY: No always-on hitboxes - hit detection only during animation windows

local CombatConfig = require(script.Parent.Parent.Parent.CombatConfig)
local Workspace = game:GetService("Workspace")

local HitboxService = {}

-- =====================================================
-- HITBOX CREATION
-- =====================================================

--- Creates a temporary hitbox in front of the character
-- WHY: Hitbox only exists during HitStart/HitEnd marker window
-- @param character Model - Character model
-- @param duration number - How long the hitbox should exist
-- @return Part - The hitbox part (will be destroyed after duration)
function HitboxService.CreateHitbox(character, duration)
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local hitbox = Instance.new("Part")
	hitbox.Name = "CombatHitbox"
	hitbox.Transparency = 1 -- Invisible
	hitbox.CanCollide = false
	hitbox.Anchored = true
	hitbox.Size = CombatConfig.Hitbox.Size
	
	-- Position hitbox in front of character
	local cf = rootPart.CFrame
	local forward = cf.LookVector
	local position = cf.Position + (forward * CombatConfig.Hitbox.ForwardOffset)
	hitbox.CFrame = CFrame.new(position, position + forward)
	
	hitbox.Parent = Workspace
	
	-- Destroy after duration
	game:GetService("Debris"):AddItem(hitbox, duration)
	
	return hitbox
end

--- Gets all valid targets within the hitbox
-- WHY: Server validates targets to prevent exploitation
-- @param hitbox Part - The hitbox part
-- @param attacker Model - The attacking character (excluded from results)
-- @param range number - Maximum range for target detection
-- @return table - Array of valid target characters
function HitboxService.GetTargetsInHitbox(hitbox, attacker, range)
	if not hitbox or not attacker then
		return {}
	end
	
	local targets = {}
	local hitboxPosition = hitbox.Position
	local hitboxSize = hitbox.Size
	local attackerUserId = nil
	
	-- Get attacker's userId if it's a player
	local attackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attacker)
	if attackerPlayer then
		attackerUserId = attackerPlayer.UserId
	end
	
	-- Check all characters in workspace
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:FindFirstChild("Humanoid") then
			local humanoid = descendant:FindFirstChild("Humanoid")
			
			-- Skip invalid targets
			if humanoid.Health > 0 and descendant ~= attacker then
				-- Check if character is within hitbox bounds
				local rootPart = descendant:FindFirstChild("HumanoidRootPart")
				if rootPart then
			
					-- Calculate distance from hitbox center
					local distance = (rootPart.Position - hitboxPosition).Magnitude
					local maxDistance = (hitboxSize.Magnitude / 2) + (range or CombatConfig.Attack.Range)
					
					if distance <= maxDistance then
						-- Additional validation: check if target is in front of attacker
						if HitboxService.IsInFrontOfAttacker(attacker, rootPart.Position) then
							table.insert(targets, {
								character = descendant,
								humanoid = humanoid,
								rootPart = rootPart,
							})
						end
					end
				end
			end
		end
	end
	
	return targets
end

--- Checks if a position is in front of the attacker
-- WHY: Prevents hitting targets behind the character
-- @param attacker Model - Attacking character
-- @param targetPosition Vector3 - Target position to check
-- @return boolean - True if target is in front
function HitboxService.IsInFrontOfAttacker(attacker, targetPosition)
	local rootPart = attacker:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end
	
	local attackerPosition = rootPart.Position
	local attackerForward = rootPart.CFrame.LookVector
	local toTarget = (targetPosition - attackerPosition).Unit
	
	-- Dot product: positive = in front, negative = behind
	local dot = attackerForward:Dot(toTarget)
	return dot > 0.3 -- 0.3 threshold allows slight angle tolerance
end

--- Validates attack range between two characters
-- WHY: Server-side range validation prevents exploitation
-- @param attacker Model - Attacking character
-- @param target Model - Target character
-- @param maxRange number - Maximum allowed range
-- @return boolean - True if target is within range
function HitboxService.ValidateRange(attacker, target, maxRange)
	if not attacker or not target then
		return false
	end
	
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	
	if not attackerRoot or not targetRoot then
		return false
	end
	
	local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
	return distance <= (maxRange or CombatConfig.Attack.Range)
end

return HitboxService

