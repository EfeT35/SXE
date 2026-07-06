-- Script de test minimal : verifie juste que le jeu accepte
-- une interface custom creee par un executor.
local player = game:GetService("Players").LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TestGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 220)
frame.Position = UDim2.new(0.5, -110, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "TEST OK"
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Font = Enum.Font.GothamBold
label.Parent = frame

warn("[Test] GUI de test cree avec succes")
