--[[
    ═════════════════════════════════════════════════════════════════════════════════
    NOVA // TRIGGERBOT & ESP
    Stand-alone Lightweight Edition: Triggerbot + CS:GO Player ESP
    ═════════════════════════════════════════════════════════════════════════════════
]]

if _G.NovaTriggerEspLoaded then
    pcall(function()
        if _G.NovaTriggerEspUnload then _G.NovaTriggerEspUnload() end
    end)
    task.wait(0.2)
end
_G.NovaTriggerEspLoaded = true

-- ══════════════════════════════════════════════
--  SERVICES & CORE REFS
-- ══════════════════════════════════════════════
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LP = Players.LocalPlayer
local safeParent = nil
pcall(function()
    if gethui then
        safeParent = gethui()
    elseif syn and syn.protect_gui then
        safeParent = game:GetService("CoreGui")
    else
        safeParent = game:GetService("CoreGui")
    end
end)
if not safeParent then safeParent = LP:WaitForChild("PlayerGui", 5) or game:GetService("CoreGui") end

-- Cleanup table
local allConn = {}
local allGuis = {}

local CONFIG_FILE = "nova_trigger_esp_config.json"
local TOGGLE_KEY = "Delete"
local menuOpen = true

-- ══════════════════════════════════════════════
--  THEME ENGINE
-- ══════════════════════════════════════════════
local accentH, accentS, accentV = 0.58, 0.55, 1.0 -- Default: Sky Blue
local T = {}

local function RebuildTheme()
    T.accent = Color3.fromHSV(accentH, accentS, accentV)
    T.accentDark = Color3.fromHSV(accentH, accentS, math.clamp(accentV * 0.7, 0, 1))
    T.accentOff = Color3.fromRGB(36, 38, 48)
    T.bg = Color3.fromRGB(13, 13, 17)
    T.cardBg = Color3.fromRGB(18, 18, 25)
    T.border = Color3.fromRGB(38, 38, 50)
    T.borderDim = Color3.fromRGB(28, 28, 38)
    T.text = Color3.fromRGB(240, 240, 250)
    T.textDim = Color3.fromRGB(150, 150, 168)
    T.textMuted = Color3.fromRGB(90, 90, 108)
    T.itemHover = Color3.fromRGB(25, 25, 35)
    T.secHeader = Color3.fromRGB(175, 175, 195)
    T.dotsBg = Color3.fromRGB(18, 18, 24)
    T.sidebar = Color3.fromRGB(15, 15, 20)
    T.tabActive = Color3.fromRGB(24, 24, 34)
end
RebuildTheme()

local accentElements = {}
local function TrackAccent(obj, prop)
    table.insert(accentElements, {obj = obj, prop = prop})
end

local ConfigSystem = {
    currentLang = "EN",
    listeners = {},
    pillRefreshers = {},
}

local function ApplyAccentColor()
    RebuildTheme()
    for _, e in ipairs(accentElements) do
        pcall(function() e.obj[e.prop] = T.accent end)
    end
    if ConfigSystem.pillRefreshers then
        for _, fn in ipairs(ConfigSystem.pillRefreshers) do
            pcall(fn)
        end
    end
    if ConfigSystem.UpdateKeybindsHud then
        ConfigSystem.UpdateKeybindsHud()
    end
end

-- ══════════════════════════════════════════════
--  LOCALIZATION SYSTEM (EN / RU)
-- ══════════════════════════════════════════════
ConfigSystem.translations = {
    -- Header
    ["NOVA // TRIGGER & ESP"] = { RU = "NOVA // ТРИГГЕР И ВХ" },
    ["v1.0 • Standalone"] = { RU = "v1.0 • Автономный" },

    -- Tabs
    ["Triggerbot"] = { RU = "Триггербот" },
    ["ESP"] = { RU = "ВХ (ESP)" },
    ["Settings"] = { RU = "Настройки" },

    -- Sections
    ["TRIGGERBOT"] = { RU = "ТРИГГЕРБОТ" },
    ["SETTINGS"] = { RU = "НАСТРОЙКИ" },
    ["PLAYER ESP"] = { RU = "ВХ НА ИГРОКОВ" },
    ["CHAMS STYLE"] = { RU = "СТИЛЬ СИЛУЭТА" },
    ["INTERFACE"] = { RU = "ИНТЕРФЕЙС" },
    ["SYSTEM"] = { RU = "СИСТЕМА" },

    -- Triggerbot Toggles
    ["Triggerbot Toggle"] = { RU = "Триггербот", desc = {
        EN = "Automatically shoots whenever your crosshair targets an enemy player.",
        RU = "Автоматически производит выстрел при наведении прицела на врага."
    }},
    ["Target Lead Circle"] = { RU = "Круг упреждения цели", desc = {
        EN = "Draws target prediction lead circle directly over enemy position.",
        RU = "Отображает маркер упреждения прямо на теле цели."
    }},
    ["Show Hitbox FOV"] = { RU = "Зона хитбокса", desc = {
        EN = "Draws activation circle boundary on screen for triggerbot.",
        RU = "Показывает круг срабатывания автовыстрела на экране."
    }},
    ["Trigger Prediction"] = { RU = "Предикт триггера", desc = {
        EN = "Applies character velocity prediction to trigger detection.",
        RU = "Учитывает скорость движения цели при расчете выстрела."
    }},
    ["Visible Check"] = { RU = "Проверка стен", desc = {
        EN = "Ensures triggerbot only fires when enemy is not hidden behind walls.",
        RU = "Блокирует стрельбу, если враг спрятан за стеной или препятствием."
    }},
    ["Alive Check"] = { RU = "Живой игрок", desc = {
        EN = "Prevents shooting at dead, ragdolled or knocked players.",
        RU = "Блокирует выстрелы по нокаутированным или мертвым игрокам."
    }},

    -- Triggerbot Sliders
    ["Hitbox FOV"] = { RU = "FOV Хитбокса", desc = {
        EN = "Pixel radius around cursor for trigger detection.",
        RU = "Радиус захвата вокруг прицела в пикселях."
    }},
    ["Max Distance"] = { RU = "Макс. Дистанция", desc = {
        EN = "Maximum distance in studs for triggerbot to fire.",
        RU = "Максимальная дистанция работы триггера в студах."
    }},
    ["Delay (ms)"] = { RU = "Задержка (мс)", desc = {
        EN = "Artificial delay in milliseconds before firing.",
        RU = "Задержка перед автовыстрелом в миллисекундах."
    }},
    ["Prediction X"] = { RU = "Предикт X", desc = {
        EN = "Horizontal lead multiplier amount.",
        RU = "Множитель упреждения цели по горизонтали."
    }},
    ["Prediction Y"] = { RU = "Предикт Y", desc = {
        EN = "Vertical lead multiplier amount.",
        RU = "Множитель упреждения цели по вертикали."
    }},

    -- ESP Toggles
    ["Player ESP"] = { RU = "ВХ на игроков", desc = {
        EN = "Enables visual ESP overlays through walls for all players.",
        RU = "Подсвечивает игроков сквозь стены и препятствия."
    }},
    ["Boxes"] = { RU = "2D Боксы", desc = {
        EN = "Draws 2D bounding boxes around players.",
        RU = "Рисует прямоугольные рамки вокруг игроков."
    }},
    ["Health Bar"] = { RU = "Полоска HP", desc = {
        EN = "Displays dynamic health bar next to each player.",
        RU = "Отображает полоску здоровья рядом с игроком."
    }},
    ["Names"] = { RU = "Ники игроков", desc = {
        EN = "Shows player username above their heads.",
        RU = "Отображает ники игроков над головами."
    }},
    ["Distance"] = { RU = "Дистанция", desc = {
        EN = "Displays distance in meters under players' feet.",
        RU = "Показывает расстояние в метрах под ногами игрока."
    }},
    ["Chams"] = { RU = "Чамсы (Силуэт)", desc = {
        EN = "Renders smooth glowing silhouettes through walls.",
        RU = "Подсвечивает модели игроков сквозь стены."
    }},

    -- Settings
    ["Keybinds List"] = { RU = "Список биндов", desc = {
        EN = "Displays on-screen floating HUD with active keybinds.",
        RU = "Показывает плавающее окно с активными биндами."
    }},
    ["Menu Key"] = { RU = "Кнопка меню", desc = {
        EN = "Key used to toggle menu visibility (default Delete).",
        RU = "Клавиша для открытия и закрытия меню (по умолчанию Delete)."
    }},
    ["Language"] = { RU = "Язык интерфейса", desc = {
        EN = "Switch menu language between English and Russian.",
        RU = "Переключение языка меню между English и Русский."
    }},
    ["Reset HUD"] = { RU = "Сброс позиции HUD", desc = {
        EN = "Resets keybinds HUD coordinates back to default.",
        RU = "Сбрасывает положение окна биндов по умолчанию."
    }},
    ["Unload Script"] = { RU = "Выгрузить скрипт", desc = {
        EN = "Completely closes and destroys all GUIs and connections.",
        RU = "Полностью отключает и удаляет скрипт и все окна."
    }},
}

function ConfigSystem.SetLanguage(lang)
    if lang ~= "EN" and lang ~= "RU" then return end
    ConfigSystem.currentLang = lang
    for _, fn in ipairs(ConfigSystem.listeners) do
        pcall(fn, lang)
    end
end

function ConfigSystem.RegisterLabel(lbl, key, isHeader)
    if not lbl or not key then return end
    local function updateText(lang)
        local isRU = (lang == "RU")
        local entry = ConfigSystem.translations[key]
        if isRU and entry and entry.RU then
            lbl.Text = entry.RU
            lbl.Font = isHeader and Enum.Font.GothamBold or Enum.Font.GothamMedium
        else
            lbl.Text = key
            lbl.Font = isHeader and Enum.Font.Arcade or Enum.Font.Arcade
        end
    end
    table.insert(ConfigSystem.listeners, updateText)
    updateText(ConfigSystem.currentLang)
end

