-- Steal An Egg — Nyx (Obsidian UI)
-- Remotes mapped from ReplicatedStorage.Packages.Networking via tools/dump.lua
-- (namecall-hook argspy avoided in this game after one kick — see README).
-- Loaded by nyx-hub's loader.lua.

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local VU        = game:GetService("VirtualUser")
local UIS       = game:GetService("UserInputService")
local RunSvc    = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local function char() return LocalPlayer.Character end
local function humanoid() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ============================================================
-- remotes (Category/Name pattern under Packages.Networking.RE|RF)
-- ============================================================
local Network = RS:WaitForChild("Packages"):WaitForChild("Networking")
local function R(kind, path)
	local ok, obj = pcall(function() return Network:FindFirstChild(kind .. "/" .. path) end)
	return ok and obj or nil
end

local AwayEarningsCollect = R("RF", "AwayEarnings/AskCollect")
local CodexRedeem         = R("RF", "Codex/AskRedeem")
local CodexRedeemAll      = R("RF", "Codex/AskRedeemAll")
local SellEveryPet        = R("RE", "PetSatchel/SellEveryPet")
local HaulWriteAutoSell   = R("RF", "Haul/WriteAutoSell")
local HaulWearBest        = R("RF", "Haul/WearBest")
local GroupPerkRedeem     = R("RF", "GroupPerk/RedeemPerk")
local OnboardingClaim     = R("RF", "OnboardingQuestline/AskClaim")
local BossMasteryClaim    = R("RF", "BossMastery/AskClaimMilestone")

-- ============================================================
-- Obsidian + addons + Nyx skin
-- ============================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local NyxTheme = (getgenv and getgenv().Nyx and getgenv().Nyx.theme) or {
	BackgroundColor = Color3.fromRGB(16, 12, 15),
	MainColor       = Color3.fromRGB(25, 19, 23),
	AccentColor     = Color3.fromRGB(233, 122, 173),
	OutlineColor    = Color3.fromRGB(50, 39, 46),
	FontColor       = Color3.fromRGB(240, 232, 237),
}

local Window = Library:CreateWindow({
	Title             = "Nyx",
	Footer            = "steal an egg",
	Scheme            = NyxTheme,
	Size              = UDim2.fromOffset(720, 600),
	Center            = true,
	AutoShow          = true,
	ToggleKeybind     = Enum.KeyCode.RightShift,
	ShowCustomCursor  = false,
	ShowMobileButtons = true,
	MobileButtonsSide = "Left",
})

local Tabs = {
	Farm     = Window:AddTab({ Name = "Farm",     Icon = "coins" }),
	Pets     = Window:AddTab({ Name = "Pets",     Icon = "paw-print" }),
	Player   = Window:AddTab({ Name = "Player",   Icon = "user" }),
	Settings = Window:AddTab({ Name = "Settings", Icon = "settings" }),
}

-- ============================================================
-- state
-- ============================================================
local running = true
local autoCollect  = false
local autoClaim    = false
local autoSellFull = false
local autoWearBest = false
local antiAfk      = false

-- CFrame escape speed — see README for the anti-cheat reasoning.
-- Leaves Humanoid.WalkSpeed untouched (that's the property WalkSpeedGovernor
-- watches); moves the HumanoidRootPart's position directly instead.
-- RISKY: this game also has RigSync (Reconcile/CorrectionBegan), a position
-- integrity check independent of WalkSpeed. Tick-bounded (dt-scaled, no big
-- jumps) to look like fast movement rather than a teleport, but that's not
-- a guarantee against a server that hard-caps distance-per-tick. Test at low
-- multiplier first.
local escapeOn, escapeSpeed = false, 32 -- studs/sec added on top of normal walking

-- ============================================================
-- background loops
-- ============================================================
local function loop(intervalOn, intervalOff, fn)
	task.spawn(function()
		while running do
			local on = fn()
			task.wait(on and intervalOn or intervalOff)
		end
	end)
end

loop(20, 3, function()
	if autoCollect and AwayEarningsCollect then pcall(function() AwayEarningsCollect:InvokeServer() end) return true end
end)
loop(30, 3, function()
	if not autoClaim then return false end
	if OnboardingClaim then pcall(function() OnboardingClaim:InvokeServer() end) end
	if BossMasteryClaim then pcall(function() BossMasteryClaim:InvokeServer() end) end
	if GroupPerkRedeem then pcall(function() GroupPerkRedeem:InvokeServer() end) end
	return true
end)
loop(5, 2, function()
	if autoWearBest and HaulWearBest then pcall(function() HaulWearBest:InvokeServer() end) return true end
end)

-- escape speed: nudge HumanoidRootPart position each frame, WalkSpeed untouched
RunSvc.RenderStepped:Connect(function(dt)
	if not escapeOn then return end
	local root = hrp(); local cam = Workspace.CurrentCamera
	if not root or not cam then return end
	local dir = Vector3.zero
	if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then return end
	local step = dir.Unit * escapeSpeed * dt -- dt-scaled: small per-tick step, not a jump
	root.CFrame = root.CFrame + step
end)

-- anti-afk: defeat the idle kick
LocalPlayer.Idled:Connect(function()
	if not antiAfk then return end
	pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
end)

