-- TrophyScan4: re-enumerate stages now that you've progressed further
-- (earlier scans ran before Stage15+ had streamed in). Lists every Stage
-- folder currently loaded, every WinBlock/Trophy found in each, AND probes
-- Stage16..Stage30 by name to see how far the track actually goes.

local Workspace = game:GetService("Workspace")
local structure = Workspace:FindFirstChild("Structure")
if not structure then
	print("No Workspace.Structure found.")
	return
end

local function describeWinBlock(inst)
	local posText = ""
	if inst:IsA("BasePart") then
		posText = string.format("Position=(%.1f, %.1f, %.1f)", inst.Position.X, inst.Position.Y, inst.Position.Z)
	end
	print(string.format("  WinBlock: %s (%s) %s", inst:GetFullName(), inst.ClassName, posText))
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BillboardGui") then
			for _, lbl in ipairs(d:GetDescendants()) do
				if lbl:IsA("TextLabel") and lbl.Text ~= "" then
					print("      -> text: '" .. lbl.Text .. "'")
				end
			end
		end
	end
end

print("=== TrophyScan4: currently loaded Stage folders ===")
local stageNames = {}
for _, child in ipairs(structure:GetChildren()) do
	if child.Name:match("^Stage") then
		table.insert(stageNames, child.Name)
	end
end
table.sort(stageNames)
print("Stages found: " .. table.concat(stageNames, ", "))

print("=== WinBlock per stage (currently loaded) ===")
for _, stageName in ipairs(stageNames) do
	local stage = structure:FindFirstChild(stageName)
	local any = false
	for _, inst in ipairs(stage:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name:match("^WinBlock%d+$") then
			any = true
			describeWinBlock(inst)
		end
	end
	if not any then
		print("-- " .. stageName .. ": no WinBlock --")
	end
end

print("=== Probing Stage16..Stage30 by name (not yet streamed = still show up if it exists but hasn't loaded fully) ===")
for i = 16, 30 do
	local stage = structure:FindFirstChild("Stage" .. i)
	if stage then
		print("Stage" .. i .. " EXISTS")
		for _, inst in ipairs(stage:GetDescendants()) do
			if inst:IsA("BasePart") and inst.Name:match("^WinBlock%d+$") then
				describeWinBlock(inst)
			end
		end
	end
end

print("=== Done ===")
