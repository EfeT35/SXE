-- LocalScript à placer dans StarterPlayer > StarterPlayerScripts
-- Construit un "téléphone" avec un écran d'accueil (icônes d'applis).
-- Chaque appli ouvre une fenêtre déplaçable contenant un mini-jeu.
-- Tout est généré au runtime avec des Frames (aucun asset externe).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, name in ipairs({ "FlappyBirdGui", "PhoneArcadeGui" }) do
	local existing = playerGui:FindFirstChild(name)
	if existing then existing:Destroy() end
end

--============ Helpers ============--

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
	return c
end

local function frame(parent, size, pos, color, zindex)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos or UDim2.new(0, 0, 0, 0)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zindex or 1
	f.Parent = parent
	return f
end

local function label(parent, size, pos, text, textSize, color, bold, zindex)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new(0, 0, 0, 0)
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.ZIndex = zindex or 1
	l.Parent = parent
	return l
end

local function button(parent, size, pos, text, bgColor, textColor, textSize, zindex)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = bgColor
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = textSize or 16
	b.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.ZIndex = zindex or 1
	b.Parent = parent
	corner(b, UDim.new(0, 10))
	return b
end

-- Overlay générique (écran de démarrage / game over) réutilisé par tous les jeux
local function messageOverlay(content, zBase)
	zBase = zBase or 90
	local overlay = frame(content, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), zBase)
	overlay.BackgroundTransparency = 0.35

	local card = frame(overlay, UDim2.new(0, 220, 0, 170), UDim2.new(0.5, -110, 0.5, -85), Color3.fromRGB(255, 255, 255), zBase + 1)
	corner(card, UDim.new(0, 14))

	local title = label(card, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 14), "", 20, Color3.fromRGB(30, 30, 30), true, zBase + 2)
	local subtitle = label(card, UDim2.new(1, -20, 0, 46), UDim2.new(0, 10, 0, 48), "", 13, Color3.fromRGB(90, 90, 90), false, zBase + 2)
	subtitle.TextWrapped = true
	local btn = button(card, UDim2.new(0, 140, 0, 40), UDim2.new(0.5, -70, 1, -54), "Jouer", Color3.fromRGB(94, 201, 98), Color3.fromRGB(255, 255, 255), 16, zBase + 2)

	return overlay, title, subtitle, btn
end

--============ Téléphone ============--

local PHONE_W, PHONE_H = 400, 800
local BEZEL = 12
local STATUSBAR_H = 26

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhoneArcadeGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local phoneOuter = frame(screenGui, UDim2.new(0, PHONE_W, 0, PHONE_H), UDim2.new(0.5, 0, 0.5, 0), Color3.fromRGB(15, 15, 18), 1)
phoneOuter.AnchorPoint = Vector2.new(0.5, 0.5)
corner(phoneOuter, UDim.new(0, 42))

local uiScale = Instance.new("UIScale")
uiScale.Parent = phoneOuter

local camera = workspace.CurrentCamera
local function updateScale()
	if not camera then return end
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min((vp.Y * 0.94) / PHONE_H, (vp.X * 0.94) / PHONE_W), 0.5, 1.6)
end
if camera then
	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
	updateScale()
end)

local speaker = frame(phoneOuter, UDim2.new(0, 60, 0, 5), UDim2.new(0.5, -30, 0, 8), Color3.fromRGB(40, 40, 46), 2)
corner(speaker, UDim.new(1, 0))

local screenArea = frame(phoneOuter, UDim2.new(0, PHONE_W - 2 * BEZEL, 0, PHONE_H - 2 * BEZEL), UDim2.new(0, BEZEL, 0, BEZEL), Color3.fromRGB(24, 26, 38), 1)
screenArea.ClipsDescendants = true
corner(screenArea, UDim.new(0, 30))

local wallGradient = Instance.new("UIGradient")
wallGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 60, 150)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 32, 60)),
})
wallGradient.Rotation = 90
wallGradient.Parent = screenArea

local statusBar = frame(screenArea, UDim2.new(1, 0, 0, STATUSBAR_H), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 2)
statusBar.BackgroundTransparency = 1
local clockLabel = label(statusBar, UDim2.new(0, 60, 1, 0), UDim2.new(0, 14, 0, 0), "9:41", 13, Color3.fromRGB(255, 255, 255), true, 3)
clockLabel.TextXAlignment = Enum.TextXAlignment.Left
local battLabel = label(statusBar, UDim2.new(0, 60, 1, 0), UDim2.new(1, -60, 0, 0), "100%", 13, Color3.fromRGB(255, 255, 255), true, 3)
battLabel.TextXAlignment = Enum.TextXAlignment.Right

local homeLabel = label(screenArea, UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, STATUSBAR_H + 4), "Mes Jeux", 16, Color3.fromRGB(255, 255, 255), true, 3)

