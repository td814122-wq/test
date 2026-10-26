-- [[ Rscripts Risk Notice ]]
-- This script is not verified by rscripts.net. Deal with caution.
--
-- Stay safe:
--   • Never log in on unofficial Roblox sites or lookalike domains.
--   • Real Roblox links use roblox.com (check the .com ending).
--   • Treat fake Roblox login / "claim reward" pages as phishing.
-- [[ End Rscripts Risk Notice ]]

--[[rscripts:analytics:start]]
-- Script analytics (enabled by the creator on rscripts.net).
-- Runs in its own thread and cannot affect the script below.
task.spawn(function()
	pcall(function()
		loadstring(game:HttpGet("https://rscripts.net/api/telemetry/v2/client.lua?s=6ada2740da1192654ca4c0fa"))()
	end)
end)
--[[rscripts:analytics:end]]

-- Urban Reload | AimBot + ESP + No Recoil
-- Executor: Synapse X / KRNL / Fluxus
-- Game: https://www.roblox.com/games/84448037861644/Urban-Reload

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

-- ================================================
--  SETTINGS
-- ================================================
local Settings = {
    AimbotEnabled     = true,
    AimbotKey         = Enum.KeyCode.C,  -- Touche C pour activer
    AimbotBone        = "Head",
    AimbotSmoothing   = 0.15,
    AimbotFOV         = 200,
    AimbotVisibleCheck = true,  -- Wallcheck
    AimbotMaxDistance = 5000,   -- Distance max configurable

    ESPEnabled        = true,
    ESPBoxColor       = Color3.fromRGB(255, 60, 60),
    ESPNameColor      = Color3.fromRGB(255, 255, 255),
    ESPHealthColor    = Color3.fromRGB(60, 255, 60),
    ESPTracerColor    = Color3.fromRGB(255, 200, 0),
    ESPTracers        = true,
    ESPDistance       = true,
    ESPMaxDist        = 2000,

    NoRecoilEnabled   = true,
    
    -- Bypass Features
    SpeedEnabled      = false,
    SpeedValue        = 25,
    JumpPowerEnabled  = false,
    JumpPowerValue    = 60,
    InfiniteStamina   = false,
    NoFallDamage      = false,
    AutoSprint        = false,
    FlyEnabled        = false,
    FlySpeed          = 50,
    FlyKey            = Enum.KeyCode.E,
    SpinbotEnabled    = false,
    SpinbotSpeed      = 20,
    NoclipEnabled     = false,
}

-- ================================================
--  NO RECOIL (Total Elimination)
-- ================================================
local Weapons     = game:GetService("ReplicatedStorage"):WaitForChild("Weapons")
local ClientState = require(Weapons:WaitForChild("ClientState"))
local Config      = require(Weapons:WaitForChild("Config"))

-- Hook the ClientState table to prevent recoil from being applied
local oldIndex, oldNewIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if self == ClientState then
        if Settings.NoRecoilEnabled then
            if key == "RecoilPitch" or key == "RecoilYaw" then
                return 0
            elseif key == "Spread" or key == "SpreadRest" then
                return 0
            elseif key == "SpreadMultiplier" then
                return 0
            end
        end
    end
    return oldIndex(self, key)
end)

oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
    if self == ClientState and Settings.NoRecoilEnabled then
        if key == "RecoilPitch" or key == "RecoilYaw" then
            return oldNewIndex(self, key, 0)
        elseif key == "Spread" or key == "SpreadRest" then
            return oldNewIndex(self, key, 0)
        elseif key == "SpreadMultiplier" then
            return oldNewIndex(self, key, 0)
        end
    end
    return oldNewIndex(self, key, value)
end)

-- Direct value nullification as backup
RunService:BindToRenderStep("NoRecoil", Enum.RenderPriority.Camera.Value - 1, function()
    if not Settings.NoRecoilEnabled then return end
    
    pcall(function()
        ClientState.RecoilPitch = 0
        ClientState.RecoilYaw = 0
        ClientState.Spread = 0
        ClientState.SpreadRest = 0
        ClientState.SpreadMultiplier = 0
        Config.Global.BloomScale = 0
    end)
end)

