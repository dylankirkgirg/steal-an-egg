-- Steal An Egg structure dump. Generic (no Knit/Network assumption) —
-- walks every RemoteEvent/RemoteFunction/Bindable in ReplicatedStorage,
-- lists RS + workspace top-level children, and requires every ModuleScript
-- printing its top-level keys (data lists: eggs, pets, gamepasses, etc).
-- Writes StealAnEgg_dump.txt to the executor workspace.

local RS = game:GetService("ReplicatedStorage")
local out = {}
local function line(s) table.insert(out, s) end

line("===== Remotes (RemoteEvent / RemoteFunction / Bindable) =====")
for _, d in ipairs(RS:GetDescendants()) do
	if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
	   or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
		line(("%s  [%s]"):format(d:GetFullName(), d.ClassName))
	end
end

line("")
line("===== ReplicatedStorage top-level children =====")
for _, c in ipairs(RS:GetChildren()) do
	line(("%s  [%s]"):format(c.Name, c.ClassName))
end

line("")
line("===== workspace top-level children =====")
for _, c in ipairs(workspace:GetChildren()) do
	line(("%s  [%s]"):format(c.Name, c.ClassName))
end

line("")
line("===== ModuleScript keys (data lists) =====")
for _, d in ipairs(RS:GetDescendants()) do
	if d:IsA("ModuleScript") then
		local ok, data = pcall(require, d)
		if ok and type(data) == "table" then
			local keys = {}
			for k in pairs(data) do table.insert(keys, tostring(k)) end
			table.sort(keys)
			line(("%s -> %s"):format(d:GetFullName(), table.concat(keys, ", "):sub(1, 500)))
		end
	end
end

local text = table.concat(out, "\n")
if writefile then
	writefile("StealAnEgg_dump.txt", text)
	print("[dump] wrote StealAnEgg_dump.txt — " .. #out .. " lines")
else
	print(text)
end