local gridArea = frame(screenArea, UDim2.new(1, -20, 1, -STATUSBAR_H - 34), UDim2.new(0, 10, 0, STATUSBAR_H + 30), Color3.fromRGB(0, 0, 0), 2)
gridArea.BackgroundTransparency = 1

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 80, 0, 90)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 14)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridArea

--============ Gestionnaire de fenêtres (draggable) ============--

local GAME_W, GAME_H = 280, 380
local TITLEBAR_H = 30

local openWindows = {}
local topZ = 100

local function makeDraggable(handle, win)
	local dragging, dragStart, startPos = false, nil, nil
	local conns = {}

	table.insert(conns, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = win.Position
			topZ += 1
			win.ZIndex = topZ
		end
	end))

	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))

	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	return conns
end

local function openApp(app)
	if openWindows[app.name] then
		topZ += 1
		openWindows[app.name].ZIndex = topZ
		return
	end

	local winH = TITLEBAR_H + GAME_H
	local cascade = 0
	for _ in pairs(openWindows) do cascade += 18 end

	local win = frame(screenArea, UDim2.new(0, GAME_W, 0, winH), UDim2.new(0.5, -GAME_W / 2 + cascade, 0.5, -winH / 2 + cascade), Color3.fromRGB(28, 28, 34), 40)
	win.ClipsDescendants = true
	corner(win, UDim.new(0, 16))
	topZ += 1
	win.ZIndex = topZ

	local winStroke = Instance.new("UIStroke")
	winStroke.Color = Color3.fromRGB(255, 255, 255)
	winStroke.Transparency = 0.7
	winStroke.Thickness = 1.5
	winStroke.Parent = win

	local titlebar = frame(win, UDim2.new(1, 0, 0, TITLEBAR_H), UDim2.new(0, 0, 0, 0), Color3.fromRGB(45, 45, 55), 41)
	titlebar.Active = true

	local dot = frame(titlebar, UDim2.new(0, 8, 0, 8), UDim2.new(0, 10, 0.5, -4), app.color, 42)
	corner(dot, UDim.new(1, 0))

	local nameLabel = label(titlebar, UDim2.new(0, 170, 1, 0), UDim2.new(0, 24, 0, 0), string.upper(app.name), 12, Color3.fromRGB(230, 230, 230), true, 42)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local closeBtn = button(titlebar, UDim2.new(0, 24, 0, 24), UDim2.new(1, -30, 0.5, -12), "x", Color3.fromRGB(200, 60, 60), Color3.fromRGB(255, 255, 255), 16, 42)

	local content = frame(win, UDim2.new(0, GAME_W, 0, GAME_H), UDim2.new(0, 0, 0, TITLEBAR_H), Color3.fromRGB(255, 255, 255), 41)
	content.ClipsDescendants = true

	local dragConns = makeDraggable(titlebar, win)

	local gameConns
	local ok, result = pcall(app.build, content)
	if ok then
		gameConns = result or {}
	else
		warn("[PhoneArcade] " .. app.name .. " a planté : " .. tostring(result))
		content.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		local errLabel = label(content, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), "Erreur dans " .. app.name .. " :\n" .. tostring(result), 13, Color3.fromRGB(255, 140, 140), true, 50)
		errLabel.TextWrapped = true
		gameConns = {}
	end

	local allConns = {}
	for _, c in ipairs(dragConns) do table.insert(allConns, c) end
	for _, c in ipairs(gameConns) do table.insert(allConns, c) end

	closeBtn.MouseButton1Click:Connect(function()
		for _, c in ipairs(allConns) do c:Disconnect() end
		win:Destroy()
		openWindows[app.name] = nil
	end)

	openWindows[app.name] = win
end

--============ Jeu 1 : Flappy Bird ============--

