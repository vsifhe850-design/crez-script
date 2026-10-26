print("[Collapse] Loading...")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local VIM = game:GetService("VirtualInputManager")

local Cfg = {
    tbEnabled = false, tbBind = Enum.KeyCode.V, tbCps = 10, tbReach = 5.0, tbTeam = false,
    espName = false, espHp = false, espDist = false, espTeam = false, espMaxDist = 500, espColor = Color3.fromRGB(130, 150, 255),
    chamsEnabled = false, chamsFill = false, chamsTeam = false, chamsColor = Color3.fromRGB(130, 150, 255),
    sprintEnabled = false, sprintBind = Enum.KeyCode.LeftShift, sprintKey = Enum.KeyCode.LeftControl,
    afkEnabled = false, afkInterval = 10,
    themeColor = Color3.fromRGB(130, 150, 255),
    guiOpen = true
}

local Connections = {}
local EspPool = {}
local ChamsPool = {}
local ActiveSlider = nil
local ActiveBind = nil
local DragState = nil
local LastAttack = 0
local LastAfk = 0
local SprintState = false
local UIElements = {}
local configFile = "CollapseV2.json"

local function track(c)
    table.insert(Connections, c)
    return c
end

local function getHealth(c)
    if not c then return 0 end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then return h.Health end
    return 0
end

local function sameTeam(p)
    if not p.Team or not LocalPlayer.Team then return false end
    return p.Team == LocalPlayer.Team
end

local function getHrp(c)
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c:FindFirstChildWhichIsA("BasePart")
end

local function getCharacterFromPart(part)
    if not part then return nil end
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function saveConfig()
    if type(writefile) ~= "function" then return end
    local data = {}
    for k, v in pairs(Cfg) do
        if type(v) == "Color3" then
            data[k] = {v.R, v.G, v.B}
        elseif type(v) == "EnumItem" then
            data[k] = v.Name
        else
            data[k] = v
        end
    end
    pcall(function()
        writefile(configFile, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(configFile) then return end
    local success, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(configFile))
    end)
    if success and decoded then
        for k, v in pairs(decoded) do
            if type(v) == "table" and #v == 3 then
                Cfg[k] = Color3.new(v[1], v[2], v[3])
            elseif type(Cfg[k]) == "EnumItem" and Enum.KeyCode[v] then
                Cfg[k] = Enum.KeyCode[v]
            else
                Cfg[k] = v
            end
        end
    end
end

pcall(loadConfig)
Cfg.guiOpen = true 

local function hideEsp(e)
    if e.n then e.n.Visible = false end
    if e.d then e.d.Visible = false end
    if e.h then e.h.Visible = false end
end

local function renderEsp(player)
    if not Drawing then return end
    if player == LocalPlayer then return end
    local char = player.Character
    local e = EspPool[player]
    local isTeam = Cfg.espTeam and sameTeam(player)
    
    if Cfg.chamsEnabled and not (Cfg.chamsTeam and sameTeam(player)) and char and getHealth(char) > 0 then
        local hl = ChamsPool[player]
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "crez_chams"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            ChamsPool[player] = hl
        elseif hl.Parent ~= char then
            hl.Parent = char
        end
        hl.Enabled = true
        hl.Adornee = char
        hl.FillColor = Cfg.chamsColor
        hl.OutlineColor = Cfg.chamsColor
        hl.FillTransparency = Cfg.chamsFill and 0.5 or 1
        hl.OutlineTransparency = 0
    elseif ChamsPool[player] then
        ChamsPool[player].Enabled = false
    end

    if not char or getHealth(char) <= 0 or isTeam then
        if e then hideEsp(e) end
        return
    end
    
    local hrp = getHrp(char)
    if not hrp then
        if e then hideEsp(e) end
        return
    end

    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > Cfg.espMaxDist then
        if e then hideEsp(e) end
        return
    end

    local topS = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2, 0))
    if topS.Z < 0 then
        if e then hideEsp(e) end
        return
    end

    if not e then
        e = {
            n = Drawing.new("Text"),
            d = Drawing.new("Text"),
            h = Drawing.new("Text")
        }
        for _, t in ipairs({ e.n, e.d, e.h }) do
            t.Center = true
            t.Outline = true
        end
        EspPool[player] = e
    end

    local col = Cfg.espColor
    local y = topS.Y

    e.n.Text = player.Name
    e.n.Size = 14
    e.n.Position = Vector2.new(topS.X, y - 40)
    e.n.Color = col
    e.n.Visible = Cfg.espName

    e.d.Text = string.format("[%d]", math.floor(dist))
    e.d.Size = 12
    e.d.Position = Vector2.new(topS.X, y - 25)
    e.d.Color = col
    e.d.Visible = Cfg.espDist

    e.h.Text = tostring(math.floor(getHealth(char)))
    e.h.Size = 12
    e.h.Position = Vector2.new(topS.X, y - 10)
    e.h.Color = col
    e.h.Visible = Cfg.espHp