-- ══════════════════════════════════════════════
--  GUI HELPERS
-- ══════════════════════════════════════════════
local function Tw(obj, props, t, style, dir)
    local tw = TS:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function Crn(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function Strk(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or T.border
    s.Thickness = th or 1
    s.Transparency = tr or 0
    s.Parent = p
    return s
end

local function Lbl(p, txt, sz, col, font, align, z)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt or ""
    l.TextSize = sz or 11
    l.TextColor3 = col or T.text
    l.Font = font or Enum.Font.Arcade
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.ZIndex = z or 2
    l.Parent = p
    return l
end

-- ══════════════════════════════════════════════
--  STATE MODULES
-- ══════════════════════════════════════════════
local Triggerbot = {
    enabled = false,
    predict = true,
    predictX = 0.14,
    predictY = 0.10,
    tolerance = 16,
    delay = 0,
    maxDistance = 500,
    visibleCheck = false,
    healthCheck = true,
    lastShot = 0,
    shooting = false,
    showFov = false,
    showTargetCircle = true,
    conn = nil,
    targetCircle = nil,
    targetStroke = nil,
    targetDot = nil,
    fovCircle = nil,
    fovStroke = nil,
    fovLabel = nil,
}

local ESP = {
    enabled = false,
    box = true,
    health = true,
    name = true,
    dist = true,
    chams = false,
    chamsMode = "VisCheck", -- "VisCheck", "Solid", "Glow", "Outline"
}

local featureBinds = {} -- [name] = { key = "V", shortKey = "V", mode = "Toggle", toggleObj = ... }
local listeningTarget = nil
local FormatKeyName = nil

local function FormatKey(k)
    if not k then return "..." end
    if k == "MouseButton1" then return "MB1" end
    if k == "MouseButton2" then return "MB2" end
    if k == "MouseButton3" then return "MB3" end
    if k == "MouseButton4" or k == "MouseBackButton" then return "MB4" end
    if k == "MouseButton5" or k == "MouseForwardButton" then return "MB5" end
    return tostring(k):gsub("Enum%.KeyCode%.", "")
end
FormatKeyName = FormatKey

-- ══════════════════════════════════════════════
--  TRIGGERBOT IMPLEMENTATION
-- ══════════════════════════════════════════════
do
    local trigSG = Instance.new("ScreenGui")
    trigSG.Name = "NOVA_TriggerVisuals"
    trigSG.ResetOnSpawn = false
    trigSG.IgnoreGuiInset = true
    trigSG.DisplayOrder = 9998
    trigSG.ZIndexBehavior = Enum.ZIndexBehavior.Global
    trigSG.Parent = safeParent
    table.insert(allGuis, trigSG)

    -- 1. Hitbox FOV Visual
    local fovF = Instance.new("Frame")
    fovF.Name = "TriggerHitboxFOV"
    fovF.AnchorPoint = Vector2.new(0.5, 0.5)
    fovF.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovF.Size = UDim2.new(0, 32, 0, 32)
    fovF.BackgroundTransparency = 1
    fovF.Visible = false
    fovF.Parent = trigSG
    Crn(fovF, 9999)
    local fovS = Strk(fovF, T.accent, 1.5, 0.25)
    TrackAccent(fovS, "Color")

    local fovL = Lbl(fovF, "TRIGGER", 8, T.accent, Enum.Font.Arcade, Enum.TextXAlignment.Center, 5)
    fovL.Size = UDim2.new(1, 0, 0, 10)
    fovL.Position = UDim2.new(0, 0, 1, 2)
    TrackAccent(fovL, "TextColor3")

    Triggerbot.fovCircle = fovF
    Triggerbot.fovStroke = fovS
    Triggerbot.fovLabel = fovL

    -- 2. Target Lead Circle Visual
    local tc = Instance.new("Frame")
    tc.Name = "TargetLeadCircle"
    tc.AnchorPoint = Vector2.new(0.5, 0.5)
    tc.Size = UDim2.new(0, 22, 0, 22)
    tc.BackgroundTransparency = 1
    tc.Visible = false
    tc.Parent = trigSG
    Crn(tc, 9999)
    local tcS = Strk(tc, T.accent, 1.5, 0)
    TrackAccent(tcS, "Color")

    local tcDot = Instance.new("Frame")
    tcDot.Size = UDim2.new(0, 4, 0, 4)
    tcDot.AnchorPoint = Vector2.new(0.5, 0.5)
    tcDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    tcDot.BackgroundColor3 = T.accent
    tcDot.BorderSizePixel = 0
    tcDot.Parent = tc
    Crn(tcDot, 9999)
    TrackAccent(tcDot, "BackgroundColor3")

    Triggerbot.targetCircle = tc
    Triggerbot.targetStroke = tcS
    Triggerbot.targetDot = tcDot

    local function isTriggerDeadOrKO(char, hum)
        if not hum or not hum.Parent or hum.Health <= 0 then return true end
        if hum:GetState() == Enum.HumanoidStateType.Dead then return true end
        local be = char:FindFirstChild("BodyEffects")
        if be then
            local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO") or be:FindFirstChild("Knocked")
            if ko and (ko.Value == true or ko.Value == 1) then return true end
            local dead = be:FindFirstChild("Dead")
            if dead and (dead.Value == true or dead.Value == 1) then return true end
            local grab = be:FindFirstChild("Grabbed")
            if grab and (grab.Value == true or grab.Value == 1) then return true end
        end
        if char:FindFirstChild("GRABBING_CONSTRAINT") then return true end
        if char:FindFirstChild("Ragdoll") or char:FindFirstChild("KO") or char:FindFirstChild("K.O") or char:FindFirstChild("Knocked") then return true end
        if char:GetAttribute("Dead") == true or char:GetAttribute("K.O") == true or char:GetAttribute("KO") == true or char:GetAttribute("Knocked") == true then
            return true
        end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if hrp and hrp.CFrame.UpVector.Y < 0.35 then return true end
        if hum.PlatformStand and hrp and hrp.CFrame.UpVector.Y < 0.5 then return true end
        return false
    end

    local trigRayParams = RaycastParams.new()
    trigRayParams.FilterType = Enum.RaycastFilterType.Exclude
    trigRayParams.IgnoreWater = true

    local function isTriggerPartVisible(part, char)
        if not Triggerbot.visibleCheck then return true end
        if not part or not char then return false end
        local cam = workspace.CurrentCamera
        if not cam then return false end
        local camPos = cam.CFrame.Position
        local targetPos = part.Position
        local dir = targetPos - camPos
        if dir.Magnitude < 0.1 then return true end

        local ignoreList = {cam}
        if LP.Character then table.insert(ignoreList, LP.Character) end
        trigRayParams.FilterDescendantsInstances = ignoreList

        local hit = workspace:Raycast(camPos, dir, trigRayParams)
        if not hit then return true end
        return hit.Instance:IsDescendantOf(char)
    end

    local coreTriggerParts = {
        "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart",
        "Right Arm", "Left Arm", "Right Leg", "Left Leg",
        "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg"
    }

    local function TriggerShoot()
        if Triggerbot.shooting then return end
        local now = tick()
        local delaySec = (Triggerbot.delay or 0) / 1000
        if now - (Triggerbot.lastShot or 0) < math.max(0.08, delaySec + 0.05) then
            return
        end
        Triggerbot.lastShot = now
        Triggerbot.shooting = true

        task.spawn(function()
            if delaySec > 0 then task.wait(delaySec) end
            if not Triggerbot.enabled then
                Triggerbot.shooting = false
                return
            end

            local char = LP.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end

            if mouse1click then
                pcall(mouse1click)
            elseif mouse1press and mouse1release then
                pcall(mouse1press)
                task.wait(0.01)
                pcall(mouse1release)
            elseif VirtualInputManager then
                local mPos = UIS:GetMouseLocation()
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(mPos.X, mPos.Y, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(mPos.X, mPos.Y, 0, false, game, 0)
                end)
            end

            task.wait(0.04)
            Triggerbot.shooting = false
        end)
    end

    local function UpdateTriggerbotLogic()
        local cam = workspace.CurrentCamera
        if not cam then
            tc.Visible = false
            fovF.Visible = false
            return
        end

        local mPos = UIS:GetMouseLocation()

        -- Update FOV circle position and radius
        if Triggerbot.showFov then
            local r = (Triggerbot.tolerance or 16) * 2
            fovF.Size = UDim2.new(0, r, 0, r)
            fovF.Position = UDim2.new(0, mPos.X, 0, mPos.Y)
            fovF.Visible = true
        else
            fovF.Visible = false
        end

        if menuOpen then
            tc.Visible = false
            return
        end

        local camCF = cam.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector
        local maxDist = Triggerbot.maxDistance or 500
        local baseTol = Triggerbot.tolerance or 16

        local px = (Triggerbot.predict and Triggerbot.predictX) or 0
        local py = (Triggerbot.predict and Triggerbot.predictY) or 0
        local doPredict = Triggerbot.predict and (px > 0 or py > 0)

        local bestPlr = nil
        local bestScreenPos = nil
        local bestDist2D = math.huge
        local shouldShoot = false

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Parent and not (Triggerbot.healthCheck and isTriggerDeadOrKO(char, hum)) then
                    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if hrp then
                        local toHrp = hrp.Position - camPos
                        local d3d = toHrp.Magnitude
                        if d3d <= (maxDist + 10) and camLook:Dot(toHrp.Unit) > 0.05 then
                            local rawVel = hrp.AssemblyLinearVelocity or hrp.Velocity
                            local hasVel = (doPredict and rawVel and rawVel.Magnitude > 0.1)
                            local vel = hasVel and Vector3.new(
                                math.clamp(rawVel.X, -150, 150),
                                math.clamp(rawVel.Y, -60, 60),
                                math.clamp(rawVel.Z, -150, 150)
                            ) or Vector3.zero
                            local predOffset = hasVel and Vector3.new(vel.X * px, vel.Y * py, vel.Z * px) or Vector3.zero

                            for _, pn in ipairs(coreTriggerParts) do
                                local p = char:FindFirstChild(pn)
                                if p and p:IsA("BasePart") then
                                    local targetPos = p.Position + predOffset
                                    local screenPos, pOnScreen = cam:WorldToViewportPoint(targetPos)
                                    if pOnScreen and screenPos.Z > 0 then
                                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - mPos).Magnitude
                                        if dist2D < bestDist2D then
                                            bestDist2D = dist2D
                                            bestPlr = plr
                                            bestScreenPos = screenPos
                                        end

                                        local isMain = (pn == "Head" or pn == "UpperTorso" or pn == "Torso" or pn == "HumanoidRootPart")
                                        local partTol = isMain and baseTol or (baseTol * 0.75)
                                        if dist2D <= partTol then
                                            if (not Triggerbot.visibleCheck) or isTriggerPartVisible(p, char) then
                                                shouldShoot = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Update Lead Circle
        if Triggerbot.showTargetCircle and bestPlr and bestScreenPos and bestDist2D <= 240 then
            tc.Position = UDim2.new(0, math.floor(bestScreenPos.X + 0.5), 0, math.floor(bestScreenPos.Y + 0.5))
            tc.Visible = true
            if shouldShoot then
                local lockCol = Color3.fromRGB(0, 255, 140)
                tcS.Color = lockCol
                tcDot.BackgroundColor3 = lockCol
                tc.Size = UDim2.new(0, 26, 0, 26)
            else
                tcS.Color = T.accent
                tcDot.BackgroundColor3 = T.accent
                tc.Size = UDim2.new(0, 22, 0, 22)
            end
        else
            tc.Visible = false
        end

        if Triggerbot.enabled and shouldShoot and not Triggerbot.shooting then
            local char = LP.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                TriggerShoot()
            end
        end
    end

    local function UpdateTriggerbotConn()
        local shouldRun = (Triggerbot.enabled == true) or (Triggerbot.showTargetCircle == true) or (Triggerbot.showFov == true)
        if shouldRun then
            if not Triggerbot.conn then
                local lastCheck = 0
                Triggerbot.conn = RS.RenderStepped:Connect(function()
                    local now = tick()
                    if now - lastCheck < 0.012 then return end
                    lastCheck = now
                    UpdateTriggerbotLogic()
                end)
            end
        else
            if Triggerbot.conn then
                Triggerbot.conn:Disconnect()
                Triggerbot.conn = nil
            end
            tc.Visible = false
            fovF.Visible = false
        end
    end

    Triggerbot.UpdateConnection = UpdateTriggerbotConn
    UpdateTriggerbotConn()
end

-- ══════════════════════════════════════════════
--  PLAYER ESP IMPLEMENTATION
-- ══════════════════════════════════════════════
local espContainer = {}

local function ClearESPForPlayer(plr)
    if espContainer[plr] then
        for _, obj in ipairs(espContainer[plr]) do
            pcall(function()
                if typeof(obj) == "RBXScriptConnection" then
                    obj:Disconnect()
                else
                    obj:Destroy()
                end
            end)
        end
        espContainer[plr] = nil
    end
    if plr.Character then
        pcall(function()
            local hl = plr.Character:FindFirstChild("NOVA_Highlight")
            if hl then hl:Destroy() end
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local b = hrp:FindFirstChild("NOVA_ESP_Box")
                if b then b:Destroy() end
                local d = hrp:FindFirstChild("NOVA_ESP_Dist")
                if d then d:Destroy() end
                local hp = hrp:FindFirstChild("NOVA_ESP_HP")
                if hp then hp:Destroy() end
                local n = hrp:FindFirstChild("NOVA_ESP_Name")
                if n then n:Destroy() end
            end
        end)
    end
end

local function ApplyESPToPlayer(plr)
    if plr == LP then return end
    ClearESPForPlayer(plr)
    if not ESP.enabled then return end

    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 1)
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 1)
    if not head or not hrp then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end

    local objects = {}

    -- 1. CHAMS
    if ESP.chams then
        pcall(function()
            local hl = Instance.new("Highlight")
            hl.Name = "NOVA_Highlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = char
            table.insert(objects, hl)

            local mode = ESP.chamsMode or "VisCheck"
            if mode == "Solid" then
                hl.FillColor = T.accent
                hl.OutlineColor = Color3.fromRGB(0, 0, 0)
                hl.FillTransparency = 0.20
                hl.OutlineTransparency = 0
                TrackAccent(hl, "FillColor")
            elseif mode == "Glow" then
                hl.FillColor = T.accent
                hl.OutlineColor = T.accent
                hl.FillTransparency = 0.35
                hl.OutlineTransparency = 0
                TrackAccent(hl, "FillColor")
                TrackAccent(hl, "OutlineColor")
            elseif mode == "Outline" then
                hl.FillColor = Color3.fromRGB(0, 0, 0)
                hl.OutlineColor = T.accent
                hl.FillTransparency = 1
                hl.OutlineTransparency = 0
                TrackAccent(hl, "OutlineColor")
            else -- VisCheck
                hl.FillTransparency = 0.20
                hl.OutlineColor = Color3.fromRGB(0, 0, 0)
                hl.OutlineTransparency = 0
                local function checkVis()
                    if not (hl.Parent and char.Parent and head.Parent) then return end
                    local cam = workspace.CurrentCamera
                    if not cam then return end
                    local origin = cam.CFrame.Position
                    local dir = head.Position - origin
                    local rp = RaycastParams.new()
                    rp.FilterType = Enum.RaycastFilterType.Exclude
                    local ign = {cam}
                    if LP.Character then table.insert(ign, LP.Character) end
                    rp.FilterDescendantsInstances = ign
                    local hit = workspace:Raycast(origin, dir, rp)
                    local isVis = (not hit) or hit.Instance:IsDescendantOf(char)
                    hl.FillColor = isVis and Color3.fromRGB(0, 255, 120) or T.accent
                end
                checkVis()
                task.spawn(function()
                    while ESP.enabled and ESP.chams and hl.Parent and char.Parent do
                        checkVis()
                        task.wait(0.2)
                    end
                end)
            end
        end)
    end

    -- 2. 2D BOX
    if ESP.box then
        pcall(function()
            local bb = Instance.new("BillboardGui")
            bb.Name = "NOVA_ESP_Box"
            bb.Size = UDim2.new(4.0, 0, 5.0, 0)
            bb.StudsOffset = Vector3.new(0, -0.15, 0)
            bb.AlwaysOnTop = true
            bb.ResetOnSpawn = false
            bb.LightInfluence = 0
            bb.MaxDistance = 2500
            bb.Adornee = hrp
            bb.Parent = hrp
            table.insert(objects, bb)

            local bf = Instance.new("Frame")
            bf.Size = UDim2.new(1, 0, 1, 0)
            bf.BackgroundTransparency = 1
            bf.BorderSizePixel = 0
            bf.Parent = bb

            local bs = Strk(bf, T.accent, 1, 0)
            TrackAccent(bs, "Color")
        end)
    end

    -- 3. HEALTH BAR
    if ESP.health and hum then
        pcall(function()
            local hpBB = Instance.new("BillboardGui")
            hpBB.Name = "NOVA_ESP_HP"
            hpBB.Size = UDim2.new(0, 3, 4.8, 0)
            hpBB.StudsOffset = Vector3.new(-2.3, -0.15, 0)
            hpBB.AlwaysOnTop = true
            hpBB.ResetOnSpawn = false
            hpBB.LightInfluence = 0
            hpBB.MaxDistance = 2500
            hpBB.Adornee = hrp
            hpBB.Parent = hrp
            table.insert(objects, hpBB)

            local hpBg = Instance.new("Frame")
            hpBg.Size = UDim2.new(1, 0, 1, 0)
            hpBg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
            hpBg.BackgroundTransparency = 0.1
            hpBg.BorderSizePixel = 0
            hpBg.Parent = hpBB
            Strk(hpBg, Color3.fromRGB(0, 0, 0), 1, 0)

            local hpFill = Instance.new("Frame")
            hpFill.AnchorPoint = Vector2.new(0, 1)
            hpFill.Position = UDim2.new(0, 0, 1, 0)
            hpFill.Size = UDim2.new(1, 0, 1, 0)
            hpFill.BorderSizePixel = 0
            hpFill.Parent = hpBg

            local hpLbl = Instance.new("TextLabel")
            hpLbl.Size = UDim2.new(0, 32, 0, 10)
            hpLbl.AnchorPoint = Vector2.new(1, 0.5)
            hpLbl.Position = UDim2.new(0, -2, 0, 0)
            hpLbl.BackgroundTransparency = 1
            hpLbl.Font = Enum.Font.GothamBold
            hpLbl.TextSize = 8
            hpLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            hpLbl.TextStrokeTransparency = 0
            hpLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            hpLbl.TextXAlignment = Enum.TextXAlignment.Right
            hpLbl.Visible = false
            hpLbl.Parent = hpBg

            local function UpdateHP()
                if not (hpBB.Parent and hrp.Parent and hum.Parent) then return end
                local mH = math.max(hum.MaxHealth, 1)
                local cH = math.clamp(hum.Health, 0, mH)
                local pct = math.clamp(cH / mH, 0, 1)
                hpFill.Size = UDim2.new(1, 0, pct, 0)
                local col = pct > 0.5
                    and Color3.fromRGB(math.floor((1 - pct) * 2 * 255), 235, 45)
                    or Color3.fromRGB(245, math.floor(pct * 2 * 215), 35)
                hpFill.BackgroundColor3 = col
                if cH < mH then
                    hpLbl.Text = tostring(math.floor(cH))
                    hpLbl.Position = UDim2.new(0, -2, 1 - pct, 0)
                    hpLbl.TextColor3 = col
                    hpLbl.Visible = true
                else
                    hpLbl.Visible = false
                end
            end

            UpdateHP()
            table.insert(objects, hum.HealthChanged:Connect(UpdateHP))
        end)
    end

    -- 4. NAME
    if ESP.name then
        pcall(function()
            local nameBB = Instance.new("BillboardGui")
            nameBB.Name = "NOVA_ESP_Name"
            nameBB.Size = UDim2.new(0, 130, 0, 14)
            nameBB.StudsOffset = Vector3.new(0, 3.2, 0)
            nameBB.AlwaysOnTop = true
            nameBB.ResetOnSpawn = false
            nameBB.LightInfluence = 0
            nameBB.MaxDistance = 2500
            nameBB.Adornee = hrp
            nameBB.Parent = hrp
            table.insert(objects, nameBB)

            local dName = plr.DisplayName
            local uName = plr.Name
            local txt = (dName and dName ~= "" and dName ~= uName) and dName or uName
            local nLbl = Lbl(nameBB, txt, 8, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
            nLbl.Size = UDim2.new(1, 0, 1, 0)
            nLbl.TextStrokeTransparency = 0
            nLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        end)
    end

    -- 5. DISTANCE
    if ESP.dist then
        pcall(function()
            local distBB = Instance.new("BillboardGui")
            distBB.Name = "NOVA_ESP_Dist"
            distBB.Size = UDim2.new(0, 80, 0, 12)
            distBB.StudsOffset = Vector3.new(0, -3.2, 0)
            distBB.AlwaysOnTop = true
            distBB.ResetOnSpawn = false
            distBB.LightInfluence = 0
            distBB.MaxDistance = 2500
            distBB.Adornee = hrp
            distBB.Parent = hrp
            table.insert(objects, distBB)

            local dLbl = Lbl(distBB, "[0m]", 8, Color3.fromRGB(235, 235, 245), Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
            dLbl.Size = UDim2.new(1, 0, 1, 0)
            dLbl.TextStrokeTransparency = 0
            dLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

            task.spawn(function()
                while ESP.enabled and ESP.dist and distBB.Parent and hrp.Parent do
                    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                        local studs = (LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                        local meters = math.floor(studs * 0.28 + 0.5)
                        dLbl.Text = "[" .. tostring(meters) .. "m]"
                    end
                    task.wait(0.25)
                end
            end)
        end)
    end

    if hum then
        table.insert(objects, hum.Died:Connect(function() ClearESPForPlayer(plr) end))
    end
    espContainer[plr] = objects
end

local function RefreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            if ESP.enabled then
                ApplyESPToPlayer(plr)
            else
                ClearESPForPlayer(plr)
            end
        end
    end
end

table.insert(allConn, Players.PlayerAdded:Connect(function(plr)
    if plr ~= LP then
        table.insert(allConn, plr.CharacterAdded:Connect(function()
            if ESP.enabled then
                task.wait(0.5)
                ApplyESPToPlayer(plr)
            end
        end))
    end
end))

table.insert(allConn, Players.PlayerRemoving:Connect(function(plr)
    ClearESPForPlayer(plr)
end))

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP and p.Character then
        table.insert(allConn, p.CharacterAdded:Connect(function()
            if ESP.enabled then
                task.wait(0.5)
                ApplyESPToPlayer(p)
            end
        end))
    end
end

-- ══════════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ══════════════════════════════════════════════
local function SaveConfig()
    pcall(function()
        if not writefile then return end
        local bindsData = {}
        for k, v in pairs(featureBinds) do
            if v and v.key then
                bindsData[k] = { key = v.key, mode = v.mode or "Toggle" }
            end
        end
        local data = {
            accentH = accentH, accentS = accentS, accentV = accentV,
            language = ConfigSystem.currentLang,
            toggleKey = TOGGLE_KEY,
            trigger = {
                enabled = Triggerbot.enabled,
                predict = Triggerbot.predict,
                predictX = Triggerbot.predictX,
                predictY = Triggerbot.predictY,
                tolerance = Triggerbot.tolerance,
                delay = Triggerbot.delay,
                maxDistance = Triggerbot.maxDistance,
                visibleCheck = Triggerbot.visibleCheck,
                healthCheck = Triggerbot.healthCheck,
                showFov = Triggerbot.showFov,
                showTargetCircle = Triggerbot.showTargetCircle,
            },
            esp = {
                enabled = ESP.enabled,
                box = ESP.box,
                health = ESP.health,
                name = ESP.name,
                dist = ESP.dist,
                chams = ESP.chams,
                chamsMode = ESP.chamsMode,
            },
            binds = bindsData,
        }
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function LoadConfig()
    pcall(function()
        if not (isfile and readfile and isfile(CONFIG_FILE)) then return end
        local raw = readfile(CONFIG_FILE)
        local data = HttpService:JSONDecode(raw)
        if type(data) ~= "table" then return end
        if data.accentH then accentH = tonumber(data.accentH) or accentH end
        if data.accentS then accentS = tonumber(data.accentS) or accentS end
        if data.accentV then accentV = tonumber(data.accentV) or accentV end
        if data.language then ConfigSystem.SetLanguage(data.language) end
        if data.toggleKey then TOGGLE_KEY = tostring(data.toggleKey) end
        if type(data.trigger) == "table" then
            for k, v in pairs(data.trigger) do
                if Triggerbot[k] ~= nil then Triggerbot[k] = v end
            end
        end
        if type(data.esp) == "table" then
            for k, v in pairs(data.esp) do
                if ESP[k] ~= nil then ESP[k] = v end
            end
        end
    end)
end
LoadConfig()

-- ══════════════════════════════════════════════
--  MENU GUI CONSTRUCTION
-- ══════════════════════════════════════════════
local mainSG = Instance.new("ScreenGui")
mainSG.Name = "NOVA_TriggerAndEsp_GUI"
mainSG.ResetOnSpawn = false
mainSG.IgnoreGuiInset = true
mainSG.DisplayOrder = 9999
mainSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainSG.Parent = safeParent
table.insert(allGuis, mainSG)

local WIN_W = 520
local WIN_H = 340
local win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
win.BackgroundColor3 = T.bg
win.BorderSizePixel = 0
win.ClipsDescendants = false
win.Parent = mainSG
Crn(win, 8)
local winStroke = Strk(win, T.border, 1, 0)

-- Topbar
local TOP_H = 36
local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, TOP_H)
topbar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
topbar.BorderSizePixel = 0
topbar.Parent = win
Crn(topbar, 8)

local topbarSquare = Instance.new("Frame")
topbarSquare.Size = UDim2.new(1, 0, 0, 8)
topbarSquare.Position = UDim2.new(0, 0, 1, -8)
topbarSquare.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
topbarSquare.BorderSizePixel = 0
topbarSquare.Parent = topbar

local topbarLine = Instance.new("Frame")
topbarLine.Size = UDim2.new(1, 0, 0, 1)
topbarLine.Position = UDim2.new(0, 0, 1, 0)
topbarLine.BackgroundColor3 = T.border
topbarLine.BorderSizePixel = 0
topbarLine.Parent = topbar

local titleL = Lbl(topbar, "NOVA // TRIGGER & ESP", 12, T.text, Enum.Font.Arcade, Enum.TextXAlignment.Left, 3)
titleL.Position = UDim2.new(0, 12, 0, 0)
titleL.Size = UDim2.new(0.6, 0, 1, 0)
ConfigSystem.RegisterLabel(titleL, "NOVA // TRIGGER & ESP", true)

local subTitleL = Lbl(topbar, "v1.0 • Standalone", 9, T.accent, Enum.Font.Arcade, Enum.TextXAlignment.Right, 3)
subTitleL.Position = UDim2.new(0.4, 0, 0, 0)
subTitleL.Size = UDim2.new(0.57, -10, 1, 0)
TrackAccent(subTitleL, "TextColor3")
ConfigSystem.RegisterLabel(subTitleL, "v1.0 • Standalone", false)

-- Tooltip System (Strictly restricted to Text hover)
local tooltipF = Instance.new("Frame")
tooltipF.Size = UDim2.new(0, 210, 0, 0)
tooltipF.AutomaticSize = Enum.AutomaticSize.Y
tooltipF.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
tooltipF.BorderSizePixel = 0
tooltipF.ZIndex = 85
tooltipF.Visible = false
tooltipF.Parent = win
Crn(tooltipF, 5)
Strk(tooltipF, T.border, 1, 0)

local tipPad = Instance.new("UIPadding")
tipPad.PaddingLeft = UDim.new(0, 8); tipPad.PaddingRight = UDim.new(0, 8)
tipPad.PaddingTop = UDim.new(0, 6); tipPad.PaddingBottom = UDim.new(0, 6)
tipPad.Parent = tooltipF

local tipLL = Instance.new("UIListLayout")
tipLL.SortOrder = Enum.SortOrder.LayoutOrder
tipLL.Padding = UDim.new(0, 3)
tipLL.Parent = tooltipF

local tipTitle = Lbl(tooltipF, "Tooltip Title", 10, T.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 86)
tipTitle.Size = UDim2.new(1, 0, 0, 12)
TrackAccent(tipTitle, "TextColor3")

local tipDesc = Lbl(tooltipF, "Description goes here.", 9, Color3.fromRGB(200, 200, 220), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 86)
tipDesc.Size = UDim2.new(1, 0, 0, 0)
tipDesc.AutomaticSize = Enum.AutomaticSize.Y
tipDesc.TextWrapped = true

local currentTipKey = nil

local function ShowTooltip(key)
    currentTipKey = key
    local isRU = (ConfigSystem.currentLang == "RU")
    local entry = ConfigSystem.translations[key]
    local tTitle = key
    local tDesc = nil
    if entry then
        if isRU and entry.RU then tTitle = entry.RU end
        if entry.desc then
            tDesc = isRU and entry.desc.RU or entry.desc.EN
        end
    end
    if not tDesc or tDesc == "" then
        tooltipF.Visible = false
        return
    end

    tipTitle.Text = tTitle
    tipDesc.Text = tDesc

    local mPos = UIS:GetMouseLocation()
    local wPos = win.AbsolutePosition
    local wSize = win.AbsoluteSize
    local rx = mPos.X - wPos.X + 12
    local ry = mPos.Y - wPos.Y + 12
    if rx + 220 > wSize.X then rx = mPos.X - wPos.X - 225 end
    if ry + 50 > wSize.Y then ry = mPos.Y - wPos.Y - 55 end
    tooltipF.Position = UDim2.new(0, math.max(4, rx), 0, math.max(4, ry))
    tooltipF.Visible = true
end

local function HideTooltip()
    currentTipKey = nil
    tooltipF.Visible = false
end

table.insert(allConn, UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and currentTipKey and tooltipF.Visible then
        local mPos = UIS:GetMouseLocation()
        local wPos = win.AbsolutePosition
        local wSize = win.AbsoluteSize
        local rx = mPos.X - wPos.X + 12
        local ry = mPos.Y - wPos.Y + 12
        if rx + 220 > wSize.X then rx = mPos.X - wPos.X - 225 end
        if ry + 50 > wSize.Y then ry = mPos.Y - wPos.Y - 55 end
        tooltipF.Position = UDim2.new(0, math.max(4, rx), 0, math.max(4, ry))
    end
end))

-- Dragging
do
    local dragging, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
            HideTooltip()
        end
    end)
    table.insert(allConn, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    table.insert(allConn, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

-- Body & Sidebar
local SIDE_W = 125
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -TOP_H)
body.Position = UDim2.new(0, 0, 0, TOP_H)
body.BackgroundTransparency = 1
body.ClipsDescendants = true
body.Parent = win

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, SIDE_W, 1, 0)
sidebar.BackgroundColor3 = T.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = body
Crn(sidebar, 8)

local sideCover = Instance.new("Frame")
sideCover.Size = UDim2.new(1, 0, 0, 10)
sideCover.BackgroundColor3 = T.sidebar
sideCover.BorderSizePixel = 0
sideCover.ZIndex = 2
sideCover.Parent = sidebar

local sideDiv = Instance.new("Frame")
sideDiv.Size = UDim2.new(0, 1, 1, 0)
sideDiv.Position = UDim2.new(1, -1, 0, 0)
sideDiv.BackgroundColor3 = T.border
sideDiv.BorderSizePixel = 0
sideDiv.ZIndex = 3
sideDiv.Parent = sidebar

local sideScroll = Instance.new("Frame")
sideScroll.Size = UDim2.new(1, -1, 1, 0)
sideScroll.BackgroundTransparency = 1
sideScroll.ClipsDescendants = false
sideScroll.ZIndex = 2
sideScroll.Parent = sidebar

local sideLL = Instance.new("UIListLayout")
sideLL.SortOrder = Enum.SortOrder.LayoutOrder
sideLL.Padding = UDim.new(0, 3)
sideLL.Parent = sideScroll

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 7)
sidePad.PaddingRight = UDim.new(0, 7)
sidePad.Parent = sideScroll

