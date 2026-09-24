local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

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
-- PATHFINDING
--------------------------------------------------

local function walkTo(target)
    local targetPart =
        target:IsA("BasePart")
        and target
        or target:FindFirstChildWhichIsA("BasePart", true)

    if not targetPart then
        return false
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    })

    path:ComputeAsync(root().Position, targetPart.Position)

    if path.Status ~= Enum.PathStatus.Success then
        return false
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid().Jump = true
        end

        humanoid():MoveTo(waypoint.Position)

        if not humanoid().MoveToFinished:Wait() then
            return false
        end
    end

    return true
end

--------------------------------------------------
-- RESOURCE SCANNER
--------------------------------------------------

local function nearestResource()
    local closest
    local closestDistance = Settings.ResourceRadius

    for _, resource in ipairs(
        CollectionService:GetTagged("Resource")
    ) do

        if resource:IsDescendantOf(workspace) then

            local part =
                resource:IsA("BasePart")
                and resource
                or resource:FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )

            if part then
                local distance =
                    (root().Position - part.Position).Magnitude

                if distance < closestDistance then
                    closestDistance = distance
                    closest = resource
                end
            end
        end
    end

    return closest
end

--------------------------------------------------
-- AUTO COLLECT
--------------------------------------------------

local function collect(resource)

    if not resource then
        return
    end

    if walkTo(resource) then

        local remote =
            game.ReplicatedStorage.Remotes
                :FindFirstChild("CollectResource")

        if remote then
            remote:FireServer(resource)
        end
    end
end

--------------------------------------------------
-- AUTO NPC
--------------------------------------------------

local function nearestNPC()

    local folder = workspace:FindFirstChild("NPCs")

    if not folder then
        return nil
    end

    local closest
    local distance = math.huge

    for _, npc in ipairs(folder:GetChildren()) do

        local part =
            npc:FindFirstChild("HumanoidRootPart")
            or npc:FindFirstChildWhichIsA(
                "BasePart",
                true
            )

        if part then

            local d =
                (root().Position - part.Position).Magnitude

            if d < distance then
                distance = d
                closest = npc
            end
        end
    end

    return closest
end

--------------------------------------------------
-- AUTO DELIVER
--------------------------------------------------

local function deliver()

    local npc = nearestNPC()

    if not npc then
        return
    end

    if walkTo(npc) then

        local remote =
            game.ReplicatedStorage.Remotes
                :FindFirstChild("DeliverItem")

        if remote then
            remote:FireServer(npc)
        end
    end
end

--------------------------------------------------
-- AUTO QUEST
--------------------------------------------------

local function doQuest()

    local quests =
        workspace:FindFirstChild("QuestPoints")

    if not quests then
        return
    end

    for _, point in ipairs(quests:GetChildren()) do

        if walkTo(point) then

            local remote =
                game.ReplicatedStorage.Remotes
                    :FindFirstChild("QuestAction")

            if remote then
                remote:FireServer(point)
            end

            break
        end
    end
end

--------------------------------------------------
-- GOD MODE
--------------------------------------------------

local function godMode()

    if not Settings.GodMode then
        return
    end

    local hum = humanoid()

    hum.MaxHealth = math.huge
    hum.Health = math.huge
end

--------------------------------------------------
-- AURA
--------------------------------------------------

local function aura()

    if not Settings.Aura then
        return
    end

    local myCharacter = character()

    for _, model in ipairs(workspace:GetChildren()) do

        if model ~= myCharacter then

            local hum =
                model:FindFirstChildOfClass("Humanoid")

            local targetRoot =
                model:FindFirstChild("HumanoidRootPart")

            if hum and targetRoot and hum.Health > 0 then

                local distance =
                    (root().Position -
                    targetRoot.Position).Magnitude

                if distance <= Settings.AuraRadius then

                    -- เกมของเราเองควรให้ Server
                    -- ตรวจสอบและทำ Damage

                    local remote =
                        game.ReplicatedStorage.Remotes
                            :FindFirstChild("AuraAttack")

                    if remote then
                        remote:FireServer(
                            model,
                            Settings.AuraDamage
                        )
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

task.spawn(function()

    while task.wait(0.25) do

        godMode()
        aura()

        if Settings.AutoCollect then
            collect(nearestResource())
        end

        if Settings.AutoNPC then
            local npc = nearestNPC()

            if npc then
                walkTo(npc)
            end
        end

        if Settings.AutoDeliver then
            deliver()
        end

        if Settings.AutoQuest then
            doQuest()
        end
    end

end)