local function buildFlappyBird(content)
	content.BackgroundColor3 = Color3.fromRGB(78, 192, 220)
	content.Active = true
	local conns = {}

	local GROUND_H = 60
	local PLAYABLE_H = GAME_H - GROUND_H
	local GRAVITY, FLAP = 900, -280
	local PW, PGAP, PSPEED, PSPACE = 46, 120, 110, 160
	local BX, BR = 60, 13

	local function makeCloud(x, y, scale)
		local c = frame(content, UDim2.new(0, 70 * scale, 0, 30 * scale), UDim2.new(0, x, 0, y), Color3.fromRGB(255, 255, 255), 1)
		c.BackgroundTransparency = 0.2
		corner(c, UDim.new(1, 0))
		return c
	end
	local clouds = {
		{ f = makeCloud(20, 40, 1), x = 20, y = 40, speed = 8 },
		{ f = makeCloud(160, 70, 0.7), x = 160, y = 70, speed = 6 },
	}

	local ground = frame(content, UDim2.new(1, 0, 0, GROUND_H), UDim2.new(0, 0, 1, -GROUND_H), Color3.fromRGB(222, 184, 111), 5)
	frame(ground, UDim2.new(1, 0, 0, 8), UDim2.new(0, 0, 0, 0), Color3.fromRGB(94, 201, 98), 5)

	local bird = frame(content, UDim2.new(0, BR * 2, 0, BR * 2), UDim2.new(0, BX, 0, PLAYABLE_H / 2), Color3.fromRGB(247, 202, 24), 10)
	bird.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(bird, UDim.new(1, 0))
	frame(bird, UDim2.new(0, 10, 0, 6), UDim2.new(1, -4, 0.5, -3), Color3.fromRGB(235, 140, 52), 11)

	local scoreLabel = label(content, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 10), "0", 30, Color3.fromRGB(255, 255, 255), true, 20)
	scoreLabel.TextStrokeTransparency = 0

	local overlay, ovTitle, ovSubtitle, ovBtn = messageOverlay(content)
	ovTitle.Text = "Flappy Bird"
	ovSubtitle.Text = "Touche l'écran pour voler"

	local state = "start"
	local birdY, birdVel, score = PLAYABLE_H / 2, 0, 0
	local pipes = {}

	local function clearPipes()
		for _, p in ipairs(pipes) do
			p.top:Destroy()
			p.bottom:Destroy()
		end
		pipes = {}
	end

	local function makePipePair()
		local top = frame(content, UDim2.new(0, PW, 0, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(94, 201, 98), 4)
		local bottom = frame(content, UDim2.new(0, PW, 0, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(94, 201, 98), 4)
		return { top = top, bottom = bottom }
	end

	local function configurePipe(p, x)
		local gapCenter = math.random(90, PLAYABLE_H - 90)
		local topH = gapCenter - PGAP / 2
		local bottomY = gapCenter + PGAP / 2
		p.x, p.topH, p.bottomY, p.passed = x, topH, bottomY, false
		p.top.Size = UDim2.new(0, PW, 0, topH)
		p.top.Position = UDim2.new(0, x, 0, 0)
		p.bottom.Size = UDim2.new(0, PW, 0, PLAYABLE_H - bottomY)
		p.bottom.Position = UDim2.new(0, x, 0, bottomY)
	end

	local function spawnPipes()
		for i = 1, 3 do
			local p = makePipePair()
			configurePipe(p, GAME_W + 80 + (i - 1) * PSPACE)
			table.insert(pipes, p)
		end
	end

	local function resetGame()
		clearPipes()
		birdY, birdVel, score = PLAYABLE_H / 2, 0, 0
		scoreLabel.Text = "0"
		bird.Position = UDim2.new(0, BX, 0, birdY)
		bird.Rotation = 0
		spawnPipes()
	end

	local function startGame()
		overlay.Visible = false
		resetGame()
		state = "playing"
	end

	local function endGame()
		if state ~= "playing" then return end
		state = "gameover"
		ovTitle.Text = "Perdu !"
		ovSubtitle.Text = "Score : " .. score
		ovBtn.Text = "Rejouer"
		overlay.Visible = true
	end

	table.insert(conns, ovBtn.MouseButton1Click:Connect(startGame))

	table.insert(conns, content.InputBegan:Connect(function(input, processed)
		if processed then return end
		if state == "playing" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			birdVel = FLAP
		end
	end))

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if state == "playing" and input.KeyCode == Enum.KeyCode.Space then
			birdVel = FLAP
		end
	end))

	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		for _, cl in ipairs(clouds) do
			cl.x -= cl.speed * dt
			if cl.x < -100 then cl.x = GAME_W + math.random(0, 60) end
			cl.f.Position = UDim2.new(0, cl.x, 0, cl.y)
		end

		if state ~= "playing" then return end

		birdVel += GRAVITY * dt
		birdY += birdVel * dt
		if birdY - BR < 0 then
			birdY = BR
			birdVel = 0
		end
		bird.Position = UDim2.new(0, BX, 0, birdY)
		bird.Rotation = math.clamp(birdVel / 12, -25, 70)

		local rightmost = 0
		for _, p in ipairs(pipes) do
			p.x -= PSPEED * dt
			p.top.Position = UDim2.new(0, p.x, 0, 0)
			p.bottom.Position = UDim2.new(0, p.x, 0, p.bottomY)
			rightmost = math.max(rightmost, p.x)

			if not p.passed and p.x + PW < BX then
				p.passed = true
				score += 1
				scoreLabel.Text = tostring(score)
			end

			if BX + BR > p.x and BX - BR < p.x + PW then
				if birdY - BR < p.topH or birdY + BR > p.bottomY then
					endGame()
					return
				end
			end
		end

		for _, p in ipairs(pipes) do
			if p.x + PW < -20 then
				configurePipe(p, rightmost + PSPACE)
			end
		end

		if birdY + BR >= PLAYABLE_H then
			endGame()
		end
	end))

	return conns
end

--============ Jeu 2 : Snake ============--