local contentF = Instance.new("Frame")
contentF.Size = UDim2.new(1, -SIDE_W - 1, 1, 0)
contentF.Position = UDim2.new(0, SIDE_W + 1, 0, 0)
contentF.BackgroundTransparency = 1
contentF.ClipsDescendants = true
contentF.Parent = body

local tabPages = {}
local currentTab = "Triggerbot"
local tabButtons = {}

local function SwitchTab(name)
    if currentTab == name then return end
    HideTooltip()
    local old = tabButtons[currentTab]
    if old then
        Tw(old.btn, {BackgroundTransparency = 1}, 0.12)
        Tw(old.bar, {BackgroundTransparency = 1}, 0.12)
        Tw(old.lbl, {TextColor3 = T.textMuted}, 0.12)
    end
    if tabPages[currentTab] then
        tabPages[currentTab].frame.Visible = false
    end
    currentTab = name
    local tb = tabButtons[name]
    if tb then
        Tw(tb.btn, {BackgroundTransparency = 0}, 0.12)
        Tw(tb.bar, {BackgroundTransparency = 0}, 0.12)
        Tw(tb.lbl, {TextColor3 = T.text}, 0.12)
    end
    if tabPages[name] then
        tabPages[name].frame.Visible = true
        tabPages[name].frame.CanvasPosition = Vector2.zero
    end
