--[[
    Phone.lua

    LocalScript a placer dans StarterPlayerScripts (ou a executer via un
    executor). Cree un telephone a l'ecran avec plusieurs mini-jeux type
    "Flappy Bird" et "Snake" jouables depuis l'ecran d'accueil, comme les
    telephones qu'on trouve dans les jeux de vie (Brookhaven etc).

    Pour ajouter une appli : construire une table {Name, Icon, Init} ou
    Init(container) retourne une fonction cleanup(), puis l'ajouter avec
    table.insert(Apps, ...).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Certains executors n'exposent pas la librairie "task" -> on retombe sur
-- les globales historiques spawn/wait pour rester compatible partout.
local safeSpawn = (task and task.spawn) or spawn
local safeWait = (task and task.wait) or wait

local function create(className, props)
    local inst = Instance.new(className)
    for key, value in pairs(props) do
        if key ~= "Parent" then
            inst[key] = value
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

--------------------------------------------------------------------------
-- Chassis du telephone
--------------------------------------------------------------------------

local PHONE_W, PHONE_H = 320, 600
local BEZEL = 12
local TOPBAR_H = 34
local SCREEN_W, SCREEN_H = PHONE_W - BEZEL * 2, PHONE_H - BEZEL * 2
local CONTENT_W, CONTENT_H = SCREEN_W, SCREEN_H - TOPBAR_H

local screenGui = create("ScreenGui", {
    Name = "PhoneGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 50,
    Parent = PlayerGui,
})

local toggleButton = create("TextButton", {
    Name = "PhoneToggle",
    Size = UDim2.fromOffset(56, 56),
    Position = UDim2.new(1, -70, 1, -90),
    AnchorPoint = Vector2.new(0, 0),
    BackgroundColor3 = Color3.fromRGB(35, 35, 40),
    Text = "\240\159\147\177", -- emoji telephone
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    ZIndex = 10,
    Parent = screenGui,
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = toggleButton })

local phoneFrame = create("Frame", {
    Name = "PhoneFrame",
    Size = UDim2.fromOffset(PHONE_W, PHONE_H),
    Position = UDim2.new(1, -PHONE_W - 20, 0.5, -PHONE_H / 2),
    BackgroundColor3 = Color3.fromRGB(15, 15, 18),
    Visible = false,
    Active = true,
    ZIndex = 5,
    Parent = screenGui,
})
create("UICorner", { CornerRadius = UDim.new(0, 34), Parent = phoneFrame })
create("UIStroke", { Color = Color3.fromRGB(60, 60, 65), Thickness = 2, Parent = phoneFrame })

local phoneScale = create("UIScale", { Parent = phoneFrame })

local function updatePhoneScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local scale = math.min((viewport.Y * 0.92) / PHONE_H, (viewport.X * 0.92) / PHONE_W)
    phoneScale.Scale = math.clamp(scale, 0.5, 1.4)
end
updatePhoneScale()
do
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(updatePhoneScale)
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updatePhoneScale)
end

local dragHandle = create("Frame", {
    Name = "DragHandle",
    Size = UDim2.new(1, 0, 0, BEZEL + 10),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = phoneFrame,
})

-- Notch decoratif
local notch = create("Frame", {
    Size = UDim2.fromOffset(70, 6),
    Position = UDim2.new(0.5, -35, 0, 4),
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    ZIndex = 6,
    Parent = phoneFrame,
})
create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = notch })

local screenFrame = create("Frame", {
    Name = "Screen",
    Size = UDim2.fromOffset(SCREEN_W, SCREEN_H),
    Position = UDim2.fromOffset(BEZEL, BEZEL),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10),
    ClipsDescendants = true,
    ZIndex = 5,
    Parent = phoneFrame,
})
create("UICorner", { CornerRadius = UDim.new(0, 24), Parent = screenFrame })

--------------------------------------------------------------------------
-- Drag du telephone (via la barre du haut)
--------------------------------------------------------------------------

do
    local dragging = false
    local dragStart, startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = phoneFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            phoneFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

toggleButton.MouseButton1Click:Connect(function()
    phoneFrame.Visible = not phoneFrame.Visible
end)