end

local function cleanupVisuals()
    local active = {}
    for _, p in ipairs(Players:GetPlayers()) do
        active[p] = true
    end
    for p, e in pairs(EspPool) do
        if not active[p] then
            e.n:Remove()
            e.d:Remove()
            e.h:Remove()
            EspPool[p] = nil
        end
    end
    for p, hl in pairs(ChamsPool) do
        if not active[p] then
            hl:Destroy()
            ChamsPool[p] = nil
        end
    end
end

local function fireM1()
    if VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
        return
    end
    if mouse1click then pcall(mouse1click) end
end

local function checkTrigger()
    local now = os.clock()
    if now - LastAttack < (1 / Cfg.tbCps) then return end
    
    local mouse = LocalPlayer:GetMouse()
    local myHrp = getHrp(LocalPlayer.Character)
    if not myHrp then return end

    local targetChar = nil
    if mouse.Target then
        targetChar = getCharacterFromPart(mouse.Target)
    end
    
    if not targetChar then
        local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        local result = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
        if result then
            targetChar = getCharacterFromPart(result.Instance)
        end
    end

    if not targetChar or targetChar == LocalPlayer.Character then return end
    
    local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
    if targetPlayer and Cfg.tbTeam and sameTeam(targetPlayer) then return end
    if getHealth(targetChar) <= 0 then return end

    local closestDist = math.huge
    for _, part in ipairs(targetChar:GetChildren()) do
        if part:IsA("BasePart") then
            local dist = (part.Position - myHrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
            end
        end
    end
    
    if closestDist <= (Cfg.tbReach + 1.5) then
        fireM1()
        LastAttack = now
    end
end

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        o[k] = v
    end
    o.Parent = parent
    return o
end

local function tween(obj, time, props)
    TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function updateAllUI()
    for k, fn in pairs(UIElements) do
        if k ~= "themeColor" then
            pcall(fn)
        end
    end
end

if game:GetService("CoreGui"):FindFirstChild("Collapse_v2") then
    game:GetService("CoreGui").Collapse_v2:Destroy()
end
if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Collapse_v2") then
    LocalPlayer.PlayerGui.Collapse_v2:Destroy()
end

local gui = mk("ScreenGui", {
    Name = "Collapse_v2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Enabled = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, LocalPlayer:WaitForChild("PlayerGui"))

pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)

local main = mk("Frame", {
    Size = UDim2.new(0, 520, 0, 360),
    Position = UDim2.new(0.5, -260, 0.5, -180),
    BackgroundColor3 = Color3.fromRGB(15, 15, 18),
    BorderSizePixel = 0,
    Active = false
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, main)

local mainStroke = mk("UIStroke", {
    Color = Cfg.themeColor,
    Thickness = 1,
    Transparency = 0.5
}, main)

local topBar = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1
}, main)

local titleLbl = mk("TextLabel", {
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 15, 0, 0),
    BackgroundTransparency = 1,
    Text = "Collapse v2",
    TextColor3 = Cfg.themeColor,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left
}, topBar)

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -35, 0, 5),
    BackgroundTransparency = 1,
    Text = "X",
    TextColor3 = Color3.fromRGB(150, 150, 160),
    Font = Enum.Font.GothamBold,
    TextSize = 20
}, topBar)

closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
    saveConfig()
end)

topBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        DragState = { start = i.Position, pos = main.Position }
    end
end)

track(UserInput.InputChanged:Connect(function(i)
    if DragState and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - DragState.start
        main.Position = UDim2.new(DragState.pos.X.Scale, DragState.pos.X.Offset + d.X, DragState.pos.Y.Scale, DragState.pos.Y.Offset + d.Y)
    end
end))

track(UserInput.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        DragState = nil
        ActiveSlider = nil
    end
end))

local sidebar = mk("Frame", {
    Size = UDim2.new(0, 130, 1, -50),
    Position = UDim2.new(0, 10, 0, 40),
    BackgroundColor3 = Color3.fromRGB(22, 22, 26),
    BorderSizePixel = 0
}, main)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, sidebar)
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, sidebar)

local content = mk("Frame", {
    Size = UDim2.new(1, -155, 1, -50),
    Position = UDim2.new(0, 145, 0, 40),
    BackgroundColor3 = Color3.fromRGB(22, 22, 26),
    BorderSizePixel = 0
}, main)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, content)

local pages = {}
local currentTab = "Combat"
local tabLines = {}

local function switchTab(tab)
    currentTab = tab
    for name, frame in pairs(pages) do
        frame.Visible = (name == tab)
    end
    for name, btn in pairs(sidebar:GetChildren()) do
        if btn:IsA("TextButton") then
            local isSelected = (btn.Name == tab)
            btn.TextColor3 = isSelected and Cfg.themeColor or Color3.fromRGB(150, 150, 160)
            btn.BackgroundColor3 = isSelected and Color3.fromRGB(35, 35, 42) or Color3.fromRGB(22, 22, 26)
            if tabLines[btn.Name] then
                tabLines[btn.Name].Visible = isSelected
            end
        end
    end
end

for i, name in ipairs({"Combat", "Visuals", "Player", "Misc"}) do
    local btn = mk("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = i,
        BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        Text = name,
        TextColor3 = Color3.fromRGB(150, 150, 160),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = false
    }, sidebar)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
    
    local line = mk("Frame", {
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = Cfg.themeColor,
        BorderSizePixel = 0,
        Visible = false
    }, btn)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, line)
    tabLines[name] = line
    
    pages[name] = mk("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Cfg.themeColor,
        Visible = false
    }, content)
    
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pages[name])
    
    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

local function makeCard(parent, title)
    local card = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(30, 30, 36),
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
    mk("UIStroke", { Color = Color3.fromRGB(50, 50, 60), Thickness = 1 }, card)
    
    local header = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false
    }, card)
    
    mk("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(230, 230, 240),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)
    
    local arrow = mk("TextLabel", {
        Size = UDim2.new(0, 30, 0, 36),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = "+",
        TextColor3 = Cfg.themeColor,
        Font = Enum.Font.GothamBold,
        TextSize = 18
    }, card)
    
    local panel = mk("Frame", {
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.new(0, 12, 0, 36),
        BackgroundTransparency = 1,
        Visible = false
    }, card)
    
    local list = mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
    local expanded = false
    
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if expanded then
            local h = list.AbsoluteContentSize.Y + 42
            tween(card, 0.2, { Size = UDim2.new(1, 0, 0, h) })
            panel.Size = UDim2.new(1, -24, 0, list.AbsoluteContentSize.Y)
        end
    end)
    
    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        panel.Visible = expanded
        tween(arrow, 0.2, { Rotation = expanded and 45 or 0 })
        if expanded then
            local h = list.AbsoluteContentSize.Y + 42
            panel.Size = UDim2.new(1, -24, 0, list.AbsoluteContentSize.Y)
            tween(card, 0.2, { Size = UDim2.new(1, 0, 0, h) })
        else
            tween(card, 0.2, { Size = UDim2.new(1, 0, 0, 36) })
        end
    end)
    return panel