end

local function CreateTabButton(name, order)
    local isActive = (name == currentTab)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = T.tabActive
    btn.BackgroundTransparency = isActive and 0 or 1
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 2
    btn.Parent = sideScroll
    Crn(btn, 5)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 2, 0.6, 0)
    bar.Position = UDim2.new(0, 0, 0.2, 0)
    bar.BackgroundColor3 = T.accent
    bar.BackgroundTransparency = isActive and 0 or 1
    bar.BorderSizePixel = 0
    bar.ZIndex = 3
    bar.Parent = btn
    Crn(bar, 1)
    TrackAccent(bar, "BackgroundColor3")

    local lbl = Lbl(btn, name, 11, isActive and T.text or T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 3)
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    ConfigSystem.RegisterLabel(lbl, name, true)

    tabButtons[name] = {btn = btn, bar = bar, lbl = lbl}

    btn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)
    btn.MouseEnter:Connect(function()
        if currentTab ~= name then
            Tw(btn, {BackgroundTransparency = 0.88}, 0.1)
            Tw(lbl,  {TextColor3 = T.textDim}, 0.1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= name then
            Tw(btn, {BackgroundTransparency = 1}, 0.1)
            Tw(lbl,  {TextColor3 = T.textMuted}, 0.1)
        end
    end)
end

local function CreateTabPage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, -16, 1, -14)
    sf.Position = UDim2.new(0, 8, 0, 7)
    sf.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = T.accent
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = (name == currentTab)
    sf.ClipsDescendants = true
    sf.Parent = contentF
    Crn(sf, 7)
    Strk(sf, T.border, 1, 0)
    TrackAccent(sf, "ScrollBarImageColor3")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = sf

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = sf

    -- Auto hide scrollbar if not overflowing
    sf.ScrollBarImageTransparency = 1
    local lastScroll = 0
    local isFading = false
    local function showBar()
        if sf.AbsoluteCanvasSize.Y <= sf.AbsoluteWindowSize.Y + 2 then
            sf.ScrollBarImageTransparency = 1
            return
        end
        lastScroll = tick()
        Tw(sf, {ScrollBarImageTransparency = 0}, 0.15)
        if not isFading then
            isFading = true
            task.spawn(function()
                while (tick() - lastScroll) < 2 do task.wait(0.2) end
                Tw(sf, {ScrollBarImageTransparency = 1}, 0.35)
                isFading = false
            end)
        end
    end
    sf:GetPropertyChangedSignal("CanvasPosition"):Connect(showBar)
    sf.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseWheel then showBar() end
    end)

    tabPages[name] = {frame = sf, order = 0}