local function buildSnake(content)
	content.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	content.Active = true
	local conns = {}

	local TOP_H, CELL = 36, 20
	local COLS = math.floor(GAME_W / CELL)
	local ROWS = math.floor((GAME_H - TOP_H) / CELL)
	local boardW, boardH = COLS * CELL, ROWS * CELL

	local scoreLabel = label(content, UDim2.new(1, 0, 0, TOP_H), UDim2.new(0, 0, 0, 0), "Score: 0", 16, Color3.fromRGB(255, 255, 255), true, 20)

	local playArea = frame(content, UDim2.new(0, boardW, 0, boardH), UDim2.new(0.5, -boardW / 2, 0, TOP_H), Color3.fromRGB(30, 34, 30), 2)

	local overlay, ovTitle, ovSubtitle, ovBtn = messageOverlay(content)
	ovTitle.Text = "Snake"
	ovSubtitle.Text = "Flèches ou pavé tactile pour bouger"

	local function dpadBtn(text, pos)
		local b = button(content, UDim2.new(0, 34, 0, 34), pos, text, Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 30, 30), 14, 25)
		b.BackgroundTransparency = 0.35
		return b
	end
	local dpadUp = dpadBtn("^", UDim2.new(1, -80, 1, -122))
	local dpadDown = dpadBtn("v", UDim2.new(1, -80, 1, -50))
	local dpadLeft = dpadBtn("<", UDim2.new(1, -116, 1, -86))
	local dpadRight = dpadBtn(">", UDim2.new(1, -44, 1, -86))

	local foodFrame = frame(playArea, UDim2.new(0, CELL - 2, 0, CELL - 2), UDim2.new(0, 0, 0, 0), Color3.fromRGB(220, 60, 60), 4)
	corner(foodFrame, UDim.new(1, 0))
	foodFrame.Visible = false

	local dx, dy, pendingDx, pendingDy = 1, 0, 1, 0
	local body, segFrames = {}, {}
	local food = { x = 0, y = 0 }
	local state, score, moveTimer = "start", 0, 0
	local moveInterval = 0.15

	local function cellPos(cx, cy)
		return UDim2.new(0, (cx - 1) * CELL + 1, 0, (cy - 1) * CELL + 1)
	end

	local function placeFood()
		local free = {}
		for cx = 1, COLS do
			for cy = 1, ROWS do
				local occupied = false
				for _, seg in ipairs(body) do
					if seg.x == cx and seg.y == cy then occupied = true break end
				end
				if not occupied then table.insert(free, { x = cx, y = cy }) end
			end
		end
		if #free == 0 then return end
		local pick = free[math.random(1, #free)]
		food.x, food.y = pick.x, pick.y
		foodFrame.Position = cellPos(food.x, food.y)
		foodFrame.Visible = true
	end

	local function renderSnake()
		for _, f in ipairs(segFrames) do f:Destroy() end
		segFrames = {}
		for i, seg in ipairs(body) do
			local segF = frame(playArea, UDim2.new(0, CELL - 2, 0, CELL - 2), cellPos(seg.x, seg.y), i == 1 and Color3.fromRGB(94, 201, 98) or Color3.fromRGB(60, 150, 70), 3)
			corner(segF, UDim.new(0, 4))
			table.insert(segFrames, segF)
		end
	end

	local function resetGame()
		body = { { x = 5, y = 9 }, { x = 4, y = 9 }, { x = 3, y = 9 } }
		dx, dy, pendingDx, pendingDy = 1, 0, 1, 0
		score, moveTimer = 0, 0
		scoreLabel.Text = "Score: 0"
		renderSnake()
		placeFood()
	end

	local function startGame()
		overlay.Visible = false
		resetGame()
		state = "playing"
	end

	local function endGame()
		if state ~= "playing" then return end
		state = "gameover"
		ovTitle.Text = "Perdu !"
		ovSubtitle.Text = "Score : " .. score
		ovBtn.Text = "Rejouer"
		overlay.Visible = true
	end

	table.insert(conns, ovBtn.MouseButton1Click:Connect(startGame))

	local function setDir(nx, ny)
		if state ~= "playing" then return end
		if nx == -dx and ny == -dy then return end
		pendingDx, pendingDy = nx, ny
	end

	table.insert(conns, dpadUp.MouseButton1Click:Connect(function() setDir(0, -1) end))
	table.insert(conns, dpadDown.MouseButton1Click:Connect(function() setDir(0, 1) end))
	table.insert(conns, dpadLeft.MouseButton1Click:Connect(function() setDir(-1, 0) end))
	table.insert(conns, dpadRight.MouseButton1Click:Connect(function() setDir(1, 0) end))

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local key = input.KeyCode
		if key == Enum.KeyCode.Up or key == Enum.KeyCode.W then setDir(0, -1)
		elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.S then setDir(0, 1)
		elseif key == Enum.KeyCode.Left or key == Enum.KeyCode.A then setDir(-1, 0)
		elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.D then setDir(1, 0)
		end
	end))

	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if state ~= "playing" then return end
		moveTimer += dt
		if moveTimer < moveInterval then return end
		moveTimer = 0
		dx, dy = pendingDx, pendingDy

		local head = body[1]
		local newHead = { x = head.x + dx, y = head.y + dy }
		if newHead.x < 1 or newHead.x > COLS or newHead.y < 1 or newHead.y > ROWS then
			endGame()
			return
		end
		for i = 1, #body do
			if body[i].x == newHead.x and body[i].y == newHead.y then
				endGame()
				return
			end
		end

		table.insert(body, 1, newHead)
		if newHead.x == food.x and newHead.y == food.y then
			score += 1
			scoreLabel.Text = "Score: " .. score
			placeFood()
		else
			table.remove(body)
		end
		renderSnake()
	end))

	return conns
