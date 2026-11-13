local USE_KEY_SYSTEM        = true
local PLATOBOOST_SERVICE_ID = 36784
local PLATOBOOST_SECRET     = "0f99f926-708c-4d38-afd7-e1001933ded0"

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local State = {

    Aimbot        = false,
    LockOn        = false,
    MobileButton  = false,
    AimHeld       = false,
    AimLatched    = false,
    AimToggleMode = true,
    TeamCheck     = true,
    WallCheck     = false,
    AimHead       = true,
    PriorityLowHP = false,
    FOV           = 150,
    Smooth        = 3,
    ShowFOV       = true,
    AimFromCenter = IS_MOBILE,
    WLPlayers     = {},
    WLRoles       = {},
    Spinbot       = false,
    SpinSpeed     = 20,

    ESP           = false,
    ESPName       = true,
    ESPRole       = true,
    ESPHealth     = true,
    ESPDistance   = true,
    ESPAllies     = true,
    Rainbow       = false,
    RoleFilter    = {},
    NoTeamColor   = Color3.fromRGB(255, 255, 255),
    NPCESP        = false,
    ItemESP       = false,
    XRay          = false,
    Fullbright    = false,
    NoFog         = false,
    LowGraphics   = false,

    ClickTP       = false,
    TpPlayerName  = "",
    TpCoords      = "",
    LocName       = "",

    Noclip        = false,
    Fly           = false,
    FlySpeed      = 60,
    InfJump       = false,
    TPWalk        = false,
    TPWalkSpeed   = 20,
    AntiGravity   = false,
    AntiVoid      = false,
    AntiAFK       = false,
}

local function getChar()
    return LocalPlayer.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlly(player)
    return player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

local function notify(title, content, icon)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = 3,
            Icon = icon or "info",
        })
    end)
end

local function parseList(text)
    local set = {}
    for item in string.gmatch(text or "", "[^,]+") do
        local trimmed = string.match(item, "^%s*(.-)%s*$"):lower()
        if trimmed ~= "" then
            set[trimmed] = true
        end
    end
    return set
end

local function findPlayer(name)
    name = (name or ""):lower()
    if name == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
            return p
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(name, 1, true) or p.DisplayName:lower():find(name, 1, true) then
            return p
        end
    end
    return nil
end

local function teleportTo(cf)
    local root = getRoot()
    if not root then return false end
    root.CFrame = cf
    return true
end

local fovCircle
if Drawing and Drawing.new then
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.NumSides = 64
        fovCircle.Filled = false
        fovCircle.Color = Color3.new(1, 1, 1)
        fovCircle.Visible = false
    end)
end

local function getAimOrigin()
    if State.AimFromCenter then
        return Camera.ViewportSize / 2
    end
    return UserInputService:GetMouseLocation()
end

local function isWhitelisted(player)
    if State.WLPlayers[player.Name:lower()] or State.WLPlayers[player.DisplayName:lower()] then
        return true
    end
    local team = player.Team
    if team and State.WLRoles[team.Name:lower()] then
        return true
    end
    return false
end

local function isVisible(part, targetChar)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getChar(), targetChar }
    local origin = Camera.CFrame.Position
    return workspace:Raycast(origin, part.Position - origin, params) == nil
end

local function getClosestTarget()
    local mousePos = getAimOrigin()
    local best, bestScore = nil, nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isWhitelisted(player) and not (State.TeamCheck and isAlly(player)) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local part
            if char then
                if State.AimHead then
                    part = char:FindFirstChild("Head")
                else
                    part = char:FindFirstChild("HumanoidRootPart")
                end
            end
            if hum and hum.Health > 0 and part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < State.FOV and (not State.WallCheck or isVisible(part, char)) then
                        local score = State.PriorityLowHP and hum.Health or dist
                        if bestScore == nil or score < bestScore then
                            best, bestScore = part, score
                        end
                    end
                end
            end
        end
    end
    return best
end

