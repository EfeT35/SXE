-- LocalScript à placer dans StarterPlayer > StarterPlayerScripts
-- Construit toute l'UI (fenêtre "app" + jeu Flappy Bird) au runtime, sans assets externes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("FlappyBirdGui")
if existing then existing:Destroy() end

-- Dimensions du jeu en unités logiques fixes (indépendantes de la résolution réelle)
local WINDOW_WIDTH, TITLEBAR_HEIGHT, GAME_HEIGHT = 360, 36, 640
local GROUND_HEIGHT = 90
local PLAYABLE_HEIGHT = GAME_HEIGHT - GROUND_HEIGHT

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
	return c
end

--============ ScreenGui + fenêtre ============--

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlappyBirdGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = playerGui

local appWindow = Instance.new("Frame")
appWindow.Name = "AppWindow"
appWindow.AnchorPoint = Vector2.new(0.5, 0.5)
appWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
appWindow.Size = UDim2.new(0, WINDOW_WIDTH, 0, TITLEBAR_HEIGHT + GAME_HEIGHT)
appWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
appWindow.BorderSizePixel = 0
appWindow.ClipsDescendants = true
appWindow.Parent = screenGui
corner(appWindow, UDim.new(0, 18))

local uiScale = Instance.new("UIScale")
uiScale.Parent = appWindow

local camera = workspace.CurrentCamera
local function updateScale()
	if not camera then return end
	local viewport = camera.ViewportSize
	local windowHeight = TITLEBAR_HEIGHT + GAME_HEIGHT
	uiScale.Scale = math.clamp(math.min((viewport.Y * 0.92) / windowHeight, (viewport.X * 0.92) / WINDOW_WIDTH), 0.5, 1.6)
end
if camera then
	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
	updateScale()
end)

--============ Barre de titre ============--

local titlebar = Instance.new("Frame")
titlebar.Name = "Titlebar"
titlebar.Size = UDim2.new(1, 0, 0, TITLEBAR_HEIGHT)
titlebar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
titlebar.BorderSizePixel = 0
titlebar.Parent = appWindow

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 14, 0.5, -4)
statusDot.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
statusDot.BorderSizePixel = 0
statusDot.Parent = titlebar
corner(statusDot, UDim.new(1, 0))

local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.new(0, 30, 0, 0)
titleText.Size = UDim2.new(0, 200, 1, 0)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextColor3 = Color3.fromRGB(230, 230, 230)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Text = "FLAPPY BIRD"
titleText.Parent = titlebar

local function titlebarButton(text, xOffset)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 28, 0, 28)
	btn.Position = UDim2.new(1, xOffset, 0.5, -14)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	btn.AutoButtonColor = true
	btn.Text = text
	btn.TextSize = 14
	btn.Font = Enum.Font.Gotham
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)
	btn.Parent = titlebar
	corner(btn, UDim.new(1, 0))
	return btn
end

local trophyBtn = titlebarButton("\240\159\143\134", -70)
trophyBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
local pauseBtn = titlebarButton("| |", -36)

--============ Zone de jeu ============--

local gameArea = Instance.new("Frame")
gameArea.Name = "GameArea"
gameArea.Position = UDim2.new(0, 0, 0, TITLEBAR_HEIGHT)
gameArea.Size = UDim2.new(1, 0, 1, -TITLEBAR_HEIGHT)
gameArea.BackgroundColor3 = Color3.fromRGB(78, 192, 220)
gameArea.ClipsDescendants = true
gameArea.BorderSizePixel = 0
gameArea.Parent = appWindow

-- Nuages décoratifs en parallaxe
local function createCloud(x, y, scale)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, 90 * scale, 0, 40 * scale)
	container.Position = UDim2.new(0, x, 0, y)
	container.ZIndex = 1
	container.Parent = gameArea

	local puffs = {
		{0, 10, 45, 30},
		{25, 0, 45, 40},
		{45, 12, 40, 28},
	}
	for _, p in ipairs(puffs) do
		local puff = Instance.new("Frame")
		puff.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		puff.BackgroundTransparency = 0.15
		puff.BorderSizePixel = 0
		puff.ZIndex = 1
		puff.Size = UDim2.new(0, p[3] * scale, 0, p[4] * scale)
		puff.Position = UDim2.new(0, p[1] * scale, 0, p[2] * scale)
		puff.Parent = container
		corner(puff, UDim.new(1, 0))
	end
	return container
end

local clouds = {
	{ frame = createCloud(20, 50, 1), x = 20, y = 50, speed = 8 },
	{ frame = createCloud(220, 90, 0.8), x = 220, y = 90, speed = 6 },
	{ frame = createCloud(120, 160, 0.6), x = 120, y = 160, speed = 10 },
}

