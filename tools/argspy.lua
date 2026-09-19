-- Steal An Egg arg spy — logs the exact args of every remote fire.
-- Run this, then do ONE of each action by hand (hatch an egg, place a pet,
-- steal from someone's base, sell/equip a pet, buy a gamepass/egg slot,
-- upgrade something). Each fire prints + appends to StealAnEgg_args.txt.

local out = {}
local function repr(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "Instance" then return ("<%s:%s>"):format(v.ClassName, v:GetFullName())
	elseif t == "table" then
		if depth > 3 then return "{...}" end
		local p = {}
		for k, val in pairs(v) do p[#p + 1] = ("[%s]=%s"):format(tostring(k), repr(val, depth + 1)) end
		return "{" .. table.concat(p, ", ") .. "}"
	elseif t == "string" then return ('%q'):format(v)
	else return tostring(v) end
end
local function reprArgs(...)
	local n, p = select("#", ...), {}
	for i = 1, n do p[i] = repr((select(i, ...))) end
	return table.concat(p, ", ")
end

local function record(s)
	out[#out + 1] = s
	print("[argspy] " .. s)
	if writefile then pcall(function() writefile("StealAnEgg_args.txt", table.concat(out, "\n"))end) end
end

local ok = pcall(function()
	local old
	old = hookmetamethod(game, "__namecall", function(self, ...)
		local m = getnamecallmethod()
		if (m == "FireServer" or m == "InvokeServer")
		   and typeof(self) == "Instance"
		   and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
			record(("%s :%s(%s)"):format(self:GetFullName(), m, reprArgs(...)))
		end
		return old(self, ...)
	end)
end)

if ok then record("=== argspy armed — do your actions now ===")
else warn("[argspy] hookmetamethod unavailable — tell nyx, we'll use another method") end