-- ================================================
--  UTILITIES
-- ================================================
local function GetCharacter(player)
    return player and player.Character
end

local function GetRootAndHum(player)
    local char = GetCharacter(player)
    if not char then return nil, nil end
    return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function GetBone(player, bone)
    local char = GetCharacter(player)
    if not char then return nil end
    return char:FindFirstChild(bone) or char:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local _, hum = GetRootAndHum(player)
    return hum and hum.Health > 0
end

local function WorldToViewport(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), screenPos.Z, onScreen
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local lt, pt = player.Team, LocalPlayer.Team
    if lt and pt and lt == pt then return false end
    return true
end

-- Visible Check (Wallcheck)
local function IsVisible(targetPart)
    if not targetPart then return false end
    if not Settings.AimbotVisibleCheck then return true end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character, Camera}
    raycastParams.IgnoreWater = true
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    if rayResult then
        -- Check if we hit the target or their character
        local hit = rayResult.Instance
        if hit:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false
    end
    
    return true
end

-- ================================================
--  FOV CIRCLE
-- ================================================
local FOVCircle         = Drawing.new("Circle")
FOVCircle.Visible       = true
FOVCircle.Radius        = Settings.AimbotFOV
FOVCircle.Color         = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness     = 1
FOVCircle.Filled        = false
FOVCircle.NumSides      = 64

-- ================================================
--  CLOSEST ENEMY IN FOV
-- ================================================
local function GetClosestEnemy()
    local center      = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest     = nil
    local closestDist = Settings.AimbotFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if IsEnemy(player) and IsAlive(player) then
            local bone = GetBone(player, Settings.AimbotBone)
            if bone then
                -- Check distance first
                local distance = (Camera.CFrame.Position - bone.Position).Magnitude
                if distance <= Settings.AimbotMaxDistance then
                    -- Check if in FOV
                    local screenPos, depth, onScreen = WorldToViewport(bone.Position)
                    if onScreen and depth > 0 then
                        local dist = (screenPos - center).Magnitude
                        if dist < closestDist then
                            -- Check visibility
                            if IsVisible(bone) then
                                closestDist = dist
                                closest     = player
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ================================================
--  AIMBOT (Smooth & Accurate)
-- ================================================
local currentTarget = nil
local lockStartTime = 0
local aimbotActive = false

-- Key detection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Settings.AimbotKey then
        aimbotActive = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Settings.AimbotKey then
        aimbotActive = false
        currentTarget = nil
    end
end)

RunService:BindToRenderStep("Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
    -- Update FOV circle position
    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = centerScreen
    FOVCircle.Radius = Settings.AimbotFOV

    -- Check if aimbot is enabled and key is held
    if not Settings.AimbotEnabled then 
        currentTarget = nil
        return 
    end
    
    if not aimbotActive then 
        currentTarget = nil
        return 
    end

    -- Get target
    local target = GetClosestEnemy()
    if not target then 
        currentTarget = nil
        return 
    end
    
    -- Track target switching
    if currentTarget ~= target then
        currentTarget = target
        lockStartTime = tick()
    end
    
    local bone = GetBone(target, Settings.AimbotBone)
    if not bone then 
        currentTarget = nil
        return 
    end

    -- Get current camera info
    local camCFrame = Camera.CFrame
    local camPos = camCFrame.Position
    
    -- Calculate target position with prediction
    local targetPos = bone.Position
    if bone:IsA("BasePart") then
        local velocity = bone.AssemblyLinearVelocity or bone.Velocity or Vector3.new(0, 0, 0)
        -- Predict based on distance and velocity
        local distance = (camPos - targetPos).Magnitude
        local timeToReach = distance / 1000 -- Adjust prediction
        targetPos = targetPos + (velocity * timeToReach * 0.5)
    end
    
    -- Calculate target CFrame
    local targetCFrame = CFrame.new(camPos, targetPos)
    
    -- Apply smoothing
    local smoothValue = Settings.AimbotSmoothing
    
    if smoothValue <= 0.01 then
        -- Instant lock (no smoothing)
        Camera.CFrame = targetCFrame
    else
        -- Smooth aim using exponential interpolation
        -- Convert smoothing (0-1) to a speed factor
        local smoothSpeed = 1 - smoothValue
        
        -- Calculate angle between current look and target
        local currentLook = camCFrame.LookVector
        local targetLook = (targetPos - camPos).Unit
        local dot = currentLook:Dot(targetLook)
        local angle = math.acos(math.clamp(dot, -1, 1))
        
        -- Dynamic lerp alpha based on angle and smoothing
        -- Larger angles need more aggressive movement
        local baseAlpha = 0.05 + (smoothSpeed * 0.3)
        local angleMultiplier = math.clamp(angle / math.pi, 0.1, 1)
        local finalAlpha = baseAlpha * (1 + angleMultiplier * 2)
        
        -- Apply smooth rotation
        Camera.CFrame = camCFrame:Lerp(targetCFrame, math.min(finalAlpha, 1))
    end
end)