end

--============ Jeu 3 : Pong ============--

local function buildPong(content)
	content.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	content.Active = true
	local conns = {}

	local midLine = frame(content, UDim2.new(1, -20, 0, 2), UDim2.new(0, 10, 0.5, -1), Color3.fromRGB(255, 255, 255), 1)
	midLine.BackgroundTransparency = 0.7

	local scoreLabel = label(content, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 6), "0 - 0", 20, Color3.fromRGB(255, 255, 255), true, 20)

	local PW_, PH_ = 60, 10
	local aiPaddle = frame(content, UDim2.new(0, PW_, 0, PH_), UDim2.new(0, (GAME_W - PW_) / 2, 0, 20), Color3.fromRGB(230, 80, 80), 5)
	corner(aiPaddle, UDim.new(0, 4))
	local plPaddle = frame(content, UDim2.new(0, PW_, 0, PH_), UDim2.new(0, (GAME_W - PW_) / 2, 0, GAME_H - 30), Color3.fromRGB(80, 160, 230), 5)
	corner(plPaddle, UDim.new(0, 4))

	local BR_ = 6
	local ball = frame(content, UDim2.new(0, BR_ * 2, 0, BR_ * 2), UDim2.new(0, GAME_W / 2 - BR_, 0, GAME_H / 2 - BR_), Color3.fromRGB(255, 255, 255), 6)
	corner(ball, UDim.new(1, 0))

	local overlay, ovTitle, ovSubtitle, ovBtn = messageOverlay(content)
	ovTitle.Text = "Pong"
	ovSubtitle.Text = "Glisse le doigt pour bouger la raquette"

	local MAX_SPEED = 420
	local state = "start"
	local px, aix = (GAME_W - PW_) / 2, (GAME_W - PW_) / 2
	local bx, by, bvx, bvy = GAME_W / 2, GAME_H / 2, 0, 0
	local scoreP, scoreA = 0, 0
	local dragging = false

	local function resetBall(serveToPlayer)
		bx, by = GAME_W / 2, GAME_H / 2
		local speed = 140
		bvx = (math.random(0, 1) == 0 and -1 or 1) * speed * 0.6
		bvy = (serveToPlayer and 1 or -1) * speed
	end

	local function resetGame()
		px, aix = (GAME_W - PW_) / 2, (GAME_W - PW_) / 2
		scoreP, scoreA = 0, 0
		scoreLabel.Text = "0 - 0"
		resetBall(true)
	end

	local function startGame()
		overlay.Visible = false
		resetGame()
		state = "playing"
	end
	table.insert(conns, ovBtn.MouseButton1Click:Connect(startGame))

	local function endRound(playerScored)
		if playerScored then scoreP += 1 else scoreA += 1 end
		scoreLabel.Text = scoreP .. " - " .. scoreA
		if scoreP >= 7 or scoreA >= 7 then
			state = "gameover"
			ovTitle.Text = scoreP >= 7 and "Gagné !" or "Perdu !"
			ovSubtitle.Text = "Score final : " .. scoreP .. " - " .. scoreA
			ovBtn.Text = "Rejouer"
			overlay.Visible = true
		else
			resetBall(not playerScored)
		end
	end

	local function toLocalX(input)
		local abs = content.AbsolutePosition
		local size = content.AbsoluteSize
		return (input.Position.X - abs.X) / size.X * GAME_W
	end

	table.insert(conns, content.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local lx = toLocalX(input)
			px = math.clamp(lx - PW_ / 2, 0, GAME_W - PW_)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if state ~= "playing" then return end
		plPaddle.Position = UDim2.new(0, px, 0, GAME_H - 30)

		local target = bx - PW_ / 2
		local aiSpeed = 130
		if aix < target then aix = math.min(aix + aiSpeed * dt, target) else aix = math.max(aix - aiSpeed * dt, target) end
		aix = math.clamp(aix, 0, GAME_W - PW_)
		aiPaddle.Position = UDim2.new(0, aix, 0, 20)

		bx += bvx * dt
		by += bvy * dt
		if bx - BR_ < 0 then bx = BR_; bvx = -bvx end
		if bx + BR_ > GAME_W then bx = GAME_W - BR_; bvx = -bvx end

		if bvy > 0 and by + BR_ >= GAME_H - 30 then
			if bx >= px - BR_ and bx <= px + PW_ + BR_ then
				by = GAME_H - 30 - BR_
				local hitOffset = math.clamp((bx - (px + PW_ / 2)) / (PW_ / 2), -1, 1)
				bvy = math.clamp(-math.abs(bvy) * 1.03, -MAX_SPEED, -1)
				bvx = hitOffset * 160
			elseif by - BR_ > GAME_H then
				endRound(false)
			end
		elseif bvy < 0 and by - BR_ <= 20 + PH_ then
			if bx >= aix - BR_ and bx <= aix + PW_ + BR_ then
				by = 20 + PH_ + BR_
				bvy = math.clamp(math.abs(bvy) * 1.03, 1, MAX_SPEED)
			elseif by + BR_ < 0 then
				endRound(true)
			end
		end

		ball.Position = UDim2.new(0, bx - BR_, 0, by - BR_)
	end))

	return conns