-- Sol
local ground = Instance.new("Frame")
ground.Size = UDim2.new(1, 0, 0, GROUND_HEIGHT)
ground.Position = UDim2.new(0, 0, 1, -GROUND_HEIGHT)
ground.BackgroundColor3 = Color3.fromRGB(222, 184, 111)
ground.BorderSizePixel = 0
ground.ZIndex = 5
ground.Parent = gameArea

local grassStrip = Instance.new("Frame")
grassStrip.Size = UDim2.new(1, 0, 0, 10)
grassStrip.BackgroundColor3 = Color3.fromRGB(94, 201, 98)
grassStrip.BorderSizePixel = 0
grassStrip.ZIndex = 5
grassStrip.Parent = ground

for i = 1, 8 do
	local dash = Instance.new("Frame")
	dash.Size = UDim2.new(0, 20, 0, 4)
	dash.Position = UDim2.new(0, (i - 1) * 46, 0, 30 + (i % 2) * 20)
	dash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dash.BackgroundTransparency = 0.5
	dash.BorderSizePixel = 0
	dash.ZIndex = 6
	dash.Parent = ground
end

-- Oiseau
local BIRD_X, BIRD_RADIUS = 90, 17
local bird = Instance.new("Frame")
bird.Size = UDim2.new(0, BIRD_RADIUS * 2, 0, BIRD_RADIUS * 2)
bird.AnchorPoint = Vector2.new(0.5, 0.5)
bird.BackgroundColor3 = Color3.fromRGB(247, 202, 24)
bird.BorderSizePixel = 0
bird.ZIndex = 10
bird.Parent = gameArea
corner(bird, UDim.new(1, 0))

local eyeWhite = Instance.new("Frame")
eyeWhite.Size = UDim2.new(0, 10, 0, 10)
eyeWhite.Position = UDim2.new(1, -16, 0, 4)
eyeWhite.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
eyeWhite.BorderSizePixel = 0
eyeWhite.ZIndex = 11
eyeWhite.Parent = bird
corner(eyeWhite, UDim.new(1, 0))

local pupil = Instance.new("Frame")
pupil.Size = UDim2.new(0, 5, 0, 5)
pupil.Position = UDim2.new(0, 3, 0, 3)
pupil.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
pupil.BorderSizePixel = 0
pupil.ZIndex = 12
pupil.Parent = eyeWhite
corner(pupil, UDim.new(1, 0))

local beak = Instance.new("Frame")
beak.Size = UDim2.new(0, 14, 0, 8)
beak.Position = UDim2.new(1, -6, 0.5, -4)
beak.BackgroundColor3 = Color3.fromRGB(235, 140, 52)
beak.BorderSizePixel = 0
beak.ZIndex = 11
beak.Parent = bird
corner(beak, UDim.new(0, 3))

local wing = Instance.new("Frame")
wing.Size = UDim2.new(0, 16, 0, 12)
wing.Position = UDim2.new(0, 4, 0.5, -2)
wing.BackgroundColor3 = Color3.fromRGB(230, 170, 20)
wing.BorderSizePixel = 0
wing.ZIndex = 11
wing.Parent = bird
corner(wing, UDim.new(1, 0))

-- Score
local scoreLabel = Instance.new("TextLabel")
scoreLabel.BackgroundTransparency = 1
scoreLabel.Position = UDim2.new(0.5, -60, 0, 16)
scoreLabel.Size = UDim2.new(0, 120, 0, 50)
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 40
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextStrokeTransparency = 0
scoreLabel.TextStrokeColor3 = Color3.fromRGB(40, 40, 40)
scoreLabel.Text = "0"
scoreLabel.ZIndex = 20
scoreLabel.Parent = gameArea

local bestBadge = Instance.new("TextLabel")
bestBadge.BackgroundTransparency = 1
bestBadge.Position = UDim2.new(0.5, -80, 0, 66)
bestBadge.Size = UDim2.new(0, 160, 0, 20)
bestBadge.Font = Enum.Font.GothamBold
bestBadge.TextSize = 14
bestBadge.TextColor3 = Color3.fromRGB(255, 215, 0)
bestBadge.TextStrokeTransparency = 0.4
bestBadge.Text = "Meilleur : 0"
bestBadge.Visible = false
bestBadge.ZIndex = 20
bestBadge.Parent = gameArea

--============ Overlays (start / game over / pause) ============--

local function createOverlay(bgTransparency)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = bgTransparency or 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 30
	overlay.Parent = gameArea

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 260, 0, 220)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = overlay
	corner(card, UDim.new(0, 16))

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.Parent = card

	return overlay, card
end

local function addTitle(card, text, order)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 0, 36)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Text = text
	label.LayoutOrder = order
	label.ZIndex = 32
	label.Parent = card
	return label
end

