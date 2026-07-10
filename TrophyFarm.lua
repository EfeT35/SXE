-- Auto Farm Trophy (1-Speed-Keyboard-Escape-Candy-Chocolate)
-- Loops through every WinBlock checkpoint (Stage2.WinBlock1 .. Stage14.WinBlock13,
-- rewards scale up to +25K Wins at the later stages) and periodically holds the
-- hub's "x2 Wins" Trophy prompt. Stage1 and Stage15 have no WinBlock (confirmed
-- via TrophyScan/TrophyScan2/TrophyScan3), so they're skipped.
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
	Enabled = true,
	DelayPerBlock = 0.35,     -- time to let the Touched event register before moving on
	UseTrophyPrompt = true,   -- also trigger the hub's x2 Wins prompt periodically
	TrophyPromptInterval = 5, -- seconds between x2 Wins attempts
}

local structure = Workspace:WaitForChild("Structure")

-- Known WinBlock world positions from TrophyScan2/TrophyScan3 (WinBlock1..13 =
-- Stage2..14; Stage15 has no WinBlock, it's the final stage).
-- Distant stages haven't necessarily streamed in yet (the character never
-- walked there), so a plain name lookup can fail even though the part
-- genuinely exists -- these positions let us force that region to load first.
local KNOWN_WINBLOCK_POSITIONS = {
	[1] = Vector3.new(-16.5, 6.9, 284.7),
	[2] = Vector3.new(-16.5, 6.9, 506.7),
	[3] = Vector3.new(-16.5, 75.1, 774.4),
	[4] = Vector3.new(-16.5, 75.1, 1108.4),
	[5] = Vector3.new(-16.5, 75.1, 1411.3),
	[6] = Vector3.new(-538.4, 52.5, 1447.9),
	[7] = Vector3.new(-1007.7, 52.5, 1447.9),
	[8] = Vector3.new(-1123.5, 294.5, 1447.9),
	[9] = Vector3.new(-2970.3, 294.5, 1447.9),
	[10] = Vector3.new(-3938.4, 294.5, 1447.9),
	[11] = Vector3.new(-4368.3, 469.0, 1512.4),
	[12] = Vector3.new(-5342.9, 468.6, 1457.1),
	[13] = Vector3.new(-6809.9, 519.1, 1469.1),
}

local function getCharacterParts()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return char, hrp
end

print(string.format("[TrophyFarm] executor caps: firetouchinterest=%s fireproximityprompt=%s",
	tostring(firetouchinterest ~= nil), tostring(fireproximityprompt ~= nil)))

local function teleportToPart(part)
	local _, hrp = getCharacterParts()
	if not hrp or not part or not part.Parent then return false end

	print(string.format("[TrophyFarm] -> %s | CanCollide=%s CanTouch=%s",
		part:GetFullName(), tostring(part.CanCollide), tostring(part.CanTouch)))

	-- Land ON the part's top surface, not floating a few studs above it --
	-- Touched only fires from genuine physical overlap, and hovering above a
	-- thin pad never actually touches it.
	local halfHeight = (part.Size and part.Size.Y or 2) / 2
	local landCFrame = CFrame.new(part.Position.X, part.Position.Y + halfHeight + 2, part.Position.Z)

	-- Hold the HRP there for ~15 physics frames (re-asserting each frame) so
	-- gravity/the character controller carrying it away doesn't cut the
	-- overlap short before the server has a chance to detect the Touched.
	for i = 1, 15 do
		if not hrp.Parent then break end
		hrp.CFrame = landCFrame
		hrp.AssemblyLinearVelocity = Vector3.zero

		if firetouchinterest and i == 3 then
			pcall(firetouchinterest, hrp, part, 0)
		end
		if firetouchinterest and i == 5 then
			pcall(firetouchinterest, hrp, part, 1)
		end

		RunService.Heartbeat:Wait()
	end
	return true
end

local function findWinBlockByNumber(n)
	for _, stage in ipairs(structure:GetChildren()) do
		if stage.Name:match("^Stage") then
			local part = stage:FindFirstChild("WinBlock" .. n, true)
			if part and part:IsA("BasePart") then return part end
		end
	end
	return nil
end

-- Teleports to WinBlock #n. If it isn't loaded client-side yet (far/unstreamed
-- stage), moves the HRP to the known position, asks the client to stream that
-- region in, and retries the real lookup+touch once it's had a moment to load.
local function teleportToWinBlockNumber(n)
	local part = findWinBlockByNumber(n)
	if part then return teleportToPart(part) end

	local knownPos = KNOWN_WINBLOCK_POSITIONS[n]
	if not knownPos then return false end

	local _, hrp = getCharacterParts()
	if hrp then hrp.CFrame = CFrame.new(knownPos + Vector3.new(0, 3, 0)) end

	pcall(function()
		if LocalPlayer.RequestStreamAroundAsync then
			LocalPlayer:RequestStreamAroundAsync(knownPos)
		end
	end)
	task.wait(0.75)

	part = findWinBlockByNumber(n)
	if part then return teleportToPart(part) end
	return false
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