end

local function makeToggle(parent, label, key)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
        BorderSizePixel = 0
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
    
    mk("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    
    local btn = mk("TextButton", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -46, 0, 6),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        Text = "",
        AutoButtonColor = false
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
    
    local fill = mk("Frame", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundColor3 = Cfg[key] and Cfg.themeColor or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0
    }, btn)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    
    local function refresh()
        local on = Cfg[key]
        tween(fill, 0.2, {
            Position = on and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = on and Cfg.themeColor or Color3.fromRGB(60, 60, 70)
        })
    end
    refresh()
    UIElements[key] = refresh
    
    btn.MouseButton1Click:Connect(function()
        Cfg[key] = not Cfg[key]
        refresh()
        saveConfig()
    end)
end

local function makeSlider(parent, label, key, min, max)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
        BorderSizePixel = 0
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
    
    mk("TextLabel", {
        Size = UDim2.new(1, -60, 0, 14),
        Position = UDim2.new(0, 10, 0, 2),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    
    local valLbl = mk("TextLabel", {
        Size = UDim2.new(0, 50, 0, 14),
        Position = UDim2.new(1, -60, 0, 2),
        BackgroundTransparency = 1,
        Text = tostring(Cfg[key]),
        TextColor3 = Cfg.themeColor,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right
    }, row)
    
    local bar = mk("Frame", {
        Size = UDim2.new(1, -20, 0, 4),
        Position = UDim2.new(0, 10, 0, 24),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderSizePixel = 0
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
    
    local fill = mk("Frame", {
        Size = UDim2.new((Cfg[key] - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Cfg.themeColor,
        BorderSizePixel = 0
    }, bar)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    
    local function refresh()
        local pct = (Cfg[key] - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = Cfg.themeColor
        valLbl.Text = tostring(math.floor(Cfg[key] * 10) / 10)
        valLbl.TextColor3 = Cfg.themeColor
    end
    UIElements[key] = refresh
    
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            ActiveSlider = { bar = bar, key = key, min = min, max = max, fill = fill, lbl = valLbl }
        end
    end)
end

track(UserInput.InputChanged:Connect(function(i)
    if ActiveSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
        local px = math.clamp((i.Position.X - ActiveSlider.bar.AbsolutePosition.X) / math.max(ActiveSlider.bar.AbsoluteSize.X, 1), 0, 1)
        local v = ActiveSlider.min + (ActiveSlider.max - ActiveSlider.min) * px
        Cfg[ActiveSlider.key] = v
        ActiveSlider.fill.Size = UDim2.new(px, 0, 1, 0)
        ActiveSlider.lbl.Text = tostring(math.floor(v * 10) / 10)
    end
end))

track(UserInput.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and ActiveSlider then
        saveConfig()
        ActiveSlider = nil
    end
end))

local function makeBind(parent, label, key)
    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
        BorderSizePixel = 0
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
    
    mk("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    
    local btn = mk("TextButton", {
        Size = UDim2.new(0, 70, 0, 20),
        Position = UDim2.new(1, -80, 0, 5),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        Text = Cfg[key].Name,
        TextColor3 = Color3.fromRGB(150, 150, 160),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, btn)
    
    local function refresh()
        btn.Text = Cfg[key].Name
    end
    UIElements[key] = refresh
    
    local listening = false
    btn.MouseButton1Click:Connect(function()
        if ActiveBind and ActiveBind ~= btn then
            ActiveBind.Text = Cfg[ActiveBind.Key].Name
            ActiveBind.Listening = false
        end
        listening = not listening
        ActiveBind = { Text = btn, Key = key, Listening = listening }
        btn.Text = listening and "..." or Cfg[key].Name
    end)
    
    track(UserInput.InputBegan:Connect(function(input)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            Cfg[key] = input.KeyCode
            listening = false
            ActiveBind = nil
            btn.Text = Cfg[key].Name
            saveConfig()
        end
    end))
end

local function makeColorPicker(parent, label, key)
    local container = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, container)
    
    local header = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false
    }, container)
    
    mk("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)
    
    local colorBox = mk("Frame", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -30, 0, 5),
        BackgroundColor3 = Cfg[key],
        BorderSizePixel = 0
    }, container)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, colorBox)
    mk("UIStroke", { Color = Color3.fromRGB(80, 80, 90), Thickness = 1 }, colorBox)
    
    local panel = mk("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.new(0, 10, 0, 34),
        BackgroundTransparency = 1,
        Visible = false
    }, container)
    
    local sv = mk("Frame", {
        Size = UDim2.new(1, -25, 0, 80),
        BorderSizePixel = 0
    }, panel)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, sv)
    
    local hGrad = Instance.new("UIGradient")
    hGrad.Transparency = NumberSequence.new(0, 1)
    hGrad.Parent = sv
    
    local vFrame = mk("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1
    }, sv)
    
    local vGrad = Instance.new("UIGradient")
    vGrad.Rotation = 90
    vGrad.Transparency = NumberSequence.new(1, 0)
    vGrad.Parent = vFrame
    
    local hueBar = mk("Frame", {
        Size = UDim2.new(0, 15, 0, 80),
        Position = UDim2.new(1, -20, 0, 0),
        BorderSizePixel = 0
    }, panel)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, hueBar)
    
    local hueGrad = Instance.new("UIGradient")
    hueGrad.Rotation = 90
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
        ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16, 1, 1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
        ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 1, 1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
        ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1))
    })
    hueGrad.Parent = hueBar
    
    local h0, s0, v0 = Cfg[key]:ToHSV()
    local hue, sat, val = h0, s0, v0
    
    local function updateColor()
        local c = Color3.fromHSV(hue, sat, val)
        Cfg[key] = c
        colorBox.BackgroundColor3 = c
        sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        if key == "themeColor" then
            mainStroke.Color = c
            titleLbl.TextColor3 = c
            for name, btn in pairs(sidebar:GetChildren()) do
                if btn:IsA("TextButton") then
                    if tabLines[btn.Name] then tabLines[btn.Name].BackgroundColor3 = c end
                    if btn.Name == currentTab then btn.TextColor3 = c end
                end
            end
        end
        updateAllUI()
    end
    sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    
    local expanded = false
    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        panel.Visible = expanded
        tween(container, 0.2, { Size = UDim2.new(1, 0, 0, expanded and 124 or 30) })
    end)
    
    local dragSV = false
    local dragHue = false
    
    sv.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true end
    end)
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragHue = true end
    end)
    
    track(UserInput.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragSV or dragHue then saveConfig() end
            dragSV = false
            dragHue = false
        end
    end))
    
    track(UserInput.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if dragSV then
            local px = math.clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
            local py = math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
            sat = px
            val = 1 - py
            updateColor()
        elseif dragHue then
            local py = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
            hue = py
            updateColor()
        end
    end))
    
    UIElements[key] = function()
        local h, s, v = Cfg[key]:ToHSV()
        hue, sat, val = h, s, v
        colorBox.BackgroundColor3 = Cfg[key]
        sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    end
