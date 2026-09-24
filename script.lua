local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local function getRemote(name)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        return remotes:FindFirstChild(name)
    end
    -- เผื่อบางเกมวาง Remote ไว้ที่ ReplicatedStorage ตรงๆ
    return ReplicatedStorage:FindFirstChild(name)
end

--------------------------------------------------
-- PATHFINDING
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

    local success, errorMessage = pcall(function()
        path:ComputeAsync(hrp.Position, targetPart.Position)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        -- ถ้า Pathfinding ติดขัด ให้ใช้วิธีเดินตรงแบบสำรองแทน
        hum:MoveTo(targetPart.Position)
        return true
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if not Settings.AutoCollect and not Settings.AutoNPC and not Settings.AutoDeliver and not Settings.AutoQuest then
            break
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end
        hum:MoveTo(waypoint.Position)
        
        local reached = false
        local connection
        connection = hum.MoveToFinished:Connect(function(isReached)
            reached = true
            if connection then connection:Disconnect() end
        end)

        -- รอให้เดินถึงหรือหมดเวลา
        local tickCount = 0
        while not reached and tickCount < 20 do
            task.wait(0.1)
            tickCount = tickCount + 1
        end
        if connection then connection:Disconnect() end
    end
    return true
end

--------------------------------------------------
-- AUTOMATION LOGIC
--------------------------------------------------
local function nearestResource()
    local closest, closestDistance = nil, Settings.ResourceRadius
    for _, resource in ipairs(CollectionService:GetTagged("Resource")) do
        if resource:IsDescendantOf(workspace) then
            local part = resource:IsA("BasePart") and resource or resource:FindFirstChildWhichIsA("BasePart", true)
            local hrp = root()
            if part and hrp then
                local distance = (hrp.Position - part.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closest = resource
                end
            end
        end
    end
    return closest
end

local function nearestNPC()
    local folder = workspace:FindFirstChild("NPCs")
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
-- MAIN LOOP
--------------------------------------------------
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            -- God Mode
            if Settings.GodMode then
                local hum = humanoid()
                if hum then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                end
            end

            -- Aura Attack
            if Settings.Aura then
                local myChar = character()
                local hrp = root()
                if myChar and hrp then
                    for _, model in ipairs(workspace:GetChildren()) do
                        if model ~= myChar and model:IsA("Model") then
                            local hum = model:FindFirstChildOfClass("Humanoid")
                            local targetRoot = model:FindFirstChild("HumanoidRootPart")
                            if hum and targetRoot and hum.Health > 0 then
                                if (hrp.Position - targetRoot.Position).Magnitude <= Settings.AuraRadius then
                                    local remote = getRemote("AuraAttack")
                                    if remote then
                                        remote:FireServer(model, Settings.AuraDamage)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Auto Collect
            if Settings.AutoCollect then
                local res = nearestResource()
                if res then
                    walkTo(res)
                    local remote = getRemote("CollectResource")
                    if remote then remote:FireServer(res) end
                end
            end

            -- Auto NPC
            if Settings.AutoNPC then
                local npc = nearestNPC()
                if npc then walkTo(npc) end
            end

            -- Auto Deliver
            if Settings.AutoDeliver then
                local npc = nearestNPC()
                if npc then
                    walkTo(npc)
                    local remote = getRemote("DeliverItem")
                    if remote then remote:FireServer(npc) end
                end
            end

            -- Auto Quest
            if Settings.AutoQuest then
                local quests = workspace:FindFirstChild("QuestPoints")
                if quests then
                    for _, point in ipairs(quests:GetChildren()) do
                        if walkTo(point) then
                            local remote = getRemote("QuestAction")
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
-- UI MENU
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
Title.Text = "MrBeast Auto Farm (Fixed)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
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
