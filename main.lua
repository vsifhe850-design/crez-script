-- +1 upgrade per kill — cheat menu (luau, executor)
-- Removed: Skeleton ESP.

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UserInput   = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local vim
pcall(function() vim = game:GetService("VirtualInputManager") end)

local Cfg = {
    espEnabled = true, espName = true, espDist = true, espHealth = true,
    espWhite = false,
    espMaxDist = 2000, espScale = 1.0, nameSize = 18,
    espColor = Color3.fromRGB(0, 255, 0),

    sprintEnabled = false,
    sprintBind = Enum.KeyCode.LeftShift,
    afkEnabled = true, afkInterval = 10, guiOpen = true
}

local pool, Connections = {}, {}
local sprintState, baseWalk, lastAfk = false, 16, 0
local activeSlider = nil

local function track(c) table.insert(Connections, c); return c end

local function getHealth(c)
    if not c then return 0 end
    local a = c:GetAttribute("Health")
    if a then return tonumber(a) or 0 end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then return h.Health end
    return 0
end

local function getAimPart(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChildWhichIsA("BasePart")
end

local function hideEsp(e)
    e.n.Visible, e.d.Visible, e.h.Visible = false, false, false
end

local function renderPlayer(player)
    if player == LocalPlayer then return end

    local char = player.Character
    local e = pool[player]
    if not char then if e then hideEsp(e) end; return end

    local hp = getHealth(char)
    if hp <= 0 then if e then hideEsp(e) end; return end

    local part = getAimPart(char)
    if not part then if e then hideEsp(e) end; return end

    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    if dist > Cfg.espMaxDist then if e then hideEsp(e) end; return end

    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then if e then hideEsp(e) end; return end

    if not e then
        e = {
            n = Drawing.new("Text"),
            d = Drawing.new("Text"),
            h = Drawing.new("Text"),
        }
        e.n.Center, e.n.Outline = true, true
        e.d.Center, e.d.Outline = true, true
        e.h.Center, e.h.Outline = true, true
        pool[player] = e
    end

    local sc  = Cfg.espScale
    local y   = sp.Y
    local col = Cfg.espWhite and Color3.fromRGB(255, 255, 255) or Cfg.espColor

    if Cfg.espName then
        e.n.Text, e.n.Size = player.Name, math.floor(Cfg.nameSize * sc)
        e.n.Position, e.n.Color = Vector2.new(sp.X, y - 20 * sc), col
        e.n.Visible = true
    else e.n.Visible = false end

    if Cfg.espDist then
        e.d.Text, e.d.Size = string.format("[%dm]", math.floor(dist)), math.floor(12 * sc)
        e.d.Position, e.d.Color = Vector2.new(sp.X, y + 2), col
        e.d.Visible = true
    else e.d.Visible = false end

    if Cfg.espHealth then
        local hearts = math.round((hp / 2) * 2) / 2
        local text = (hearts == math.floor(hearts)) and string.format("%d/10", hearts) or string.format("%.1f/10", hearts)
        e.h.Text, e.h.Size = text, math.floor(14 * sc)
        e.h.Position, e.h.Color = Vector2.new(sp.X, y + 18 * sc), col
        e.h.Visible = true
    else e.h.Visible = false end
end

local function cleanupEsp()
    local active = {}
    for _, p in ipairs(Players:GetPlayers()) do active[p] = true end

    for p, e in pairs(pool) do
        if not active[p] then
            e.n:Remove(); e.d:Remove(); e.h:Remove()
            pool[p] = nil
        end
    end
end

-- ============ GUI ============
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function guiParent()
    if gethui then
        local ok, r = pcall(gethui)
        if ok and r then return r end
    end
    return game:GetService("CoreGui")
end

local gui = mk("ScreenGui", {
    Name = "crez_menu", ResetOnSpawn = false, IgnoreGuiInset = true,
    Enabled = Cfg.guiOpen, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent())

local root = mk("Frame", {
    Name = "root", Size = UDim2.new(0, 360, 0, 260),
    Position = UDim2.new(0.5, -180, 0.5, -130),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0, Active = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, root)
mk("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, root)

local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, root)
mk("TextLabel", {
    Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1, Text = "crez | +1 upgrade per kill",
    TextColor3 = Color3.fromRGB(230, 230, 240),
    TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, TextSize = 13,
}, header)

local scroll = mk("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -34), Position = UDim2.new(0, 6, 0, 30),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
}, root)
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

local function makeFeature(label, enabledKey)
    local card = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(28, 28, 34),
        BorderSizePixel = 0, ClipsDescendants = true,
    }, scroll)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
    mk("UIStroke", { Color = Color3.fromRGB(55, 55, 65), Thickness = 1 }, card)

    local headerBtn = mk("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
    mk("TextLabel", {
        Size = UDim2.new(1, -100, 0, 30), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(230, 230, 240),
        TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, TextSize = 13,
    }, card)

    local toggleBtn = mk("TextButton", {
        Size = UDim2.new(0, 56, 0, 18), Position = UDim2.new(1, -66, 0, 6),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, card)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, toggleBtn)
    local toggleFill = mk("Frame", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 140), BorderSizePixel = 0 }, toggleBtn)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, toggleFill)
    local toggleState = mk("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = "ON", TextColor3 = Color3.fromRGB(20, 20, 24), Font = Enum.Font.GothamBold, TextSize = 10 }, toggleBtn)

    local panel = mk("Frame", { Size = UDim2.new(1, -12, 0, 0), Position = UDim2.new(0, 6, 0, 32), BackgroundTransparency = 1, Visible = false }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, panel)

    local function refreshToggle()
        local on = Cfg[enabledKey]
        toggleFill.Position = on and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
        toggleFill.BackgroundColor3 = on and Color3.fromRGB(80, 200, 140) or Color3.fromRGB(120, 60, 60)
        toggleState.Position = on and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
        toggleState.Text = on and "ON" or "OFF"
    end
    refreshToggle()

    toggleBtn.MouseButton1Click:Connect(function()
        Cfg[enabledKey] = not Cfg[enabledKey]
        refreshToggle()
    end)

    local expanded = false
    local function relayout()
        local baseH, listH = 30, 0
        for _, child in ipairs(panel:GetChildren()) do if child:IsA("Frame") then listH += child.AbsoluteSize.Y + 4 end end
        panel.Size = UDim2.new(1, -12, 0, expanded and listH or 0)
        card.Size = UDim2.new(1, 0, 0, baseH + (expanded and (listH + 4) or 0))
    end
    headerBtn.MouseButton1Click:Connect(function() expanded = not expanded; panel.Visible = expanded; relayout() end)
    return { card = card, panel = panel, relayout = relayout, refreshToggle = refreshToggle }
end

local function makeSubToggle(parent, label, key, cardObj)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0 }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
    mk("TextLabel", { Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(210, 210, 220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, row)
    local btn = mk("TextButton", { Size = UDim2.new(0, 48, 0, 16), Position = UDim2.new(1, -54, 0, 3), BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
    local fill = mk("Frame", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 140), BorderSizePixel = 0 }, btn)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local txt = mk("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(20, 20, 24), Font = Enum.Font.GothamBold, TextSize = 9 }, btn)

    local function refresh()
        local on = Cfg[key]
        fill.Position = on and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
        fill.BackgroundColor3 = on and Color3.fromRGB(80, 200, 140) or Color3.fromRGB(120, 60, 60)
        txt.Position = on and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
        txt.Text = on and "ON" or "OFF"
    end
    refresh()
    btn.MouseButton1Click:Connect(function() Cfg[key] = not Cfg[key]; refresh(); if cardObj then cardObj.relayout() end end)
end

local function makeSubSlider(parent, label, key, min, max, integer)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0 }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
    mk("TextLabel", { Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(210, 210, 220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, row)
    local valLbl = mk("TextLabel", { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -52, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(120, 220, 160), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium, TextSize = 11 }, row)
    local bar = mk("Frame", { Size = UDim2.new(0, 120, 0, 6), Position = UDim2.new(0, 120, 0, 8), BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

    local currentVal = Cfg[key] or min
    local fill = mk("Frame", { Size = UDim2.new(math.clamp((currentVal - min) / (max - min), 0, 1), 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 140), BorderSizePixel = 0 }, bar)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local function fmt(v) return integer and tostring(math.floor(v)) or string.format("%.2f", v) end
    valLbl.Text = fmt(currentVal)

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            activeSlider = { bar = bar, min = min, max = max, int = integer, key = key, fill = fill, valLbl = valLbl, fmt = fmt }
        end
    end)
end

track(UserInput.InputChanged:Connect(function(i)
    if not activeSlider or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local px = math.clamp((i.Position.X - activeSlider.bar.AbsolutePosition.X) / math.max(activeSlider.bar.AbsoluteSize.X, 1), 0, 1)
    local v = activeSlider.min + (activeSlider.max - activeSlider.min) * px
    if activeSlider.int then v = math.floor(v + 0.5) end
    Cfg[activeSlider.key] = v
    activeSlider.fill.Size = UDim2.new(px, 0, 1, 0)
    activeSlider.valLbl.Text = activeSlider.fmt(v)
end))
track(UserInput.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then activeSlider = nil end
end))

local function makeColorPicker(parent, key, cardObj)
    local container = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0, ClipsDescendants = true }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, container)

    local headBtn = mk("TextButton", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, container)
    mk("TextLabel", { Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = "ESP Color", TextColor3 = Color3.fromRGB(210, 210, 220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, container)
    local colorBox = mk("Frame", { Size = UDim2.new(0, 30, 0, 16), Position = UDim2.new(1, -38, 0, 3), BackgroundColor3 = Cfg[key], BorderSizePixel = 0 }, container)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, colorBox)
    mk("UIStroke", { Color = Color3.fromRGB(80, 80, 90), Thickness = 1 }, colorBox)

    local pickerPanel = mk("Frame", { Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1, Visible = false }, container)

    local sv = mk("Frame", { Size = UDim2.new(1, -30, 0, 100), BorderSizePixel = 0 }, pickerPanel)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, sv)
    local hGrad = Instance.new("UIGradient"); hGrad.Transparency = NumberSequence.new(0, 1); hGrad.Parent = sv
    local vFrame = mk("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 }, sv)
    local vGrad = Instance.new("UIGradient"); vGrad.Rotation = 90; vGrad.Transparency = NumberSequence.new(1, 0); vGrad.Parent = vFrame

    local hueBar = mk("Frame", { Size = UDim2.new(0, 15, 0, 100), Position = UDim2.new(1, -20, 0, 0), BorderSizePixel = 0 }, pickerPanel)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, hueBar)
    local hueGrad = Instance.new("UIGradient"); hueGrad.Rotation = 90
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
        ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16, 1, 1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
        ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 1, 1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
        ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
    })
    hueGrad.Parent = hueBar

    local h0, s0, v0 = Cfg[key]:ToHSV()
    local hue, sat, val = h0, s0, v0
    local function updateColor()
        local c = Color3.fromHSV(hue, sat, val)
        Cfg[key] = c
        colorBox.BackgroundColor3 = c
        sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    end
    sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)

    local draggingSV, draggingHue = false, false
    sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true end end)
    hueBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end end)
    track(UserInput.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV, draggingHue = false, false end
    end))
    track(UserInput.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if draggingSV then
            local px = math.clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
            local py = math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
            sat, val = px, 1 - py
            updateColor()
        elseif draggingHue then
            local py = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
            hue = py
            updateColor()
        end
    end))

    local expanded = false
    headBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        pickerPanel.Visible = expanded
        container.Size = UDim2.new(1, 0, 0, expanded and 140 or 22)
        cardObj.relayout()
    end)
