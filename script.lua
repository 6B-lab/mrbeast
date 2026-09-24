local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Settings = {
    AutoCollect = false,
    AutoNPC = false,
    AutoDeliver = false,
    AutoQuest = false,
    GodMode = false,
    NoHunger = false,
    KillAllAura = false,

    ResourceRadius = 500,
    AuraDamage = 100
}

local function character()
    return player.Character or player.CharacterAdded:Wait()
end

local function root()
    local char = character()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function humanoid()
    local char = character()
    return char:WaitForChild("Humanoid", 5)
end

--------------------------------------------------
-- SAFE REMOTE FINDER
--------------------------------------------------
local function getRemote(...)
    local names = {...}
    for _, name in ipairs(names) do
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(name) then
            return remotes:FindFirstChild(name)
        end
        if ReplicatedStorage:FindFirstChild(name) then
            return ReplicatedStorage:FindFirstChild(name)
        end
    end
    return nil
end

--------------------------------------------------
-- PATHFINDING & MOVEMENT
--------------------------------------------------
local function walkTo(target)
    if not target then return false end
    local targetPart = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
    if not targetPart then return false end

    local hrp = root()
    local hum = humanoid()
    if not hrp or not hum then return false end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    })

    local success = pcall(function()
        path:ComputeAsync(hrp.Position, targetPart.Position)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPart.Position)
        return true
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end
        hum:MoveTo(waypoint.Position)
        
        local reached = false
        local conn
        conn = hum.MoveToFinished:Connect(function()
            reached = true
            if conn then conn:Disconnect() end
        end)

        local t = 0
        while not reached and t < 10 do
            task.wait(0.1)
            t = t + 1
        end
        if conn then conn:Disconnect() end
    end
    return true
end

--------------------------------------------------
-- FINDERS
--------------------------------------------------
local function nearestResource()
    local closest, closestDistance = nil, math.huge
    for _, resource in ipairs(CollectionService:GetTagged("Resource")) do
        if resource:IsDescendantOf(workspace) then
            local part = resource:IsA("BasePart") and resource or resource:FindFirstChildWhichIsA("BasePart", true)
            local hrp = root()
            if part and hrp then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < closestDistance then
                    closestDistance = dist
                    closest = resource
                end
            end
        end
    end
    return closest
end

local function nearestNPC()
    local folder = workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("Npc") or workspace:FindFirstChild("Monsters")
    if not folder then return nil end
    local closest, distance = nil, math.huge
    for _, npc in ipairs(folder:GetChildren()) do
        local part = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
        local hrp = root()
        if part and hrp then
            local d = (hrp.Position - part.Position).Magnitude
            if d < distance then
                distance = d
                closest = npc
            end
        end
    end
    return closest
end

--------------------------------------------------
-- MAIN AUTOMATION LOOP
--------------------------------------------------
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            -- 1. God Mode
            if Settings.GodMode then
                local hum = humanoid()
                if hum then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                end
            end

            -- 2. No Hunger
            if Settings.NoHunger then
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                    for _, stat in ipairs(leaderstats:GetChildren()) do
                        local name = stat.Name:lower()
                        if name:find("hunger") or name:find("thirst") or name:find("food") or name:find("stamina") or name:find("energy") then
                            stat.Value = 100
                        end
                    end
                end
            end

            -- 3. Kill All Aura
            if Settings.KillAllAura then
                local myChar = character()
                local hrp = root()
                for _, model in ipairs(workspace:GetDescendants()) do
                    if model:IsA("Model") and model ~= myChar then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        local targetRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
                        
                        if hum and targetRoot and hum.Health > 0 then
                            local isPlayer = false
                            for _, p in ipairs(Players:GetPlayers()) do
                                if p.Character == model then
                                    isPlayer = true
                                    break
                                end
                            end
                            
                            if not isPlayer then
                                if hrp and (hrp.Position - targetRoot.Position).Magnitude < 300 then
                                    local remote = getRemote("AuraAttack", "AttackRemote", "Hit", "Damage", "CombatRemote", "WeaponDamage")
                                    if remote then
                                        remote:FireServer(model, Settings.AuraDamage)
                                    else
                                        hum.Health = 0
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 4. Auto Collect
            if Settings.AutoCollect then
                local res = nearestResource()
                if res then
                    walkTo(res)
                    local remote = getRemote("CollectResource", "Collect", "Gather", "Pickup")
                    if remote then remote:FireServer(res) end
                end
            end

            -- 5. Auto NPC / Deliver / Quest
            if Settings.AutoNPC then
                local npc = nearestNPC()
                if npc then walkTo(npc) end
            end

            if Settings.AutoDeliver then
                local npc = nearestNPC()
                if npc then
                    walkTo(npc)
                    local remote = getRemote("DeliverItem", "Deliver", "TurnIn", "Sell")
                    if remote then remote:FireServer(npc) end
                end
            end

            if Settings.AutoQuest then
                local quests = workspace:FindFirstChild("QuestPoints") or workspace:FindFirstChild("Quests")
                if quests then
                    for _, point in ipairs(quests:GetChildren()) do
                        if walkTo(point) then
                            local remote = getRemote("QuestAction", "AcceptQuest", "QuestRemote", "CompleteQuest")
                            if remote then remote:FireServer(point) end
                            break
                        end
                    end
                end
            end
        end)
    end