end

CreateTabPage("Triggerbot")
CreateTabPage("ESP")
CreateTabPage("Settings")

CreateTabButton("Triggerbot", 1)
CreateTabButton("ESP", 2)
CreateTabButton("Settings", 3)

-- ══════════════════════════════════════════════
--  UI CONTROLS: SECTION, TOGGLE, SLIDER
-- ══════════════════════════════════════════════
local function AddSection(tabName, title)
    local pg = tabPages[tabName]
    pg.order += 1
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.LayoutOrder = pg.order
    f.Parent = pg.frame

    local tL = Lbl(f, title, 11, T.secHeader, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    tL.Size = UDim2.new(1, 0, 1, 0)
    ConfigSystem.RegisterLabel(tL, title, true)
end

local function AddToggle(tabName, name, defOn, callback, noBind)
    local pg = tabPages[tabName]
    pg.order += 1

    local en = defOn or false
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, 28)
    item.BackgroundTransparency = 1
    item.LayoutOrder = pg.order
    item.Parent = pg.frame

    local hover = Instance.new("Frame")
    hover.Size = UDim2.new(1, 0, 1, 0)
    hover.BackgroundColor3 = T.itemHover
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.Parent = item
    Crn(hover, 4)

    local textRightOffset = noBind and -44 or -78
    local nL = Lbl(item, name, 11, en and T.text or T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    nL.Size = UDim2.new(1, textRightOffset, 1, 0)
    nL.Position = UDim2.new(0, 4, 0, 0)
    ConfigSystem.RegisterLabel(nL, name, false)

    -- Switch Frame
    local tBg = Instance.new("Frame")
    tBg.Size = UDim2.new(0, 34, 0, 17)
    tBg.Position = UDim2.new(1, -38, 0.5, -8)
    tBg.BackgroundColor3 = en and T.accent or T.accentOff
    tBg.BorderSizePixel = 0
    tBg.ZIndex = 2
    tBg.Parent = item
    Crn(tBg, 8)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 13, 0, 13)
    knob.Position = en and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = tBg
    Crn(knob, 6)

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(1, 0, 1, 0); switchBtn.BackgroundTransparency = 1; switchBtn.Text = ""; switchBtn.ZIndex = 5; switchBtn.Parent = tBg

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, textRightOffset, 1, 0); click.BackgroundTransparency = 1; click.Text = ""; click.ZIndex = 5; click.Parent = item

    local tObj = {}

    local function setToggle(v, runCb)
        if v == nil then v = not en end
        en = v
        Tw(tBg, {BackgroundColor3 = en and T.accent or T.accentOff}, 0.18)
        knob.Size = UDim2.new(0, 16, 0, 13)
        Tw(knob, {
            Position = en and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
            Size = UDim2.new(0, 13, 0, 13)
        }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Tw(nL, {TextColor3 = en and T.text or T.textDim}, 0.15)
        if runCb and callback then callback(en) end
        if ConfigSystem.UpdateKeybindsHud then ConfigSystem.UpdateKeybindsHud() end
        SaveConfig()
    end

    click.MouseButton1Click:Connect(function() setToggle(not en, true) end)
    switchBtn.MouseButton1Click:Connect(function() setToggle(not en, true) end)

    -- Dedicated Hit Box ONLY over the exact text bounds
    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 2, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 6
    textHit.Parent = item

    local function updateTextHit()
        local tbX = nL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nL.Text * 7, 20) end
        local maxW = noBind and 260 or 210
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, maxW), 1, 0)
    end
    updateTextHit()
    nL:GetPropertyChangedSignal("TextBounds"):Connect(updateTextHit)
    nL:GetPropertyChangedSignal("Text"):Connect(updateTextHit)
    task.defer(updateTextHit)

    textHit.MouseButton1Click:Connect(function() setToggle(not en, true) end)
    textHit.MouseEnter:Connect(function()
        Tw(hover, {BackgroundTransparency = 0.88}, 0.1)
        Tw(nL, {TextColor3 = en and T.text or Color3.fromRGB(255, 255, 255)}, 0.1)
        ShowTooltip(name)
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nL, {TextColor3 = en and T.text or T.textDim}, 0.1)
        HideTooltip()
    end)

    click.MouseEnter:Connect(function() Tw(hover, {BackgroundTransparency = 0.88}, 0.1) end)
    click.MouseLeave:Connect(function() Tw(hover, {BackgroundTransparency = 1}, 0.1) end)
    switchBtn.MouseEnter:Connect(function() Tw(hover, {BackgroundTransparency = 0.88}, 0.1) end)
    switchBtn.MouseLeave:Connect(function() Tw(hover, {BackgroundTransparency = 1}, 0.1) end)
    item.MouseLeave:Connect(function()
        Tw(hover, {BackgroundTransparency = 1}, 0.1)
        Tw(nL, {TextColor3 = en and T.text or T.textDim}, 0.1)
        HideTooltip()
    end)

    -- Keybind "..." button
    if not noBind then
        local dotsF = Instance.new("Frame")
        dotsF.Size = UDim2.new(0, 26, 0, 17)
        dotsF.Position = UDim2.new(1, -74, 0.5, -8)
        dotsF.BackgroundColor3 = T.dotsBg
        dotsF.BorderSizePixel = 0
        dotsF.ZIndex = 2
        dotsF.Parent = item
        Crn(dotsF, 4)
        Strk(dotsF, T.border, 1, 0)

        local dotsBtn = Instance.new("TextButton")
        dotsBtn.Size = UDim2.new(1, 0, 1, 0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.Font = Enum.Font.Arcade
        dotsBtn.TextSize = 8
        dotsBtn.Text = "..."
        dotsBtn.TextColor3 = T.textMuted
        dotsBtn.ZIndex = 8
        dotsBtn.Parent = dotsF

        local function refreshBindText()
            local b = featureBinds[name]
            if b and b.key then
                dotsBtn.Text = b.shortKey
                dotsBtn.TextColor3 = T.accent
            else
                dotsBtn.Text = "..."
                dotsBtn.TextColor3 = T.textMuted
            end
        end

        dotsBtn.MouseButton1Click:Connect(function()
            if listeningTarget and listeningTarget.name == name then
                listeningTarget = nil
                refreshBindText()
            else
                listeningTarget = {name = name, btn = dotsBtn, frame = dotsF, toggle = tObj}
                dotsBtn.Text = "..."
                dotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end)
        dotsBtn.MouseButton2Click:Connect(function()
            featureBinds[name] = nil
            refreshBindText()
            if ConfigSystem.UpdateKeybindsHud then ConfigSystem.UpdateKeybindsHud() end
            SaveConfig()
        end)
        dotsBtn.MouseEnter:Connect(function()
            Tw(dotsF, {BackgroundColor3 = Color3.fromRGB(24, 24, 34)}, 0.12)
        end)
        dotsBtn.MouseLeave:Connect(function()
            Tw(dotsF, {BackgroundColor3 = T.dotsBg}, 0.12)
        end)
        tObj.refreshBindText = refreshBindText
    end

    tObj.name = name
    tObj.setToggle = setToggle
    tObj.isEnabled = function() return en end
    tObj.tBg = tBg
    table.insert(ConfigSystem.pillRefreshers, function()
        if en then tBg.BackgroundColor3 = T.accent end
    end)

    return tObj
end

local function CreateSlider(tabName, labelText, minVal, maxVal, defaultVal, callback, isFloat)
    local pg = tabPages[tabName]
    pg.order += 1

    local curVal = math.clamp(defaultVal, minVal, maxVal)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.LayoutOrder = pg.order
    row.Parent = pg.frame

    local topF = Instance.new("Frame")
    topF.Size = UDim2.new(1, 0, 0, 16)
    topF.BackgroundTransparency = 1
    topF.Parent = row

    local nameL = Lbl(topF, labelText, 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    nameL.Size = UDim2.new(1, -48, 1, 0)
    nameL.Position = UDim2.new(0, 2, 0, 0)
    ConfigSystem.RegisterLabel(nameL, labelText, false)

    -- Tooltip strictly on label text
    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 0, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 5
    textHit.Parent = topF

    local function updateSliderTextHit()
        local tbX = nameL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nameL.Text * 7, 20) end
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, 200), 1, 0)
    end
    updateSliderTextHit()
    nameL:GetPropertyChangedSignal("TextBounds"):Connect(updateSliderTextHit)
    nameL:GetPropertyChangedSignal("Text"):Connect(updateSliderTextHit)
    task.defer(updateSliderTextHit)

    textHit.MouseEnter:Connect(function()
        Tw(nameL, {TextColor3 = T.text}, 0.1)
        ShowTooltip(labelText)
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nameL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)
    topF.MouseLeave:Connect(function()
        Tw(nameL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)

    -- Numeric Box
    local valBoxF = Instance.new("Frame")
    valBoxF.Size = UDim2.new(0, 42, 0, 16)
    valBoxF.Position = UDim2.new(1, -42, 0, 0)
    valBoxF.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    valBoxF.BorderSizePixel = 0
    valBoxF.ZIndex = 3
    valBoxF.Parent = topF
    Crn(valBoxF, 4)
    Strk(valBoxF, T.border, 1, 0)

    local valTB = Instance.new("TextBox")
    valTB.Size = UDim2.new(1, 0, 1, 0)
    valTB.BackgroundTransparency = 1
    valTB.Font = Enum.Font.Arcade
    valTB.TextSize = 10
    valTB.Text = isFloat and string.format("%.2f", curVal) or tostring(math.floor(curVal + 0.5))
    valTB.TextColor3 = T.accent
    valTB.TextXAlignment = Enum.TextXAlignment.Center
    valTB.ClearTextOnFocus = false
    valTB.ZIndex = 4
    valTB.Parent = valBoxF
    TrackAccent(valTB, "TextColor3")

    -- Track
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -4, 0, 6)
    track.Position = UDim2.new(0, 2, 0, 23)
    track.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    track.BorderSizePixel = 0
    track.ZIndex = 3
    track.Parent = row
    Crn(track, 3)
    Strk(track, Color3.fromRGB(34, 34, 46), 1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = T.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 4
    fill.Parent = track
    Crn(fill, 3)
    TrackAccent(fill, "BackgroundColor3")

    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(1, 0, 0, 14)
    sliderBtn.Position = UDim2.new(0, 0, 0, 19)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.ZIndex = 5
    sliderBtn.Parent = row

    local isDragging = false

    local function SetValue(v)
        curVal = math.clamp(v, minVal, maxVal)
        local pct = math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valTB.Text = isFloat and string.format("%.2f", curVal) or tostring(math.floor(curVal + 0.5))
        if callback then callback(curVal) end
        SaveConfig()
    end

    local function UpdateFromMouse(input)
        local relX = input.Position.X - track.AbsolutePosition.X
        local pct = math.clamp(relX / track.AbsoluteSize.X, 0, 1)
        local raw = minVal + pct * (maxVal - minVal)
        if not isFloat then raw = math.floor(raw + 0.5) end
        SetValue(raw)
    end

    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            UpdateFromMouse(input)
        end
    end)
    table.insert(allConn, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end))
    table.insert(allConn, UIS.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateFromMouse(input)
        end
    end))

    valTB.FocusLost:Connect(function()
        local n = tonumber(valTB.Text)
        if n then SetValue(n) else SetValue(curVal) end
    end)