local buildOk, buildErr = pcall(function()

--------------------------------------------------------------------------
-- Ecran d'accueil
--------------------------------------------------------------------------

local function safeClockText()
    local ok, result = pcall(function()
        return os.date("%H:%M")
    end)
    if ok then
        return result
    end
    return "--:--"
end

local homeScreen = create("Frame", {
    Name = "HomeScreen",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Parent = screenFrame,
})

local clockLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40),
    Position = UDim2.fromOffset(0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 26,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Text = safeClockText(),
    Parent = homeScreen,
})

safeSpawn(function()
    while screenGui.Parent do
        clockLabel.Text = safeClockText()
        safeWait(15)
    end
end)

local iconHolder = create("Frame", {
    Size = UDim2.new(1, -20, 1, -70),
    Position = UDim2.fromOffset(10, 60),
    BackgroundTransparency = 1,
    Parent = homeScreen,
})
create("UIGridLayout", {
    CellSize = UDim2.fromOffset(76, 96),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = iconHolder,
})

--------------------------------------------------------------------------
-- Ecran d'une appli (topbar + zone de contenu)
--------------------------------------------------------------------------

local appScreen = create("Frame", {
    Name = "AppScreen",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = screenFrame,
})

local topBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, TOPBAR_H),
    BackgroundColor3 = Color3.fromRGB(20, 20, 24),
    Parent = appScreen,
})

local backButton = create("TextButton", {
    Size = UDim2.fromOffset(30, TOPBAR_H),
    Position = UDim2.fromOffset(4, 0),
    BackgroundTransparency = 1,
    Text = "\226\151\128", -- fleche retour
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    Parent = topBar,
})

local titleLabel = create("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.fromOffset(36, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
    Parent = topBar,
})

local scoreLabel = create("TextLabel", {
    Size = UDim2.fromOffset(70, TOPBAR_H),
    Position = UDim2.new(1, -74, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(255, 255, 100),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "",
    Parent = topBar,
})

local appContainer = create("Frame", {
    Name = "AppContainer",
    Size = UDim2.fromOffset(CONTENT_W, CONTENT_H),
    Position = UDim2.fromOffset(0, TOPBAR_H),
    BackgroundColor3 = Color3.fromRGB(12, 12, 15),
    ClipsDescendants = true,
    Parent = appScreen,
})

--------------------------------------------------------------------------
-- Gestion de l'ouverture / fermeture des applis
--------------------------------------------------------------------------

local Apps = {}
local currentCleanup = nil

local function clearContainer()
    for _, child in ipairs(appContainer:GetChildren()) do
        child:Destroy()
    end
end

local function closeApp()
    if currentCleanup then
        pcall(currentCleanup)
        currentCleanup = nil
    end
    clearContainer()
    scoreLabel.Text = ""
    appScreen.Visible = false
    homeScreen.Visible = true
end

backButton.MouseButton1Click:Connect(closeApp)

local function openApp(app)
    if currentCleanup then
        pcall(currentCleanup)
        currentCleanup = nil
    end
    clearContainer()
    homeScreen.Visible = false
    appScreen.Visible = true
    titleLabel.Text = app.Name
    scoreLabel.Text = "Score: 0"
    currentCleanup = app.Init(appContainer, scoreLabel)
end

local function buildHomeScreen()
    for order, app in ipairs(Apps) do
        local wrapper = create("Frame", {
            Size = UDim2.fromOffset(76, 96),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = iconHolder,
        })

        local iconButton = create("TextButton", {
            Size = UDim2.fromOffset(64, 64),
            Position = UDim2.fromOffset(6, 0),
            BackgroundColor3 = app.Color or Color3.fromRGB(60, 120, 220),
            Text = app.Icon,
            TextScaled = true,
            Font = Enum.Font.GothamBold,
            Parent = wrapper,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = iconButton })

        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.fromOffset(0, 68),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(230, 230, 230),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            Text = app.Name,
            Parent = wrapper,
        })

        iconButton.MouseButton1Click:Connect(function()
            openApp(app)
        end)
    end
end

--------------------------------------------------------------------------
-- Boutons directionnels reutilisables (Snake / 2048)
--------------------------------------------------------------------------