end)

--------------------------------------------------
-- UI SETUP (ย่อหน้าต่างให้เหลือจิ๋วสุดๆ)
--------------------------------------------------
if playerGui:FindFirstChild("MrBeastModernUI") then
    playerGui:FindFirstChild("MrBeastModernUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MrBeastModernUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 370)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -185)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 45)
TopBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "MrBeast Hub V2"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, 0, 1, -45)
Container.Position = UDim2.new(0, 0, 0, 45)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.CanvasSize = UDim2.new(0, 0, 0, 310)
Container.ScrollBarThickness = 4
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = Container

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0, 7.5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -74, 0, 7.5)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 16
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- ระบบย่อหน้าต่างให้เหลือขนาดจิ๋ว (ซ่อนทุกอย่างยกเว้นปุ่มเปิดคืน)
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Container.Visible = not minimized
    Title.Visible = not minimized
    CloseBtn.Visible = not minimized
    TopBar.Size = minimized and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 0, 45)
    MainFrame.Size = minimized and UDim2.new(0, 45, 0, 25) or UDim2.new(0, 280, 0, 370)
    MinBtn.Position = minimized and UDim2.new(0, 7.5, 0, 2.5) or UDim2.new(1, -74, 0, 7.5)
    MinBtn.Size = minimized and UDim2.new(0, 30, 0, 20) or UDim2.new(0, 30, 0, 30)
    MinBtn.Text = minimized and "+" or "-"
end)

local function createToggle(name, settingKey)
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 250, 0, 38)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
    ToggleBtn.Text = "   " .. name
    ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    ToggleBtn.TextSize = 14
    ToggleBtn.Font = Enum.Font.GothamSemibold
    ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left
    ToggleBtn.Parent = Container

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 8)
    BtnCorner.Parent = ToggleBtn

    local StatusIndicator = Instance.new("Frame")
    StatusIndicator.Size = UDim2.new(0, 12, 0, 12)
    StatusIndicator.Position = UDim2.new(1, -25, 0.5, -6)
    StatusIndicator.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
    StatusIndicator.Parent = ToggleBtn

    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(1, 0)
    StatusCorner.Parent = StatusIndicator

    ToggleBtn.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        if Settings[settingKey] then
            StatusIndicator.BackgroundColor3 = Color3.fromRGB(60, 220, 90)
            ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 50)
        else
            StatusIndicator.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
            ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
        end
    end)
end

createToggle("Auto Collect", "AutoCollect")
createToggle("Auto NPC", "AutoNPC")
createToggle("Auto Deliver", "AutoDeliver")
createToggle("Auto Quest", "AutoQuest")
createToggle("God Mode", "GodMode")
createToggle("No Hunger (ไม่หิว)", "NoHunger")
createToggle("Kill All (ออร่าฆ่าหมดแมพ)", "KillAllAura")