end

-- ══════════════════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════════════════

-- 1. TRIGGERBOT TAB
AddSection("Triggerbot", "TRIGGERBOT")
AddToggle("Triggerbot", "Triggerbot Toggle", Triggerbot.enabled, function(v)
    Triggerbot.enabled = v
    if Triggerbot.UpdateConnection then Triggerbot.UpdateConnection() end
end)
AddToggle("Triggerbot", "Target Lead Circle", Triggerbot.showTargetCircle, function(v)
    Triggerbot.showTargetCircle = v
    if Triggerbot.UpdateConnection then Triggerbot.UpdateConnection() end
end)
AddToggle("Triggerbot", "Show Hitbox FOV", Triggerbot.showFov, function(v)
    Triggerbot.showFov = v
    if Triggerbot.UpdateConnection then Triggerbot.UpdateConnection() end
end)
AddToggle("Triggerbot", "Trigger Prediction", Triggerbot.predict, function(v)
    Triggerbot.predict = v
end)
AddToggle("Triggerbot", "Visible Check", Triggerbot.visibleCheck, function(v)
    Triggerbot.visibleCheck = v
end)
AddToggle("Triggerbot", "Alive Check", Triggerbot.healthCheck, function(v)
    Triggerbot.healthCheck = v
end)

AddSection("Triggerbot", "SETTINGS")
CreateSlider("Triggerbot", "Hitbox FOV", 5, 80, Triggerbot.tolerance, function(v)
    Triggerbot.tolerance = v
end)
CreateSlider("Triggerbot", "Max Distance", 50, 2000, Triggerbot.maxDistance, function(v)
    Triggerbot.maxDistance = v
end)
CreateSlider("Triggerbot", "Delay (ms)", 0, 150, Triggerbot.delay, function(v)
    Triggerbot.delay = v
end)
CreateSlider("Triggerbot", "Prediction X", 0.00, 0.40, Triggerbot.predictX, function(v)
    Triggerbot.predictX = v
end, true)
CreateSlider("Triggerbot", "Prediction Y", 0.00, 0.40, Triggerbot.predictY, function(v)
    Triggerbot.predictY = v
end, true)

-- 2. ESP TAB
AddSection("ESP", "PLAYER ESP")
AddToggle("ESP", "Player ESP", ESP.enabled, function(v)
    ESP.enabled = v
    RefreshAllESP()
end)
AddToggle("ESP", "Boxes", ESP.box, function(v)
    ESP.box = v
    RefreshAllESP()
end)
AddToggle("ESP", "Health Bar", ESP.health, function(v)
    ESP.health = v
    RefreshAllESP()
end)
AddToggle("ESP", "Names", ESP.name, function(v)
    ESP.name = v
    RefreshAllESP()
end)
AddToggle("ESP", "Distance", ESP.dist, function(v)
    ESP.dist = v
    RefreshAllESP()
end)
AddToggle("ESP", "Chams", ESP.chams, function(v)
    ESP.chams = v
    RefreshAllESP()
end)