local function aimInputDown()
    if State.LockOn then return true end
    if State.AimLatched or State.AimHeld then return true end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

pcall(function() RunService:UnbindFromRenderStep("HubAimbot") end)
RunService:BindToRenderStep("HubAimbot", Enum.RenderPriority.Camera.Value + 1, function()
    Camera = workspace.CurrentCamera

    if fovCircle then
        fovCircle.Visible = State.Aimbot and State.ShowFOV
        fovCircle.Radius = State.FOV
        fovCircle.Position = getAimOrigin()
    end

    if not State.Aimbot then return end
    if not aimInputDown() then return end

    local target = getClosestTarget()
    if target then
        local goal = CFrame.new(Camera.CFrame.Position, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1 / State.Smooth)
    end
end)

local mobileGui, mobileBtn

local function refreshMobileButton()
    if not mobileBtn then return end
    local active = State.AimHeld or State.AimLatched
    mobileBtn.Text = active and "AIM ON" or "AIM"
    mobileBtn.BackgroundColor3 = active and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(30, 30, 30)
end

local function setMobileButton(enabled)
    if not enabled then
        State.AimHeld = false
        State.AimLatched = false
        refreshMobileButton()
        if mobileGui then mobileGui.Enabled = false end
        return
    end
    if mobileGui then
        mobileGui.Enabled = true
        return
    end

    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "HubAimButton"
    mobileGui.ResetOnSpawn = false

    local okParent = pcall(function()
        mobileGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not okParent or not mobileGui.Parent then
        mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(80, 80)
    btn.Position = UDim2.new(1, -110, 0.5, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BackgroundTransparency = 0.2
    btn.Text = "AIM"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.Parent = mobileGui
    mobileBtn = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
    end

    btn.InputBegan:Connect(function(input)
        if isPress(input) then
            if State.AimToggleMode then
                State.AimLatched = not State.AimLatched
            else
                State.AimHeld = true
            end
            refreshMobileButton()
        end
    end)

    btn.InputEnded:Connect(function(input)
        if isPress(input) and not State.AimToggleMode then
            State.AimHeld = false
            refreshMobileButton()
        end
    end)

    refreshMobileButton()
end

RunService.Heartbeat:Connect(function()
    if State.Spinbot then
        local root = getRoot()
        if root then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(State.SpinSpeed), 0)
        end
    end
end)

local espObjects = {}

local function getTeamInfo(player)
    local team = player.Team
    if team then
        return team.TeamColor.Color, team.Name
    end
    return State.NoTeamColor, "No Team"
end

local function passesRoleFilter(player)
    if next(State.RoleFilter) == nil then return true end
    local team = player.Team
    return team ~= nil and State.RoleFilter[team.Name:lower()] == true
end

local function removeESP(player)
    local obj = espObjects[player]
    if obj then
        if obj.Highlight then obj.Highlight:Destroy() end
        if obj.Gui then obj.Gui:Destroy() end
        espObjects[player] = nil
    end
end

local function createESP(player, char)
    local head = char:FindFirstChild("Head")
    if not head then return end

    local h = Instance.new("Highlight")
    h.Name = "HubESP"
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.5
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = char
    h.Parent = char

    local gui = Instance.new("BillboardGui")
    gui.Name = "HubESPTag"
    gui.Adornee = head
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(340, 24)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0
    label.Parent = gui

    espObjects[player] = { Char = char, Highlight = h, Gui = gui, Label = label }
end

local function updateESP(player)
    local char = player.Character
    local obj = espObjects[player]

    if obj and obj.Char ~= char then
        removeESP(player)
        obj = nil
    end
    if not char then return end
    if not obj then
        createESP(player, char)
        obj = espObjects[player]
        if not obj then return end
    end

    local show = passesRoleFilter(player) and not (isAlly(player) and not State.ESPAllies)
    obj.Highlight.Enabled = show
    obj.Gui.Enabled = show
    if not show then return end

    local color, teamName = getTeamInfo(player)
    if State.Rainbow then
        color = Color3.fromHSV((tick() % 5) / 5, 1, 1)
    end
    obj.Highlight.FillColor = color
    obj.Label.TextColor3 = color

    local parts = {}
    if State.ESPName then
        table.insert(parts, "[@" .. player.Name .. "]")
    end
    if State.ESPRole then
        table.insert(parts, "[" .. teamName .. "]")
    end
    if State.ESPDistance then
        local root = char:FindFirstChild("HumanoidRootPart")
        local myRoot = getRoot()
        if root and myRoot then
            table.insert(parts, "[" .. math.floor((root.Position - myRoot.Position).Magnitude) .. "m]")
        end
    end
    if State.ESPHealth then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            table.insert(parts, "[" .. math.floor(hum.Health) .. " HP]")
        end
    end
    obj.Label.Text = table.concat(parts, " ")
end

Players.PlayerRemoving:Connect(removeESP)

task.spawn(function()
    while true do
        if State.ESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    pcall(updateESP, player)
                end
            end
        else
            for player in pairs(espObjects) do
                removeESP(player)
            end
        end
        task.wait(0.2)
    end
end)

local npcStore  = {}
local itemStore = {}

local function clearStore(store)
    for inst, obj in pairs(store) do
        if obj.Highlight then obj.Highlight:Destroy() end
        if obj.Gui then obj.Gui:Destroy() end
        store[inst] = nil
    end
end

local function pruneStore(store)
    for inst, obj in pairs(store) do
        if not inst.Parent then
            if obj.Highlight then obj.Highlight:Destroy() end
            if obj.Gui then obj.Gui:Destroy() end
            store[inst] = nil
        end
    end
end

local function tagObject(store, inst, adornee, text, color)
    if store[inst] then return end

    local h = Instance.new("Highlight")
    h.Name = "HubObjESP"
    h.FillColor = color
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.6
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = inst
    h.Parent = inst

    local gui = Instance.new("BillboardGui")
    gui.Name = "HubObjESPTag"
    gui.Adornee = adornee
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(200, 20)
    gui.StudsOffset = Vector3.new(0, 2, 0)
    gui.Parent = adornee

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Parent = gui

    store[inst] = { Highlight = h, Gui = gui }
end

task.spawn(function()
    while true do
        task.wait(3)
        pruneStore(npcStore)
        pruneStore(itemStore)

        if State.NPCESP or State.ItemESP then
            for _, d in ipairs(workspace:GetDescendants()) do
                if State.NPCESP and d:IsA("Humanoid") then
                    local model = d.Parent
                    if model and model:IsA("Model") and model ~= getChar() and not Players:GetPlayerFromCharacter(model) then
                        local anchor = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
                        if anchor then
                            tagObject(npcStore, model, anchor, "[NPC] " .. model.Name, Color3.fromRGB(255, 170, 0))
                        end
                    end
                elseif State.ItemESP and d:IsA("Tool") then
                    local p = d.Parent
                    local carried = p and (p:IsA("Backpack") or (p:IsA("Model") and p:FindFirstChildOfClass("Humanoid")))
                    local handle = d:FindFirstChild("Handle")
                    if p and not carried and handle then
                        tagObject(itemStore, d, handle, "[Item] " .. d.Name, Color3.fromRGB(80, 200, 255))
                    end
                end
            end
        end
    end
end)

local xrayOriginal = {}

local function setXRay(enabled)
    if enabled then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and d.Transparency < 0.6 then
                local model = d:FindFirstAncestorOfClass("Model")
                local isCharacter = model and model:FindFirstChildOfClass("Humanoid")
                if not isCharacter then
                    xrayOriginal[d] = d.Transparency
                    d.Transparency = 0.6
                end
            end
        end
    else
        for part, transparency in pairs(xrayOriginal) do
            if part.Parent then
                part.Transparency = transparency
            end
            xrayOriginal[part] = nil
        end
    end
end

local originalLighting = {
    Brightness    = Lighting.Brightness,
    ClockTime     = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient       = Lighting.Ambient,
    FogEnd        = Lighting.FogEnd,
    FogStart      = Lighting.FogStart,
}
local originalDensity = {}

local function setNoFog(enabled)
    if enabled then
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                originalDensity[a] = a.Density
                a.Density = 0
            end
        end
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
        for a, density in pairs(originalDensity) do
            if a.Parent then
                a.Density = density
            end
            originalDensity[a] = nil
        end
    end
end

local function setLowGraphics(enabled)
    pcall(function()
        if enabled then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        else
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end
    end)
end

RunService.RenderStepped:Connect(function()
    if State.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
    end
    if State.NoFog then
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 9e9
    end
    if State.LowGraphics then
        Lighting.GlobalShadows = false
    end
end)

local function restoreLighting()
    if not State.Fullbright and not State.LowGraphics then
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.Ambient = originalLighting.Ambient
    end
end

local LOC_FILE = "ShootingHub_Locations.json"
local Locations = {}

local function saveLocations()
    if not writefile then return end
    pcall(function()
        writefile(LOC_FILE, HttpService:JSONEncode(Locations))
    end)
end

local function loadLocations()
    if not (isfile and readfile) then return end
    pcall(function()
        if isfile(LOC_FILE) then
            local data = HttpService:JSONDecode(readfile(LOC_FILE))
            if type(data) == "table" then
                Locations = data
            end
        end
    end)
end

loadLocations()

local function findLocationName(name)
    name = (name or ""):lower()
    for key in pairs(Locations) do
        if key:lower() == name then
            return key
        end
    end
    return nil
end

local function gotoPlayer()
    local target = findPlayer(State.TpPlayerName)
    if not target then
        notify("Телепорт", "Игрок не найден", "x")
        return
    end
    local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        notify("Телепорт", "У игрока нет персонажа", "x")
        return
    end
    teleportTo(root.CFrame * CFrame.new(0, 0, 3))
    notify("Телепорт", "Вы у игрока " .. target.Name, "check")
end

local function gotoCoords()
    local x, y, z = string.match(State.TpCoords or "", "(-?%d+%.?%d*)[,%s]+(-?%d+%.?%d*)[,%s]+(-?%d+%.?%d*)")
    if not x then
        notify("Телепорт", "Формат: x, y, z", "x")
        return
    end
    teleportTo(CFrame.new(tonumber(x), tonumber(y), tonumber(z)))
end

local function saveLocation()
    local name = State.LocName
    local root = getRoot()
    if not name or name == "" then
        notify("Позиции", "Введите название позиции", "x")
        return
    end
    if not root then return end
    local p = root.Position
    Locations[name] = { x = p.X, y = p.Y, z = p.Z }
    saveLocations()
    notify("Позиции", "Сохранено: " .. name, "check")
end

local function loadLocation()
    local key = findLocationName(State.LocName)
    if not key then
        notify("Позиции", "Позиция не найдена", "x")
        return
    end
    local p = Locations[key]
    teleportTo(CFrame.new(p.x, p.y, p.z))
end

local function deleteLocation()
    local key = findLocationName(State.LocName)
    if not key then
        notify("Позиции", "Позиция не найдена", "x")
        return
    end
    Locations[key] = nil
    saveLocations()
    notify("Позиции", "Удалено: " .. key, "check")
end

local function listLocations()
    local names = {}
    for key in pairs(Locations) do
        table.insert(names, key)
    end
    table.sort(names)
    if #names == 0 then
        notify("Позиции", "Список пуст")
    else
        notify("Позиции", table.concat(names, ", "))
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not State.ClickTP then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local hit = Mouse.Hit
        if hit then
            teleportTo(CFrame.new(hit.Position + Vector3.new(0, 3, 0)))
        end
    end
end)

