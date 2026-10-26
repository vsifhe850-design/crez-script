-- +1 upgrade per kill — cheat menu (luau, executor)
-- REMOVED: FastBow. Kept: ESP, Sprint, Anti-AFK.

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UserInput   = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local Cfg = {
    espEnabled = true, espName = true, espDist = true, espHealth = true,
    espWhite = false,
    espMaxDist = 2000, espScale = 1.0, nameSize = 18,
    espColor = Color3.fromRGB(0, 255, 0),
    
    sprintEnabled = false,
    sprintBind = Enum.KeyCode.LeftShift,
    afkEnabled = true, afkInterval = 10, guiOpen = true
}

local pool = {}
local sprintState = false
local vim = game:GetService("VirtualInputManager")

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

local vpSize = Camera.ViewportSize

-- ============ ESP ============
local function renderPlayer(player)
    if player == LocalPlayer then return end
    
    local char = player.Character
    if not char then 
        if pool[player] then 
            for _, obj in pairs(pool[player]) do obj.Visible = false end 
        end
        return 
    end
    
    local hp = getHealth(char)
    if hp <= 0 then
        if pool[player] then 
            for _, obj in pairs(pool[player]) do obj.Visible = false end 
        end
        return 
    end

    local part = getAimPart(char)
    if not part then return end
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    
    if dist > Cfg.espMaxDist then
        if pool[player] then 
            for _, obj in pairs(pool[player]) do obj.Visible = false end 
        end
        return 
    end
    
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        if pool[player] then 
            for _, obj in pairs(pool[player]) do obj.Visible = false end 
        end
        return 
    end

    if not pool[player] then
        local e = { n = Drawing.new("Text"), d = Drawing.new("Text"), h = Drawing.new("Text") }
        e.n.Center, e.n.Outline = true, true
        e.d.Center, e.d.Outline = true, true
        e.h.Center, e.h.Outline = true, true
        pool[player] = e
    end

    local e = pool[player]
    local sc = Cfg.espScale
    local y = sp.Y
    local col = Cfg.espWhite and Color3.fromRGB(255, 255, 255) or Cfg.espColor

    if Cfg.espName then
        e.n.Text, e.n.Size, e.n.Position, e.n.Color = player.Name, math.floor(Cfg.nameSize * sc), Vector2.new(sp.X, y - 20*sc), col
        e.n.Visible = true
    else 
        e.n.Visible = false 
    end

    if Cfg.espDist then
        e.d.Text, e.d.Size, e.d.Position, e.d.Color = string.format("[%dm]", math.floor(dist)), math.floor(12 * sc), Vector2.new(sp.X, y + 2), col
        e.d.Visible = true
    else 
        e.d.Visible = false 
    end

    if Cfg.espHealth then
        local heartsRaw = hp / 2
        local hearts = math.round(heartsRaw * 2) / 2
        local text = string.format("%.1f/10", hearts)
        if hearts == math.floor(hearts) then text = string.format("%d/10", hearts) end
        e.h.Text, e.h.Size, e.h.Position, e.h.Color = text, math.floor(14 * sc), Vector2.new(sp.X, y + 18*sc), col
        e.h.Visible = true
    else 
        e.h.Visible = false 
    end
end

local function cleanupEsp()
    local activePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do activePlayers[p] = true end
    
    for p, e in pairs(pool) do
        if not activePlayers[p] then
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