AddSection("ESP", "CHAMS STYLE")
do
    local pg = tabPages["ESP"]
    pg.order += 1

    local pillRow = Instance.new("Frame")
    pillRow.Size = UDim2.new(1, 0, 0, 26)
    pillRow.BackgroundTransparency = 1
    pillRow.LayoutOrder = pg.order
    pillRow.Parent = pg.frame

    local pillLL = Instance.new("UIListLayout")
    pillLL.FillDirection = Enum.FillDirection.Horizontal
    pillLL.Padding = UDim.new(0, 6)
    pillLL.Parent = pillRow

    local modes = {"VisCheck", "Solid", "Glow", "Outline"}
    local btns = {}

    local function refreshChamsPills()
        for m, b in pairs(btns) do
            local isSel = (ESP.chamsMode == m)
            b.BackgroundColor3 = isSel and T.accent or Color3.fromRGB(24, 24, 34)
            b.TextColor3 = isSel and Color3.new(1, 1, 1) or T.textDim
        end
    end
    table.insert(ConfigSystem.pillRefreshers, refreshChamsPills)

    for _, m in ipairs(modes) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.23, 0, 1, 0)
        b.BackgroundColor3 = (ESP.chamsMode == m) and T.accent or Color3.fromRGB(24, 24, 34)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.Arcade
        b.TextSize = 9
        b.Text = m
        b.TextColor3 = (ESP.chamsMode == m) and Color3.new(1, 1, 1) or T.textDim
        b.AutoButtonColor = false
        b.Parent = pillRow
        Crn(b, 4)
        Strk(b, T.border, 1, 0)

        b.MouseButton1Click:Connect(function()
            ESP.chamsMode = m
            refreshChamsPills()
            RefreshAllESP()
            SaveConfig()
        end)
        btns[m] = b
    end
end

-- 3. SETTINGS TAB
AddSection("Settings", "INTERFACE")

-- Keybinds HUD Toggle
local kbHudVisible = false
local kbWin = nil

AddToggle("Settings", "Keybinds List", kbHudVisible, function(v)
    kbHudVisible = v
    if kbWin then kbWin.Visible = v end
end, true)

-- Menu Key Row
do
    local pg = tabPages["Settings"]
    pg.order += 1

    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, 28)
    item.BackgroundTransparency = 1
    item.LayoutOrder = pg.order
    item.Parent = pg.frame

    local hover = Instance.new("Frame")
    hover.Size = UDim2.new(1, 0, 1, 0)
    hover.BackgroundColor3 = T.itemHover
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.Parent = item
    Crn(hover, 4)

    local nL = Lbl(item, "Menu Key", 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    nL.Size = UDim2.new(1, -66, 1, 0)
    nL.Position = UDim2.new(0, 4, 0, 0)
    ConfigSystem.RegisterLabel(nL, "Menu Key", false)

    local dotsF = Instance.new("Frame")
    dotsF.Size = UDim2.new(0, 52, 0, 18)
    dotsF.Position = UDim2.new(1, -56, 0.5, -9)
    dotsF.BackgroundColor3 = T.dotsBg
    dotsF.BorderSizePixel = 0
    dotsF.ZIndex = 2
    dotsF.Parent = item
    Crn(dotsF, 4)
    Strk(dotsF, T.border, 1, 0)

    local dotsBtn = Instance.new("TextButton")
    dotsBtn.Size = UDim2.new(1, 0, 1, 0)
    dotsBtn.BackgroundTransparency = 1
    dotsBtn.BorderSizePixel = 0
    dotsBtn.Font = Enum.Font.Arcade
    dotsBtn.TextSize = 9
    dotsBtn.Text = FormatKeyName(TOGGLE_KEY)
    dotsBtn.TextColor3 = T.accent
    dotsBtn.ZIndex = 8
    dotsBtn.Parent = dotsF
    TrackAccent(dotsBtn, "TextColor3")

    local function startMenuBind()
        if listeningTarget and listeningTarget.isMenuKey then
            listeningTarget = nil
            dotsBtn.Text = FormatKeyName(TOGGLE_KEY)
        else
            listeningTarget = {isMenuKey = true, btn = dotsBtn, frame = dotsF}
            dotsBtn.Text = "..."
            dotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    dotsBtn.MouseButton1Click:Connect(startMenuBind)
    dotsBtn.MouseButton2Click:Connect(function()
        TOGGLE_KEY = "Delete"
        dotsBtn.Text = "Delete"
        dotsBtn.TextColor3 = T.accent
        SaveConfig()
    end)

    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 2, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 6
    textHit.Parent = item

    local function updateMenuKeyTextHit()
        local tbX = nL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nL.Text * 7, 20) end
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, 110), 1, 0)
    end
    updateMenuKeyTextHit()
    nL:GetPropertyChangedSignal("TextBounds"):Connect(updateMenuKeyTextHit)
    nL:GetPropertyChangedSignal("Text"):Connect(updateMenuKeyTextHit)
    task.defer(updateMenuKeyTextHit)

    textHit.MouseButton1Click:Connect(startMenuBind)
    textHit.MouseEnter:Connect(function()
        Tw(hover, {BackgroundTransparency = 0.88}, 0.1)
        Tw(nL, {TextColor3 = T.text}, 0.1)
        ShowTooltip("Menu Key")
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)
    item.MouseLeave:Connect(function()
        Tw(hover, {BackgroundTransparency = 1}, 0.1)
        Tw(nL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)
end

-- Language Dual-Pill [ EN | RU ]
do
    local pg = tabPages["Settings"]
    pg.order += 1

    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, 28)
    item.BackgroundTransparency = 1
    item.LayoutOrder = pg.order
    item.Parent = pg.frame

    local hover = Instance.new("Frame")
    hover.Size = UDim2.new(1, 0, 1, 0)
    hover.BackgroundColor3 = T.itemHover
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.Parent = item
    Crn(hover, 4)

    local nL = Lbl(item, "Language", 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    nL.Size = UDim2.new(1, -78, 1, 0)
    nL.Position = UDim2.new(0, 4, 0, 0)
    ConfigSystem.RegisterLabel(nL, "Language", false)

    local pillF = Instance.new("Frame")
    pillF.Size = UDim2.new(0, 70, 0, 18)
    pillF.Position = UDim2.new(1, -74, 0.5, -9)
    pillF.BackgroundColor3 = T.dotsBg
    pillF.BorderSizePixel = 0
    pillF.ZIndex = 2
    pillF.Parent = item
    Crn(pillF, 4)
    Strk(pillF, T.border, 1, 0)

    local enBtn = Instance.new("TextButton")
    enBtn.Size = UDim2.new(0.5, 0, 1, 0)
    enBtn.Position = UDim2.new(0, 0, 0, 0)
    enBtn.BorderSizePixel = 0
    enBtn.Font = Enum.Font.GothamBold
    enBtn.TextSize = 8
    enBtn.Text = "EN"
    enBtn.AutoButtonColor = false
    enBtn.ZIndex = 4
    enBtn.Parent = pillF
    Crn(enBtn, 3)

    local ruBtn = Instance.new("TextButton")
    ruBtn.Size = UDim2.new(0.5, 0, 1, 0)
    ruBtn.Position = UDim2.new(0.5, 0, 0, 0)
    ruBtn.BorderSizePixel = 0
    ruBtn.Font = Enum.Font.GothamBold
    ruBtn.TextSize = 8
    ruBtn.Text = "RU"
    ruBtn.AutoButtonColor = false
    ruBtn.ZIndex = 4
    ruBtn.Parent = pillF
    Crn(ruBtn, 3)

    local function refreshLangButtons()
        local isRU = (ConfigSystem.currentLang == "RU")
        if isRU then
            ruBtn.BackgroundColor3 = T.accent
            ruBtn.BackgroundTransparency = 0
            ruBtn.TextColor3 = Color3.new(1, 1, 1)
            enBtn.BackgroundTransparency = 1
            enBtn.TextColor3 = T.textMuted
        else
            enBtn.BackgroundColor3 = T.accent
            enBtn.BackgroundTransparency = 0
            enBtn.TextColor3 = Color3.new(1, 1, 1)
            ruBtn.BackgroundTransparency = 1
            ruBtn.TextColor3 = T.textMuted
        end
    end
    table.insert(ConfigSystem.pillRefreshers, refreshLangButtons)
    table.insert(ConfigSystem.listeners, refreshLangButtons)
    refreshLangButtons()

    enBtn.MouseButton1Click:Connect(function()
        ConfigSystem.SetLanguage("EN")
        SaveConfig()
    end)
    ruBtn.MouseButton1Click:Connect(function()
        ConfigSystem.SetLanguage("RU")
        SaveConfig()
    end)

    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 2, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 6
    textHit.Parent = item

    local function updateLangTextHit()
        local tbX = nL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nL.Text * 7, 20) end
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, 110), 1, 0)
    end
    updateLangTextHit()
    nL:GetPropertyChangedSignal("TextBounds"):Connect(updateLangTextHit)
    nL:GetPropertyChangedSignal("Text"):Connect(updateLangTextHit)
    task.defer(updateLangTextHit)

    textHit.MouseEnter:Connect(function()
        Tw(hover, {BackgroundTransparency = 0.88}, 0.1)
        Tw(nL, {TextColor3 = T.text}, 0.1)
        ShowTooltip("Language")
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)
    item.MouseLeave:Connect(function()
        Tw(hover, {BackgroundTransparency = 1}, 0.1)
        Tw(nL, {TextColor3 = T.textDim}, 0.1)
        HideTooltip()
    end)
end

AddSection("Settings", "SYSTEM")

