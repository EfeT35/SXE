-- TrophyScan: diagnostic script, run this FIRST.
-- Prints every Workspace instance whose name looks trophy/reward-related,
-- along with its class, full path, position, and any ProximityPrompt found
-- inside it. Copy/paste the console output back so the real auto-farm can
-- target the exact instance names/remotes this game actually uses.

local Workspace = game:GetService("Workspace")

local KEYWORDS = {"trophy", "troph", "reward", "win", "prize", "cup"}

local function matches(name)
	local lower = name:lower()
	for _, kw in ipairs(KEYWORDS) do
		if lower:find(kw, 1, true) then return true end
	end
	return false
end

local function fullPath(inst)
	local parts = {}
	local cur = inst
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, ".")
end

print("=== TrophyScan: searching Workspace ===")

local found = 0
for _, inst in ipairs(Workspace:GetDescendants()) do
	if matches(inst.Name) then
		found = found + 1
		local posText = ""
		if inst:IsA("BasePart") then
			posText = string.format(" | Position=(%.1f, %.1f, %.1f)", inst.Position.X, inst.Position.Y, inst.Position.Z)
		elseif inst:IsA("Model") then
			local ok, cf = pcall(function() return inst:GetPivot() end)
			if ok then
				posText = string.format(" | Pivot=(%.1f, %.1f, %.1f)", cf.Position.X, cf.Position.Y, cf.Position.Z)
			end
		end

		print(string.format("[%d] %s (%s)%s", found, fullPath(inst), inst.ClassName, posText))

		for _, prompt in ipairs(inst:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				print(string.format("      -> ProximityPrompt: ActionText='%s' ObjectText='%s' KeyboardKeyCode=%s HoldDuration=%s",
					prompt.ActionText, prompt.ObjectText, tostring(prompt.KeyboardKeyCode), tostring(prompt.HoldDuration)))
			end
		end

		local clickDetector = inst:FindFirstChildOfClass("ClickDetector")
		if clickDetector then
			print("      -> has a ClickDetector")
		end
	end
end

if found == 0 then
	print("No trophy/reward-named instance found. Try standing right next to the trophy prop and re-run, or tell Claude the exact visible name if you can see it (e.g. via a Dex/explorer tool).")
else
	print(string.format("=== Done: %d match(es) found ===", found))
end