local gui = mk("ScreenGui", {
    Name = "crez_menu", ResetOnSpawn = false, IgnoreGuiInset = true,
    Enabled = Cfg.guiOpen, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, (gethui and gethui()) or game:GetService("CoreGui"))

local root = mk("Frame", {
    Name = "root", Size = UDim2.new(0, 360, 0, 240),
    Position = UDim2.new(0.5, -180, 0.5, -120),
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

local function makeSubToggle(parent, label, key)
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
    btn.MouseButton1Click:Connect(function() Cfg[key] = not Cfg[key]; refresh() end)
end

local function makeSubSlider(parent, label, key, min, max, integer, callback)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0 }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
    mk("TextLabel", { Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(210, 210, 220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, row)
    local valLbl = mk("TextLabel", { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -52, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(120, 220, 160), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium, TextSize = 11 }, row)
    local bar = mk("Frame", { Size = UDim2.new(0, 120, 0, 6), Position = UDim2.new(0, 120, 0, 8), BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
    
    local currentVal = Cfg[key] or 0
    local fill = mk("Frame", { Size = UDim2.new(math.clamp((currentVal - min) / (max - min), 0, 1), 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 200, 140), BorderSizePixel = 0 }, bar)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local function fmt(v) return integer and tostring(math.floor(v)) or string.format("%.2f", v) end
    valLbl.Text = fmt(currentVal)

    local dragging = false
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInput.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local px = math.clamp((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            local v = min + (max - min) * px
            if integer then v = math.floor(v) end
            Cfg[key] = v
            fill.Size = UDim2.new(px, 0, 1, 0)
            valLbl.Text = fmt(v)
            if callback then callback() end
        end
    end)
end

local function makeColorPicker(parent, key, cardObj)
    local container = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22,22,28), BorderSizePixel = 0, ClipsDescendants = true }, parent)
    mk("UICorner", { CornerRadius = UDim.new(0,4) }, container)
    
    local header = mk("TextButton", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, container)
    mk("TextLabel", { Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = "ESP Color", TextColor3 = Color3.fromRGB(210,210,220), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 12 }, container)
    local colorBox = mk("Frame", { Size = UDim2.new(0, 30, 0, 16), Position = UDim2.new(1, -38, 0, 3), BackgroundColor3 = Cfg[key], BorderSizePixel = 0 }, container)
    mk("UICorner", { CornerRadius = UDim.new(0,4) }, colorBox)
    mk("UIStroke", { Color = Color3.fromRGB(80,80,90), Thickness = 1 }, colorBox)

    local pickerPanel = mk("Frame", { Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1, Visible = false }, container)

    local sv = mk("Frame", { Size = UDim2.new(1, -30, 0, 100), Position = UDim2.new(0, 0, 0, 0), BorderSizePixel = 0 }, pickerPanel)
    mk("UICorner", { CornerRadius = UDim.new(0,4) }, sv)
    
    local hGrad = Instance.new("UIGradient")
    hGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
    hGrad.Transparency = NumberSequence.new(0, 1)
    hGrad.Parent = sv
    
    local vFrame = mk("Frame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1 }, sv)
    local vGrad = Instance.new("UIGradient")
    vGrad.Rotation = 90
    vGrad.Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0))
    vGrad.Transparency = NumberSequence.new(1, 0)
    vGrad.Parent = vFrame

    local hueBar = mk("Frame", { Size = UDim2.new(0, 15, 0, 100), Position = UDim2.new(1, -20, 0, 0), BorderSizePixel = 0 }, pickerPanel)
    mk("UICorner", { CornerRadius = UDim.new(0,4) }, hueBar)
    local hueGrad = Instance.new("UIGradient")
    hueGrad.Rotation = 90
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
        ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16,1,1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
        ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66,1,1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1))
    })
    hueGrad.Parent = hueBar

    local hue, sat, val = 0, 1, 1
    
    local function updateColor()
        local c = Color3.fromHSV(hue, sat, val)
        Cfg[key] = c
        colorBox.BackgroundColor3 = c
        sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    end
    updateColor()

    local draggingSV = false
    sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = true end end)
    UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false end end)
    UserInput.InputChanged:Connect(function(i)
        if draggingSV and i.UserInputType == Enum.UserInputType.MouseMovement then
            local px = math.clamp((i.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
            local py = math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
            sat = px
            val = 1 - py
            updateColor()
        end
    end)

    local draggingHue = false
    hueBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true end end)
    UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = false end end)
    UserInput.InputChanged:Connect(function(i)
        if draggingHue and i.UserInputType == Enum.UserInputType.MouseMovement then
            local py = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
            hue = py
            updateColor()
        end
    end)

    local expanded = false
    header.MouseButton1Click:Connect(function()
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
    UserInput.InputBegan:Connect(function(input, gp)
        if not listening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Cfg[key] = input.KeyCode
            listening = false
            refresh()
        end
    end)
end

-- build menu
local espCard = makeFeature("ESP", "espEnabled")
makeSubToggle(espCard.panel, "Full White", "espWhite")
makeSubSlider(espCard.panel, "Max dist", "espMaxDist", 100, 5000, true)
makeColorPicker(espCard.panel, "espColor", espCard)

local sprintCard = makeFeature("Sprint", "sprintEnabled")
makeBindRow(sprintCard.panel, "Sprint Bind", "sprintBind")

local afkCard = makeFeature("Anti-AFK", "afkEnabled")
makeSubSlider(afkCard.panel, "Interval", "afkInterval", 3, 60, true)

-- ============ Main Loop ============
RunService.RenderStepped:Connect(function()
    if Cfg.espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do renderPlayer(p) end
        cleanupEsp()
    else
        for _, e in pairs(pool) do e.n.Visible = false; e.d.Visible = false; e.h.Visible = false end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    -- SPRINT
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if Cfg.sprintEnabled and hum then
        local wDown = UserInput:IsKeyDown(Enum.KeyCode.W)
        local moving = hum.MoveDirection.Magnitude > 0.1
        
        if wDown or moving then
            if not sprintState then
                pcall(function() vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game) end)
                sprintState = true
            end
            if hum.WalkSpeed < 24 then hum.WalkSpeed = 24 end
        else
            if sprintState then
                pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game) end)
                sprintState = false
            end
            if hum.WalkSpeed > 16 then hum.WalkSpeed = 16 end
        end
    else
        if sprintState then
            pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game) end)
            sprintState = false
        end
        if hum and hum.WalkSpeed > 16 then hum.WalkSpeed = 16 end
    end
end)

-- Hotkeys
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.O then
        Cfg.guiOpen = not Cfg.guiOpen
        gui.Enabled = Cfg.guiOpen
    elseif input.KeyCode == Cfg.sprintBind then
        Cfg.sprintEnabled = not Cfg.sprintEnabled
        sprintCard.refreshToggle()
    end
end)

getgenv().CrezUnload = function()
    gui:Destroy()
    if sprintState then
        pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game) end)
    end
    for p, e in pairs(pool) do
        e.n:Remove(); e.d:Remove(); e.h:Remove()
    end
end