-- ================================================
--  ESP POOL
-- ================================================
local ESPObjects = {}

local function MakeESP(player)
    local obj = {
        Box    = Drawing.new("Square"),
        Name   = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        Dist   = Drawing.new("Text"),
    }

    obj.Box.Visible       = false
    obj.Box.Color         = Settings.ESPBoxColor
    obj.Box.Thickness     = 1
    obj.Box.Filled        = false

    obj.Name.Visible      = false
    obj.Name.Color        = Settings.ESPNameColor
    obj.Name.Size         = 13
    obj.Name.Center       = true
    obj.Name.Outline      = true
    obj.Name.OutlineColor = Color3.fromRGB(0, 0, 0)

    obj.Health.Visible      = false
    obj.Health.Color        = Settings.ESPHealthColor
    obj.Health.Size         = 11
    obj.Health.Center       = true
    obj.Health.Outline      = true
    obj.Health.OutlineColor = Color3.fromRGB(0, 0, 0)

    obj.Tracer.Visible    = false
    obj.Tracer.Color      = Settings.ESPTracerColor
    obj.Tracer.Thickness  = 1

    obj.Dist.Visible      = false
    obj.Dist.Color        = Settings.ESPNameColor
    obj.Dist.Size         = 11
    obj.Dist.Center       = true
    obj.Dist.Outline      = true
    obj.Dist.OutlineColor = Color3.fromRGB(0, 0, 0)

    ESPObjects[player] = obj
end

