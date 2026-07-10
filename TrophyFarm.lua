-- Auto Farm Trophy (1-Speed-Keyboard-Escape-Candy-Chocolate)
-- Walks the character forward toward each WinBlock checkpoint in order
-- (Stage2.WinBlock1 .. Stage14.WinBlock13) using real humanoid movement
-- instead of teleporting -- confirmed in-game that the win-grant logic
-- validates genuine movement, so a teleport-based touch never counted.
-- Advancement to the next waypoint is driven by an actual .Touched
-- connection on the current WinBlock (the same event that grants the win),
-- with a stuck-timeout fallback so the loop can't get stuck forever.
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
	Enabled = true,
	ArriveDistance = 10,      -- flat (XZ) distance considered "at" the waypoint
	StuckTimeout = 8,         -- seconds with no touch + no progress before skipping ahead anyway
	JumpInterval = 1.2,       -- min seconds between anti-stuck jumps
	MoveSpeed = 250,          -- studs/sec driven directly via velocity (Humanoid:Move can get
	                          -- overridden by the game's own control scripts if you aren't
	                          -- actually touching the controls, so this is the primary driver)
	UseTrophyPrompt = true,   -- also trigger the hub's x2 Wins prompt periodically
	TrophyPromptInterval = 5, -- seconds between x2 Wins attempts
}

local structure = Workspace:WaitForChild("Structure")

-- Known WinBlock world positions from TrophyScan2/TrophyScan3 (WinBlock1..13 =
-- Stage2..14). Stage15 has a reward too ("+50K Wins") but under a different
-- name we haven't identified yet, so it's not included here.
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
local MAX_WAYPOINT = 13

local function getCharacterParts()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
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
-- AUTO-RUN STATE
-- ============================================================
local State = {
	waypoint = 1,
	lastProgressTime = tick(),
	lastJumpTime = 0,
	lastPos = nil,
	lastStatusPrint = 0,
}
local touchConnections = {}

local function advanceWaypoint(reason)
	print(string.format("[TrophyFarm] WinBlock%d cleared (%s)", State.waypoint, reason))
	State.waypoint = State.waypoint + 1
	if State.waypoint > MAX_WAYPOINT then
		State.waypoint = 1
		print("[TrophyFarm] lap complete -- looping back to WinBlock1")
	end
	State.lastProgressTime = tick()
end

local function connectWinBlockTouch(n)
	if touchConnections[n] then return end
	local part = findWinBlockByNumber(n)
	if not part then return end
	touchConnections[n] = part.Touched:Connect(function(hit)
		local _, hrp = getCharacterParts()
		if hrp and (hit == hrp or hit:IsDescendantOf(hrp.Parent)) and State.waypoint == n then
			advanceWaypoint("Touched")
		end
	end)
end

local function autoRunStep()
	local _, hrp, hum = getCharacterParts()
	if not hrp or not hum then return end

	connectWinBlockTouch(State.waypoint)

	local target = KNOWN_WINBLOCK_POSITIONS[State.waypoint]
	if not target then
		State.waypoint = 1
		target = KNOWN_WINBLOCK_POSITIONS[1]
	end

	local toTarget = target - hrp.Position
	local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

	-- Track real progress (moved meaningfully since last frame) for the
	-- stuck-jump/stuck-skip logic, independent of the Touched-based advance.
	if State.lastPos then
		if (hrp.Position - State.lastPos).Magnitude > 2 then
			State.lastProgressTime = tick()
		end
	end
	State.lastPos = hrp.Position

	if flatDist < Config.ArriveDistance and tick() - State.lastProgressTime > Config.StuckTimeout then
		-- Arrived close enough but Touched never fired (streaming lag, missed
		-- connection, etc.) -- don't get stuck forever, move on anyway.
		advanceWaypoint("stuck-timeout at close range")
		return
	end

	if tick() - State.lastProgressTime > Config.StuckTimeout then
		-- Not making progress at all and not close either -- still move on
		-- rather than idling forever against a wall.
		advanceWaypoint("stuck-timeout, no progress")
		return
	end

	local dir = toTarget.Unit
	hum:Move(Vector3.new(dir.X, 0, dir.Z), false)
	hrp.AssemblyLinearVelocity = Vector3.new(dir.X * Config.MoveSpeed, hrp.AssemblyLinearVelocity.Y, dir.Z * Config.MoveSpeed)

	if flatDist > Config.ArriveDistance
		and tick() - State.lastJumpTime > Config.JumpInterval
		and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
		hum.Jump = true
		State.lastJumpTime = tick()
	end

	if tick() - State.lastStatusPrint > 2 then
		State.lastStatusPrint = tick()
		print(string.format("[TrophyFarm] waypoint=%d flatDist=%.1f pos=(%.1f,%.1f,%.1f) WalkSpeed=%s MoveDir=(%.2f,%.2f,%.2f)",
			State.waypoint, flatDist, hrp.Position.X, hrp.Position.Y, hrp.Position.Z,
			tostring(hum.WalkSpeed), hum.MoveDirection.X, hum.MoveDirection.Y, hum.MoveDirection.Z))
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
		btn.Text = "RUN: ON (tap to stop)"
		btn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
	else
		btn.Text = "RUN: OFF (tap to start)"
		btn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
	end
end
refreshButton()

-- ============================================================
-- "GO TO #" INPUT: jump the auto-run's target straight to a WinBlock number
-- (still walks/runs there for real -- this only skips which waypoint it's
-- currently chasing, it never teleports).
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
	input.Text = ""
	if not n then
		input.PlaceholderText = "enter a number"
		return
	end
	n = math.floor(n)
	if n < 1 or n > MAX_WAYPOINT then
		input.PlaceholderText = "1-" .. MAX_WAYPOINT .. " only"
		return
	end
	State.waypoint = n
	State.lastProgressTime = tick()
	print("[TrophyFarm] now heading for WinBlock" .. n)
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
			task.wait(0.3)
		else
			local ok, err = pcall(autoRunStep)
			if not ok then
				warn("[TrophyFarm] autoRunStep error: " .. tostring(err))
			end

			if Config.UseTrophyPrompt and (tick() - lastTrophyFire) >= Config.TrophyPromptInterval then
				pcall(fireHubTrophy)
				lastTrophyFire = tick()
			end

			RunService.Heartbeat:Wait()
		end
	end
end)

getgenv().TrophyFarm = {
	Stop = function() Config.Enabled = false; refreshButton() end,
	Start = function() Config.Enabled = true; refreshButton() end,
	Config = Config,
	State = State,
}

print("[TrophyFarm] started -- auto-running toward WinBlock1..WinBlock13 (real movement, no teleport). Tap the on-screen button (or call getgenv().TrophyFarm.Stop()) to pause.")