local originalGravity = workspace.Gravity
local lastSafePos

UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = getHum()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

RunService.Stepped:Connect(function()
    if State.Noclip or State.Fly then
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

local flyBV, flyBG

local function stopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

RunService.RenderStepped:Connect(function()
    local root = getRoot()
    local hum = getHum()

    if not State.Fly or not root or not hum then
        if flyBV or flyBG then stopFly() end
        return
    end

    if not flyBV or flyBV.Parent ~= root then
        stopFly()
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root

        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        flyBG.P = 9e4
        flyBG.Parent = root
    end

    hum.PlatformStand = true

    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end

    flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * State.FlySpeed or Vector3.zero
    flyBG.CFrame = Camera.CFrame
end)

RunService.Heartbeat:Connect(function(dt)
    local root = getRoot()
    local hum = getHum()
    if not root or not hum then return end

    if State.TPWalk and hum.MoveDirection.Magnitude > 0 then
        root.CFrame = root.CFrame + hum.MoveDirection * (State.TPWalkSpeed * dt)
    end

    if State.AntiVoid then
        local voidY = workspace.FallenPartsDestroyHeight
        if root.Position.Y > voidY + 100 and hum.FloorMaterial ~= Enum.Material.Air then
            lastSafePos = root.CFrame
        elseif root.Position.Y < voidY + 30 and lastSafePos then
            root.CFrame = lastSafePos
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

local function serverHop()
    notify("Server Hop", "Ищу другой сервер...")
    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or type(result) ~= "table" or not result.data then
        notify("Server Hop", "Не удалось получить список серверов", "x")
        return
    end

    local candidates = {}
    for _, s in ipairs(result.data) do
        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
            table.insert(candidates, s.id)
        end
    end
    if #candidates == 0 then
        notify("Server Hop", "Подходящих серверов нет", "x")
        return
    end

    TeleportService:TeleportToPlaceInstance(game.PlaceId, candidates[math.random(#candidates)], LocalPlayer)
end

local Window

local function unloadAll()
    for key, value in pairs(State) do
        if type(value) == "boolean" then
            State[key] = false
        end
    end
    pcall(function() RunService:UnbindFromRenderStep("HubAimbot") end)
    for player in pairs(espObjects) do removeESP(player) end
    clearStore(npcStore)
    clearStore(itemStore)
    setXRay(false)
    setNoFog(false)
    setLowGraphics(false)
    restoreLighting()
    setMobileButton(false)
    stopFly()
    workspace.Gravity = originalGravity
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    if Window then pcall(function() Window:Destroy() end) end
end

local windowConfig = {
    Title = "Shooting Hub",
    Icon = "star",
    Author = "By Script community",
    Folder = "ShootingHub",
    Size = UDim2.fromOffset(640, 500),
    ToggleKey = Enum.KeyCode.RightShift,
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 190,
}

if USE_KEY_SYSTEM and PLATOBOOST_SECRET ~= "ВАШ_SECRET" then
    windowConfig.KeySystem = {
        Note = "Shooting Hub key system.",
        API = {
            {
                Type = "platoboost",
                ServiceId = PLATOBOOST_SERVICE_ID,
                Secret = PLATOBOOST_SECRET,
            },
        },
    }
elseif USE_KEY_SYSTEM then
    warn("[Shooting Hub] Secret не заполнен — запуск без ключа. Вставьте PLATOBOOST_SECRET.")
end

Window = WindUI:CreateWindow(windowConfig)

Window:Tag({
    Title = "v1.0",
    Icon = "star",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 0,
})

local CombatTab   = Window:Tab({ Title = "Combat",    Icon = "crosshair" })
local VisualTab   = Window:Tab({ Title = "Visual",    Icon = "eye" })
local TeleportTab = Window:Tab({ Title = "Teleports", Icon = "map-pin" })
local MiscTab     = Window:Tab({ Title = "Misc",      Icon = "gamepad-2" })
local SettingsTab = Window:Tab({ Title = "Settings",  Icon = "settings" })

local MobileToggle

CombatTab:Toggle({
    Title = "Aimbot",
    Desc = "Наведение на ближайшего врага (ПКМ на ПК, кнопка AIM на телефоне)",
    Icon = "crosshair",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        State.Aimbot = state
        if not state then
            State.AimLatched = false
            refreshMobileButton()
        end

        if state and IS_MOBILE and not State.LockOn and not State.MobileButton then
            State.MobileButton = true
            setMobileButton(true)
            if MobileToggle then
                pcall(function() MobileToggle:Set(true) end)
            end
            notify("Aimbot", "Включена кнопка AIM: нажми её один раз — наведение включится, ещё раз — выключится", "crosshair")
        end
    end,
})

CombatTab:Toggle({
    Title = "Lock-On",
    Desc = "Камера наводится без удержания кнопки",
    Value = false,
    Callback = function(state)
        State.LockOn = state
    end,
})

MobileToggle = CombatTab:Toggle({
    Title = "Мобильная кнопка Aimbot",
    Desc = "Экранная кнопка AIM (по умолчанию: нажал — вкл, нажал ещё — выкл)",
    Value = false,
    Callback = function(state)
        State.MobileButton = state
        setMobileButton(state)
    end,
})

CombatTab:Toggle({
    Title = "Кнопка AIM: режим переключения",
    Desc = "Нажал один раз — наводится, нажал ещё раз — выключается. Выкл = удержание",
    Value = true,
    Callback = function(state)
        State.AimToggleMode = state
        State.AimHeld = false
        State.AimLatched = false
        refreshMobileButton()
    end,
})

CombatTab:Toggle({
    Title = "Наведение от центра экрана",
    Desc = "FOV считается от центра, а не от курсора (на телефоне включено само)",
    Value = IS_MOBILE,
    Callback = function(state)
        State.AimFromCenter = state
    end,
})

CombatTab:Toggle({
    Title = "Team Check",
    Desc = "Не целиться в свою команду",
    Value = true,
    Callback = function(state)
        State.TeamCheck = state
    end,
})

CombatTab:Toggle({
    Title = "Wall Check",
    Desc = "Не целиться сквозь стены",
    Value = false,
    Callback = function(state)
        State.WallCheck = state
    end,
})

CombatTab:Toggle({
    Title = "Цель: голова",
    Desc = "Выключено — цель в торс",
    Value = true,
    Callback = function(state)
        State.AimHead = state
    end,
})

CombatTab:Toggle({
    Title = "Приоритет: наименьшее HP",
    Desc = "Выключено — ближайший к курсору",
    Value = false,
    Callback = function(state)
        State.PriorityLowHP = state
    end,
})

CombatTab:Toggle({
    Title = "Показать FOV",
    Desc = "Нужен Drawing в executor",
    Value = true,
    Callback = function(state)
        State.ShowFOV = state
    end,
})

CombatTab:Slider({
    Title = "FOV",
    Step = 1,
    Value = { Min = 30, Max = 600, Default = State.FOV },
    Callback = function(value)
        State.FOV = value
    end,
})

CombatTab:Slider({
    Title = "Плавность (1 = мгновенно)",
    Step = 1,
    Value = { Min = 1, Max = 20, Default = State.Smooth },
    Callback = function(value)
        State.Smooth = value
    end,
})

CombatTab:Input({
    Title = "Whitelist игроков",
    Desc = "Ники через запятую (Enter). Эти игроки не будут целями",
    Placeholder = "nick1, nick2",
    Value = "",
    Callback = function(text)
        State.WLPlayers = parseList(text)
    end,
})

CombatTab:Input({
    Title = "Whitelist ролей",
    Desc = "Названия команд через запятую (Enter)",
    Placeholder = "D-class, Scientist",
    Value = "",
    Callback = function(text)
        State.WLRoles = parseList(text)
    end,
})

CombatTab:Toggle({
    Title = "Spinbot",
    Desc = "Персонаж постоянно вращается",
    Value = false,
    Callback = function(state)
        State.Spinbot = state
    end,
})

CombatTab:Slider({
    Title = "Скорость Spinbot",
    Step = 1,
    Value = { Min = 5, Max = 60, Default = State.SpinSpeed },
    Callback = function(value)
        State.SpinSpeed = value
    end,
})

VisualTab:Toggle({
    Title = "Player ESP",
    Desc = "Цвет команды + подписи над головой",
    Icon = "eye",
    Type = "Checkbox",
    Value = false,
    Callback = function(state)
        State.ESP = state
    end,
})

VisualTab:Toggle({
    Title = "ESP: ник",
    Value = true,
    Callback = function(state)
        State.ESPName = state
    end,
})

VisualTab:Toggle({
    Title = "ESP: роль (команда)",
    Value = true,
    Callback = function(state)
        State.ESPRole = state
    end,
})

VisualTab:Toggle({
    Title = "ESP: здоровье",
    Value = true,
    Callback = function(state)
        State.ESPHealth = state
    end,
})

VisualTab:Toggle({
    Title = "ESP: дистанция",
    Value = true,
    Callback = function(state)
        State.ESPDistance = state
    end,
})

VisualTab:Toggle({
    Title = "Показывать свою команду",
    Value = true,
    Callback = function(state)
        State.ESPAllies = state
    end,
})

VisualTab:Toggle({
    Title = "Радужная подсветка",
    Desc = "Цвет подсветки плавно меняется",
    Value = false,
    Callback = function(state)
        State.Rainbow = state
    end,
})

VisualTab:Input({
    Title = "Фильтр ролей",
    Desc = "Показывать только эти команды (через запятую, Enter). Пусто — все",
    Placeholder = "D-class, MTF",
    Value = "",
    Callback = function(text)
        State.RoleFilter = parseList(text)
    end,
})

VisualTab:Colorpicker({
    Title = "Цвет без команды",
    Default = State.NoTeamColor,
    Callback = function(color)
        State.NoTeamColor = color
    end,
})

VisualTab:Toggle({
    Title = "NPC ESP",
    Desc = "Подсветка NPC (модели с Humanoid, не игроки)",
    Value = false,
    Callback = function(state)
        State.NPCESP = state
        if not state then clearStore(npcStore) end
    end,
})

VisualTab:Toggle({
    Title = "Items ESP",
    Desc = "Подсветка предметов (Tool), лежащих на карте",
    Value = false,
    Callback = function(state)
        State.ItemESP = state
        if not state then clearStore(itemStore) end
    end,
})

VisualTab:Toggle({
    Title = "X-Ray",
    Desc = "Делает стены полупрозрачными",
    Value = false,
    Callback = function(state)
        State.XRay = state
        setXRay(state)
    end,
})

VisualTab:Toggle({
    Title = "Fullbright",
    Desc = "Убрать темноту",
    Value = false,
    Callback = function(state)
        State.Fullbright = state
        restoreLighting()
    end,
})

VisualTab:Toggle({
    Title = "No Fog",
    Desc = "Убрать туман",
    Value = false,
    Callback = function(state)
        State.NoFog = state
        setNoFog(state)
    end,
})

VisualTab:Toggle({
    Title = "Low Graphics",
    Desc = "Минимальное качество графики для FPS",
    Value = false,
    Callback = function(state)
        State.LowGraphics = state
        setLowGraphics(state)
        restoreLighting()
    end,
})

TeleportTab:Input({
    Title = "Ник игрока",
    Desc = "Можно часть ника (Enter)",
    Placeholder = "nickname",
    Value = "",
    Callback = function(text)
        State.TpPlayerName = text
    end,
})

TeleportTab:Button({
    Title = "Goto Player",
    Desc = "Телепорт к игроку с этим ником",
    Callback = gotoPlayer,
})

TeleportTab:Input({
    Title = "Координаты",
    Desc = "Формат: x, y, z (Enter)",
    Placeholder = "0, 50, 0",
    Value = "",
    Callback = function(text)
        State.TpCoords = text
    end,
})

TeleportTab:Button({
    Title = "TP to Coordinates",
    Desc = "Телепорт по введённым координатам",
    Callback = gotoCoords,
})

TeleportTab:Input({
    Title = "Название позиции",
    Desc = "Имя для сохранения / загрузки (Enter)",
    Placeholder = "home",
    Value = "",
    Callback = function(text)
        State.LocName = text
    end,
})

TeleportTab:Button({
    Title = "Сохранить текущую позицию",
    Callback = saveLocation,
})

TeleportTab:Button({
    Title = "Телепорт на сохранённую позицию",
    Callback = loadLocation,
})

TeleportTab:Button({
    Title = "Удалить позицию",
    Callback = deleteLocation,
})

TeleportTab:Button({
    Title = "Список позиций",
    Callback = listLocations,
})

TeleportTab:Toggle({
    Title = "Click TP",
    Desc = "Ctrl + ЛКМ — телепорт в точку курсора",
    Value = false,
    Callback = function(state)
        State.ClickTP = state
    end,
})

MiscTab:Toggle({
    Title = "Noclip",
    Desc = "Проходить сквозь объекты",
    Value = false,
    Callback = function(state)
        State.Noclip = state
    end,
})

MiscTab:Toggle({
    Title = "Fly",
    Desc = "WASD + Space (вверх) / LeftCtrl (вниз)",
    Value = false,
    Callback = function(state)
        State.Fly = state
    end,
})

MiscTab:Slider({
    Title = "Скорость полёта",
    Step = 1,
    Value = { Min = 10, Max = 250, Default = State.FlySpeed },
    Callback = function(value)
        State.FlySpeed = value
    end,
})

MiscTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Прыгать в воздухе без ограничений",
    Value = false,
    Callback = function(state)
        State.InfJump = state
    end,
})

MiscTab:Toggle({
    Title = "TP Walk",
    Desc = "Ускорение через смещение персонажа",
    Value = false,
    Callback = function(state)
        State.TPWalk = state
    end,
})

MiscTab:Slider({
    Title = "Скорость TP Walk",
    Step = 1,
    Value = { Min = 5, Max = 150, Default = State.TPWalkSpeed },
    Callback = function(value)
        State.TPWalkSpeed = value
    end,
})

MiscTab:Toggle({
    Title = "Anti-Gravity",
    Desc = "Пониженная гравитация",
    Value = false,
    Callback = function(state)
        State.AntiGravity = state
        if state then
            workspace.Gravity = originalGravity * 0.25
        else
            workspace.Gravity = originalGravity
        end
    end,
})

MiscTab:Toggle({
    Title = "Anti-Void",
    Desc = "Возврат на безопасную позицию при падении в бездну",
    Value = false,
    Callback = function(state)
        State.AntiVoid = state
    end,
})

MiscTab:Toggle({
    Title = "Anti-AFK",
    Desc = "Не кикает за бездействие",
    Value = false,
    Callback = function(state)
        State.AntiAFK = state
    end,
})

MiscTab:Button({
    Title = "Server Hop",
    Desc = "Перейти на другой сервер этой игры",
    Callback = function()
        task.spawn(serverHop)
    end,
})

MiscTab:Button({
    Title = "Reset Character",
    Desc = "Респавн персонажа",
    Callback = function()
        local hum = getHum()
        if hum then hum.Health = 0 end
    end,
})

SettingsTab:Keybind({
    Title = "Клавиша меню",
    Desc = "Скрыть/показать окно",
    Value = "RightShift",
    Callback = function(v)
        pcall(function()
            Window:SetToggleKey(Enum.KeyCode[v])
        end)
    end,
})

SettingsTab:Button({
    Title = "Выгрузить скрипт",
    Desc = "Выключает все функции, убирает ESP и закрывает окно",
    Callback = unloadAll,
})

CombatTab:Select()

if IS_MOBILE then
    notify("Shooting Hub", "Загружено. Для Aimbot включи его и кнопку AIM (или Lock-On).", "crosshair")
else
    notify("Shooting Hub", "Загружено. RightShift — скрыть/показать меню.", "crosshair")
end