local function buildDPad(parent, onDirection)
    local pad = create("Frame", {
        Size = UDim2.fromOffset(140, 140),
        Position = UDim2.new(0.5, -70, 1, -150),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = parent,
    })

    local specs = {
        { text = "\226\150\178", pos = UDim2.fromOffset(48, 0), dir = "Up" },
        { text = "\226\150\188", pos = UDim2.fromOffset(48, 96), dir = "Down" },
        { text = "\226\151\128", pos = UDim2.fromOffset(0, 48), dir = "Left" },
        { text = "\226\150\182", pos = UDim2.fromOffset(96, 48), dir = "Right" },
    }

    local connections = {}
    for _, spec in ipairs(specs) do
        local btn = create("TextButton", {
            Size = UDim2.fromOffset(44, 44),
            Position = spec.pos,
            BackgroundColor3 = Color3.fromRGB(40, 40, 46),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = spec.text,
            TextScaled = true,
            Font = Enum.Font.GothamBold,
            ZIndex = 3,
            Parent = pad,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = btn })
        table.insert(connections, btn.MouseButton1Click:Connect(function()
            onDirection(spec.dir)
        end))
    end

    return pad, connections
end

--------------------------------------------------------------------------
-- Appli 1 : Flappy Bird
--------------------------------------------------------------------------

local FlappyBird = { Name = "Flappy", Icon = "\240\159\144\166", Color = Color3.fromRGB(80, 170, 235), Best = 0 }