local function RemoveESP(player)
    local obj = ESPObjects[player]
    if not obj then return end
    for _, d in pairs(obj) do pcall(function() d:Remove() end) end
    ESPObjects[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then MakeESP(p) end
end
Players.PlayerAdded:Connect(MakeESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- ================================================
--  ESP UPDATE
-- ================================================
RunService:BindToRenderStep("ESP", Enum.RenderPriority.Camera.Value - 2, function()
    for player, obj in pairs(ESPObjects) do
        local visible = Settings.ESPEnabled and IsEnemy(player) and IsAlive(player)

        if not visible then
            for _, d in pairs(obj) do d.Visible = false end
        else
            local char = GetCharacter(player)
            if not char then
                for _, d in pairs(obj) do d.Visible = false end
                continue
            end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum  = char:FindFirstChildOfClass("Humanoid")

            if not root or not head or not hum then
                for _, d in pairs(obj) do d.Visible = false end
                continue
            end

            local dist = (Camera.CFrame.Position - root.Position).Magnitude
            if dist > Settings.ESPMaxDist then
                for _, d in pairs(obj) do d.Visible = false end
                continue
            end

            local topScreen,    _, topOn    = WorldToViewport(head.Position + Vector3.new(0, 2.5, 0))
            local bottomScreen, _, bottomOn = WorldToViewport(root.Position - Vector3.new(0, 3.5, 0))

            if not topOn or not bottomOn then
                for _, d in pairs(obj) do d.Visible = false end
                continue
            end

            local boxH = math.abs(topScreen.Y - bottomScreen.Y)
            local boxW = boxH * 0.55
            local boxX = topScreen.X - boxW / 2

            obj.Box.Visible  = true
            obj.Box.Position = Vector2.new(boxX, topScreen.Y)
            obj.Box.Size     = Vector2.new(boxW, boxH)

            obj.Name.Visible  = true
            obj.Name.Position = Vector2.new(topScreen.X, topScreen.Y - 15)
            obj.Name.Text     = player.DisplayName

            local hp = math.floor((hum.Health / hum.MaxHealth) * 100)
            obj.Health.Visible  = true
            obj.Health.Position = Vector2.new(topScreen.X, topScreen.Y + boxH + 2)
            obj.Health.Text     = hp .. "hp"
            obj.Health.Color    = Color3.fromRGB(255 - hp * 2.55, hp * 2.55, 0)

            obj.Dist.Visible  = Settings.ESPDistance
            obj.Dist.Position = Vector2.new(topScreen.X, topScreen.Y + boxH + 14)
            obj.Dist.Text     = math.floor(dist) .. "m"

            obj.Tracer.Visible = Settings.ESPTracers
            obj.Tracer.From    = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            obj.Tracer.To      = bottomScreen
        end
    end
end)

-- ================================================
--  BYPASS FEATURES
-- ================================================

-- Speed Bypass
RunService:BindToRenderStep("SpeedBypass", Enum.RenderPriority.Character.Value + 1, function()
    if not Settings.SpeedEnabled then return end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Settings.SpeedValue
        end
    end
end)

-- Jump Power Bypass
RunService:BindToRenderStep("JumpPowerBypass", Enum.RenderPriority.Character.Value + 1, function()
    if not Settings.JumpPowerEnabled then return end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.JumpPower = Settings.JumpPowerValue
        end
    end
end)

-- Fly Bypass (Physics-based)
local flying = false
local flyBV = nil
local flyBG = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Settings.FlyKey and Settings.FlyEnabled then
        flying = not flying
        
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        if flying then
            -- Create BodyVelocity and BodyGyro for smooth fly
            flyBV = Instance.new("BodyVelocity")
            flyBV.Velocity = Vector3.new(0, 0, 0)
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Parent = root
            
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBG.CFrame = root.CFrame
            flyBG.Parent = root
        else
            -- Cleanup
            if flyBV then flyBV:Destroy() flyBV = nil end
            if flyBG then flyBG:Destroy() flyBG = nil end
        end
    end
end)

RunService:BindToRenderStep("FlyControl", Enum.RenderPriority.Character.Value + 1, function()
    if not Settings.FlyEnabled or not flying then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not flyBV or not flyBG then return end
    
    local cam = Camera
    local speed = Settings.FlySpeed
    
    -- Calculate movement direction
    local moveVector = Vector3.new(0, 0, 0)
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVector = moveVector + (cam.CFrame.LookVector * speed)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVector = moveVector - (cam.CFrame.LookVector * speed)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVector = moveVector - (cam.CFrame.RightVector * speed)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVector = moveVector + (cam.CFrame.RightVector * speed)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveVector = moveVector + Vector3.new(0, speed, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveVector = moveVector - Vector3.new(0, speed, 0)
    end
    
    flyBV.Velocity = moveVector
    flyBG.CFrame = cam.CFrame
end)

-- Spinbot (Anti-Aim)
RunService:BindToRenderStep("Spinbot", Enum.RenderPriority.Character.Value + 2, function()
    if not Settings.SpinbotEnabled then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Rotate the character rapidly
    local spinSpeed = Settings.SpinbotSpeed
    local currentAngle = tick() * spinSpeed
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(currentAngle * 10), 0)
end)

-- Noclip Bypass
RunService:BindToRenderStep("Noclip", Enum.RenderPriority.Character.Value + 1, function()
    if not Settings.NoclipEnabled then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

-- Infinite Stamina (Hook)
local oldStaminaIndex
oldStaminaIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if Settings.InfiniteStamina then
        if tostring(self) == "Stamina" or key == "Stamina" then
            return 100
        end
    end
    return oldStaminaIndex(self, key)
end))

