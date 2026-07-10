-- Auto Farm Trophy (1-Speed-Keyboard-Escape-Candy-Chocolate)
-- Discovered on the shop wall: equipped "shoes" grant Wins per STEP taken
-- (+1/pas, +2/pas, up to +100/pas requiring more total wins to unlock).
-- That's a far safer, more reliable farm than navigating the obstacle
-- course (which has turns/hazards a straight-line bot kept running into
-- and dying on). This walks the character gently back and forth in place,
-- right where you start it, to rack up steps with zero navigation risk.
--
-- The WinBlock checkpoints (Stage2.WinBlock1 .. Stage14.WinBlock13) still
-- exist for one-off manual claims via the GO input below -- confirmed
-- in-game that touching them for real (not teleporting) grants a win, so
-- GO walks there for real using the same movement + obstacle-avoidance
-- logic, once, instead of teleporting.
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
	Enabled = false,      -- starts off; tap ON once you're standing somewhere safe
	StepRadius = 5,       -- studs to walk back and forth from the start point
	StepTimeout = 3,      -- max seconds to wait per leg before switching anyway
	MoveSpeed = 250,      -- studs/sec for the manual GO-to-WinBlock walk
}

local structure = Workspace:WaitForChild("Structure")

-- Known WinBlock world positions (WinBlock1..13 = Stage2..14), for the
-- manual GO input only -- not used by the step-in-place farm.
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

local State = {
	dead = false,
	homeCFrame = nil,  -- captured the moment stepping is enabled
	stepDir = 1,       -- 1 = forward, -1 = backward from homeCFrame
}

-- ============================================================
-- DEATH HANDLING: pause while dead, resume automatically on respawn
-- ============================================================
local function onCharacterAdded(char)
	State.dead = false
	State.homeCFrame = nil -- re-anchor wherever the respawned character ends up
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		print("[TrophyFarm] character died -- pausing until respawn")
		State.dead = true
	end)
	char:WaitForChild("HumanoidRootPart")
	print("[TrophyFarm] character (re)spawned")
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

-- ============================================================
-- STEP-IN-PLACE FARM: walks back and forth a few studs from wherever
-- stepping was enabled, checking for ground before each leg so it can't
-- walk itself off a ledge.
-- ============================================================
local function hasGroundBelow(pos, char)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	return Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), params) ~= nil
end

local function stepFarmTick()
	local char, hrp, hum = getCharacterParts()
	if not char or not hrp or not hum then return end

	if not State.homeCFrame then
		State.homeCFrame = hrp.CFrame
		print("[TrophyFarm] step-farm anchored here: " .. tostring(hrp.Position))
	end

	local forward = State.homeCFrame.LookVector
	local targetPos = State.homeCFrame.Position + forward * (Config.StepRadius * State.stepDir)

	if not hasGroundBelow(targetPos, char) then
		-- No floor that way (edge/gap) -- flip direction and try the other leg.
		State.stepDir = -State.stepDir
		return
	end

	hum:MoveTo(targetPos)
	local done = false
	local conn
	conn = hum.MoveToFinished:Connect(function() done = true end)
	local start = tick()
	while not done and tick() - start < Config.StepTimeout and Config.Enabled and not State.dead do
		task.wait(0.1)
	end
	conn:Disconnect()

	State.stepDir = -State.stepDir
end

-- ============================================================
-- MANUAL "GO TO #": walks (doesn't teleport) to a specific WinBlock, once,
-- with the same obstacle-avoidance used for the old auto-run.
-- ============================================================
local function isPathClear(origin, dir, filterInstance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {filterInstance}
	return Workspace:Raycast(origin, dir * 8, params) == nil
end

local function computeMoveDirection(hrp, dir, char)
	if isPathClear(hrp.Position, dir, char) then return dir, false end
	for _, angleDeg in ipairs({30, -30, 60, -60, 90, -90}) do
		local rad = math.rad(angleDeg)
		local rotated = Vector3.new(
			dir.X * math.cos(rad) - dir.Z * math.sin(rad),
			0,
			dir.X * math.sin(rad) + dir.Z * math.cos(rad)
		)
		if isPathClear(hrp.Position, rotated, char) then
			return rotated, true
		end
	end
	return dir, true
end

local function walkToWinBlock(n)
	local target = KNOWN_WINBLOCK_POSITIONS[n]
	if not target then return end

	print("[TrophyFarm] walking to WinBlock" .. n .. " ...")
	local start = tick()
	local lastJump = 0
	while tick() - start < 60 do
		local char, hrp, hum = getCharacterParts()
		if not char or not hrp or not hum or State.dead then
			task.wait(0.2)
		else
			local toTarget = target - hrp.Position
			local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
			if flatDist < 8 then
				print("[TrophyFarm] arrived at WinBlock" .. n)
				return
			end

			local dir = toTarget.Unit
			local moveDir, wasBlocked = computeMoveDirection(hrp, Vector3.new(dir.X, 0, dir.Z).Unit, char)
			hum:Move(moveDir, false)
			hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * Config.MoveSpeed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * Config.MoveSpeed)

			if wasBlocked and tick() - lastJump > 0.5 and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
				hum.Jump = true
				lastJump = tick()
			end

			RunService.Heartbeat:Wait()
		end
	end
	print("[TrophyFarm] gave up walking to WinBlock" .. n .. " (60s timeout)")
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
		btn.Text = "STEP: ON (tap to stop)"
		btn.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
	else
		btn.Text = "STEP: OFF (tap to start)"
		btn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
	end
end
refreshButton()

-- ============================================================
-- "GO TO #" INPUT: one-off manual walk to a specific WinBlock
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

local walking = false
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
	if walking then return end
	walking = true
	task.spawn(function()
		local ok, err = pcall(walkToWinBlock, n)
		if not ok then warn("[TrophyFarm] walkToWinBlock error: " .. tostring(err)) end
		walking = false
	end)
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
	if not Config.Enabled then
		State.homeCFrame = nil -- re-anchor fresh next time it's turned on
	end
	refreshButton()
end)

task.spawn(function()
	while true do
		if not Config.Enabled or State.dead then
			task.wait(0.3)
		else
			local ok, err = pcall(stepFarmTick)
			if not ok then
				warn("[TrophyFarm] stepFarmTick error: " .. tostring(err))
				task.wait(0.5)
			end
		end
	end
end)

getgenv().TrophyFarm = {
	Stop = function() Config.Enabled = false; State.homeCFrame = nil; refreshButton() end,
	Start = function() Config.Enabled = true; refreshButton() end,
	Config = Config,
	State = State,
}

print("[TrophyFarm] ready -- stand somewhere safe and tap STEP: OFF to start farming Wins per step. Use the GO box to manually walk to a specific WinBlock (1-13) once.")