-- ============================================================
-- FARM tab
-- ============================================================
local FarmBox = Tabs.Farm:AddLeftGroupbox("Auto Farm")
local CodeBox = Tabs.Farm:AddRightGroupbox("Codes")

FarmBox:AddToggle("AutoCollect", { Text = "Auto Collect Away Earnings", Default = false,
	Callback = function(v) autoCollect = v end })
FarmBox:AddToggle("AutoClaim", { Text = "Auto Claim Rewards", Default = false,
	Tooltip = "Onboarding quests / boss mastery milestones / group perk.",
	Callback = function(v) autoClaim = v end })

local codeText = ""
CodeBox:AddInput("Code", { Text = "Code", Placeholder = "enter code", Default = "",
	Callback = function(v) codeText = v end })
CodeBox:AddButton({ Text = "Redeem Code",
	Func = function() if CodexRedeem and codeText ~= "" then pcall(function() CodexRedeem:InvokeServer(codeText) end) end end,
	Callback = function() if CodexRedeem and codeText ~= "" then pcall(function() CodexRedeem:InvokeServer(codeText) end) end end })
CodeBox:AddButton({ Text = "Redeem All Known Codes",
	Func = function() if CodexRedeemAll then pcall(function() CodexRedeemAll:InvokeServer() end) end end,
	Callback = function() if CodexRedeemAll then pcall(function() CodexRedeemAll:InvokeServer() end) end end })

-- ============================================================
-- PETS tab
-- ============================================================
local SellBox = Tabs.Pets:AddLeftGroupbox("Sell")
local WearBox = Tabs.Pets:AddRightGroupbox("Wear")

SellBox:AddButton({ Text = "Sell Every Pet",
	Func = function() if SellEveryPet then pcall(function() SellEveryPet:FireServer() end) end end,
	Callback = function() if SellEveryPet then pcall(function() SellEveryPet:FireServer() end) end end })
SellBox:AddToggle("AutoSellFull", { Text = "Auto Sell (native)", Default = false,
	Callback = function(v)
		autoSellFull = v
		if HaulWriteAutoSell then pcall(function() HaulWriteAutoSell:InvokeServer(v) end) end
	end })

WearBox:AddButton({ Text = "Wear Best Now",
	Func = function() if HaulWearBest then pcall(function() HaulWearBest:InvokeServer() end) end end,
	Callback = function() if HaulWearBest then pcall(function() HaulWearBest:InvokeServer() end) end end })
WearBox:AddToggle("AutoWearBest", { Text = "Auto Wear Best", Default = false,
	Callback = function(v) autoWearBest = v end })

-- ============================================================
-- PLAYER tab
-- ============================================================
local EscBox  = Tabs.Player:AddLeftGroupbox("Escape Speed (risky)")
local PerfBox = Tabs.Player:AddRightGroupbox("Performance")

EscBox:AddToggle("EscapeSpeed", { Text = "CFrame Escape Speed", Default = false,
	Tooltip = "WASD-relative. Moves position directly, leaves WalkSpeed untouched to dodge the WalkSpeedGovernor. RigSync may still catch large/fast movement — test at low speed first.",
	Callback = function(v) escapeOn = v end })
EscBox:AddSlider("EscapeSpeedAmount", { Text = "Extra Speed (studs/s)", Default = 32, Min = 0, Max = 150, Rounding = 0,
	Callback = function(v) escapeSpeed = v end })
EscBox:AddLabel({ Text = "Starts conservative. Raise gradually; watch for rubber-banding = it's catching you." })

-- FPS boost + GPU saver (cosmetic only, safe)
local perf = { disabled = {}, shadows = nil }
local function fpsBoost(on)
	if on then
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		perf.shadows = Lighting.GlobalShadows
		pcall(function() Lighting.GlobalShadows = false end)
		for _, v in ipairs(Workspace:GetDescendants()) do
			if (v:IsA("ParticleEmitter") or v:IsA("Trail")) and v.Enabled then
				v.Enabled = false; table.insert(perf.disabled, v)
			end
		end
	else
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		if perf.shadows ~= nil then pcall(function() Lighting.GlobalShadows = perf.shadows end) end
		for _, v in ipairs(perf.disabled) do pcall(function() v.Enabled = true end) end
		perf.disabled = {}
	end
end
local function gpuSaver(on) pcall(function() RunSvc:Set3dRenderingEnabled(not on) end) end

PerfBox:AddToggle("FPSBoost", { Text = "FPS Boost", Default = false, Callback = fpsBoost })
PerfBox:AddToggle("GPUSaver", { Text = "GPU Saver (disable 3D)", Default = false, Callback = gpuSaver })
PerfBox:AddToggle("AntiAfk", { Text = "Anti-AFK", Default = false, Callback = function(v) antiAfk = v end })

-- ============================================================
-- SETTINGS tab
-- ============================================================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder("steal-an-egg")
SaveManager:SetFolder("steal-an-egg")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

-- ============================================================
-- cleanup
-- ============================================================
Library:OnUnload(function()
	running = false
	autoCollect, autoClaim, autoWearBest, antiAfk, escapeOn = false, false, false, false, false
	if autoSellFull and HaulWriteAutoSell then pcall(function() HaulWriteAutoSell:InvokeServer(false) end) end
	fpsBoost(false); gpuSaver(false)
end)

SaveManager:LoadAutoloadConfig()
Library:Notify("Nyx loaded — RightShift to toggle UI")