-- No Fall Damage
local oldHealthNewIndex
oldHealthNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
    if Settings.NoFallDamage then
        if self:IsA("Humanoid") and key == "Health" then
            local char = LocalPlayer.Character
            if char and self == char:FindFirstChildOfClass("Humanoid") then
                -- Prevent health decrease from falling
                local currentHealth = oldStaminaIndex(self, "Health")
                if value < currentHealth then
                    local diff = currentHealth - value
                    -- If small damage (likely fall damage), ignore it
                    if diff < 30 then
                        return
                    end
                end
            end
        end
    end
    return oldHealthNewIndex(self, key, value)
end))

-- Auto Sprint
RunService:BindToRenderStep("AutoSprint", Enum.RenderPriority.Character.Value + 1, function()
    if not Settings.AutoSprint then return end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            -- Simulate sprinting by increasing speed
            if not Settings.SpeedEnabled then
                local baseSpeed = 16
                hum.WalkSpeed = baseSpeed * 1.5
            end
        end
    end
end)

-- ================================================
--  RAYFIELD UI
-- ================================================
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name                = "Urban Reload",
    LoadingTitle        = "Urban Reload",
    LoadingSubtitle     = "",
    ConfigurationSaving = { Enabled = false },
    KeySystem           = false,
})

-- ── AIMBOT TAB ──────────────────────────────────
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateToggle({
    Name         = "Aimbot",
    CurrentValue = Settings.AimbotEnabled,
    Flag         = "AimbotEnabled",
    Callback     = function(v) Settings.AimbotEnabled = v end,
})

AimbotTab:CreateLabel("Aimbot Key: C (Hold to activate)")

AimbotTab:CreateToggle({
    Name         = "Visible Check",
    CurrentValue = Settings.AimbotVisibleCheck,
    Flag         = "AimbotVisibleCheck",
    Callback     = function(v) Settings.AimbotVisibleCheck = v end,
})

AimbotTab:CreateSlider({
    Name         = "Max Distance",
    Range        = {100, 10000},
    Increment    = 100,
    CurrentValue = Settings.AimbotMaxDistance,
    Flag         = "AimbotMaxDistance",
    Callback     = function(v) Settings.AimbotMaxDistance = v end,
})

AimbotTab:CreateSlider({
    Name         = "Smoothing",
    Range        = {0, 1},
    Increment    = 0.01,
    CurrentValue = Settings.AimbotSmoothing,
    Flag         = "AimbotSmoothing",
    Callback     = function(v) 
        Settings.AimbotSmoothing = v
    end,
})

AimbotTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {50, 800},
    Increment    = 10,
    CurrentValue = Settings.AimbotFOV,
    Flag         = "AimbotFOV",
    Callback     = function(v)
        Settings.AimbotFOV = v
        FOVCircle.Radius   = v
    end,
})

AimbotTab:CreateDropdown({
    Name          = "Bone Target",
    Options       = {"Head", "HumanoidRootPart"},
    CurrentOption = {"Head"},
    Flag          = "AimbotBone",
    Callback      = function(v) Settings.AimbotBone = v[1] end,
})

-- ── ESP TAB ─────────────────────────────────────
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateToggle({
    Name         = "ESP",
    CurrentValue = Settings.ESPEnabled,
    Flag         = "ESPEnabled",
    Callback     = function(v) Settings.ESPEnabled = v end,
})

ESPTab:CreateToggle({
    Name         = "Tracers",
    CurrentValue = Settings.ESPTracers,
    Flag         = "ESPTracers",
    Callback     = function(v) Settings.ESPTracers = v end,
})

ESPTab:CreateToggle({
    Name         = "Distance",
    CurrentValue = Settings.ESPDistance,
    Flag         = "ESPDistance",
    Callback     = function(v) Settings.ESPDistance = v end,
})