end

--============ Jeu 4 : Casse-briques ============--

local function buildBreakout(content)
	content.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	content.Active = true
	local conns = {}

	local scoreLabel = label(content, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 4), "Score: 0", 16, Color3.fromRGB(255, 255, 255), true, 20)

	local rowColors = {
		Color3.fromRGB(230, 80, 80), Color3.fromRGB(240, 150, 60), Color3.fromRGB(240, 220, 60),
		Color3.fromRGB(120, 200, 90), Color3.fromRGB(90, 160, 230),
	}
	local margin, gap, cols, rows = 5, 3, 7, 5
	local brickW = (GAME_W - 2 * margin - (cols - 1) * gap) / cols
	local brickH = 14
	local startY = 38

	local bricks = {}
	local function buildBricks()
		for _, b in ipairs(bricks) do b.f:Destroy() end
		bricks = {}
		for r = 1, rows do
			for c = 1, cols do
				local bx0 = margin + (c - 1) * (brickW + gap)
				local by0 = startY + (r - 1) * (brickH + gap)
				local f = frame(content, UDim2.new(0, brickW, 0, brickH), UDim2.new(0, bx0, 0, by0), rowColors[r], 4)
				corner(f, UDim.new(0, 3))
				table.insert(bricks, { f = f, x = bx0, y = by0, w = brickW, h = brickH, alive = true })
			end
		end
	end

	local PW_, PH_ = 56, 10
	local paddle = frame(content, UDim2.new(0, PW_, 0, PH_), UDim2.new(0, (GAME_W - PW_) / 2, 0, GAME_H - 24), Color3.fromRGB(80, 160, 230), 5)
	corner(paddle, UDim.new(0, 4))

	local BR_ = 6
	local ball = frame(content, UDim2.new(0, BR_ * 2, 0, BR_ * 2), UDim2.new(0, GAME_W / 2 - BR_, 0, GAME_H - 40), Color3.fromRGB(255, 255, 255), 6)
	corner(ball, UDim.new(1, 0))

	local overlay, ovTitle, ovSubtitle, ovBtn = messageOverlay(content)
	ovTitle.Text = "Casse-briques"
	ovSubtitle.Text = "Glisse le doigt pour bouger la raquette"

	local state = "start"
	local px = (GAME_W - PW_) / 2
	local bx, by, bvx, bvy = GAME_W / 2, GAME_H - 40, 0, 0
	local score, aliveCount = 0, 0
	local dragging = false

	local function resetBall()
		bx, by = GAME_W / 2, GAME_H - 50
		bvx = (math.random(0, 1) == 0 and -1 or 1) * 110
		bvy = -150
	end

	local function resetGame()
		buildBricks()
		aliveCount = #bricks
		px = (GAME_W - PW_) / 2
		score = 0
		scoreLabel.Text = "Score: 0"
		resetBall()
	end

	local function startGame()
		overlay.Visible = false
		resetGame()
		state = "playing"
	end
	table.insert(conns, ovBtn.MouseButton1Click:Connect(startGame))

	local function endGame(won)
		state = "gameover"
		ovTitle.Text = won and "Gagné !" or "Perdu !"
		ovSubtitle.Text = "Score : " .. score
		ovBtn.Text = "Rejouer"
		overlay.Visible = true
	end

	local function toLocalX(input)
		local abs = content.AbsolutePosition
		local size = content.AbsoluteSize
		return (input.Position.X - abs.X) / size.X * GAME_W
	end

	table.insert(conns, content.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local lx = toLocalX(input)
			px = math.clamp(lx - PW_ / 2, 0, GAME_W - PW_)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if state ~= "playing" then return end
		paddle.Position = UDim2.new(0, px, 0, GAME_H - 24)

		bx += bvx * dt
		by += bvy * dt
		if bx - BR_ < 0 then bx = BR_; bvx = -bvx end
		if bx + BR_ > GAME_W then bx = GAME_W - BR_; bvx = -bvx end
		if by - BR_ < 0 then by = BR_; bvy = -bvy end

		if bvy > 0 and by + BR_ >= GAME_H - 24 and by + BR_ <= GAME_H - 24 + PH_ + 6 and bx >= px - BR_ and bx <= px + PW_ + BR_ then
			by = GAME_H - 24 - BR_
			local hitOffset = math.clamp((bx - (px + PW_ / 2)) / (PW_ / 2), -1, 1)
			bvy = -math.abs(bvy)
			bvx = hitOffset * 140
		end

		for _, brk in ipairs(bricks) do
			if brk.alive and bx + BR_ > brk.x and bx - BR_ < brk.x + brk.w and by + BR_ > brk.y and by - BR_ < brk.y + brk.h then
				brk.alive = false
				brk.f:Destroy()
				aliveCount -= 1
				score += 1
				scoreLabel.Text = "Score: " .. score
				bvy = -bvy
				break
			end
		end

		ball.Position = UDim2.new(0, bx - BR_, 0, by - BR_)

		if by - BR_ > GAME_H then
			endGame(false)
		elseif aliveCount <= 0 then
			endGame(true)
		end
	end))

	return conns