end

local tbPanel = makeCard(pages.Combat, "TriggerBot")
makeSlider(tbPanel, "Reach (studs)", "tbReach", 1, 15)
makeSlider(tbPanel, "CPS", "tbCps", 1, 20)
makeToggle(tbPanel, "Team Check", "tbTeam")
makeBind(tbPanel, "Trigger Bind", "tbBind")

local espPanel = makeCard(pages.Visuals, "Text ESP")
makeToggle(espPanel, "Name", "espName")
makeToggle(espPanel, "Health", "espHp")
makeToggle(espPanel, "Distance", "espDist")
makeSlider(espPanel, "Max Dist", "espMaxDist", 100, 2000)
makeColorPicker(espPanel, "Color", "espColor")

local chamsPanel = makeCard(pages.Visuals, "Chams")
makeToggle(chamsPanel, "Enable Chams", "chamsEnabled")
makeToggle(chamsPanel, "Fill", "chamsFill")
makeToggle(chamsPanel, "Team Check", "chamsTeam")
makeColorPicker(chamsPanel, "Color", "chamsColor")

local sprintPanel = makeCard(pages.Player, "Auto Sprint")
makeToggle(sprintPanel, "Enable Sprint", "sprintEnabled")
makeBind(sprintPanel, "Bind", "sprintBind")

