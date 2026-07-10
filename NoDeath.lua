-- No Death: keeps your Humanoid's health pinned at max so hazards/traps
-- (lava, spikes, the "BarreRouge" stuff, fall damage, etc.) can't kill you.
-- Client-side health lock: works against anything that damages Health
-- normally. It can't stop a kill mechanism that doesn't go through Health
-- (e.g. a script that force-teleports you into the void or destroys your
-- character directly) -- tell me if you still die somewhere and I'll add
-- a targeted fix for that specific case.
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local healthConnections = {}

local function lockHealth(hum)
	pcall(function() hum.MaxHealth = math.huge end)
	pcall(function() hum.Health = hum.MaxHealth end)

	local conn = hum.HealthChanged:Connect(function(health)
		if health < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
	end)
	table.insert(healthConnections, conn)
end

local function onCharacterAdded(char)
	for _, conn in ipairs(healthConnections) do
		pcall(function() conn:Disconnect() end)
	end
	healthConnections = {}

	local hum = char:WaitForChild("Humanoid")
	lockHealth(hum)
	print("[NoDeath] health locked for (re)spawned character")
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

getgenv().NoDeath = {
	Disable = function()
		for _, conn in ipairs(healthConnections) do
			pcall(function() conn:Disconnect() end)
		end
		healthConnections = {}
		print("[NoDeath] disabled")
	end,
}

print("[NoDeath] active -- call getgenv().NoDeath.Disable() to turn it off.")
