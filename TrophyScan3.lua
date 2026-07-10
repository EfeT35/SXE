-- TrophyScan3: dumps EVERYTHING inside the stages that had no WinBlock
-- (Stage1, Stage13, Stage14, Stage15), so we can find what the "+10K Wins"
-- style reward is actually named there.

local Workspace = game:GetService("Workspace")
local structure = Workspace:FindFirstChild("Structure")
if not structure then
	print("No Workspace.Structure found.")
	return
end

local TARGET_STAGES = {"Stage1", "Stage13", "Stage14", "Stage15"}

local function describe(inst)
	local posText = ""
	if inst:IsA("BasePart") then
		posText = string.format(" | Position=(%.1f, %.1f, %.1f)", inst.Position.X, inst.Position.Y, inst.Position.Z)
	elseif inst:IsA("Model") then
		local ok, cf = pcall(function() return inst:GetPivot() end)
		if ok then posText = string.format(" | Pivot=(%.1f, %.1f, %.1f)", cf.Position.X, cf.Position.Y, cf.Position.Z) end
	end
	print(string.format("  %s (%s)%s", inst:GetFullName(), inst.ClassName, posText))
	if inst:IsA("ProximityPrompt") then
		print(string.format("      -> ProximityPrompt: ActionText='%s' ObjectText='%s' KeyboardKeyCode=%s",
			inst.ActionText, inst.ObjectText, tostring(inst.KeyboardKeyCode)))
	end
	if inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text ~= "" then
				print("      -> text: '" .. d.Text .. "'")
			end
		end
	end
end

for _, stageName in ipairs(TARGET_STAGES) do
	local stage = structure:FindFirstChild(stageName)
	print("=== " .. stageName .. " ===")
	if not stage then
		print("  (not found)")
	else
		-- Only top-level-ish structure to keep output short: first 2 levels
		-- plus anything with a ProximityPrompt/BillboardGui/SurfaceGui/ClickDetector.
		for _, inst in ipairs(stage:GetDescendants()) do
			local depth = 0
			local cur = inst
			while cur and cur ~= stage do depth = depth + 1; cur = cur.Parent end
			if depth <= 3 or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector")
				or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
				describe(inst)
			end
		end
	end
end

print("=== Done ===")
