-- Anti-Hit (noclip): disables collision on every part of your character so
-- traps/obstacles can't physically stop or register a hit against you.
-- Reapplies continuously since respawns and some game scripts reset
-- CanCollide back to true on their own.
-- Note: this stops COLLISION-based hits. If a hazard is detected purely via
-- server-side Touched/overlap regardless of CanCollide, passing all the way
-- through it can still register a touch -- combine with NoDeath.lua (health
-- lock) for that case, and tell me which specific obstacle still gets you.
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Config = { Enabled = true }
local noclipConnection = nil

local function applyNoclip(char)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

local function onCharacterAdded(char)
	applyNoclip(char)
	char.DescendantAdded:Connect(function(desc)
		if Config.Enabled and desc:IsA("BasePart") then
			desc.CanCollide = false
		end
	end)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

if noclipConnection then noclipConnection:Disconnect() end
noclipConnection = RunService.Stepped:Connect(function()
	if not Config.Enabled then return end
	local char = LocalPlayer.Character
	if not char then return end
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

getgenv().AntiHit = {
	Disable = function()
		Config.Enabled = false
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
		print("[AntiHit] disabled, collision restored")
	end,
	Enable = function()
		Config.Enabled = true
		local char = LocalPlayer.Character
		if char then applyNoclip(char) end
		print("[AntiHit] enabled")
	end,
}

print("[AntiHit] active -- getgenv().AntiHit.Disable() to turn off, .Enable() to turn back on.")