end

--============ Jeu 5 : 2048 ============--

local function build2048(content)
	content.BackgroundColor3 = Color3.fromRGB(250, 248, 239)
	content.Active = true
	local conns = {}

	local scoreLabel = label(content, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "Score: 0", 20, Color3.fromRGB(60, 50, 40), true, 20)

	local margin, gap, cell = 10, 8, 59
	local boardTop = 56
	local boardBg = frame(content, UDim2.new(0, GAME_W - 2 * margin, 0, GAME_W - 2 * margin), UDim2.new(0, margin, 0, boardTop), Color3.fromRGB(187, 173, 160), 2)
	corner(boardBg, UDim.new(0, 8))

	for r = 0, 3 do
		for c = 0, 3 do
			local cellBg = frame(boardBg, UDim2.new(0, cell, 0, cell), UDim2.new(0, gap + c * (cell + gap), 0, gap + r * (cell + gap)), Color3.fromRGB(205, 193, 180), 3)
			corner(cellBg, UDim.new(0, 6))
		end
	end

	local tileColors = {
		[2] = Color3.fromRGB(238, 228, 218), [4] = Color3.fromRGB(237, 224, 200),
		[8] = Color3.fromRGB(242, 177, 121), [16] = Color3.fromRGB(245, 149, 99),
		[32] = Color3.fromRGB(246, 124, 95), [64] = Color3.fromRGB(246, 94, 59),
		[128] = Color3.fromRGB(237, 207, 114), [256] = Color3.fromRGB(237, 204, 97),
		[512] = Color3.fromRGB(237, 200, 80), [1024] = Color3.fromRGB(237, 197, 63),
		[2048] = Color3.fromRGB(237, 194, 46),
	}
	local function tileColor(v) return tileColors[v] or Color3.fromRGB(60, 58, 50) end
	local function tileTextColor(v) return (v <= 4) and Color3.fromRGB(110, 100, 90) or Color3.fromRGB(255, 255, 255) end

	local overlay, ovTitle, ovSubtitle, ovBtn = messageOverlay(content)
	ovTitle.Text = "2048"
	ovSubtitle.Text = "Flèches ou glisser pour déplacer"

	local state = "start"
	local board, score, tileFrames = {}, 0, {}

	local function emptyBoard()
		board = {}
		for r = 1, 4 do
			board[r] = {}
			for c = 1, 4 do board[r][c] = 0 end
		end
	end

	local function renderBoard()
		for _, f in ipairs(tileFrames) do f:Destroy() end
		tileFrames = {}
		for r = 1, 4 do
			for c = 1, 4 do
				local v = board[r][c]
				if v ~= 0 then
					local f = frame(boardBg, UDim2.new(0, cell, 0, cell), UDim2.new(0, gap + (c - 1) * (cell + gap), 0, gap + (r - 1) * (cell + gap)), tileColor(v), 4)
					corner(f, UDim.new(0, 6))
					local txt = label(f, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), tostring(v), v >= 128 and 20 or 24, tileTextColor(v), true, 5)
					table.insert(tileFrames, f)
					table.insert(tileFrames, txt)
				end
			end
		end
	end

	local function emptyCells()
		local cells = {}
		for r = 1, 4 do
			for c = 1, 4 do
				if board[r][c] == 0 then table.insert(cells, { r = r, c = c }) end
			end
		end
		return cells
	end

	local function spawnTile()
		local cells = emptyCells()
		if #cells == 0 then return end
		local pick = cells[math.random(1, #cells)]
		board[pick.r][pick.c] = (math.random(1, 10) == 1) and 4 or 2
	end

	local function mergeLine(line)
		local vals = {}
		for _, v in ipairs(line) do
			if v ~= 0 then table.insert(vals, v) end
		end
		local merged = {}
		local i = 1
		while i <= #vals do
			if vals[i] == vals[i + 1] then
				local newVal = vals[i] * 2
				table.insert(merged, newVal)
				score += newVal
				i += 2
			else
				table.insert(merged, vals[i])
				i += 1
			end
		end
		while #merged < 4 do table.insert(merged, 0) end
		return merged
	end

	local function getRow(r) return { board[r][1], board[r][2], board[r][3], board[r][4] } end
	local function setRow(r, line) for c = 1, 4 do board[r][c] = line[c] end end
	local function getCol(c) return { board[1][c], board[2][c], board[3][c], board[4][c] } end
	local function setCol(c, line) for r = 1, 4 do board[r][c] = line[r] end end
	local function reverseLine(line) return { line[4], line[3], line[2], line[1] } end

	local function boardsEqual(a, b)
		for r = 1, 4 do
			for c = 1, 4 do
				if a[r][c] ~= b[r][c] then return false end
			end
		end
		return true
	end

	local function copyBoard()
		local cp = {}
		for r = 1, 4 do
			cp[r] = {}
			for c = 1, 4 do cp[r][c] = board[r][c] end
		end
		return cp
	end

	local function canMove()
		for r = 1, 4 do
			for c = 1, 4 do
				if board[r][c] == 0 then return true end
				if c < 4 and board[r][c] == board[r][c + 1] then return true end
				if r < 4 and board[r][c] == board[r + 1][c] then return true end
			end
		end
		return false
	end

	local function move(dir)
		if state ~= "playing" then return end
		local before = copyBoard()
		if dir == "left" then
			for r = 1, 4 do setRow(r, mergeLine(getRow(r))) end
		elseif dir == "right" then
			for r = 1, 4 do setRow(r, reverseLine(mergeLine(reverseLine(getRow(r))))) end
		elseif dir == "up" then
			for c = 1, 4 do setCol(c, mergeLine(getCol(c))) end
		elseif dir == "down" then
			for c = 1, 4 do setCol(c, reverseLine(mergeLine(reverseLine(getCol(c))))) end
		end
		if not boardsEqual(before, board) then
			spawnTile()
			renderBoard()
			scoreLabel.Text = "Score: " .. score
			if not canMove() then
				state = "gameover"
				ovTitle.Text = "Perdu !"
				ovSubtitle.Text = "Score : " .. score
				ovBtn.Text = "Rejouer"
				overlay.Visible = true
			end
		end
	end

	local function resetGame()
		emptyBoard()
		score = 0
		scoreLabel.Text = "Score: 0"
		spawnTile()
		spawnTile()
		renderBoard()
	end

	local function startGame()
		overlay.Visible = false
		resetGame()
		state = "playing"
	end
	table.insert(conns, ovBtn.MouseButton1Click:Connect(startGame))

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local key = input.KeyCode
		if key == Enum.KeyCode.Left then move("left")
		elseif key == Enum.KeyCode.Right then move("right")
		elseif key == Enum.KeyCode.Up then move("up")
		elseif key == Enum.KeyCode.Down then move("down")
		end
	end))

	local swipeStart = nil
	table.insert(conns, content.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			swipeStart = input.Position
		end
	end))
	table.insert(conns, content.InputEnded:Connect(function(input)
		if not swipeStart then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - swipeStart
			swipeStart = nil
			if delta.Magnitude < 20 then return end
			if math.abs(delta.X) > math.abs(delta.Y) then
				move(delta.X > 0 and "right" or "left")
			else
				move(delta.Y > 0 and "down" or "up")
			end
		end
	end))

	return conns