-- ============================================================
-- UI: single draggable container holding the toggle + "go to #" row,
-- so nothing overlaps and both move together. Spawns centered.
-- ============================================================
local old = PlayerGui:FindFirstChild("TrophyFarmGui")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrophyFarmGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.Parent = PlayerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.fromOffset(140, 79)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.new(0.5, 0, 0.5, 0)
container.BackgroundTransparency = 1
container.Parent = screenGui

local btn = Instance.new("TextButton")
btn.Name = "ToggleButton"
btn.Size = UDim2.fromOffset(140, 40)
btn.Position = UDim2.fromOffset(0, 0)
btn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.TextColor3 = Color3.new(1, 1, 1)
btn.AutoButtonColor = false
btn.Active = true
btn.ZIndex = 2
btn.Parent = container
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local function refreshButton()
	if Config.Enabled then
		btn.Text = "TP: ON (tap to stop)"
		btn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
	else
		btn.Text = "TP: OFF (tap to start)"
		btn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
	end
end
refreshButton()

-- ============================================================
-- "GO TO #" INPUT: teleport straight to a specific WinBlock number
-- ============================================================
local goRow = Instance.new("Frame")
goRow.Name = "GoToRow"
goRow.Size = UDim2.fromOffset(140, 34)
goRow.Position = UDim2.fromOffset(0, 45)
goRow.BackgroundTransparency = 1
goRow.ZIndex = 2
goRow.Parent = container

local input = Instance.new("TextBox")
input.Name = "WinBlockInput"
input.Size = UDim2.fromOffset(80, 34)
input.Position = UDim2.fromOffset(0, 0)
input.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
input.BorderSizePixel = 0
input.Font = Enum.Font.GothamBold
input.TextSize = 14
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderText = "1-13"
input.Text = ""
input.ClearTextOnFocus = false
input.ZIndex = 2
input.Parent = goRow
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)

local goBtn = Instance.new("TextButton")
goBtn.Name = "GoButton"
goBtn.Size = UDim2.fromOffset(56, 34)
goBtn.Position = UDim2.fromOffset(84, 0)
goBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 220)
goBtn.BorderSizePixel = 0
goBtn.Font = Enum.Font.GothamBold
goBtn.TextSize = 14
goBtn.TextColor3 = Color3.new(1, 1, 1)
goBtn.AutoButtonColor = false
goBtn.Text = "GO"
goBtn.ZIndex = 2
goBtn.Parent = goRow
Instance.new("UICorner", goBtn).CornerRadius = UDim.new(0, 8)

local function goToWinBlock()
	local n = tonumber(input.Text)
	if not n then
		input.PlaceholderText = "enter a number"
		input.Text = ""
		return
	end
	n = math.floor(n)
	input.Text = ""
	if not teleportToWinBlockNumber(n) then
		input.PlaceholderText = "WinBlock " .. n .. " not found"
	end
end
goBtn.MouseButton1Click:Connect(goToWinBlock)
input.FocusLost:Connect(function(enterPressed)
	if enterPressed then goToWinBlock() end
end)

-- Drag handle: a thin strip along the top of the toggle button. Dragging it
-- moves the whole container (both rows together); tapping the rest of the
-- button still toggles normally.
local dragHandle = Instance.new("Frame")
dragHandle.Name = "DragHandle"
dragHandle.Size = UDim2.new(1, 0, 0, 12)
dragHandle.Position = UDim2.fromOffset(0, 0)
dragHandle.BackgroundColor3 = Color3.new(1, 1, 1)
dragHandle.BackgroundTransparency = 0.85
dragHandle.ZIndex = 3
dragHandle.Active = true
dragHandle.Parent = btn
Instance.new("UICorner", dragHandle).CornerRadius = UDim.new(0, 8)

local dragging, dragStart, startPos = false, nil, nil
dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = container.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
btn.MouseButton1Click:Connect(function()
	Config.Enabled = not Config.Enabled
	refreshButton()
end)

task.spawn(function()
	local lastTrophyFire = 0
	while true do
		if not Config.Enabled then
			task.wait(0.5)
		else
			for n = 1, 13 do
				if not Config.Enabled then break end
				teleportToWinBlockNumber(n)
				task.wait(Config.DelayPerBlock)

				if Config.UseTrophyPrompt and (tick() - lastTrophyFire) >= Config.TrophyPromptInterval then
					pcall(fireHubTrophy)
					lastTrophyFire = tick()
				end
			end
		end
	end
end)

getgenv().TrophyFarm = {
	Stop = function() Config.Enabled = false; refreshButton() end,
	Start = function() Config.Enabled = true; refreshButton() end,
	Config = Config,
}

print("[TrophyFarm] started -- looping WinBlock1..WinBlock13. Tap the on-screen button (or call getgenv().TrophyFarm.Stop()) to pause.")