function FlappyBird.Init(container, scoreLabel)
    local GRAVITY = 900
    local FLAP_IMPULSE = -300
    local PIPE_WIDTH = 44
    local PIPE_GAP = 145
    local PIPE_SPEED = 130
    local PIPE_SPACING = 190
    local GROUND_HEIGHT = 30
    local PLAYABLE_HEIGHT = CONTENT_H - GROUND_HEIGHT
    local BIRD_X, BIRD_RADIUS = 46, 13

    local conns = {}
    local pipes = {}
    local birdY, birdVel = PLAYABLE_HEIGHT / 2, 0
    local score = 0
    local gameState = "start" -- start | playing | gameover
    local idleTween

    create("Frame", {
        Size = UDim2.new(1, 0, 0, GROUND_HEIGHT),
        Position = UDim2.new(0, 0, 1, -GROUND_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(222, 184, 111),
        ZIndex = 3,
        Parent = container,
    })

    local bird = create("Frame", {
        Size = UDim2.fromOffset(BIRD_RADIUS * 2, BIRD_RADIUS * 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(247, 202, 24),
        ZIndex = 4,
        Parent = container,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bird })
    create("Frame", {
        Size = UDim2.fromOffset(10, 6),
        Position = UDim2.new(1, -4, 0.5, -3),
        BackgroundColor3 = Color3.fromRGB(235, 140, 52),
        ZIndex = 5,
        Parent = bird,
    })

    local flapButton = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 1,
        Parent = container,
    })

    local function createOverlay()
        return create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.35,
            Visible = false,
            ZIndex = 6,
            Parent = container,
        })
    end

    local startOverlay = createOverlay()
    startOverlay.Visible = true
    create("TextLabel", {
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 10, 0.3, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Flappy Bird",
        ZIndex = 7,
        Parent = startOverlay,
    })
    local startButton = create("TextButton", {
        Size = UDim2.fromOffset(140, 44),
        Position = UDim2.new(0.5, -70, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(94, 201, 98),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Jouer",
        ZIndex = 7,
        Parent = startOverlay,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = startButton })

    local overlay = createOverlay()
    local overlayLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0.28, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        Text = "Perdu !",
        ZIndex = 7,
        Parent = overlay,
    })
    local restartButton = create("TextButton", {
        Size = UDim2.fromOffset(140, 44),
        Position = UDim2.new(0.5, -70, 0.55, 0),
        BackgroundColor3 = Color3.fromRGB(80, 170, 235),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Rejouer",
        ZIndex = 7,
        Parent = overlay,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

    local function configurePipe(pipe, x)
        local gapCenter = math.random(70, math.max(71, PLAYABLE_HEIGHT - 70))
        local topHeight = gapCenter - PIPE_GAP / 2
        local bottomY = gapCenter + PIPE_GAP / 2
        pipe.x = x
        pipe.gapTop = topHeight
        pipe.gapBottom = bottomY
        pipe.scored = false
        pipe.top.Size = UDim2.fromOffset(PIPE_WIDTH, topHeight)
        pipe.top.Position = UDim2.fromOffset(x, 0)
        pipe.bottom.Size = UDim2.fromOffset(PIPE_WIDTH, PLAYABLE_HEIGHT - bottomY)
        pipe.bottom.Position = UDim2.fromOffset(x, bottomY)
    end

    local function createPipe()
        local top = create("Frame", { BackgroundColor3 = Color3.fromRGB(94, 201, 98), ZIndex = 2, Parent = container })
        local bottom = create("Frame", { BackgroundColor3 = Color3.fromRGB(94, 201, 98), ZIndex = 2, Parent = container })
        return { top = top, bottom = bottom }
    end

    local function destroyPipes()
        for _, pipe in ipairs(pipes) do
            pipe.top:Destroy()
            pipe.bottom:Destroy()
        end
        pipes = {}
    end

    local function spawnInitialPipes()
        for i = 1, 3 do
            local pipe = createPipe()
            configurePipe(pipe, CONTENT_W + 80 + (i - 1) * PIPE_SPACING)
            table.insert(pipes, pipe)
        end
    end

    local function setIdle(enabled)
        if idleTween then
            idleTween:Cancel()
            idleTween = nil
        end
        if enabled then
            idleTween = TweenService:Create(bird, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Position = UDim2.fromOffset(BIRD_X, birdY - 14),
            })
            idleTween:Play()
        end
    end

    local function resetGame()
        destroyPipes()
        birdY = PLAYABLE_HEIGHT / 2
        birdVel = 0
        score = 0
        scoreLabel.Text = "Score: 0"
        bird.Rotation = 0
        bird.Position = UDim2.fromOffset(BIRD_X, birdY)
        spawnInitialPipes()
    end

    local function startGame()
        setIdle(false)
        startOverlay.Visible = false
        overlay.Visible = false
        resetGame()
        gameState = "playing"
    end

    local function endGame()
        if gameState ~= "playing" then return end
        gameState = "gameover"
        if score > FlappyBird.Best then
            FlappyBird.Best = score
        end
        overlayLabel.Text = "Perdu !\nScore: " .. score .. "  (Meilleur: " .. FlappyBird.Best .. ")"
        overlay.Visible = true
    end

    local function flap()
        if gameState == "playing" then
            birdVel = FLAP_IMPULSE
        elseif gameState == "start" then
            startGame()
        end
    end

    bird.Position = UDim2.fromOffset(BIRD_X, birdY)
    setIdle(true)

    table.insert(conns, flapButton.MouseButton1Down:Connect(flap))
    table.insert(conns, startButton.MouseButton1Click:Connect(startGame))
    table.insert(conns, restartButton.MouseButton1Click:Connect(startGame))
    table.insert(conns, UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
            flap()
        end
    end))

    table.insert(conns, RunService.Heartbeat:Connect(function(dt)
        if gameState ~= "playing" then return end

        birdVel += GRAVITY * dt
        birdY += birdVel * dt
        if birdY - BIRD_RADIUS < 0 then
            birdY = BIRD_RADIUS
            birdVel = 0
        end
        bird.Position = UDim2.fromOffset(BIRD_X, birdY)
        bird.Rotation = math.clamp(birdVel / 12, -25, 70)

        local rightmostX = 0
        for _, pipe in ipairs(pipes) do
            pipe.x -= PIPE_SPEED * dt
            pipe.top.Position = UDim2.fromOffset(pipe.x, 0)
            pipe.bottom.Position = UDim2.fromOffset(pipe.x, pipe.gapBottom)
            rightmostX = math.max(rightmostX, pipe.x)

            if not pipe.scored and pipe.x + PIPE_WIDTH < BIRD_X then
                pipe.scored = true
                score += 1
                scoreLabel.Text = "Score: " .. score
            end

            if BIRD_X + BIRD_RADIUS > pipe.x and BIRD_X - BIRD_RADIUS < pipe.x + PIPE_WIDTH then
                if birdY - BIRD_RADIUS < pipe.gapTop or birdY + BIRD_RADIUS > pipe.gapBottom then
                    endGame()
                    return
                end
            end
        end

        for _, pipe in ipairs(pipes) do
            if pipe.x + PIPE_WIDTH < -20 then
                configurePipe(pipe, rightmostX + PIPE_SPACING)
            end
        end

        if birdY + BIRD_RADIUS >= PLAYABLE_HEIGHT then
            endGame()
        end
    end))

    return function()
        setIdle(false)
        for _, conn in ipairs(conns) do
            conn:Disconnect()
        end
        destroyPipes()
    end
end

table.insert(Apps, FlappyBird)

--------------------------------------------------------------------------
-- Appli 2 : Snake
--------------------------------------------------------------------------