local function addButton(card, text, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 160, 0, 44)
	btn.BackgroundColor3 = Color3.fromRGB(94, 201, 98)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.LayoutOrder = order
	btn.ZIndex = 32
	btn.Parent = card
	corner(btn, UDim.new(0, 12))
	return btn
end

-- Start screen
local startScreen, startCard = createOverlay(0.15)
addTitle(startCard, "FLAPPY BIRD", 1)
local startSubtitle = Instance.new("TextLabel")
startSubtitle.BackgroundTransparency = 1
startSubtitle.Size = UDim2.new(1, -30, 0, 50)
startSubtitle.Font = Enum.Font.Gotham
startSubtitle.TextSize = 14
startSubtitle.TextWrapped = true
startSubtitle.TextColor3 = Color3.fromRGB(90, 90, 90)
startSubtitle.Text = "Touche l'écran, clique ou appuie sur Espace\npour faire voler l'oiseau"
startSubtitle.LayoutOrder = 2
startSubtitle.ZIndex = 32
startSubtitle.Parent = startCard
local startBtn = addButton(startCard, "Jouer", 3)

-- Game over screen
local gameOverScreen, gameOverCard = createOverlay(0.15)
gameOverScreen.Visible = false
addTitle(gameOverCard, "Perdu !", 1)
local scoreRow = Instance.new("Frame")
scoreRow.BackgroundTransparency = 1
scoreRow.Size = UDim2.new(1, -20, 0, 50)
scoreRow.LayoutOrder = 2
scoreRow.ZIndex = 32
scoreRow.Parent = gameOverCard
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 30)
rowLayout.Parent = scoreRow

local function scoreStat(caption)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0, 90, 1, 0)
	holder.ZIndex = 32
	holder.Parent = scoreRow
	local capLabel = Instance.new("TextLabel")
	capLabel.BackgroundTransparency = 1
	capLabel.Size = UDim2.new(1, 0, 0, 16)
	capLabel.Font = Enum.Font.Gotham
	capLabel.TextSize = 12
	capLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	capLabel.Text = caption
	capLabel.ZIndex = 32
	capLabel.Parent = holder
	local valLabel = Instance.new("TextLabel")
	valLabel.BackgroundTransparency = 1
	valLabel.Position = UDim2.new(0, 0, 0, 16)
	valLabel.Size = UDim2.new(1, 0, 0, 30)
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 24
	valLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	valLabel.Text = "0"
	valLabel.ZIndex = 32
	valLabel.Parent = holder
	return valLabel
end

local finalScoreLabel = scoreStat("Score")
local bestScoreLabel = scoreStat("Meilleur")
local restartBtn = addButton(gameOverCard, "Rejouer", 3)

-- Pause screen
local pauseScreen, pauseCard = createOverlay(0.35)
pauseScreen.Visible = false
addTitle(pauseCard, "Pause", 1)
local resumeBtn = addButton(pauseCard, "Reprendre", 2)

--============ Logique du jeu ============--

local GRAVITY = 900
local FLAP_IMPULSE = -300
local PIPE_WIDTH = 60
local PIPE_GAP = 160
local PIPE_SPEED = 140
local PIPE_SPACING = 220

local gameState = "start" -- start | playing | paused | gameover
local birdY, birdVel = PLAYABLE_HEIGHT / 2, 0
local score, bestScore = 0, 0
local pipes = {}
local idleTween

local function clearPipes()
	for _, p in ipairs(pipes) do
		p.top:Destroy()
		p.bottom:Destroy()
	end
	pipes = {}
end

local function configurePipe(p, x)
	local gapCenter = math.random(120, PLAYABLE_HEIGHT - 120)
	local topHeight = gapCenter - PIPE_GAP / 2
	local bottomY = gapCenter + PIPE_GAP / 2
	local bottomHeight = PLAYABLE_HEIGHT - bottomY

	p.x = x
	p.topHeight = topHeight
	p.bottomY = bottomY
	p.passed = false

	p.top.Size = UDim2.new(0, PIPE_WIDTH, 0, topHeight)
	p.top.Position = UDim2.new(0, x, 0, 0)
	p.bottom.Size = UDim2.new(0, PIPE_WIDTH, 0, bottomHeight)
	p.bottom.Position = UDim2.new(0, x, 0, bottomY)
end

