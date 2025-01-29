local Library = loadstring(game:HttpGetAsync("https://github.com/Vallmerka/Fling-Mode/releases/download/lib/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()
 
local Window = Library:CreateWindow{
    Title = `FlingMode {Library.Version}`,
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(830, 525),
    Resize = true, -- Resize this ^ Size according to a 1920x1080 screen, good for mobile users but may look weird on some devices
    MinSize = Vector2.new(470, 380),
    Acrylic = true, -- The blur may be detectable, setting this to false disables blur entirely
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl -- Used when theres no MinimizeKeybind
}

-- Fluent Renewed provides ALL 1544 Lucide 0.469.0 https://lucide.dev/icons/ Icons and ALL 9072 Phosphor 2.1.0 https://phosphoricons.com/ Icons for the tabs, icons are optional
local Tabs = {
    Combat = Window:CreateTab{
        Title = "Combat",
        Icon = "crosshair"
    },
    Settings = Window:CreateTab{
        Title = "Settings",
        Icon = "settings"
    }
}

local Options = Library.Options

Tabs.Combat:CreateParagraph("Aligned Paragraph", {
    Title = "Paragraph",
    Content = "This is a paragraph with a center alignment!",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Center
})

local masterToggle = false

local function enableMasterToggle(value)
    masterToggle = value
end

Tabs.Combat:AddToggle("Master Toggle", {
    Text = "Enable/Disable",
    Default = false,
    Tooltip = "Enable or disable all features globally.",
    Callback = enableMasterToggle
})

local hookEnabled = false
local oldNamecall

local function enableBulletHitManipulation(value)
    if not masterToggle then return end
    BManipulation = value
    local remote = game:GetService("ReplicatedStorage").BulletFireSystem.BulletHit

    if BManipulation then
        if not hookEnabled then
            hookEnabled = true
            oldNamecall = hookmetamethod(remote, "__namecall", newcclosure(function(self, ...)
                if typeof(self) == "Instance" then
                    local method = getnamecallmethod()
                    if method and (method == "FireServer" and self == remote) then
                        local HitPart = getClosestPlayer()
                        if HitPart then
                            local remArgs = {...}
                            remArgs[2] = HitPart
                            remArgs[3] = HitPart.Position
                            setnamecallmethod(method)
                            return oldNamecall(self, unpack(remArgs))
                        else
                            setnamecallmethod(method)
                        end
                    end
                end
                return oldNamecall(self, ...)
            end))
        end
    else
        BsManipulation = false
        if hookEnabled then
            hookEnabled = false
            if oldNamecall then
                hookmetamethod(remote, "__namecall", oldNamecall)
            end
        end
    end
end

Tabs.Combat:AddToggle("BulletHit manipulation", {
    Text = "Magic Bullet [beta]",
    Default = false,
    Tooltip = "Magic Bullet?",
    Callback = function(value)
        enableBulletHitManipulation(value)
    end
})

local hookEnabled = false
local oldNamecall

local function enableRocketHitManipulation(value)
    if not masterToggle then return end
    RManipulation = value
    local remote = game:GetService("ReplicatedStorage").RocketSystem.Events.RocketHit

    if RManipulation and not hookEnabled then
        hookEnabled = true
        oldNamecall = hookmetamethod(remote, "__namecall", newcclosure(function(self, ...)
            if typeof(self) == "Instance" and getnamecallmethod() == "FireServer" and self == remote then
                local remArgs = {...}
                local targetPart = getClosestPlayer()
                if targetPart then
                    remArgs[1] = targetPart.Position
                    remArgs[2] = (targetPart.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).unit
                    remArgs[5] = targetPart
                    setnamecallmethod("FireServer")
                    return oldNamecall(self, unpack(remArgs))
                end
            end
            return oldNamecall(self, ...)
        end))
    elseif not RManipulation and hookEnabled then
        hookEnabled = false
        if oldNamecall then hookmetamethod(remote, "__namecall", oldNamecall) end
    end
end

Tabs.Combat:AddToggle("RocketHit manipulation", {
    Text = "Magic Rocket",
    Default = false,
    Tooltip = "Enables Magic Rocket manipulation",
    Callback = enableRocketHitManipulation
})

local function modifyWeaponSettings(property, value)
    local function findSettingsModule(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, module = pcall(function() return require(child) end)
                if success and module[property] ~= nil then
                    return module
                end
            end
            local found = findSettingsModule(child)
            if found then
                return found
            end
        end
        return nil
    end

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
    local foundModules = {}

    if getgenv().WeaponOnHands then
        local toolInHand = character:FindFirstChildOfClass("Tool")
        if toolInHand then
            local settingsModule = findSettingsModule(toolInHand)
            if settingsModule then
                table.insert(foundModules, settingsModule)
            end
        end
    else
        for _, item in pairs(backpack:GetChildren()) do
            local settingsModule = findSettingsModule(item)
            if settingsModule then
                table.insert(foundModules, settingsModule)
            end
        end
    end

    if #foundModules > 0 then
        for _, module in pairs(foundModules) do
            module[property] = value
        end
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local isRPGSpamEnabled = false
local spamSpeed = 1
local rocketsToFire = 1

local RocketSystem, FireRocket, FireRocketClient, ACS_Client

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

local function startRPGSpam()
    if not masterToggle then return end
    if not isRPGSpamEnabled then 
        return 
    end

    if not RocketSystem then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        RocketSystem = ReplicatedStorage:WaitForChild("RocketSystem")
        FireRocket = RocketSystem:WaitForChild("Events"):WaitForChild("FireRocket")
        FireRocketClient = RocketSystem:WaitForChild("Events"):WaitForChild("FireRocketClient")
    end

    for i = 1, rocketsToFire do
        if not isRPGSpamEnabled then 
            return 
        end

        local closestPlayer = getClosestPlayer()
        if not closestPlayer then 
            return 
        end

        local targetPosition = closestPlayer.Position
        local directionToTarget = (targetPosition - LocalPlayer.Character.HumanoidRootPart.Position).unit

        FireRocket:InvokeServer(directionToTarget, workspace[LocalPlayer.Name].RPG, workspace[LocalPlayer.Name].RPG, targetPosition)
        FireRocketClient:Fire(
            targetPosition,
            directionToTarget,
            {
                ["expShake"] = {["fadeInTime"] = 0.05, ["magnitude"] = 3, ["rotInfluence"] = {0.4, 0, 0.4}, ["fadeOutTime"] = 0.5, ["posInfluence"] = {1, 1, 0}, ["roughness"] = 3},
                ["gravity"] = Vector3.new(0, -20, 0),
                ["HelicopterDamage"] = 450,
                ["FireRate"] = 15,
                ["VehicleDamage"] = 350,
                ["ExpName"] = "RPG",
                ["ExpRadius"] = 12,
                ["BoatDamage"] = 300,
                ["TankDamage"] = 300,
                ["Acceleration"] = 8,
                ["ShieldDamage"] = 170,
                ["Distance"] = 4000,
                ["PlaneDamage"] = 500,
                ["GunshipDamage"] = 170,
                ["velocity"] = 200,
                ["ExplosionDamage"] = 120
            },
            RocketSystem.Rockets["RPG Rocket"],
            workspace[LocalPlayer.Name].RPG,
            workspace[LocalPlayer.Name].RPG,
            LocalPlayer
        )
    end
end

Tabs.Combat:AddToggle("RPG Spam", {
    Text = "Toggle RPG Spam",
    Default = false,
    Tooltip = "Enable or disable RPG spam.",
    Callback = function(value)
        isRPGSpamEnabled = value
    end,
}):AddKeyPicker("RPG Spam Key", {
    Default = "Q",
    SyncToggleState = true,
    Mode = "Toggle",  
    Text = "RPG Spam Key",
    Tooltip = "Key to toggle RPG Spam",
    Callback = function()
        if isRPGSpamEnabled then
            startRPGSpam()
        end
    end,
})

Tabs.Combat:AddSlider("Rocket Count", {
    Text = "Rockets per Spam",
    Default = 1,
    Min = 1,
    Max = 500000,
    Rounding = 0,
    Tooltip = "Adjust how many rockets to fire at once.",
    Callback = function(value)
        rocketsToFire = math.floor(value)
    end,
})

Tabs.Combat:AddSlider("Spam Speed", {
    Text = "RPG Spam Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Tooltip = "Adjust the speed of RPG spam.",
    Callback = function(value)
        spamSpeed = value
    end,
})

game:GetService("RunService").Heartbeat:Connect(function()
    if isRPGSpamEnabled then
        wait(1 / spamSpeed)
        startRPGSpam()
    end
end)

local isQuickLagRPGExecuting = false

local function startQuickLagRPG()
    if not masterToggle then return end
    local camera, playerName = workspace.Camera, game:GetService("Players").LocalPlayer.Name
    local repeatCount = 500

    local function fireQuickLagRocket()
        local fireRocketVector = camera.CFrame.LookVector
        local fireRocketPosition = camera.CFrame.Position
        game:GetService("ReplicatedStorage").RocketSystem.Events.FireRocket:InvokeServer(
            fireRocketVector, workspace[playerName].RPG, workspace[playerName].RPG, fireRocketPosition
        )

        local fireRocketClientTable = {
            ["expShake"] = {["fadeInTime"] = 0.05, ["magnitude"] = 3, ["rotInfluence"] = {0.4, 0, 0.4}, ["fadeOutTime"] = 0.5, ["posInfluence"] = {1, 1, 0}, ["roughness"] = 3},
            ["gravity"] = Vector3.new(0, -20, 0), ["HelicopterDamage"] = 450, ["FireRate"] = 15, ["VehicleDamage"] = 350, ["ExpName"] = "RPG",
            ["RocketAmount"] = 1, ["ExpRadius"] = 12, ["BoatDamage"] = 300, ["TankDamage"] = 300, ["Acceleration"] = 8, ["ShieldDamage"] = 11170,
            ["Distance"] = 4000, ["PlaneDamage"] = 500, ["GunshipDamage"] = 170, ["velocity"] = 200, ["ExplosionDamage"] = 120
        }

        local fireRocketClientInstance1 = game:GetService("ReplicatedStorage").RocketSystem.Rockets["RPG Rocket"]
        local fireRocketClientInstance2 = workspace[playerName].RPG
        local fireRocketClientInstance3 = workspace[playerName].RPG
        game:GetService("ReplicatedStorage").RocketSystem.Events.FireRocketClient:Fire(
            camera.CFrame.Position, camera.CFrame.LookVector, fireRocketClientTable, fireRocketClientInstance1, fireRocketClientInstance2, fireRocketClientInstance3,
            game:GetService("Players").LocalPlayer, nil, { [1] = camera:FindFirstChild("RPG") }
        )
    end

    for i = 1, repeatCount do
        task.spawn(fireQuickLagRocket)
    end
end

Tabs.Combat:AddToggle("Quick Lag RPG", {
    Text = "Quick Lag RPG",
    Default = false,
    Tooltip = "Enable or disable Quick Lag RPG.",
    Callback = function(value)
        if value then
            if not isQuickLagRPGExecuting then
                isQuickLagRPGExecuting = true
                startQuickLagRPG()
            end
        else
            isQuickLagRPGExecuting = false
        end
    end,
}):AddKeyPicker("Quick Lag RPG Key", {
    Default = "I",
    Mode = "Toggle",
    Text = "Quick Lag RPG Key",
    Tooltip = "Key to toggle Quick Lag RPG",
    Callback = function()
        if not isQuickLagRPGExecuting then
            isQuickLagRPGExecuting = true
            startQuickLagRPG()
        else
            isQuickLagRPGExecuting = false
        end
    end,
})

-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- InterfaceManager (Allows you to have a interface managment system)

-- Hand the library over to our managers
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes{}

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("FlingMode")
SaveManager:SetFolder("FlingMode/main")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)


Window:SelectTab(1)

Library:Notify{
    Title = "♥",
    Content = "Было разработано Fling Dev.",
    Duration = 8
}

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()