-- Auto Farm Trophy (1-Speed-Keyboard-Escape-Candy-Chocolate)
-- Loops through every WinBlock checkpoint (Stage2.WinBlock1 .. Stage12.WinBlock11)
-- to rack up wins, and periodically holds the hub's "x2 Wins" Trophy prompt.
-- Built from TrophyScan/TrophyScan2 output: no WinBlock exists in Stage1/13/14/15,
-- so those are skipped automatically (the scan just didn't find one there).
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Config = {
	Enabled = true,
	DelayPerBlock = 0.35,     -- time to let the Touched event register before moving on
	UseTrophyPrompt = true,   -- also trigger the hub's x2 Wins prompt periodically
	TrophyPromptInterval = 5, -- seconds between x2 Wins attempts
}

local structure = Workspace:WaitForChild("Structure")

local function getCharacterParts()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return char, hrp
end

local function getWinBlocks()
	local blocks = {}
	for _, stage in ipairs(structure:GetChildren()) do
		if stage.Name:match("^Stage") then
			for _, inst in ipairs(stage:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Name:match("^WinBlock%d+$") then
					local n = tonumber(inst.Name:match("%d+"))
					if n then table.insert(blocks, {n = n, part = inst}) end
				end
			end
		end
	end
	table.sort(blocks, function(a, b) return a.n < b.n end)
	local ordered = {}
	for _, b in ipairs(blocks) do table.insert(ordered, b.part) end
	return ordered
end

local function touchBlock(part)
	if not Config.Enabled then return end
	local _, hrp = getCharacterParts()
	if not hrp or not part or not part.Parent then return end

	hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
	task.wait(0.05)

	-- Nudge the Touched event directly when the executor supports it, in
	-- addition to the teleport-based collision (belt and suspenders).
	if firetouchinterest then
		pcall(firetouchinterest, hrp, part, 0)
		task.wait()
		pcall(firetouchinterest, hrp, part, 1)
	end

	task.wait(Config.DelayPerBlock)
end

local function findHubTrophyPrompt()
	local hub = structure:FindFirstChild("Stage0_HUB")
	local trophy = hub and hub:FindFirstChild("Trophy")
	if not trophy then return nil, nil end
	for _, d in ipairs(trophy:GetDescendants()) do
		if d:IsA("ProximityPrompt") then return trophy, d end
	end
	return trophy, nil
end

local function fireHubTrophy()
	local trophy, prompt = findHubTrophyPrompt()
	if not trophy or not prompt then return end

	local _, hrp = getCharacterParts()
	if hrp then
		local ok, pivot = pcall(function() return trophy:GetPivot() end)
		if ok then
			hrp.CFrame = pivot + Vector3.new(0, 3, 0)
			task.wait(0.1)
		end
	end

	if fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait((prompt.HoldDuration or 0) + 0.05)
			prompt:InputHoldEnd()
		end)
	end
end

task.spawn(function()
	local lastTrophyFire = 0
	while true do
		if not Config.Enabled then
			task.wait(0.5)
		else
			local blocks = getWinBlocks()
			if #blocks == 0 then
				task.wait(1)
			else
				for _, part in ipairs(blocks) do
					if not Config.Enabled then break end
					touchBlock(part)

					if Config.UseTrophyPrompt and (tick() - lastTrophyFire) >= Config.TrophyPromptInterval then
						pcall(fireHubTrophy)
						lastTrophyFire = tick()
					end
				end
			end
		end
	end
end)

getgenv().TrophyFarm = {
	Stop = function() Config.Enabled = false end,
	Start = function() Config.Enabled = true end,
	Config = Config,
}

print("[TrophyFarm] started -- looping WinBlock1..WinBlock11. Call getgenv().TrophyFarm.Stop() to pause.")
