-- TrophyScan2: targeted scan, run this after TrophyScan.lua.
-- Lists every Stage folder under Workspace.Structure, and every WinBlock/Trophy
-- part inside each one, with position and any ProximityPrompt/Touched-relevant
-- info. Ignores decoration (cupcakes etc).

local Workspace = game:GetService("Workspace")

local structure = Workspace:FindFirstChild("Structure")
if not structure then
	print("No Workspace.Structure found.")
	return
end

print("=== TrophyScan2: Stage folders ===")
local stageNames = {}
for _, child in ipairs(structure:GetChildren()) do
	if child.Name:match("^Stage") then
		table.insert(stageNames, child.Name)
	end
end
table.sort(stageNames)
print("Stages found: " .. table.concat(stageNames, ", "))

local function describePart(inst, label)
	local posText = ""
	if inst:IsA("BasePart") then
		posText = string.format("Position=(%.1f, %.1f, %.1f)", inst.Position.X, inst.Position.Y, inst.Position.Z)
	elseif inst:IsA("Model") then
		local ok, cf = pcall(function() return inst:GetPivot() end)
		if ok then posText = string.format("Pivot=(%.1f, %.1f, %.1f)", cf.Position.X, cf.Position.Y, cf.Position.Z) end
	end
	print(string.format("  %s: %s (%s) %s", label, inst:GetFullName(), inst.ClassName, posText))
	for _, prompt in ipairs(inst:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			print(string.format("      -> ProximityPrompt: ActionText='%s' KeyboardKeyCode=%s HoldDuration=%s",
				prompt.ActionText, tostring(prompt.KeyboardKeyCode), tostring(prompt.HoldDuration)))
		end
	end
end

print("=== WinBlock / Trophy parts per stage ===")
for _, stageName in ipairs(stageNames) do
	local stage = structure:FindFirstChild(stageName)
	print("-- " .. stageName .. " --")
	for _, inst in ipairs(stage:GetDescendants()) do
		if inst.Name:match("^WinBlock") then
			describePart(inst, "WinBlock")
		elseif inst.Name == "Trophy" then
			describePart(inst, "Trophy")
		end
	end
end

print("=== Done ===")