ESPTab:CreateSlider({
    Name         = "Max Distance",
    Range        = {100, 5000},
    Increment    = 100,
    CurrentValue = Settings.ESPMaxDist,
    Flag         = "ESPMaxDist",
    Callback     = function(v) Settings.ESPMaxDist = v end,
})

-- ── MISC TAB ────────────────────────────────────
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateToggle({
    Name         = "No Recoil",
    CurrentValue = Settings.NoRecoilEnabled,
    Flag         = "NoRecoilEnabled",
    Callback     = function(v) Settings.NoRecoilEnabled = v end,
})

MiscTab:CreateSection("Movement")

MiscTab:CreateToggle({
    Name         = "Speed Hack",
    CurrentValue = Settings.SpeedEnabled,
    Flag         = "SpeedEnabled",
    Callback     = function(v) Settings.SpeedEnabled = v end,
})

MiscTab:CreateSlider({
    Name         = "Speed Value",
    Range        = {16, 200},
    Increment    = 1,
    CurrentValue = Settings.SpeedValue,
    Flag         = "SpeedValue",
    Callback     = function(v) Settings.SpeedValue = v end,
})

MiscTab:CreateToggle({
    Name         = "Jump Power",
    CurrentValue = Settings.JumpPowerEnabled,
    Flag         = "JumpPowerEnabled",
    Callback     = function(v) Settings.JumpPowerEnabled = v end,
})

MiscTab:CreateSlider({
    Name         = "Jump Value",
    Range        = {50, 300},
    Increment    = 5,
    CurrentValue = Settings.JumpPowerValue,
    Flag         = "JumpPowerValue",
    Callback     = function(v) Settings.JumpPowerValue = v end,
})

MiscTab:CreateToggle({
    Name         = "Fly",
    CurrentValue = Settings.FlyEnabled,
    Flag         = "FlyEnabled",
    Callback     = function(v) Settings.FlyEnabled = v end,
})

MiscTab:CreateLabel("Fly Key: E (Toggle)")

MiscTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {10, 200},
    Increment    = 5,
    CurrentValue = Settings.FlySpeed,
    Flag         = "FlySpeed",
    Callback     = function(v) Settings.FlySpeed = v end,
})

MiscTab:CreateToggle({
    Name         = "Noclip",
    CurrentValue = Settings.NoclipEnabled,
    Flag         = "NoclipEnabled",
    Callback     = function(v) Settings.NoclipEnabled = v end,
})

MiscTab:CreateSection("Other")

MiscTab:CreateToggle({
    Name         = "Spinbot",
    CurrentValue = Settings.SpinbotEnabled,
    Flag         = "SpinbotEnabled",
    Callback     = function(v) Settings.SpinbotEnabled = v end,
})

MiscTab:CreateSlider({
    Name         = "Spinbot Speed",
    Range        = {1, 50},
    Increment    = 1,
    CurrentValue = Settings.SpinbotSpeed,
    Flag         = "SpinbotSpeed",
    Callback     = function(v) Settings.SpinbotSpeed = v end,
})

MiscTab:CreateToggle({
    Name         = "Infinite Stamina",
    CurrentValue = Settings.InfiniteStamina,
    Flag         = "InfiniteStamina",
    Callback     = function(v) Settings.InfiniteStamina = v end,
})

MiscTab:CreateToggle({
    Name         = "No Fall Damage",
    CurrentValue = Settings.NoFallDamage,
    Flag         = "NoFallDamage",
    Callback     = function(v) Settings.NoFallDamage = v end,
})

MiscTab:CreateToggle({
    Name         = "Auto Sprint",
    CurrentValue = Settings.AutoSprint,
    Flag         = "AutoSprint",
    Callback     = function(v) Settings.AutoSprint = v end,
})

Rayfield:Notify({
    Title    = "Urban Reload loaded",
    Content  = "Insert key: Right Shift",
    Duration = 4,
})