local function createPipeFrames()
	local top = Instance.new("Frame")
	top.BackgroundColor3 = Color3.fromRGB(94, 201, 98)
	top.BorderSizePixel = 0
	top.ZIndex = 4
	top.Parent = gameArea
	local topCap = Instance.new("Frame")
	topCap.AnchorPoint = Vector2.new(0.5, 0)
	topCap.Position = UDim2.new(0.5, 0, 1, 0)
	topCap.Size = UDim2.new(1, 10, 0, 20)
	topCap.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	topCap.BorderSizePixel = 0
	topCap.ZIndex = 5
	topCap.Parent = top
	corner(topCap, UDim.new(0, 4))

	local bottom = Instance.new("Frame")
	bottom.BackgroundColor3 = Color3.fromRGB(94, 201, 98)
	bottom.BorderSizePixel = 0
	bottom.ZIndex = 4
	bottom.Parent = gameArea
	local bottomCap = Instance.new("Frame")
	bottomCap.AnchorPoint = Vector2.new(0.5, 1)
	bottomCap.Position = UDim2.new(0.5, 0, 0, 0)
	bottomCap.Size = UDim2.new(1, 10, 0, 20)
	bottomCap.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	bottomCap.BorderSizePixel = 0
	bottomCap.ZIndex = 5
	bottomCap.Parent = bottom
	corner(bottomCap, UDim.new(0, 4))

	return top, bottom
end

local function spawnInitialPipes()
	for i = 1, 3 do
		local top, bottom = createPipeFrames()
		local p = { top = top, bottom = bottom }
		configurePipe(p, WINDOW_WIDTH + 100 + (i - 1) * PIPE_SPACING)
		table.insert(pipes, p)
	end
end

local function updateBestBadge()
	bestBadge.Text = "Meilleur : " .. tostring(bestScore)
end

local function resetGame()
	clearPipes()
	birdY = PLAYABLE_HEIGHT / 2
	birdVel = 0
	score = 0
	scoreLabel.Text = "0"
	bird.Position = UDim2.new(0, BIRD_X, 0, birdY)
	bird.Rotation = 0
	spawnInitialPipes()
end

local function startGame()
	if idleTween then idleTween:Cancel() end
	startScreen.Visible = false
	gameOverScreen.Visible = false
	pauseScreen.Visible = false
	resetGame()
	gameState = "playing"
end

local function endGame()
	if gameState ~= "playing" then return end
	gameState = "gameover"
	if score > bestScore then
		bestScore = score
		updateBestBadge()
	end
	finalScoreLabel.Text = tostring(score)
	bestScoreLabel.Text = tostring(bestScore)
	gameOverScreen.Visible = true
end

local function togglePause()
	if gameState == "playing" then
		gameState = "paused"
		pauseScreen.Visible = true
	elseif gameState == "paused" then
		gameState = "playing"
		pauseScreen.Visible = false
	end
end

local function flap()
	if gameState == "playing" then
		birdVel = FLAP_IMPULSE
	end
end

-- Bobbing de l'oiseau sur l'écran de démarrage
bird.Position = UDim2.new(0, BIRD_X, 0, birdY)
idleTween = TweenService:Create(bird, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, BIRD_X, 0, birdY - 20) })
idleTween:Play()

startBtn.MouseButton1Click:Connect(startGame)
restartBtn.MouseButton1Click:Connect(startGame)
pauseBtn.MouseButton1Click:Connect(togglePause)
resumeBtn.MouseButton1Click:Connect(togglePause)
trophyBtn.MouseButton1Click:Connect(function()
	bestBadge.Visible = not bestBadge.Visible
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space then
		flap()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, cloud in ipairs(clouds) do
		cloud.x -= cloud.speed * dt
		if cloud.x < -120 then
			cloud.x = WINDOW_WIDTH + math.random(0, 100)
		end
		cloud.frame.Position = UDim2.new(0, cloud.x, 0, cloud.y)
	end

	if gameState ~= "playing" then return end

	birdVel += GRAVITY * dt
	birdY += birdVel * dt
	if birdY - BIRD_RADIUS < 0 then
		birdY = BIRD_RADIUS
		birdVel = 0
	end
	bird.Position = UDim2.new(0, BIRD_X, 0, birdY)
	bird.Rotation = math.clamp(birdVel / 12, -25, 70)

	local rightmostX = 0
	for _, p in ipairs(pipes) do
		p.x -= PIPE_SPEED * dt
		p.top.Position = UDim2.new(0, p.x, 0, 0)
		p.bottom.Position = UDim2.new(0, p.x, 0, p.bottomY)
		rightmostX = math.max(rightmostX, p.x)

		if not p.passed and p.x + PIPE_WIDTH < BIRD_X then
			p.passed = true
			score += 1
			scoreLabel.Text = tostring(score)
		end

		if BIRD_X + BIRD_RADIUS > p.x and BIRD_X - BIRD_RADIUS < p.x + PIPE_WIDTH then
			if birdY - BIRD_RADIUS < p.topHeight or birdY + BIRD_RADIUS > p.bottomY then
				endGame()
				return
			end
		end
	end

	for _, p in ipairs(pipes) do
		if p.x + PIPE_WIDTH < -20 then
			configurePipe(p, rightmostX + PIPE_SPACING)
		end
	end

	if birdY + BIRD_RADIUS >= PLAYABLE_HEIGHT then
		endGame()
	end
end)
