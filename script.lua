local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local Settings = {
    AutoCollect = false,
    AutoNPC = false,
    AutoDeliver = false,
    AutoQuest = false,
    GodMode = false,
    Aura = false,

    ResourceRadius = 100,
    AuraRadius = 15,
    AuraDamage = 25
}

local function character()
    return player.Character or player.CharacterAdded:Wait()
end

local function root()
    return character():WaitForChild("HumanoidRootPart")
end

local function humanoid()
    return character():WaitForChild("Humanoid")
end

--------------------------------------------------
-- PATHFINDING & LOGIC
--------------------------------------------------

local function walkTo(target)
    local targetPart = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
    if not targetPart then return false end

    local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
    path:ComputeAsync(root().Position, targetPart.Position)

    if path.Status ~= Enum.PathStatus.Success then return false end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid().Jump = true
        end
        humanoid():MoveTo(waypoint.Position)
        if not humanoid().MoveToFinished:Wait() then return false end
    end
    return true
end

local function nearestResource()
    local closest, closestDistance = nil, Settings.ResourceRadius
    for _, resource in ipairs(CollectionService:GetTagged("Resource")) do
        if resource:IsDescendantOf(workspace) then
            local part = resource:IsA("BasePart") and resource or resource:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = (root().Position - part.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closest = resource
                end
            end
        end
    end
    return closest
end

local function collect(resource)
    if not resource then return end
    if walkTo(resource) then
        local remote = game.ReplicatedStorage.Remotes:FindFirstChild("CollectResource")
        if remote then remote:FireServer(resource) end
    end
end

local function nearestNPC()
    local folder = workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local closest, distance = nil, math.huge
    for _, npc in ipairs(folder:GetChildren()) do
        local part = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local d = (root().Position - part.Position).Magnitude
            if d < distance then
                distance = d
                closest = npc
            end
        end
    end
    return closest
end

local function deliver()
    local npc = nearestNPC()
    if not npc then return end
    if walkTo(npc) then
        local remote = game.ReplicatedStorage.Remotes:FindFirstChild("DeliverItem")
        if remote then remote:FireServer(npc) end
    end
end

local function doQuest()
    local quests = workspace:FindFirstChild("QuestPoints")
    if not quests then return end
    for _, point in ipairs(quests:GetChildren()) do
        if walkTo(point) then
            local remote = game.ReplicatedStorage.Remotes:FindFirstChild("QuestAction")
            if remote then remote:FireServer(point) end
            break
        end
    end
end

local function godMode()
    if not Settings.GodMode then return end
    local hum = humanoid()
    hum.MaxHealth = math.huge
    hum.Health = math.huge
end

local function aura()
    if not Settings.Aura then return end
    local myCharacter = character()
    for _, model in ipairs(workspace:GetChildren()) do
        if model ~= myCharacter then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local targetRoot = model:FindFirstChild("HumanoidRootPart")
            if hum and targetRoot and hum.Health > 0 then
                local distance = (root().Position - targetRoot.Position).Magnitude
                if distance <= Settings.AuraRadius then
                    local remote = game.ReplicatedStorage.Remotes:FindFirstChild("AuraAttack")
                    if remote then remote:FireServer(model, Settings.AuraDamage) end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.25) do
        godMode()
        aura()
        if Settings.AutoCollect then collect(nearestResource()) end
        if Settings.AutoNPC then
            local npc = nearestNPC()
            if npc then walkTo(npc) end
        end
        if Settings.AutoDeliver then deliver() end
        if Settings.AutoQuest then doQuest() end
    end
end)

--------------------------------------------------
-- SIMPLE BUILT-IN UI (TOGGLE MENU)
--------------------------------------------------

if CoreGui:FindFirstChild("MrBeastUI") then
    CoreGui:FindFirstChild("MrBeastUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MrBeastUI"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 320)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "MrBeast Auto Farm"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

local function createToggle(name, yPos, settingKey)
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 220, 0, 35)
    ToggleBtn.Position = UDim2.new(0.5, -110, 0, yPos)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    ToggleBtn.Text = name .. ": OFF"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    ToggleBtn.TextSize = 14
    ToggleBtn.Font = Enum.Font.SourceSansBold
    ToggleBtn.Parent = MainFrame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = ToggleBtn

    ToggleBtn.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        if Settings[settingKey] then
            ToggleBtn.Text = name .. ": ON"
            ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        else
            ToggleBtn.Text = name .. ": OFF"
            ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)
end

createToggle("Auto Collect", 50, "AutoCollect")
createToggle("Auto NPC", 90, "AutoNPC")
createToggle("Auto Deliver", 130, "AutoDeliver")
createToggle("Auto Quest", 170, "AutoQuest")
createToggle("God Mode", 210, "GodMode")
createToggle("Aura Attack", 250, "Aura")