-- Accent Preset Picker Row
do
    local pg = tabPages["Settings"]
    pg.order += 1

    local colRow = Instance.new("Frame")
    colRow.Size = UDim2.new(1, 0, 0, 24)
    colRow.BackgroundTransparency = 1
    colRow.LayoutOrder = pg.order
    colRow.Parent = pg.frame

    local colLL = Instance.new("UIListLayout")
    colLL.FillDirection = Enum.FillDirection.Horizontal
    colLL.Padding = UDim.new(0, 8)
    colLL.Parent = colRow

    local colorPresets = {
        {name = "Sky Blue", h = 0.58, s = 0.55, v = 1.0},
        {name = "Neon Pink", h = 0.83, s = 0.70, v = 1.0},
        {name = "Emerald", h = 0.38, s = 0.75, v = 1.0},
        {name = "Amber", h = 0.10, s = 0.80, v = 1.0},
        {name = "Purple", h = 0.75, s = 0.65, v = 1.0},
    }

    for _, cp in ipairs(colorPresets) do
        local dot = Instance.new("TextButton")
        dot.Size = UDim2.new(0, 20, 0, 20)
        dot.BackgroundColor3 = Color3.fromHSV(cp.h, cp.s, cp.v)
        dot.BorderSizePixel = 0
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.Parent = colRow
        Crn(dot, 10)
        Strk(dot, T.border, 1, 0)

        dot.MouseButton1Click:Connect(function()
            accentH, accentS, accentV = cp.h, cp.s, cp.v
            ApplyAccentColor()
            SaveConfig()
        end)
    end
end

-- Reset HUD Button
do
    local pg = tabPages["Settings"]
    pg.order += 1

    local rRow = Instance.new("Frame")
    rRow.Size = UDim2.new(1, 0, 0, 26)
    rRow.BackgroundTransparency = 1
    rRow.LayoutOrder = pg.order
    rRow.Parent = pg.frame

    local rBtn = Instance.new("TextButton")
    rBtn.Size = UDim2.new(1, -4, 0, 22)
    rBtn.Position = UDim2.new(0, 2, 0.5, -11)
    rBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    rBtn.BorderSizePixel = 0
    rBtn.Font = Enum.Font.Arcade
    rBtn.Text = "Reset HUD"
    rBtn.TextColor3 = T.text
    rBtn.TextSize = 10
    rBtn.AutoButtonColor = false
    rBtn.ZIndex = 3
    rBtn.Parent = rRow
    Crn(rBtn, 5)
    Strk(rBtn, T.border, 1, 0)
    ConfigSystem.RegisterLabel(rBtn, "Reset HUD", false)

    rBtn.MouseEnter:Connect(function()
        Tw(rBtn, {BackgroundColor3 = Color3.fromRGB(32, 38, 50)}, 0.1)
        ShowTooltip("Reset HUD")
    end)
    rBtn.MouseLeave:Connect(function()
        Tw(rBtn, {BackgroundColor3 = Color3.fromRGB(24, 28, 36)}, 0.1)
        HideTooltip()
    end)
    rBtn.MouseButton1Click:Connect(function()
        if kbWin then kbWin.Position = UDim2.new(0, 20, 0, 220) end
    end)
end

-- Unload Script Button
do
    local pg = tabPages["Settings"]
    pg.order += 1

    local uRow = Instance.new("Frame")
    uRow.Size = UDim2.new(1, 0, 0, 26)
    uRow.BackgroundTransparency = 1
    uRow.LayoutOrder = pg.order
    uRow.Parent = pg.frame

    local uBtn = Instance.new("TextButton")
    uBtn.Size = UDim2.new(1, -4, 0, 22)
    uBtn.Position = UDim2.new(0, 2, 0.5, -11)
    uBtn.BackgroundColor3 = Color3.fromRGB(36, 18, 24)
    uBtn.BorderSizePixel = 0
    uBtn.Font = Enum.Font.Arcade
    uBtn.Text = "Unload Script"
    uBtn.TextColor3 = Color3.fromRGB(255, 85, 95)
    uBtn.TextSize = 10
    uBtn.AutoButtonColor = false
    uBtn.ZIndex = 3
    uBtn.Parent = uRow
    Crn(uBtn, 5)
    Strk(uBtn, Color3.fromRGB(65, 25, 35), 1, 0)
    ConfigSystem.RegisterLabel(uBtn, "Unload Script", false)

    uBtn.MouseEnter:Connect(function()
        Tw(uBtn, {BackgroundColor3 = Color3.fromRGB(50, 22, 30)}, 0.1)
        ShowTooltip("Unload Script")
    end)
    uBtn.MouseLeave:Connect(function()
        Tw(uBtn, {BackgroundColor3 = Color3.fromRGB(36, 18, 24)}, 0.1)
        HideTooltip()
    end)
    uBtn.MouseButton1Click:Connect(function()
        if _G.NovaTriggerEspUnload then _G.NovaTriggerEspUnload() end
    end)
end

-- ══════════════════════════════════════════════
--  KEYBINDS HUD WINDOW
-- ══════════════════════════════════════════════
do
    local hud = Instance.new("Frame")
    hud.Name = "KeybindsHUD"
    hud.Size = UDim2.new(0, 170, 0, 24)
    hud.Position = UDim2.new(0, 20, 0, 220)
    hud.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    hud.BorderSizePixel = 0
    hud.Visible = false
    hud.Parent = mainSG
    Crn(hud, 6)
    Strk(hud, T.border, 1, 0)
    kbWin = hud

    local hTop = Instance.new("Frame")
    hTop.Size = UDim2.new(1, 0, 0, 22)
    hTop.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    hTop.BorderSizePixel = 0
    hTop.Parent = hud
    Crn(hTop, 6)

    local hTopL = Lbl(hTop, "Keybinds", 10, T.text, Enum.Font.Arcade, Enum.TextXAlignment.Left, 3)
    hTopL.Position = UDim2.new(0, 8, 0, 0)
    hTopL.Size = UDim2.new(1, -16, 1, 0)

    local listF = Instance.new("Frame")
    listF.Size = UDim2.new(1, -8, 0, 0)
    listF.Position = UDim2.new(0, 4, 0, 24)
    listF.BackgroundTransparency = 1
    listF.AutomaticSize = Enum.AutomaticSize.Y
    listF.Parent = hud

    local listLL = Instance.new("UIListLayout")
    listLL.Padding = UDim.new(0, 2)
    listLL.SortOrder = Enum.SortOrder.LayoutOrder
    listLL.Parent = listF

    local function UpdateKeybindsHud()
        for _, ch in ipairs(listF:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        local count = 0
        for name, b in pairs(featureBinds) do
            if b and b.key then
                count += 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 16)
                row.BackgroundTransparency = 1
                row.LayoutOrder = count
                row.Parent = listF

                local nameL = Lbl(row, name, 9, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
                nameL.Position = UDim2.new(0, 4, 0, 0)
                nameL.Size = UDim2.new(0.65, 0, 1, 0)

                local stateL = Lbl(row, "[" .. tostring(b.shortKey) .. "]", 9, (b.toggleObj and b.toggleObj.isEnabled()) and T.accent or T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Right, 2)
                stateL.Position = UDim2.new(0.65, 0, 0, 0)
                stateL.Size = UDim2.new(0.35, -4, 1, 0)
            end
        end
        hud.Size = UDim2.new(0, 170, 0, 24 + math.max(0, count * 18 + 4))
    end
    ConfigSystem.UpdateKeybindsHud = UpdateKeybindsHud
end

-- ══════════════════════════════════════════════
--  KEYBOARD / INPUT LISTENER
-- ══════════════════════════════════════════════
table.insert(allConn, UIS.InputBegan:Connect(function(input, gpe)
    local inKey = nil
    if input.UserInputType == Enum.UserInputType.Keyboard then
        inKey = input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        inKey = "MouseButton2"
    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
        inKey = "MouseButton3"
    end

    if not inKey then return end

    -- Listening mode for setting bind
    if listeningTarget then
        if inKey == "Escape" then
            if listeningTarget.btn then listeningTarget.btn.Text = "..." end
            listeningTarget = nil
            return
        end

        local sKey = FormatKeyName(inKey)
        if listeningTarget.isMenuKey then
            TOGGLE_KEY = inKey
            listeningTarget.btn.Text = sKey
            listeningTarget.btn.TextColor3 = T.accent
            listeningTarget = nil
            SaveConfig()
            return
        end

        featureBinds[listeningTarget.name] = {
            key = inKey,
            shortKey = sKey,
            mode = "Toggle",
            toggleObj = listeningTarget.toggle
        }
        if listeningTarget.toggle and listeningTarget.toggle.refreshBindText then
            listeningTarget.toggle.refreshBindText()
        end
        listeningTarget = nil
        if ConfigSystem.UpdateKeybindsHud then ConfigSystem.UpdateKeybindsHud() end
        SaveConfig()
        return
    end

    -- Menu Toggle Key
    if inKey == TOGGLE_KEY and not gpe then
        menuOpen = not menuOpen
        win.Visible = menuOpen
        if not menuOpen then
            HideTooltip()
        else
            win.Position = UDim2.new(win.Position.X.Scale, win.Position.X.Offset, win.Position.Y.Scale, win.Position.Y.Offset - 10)
            Tw(win, {Position = UDim2.new(win.Position.X.Scale, win.Position.X.Offset, win.Position.Y.Scale, win.Position.Y.Offset + 10)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
        return
    end

    -- Feature Binds Activation
    if not gpe then
        for name, b in pairs(featureBinds) do
            if b.key == inKey and b.toggleObj then
                b.toggleObj.setToggle(not b.toggleObj.isEnabled(), true)
            end
        end
    end
end))

-- ══════════════════════════════════════════════
--  CLEANUP / UNLOAD
-- ══════════════════════════════════════════════
_G.NovaTriggerEspUnload = function()
    _G.NovaTriggerEspLoaded = nil
    _G.NovaTriggerEspUnload = nil

    for _, c in ipairs(allConn) do
        pcall(function() c:Disconnect() end)
    end
    if Triggerbot.conn then
        pcall(function() Triggerbot.conn:Disconnect() end)
    end
    for _, p in ipairs(Players:GetPlayers()) do
        ClearESPForPlayer(p)
    end
    for _, g in ipairs(allGuis) do
        pcall(function() g:Destroy() end)
    end
end

-- Smooth intro animation
win.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2 - 15)
Tw(win, {Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)}, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