local afkPanel = makeCard(pages.Player, "Anti-AFK")
makeToggle(afkPanel, "Enable AFK", "afkEnabled")
makeSlider(afkPanel, "Interval", "afkInterval", 3, 60)

local themePanel = makeCard(pages.Misc, "UI Theme")
makeColorPicker(themePanel, "Accent Color", "themeColor")

local infoPanel = makeCard(pages.Misc, "Info")
mk("TextLabel", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = "Settings save automatically.",
    TextColor3 = Color3.fromRGB(200, 200, 210),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
}, infoPanel)

switchTab("Combat")

track(LocalPlayer.Idled:Connect(function()
    if not Cfg.afkEnabled then return end
    local now = os.clock()
    if now - LastAfk < Cfg.afkInterval then return end
    LastAfk = now
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

local function releaseSprint()
    if SprintState then
        if VIM then
            pcall(function()
                VIM:SendKeyEvent(false, Cfg.sprintKey, false, game)
            end)
        end
        SprintState = false
    end
end

track(RunService.RenderStepped:Connect(function()
    if Cfg.sprintEnabled then
        local wDown = UserInput:IsKeyDown(Enum.KeyCode.W)
        if wDown then
            if not SprintState then
                if VIM then
                    pcall(function()
                        VIM:SendKeyEvent(true, Cfg.sprintKey, false, game)
                    end)
                end
                SprintState = true
            end
        else
            releaseSprint()
        end
    else
        releaseSprint()
    end

    if Cfg.tbEnabled then checkTrigger() end
end))

track(RunService.RenderStepped:Connect(function()
    if Cfg.espName or Cfg.espHp or Cfg.espDist or Cfg.chamsEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            renderEsp(p)
        end
        cleanupVisuals()
    else
        for _, e in pairs(EspPool) do
            hideEsp(e)
        end
        for _, hl in pairs(ChamsPool) do
            hl.Enabled = false
        end
    end
end))

track(UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Cfg.guiOpen = not Cfg.guiOpen
        gui.Enabled = Cfg.guiOpen
        print("[Collapse] Toggled GUI: " .. tostring(Cfg.guiOpen))
    end
    if input.KeyCode == Cfg.tbBind then
        Cfg.tbEnabled = not Cfg.tbEnabled
        if UIElements["tbEnabled"] then UIElements["tbEnabled"]() end
    end
    if input.KeyCode == Cfg.sprintBind then
        Cfg.sprintEnabled = not Cfg.sprintEnabled
        if UIElements["sprintEnabled"] then UIElements["sprintEnabled"]() end
    end
end))

getgenv().CollapseUnload = function()
    saveConfig()
    releaseSprint()
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, e in pairs(EspPool) do
        e.n:Remove()
        e.d:Remove()
        e.h:Remove()
    end
    for _, hl in pairs(ChamsPool) do
        hl:Destroy()
    end
    gui:Destroy()
end

pcall(function()
    game:BindToClose(saveConfig)
end)
print("[Collapse] Loaded successfully.")