end

local function makeBindRow(parent, label, key)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0 }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
    mk("TextLabel", { Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(210, 210, 220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, row)
    local keyBtn = mk("TextButton", { Size = UDim2.new(0, 80, 0, 18), Position = UDim2.new(1, -88, 0, 2), BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0, TextColor3 = Color3.fromRGB(220, 220, 230), Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false }, row)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, keyBtn)

    local listening = false
    local function refresh() keyBtn.Text = listening and "..." or Cfg[key].Name end
    refresh()
    keyBtn.MouseButton1Click:Connect(function() listening = not listening; refresh() end)
    track(UserInput.InputBegan:Connect(function(input)
        if not listening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Cfg[key] = input.KeyCode
            listening = false
            refresh()
        end
    end))
end

local espCard = makeFeature("ESP", "espEnabled")
makeSubToggle(espCard.panel, "Full White", "espWhite", espCard)
makeSubSlider(espCard.panel, "Max dist", "espMaxDist", 100, 5000, true)
makeColorPicker(espCard.panel, "espColor", espCard)

local sprintCard = makeFeature("Sprint", "sprintEnabled")
makeBindRow(sprintCard.panel, "Sprint Bind", "sprintBind")

local afkCard = makeFeature("Anti-AFK", "afkEnabled")
makeSubSlider(afkCard.panel, "Interval", "afkInterval", 3, 60, true)

-- character handler
local function onCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then baseWalk = hum.WalkSpeed end
end
if LocalPlayer.Character then onCharacter(LocalPlayer.Character) end
track(LocalPlayer.CharacterAdded:Connect(onCharacter))

-- anti-afk
track(LocalPlayer.Idled:Connect(function()
    if not Cfg.afkEnabled then return end
    local now = os.clock()
    if now - lastAfk < Cfg.afkInterval then return end
    lastAfk = now
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

-- main render
track(RunService.RenderStepped:Connect(function()
    if Cfg.espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do renderPlayer(p) end
        cleanupEsp()
    else
        for _, e in pairs(pool) do hideEsp(e) end
    end
end))

local function releaseSprint()
    if sprintState then
        if vim then pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game) end) end
        sprintState = false
    end
end

track(RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if Cfg.sprintEnabled and hum then
        local wDown  = UserInput:IsKeyDown(Enum.KeyCode.W)
        local moving = hum.MoveDirection.Magnitude > 0.1
        if wDown or moving then
            if not sprintState then
                if vim then pcall(function() vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game) end) end
                sprintState = true
            end
            if hum.WalkSpeed < 24 then hum.WalkSpeed = 24 end
        else
            releaseSprint()
            if hum.WalkSpeed ~= baseWalk then hum.WalkSpeed = baseWalk end
        end
    else
        releaseSprint()
        if hum and hum.WalkSpeed ~= baseWalk then hum.WalkSpeed = baseWalk end
    end
end))

-- hotkeys
track(UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.O then
        Cfg.guiOpen = not Cfg.guiOpen
        gui.Enabled = Cfg.guiOpen
    elseif input.KeyCode == Cfg.sprintBind then
        Cfg.sprintEnabled = not Cfg.sprintEnabled
        sprintCard.refreshToggle()
    end
end))

getgenv().CrezUnload = function()
    releaseSprint()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    for _, e in pairs(pool) do e.n:Remove(); e.d:Remove(); e.h:Remove() end
    pool = {}
    gui:Destroy()
end