end

--============ Écran d'accueil ============--

local apps = {
	{ name = "Flappy Bird", badge = "FB", color = Color3.fromRGB(247, 202, 24), build = buildFlappyBird },
	{ name = "Snake", badge = "SN", color = Color3.fromRGB(46, 204, 113), build = buildSnake },
	{ name = "Pong", badge = "PG", color = Color3.fromRGB(52, 152, 219), build = buildPong },
	{ name = "Casse-briques", badge = "CB", color = Color3.fromRGB(230, 126, 34), build = buildBreakout },
	{ name = "2048", badge = "2048", color = Color3.fromRGB(155, 89, 182), build = build2048 },
}

for _, app in ipairs(apps) do
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Parent = gridArea

	local iconBtn = Instance.new("TextButton")
	iconBtn.Size = UDim2.new(0, 64, 0, 64)
	iconBtn.Position = UDim2.new(0.5, -32, 0, 0)
	iconBtn.BackgroundColor3 = app.color
	iconBtn.Text = app.badge
	iconBtn.TextSize = app.badge == "2048" and 18 or 22
	iconBtn.Font = Enum.Font.GothamBold
	iconBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
	iconBtn.Parent = icon
	corner(iconBtn, UDim.new(0, 16))

	local nameLabel = label(icon, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 68), app.name, 11, Color3.fromRGB(255, 255, 255), true, 1)
	nameLabel.TextWrapped = true

	iconBtn.MouseButton1Click:Connect(function()
		openApp(app)
	end)
end