local SnakeApp = { Name = "Snake", Icon = "\240\159\144\141", Color = Color3.fromRGB(70, 200, 110) }

function SnakeApp.Init(container, scoreLabel)
    local CELL = 20
    local COLS = math.floor(CONTENT_W / CELL)
    local ROWS = math.floor(CONTENT_H / CELL)
    local OFFSET_X = (CONTENT_W - COLS * CELL) / 2
    local OFFSET_Y = (CONTENT_H - ROWS * CELL) / 2
    local MOVE_INTERVAL = 0.15

    local conns = {}
    local segmentFrames = {}
    local body = {}
    local direction = { x = 1, y = 0 }
    local nextDirection = direction
    local apple = { x = 0, y = 0 }
    local score = 0
    local running = true
    local dead = false

    local board = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = container,
    })

    local appleFrame = create("Frame", {
        Size = UDim2.fromOffset(CELL - 2, CELL - 2),
        BackgroundColor3 = Color3.fromRGB(230, 70, 70),
        ZIndex = 2,
        Parent = board,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = appleFrame })

    local overlay = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        Visible = false,
        ZIndex = 5,
        Parent = container,
    })
    local overlayLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0.3, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        Text = "Game Over",
        ZIndex = 6,
        Parent = overlay,
    })
    local restartButton = create("TextButton", {
        Size = UDim2.fromOffset(140, 44),
        Position = UDim2.new(0.5, -70, 0.55, 0),
        BackgroundColor3 = Color3.fromRGB(70, 200, 110),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Rejouer",
        ZIndex = 6,
        Parent = overlay,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

    local function cellPosition(cx, cy)
        return UDim2.fromOffset(OFFSET_X + cx * CELL + 1, OFFSET_Y + cy * CELL + 1)
    end

    local function clearSegments()
        for _, frame in ipairs(segmentFrames) do
            frame:Destroy()
        end
        segmentFrames = {}
    end

    local function drawSnake()
        clearSegments()
        for i, segment in ipairs(body) do
            local frame = create("Frame", {
                Size = UDim2.fromOffset(CELL - 2, CELL - 2),
                Position = cellPosition(segment.x, segment.y),
                BackgroundColor3 = i == 1 and Color3.fromRGB(120, 230, 150) or Color3.fromRGB(70, 190, 100),
                ZIndex = 2,
                Parent = board,
            })
            create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })
            table.insert(segmentFrames, frame)
        end
    end

    local function placeApple()
        local free = {}
        for x = 0, COLS - 1 do
            for y = 0, ROWS - 1 do
                local occupied = false
                for _, seg in ipairs(body) do
                    if seg.x == x and seg.y == y then
                        occupied = true
                        break
                    end
                end
                if not occupied then
                    table.insert(free, { x = x, y = y })
                end
            end
        end
        if #free == 0 then return end
        apple = free[math.random(1, #free)]
        appleFrame.Position = cellPosition(apple.x, apple.y)
    end

    local function reset()
        dead = false
        score = 0
        scoreLabel.Text = "Score: 0"
        overlay.Visible = false
        direction = { x = 1, y = 0 }
        nextDirection = direction
        local midX, midY = math.floor(COLS / 2), math.floor(ROWS / 2)
        body = {
            { x = midX, y = midY },
            { x = midX - 1, y = midY },
            { x = midX - 2, y = midY },
        }
        drawSnake()
        placeApple()
    end

    local function setDirection(dir)
        local map = {
            Up = { x = 0, y = -1 },
            Down = { x = 0, y = 1 },
            Left = { x = -1, y = 0 },
            Right = { x = 1, y = 0 },
        }
        local d = map[dir]
        if not d then return end
        if d.x == -direction.x and d.y == -direction.y then return end
        nextDirection = d
    end

    local pad, padConns = buildDPad(container, setDirection)
    for _, c in ipairs(padConns) do table.insert(conns, c) end

    table.insert(conns, UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        local keyMap = {
            [Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up",
            [Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down",
            [Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left",
            [Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right",
        }
        local dir = keyMap[input.KeyCode]
        if dir then setDirection(dir) end
    end))

    table.insert(conns, restartButton.MouseButton1Click:Connect(reset))

    reset()

    safeSpawn(function()
        while running do
            safeWait(MOVE_INTERVAL)
            if not running or dead then continue end

            direction = nextDirection
            local head = body[1]
            local newHead = { x = head.x + direction.x, y = head.y + direction.y }

            if newHead.x < 0 or newHead.x >= COLS or newHead.y < 0 or newHead.y >= ROWS then
                dead = true
                overlayLabel.Text = "Game Over\nScore: " .. score
                overlay.Visible = true
                continue
            end

            for _, seg in ipairs(body) do
                if seg.x == newHead.x and seg.y == newHead.y then
                    dead = true
                    overlayLabel.Text = "Game Over\nScore: " .. score
                    overlay.Visible = true
                    break
                end
            end
            if dead then continue end

            table.insert(body, 1, newHead)
            if newHead.x == apple.x and newHead.y == apple.y then
                score += 1
                scoreLabel.Text = "Score: " .. score
                placeApple()
            else
                table.remove(body)
            end

            drawSnake()
        end
    end)

    return function()
        running = false
        for _, conn in ipairs(conns) do
            conn:Disconnect()
        end
        clearSegments()
    end
end

table.insert(Apps, SnakeApp)

--------------------------------------------------------------------------
-- Appli 3 : 2048
--------------------------------------------------------------------------

local Game2048 = { Name = "2048", Icon = "\240\159\148\162", Color = Color3.fromRGB(230, 160, 60) }

local TILE_COLORS = {
    [2] = Color3.fromRGB(238, 228, 218), [4] = Color3.fromRGB(237, 224, 200),
    [8] = Color3.fromRGB(242, 177, 121), [16] = Color3.fromRGB(245, 149, 99),
    [32] = Color3.fromRGB(246, 124, 95), [64] = Color3.fromRGB(246, 94, 59),
    [128] = Color3.fromRGB(237, 207, 114), [256] = Color3.fromRGB(237, 204, 97),
    [512] = Color3.fromRGB(237, 200, 80), [1024] = Color3.fromRGB(237, 197, 63),
    [2048] = Color3.fromRGB(237, 194, 46),
}

function Game2048.Init(container, scoreLabel)
    local SIZE = 4
    local CELL = 60
    local GAP = 8
    local BOARD = SIZE * CELL + (SIZE + 1) * GAP
    local OFFSET_X = (CONTENT_W - BOARD) / 2
    local OFFSET_Y = 20

    local conns = {}
    local grid = {}
    local tileFrames = {}
    local score = 0
    local dead = false

    local board = create("Frame", {
        Size = UDim2.fromOffset(BOARD, BOARD),
        Position = UDim2.fromOffset(OFFSET_X, OFFSET_Y),
        BackgroundColor3 = Color3.fromRGB(40, 36, 32),
        Parent = container,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = board })

    for x = 1, SIZE do
        for y = 1, SIZE do
            create("Frame", {
                Size = UDim2.fromOffset(CELL, CELL),
                Position = UDim2.fromOffset(GAP + (x - 1) * (CELL + GAP), GAP + (y - 1) * (CELL + GAP)),
                BackgroundColor3 = Color3.fromRGB(60, 55, 50),
                ZIndex = 1,
                Parent = board,
            })
        end
    end

    local overlay = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        Visible = false,
        ZIndex = 5,
        Parent = container,
    })
    local overlayLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0.3, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        Text = "Perdu !",
        ZIndex = 6,
        Parent = overlay,
    })
    local restartButton = create("TextButton", {
        Size = UDim2.fromOffset(140, 44),
        Position = UDim2.new(0.5, -70, 0.55, 0),
        BackgroundColor3 = Color3.fromRGB(230, 160, 60),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Rejouer",
        ZIndex = 6,
        Parent = overlay,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

    local function clearTiles()
        for _, frame in ipairs(tileFrames) do
            frame:Destroy()
        end
        tileFrames = {}
    end

    local function draw()
        clearTiles()
        for x = 1, SIZE do
            for y = 1, SIZE do
                local value = grid[x][y]
                if value ~= 0 then
                    local frame = create("Frame", {
                        Size = UDim2.fromOffset(CELL, CELL),
                        Position = UDim2.fromOffset(GAP + (x - 1) * (CELL + GAP), GAP + (y - 1) * (CELL + GAP)),
                        BackgroundColor3 = TILE_COLORS[value] or Color3.fromRGB(60, 20, 20),
                        ZIndex = 2,
                        Parent = board,
                    })
                    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
                    create("TextLabel", {
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        Font = Enum.Font.GothamBold,
                        TextScaled = true,
                        TextColor3 = value <= 4 and Color3.fromRGB(60, 55, 50) or Color3.fromRGB(255, 255, 255),
                        Text = tostring(value),
                        ZIndex = 3,
                        Parent = frame,
                    })
                    table.insert(tileFrames, frame)
                end
            end
        end
    end

    local function emptyCells()
        local cells = {}
        for x = 1, SIZE do
            for y = 1, SIZE do
                if grid[x][y] == 0 then
                    table.insert(cells, { x = x, y = y })
                end
            end
        end
        return cells
    end

    local function spawnTile()
        local cells = emptyCells()
        if #cells == 0 then return end
        local cell = cells[math.random(1, #cells)]
        grid[cell.x][cell.y] = math.random() < 0.9 and 2 or 4
    end

    local function canMove()
        if #emptyCells() > 0 then return true end
        for x = 1, SIZE do
            for y = 1, SIZE do
                local value = grid[x][y]
                if (x < SIZE and grid[x + 1][y] == value) or (y < SIZE and grid[x][y + 1] == value) then
                    return true
                end
            end
        end
        return false
    end

    -- Deplace et fusionne une seule ligne (liste de valeurs, 0 = vide) vers la gauche.
    local function collapseLine(line)
        local values = {}
        for _, v in ipairs(line) do
            if v ~= 0 then table.insert(values, v) end
        end
        local result = {}
        local i = 1
        local gained = 0
        while i <= #values do
            if values[i + 1] and values[i] == values[i + 1] then
                local merged = values[i] * 2
                table.insert(result, merged)
                gained += merged
                i += 2
            else
                table.insert(result, values[i])
                i += 1
            end
        end
        while #result < #line do
            table.insert(result, 0)
        end
        return result, gained
    end

    local function getLine(dir, index)
        local line = {}
        for i = 1, SIZE do
            if dir == "Left" or dir == "Right" then
                line[i] = grid[i][index]
            else
                line[i] = grid[index][i]
            end
        end
        if dir == "Right" or dir == "Down" then
            local reversed = {}
            for i = 1, SIZE do reversed[i] = line[SIZE - i + 1] end
            line = reversed
        end
        return line
    end

    local function setLine(dir, index, line)
        if dir == "Right" or dir == "Down" then
            local reversed = {}
            for i = 1, SIZE do reversed[i] = line[SIZE - i + 1] end
            line = reversed
        end
        for i = 1, SIZE do
            if dir == "Left" or dir == "Right" then
                grid[i][index] = line[i]
            else
                grid[index][i] = line[i]
            end
        end
    end

    local function move(dir)
        if dead then return end
        local moved = false
        local totalGain = 0

        for index = 1, SIZE do
            local before = getLine(dir, index)
            local after, gained = collapseLine(before)
            totalGain += gained
            for i = 1, SIZE do
                if before[i] ~= after[i] then moved = true end
            end
            setLine(dir, index, after)
        end

        if moved then
            score += totalGain
            scoreLabel.Text = "Score: " .. score
            spawnTile()
            draw()
            if not canMove() then
                dead = true
                overlayLabel.Text = "Perdu !\nScore: " .. score
                overlay.Visible = true
            end
        end
    end

    local function reset()
        grid = {}
        for x = 1, SIZE do
            grid[x] = {}
            for y = 1, SIZE do
                grid[x][y] = 0
            end
        end
        score = 0
        dead = false
        scoreLabel.Text = "Score: 0"
        overlay.Visible = false
        spawnTile()
        spawnTile()
        draw()
    end

    local pad, padConns = buildDPad(container, move)
    for _, c in ipairs(padConns) do table.insert(conns, c) end

    table.insert(conns, UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        local keyMap = {
            [Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up",
            [Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down",
            [Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left",
            [Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right",
        }
        local dir = keyMap[input.KeyCode]
        if dir then move(dir) end
    end))

    table.insert(conns, restartButton.MouseButton1Click:Connect(reset))

    reset()

    return function()
        for _, conn in ipairs(conns) do
            conn:Disconnect()
        end
        clearTiles()
    end
end

table.insert(Apps, Game2048)

--------------------------------------------------------------------------
-- Construction finale de l'ecran d'accueil
--------------------------------------------------------------------------

buildHomeScreen()

end)

if not buildOk then
    warn("[Phone] Erreur au chargement, ecran vide en consequence: " .. tostring(buildErr))
end
