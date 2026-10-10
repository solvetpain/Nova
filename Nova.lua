-- NOVA GUI | HvH-style dark menu
-- [Delete] = toggle menu

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RS          = game:GetService("RunService")
local TS          = game:GetService("TweenService")
local Lighting    = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer

local safeParent
pcall(function() safeParent = game:GetService("CoreGui") end)
if not safeParent then safeParent = LP:WaitForChild("PlayerGui") end

-- ══════════════════════════════════════════════
--  AUTO-CLEANUP PREVIOUS INSTANCE (Re-inject reset)
-- ══════════════════════════════════════════════
local SCRIPT_ID = math.random(1000000, 9999999)
pcall(function()
    if getgenv then
        if getgenv().NOVA_UNLOAD then
            getgenv().NOVA_UNLOAD()
        end
        getgenv().NOVA_CURRENT_ID = SCRIPT_ID
    end
end)
pcall(function()
    for _, g in ipairs(safeParent:GetChildren()) do
        if g.Name == "NOVA_GUI" or g.Name == "NOVA_Rain" or g.Name == "NOVA_Lightning" or g.Name == "NOVA_Admins" or g.Name == "NOVA_Crosshair" or g.Name == "NOVA_Notifications" then
            g:Destroy()
        end
    end
    local wp = workspace:FindFirstChild("NOVA_WeatherPart")
    if wp then wp:Destroy() end
    local wg = workspace:FindFirstChild("NOVA_Ghosts")
    if wg then wg:Destroy() end
    local wcc = Lighting:FindFirstChild("NOVA_WeatherCC")
    if wcc then wcc:Destroy() end
    for _, b in ipairs(Lighting:GetChildren()) do
        if b:IsA("BlurEffect") and (b.Name == "NOVA_Blur" or b.Name == "BlurEffect" or b.Name == "Blur") then
            b.Size = 0
            b.Enabled = false
            b:Destroy()
        end
    end
end)

-- ══════════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ══════════════════════════════════════════════
local CONFIG_DIR = "nova_configs"
local CONFIG_FILE = "nova_configs/default.json"
local CONFIGS_FILE = "nova_configs_store.json"
local isApplyingConfig = false
local savedW, savedH = 580, 340
local accentH, accentS, accentV = 0.738, 0.70, 0.94   -- default: purple HSV (matches modern dark UI)
local savedBinds, savedToggles = {}, {}
local kbHudVisible, kbHudPosX, kbHudPosY = true, 20, 220
local savedFlySpeed, savedSpeedBoost = 50, 42
local savedChamsMode = "VisCheck"
local allSliders = {}

local Crosshair = {
    enabled = false,
    followMouse = false,
    spin = false,
    spinSpeed = 120,
    size = 10,
    gap = 4,
    thickness = 2,
    dot = false,
    useAccent = true,
    color = Color3.fromRGB(142, 72, 240),
    gui = nil,
    frame = nil,
    lines = {},
    centerDot = nil,
    currentAngle = 0,
    UpdateVisuals = nil,
}

local Notify = nil

local ConfigSystem = {
    activeConfig = "default",
    configs = {},
    selectedConfig = "default",
    defaultConfigName = "default",
    savedToggleKey = "Delete",
    UpdateMenuKeyUI = nil,
    pillRefreshers = {},
    themeRefreshers = {},
    refreshList = nil,
    statusLabel = nil,
    LoadNamed = nil,
    SaveNamed = nil,
    DeleteNamed = nil,
    SetDefault = nil,
    LoadPreset = nil,
    ParseColor = function(str)
        if not str or type(str) ~= "string" then return nil end
        local s = str:gsub("%s+", ""):gsub("^#", "")
        if (#s == 6 or #s == 8) and s:match("^%x+$") then
            local r = tonumber(s:sub(1, 2), 16) or 255
            local g = tonumber(s:sub(3, 4), 16) or 255
            local b = tonumber(s:sub(5, 6), 16) or 255
            return Color3.fromRGB(r, g, b)
        elseif #s == 3 and s:match("^%x+$") then
            local r = tonumber(s:sub(1, 1):rep(2), 16) or 255
            local g = tonumber(s:sub(2, 2):rep(2), 16) or 255
            local b = tonumber(s:sub(3, 3):rep(2), 16) or 255
            return Color3.fromRGB(r, g, b)
        end
        local r, g, b = str:match("(%d+)[%s,]+(%d+)[%s,]+(%d+)")
        if r and g and b then
            return Color3.fromRGB(
                math.clamp(tonumber(r) or 255, 0, 255),
                math.clamp(tonumber(g) or 255, 0, 255),
                math.clamp(tonumber(b) or 255, 0, 255)
            )
        end
        return nil
    end,
    ColorToHex = function(col)
        if not col then return "#FFFFFF" end
        local r = math.clamp(math.floor(col.R * 255 + 0.5), 0, 255)
        local g = math.clamp(math.floor(col.G * 255 + 0.5), 0, 255)
        local b = math.clamp(math.floor(col.B * 255 + 0.5), 0, 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end,
    noBindToggles = {
        ["Visible Check"] = true,
        ["Alive Check (Da Hood)"] = true,
        ["Sticky Aim"] = true,
        ["Show FOV Circle"] = true,
        ["Prediction"] = true,
        ["Trigger Prediction"] = true,
        ["Trigger Visible Check"] = true,
        ["Trigger Alive Check"] = true,
        ["Show Hitbox FOV"] = true,
        ["Target Lead Circle"] = true,
        ["Follow Mouse"] = true,
        ["Spin Animation"] = true,
        ["Center Dot"] = true,
        ["Map Snow"] = true,
        ["Map Rain"] = true,
        ["Thunderstorm"] = true,
        ["Sandstorm"] = true,
        ["Boxes"] = true,
        ["Health Bar"] = true,
        ["Names"] = true,
        ["Distance"] = true,
        ["Chams"] = true,
        ["Hit Sound"] = true,
        ["Damage Indicator"] = true,
        ["Hit Ghost"] = true,
        ["Admin Detector"] = true,
        ["Admins HUD"] = true,
        ["Auto-Hide Empty HUD"] = true,
        ["Staff Alerts"] = true,
        ["Blur on Open"] = true,
        ["Rain Effect"] = true,
        ["Snow Effect"] = true,
        ["Keybinds List"] = true,
        ["Watermark"] = true,
        ["Language"] = true,
    },
}

ConfigSystem.savedLanguage = "EN"
ConfigSystem.Localization = {
    currentLang = "EN",
    listeners = {},
    translations = {
        -- Combat
        ["Aim Assist"] = { RU = "Аим Ассист", desc = {
            EN = "Smoothly guides crosshair towards enemies within FOV.",
            RU = "Плавно доводит прицел до врагов в радиусе захвата."
        }},
        ["Visible Check"] = { RU = "Проверка стен", desc = {
            EN = "Only targets enemies not obscured by obstacles or walls.",
            RU = "Наводится только на врагов вне стен и укрытий."
        }},
        ["Alive Check (Da Hood)"] = { RU = "Проверка нокаута", desc = {
            EN = "Ignores knocked out, stunned or defeated players.",
            RU = "Игнорирует нокаутированных и погибших игроков."
        }},
        ["No Recoil (Mad Hood)"] = { RU = "Без отдачи (Mad Hood)", desc = {
            EN = "Eliminates camera shake and weapon recoil kick in Mad Hood.",
            RU = "Полностью убирает отдачу и тряску камеры при стрельбе в Mad Hood."
        }},
        ["Sticky Aim"] = { RU = "Прилипание к цели", desc = {
            EN = "Sticks onto the current target until they exit your FOV.",
            RU = "Удерживает захват на цели, пока она в поле зрения."
        }},
        ["Show FOV Circle"] = { RU = "Круг радиуса FOV", desc = {
            EN = "Renders visual circular field of view on screen.",
            RU = "Отображает визуальный круг радиуса захвата аима."
        }},
        ["Prediction"] = { RU = "Предикт (Упреждение)", desc = {
            EN = "Compensates for target velocity and latency when aiming.",
            RU = "Рассчитывает упреждение выстрела по скорости цели."
        }},
        ["Triggerbot"] = { RU = "Триггербот", desc = {
            EN = "Automatically fires your weapon when crosshair is on target.",
            RU = "Автоматически стреляет при наведении прицела на цель."
        }},
        ["Target Lead Circle"] = { RU = "Круг упреждения цели", desc = {
            EN = "Displays target lead prediction circle directly on enemy.",
            RU = "Показывает точку упреждения прямо на теле цели."
        }},
        ["Show Hitbox FOV"] = { RU = "Зона хитбокса", desc = {
            EN = "Visualizes activation boundary area for triggerbot.",
            RU = "Отображает область срабатывания выстрела триггербота."
        }},
        ["Trigger Prediction"] = { RU = "Предикт триггера", desc = {
            EN = "Applies velocity prediction to triggerbot hit detection.",
            RU = "Учитывает скорость цели при проверке выстрела."
        }},
        ["Trigger Visible Check"] = { RU = "Триггер: проверка стен", desc = {
            EN = "Ensures triggerbot only shoots when enemy is directly visible.",
            RU = "Стреляет только если цель не закрыта препятствиями."
        }},
        ["Trigger Alive Check"] = { RU = "Триггер: живой игрок", desc = {
            EN = "Prevents triggerbot from shooting knocked or dead players.",
            RU = "Блокирует выстрелы по нокаутированным и мертвым игрокам."
        }},

        -- Movement
        ["Fly"] = { RU = "Полет (Fly)", desc = {
            EN = "Fly freely through the air in any direction.",
            RU = "Свободный полет персонажа в любом направлении."
        }},
        ["Speed Boost"] = { RU = "Быстрый бег", desc = {
            EN = "Significantly increases character walkspeed.",
            RU = "Увеличивает скорость перемещения персонажа."
        }},
        ["Noclip"] = { RU = "Проход сквозь стены", desc = {
            EN = "Allows walking directly through solid collision geometry.",
            RU = "Позволяет проходить сквозь стены и препятствия."
        }},
        ["Infinite Jump"] = { RU = "Бесконечный прыжок", desc = {
            EN = "Allows jumping infinitely in air without touching ground.",
            RU = "Позволяет прыгать в воздухе без приземления."
        }},

        -- Visuals
        ["Map Snow"] = { RU = "Снег на карте", desc = {
            EN = "Spawns visual snowflakes falling across the game world.",
            RU = "Включает визуальный снегопад в игровом мире."
        }},
        ["Map Rain"] = { RU = "Дождь на карте", desc = {
            EN = "Spawns ambient rain droplets across the game world.",
            RU = "Включает визуальный дождь в игровом мире."
        }},
        ["Thunderstorm"] = { RU = "Гроза", desc = {
            EN = "Dynamic storm lighting effects and dark atmosphere.",
            RU = "Грозовая атмосфера с молниями и темным небом."
        }},
        ["Sandstorm"] = { RU = "Песчаная буря", desc = {
            EN = "Dust haze sandstorm atmosphere in the game world.",
            RU = "Атмосфера песчаной бури с эффектом пыли."
        }},
        ["Custom Crosshair"] = { RU = "Кастомный прицел", desc = {
            EN = "Draws custom configurable crosshair lines on screen.",
            RU = "Отображает настраиваемое перекрестие на экране."
        }},
        ["Follow Mouse"] = { RU = "Следование за курсором", desc = {
            EN = "Crosshair follows mouse cursor instead of screen center.",
            RU = "Прицел следует за курсором мыши вместо центра."
        }},
        ["Spin Animation"] = { RU = "Вращение прицела", desc = {
            EN = "Continuously spins crosshair at customizable speed.",
            RU = "Вращает линии перекрестия вокруг своей оси."
        }},
        ["Center Dot"] = { RU = "Точка в центре", desc = {
            EN = "Draws a precise dot at the center of crosshair.",
            RU = "Отображает точку в самом центре перекрестия."
        }},
        ["Player ESP"] = { RU = "ВХ на игроков", desc = {
            EN = "Highlights other players with visual overlays through walls.",
            RU = "Подсвечивает игроков сквозь стены и препятствия."
        }},
        ["Boxes"] = { RU = "2D Боксы", desc = {
            EN = "Draws 2D bounding boxes around players.",
            RU = "Рисует прямоугольные рамки вокруг игроков."
        }},
        ["Health Bar"] = { RU = "Полоска HP", desc = {
            EN = "Displays animated health bar next to each player.",
            RU = "Показывает полоску здоровья рядом с игроком."
        }},
        ["Names"] = { RU = "Ники игроков", desc = {
            EN = "Displays player usernames above their heads.",
            RU = "Отображает ники игроков над их головами."
        }},
        ["Distance"] = { RU = "Дистанция", desc = {
            EN = "Displays distance in studs to each player.",
            RU = "Показывает расстояние в студах до каждого игрока."
        }},
        ["Chams"] = { RU = "Чамсы (Силуэт)", desc = {
            EN = "Highlights player character models through walls.",
            RU = "Подсвечивает модели игроков сквозь стены."
        }},
        ["Hit Sound"] = { RU = "Звук попадания", desc = {
            EN = "Plays an audio hitsound whenever you hit an enemy.",
            RU = "Воспроизводит звук при нанесении урона врагу."
        }},
        ["Damage Indicator"] = { RU = "Индикатор урона", desc = {
            EN = "Displays animated damage numbers upon hitting an enemy.",
            RU = "Показывает нанесенный урон по центру экрана."
        }},
        ["Hit Ghost"] = { RU = "Призрак при уроне", desc = {
            EN = "Leaves a glowing ghost clone at the enemy hit location.",
            RU = "Оставляет силуэт врага на месте получения урона."
        }},

        -- Settings / Interface
        ["Blur on Open"] = { RU = "Размытие фона", desc = {
            EN = "Blurs the background camera view while menu is open.",
            RU = "Размывает игровой фон при открытом меню чита."
        }},
        ["Rain Effect"] = { RU = "Дождь в меню", desc = {
            EN = "Renders animated rain particles inside the menu window.",
            RU = "Отображает капли дождя внутри окна меню."
        }},
        ["Snow Effect"] = { RU = "Снег в меню", desc = {
            EN = "Renders animated snowflakes falling inside the menu window.",
            RU = "Отображает падающий снег внутри окна меню."
        }},
        ["Keybinds List"] = { RU = "Список биндов", desc = {
            EN = "Shows on-screen HUD with currently active keybinds.",
            RU = "Отображает окно с активными горячими клавишами."
        }},
        ["Watermark"] = { RU = "Ватермарк", desc = {
            EN = "Shows top status watermark bar with FPS, ping, time and server.",
            RU = "Отображает верхнюю статус-панель с FPS, пингом, временем и сервером."
        }},
        ["Menu Key"] = { RU = "Кнопка меню", desc = {
            EN = "Key or mouse button used to open and close this menu.",
            RU = "Клавиша или кнопка мыши для открытия и закрытия меню."
        }},
        ["Language"] = { RU = "Язык интерфейса", desc = {
            EN = "Switches interface language between English and Russian.",
            RU = "Переключает язык интерфейса меню между English и Русский."
        }},
        ["Reset HUD Positions"] = { RU = "Сброс позиций HUD", desc = {
            EN = "Resets Keybinds and Admins HUD windows to default coordinates.",
            RU = "Сбрасывает положение окон биндов и админов."
        }},
        ["Unload Script"] = { RU = "Выгрузить скрипт", desc = {
            EN = "Completely closes and cleans up all script modules and GUIs.",
            RU = "Полностью отключает и удаляет все модули чита и GUI."
        }},
        ["Eject Bind"] = { RU = "Выгрузка чита", desc = {
            EN = "Keybind to instantly unload and remove the script.",
            RU = "Бинд для моментальной выгрузки и очистки скрипта."
        }},
        ["Freecam"] = { RU = "Свободная камера", desc = {
            EN = "Allows free 3D camera flight and world exploration.",
            RU = "Свободный полет камеры для осмотра карты."
        }},
        ["Teleport on click"] = { RU = "Телепорт по клику", desc = {
            EN = "Teleports your character to the clicked surface in Freecam.",
            RU = "Телепортирует персонажа в точку клика мыши в режиме Freecam."
        }},
        ["Teleport on disable"] = { RU = "Телепорт при выключении", desc = {
            EN = "Teleports character to camera position when exiting Freecam.",
            RU = "Телепортирует персонажа в точку остановки камеры при отключении Freecam."
        }},
        ["Teleport to Camera"] = { RU = "Телепорт к камере", desc = {
            EN = "Instantly teleports your character to the freecam camera position.",
            RU = "Мгновенно телепортирует персонажа в точку, где остановилась камера."
        }},
        ["Lock Character Position"] = { RU = "Фиксация позиции персонажа", desc = {
            EN = "Locks and anchors character in place while moving camera.",
            RU = "Фиксирует позицию персонажа на месте во время полета камеры."
        }},

        -- Player / Misc
        ["Anti-AFK"] = { RU = "Анти-АФК", desc = {
            EN = "Prevents being disconnected for inactivity after 20 minutes.",
            RU = "Защищает от отключения от сервера за неактивность."
        }},
        ["Admin Detector"] = { RU = "Детектор админов", desc = {
            EN = "Scans server playerlist for staff members and moderators.",
            RU = "Отслеживает модераторов и администраторов на сервере."
        }},
        ["Admins HUD"] = { RU = "Окно админов", desc = {
            EN = "Displays floating list of detected staff members.",
            RU = "Показывает панель со списком найденных админов."
        }},
        ["Auto-Hide Empty HUD"] = { RU = "Скрывать если пусто", desc = {
            EN = "Automatically hides admin HUD when no staff are in server.",
            RU = "Скрывает окно админов, если на сервере никого нет."
        }},
        ["Staff Alerts"] = { RU = "Уведомление об админах", desc = {
            EN = "Sends on-screen warning banner when a staff member joins.",
            RU = "Показывает предупреждение при заходе админа на сервер."
        }},

        -- Sliders
        ["FOV Radius"] = { RU = "Радиус FOV", desc = {
            EN = "Radius of aimbot target search area in pixels.",
            RU = "Радиус захвата целей аимботом в пикселях."
        }},
        ["Distance"] = { RU = "Дистанция", desc = {
            EN = "Maximum distance to engage targets in studs.",
            RU = "Максимальная дистанция работы в студах."
        }},
        ["Sensitivity %"] = { RU = "Скорость наводки %", desc = {
            EN = "Aim smoothing speed: higher is faster, lower is smoother.",
            RU = "Скорость доводки: выше — быстрее, ниже — плавнее."
        }},
        ["Hitbox FOV"] = { RU = "FOV Хитбокса", desc = {
            EN = "Size of hitbox check circle for triggerbot.",
            RU = "Размер зоны проверки автовыстрела триггербота."
        }},
        ["Delay (ms)"] = { RU = "Задержка (мс)", desc = {
            EN = "Reaction delay in milliseconds before shooting.",
            RU = "Задержка в миллисекундах перед автовыстрелом."
        }},
        ["Fly Speed"] = { RU = "Скорость полета", desc = {
            EN = "Velocity speed when flying.",
            RU = "Скорость перемещения в режиме полета."
        }},
        ["Speed Boost Amount"] = { RU = "Сила ускорения", desc = {
            EN = "WalkSpeed multiplier amount.",
            RU = "Значение скорости бега персонажа."
        }},
        ["Crosshair Size"] = { RU = "Размер прицела", desc = {
            EN = "Length of each crosshair line in pixels.",
            RU = "Длина линий перекрестия в пикселях."
        }},
        ["Crosshair Gap"] = { RU = "Зазор прицела", desc = {
            EN = "Center gap spacing between crosshair lines.",
            RU = "Расстояние от центра до начала линий прицела."
        }},
        ["Crosshair Thickness"] = { RU = "Толщина линий", desc = {
            EN = "Line thickness in pixels.",
            RU = "Толщина линий перекрестия в пикселях."
        }},
        ["Spin Speed"] = { RU = "Скорость вращения", desc = {
            EN = "Rotation speed in degrees per second.",
            RU = "Скорость вращения перекрестия в градусах в секунду."
        }},
        ["Hit Sound Volume"] = { RU = "Громкость звука", desc = {
            EN = "Audio playback volume for hitsound effect.",
            RU = "Громкость звукового эффекта попадания."
        }},
        ["Hit Sound Vol"] = { RU = "Громкость звука", desc = {
            EN = "Audio playback volume for hitsound effect.",
            RU = "Громкость звукового эффекта попадания."
        }},
        ["Walk Speed"] = { RU = "Скорость бега", desc = {
            EN = "WalkSpeed multiplier amount.",
            RU = "Значение скорости бега персонажа."
        }},
        ["Prediction X"] = { RU = "Предикт X", desc = {
            EN = "Horizontal lead prediction multiplier.",
            RU = "Коэффициент упреждения цели по горизонтали."
        }},
        ["Prediction Y"] = { RU = "Предикт Y", desc = {
            EN = "Vertical lead prediction multiplier.",
            RU = "Коэффициент упреждения цели по вертикали."
        }},
        ["Ghost Duration (s)"] = { RU = "Длительность силуэта", desc = {
            EN = "How many seconds hit ghost stays visible.",
            RU = "Время отображения призрачного силуэта в секундах."
        }},

        -- Sections & Card Headers
        ["Aim Assist"] = { RU = "Аим Ассист" },
        ["Triggerbot"] = { RU = "Триггербот" },
        ["Flight & Speed"] = { RU = "Полет и Скорость" },
        ["Physics"] = { RU = "Физика" },
        ["Weather"] = { RU = "Погода" },
        ["Custom Crosshair"] = { RU = "Кастомный прицел" },
        ["ESP"] = { RU = "ВХ (ESP)" },
        ["Hit Feedback"] = { RU = "Эффекты урона" },
        ["Damage & Ghost Color"] = { RU = "Цвет урона и силуэта" },
        ["Interface"] = { RU = "Интерфейс" },
        ["System"] = { RU = "Система" },
        ["Utilities"] = { RU = "Утилиты" },
        ["Staff Detector"] = { RU = "Детектор персонала" },
        ["Detected Staff Members"] = { RU = "Найденный персонал" },
        ["Config"] = { RU = "Конфиг" },
        ["AIM SETTINGS"] = { RU = "НАСТРОЙКИ АИМА" },
        ["TRIGGERBOT SETTINGS"] = { RU = "НАСТРОЙКИ ТРИГГЕРБОТА" },
        ["SPEED SETTINGS"] = { RU = "НАСТРОЙКИ СКОРОСТИ" },
        ["CROSSHAIR SETTINGS"] = { RU = "НАСТРОЙКИ ПРИЦЕЛА" },
        ["HIT FEEDBACK SETTINGS"] = { RU = "НАСТРОЙКИ ЭФФЕКТОВ" },

        -- Tabs & Search Group Headers
        ["Combat"] = { RU = "Бой" },
        ["Movement"] = { RU = "Движение" },
        ["Visuals"] = { RU = "Визуалы" },
        ["Player"] = { RU = "Игрок" },
        ["Misc"] = { RU = "Разное" },
        ["Configs"] = { RU = "Конфиги" },
        ["Settings"] = { RU = "Настройки" },
        ["Preset"] = { RU = "Пресет темы" },
        ["Font"] = { RU = "Шрифт" },
        ["Chams Style"] = { RU = "Стиль чамсов" },
        ["COMBAT  →"] = { RU = "БОЙ  →" },
        ["MOVEMENT  →"] = { RU = "ДВИЖЕНИЕ  →" },
        ["VISUALS  →"] = { RU = "ВИЗУАЛЫ  →" },
        ["PLAYER  →"] = { RU = "ИГРОК  →" },
        ["MISC  →"] = { RU = "РАЗНОЕ  →" },
        ["CONFIG  →"] = { RU = "КОНФИГ  →" },
        ["CONFIGS  →"] = { RU = "КОНФИГИ  →" },
    },
    SetLanguage = function(lang)
        if lang ~= "EN" and lang ~= "RU" then return end
        ConfigSystem.Localization.currentLang = lang
        ConfigSystem.savedLanguage = lang
        for _, fn in ipairs(ConfigSystem.Localization.listeners) do
            pcall(fn, lang)
        end
    end,
    RegisterLabel = function(lbl, originalKey, isHeader)
        if not lbl or not originalKey then return end
        local function updateText(lang)
            local isRU = (lang == "RU")
            local trans = ConfigSystem.Localization.translations[originalKey]
            local fontToUse = ConfigSystem.currentFont or Enum.Font.Arcade
            if isRU and trans and trans.RU then
                lbl.Text = trans.RU
                lbl.Font = isHeader and Enum.Font.GothamBold or Enum.Font.GothamMedium
            else
                lbl.Text = originalKey
                lbl.Font = isHeader and (fontToUse == Enum.Font.Arcade and Enum.Font.Arcade or Enum.Font.GothamBold) or fontToUse
            end
        end
        table.insert(ConfigSystem.Localization.listeners, updateText)
        updateText(ConfigSystem.Localization.currentLang)
    end,
}

local AdminStaff = {
    enabled = true,
    groupId = 874889700,
    minRank = 249,
    maxRank = 255,
    hudVisible = true,
    autoHide = true,
    alerts = true,
    hudPosX = 20,
    hudPosY = 100,
    cache = {},
    notifiedUserIds = {},
    win = nil,
    list = nil,
    UpdateHud = nil,
    CheckIfAdmin = nil,
    ScanServer = nil,
    onListUpdated = nil,
}

local Watermark = {
    visible = true,
    posX = nil,
    posY = 20,
    win = nil,
    shadow = nil,
    SetVisible = nil,
}
local defaultFeatureBinds = {
    ["Eject Bind"] = "F10",
    ["Enabled"] = "Z",
    ["Teleport on click"] = "X",
}

local Freecam = {
    enabled = false,
    tpOnClick = false,
    tpOnDisable = true,
    lockChar = false,
    speed = 2.77,
    camConn = nil,
    inputConn = nil,
    clickConn = nil,
    origCamType = nil,
    origCamSubject = nil,
    camPos = nil,
    camRotX = 0,
    camRotY = 0,
    lockedHrpCFrame = nil,
    SetEnabled = nil,
    TeleportToCam = nil,
    UpdateCharLock = nil,
}
local HitEffects = {
    soundEnabled = true,
    soundId = "rbxassetid://4817809188",
    soundName = "Bell",
    soundVolume = 0.65,
    dmgHudEnabled = true,
    dmgHudColor = "Accent",
    ghostEnabled = true,
    ghostDuration = 0.5,
    pendingShots = {},
    lastShotTime = 0,
    RegisterShot = nil,
    PlaySound = nil,
    ShowDamage = nil,
    SpawnGhost = nil,
    UpdateDmgColor = nil,
}

local Aim = {
    enabled = false,
    fov = 220,
    smooth = 0.28,
    predict = true,
    predictAmount = 0.14,
    predictX = 0.14,
    predictY = 0.10,
    showFov = false,
    visibleCheck = false,
    healthCheck = true,
    stickyAim = false,
    maxDistance = 500,
    hitPart = "Torso",
    aimType = "Camera",
    currentTarget = nil,
    noRecoil = false,
    SetNoRecoil = nil,
}

local Triggerbot = {
    enabled = false,
    predict = true,
    predictAmount = 0.14,
    predictX = 0.14,
    predictY = 0.10,
    tolerance = 14,
    delay = 0,
    maxDistance = 500,
    hitPart = "Any",
    visibleCheck = false,
    healthCheck = true,
    lastShot = 0,
    conn = nil,
    shooting = false,
    showFov = false,
    fovCircle = nil,
    fovLabel = nil,
    UpdateFovVisual = nil,
    showTargetCircle = true,
    targetCircle = nil,
    targetStroke = nil,
    targetDot = nil,
    UpdateConnection = nil,
}

pcall(function()
    if isfolder and makefolder then
        pcall(function()
            if not isfolder(CONFIG_DIR) then
                makefolder(CONFIG_DIR)
            end
        end)
    end

    -- Migrate legacy files into nova_configs directory
    if isfile and readfile and writefile then
        pcall(function()
            if isfile(CONFIGS_FILE) then
                local rawConfigs = readfile(CONFIGS_FILE)
                local store = HttpService:JSONDecode(rawConfigs)
                if type(store) == "table" and type(store.configs) == "table" then
                    for cName, cData in pairs(store.configs) do
                        local fPath = CONFIG_DIR .. "/" .. cName .. ".json"
                        if not isfile(fPath) then
                            writefile(fPath, HttpService:JSONEncode(cData))
                        end
                    end
                end
            end
            if isfile("nova_menu_config.json") and not isfile(CONFIG_DIR .. "/default.json") then
                local raw = readfile("nova_menu_config.json")
                writefile(CONFIG_DIR .. "/default.json", raw)
            end
        end)
    end

    local loadedData = nil
    local defName = "default"
    pcall(function()
        if isfile and readfile and isfile(CONFIG_DIR .. "/_default.txt") then
            local savedDef = readfile(CONFIG_DIR .. "/_default.txt"):gsub("^%s+", ""):gsub("%s+$", "")
            if savedDef ~= "" then defName = savedDef end
        end
    end)
    ConfigSystem.defaultConfigName = defName
    ConfigSystem.activeConfig = defName
    ConfigSystem.selectedConfig = defName

    pcall(function()
        if isfile and readfile then
            local defFile = CONFIG_DIR .. "/" .. defName .. ".json"
            if isfile(defFile) then
                loadedData = HttpService:JSONDecode(readfile(defFile))
            elseif isfile(CONFIG_DIR .. "/default.json") then
                loadedData = HttpService:JSONDecode(readfile(CONFIG_DIR .. "/default.json"))
            end
        end
    end)

    if type(loadedData) == "table" then
        local data = loadedData
        if data.w and data.h then
            savedW = math.clamp(tonumber(data.w) or 580, 440, 920)
            savedH = math.clamp(tonumber(data.h) or 340, 260, 640)
        end
        if data.accentH then accentH = tonumber(data.accentH) or accentH end
        if data.accentS then accentS = tonumber(data.accentS) or accentS end
        if data.accentV then accentV = tonumber(data.accentV) or accentV end
        if data.menuTheme and ConfigSystem then ConfigSystem.savedMenuTheme = tostring(data.menuTheme) end
        if data.toggleKey and type(data.toggleKey) == "string" and ConfigSystem then ConfigSystem.savedToggleKey = data.toggleKey end
        if data.language and (data.language == "EN" or data.language == "RU") and ConfigSystem and ConfigSystem.Localization then
            ConfigSystem.Localization.currentLang = data.language
            ConfigSystem.savedLanguage = data.language
        end
        if type(data.binds) == "table" then savedBinds = data.binds end
        if type(data.toggles) == "table" then
            savedToggles = data.toggles
            savedToggles["Eject Bind"] = false
        end
        if data.chamsMode then savedChamsMode = tostring(data.chamsMode) end
        if type(data.aim) == "table" then
            if data.aim.fov then Aim.fov = math.clamp(tonumber(data.aim.fov) or 350, 30, 800) end
            if data.aim.smooth then Aim.smooth = math.clamp(tonumber(data.aim.smooth) or 0.30, 0.05, 1.0) end
            if data.aim.predict ~= nil then Aim.predict = (data.aim.predict == true) end
            if data.aim.predictAmount then Aim.predictAmount = math.clamp(tonumber(data.aim.predictAmount) or 0.14, 0.0, 0.5) end
            if data.aim.predictX then Aim.predictX = math.clamp(tonumber(data.aim.predictX) or 0.14, 0.0, 0.5)
            elseif data.aim.predictAmount then Aim.predictX = Aim.predictAmount end
            if data.aim.predictY then Aim.predictY = math.clamp(tonumber(data.aim.predictY) or 0.14, 0.0, 0.5)
            elseif data.aim.predictAmount then Aim.predictY = Aim.predictAmount end
            if data.aim.showFov ~= nil then Aim.showFov = (data.aim.showFov == true) end
            if data.aim.visibleCheck ~= nil then Aim.visibleCheck = (data.aim.visibleCheck == true) end
            if data.aim.healthCheck ~= nil then Aim.healthCheck = (data.aim.healthCheck == true) end
            if data.aim.stickyAim ~= nil then Aim.stickyAim = (data.aim.stickyAim == true) end
            if data.aim.maxDistance then Aim.maxDistance = math.clamp(tonumber(data.aim.maxDistance) or 500, 50, 2000) end
            if data.aim.hitPart then Aim.hitPart = tostring(data.aim.hitPart) end
            if data.aim.aimType then Aim.aimType = tostring(data.aim.aimType) end
            if data.aim.noRecoil ~= nil then Aim.noRecoil = (data.aim.noRecoil == true) end
        end
        if type(data.triggerbot) == "table" then
            if data.triggerbot.predict ~= nil then Triggerbot.predict = (data.triggerbot.predict == true) end
            if data.triggerbot.predictX then Triggerbot.predictX = math.clamp(tonumber(data.triggerbot.predictX) or 0.14, 0.0, 0.5) end
            if data.triggerbot.predictY then Triggerbot.predictY = math.clamp(tonumber(data.triggerbot.predictY) or 0.14, 0.0, 0.5) end
            if data.triggerbot.tolerance then Triggerbot.tolerance = math.clamp(tonumber(data.triggerbot.tolerance) or 22, 5, 100) end
            if data.triggerbot.delay then Triggerbot.delay = math.clamp(tonumber(data.triggerbot.delay) or 0, 0, 200) end
            if data.triggerbot.maxDistance then Triggerbot.maxDistance = math.clamp(tonumber(data.triggerbot.maxDistance) or 500, 50, 2000) end
            if data.triggerbot.hitPart then Triggerbot.hitPart = tostring(data.triggerbot.hitPart) end
            if data.triggerbot.visibleCheck ~= nil then Triggerbot.visibleCheck = (data.triggerbot.visibleCheck == true) end
            if data.triggerbot.healthCheck ~= nil then Triggerbot.healthCheck = (data.triggerbot.healthCheck == true) end
            if data.triggerbot.showFov ~= nil then Triggerbot.showFov = (data.triggerbot.showFov == true) end
            if data.triggerbot.showTargetCircle ~= nil then Triggerbot.showTargetCircle = (data.triggerbot.showTargetCircle == true) end
        end
        if type(data.crosshair) == "table" then
            if data.crosshair.enabled ~= nil then Crosshair.enabled = (data.crosshair.enabled == true) end
            if data.crosshair.followMouse ~= nil then Crosshair.followMouse = (data.crosshair.followMouse == true) end
            if data.crosshair.spin ~= nil then Crosshair.spin = (data.crosshair.spin == true) end
            if data.crosshair.spinSpeed then Crosshair.spinSpeed = tonumber(data.crosshair.spinSpeed) or 120 end
            if data.crosshair.size then Crosshair.size = tonumber(data.crosshair.size) or 10 end
            if data.crosshair.gap then Crosshair.gap = tonumber(data.crosshair.gap) or 4 end
            if data.crosshair.thickness then Crosshair.thickness = tonumber(data.crosshair.thickness) or 2 end
            if data.crosshair.dot ~= nil then Crosshair.dot = (data.crosshair.dot == true) end
            if data.crosshair.useAccent ~= nil then Crosshair.useAccent = (data.crosshair.useAccent == true) end
            if data.crosshair.colorR and data.crosshair.colorG and data.crosshair.colorB then
                Crosshair.color = Color3.fromRGB(data.crosshair.colorR, data.crosshair.colorG, data.crosshair.colorB)
            end
        end

        if type(data.hitEffects) == "table" then
            if data.hitEffects.soundEnabled ~= nil then HitEffects.soundEnabled = (data.hitEffects.soundEnabled == true) end
            if data.hitEffects.soundId then HitEffects.soundId = tostring(data.hitEffects.soundId) end
            if data.hitEffects.soundName then
            local sName = tostring(data.hitEffects.soundName)
            if sName == "Rust" or data.hitEffects.soundId == "rbxassetid://5043539554" then
                sName = "Ding"
                HitEffects.soundId = "rbxassetid://4018616850"
            end
            HitEffects.soundName = sName
        end
            if data.hitEffects.soundVolume then HitEffects.soundVolume = tonumber(data.hitEffects.soundVolume) or 0.65 end
            if data.hitEffects.dmgHudEnabled ~= nil then HitEffects.dmgHudEnabled = (data.hitEffects.dmgHudEnabled == true) end
            if data.hitEffects.dmgHudColor then HitEffects.dmgHudColor = tostring(data.hitEffects.dmgHudColor) end
            if data.hitEffects.ghostEnabled ~= nil then HitEffects.ghostEnabled = (data.hitEffects.ghostEnabled == true) end
            if data.hitEffects.ghostDuration then HitEffects.ghostDuration = math.clamp(tonumber(data.hitEffects.ghostDuration) or 1.2, 0.3, 5.0) end
        end
        if data.kbHudVisible ~= nil then kbHudVisible = (data.kbHudVisible == true) end
        if data.kbHudX then
            local x = tonumber(data.kbHudX) or 20
            kbHudPosX = (x < 0 or x > 3840) and 20 or x
        end
        if data.kbHudY then
            local y = tonumber(data.kbHudY) or 220
            kbHudPosY = (y < 0 or y > 2160) and 220 or y
        end
        if data.flySpeed then savedFlySpeed = tonumber(data.flySpeed) or 50 end
        if data.speedBoostValue then savedSpeedBoost = tonumber(data.speedBoostValue) or 42 end
        if data.adminStaffEnabled ~= nil then AdminStaff.enabled = (data.adminStaffEnabled == true) end
        if data.adminHudVisible ~= nil then AdminStaff.hudVisible = (data.adminHudVisible == true) end
        if data.adminHudAutoHide ~= nil then AdminStaff.autoHide = (data.adminHudAutoHide == true) end
        if data.adminAlerts ~= nil then AdminStaff.alerts = (data.adminAlerts == true) end
        if data.adminHudX then
            local x = tonumber(data.adminHudX) or 20
            AdminStaff.hudPosX = (x < 0 or x > 3840) and 20 or x
        end
        if data.adminHudY then
            local y = tonumber(data.adminHudY) or 100
            AdminStaff.hudPosY = (y < 0 or y > 2160) and 100 or y
        end
        if type(data.freecam) == "table" then
            if data.freecam.enabled ~= nil then Freecam.enabled = (data.freecam.enabled == true) end
            if data.freecam.tpOnClick ~= nil then Freecam.tpOnClick = (data.freecam.tpOnClick == true) end
            if data.freecam.tpOnDisable ~= nil then Freecam.tpOnDisable = (data.freecam.tpOnDisable == true) end
            if data.freecam.lockChar ~= nil then Freecam.lockChar = (data.freecam.lockChar == true) end
            if data.freecam.speed then Freecam.speed = math.clamp(tonumber(data.freecam.speed) or 2.77, 0.1, 20.0) end
        end
        if data.watermarkVisible ~= nil then
            Watermark.visible = (data.watermarkVisible == true)
            if Watermark.SetVisible then Watermark.SetVisible(Watermark.visible) end
        end
        if data.watermarkScaleX ~= nil then Watermark.scaleX = tonumber(data.watermarkScaleX) end
        if data.watermarkX ~= nil then Watermark.posX = tonumber(data.watermarkX) end
        if data.watermarkScaleY ~= nil then Watermark.scaleY = tonumber(data.watermarkScaleY) end
        if data.watermarkY ~= nil then Watermark.posY = tonumber(data.watermarkY) end
        if Watermark.win then
            Watermark.win.AnchorPoint = Vector2.new(0.5, 0.5)
            if Watermark.shadow then Watermark.shadow.AnchorPoint = Vector2.new(0.5, 0.5) end
            local sx = Watermark.scaleX or (Watermark.posX and 0 or 0.5)
            local ox = Watermark.posX or 0
            local sy = Watermark.scaleY or 0
            local oy = Watermark.posY or 20
            Watermark.win.Position = UDim2.new(sx, ox, sy, oy)
            if Watermark.shadow then Watermark.shadow.Position = UDim2.new(sx, ox, sy, oy + 1) end
        end
    end
end)

-- ══════════════════════════════════════════════
--  THEME & COLOR STATE
-- ══════════════════════════════════════════════
if ConfigSystem then
    ConfigSystem.themePresets = {
        {name="Dark",        bg=Color3.fromRGB(16, 16, 18), side=Color3.fromRGB(13, 13, 15), top=Color3.fromRGB(13, 13, 15), card=Color3.fromRGB(22, 22, 25)},
        {name="Light",       bg=Color3.fromRGB(236, 238, 244), side=Color3.fromRGB(222, 225, 234), top=Color3.fromRGB(222, 225, 234), card=Color3.fromRGB(248, 249, 253), isLight=true},
        {name="Midnight",    bg=Color3.fromRGB(14, 12, 22), side=Color3.fromRGB(10, 8, 16),  top=Color3.fromRGB(10, 8, 16),  card=Color3.fromRGB(20, 17, 32)},
        {name="Nord",        bg=Color3.fromRGB(15, 18, 26), side=Color3.fromRGB(11, 14, 20), top=Color3.fromRGB(11, 14, 20), card=Color3.fromRGB(22, 27, 38)},
        {name="Mocha",       bg=Color3.fromRGB(18, 16, 21), side=Color3.fromRGB(13, 11, 16), top=Color3.fromRGB(13, 11, 16), card=Color3.fromRGB(26, 23, 31)},
        {name="Catppuccin",  bg=Color3.fromRGB(17, 17, 27), side=Color3.fromRGB(12, 12, 19), top=Color3.fromRGB(12, 12, 19), card=Color3.fromRGB(24, 24, 37)},
        {name="Tokyo Night", bg=Color3.fromRGB(13, 14, 24), side=Color3.fromRGB(9, 10, 18),  top=Color3.fromRGB(9, 10, 18),  card=Color3.fromRGB(20, 22, 36)},
        {name="Dracula",     bg=Color3.fromRGB(20, 16, 26), side=Color3.fromRGB(14, 11, 20), top=Color3.fromRGB(14, 11, 20), card=Color3.fromRGB(28, 22, 38)},
        {name="Gruvbox",     bg=Color3.fromRGB(20, 18, 15), side=Color3.fromRGB(15, 13, 10), top=Color3.fromRGB(15, 13, 10), card=Color3.fromRGB(28, 25, 21)},
        {name="Rose Pine",   bg=Color3.fromRGB(18, 14, 20), side=Color3.fromRGB(13, 10, 15), top=Color3.fromRGB(13, 10, 15), card=Color3.fromRGB(25, 20, 29)},
        {name="Solarized",   bg=Color3.fromRGB(7, 24, 30),  side=Color3.fromRGB(4, 18, 23),  top=Color3.fromRGB(4, 18, 23),  card=Color3.fromRGB(11, 33, 40)},
        {name="One Dark",    bg=Color3.fromRGB(18, 20, 24), side=Color3.fromRGB(13, 15, 18), top=Color3.fromRGB(13, 15, 18), card=Color3.fromRGB(25, 27, 33)},
        {name="Glass",       bg=Color3.fromRGB(15, 15, 18), side=Color3.fromRGB(12, 12, 15), top=Color3.fromRGB(12, 12, 15), card=Color3.fromRGB(20, 20, 25), trans=0.32, cardTrans=0.72, subTrans=0.55, borderColor=Color3.fromRGB(36, 36, 42), borderTrans=0.6},
    }
    ConfigSystem.savedMenuTheme = ConfigSystem.savedMenuTheme or "Dark"

    ConfigSystem.fontPresets = {
        {name = "ProggyClean",       font = Enum.Font.RobotoMono},
        {name = "Sentinel",          font = Enum.Font.SourceSans},
        {name = "Noto San",          font = Enum.Font.GothamMedium},
        {name = "Minecraft",         font = Enum.Font.Arcade},
        {name = "Tahoma",            font = Enum.Font.Ubuntu},
        {name = "Pixel",             font = Enum.Font.Arcade},
        {name = "Jetbrains",         font = Enum.Font.Code},
        {name = "Proxima Soft Bold", font = Enum.Font.GothamBold},
    }
    ConfigSystem.savedFont = ConfigSystem.savedFont or "Minecraft"
end

local T = {}
local function RebuildTheme()
    T.accent     = Color3.fromHSV(accentH, accentS, accentV)
    T.accentOff  = Color3.fromRGB(56, 56, 68)
    local curTh = nil
    if ConfigSystem and ConfigSystem.themePresets then
        local curThName = ConfigSystem.savedMenuTheme or "Dark"
        for _, th in ipairs(ConfigSystem.themePresets) do
            if th.name == curThName then curTh = th; break end
        end
    end
    local isLight = curTh and curTh.isLight
    local isGlass = curTh and (curTh.name == "Glass")
    T.bg         = (curTh and curTh.bg) or Color3.fromRGB(16, 16, 18)
    T.sidebar    = (curTh and curTh.side) or Color3.fromRGB(13, 13, 15)
    T.topbar     = (curTh and curTh.top) or Color3.fromRGB(13, 13, 15)
    T.cardBg     = (curTh and curTh.card) or Color3.fromRGB(22, 22, 25)
    T.trans      = (curTh and curTh.trans) or 0
    T.border     = isLight and Color3.fromRGB(210, 214, 225) or Color3.fromRGB(36, 36, 46)
    T.inputBg    = isLight and Color3.fromRGB(240, 242, 248) or (isGlass and Color3.fromRGB(20, 20, 26) or Color3.fromRGB(26, 26, 34))
    T.itemHover  = isLight and Color3.fromRGB(220, 224, 235) or Color3.fromRGB(28, 28, 38)
    T.dotsBg     = isLight and Color3.fromRGB(230, 232, 240) or (isGlass and Color3.fromRGB(22, 22, 28) or Color3.fromRGB(26, 26, 36))
    T.tabActive  = isLight and Color3.fromRGB(215, 218, 230) or (isGlass and Color3.fromRGB(26, 26, 34) or Color3.fromRGB(28, 28, 38))
    T.text       = isLight and Color3.fromRGB(28, 30, 40)    or Color3.fromRGB(225, 225, 238)
    T.textDim    = isLight and Color3.fromRGB(90, 95, 115)   or Color3.fromRGB(150, 150, 165)
    T.textMuted  = isLight and Color3.fromRGB(130, 135, 150) or Color3.fromRGB(80, 80, 95)
    T.secHeader  = isLight and Color3.fromRGB(70, 75, 95)    or Color3.fromRGB(145, 148, 165)
end
RebuildTheme()

local accentElements = {}   -- {obj, prop}
local accentBarEls   = {}   -- tab accent bars {obj}
local toggleObjects  = {}   -- all toggle objects for dynamic color refresh
local allRegisteredTogglesList = {}
local featureBinds   = {}   -- [name] = { key = "V", shortKey = "V", toggle = t, name = name }
local listeningTarget = nil -- { name = "...", dotsBtn = ..., dotsF = ..., toggle = ... }
local UpdateKeybindsHud, UpdateBcmVisuals, FormatKeyName = nil, nil, nil

local function TrackAccent(obj, prop) table.insert(accentElements, {obj=obj, prop=prop}) end
local function TrackAccentBar(obj)    table.insert(accentBarEls, obj) end

local function ApplyAccentColor()
    RebuildTheme()
    for _, e in ipairs(accentElements) do
        pcall(function() e.obj[e.prop] = T.accent end)
    end
    for _, b in ipairs(accentBarEls) do
        pcall(function() b.BackgroundColor3 = T.accent end)
    end
    for _, t in ipairs(allRegisteredTogglesList) do
        pcall(function()
            if t.isEnabled and t.isEnabled() and t.tBg then
                t.tBg.BackgroundColor3 = T.accent
            end
            if featureBinds[t.name] and featureBinds[t.name].key and t.dotsBtn then
                t.dotsBtn.TextColor3 = T.accent
            end
            if t.nL and t.nL.Parent then
                t.nL.TextColor3 = (t.isEnabled and t.isEnabled()) and T.text or T.textDim
            end
        end)
    end
    if ConfigSystem and ConfigSystem.pillRefreshers then
        for _, rf in ipairs(ConfigSystem.pillRefreshers) do
            pcall(rf)
        end
    end
    if ConfigSystem and ConfigSystem.refreshList then
        pcall(ConfigSystem.refreshList)
    end
    if HitEffects and HitEffects.UpdateDmgColor then
        pcall(HitEffects.UpdateDmgColor)
    end
    if Crosshair and Crosshair.UpdateVisuals then
        pcall(Crosshair.UpdateVisuals)
    end
    if ConfigSystem and ConfigSystem.RefreshLanguageButtons then
        pcall(ConfigSystem.RefreshLanguageButtons)
    end
    if UpdateKeybindsHud then UpdateKeybindsHud() end
    if UpdateBcmVisuals then UpdateBcmVisuals() end
end

if ConfigSystem then
    ConfigSystem.ApplyMenuTheme = function(themeName)
        ConfigSystem.savedMenuTheme = themeName or ConfigSystem.savedMenuTheme or "Dark"
        RebuildTheme()
        if ConfigSystem.UpdateThemeVisuals then
            pcall(ConfigSystem.UpdateThemeVisuals)
        end
    end
    ConfigSystem.ApplyFont = function(fontName)
        ConfigSystem.savedFont = fontName or ConfigSystem.savedFont or "Minecraft"
        local chosenFont = Enum.Font.Arcade
        if ConfigSystem.fontPresets then
            for _, fp in ipairs(ConfigSystem.fontPresets) do
                if fp.name == ConfigSystem.savedFont then
                    chosenFont = fp.font
                    break
                end
            end
        end
        ConfigSystem.currentFont = chosenFont
        if ConfigSystem.Localization and ConfigSystem.Localization.listeners then
            for _, fn in ipairs(ConfigSystem.Localization.listeners) do
                pcall(fn, ConfigSystem.Localization.currentLang)
            end
        end
        if ConfigSystem.fontRefreshers then
            for _, fn in ipairs(ConfigSystem.fontRefreshers) do
                pcall(fn)
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════
local TOGGLE_KEY = (ConfigSystem and ConfigSystem.savedToggleKey) or "Delete"
local menuOpen   = true
local currentTab = "Combat"
local tabPages   = {}
local tabBtns    = {}
local allConn    = {}
local UpdateSearch
local SwitchTab
local SetFly, SetSpeed, SetNoclip, SetInfiniteJump, SetPlayerESP, SetAimbot, SetTriggerbot
local flySpeed = savedFlySpeed or 50
local speedBoostValue = savedSpeedBoost or 42

-- min/max window size for resize
local MIN_W, MAX_W, MIN_H, MAX_H = 440, 920, 260, 640

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
local function Crn(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function Strk(p, col, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or T.border; s.Thickness = t or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function Tw(o, pr, d, st, dir)
    if not o or not o.Parent then return end
    pcall(function() TS:Create(o, TweenInfo.new(d or .18, st or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), pr):Play() end)
end
local function Lbl(parent, text, size, col, font, xa, zx)
    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1
    l.Font = font or Enum.Font.GothamMedium; l.Text = text; l.TextSize = size or 11
    l.TextColor3 = col or T.textDim; l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.ZIndex = zx or 2; l.Parent = parent; return l
end
local function Div(parent, vertical, col)
    local d = Instance.new("Frame"); d.BackgroundColor3 = col or T.border; d.BorderSizePixel = 0
    if vertical then d.Size = UDim2.new(0, 1, 1, 0)
    else             d.Size = UDim2.new(1, 0, 0, 1) end
    d.Parent = parent; return d
end

-- ══════════════════════════════════════════════
--  SCREEN GUI & MAIN WINDOW (580 × 340)
-- ══════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name = "NOVA_GUI"; SG.ResetOnSpawn = false; SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SG.Parent = safeParent

local win = Instance.new("Frame")
win.Size = UDim2.new(0, savedW, 0, savedH); win.AnchorPoint = Vector2.new(.5, .5)
win.Position = UDim2.new(.5, 0, .5, 0); win.BackgroundColor3 = T.bg; win.BackgroundTransparency = T.trans or 0
win.BorderSizePixel = 0; win.Active = true; win.ClipsDescendants = false; win.Parent = SG
Crn(win, 8)
if ConfigSystem then
    ConfigSystem.win = win
    ConfigSystem.winStroke = Strk(win, T.border, 1, 0)
else
    Strk(win, T.border, 1, 0)
end

local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = win

local function InitTooltipSystem()
local tooltipF = Instance.new("Frame")
tooltipF.Name = "NOVA_Tooltip"
tooltipF.Size = UDim2.new(0, 220, 0, 0)
tooltipF.AutomaticSize = Enum.AutomaticSize.Y
tooltipF.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
tooltipF.BorderSizePixel = 0
tooltipF.Visible = false
tooltipF.ZIndex = 85
tooltipF.Parent = win
Crn(tooltipF, 5)
Strk(tooltipF, Color3.fromRGB(35, 38, 50), 1, 0)

local tipScale = Instance.new("UIScale")
tipScale.Scale = 1
tipScale.Parent = tooltipF

local tipPad = Instance.new("UIPadding")
tipPad.PaddingTop = UDim.new(0, 7)
tipPad.PaddingBottom = UDim.new(0, 7)
tipPad.PaddingLeft = UDim.new(0, 9)
tipPad.PaddingRight = UDim.new(0, 9)
tipPad.Parent = tooltipF

local tipLL = Instance.new("UIListLayout")
tipLL.SortOrder = Enum.SortOrder.LayoutOrder
tipLL.Padding = UDim.new(0, 3)
tipLL.Parent = tooltipF

local tipTitle = Lbl(tooltipF, "", 10, T.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 87)
tipTitle.Size = UDim2.new(1, 0, 0, 14)
tipTitle.LayoutOrder = 1
TrackAccent(tipTitle, "TextColor3")

local tipDesc = Lbl(tooltipF, "", 9, Color3.fromRGB(195, 200, 215), Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 87)
tipDesc.Size = UDim2.new(1, 0, 0, 0)
tipDesc.AutomaticSize = Enum.AutomaticSize.Y
tipDesc.TextWrapped = true
tipDesc.LayoutOrder = 2

local currentTooltipKey = nil

ConfigSystem.ShowTooltip = function(key, sourceBtn)
    if not win or not win.Parent or not menuOpen then return end
    if currentTooltipKey == key and tooltipF.Visible then
        ConfigSystem.HideTooltip()
        return
    end

    local loc = ConfigSystem.Localization
    local isRU = loc and (loc.currentLang == "RU")
    local info = loc and loc.translations and loc.translations[key]
    local titleText = key
    local descText = nil
    if info then
        if isRU and info.RU then titleText = info.RU end
        if info.desc then
            descText = isRU and info.desc.RU or info.desc.EN
        end
    end
    if not descText or descText == "" then
        tooltipF.Visible = false
        currentTooltipKey = nil
        ConfigSystem.currentTooltipKey = nil
        return
    end

    currentTooltipKey = key
    ConfigSystem.currentTooltipKey = key
    tipTitle.Text = titleText
    tipDesc.Text = descText

    local wPos = win.AbsolutePosition
    local wSize = win.AbsoluteSize
    local tipW = 220
    local rx, ry

    if sourceBtn and sourceBtn.Parent then
        local bPos = sourceBtn.AbsolutePosition
        local bSize = sourceBtn.AbsoluteSize
        rx = bPos.X - wPos.X + bSize.X + 8
        ry = bPos.Y - wPos.Y - 4
        if rx + tipW > wSize.X - 10 then
            rx = bPos.X - wPos.X - tipW - 8
        end
    else
        local mPos = UIS:GetMouseLocation()
        rx = mPos.X - wPos.X + 12
        ry = mPos.Y - wPos.Y + 12
        if rx + tipW > wSize.X - 10 then
            rx = mPos.X - wPos.X - tipW - 8
        end
    end

    local finalX = math.clamp(rx, 6, math.max(6, wSize.X - tipW - 8))
    local finalY = math.clamp(ry, 6, math.max(6, wSize.Y - 70))
    local targetPos = UDim2.new(0, finalX, 0, finalY)
    local startPos = UDim2.new(0, finalX + 14, 0, finalY)

    tooltipF.Position = startPos
    tipScale.Scale = 0.86
    tooltipF.Visible = true

    Tw(tipScale, {Scale = 1.0}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    Tw(tooltipF, {Position = targetPos}, 0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

ConfigSystem.HideTooltip = function()
    if not tooltipF or not tooltipF.Visible then
        currentTooltipKey = nil
        ConfigSystem.currentTooltipKey = nil
        return
    end
    currentTooltipKey = nil
    ConfigSystem.currentTooltipKey = nil
    Tw(tipScale, {Scale = 0.88}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.12, function()
        if currentTooltipKey == nil and tooltipF then
            tooltipF.Visible = false
        end
    end)
end

ConfigSystem.ToggleTooltip = function(key, sourceBtn)
    if currentTooltipKey == key and tooltipF and tooltipF.Visible then
        ConfigSystem.HideTooltip()
    else
        ConfigSystem.ShowTooltip(key, sourceBtn)
    end
end
end
InitTooltipSystem()

local kbWin, kbList
-- ── SAVE CONFIG HELPER ─────────────────────────
local function GetCurrentConfigData()
    local bindsToSave = {}
    for name, bindInfo in pairs(featureBinds) do
        if bindInfo and (bindInfo.key or bindInfo.mode == "Always") then
            bindsToSave[name] = {
                key = bindInfo.key,
                mode = bindInfo.mode or "Toggle",
            }
        end
    end
    local togglesToSave = {}
    for _, t in ipairs(allRegisteredTogglesList) do
        if t and t.name and t.isEnabled then
            if t.name == "Eject Bind" then
                togglesToSave[t.name] = false
            else
                togglesToSave[t.name] = t.isEnabled()
            end
        end
    end
    return {
        w = win and win.AbsoluteSize.X or savedW,
        h = win and win.AbsoluteSize.Y or savedH,
        accentH = accentH,
        accentS = accentS,
        accentV = accentV,
        menuTheme = (ConfigSystem and ConfigSystem.savedMenuTheme) or "Dark",
        font = (ConfigSystem and ConfigSystem.savedFont) or "Minecraft",
        toggleKey = TOGGLE_KEY or "Delete",
        language = (ConfigSystem and ConfigSystem.Localization and ConfigSystem.Localization.currentLang) or "EN",
        binds = bindsToSave,
        toggles = togglesToSave,
        aim = {
            fov = Aim.fov,
            smooth = Aim.smooth,
            predict = Aim.predict,
            predictAmount = Aim.predictAmount,
            predictX = Aim.predictX,
            predictY = Aim.predictY,
            showFov = Aim.showFov,
            visibleCheck = Aim.visibleCheck,
            healthCheck = Aim.healthCheck,
            stickyAim = Aim.stickyAim,
            maxDistance = Aim.maxDistance,
            hitPart = Aim.hitPart,
            aimType = Aim.aimType,
            noRecoil = Aim.noRecoil,
        },
        triggerbot = {
            enabled = Triggerbot.enabled,
            predict = Triggerbot.predict,
            predictX = Triggerbot.predictX,
            predictY = Triggerbot.predictY,
            tolerance = Triggerbot.tolerance,
            delay = Triggerbot.delay,
            maxDistance = Triggerbot.maxDistance,
            hitPart = Triggerbot.hitPart,
            visibleCheck = Triggerbot.visibleCheck,
            healthCheck = Triggerbot.healthCheck,
            showFov = Triggerbot.showFov,
            showTargetCircle = Triggerbot.showTargetCircle,
        },
        crosshair = {
            enabled = Crosshair.enabled,
            followMouse = Crosshair.followMouse,
            spin = Crosshair.spin,
            spinSpeed = Crosshair.spinSpeed,
            size = Crosshair.size,
            gap = Crosshair.gap,
            thickness = Crosshair.thickness,
            dot = Crosshair.dot,
            useAccent = Crosshair.useAccent,
            colorR = math.floor(Crosshair.color.R * 255 + 0.5),
            colorG = math.floor(Crosshair.color.G * 255 + 0.5),
            colorB = math.floor(Crosshair.color.B * 255 + 0.5),
        },

        hitEffects = {
            soundEnabled = HitEffects.soundEnabled,
            soundId = HitEffects.soundId,
            soundName = HitEffects.soundName,
            soundVolume = HitEffects.soundVolume,
            dmgHudEnabled = HitEffects.dmgHudEnabled,
            dmgHudColor = HitEffects.dmgHudColor or "Accent",
            ghostEnabled = HitEffects.ghostEnabled,
            ghostDuration = HitEffects.ghostDuration,
        },
        kbHudVisible = kbHudVisible,
        kbHudX = kbWin and kbWin.Position.X.Offset or kbHudPosX,
        kbHudY = kbWin and kbWin.Position.Y.Offset or kbHudPosY,
        flySpeed = flySpeed,
        speedBoostValue = speedBoostValue,
        chamsMode = (ESP and ESP.chamsMode) or savedChamsMode or "VisCheck",
        adminStaffEnabled = AdminStaff.enabled,
        adminHudVisible = AdminStaff.hudVisible,
        adminHudAutoHide = AdminStaff.autoHide,
        adminAlerts = AdminStaff.alerts,
        adminHudX = AdminStaff.win and AdminStaff.win.Position.X.Offset or AdminStaff.hudPosX,
        adminHudY = AdminStaff.win and AdminStaff.win.Position.Y.Offset or AdminStaff.hudPosY,
        watermarkVisible = (Watermark.visible ~= false),
        watermarkScaleX = Watermark.scaleX or (Watermark.win and Watermark.win.Position.X.Scale) or 0.5,
        watermarkX = Watermark.posX or (Watermark.win and Watermark.win.Position.X.Offset) or 0,
        watermarkScaleY = Watermark.scaleY or (Watermark.win and Watermark.win.Position.Y.Scale) or 0,
        watermarkY = Watermark.posY or (Watermark.win and Watermark.win.Position.Y.Offset) or 20,
        freecam = {
            enabled = Freecam.enabled,
            tpOnClick = Freecam.tpOnClick,
            tpOnDisable = Freecam.tpOnDisable,
            lockChar = Freecam.lockChar,
            speed = Freecam.speed or 2.77,
        },
    }
end

local function ApplyConfigData(data)
    if type(data) ~= "table" then return end
    if data.accentH then accentH = tonumber(data.accentH) or accentH end
    if data.accentS then accentS = tonumber(data.accentS) or accentS end
    if data.accentV then accentV = tonumber(data.accentV) or accentV end
    if data.menuTheme and ConfigSystem and ConfigSystem.ApplyMenuTheme then
        ConfigSystem.ApplyMenuTheme(data.menuTheme)
    end
    if data.font and ConfigSystem and ConfigSystem.ApplyFont then
        ConfigSystem.ApplyFont(data.font)
    end
    if data.toggleKey and type(data.toggleKey) == "string" then
        TOGGLE_KEY = data.toggleKey
        if ConfigSystem then
            ConfigSystem.savedToggleKey = data.toggleKey
            if ConfigSystem.UpdateMenuKeyUI then ConfigSystem.UpdateMenuKeyUI() end
        end
    end
    if data.language and (data.language == "EN" or data.language == "RU") and ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.SetLanguage(data.language)
    end
    if ApplyAccentColor then ApplyAccentColor() end

    if data.chamsMode then
        savedChamsMode = tostring(data.chamsMode)
        if ESP then
            ESP.chamsMode = savedChamsMode
            if RefreshAllESP then RefreshAllESP() end
        end
    end

    if type(data.aim) == "table" then
        if data.aim.fov then Aim.fov = math.clamp(tonumber(data.aim.fov) or 350, 30, 800) end
        if data.aim.smooth then Aim.smooth = math.clamp(tonumber(data.aim.smooth) or 0.30, 0.05, 1.0) end
        if data.aim.predict ~= nil then Aim.predict = (data.aim.predict == true) end
        if data.aim.predictAmount then Aim.predictAmount = math.clamp(tonumber(data.aim.predictAmount) or 0.14, 0.0, 0.5) end
        if data.aim.predictX then Aim.predictX = math.clamp(tonumber(data.aim.predictX) or 0.14, 0.0, 0.5)
        elseif data.aim.predictAmount then Aim.predictX = Aim.predictAmount end
        if data.aim.predictY then Aim.predictY = math.clamp(tonumber(data.aim.predictY) or 0.14, 0.0, 0.5)
        elseif data.aim.predictAmount then Aim.predictY = Aim.predictAmount end
        if data.aim.showFov ~= nil then Aim.showFov = (data.aim.showFov == true) end
        if data.aim.visibleCheck ~= nil then Aim.visibleCheck = (data.aim.visibleCheck == true) end
        if data.aim.healthCheck ~= nil then Aim.healthCheck = (data.aim.healthCheck == true) end
        if data.aim.stickyAim ~= nil then Aim.stickyAim = (data.aim.stickyAim == true) end
        if data.aim.maxDistance then Aim.maxDistance = math.clamp(tonumber(data.aim.maxDistance) or 500, 50, 2000) end
        if data.aim.hitPart then Aim.hitPart = tostring(data.aim.hitPart) end
        if data.aim.aimType then Aim.aimType = tostring(data.aim.aimType) end
        if data.aim.noRecoil ~= nil then
            Aim.noRecoil = (data.aim.noRecoil == true)
            if Aim.SetNoRecoil then Aim.SetNoRecoil(Aim.noRecoil) end
        end
        if UpdateFovVisual then UpdateFovVisual() end
    end

    if type(data.triggerbot) == "table" then
        if data.triggerbot.predict ~= nil then Triggerbot.predict = (data.triggerbot.predict == true) end
        if data.triggerbot.predictX then Triggerbot.predictX = math.clamp(tonumber(data.triggerbot.predictX) or 0.14, 0.0, 0.5) end
        if data.triggerbot.predictY then Triggerbot.predictY = math.clamp(tonumber(data.triggerbot.predictY) or 0.14, 0.0, 0.5) end
        if data.triggerbot.tolerance then Triggerbot.tolerance = math.clamp(tonumber(data.triggerbot.tolerance) or 22, 5, 100) end
        if data.triggerbot.delay then Triggerbot.delay = math.clamp(tonumber(data.triggerbot.delay) or 0, 0, 200) end
        if data.triggerbot.maxDistance then Triggerbot.maxDistance = math.clamp(tonumber(data.triggerbot.maxDistance) or 500, 50, 2000) end
        if data.triggerbot.hitPart then Triggerbot.hitPart = tostring(data.triggerbot.hitPart) end
        if data.triggerbot.visibleCheck ~= nil then Triggerbot.visibleCheck = (data.triggerbot.visibleCheck == true) end
        if data.triggerbot.healthCheck ~= nil then Triggerbot.healthCheck = (data.triggerbot.healthCheck == true) end
        if data.triggerbot.showFov ~= nil then Triggerbot.showFov = (data.triggerbot.showFov == true) end
        if data.triggerbot.showTargetCircle ~= nil then Triggerbot.showTargetCircle = (data.triggerbot.showTargetCircle == true) end
        if Triggerbot.UpdateFovVisual then Triggerbot.UpdateFovVisual() end
        if Triggerbot.UpdateConnection then Triggerbot.UpdateConnection() end
    end

    if type(data.crosshair) == "table" then
        if data.crosshair.enabled ~= nil then Crosshair.enabled = (data.crosshair.enabled == true) end
        if data.crosshair.followMouse ~= nil then Crosshair.followMouse = (data.crosshair.followMouse == true) end
        if data.crosshair.spin ~= nil then Crosshair.spin = (data.crosshair.spin == true) end
        if data.crosshair.spinSpeed then Crosshair.spinSpeed = tonumber(data.crosshair.spinSpeed) or 120 end
        if data.crosshair.size then Crosshair.size = tonumber(data.crosshair.size) or 10 end
        if data.crosshair.gap then Crosshair.gap = tonumber(data.crosshair.gap) or 4 end
        if data.crosshair.thickness then Crosshair.thickness = tonumber(data.crosshair.thickness) or 2 end
        if data.crosshair.dot ~= nil then Crosshair.dot = (data.crosshair.dot == true) end
        if data.crosshair.useAccent ~= nil then Crosshair.useAccent = (data.crosshair.useAccent == true) end
        if data.crosshair.colorR and data.crosshair.colorG and data.crosshair.colorB then
            Crosshair.color = Color3.fromRGB(data.crosshair.colorR, data.crosshair.colorG, data.crosshair.colorB)
        end
        if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
    end

    if type(data.hitEffects) == "table" then
        if data.hitEffects.soundEnabled ~= nil then HitEffects.soundEnabled = (data.hitEffects.soundEnabled == true) end
        if data.hitEffects.soundId then HitEffects.soundId = tostring(data.hitEffects.soundId) end
        if data.hitEffects.soundName then HitEffects.soundName = tostring(data.hitEffects.soundName) end
        if data.hitEffects.soundVolume then HitEffects.soundVolume = tonumber(data.hitEffects.soundVolume) or 0.65 end
        if data.hitEffects.dmgHudEnabled ~= nil then HitEffects.dmgHudEnabled = (data.hitEffects.dmgHudEnabled == true) end
        if data.hitEffects.dmgHudColor then HitEffects.dmgHudColor = tostring(data.hitEffects.dmgHudColor) end
        if data.hitEffects.ghostEnabled ~= nil then HitEffects.ghostEnabled = (data.hitEffects.ghostEnabled == true) end
        if data.hitEffects.ghostDuration then HitEffects.ghostDuration = math.clamp(tonumber(data.hitEffects.ghostDuration) or 1.2, 0.3, 5.0) end
        if HitEffects.UpdateDmgColor then HitEffects.UpdateDmgColor() end
    end

    if data.flySpeed then flySpeed = tonumber(data.flySpeed) or flySpeed end
    if data.speedBoostValue then speedBoostValue = tonumber(data.speedBoostValue) or speedBoostValue end

    if data.adminStaffEnabled ~= nil then AdminStaff.enabled = (data.adminStaffEnabled == true) end
    if data.adminHudVisible ~= nil then AdminStaff.hudVisible = (data.adminHudVisible == true) end
    if data.adminHudAutoHide ~= nil then AdminStaff.autoHide = (data.adminHudAutoHide == true) end
    if data.watermarkVisible ~= nil then
        Watermark.visible = (data.watermarkVisible == true)
        if Watermark.SetVisible then Watermark.SetVisible(Watermark.visible) end
    end
    if data.watermarkScaleX ~= nil then Watermark.scaleX = tonumber(data.watermarkScaleX) end
    if data.watermarkX ~= nil then Watermark.posX = tonumber(data.watermarkX) end
    if data.watermarkScaleY ~= nil then Watermark.scaleY = tonumber(data.watermarkScaleY) end
    if data.watermarkY ~= nil then Watermark.posY = tonumber(data.watermarkY) end
    if Watermark.win then
        Watermark.win.AnchorPoint = Vector2.new(0.5, 0.5)
        if Watermark.shadow then Watermark.shadow.AnchorPoint = Vector2.new(0.5, 0.5) end
        local sx = Watermark.scaleX or (Watermark.posX and 0 or 0.5)
        local ox = Watermark.posX or 0
        local sy = Watermark.scaleY or 0
        local oy = Watermark.posY or 20
        Watermark.win.Position = UDim2.new(sx, ox, sy, oy)
        if Watermark.shadow then Watermark.shadow.Position = UDim2.new(sx, ox, sy, oy + 1) end
    end
    if data.adminAlerts ~= nil then AdminStaff.alerts = (data.adminAlerts == true) end
    if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end

    if type(data.freecam) == "table" then
        if data.freecam.enabled ~= nil then
            Freecam.enabled = (data.freecam.enabled == true)
            if Freecam.SetEnabled then Freecam.SetEnabled(Freecam.enabled) end
        end
        if data.freecam.tpOnClick ~= nil then Freecam.tpOnClick = (data.freecam.tpOnClick == true) end
        if data.freecam.tpOnDisable ~= nil then Freecam.tpOnDisable = (data.freecam.tpOnDisable == true) end
        if data.freecam.lockChar ~= nil then
            Freecam.lockChar = (data.freecam.lockChar == true)
            if Freecam.UpdateCharLock then Freecam.UpdateCharLock() end
        end
        if data.freecam.speed then
            Freecam.speed = math.clamp(tonumber(data.freecam.speed) or 2.77, 0.1, 20.0)
            if allSliders["Freecam Speed"] then
                allSliders["Freecam Speed"].SetValue(Freecam.speed, true)
            elseif allSliders["Speed"] then
                allSliders["Speed"].SetValue(Freecam.speed, true)
            end
        end
    end

    -- Sync all registered toggles (skipSaveState to prevent I/O lag)
    if type(data.toggles) == "table" then
        for _, t in ipairs(allRegisteredTogglesList) do
            if t and t.name and data.toggles[t.name] ~= nil and t.name ~= "Eject Bind" then
                t.setToggleState(data.toggles[t.name] == true, true, true)
            end
        end
    end

    -- Sync all registered binds
    if type(data.binds) == "table" then
        featureBinds = {}
        for _, t in ipairs(allRegisteredTogglesList) do
            if not t.noBind then
                local rawB = data.binds[t.name]
                if rawB then
                    local bKey = (type(rawB) == "table" and rawB.key) or (type(rawB) == "string" and rawB)
                    local bMode = (type(rawB) == "table" and rawB.mode) or "Toggle"
                    local shortK = "..."
                    if bKey and FormatKeyName then
                        pcall(function() shortK = FormatKeyName(bKey) end)
                    end
                    featureBinds[t.name] = {
                        key = bKey,
                        shortKey = shortK,
                        mode = bMode,
                        toggle = t,
                        name = t.name,
                    }
                    if t.dotsBtn then
                        if bKey then
                            t.dotsBtn.Text = shortK
                            t.dotsBtn.TextColor3 = T.accent
                        elseif bMode == "Always" then
                            t.dotsBtn.Text = "ALW"
                            t.dotsBtn.TextColor3 = T.accent
                        else
                            t.dotsBtn.Text = "..."
                            t.dotsBtn.TextColor3 = T.textMuted
                        end
                    end
                elseif t.dotsBtn then
                    t.dotsBtn.Text = "..."
                    t.dotsBtn.TextColor3 = T.textMuted
                end
            end
        end
    end

    -- Sync all active slider controls in UI
    if allSliders["FOV Radius"] and data.aim and data.aim.fov then
        allSliders["FOV Radius"].SetValue(data.aim.fov, true)
    end
    if allSliders["Distance"] and data.aim and data.aim.maxDistance then
        allSliders["Distance"].SetValue(data.aim.maxDistance, true)
    end
    if allSliders["Sensitivity %"] and data.aim and data.aim.smooth then
        allSliders["Sensitivity %"].SetValue(math.floor(data.aim.smooth * 100 + 0.5), true)
    end
    if allSliders["Aim Prediction X"] and data.aim and data.aim.predictX then
        allSliders["Aim Prediction X"].SetValue(data.aim.predictX, true)
    elseif allSliders["Prediction X"] and data.aim and data.aim.predictX then
        allSliders["Prediction X"].SetValue(data.aim.predictX, true)
    end
    if allSliders["Aim Prediction Y"] and data.aim and data.aim.predictY then
        allSliders["Aim Prediction Y"].SetValue(data.aim.predictY, true)
    elseif allSliders["Prediction Y"] and data.aim and data.aim.predictY then
        allSliders["Prediction Y"].SetValue(data.aim.predictY, true)
    end

    if allSliders["Trigger Tolerance"] and data.triggerbot and data.triggerbot.tolerance then
        allSliders["Trigger Tolerance"].SetValue(data.triggerbot.tolerance, true)
    end
    if allSliders["Trigger Distance"] and data.triggerbot and data.triggerbot.maxDistance then
        allSliders["Trigger Distance"].SetValue(data.triggerbot.maxDistance, true)
    end
    if allSliders["Trigger Delay"] and data.triggerbot and data.triggerbot.delay then
        allSliders["Trigger Delay"].SetValue(data.triggerbot.delay, true)
    end
    if allSliders["Trigger Prediction X"] and data.triggerbot and data.triggerbot.predictX then
        allSliders["Trigger Prediction X"].SetValue(data.triggerbot.predictX, true)
    end
    if allSliders["Trigger Prediction Y"] and data.triggerbot and data.triggerbot.predictY then
        allSliders["Trigger Prediction Y"].SetValue(data.triggerbot.predictY, true)
    end

    if allSliders["Fly Speed"] and data.flySpeed then
        allSliders["Fly Speed"].SetValue(data.flySpeed, true)
    end
    if allSliders["Walk Speed"] and data.speedBoostValue then
        allSliders["Walk Speed"].SetValue(data.speedBoostValue, true)
    end
    if allSliders["Crosshair Size"] and data.crosshair and data.crosshair.size then
        allSliders["Crosshair Size"].SetValue(data.crosshair.size, true)
    end
    if allSliders["Crosshair Gap"] and data.crosshair and data.crosshair.gap then
        allSliders["Crosshair Gap"].SetValue(data.crosshair.gap, true)
    end
    if allSliders["Crosshair Thickness"] and data.crosshair and data.crosshair.thickness then
        allSliders["Crosshair Thickness"].SetValue(data.crosshair.thickness, true)
    end
    if allSliders["Spin Speed"] and data.crosshair and data.crosshair.spinSpeed then
        allSliders["Spin Speed"].SetValue(data.crosshair.spinSpeed, true)
    end
    if allSliders["Hit Sound Vol"] and data.hitEffects and data.hitEffects.soundVolume then
        allSliders["Hit Sound Vol"].SetValue(math.floor(data.hitEffects.soundVolume * 100 + 0.5), true)
    end

    if ConfigSystem.pillRefreshers then
        for _, rf in ipairs(ConfigSystem.pillRefreshers) do
            pcall(rf)
        end
    end

    if UpdateKeybindsHud then UpdateKeybindsHud() end
end

local SaveConfig
do
    local saveDebounceScheduled = false
    SaveConfig = function(forceImmediate)
        if isApplyingConfig then return end
        local function doWrite()
            if isApplyingConfig then return end
            pcall(function()
                if writefile then
                    local data = GetCurrentConfigData()
                    local activeName = ConfigSystem.activeConfig or "default"
                    if isfolder and makefolder and not isfolder(CONFIG_DIR) then
                        makefolder(CONFIG_DIR)
                    end
                    writefile(CONFIG_DIR .. "/" .. activeName .. ".json", HttpService:JSONEncode(data))
                    if not ConfigSystem.configs then ConfigSystem.configs = {} end
                    ConfigSystem.configs[activeName] = data
                end
            end)
        end

        if forceImmediate then
            saveDebounceScheduled = false
            doWrite()
            return
        end

        if saveDebounceScheduled then return end
        saveDebounceScheduled = true
        task.delay(0.5, function()
            saveDebounceScheduled = false
            doWrite()
        end)
    end
end

-- ── INVISIBLE CONTOUR BORDER RESIZERS ──────────
local resizeState = {active = false, mode = nil, startPos = Vector2.zero, startW = 0, startH = 0, startWinPos = UDim2.new()}

local function StartBorderResize(mode, inputPos)
    resizeState.active = true
    resizeState.mode = mode
    resizeState.startPos = inputPos
    resizeState.startW = win.AbsoluteSize.X
    resizeState.startH = win.AbsoluteSize.Y
    resizeState.startWinPos = win.Position
end

local function MakeResizeBorder(size, pos, mode)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.ZIndex = 45
    b.Parent = win

    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            StartBorderResize(mode, i.Position)
        end
    end)
    return b
end

-- Transparent hitboxes along each border contour
MakeResizeBorder(UDim2.new(0, 10, 1, -16), UDim2.new(1, -5, 0, 8),   "E")
MakeResizeBorder(UDim2.new(1, -16, 0, 10), UDim2.new(0, 8, 1, -5),   "S")
MakeResizeBorder(UDim2.new(0, 10, 1, -16), UDim2.new(0, -5, 0, 8),   "W")
MakeResizeBorder(UDim2.new(0, 16, 0, 16),  UDim2.new(1, -8, 1, -8),  "SE")
MakeResizeBorder(UDim2.new(0, 16, 0, 16),  UDim2.new(0, -8, 1, -8),  "SW")

table.insert(allConn, UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if resizeState.active then
            resizeState.active = false
            SaveConfig()
        end
    end
end))

table.insert(allConn, UIS.InputChanged:Connect(function(i)
    if resizeState.active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local dX = i.Position.X - resizeState.startPos.X
        local dY = i.Position.Y - resizeState.startPos.Y
        local mode = resizeState.mode

        local newW = resizeState.startW
        local newH = resizeState.startH
        local posX = resizeState.startWinPos.X.Offset
        local posY = resizeState.startWinPos.Y.Offset

        if mode == "E" or mode == "SE" then
            newW = math.clamp(resizeState.startW + dX, MIN_W, MAX_W)
            local deltaW = newW - resizeState.startW
            posX = resizeState.startWinPos.X.Offset + deltaW / 2
        elseif mode == "W" or mode == "SW" then
            newW = math.clamp(resizeState.startW - dX, MIN_W, MAX_W)
            local deltaW = newW - resizeState.startW
            posX = resizeState.startWinPos.X.Offset - deltaW / 2
        end

        if mode == "S" or mode == "SE" or mode == "SW" then
            newH = math.clamp(resizeState.startH + dY, MIN_H, MAX_H)
            local deltaH = newH - resizeState.startH
            posY = resizeState.startWinPos.Y.Offset + deltaH / 2
        end

        win.Size = UDim2.new(0, newW, 0, newH)
        win.Position = UDim2.new(resizeState.startWinPos.X.Scale, posX, resizeState.startWinPos.Y.Scale, posY)
    end
end))

-- ══════════════════════════════════════════════
--  KEYBINDS HUD WINDOW (Draggable overlay)
-- ══════════════════════════════════════════════
FormatKeyName = function(k)
    if not k then return "..." end
    local s = tostring(k):gsub("Enum.KeyCode.", "")
    local shortcuts = {
        LeftShift = "LShift",
        RightShift = "RShift",
        LeftControl = "LCtrl",
        RightControl = "RCtrl",
        LeftAlt = "LAlt",
        RightAlt = "RAlt",
        MouseButton1 = "MB1",
        MouseButton2 = "MB2",
        MouseButton3 = "MB3",
        MouseBackButton = "MB4",
        MouseForwardButton = "MB5",
        CapsLock = "Caps",
        Backspace = "Bksp",
        Return = "Enter",
        PageUp = "PgUp",
        PageDown = "PgDn",
    }
    return shortcuts[s] or s
end

local hasCanvasGroup, testC = pcall(function() return Instance.new("CanvasGroup") end)
if hasCanvasGroup and testC then testC:Destroy() end

do
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize
    if not vs or vs.X < 200 or vs.Y < 200 then vs = Vector2.new(1920, 1080) end
    if kbHudPosX < 0 or kbHudPosX > vs.X - 30 or kbHudPosY < 40 or kbHudPosY > vs.Y - 20 then
        kbHudPosX, kbHudPosY = 20, 220
    end
end

kbWin = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
kbWin.Name = "NOVA_Keybinds"
kbWin.Size = UDim2.new(0, 195, 0, 0)
kbWin.Position = UDim2.new(0, kbHudPosX, 0, kbHudPosY)
kbWin.BackgroundColor3 = T.bg
kbWin.BorderSizePixel = 0
kbWin.Active = true
kbWin.ClipsDescendants = true
kbWin.Visible = false
kbWin.ZIndex = 50
kbWin.AutomaticSize = Enum.AutomaticSize.Y
kbWin.Parent = SG
Crn(kbWin, 6)
Strk(kbWin, T.border, 1, 0)

if hasCanvasGroup then
    kbWin.GroupTransparency = 1
end

local kbShown = false

do
    local kbHeader = Instance.new("Frame")
    kbHeader.Name = "KbHeader"
    kbHeader.Size = UDim2.new(1, 0, 0, 22)
    kbHeader.BackgroundColor3 = T.topbar
    kbHeader.BorderSizePixel = 0
    kbHeader.ZIndex = 51
    kbHeader.Parent = kbWin
    Crn(kbHeader, 6)

    local kbHeaderCover = Instance.new("Frame")
    kbHeaderCover.Name = "KbHeaderCover"
    kbHeaderCover.Size = UDim2.new(1, 0, 0, 8)
    kbHeaderCover.Position = UDim2.new(0, 0, 1, -8)
    kbHeaderCover.BackgroundColor3 = T.topbar
    kbHeaderCover.BorderSizePixel = 0
    kbHeaderCover.ZIndex = 51
    kbHeaderCover.Parent = kbHeader

    local kbTitle = Lbl(kbHeader, "Keybinds", 10, T.text, Enum.Font.Arcade, Enum.TextXAlignment.Left, 52)
    kbTitle.Position = UDim2.new(0, 8, 0, 0)
    kbTitle.Size = UDim2.new(1, -16, 1, 0)

    local kbDiv = Instance.new("Frame")
    kbDiv.Name = "KbDiv"
    kbDiv.Size = UDim2.new(1, 0, 0, 1)
    kbDiv.Position = UDim2.new(0, 0, 1, -1)
    kbDiv.BackgroundColor3 = T.border
    kbDiv.BorderSizePixel = 0
    kbDiv.ZIndex = 52
    kbDiv.Parent = kbHeader

    kbList = Instance.new("Frame")
    kbList.Size = UDim2.new(1, 0, 0, 0)
    kbList.Position = UDim2.new(0, 0, 0, 22)
    kbList.BackgroundTransparency = 1
    kbList.AutomaticSize = Enum.AutomaticSize.Y
    kbList.ZIndex = 51
    kbList.Parent = kbWin

    local kbPad = Instance.new("UIPadding")
    kbPad.PaddingLeft = UDim.new(0, 8)
    kbPad.PaddingRight = UDim.new(0, 8)
    kbPad.PaddingTop = UDim.new(0, 4)
    kbPad.PaddingBottom = UDim.new(0, 5)
    kbPad.Parent = kbList

    local kbLayout = Instance.new("UIListLayout")
    kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    kbLayout.Padding = UDim.new(0, 0)
    kbLayout.Parent = kbList

    -- Dragging Keybinds HUD
    local kbDrag = {drag=false, start=Vector2.zero, orig=UDim2.new()}
    kbHeader.InputBegan:Connect(function(i)
        if not menuOpen then return end
        if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            kbDrag = {drag=true, start=i.Position, orig=kbWin.Position}
        end
    end)
    table.insert(allConn, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if kbDrag.drag then
                kbDrag.drag = false
                kbHudPosX = kbWin.Position.X.Offset
                kbHudPosY = kbWin.Position.Y.Offset
                SaveConfig()
            end
        end
    end))
    table.insert(allConn, UIS.InputChanged:Connect(function(i)
        if not menuOpen and kbDrag.drag then kbDrag.drag = false return end
        if kbDrag.drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - kbDrag.start
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize
            if not vs or vs.X < 200 or vs.Y < 200 then vs = Vector2.new(1920, 1080) end
            local w = (kbWin.AbsoluteSize.X > 0 and kbWin.AbsoluteSize.X) or 195
            local h = (kbWin.AbsoluteSize.Y > 0 and kbWin.AbsoluteSize.Y) or 40
            local nx = math.clamp(kbDrag.orig.X.Offset + d.X, 0, math.max(0, vs.X - w))
            local ny = math.clamp(kbDrag.orig.Y.Offset + d.Y, 0, math.max(0, vs.Y - h))
            kbWin.Position = UDim2.new(0, nx, 0, ny)
        end
    end))
end

-- ══════════════════════════════════════════════
--  ADMINS HUD WINDOW (Mad Hood Staff Detector)
-- ══════════════════════════════════════════════
do
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize
    if not vs or vs.X < 200 or vs.Y < 200 then vs = Vector2.new(1920, 1080) end
    if AdminStaff.hudPosX < 0 or AdminStaff.hudPosX > vs.X - 30 or AdminStaff.hudPosY < 0 or AdminStaff.hudPosY > vs.Y - 20 then
        AdminStaff.hudPosX, AdminStaff.hudPosY = 20, 100
    end
    local adminWin = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
    adminWin.Name = "NOVA_Admins"
    adminWin.Size = UDim2.new(0, 195, 0, 0)
    adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
    adminWin.BackgroundColor3 = T.bg
    adminWin.BorderSizePixel = 0
    adminWin.Active = true
    adminWin.ClipsDescendants = true
    adminWin.Visible = false
    adminWin.ZIndex = 50
    adminWin.AutomaticSize = Enum.AutomaticSize.Y
    adminWin.Parent = SG
    Crn(adminWin, 6)
    Strk(adminWin, T.border, 1, 0)

    if hasCanvasGroup then
        adminWin.GroupTransparency = 1
    end

    AdminStaff.win = adminWin

    local adminShown = false

    local aHeader = Instance.new("Frame")
    aHeader.Name = "AHeader"
    aHeader.Size = UDim2.new(1, 0, 0, 22)
    aHeader.BackgroundColor3 = T.topbar
    aHeader.BorderSizePixel = 0
    aHeader.ZIndex = 51
    aHeader.Parent = adminWin
    Crn(aHeader, 6)

    local aHeaderCover = Instance.new("Frame")
    aHeaderCover.Name = "AHeaderCover"
    aHeaderCover.Size = UDim2.new(1, 0, 0, 8)
    aHeaderCover.Position = UDim2.new(0, 0, 1, -8)
    aHeaderCover.BackgroundColor3 = T.topbar
    aHeaderCover.BorderSizePixel = 0
    aHeaderCover.ZIndex = 51
    aHeaderCover.Parent = aHeader

    local aTitle = Lbl(aHeader, "Admins", 10, T.text, Enum.Font.Arcade, Enum.TextXAlignment.Left, 52)
    aTitle.Position = UDim2.new(0, 10, 0, 0)
    aTitle.Size = UDim2.new(1, -20, 1, 0)

    local aDiv = Instance.new("Frame")
    aDiv.Name = "ADiv"
    aDiv.Size = UDim2.new(1, 0, 0, 1)
    aDiv.Position = UDim2.new(0, 0, 1, -1)
    aDiv.BackgroundColor3 = T.border
    aDiv.BorderSizePixel = 0
    aDiv.ZIndex = 52
    aDiv.Parent = aHeader

    local aList = Instance.new("Frame")
    aList.Size = UDim2.new(1, 0, 0, 0)
    aList.Position = UDim2.new(0, 0, 0, 22)
    aList.BackgroundTransparency = 1
    aList.AutomaticSize = Enum.AutomaticSize.Y
    aList.ZIndex = 51
    aList.Parent = adminWin

    AdminStaff.list = aList

    local aPad = Instance.new("UIPadding")
    aPad.PaddingLeft = UDim.new(0, 8)
    aPad.PaddingRight = UDim.new(0, 8)
    aPad.PaddingTop = UDim.new(0, 4)
    aPad.PaddingBottom = UDim.new(0, 6)
    aPad.Parent = aList

    local aLayout = Instance.new("UIListLayout")
    aLayout.SortOrder = Enum.SortOrder.LayoutOrder
    aLayout.Padding = UDim.new(0, 4)
    aLayout.Parent = aList

    -- Dragging Admins HUD
    local aDrag = {drag=false, start=Vector2.zero, orig=UDim2.new()}
    aHeader.InputBegan:Connect(function(i)
        if not menuOpen then return end
        if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            aDrag = {drag=true, start=i.Position, orig=adminWin.Position}
        end
    end)
    table.insert(allConn, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if aDrag.drag then
                aDrag.drag = false
                AdminStaff.hudPosX = adminWin.Position.X.Offset
                AdminStaff.hudPosY = adminWin.Position.Y.Offset
                SaveConfig()
            end
        end
    end))
    table.insert(allConn, UIS.InputChanged:Connect(function(i)
        if not menuOpen and aDrag.drag then aDrag.drag = false return end
        if aDrag.drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - aDrag.start
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize
            if not vs or vs.X < 200 or vs.Y < 200 then vs = Vector2.new(1920, 1080) end
            local w = (adminWin.AbsoluteSize.X > 0 and adminWin.AbsoluteSize.X) or 195
            local h = (adminWin.AbsoluteSize.Y > 0 and adminWin.AbsoluteSize.Y) or 40
            local nx = math.clamp(aDrag.orig.X.Offset + d.X, 0, math.max(0, vs.X - w))
            local ny = math.clamp(aDrag.orig.Y.Offset + d.Y, 0, math.max(0, vs.Y - h))
            adminWin.Position = UDim2.new(0, nx, 0, ny)
        end
    end))

    AdminStaff.CheckIfAdmin = function(p)
        if not p or not p.Parent then return false, 0, "" end
        if AdminStaff.cache[p.UserId] ~= nil then
            local c = AdminStaff.cache[p.UserId]
            return c.isAdmin, c.rank, c.role
        end
        local s, r = pcall(function() return p:GetRankInGroup(AdminStaff.groupId) end)
        local sRole, roleName = pcall(function() return p:GetRoleInGroup(AdminStaff.groupId) end)
        local rank = (s and tonumber(r)) or 0
        local role = (sRole and tostring(roleName)) or ("Rank " .. tostring(rank))
        local isAdmin = (s and rank >= AdminStaff.minRank and rank <= AdminStaff.maxRank)
        if s then
            AdminStaff.cache[p.UserId] = {
                isAdmin = isAdmin,
                rank = rank,
                role = role,
                name = p.Name,
                displayName = p.DisplayName,
            }
            return isAdmin, rank, role
        end
        return false, 0, ""
    end

    AdminStaff.UpdateHud = function()
        if not adminWin or not aList then return end

        if not AdminStaff.enabled or not AdminStaff.hudVisible then
            if adminShown then
                adminShown = false
                if hasCanvasGroup then
                    Tw(adminWin, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                end
                task.delay(0.16, function()
                    if not adminShown then
                        adminWin.Visible = false
                        adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
                        if hasCanvasGroup then adminWin.GroupTransparency = 1 end
                    end
                end)
            else
                adminWin.Visible = false
                adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
            end
            if AdminStaff.onListUpdated then AdminStaff.onListUpdated() end
            return
        end

        local activeAdmins = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local isAdm, rank, role = AdminStaff.CheckIfAdmin(plr)
                if isAdm then
                    table.insert(activeAdmins, {
                        player = plr,
                        rank = rank,
                        role = role,
                    })
                end
            end
        end

        if #activeAdmins == 0 and AdminStaff.autoHide then
            if adminShown then
                adminShown = false
                if hasCanvasGroup then
                    Tw(adminWin, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                end
                task.delay(0.16, function()
                    if not adminShown then
                        adminWin.Visible = false
                        adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
                        if hasCanvasGroup then adminWin.GroupTransparency = 1 end
                    end
                end)
            else
                adminWin.Visible = false
                adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
            end
            if AdminStaff.onListUpdated then AdminStaff.onListUpdated() end
            return
        end

        for _, ch in ipairs(aList:GetChildren()) do
            if ch:IsA("Frame") or ch:IsA("TextLabel") then
                ch:Destroy()
            end
        end



        if #activeAdmins == 0 then
            local emptyF = Instance.new("Frame")
            emptyF.Size = UDim2.new(1, 0, 0, 22)
            emptyF.BackgroundTransparency = 1
            emptyF.Parent = aList

            local emptyLbl = Lbl(emptyF, "No admins in server", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Center, 53)
            emptyLbl.Size = UDim2.new(1, 0, 1, 0)
        else
            local order = 0
            for idx, adm in ipairs(activeAdmins) do
                if idx > 1 then
                    order += 1
                    local sep = Instance.new("Frame")
                    sep.Size = UDim2.new(1, 0, 0, 1)
                    sep.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
                    sep.BorderSizePixel = 0
                    sep.LayoutOrder = order
                    sep.ZIndex = 53
                    sep.Parent = aList
                end

                order += 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 28)
                row.BackgroundTransparency = 1
                row.BorderSizePixel = 0
                row.LayoutOrder = order
                row.ZIndex = 53
                row.Parent = aList

                local dName = Lbl(row, adm.player.DisplayName, 10, Color3.fromRGB(240, 240, 255), Enum.Font.Arcade, Enum.TextXAlignment.Left, 54)
                dName.Position = UDim2.new(0, 2, 0, 1)
                dName.Size = UDim2.new(1, -46, 0, 13)

                local uName = Lbl(row, "@" .. adm.player.Name, 8, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 54)
                uName.Position = UDim2.new(0, 2, 0, 15)
                uName.Size = UDim2.new(1, -46, 0, 12)

                local specLbl = Lbl(row, "spec", 9, T.accent, Enum.Font.Arcade, Enum.TextXAlignment.Right, 54)
                specLbl.AnchorPoint = Vector2.new(1, 0.5)
                specLbl.Position = UDim2.new(1, -4, 0.5, 0)
                specLbl.Size = UDim2.new(0, 42, 0, 14)
                TrackAccent(specLbl, "TextColor3")

                local c = AdminStaff.cache[adm.player.UserId]
                local isSpecNow = c and c.isSpec
                if isSpecNow then
                    specLbl.TextTransparency = 0
                    specLbl.Visible = true
                    specLbl.Position = UDim2.new(1, -4, 0.5, 0)
                else
                    specLbl.TextTransparency = 1
                    specLbl.Visible = false
                    specLbl.Position = UDim2.new(1, 6, 0.5, 0)
                end

                if c then
                    c.updateSpecUI = function(active)
                        if not specLbl or not specLbl.Parent then return end
                        if active then
                            specLbl.Visible = true
                            specLbl.Position = UDim2.new(1, 6, 0.5, 0)
                            specLbl.TextTransparency = 1
                            Tw(specLbl, {TextTransparency = 0, Position = UDim2.new(1, -4, 0.5, 0)}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        else
                            Tw(specLbl, {TextTransparency = 1, Position = UDim2.new(1, 6, 0.5, 0)}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                            task.delay(0.24, function()
                                if specLbl and specLbl.Parent and not (c and c.isSpec) then
                                    specLbl.Visible = false
                                end
                            end)
                        end
                    end
                end
            end
        end

        adminWin.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
        if not adminShown then
            adminShown = true
            adminWin.Visible = true
            if hasCanvasGroup then
                adminWin.GroupTransparency = 1
                Tw(adminWin, {GroupTransparency = 0}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            end
        else
            adminWin.Visible = true
            if hasCanvasGroup then adminWin.GroupTransparency = 0 end
        end

        if AdminStaff.onListUpdated then AdminStaff.onListUpdated() end
    end

    AdminStaff.ScanServer = function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local isAdm, rank, role = AdminStaff.CheckIfAdmin(p)
                if isAdm and AdminStaff.alerts then
                    if not AdminStaff.notifiedUserIds[p.UserId] then
                        AdminStaff.notifiedUserIds[p.UserId] = true
                        pcall(function()
                            if Notify then Notify("Staff Detected", p.DisplayName .. " (@" .. p.Name .. ") is on server!", 5, "admin") end
                        end)
                    end
                end
            end
        end
        AdminStaff.UpdateHud()
    end

    -- 10s stillness tracker for spectating detection
    task.spawn(function()
        while true do
            task.wait(0.5)
            if AdminStaff.enabled then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP then
                        local c = AdminStaff.cache[p.UserId]
                        if c and c.isAdmin then
                            local char = p.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if hrp and hum and hum.Health > 0 then
                                local curPos = hrp.Position
                                if not c.lastPos then
                                    c.lastPos = curPos
                                    c.lastMoveTime = tick()
                                end
                                local dist = (curPos - c.lastPos).Magnitude
                                if dist > 0.8 then
                                    c.lastPos = curPos
                                    c.lastMoveTime = tick()
                                    if c.isSpec then
                                        c.isSpec = false
                                        if c.updateSpecUI then pcall(c.updateSpecUI, false) end
                                    end
                                else
                                    if not c.lastMoveTime then c.lastMoveTime = tick() end
                                    if (tick() - c.lastMoveTime) >= 10 then
                                        if not c.isSpec then
                                            c.isSpec = true
                                            if c.updateSpecUI then pcall(c.updateSpecUI, true) end
                                        end
                                    end
                                end
                            else
                                if c.isSpec then
                                    c.isSpec = false
                                    if c.updateSpecUI then pcall(c.updateSpecUI, false) end
                                end
                                c.lastPos = nil
                                c.lastMoveTime = nil
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════════
--  STATUS WATERMARK BAR (N Logo, FPS, Ping, Time, Server)
-- ══════════════════════════════════════════════
do
    local cam = workspace.CurrentCamera
    local vs = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local sx = Watermark.scaleX or (Watermark.posX and 0 or 0.5)
    local ox = Watermark.posX or 0
    local sy = Watermark.scaleY or 0
    local oy = Watermark.posY or 20
    local defaultPos = UDim2.new(sx, ox, sy, oy)
    local initialPos = defaultPos
    local initAnchor = Vector2.new(0.5, 0.5)

    local isInitVisible = (Watermark.visible ~= false)

    local wmShadow = Instance.new("Frame")
    wmShadow.Name = "NOVA_WatermarkShadow"
    wmShadow.AnchorPoint = initAnchor
    wmShadow.Position = initialPos + UDim2.new(0, 0, 0, 1)
    wmShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    wmShadow.BackgroundTransparency = isInitVisible and 1 or 0.65
    wmShadow.BorderSizePixel = 0
    wmShadow.AutomaticSize = Enum.AutomaticSize.XY
    wmShadow.Visible = isInitVisible
    wmShadow.ZIndex = 43
    wmShadow.Parent = SG
    Crn(wmShadow, 16)

    local wmShadowScale = Instance.new("UIScale")
    wmShadowScale.Scale = isInitVisible and 0.88 or 1
    wmShadowScale.Parent = wmShadow

    local wmWin = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
    wmWin.Name = "NOVA_Watermark"
    wmWin.AnchorPoint = initAnchor
    wmWin.Position = initialPos
    wmWin.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    wmWin.BackgroundTransparency = 0.35
    if hasCanvasGroup then
        wmWin.GroupTransparency = isInitVisible and 1 or 0
    end
    wmWin.BorderSizePixel = 0
    wmWin.Active = true
    wmWin.AutomaticSize = Enum.AutomaticSize.XY
    wmWin.Visible = isInitVisible
    wmWin.ZIndex = 44
    wmWin.Parent = SG
    Crn(wmWin, 15)
    Strk(wmWin, Color3.fromRGB(48, 48, 58), 1, 0.45)

    local wmScale = Instance.new("UIScale")
    wmScale.Scale = isInitVisible and 0.88 or 1
    wmScale.Parent = wmWin

    Watermark.win = wmWin
    Watermark.shadow = wmShadow

    local function getTargetPos()
        local sx = Watermark.scaleX or (Watermark.posX and 0 or 0.5)
        local ox = Watermark.posX or 0
        local sy = Watermark.scaleY or 0
        local oy = Watermark.posY or 20
        return UDim2.new(sx, ox, sy, oy)
    end

    local wmAnimToken = 0
    local function playAppearAnim()
        wmAnimToken += 1
        local myToken = wmAnimToken
        local targetPos = getTargetPos()

        wmWin.AnchorPoint = Vector2.new(0.5, 0.5)
        wmShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        wmWin.Position = targetPos
        wmShadow.Position = targetPos + UDim2.new(0, 0, 0, 1)
        wmScale.Scale = 0.88
        wmShadowScale.Scale = 0.88
        wmWin.Visible = true
        wmShadow.Visible = true

        if hasCanvasGroup then
            wmWin.GroupTransparency = 1
            Tw(wmWin, {GroupTransparency = 0}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        else
            wmWin.BackgroundTransparency = 1
            Tw(wmWin, {BackgroundTransparency = 0.35}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end

        wmShadow.BackgroundTransparency = 1
        Tw(wmShadow, {BackgroundTransparency = 0.65}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        Tw(wmScale, {Scale = 1.0}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Tw(wmShadowScale, {Scale = 1.0}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end

    local function playDisappearAnim()
        wmAnimToken += 1
        local myToken = wmAnimToken

        Tw(wmScale, {Scale = 0.88}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Tw(wmShadowScale, {Scale = 0.88}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        if hasCanvasGroup then
            Tw(wmWin, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        else
            Tw(wmWin, {BackgroundTransparency = 1}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        Tw(wmShadow, {BackgroundTransparency = 1}, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        task.delay(0.16, function()
            if wmAnimToken == myToken and not Watermark.visible then
                wmWin.Visible = false
                wmShadow.Visible = false
                local curTarget = getTargetPos()
                wmWin.Position = curTarget
                wmShadow.Position = curTarget + UDim2.new(0, 0, 0, 1)
                wmScale.Scale = 1
                wmShadowScale.Scale = 1
            end
        end)
    end

    local wmVisibleState = isInitVisible
    Watermark.SetVisible = function(v, force)
        local state = (v == true)
        if not force and wmVisibleState == state then
            return
        end
        wmVisibleState = state
        if state then
            playAppearAnim()
        else
            playDisappearAnim()
        end
    end

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = wmWin

    local shadowPad = Instance.new("UIPadding")
    shadowPad.PaddingLeft = UDim.new(0, 10)
    shadowPad.PaddingRight = UDim.new(0, 12)
    shadowPad.PaddingTop = UDim.new(0, 4)
    shadowPad.PaddingBottom = UDim.new(0, 4)
    shadowPad.Parent = wmShadow

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 9)
    layout.Parent = wmWin

    -- Base64 decoder helper for watermark icons
    local function decodeB64(b64str)
        local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        local b = {}
        for i = 1, #b64chars do b[b64chars:byte(i)] = i - 1 end
        local clean = b64str:gsub('[^'..b64chars..'=]', '')
        local out = {}
        local len = #clean
        for i = 1, len, 4 do
            local c1 = b[clean:byte(i)] or 0
            local c2 = b[clean:byte(i+1)] or 0
            local c3 = b[clean:byte(i+2)] or 0
            local c4 = b[clean:byte(i+3)] or 0
            table.insert(out, string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4))))
            if clean:sub(i+2, i+2) ~= '=' then
                table.insert(out, string.char(bit32.bor(bit32.band(bit32.lshift(c2, 4), 255), bit32.rshift(c3, 2))))
            end
            if clean:sub(i+3, i+3) ~= '=' then
                table.insert(out, string.char(bit32.bor(bit32.band(bit32.lshift(c3, 6), 255), c4)))
            end
        end
        return table.concat(out)
    end

    local getAsset = getcustomasset or getsynasset
    local function loadAsset(filename, b64str, forceWrite)
        local asset = nil
        pcall(function()
            if writefile and getAsset then
                if forceWrite or not (isfile and isfile(filename)) then
                    writefile(filename, decodeB64(b64str))
                end
                asset = getAsset(filename)
            elseif getAsset then
                pcall(function() asset = getAsset(filename) end)
            end
        end)
        return asset
    end

    -- 1. Logo (N letter in Watermark)
    local logoBox = Instance.new("Frame")
    logoBox.Name = "LogoBox"
    logoBox.Size = UDim2.new(0, 24, 0, 22)
    logoBox.BackgroundTransparency = 1
    logoBox.LayoutOrder = 1
    logoBox.Parent = wmWin

    local logoTxt = Instance.new("TextLabel")
    logoTxt.Size = UDim2.new(1, 0, 1, 0)
    logoTxt.Position = UDim2.new(0.5, 0, 0.5, 0)
    logoTxt.AnchorPoint = Vector2.new(0.5, 0.5)
    logoTxt.BackgroundTransparency = 1
    logoTxt.Font = Enum.Font.GothamBlack
    logoTxt.Text = "N"
    logoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoTxt.TextSize = 15
    logoTxt.ZIndex = 46
    logoTxt.Parent = logoBox

    -- 2. Dot Separator
    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.new(0, 3, 0, 3)
    dot.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
    dot.BackgroundTransparency = 0.4
    dot.BorderSizePixel = 0
    dot.LayoutOrder = 2
    dot.Parent = wmWin
    Crn(dot, 2)

    local fpsB64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAcUlEQVR4nO2VQQrAMAgE1/3/n+2lpyJtMEZ72DmFINkB0QBCbOA3O29wJzw6twh4EJiVIIahBDA8KTwdHp1bBHxxUohheHLLpQW8aMulBLxwy6UEumF7ogQeEMNQAlAL/tYCM7Ovu6qaV1Z+w6oagUkuBotf5046f1YAAAAASUVORK5CYII="
    local pingB64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAc0lEQVR4nO2UQQrAMAgE1f//eXvpMa0ia0Jg5xSMxAHZmAkhhsHL131MD1+dtwhgMXBVCztMSMBuXgGSiI0KoBCxMQEUIzYmwCSor0mAuQIQItYWACliLQEQI9YS2E1snyiBbAXu7lmN1fNL5R9g9Qg7yQNGXl/jmeI3WgAAAABJRU5ErkJggg=="
    local clockB64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAw0lEQVR4nO1XywrEMAh0Bv//l7PsoRBKanxkkYXOMXVGq8ZakRfNQIY0xhhLMSCsh6rTR2FnMPyF8wgHGZGnt8uUBhHn3rRGuOoRjDbXZe8pA1aHM9GTbivAnR0twmmstGkRMvc6qkFpBjN1jWLWupdBTziojGZKM9gdgGaJ3/Reqa/0i2aJVcfLEsDo1gqs20VpBq2HJ7Kw0+D94OQA8mhzZ1jJgmeyakSospD830o2I1uGY98CZPZ9JwfS/GPyQrrxAaVpeD8PpZQkAAAAAElFTkSuQmCC"
    local locB64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAArUlEQVR4nO2WwQ7AIAhDofH/f9nFm9mmMCzhsl4VXkUwivwqlu4We++dAlFdcpANt3IhG27lVGvjrnwR8D0fMuFvOe4MeAOZJma1aFKrT7wHgCTJ28iQYrVo4Fzik7FFNJABPzbAeLDAhEdGF5XwkAEmfKix4V/NgAmPCJVwt4HTMh8bmKFM+NCnKWDDtwZK/oRq/F4Y8Ec/iSOIpbcrhHdjBnxpgG0i40C/hKULK3NkROha/sEAAAAASUVORK5CYII="

    local fpsAsset = loadAsset("nova_wm_fps.png", fpsB64)
    local pingAsset = loadAsset("nova_wm_ping.png", pingB64)
    local clockAsset = loadAsset("nova_wm_clock.png", clockB64)
    local locAsset = loadAsset("nova_wm_loc.png", locB64)

    -- Helper to create item with icon and label
    local function CreateWmItem(order, iconAsset, fallbackBuilder)
        local itemF = Instance.new("Frame")
        itemF.BackgroundTransparency = 1
        itemF.AutomaticSize = Enum.AutomaticSize.XY
        itemF.LayoutOrder = order
        itemF.Parent = wmWin

        local itemLayout = Instance.new("UIListLayout")
        itemLayout.FillDirection = Enum.FillDirection.Horizontal
        itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
        itemLayout.Padding = UDim.new(0, 5)
        itemLayout.Parent = itemF

        local iconContainer = Instance.new("Frame")
        iconContainer.Size = UDim2.new(0, 12, 0, 12)
        iconContainer.BackgroundTransparency = 1
        iconContainer.LayoutOrder = 1
        iconContainer.Parent = itemF

        if iconAsset then
            local iconImg = Instance.new("ImageLabel")
            iconImg.Size = UDim2.new(1, 0, 1, 0)
            iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
            iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
            iconImg.BackgroundTransparency = 1
            iconImg.ScaleType = Enum.ScaleType.Fit
            iconImg.Image = iconAsset
            iconImg.ImageColor3 = T.accent
            iconImg.ZIndex = 46
            iconImg.Parent = iconContainer
            TrackAccent(iconImg, "ImageColor3")
        elseif fallbackBuilder then
            fallbackBuilder(iconContainer)
        end

        local txt = Instance.new("TextLabel")
        txt.BackgroundTransparency = 1
        txt.AutomaticSize = Enum.AutomaticSize.XY
        txt.Font = Enum.Font.Arcade
        txt.TextSize = 11
        txt.RichText = true
        txt.Text = ""
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.LayoutOrder = 2
        txt.ZIndex = 46
        txt.Parent = itemF

        return txt
    end

    -- 3. FPS item (icon: matching asset equalizer, same as other icons)
    local fpsTxt = CreateWmItem(3, fpsAsset, function(c)
        local waveB1 = Instance.new("Frame"); waveB1.Size = UDim2.new(0, 2, 0, 4); waveB1.Position = UDim2.new(0, 1, 1, -4); waveB1.BackgroundColor3 = T.accent; waveB1.BorderSizePixel = 0; waveB1.Parent = c; Crn(waveB1, 1); TrackAccent(waveB1, "BackgroundColor3")
        local waveB2 = Instance.new("Frame"); waveB2.Size = UDim2.new(0, 2, 0, 9); waveB2.Position = UDim2.new(0, 5, 1, -9); waveB2.BackgroundColor3 = T.accent; waveB2.BorderSizePixel = 0; waveB2.Parent = c; Crn(waveB2, 1); TrackAccent(waveB2, "BackgroundColor3")
        local waveB3 = Instance.new("Frame"); waveB3.Size = UDim2.new(0, 2, 0, 6); waveB3.Position = UDim2.new(0, 9, 1, -6); waveB3.BackgroundColor3 = T.accent; waveB3.BorderSizePixel = 0; waveB3.Parent = c; Crn(waveB3, 1); TrackAccent(waveB3, "BackgroundColor3")
    end)

    -- 4. MS Ping item (icon: signal bars staircase)
    local pingTxt = CreateWmItem(4, pingAsset, function(c)
        local b1 = Instance.new("Frame"); b1.Size = UDim2.new(0, 2, 0, 4); b1.Position = UDim2.new(0, 1, 1, -4); b1.BackgroundColor3 = T.accent; b1.BorderSizePixel = 0; b1.Parent = c; Crn(b1, 1); TrackAccent(b1, "BackgroundColor3")
        local b2 = Instance.new("Frame"); b2.Size = UDim2.new(0, 2, 0, 7); b2.Position = UDim2.new(0, 5, 1, -7); b2.BackgroundColor3 = T.accent; b2.BorderSizePixel = 0; b2.Parent = c; Crn(b2, 1); TrackAccent(b2, "BackgroundColor3")
        local b3 = Instance.new("Frame"); b3.Size = UDim2.new(0, 2, 0, 11); b3.Position = UDim2.new(0, 9, 1, -11); b3.BackgroundColor3 = T.accent; b3.BorderSizePixel = 0; b3.Parent = c; Crn(b3, 1); TrackAccent(b3, "BackgroundColor3")
    end)

    -- 5. Time item (icon: perfectly centered clock circle with hands at 12 and 3)
    local timeTxt = CreateWmItem(5, clockAsset, function(c)
        local circ = Instance.new("Frame")
        circ.Size = UDim2.new(0, 12, 0, 12)
        circ.Position = UDim2.new(0.5, 0, 0.5, 0)
        circ.AnchorPoint = Vector2.new(0.5, 0.5)
        circ.BackgroundTransparency = 1
        circ.Parent = c
        Crn(circ, 6)
        local s = Strk(circ, T.accent, 1, 0)
        TrackAccent(s, "Color")
        local hHand = Instance.new("Frame"); hHand.Size = UDim2.new(0, 1, 0, 4); hHand.Position = UDim2.new(0.5, 0, 0.5, 0); hHand.AnchorPoint = Vector2.new(0.5, 1); hHand.BackgroundColor3 = T.accent; hHand.BorderSizePixel = 0; hHand.Parent = circ; TrackAccent(hHand, "BackgroundColor3")
        local mHand = Instance.new("Frame"); mHand.Size = UDim2.new(0, 4, 0, 1); mHand.Position = UDim2.new(0.5, 0, 0.5, 0); mHand.AnchorPoint = Vector2.new(0, 0.5); mHand.BackgroundColor3 = T.accent; mHand.BorderSizePixel = 0; mHand.Parent = circ; TrackAccent(mHand, "BackgroundColor3")
    end)

    -- 6. Server / Location item (icon: rounded box with diagonal arrow)
    local locTxt = CreateWmItem(6, locAsset, function(c)
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 12, 0, 12)
        box.Position = UDim2.new(0.5, 0, 0.5, 0)
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.BackgroundTransparency = 1
        box.Parent = c
        Crn(box, 3)
        local s = Strk(box, T.accent, 1, 0)
        TrackAccent(s, "Color")
        local arr = Instance.new("TextLabel")
        arr.Size = UDim2.new(1, 0, 1, 0)
        arr.BackgroundTransparency = 1
        arr.Font = Enum.Font.GothamBold
        arr.TextSize = 8
        arr.Text = "^"
        arr.Rotation = 45
        arr.TextColor3 = T.accent
        arr.Parent = box
        TrackAccent(arr, "TextColor3")
    end)

    -- Draggable watermark
    local wmDrag = {drag = false, start = Vector2.zero, orig = UDim2.new()}
    wmWin.InputBegan:Connect(function(i)
        if not menuOpen then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            wmAnimToken += 1
            wmScale.Scale = 1
            wmShadowScale.Scale = 1
            if hasCanvasGroup then wmWin.GroupTransparency = 0 end
            wmShadow.BackgroundTransparency = 0.65
            wmDrag = {
                drag = true,
                start = Vector2.new(i.Position.X, i.Position.Y),
                orig = wmWin.Position,
            }
        end
    end)
    table.insert(allConn, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if wmDrag.drag then
                wmDrag.drag = false
                Watermark.scaleX = wmWin.Position.X.Scale
                Watermark.posX = wmWin.Position.X.Offset
                Watermark.scaleY = wmWin.Position.Y.Scale
                Watermark.posY = wmWin.Position.Y.Offset
                SaveConfig()
            end
        end
    end))
    table.insert(allConn, UIS.InputChanged:Connect(function(i)
        if not menuOpen and wmDrag.drag then wmDrag.drag = false return end
        if wmDrag.drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = Vector2.new(i.Position.X, i.Position.Y) - wmDrag.start
            local cCam = workspace.CurrentCamera
            local cVs = (cCam and cCam.ViewportSize) or Vector2.new(1920, 1080)
            local w = (wmWin.AbsoluteSize.X > 0 and wmWin.AbsoluteSize.X) or 300
            local h = (wmWin.AbsoluteSize.Y > 0 and wmWin.AbsoluteSize.Y) or 30
            local halfW = math.floor(w / 2)
            local halfH = math.floor(h / 2)

            local minOX = (halfW + 4) - (wmDrag.orig.X.Scale * cVs.X)
            local maxOX = (cVs.X - halfW - 4) - (wmDrag.orig.X.Scale * cVs.X)
            local minOY = (halfH + 4) - (wmDrag.orig.Y.Scale * cVs.Y)
            local maxOY = (cVs.Y - halfH - 4) - (wmDrag.orig.Y.Scale * cVs.Y)

            local ox = math.clamp(wmDrag.orig.X.Offset + d.X, minOX, maxOX)
            local oy = math.clamp(wmDrag.orig.Y.Offset + d.Y, minOY, maxOY)

            local newPos = UDim2.new(wmDrag.orig.X.Scale, ox, wmDrag.orig.Y.Scale, oy)
            wmWin.Position = newPos
            wmShadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset, newPos.Y.Scale, newPos.Y.Offset + 1)
        end
    end))

    -- Real-time tracking loop (FPS, Ping, Session Timer, Server Location)
    local curFps = 60
    local fpsCount = 0
    local fpsTimer = os.clock()
    local startTime = os.clock()
    local serverLocation = "Amsterdam, NL"

    task.spawn(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local ok, res = pcall(req, {Url = "http://ip-api.com/json", Method = "GET"})
            if ok and res and res.Body then
                local pOk, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
                if pOk and type(data) == "table" and data.city and data.countryCode then
                    serverLocation = tostring(data.city) .. ", " .. tostring(data.countryCode)
                end
            end
        end
    end)

    table.insert(allConn, RS.RenderStepped:Connect(function()
        fpsCount += 1
        local now = os.clock()
        if now - fpsTimer >= 0.5 then
            curFps = math.floor(fpsCount / (now - fpsTimer) + 0.5)
            fpsCount = 0
            fpsTimer = now
        end
    end))

    task.spawn(function()
        while true do
            task.wait(0.25)
            if not wmWin or not wmWin.Parent or not SG or not SG.Parent then break end
            if wmWin.Visible then
                -- FPS
                fpsTxt.Text = string.format('<font color="#ffffff"><b>%d</b></font> <font color="#9595a5">FPS</font>', math.clamp(curFps, 1, 999))

                -- MS Ping
                local ping = 50
                pcall(function()
                    local p = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
                    if p and p >= 0 then ping = math.floor(p) end
                end)
                pingTxt.Text = string.format('<font color="#ffffff"><b>%d</b></font> <font color="#9595a5">MS</font>', math.clamp(ping, 1, 9999))

                -- Elapsed Time (hh:mm:ss)
                local elapsed = math.floor(os.clock() - startTime)
                local h = math.floor(elapsed / 3600)
                local m = math.floor((elapsed % 3600) / 60)
                local s = elapsed % 60
                timeTxt.Text = string.format('<font color="#ffffff"><b>%02d:%02d:%02d</b></font>', h, m, s)

                -- Server Location
                locTxt.Text = string.format('<font color="#ffffff"><b>%s</b></font>', serverLocation)
            end
        end
    end)

end

-- ── BIND MODE CONTEXT MENU (Toggle / Hold / Always) ──
local bindContextMenu = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
bindContextMenu.Name = "NOVA_BindContextMenu"
bindContextMenu.Size = UDim2.new(0, 84, 0, 75)
bindContextMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
bindContextMenu.BorderSizePixel = 0
bindContextMenu.Visible = false
bindContextMenu.ZIndex = 85
bindContextMenu.ClipsDescendants = true
bindContextMenu.Parent = SG
Crn(bindContextMenu, 5)
Strk(bindContextMenu, T.border, 1, 0)
if hasCanvasGroup then
    bindContextMenu.GroupTransparency = 1
end

local bcmList = Instance.new("Frame")
bcmList.Size = UDim2.new(1, 0, 1, 0)
bcmList.Position = UDim2.new(0, 0, 0, 0)
bcmList.BackgroundTransparency = 1
bcmList.ZIndex = 86
bcmList.Parent = bindContextMenu

local bcmPad = Instance.new("UIPadding")
bcmPad.PaddingTop = UDim.new(0, 3)
bcmPad.PaddingBottom = UDim.new(0, 3)
bcmPad.PaddingLeft = UDim.new(0, 4)
bcmPad.PaddingRight = UDim.new(0, 4)
bcmPad.Parent = bcmList

local bcmLL = Instance.new("UIListLayout")
bcmLL.SortOrder = Enum.SortOrder.LayoutOrder
bcmLL.Padding = UDim.new(0, 0)
bcmLL.Parent = bcmList

local bcmTarget = nil
local bcmButtons = {}
local bcmIsOpen = false

local CloseKeybindContextMenu
CloseKeybindContextMenu = function(immediate)
    if not bindContextMenu.Visible then return end
    bcmIsOpen = false
    bcmTarget = nil

    if immediate then
        bindContextMenu.Visible = false
        if hasCanvasGroup then bindContextMenu.GroupTransparency = 1 end
        return
    end

    local curPos = bindContextMenu.Position
    local hidePos = UDim2.new(curPos.X.Scale, curPos.X.Offset, curPos.Y.Scale, curPos.Y.Offset - 5)
    if hasCanvasGroup then
        Tw(bindContextMenu, {GroupTransparency = 1, Position = hidePos}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    else
        Tw(bindContextMenu, {Size = UDim2.new(0, 84, 0, 0), Position = hidePos}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
    task.delay(0.15, function()
        if not bcmIsOpen then
            bindContextMenu.Visible = false
            if hasCanvasGroup then bindContextMenu.GroupTransparency = 1 end
        end
    end)
end

local OpenKeybindContextMenu
UpdateBcmVisuals = function()
    local curMode = (bcmTarget and featureBinds[bcmTarget.name] and featureBinds[bcmTarget.name].mode) or "Toggle"
    for mName, btn in pairs(bcmButtons) do
        local isCur = (mName == curMode)
        if isCur then
            Tw(btn, {TextColor3 = T.accent, BackgroundColor3 = T.accent, BackgroundTransparency = 0.84}, 0.15)
            btn.Font = Enum.Font.Arcade
        else
            Tw(btn, {TextColor3 = T.textDim, BackgroundTransparency = 1}, 0.15)
            btn.Font = Enum.Font.Arcade
        end
    end
end

local function SelectBindMode(mName)
    if not bcmTarget then return end
    local tName = bcmTarget.name
    local targetCopy = bcmTarget

    if not featureBinds[tName] then
        featureBinds[tName] = {
            key = nil,
            shortKey = "...",
            mode = mName,
            toggle = targetCopy.toggle,
            name = tName,
        }
    else
        featureBinds[tName].mode = mName
    end

    if targetCopy.dotsBtn then
        if featureBinds[tName].key then
            targetCopy.dotsBtn.Text = featureBinds[tName].shortKey
            targetCopy.dotsBtn.TextColor3 = T.accent
        elseif mName == "Always" then
            targetCopy.dotsBtn.Text = "ALW"
            targetCopy.dotsBtn.TextColor3 = T.accent
        else
            targetCopy.dotsBtn.Text = "..."
            targetCopy.dotsBtn.TextColor3 = T.textMuted
        end
        Tw(targetCopy.dotsBtn, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.08)
        task.delay(0.1, function()
            if targetCopy.dotsBtn and targetCopy.dotsBtn.Parent then
                Tw(targetCopy.dotsBtn, {TextColor3 = T.accent}, 0.22)
            end
        end)
    end

    if mName == "Always" and targetCopy.toggle then
        targetCopy.toggle.setToggleState(true, true)
    end

    local clickedBtn = bcmButtons[mName]
    if clickedBtn then
        Tw(clickedBtn, {BackgroundTransparency = 0.55, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.08)
    end

    UpdateBcmVisuals()
    task.delay(0.08, function()
        CloseKeybindContextMenu(false)
        if UpdateKeybindsHud then UpdateKeybindsHud() end
        SaveConfig()
    end)
end

for i, mName in ipairs({"Toggle", "Hold", "Always"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 21)
    btn.BackgroundTransparency = 1
    btn.BackgroundColor3 = T.accent
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Arcade
    btn.Text = mName
    btn.TextColor3 = T.textDim
    btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Center
    btn.AutoButtonColor = false
    btn.ZIndex = 87
    btn.LayoutOrder = (i - 1) * 2 + 1
    btn.Parent = bcmList
    Crn(btn, 4)

    bcmButtons[mName] = btn

    btn.MouseEnter:Connect(function()
        local isCur = bcmTarget and featureBinds[bcmTarget.name] and (featureBinds[bcmTarget.name].mode or "Toggle") == mName
        Tw(btn, {
            BackgroundColor3 = T.accent,
            BackgroundTransparency = isCur and 0.70 or 0.88,
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
    btn.MouseLeave:Connect(function()
        local isCur = bcmTarget and featureBinds[bcmTarget.name] and (featureBinds[bcmTarget.name].mode or "Toggle") == mName
        if isCur then
            Tw(btn, {
                TextColor3 = T.accent,
                BackgroundColor3 = T.accent,
                BackgroundTransparency = 0.84
            }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            btn.Font = Enum.Font.Arcade
        else
            Tw(btn, {
                TextColor3 = T.textDim,
                BackgroundTransparency = 1
            }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            btn.Font = Enum.Font.Arcade
        end
    end)
    btn.MouseButton1Click:Connect(function()
        SelectBindMode(mName)
    end)

    if i < 3 then
        local sep = Instance.new("Frame")
        sep.Size = UDim2.new(1, 0, 0, 3)
        sep.BackgroundTransparency = 1
        sep.BorderSizePixel = 0
        sep.LayoutOrder = (i - 1) * 2 + 2
        sep.Parent = bcmList

        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, -14, 0, 1)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(0.5, 0, 0.5, 0)
        line.BackgroundColor3 = Color3.fromRGB(34, 34, 46)
        line.BorderSizePixel = 0
        line.Parent = sep
    end
end

OpenKeybindContextMenu = function(targetName, dotsBtn, dotsF, targetToggle)
    bcmIsOpen = true
    bcmTarget = {name = targetName, dotsBtn = dotsBtn, dotsF = dotsF, toggle = targetToggle}
    UpdateBcmVisuals()

    local absPos = dotsBtn.AbsolutePosition
    local absSize = dotsBtn.AbsoluteSize
    local vSize = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
    local posX = math.clamp(absPos.X - 35, 10, vSize.X - 96)
    local posY = math.clamp(absPos.Y + absSize.Y + 4, 10, vSize.Y - 80)

    local targetPos = UDim2.new(0, posX, 0, posY)
    local startPos = UDim2.new(0, posX, 0, posY - 6)

    bindContextMenu.Position = startPos
    bindContextMenu.Visible = true

    if hasCanvasGroup then
        bindContextMenu.GroupTransparency = 1
        bindContextMenu.Size = UDim2.new(0, 84, 0, 75)
        Tw(bindContextMenu, {GroupTransparency = 0, Position = targetPos}, 0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    else
        bindContextMenu.Size = UDim2.new(0, 84, 0, 0)
        Tw(bindContextMenu, {Size = UDim2.new(0, 84, 0, 75), Position = targetPos}, 0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end

    for i, mName in ipairs({"Toggle", "Hold", "Always"}) do
        local btn = bcmButtons[mName]
        if btn then
            btn.Position = UDim2.new(0, -6, 0, 0)
            btn.TextTransparency = 1
            task.delay(i * 0.025, function()
                if bcmIsOpen and btn.Parent then
                    Tw(btn, {Position = UDim2.new(0, 0, 0, 0), TextTransparency = 0}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                end
            end)
        end
    end
end

table.insert(allConn, UIS.InputBegan:Connect(function(i)
    if bindContextMenu.Visible and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3) then
        local mPos = i.Position
        local bPos = bindContextMenu.AbsolutePosition
        local bSize = bindContextMenu.AbsoluteSize
        if mPos.X < bPos.X or mPos.X > bPos.X + bSize.X or mPos.Y < bPos.Y or mPos.Y > bPos.Y + bSize.Y then
            CloseKeybindContextMenu(false)
        end
    end
end))

local function CancelBinding()
    if listeningTarget then
        if listeningTarget.isMenuKey then
            if listeningTarget.dotsBtn then
                local k = TOGGLE_KEY or "Delete"
                listeningTarget.dotsBtn.Text = FormatKeyName(k)
                Tw(listeningTarget.dotsBtn, {TextColor3 = T.accent}, 0.15)
            end
            if listeningTarget.dotsF then
                local s = listeningTarget.dotsF:FindFirstChildOfClass("UIStroke")
                if s then Tw(s, {Color = T.border}, 0.15) end
            end
            listeningTarget = nil
            return
        end
        if listeningTarget.dotsBtn then
            local isBound = featureBinds[listeningTarget.name] ~= nil and featureBinds[listeningTarget.name].key ~= nil
            listeningTarget.dotsBtn.Text = isBound and featureBinds[listeningTarget.name].shortKey or "..."
            Tw(listeningTarget.dotsBtn, {TextColor3 = isBound and T.accent or T.textMuted}, 0.15)
        end
        if listeningTarget.dotsF then
            local s = listeningTarget.dotsF:FindFirstChildOfClass("UIStroke")
            if s then Tw(s, {Color = T.border}, 0.15) end
        end
        listeningTarget = nil
        if UpdateKeybindsHud then UpdateKeybindsHud() end
    end
end

local function StartBinding(targetName, targetDotsBtn, targetDotsF, targetToggle, isMenuKey)
    CloseKeybindContextMenu(true)
    if listeningTarget and listeningTarget.name == targetName then
        CancelBinding()
        return
    end
    if listeningTarget then
        CancelBinding()
    end
    listeningTarget = {
        name = targetName,
        dotsBtn = targetDotsBtn,
        dotsF = targetDotsF,
        toggle = targetToggle,
        isMenuKey = isMenuKey,
        startTime = os.clock(),
    }
    if targetDotsBtn then
        targetDotsBtn.Text = "[?]"
        targetDotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Tw(targetDotsBtn, {TextColor3 = T.accent}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
    if targetDotsF then
        local s = targetDotsF:FindFirstChildOfClass("UIStroke")
        if s then Tw(s, {Color = T.accent}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
    end
    if not isMenuKey and UpdateKeybindsHud then UpdateKeybindsHud() end
end

UpdateKeybindsHud = function()
    if not kbList or not kbWin then return end

    local items = {}
    local seen = {}

    for _, t in ipairs(allRegisteredTogglesList) do
        local name = t.name
        local bData = featureBinds[name]
        local isBound = (bData ~= nil and (bData.key ~= nil or bData.mode == "Always"))
        local isActive = t.isEnabled()
        if isActive and isBound and not seen[name] then
            seen[name] = true
            table.insert(items, {
                name = name,
                toggle = t,
                key = bData.key,
                shortKey = bData.shortKey or "...",
                mode = bData.mode or "Toggle",
            })
        end
    end

    -- When there are no active binds or HUD disabled: smoothly animate out and hide
    if #items == 0 or not kbHudVisible then
        if kbShown then
            kbShown = false
            if hasCanvasGroup then
                Tw(kbWin, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.delay(0.16, function()
                if not kbShown then
                    kbWin.Visible = false
                    kbWin.Position = UDim2.new(0, kbHudPosX, 0, kbHudPosY)
                    if hasCanvasGroup then kbWin.GroupTransparency = 1 end
                end
            end)
        else
            kbWin.Visible = false
            kbWin.Position = UDim2.new(0, kbHudPosX, 0, kbHudPosY)
        end
        return
    end

    -- Clear previous rows
    for _, ch in ipairs(kbList:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") or ch:IsA("TextButton") then
            ch:Destroy()
        end
    end

    -- Always lock Position strictly to canonical coordinates to prevent any drift
    kbWin.Position = UDim2.new(0, kbHudPosX, 0, kbHudPosY)

    -- When appearing: smooth fade without position drift
    if not kbShown then
        kbShown = true
        kbWin.Visible = true
        if hasCanvasGroup then
            kbWin.GroupTransparency = 1
            Tw(kbWin, {GroupTransparency = 0}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    else
        kbWin.Visible = true
        if hasCanvasGroup then kbWin.GroupTransparency = 0 end
    end

    local order = 0
    for i, it in ipairs(items) do
        order += 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.ZIndex = 52
        row.Parent = kbList

        -- Row entrance: static position without sliding
        row.Position = UDim2.new(0, 0, 0, 0)

        local nameL = Lbl(row, it.name, 10, T.text, Enum.Font.Arcade, Enum.TextXAlignment.Left, 53)
        nameL.Size = UDim2.new(1, -50, 1, 0)
        nameL.Position = UDim2.new(0, 0, 0, 0)
        nameL.TextTruncate = Enum.TextTruncate.AtEnd
        nameL.TextTransparency = 0

        local isListening = (listeningTarget and listeningTarget.name == it.name)

        -- Keybind button: clean text without any contour or box outline
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 48, 1, 0)
        keyBtn.Position = UDim2.new(1, 0, 0, 0)
        keyBtn.AnchorPoint = Vector2.new(1, 0)
        keyBtn.BackgroundTransparency = 1
        keyBtn.BorderSizePixel = 0
        keyBtn.Font = Enum.Font.Arcade
        keyBtn.TextSize = 8
        keyBtn.TextXAlignment = Enum.TextXAlignment.Right
        keyBtn.AutoButtonColor = false
        keyBtn.ZIndex = 54

        local keyText
        if isListening then
            keyText = "[?]"
        elseif it.key then
            keyText = "[" .. it.shortKey .. "]"
        elseif it.mode == "Always" then
            keyText = "[Always]"
        else
            keyText = "[" .. it.shortKey .. "]"
        end
        keyBtn.Text = keyText
        keyBtn.TextColor3 = isListening and T.accent or Color3.fromRGB(255, 255, 255)
        keyBtn.TextTransparency = 1
        keyBtn.Parent = row
        -- Activation flash on key label
        Tw(keyBtn, {TextTransparency = 0, TextColor3 = isListening and T.accent or T.textDim}, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        -- Row hover animation
        local function onRowEnter()
            Tw(nameL, {TextColor3 = Color3.fromRGB(245, 248, 255)}, 0.12)
            if not isListening then
                Tw(keyBtn, {TextColor3 = T.accent}, 0.12)
            end
        end
        local function onRowLeave()
            Tw(nameL, {TextColor3 = T.text}, 0.12)
            if not isListening then
                Tw(keyBtn, {TextColor3 = T.textDim}, 0.12)
            end
        end

        keyBtn.MouseEnter:Connect(onRowEnter); keyBtn.MouseLeave:Connect(onRowLeave)

        keyBtn.MouseButton1Click:Connect(function()
            if listeningTarget and listeningTarget.name == it.name then
                CancelBinding()
            else
                StartBinding(it.name, it.toggle.dotsBtn, it.toggle.dotsF, it.toggle)
            end
        end)
        keyBtn.MouseButton2Click:Connect(function()
            if listeningTarget then return end
            featureBinds[it.name] = nil
            if it.toggle.dotsBtn then
                it.toggle.dotsBtn.Text = "..."
                Tw(it.toggle.dotsBtn, {TextColor3 = T.textMuted}, 0.15)
            end
            UpdateKeybindsHud()
            SaveConfig()
        end)
        keyBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton3 then
                if listeningTarget then return end
                OpenKeybindContextMenu(it.name, it.toggle.dotsBtn, it.toggle.dotsF, it.toggle)
            end
        end)

        local rowClick = Instance.new("TextButton")
        rowClick.Size = UDim2.new(1, -78, 1, 0)
        rowClick.BackgroundTransparency = 1
        rowClick.Text = ""
        rowClick.ZIndex = 53
        rowClick.Parent = row
        rowClick.MouseEnter:Connect(onRowEnter); rowClick.MouseLeave:Connect(onRowLeave)
        rowClick.MouseButton1Click:Connect(function()
            StartBinding(it.name, it.toggle.dotsBtn, it.toggle.dotsF, it.toggle)
        end)
        rowClick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton3 then
                OpenKeybindContextMenu(it.name, it.toggle.dotsBtn, it.toggle.dotsF, it.toggle)
            end
        end)

        -- If multiple binds, insert a divider line between them that does NOT extend to the ends
        if i < #items then
            order += 1
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(1, 0, 0, 7)
            sep.BackgroundTransparency = 1
            sep.BorderSizePixel = 0
            sep.LayoutOrder = order
            sep.ZIndex = 52
            sep.Parent = kbList

            local line = Instance.new("Frame")
            line.Size = UDim2.new(1, -20, 0, 1)
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.Position = UDim2.new(0.5, 0, 0.5, 0)
            line.BackgroundColor3 = T.border
            line.BackgroundTransparency = 1
            line.BorderSizePixel = 0
            line.ZIndex = 52
            line.Parent = sep
            Tw(line, {BackgroundTransparency = 0.25}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end
end

-- ══════════════════════════════════════════════
--  BLUR & OPEN/CLOSE ANIMATION
-- ══════════════════════════════════════════════
local blurEffect = Lighting:FindFirstChild("NOVA_Blur")
if not blurEffect or not blurEffect:IsA("BlurEffect") then
    blurEffect = Instance.new("BlurEffect")
    blurEffect.Name = "NOVA_Blur"
    blurEffect.Parent = Lighting
end
blurEffect.Size = 0
blurEffect.Enabled = false

local blurEnabled = true
local function ShowBlur()
    if not blurEnabled or not menuOpen then return end
    if not win or not win.Parent or not win.Visible then return end
    if getgenv and getgenv().NOVA_CURRENT_ID ~= SCRIPT_ID then return end
    blurEffect.Enabled = true
    Tw(blurEffect, {Size=8}, .3)
end

local function HideBlur()
    Tw(blurEffect, {Size=0}, .2)
    for _, b in ipairs(Lighting:GetChildren()) do
        if b:IsA("BlurEffect") and (b.Name == "NOVA_Blur" or b == blurEffect) then
            Tw(b, {Size=0}, .2)
        end
    end
    task.delay(.22, function()
        if not menuOpen then
            pcall(function()
                blurEffect.Size = 0
                blurEffect.Enabled = false
            end)
            for _, b in ipairs(Lighting:GetChildren()) do
                if b:IsA("BlurEffect") and (b.Name == "NOVA_Blur" or b == blurEffect) then
                    pcall(function() b.Size = 0; b.Enabled = false end)
                end
            end
        end
    end)
end

local function OpenMenu()
    menuOpen = true
    win.Visible = true
    uiScale.Scale = 1
    ShowBlur()
    if UpdateKeybindsHud then UpdateKeybindsHud() end

    -- Auto-recover HUDs if off-screen
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize
    if not vs or vs.X < 200 or vs.Y < 200 then vs = Vector2.new(1920, 1080) end
    if kbWin then
        local curX = kbWin.Position.X.Offset
        local curY = kbWin.Position.Y.Offset
        if curX < 0 or curX > vs.X - 30 or curY < 40 or curY > vs.Y - 20 then
            kbHudPosX = math.clamp(curX, 20, math.max(20, vs.X - 210))
            kbHudPosY = math.clamp(curY, 50, math.max(50, vs.Y - 100))
            if curX < 0 or curX > vs.X - 30 then kbHudPosX = 20 end
            if curY < 0 or curY > vs.Y - 20 then kbHudPosY = 220 end
            kbWin.Position = UDim2.new(0, kbHudPosX, 0, kbHudPosY)
            SaveConfig()
        end
    end
    if AdminStaff.win then
        local curX = AdminStaff.win.Position.X.Offset
        local curY = AdminStaff.win.Position.Y.Offset
        if curX < 0 or curX > vs.X - 30 or curY < 0 or curY > vs.Y - 20 then
            AdminStaff.hudPosX = math.clamp(curX, 20, math.max(20, vs.X - 210))
            AdminStaff.hudPosY = math.clamp(curY, 50, math.max(50, vs.Y - 100))
            if curX < 0 or curX > vs.X - 30 then AdminStaff.hudPosX = 20 end
            if curY < 0 or curY > vs.Y - 20 then AdminStaff.hudPosY = 100 end
            AdminStaff.win.Position = UDim2.new(0, AdminStaff.hudPosX, 0, AdminStaff.hudPosY)
            SaveConfig()
        end
    end
    if Watermark and Watermark.win then
        local sx = Watermark.scaleX or (Watermark.posX and 0 or 0.5)
        local ox = Watermark.posX or 0
        local sy = Watermark.scaleY or 0
        local oy = Watermark.posY or 20
        local w = (Watermark.win.AbsoluteSize.X > 0 and Watermark.win.AbsoluteSize.X) or 300
        local h = (Watermark.win.AbsoluteSize.Y > 0 and Watermark.win.AbsoluteSize.Y) or 30
        local halfW = math.floor(w / 2)
        local halfH = math.floor(h / 2)
        local minOX = (halfW + 4) - (sx * vs.X)
        local maxOX = (vs.X - halfW - 4) - (sx * vs.X)
        local minOY = (halfH + 4) - (sy * vs.Y)
        local maxOY = (vs.Y - halfH - 4) - (sy * vs.Y)
        if ox < minOX or ox > maxOX or oy < minOY or oy > maxOY then
            Watermark.posX = math.clamp(ox, minOX, maxOX)
            Watermark.posY = math.clamp(oy, minOY, maxOY)
            Watermark.scaleX = sx
            Watermark.scaleY = sy
            Watermark.win.Position = UDim2.new(sx, Watermark.posX, sy, Watermark.posY)
            if Watermark.shadow then Watermark.shadow.Position = UDim2.new(sx, Watermark.posX, sy, Watermark.posY + 1) end
            SaveConfig()
        end
    end
end

local function CloseMenu()
    menuOpen = false
    win.Visible = false
    uiScale.Scale = 1
    HideBlur()
    CancelBinding()
    if ConfigSystem and ConfigSystem.HideTooltip then ConfigSystem.HideTooltip() end
    if UpdateKeybindsHud then UpdateKeybindsHud() end
    SaveConfig()
end

-- ══════════════════════════════════════════════
--  2D MENU PARTICLES (Rain & Snow)
-- ══════════════════════════════════════════════
local MenuParticles = {
    rainCanvas = nil,
    snowCanvas = nil,
    rainEnabled = true,
    snowEnabled = false,
}
local weatherToggles = {}
local SetWeather, RestoreWeatherAtmosphere = nil, nil
local function InitWeatherSystem()
local activeWeather = nil
local rainSG = Instance.new("ScreenGui")
rainSG.Name = "NOVA_Rain"; rainSG.ResetOnSpawn = false; rainSG.IgnoreGuiInset = true
rainSG.DisplayOrder = 9999
rainSG.ZIndexBehavior = Enum.ZIndexBehavior.Global; rainSG.Parent = safeParent

local rainCanvas = Instance.new("Frame")
rainCanvas.Size = UDim2.new(1,0,1,0); rainCanvas.BackgroundTransparency = 1
rainCanvas.BorderSizePixel = 0; rainCanvas.ClipsDescendants = true; rainCanvas.Parent = win
MenuParticles.rainCanvas = rainCanvas

local snowCanvas = Instance.new("Frame")
snowCanvas.Size = UDim2.new(1,0,1,0); snowCanvas.BackgroundTransparency = 1
snowCanvas.BorderSizePixel = 0; snowCanvas.ClipsDescendants = true; snowCanvas.Parent = win
MenuParticles.snowCanvas = snowCanvas

local function MakeRainDrop()
    local drop = Instance.new("Frame")
    drop.BackgroundColor3 = T.accent
    drop.BackgroundTransparency = math.random(60, 85) / 100
    drop.BorderSizePixel = 0
    local w = math.random(1, 2)
    local h = math.random(12, 26)
    local x = math.random(0, 1000) / 1000
    drop.Size = UDim2.new(0, w, 0, h)
    drop.Position = UDim2.new(x, 0, -0.05, 0)
    drop.ZIndex = 1; drop.Parent = rainCanvas
    Crn(drop, 1)
    return drop
end

local function MakeSnowFlake()
    local flake = Instance.new("Frame")
    flake.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
    flake.BackgroundTransparency = math.random(25, 60) / 100
    flake.BorderSizePixel = 0
    local size = math.random(3, 7)
    local x = math.random(0, 1000) / 1000
    flake.Size = UDim2.new(0, size, 0, size)
    flake.Position = UDim2.new(x, 0, -0.05, 0)
    flake.ZIndex = 1; flake.Parent = snowCanvas
    Crn(flake, 10)
    return flake
end

task.spawn(function()
    while true do
        if MenuParticles.rainEnabled and menuOpen then
            local drop = MakeRainDrop()
            local duration = math.random(9, 18) / 10
            local xDrift = math.random(-15, 15)
            local startPos = drop.Position
            Tw(drop, {
                Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + xDrift,
                    1.05, 0
                ),
                BackgroundTransparency = 0.95,
            }, duration, Enum.EasingStyle.Linear)
            task.delay(duration, function()
                if drop and drop.Parent then drop:Destroy() end
            end)
        end
        if MenuParticles.snowEnabled and menuOpen then
            local flake = MakeSnowFlake()
            local duration = math.random(25, 45) / 10
            local xDrift = math.random(-40, 40)
            local startPos = flake.Position
            Tw(flake, {
                Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + xDrift,
                    1.05, 0
                ),
                BackgroundTransparency = 0.92,
            }, duration, Enum.EasingStyle.Linear)
            task.delay(duration, function()
                if flake and flake.Parent then flake:Destroy() end
            end)
        end
        task.wait(0.08)
    end
end)

-- ══════════════════════════════════════════════
--  ROBLOX MAP & 3D WORLD WEATHER SYSTEM
-- ══════════════════════════════════════════════
local origLighting = {
    FogColor       = Lighting.FogColor,
    FogEnd         = Lighting.FogEnd,
    FogStart       = Lighting.FogStart,
    Brightness     = Lighting.Brightness,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ClockTime      = Lighting.ClockTime,
    ColorShift_Top = Lighting.ColorShift_Top,
}

local weatherPart = Instance.new("Part")
weatherPart.Name = "NOVA_WeatherPart"
weatherPart.Transparency = 1
weatherPart.CanCollide = false
weatherPart.CanQuery = false
weatherPart.CanTouch = false
weatherPart.CastShadow = false
weatherPart.Anchored = true
weatherPart.Size = Vector3.new(100, 2, 100)
weatherPart.Parent = workspace

local sandPart = Instance.new("Part")
sandPart.Name = "NOVA_SandPart"
sandPart.Transparency = 1
sandPart.CanCollide = false
sandPart.CanQuery = false
sandPart.CanTouch = false
sandPart.CastShadow = false
sandPart.Anchored = true
sandPart.Size = Vector3.new(45, 25, 45)
sandPart.Parent = workspace

local weatherCC = Instance.new("ColorCorrectionEffect")
weatherCC.Name = "NOVA_WeatherCC"
weatherCC.Enabled = false
weatherCC.Parent = Lighting

local lightningSG = Instance.new("ScreenGui")
lightningSG.Name = "NOVA_Lightning"
lightningSG.ResetOnSpawn = false
lightningSG.IgnoreGuiInset = true
lightningSG.Parent = safeParent

local lightningFlash = Instance.new("Frame")
lightningFlash.Size = UDim2.new(1, 0, 1, 0)
lightningFlash.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
lightningFlash.BackgroundTransparency = 1
lightningFlash.BorderSizePixel = 0
lightningFlash.ZIndex = 99
lightningFlash.Parent = lightningSG

local lightningFolder = Instance.new("Folder")
lightningFolder.Name = "NOVA_LightningBolts"
lightningFolder.Parent = workspace

-- Atmosphere and Clouds handling (procedural sky dome without purple nebula textures)
local savedSky = nil
local savedAtmosphere = nil
local weatherAtmo = nil
local weatherClouds = nil

local function EnsureWeatherAtmosphere()
    -- Hide any existing Sky or Atmosphere in Lighting so their textures/settings don't bleed through!
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") then
            if not savedSky then savedSky = obj end
            obj.Parent = nil
        elseif obj:IsA("Atmosphere") and obj.Name ~= "NOVA_WeatherAtmo" then
            if not savedAtmosphere then savedAtmosphere = obj end
            obj.Parent = nil
        end
    end

    if not weatherAtmo or not weatherAtmo.Parent then
        pcall(function()
            weatherAtmo = Instance.new("Atmosphere")
            weatherAtmo.Name = "NOVA_WeatherAtmo"
            weatherAtmo.Parent = Lighting
        end)
    end
    if not weatherClouds or not weatherClouds.Parent then
        pcall(function()
            weatherClouds = Instance.new("Clouds")
            weatherClouds.Name = "NOVA_WeatherClouds"
            weatherClouds.Parent = workspace.Terrain
        end)
    end
end

RestoreWeatherAtmosphere = function()
    if weatherAtmo then
        pcall(function() weatherAtmo:Destroy() end)
        weatherAtmo = nil
    end
    if weatherClouds then
        pcall(function() weatherClouds:Destroy() end)
        weatherClouds = nil
    end
    if savedSky and savedSky.Parent == nil then
        pcall(function() savedSky.Parent = Lighting end)
        savedSky = nil
    end
    if savedAtmosphere and savedAtmosphere.Parent == nil then
        pcall(function() savedAtmosphere.Parent = Lighting end)
        savedAtmosphere = nil
    end
end

-- SNOW EMITTER
local snowEmitter = Instance.new("ParticleEmitter")
snowEmitter.Name = "SnowEmitter"
snowEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
snowEmitter.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
snowEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.35),
    NumberSequenceKeypoint.new(0.5, 0.55),
    NumberSequenceKeypoint.new(1, 0.3)
})
snowEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.3),
    NumberSequenceKeypoint.new(0.8, 0.15),
    NumberSequenceKeypoint.new(1, 0.85)
})
snowEmitter.Speed = NumberRange.new(14, 24)
snowEmitter.Rate = 280
snowEmitter.Lifetime = NumberRange.new(3.0, 5.0)
snowEmitter.SpreadAngle = Vector2.new(20, 20)
snowEmitter.Acceleration = Vector3.new(2, -15, -2)
snowEmitter.EmissionDirection = Enum.NormalId.Bottom
snowEmitter.Enabled = false
snowEmitter.Parent = weatherPart

-- RAIN EMITTER (Falling vertical rain sticks in 3D world)
local rainEmitter = Instance.new("ParticleEmitter")
rainEmitter.Name = "RainEmitter"
rainEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
rainEmitter.Color = ColorSequence.new(Color3.fromRGB(225, 238, 255))
rainEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.45),
    NumberSequenceKeypoint.new(0.5, 0.50),
    NumberSequenceKeypoint.new(1, 0.45)
})
rainEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.10),
    NumberSequenceKeypoint.new(0.8, 0.20),
    NumberSequenceKeypoint.new(1, 0.60)
})
rainEmitter.Speed = NumberRange.new(125, 175)
rainEmitter.Rate = 750
rainEmitter.Lifetime = NumberRange.new(0.9, 1.4)
rainEmitter.SpreadAngle = Vector2.new(1, 1)
rainEmitter.Acceleration = Vector3.new(0, -180, 0)
rainEmitter.EmissionDirection = Enum.NormalId.Bottom
pcall(function()
    rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
    rainEmitter.Squash = NumberSequence.new(-3.0)
end)
rainEmitter.Enabled = false
rainEmitter.Parent = weatherPart

-- SAND PARTICLES (Fast horizontal flying streaks across screen)
local sandEmitter = Instance.new("ParticleEmitter")
sandEmitter.Name = "SandEmitter"
sandEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
sandEmitter.Color = ColorSequence.new(Color3.fromRGB(215, 185, 130))
sandEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.22),
    NumberSequenceKeypoint.new(0.5, 0.45),
    NumberSequenceKeypoint.new(1, 0.2)
})
sandEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.25),
    NumberSequenceKeypoint.new(0.5, 0.10),
    NumberSequenceKeypoint.new(1, 0.70)
})
sandEmitter.Speed = NumberRange.new(90, 135)
sandEmitter.Rate = 950
sandEmitter.Lifetime = NumberRange.new(0.6, 1.2)
sandEmitter.SpreadAngle = Vector2.new(10, 8)
sandEmitter.Acceleration = Vector3.new(100, -6, 15)
sandEmitter.EmissionDirection = Enum.NormalId.Right
pcall(function()
    sandEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
    sandEmitter.Squash = NumberSequence.new(-3.0)
end)
sandEmitter.Enabled = false
sandEmitter.Parent = sandPart

-- SAND HAZE (Soft blowing dust puffs)
local sandHazeEmitter = Instance.new("ParticleEmitter")
sandHazeEmitter.Name = "SandHazeEmitter"
sandHazeEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
sandHazeEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 175, 130))
sandHazeEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 2.5),
    NumberSequenceKeypoint.new(0.5, 6.0),
    NumberSequenceKeypoint.new(1, 10.0)
})
sandHazeEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.85),
    NumberSequenceKeypoint.new(0.5, 0.65),
    NumberSequenceKeypoint.new(1, 0.95)
})
sandHazeEmitter.Speed = NumberRange.new(55, 90)
sandHazeEmitter.Rate = 180
sandHazeEmitter.Lifetime = NumberRange.new(1.0, 1.8)
sandHazeEmitter.SpreadAngle = Vector2.new(15, 10)
sandHazeEmitter.Acceleration = Vector3.new(80, -4, 15)
sandHazeEmitter.EmissionDirection = Enum.NormalId.Right
sandHazeEmitter.Enabled = false
sandHazeEmitter.Parent = sandPart

table.insert(allConn, RS.RenderStepped:Connect(function()
    if activeWeather and workspace.CurrentCamera then
        local camCF = workspace.CurrentCamera.CFrame
        local cPos = camCF.Position
        if weatherPart then
            weatherPart.CFrame = CFrame.new(cPos.X, cPos.Y + 16, cPos.Z)
        end
        if sandPart then
            sandPart.CFrame = camCF * CFrame.new(-18, 0, -8)
        end
    end
end))

local function SpawnLightningBolt()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camCF = cam.CFrame
    local camPos = camCF.Position

    local fwd = math.random(50, 115)
    local side = math.random(-40, 40)
    local targetGround = camPos + (camCF.LookVector * fwd) + (camCF.RightVector * side)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {weatherPart, sandPart, lightningFolder}
    if LP.Character then
        table.insert(filterList, LP.Character)
    end
    rayParams.FilterDescendantsInstances = filterList

    local hit = workspace:Raycast(targetGround + Vector3.new(0, 150, 0), Vector3.new(0, -350, 0), rayParams)
    local endPos = hit and hit.Position or Vector3.new(targetGround.X, camPos.Y - 6, targetGround.Z)

    local skyHeight = math.random(110, 160)
    local startPos = endPos + Vector3.new(math.random(-30, 30), skyHeight, math.random(-30, 30))

    local boltModel = Instance.new("Model")
    boltModel.Name = "NOVA_Bolt"
    boltModel.Parent = lightningFolder

    local function MakeSeg(p1, p2, thick, col)
        local len = (p2 - p1).Magnitude
        if len < 0.1 then return end
        local p = Instance.new("Part")
        p.Name = "Seg"
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = col or Color3.fromRGB(240, 248, 255)
        p.Size = Vector3.new(thick, thick, len)
        p.CFrame = CFrame.new(p1:Lerp(p2, 0.5), p2)
        p.Parent = boltModel
    end

    local points = {startPos}
    local segCount = 8
    for i = 1, segCount - 1 do
        local frac = i / segCount
        local base = startPos:Lerp(endPos, frac)
        local jitter = Vector3.new(math.random(-8, 8), math.random(-2, 2), math.random(-8, 8))
        table.insert(points, base + jitter)
    end
    table.insert(points, endPos)

    for i = 1, #points - 1 do
        MakeSeg(points[i], points[i + 1], 0.7, Color3.fromRGB(245, 250, 255))
    end

    local branchIdx = math.random(3, 5)
    local bStart = points[branchIdx]
    if bStart then
        local bEnd = bStart + Vector3.new(math.random(-25, 25), -math.random(30, 50), math.random(-25, 25))
        local bPts = {bStart}
        for b = 1, 3 do
            local frac = b / 4
            table.insert(bPts, bStart:Lerp(bEnd, frac) + Vector3.new(math.random(-5, 5), math.random(-2, 2), math.random(-5, 5)))
        end
        table.insert(bPts, bEnd)
        for b = 1, #bPts - 1 do
            MakeSeg(bPts[b], bPts[b + 1], 0.4, Color3.fromRGB(215, 235, 255))
        end
    end

    local impact = Instance.new("Part")
    impact.Name = "Impact"
    impact.Shape = Enum.PartType.Ball
    impact.Anchored = true
    impact.CanCollide = false
    impact.CanQuery = false
    impact.CanTouch = false
    impact.CastShadow = false
    impact.Material = Enum.Material.Neon
    impact.Color = Color3.fromRGB(255, 255, 255)
    impact.Size = Vector3.new(3.5, 3.5, 3.5)
    impact.CFrame = CFrame.new(endPos)
    impact.Parent = boltModel

    local pLight = Instance.new("PointLight")
    pLight.Color = Color3.fromRGB(225, 240, 255)
    pLight.Range = 80
    pLight.Brightness = 10
    pLight.Parent = impact

    task.delay(0.13, function()
        pcall(function()
            if boltModel then boltModel:Destroy() end
        end)
    end)
end

task.spawn(function()
    while true do
        if activeWeather == "Thunderstorm" then
            task.wait(math.random(3, 7))
            if activeWeather == "Thunderstorm" then
                SpawnLightningBolt()
                Lighting.Brightness = 3.6
                Lighting.FogColor = Color3.fromRGB(225, 238, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(225, 238, 255)
                lightningFlash.BackgroundTransparency = 0.50
                Tw(lightningFlash, {BackgroundTransparency = 1}, 0.20)
                task.wait(0.06)
                if activeWeather == "Thunderstorm" then
                    Lighting.Brightness = 1.2
                    task.wait(0.04)
                    Lighting.Brightness = 2.6
                    lightningFlash.BackgroundTransparency = 0.68
                    Tw(lightningFlash, {BackgroundTransparency = 1}, 0.15)
                    task.wait(0.08)
                    Lighting.Brightness = 0.85
                    Lighting.FogColor = Color3.fromRGB(80, 85, 95)
                    Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 105)
                end
            end
        else
            task.wait(0.5)
        end
    end
end)

SetWeather = function(mode, enabled)
    if not enabled then
        if activeWeather == mode then
            activeWeather = nil
            snowEmitter.Enabled = false
            rainEmitter.Enabled = false
            sandEmitter.Enabled = false
            sandHazeEmitter.Enabled = false
            weatherCC.Enabled = false
            RestoreWeatherAtmosphere()
            if lightningFolder then lightningFolder:ClearAllChildren() end
            lightningFlash.BackgroundTransparency = 1
            Lighting.FogColor       = origLighting.FogColor
            Lighting.FogEnd         = origLighting.FogEnd
            Lighting.FogStart       = origLighting.FogStart
            Lighting.Brightness     = origLighting.Brightness
            Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
            Lighting.ClockTime      = origLighting.ClockTime
            Lighting.ColorShift_Top = origLighting.ColorShift_Top
        end
        return
    end

    if weatherToggles then
        for m, toggleObj in pairs(weatherToggles) do
            if m ~= mode and toggleObj and toggleObj.isEnabled and toggleObj.isEnabled() then
                toggleObj.setToggleState(false, false)
            end
        end
    end

    activeWeather = mode
    snowEmitter.Enabled = false
    rainEmitter.Enabled = false
    sandEmitter.Enabled = false
    sandHazeEmitter.Enabled = false
    if lightningFolder then lightningFolder:ClearAllChildren() end
    lightningFlash.BackgroundTransparency = 1
    EnsureWeatherAtmosphere()

    if mode == "Snow" then
        snowEmitter.Enabled = true
        weatherCC.Enabled = true
        weatherCC.TintColor = Color3.fromRGB(235, 245, 255)
        weatherCC.Saturation = -0.08
        weatherCC.Brightness = 0.04
        Lighting.ClockTime = 14
        Lighting.FogColor = Color3.fromRGB(225, 235, 248)
        Lighting.FogStart = 30
        Lighting.FogEnd = 360
        Lighting.OutdoorAmbient = Color3.fromRGB(210, 225, 245)
        Lighting.Brightness = 1.15

        -- Pale-White Snowy Winter Sky & Atmosphere (No purple nebula!)
        if weatherAtmo then
            weatherAtmo.Density = 0.38
            weatherAtmo.Offset = 0.25
            weatherAtmo.Color = Color3.fromRGB(225, 235, 248)
            weatherAtmo.Decay = Color3.fromRGB(195, 210, 225)
            weatherAtmo.Haze = 2.0
            weatherAtmo.Glare = 0
        end
        if weatherClouds then
            weatherClouds.Enabled = true
            weatherClouds.Cover = 0.88
            weatherClouds.Density = 0.70
            weatherClouds.Color = Color3.fromRGB(240, 245, 255)
        end

    elseif mode == "Rain" then
        rainEmitter.Enabled = true
        rainEmitter.Rate = 750
        weatherCC.Enabled = true
        weatherCC.TintColor = Color3.fromRGB(205, 215, 230)
        weatherCC.Saturation = -0.15
        weatherCC.Brightness = -0.02
        Lighting.ClockTime = 14
        Lighting.FogColor = Color3.fromRGB(80, 88, 100)
        Lighting.FogStart = 25
        Lighting.FogEnd = 270
        Lighting.OutdoorAmbient = Color3.fromRGB(90, 98, 110)
        Lighting.Brightness = 0.85

        -- Gloomy Overcast Rainy Sky & Atmosphere
        if weatherAtmo then
            weatherAtmo.Density = 0.48
            weatherAtmo.Offset = 0.20
            weatherAtmo.Color = Color3.fromRGB(85, 95, 110)
            weatherAtmo.Decay = Color3.fromRGB(60, 68, 80)
            weatherAtmo.Haze = 2.8
            weatherAtmo.Glare = 0
        end
        if weatherClouds then
            weatherClouds.Enabled = true
            weatherClouds.Cover = 0.92
            weatherClouds.Density = 0.80
            weatherClouds.Color = Color3.fromRGB(70, 75, 88)
        end

    elseif mode == "Thunderstorm" then
        rainEmitter.Enabled = true
        rainEmitter.Rate = 900
        weatherCC.Enabled = true
        weatherCC.TintColor = Color3.fromRGB(205, 215, 235)
        weatherCC.Saturation = -0.12
        weatherCC.Brightness = 0.02
        Lighting.ClockTime = 14
        Lighting.FogColor = Color3.fromRGB(80, 85, 95)
        Lighting.FogStart = 25
        Lighting.FogEnd = 280
        Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 105)
        Lighting.Brightness = 0.85

        -- Dark Thunderstorm Sky & Atmosphere
        if weatherAtmo then
            weatherAtmo.Density = 0.55
            weatherAtmo.Offset = 0.15
            weatherAtmo.Color = Color3.fromRGB(70, 75, 90)
            weatherAtmo.Decay = Color3.fromRGB(48, 52, 66)
            weatherAtmo.Haze = 3.5
            weatherAtmo.Glare = 0
        end
        if weatherClouds then
            weatherClouds.Enabled = true
            weatherClouds.Cover = 0.97
            weatherClouds.Density = 0.88
            weatherClouds.Color = Color3.fromRGB(45, 50, 62)
        end

    elseif mode == "Sandstorm" then
        sandEmitter.Enabled = true
        sandHazeEmitter.Enabled = true
        weatherCC.Enabled = true
        weatherCC.TintColor = Color3.fromRGB(245, 225, 195)
        weatherCC.Saturation = 0.05
        weatherCC.Brightness = 0.02
        Lighting.ClockTime = 16.5
        Lighting.FogColor = Color3.fromRGB(195, 160, 115)
        Lighting.FogStart = 15
        Lighting.FogEnd = 200
        Lighting.OutdoorAmbient = Color3.fromRGB(175, 140, 95)
        Lighting.ColorShift_Top = Color3.fromRGB(235, 195, 135)
        Lighting.Brightness = 0.85

        -- Immersive Desert Sandstorm Sky & Atmosphere (No blue sky or rain clouds!)
        if weatherAtmo then
            weatherAtmo.Density = 0.94
            weatherAtmo.Offset = 0.90
            weatherAtmo.Color = Color3.fromRGB(215, 175, 120)
            weatherAtmo.Decay = Color3.fromRGB(180, 135, 85)
            weatherAtmo.Haze = 25.0
            weatherAtmo.Glare = 0
        end
        if weatherClouds then
            weatherClouds.Enabled = false
            weatherClouds.Cover = 0
        end
    end
end
end
InitWeatherSystem()

-- ══════════════════════════════════════════════
--  CUSTOM TOP-RIGHT HUD NOTIFICATIONS
-- ══════════════════════════════════════════════
local function InitNotificationSystem()
    local notifSG = Instance.new("ScreenGui")
    notifSG.Name = "NOVA_Notifications"
    notifSG.ResetOnSpawn = false
    notifSG.IgnoreGuiInset = true
    notifSG.DisplayOrder = 10000
    notifSG.ZIndexBehavior = Enum.ZIndexBehavior.Global
    notifSG.Parent = safeParent

    local notifHolder = Instance.new("Frame")
    notifHolder.Name = "NotifHolder"
    notifHolder.Size = UDim2.new(0, 260, 1, -20)
    notifHolder.Position = UDim2.new(1, -270, 0, 16)
    notifHolder.BackgroundTransparency = 1
    notifHolder.Parent = notifSG

    local nLL = Instance.new("UIListLayout")
    nLL.SortOrder = Enum.SortOrder.LayoutOrder
    nLL.VerticalAlignment = Enum.VerticalAlignment.Top
    nLL.HorizontalAlignment = Enum.HorizontalAlignment.Right
    nLL.Padding = UDim.new(0, 6)
    nLL.Parent = notifHolder

    Notify = function(title, text, duration, nType)
        if not notifHolder or not notifHolder.Parent then return end
        duration = duration or 3.5

        local slot = Instance.new("Frame")
        slot.Size = UDim2.new(1, 0, 0, 46)
        slot.BackgroundTransparency = 1
        slot.BorderSizePixel = 0
        slot.ClipsDescendants = false
        slot.Parent = notifHolder

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 1, 0)
        card.Position = UDim2.new(1, 80, 0, 0)
        card.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = slot
        Crn(card, 6)
        Strk(card, T.border, 1, 0)

        local tL = Lbl(card, title, 10, T.accent, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
        tL.Position = UDim2.new(0, 10, 0, 6)
        tL.Size = UDim2.new(1, -20, 0, 14)
        TrackAccent(tL, "TextColor3")

        local mL = Lbl(card, text, 9, Color3.fromRGB(175, 178, 195), Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
        mL.Position = UDim2.new(0, 10, 0, 22)
        mL.Size = UDim2.new(1, -20, 0, 18)
        mL.TextWrapped = true

        -- Progress bar
        local timerBar = Instance.new("Frame")
        timerBar.Size = UDim2.new(1, 0, 0, 2)
        timerBar.Position = UDim2.new(0, 0, 1, -2)
        timerBar.BackgroundColor3 = T.accent
        timerBar.BackgroundTransparency = 0.35
        timerBar.BorderSizePixel = 0
        timerBar.Parent = card
        TrackAccent(timerBar, "BackgroundColor3")

        -- Slide in animation from right edge
        Tw(card, {Position = UDim2.new(0, 0, 0, 0)}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Tw(timerBar, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

        task.delay(duration, function()
            if card and card.Parent and slot and slot.Parent then
                Tw(card, {Position = UDim2.new(1, 80, 0, 0), BackgroundTransparency = 1}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.delay(0.25, function()
                    if slot and slot.Parent then slot:Destroy() end
                end)
            end
        end)
    end
end
InitNotificationSystem()

-- ══════════════════════════════════════════════
--  UNLOAD SCRIPT HANDLER
-- ══════════════════════════════════════════════
local UnloadScript
UnloadScript = function()
    for _, conn in ipairs(allConn) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(allConn)

    MenuParticles.rainEnabled = false
    MenuParticles.snowEnabled = false
    menuOpen = false
    pcall(function() if SetWeather then SetWeather(nil, false) end end)
    pcall(function() if RestoreWeatherAtmosphere then RestoreWeatherAtmosphere() end end)
    pcall(function() if weatherPart then weatherPart:Destroy() end end)
    pcall(function() if sandPart then sandPart:Destroy() end end)
    pcall(function() if weatherCC then weatherCC:Destroy() end end)
    pcall(function() if lightningSG then lightningSG:Destroy() end end)
    pcall(function() if lightningFolder then lightningFolder:Destroy() end end)
    pcall(function()
        Lighting.FogColor       = origLighting.FogColor
        Lighting.FogEnd         = origLighting.FogEnd
        Lighting.FogStart       = origLighting.FogStart
        Lighting.Brightness     = origLighting.Brightness
        Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
        Lighting.ClockTime      = origLighting.ClockTime
        Lighting.ColorShift_Top = origLighting.ColorShift_Top
    end)

    pcall(function() if SetFly then SetFly(false) end end)
    pcall(function() if SetSpeed then SetSpeed(false) end end)
    pcall(function() if SetNoclip then SetNoclip(false) end end)
    pcall(function() if SetInfiniteJump then SetInfiniteJump(false) end end)
    pcall(function() if SetPlayerESP then SetPlayerESP(false) end end)
    pcall(function() if SetAimbot then SetAimbot(false) end end)
    pcall(function() if SetTriggerbot then SetTriggerbot(false) end end)
    pcall(function() if Aim and Aim.SetNoRecoil then Aim.SetNoRecoil(false) end end)
    pcall(function() if Freecam and Freecam.SetEnabled then Freecam.SetEnabled(false) end end)

    pcall(function() if fovSG then fovSG:Destroy() end end)
    pcall(function() if bindContextMenu then bindContextMenu:Destroy() end end)
    pcall(function() if kbWin and kbWin.Parent then kbWin:Destroy() end end)
    pcall(function() if AdminStaff and AdminStaff.win and AdminStaff.win.Parent then AdminStaff.win:Destroy() end end)
    pcall(function() if Crosshair and Crosshair.gui and Crosshair.gui.Parent then Crosshair.gui:Destroy() end end)
    pcall(function() local nsg = safeParent:FindFirstChild("NOVA_Notifications"); if nsg then nsg:Destroy() end end)
    pcall(function() local dsg = safeParent:FindFirstChild("NOVA_DamageHUD"); if dsg then dsg:Destroy() end end)
    pcall(function() local g = workspace:FindFirstChild("NOVA_Ghosts"); if g then g:Destroy() end end)
    pcall(function()
        blurEffect.Size = 0
        blurEffect.Enabled = false
        blurEffect:Destroy()
    end)
    for _, b in ipairs(Lighting:GetChildren()) do
        if b:IsA("BlurEffect") and (b.Name == "NOVA_Blur" or b == blurEffect) then
            pcall(function()
                b.Size = 0
                b.Enabled = false
                b:Destroy()
            end)
        end
    end
    pcall(function() rainSG:Destroy() end)
    pcall(function() SG:Destroy() end)

    pcall(function()
        if getgenv and getgenv().NOVA_UNLOAD == UnloadScript then
            getgenv().NOVA_UNLOAD = nil
        end
    end)
    print("[NOVA] Script successfully unloaded.")
end

pcall(function()
    if getgenv then
        getgenv().NOVA_UNLOAD = UnloadScript
    end
end)

-- ══════════════════════════════════════════════
--  TOPBAR (height = 42)
-- ══════════════════════════════════════════════
local TOP_H = 42
local isGlassTop = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, TOP_H); topbar.BackgroundColor3 = T.topbar
topbar.BackgroundTransparency = isGlassTop and 1 or 0
topbar.BorderSizePixel = 0; topbar.ZIndex = 4; topbar.Parent = win
Crn(topbar, 8)

local topCover = Instance.new("Frame")
topCover.Size = UDim2.new(1, 0, 0, 10); topCover.Position = UDim2.new(0, 0, 1, -10)
topCover.BackgroundColor3 = T.topbar
topCover.BackgroundTransparency = isGlassTop and 1 or 0
topCover.BorderSizePixel = 0; topCover.ZIndex = 3; topCover.Parent = topbar

local topDivLine = Div(topbar, false, T.border)
topDivLine.Position = UDim2.new(0, 0, 1, -1); topDivLine.ZIndex = 5

if ConfigSystem then
    ConfigSystem.topbar = topbar
    ConfigSystem.topCover = topCover
    ConfigSystem.topDivLine = topDivLine
end

-- Nova brand label (bold font, dynamic accent color)
local novaLabel = Instance.new("TextLabel")
novaLabel.Size = UDim2.new(0, 80, 1, 0)
novaLabel.Position = UDim2.new(0, 14, 0, 0)
novaLabel.BackgroundTransparency = 1
novaLabel.Font = Enum.Font.Arcade
novaLabel.Text = "Nova"
novaLabel.TextSize = 18
novaLabel.TextColor3 = T.accent
novaLabel.TextXAlignment = Enum.TextXAlignment.Left
novaLabel.ZIndex = 6
novaLabel.Parent = topbar
TrackAccent(novaLabel, "TextColor3")

-- Dragging window via Topbar
local dragData = {}
topbar.InputBegan:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and not resizeState.active then
        dragData = {drag=true, start=i.Position, orig=win.Position}
        if ConfigSystem and ConfigSystem.HideTooltip then ConfigSystem.HideTooltip() end
    end
end)
table.insert(allConn, UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragData.drag = false
    end
end))
table.insert(allConn, UIS.InputChanged:Connect(function(i)
    if dragData.drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragData.start
        win.Position = UDim2.new(dragData.orig.X.Scale, dragData.orig.X.Offset+d.X,
                                 dragData.orig.Y.Scale, dragData.orig.Y.Offset+d.Y)
    end
end))

-- Search input (centered in topbar, clean, English)
local searchF = Instance.new("Frame")
searchF.Size = UDim2.new(0, 220, 0, 24); searchF.AnchorPoint = Vector2.new(0.5, 0.5)
searchF.Position = UDim2.new(0.5, 0, 0.5, 0)
local isGlassSearch = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
searchF.BackgroundColor3 = isGlassSearch and Color3.fromRGB(24, 24, 32) or T.inputBg
searchF.BackgroundTransparency = isGlassSearch and 0.65 or 0
searchF.BorderSizePixel = 0; searchF.ZIndex = 5; searchF.Parent = topbar
Crn(searchF, 6)
local searchStroke = Strk(searchF, T.border, 1, 0)
if isGlassSearch then searchStroke.Transparency = 0.5 end
if ConfigSystem then
    ConfigSystem.searchF = searchF
    ConfigSystem.searchStroke = searchStroke
end

local searchTB = Instance.new("TextBox")
searchTB.Size = UDim2.new(1, -16, 1, 0); searchTB.Position = UDim2.new(0, 8, 0, 0)
searchTB.BackgroundTransparency = 1; searchTB.Font = Enum.Font.Arcade
searchTB.PlaceholderText = "Search..."; searchTB.PlaceholderColor3 = Color3.fromRGB(115, 120, 140)
searchTB.Text = ""; searchTB.TextColor3 = Color3.fromRGB(220, 225, 240); searchTB.TextSize = 11
searchTB.TextXAlignment = Enum.TextXAlignment.Left; searchTB.ClearTextOnFocus = false
searchTB.ZIndex = 6; searchTB.Parent = searchF

searchTB.Focused:Connect(function()
    Tw(searchStroke, {Color = T.accent}, 0.16)
end)
searchTB.FocusLost:Connect(function()
    if searchTB.Text == "" then
        Tw(searchStroke, {Color = T.border}, 0.16)
    end
end)

searchTB:GetPropertyChangedSignal("Text"):Connect(function()
    if UpdateSearch then UpdateSearch() end
end)

if ConfigSystem and ConfigSystem.Localization then
    local function updateSearchTB(lang)
        if lang == "RU" then
            searchTB.PlaceholderText = "Поиск..."
            searchTB.Font = Enum.Font.GothamMedium
        else
            searchTB.PlaceholderText = "Search..."
            searchTB.Font = Enum.Font.Arcade
        end
        if UpdateSearch and searchTB.Text ~= "" then
            UpdateSearch()
        end
    end
    table.insert(ConfigSystem.Localization.listeners, updateSearchTB)
    updateSearchTB(ConfigSystem.Localization.currentLang)
end

-- ══════════════════════════════════════════════
--  BODY FRAME
-- ══════════════════════════════════════════════
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -TOP_H); body.Position = UDim2.new(0, 0, 0, TOP_H)
body.BackgroundTransparency = 1; body.ClipsDescendants = true; body.Parent = win

-- ══════════════════════════════════════════════
--  SIDEBAR (width = 132)
-- ══════════════════════════════════════════════
local SIDE_W = 132
local isGlassSide = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, SIDE_W, 1, 0); sidebar.BackgroundColor3 = T.sidebar
sidebar.BackgroundTransparency = isGlassSide and 1 or 0
sidebar.BorderSizePixel = 0; sidebar.Parent = body
Crn(sidebar, 8)

local sideCover = Instance.new("Frame")
sideCover.Size = UDim2.new(1, 0, 0, 10); sideCover.BackgroundColor3 = T.sidebar
sideCover.BackgroundTransparency = isGlassSide and 1 or 0
sideCover.BorderSizePixel = 0; sideCover.ZIndex = 2; sideCover.Parent = sidebar

local sideDiv = Div(sidebar, true, T.border)
sideDiv.Position = UDim2.new(1, 0, 0, 0); sideDiv.ZIndex = 3

if ConfigSystem then
    ConfigSystem.sidebar = sidebar
    ConfigSystem.sideCover = sideCover
    ConfigSystem.sideDiv = sideDiv
end

local sideScroll = Instance.new("Frame")
sideScroll.Size = UDim2.new(1, -1, 1, 0); sideScroll.BackgroundTransparency = 1
sideScroll.ClipsDescendants = false; sideScroll.ZIndex = 2; sideScroll.Parent = sidebar

local sideLL = Instance.new("UIListLayout")
sideLL.Padding = UDim.new(0, 1); sideLL.SortOrder = Enum.SortOrder.LayoutOrder; sideLL.Parent = sideScroll
local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 8); sidePad.PaddingLeft = UDim.new(0, 7)
sidePad.PaddingRight = UDim.new(0, 7); sidePad.Parent = sideScroll

if ConfigSystem then
    ConfigSystem.glassCards = ConfigSystem.glassCards or {}
    ConfigSystem.glassPills = ConfigSystem.glassPills or {}
    ConfigSystem.glassButtons = ConfigSystem.glassButtons or {}
    ConfigSystem.themeRefreshers = ConfigSystem.themeRefreshers or {}

    ConfigSystem.RegisterGlassCard = function(card, stroke, defBg)
        local curTh = nil
        if ConfigSystem.themePresets then
            for _, th in ipairs(ConfigSystem.themePresets) do
                if th.name == ConfigSystem.savedMenuTheme then curTh = th; break end
            end
        end
        local isGlass = curTh and (curTh.name == "Glass")
        card.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or (defBg or Color3.fromRGB(18, 18, 25))
        card.BackgroundTransparency = isGlass and 0.75 or 0
        if stroke then
            stroke.Color = isGlass and (curTh and curTh.borderColor or Color3.fromRGB(36, 36, 42)) or T.border
            stroke.Transparency = isGlass and 0.45 or 0
        end
        table.insert(ConfigSystem.glassCards, {card = card, stroke = stroke, defBg = defBg or Color3.fromRGB(18, 18, 25)})
    end

    ConfigSystem.RegisterGlassPill = function(pill, stroke)
        local curTh = nil
        if ConfigSystem.themePresets then
            for _, th in ipairs(ConfigSystem.themePresets) do
                if th.name == ConfigSystem.savedMenuTheme then curTh = th; break end
            end
        end
        local isGlass = curTh and (curTh.name == "Glass")
        pill.BackgroundColor3 = T.dotsBg
        pill.BackgroundTransparency = isGlass and 0.65 or 0
        if stroke then
            stroke.Color = isGlass and (curTh and curTh.borderColor or Color3.fromRGB(36, 36, 42)) or T.border
            stroke.Transparency = isGlass and 0.45 or 0
        end
        table.insert(ConfigSystem.glassPills, {pill = pill, stroke = stroke})
    end

    ConfigSystem.RegisterGlassButton = function(btn, stroke, defBg)
        local curTh = nil
        if ConfigSystem.themePresets then
            for _, th in ipairs(ConfigSystem.themePresets) do
                if th.name == ConfigSystem.savedMenuTheme then curTh = th; break end
            end
        end
        local isGlass = curTh and (curTh.name == "Glass")
        btn.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or (defBg or Color3.fromRGB(24, 28, 38))
        btn.BackgroundTransparency = isGlass and 0.70 or 0
        if stroke then
            stroke.Color = isGlass and (curTh and curTh.borderColor or Color3.fromRGB(36, 36, 42)) or T.border
            stroke.Transparency = isGlass and 0.45 or 0
        end
        table.insert(ConfigSystem.glassButtons, {btn = btn, stroke = stroke, defBg = defBg or Color3.fromRGB(24, 28, 38)})
    end

    ConfigSystem.UpdateThemeVisuals = function()
        local curTh = nil
        if ConfigSystem and ConfigSystem.themePresets then
            for _, th in ipairs(ConfigSystem.themePresets) do
                if th.name == ConfigSystem.savedMenuTheme then curTh = th; break end
            end
        end
        local isGlass = curTh and (curTh.name == "Glass")
        local tr = (curTh and curTh.trans) or 0
        local cardTr = isGlass and (curTh.cardTrans or 0.72) or 0
        local subTr = isGlass and (curTh.subTrans or 0.55) or 0
        local bCol = isGlass and (curTh.borderColor or Color3.fromRGB(36, 36, 46)) or T.border
        local bTr = isGlass and (curTh.borderTrans or 0.5) or 0

        if win then
            win.BackgroundColor3 = T.bg
            win.BackgroundTransparency = tr
        end
        if ConfigSystem.winStroke then
            ConfigSystem.winStroke.Color = bCol
            ConfigSystem.winStroke.Transparency = bTr
        end

        if topbar then
            topbar.BackgroundColor3 = T.topbar
            topbar.BackgroundTransparency = isGlass and 1 or subTr
        end
        if topCover then
            topCover.BackgroundColor3 = T.topbar
            topCover.BackgroundTransparency = isGlass and 1 or 0
        end
        if topDivLine then
            topDivLine.BackgroundColor3 = bCol
            topDivLine.BackgroundTransparency = isGlass and 0.6 or 0
        end

        if searchF then
            searchF.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or T.inputBg
            searchF.BackgroundTransparency = isGlass and 0.65 or 0
        end
        if searchStroke then
            searchStroke.Color = bCol
            searchStroke.Transparency = isGlass and 0.5 or 0
        end
        if searchTB then
            searchTB.TextColor3 = T.text
            searchTB.PlaceholderColor3 = T.textMuted
        end

        if sidebar then
            sidebar.BackgroundColor3 = T.sidebar
            sidebar.BackgroundTransparency = isGlass and 1 or subTr
        end
        if sideCover then
            sideCover.BackgroundColor3 = T.sidebar
            sideCover.BackgroundTransparency = isGlass and 1 or 0
        end
        if sideDiv then
            sideDiv.BackgroundColor3 = bCol
            sideDiv.BackgroundTransparency = isGlass and 0.6 or 0
        end

        if tabPages and type(tabPages) == "table" then
            for _, pg in pairs(tabPages) do
                if pg.leftSF then
                    pg.leftSF.BackgroundColor3 = T.cardBg
                    pg.leftSF.BackgroundTransparency = cardTr
                end
                if pg.rightSF then
                    pg.rightSF.BackgroundColor3 = T.cardBg
                    pg.rightSF.BackgroundTransparency = cardTr
                end
                if pg.leftStroke then
                    pg.leftStroke.Color = bCol
                    pg.leftStroke.Transparency = isGlass and 0.45 or 0
                end
                if pg.rightStroke then
                    pg.rightStroke.Color = bCol
                    pg.rightStroke.Transparency = isGlass and 0.45 or 0
                end
            end
        end

        if ConfigSystem.searchLeftSF then
            ConfigSystem.searchLeftSF.BackgroundColor3 = T.cardBg
            ConfigSystem.searchLeftSF.BackgroundTransparency = cardTr
        end
        if ConfigSystem.searchRightSF then
            ConfigSystem.searchRightSF.BackgroundColor3 = T.cardBg
            ConfigSystem.searchRightSF.BackgroundTransparency = cardTr
        end
        if ConfigSystem.searchLeftStroke then
            ConfigSystem.searchLeftStroke.Color = bCol
            ConfigSystem.searchLeftStroke.Transparency = isGlass and 0.45 or 0
        end
        if ConfigSystem.searchRightStroke then
            ConfigSystem.searchRightStroke.Color = bCol
            ConfigSystem.searchRightStroke.Transparency = isGlass and 0.45 or 0
        end

        if ConfigSystem.glassCards then
            for _, item in ipairs(ConfigSystem.glassCards) do
                if item.card and item.card.Parent then
                    item.card.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or T.cardBg
                    item.card.BackgroundTransparency = isGlass and 0.75 or 0
                    if item.stroke then
                        item.stroke.Color = bCol
                        item.stroke.Transparency = isGlass and 0.45 or 0
                    end
                end
            end
        end

        if ConfigSystem.glassPills then
            for _, item in ipairs(ConfigSystem.glassPills) do
                if item.pill and item.pill.Parent then
                    item.pill.BackgroundColor3 = T.dotsBg
                    item.pill.BackgroundTransparency = isGlass and 0.65 or 0
                    if item.stroke then
                        item.stroke.Color = bCol
                        item.stroke.Transparency = isGlass and 0.45 or 0
                    end
                end
            end
        end

        if ConfigSystem.glassButtons then
            for _, item in ipairs(ConfigSystem.glassButtons) do
                if item.btn and item.btn.Parent then
                    item.btn.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or (isLight and Color3.fromRGB(230, 232, 242) or item.defBg)
                    item.btn.BackgroundTransparency = isGlass and 0.70 or 0
                    if item.stroke then
                        item.stroke.Color = bCol
                        item.stroke.Transparency = isGlass and 0.45 or 0
                    end
                end
            end
        end

        if ConfigSystem.inBoxFrame then
            ConfigSystem.inBoxFrame.BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or T.inputBg
            ConfigSystem.inBoxFrame.BackgroundTransparency = isGlass and 0.65 or 0
            if ConfigSystem.inStroke then
                ConfigSystem.inStroke.Color = bCol
                ConfigSystem.inStroke.Transparency = isGlass and 0.45 or 0
            end
        end

        if tabBtns then
            for tName, tData in pairs(tabBtns) do
                if tData.btn and tData.btn.Parent then
                    tData.btn.BackgroundColor3 = T.tabActive
                    tData.bar.BackgroundColor3 = T.accent
                    if tName == currentTab then
                        tData.btn.BackgroundTransparency = isGlass and 0.55 or 0
                        tData.lbl.TextColor3 = T.text
                        tData.bar.BackgroundTransparency = 0
                    else
                        tData.btn.BackgroundTransparency = 1
                        tData.lbl.TextColor3 = T.textMuted
                        tData.bar.BackgroundTransparency = 1
                    end
                end
            end
        end

        if allRegisteredTogglesList then
            for _, t in ipairs(allRegisteredTogglesList) do
                if t.nL and t.nL.Parent then
                    t.nL.TextColor3 = (t.isEnabled and t.isEnabled()) and T.text or T.textDim
                end
                if t.dotsBtn and t.dotsBtn.Parent then
                    local isBound = (featureBinds[t.name] ~= nil and (featureBinds[t.name].key ~= nil or featureBinds[t.name].mode == "Always"))
                    t.dotsBtn.TextColor3 = isBound and T.accent or T.textMuted
                end
            end
        end

        if ConfigSystem.themeSliders then
            for _, s in ipairs(ConfigSystem.themeSliders) do
                if s.nameL and s.nameL.Parent then s.nameL.TextColor3 = T.textDim end
                if s.valTB and s.valTB.Parent then s.valTB.TextColor3 = T.text end
                if s.track and s.track.Parent then s.track.BackgroundColor3 = isLight and Color3.fromRGB(220, 222, 230) or Color3.fromRGB(36, 36, 46) end
            end
        end

        if ConfigSystem.themeSections then
            for _, sec in ipairs(ConfigSystem.themeSections) do
                if sec and sec.Parent then
                    sec.TextColor3 = (sec.TextSize <= 10) and T.textMuted or T.secHeader
                end
            end
        end

        if kbWin then
            local isGlassKb = (curTh and curTh.name == "Glass")
            kbWin.BackgroundColor3 = T.bg
            kbWin.BackgroundTransparency = isGlassKb and 0.32 or (T.trans or 0)
            local kbStroke = kbWin:FindFirstChildOfClass("UIStroke")
            if kbStroke then
                kbStroke.Color = bCol
                kbStroke.Transparency = isGlassKb and 0.5 or 0
            end
            local kbHeader = kbWin:FindFirstChild("KbHeader") or kbWin:FindFirstChild("Frame")
            if kbHeader then
                kbHeader.BackgroundColor3 = isGlassKb and Color3.fromRGB(12, 12, 15) or T.topbar
                kbHeader.BackgroundTransparency = isGlassKb and 1 or 0
                local kbCover = kbHeader:FindFirstChild("KbHeaderCover")
                if kbCover then
                    kbCover.BackgroundColor3 = isGlassKb and Color3.fromRGB(12, 12, 15) or T.topbar
                    kbCover.BackgroundTransparency = isGlassKb and 1 or 0
                end
                local kbD = kbHeader:FindFirstChild("KbDiv")
                if kbD then
                    kbD.BackgroundColor3 = bCol
                    kbD.BackgroundTransparency = isGlassKb and 0.6 or 0
                end
            end
            local kbTitle = kbWin:FindFirstChild("TextLabel", true)
            if kbTitle then
                kbTitle.TextColor3 = T.text
            end
            if UpdateKeybindsHud then UpdateKeybindsHud() end
        end

        if AdminStaff and AdminStaff.win then
            local isGlassAdmin = (curTh and curTh.name == "Glass")
            AdminStaff.win.BackgroundColor3 = T.bg
            AdminStaff.win.BackgroundTransparency = isGlassAdmin and 0.32 or (T.trans or 0)
            local adminStroke = AdminStaff.win:FindFirstChildOfClass("UIStroke")
            if adminStroke then
                adminStroke.Color = bCol
                adminStroke.Transparency = isGlassAdmin and 0.5 or 0
            end
            local aHeader = AdminStaff.win:FindFirstChild("AHeader") or AdminStaff.win:FindFirstChild("Frame")
            if aHeader then
                aHeader.BackgroundColor3 = isGlassAdmin and Color3.fromRGB(12, 12, 15) or T.topbar
                aHeader.BackgroundTransparency = isGlassAdmin and 1 or 0
                local aCover = aHeader:FindFirstChild("AHeaderCover")
                if aCover then
                    aCover.BackgroundColor3 = isGlassAdmin and Color3.fromRGB(12, 12, 15) or T.topbar
                    aCover.BackgroundTransparency = isGlassAdmin and 1 or 0
                end
                local aD = aHeader:FindFirstChild("ADiv")
                if aD then
                    aD.BackgroundColor3 = bCol
                    aD.BackgroundTransparency = isGlassAdmin and 0.6 or 0
                end
            end
            if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end
        end

        if Watermark and Watermark.win then
            local isGlassWm = (curTh and curTh.name == "Glass")
            Watermark.win.BackgroundColor3 = isGlassWm and Color3.fromRGB(15, 15, 18) or (isLight and Color3.fromRGB(240, 242, 248) or Color3.fromRGB(13, 13, 15))
            Watermark.win.BackgroundTransparency = isGlassWm and 0.40 or 0
        end

        if ConfigSystem.themeRefreshers then
            for _, rf in ipairs(ConfigSystem.themeRefreshers) do pcall(rf) end
        end
    end
end

local function SideSection(text, order)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 20); f.BackgroundTransparency = 1
    f.LayoutOrder = order; f.ZIndex = 2; f.Parent = sideScroll
    local l = Lbl(f, text, 8, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    l.Size = UDim2.new(1, 0, 1, 0)
end

SwitchTab = function(name)
    if searchTB.Text ~= "" then
        searchTB.Text = ""
    end
    if currentTab == name then return end
    local old = tabBtns[currentTab]
    if old then
        Tw(old.btn, {BackgroundTransparency=1}, .12)
        Tw(old.bar, {BackgroundTransparency=1}, .12)
        Tw(old.lbl, {TextColor3=T.textMuted}, .12)
    end
    if tabPages[currentTab] then
        tabPages[currentTab].leftSF.Visible  = false
        tabPages[currentTab].rightSF.Visible = false
    end
    currentTab = name
    local tb = tabBtns[name]
    if tb then
        local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
        tb.btn.BackgroundColor3 = T.tabActive
        tb.bar.BackgroundColor3 = T.accent
        Tw(tb.btn, {BackgroundTransparency = isGlass and 0.55 or 0}, .12)
        Tw(tb.bar, {BackgroundTransparency = 0}, .12)
        Tw(tb.lbl, {TextColor3 = T.text}, .12)
    end
    if tabPages[name] then
        local pg = tabPages[name]
        pg.leftSF.Visible  = true
        pg.rightSF.Visible = not pg.isSingle
        pg.leftSF.CanvasPosition  = Vector2.zero
        pg.rightSF.CanvasPosition = Vector2.zero
    end
end

local function SideTab(name, order)
    local isActive = (name == currentTab)
    local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
    local btn = Instance.new("TextButton")
    btn.Name = name; btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = T.tabActive; btn.BackgroundTransparency = isActive and (isGlass and 0.55 or 0) or 1
    btn.BorderSizePixel = 0; btn.Text = ""; btn.AutoButtonColor = false
    btn.LayoutOrder = order; btn.ZIndex = 2; btn.Parent = sideScroll
    Crn(btn, 5)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 2, .6, 0); bar.Position = UDim2.new(0, 0, .2, 0)
    bar.BackgroundColor3 = T.accent; bar.BackgroundTransparency = isActive and 0 or 1
    bar.BorderSizePixel = 0; bar.ZIndex = 3; bar.Parent = btn
    Crn(bar, 1); TrackAccentBar(bar)

    local lbl = Lbl(btn, name, 11, isActive and T.text or T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 3)
    lbl.Size = UDim2.new(1, -14, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    if ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.RegisterLabel(lbl, name, true)
    end

    tabBtns[name] = {btn=btn, bar=bar, lbl=lbl}

    btn.MouseButton1Click:Connect(function()
        if searchTB.Text ~= "" then
            searchTB.Text = ""
        end
        SwitchTab(name)
    end)
    btn.MouseEnter:Connect(function()
        if currentTab ~= name then
            local isGlassHover = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            Tw(btn, {BackgroundTransparency = isGlassHover and 0.80 or .88}, .1)
            Tw(lbl,  {TextColor3 = T.textDim}, .1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= name then
            Tw(btn, {BackgroundTransparency = 1}, .1)
            Tw(lbl,  {TextColor3 = T.textMuted}, .1)
        end
    end)
end

-- ══════════════════════════════════════════════
--  CONTENT AREA & DUAL COLUMNS
-- ══════════════════════════════════════════════
local contentF = Instance.new("Frame")
contentF.Size = UDim2.new(1, -SIDE_W-1, 1, 0); contentF.Position = UDim2.new(0, SIDE_W+1, 0, 0)
contentF.BackgroundTransparency = 1; contentF.ClipsDescendants = true; contentF.Parent = body

-- ── SEARCH RESULTS OVERLAY VIEW (CanvasGroup glide & fade) ──
local searchView = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
searchView.Name = "NOVA_SearchView"
searchView.Size = UDim2.new(1, 0, 1, 0)
searchView.Position = UDim2.new(0, 0, 0, 0)
searchView.BackgroundTransparency = 1
searchView.BorderSizePixel = 0
searchView.Visible = false
searchView.ClipsDescendants = true
searchView.ZIndex = 15
searchView.Parent = contentF
if hasCanvasGroup then searchView.GroupTransparency = 1 end

ConfigSystem.AttachScrollbarAutoHide = function(sf)
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
                while (tick() - lastScroll) < 2 do
                    task.wait(0.2)
                end
                Tw(sf, {ScrollBarImageTransparency = 1}, 0.35)
                isFading = false
            end)
        end
    end
    sf:GetPropertyChangedSignal("CanvasPosition"):Connect(showBar)
    sf.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            showBar()
        end
    end)
end

local searchLeftSF = Instance.new("ScrollingFrame")
searchLeftSF.Size = UDim2.new(0.5, -11, 1, -12); searchLeftSF.Position = UDim2.new(0, 7, 0, 6)
searchLeftSF.BackgroundColor3 = Color3.fromRGB(15, 15, 21); searchLeftSF.BackgroundTransparency = 0
searchLeftSF.BorderSizePixel = 0; searchLeftSF.ScrollBarThickness = 3; searchLeftSF.ScrollBarImageColor3 = T.accent
searchLeftSF.CanvasSize = UDim2.new(0, 0, 0, 0); searchLeftSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
searchLeftSF.VerticalScrollBarInset = Enum.ScrollBarInset.None
searchLeftSF.ClipsDescendants = true; searchLeftSF.ZIndex = 16; searchLeftSF.Parent = searchView
Crn(searchLeftSF, 7)
local searchLeftStroke = Strk(searchLeftSF, T.border, 1, 0)
TrackAccent(searchLeftSF, "ScrollBarImageColor3")
ConfigSystem.AttachScrollbarAutoHide(searchLeftSF)

do
    local sLPad = Instance.new("UIPadding")
    sLPad.PaddingTop = UDim.new(0, 8); sLPad.PaddingBottom = UDim.new(0, 16)
    sLPad.PaddingLeft = UDim.new(0, 8); sLPad.PaddingRight = UDim.new(0, 8)
    sLPad.Parent = searchLeftSF
    local sLList = Instance.new("UIListLayout")
    sLList.Padding = UDim.new(0, 3); sLList.SortOrder = Enum.SortOrder.LayoutOrder; sLList.Parent = searchLeftSF
    local spL = Instance.new("Frame")
    spL.Size = UDim2.new(1, 0, 0, 20); spL.BackgroundTransparency = 1; spL.LayoutOrder = 999999; spL.Parent = searchLeftSF
end

local searchRightSF = Instance.new("ScrollingFrame")
searchRightSF.Size = UDim2.new(0.5, -11, 1, -12); searchRightSF.Position = UDim2.new(0.5, 4, 0, 6)
searchRightSF.BackgroundColor3 = Color3.fromRGB(15, 15, 21); searchRightSF.BackgroundTransparency = 0
searchRightSF.BorderSizePixel = 0; searchRightSF.ScrollBarThickness = 3; searchRightSF.ScrollBarImageColor3 = T.accent
searchRightSF.CanvasSize = UDim2.new(0, 0, 0, 0); searchRightSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
searchRightSF.VerticalScrollBarInset = Enum.ScrollBarInset.None
searchRightSF.ClipsDescendants = true; searchRightSF.ZIndex = 16; searchRightSF.Parent = searchView
Crn(searchRightSF, 7)
local searchRightStroke = Strk(searchRightSF, T.border, 1, 0)
TrackAccent(searchRightSF, "ScrollBarImageColor3")
ConfigSystem.AttachScrollbarAutoHide(searchRightSF)

if ConfigSystem then
    ConfigSystem.searchLeftSF = searchLeftSF
    ConfigSystem.searchRightSF = searchRightSF
    ConfigSystem.searchLeftStroke = searchLeftStroke
    ConfigSystem.searchRightStroke = searchRightStroke
end

do
    local sRPad = Instance.new("UIPadding")
    sRPad.PaddingTop = UDim.new(0, 8); sRPad.PaddingBottom = UDim.new(0, 16)
    sRPad.PaddingLeft = UDim.new(0, 8); sRPad.PaddingRight = UDim.new(0, 8)
    sRPad.Parent = searchRightSF
    local sRList = Instance.new("UIListLayout")
    sRList.Padding = UDim.new(0, 3); sRList.SortOrder = Enum.SortOrder.LayoutOrder; sRList.Parent = searchRightSF
    local spR = Instance.new("Frame")
    spR.Size = UDim2.new(1, 0, 0, 20); spR.BackgroundTransparency = 1; spR.LayoutOrder = 999999; spR.Parent = searchRightSF
end

local searchEmptyL = Lbl(searchView, "No functions found", 12, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Center, 16)
searchEmptyL.Size = UDim2.new(1, 0, 0, 40)
searchEmptyL.Position = UDim2.new(0, 0, 0.4, 0)
searchEmptyL.Visible = false

local function MakePage(name)
    local isActive = (name == currentTab)
    local isSingle = (name == "Configs" or name == "Presets")

    -- Left Column (Rounded Groupbox with Internal Scroll)
    local leftSF = Instance.new("ScrollingFrame")
    leftSF.Size = isSingle and UDim2.new(1, -14, 1, -12) or UDim2.new(0.5, -11, 1, -12)
    leftSF.Position = UDim2.new(0, 7, 0, 6)
    leftSF.BackgroundColor3 = T.cardBg
    leftSF.BackgroundTransparency = 0
    leftSF.BorderSizePixel = 0
    leftSF.ScrollBarThickness = 3
    leftSF.ScrollBarImageColor3 = T.accent
    leftSF.CanvasSize = UDim2.new(0, 0, 0, 0)
    leftSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
    leftSF.VerticalScrollBarInset = Enum.ScrollBarInset.None
    leftSF.Visible = isActive
    leftSF.ClipsDescendants = true
    leftSF.Parent = contentF
    Crn(leftSF, 8)
    local leftStroke = Strk(leftSF, T.border, 1, 0)
    TrackAccent(leftSF, "ScrollBarImageColor3")
    if ConfigSystem and ConfigSystem.AttachScrollbarAutoHide then
        ConfigSystem.AttachScrollbarAutoHide(leftSF)
    end

    local lPad = Instance.new("UIPadding")
    lPad.PaddingTop = UDim.new(0, 8)
    lPad.PaddingBottom = UDim.new(0, 16)
    lPad.PaddingLeft = UDim.new(0, 8)
    lPad.PaddingRight = UDim.new(0, 8)
    lPad.Parent = leftSF

    local lList = Instance.new("UIListLayout")
    lList.Padding = UDim.new(0, 3)
    lList.SortOrder = Enum.SortOrder.LayoutOrder
    lList.Parent = leftSF

    local lSpacer = Instance.new("Frame")
    lSpacer.Name = "BottomSpacer"
    lSpacer.Size = UDim2.new(1, 0, 0, 20)
    lSpacer.BackgroundTransparency = 1
    lSpacer.BorderSizePixel = 0
    lSpacer.LayoutOrder = 999999
    lSpacer.Parent = leftSF

    -- Right Column (Rounded Groupbox with Internal Scroll)
    local rightSF = Instance.new("ScrollingFrame")
    rightSF.Size = UDim2.new(0.5, -11, 1, -12)
    rightSF.Position = UDim2.new(0.5, 4, 0, 6)
    rightSF.BackgroundColor3 = T.cardBg
    rightSF.BackgroundTransparency = 0
    rightSF.BorderSizePixel = 0
    rightSF.ScrollBarThickness = 3
    rightSF.ScrollBarImageColor3 = T.accent
    rightSF.CanvasSize = UDim2.new(0, 0, 0, 0)
    rightSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rightSF.VerticalScrollBarInset = Enum.ScrollBarInset.None
    rightSF.Visible = (isActive and not isSingle)
    rightSF.ClipsDescendants = true
    rightSF.Parent = contentF
    Crn(rightSF, 8)
    local rightStroke = Strk(rightSF, T.border, 1, 0)
    TrackAccent(rightSF, "ScrollBarImageColor3")
    if ConfigSystem and ConfigSystem.AttachScrollbarAutoHide then
        ConfigSystem.AttachScrollbarAutoHide(rightSF)
    end

    local rPad = Instance.new("UIPadding")
    rPad.PaddingTop = UDim.new(0, 8)
    rPad.PaddingBottom = UDim.new(0, 16)
    rPad.PaddingLeft = UDim.new(0, 8)
    rPad.PaddingRight = UDim.new(0, 8)
    rPad.Parent = rightSF

    local rList = Instance.new("UIListLayout")
    rList.Padding = UDim.new(0, 3)
    rList.SortOrder = Enum.SortOrder.LayoutOrder
    rList.Parent = rightSF

    local rSpacer = Instance.new("Frame")
    rSpacer.Name = "BottomSpacer"
    rSpacer.Size = UDim2.new(1, 0, 0, 20)
    rSpacer.BackgroundTransparency = 1
    rSpacer.BorderSizePixel = 0
    rSpacer.LayoutOrder = 999999
    rSpacer.Parent = rightSF

    tabPages[name] = {leftSF=leftSF, rightSF=rightSF, leftStroke=leftStroke, rightStroke=rightStroke, lOrder=0, rOrder=0, isSingle=isSingle}
end

-- ── SECTION HEADER (clean title, matching screenshot) ──
local function Section(col, title, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order
    f.Parent = col

    local tL = Lbl(f, title, 13, T.secHeader, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 2)
    tL.Position = UDim2.new(0, 4, 0, 2)
    tL.Size = UDim2.new(1, -8, 1, -2)
    if ConfigSystem then
        if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
        table.insert(ConfigSystem.themeSections, tL)
        if ConfigSystem.Localization then
            ConfigSystem.Localization.RegisterLabel(tL, title, true)
        end
    end
    return f, tL
end

-- ── TOGGLE ITEM (Modern squircle design matching screenshot) ──
local function Toggle(col, name, order, defOn, callback, noBind)
    if noBind == nil and ConfigSystem and ConfigSystem.noBindToggles then
        noBind = (ConfigSystem.noBindToggles[name] == true)
    end
    local en = defOn or false
    local item = Instance.new("Frame"); item.Size = UDim2.new(1, 0, 0, 26); item.BackgroundTransparency = 1
    item.LayoutOrder = order; item.Parent = col

    local hover = Instance.new("Frame"); hover.Size = UDim2.new(1, 0, 1, 0); hover.BackgroundColor3 = T.itemHover
    hover.BackgroundTransparency = 1; hover.BorderSizePixel = 0; hover.ZIndex = 1; hover.Parent = item
    Crn(hover, 5)

    -- Left squircle checkbox
    local tBg = Instance.new("Frame")
    tBg.Size = UDim2.new(0, 18, 0, 18)
    tBg.Position = UDim2.new(0, 4, 0.5, -9)
    tBg.BackgroundColor3 = en and T.accent or T.accentOff
    tBg.BorderSizePixel = 0
    tBg.ZIndex = 3
    tBg.Parent = item
    Crn(tBg, 5)
    Strk(tBg, Color3.fromRGB(44, 44, 56), 1, 0)

    -- Label next to checkbox
    local textRightOffset = noBind and -8 or -36
    local nL = Lbl(item, name, 12, en and T.text or T.textDim, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 2)
    nL.Size = UDim2.new(1, textRightOffset, 1, 0)
    nL.Position = UDim2.new(0, 28, 0, 0)
    if ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.RegisterLabel(nL, name, false)
    end

    local dotsF, dotsBtn
    if not noBind then
        -- Keybind button positioned on the right
        dotsF = Instance.new("Frame")
        dotsF.Size = UDim2.new(0, 26, 0, 16)
        dotsF.Position = UDim2.new(1, -30, 0.5, -8)
        dotsF.BackgroundColor3 = T.dotsBg
        local isGlassInit = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
        dotsF.BackgroundTransparency = isGlassInit and 0.65 or 0
        dotsF.BorderSizePixel = 0
        dotsF.ZIndex = 3
        dotsF.Parent = item
        Crn(dotsF, 4)
        local dStrk = Strk(dotsF, T.border, 1, 0)
        if ConfigSystem and ConfigSystem.RegisterGlassPill then
            ConfigSystem.RegisterGlassPill(dotsF, dStrk)
        end

        dotsBtn = Instance.new("TextButton")
        dotsBtn.Size = UDim2.new(1, 0, 1, 0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.BorderSizePixel = 0
        dotsBtn.Font = Enum.Font.GothamMedium
        dotsBtn.TextSize = 9
        dotsBtn.AutoButtonColor = false
        dotsBtn.ZIndex = 8
        dotsBtn.Parent = dotsF

        local initKey = nil
        local initMode = "Toggle"
        if savedBinds and savedBinds[name] then
            local rawB = savedBinds[name]
            initKey = (type(rawB) == "table" and rawB.key) or (type(rawB) == "string" and rawB)
            initMode = (type(rawB) == "table" and rawB.mode) or "Toggle"
        elseif defaultFeatureBinds and defaultFeatureBinds[name] then
            initKey = defaultFeatureBinds[name]
            initMode = "Toggle"
        end
        if initKey then
            dotsBtn.Text = FormatKeyName(initKey)
            dotsBtn.TextColor3 = T.accent
        elseif initMode == "Always" then
            dotsBtn.Text = "ALW"
            dotsBtn.TextColor3 = T.accent
        else
            dotsBtn.Text = "..."
            dotsBtn.TextColor3 = T.textMuted
        end
    end

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, textRightOffset, 1, 0)
    click.Position = UDim2.new(0, 0, 0, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.ZIndex = 5
    click.Parent = item

    local tObj = {}

    local function setToggleState(v, runCb, skipSaveState)
        if v == nil then v = not en end
        en = v
        Tw(tBg,  {BackgroundColor3 = en and T.accent or T.accentOff}, .18)
        Tw(nL,   {TextColor3 = en and T.text or T.textDim}, .15)
        if runCb and callback then callback(en) end
        if UpdateKeybindsHud then UpdateKeybindsHud() end
        if tObj.onSync then tObj.onSync(en) end
        if not skipSaveState and SaveConfig then SaveConfig() end
    end

    click.MouseButton1Click:Connect(function()
        setToggleState(not en, true)
    end)

    if dotsBtn then
        dotsBtn.MouseButton1Click:Connect(function()
            if listeningTarget and listeningTarget.name == name then
                CancelBinding()
            else
                StartBinding(name, dotsBtn, dotsF, tObj)
            end
        end)
        dotsBtn.MouseButton2Click:Connect(function()
            if listeningTarget then return end
            featureBinds[name] = nil
            dotsBtn.Text = "..."
            dotsBtn.TextColor3 = T.textMuted
            local s = dotsF:FindFirstChildOfClass("UIStroke")
            if s then s.Color = T.border end
            if UpdateKeybindsHud then UpdateKeybindsHud() end
            SaveConfig()
        end)
        dotsBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton3 then
                if listeningTarget then return end
                OpenKeybindContextMenu(name, dotsBtn, dotsF, tObj)
            end
        end)

        dotsBtn.MouseEnter:Connect(function()
            local isGlassHover = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            Tw(dotsF, {BackgroundColor3 = Color3.fromRGB(34, 34, 46), BackgroundTransparency = isGlassHover and 0.45 or 0}, 0.12)
            local isBound = (featureBinds[name] ~= nil and (featureBinds[name].key ~= nil or featureBinds[name].mode == "Always"))
            if not (listeningTarget and listeningTarget.name == name) then
                Tw(dotsBtn, {TextColor3 = isBound and Color3.fromRGB(255, 255, 255) or T.textDim}, 0.12)
            end
        end)
        dotsBtn.MouseLeave:Connect(function()
            local isGlassLeave = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            Tw(dotsF, {BackgroundColor3 = T.dotsBg, BackgroundTransparency = isGlassLeave and 0.65 or 0}, 0.12)
            local isBound = (featureBinds[name] ~= nil and (featureBinds[name].key ~= nil or featureBinds[name].mode == "Always"))
            if not (listeningTarget and listeningTarget.name == name) then
                Tw(dotsBtn, {TextColor3 = isBound and T.accent or T.textMuted}, 0.12)
            end
        end)
    end

    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 24, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 6
    textHit.Parent = item

    local function updateTextHit()
        local tbX = nL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nL.Text * 7, 20) end
        local maxW = noBind and 150 or 125
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, maxW), 1, 0)
    end
    updateTextHit()
    nL:GetPropertyChangedSignal("TextBounds"):Connect(updateTextHit)
    nL:GetPropertyChangedSignal("Text"):Connect(updateTextHit)
    task.defer(updateTextHit)

    textHit.MouseButton1Click:Connect(function()
        setToggleState(not en, true)
    end)
    textHit.MouseEnter:Connect(function()
        Tw(hover, {BackgroundTransparency = .88}, .1)
        Tw(nL,    {TextColor3 = en and T.text or (T.text == Color3.fromRGB(28, 30, 40) and Color3.fromRGB(10, 10, 15) or Color3.fromRGB(255, 255, 255))}, .1)
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nL,    {TextColor3 = en and T.text or T.textDim}, .1)
    end)

    click.MouseEnter:Connect(function() Tw(hover, {BackgroundTransparency = .88}, .1) end)
    click.MouseLeave:Connect(function() Tw(hover, {BackgroundTransparency = 1}, .1) end)
    item.MouseLeave:Connect(function()
        Tw(hover, {BackgroundTransparency = 1}, .1)
        Tw(nL,    {TextColor3 = en and T.text or T.textDim}, .1)
        if ConfigSystem and ConfigSystem.HideTooltip then ConfigSystem.HideTooltip() end
    end)

    tObj.name = name
    tObj.item = item
    tObj.nL = nL
    tObj.setEnabled = function(v) setToggleState(v, false) end
    tObj.setToggleState = function(v, runCb, skipSaveState) setToggleState(v, runCb, skipSaveState) end
    tObj.isEnabled = function() return en end
    tObj.tBg = tBg
    tObj.dotsBtn = dotsBtn
    tObj.dotsF = dotsF
    tObj.noBind = noBind

    return tObj
end

local lastSectionByTab = {}
local function AddSection(tabName, side, title)
    if not lastSectionByTab[tabName] then lastSectionByTab[tabName] = {} end
    lastSectionByTab[tabName][side] = title
    local pg = tabPages[tabName]
    local col = side == "left" and pg.leftSF or pg.rightSF
    local key = side == "left" and "lOrder" or "rOrder"
    pg[key] += 1; Section(col, title, pg[key])
end

local function AddToggle(tabName, side, name, defOn, callback, noBind)
    if noBind == nil and ConfigSystem and ConfigSystem.noBindToggles then
        noBind = (ConfigSystem.noBindToggles[name] == true)
    end
    if name == "Eject Bind" then
        defOn = false
    elseif savedToggles and savedToggles[name] ~= nil then
        defOn = (savedToggles[name] == true)
    end
    local pg = tabPages[tabName]
    local col = side == "left" and pg.leftSF or pg.rightSF
    local key = side == "left" and "lOrder" or "rOrder"
    pg[key] += 1
    local t = Toggle(col, name, pg[key], defOn, callback, noBind)
    t.tabName = tabName
    t.side = side
    t.sectionName = (lastSectionByTab[tabName] and lastSectionByTab[tabName][side]) or ""
    table.insert(toggleObjects, t)
    table.insert(allRegisteredTogglesList, t)
    if not noBind then
        if savedBinds and savedBinds[name] then
            local rawB = savedBinds[name]
            local bKey = (type(rawB) == "table" and rawB.key) or (type(rawB) == "string" and rawB)
            local bMode = (type(rawB) == "table" and rawB.mode) or "Toggle"
            featureBinds[name] = {
                key = bKey,
                shortKey = bKey and FormatKeyName(bKey) or "...",
                mode = bMode,
                toggle = t,
                name = name,
            }
            if bMode == "Always" and name ~= "Eject Bind" then
                task.spawn(function()
                    t.setToggleState(true, true)
                end)
            end
        elseif defaultFeatureBinds and defaultFeatureBinds[name] then
            local bKey = defaultFeatureBinds[name]
            local bMode = "Toggle"
            featureBinds[name] = {
                key = bKey,
                shortKey = FormatKeyName(bKey),
                mode = bMode,
                toggle = t,
                name = name,
            }
        end
    end
    if callback then
        task.spawn(function()
            pcall(function() callback(defOn) end)
        end)
    end
    return t
end

-- ══════════════════════════════════════════════
--  BUILD SIDEBAR
-- ══════════════════════════════════════════════
local tabDefs = {
    {section="FEATURES", name="Combat"},
    {section="FEATURES", name="Movement"},
    {section="FEATURES", name="Visuals"},
    {section="FEATURES", name="Player"},
    {section="FEATURES", name="Misc"},
    {section="MANAGER",  name="Configs"},
    {section="MANAGER",  name="Settings"},
}

local lo = 0
local lastSec = nil
for _, def in ipairs(tabDefs) do
    if def.section ~= lastSec then
        lastSec = def.section; lo += 1; SideSection(def.section, lo)
    end
    lo += 1; SideTab(def.name, lo)
    MakePage(def.name)
end
tabPages["Presets"] = tabPages["Configs"]
tabPages["Config"] = tabPages["Settings"]
tabBtns["Presets"] = tabBtns["Configs"]
tabBtns["Config"] = tabBtns["Settings"]

-- ══════════════════════════════════════════════
--  GAMEPLAY MODULES (Fly, Speed, Noclip, InfJump, ESP, Aimbot)
-- ══════════════════════════════════════════════

-- ── FLY ────────────────────────────────────────
local flyEnabled = false
local flyBV = nil
local flyBG = nil
local flyConn = nil

local function StopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local function StartFly()
    StopFly()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "NOVA_FlyBV"
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp

    flyBG = Instance.new("BodyGyro")
    flyBG.Name = "NOVA_FlyBG"
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 10000
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp

    hum.PlatformStand = true

    flyConn = RS.RenderStepped:Connect(function()
        if not flyEnabled or not hrp.Parent then
            StopFly()
            return
        end
        local cam = workspace.CurrentCamera
        if not cam then return end

        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            dir -= Vector3.new(0, 1, 0)
        end

        if dir.Magnitude > 0.05 then
            flyBV.Velocity = dir.Unit * flySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
        flyBG.CFrame = cam.CFrame
    end)
end

SetFly = function(enabled)
    flyEnabled = enabled
    if enabled then StartFly() else StopFly() end
end

-- ── SPEED BOOST ────────────────────────────────
local speedBoostEnabled = false

SetSpeed = function(enabled)
    speedBoostEnabled = enabled
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = enabled and math.max(16, math.min(speedBoostValue, 25)) or 16
        end
    end
end

table.insert(allConn, RS.Heartbeat:Connect(function()
    if speedBoostEnabled and LP.Character then
        local char = LP.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            if hum.MoveDirection.Magnitude > 0.05 then
                local moveDir = hum.MoveDirection.Unit
                local targetVel = speedBoostValue or 45
                local curY = hrp.AssemblyLinearVelocity and hrp.AssemblyLinearVelocity.Y or hrp.Velocity.Y
                local newVel = Vector3.new(moveDir.X * targetVel, curY, moveDir.Z * targetVel)
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = newVel
                end
                hrp.Velocity = newVel
            end
        end
    end
end))

-- ── NOCLIP ─────────────────────────────────────
local noclipEnabled = false
table.insert(allConn, RS.Stepped:Connect(function()
    if noclipEnabled and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end
end))

SetNoclip = function(enabled)
    noclipEnabled = enabled
    if not enabled and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = true end
    end
end

-- ── INFINITE JUMP ──────────────────────────────
local infJumpEnabled = false
table.insert(allConn, UIS.JumpRequest:Connect(function()
    if infJumpEnabled and LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

local antiAfkEnabled = false
pcall(function()
    local vu = game:GetService("VirtualUser")
    table.insert(allConn, LP.Idled:Connect(function()
        if antiAfkEnabled then
            pcall(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end))
end)

SetInfiniteJump = function(enabled)
    infJumpEnabled = enabled
end

-- ── FREECAM ENGINE ────────────────────────────
do
    local function StartFreecam()
        if Freecam.camConn then
            Freecam.camConn:Disconnect()
            Freecam.camConn = nil
        end
        local cam = workspace.CurrentCamera
        if not cam then return end

        Freecam.origCamType = cam.CameraType
        Freecam.origCamSubject = cam.CameraSubject
        cam.CameraType = Enum.CameraType.Scriptable

        local rx, ry, _ = cam.CFrame:ToOrientation()
        Freecam.camRotX = rx
        Freecam.camRotY = ry
        Freecam.camPos = cam.CFrame.Position

        if Freecam.UpdateCharLock then
            Freecam.UpdateCharLock()
        end

        Freecam.camConn = RS.RenderStepped:Connect(function(dt)
            if not Freecam.enabled then return end
            local c = workspace.CurrentCamera
            if not c then return end

            local rmbHeld = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            if rmbHeld and not menuOpen then
                UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
                local delta = UIS:GetMouseDelta()
                Freecam.camRotY = Freecam.camRotY - delta.X * 0.003
                Freecam.camRotX = math.clamp(Freecam.camRotX - delta.Y * 0.003, -math.rad(89), math.rad(89))
            else
                if not menuOpen and UIS.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
                    UIS.MouseBehavior = Enum.MouseBehavior.Default
                end
            end

            if Freecam.lockChar and Freecam.lockedHrpCFrame and LP.Character then
                local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = Freecam.lockedHrpCFrame
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end

            local rotCFrame = CFrame.Angles(0, Freecam.camRotY, 0) * CFrame.Angles(Freecam.camRotX, 0, 0)
            local focusedTB = UIS:GetFocusedTextBox()
            if not focusedTB and not menuOpen then
                local moveDir = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
                if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
                if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
                if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end
                if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir + Vector3.new(0, -1, 0) end

                local speedMult = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1.0
                local spd = (Freecam.speed or 2.77) * 45 * speedMult

                local worldMove = rotCFrame:VectorToWorldSpace(Vector3.new(moveDir.X, 0, moveDir.Z)) + Vector3.new(0, moveDir.Y, 0)
                if worldMove.Magnitude > 0 then
                    Freecam.camPos = Freecam.camPos + worldMove.Unit * (spd * dt)
                end
            end

            c.CFrame = CFrame.new(Freecam.camPos) * rotCFrame
            c.Focus = c.CFrame * CFrame.new(0, 0, -10)
        end)
    end

    local function StopFreecam()
        if Freecam.camConn then
            Freecam.camConn:Disconnect()
            Freecam.camConn = nil
        end
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then
                cam.CameraType = Freecam.origCamType or Enum.CameraType.Custom
                if LP.Character and LP.Character:FindFirstChild("Humanoid") then
                    cam.CameraSubject = LP.Character.Humanoid
                elseif Freecam.origCamSubject then
                    cam.CameraSubject = Freecam.origCamSubject
                end
            end
        end)
        pcall(function()
            if UIS.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
        if Freecam.UpdateCharLock then
            Freecam.UpdateCharLock()
        end
    end

    Freecam.SetEnabled = function(val)
        Freecam.enabled = (val == true)
        if Freecam.enabled then
            StartFreecam()
        else
            if Freecam.tpOnDisable and Freecam.camPos then
                Freecam.TeleportToCam()
            end
            StopFreecam()
        end
    end

    Freecam.TeleportToCam = function(autoDisable)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local targetCF = nil
        if Freecam.camPos then
            local yAngle = Freecam.camRotY or 0
            targetCF = CFrame.new(Freecam.camPos) * CFrame.Angles(0, yAngle, 0)
        elseif workspace.CurrentCamera then
            local pos = workspace.CurrentCamera.CFrame.Position
            local _, yAngle, _ = workspace.CurrentCamera.CFrame:ToOrientation()
            targetCF = CFrame.new(pos) * CFrame.Angles(0, yAngle, 0)
        end

        if hrp and targetCF then
            hrp.CFrame = targetCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if torso then
                torso.AssemblyLinearVelocity = Vector3.zero
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            if Freecam.lockChar then
                Freecam.lockedHrpCFrame = targetCF
            end
            if Notify then
                Notify("Freecam", "Teleported to camera position", 2.0, "success")
            end
        end

        if autoDisable and Freecam.enabled and Freecam.SetEnabled then
            Freecam.SetEnabled(false)
        end
    end

    Freecam.UpdateCharLock = function()
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LP.Character.HumanoidRootPart
            if Freecam.enabled and Freecam.lockChar then
                if not Freecam.lockedHrpCFrame then
                    Freecam.lockedHrpCFrame = hrp.CFrame
                end
                pcall(function() hrp.Anchored = true end)
            else
                Freecam.lockedHrpCFrame = nil
                pcall(function() hrp.Anchored = false end)
            end
        end
    end

    table.insert(allConn, UIS.InputBegan:Connect(function(input, gp)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Freecam.enabled and Freecam.tpOnClick and not menuOpen and not gp then
                local cam = workspace.CurrentCamera
                if cam then
                    local mPos = UIS:GetMouseLocation()
                    local unitRay = cam:ViewportPointToRay(mPos.X, mPos.Y)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local char = LP.Character
                    if char then
                        rayParams.FilterDescendantsInstances = {char}
                    end
                    local rayRes = workspace:Raycast(unitRay.Origin, unitRay.Direction * 3000, rayParams)
                    local targetPos = nil
                    if rayRes then
                        targetPos = rayRes.Position + Vector3.new(0, 3, 0)
                    else
                        targetPos = unitRay.Origin + unitRay.Direction * 150
                    end
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local hrp = char.HumanoidRootPart
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        if Freecam.lockChar then
                            Freecam.lockedHrpCFrame = hrp.CFrame
                        end
                    end
                end
            end
        end
    end))
end

-- Respawn hooks for Fly & Speed
table.insert(allConn, LP.CharacterAdded:Connect(function(char)
    task.wait(0.25)
    if flyEnabled then StartFly() end
    if speedBoostEnabled then
        local hum = char:WaitForChild("Humanoid", 3)
        if hum then hum.WalkSpeed = speedBoostValue end
    end
    if Freecam.enabled and Freecam.UpdateCharLock then
        Freecam.UpdateCharLock()
    end
end))

-- ── PLAYER ESP (Highlights & Nametags) ─────────
local espContainer = {}

local ESP = {
    enabled = false,
    box = true,
    health = true,
    name = true,
    dist = true,
    chams = false,
    chamsMode = savedChamsMode or "VisCheck", -- "VisCheck", "Solid", "Glow", "Outline"
}

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
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local bb = head:FindFirstChild("NOVA_Billboard")
                if bb then bb:Destroy() end
            end
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local b = hrp:FindFirstChild("NOVA_ESP_Box")
                if b then b:Destroy() end
                local d = hrp:FindFirstChild("NOVA_ESP_Dist")
                if d then d:Destroy() end
                local hp = hrp:FindFirstChild("NOVA_ESP_HP")
                if hp then hp:Destroy() end
                local n = hrp:FindFirstChild("NOVA_Billboard")
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

    -- 1. CHAMS (High-Performance CS:GO / Gamesense Highlight)
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
                hl.FillTransparency = 0.18
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
            else -- "VisCheck" (Visible = Bright Green, Behind Wall = Accent)
                hl.FillTransparency = 0.20
                hl.OutlineColor = Color3.fromRGB(0, 0, 0)
                hl.OutlineTransparency = 0

                local function checkVis()
                    if not (hl.Parent and char.Parent and head.Parent) then return end
                    local cam = workspace.CurrentCamera
                    if not cam then return end
                    local origin = cam.CFrame.Position
                    local dir = head.Position - origin
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local ignore = {cam}
                    if LP.Character then table.insert(ignore, LP.Character) end
                    rayParams.FilterDescendantsInstances = ignore
                    rayParams.IgnoreWater = true
                    local hit = workspace:Raycast(origin, dir, rayParams)
                    local isVis = (not hit) or hit.Instance:IsDescendantOf(char)
                    if isVis then
                        hl.FillColor = Color3.fromRGB(0, 255, 120)
                    else
                        hl.FillColor = T.accent
                    end
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

    -- 2. CS:GO 2D BOUNDING BOX (Stabilized & locked to HRP center)
    if ESP.box then
        pcall(function()
            local boxBB = Instance.new("BillboardGui")
            boxBB.Name = "NOVA_ESP_Box"
            boxBB.Size = UDim2.new(4.0, 0, 5.0, 0)
            boxBB.StudsOffset = Vector3.new(0, -0.15, 0)
            boxBB.AlwaysOnTop = true
            boxBB.ResetOnSpawn = false
            boxBB.LightInfluence = 0
            boxBB.MaxDistance = 2500
            boxBB.Adornee = hrp
            boxBB.Parent = hrp
            table.insert(objects, boxBB)

            local boxFrame = Instance.new("Frame")
            boxFrame.Size = UDim2.new(1, 0, 1, 0)
            boxFrame.BackgroundTransparency = 1
            boxFrame.BorderSizePixel = 0
            boxFrame.Parent = boxBB

            local boxStroke = Instance.new("UIStroke")
            boxStroke.Color = T.accent
            boxStroke.Thickness = 1
            boxStroke.Parent = boxFrame
            TrackAccent(boxStroke, "Color")
        end)
    end

    -- 3. CS:GO HEALTH BAR (Sleek 3px bar, guaranteed visible, no overlap)
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

            local hpOutline = Instance.new("UIStroke")
            hpOutline.Color = Color3.fromRGB(0, 0, 0)
            hpOutline.Thickness = 1
            hpOutline.Parent = hpBg

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

            local function GetHealthColor(pct)
                if pct > 0.5 then
                    return Color3.fromRGB(math.floor((1 - pct) * 2 * 255), 235, 45)
                else
                    return Color3.fromRGB(245, math.floor(pct * 2 * 215), 35)
                end
            end

            local function UpdateHP()
                if not (hpBB.Parent and hrp.Parent and hum.Parent) then return end
                local mH = math.max(hum.MaxHealth, 1)
                local cH = math.clamp(hum.Health, 0, mH)
                local pct = math.clamp(cH / mH, 0, 1)
                hpFill.Size = UDim2.new(1, 0, pct, 0)
                local col = GetHealthColor(pct)
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
            local hpConn = hum.HealthChanged:Connect(UpdateHP)
            table.insert(objects, hpConn)

            task.spawn(function()
                while ESP.enabled and ESP.health and hpBB.Parent and hrp.Parent and hum.Parent do
                    UpdateHP()
                    task.wait(0.4)
                end
            end)
        end)
    end

    -- 4. CS:GO NAME (Minecraft font above head, no overlap)
    if ESP.name then
        pcall(function()
            local nameBB = Instance.new("BillboardGui")
            nameBB.Name = "NOVA_Billboard"
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

    -- 5. CS:GO DISTANCE (Minecraft font under feet)
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
        table.insert(objects, hum.Died:Connect(function()
            ClearESPForPlayer(plr)
        end))
    end
    espContainer[plr] = objects
end

-- ESP Streaming & Respawn Watchdog Loop (Guarantees Stable ESP)
task.spawn(function()
    while true do
        task.wait(1.5)
        if ESP.enabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        if not espContainer[p] or (ESP.health and not hrp:FindFirstChild("NOVA_ESP_HP")) then
                            ApplyESPToPlayer(p)
                        end
                    end
                end
            end
        end
    end
end)

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

SetPlayerESP = function(enabled)
    ESP.enabled = enabled
    RefreshAllESP()
end

table.insert(allConn, Players.PlayerAdded:Connect(function(plr)
    if plr ~= LP then
        table.insert(allConn, plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if ESP.enabled then ApplyESPToPlayer(plr) end
        end))
    end
end))
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then
        table.insert(allConn, plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if ESP.enabled then ApplyESPToPlayer(plr) end
        end))
    end
end
table.insert(allConn, Players.PlayerRemoving:Connect(function(plr)
    ClearESPForPlayer(plr)
    local wasCached = AdminStaff.cache[plr.UserId]
    if wasCached and wasCached.isAdmin then
        if AdminStaff.alerts then
            print("[NOVA ADMIN ALERT] Admin Left: " .. (wasCached.displayName or plr.Name))
            pcall(function()
                if Notify then Notify("Staff Left", (wasCached.displayName or plr.Name) .. " left the server", 4, "info") end
            end)
        end
    end
    AdminStaff.cache[plr.UserId] = nil
    AdminStaff.notifiedUserIds[plr.UserId] = nil
    if AdminStaff.enabled and AdminStaff.UpdateHud then
        AdminStaff.UpdateHud()
    end
end))

table.insert(allConn, Players.PlayerAdded:Connect(function(plr)
    if not AdminStaff.enabled then return end
    task.wait(1)
    if AdminStaff.enabled then
        local isAdmin, rank, role = AdminStaff.CheckIfAdmin(plr)
        if isAdmin then
            if AdminStaff.alerts and not AdminStaff.notifiedUserIds[plr.UserId] then
                AdminStaff.notifiedUserIds[plr.UserId] = true
                print("[NOVA ADMIN ALERT] Admin Joined: " .. plr.DisplayName .. " (@" .. plr.Name .. ")")
                pcall(function()
                    if Notify then Notify("Staff Joined", plr.DisplayName .. " (@" .. plr.Name .. ") joined server!", 6, "admin") end
                end)
            end
            if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end
        end
    end
end))

task.spawn(function()
    task.wait(1.5)
    if AdminStaff.enabled and AdminStaff.ScanServer then
        AdminStaff.ScanServer()
    end
end)

-- ── AIM ASSIST (AIMBOT) ────────────────────────
local aimbotConn = nil
local fovSG, fovCircle

local function UpdateFovVisual()
    if fovCircle then
        fovCircle.Visible = (Aim.showFov == true)
        fovCircle.Size = UDim2.new(0, Aim.fov * 2, 0, Aim.fov * 2)
    end
end

Triggerbot.UpdateFovVisual = function()
    if Triggerbot.fovCircle then
        local tol = Triggerbot.tolerance or 14
        Triggerbot.fovCircle.Visible = (Triggerbot.showFov == true)
        Triggerbot.fovCircle.Size = UDim2.new(0, tol * 2, 0, tol * 2)
        if Triggerbot.fovLabel then
            Triggerbot.fovLabel.Text = tostring(tol) .. " px"
        end
    end
end

pcall(function()
    fovSG = Instance.new("ScreenGui")
    fovSG.Name = "NOVA_FOV"
    fovSG.ResetOnSpawn = false
    fovSG.IgnoreGuiInset = true
    fovSG.DisplayOrder = 9998
    fovSG.ZIndexBehavior = Enum.ZIndexBehavior.Global
    fovSG.Parent = safeParent

    fovCircle = Instance.new("Frame")
    fovCircle.Name = "FOVCircle"
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovCircle.Size = UDim2.new(0, Aim.fov * 2, 0, Aim.fov * 2)
    fovCircle.BackgroundTransparency = 1
    fovCircle.Visible = (Aim.showFov == true)
    fovCircle.Parent = fovSG

    local fovCrn = Instance.new("UICorner")
    fovCrn.CornerRadius = UDim.new(1, 0)
    fovCrn.Parent = fovCircle

    local fovStroke = Instance.new("UIStroke")
    fovStroke.Color = T.accent
    fovStroke.Thickness = 1.2
    fovStroke.Transparency = 0.35
    fovStroke.Parent = fovCircle
    TrackAccent(fovStroke, "Color")

    local tfc = Instance.new("Frame")
    tfc.Name = "TriggerFOVCircle"
    tfc.AnchorPoint = Vector2.new(0.5, 0.5)
    tfc.Position = UDim2.new(0.5, 0, 0.5, 0)
    tfc.Size = UDim2.new(0, (Triggerbot.tolerance or 14) * 2, 0, (Triggerbot.tolerance or 14) * 2)
    tfc.BackgroundTransparency = 1
    tfc.Visible = (Triggerbot.showFov == true)
    tfc.Parent = fovSG
    Triggerbot.fovCircle = tfc

    local tfcCrn = Instance.new("UICorner")
    tfcCrn.CornerRadius = UDim.new(1, 0)
    tfcCrn.Parent = tfc

    local tfcStroke = Instance.new("UIStroke")
    tfcStroke.Color = T.accent
    tfcStroke.Thickness = 1.2
    tfcStroke.Transparency = 0.25
    tfcStroke.Parent = tfc
    TrackAccent(tfcStroke, "Color")

    local tfcLbl = Instance.new("TextLabel")
    tfcLbl.Name = "FOVValLabel"
    tfcLbl.AnchorPoint = Vector2.new(0.5, 0)
    tfcLbl.Position = UDim2.new(0.5, 0, 1, 3)
    tfcLbl.Size = UDim2.new(0, 50, 0, 14)
    tfcLbl.BackgroundTransparency = 1
    tfcLbl.Font = Enum.Font.Arcade
    tfcLbl.TextSize = 10
    tfcLbl.TextColor3 = T.accent
    tfcLbl.TextStrokeTransparency = 0.3
    tfcLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    tfcLbl.Text = tostring(Triggerbot.tolerance or 14) .. " px"
    tfcLbl.Parent = tfc
    TrackAccent(tfcLbl, "TextColor3")
    Triggerbot.fovLabel = tfcLbl

    local tgtCircle = Instance.new("Frame")
    tgtCircle.Name = "TriggerTargetCircle"
    tgtCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    tgtCircle.Size = UDim2.new(0, 22, 0, 22)
    tgtCircle.BackgroundTransparency = 1
    tgtCircle.Visible = false
    tgtCircle.Parent = fovSG
    Triggerbot.targetCircle = tgtCircle

    local tcCrn = Instance.new("UICorner")
    tcCrn.CornerRadius = UDim.new(1, 0)
    tcCrn.Parent = tgtCircle

    local tcStroke = Instance.new("UIStroke")
    tcStroke.Color = T.accent
    tcStroke.Thickness = 1.5
    tcStroke.Transparency = 0.2
    tcStroke.Parent = tgtCircle
    Triggerbot.targetStroke = tcStroke
    TrackAccent(tcStroke, "Color")

    local tcDot = Instance.new("Frame")
    tcDot.Name = "CenterDot"
    tcDot.AnchorPoint = Vector2.new(0.5, 0.5)
    tcDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    tcDot.Size = UDim2.new(0, 4, 0, 4)
    tcDot.BackgroundColor3 = T.accent
    tcDot.BorderSizePixel = 0
    tcDot.Parent = tgtCircle
    Triggerbot.targetDot = tcDot
    TrackAccent(tcDot, "BackgroundColor3")

    local tcDotCrn = Instance.new("UICorner")
    tcDotCrn.CornerRadius = UDim.new(1, 0)
    tcDotCrn.Parent = tcDot

    table.insert(allConn, RS.RenderStepped:Connect(function()
        if Triggerbot.fovCircle and Triggerbot.fovCircle.Visible then
            local mPos = UIS:GetMouseLocation()
            Triggerbot.fovCircle.Position = UDim2.new(0, mPos.X, 0, mPos.Y)
        end
    end))
end)

-- ── CUSTOM CROSSHAIR GUI & ANIMATION ───────────
local function InitCustomCrosshair()
    local chSG = Instance.new("ScreenGui")
    chSG.Name = "NOVA_Crosshair"
    chSG.ResetOnSpawn = false
    chSG.IgnoreGuiInset = true
    chSG.DisplayOrder = 9999
    chSG.ZIndexBehavior = Enum.ZIndexBehavior.Global
    chSG.Parent = safeParent
    Crosshair.gui = chSG

    local chFrame = Instance.new("Frame")
    chFrame.Name = "CrosshairHolder"
    chFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    chFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    chFrame.Size = UDim2.new(0, 100, 0, 100)
    chFrame.BackgroundTransparency = 1
    chFrame.Visible = Crosshair.enabled
    chFrame.Parent = chSG
    Crosshair.frame = chFrame

    local function MakeLine(name, anchor)
        local line = Instance.new("Frame")
        line.Name = name
        line.AnchorPoint = anchor
        line.BackgroundColor3 = Crosshair.useAccent and T.accent or Crosshair.color
        line.BorderSizePixel = 0
        line.Parent = chFrame
        Strk(line, Color3.fromRGB(0, 0, 0), 1, 0)
        return line
    end

    local lTop = MakeLine("Top", Vector2.new(0.5, 1))
    local lBottom = MakeLine("Bottom", Vector2.new(0.5, 0))
    local lLeft = MakeLine("Left", Vector2.new(1, 0.5))
    local lRight = MakeLine("Right", Vector2.new(0, 0.5))

    local cDot = Instance.new("Frame")
    cDot.Name = "CenterDot"
    cDot.AnchorPoint = Vector2.new(0.5, 0.5)
    cDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    cDot.BackgroundColor3 = Crosshair.useAccent and T.accent or Crosshair.color
    cDot.BorderSizePixel = 0
    cDot.Visible = Crosshair.dot
    cDot.Parent = chFrame
    Strk(cDot, Color3.fromRGB(0, 0, 0), 1, 0)

    Crosshair.UpdateVisuals = function()
        if not chFrame or not chFrame.Parent then return end
        chFrame.Visible = Crosshair.enabled
        local sz = Crosshair.size or 10
        local gp = Crosshair.gap or 4
        local th = Crosshair.thickness or 2
        local col = Crosshair.useAccent and T.accent or Crosshair.color

        lTop.BackgroundColor3 = col
        lTop.Size = UDim2.new(0, th, 0, sz)
        lTop.Position = UDim2.new(0.5, 0, 0.5, -gp)

        lBottom.BackgroundColor3 = col
        lBottom.Size = UDim2.new(0, th, 0, sz)
        lBottom.Position = UDim2.new(0.5, 0, 0.5, gp)

        lLeft.BackgroundColor3 = col
        lLeft.Size = UDim2.new(0, sz, 0, th)
        lLeft.Position = UDim2.new(0.5, -gp, 0.5, 0)

        lRight.BackgroundColor3 = col
        lRight.Size = UDim2.new(0, sz, 0, th)
        lRight.Position = UDim2.new(0.5, gp, 0.5, 0)

        cDot.BackgroundColor3 = col
        cDot.Size = UDim2.new(0, th + 2, 0, th + 2)
        cDot.Visible = Crosshair.dot
    end
    Crosshair.UpdateVisuals()

    table.insert(allConn, RS.RenderStepped:Connect(function(dt)
        if not Crosshair.enabled or not chFrame or not chFrame.Parent then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        if Crosshair.followMouse then
            local mPos = UIS:GetMouseLocation()
            chFrame.Position = UDim2.new(0, mPos.X, 0, mPos.Y)
        else
            local vSize = cam.ViewportSize
            chFrame.Position = UDim2.new(0, vSize.X / 2, 0, vSize.Y / 2)
        end

        if Crosshair.spin then
            Crosshair.currentAngle = (Crosshair.currentAngle + (Crosshair.spinSpeed or 120) * dt) % 360
            chFrame.Rotation = Crosshair.currentAngle
        else
            chFrame.Rotation = 0
        end
    end))
end
InitCustomCrosshair()

local function GetClosestTargetHead()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    local function getTargetPart(char)
        if not char then return nil end
        local choice = Aim.hitPart or "Head"

        if choice == "Head" then
            return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        elseif choice == "Torso" then
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        elseif choice == "HumanoidRootPart" or choice == "HRP" then
            return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        elseif choice == "Limbs" then
            local limbNames = {"Right Arm", "Left Arm", "Right Leg", "Left Leg", "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg"}
            local bestLimb, bestLimbDist = nil, math.huge
            for _, ln in ipairs(limbNames) do
                local p = char:FindFirstChild(ln)
                if p and p:IsA("BasePart") then
                    if (not Aim.visibleCheck) or isVisible(p, char) then
                        local sp, onS = cam:WorldToViewportPoint(p.Position)
                        if onS and sp.Z > 0 then
                            local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                            if d < bestLimbDist then
                                bestLimbDist = d
                                bestLimb = p
                            end
                        end
                    end
                end
            end
            if bestLimb then return bestLimb end
            return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        elseif choice == "Nearest" then
            local allCandidateParts = {
                "Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart",
                "Right Arm", "Left Arm", "Right Leg", "Left Leg",
                "RightUpperArm", "RightLowerArm", "RightHand",
                "LeftUpperArm", "LeftLowerArm", "LeftHand",
                "RightUpperLeg", "RightLowerLeg", "RightFoot",
                "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"
            }
            local bestCand, bestCandDist = nil, math.huge
            for _, pn in ipairs(allCandidateParts) do
                local p = char:FindFirstChild(pn)
                if p and p:IsA("BasePart") then
                    if (not Aim.visibleCheck) or isVisible(p, char) then
                        local sp, onS = cam:WorldToViewportPoint(p.Position)
                        if onS and sp.Z > 0 then
                            local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                            if d < bestCandDist then
                                bestCandDist = d
                                bestCand = p
                            end
                        end
                    end
                end
            end
            if bestCand then return bestCand end
            return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        end
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end

    local aimRayParams = RaycastParams.new()
    aimRayParams.FilterType = Enum.RaycastFilterType.Exclude
    aimRayParams.IgnoreWater = true

    local function isVisible(part, char)
        if not Aim.visibleCheck then return true end
        if not part or not char then return false end
        local camPos = cam.CFrame.Position
        local targetPos = part.Position
        local dir = targetPos - camPos
        if dir.Magnitude < 0.1 then return true end

        local ignoreList = {cam}
        if LP.Character then table.insert(ignoreList, LP.Character) end
        local ign = workspace:FindFirstChild("Ignored")
        if ign then table.insert(ignoreList, ign) end
        local ghosts = workspace:FindFirstChild("NOVA_Ghosts")
        if ghosts then table.insert(ignoreList, ghosts) end

        aimRayParams.FilterDescendantsInstances = ignoreList

        local curOrigin = camPos
        local curDir = dir
        for _ = 1, 3 do
            local hit = workspace:Raycast(curOrigin, curDir, aimRayParams)
            if not hit then return true end
            local inst = hit.Instance
            if inst:IsDescendantOf(char) then return true end
            if (not inst.CanCollide and inst.Transparency > 0.35) or inst.Transparency >= 0.85 or inst.Name == "Ignored" or (inst.Parent and inst.Parent.Name == "Ignored") then
                local hitPos = hit.Position
                local rem = targetPos - hitPos
                if rem.Magnitude < 0.5 then return true end
                curOrigin = hitPos + (curDir.Unit * 0.05)
                curDir = targetPos - curOrigin
                table.insert(ignoreList, inst)
                aimRayParams.FilterDescendantsInstances = ignoreList
            else
                return false
            end
        end
        return false
    end

    local function isDeadOrKO(char, hum)
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
        return false
    end

    local function isPlayerValid(plr)
        if plr == LP or not (plr and plr.Parent and plr.Character) then return nil end
        local char = plr.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.Parent or hum.Health <= 0 then return nil end
        if Aim.healthCheck and isDeadOrKO(char, hum) then return nil end
        local part = getTargetPart(char)
        if not part then return nil end
        local dist3D = (part.Position - cam.CFrame.Position).Magnitude
        if dist3D > (Aim.maxDistance or 600) then return nil end
        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen or screenPos.Z <= 0 then return nil end
        local distFov = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distFov > Aim.fov then return nil end
        if Aim.visibleCheck and not isVisible(part, char) then return nil end
        return part, distFov
    end

    -- Sticky Camlock: Firmly holds acquired target while in front / within sticky FOV
    if Aim.stickyAim and Aim.currentTarget then
        local cPlr = Aim.currentTarget
        if cPlr and cPlr.Parent and cPlr.Character then
            local cChar = cPlr.Character
            local cHum = cChar:FindFirstChildOfClass("Humanoid")
            if cHum and cHum.Parent and cHum.Health > 0 and not (Aim.healthCheck and isDeadOrKO(cChar, cHum)) then
                local cPart = getTargetPart(cChar)
                if cPart then
                    local d3D = (cPart.Position - cam.CFrame.Position).Magnitude
                    if d3D <= (Aim.maxDistance or 600) then
                        local screenPos, onScreen = cam:WorldToViewportPoint(cPart.Position)
                        if screenPos.Z > 0 then
                            local distFov = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            local maxStickyFov = math.max((Aim.fov or 220) * 1.6, 260)
                            if distFov <= maxStickyFov then
                                local canTarget = true
                                if Aim.visibleCheck then
                                    if isVisible(cPart, cChar) then
                                        Aim.lostTicks = 0
                                    else
                                        Aim.lostTicks = (Aim.lostTicks or 0) + 1
                                        if Aim.lostTicks > 18 then
                                            canTarget = false
                                        end
                                    end
                                end
                                if canTarget then
                                    return cPart
                                end
                            end
                        end
                    end
                end
            end
        end
        Aim.currentTarget = nil
        Aim.lostTicks = 0
    end

    -- Find Closest Target inside FOV
    local bestPart = nil
    local bestPlr = nil
    local bestDist = Aim.fov

    for _, plr in ipairs(Players:GetPlayers()) do
        local part, distFov = isPlayerValid(plr)
        if part and distFov and distFov < bestDist then
            bestDist = distFov
            bestPart = part
            bestPlr = plr
        end
    end

    if Aim.stickyAim and bestPlr then
        Aim.currentTarget = bestPlr
        Aim.lostTicks = 0
    end

    return bestPart
end

SetAimbot = function(enabled)
    Aim.enabled = enabled
    if not enabled then
        Aim.currentTarget = nil
        Aim.lostTicks = 0
    end
    if enabled then
        if not aimbotConn then
            aimbotConn = RS.RenderStepped:Connect(function()
                if not Aim.enabled then return end
                local cam = workspace.CurrentCamera
                if not cam then return end
                local target = GetClosestTargetHead()
                if target then
                    local targetPos = target.Position
                    if Aim.predict and target.Parent then
                        local char = target.Parent
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local rawVel = (hrp and (hrp.AssemblyLinearVelocity or hrp.Velocity)) or (target.AssemblyLinearVelocity or target.Velocity)
                        if rawVel and rawVel.Magnitude > 0.1 then
                            local px = Aim.predictX or Aim.predictAmount or 0.135
                            local py = Aim.predictY or 0.10
                            local cVel = Vector3.new(
                                math.clamp(rawVel.X, -120, 120),
                                math.clamp(rawVel.Y, -50, 50),
                                math.clamp(rawVel.Z, -120, 120)
                            )
                            targetPos = targetPos + Vector3.new(cVel.X * px, cVel.Y * py, cVel.Z * px)
                        end
                    end
                    if Aim.aimType == "Mouse" and mousemoverel then
                        local screenPos, onScreen = cam:WorldToViewportPoint(targetPos)
                        if onScreen and screenPos.Z > 0 then
                            local mousePos = UIS:GetMouseLocation()
                            local sens = math.clamp(Aim.smooth or 0.35, 0.05, 1.0)
                            local deltaX = (screenPos.X - mousePos.X) * sens
                            local deltaY = (screenPos.Y - mousePos.Y) * sens
                            mousemoverel(deltaX, deltaY)
                        end
                    else
                        local curCF = cam.CFrame
                        local targetCF = CFrame.lookAt(curCF.Position, targetPos)
                        local smoothVal = math.clamp(Aim.smooth or 0.35, 0.05, 1.0)
                        if smoothVal >= 0.98 then
                            cam.CFrame = targetCF
                        else
                            cam.CFrame = curCF:Lerp(targetCF, smoothVal)
                        end
                    end
                end
            end)
        end
    else
        if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
    end
end

-- ══════════════════════════════════════════════
--  TRIGGERBOT
-- ══════════════════════════════════════════════
do
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
        if hrp and hrp.CFrame.UpVector.Y < 0.35 then
            return true
        end
        if hum.PlatformStand and hrp and hrp.CFrame.UpVector.Y < 0.5 then
            return true
        end
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
        local ign = workspace:FindFirstChild("Ignored")
        if ign then table.insert(ignoreList, ign) end
        local ghosts = workspace:FindFirstChild("NOVA_Ghosts")
        if ghosts then table.insert(ignoreList, ghosts) end

        trigRayParams.FilterDescendantsInstances = ignoreList

        local curOrigin = camPos
        local curDir = dir
        for _ = 1, 3 do
            local hit = workspace:Raycast(curOrigin, curDir, trigRayParams)
            if not hit then return true end
            local inst = hit.Instance
            if inst:IsDescendantOf(char) then return true end
            if (not inst.CanCollide and inst.Transparency > 0.35) or inst.Transparency >= 0.85 or inst.Name == "Ignored" or (inst.Parent and inst.Parent.Name == "Ignored") then
                local hitPos = hit.Position
                local rem = targetPos - hitPos
                if rem.Magnitude < 0.5 then return true end
                curOrigin = hitPos + (curDir.Unit * 0.05)
                curDir = targetPos - curOrigin
                table.insert(ignoreList, inst)
                trigRayParams.FilterDescendantsInstances = ignoreList
            else
                return false
            end
        end
        return false
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
            if delaySec > 0 then
                task.wait(delaySec)
            end
            if not Triggerbot.enabled then
                Triggerbot.shooting = false
                return
            end

            local char = LP.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() tool:Activate() end)
            end
            if HitEffects and HitEffects.RegisterShot then
                HitEffects.RegisterShot()
            end

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
        if menuOpen then
            if Triggerbot.targetCircle then Triggerbot.targetCircle.Visible = false end
            return
        end

        local cam = workspace.CurrentCamera
        if not cam then
            if Triggerbot.targetCircle then Triggerbot.targetCircle.Visible = false end
            return
        end

        local camCF = cam.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector
        local mPos = UIS:GetMouseLocation()
        local maxDist = Triggerbot.maxDistance or 500
        local baseTol = Triggerbot.tolerance or 14

        local px = (Triggerbot.predict and (Triggerbot.predictX or Triggerbot.predictAmount or 0.14)) or 0
        local py = (Triggerbot.predict and (Triggerbot.predictY or Triggerbot.predictAmount or 0.10)) or 0
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
                    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if hrp then
                        local hrpPos = hrp.Position
                        local toHrp = hrpPos - camPos
                        local d3d = toHrp.Magnitude
                        if d3d <= (maxDist + 10) then
                            if camLook:Dot(toHrp.Unit) > 0.05 then
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

                                            local isMainBody = (pn == "Head" or pn == "UpperTorso" or pn == "Torso" or pn == "LowerTorso" or pn == "HumanoidRootPart")
                                            local partTol = isMainBody and baseTol or (baseTol * 0.75)
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
        end

        -- Update Target Lead Circle Visual
        local tc = Triggerbot.targetCircle
        if tc then
            local maxAimRadius = bestScreenPos and math.clamp(3200 / bestScreenPos.Z, 70, 380) or 220
            if Triggerbot.showTargetCircle and bestPlr and bestScreenPos and bestDist2D <= (maxAimRadius + 60) then
                tc.Position = UDim2.new(0, math.floor(bestScreenPos.X + 0.5), 0, math.floor(bestScreenPos.Y + 0.5))
                tc.Visible = true

                local stroke = Triggerbot.targetStroke
                local dot = Triggerbot.targetDot
                if shouldShoot then
                    local lockCol = Color3.fromRGB(0, 255, 140)
                    if stroke then stroke.Color = lockCol; stroke.Thickness = 2.0 end
                    if dot then dot.BackgroundColor3 = lockCol end
                    tc.Size = UDim2.new(0, 26, 0, 26)
                else
                    local normalCol = T.accent or Color3.fromRGB(0, 255, 140)
                    if stroke then stroke.Color = normalCol; stroke.Thickness = 1.5 end
                    if dot then dot.BackgroundColor3 = normalCol end
                    tc.Size = UDim2.new(0, 22, 0, 22)
                end
            else
                tc.Visible = false
            end
        end

        -- Execute Trigger Shoot if armed and conditions met
        if Triggerbot.enabled and shouldShoot and not Triggerbot.shooting then
            local char = LP.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                TriggerShoot()
            end
        end
    end

    local function UpdateTriggerbotConn()
        local shouldRun = (Triggerbot.enabled == true) or (Triggerbot.showTargetCircle == true)
        if shouldRun then
            if not Triggerbot.conn then
                local lastCheckTime = 0
                Triggerbot.conn = RS.RenderStepped:Connect(function()
                    local now = tick()
                    if now - lastCheckTime < 0.012 then return end
                    lastCheckTime = now
                    UpdateTriggerbotLogic()
                end)
            end
        else
            if Triggerbot.conn then
                Triggerbot.conn:Disconnect()
                Triggerbot.conn = nil
            end
            if Triggerbot.targetCircle then
                Triggerbot.targetCircle.Visible = false
            end
        end
    end

    Triggerbot.UpdateConnection = UpdateTriggerbotConn

    SetTriggerbot = function(enabled)
        Triggerbot.enabled = enabled
        UpdateTriggerbotConn()
    end
end

-- ══════════════════════════════════════════════
-- ══════════════════════════════════════════════
--  NO RECOIL & NO SPREAD SYSTEM (Mad Hood / Da Hood)
-- ══════════════════════════════════════════════
local function InitNoRecoilSystem()
    local function isRecoilKey(k)
        if type(k) ~= "string" then return false end
        local lk = k:lower()
        -- Safeguard: never zero out weapon ammo, damage, pellet count, firerate, offsets that aren't camera recoil
        if lk == "pellets" or lk == "pelletcount" or lk == "numpellets" or lk:find("damage") or lk:find("ammo")
            or lk:find("clip") or lk:find("firerate") or lk:find("cooldown") or lk:find("range")
            or lk:find("muzzle") or lk:find("grip") or lk:find("handle") or lk:find("reload")
            or lk:find("sound") or lk:find("anim") or lk:find("mesh") or lk:find("texture") then
            return false
        end
        return lk:find("recoil") ~= nil
            or lk:find("spread") ~= nil
            or lk:find("camshake") ~= nil
            or lk:find("shake") ~= nil
            or lk:find("kick") ~= nil
            or lk:find("knock") ~= nil
            or lk:find("pushback") ~= nil
            or lk:find("punch") ~= nil
            or lk:find("sway") ~= nil
            or lk:find("bloom") ~= nil
            or lk:find("dispersion") ~= nil
            or lk:find("inaccuracy") ~= nil
            or lk:find("scatter") ~= nil
            or lk:find("deviation") ~= nil
            or lk:find("lift") ~= nil
            or lk:find("climb") ~= nil
            or lk:find("camoffset") ~= nil
            or lk:find("cameraoffset") ~= nil
            or lk:find("recoiloffset") ~= nil
            or lk:find("kickoffset") ~= nil
            or lk:find("impulse") ~= nil
    end

    local function patchValue(tbl, k, v)
        local tv = typeof(v)
        local wasRo = false
        if isreadonly and isreadonly(tbl) then
            wasRo = true
            if setreadonly then pcall(setreadonly, tbl, false) end
        end
        pcall(function()
            if tv == "number" then
                rawset(tbl, k, 0)
            elseif tv == "Vector3" then
                rawset(tbl, k, Vector3.zero)
            elseif tv == "Vector2" then
                rawset(tbl, k, Vector2.zero)
            elseif tv == "CFrame" then
                rawset(tbl, k, CFrame.new())
            end
        end)
        if wasRo and setreadonly then
            pcall(setreadonly, tbl, true)
        end
    end

    local function patchTableRecoil(tbl, visited, isParentRecoil)
        if type(tbl) ~= "table" then return end
        visited = visited or {}
        if visited[tbl] then return end
        visited[tbl] = true

        pcall(function()
            local wasRo = false
            if isreadonly and isreadonly(tbl) then
                wasRo = true
                if setreadonly then pcall(setreadonly, tbl, false) end
            end
            for k, v in pairs(tbl) do
                local match = isParentRecoil or isRecoilKey(k)
                if match then
                    if type(v) == "table" and not visited[v] then
                        patchTableRecoil(v, visited, true)
                    else
                        patchValue(tbl, k, v)
                    end
                elseif type(v) == "table" and not visited[v] then
                    patchTableRecoil(v, visited, false)
                end
            end
            if wasRo and setreadonly then
                pcall(setreadonly, tbl, true)
            end
        end)
    end

    local function patchFunctionUpvalues(fn, visited)
        if type(fn) ~= "function" then return end
        if not getupvalues or not setupvalue then return end
        visited = visited or {}
        if visited[fn] then return end
        visited[fn] = true

        pcall(function()
            local upvs = getupvalues(fn)
            for idx, uVal in pairs(upvs) do
                local uName = ""
                if debug and debug.getupvalue then
                    pcall(function() uName = debug.getupvalue(fn, idx) or "" end)
                end
                if type(uName) ~= "string" or uName == "" then uName = tostring(idx) end

                if type(uVal) == "table" then
                    local isRecoil = isRecoilKey(uName)
                    patchTableRecoil(uVal, visited, isRecoil)
                elseif isRecoilKey(uName) then
                    local tv = typeof(uVal)
                    if tv == "number" then
                        setupvalue(fn, idx, 0)
                    elseif tv == "Vector3" then
                        setupvalue(fn, idx, Vector3.zero)
                    elseif tv == "Vector2" then
                        setupvalue(fn, idx, Vector2.zero)
                    end
                elseif type(uVal) == "function" and not visited[uVal] then
                    patchFunctionUpvalues(uVal, visited)
                end
            end
        end)
    end

    local function patchTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        pcall(function()
            -- 1. Scan tool attributes
            for attrName, attrVal in pairs(tool:GetAttributes()) do
                if isRecoilKey(attrName) then
                    local tv = typeof(attrVal)
                    if tv == "number" then tool:SetAttribute(attrName, 0)
                    elseif tv == "Vector3" then tool:SetAttribute(attrName, Vector3.zero)
                    elseif tv == "Vector2" then tool:SetAttribute(attrName, Vector2.zero)
                    end
                end
            end

            -- 2. Scan descendants
            for _, desc in ipairs(tool:GetDescendants()) do
                -- Attributes
                for attrName, attrVal in pairs(desc:GetAttributes()) do
                    if isRecoilKey(attrName) then
                        local tv = typeof(attrVal)
                        if tv == "number" then desc:SetAttribute(attrName, 0)
                        elseif tv == "Vector3" then desc:SetAttribute(attrName, Vector3.zero)
                        elseif tv == "Vector2" then desc:SetAttribute(attrName, Vector2.zero)
                        end
                    end
                end

                -- Value Objects
                if desc:IsA("NumberValue") or desc:IsA("IntValue") then
                    if isRecoilKey(desc.Name) then desc.Value = 0 end
                elseif desc:IsA("Vector3Value") then
                    if isRecoilKey(desc.Name) then desc.Value = Vector3.zero end
                -- ModuleScript (Gun settings/stats/recoil modules)
                elseif desc:IsA("ModuleScript") then
                    local ok, modData = pcall(require, desc)
                    if ok and type(modData) == "table" then
                        patchTableRecoil(modData)
                    end
                -- LocalScript / Client Script (Environment and upvalues)
                elseif (desc:IsA("LocalScript") or (desc:IsA("Script") and pcall(function() return desc.RunContext == Enum.RunContext.Client end))) and getsenv then
                    local ok, env = pcall(getsenv, desc)
                    if ok and type(env) == "table" then
                        patchTableRecoil(env)
                        for _, val in pairs(env) do
                            if type(val) == "function" then
                                patchFunctionUpvalues(val)
                            end
                        end
                    end
                end
            end

            -- 3. Scan tool event connections (Activated, Equipped)
            if getconnections then
                for _, sig in ipairs({tool.Activated, tool.Equipped}) do
                    pcall(function()
                        for _, conn in ipairs(getconnections(sig)) do
                            if conn.Function then
                                patchFunctionUpvalues(conn.Function)
                            end
                        end
                    end)
                end
            end

            -- 4. Re-patch on equip
            if not tool:GetAttribute("NOVA_PatchedEquip") then
                tool:SetAttribute("NOVA_PatchedEquip", true)
                tool.Equipped:Connect(function()
                    if Aim.noRecoil then
                        task.defer(patchTool, tool)
                    end
                end)
            end
        end)
    end

    local function patchAllTools()
        if not Aim.noRecoil then return end
        local char = LP.Character
        if char then
            for _, ch in ipairs(char:GetChildren()) do
                if ch:IsA("Tool") then patchTool(ch) end
            end
        end
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            for _, ch in ipairs(bp:GetChildren()) do
                if ch:IsA("Tool") then patchTool(ch) end
            end
        end
        -- Also scan ReplicatedStorage for shared weapon modules / settings
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            for _, desc in ipairs(rs:GetDescendants()) do
                if desc:IsA("ModuleScript") then
                    local dName = desc.Name:lower()
                    if dName:find("gun") or dName:find("weapon") or dName:find("setting") or dName:find("config") or dName:find("shotgun") or dName:find("barrel") or dName:find("stats") then
                        local ok, modData = pcall(require, desc)
                        if ok and type(modData) == "table" then
                            patchTableRecoil(modData)
                        end
                    end
                end
            end
        end)
        -- Also scan getloadedmodules if executor supports it
        if getloadedmodules then
            pcall(function()
                for _, mod in ipairs(getloadedmodules()) do
                    if mod:IsA("ModuleScript") then
                        local mName = mod.Name:lower()
                        if mName:find("gun") or mName:find("weapon") or mName:find("recoil") or mName:find("spread") or mName:find("shotgun") or mName:find("barrel") or mName:find("setting") or mName:find("stats") or mName:find("spring") then
                            local ok, modData = pcall(require, mod)
                            if ok and type(modData) == "table" then
                                patchTableRecoil(modData)
                            end
                        end
                    end
                end
            end)
        end
    end

    local function patchGC()
        if not Aim.noRecoil or not getgc then return end
        pcall(function()
            local visited = {}
            for _, obj in ipairs(getgc(true)) do
                local t = type(obj)
                if t == "table" and not visited[obj] then
                    visited[obj] = true
                    -- Neutralize CameraShaker objects
                    if type(rawget(obj, "Shake")) == "function" or type(rawget(obj, "ShakeOnce")) == "function" then
                        pcall(function()
                            if isreadonly and isreadonly(obj) and setreadonly then setreadonly(obj, false) end
                            obj.Shake = function() end
                            obj.ShakeOnce = function() end
                            if type(rawget(obj, "ShakeSustain")) == "function" then
                                obj.ShakeSustain = function() end
                            end
                        end)
                    end
                    -- Neutralize Spring shove methods (common in gun recoil systems)
                    if type(rawget(obj, "shove")) == "function" or type(rawget(obj, "Shove")) == "function" then
                        pcall(function()
                            if isreadonly and isreadonly(obj) and setreadonly then setreadonly(obj, false) end
                            if obj.shove then obj.shove = function() end end
                            if obj.Shove then obj.Shove = function() end end
                        end)
                    end
                    -- Targeted filter: gun/weapon configs
                    local isGunTable = rawget(obj, "Recoil") ~= nil or rawget(obj, "recoil") ~= nil
                        or rawget(obj, "Spread") ~= nil or rawget(obj, "spread") ~= nil
                        or rawget(obj, "Knockback") ~= nil or rawget(obj, "knockback") ~= nil
                        or rawget(obj, "CamShake") ~= nil or rawget(obj, "camShake") ~= nil
                    if isGunTable then
                        patchTableRecoil(obj, visited)
                    end
                end
            end
        end)
    end

    local function isDefaultCameraCaller()
        if debug and debug.info then
            for lvl = 2, 6 do
                local src = debug.info(lvl, "s")
                if not src then break end
                local s = src:lower()
                if s:find("cameramodule")
                    or s:find("playermodule")
                    or s:find("basecamera")
                    or s:find("classiccamera")
                    or s:find("transparencycontroller")
                    or s:find("invisicam")
                    or s:find("poppercam")
                    or s:find("freecam") then
                    return true
                end
            end
        end
        return false
    end

    -- Universal __newindex metamethod hook: blocks weapon recoil kicks on CurrentCamera & Humanoid.CameraOffset
    local oldNewIndex = nil
    local function installNewIndexHook()
        local function newIndexCallback(self, prop, val)
            if Aim.noRecoil and not (checkcaller and checkcaller()) then
                if self == workspace.CurrentCamera and (prop == "CFrame" or prop == "CoordinateFrame" or prop == "Focus") then
                    if not isDefaultCameraCaller() then
                        -- Gun recoil script attempting to tilt or shake the camera!
                        return
                    end
                elseif typeof(self) == "Instance" and self:IsA("Humanoid") and prop == "CameraOffset" then
                    -- Gun recoil jolting Humanoid.CameraOffset
                    return
                elseif typeof(self) == "Instance" and self:IsA("BasePart") and LP.Character and self:IsDescendantOf(LP.Character) and (prop == "Velocity" or prop == "AssemblyLinearVelocity") then
                    -- Gun recoil knockback/pushback on any character part (RootPart, Torso, etc.)
                    local isGunCaller = false
                    if debug and debug.info then
                        for lvl = 2, 6 do
                            local src = debug.info(lvl, "s")
                            if not src then break end
                            local s = src:lower()
                            if s:find("gun") or s:find("weapon") or s:find("shotgun") or s:find("barrel") or s:find("recoil") or s:find("knock") or s:find("tool") then
                                isGunCaller = true
                                break
                            end
                        end
                    end
                    if isGunCaller then
                        return
                    end
                end
            end
            if oldNewIndex then
                return oldNewIndex(self, prop, val)
            end
        end

        pcall(function()
            if hookmetamethod then
                oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(newIndexCallback))
            end
        end)

        if not oldNewIndex and getrawmetatable and setreadonly then
            pcall(function()
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                oldNewIndex = mt.__newindex
                mt.__newindex = newcclosure(newIndexCallback)
                setreadonly(mt, true)
            end)
        end
    end
    installNewIndexHook()

    -- TweenService hook: blocks camera recoil tweens (e.g. shotgun kicks created via TweenService:Create)
    pcall(function()
        local TS = game:GetService("TweenService")
        if hookfunction and TS and TS.Create then
            local oldCreate
            oldCreate = hookfunction(TS.Create, function(self, inst, info, props)
                if Aim.noRecoil and not (checkcaller and checkcaller()) then
                    if inst == workspace.CurrentCamera and type(props) == "table" then
                        if props.CFrame or props.CoordinateFrame or props.Focus then
                            props.CFrame = nil
                            props.CoordinateFrame = nil
                            props.Focus = nil
                        end
                    end
                end
                return oldCreate(self, inst, info, props)
            end)
        end
    end)

    -- Continuous camera shake suppression & Double Barrel knockback neutralization
    RS.RenderStepped:Connect(function()
        if not Aim.noRecoil then return end
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.CameraOffset ~= Vector3.zero then
                hum.CameraOffset = Vector3.zero
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, child in ipairs(hrp:GetChildren()) do
                    if child:IsA("BodyVelocity") or child:IsA("BodyForce") or child:IsA("BodyThrust") or child:IsA("LinearVelocity") or child:IsA("VectorForce") then
                        pcall(function()
                            if child:IsA("BodyVelocity") then
                                child.MaxForce = Vector3.zero
                                child.Velocity = Vector3.zero
                            elseif child:IsA("LinearVelocity") then
                                child.VectorVelocity = Vector3.zero
                                child.MaxForce = 0
                            end
                            child:Destroy()
                        end)
                    end
                end
            end
        end
    end)

    Aim.SetNoRecoil = function(enabled)
        Aim.noRecoil = (enabled == true)
        if Aim.noRecoil then
            patchAllTools()
            task.defer(patchGC)
        end
        SaveConfig()
    end

    local function onCharAdded(char)
        if not char then return end
        char.ChildAdded:Connect(function(child)
            if Aim.noRecoil and child:IsA("Tool") then
                task.defer(patchTool, child)
            end
        end)
        char.DescendantAdded:Connect(function(desc)
            if Aim.noRecoil and (desc:IsA("BodyVelocity") or desc:IsA("BodyForce") or desc:IsA("LinearVelocity") or desc:IsA("VectorForce") or desc:IsA("BodyThrust")) then
                pcall(function()
                    if desc:IsA("BodyVelocity") then
                        desc.MaxForce = Vector3.zero
                        desc.Velocity = Vector3.zero
                    elseif desc:IsA("LinearVelocity") then
                        desc.VectorVelocity = Vector3.zero
                        desc.MaxForce = 0
                    end
                    desc:Destroy()
                end)
            end
        end)
    end
    if LP.Character then onCharAdded(LP.Character) end
    LP.CharacterAdded:Connect(onCharAdded)

    local function onBackpackAdded(bp)
        if not bp then return end
        bp.ChildAdded:Connect(function(child)
            if Aim.noRecoil and child:IsA("Tool") then
                task.defer(patchTool, child)
            end
        end)
    end
    if LP:FindFirstChild("Backpack") then onBackpackAdded(LP.Backpack) end
    LP.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then onBackpackAdded(child) end
    end)
end
InitNoRecoilSystem()


-- ══════════════════════════════════════════════
--  HIT SOUNDS & CENTER-BOTTOM DAMAGE INDICATOR
-- ══════════════════════════════════════════════
do
    HitEffects.canPlay = false
    HitEffects.PlaySound = function()
        if not HitEffects.soundEnabled then return end
        if not HitEffects.canPlay then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = HitEffects.soundId or "rbxassetid://4817809188"
            s.Volume = HitEffects.soundVolume or 0.65
            s.Parent = game:GetService("SoundService")
            s:Play()
            task.delay(1.5, function() pcall(function() s:Destroy() end) end)
        end)
    end

    local dmgSG = Instance.new("ScreenGui")
    dmgSG.Name = "NOVA_DamageHUD"
    dmgSG.ResetOnSpawn = false
    dmgSG.IgnoreGuiInset = true
    dmgSG.DisplayOrder = 9995
    dmgSG.ZIndexBehavior = Enum.ZIndexBehavior.Global
    dmgSG.Parent = safeParent

    local dmgCard = Instance.new("Frame")
    dmgCard.Name = "DamageIndicator"
    dmgCard.AnchorPoint = Vector2.new(0.5, 0.5)
    dmgCard.Position = UDim2.new(0.5, 0, 0.77, 0)
    dmgCard.Size = UDim2.new(0, 0, 0, 28)
    dmgCard.AutomaticSize = Enum.AutomaticSize.X
    dmgCard.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    dmgCard.BackgroundTransparency = 1
    dmgCard.BorderSizePixel = 0
    dmgCard.Visible = false
    dmgCard.ClipsDescendants = false
    dmgCard.Parent = dmgSG
    Crn(dmgCard, 6)
    local dStroke = Strk(dmgCard, T.border, 1, 0)
    dStroke.Transparency = 1

    local dPad = Instance.new("UIPadding")
    dPad.PaddingLeft = UDim.new(0, 14)
    dPad.PaddingRight = UDim.new(0, 14)
    dPad.Parent = dmgCard

    local dLL = Instance.new("UIListLayout")
    dLL.FillDirection = Enum.FillDirection.Horizontal
    dLL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dLL.VerticalAlignment = Enum.VerticalAlignment.Center
    dLL.SortOrder = Enum.SortOrder.LayoutOrder
    dLL.Padding = UDim.new(0, 8)
    dLL.Parent = dmgCard

    local dmgL = Lbl(dmgCard, "-0 HP", 11, T.accent, Enum.Font.Arcade, Enum.TextXAlignment.Center, 2)
    dmgL.AutomaticSize = Enum.AutomaticSize.X
    dmgL.TextTransparency = 1
    dmgL.TextStrokeTransparency = 0
    dmgL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TrackAccent(dmgL, "TextColor3")

    local sepL = Lbl(dmgCard, "•", 10, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Center, 2)
    sepL.AutomaticSize = Enum.AutomaticSize.X
    sepL.TextTransparency = 1

    local tgtL = Lbl(dmgCard, "Target", 11, Color3.fromRGB(240, 240, 255), Enum.Font.Arcade, Enum.TextXAlignment.Center, 2)
    tgtL.AutomaticSize = Enum.AutomaticSize.X
    tgtL.TextWrapped = false
    tgtL.TextTransparency = 1
    tgtL.TextStrokeTransparency = 0
    tgtL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    local function GetDmgTextColor()
        local cur = HitEffects.dmgHudColor
        local col = nil
        if not cur or cur == "Accent" or cur == "GUI" then
            col = T.accent or Color3.fromRGB(0, 255, 140)
        elseif ConfigSystem and ConfigSystem.ParseColor then
            local pc = ConfigSystem.ParseColor(cur)
            if pc then col = pc end
        end
        if not col then
            if cur == "Red" then
                col = Color3.fromRGB(255, 75, 85)
            elseif cur == "Green" then
                col = Color3.fromRGB(80, 255, 120)
            elseif cur == "White" then
                col = Color3.fromRGB(255, 255, 255)
            else
                col = T.accent or Color3.fromRGB(0, 255, 140)
            end
        end
        if col and (col.R + col.G + col.B) < 0.12 then
            col = T.accent or Color3.fromRGB(0, 255, 140)
        end
        return col or T.accent or Color3.fromRGB(0, 255, 140)
    end

    HitEffects.UpdateDmgColor = function()
        if dmgL and dmgL.Parent then
            dmgL.TextColor3 = GetDmgTextColor()
        end
    end

    HitEffects.ShowDamage = function(plr, dmg)
        if not HitEffects.dmgHudEnabled then return end
        if not dmgCard or not dmgCard.Parent then return end

        dmgL.Text = "-" .. tostring(dmg) .. " HP"
        dmgL.TextColor3 = GetDmgTextColor()
        tgtL.Text = (plr and (plr.DisplayName .. " (@" .. plr.Name .. ")")) or "Enemy"

        dmgCard.Visible = true
        dmgCard.Position = UDim2.new(0.5, 0, 0.78, 0)
        Tw(dmgCard, {Position = UDim2.new(0.5, 0, 0.76, 0), BackgroundTransparency = 0.15}, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        Tw(dStroke, {Transparency = 0}, 0.18)
        Tw(dmgL, {TextTransparency = 0}, 0.18)
        Tw(sepL, {TextTransparency = 0}, 0.18)
        Tw(tgtL, {TextTransparency = 0}, 0.18)

        local myHitTime = tick()
        HitEffects.lastHitTime = myHitTime
        task.delay(1.7, function()
            if HitEffects.lastHitTime == myHitTime and dmgCard and dmgCard.Parent then
                Tw(dmgCard, {Position = UDim2.new(0.5, 0, 0.77, 0), BackgroundTransparency = 1}, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                Tw(dStroke, {Transparency = 1}, 0.22)
                Tw(dmgL, {TextTransparency = 1}, 0.22)
                Tw(sepL, {TextTransparency = 1}, 0.22)
                Tw(tgtL, {TextTransparency = 1}, 0.22)
                task.delay(0.24, function()
                    if HitEffects.lastHitTime == myHitTime and dmgCard and dmgCard.Parent then
                        dmgCard.Visible = false
                    end
                end)
            end
        end)
    end

    HitEffects.SpawnGhost = function(char)
        if not HitEffects.ghostEnabled or not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead or hum.PlatformStand then
            return
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.CFrame.UpVector.Y < 0.45 then
            return
        end
        local be = char:FindFirstChild("BodyEffects")
        if be then
            local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO") or be:FindFirstChild("Knocked")
            if ko and (ko.Value == true or ko.Value == 1) then return end
            local dead = be:FindFirstChild("Dead")
            if dead and (dead.Value == true or dead.Value == 1) then return end
        end
        if char:FindFirstChild("Ragdoll") or char:FindFirstChild("KO") or char:FindFirstChild("K.O") or char:FindFirstChild("Knocked") then
            return
        end

        local ghostFolder = workspace:FindFirstChild("NOVA_Ghosts")
        if not ghostFolder then
            ghostFolder = Instance.new("Folder")
            ghostFolder.Name = "NOVA_Ghosts"
            ghostFolder.Parent = workspace
        end

        local existing = ghostFolder:GetChildren()
        if #existing >= 6 then
            for i = 1, #existing - 4 do
                pcall(function() existing[i]:Destroy() end)
            end
        end

        local ghost = Instance.new("Model")
        ghost.Name = "HitGhost"
        ghost.Parent = ghostFolder

        local ghostCol = GetDmgTextColor()
        if not ghostCol or (ghostCol.R + ghostCol.G + ghostCol.B) < 0.12 then
            ghostCol = T.accent or Color3.fromRGB(0, 255, 140)
        end

        local partsToFade = {}
        local bodyPartNames = {
            ["Head"] = true, ["Torso"] = true, ["Left Arm"] = true, ["Right Arm"] = true,
            ["Left Leg"] = true, ["Right Leg"] = true,
            ["UpperTorso"] = true, ["LowerTorso"] = true,
            ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
            ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
            ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
            ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true,
        }

        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("BasePart") and bodyPartNames[child.Name] and child.Transparency < 0.95 then
                pcall(function()
                    if child.Name == "Head" then
                        local p = Instance.new("Part")
                        p.Name = "Ghost_Head"
                        p.Size = child.Size
                        p.CFrame = child.CFrame
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                        p.Anchored = true
                        p.Material = Enum.Material.Neon
                        p.Color = ghostCol
                        p.Transparency = 0.4
                        local sm = Instance.new("SpecialMesh")
                        sm.MeshType = Enum.MeshType.Head
                        sm.Scale = Vector3.new(1.25, 1.25, 1.25)
                        sm.Parent = p
                        p.Parent = ghost
                        table.insert(partsToFade, p)
                    else
                        local p = child:Clone()
                        for _, sc in ipairs(p:GetChildren()) do
                            sc:Destroy()
                        end
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                        p.Anchored = true
                        p.Material = Enum.Material.Neon
                        p.Color = ghostCol
                        p.Transparency = 0.4
                        p.CFrame = child.CFrame
                        p.Parent = ghost
                        table.insert(partsToFade, p)
                    end
                end)
            end
        end

        if #partsToFade == 0 then
            ghost:Destroy()
            return
        end

        local duration = math.clamp(tonumber(HitEffects.ghostDuration) or 0.5, 0.2, 2.0)
        local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, p in ipairs(partsToFade) do
            pcall(function() TS:Create(p, ti, {Transparency = 1}):Play() end)
        end

        task.delay(duration + 0.05, function()
            if ghost and ghost.Parent then
                ghost:Destroy()
            end
        end)
        pcall(function()
            game:GetService("Debris"):AddItem(ghost, duration + 0.5)
        end)
    end

    -- Register a shot fired by LocalPlayer (targeted or towards crosshair cone)
    HitEffects.RegisterShot = function(directPlr)
        local now = tick()
        HitEffects.lastShotTime = now

        if directPlr and directPlr:IsA("Player") and directPlr ~= LP then
            HitEffects.pendingShots[directPlr] = now
            return
        end

        local cam = workspace.CurrentCamera
        if not cam then return end
        local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

        if Aim.enabled and Aim.currentTarget then
            HitEffects.pendingShots[Aim.currentTarget] = now
        end

        -- Check players in crosshair line of fire
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local char = p.Character
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                if hrp then
                    local sPos, onS = cam:WorldToViewportPoint(hrp.Position)
                    if onS and sPos.Z > 0 then
                        local dCenter = (Vector2.new(sPos.X, sPos.Y) - screenCenter).Magnitude
                        local d3D = (hrp.Position - cam.CFrame.Position).Magnitude
                        if dCenter <= 110 and d3D <= 350 then
                            HitEffects.pendingShots[p] = now
                        end
                    end
                end
            end
        end
    end

    -- Monitor player health changes: strictly ONLY triggers when LocalPlayer dealt the damage
    local function monitorPlayer(plr)
        if plr == LP then return end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 4)
            if not hum then return end
            local lastHealth = hum.Health
            local c = hum.HealthChanged:Connect(function(newHealth)
                if newHealth < lastHealth then
                    local dmg = math.floor((lastHealth - newHealth) + 0.5)
                    local shotTime = HitEffects.pendingShots[plr]
                    local isOurHit = false

                    -- Check 1: We fired at this specific player within the last 0.38s
                    if shotTime and (tick() - shotTime) <= 0.38 then
                        isOurHit = true
                        HitEffects.pendingShots[plr] = nil -- Consumed immediately
                    end

                    -- Check 2: Roblox creator tag
                    if not isOurHit then
                        local creator = hum:FindFirstChild("creator")
                        if creator and creator.Value == LP then
                            isOurHit = true
                        end
                    end

                    if isOurHit and dmg > 0 and dmg <= 150 then
                        HitEffects.PlaySound()
                        HitEffects.ShowDamage(plr, dmg)
                        if HitEffects.SpawnGhost and plr.Character then
                            HitEffects.SpawnGhost(plr.Character)
                        end
                    end
                end
                lastHealth = newHealth
            end)
            table.insert(allConn, c)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        table.insert(allConn, plr.CharacterAdded:Connect(onChar))
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then monitorPlayer(p) end
    end
    table.insert(allConn, Players.PlayerAdded:Connect(monitorPlayer))

    -- Register shot on manual click only when a weapon Tool is equipped
    table.insert(allConn, UIS.InputBegan:Connect(function(inp, gpe)
        if not gpe and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if LP.Character and LP.Character:FindFirstChildOfClass("Tool") then
                HitEffects.RegisterShot()
            end
        end
    end))
end

-- ══════════════════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════════════════

local function CreateSlider(parent, order, labelText, minVal, maxVal, defaultVal, callback, isFloat, customKey)
    local curVal = math.clamp(defaultVal, minVal, maxVal)
    if isFloat then
        curVal = math.clamp(math.floor(curVal * 1000 + 0.5) / 1000, minVal, maxVal)
    else
        curVal = math.clamp(math.floor(curVal + 0.5), minVal, maxVal)
    end

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local topF = Instance.new("Frame")
    topF.Size = UDim2.new(1, 0, 0, 16)
    topF.BackgroundTransparency = 1
    topF.Parent = row

    local nameL = Lbl(topF, labelText, 11, T.textDim, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 2)
    nameL.Size = UDim2.new(1, -54, 1, 0)
    nameL.Position = UDim2.new(0, 2, 0, 0)
    if ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.RegisterLabel(nameL, labelText, false)
    end

    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 0, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 5
    textHit.Parent = topF

    local function updateSliderTextHit()
        local tbX = nameL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nameL.Text * 7, 20) end
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, 130), 1, 0)
    end
    updateSliderTextHit()
    nameL:GetPropertyChangedSignal("TextBounds"):Connect(updateSliderTextHit)
    nameL:GetPropertyChangedSignal("Text"):Connect(updateSliderTextHit)
    task.defer(updateSliderTextHit)

    textHit.MouseEnter:Connect(function()
        Tw(nameL, {TextColor3 = T.text}, 0.1)
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nameL, {TextColor3 = T.textDim}, 0.1)
    end)
    topF.MouseLeave:Connect(function()
        Tw(nameL, {TextColor3 = T.textDim}, 0.1)
    end)

    -- Numeric input box (clean right-aligned display matching screenshot)
    local valBoxF = Instance.new("Frame")
    valBoxF.Size = UDim2.new(0, 52, 0, 16)
    valBoxF.Position = UDim2.new(1, -52, 0, 0)
    valBoxF.BackgroundTransparency = 1
    valBoxF.BorderSizePixel = 0
    valBoxF.ZIndex = 3
    valBoxF.Parent = topF

    local valTB = Instance.new("TextBox")
    valTB.Size = UDim2.new(1, 0, 1, 0)
    valTB.BackgroundTransparency = 1
    valTB.Font = Enum.Font.GothamMedium
    valTB.TextSize = 11
    valTB.Text = isFloat and string.format(curVal == math.floor(curVal) and "%d" or "%.3g", curVal) or tostring(curVal)
    valTB.TextColor3 = T.text
    valTB.TextXAlignment = Enum.TextXAlignment.Right
    valTB.ClearTextOnFocus = false
    valTB.ZIndex = 4
    valTB.Parent = valBoxF

    -- Slider track (rounded sleek track matching screenshot)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -4, 0, 7)
    track.Position = UDim2.new(0, 2, 0, 21)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
    track.BorderSizePixel = 0
    track.ZIndex = 3
    track.Parent = row
    Crn(track, 4)
    if ConfigSystem then
        if not ConfigSystem.themeSliders then ConfigSystem.themeSliders = {} end
        table.insert(ConfigSystem.themeSliders, {nameL = nameL, valTB = valTB, track = track})
    end

    local initialPct = (maxVal > minVal) and math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1) or 0

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initialPct, 0, 1, 0)
    fill.BackgroundColor3 = T.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 4
    fill.Parent = track
    Crn(fill, 4)
    TrackAccent(fill, "BackgroundColor3")

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 8, 0, 8)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(initialPct, 0, 0.5, 0)
    knob.BackgroundTransparency = 1
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = track

    local function SetValue(newVal, skipSave)
        if isFloat then
            curVal = math.clamp(math.floor(newVal * 1000 + 0.5) / 1000, minVal, maxVal)
            valTB.Text = string.format(curVal == math.floor(curVal) and "%d" or "%.3g", curVal)
        else
            curVal = math.clamp(math.floor(newVal + 0.5), minVal, maxVal)
            valTB.Text = tostring(curVal)
        end
        local pct = (maxVal > minVal) and math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1) or 0
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        if callback then
            task.spawn(function()
                pcall(function() callback(curVal) end)
            end)
        end
        if not skipSave and SaveConfig then SaveConfig() end
    end

    local dragging = false
    local function UpdateFromX(x)
        local absX = track.AbsolutePosition.X
        local absW = track.AbsoluteSize.X
        if absW <= 0 then return end
        local pct = math.clamp((x - absX) / absW, 0, 1)
        local rawVal = minVal + pct * (maxVal - minVal)
        SetValue(rawVal)
    end

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1, 0, 0, 16)
    clickBtn.Position = UDim2.new(0, 0, 0, 16)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.ZIndex = 7
    clickBtn.Parent = row

    clickBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            UpdateFromX(inp.Position.X)
        end
    end)
    table.insert(allConn, UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromX(inp.Position.X)
        end
    end))
    table.insert(allConn, UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                SaveConfig()
            end
        end
    end))

    valTB.FocusLost:Connect(function()
        local n = tonumber(valTB.Text)
        if n then
            SetValue(n)
        else
            valTB.Text = isFloat and string.format(curVal == math.floor(curVal) and "%d" or "%.3g", curVal) or tostring(curVal)
        end
    end)

    local sObj = {
        row = row,
        SetValue = SetValue,
        GetValue = function() return curVal end,
    }
    if customKey then
        allSliders[customKey] = sObj
    end
    return sObj
end

ConfigSystem.CreateColorPicker = function(parentCard, order, title, getCol, setCol, showSync, getSync, setSync)
    local curCol = getCol() or Color3.fromRGB(255, 255, 255)
    local curH, curS, curV = Color3.toHSV(curCol)

    local wrapper = Instance.new("Frame")
    wrapper.Name = title:gsub("%s+", "") .. "Wrapper"
    wrapper.Size = UDim2.new(1, 0, 0, 0)
    wrapper.AutomaticSize = Enum.AutomaticSize.Y
    wrapper.BackgroundTransparency = 1
    wrapper.LayoutOrder = order
    wrapper.Parent = parentCard

    local wLL = Instance.new("UIListLayout")
    wLL.SortOrder = Enum.SortOrder.LayoutOrder
    wLL.Padding = UDim.new(0, 4)
    wLL.Parent = wrapper

    local hRow = Instance.new("Frame")
    hRow.Name = "HeaderRow"
    hRow.Size = UDim2.new(1, 0, 0, 24)
    hRow.BackgroundTransparency = 1
    hRow.LayoutOrder = 1
    hRow.Parent = wrapper

    local titleLbl = Lbl(hRow, title, 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
    titleLbl.Size = UDim2.new(1, -74, 1, 0)
    titleLbl.Position = UDim2.new(0, 2, 0, 0)

    local rightControls = Instance.new("Frame")
    rightControls.Size = UDim2.new(0, 72, 1, 0)
    rightControls.Position = UDim2.new(1, -72, 0, 0)
    rightControls.BackgroundTransparency = 1
    rightControls.Parent = hRow

    local rcLL = Instance.new("UIListLayout")
    rcLL.FillDirection = Enum.FillDirection.Horizontal
    rcLL.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rcLL.VerticalAlignment = Enum.VerticalAlignment.Center
    rcLL.Padding = UDim.new(0, 5)
    rcLL.SortOrder = Enum.SortOrder.LayoutOrder
    rcLL.Parent = rightControls

    local syncHeaderBtn = nil
    if showSync then
        syncHeaderBtn = Instance.new("TextButton")
        syncHeaderBtn.Size = UDim2.new(0, 42, 0, 18)
        local syncIsGui = (getSync and getSync())
        syncHeaderBtn.BackgroundColor3 = syncIsGui and T.accent or Color3.fromRGB(25, 25, 34)
        local isGlassSync = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
        syncHeaderBtn.BackgroundTransparency = syncIsGui and 0 or (isGlassSync and 0.65 or 0)
        syncHeaderBtn.BorderSizePixel = 0
        syncHeaderBtn.Font = Enum.Font.Arcade
        syncHeaderBtn.Text = syncIsGui and "GUI" or "Custom"
        syncHeaderBtn.TextColor3 = syncIsGui and Color3.fromRGB(255, 255, 255) or T.textMuted
        syncHeaderBtn.TextSize = 9
        syncHeaderBtn.AutoButtonColor = false
        syncHeaderBtn.LayoutOrder = 1
        syncHeaderBtn.Parent = rightControls
        Crn(syncHeaderBtn, 4)
        local syncStroke = Strk(syncHeaderBtn, T.border, 1, 0)
        if ConfigSystem and ConfigSystem.RegisterGlassButton then
            ConfigSystem.RegisterGlassButton(syncHeaderBtn, syncStroke, Color3.fromRGB(25, 25, 34))
        end
    end

    local swatchBtn = Instance.new("TextButton")
    swatchBtn.Size = UDim2.new(0, 20, 0, 20)
    swatchBtn.BackgroundColor3 = curCol
    swatchBtn.BorderSizePixel = 0
    swatchBtn.Text = ""
    swatchBtn.AutoButtonColor = false
    swatchBtn.LayoutOrder = 2
    swatchBtn.Parent = rightControls
    Crn(swatchBtn, 5)
    Strk(swatchBtn, Color3.fromRGB(45, 45, 60), 1, 0)

    local hClickBtn = Instance.new("TextButton")
    hClickBtn.Size = UDim2.new(1, showSync and -74 or -26, 1, 0)
    hClickBtn.BackgroundTransparency = 1
    hClickBtn.Text = ""
    hClickBtn.ZIndex = 3
    hClickBtn.Parent = hRow

    local popPanel = (hasCanvasGroup and Instance.new("CanvasGroup") or Instance.new("Frame"))
    popPanel.Name = "ColorPickerPopup"
    popPanel.Size = UDim2.new(1, 0, 0, 0)
    popPanel.ClipsDescendants = true
    local isGlassPop = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
    popPanel.BackgroundColor3 = isGlassPop and Color3.fromRGB(18, 18, 26) or Color3.fromRGB(16, 16, 22)
    popPanel.BackgroundTransparency = isGlassPop and 0.25 or 0
    popPanel.BorderSizePixel = 0
    popPanel.Visible = false
    if hasCanvasGroup then popPanel.GroupTransparency = 1 end
    popPanel.LayoutOrder = 2
    popPanel.Parent = wrapper
    Crn(popPanel, 7)
    local popStroke = Strk(popPanel, Color3.fromRGB(36, 36, 50), 1, 0)
    if ConfigSystem and ConfigSystem.RegisterGlassCard then
        ConfigSystem.RegisterGlassCard(popPanel, popStroke, Color3.fromRGB(16, 16, 22))
    end

    local pPad = Instance.new("UIPadding")
    pPad.PaddingLeft = UDim.new(0, 8); pPad.PaddingRight = UDim.new(0, 8)
    pPad.PaddingTop = UDim.new(0, 8); pPad.PaddingBottom = UDim.new(0, 8)
    pPad.Parent = popPanel

    local pLL = Instance.new("UIListLayout")
    pLL.SortOrder = Enum.SortOrder.LayoutOrder
    pLL.Padding = UDim.new(0, 7)
    pLL.Parent = popPanel

    local svBox = Instance.new("Frame")
    svBox.Name = "SVCanvas"
    svBox.Size = UDim2.new(1, 0, 0, 130)
    svBox.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
    svBox.BorderSizePixel = 0
    svBox.ClipsDescendants = true
    svBox.LayoutOrder = 1
    svBox.Parent = popPanel
    Crn(svBox, 6)
    Strk(svBox, Color3.fromRGB(36, 36, 48), 1, 0)

    local satOverlay = Instance.new("Frame")
    satOverlay.Size = UDim2.new(1, 0, 1, 0)
    satOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    satOverlay.BorderSizePixel = 0
    satOverlay.ZIndex = 2
    satOverlay.Parent = svBox
    local satGrad = Instance.new("UIGradient")
    satGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    satGrad.Rotation = 0
    satGrad.Parent = satOverlay

    local valOverlay = Instance.new("Frame")
    valOverlay.Size = UDim2.new(1, 0, 1, 0)
    valOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    valOverlay.BorderSizePixel = 0
    valOverlay.ZIndex = 3
    valOverlay.Parent = svBox
    local valGrad = Instance.new("UIGradient")
    valGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0)
    })
    valGrad.Rotation = 90
    valGrad.Parent = valOverlay

    local svRing = Instance.new("Frame")
    svRing.Name = "DraggerRing"
    svRing.Size = UDim2.new(0, 14, 0, 14)
    svRing.AnchorPoint = Vector2.new(0.5, 0.5)
    svRing.Position = UDim2.new(curS, 0, 1 - curV, 0)
    svRing.BackgroundTransparency = 1
    svRing.BorderSizePixel = 0
    svRing.ZIndex = 5
    svRing.Parent = svBox
    Crn(svRing, 7)
    Strk(svRing, Color3.fromRGB(255, 255, 255), 2.5, 0)

    local svBtn = Instance.new("TextButton")
    svBtn.Size = UDim2.new(1, 0, 1, 0)
    svBtn.BackgroundTransparency = 1
    svBtn.Text = ""
    svBtn.ZIndex = 6
    svBtn.Parent = svBox

    local hueTrack = Instance.new("Frame")
    hueTrack.Name = "HueTrack"
    hueTrack.Size = UDim2.new(1, 0, 0, 12)
    hueTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueTrack.BorderSizePixel = 0
    hueTrack.LayoutOrder = 2
    hueTrack.Parent = popPanel
    Crn(hueTrack, 6)
    Strk(hueTrack, Color3.fromRGB(36, 36, 48), 1, 0)

    local hueGrad = Instance.new("UIGradient")
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
        ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
        ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
        ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
    })
    hueGrad.Parent = hueTrack

    local hueKnob = Instance.new("Frame")
    hueKnob.Name = "HueKnob"
    hueKnob.Size = UDim2.new(0, 10, 0, 18)
    hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    hueKnob.Position = UDim2.new(curH, 0, 0.5, 0)
    hueKnob.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
    hueKnob.BorderSizePixel = 0
    hueKnob.ZIndex = 5
    hueKnob.Parent = hueTrack
    Crn(hueKnob, 4)
    Strk(hueKnob, Color3.fromRGB(255, 255, 255), 2, 0)

    local hueBtn = Instance.new("TextButton")
    hueBtn.Size = UDim2.new(1, 0, 2.5, 0)
    hueBtn.Position = UDim2.new(0, 0, -0.75, 0)
    hueBtn.BackgroundTransparency = 1
    hueBtn.Text = ""
    hueBtn.ZIndex = 6
    hueBtn.Parent = hueTrack

    local botRow = Instance.new("Frame")
    botRow.Name = "BottomRow"
    botRow.Size = UDim2.new(1, 0, 0, 22)
    botRow.BackgroundTransparency = 1
    botRow.LayoutOrder = 3
    botRow.Parent = popPanel

    local bLL = Instance.new("UIListLayout")
    bLL.FillDirection = Enum.FillDirection.Horizontal
    bLL.SortOrder = Enum.SortOrder.LayoutOrder
    bLL.VerticalAlignment = Enum.VerticalAlignment.Center
    bLL.Padding = UDim.new(0, 5)
    bLL.Parent = botRow

    local hexTagBtn = Instance.new("Frame")
    hexTagBtn.Size = UDim2.new(0, 44, 0, 22)
    hexTagBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    hexTagBtn.BorderSizePixel = 0
    hexTagBtn.LayoutOrder = 1
    hexTagBtn.Parent = botRow
    Crn(hexTagBtn, 4)
    Strk(hexTagBtn, T.border, 1, 0)

    local hexTagLbl = Lbl(hexTagBtn, "HEX", 9, Color3.fromRGB(190, 195, 215), Enum.Font.Arcade, Enum.TextXAlignment.Center, 2)
    hexTagLbl.Size = UDim2.new(1, 0, 1, 0)

    local hexBoxFrame = Instance.new("Frame")
    hexBoxFrame.Size = showSync and UDim2.new(1, -106, 0, 22) or UDim2.new(1, -50, 0, 22)
    hexBoxFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    hexBoxFrame.BorderSizePixel = 0
    hexBoxFrame.LayoutOrder = 2
    hexBoxFrame.Parent = botRow
    Crn(hexBoxFrame, 4)
    local hexBoxStroke = Strk(hexBoxFrame, T.border, 1, 0)

    local miniSwatch = Instance.new("Frame")
    miniSwatch.Size = UDim2.new(0, 14, 0, 14)
    miniSwatch.Position = UDim2.new(0, 4, 0.5, -7)
    miniSwatch.BackgroundColor3 = curCol
    miniSwatch.BorderSizePixel = 0
    miniSwatch.Parent = hexBoxFrame
    Crn(miniSwatch, 3)

    local hexInput = Instance.new("TextBox")
    hexInput.Size = UDim2.new(1, -24, 1, 0)
    hexInput.Position = UDim2.new(0, 22, 0, 0)
    hexInput.BackgroundTransparency = 1
    hexInput.Font = Enum.Font.Code
    hexInput.Text = ConfigSystem.ColorToHex(curCol)
    hexInput.TextColor3 = Color3.fromRGB(240, 240, 255)
    hexInput.TextSize = 10
    hexInput.ClearTextOnFocus = false
    hexInput.PlaceholderText = "#HEX or R,G,B"
    hexInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    hexInput.TextXAlignment = Enum.TextXAlignment.Left
    hexInput.Parent = hexBoxFrame

    local syncPopBtn = nil
    if showSync then
        syncPopBtn = Instance.new("TextButton")
        syncPopBtn.Size = UDim2.new(0, 52, 0, 22)
        syncPopBtn.BackgroundColor3 = (getSync and getSync()) and T.accent or Color3.fromRGB(25, 25, 34)
        syncPopBtn.BorderSizePixel = 0
        syncPopBtn.Font = Enum.Font.Arcade
        syncPopBtn.Text = (getSync and getSync()) and "GUI: ON" or "Sync"
        syncPopBtn.TextColor3 = (getSync and getSync()) and Color3.fromRGB(255, 255, 255) or T.textMuted
        syncPopBtn.TextSize = 9
        syncPopBtn.AutoButtonColor = false
        syncPopBtn.LayoutOrder = 3
        syncPopBtn.Parent = botRow
        Crn(syncPopBtn, 4); Strk(syncPopBtn, T.border, 1, 0)
    end

    local function updateVisuals(isSync)
        swatchBtn.BackgroundColor3 = curCol
        miniSwatch.BackgroundColor3 = curCol
        svBox.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
        svRing.Position = UDim2.new(curS, 0, 1 - curV, 0)
        hueKnob.Position = UDim2.new(curH, 0, 0.5, 0)
        hueKnob.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
        if not hexInput:IsFocused() then
            hexInput.Text = ConfigSystem.ColorToHex(curCol)
        end
        local syncActive = isSync
        if syncActive == nil and getSync then syncActive = getSync() end
        if syncHeaderBtn then
            syncHeaderBtn.BackgroundColor3 = syncActive and T.accent or Color3.fromRGB(25, 25, 34)
            syncHeaderBtn.TextColor3 = syncActive and Color3.fromRGB(255, 255, 255) or T.textMuted
            syncHeaderBtn.Text = syncActive and "GUI" or "Custom"
        end
        if syncPopBtn then
            syncPopBtn.BackgroundColor3 = syncActive and T.accent or Color3.fromRGB(25, 25, 34)
            syncPopBtn.TextColor3 = syncActive and Color3.fromRGB(255, 255, 255) or T.textMuted
            syncPopBtn.Text = syncActive and "GUI: ON" or "Sync"
        end
    end

    local isSvDragging = false
    local function updateFromSV(x, y)
        local boxPos = svBox.AbsolutePosition
        local boxSize = svBox.AbsoluteSize
        if boxSize.X <= 0 or boxSize.Y <= 0 then return end
        local relX = math.clamp((x - boxPos.X) / boxSize.X, 0, 1)
        local relY = math.clamp((y - boxPos.Y) / boxSize.Y, 0, 1)
        curS = relX
        curV = 1 - relY
        curCol = Color3.fromHSV(curH, curS, curV)
        if setSync then setSync(false) end
        updateVisuals(false)
        setCol(curCol)
    end

    svBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSvDragging = true
            updateFromSV(input.Position.X, input.Position.Y)
        end
    end)

    table.insert(allConn, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isSvDragging then
                isSvDragging = false
                if SaveConfig then SaveConfig() end
            end
        end
    end))

    table.insert(allConn, UIS.InputChanged:Connect(function(input)
        if isSvDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromSV(input.Position.X, input.Position.Y)
        end
    end))

    local isHueDragging = false
    local function updateFromHue(x)
        local trackPos = hueTrack.AbsolutePosition
        local trackSize = hueTrack.AbsoluteSize
        if trackSize.X <= 0 then return end
        local relX = math.clamp((x - trackPos.X) / trackSize.X, 0, 1)
        curH = relX
        curCol = Color3.fromHSV(curH, curS, curV)
        if setSync then setSync(false) end
        updateVisuals(false)
        setCol(curCol)
    end

    hueBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isHueDragging = true
            updateFromHue(input.Position.X)
        end
    end)

    table.insert(allConn, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isHueDragging then
                isHueDragging = false
                if SaveConfig then SaveConfig() end
            end
        end
    end))

    table.insert(allConn, UIS.InputChanged:Connect(function(input)
        if isHueDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromHue(input.Position.X)
        end
    end))

    hexInput.Focused:Connect(function()
        Tw(hexBoxStroke, {Color = T.accent}, 0.15)
    end)

    hexInput.FocusLost:Connect(function()
        Tw(hexBoxStroke, {Color = T.border}, 0.15)
        local raw = hexInput.Text
        local parsed = ConfigSystem.ParseColor(raw)
        if parsed then
            if setSync then setSync(false) end
            curCol = parsed
            curH, curS, curV = Color3.toHSV(curCol)
            updateVisuals(false)
            setCol(curCol)
            if SaveConfig then SaveConfig() end
        else
            hexInput.Text = ConfigSystem.ColorToHex(curCol)
        end
    end)

    local isPopOpen = false
    local isPopBusy = false
    local function togglePopup()
        if isPopBusy then return end
        isPopOpen = not isPopOpen
        isPopBusy = true

        Tw(swatchBtn, {Size = UDim2.new(0, 16, 0, 16)}, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.07, function()
            Tw(swatchBtn, {Size = UDim2.new(0, 20, 0, 20)}, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)

        local sStrk = swatchBtn:FindFirstChildOfClass("UIStroke")
        if sStrk then
            Tw(sStrk, {Color = isPopOpen and Color3.fromRGB(240, 240, 255) or Color3.fromRGB(45, 45, 60)}, 0.18)
        end

        if isPopOpen then
            popPanel.Visible = true
            popPanel.Size = UDim2.new(1, 0, 0, 0)
            if hasCanvasGroup then
                popPanel.GroupTransparency = 1
                Tw(popPanel, {GroupTransparency = 0, Size = UDim2.new(1, 0, 0, 190)}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            else
                Tw(popPanel, {Size = UDim2.new(1, 0, 0, 190)}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            end
            task.delay(0.25, function()
                isPopBusy = false
            end)
        else
            if hasCanvasGroup then
                Tw(popPanel, {GroupTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            else
                Tw(popPanel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.delay(0.19, function()
                if not isPopOpen then
                    popPanel.Visible = false
                end
                isPopBusy = false
            end)
        end
    end
    swatchBtn.MouseButton1Click:Connect(togglePopup)
    hClickBtn.MouseButton1Click:Connect(togglePopup)

    local function toggleSync()
        local newState = not (getSync and getSync())
        if setSync then setSync(newState) end
        if newState then
            curCol = T.accent
            curH, curS, curV = Color3.toHSV(curCol)
            setCol(curCol)
            updateVisuals(true)
        else
            updateVisuals(false)
        end
        if SaveConfig then SaveConfig() end
    end

    if syncHeaderBtn then
        syncHeaderBtn.MouseButton1Click:Connect(toggleSync)
    end
    if syncPopBtn then
        syncPopBtn.MouseButton1Click:Connect(toggleSync)
    end

    local pickerObj = {
        update = function(newCol, isSync)
            if newCol then
                curCol = newCol
                curH, curS, curV = Color3.toHSV(newCol)
            else
                curCol = getCol()
                curH, curS, curV = Color3.toHSV(curCol)
            end
            updateVisuals(isSync)
        end
    }

    return pickerObj
end

ConfigSystem.openDropdownCloser = nil

ConfigSystem.CreateDropdown = function(parentCol, order, labelText, options, getCurVal, setCurVal)
    local ddContainer = Instance.new("Frame")
    ddContainer.Size = UDim2.new(1, 0, 0, 52)
    ddContainer.BackgroundTransparency = 1
    ddContainer.LayoutOrder = order or 1
    ddContainer.ClipsDescendants = false
    ddContainer.ZIndex = 15
    ddContainer.Parent = parentCol

    local headerLbl = Lbl(ddContainer, labelText, 11, T.secHeader, Enum.Font.GothamMedium, Enum.TextXAlignment.Left, 16)
    headerLbl.Size = UDim2.new(1, 0, 0, 18)
    headerLbl.Position = UDim2.new(0, 0, 0, 0)
    if ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.RegisterLabel(headerLbl, labelText, true)
    end

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(1, 0, 0, 28)
    box.Position = UDim2.new(0, 0, 0, 22)
    box.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    box.BorderSizePixel = 0
    box.AutoButtonColor = false
    box.Text = ""
    box.ZIndex = 16
    box.Parent = ddContainer
    Crn(box, 6)
    local boxStroke = Strk(box, T.border, 1, 0)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, -30, 1, 0)
    valLbl.Position = UDim2.new(0, 10, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 11
    valLbl.TextColor3 = Color3.fromRGB(220, 220, 235)
    valLbl.TextXAlignment = Enum.TextXAlignment.Left
    valLbl.ZIndex = 17
    valLbl.Parent = box

    local arrowLbl = Instance.new("TextLabel")
    arrowLbl.Size = UDim2.new(0, 16, 0, 16)
    arrowLbl.AnchorPoint = Vector2.new(0.5, 0.5)
    arrowLbl.Position = UDim2.new(1, -14, 0.5, 0)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.Font = Enum.Font.GothamBold
    arrowLbl.TextSize = 10
    arrowLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
    arrowLbl.Text = "▼"
    arrowLbl.ZIndex = 17
    arrowLbl.Parent = box

    local itemH = 26
    local maxVisible = math.min(#options, 7)
    local listH = maxVisible * itemH + 8

    local menuF = Instance.new("Frame")
    menuF.Size = UDim2.new(1, 0, 0, 0)
    menuF.Position = UDim2.new(0, 0, 0, 54)
    menuF.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    menuF.BorderSizePixel = 0
    menuF.Visible = false
    menuF.ZIndex = 25
    menuF.ClipsDescendants = true
    menuF.Parent = ddContainer
    Crn(menuF, 8)
    local curIsGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
    local curIsLight = (ConfigSystem and ConfigSystem.savedMenuTheme == "Light")
    local initBorderCol = curIsGlass and Color3.fromRGB(36, 36, 42) or (curIsLight and Color3.fromRGB(210, 214, 225) or Color3.fromRGB(42, 42, 52))
    local menuStroke = Strk(menuF, initBorderCol, 1, curIsGlass and 0.45 or 0)

    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, -4, 1, -8)
    sf.Position = UDim2.new(0, 2, 0, 4)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = T.accent
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.ZIndex = 26
    sf.Parent = menuF
    TrackAccent(sf, "ScrollBarImageColor3")

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 2); pad.PaddingBottom = UDim.new(0, 2)
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = sf

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 2)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = sf

    local optBtns = {}
    local function refreshSelection()
        local raw = getCurVal()
        local curText = raw
        for _, opt in ipairs(options) do
            local oVal = (type(opt) == "table" and (opt.val or opt.value)) or opt
            local oLbl = (type(opt) == "table" and opt.label) or opt
            if oVal == raw or oLbl == raw then
                curText = oLbl
                break
            end
        end
        valLbl.Text = tostring(curText)

        for _, item in ipairs(optBtns) do
            local isSel = (item.val == raw or item.label == raw)
            item.btn.BackgroundColor3 = isSel and T.accent or Color3.fromRGB(24, 24, 32)
            item.btn.BackgroundTransparency = isSel and 0 or 1
            item.lbl.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 180)
            item.lbl.Font = isSel and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end
    end

    local isOpen = false
    local function toggleMenu(open)
        if open == isOpen then return end
        isOpen = open
        if isOpen then
            if ConfigSystem.openDropdownCloser and ConfigSystem.openDropdownCloser ~= toggleMenu then
                pcall(ConfigSystem.openDropdownCloser, false)
            end
            ConfigSystem.openDropdownCloser = toggleMenu
            menuF.Visible = true
            ddContainer.ZIndex = 35
            menuF.ZIndex = 36
            Tw(ddContainer, {Size = UDim2.new(1, 0, 0, 54 + listH + 4)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tw(menuF, {Size = UDim2.new(1, 0, 0, listH)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tw(arrowLbl, {Rotation = 180, TextColor3 = T.accent}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tw(boxStroke, {Color = T.accent}, 0.15)
        else
            if ConfigSystem.openDropdownCloser == toggleMenu then
                ConfigSystem.openDropdownCloser = nil
            end
            Tw(ddContainer, {Size = UDim2.new(1, 0, 0, 52)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tw(menuF, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tw(arrowLbl, {Rotation = 0, TextColor3 = Color3.fromRGB(140, 140, 160)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            local isLight = (ConfigSystem and ConfigSystem.savedMenuTheme == "Light")
            local bCol = isGlass and Color3.fromRGB(36, 36, 42) or (isLight and Color3.fromRGB(210, 214, 225) or Color3.fromRGB(42, 42, 52))
            Tw(boxStroke, {Color = bCol}, 0.15)
            task.delay(0.19, function()
                if not isOpen then
                    menuF.Visible = false
                    ddContainer.ZIndex = 15
                end
            end)
        end
    end

    box.MouseButton1Click:Connect(function()
        toggleMenu(not isOpen)
    end)
    box.MouseEnter:Connect(function()
        if not isOpen then Tw(boxStroke, {Color = T.accent}, 0.12) end
    end)
    box.MouseLeave:Connect(function()
        if not isOpen then
            local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            local isLight = (ConfigSystem and ConfigSystem.savedMenuTheme == "Light")
            local bCol = isGlass and Color3.fromRGB(36, 36, 42) or (isLight and Color3.fromRGB(210, 214, 225) or Color3.fromRGB(42, 42, 52))
            Tw(boxStroke, {Color = bCol}, 0.12)
        end
    end)

    for i, opt in ipairs(options) do
        local oVal = (type(opt) == "table" and (opt.val or opt.value)) or opt
        local oLbl = (type(opt) == "table" and opt.label) or opt

        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.LayoutOrder = i
        optBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
        optBtn.BackgroundTransparency = 1
        optBtn.BorderSizePixel = 0
        optBtn.Text = ""
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 27
        optBtn.Parent = sf
        Crn(optBtn, 4)

        local optLbl = Instance.new("TextLabel")
        optLbl.Size = UDim2.new(1, -12, 1, 0)
        optLbl.Position = UDim2.new(0, 8, 0, 0)
        optLbl.BackgroundTransparency = 1
        optLbl.Font = Enum.Font.GothamMedium
        optLbl.TextSize = 10
        optLbl.TextColor3 = Color3.fromRGB(160, 160, 180)
        optLbl.TextXAlignment = Enum.TextXAlignment.Left
        optLbl.Text = tostring(oLbl)
        optLbl.ZIndex = 28
        optLbl.Parent = optBtn

        optBtn.MouseEnter:Connect(function()
            local raw = getCurVal()
            if oVal ~= raw and oLbl ~= raw then
                Tw(optBtn, {BackgroundTransparency = 0.85, BackgroundColor3 = T.accent}, 0.1)
                Tw(optLbl, {TextColor3 = Color3.fromRGB(240, 240, 255)}, 0.1)
            end
        end)
        optBtn.MouseLeave:Connect(function()
            local raw = getCurVal()
            if oVal ~= raw and oLbl ~= raw then
                Tw(optBtn, {BackgroundTransparency = 1}, 0.1)
                Tw(optLbl, {TextColor3 = Color3.fromRGB(160, 160, 180)}, 0.1)
            end
        end)
        optBtn.MouseButton1Click:Connect(function()
            setCurVal(oVal, oLbl)
            refreshSelection()
            toggleMenu(false)
        end)

        table.insert(optBtns, {btn = optBtn, lbl = optLbl, val = oVal, label = oLbl})
    end

    local function updateDDTheme()
        local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
        local isLight = (ConfigSystem and ConfigSystem.savedMenuTheme == "Light")
        local bCol = isGlass and Color3.fromRGB(36, 36, 42) or (isLight and Color3.fromRGB(210, 214, 225) or Color3.fromRGB(42, 42, 52))
        box.BackgroundColor3 = isGlass and Color3.fromRGB(26, 26, 36) or (isLight and Color3.fromRGB(240, 242, 248) or Color3.fromRGB(24, 24, 32))
        box.BackgroundTransparency = isGlass and 0.70 or 0
        boxStroke.Color = bCol
        boxStroke.Transparency = isGlass and 0.45 or 0
        menuF.BackgroundColor3 = isGlass and Color3.fromRGB(18, 18, 26) or (isLight and Color3.fromRGB(248, 249, 253) or Color3.fromRGB(18, 18, 25))
        menuF.BackgroundTransparency = isGlass and 0.25 or 0
        menuStroke.Color = bCol
        menuStroke.Transparency = isGlass and 0.45 or 0
        refreshSelection()
    end
    updateDDTheme()
    if ConfigSystem and ConfigSystem.themeRefreshers then
        table.insert(ConfigSystem.themeRefreshers, updateDDTheme)
    end
    if ConfigSystem and ConfigSystem.pillRefreshers then
        table.insert(ConfigSystem.pillRefreshers, refreshSelection)
    end

    refreshSelection()
    return {refresh = refreshSelection, container = ddContainer}
end


-- ══════════════════════════════════════════════
--  POPULATE TABS (Modular builders to prevent Luau register exhaustion)
-- ══════════════════════════════════════════════

local function PopulateTabs()
    local function BuildCombatTab()
        -- COMBAT
        AddSection("Combat","left","Aim Assist")
        AddToggle("Combat","left","Aim Assist", false, function(v) SetAimbot(v) end)
        AddToggle("Combat","left","Visible Check", Aim.visibleCheck, function(v)
            Aim.visibleCheck = v
        end)
        AddToggle("Combat","left","Alive Check (Da Hood)", Aim.healthCheck, function(v)
            Aim.healthCheck = v
        end)
        AddToggle("Combat","left","No Recoil (Mad Hood)", Aim.noRecoil, function(v)
            if Aim.SetNoRecoil then Aim.SetNoRecoil(v) end
        end)
        AddToggle("Combat","left","Sticky Aim", Aim.stickyAim, function(v)
            Aim.stickyAim = v
        end)
        AddToggle("Combat","left","Show FOV Circle", Aim.showFov, function(v)
            Aim.showFov = v
            UpdateFovVisual()
        end)
        AddToggle("Combat","left","Prediction", Aim.predict, function(v)
            Aim.predict = v
        end)

        do
            local pg = tabPages["Combat"]
            local col = pg.leftSF
            pg.lOrder += 1

            local aimCard = Instance.new("Frame")
            aimCard.Name = "AimControlsCard"
            aimCard.Size = UDim2.new(1, 0, 0, 0)
            aimCard.AutomaticSize = Enum.AutomaticSize.Y
            aimCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            aimCard.BorderSizePixel = 0
            aimCard.LayoutOrder = pg.lOrder
            aimCard.Parent = col
            Crn(aimCard, 6)
            local aimStroke = Strk(aimCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(aimCard, aimStroke, Color3.fromRGB(18, 18, 25))
            end

            local cardPad = Instance.new("UIPadding")
            cardPad.PaddingLeft = UDim.new(0, 8)
            cardPad.PaddingRight = UDim.new(0, 8)
            cardPad.PaddingTop = UDim.new(0, 7)
            cardPad.PaddingBottom = UDim.new(0, 7)
            cardPad.Parent = aimCard

            local cardLL = Instance.new("UIListLayout")
            cardLL.SortOrder = Enum.SortOrder.LayoutOrder
            cardLL.Padding = UDim.new(0, 5)
            cardLL.Parent = aimCard

            local cardHeader = Instance.new("Frame")
            cardHeader.Size = UDim2.new(1, 0, 0, 14)
            cardHeader.BackgroundTransparency = 1
            cardHeader.LayoutOrder = 1
            cardHeader.Parent = aimCard

            local cardTitle = Lbl(cardHeader, "AIM SETTINGS", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cardTitle.Size = UDim2.new(1, 0, 1, 0)
            if ConfigSystem then
                if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
                table.insert(ConfigSystem.themeSections, cardTitle)
                if ConfigSystem.Localization then
                    ConfigSystem.Localization.RegisterLabel(cardTitle, "AIM SETTINGS", true)
                end
            end

            local function AddCardSep(order)
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 3)
                sep.BackgroundTransparency = 1
                sep.LayoutOrder = order
                sep.Parent = aimCard
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -12, 0, 1)
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Position = UDim2.new(0.5, 0, 0.5, 0)
                line.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
                line.BorderSizePixel = 0
                line.Parent = sep
            end

            -- FOV Radius Slider (30 to 800)
            CreateSlider(aimCard, 2, "FOV Radius", 30, 800, Aim.fov, function(v)
                Aim.fov = v
                UpdateFovVisual()
            end, false)

            AddCardSep(3)

            -- Max Distance Slider (50 to 2000)
            CreateSlider(aimCard, 4, "Distance", 50, 2000, Aim.maxDistance or 500, function(v)
                Aim.maxDistance = v
            end, false)

            AddCardSep(5)

            -- Smoothness / Sensitivity Slider (5 to 100)
            CreateSlider(aimCard, 6, "Sensitivity %", 5, 100, math.floor(Aim.smooth * 100 + 0.5), function(v)
                Aim.smooth = v / 100
            end, false)

            AddCardSep(7)

            -- Prediction X Slider (0.00 to 0.40)
            CreateSlider(aimCard, 8, "Prediction X", 0.00, 0.40, Aim.predictX, function(v)
                Aim.predictX = v
                Aim.predictAmount = v
            end, true, "Aim Prediction X")

            AddCardSep(9)

            -- Prediction Y Slider (0.00 to 0.40)
            CreateSlider(aimCard, 10, "Prediction Y", 0.00, 0.40, Aim.predictY, function(v)
                Aim.predictY = v
            end, true, "Aim Prediction Y")

            AddCardSep(11)

            -- Pill Selector Helper
            local function CreatePillSelector(order, labelText, options, getCurrent, onSelect)
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 26)
                row.BackgroundTransparency = 1
                row.LayoutOrder = order
                row.Parent = aimCard

                local lbl = Lbl(row, labelText, 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
                lbl.Size = UDim2.new(0, 65, 1, 0)
                lbl.Position = UDim2.new(0, 2, 0, 0)

                local btnContainer = Instance.new("Frame")
                btnContainer.Size = UDim2.new(1, -68, 1, 0)
                btnContainer.Position = UDim2.new(0, 68, 0, 0)
                btnContainer.BackgroundTransparency = 1
                btnContainer.Parent = row

                local btnLL = Instance.new("UIListLayout")
                btnLL.FillDirection = Enum.FillDirection.Horizontal
                btnLL.HorizontalAlignment = Enum.HorizontalAlignment.Right
                btnLL.SortOrder = Enum.SortOrder.LayoutOrder
                btnLL.Padding = UDim.new(0, 4)
                btnLL.Parent = btnContainer

                local pillBtns = {}
                local function refreshPills()
                    local cur = getCurrent()
                    for val, pBtn in pairs(pillBtns) do
                        local isSel = (cur == val)
                        pBtn.BackgroundColor3 = isSel and T.accent or Color3.fromRGB(22, 22, 30)
                        pBtn.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or T.textMuted
                    end
                end

                for idx, opt in ipairs(options) do
                    local pBtn = Instance.new("TextButton")
                    pBtn.Size = UDim2.new(0, opt.w or 42, 0, 22)
                    pBtn.AnchorPoint = Vector2.new(0, 0.5)
                    pBtn.Position = UDim2.new(0, 0, 0.5, 0)
                    pBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
                    pBtn.BorderSizePixel = 0
                    pBtn.AutoButtonColor = false
                    pBtn.Font = Enum.Font.Arcade
                    pBtn.TextSize = 10
                    pBtn.Text = opt.label
                    pBtn.TextColor3 = T.textMuted
                    pBtn.LayoutOrder = idx
                    pBtn.Parent = btnContainer
                    Crn(pBtn, 4)
                    Strk(pBtn, T.border, 1, 0)

                    pillBtns[opt.value] = pBtn

                    pBtn.MouseButton1Click:Connect(function()
                        onSelect(opt.value)
                        refreshPills()
                        if SaveConfig then SaveConfig() end
                    end)
                end
                refreshPills()
                if ConfigSystem and ConfigSystem.pillRefreshers then
                    table.insert(ConfigSystem.pillRefreshers, refreshPills)
                end
            end

            -- Hit Part Dropdown (Head, Torso, Nearest, Limbs, HRP)
            local hitPartDD = ConfigSystem.CreateDropdown(aimCard, 12, "Hit Part", {
                {label = "Head", value = "Head"},
                {label = "Torso", value = "Torso"},
                {label = "Nearest", value = "Nearest"},
                {label = "Limbs", value = "Limbs"},
                {label = "HRP", value = "HumanoidRootPart"},
            }, function()
                return Aim.hitPart or "Head"
            end, function(v)
                Aim.hitPart = v
                if SaveConfig then SaveConfig() end
            end)
            if not ConfigSystem.pillRefreshers then ConfigSystem.pillRefreshers = {} end
            table.insert(ConfigSystem.pillRefreshers, function()
                if hitPartDD and hitPartDD.refresh then hitPartDD.refresh() end
            end)

            AddCardSep(13)

            -- Aim Type (Camera, Mouse)
            CreatePillSelector(14, "Aim Type", {
                {label = "Camera", value = "Camera", w = 52},
                {label = "Mouse", value = "Mouse", w = 46},
            }, function() return Aim.aimType or "Camera" end, function(v) Aim.aimType = v end)
        end

        -- TRIGGERBOT (Right Column)
        AddSection("Combat","right","Triggerbot")
        AddToggle("Combat","right","Triggerbot", false, function(v) SetTriggerbot(v) end)
        AddToggle("Combat","right","Target Lead Circle", Triggerbot.showTargetCircle, function(v)
            Triggerbot.showTargetCircle = v
            if Triggerbot.UpdateConnection then Triggerbot.UpdateConnection() end
            SaveConfig()
        end)
        AddToggle("Combat","right","Show Hitbox FOV", Triggerbot.showFov, function(v)
            Triggerbot.showFov = v
            if Triggerbot.UpdateFovVisual then Triggerbot.UpdateFovVisual() end
            SaveConfig()
        end)
        AddToggle("Combat","right","Trigger Prediction", Triggerbot.predict, function(v)
            Triggerbot.predict = v
            SaveConfig()
        end)
        AddToggle("Combat","right","Trigger Visible Check", Triggerbot.visibleCheck, function(v)
            Triggerbot.visibleCheck = v
            SaveConfig()
        end)
        AddToggle("Combat","right","Trigger Alive Check", Triggerbot.healthCheck, function(v)
            Triggerbot.healthCheck = v
            SaveConfig()
        end)

        do
            local pg = tabPages["Combat"]
            local col = pg.rightSF
            pg.rOrder += 1

            local trigCard = Instance.new("Frame")
            trigCard.Name = "TriggerbotControlsCard"
            trigCard.Size = UDim2.new(1, 0, 0, 0)
            trigCard.AutomaticSize = Enum.AutomaticSize.Y
            trigCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            trigCard.BorderSizePixel = 0
            trigCard.LayoutOrder = pg.rOrder
            trigCard.Parent = col
            Crn(trigCard, 6)
            local trigStroke = Strk(trigCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(trigCard, trigStroke, Color3.fromRGB(18, 18, 25))
            end

            local cardPad = Instance.new("UIPadding")
            cardPad.PaddingLeft = UDim.new(0, 8)
            cardPad.PaddingRight = UDim.new(0, 8)
            cardPad.PaddingTop = UDim.new(0, 7)
            cardPad.PaddingBottom = UDim.new(0, 7)
            cardPad.Parent = trigCard

            local cardLL = Instance.new("UIListLayout")
            cardLL.SortOrder = Enum.SortOrder.LayoutOrder
            cardLL.Padding = UDim.new(0, 5)
            cardLL.Parent = trigCard

            local cardHeader = Instance.new("Frame")
            cardHeader.Size = UDim2.new(1, 0, 0, 14)
            cardHeader.BackgroundTransparency = 1
            cardHeader.LayoutOrder = 1
            cardHeader.Parent = trigCard

            local cardTitle = Lbl(cardHeader, "TRIGGERBOT SETTINGS", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cardTitle.Size = UDim2.new(1, 0, 1, 0)
            if ConfigSystem then
                if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
                table.insert(ConfigSystem.themeSections, cardTitle)
                if ConfigSystem.Localization then
                    ConfigSystem.Localization.RegisterLabel(cardTitle, "TRIGGERBOT SETTINGS", true)
                end
            end

            local function AddCardSep(order)
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 3)
                sep.BackgroundTransparency = 1
                sep.LayoutOrder = order
                sep.Parent = trigCard
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -12, 0, 1)
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Position = UDim2.new(0.5, 0, 0.5, 0)
                line.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
                line.BorderSizePixel = 0
                line.Parent = sep
            end

            -- Hitbox FOV / Tolerance Slider (5 to 80 px)
            CreateSlider(trigCard, 2, "Hitbox FOV", 5, 80, Triggerbot.tolerance or 14, function(v)
                Triggerbot.tolerance = v
                if Triggerbot.UpdateFovVisual then Triggerbot.UpdateFovVisual() end
            end, false, "Trigger Tolerance")

            AddCardSep(3)

            -- Max Distance Slider (50 to 2000)
            CreateSlider(trigCard, 4, "Distance", 50, 2000, Triggerbot.maxDistance or 500, function(v)
                Triggerbot.maxDistance = v
            end, false, "Trigger Distance")

            AddCardSep(5)

            -- Reaction Delay (0 to 150 ms)
            CreateSlider(trigCard, 6, "Delay (ms)", 0, 150, Triggerbot.delay or 0, function(v)
                Triggerbot.delay = v
            end, false, "Trigger Delay")

            AddCardSep(7)

            -- Prediction X Slider (0.00 to 0.40)
            CreateSlider(trigCard, 8, "Prediction X", 0.00, 0.40, Triggerbot.predictX, function(v)
                Triggerbot.predictX = v
                Triggerbot.predictAmount = v
            end, true, "Trigger Prediction X")

            AddCardSep(9)

            -- Prediction Y Slider (0.00 to 0.40)
            CreateSlider(trigCard, 10, "Prediction Y", 0.00, 0.40, Triggerbot.predictY, function(v)
                Triggerbot.predictY = v
            end, true, "Trigger Prediction Y")
        end

    end
    BuildCombatTab()

    local function BuildMovementTab()
        -- MOVEMENT
        AddSection("Movement","left","Flight & Speed")
        AddToggle("Movement","left","Fly", false, function(v) SetFly(v) end)
        AddToggle("Movement","left","Speed Boost", false, function(v) SetSpeed(v) end)

        -- Speed Controls Card (Плашка настройки скорости)
        do
            local pg = tabPages["Movement"]
            local col = pg.leftSF
            pg.lOrder += 1

            local speedCard = Instance.new("Frame")
            speedCard.Name = "SpeedControlsCard"
            speedCard.Size = UDim2.new(1, 0, 0, 0)
            speedCard.AutomaticSize = Enum.AutomaticSize.Y
            speedCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            speedCard.BorderSizePixel = 0
            speedCard.LayoutOrder = pg.lOrder
            speedCard.Parent = col
            Crn(speedCard, 6)
            local speedStroke = Strk(speedCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(speedCard, speedStroke, Color3.fromRGB(18, 18, 25))
            end

            local cardPad = Instance.new("UIPadding")
            cardPad.PaddingLeft = UDim.new(0, 8)
            cardPad.PaddingRight = UDim.new(0, 8)
            cardPad.PaddingTop = UDim.new(0, 7)
            cardPad.PaddingBottom = UDim.new(0, 7)
            cardPad.Parent = speedCard

            local cardLL = Instance.new("UIListLayout")
            cardLL.SortOrder = Enum.SortOrder.LayoutOrder
            cardLL.Padding = UDim.new(0, 5)
            cardLL.Parent = speedCard

            -- Card Header Label
            local cardHeader = Instance.new("Frame")
            cardHeader.Size = UDim2.new(1, 0, 0, 14)
            cardHeader.BackgroundTransparency = 1
            cardHeader.LayoutOrder = 1
            cardHeader.Parent = speedCard

            local cardTitle = Lbl(cardHeader, "SPEED SETTINGS", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cardTitle.Size = UDim2.new(1, 0, 1, 0)
            if ConfigSystem then
                if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
                table.insert(ConfigSystem.themeSections, cardTitle)
                if ConfigSystem.Localization then
                    ConfigSystem.Localization.RegisterLabel(cardTitle, "SPEED SETTINGS", true)
                end
            end

            -- Fly Speed Slider (10 to 300)
            CreateSlider(speedCard, 2, "Fly Speed", 10, 300, flySpeed, function(v)
                flySpeed = v
            end)

            -- Separator line (not reaching the ends)
            local cardSep = Instance.new("Frame")
            cardSep.Size = UDim2.new(1, 0, 0, 3)
            cardSep.BackgroundTransparency = 1
            cardSep.BorderSizePixel = 0
            cardSep.LayoutOrder = 3
            cardSep.Parent = speedCard

            local sepLine = Instance.new("Frame")
            sepLine.Size = UDim2.new(1, -12, 0, 1)
            sepLine.AnchorPoint = Vector2.new(0.5, 0.5)
            sepLine.Position = UDim2.new(0.5, 0, 0.5, 0)
            sepLine.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
            sepLine.BorderSizePixel = 0
            sepLine.Parent = cardSep

            -- Walk Speed Slider (16 to 250)
            CreateSlider(speedCard, 4, "Walk Speed", 16, 250, speedBoostValue, function(v)
                speedBoostValue = v
                if speedBoostEnabled and LP.Character then
                    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = v end
                end
            end)
        end

        AddSection("Movement","right","Physics")
        AddToggle("Movement","right","Noclip", false, function(v) SetNoclip(v) end)
        AddToggle("Movement","right","Infinite Jump", false, function(v) SetInfiniteJump(v) end)
    end
    BuildMovementTab()

    local function BuildVisualsTab()
        local CreateColorPicker = ConfigSystem.CreateColorPicker
        local chPicker, dmgPicker = nil, nil

        -- VISUALS
        AddSection("Visuals","left","Weather")
        if not weatherToggles then weatherToggles = {} end
        weatherToggles["Snow"] = AddToggle("Visuals","left","Map Snow",false, function(v) SetWeather("Snow", v) end)
        weatherToggles["Rain"] = AddToggle("Visuals","left","Map Rain",false, function(v) SetWeather("Rain", v) end)
        weatherToggles["Thunderstorm"] = AddToggle("Visuals","left","Thunderstorm",false, function(v) SetWeather("Thunderstorm", v) end)
        weatherToggles["Sandstorm"] = AddToggle("Visuals","left","Sandstorm",false, function(v) SetWeather("Sandstorm", v) end)

        AddSection("Visuals", "left", "Custom Crosshair")
        AddToggle("Visuals", "left", "Custom Crosshair", Crosshair.enabled, function(v)
            Crosshair.enabled = v
            if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
            SaveConfig()
        end)
        AddToggle("Visuals", "left", "Follow Mouse", Crosshair.followMouse, function(v)
            Crosshair.followMouse = v
            SaveConfig()
        end)
        AddToggle("Visuals", "left", "Spin Animation", Crosshair.spin, function(v)
            Crosshair.spin = v
            SaveConfig()
        end)
        AddToggle("Visuals", "left", "Center Dot", Crosshair.dot, function(v)
            Crosshair.dot = v
            if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
            SaveConfig()
        end)

        do
            local pg = tabPages["Visuals"]
            local col = pg.leftSF
            pg.lOrder += 1

            local chCard = Instance.new("Frame")
            chCard.Name = "CrosshairControlsCard"
            chCard.Size = UDim2.new(1, 0, 0, 0)
            chCard.AutomaticSize = Enum.AutomaticSize.Y
            chCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            chCard.BorderSizePixel = 0
            chCard.LayoutOrder = pg.lOrder
            chCard.Parent = col
            Crn(chCard, 6)
            local chStroke = Strk(chCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(chCard, chStroke, Color3.fromRGB(18, 18, 25))
            end

            local cardPad = Instance.new("UIPadding")
            cardPad.PaddingLeft = UDim.new(0, 8); cardPad.PaddingRight = UDim.new(0, 8)
            cardPad.PaddingTop = UDim.new(0, 7); cardPad.PaddingBottom = UDim.new(0, 7)
            cardPad.Parent = chCard

            local cardLL = Instance.new("UIListLayout")
            cardLL.SortOrder = Enum.SortOrder.LayoutOrder
            cardLL.Padding = UDim.new(0, 5)
            cardLL.Parent = chCard

            local cardHeader = Instance.new("Frame")
            cardHeader.Size = UDim2.new(1, 0, 0, 14)
            cardHeader.BackgroundTransparency = 1
            cardHeader.LayoutOrder = 1
            cardHeader.Parent = chCard

            local cardTitle = Lbl(cardHeader, "CROSSHAIR SETTINGS", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cardTitle.Size = UDim2.new(1, 0, 1, 0)
            if ConfigSystem then
                if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
                table.insert(ConfigSystem.themeSections, cardTitle)
                if ConfigSystem.Localization then
                    ConfigSystem.Localization.RegisterLabel(cardTitle, "CROSSHAIR SETTINGS", true)
                end
            end

            local function AddChSep(order)
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 3)
                sep.BackgroundTransparency = 1
                sep.LayoutOrder = order
                sep.Parent = chCard
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -12, 0, 1)
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Position = UDim2.new(0.5, 0, 0.5, 0)
                line.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
                line.BorderSizePixel = 0
                line.Parent = sep
            end

            CreateSlider(chCard, 2, "Crosshair Size", 4, 35, Crosshair.size, function(v)
                Crosshair.size = v
                if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
            end, false)

            AddChSep(3)

            CreateSlider(chCard, 4, "Crosshair Gap", 0, 25, Crosshair.gap, function(v)
                Crosshair.gap = v
                if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
            end, false)

            AddChSep(5)

            CreateSlider(chCard, 6, "Crosshair Thickness", 1, 6, Crosshair.thickness, function(v)
                Crosshair.thickness = v
                if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
            end, false)

            AddChSep(7)

            CreateSlider(chCard, 8, "Spin Speed", 20, 600, Crosshair.spinSpeed, function(v)
                Crosshair.spinSpeed = v
            end, false)

            AddChSep(9)

            -- Custom Color Selection via Color Picker
            chPicker = CreateColorPicker(chCard, 10, "Crosshair Color",
                function()
                    return Crosshair.color or Color3.fromRGB(0, 255, 140)
                end,
                function(newCol)
                    Crosshair.color = newCol
                    Crosshair.useAccent = false
                    if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
                    SaveConfig()
                end,
                true,
                function()
                    return Crosshair.useAccent
                end,
                function(isSync)
                    Crosshair.useAccent = isSync
                    if Crosshair.UpdateVisuals then Crosshair.UpdateVisuals() end
                    SaveConfig()
                end
            )
        end

        AddSection("Visuals","right","ESP")
        AddToggle("Visuals","right","Player ESP", false, function(v) SetPlayerESP(v) end)
        AddToggle("Visuals","right","Boxes", true, function(v) ESP.box = v; if ESP.enabled then RefreshAllESP() end end)
        AddToggle("Visuals","right","Health Bar", true, function(v) ESP.health = v; if ESP.enabled then RefreshAllESP() end end)
        AddToggle("Visuals","right","Names", true, function(v) ESP.name = v; if ESP.enabled then RefreshAllESP() end end)
        AddToggle("Visuals","right","Distance", true, function(v) ESP.dist = v; if ESP.enabled then RefreshAllESP() end end)
        AddToggle("Visuals","right","Chams", false, function(v) ESP.chams = v; if ESP.enabled then RefreshAllESP() end end)

        do
            local pg = tabPages["Visuals"]
            local col = pg.rightSF
            pg.rOrder += 1

            local styles = {
                {label = "Visible", val = "VisCheck"},
                {label = "Solid",   val = "Solid"},
                {label = "Glow",    val = "Glow"},
                {label = "Outline", val = "Outline"},
            }

            ConfigSystem.CreateDropdown(col, pg.rOrder, "Chams Style", styles, function()
                return ESP.chamsMode or "VisCheck"
            end, function(chosenVal)
                ESP.chamsMode = chosenVal
                if ESP.enabled and ESP.chams and RefreshAllESP then RefreshAllESP() end
                if SaveConfig then SaveConfig() end
            end)
        end
        -- ══════════════════════════════════════════════
        --  HIT FEEDBACK (Visuals Tab, Right Column)
        -- ══════════════════════════════════════════════
        AddSection("Visuals", "right", "Hit Feedback")
        AddToggle("Visuals", "right", "Hit Sound", HitEffects.soundEnabled, function(v)
            HitEffects.soundEnabled = v
            SaveConfig()
        end)
        AddToggle("Visuals", "right", "Damage Indicator", HitEffects.dmgHudEnabled, function(v)
            HitEffects.dmgHudEnabled = v
            SaveConfig()
        end)
        AddToggle("Visuals", "right", "Hit Ghost", HitEffects.ghostEnabled, function(v)
            HitEffects.ghostEnabled = v
            SaveConfig()
        end)

        do
            local pg = tabPages["Visuals"]
            local col = pg.rightSF
            pg.rOrder += 1

            local hfCard = Instance.new("Frame")
            hfCard.Name = "HitFeedbackControlsCard"
            hfCard.Size = UDim2.new(1, 0, 0, 0)
            hfCard.AutomaticSize = Enum.AutomaticSize.Y
            hfCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            hfCard.BorderSizePixel = 0
            hfCard.LayoutOrder = pg.rOrder
            hfCard.Parent = col
            Crn(hfCard, 6)
            local hfStroke = Strk(hfCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(hfCard, hfStroke, Color3.fromRGB(18, 18, 25))
            end

            local cardPad = Instance.new("UIPadding")
            cardPad.PaddingLeft = UDim.new(0, 8)
            cardPad.PaddingRight = UDim.new(0, 8)
            cardPad.PaddingTop = UDim.new(0, 7)
            cardPad.PaddingBottom = UDim.new(0, 7)
            cardPad.Parent = hfCard

            local cardLL = Instance.new("UIListLayout")
            cardLL.SortOrder = Enum.SortOrder.LayoutOrder
            cardLL.Padding = UDim.new(0, 5)
            cardLL.Parent = hfCard

            local cardHeader = Instance.new("Frame")
            cardHeader.Size = UDim2.new(1, 0, 0, 14)
            cardHeader.BackgroundTransparency = 1
            cardHeader.LayoutOrder = 1
            cardHeader.Parent = hfCard

            local cardTitle = Lbl(cardHeader, "HIT FEEDBACK SETTINGS", 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cardTitle.Size = UDim2.new(1, 0, 1, 0)
            if ConfigSystem then
                if not ConfigSystem.themeSections then ConfigSystem.themeSections = {} end
                table.insert(ConfigSystem.themeSections, cardTitle)
                if ConfigSystem.Localization then
                    ConfigSystem.Localization.RegisterLabel(cardTitle, "HIT FEEDBACK SETTINGS", true)
                end
            end

            local function AddHfSep(order)
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 3)
                sep.BackgroundTransparency = 1
                sep.LayoutOrder = order
                sep.Parent = hfCard
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -12, 0, 1)
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Position = UDim2.new(0.5, 0, 0.5, 0)
                line.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
                line.BorderSizePixel = 0
                line.Parent = sep
            end

            -- Hit Sound Volume
            CreateSlider(hfCard, 2, "Hit Sound Vol", 10, 100, math.floor(HitEffects.soundVolume * 100 + 0.5), function(v)
                HitEffects.soundVolume = v / 100
            end, false)

            AddHfSep(3)

            -- Hit Sound Selector (Animated Dropdown)
            local soundPresets = {
                {label = "Bell",   val = "rbxassetid://4817809188"},
                {label = "Skeet",  val = "rbxassetid://6534948092"},
                {label = "Marker", val = "rbxassetid://8679627751"},
                {label = "Ding",   val = "rbxassetid://4018616850"},
                {label = "Pop",    val = "rbxassetid://6607204501"},
            }

            ConfigSystem.CreateDropdown(hfCard, 4, "Hit Sound", soundPresets, function()
                local curId = HitEffects.soundId or "rbxassetid://4817809188"
                for _, s in ipairs(soundPresets) do
                    if s.val == curId then return s.label end
                end
                return HitEffects.soundName or "Bell"
            end, function(chosenVal, chosenLabel)
                HitEffects.soundId = chosenVal
                HitEffects.soundName = chosenLabel
                if HitEffects.soundEnabled and HitEffects.PlaySound then
                    HitEffects.PlaySound()
                end
                if SaveConfig then SaveConfig() end
            end)
        end

        AddSection("Visuals", "right", "Damage & Ghost Color")

        -- Dedicated Damage Color Card
        do
            local pg = tabPages["Visuals"]
            local col = pg.rightSF
            pg.rOrder += 1

            local dmgCard = Instance.new("Frame")
            dmgCard.Name = "DamageColorControlsCard"
            dmgCard.Size = UDim2.new(1, 0, 0, 0)
            dmgCard.AutomaticSize = Enum.AutomaticSize.Y
            dmgCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            dmgCard.BorderSizePixel = 0
            dmgCard.LayoutOrder = pg.rOrder
            dmgCard.Parent = col
            Crn(dmgCard, 6)
            local dmgStroke = Strk(dmgCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(dmgCard, dmgStroke, Color3.fromRGB(18, 18, 25))
            end

            local dPad = Instance.new("UIPadding")
            dPad.PaddingLeft = UDim.new(0, 8); dPad.PaddingRight = UDim.new(0, 8)
            dPad.PaddingTop = UDim.new(0, 7); dPad.PaddingBottom = UDim.new(0, 7)
            dPad.Parent = dmgCard

            local dLL = Instance.new("UIListLayout")
            dLL.SortOrder = Enum.SortOrder.LayoutOrder
            dLL.Padding = UDim.new(0, 5)
            dLL.Parent = dmgCard

            dmgPicker = CreateColorPicker(dmgCard, 1, "Damage Color",
                function()
                    local cur = HitEffects.dmgHudColor
                    if not cur or cur == "Accent" or cur == "GUI" then return T.accent end
                    if ConfigSystem and ConfigSystem.ParseColor then
                        local pc = ConfigSystem.ParseColor(cur)
                        if pc then return pc end
                    end
                    if cur == "Red" then return Color3.fromRGB(255, 75, 85)
                    elseif cur == "Green" then return Color3.fromRGB(80, 255, 120)
                    elseif cur == "White" then return Color3.fromRGB(255, 255, 255) end
                    return T.accent
                end,
                function(newCol)
                    HitEffects.dmgHudColor = ConfigSystem.ColorToHex(newCol)
                    if HitEffects.UpdateDmgColor then HitEffects.UpdateDmgColor() end
                    SaveConfig()
                end,
                true,
                function()
                    return (HitEffects.dmgHudColor == "Accent" or HitEffects.dmgHudColor == "GUI" or HitEffects.dmgHudColor == nil)
                end,
                function(isSync)
                    if isSync then
                        HitEffects.dmgHudColor = "Accent"
                    else
                        local cur = HitEffects.dmgHudColor
                        local parsed = (ConfigSystem and ConfigSystem.ParseColor and ConfigSystem.ParseColor(cur))
                        HitEffects.dmgHudColor = ConfigSystem.ColorToHex(parsed or T.accent)
                    end
                    if HitEffects.UpdateDmgColor then HitEffects.UpdateDmgColor() end
                    SaveConfig()
                end
            )

            if not ConfigSystem.pillRefreshers then ConfigSystem.pillRefreshers = {} end
            table.insert(ConfigSystem.pillRefreshers, function()
                if Crosshair.useAccent and chPicker and chPicker.update then
                    chPicker.update(T.accent, true)
                end
                if (HitEffects.dmgHudColor == "Accent" or HitEffects.dmgHudColor == "GUI" or HitEffects.dmgHudColor == nil) and dmgPicker and dmgPicker.update then
                    dmgPicker.update(T.accent, true)
                end
            end)
        end
    end
    BuildVisualsTab()

    local function BuildConfigTab()
        -- ══════════════════════════════════════════════
        --  CONFIG TAB  (Color Customization & Effects)
        -- ══════════════════════════════════════════════
        AddSection("Config","left","Interface")
        AddToggle("Config","left","Blur on Open",true, function(v)
            blurEnabled = v
            if v then ShowBlur() else HideBlur() end
        end)
        AddToggle("Config","left","Rain Effect", MenuParticles and MenuParticles.rainEnabled, function(v)
            if MenuParticles then MenuParticles.rainEnabled = v end
            if not v and MenuParticles and MenuParticles.rainCanvas then
                pcall(function()
                    for _, child in ipairs(MenuParticles.rainCanvas:GetChildren()) do
                        if child:IsA("Frame") then child:Destroy() end
                    end
                end)
            end
        end)
        AddToggle("Config","left","Snow Effect", MenuParticles and MenuParticles.snowEnabled, function(v)
            if MenuParticles then MenuParticles.snowEnabled = v end
            if not v and MenuParticles and MenuParticles.snowCanvas then
                pcall(function()
                    for _, child in ipairs(MenuParticles.snowCanvas:GetChildren()) do
                        if child:IsA("Frame") then child:Destroy() end
                    end
                end)
            end
        end)
        AddToggle("Config","left","Keybinds List", kbHudVisible, function(v)
            kbHudVisible = v
            if kbWin then kbWin.Visible = v end
            SaveConfig()
        end)
        AddToggle("Config","left","Watermark", Watermark.visible, function(v)
            Watermark.visible = v
            if Watermark.SetVisible then Watermark.SetVisible(v) end
            SaveConfig()
        end)

        do
            local pg = tabPages["Config"]
            local col = pg.leftSF
            pg.lOrder += 1

            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundTransparency = 1
            item.LayoutOrder = pg.lOrder
            item.Parent = col

            local hover = Instance.new("Frame")
            hover.Size = UDim2.new(1, 0, 1, 0)
            hover.BackgroundColor3 = T.itemHover
            hover.BackgroundTransparency = 1
            hover.BorderSizePixel = 0
            hover.ZIndex = 1
            hover.Parent = item
            Crn(hover, 4)

            local nL = Lbl(item, "Menu Key", 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            nL.Size = UDim2.new(1, -66, 1, 0)
            nL.Position = UDim2.new(0, 4, 0, 0)
            if ConfigSystem and ConfigSystem.Localization then
                ConfigSystem.Localization.RegisterLabel(nL, "Menu Key", false)
            end

            local dotsF = Instance.new("Frame")
            dotsF.Size = UDim2.new(0, 52, 0, 18)
            dotsF.Position = UDim2.new(1, -56, 0.5, -9)
            dotsF.BackgroundColor3 = T.dotsBg
            local isGlassMKey = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            dotsF.BackgroundTransparency = isGlassMKey and 0.65 or 0
            dotsF.BorderSizePixel = 0
            dotsF.ZIndex = 2
            dotsF.Parent = item
            Crn(dotsF, 4)
            local dotsStroke = Strk(dotsF, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassPill then
                ConfigSystem.RegisterGlassPill(dotsF, dotsStroke)
            end

            local dotsBtn = Instance.new("TextButton")
            dotsBtn.Size = UDim2.new(1, 0, 1, 0)
            dotsBtn.BackgroundTransparency = 1
            dotsBtn.BorderSizePixel = 0
            dotsBtn.Font = Enum.Font.Arcade
            dotsBtn.TextSize = 9
            dotsBtn.AutoButtonColor = false
            dotsBtn.ZIndex = 8
            dotsBtn.Text = FormatKeyName(TOGGLE_KEY)
            dotsBtn.TextColor3 = T.accent
            dotsBtn.Parent = dotsF
            TrackAccent(dotsBtn, "TextColor3")

            ConfigSystem.UpdateMenuKeyUI = function()
                dotsBtn.Text = FormatKeyName(TOGGLE_KEY)
            end

            local function startMenuBind()
                if listeningTarget and listeningTarget.isMenuKey then
                    CancelBinding()
                else
                    StartBinding("MenuToggleKey", dotsBtn, dotsF, nil, true)
                end
            end

            dotsBtn.MouseButton1Click:Connect(startMenuBind)

            dotsBtn.MouseButton2Click:Connect(function()
                if listeningTarget and listeningTarget.isMenuKey then CancelBinding() end
                TOGGLE_KEY = "Delete"
                if ConfigSystem then ConfigSystem.savedToggleKey = "Delete" end
                dotsBtn.Text = FormatKeyName("Delete")
                dotsBtn.TextColor3 = T.accent
                local s = dotsF:FindFirstChildOfClass("UIStroke")
                if s then s.Color = T.border end
                if Notify then
                    Notify("Menu Key", "Reset to [Delete]", 2.5)
                end
                SaveConfig()
            end)

            local click = Instance.new("TextButton")
            click.Size = UDim2.new(1, -66, 1, 0)
            click.BackgroundTransparency = 1
            click.Text = ""
            click.ZIndex = 5
            click.Parent = item
            click.MouseButton1Click:Connect(startMenuBind)

            dotsBtn.MouseEnter:Connect(function()
                local isGlassHover = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(dotsF, {BackgroundColor3 = Color3.fromRGB(34, 34, 46), BackgroundTransparency = isGlassHover and 0.45 or 0}, 0.12)
                if not (listeningTarget and listeningTarget.isMenuKey) then
                    Tw(dotsBtn, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.12)
                end
            end)
            dotsBtn.MouseLeave:Connect(function()
                local isGlassLeave = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(dotsF, {BackgroundColor3 = T.dotsBg, BackgroundTransparency = isGlassLeave and 0.65 or 0}, 0.12)
                if not (listeningTarget and listeningTarget.isMenuKey) then
                    Tw(dotsBtn, {TextColor3 = T.accent}, 0.12)
                end
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
            end)
            textHit.MouseLeave:Connect(function()
                Tw(nL, {TextColor3 = T.textDim}, 0.1)
            end)

            item.MouseEnter:Connect(function()
                Tw(hover, {BackgroundTransparency = 0.88}, 0.1)
            end)
            item.MouseLeave:Connect(function()
                Tw(hover, {BackgroundTransparency = 1}, 0.1)
                Tw(nL, {TextColor3 = T.textDim}, 0.1)
            end)
        end

        AddSection("Config","right","System")

        -- Reset HUD Positions button
        do
            local pg = tabPages["Config"]
            local col = pg.rightSF
            pg.rOrder += 1

            local rRow = Instance.new("Frame")
            rRow.Size = UDim2.new(1, 0, 0, 26)
            rRow.BackgroundTransparency = 1
            rRow.LayoutOrder = pg.rOrder
            rRow.Parent = col

            local rBtn = Instance.new("TextButton")
            rBtn.Size = UDim2.new(1, -4, 0, 22)
            rBtn.Position = UDim2.new(0, 2, 0.5, -11)
            rBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
            local isGlassRBtn = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            rBtn.BackgroundTransparency = isGlassRBtn and 0.70 or 0
            rBtn.BorderSizePixel = 0
            rBtn.Font = Enum.Font.Arcade
            rBtn.Text = "Reset HUD Positions"
            rBtn.TextColor3 = T.text
            rBtn.TextSize = 10
            rBtn.AutoButtonColor = false
            rBtn.ZIndex = 3
            rBtn.Parent = rRow
            Crn(rBtn, 5)
            local rStroke = Strk(rBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(rBtn, rStroke, Color3.fromRGB(24, 28, 36))
            end
            local function updateRBtnTheme()
                rBtn.TextColor3 = T.text
            end
            updateRBtnTheme()
            if ConfigSystem and ConfigSystem.themeRefreshers then
                table.insert(ConfigSystem.themeRefreshers, updateRBtnTheme)
            end
            if ConfigSystem and ConfigSystem.Localization then
                ConfigSystem.Localization.RegisterLabel(rBtn, "Reset HUD Positions", false)
            end

            rBtn.MouseEnter:Connect(function()
                local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(rBtn, {BackgroundColor3 = Color3.fromRGB(36, 36, 46), BackgroundTransparency = isGlass and 0.50 or 0}, 0.1)
            end)
            rBtn.MouseLeave:Connect(function()
                local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(rBtn, {BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or Color3.fromRGB(24, 28, 36), BackgroundTransparency = isGlass and 0.70 or 0}, 0.1)
            end)
            rBtn.MouseButton1Click:Connect(function()
                kbHudPosX, kbHudPosY = 20, 220
                if kbWin then
                    kbWin.Position = UDim2.new(0, 20, 0, 220)
                end
                AdminStaff.hudPosX, AdminStaff.hudPosY = 20, 100
                if AdminStaff.win then
                    AdminStaff.win.Position = UDim2.new(0, 20, 0, 100)
                end
                Watermark.scaleX = 0.5
                Watermark.posX = 0
                Watermark.scaleY = 0
                Watermark.posY = 20
                if Watermark.win then
                    Watermark.win.AnchorPoint = Vector2.new(0.5, 0.5)
                    Watermark.win.Position = UDim2.new(0.5, 0, 0, 20)
                end
                if Watermark.shadow then
                    Watermark.shadow.AnchorPoint = Vector2.new(0.5, 0.5)
                    Watermark.shadow.Position = UDim2.new(0.5, 0, 0, 21)
                end
                SaveConfig()
                if Notify then
                    Notify("HUDs", "Positions reset to default", 2.5)
                end
            end)
        end

        -- Eject Bind toggle (matches user screenshot)
        local ejectToggle
        ejectToggle = AddToggle("Config", "right", "Eject Bind", false, function(v)
            if v then
                if ejectToggle and ejectToggle.setToggleState then
                    ejectToggle.setToggleState(false, false, true)
                end
                task.spawn(function()
                    task.wait(0.05)
                    UnloadScript()
                end)
            end
        end)

        -- Color Customization Controls
        do
            local pg = tabPages["Config"]
            local col = pg.rightSF

            pg.rOrder += 1
            local accCard = Instance.new("Frame")
            accCard.Name = "AccentColorCard"
            accCard.Size = UDim2.new(1, 0, 0, 0)
            accCard.AutomaticSize = Enum.AutomaticSize.Y
            accCard.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
            accCard.BorderSizePixel = 0
            accCard.LayoutOrder = pg.rOrder
            accCard.Parent = col
            Crn(accCard, 6)
            local accStroke = Strk(accCard, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(accCard, accStroke, Color3.fromRGB(18, 18, 25))
            end

            local accPad = Instance.new("UIPadding")
            accPad.PaddingLeft = UDim.new(0, 8); accPad.PaddingRight = UDim.new(0, 8)
            accPad.PaddingTop = UDim.new(0, 7); accPad.PaddingBottom = UDim.new(0, 7)
            accPad.Parent = accCard

            local accLL = Instance.new("UIListLayout")
            accLL.SortOrder = Enum.SortOrder.LayoutOrder
            accLL.Padding = UDim.new(0, 5)
            accLL.Parent = accCard

            local accPicker = ConfigSystem.CreateColorPicker(accCard, 1, "Accent Color",
                function()
                    return Color3.fromHSV(accentH, accentS, accentV)
                end,
                function(newCol)
                    local h, s, v = Color3.toHSV(newCol)
                    accentH, accentS, accentV = h, s, v
                    ApplyAccentColor()
                    SaveConfig()
                end,
                false, nil, nil
            )

            if not ConfigSystem.pillRefreshers then ConfigSystem.pillRefreshers = {} end
            table.insert(ConfigSystem.pillRefreshers, function()
                if accPicker and accPicker.update then
                    accPicker.update(Color3.fromHSV(accentH, accentS, accentV))
                end
            end)

            -- ── DROPDOWN SELECTORS (Preset) ──

            -- 1. Preset (Theme) Dropdown
            local themeNames = {}
            if ConfigSystem and ConfigSystem.themePresets then
                for _, th in ipairs(ConfigSystem.themePresets) do
                    table.insert(themeNames, th.name)
                end
            else
                themeNames = {"Dark", "Light", "Midnight", "Nord", "Mocha", "Catppuccin", "Tokyo Night", "Dracula", "Gruvbox", "Rose Pine", "Solarized", "One Dark", "Glass"}
            end

            pg.rOrder += 1
            ConfigSystem.CreateDropdown(col, pg.rOrder, "Preset", themeNames, function()
                return (ConfigSystem and ConfigSystem.savedMenuTheme) or "Dark"
            end, function(chosen)
                if ConfigSystem and ConfigSystem.ApplyMenuTheme then
                    ConfigSystem.ApplyMenuTheme(chosen)
                end
                if SaveConfig then SaveConfig() end
            end)
        end
    end
    local function BuildPlayerTab()
        AddSection("Player", "left", "Utilities")
        AddToggle("Player", "left", "Anti-AFK", antiAfkEnabled, function(v)
            antiAfkEnabled = v
            SaveConfig()
            if Notify then
                Notify("Anti-AFK", v and "Anti-AFK enabled" or "Anti-AFK disabled", 2.5, "info")
            end
        end)

        AddSection("Player", "right", "Freecam")
        AddToggle("Player", "right", "Enabled", Freecam.enabled, function(v)
            if Freecam.SetEnabled then
                Freecam.SetEnabled(v)
            else
                Freecam.enabled = v
            end
            SaveConfig()
        end)
        AddToggle("Player", "right", "Teleport on click", Freecam.tpOnClick, function(v)
            Freecam.tpOnClick = v
            SaveConfig()
        end)
        AddToggle("Player", "right", "Teleport on disable", Freecam.tpOnDisable, function(v)
            Freecam.tpOnDisable = v
            SaveConfig()
        end)
        AddToggle("Player", "right", "Lock Character Position", Freecam.lockChar, function(v)
            Freecam.lockChar = v
            if Freecam.UpdateCharLock then
                Freecam.UpdateCharLock()
            end
            SaveConfig()
        end, true)

        local pPg = tabPages["Player"]
        local pCol = pPg.rightSF
        pPg.rOrder += 1
        CreateSlider(pCol, pPg.rOrder, "Speed", 0.1, 10.0, Freecam.speed or 2.77, function(val)
            Freecam.speed = val
            SaveConfig()
        end, true, "Freecam Speed")

        -- Teleport to Camera button
        do
            pPg.rOrder += 1
            local tpRow = Instance.new("Frame")
            tpRow.Size = UDim2.new(1, 0, 0, 26)
            tpRow.BackgroundTransparency = 1
            tpRow.LayoutOrder = pPg.rOrder
            tpRow.Parent = pCol

            local tpBtn = Instance.new("TextButton")
            tpBtn.Size = UDim2.new(1, -4, 0, 22)
            tpBtn.Position = UDim2.new(0, 2, 0.5, -11)
            tpBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
            local isGlassTpBtn = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
            tpBtn.BackgroundTransparency = isGlassTpBtn and 0.70 or 0
            tpBtn.BorderSizePixel = 0
            tpBtn.Font = Enum.Font.GothamMedium
            tpBtn.Text = "Teleport to Camera"
            tpBtn.TextColor3 = T.text
            tpBtn.TextSize = 10
            tpBtn.AutoButtonColor = false
            tpBtn.ZIndex = 3
            tpBtn.Parent = tpRow
            Crn(tpBtn, 5)
            local tpStroke = Strk(tpBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(tpBtn, tpStroke, Color3.fromRGB(24, 28, 36))
            end
            if ConfigSystem and ConfigSystem.Localization then
                ConfigSystem.Localization.RegisterLabel(tpBtn, "Teleport to Camera", false)
            end

            tpBtn.MouseEnter:Connect(function()
                local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(tpBtn, {BackgroundColor3 = Color3.fromRGB(36, 36, 46), BackgroundTransparency = isGlass and 0.50 or 0}, 0.1)
            end)
            tpBtn.MouseLeave:Connect(function()
                local isGlass = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")
                Tw(tpBtn, {BackgroundColor3 = isGlass and Color3.fromRGB(24, 24, 32) or Color3.fromRGB(24, 28, 36), BackgroundTransparency = isGlass and 0.70 or 0}, 0.1)
            end)
            tpBtn.MouseButton1Click:Connect(function()
                if Freecam.TeleportToCam then
                    Freecam.TeleportToCam(true)
                end
            end)
        end
    end
    BuildPlayerTab()

    local function BuildMiscTab()
        -- ══════════════════════════════════════════════
        --  MISC TAB (Staff Detector)
        -- ══════════════════════════════════════════════
        AddSection("Misc", "left", "Staff Detector")
        AddToggle("Misc", "left", "Admin Detector", AdminStaff.enabled, function(v)
            AdminStaff.enabled = v
            if v then
                AdminStaff.ScanServer()
            else
                if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end
            end
            SaveConfig()
        end)
        AddToggle("Misc", "left", "Admins HUD", AdminStaff.hudVisible, function(v)
            AdminStaff.hudVisible = v
            if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end
            SaveConfig()
        end)
        AddToggle("Misc", "left", "Auto-Hide Empty HUD", AdminStaff.autoHide, function(v)
            AdminStaff.autoHide = v
            if AdminStaff.UpdateHud then AdminStaff.UpdateHud() end
            SaveConfig()
        end)
        AddToggle("Misc", "left", "Staff Alerts", AdminStaff.alerts, function(v)
            AdminStaff.alerts = v
            SaveConfig()
        end)

        AddSection("Misc", "right", "Detected Staff Members")
        do
            local pg = tabPages["Misc"]
            local col = pg.rightSF
            pg.rOrder += 1

            local staffListCont = Instance.new("Frame")
            staffListCont.Size = UDim2.new(1, 0, 0, 0)
            staffListCont.AutomaticSize = Enum.AutomaticSize.Y
            staffListCont.BackgroundTransparency = 1
            staffListCont.LayoutOrder = pg.rOrder
            staffListCont.Parent = col

            local sLL = Instance.new("UIListLayout")
            sLL.SortOrder = Enum.SortOrder.LayoutOrder
            sLL.Padding = UDim.new(0, 4)
            sLL.Parent = staffListCont

            local function RefreshMenuStaffList()
                for _, ch in ipairs(staffListCont:GetChildren()) do
                    if ch:IsA("Frame") then ch:Destroy() end
                end

                local activeAdmins = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP then
                        local isAdm, rank, role = AdminStaff.CheckIfAdmin(plr)
                        if isAdm then
                            table.insert(activeAdmins, {player = plr, rank = rank, role = role})
                        end
                    end
                end

                if #activeAdmins == 0 then
                    local emptyCard = Instance.new("Frame")
                    emptyCard.Size = UDim2.new(1, -4, 0, 32)
                    emptyCard.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                    emptyCard.BorderSizePixel = 0
                    emptyCard.Parent = staffListCont
                    Crn(emptyCard, 6)
                    local emptyStroke = Strk(emptyCard, T.border, 1, 0)
                    if ConfigSystem and ConfigSystem.RegisterGlassCard then
                        ConfigSystem.RegisterGlassCard(emptyCard, emptyStroke, Color3.fromRGB(18, 18, 24))
                    end

                    local eL = Lbl(emptyCard, "No staff members on server", 10, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Center, 2)
                    eL.Size = UDim2.new(1, 0, 1, 0)
                else
                    for idx, adm in ipairs(activeAdmins) do
                        local card = Instance.new("Frame")
                        card.Size = UDim2.new(1, -4, 0, 42)
                        card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
                        card.BorderSizePixel = 0
                        card.LayoutOrder = idx
                        card.Parent = staffListCont
                        Crn(card, 6)
                        local cardStroke = Strk(card, Color3.fromRGB(40, 40, 52), 1, 0)
                        if ConfigSystem and ConfigSystem.RegisterGlassCard then
                            ConfigSystem.RegisterGlassCard(card, cardStroke, Color3.fromRGB(20, 20, 28))
                        end

                        local dn = Lbl(card, adm.player.DisplayName, 11, Color3.fromRGB(240, 240, 255), Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
                        dn.Position = UDim2.new(0, 10, 0, 4)
                        dn.Size = UDim2.new(1, -16, 0, 14)

                        local un = Lbl(card, "@" .. adm.player.Name, 9, T.textMuted, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
                        un.Position = UDim2.new(0, 10, 0, 20)
                        un.Size = UDim2.new(1, -16, 0, 14)
                    end
                end
            end

            AdminStaff.onListUpdated = RefreshMenuStaffList
            RefreshMenuStaffList()
        end
    end
    BuildMiscTab()    local function BuildPresetsTab()
        -- ══════════════════════════════════════════════
        --  CONFIG MANAGER (Clean Single Column UI)
        -- ══════════════════════════════════════════════
        ConfigSystem.SaveNamed = function(name, customData)
            name = (name and name:gsub("^%s+", ""):gsub("%s+$", "")) or ConfigSystem.activeConfig or "default"
            if name == "" then name = "default" end
            local data = customData or GetCurrentConfigData()
            if not ConfigSystem.configs then ConfigSystem.configs = {} end
            ConfigSystem.configs[name] = data
            ConfigSystem.activeConfig = name
            ConfigSystem.selectedConfig = name
            pcall(function()
                if writefile then
                    if isfolder and makefolder and not isfolder(CONFIG_DIR) then
                        makefolder(CONFIG_DIR)
                    end
                    writefile(CONFIG_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(data))
                end
            end)
            if ConfigSystem.refreshList then ConfigSystem.refreshList() end
            pcall(function()
                if Notify then Notify("Config Saved", "Config [" .. name .. "] saved successfully!", 3, "success") end
            end)
        end

        ConfigSystem.LoadNamed = function(name)
            name = (name and name:gsub("^%s+", ""):gsub("%s+$", "")) or ConfigSystem.selectedConfig or "default"
            if name == "" then name = "default" end
            local data = nil
            pcall(function()
                local filePath = CONFIG_DIR .. "/" .. name .. ".json"
                if isfile and readfile and isfile(filePath) then
                    data = HttpService:JSONDecode(readfile(filePath))
                end
            end)
            if not data and ConfigSystem.configs then
                data = ConfigSystem.configs[name]
            end
            if data then
                ConfigSystem.activeConfig = name
                ConfigSystem.selectedConfig = name
                isApplyingConfig = true
                pcall(function()
                    ApplyConfigData(data)
                end)
                isApplyingConfig = false
                if ConfigSystem.refreshList then ConfigSystem.refreshList() end
                pcall(function()
                    if Notify then Notify("Config Loaded", "Loaded [" .. name .. "]!", 3, "success") end
                end)
            else
                pcall(function()
                    if Notify then Notify("Config Error", "Could not find config [" .. name .. "]", 3, "error") end
                end)
            end
        end

        ConfigSystem.DeleteNamed = function(name)
            if not name or name == "default" then
                if Notify then Notify("Config", "Cannot delete default config", 2, "info") end
                return
            end
            pcall(function()
                local filePath = CONFIG_DIR .. "/" .. name .. ".json"
                if delfile and isfile and isfile(filePath) then
                    delfile(filePath)
                end
            end)
            if ConfigSystem.configs then
                ConfigSystem.configs[name] = nil
            end
            if ConfigSystem.activeConfig == name then
                ConfigSystem.activeConfig = "default"
            end
            ConfigSystem.selectedConfig = "default"
            if ConfigSystem.refreshList then ConfigSystem.refreshList() end
            pcall(function()
                if Notify then Notify("Config Deleted", "Config [" .. name .. "] deleted", 3, "info") end
            end)
        end

        ConfigSystem.SetDefault = function(name)
            name = (name and name:gsub("^%s+", ""):gsub("%s+$", "")) or ConfigSystem.selectedConfig or "default"
            if name == "" then name = "default" end
            ConfigSystem.defaultConfigName = name
            pcall(function()
                if writefile then
                    if isfolder and makefolder and not isfolder(CONFIG_DIR) then
                        makefolder(CONFIG_DIR)
                    end
                    writefile(CONFIG_DIR .. "/_default.txt", name)
                end
            end)
            if ConfigSystem.refreshList then ConfigSystem.refreshList() end
            pcall(function()
                if Notify then Notify("Default Config", "[" .. name .. "] set as auto-load default", 3, "success") end
            end)
        end

        -- ── CONFIG SYSTEM UI (Matching User Request) ──
        do
            local pg = tabPages["Configs"] or tabPages["Presets"]
            local col = pg.leftSF
            if pg.rightSF then
                pg.rightSF.Visible = false
            end

            -- Header: Config
            AddSection("Configs", "left", "Config")

            -- Button: Open Folder
            pg.lOrder += 1
            local ofRow = Instance.new("Frame")
            ofRow.Size = UDim2.new(1, 0, 0, 30)
            ofRow.BackgroundTransparency = 1
            ofRow.LayoutOrder = pg.lOrder
            ofRow.Parent = col

            local ofBtn = Instance.new("TextButton")
            ofBtn.Size = UDim2.new(1, -4, 0, 26)
            ofBtn.Position = UDim2.new(0, 2, 0.5, -13)
            ofBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
            ofBtn.BorderSizePixel = 0
            ofBtn.Font = Enum.Font.Arcade
            ofBtn.Text = "Open Folder"
            ofBtn.TextColor3 = Color3.fromRGB(210, 210, 225)
            ofBtn.TextSize = 11
            ofBtn.AutoButtonColor = false
            ofBtn.ZIndex = 3
            ofBtn.Parent = ofRow
            Crn(ofBtn, 5)
            local ofStroke = Strk(ofBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(ofBtn, ofStroke, Color3.fromRGB(24, 24, 34))
            end

            ofBtn.MouseEnter:Connect(function() Tw(ofBtn, {BackgroundColor3 = Color3.fromRGB(32, 32, 44)}, 0.1) end)
            ofBtn.MouseLeave:Connect(function() Tw(ofBtn, {BackgroundColor3 = Color3.fromRGB(24, 24, 34)}, 0.1) end)
            ofBtn.MouseButton1Click:Connect(function()
                pcall(function()
                    if isfolder and makefolder and not isfolder(CONFIG_DIR) then
                        makefolder(CONFIG_DIR)
                    end
                    if openfolder then
                        local ok = pcall(openfolder, CONFIG_DIR)
                        if not ok then
                            pcall(openfolder, "")
                        end
                        if Notify then Notify("Config Folder", "Opened " .. CONFIG_DIR .. " folder!", 2.5, "success") end
                    elseif setclipboard then
                        setclipboard(CONFIG_DIR)
                        if Notify then Notify("Config Folder", "Config folder path copied: " .. CONFIG_DIR, 3, "info") end
                    else
                        if Notify then Notify("Config Folder", "Folder: " .. CONFIG_DIR, 3, "info") end
                    end
                end)
            end)

            -- Header Label: Config List
            pg.lOrder += 1
            local clLblRow = Instance.new("Frame")
            clLblRow.Size = UDim2.new(1, 0, 0, 22)
            clLblRow.BackgroundTransparency = 1
            clLblRow.LayoutOrder = pg.lOrder
            clLblRow.Parent = col

            local clLbl = Lbl(clLblRow, "Config List", 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            clLbl.Size = UDim2.new(1, -4, 1, 0)
            clLbl.Position = UDim2.new(0, 4, 0, 0)

            -- Config List Container (Rounded Box Frame)
            pg.lOrder += 1
            local listOuter = Instance.new("Frame")
            listOuter.Size = UDim2.new(1, -4, 0, 186)
            listOuter.BackgroundColor3 = Color3.fromRGB(16, 16, 23)
            listOuter.BorderSizePixel = 0
            listOuter.LayoutOrder = pg.lOrder
            listOuter.Parent = col
            Crn(listOuter, 6)
            local listStroke = Strk(listOuter, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassCard then
                ConfigSystem.RegisterGlassCard(listOuter, listStroke, Color3.fromRGB(16, 16, 23))
            end

            local listSF = Instance.new("ScrollingFrame")
            listSF.Size = UDim2.new(1, -8, 1, -10)
            listSF.Position = UDim2.new(0, 4, 0, 5)
            listSF.BackgroundTransparency = 1
            listSF.BorderSizePixel = 0
            listSF.ScrollBarThickness = 3
            listSF.ScrollBarImageColor3 = T.accent
            listSF.CanvasSize = UDim2.new(0, 0, 0, 0)
            listSF.AutomaticCanvasSize = Enum.AutomaticSize.Y
            listSF.ClipsDescendants = true
            listSF.Parent = listOuter
            TrackAccent(listSF, "ScrollBarImageColor3")
            if ConfigSystem and ConfigSystem.AttachScrollbarAutoHide then
                ConfigSystem.AttachScrollbarAutoHide(listSF)
            end

            local listPad = Instance.new("UIPadding")
            listPad.PaddingTop = UDim.new(0, 4)
            listPad.PaddingBottom = UDim.new(0, 4)
            listPad.PaddingLeft = UDim.new(0, 4)
            listPad.PaddingRight = UDim.new(0, 6)
            listPad.Parent = listSF

            local listLL = Instance.new("UIListLayout")
            listLL.SortOrder = Enum.SortOrder.LayoutOrder
            listLL.Padding = UDim.new(0, 2)
            listLL.Parent = listSF

            -- Header Label: Config Name
            pg.lOrder += 1
            local cnLblRow = Instance.new("Frame")
            cnLblRow.Size = UDim2.new(1, 0, 0, 22)
            cnLblRow.BackgroundTransparency = 1
            cnLblRow.LayoutOrder = pg.lOrder
            cnLblRow.Parent = col

            local cnLbl = Lbl(cnLblRow, "Config Name", 11, T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 2)
            cnLbl.Size = UDim2.new(1, -4, 1, 0)
            cnLbl.Position = UDim2.new(0, 4, 0, 0)

            -- Config Name Input Box
            pg.lOrder += 1
            local inBoxFrame = Instance.new("Frame")
            inBoxFrame.Size = UDim2.new(1, -4, 0, 30)
            inBoxFrame.BackgroundColor3 = T.inputBg
            inBoxFrame.BorderSizePixel = 0
            inBoxFrame.LayoutOrder = pg.lOrder
            inBoxFrame.Parent = col
            Crn(inBoxFrame, 6)
            local inStroke = Strk(inBoxFrame, T.border, 1, 0)
            if ConfigSystem then
                ConfigSystem.inBoxFrame = inBoxFrame
                ConfigSystem.inStroke = inStroke
                local isGlassIn = (ConfigSystem.savedMenuTheme == "Glass")
                inBoxFrame.BackgroundColor3 = isGlassIn and Color3.fromRGB(24, 24, 32) or T.inputBg
                inBoxFrame.BackgroundTransparency = isGlassIn and 0.65 or 0
                inStroke.Transparency = isGlassIn and 0.45 or 0
            end

            local inTB = Instance.new("TextBox")
            inTB.Size = UDim2.new(1, -16, 1, 0)
            inTB.Position = UDim2.new(0, 8, 0, 0)
            inTB.BackgroundTransparency = 1
            inTB.Font = Enum.Font.Arcade
            inTB.TextSize = 11
            inTB.TextColor3 = T.text
            inTB.PlaceholderColor3 = T.textMuted
            inTB.PlaceholderText = "Enter config name..."
            inTB.Text = ConfigSystem.selectedConfig or "default"
            inTB.ClearTextOnFocus = false
            inTB.Parent = inBoxFrame

            inTB.Focused:Connect(function() Tw(inStroke, {Color = T.accent}, 0.15) end)
            inTB.FocusLost:Connect(function() Tw(inStroke, {Color = T.border}, 0.15) end)

            -- Action Buttons Row: [ Load ]  [ Save ]
            pg.lOrder += 1
            local btnRow = Instance.new("Frame")
            btnRow.Size = UDim2.new(1, 0, 0, 30)
            btnRow.BackgroundTransparency = 1
            btnRow.LayoutOrder = pg.lOrder
            btnRow.Parent = col

            local loadBtn = Instance.new("TextButton")
            loadBtn.Size = UDim2.new(0.5, -4, 0, 26)
            loadBtn.Position = UDim2.new(0, 2, 0.5, -13)
            loadBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
            loadBtn.BorderSizePixel = 0
            loadBtn.Font = Enum.Font.Arcade
            loadBtn.Text = "Load"
            loadBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
            loadBtn.TextSize = 11
            loadBtn.AutoButtonColor = false
            loadBtn.ZIndex = 3
            loadBtn.Parent = btnRow
            Crn(loadBtn, 5)
            local loadStroke = Strk(loadBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(loadBtn, loadStroke, Color3.fromRGB(24, 28, 38))
            end

            loadBtn.MouseEnter:Connect(function() Tw(loadBtn, {BackgroundColor3 = Color3.fromRGB(32, 38, 52)}, 0.1) end)
            loadBtn.MouseLeave:Connect(function() Tw(loadBtn, {BackgroundColor3 = Color3.fromRGB(24, 28, 38)}, 0.1) end)
            loadBtn.MouseButton1Click:Connect(function()
                local name = inTB.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if name == "" then name = ConfigSystem.selectedConfig or "default" end
                ConfigSystem.LoadNamed(name)
            end)

            local saveBtn = Instance.new("TextButton")
            saveBtn.Size = UDim2.new(0.5, -4, 0, 26)
            saveBtn.Position = UDim2.new(0.5, 2, 0.5, -13)
            saveBtn.BackgroundColor3 = Color3.fromRGB(28, 24, 38)
            saveBtn.BorderSizePixel = 0
            saveBtn.Font = Enum.Font.Arcade
            saveBtn.Text = "Save"
            saveBtn.TextColor3 = T.accent
            saveBtn.TextSize = 11
            saveBtn.AutoButtonColor = false
            saveBtn.ZIndex = 3
            saveBtn.Parent = btnRow
            Crn(saveBtn, 5)
            local saveStroke = Strk(saveBtn, T.border, 1, 0)
            TrackAccent(saveBtn, "TextColor3")
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(saveBtn, saveStroke, Color3.fromRGB(28, 24, 38))
            end

            saveBtn.MouseEnter:Connect(function() Tw(saveBtn, {BackgroundColor3 = Color3.fromRGB(38, 30, 52)}, 0.1) end)
            saveBtn.MouseLeave:Connect(function() Tw(saveBtn, {BackgroundColor3 = Color3.fromRGB(28, 24, 38)}, 0.1) end)
            saveBtn.MouseButton1Click:Connect(function()
                local name = inTB.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if name == "" then name = ConfigSystem.selectedConfig or "default" end
                ConfigSystem.SaveNamed(name)
            end)

            -- Secondary Buttons Row: [ Delete ]  [ Set Default ]
            pg.lOrder += 1
            local secRow = Instance.new("Frame")
            secRow.Size = UDim2.new(1, 0, 0, 28)
            secRow.BackgroundTransparency = 1
            secRow.LayoutOrder = pg.lOrder
            secRow.Parent = col

            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.new(0.5, -4, 0, 24)
            delBtn.Position = UDim2.new(0, 2, 0.5, -12)
            delBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
            delBtn.BorderSizePixel = 0
            delBtn.Font = Enum.Font.Arcade
            delBtn.Text = "Delete"
            delBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
            delBtn.TextSize = 10
            delBtn.AutoButtonColor = false
            delBtn.ZIndex = 3
            delBtn.Parent = secRow
            Crn(delBtn, 5)
            local delStroke = Strk(delBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(delBtn, delStroke, Color3.fromRGB(24, 28, 38))
            end

            delBtn.MouseEnter:Connect(function() Tw(delBtn, {BackgroundColor3 = Color3.fromRGB(32, 38, 52)}, 0.1) end)
            delBtn.MouseLeave:Connect(function() Tw(delBtn, {BackgroundColor3 = Color3.fromRGB(24, 28, 38)}, 0.1) end)
            delBtn.MouseButton1Click:Connect(function()
                local name = inTB.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if name == "" then name = ConfigSystem.selectedConfig end
                if name and name ~= "default" then
                    ConfigSystem.DeleteNamed(name)
                    inTB.Text = "default"
                else
                    if Notify then Notify("Config", "Cannot delete default config", 2, "info") end
                end
            end)

            local defBtn = Instance.new("TextButton")
            defBtn.Size = UDim2.new(0.5, -4, 0, 24)
            defBtn.Position = UDim2.new(0.5, 2, 0.5, -12)
            defBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
            defBtn.BorderSizePixel = 0
            defBtn.Font = Enum.Font.Arcade
            defBtn.Text = "Set Default"
            defBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
            defBtn.TextSize = 10
            defBtn.AutoButtonColor = false
            defBtn.ZIndex = 3
            defBtn.Parent = secRow
            Crn(defBtn, 5)
            local defStroke = Strk(defBtn, T.border, 1, 0)
            if ConfigSystem and ConfigSystem.RegisterGlassButton then
                ConfigSystem.RegisterGlassButton(defBtn, defStroke, Color3.fromRGB(24, 28, 38))
            end

            defBtn.MouseEnter:Connect(function() Tw(defBtn, {BackgroundColor3 = Color3.fromRGB(32, 38, 52)}, 0.1) end)
            defBtn.MouseLeave:Connect(function() Tw(defBtn, {BackgroundColor3 = Color3.fromRGB(24, 28, 38)}, 0.1) end)
            defBtn.MouseButton1Click:Connect(function()
                local name = inTB.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if name == "" then name = ConfigSystem.selectedConfig or "default" end
                ConfigSystem.SetDefault(name)
            end)

            -- Refresh function for the Config List container
            local function RefreshConfigCards()
                for _, ch in ipairs(listSF:GetChildren()) do
                    if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end
                end

                if not ConfigSystem.configs["default"] then
                    ConfigSystem.configs["default"] = GetCurrentConfigData()
                end

                local names = {}
                local foundMap = {}
                pcall(function()
                    if listfiles and isfolder and isfolder(CONFIG_DIR) then
                        for _, f in ipairs(listfiles(CONFIG_DIR)) do
                            local clean = f:match("([^/\\]+)%.json$")
                            if clean and clean ~= "_default" then
                                foundMap[clean] = true
                            end
                        end
                    end
                end)
                foundMap["default"] = true
                if ConfigSystem.configs then
                    for k in pairs(ConfigSystem.configs) do
                        if k ~= "_default" then foundMap[k] = true end
                    end
                end
                for k in pairs(foundMap) do
                    table.insert(names, k)
                end
                table.sort(names)

                for idx, cName in ipairs(names) do
                    local isSel = (ConfigSystem.selectedConfig == cName)
                    local isDef = (ConfigSystem.defaultConfigName == cName)
                    local isGlassRow = (ConfigSystem and ConfigSystem.savedMenuTheme == "Glass")

                    local row = Instance.new("TextButton")
                    row.Size = UDim2.new(1, 0, 0, 24)
                    row.BackgroundColor3 = isSel and (isGlassRow and Color3.fromRGB(36, 40, 56) or Color3.fromRGB(28, 30, 44)) or (isGlassRow and Color3.fromRGB(22, 22, 30) or Color3.fromRGB(18, 18, 25))
                    row.BackgroundTransparency = isSel and (isGlassRow and 0.50 or 0) or (isGlassRow and 0.75 or 0.4)
                    row.BorderSizePixel = 0
                    row.AutoButtonColor = false
                    row.LayoutOrder = idx
                    row.Text = ""
                    row.ZIndex = 3
                    row.Parent = listSF
                    Crn(row, 4)

                    if isSel then
                        Strk(row, T.accent, 1, 0)
                    end

                    local nameL = Lbl(row, cName, 11, isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 165), isSel and Enum.Font.Arcade or Enum.Font.Arcade, Enum.TextXAlignment.Left, 4)
                    nameL.Position = UDim2.new(0, 10, 0, 0)
                    nameL.Size = UDim2.new(0.65, -10, 1, 0)

                    if isDef then
                        local tagL = Lbl(row, "[Default]", 9, Color3.fromRGB(255, 205, 60), Enum.Font.Arcade, Enum.TextXAlignment.Right, 4)
                        tagL.Position = UDim2.new(0.65, 0, 0, 0)
                        tagL.Size = UDim2.new(0.35, -8, 1, 0)
                    end

                    row.MouseEnter:Connect(function()
                        if ConfigSystem.selectedConfig ~= cName then
                            Tw(row, {BackgroundTransparency = 0.1}, 0.1)
                            nameL.TextColor3 = Color3.fromRGB(210, 210, 225)
                        end
                    end)
                    row.MouseLeave:Connect(function()
                        if ConfigSystem.selectedConfig ~= cName then
                            Tw(row, {BackgroundTransparency = 0.4}, 0.1)
                            nameL.TextColor3 = Color3.fromRGB(150, 150, 165)
                        end
                    end)

                    row.MouseButton1Click:Connect(function()
                        ConfigSystem.selectedConfig = cName
                        inTB.Text = cName
                        RefreshConfigCards()
                    end)
                end
            end

            ConfigSystem.refreshList = RefreshConfigCards
            RefreshConfigCards()
        end
    end
    BuildPresetsTab()

    BuildConfigTab()
end
PopulateTabs()
if ConfigSystem and ConfigSystem.UpdateThemeVisuals then
    pcall(ConfigSystem.UpdateThemeVisuals)
end

-- ══════════════════════════════════════════════
--  GLOBAL SEARCH SYSTEM (Search across all tabs)
-- ══════════════════════════════════════════════
local searchShown = false

local function CreateSearchResultItem(col, t, order)
    local en = t.isEnabled()
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, 28)
    item.BackgroundTransparency = 1
    item.LayoutOrder = order
    item.ZIndex = 17
    item.Parent = col

    local hover = Instance.new("Frame")
    hover.Size = UDim2.new(1, 0, 1, 0)
    hover.BackgroundColor3 = T.itemHover
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.ZIndex = 17
    hover.Parent = item
    Crn(hover, 4)

    local textRightOffset = t.noBind and -44 or -78
    local nL = Lbl(item, t.name, 11, en and T.text or T.textDim, Enum.Font.Arcade, Enum.TextXAlignment.Left, 18)
    nL.Size = UDim2.new(1, textRightOffset, 1, 0)
    nL.Position = UDim2.new(0, 4, 0, 0)
    if ConfigSystem and ConfigSystem.Localization then
        ConfigSystem.Localization.RegisterLabel(nL, t.name, false)
    end

    local dotsF, dotsBtn
    if not t.noBind then
        -- "..." button (keybind button)
        dotsF = Instance.new("Frame")
        dotsF.Size = UDim2.new(0, 26, 0, 17)
        dotsF.Position = UDim2.new(1, -74, .5, -8)
        dotsF.BackgroundColor3 = T.dotsBg
        dotsF.BorderSizePixel = 0
        dotsF.ZIndex = 18
        dotsF.Parent = item
        Crn(dotsF, 4)
        Strk(dotsF, T.border, 1, 0)

        dotsBtn = Instance.new("TextButton")
        dotsBtn.Size = UDim2.new(1, 0, 1, 0)
        dotsBtn.BackgroundTransparency = 1
        dotsBtn.BorderSizePixel = 0
        dotsBtn.Font = Enum.Font.Arcade
        dotsBtn.TextSize = 8
        dotsBtn.AutoButtonColor = false
        dotsBtn.ZIndex = 19
        dotsBtn.Parent = dotsF

        local function refreshBindText()
            local bInfo = featureBinds[t.name]
            if bInfo and bInfo.key then
                dotsBtn.Text = bInfo.shortKey
                dotsBtn.TextColor3 = T.accent
            elseif bInfo and bInfo.mode == "Always" then
                dotsBtn.Text = "ALW"
                dotsBtn.TextColor3 = T.accent
            else
                dotsBtn.Text = "..."
                dotsBtn.TextColor3 = T.textMuted
            end
        end
        refreshBindText()

        dotsBtn.MouseButton1Click:Connect(function()
            if listeningTarget and listeningTarget.name == t.name then
                CancelBinding()
            else
                StartBinding(t.name, dotsBtn, dotsF, t)
            end
        end)
        dotsBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton3 then
                if listeningTarget then return end
                OpenKeybindContextMenu(t.name, dotsBtn, dotsF, t)
            end
        end)
        dotsBtn.MouseButton2Click:Connect(function()
            if listeningTarget then return end
            featureBinds[t.name] = nil
            refreshBindText()
            if t.dotsBtn then
                t.dotsBtn.Text = "..."
                t.dotsBtn.TextColor3 = T.textMuted
                local s = t.dotsF:FindFirstChildOfClass("UIStroke")
                if s then s.Color = T.border end
            end
            if UpdateKeybindsHud then UpdateKeybindsHud() end
            SaveConfig()
        end)

        dotsBtn.MouseEnter:Connect(function()
            Tw(dotsF, {BackgroundColor3 = Color3.fromRGB(24, 24, 34)}, 0.12)
            local isBound = (featureBinds[t.name] ~= nil and (featureBinds[t.name].key ~= nil or featureBinds[t.name].mode == "Always"))
            if not (listeningTarget and listeningTarget.name == t.name) then
                Tw(dotsBtn, {TextColor3 = isBound and Color3.fromRGB(255, 255, 255) or T.textDim}, 0.12)
            end
        end)
        dotsBtn.MouseLeave:Connect(function()
            Tw(dotsF, {BackgroundColor3 = T.dotsBg}, 0.12)
            local isBound = (featureBinds[t.name] ~= nil and (featureBinds[t.name].key ~= nil or featureBinds[t.name].mode == "Always"))
            if not (listeningTarget and listeningTarget.name == t.name) then
                Tw(dotsBtn, {TextColor3 = isBound and T.accent or T.textMuted}, 0.12)
            end
        end)
    end

    -- Switch
    local tBg = Instance.new("Frame")
    tBg.Size = UDim2.new(0, 34, 0, 17)
    tBg.Position = UDim2.new(1, -38, .5, -8)
    tBg.BackgroundColor3 = en and T.accent or T.accentOff
    tBg.BorderSizePixel = 0
    tBg.ZIndex = 18
    tBg.Parent = item
    Crn(tBg, 8)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 13, 0, 13)
    knob.Position = en and UDim2.new(1, -15, .5, -6) or UDim2.new(0, 2, .5, -6)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 19
    knob.Parent = tBg
    Crn(knob, 6)

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(1, 0, 1, 0); switchBtn.BackgroundTransparency = 1
    switchBtn.Text = ""; switchBtn.ZIndex = 20; switchBtn.Parent = tBg

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, textRightOffset, 1, 0); click.BackgroundTransparency = 1
    click.Text = ""; click.ZIndex = 20; click.Parent = item

    local function updateSwitchVisual(state)
        en = state
        Tw(tBg,  {BackgroundColor3 = en and T.accent or T.accentOff}, .18)
        knob.Size = UDim2.new(0, 16, 0, 13)
        Tw(knob, {
            Position = en and UDim2.new(1, -15, .5, -6) or UDim2.new(0, 2, .5, -6),
            Size = UDim2.new(0, 13, 0, 13),
        }, .22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Tw(nL,   {TextColor3 = en and T.text or T.textDim}, .15)
    end

    local function triggerToggle()
        local nextState = not t.isEnabled()
        t.setToggleState(nextState, true)
        updateSwitchVisual(nextState)
    end

    click.MouseButton1Click:Connect(triggerToggle)
    switchBtn.MouseButton1Click:Connect(triggerToggle)

    local textHit = Instance.new("TextButton")
    textHit.Position = UDim2.new(0, 2, 0, 0)
    textHit.BackgroundTransparency = 1
    textHit.Text = ""
    textHit.ZIndex = 21
    textHit.Parent = item

    local function updateSearchTextHit()
        local tbX = nL.TextBounds.X
        if tbX <= 0 then tbX = math.max(#nL.Text * 7, 20) end
        local maxW = t.noBind and 146 or 112
        textHit.Size = UDim2.new(0, math.clamp(tbX + 6, 20, maxW), 1, 0)
    end
    updateSearchTextHit()
    nL:GetPropertyChangedSignal("TextBounds"):Connect(updateSearchTextHit)
    nL:GetPropertyChangedSignal("Text"):Connect(updateSearchTextHit)
    task.defer(updateSearchTextHit)

    textHit.MouseButton1Click:Connect(triggerToggle)
    textHit.MouseEnter:Connect(function()
        Tw(hover, {BackgroundTransparency = .88}, .1)
        Tw(nL,    {TextColor3 = en and T.text or Color3.fromRGB(255, 255, 255)}, .1)
    end)
    textHit.MouseLeave:Connect(function()
        Tw(nL,    {TextColor3 = en and T.text or T.textDim}, .1)
    end)

    click.MouseEnter:Connect(function() Tw(hover, {BackgroundTransparency = .88}, .1) end)
    click.MouseLeave:Connect(function() Tw(hover, {BackgroundTransparency = 1}, .1) end)
    switchBtn.MouseEnter:Connect(function() Tw(hover, {BackgroundTransparency = .88}, .1) end)
    switchBtn.MouseLeave:Connect(function() Tw(hover, {BackgroundTransparency = 1}, .1) end)
    item.MouseLeave:Connect(function()
        Tw(hover, {BackgroundTransparency = 1}, .1)
        Tw(nL,    {TextColor3 = en and T.text or T.textDim}, .1)
        if ConfigSystem and ConfigSystem.HideTooltip then ConfigSystem.HideTooltip() end
    end)

    -- Item row entrance animation: subtle slide from left
    item.Position = UDim2.new(0, 0, 0, 0)

    -- Sync if toggled externally (e.g. keybind)
    t.onSync = function(state)
        if item.Parent then
            updateSwitchVisual(state)
        end
    end

    return item
end

UpdateSearch = function()
    local rawQ = searchTB.Text
    local q = rawQ:lower():gsub("%s+", "")

    if q == "" then
        if searchShown then
            searchShown = false
            if hasCanvasGroup then
                Tw(searchView, {GroupTransparency = 1, Position = UDim2.new(0, 0, 0, -8)}, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            else
                Tw(searchView, {Position = UDim2.new(0, 0, 0, -8)}, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            end
            task.delay(0.17, function()
                if not searchShown then
                    searchView.Visible = false
                    searchView.Position = UDim2.new(0, 0, 0, 0)
                    if tabPages[currentTab] then
                        tabPages[currentTab].leftSF.Visible = true
                        tabPages[currentTab].rightSF.Visible = not tabPages[currentTab].isSingle
                    end
                end
            end)
        else
            searchView.Visible = false
            if tabPages[currentTab] then
                tabPages[currentTab].leftSF.Visible = true
                tabPages[currentTab].rightSF.Visible = not tabPages[currentTab].isSingle
            end
        end
        return
    end

    -- Searching: hide current tab and reveal search view
    if not searchShown then
        searchShown = true
        searchView.Visible = true
        if tabPages[currentTab] then
            tabPages[currentTab].leftSF.Visible = false
            tabPages[currentTab].rightSF.Visible = false
        end
        searchView.Position = UDim2.new(0, 0, 0, -10)
        if hasCanvasGroup then
            searchView.GroupTransparency = 1
            Tw(searchView, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        else
            Tw(searchView, {Position = UDim2.new(0, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    else
        searchView.Visible = true
        if tabPages[currentTab] then
            tabPages[currentTab].leftSF.Visible = false
            tabPages[currentTab].rightSF.Visible = false
        end
    end

    -- Clear previous search result cards
    for _, ch in ipairs(searchLeftSF:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") or ch:IsA("TextButton") then ch:Destroy() end
    end
    for _, ch in ipairs(searchRightSF:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") or ch:IsA("TextButton") then ch:Destroy() end
    end

    -- Match against all registered toggles across all tabs
    local matches = {}
    local isRU = (ConfigSystem and ConfigSystem.Localization and ConfigSystem.Localization.currentLang == "RU")
    for _, t in ipairs(allRegisteredTogglesList) do
        local tNameNorm = t.name:lower():gsub("%s+", "")
        local tTabNorm  = (t.tabName or ""):lower():gsub("%s+", "")
        local tSecNorm  = (t.sectionName or ""):lower():gsub("%s+", "")
        local ruMatch = false
        if ConfigSystem and ConfigSystem.Localization and ConfigSystem.Localization.translations then
            local trans = ConfigSystem.Localization.translations[t.name]
            if trans and trans.RU then
                local ruTitle = trans.RU:lower():gsub("%s+", "")
                if ruTitle:find(q, 1, true) then ruMatch = true end
            end
            local tabTrans = ConfigSystem.Localization.translations[t.tabName or ""]
            if tabTrans and tabTrans.RU then
                local ruTab = tabTrans.RU:lower():gsub("%s+", "")
                if ruTab:find(q, 1, true) then ruMatch = true end
            end
            local secTrans = ConfigSystem.Localization.translations[t.sectionName or ""]
            if secTrans and secTrans.RU then
                local ruSec = secTrans.RU:lower():gsub("%s+", "")
                if ruSec:find(q, 1, true) then ruMatch = true end
            end
        end
        if tNameNorm:find(q, 1, true) or tTabNorm:find(q, 1, true) or tSecNorm:find(q, 1, true) or ruMatch then
            table.insert(matches, t)
        end
    end

    if #matches == 0 then
        local emptyMsg = isRU and ("Ничего не найдено по запросу \"" .. rawQ .. "\"") or ("No functions found matching \"" .. rawQ .. "\"")
        searchEmptyL.Text = emptyMsg
        searchEmptyL.Font = isRU and Enum.Font.GothamMedium or Enum.Font.Arcade
        searchEmptyL.Visible = true
        searchEmptyL.TextTransparency = 1
        Tw(searchEmptyL, {TextTransparency = 0}, 0.15)
        return
    end

    searchEmptyL.Visible = false

    -- Group matches by tab
    local tabGroups = {}
    local tabNamesOrdered = {}
    for _, t in ipairs(matches) do
        local tn = t.tabName or "Other"
        if not tabGroups[tn] then
            tabGroups[tn] = {}
            table.insert(tabNamesOrdered, tn)
        end
        table.insert(tabGroups[tn], t)
    end

    local leftCount, rightCount = 0, 0
    local leftOrder, rightOrder = 0, 0

    for _, tn in ipairs(tabNamesOrdered) do
        local itemsInTab = tabGroups[tn]
        local isLeft = (leftCount <= rightCount)

        if isLeft then
            leftOrder += 1
            leftCount += 1
            local secF, secL = Section(searchLeftSF, tn:upper() .. "  →", leftOrder)
            local sBtn = Instance.new("TextButton")
            sBtn.Size = UDim2.new(1, 0, 1, 0); sBtn.BackgroundTransparency = 1; sBtn.Text = ""
            sBtn.ZIndex = 5; sBtn.Parent = secF
            sBtn.MouseButton1Click:Connect(function()
                SwitchTab(tn)
            end)
            sBtn.MouseEnter:Connect(function() Tw(secL, {TextColor3 = T.accent}, 0.1) end)
            sBtn.MouseLeave:Connect(function() Tw(secL, {TextColor3 = T.secHeader}, 0.1) end)

            for _, t in ipairs(itemsInTab) do
                leftOrder += 1
                leftCount += 1
                CreateSearchResultItem(searchLeftSF, t, leftOrder)
            end
        else
            rightOrder += 1
            rightCount += 1
            local secF, secL = Section(searchRightSF, tn:upper() .. "  →", rightOrder)
            local sBtn = Instance.new("TextButton")
            sBtn.Size = UDim2.new(1, 0, 1, 0); sBtn.BackgroundTransparency = 1; sBtn.Text = ""
            sBtn.ZIndex = 5; sBtn.Parent = secF
            sBtn.MouseButton1Click:Connect(function()
                SwitchTab(tn)
            end)
            sBtn.MouseEnter:Connect(function() Tw(secL, {TextColor3 = T.accent}, 0.1) end)
            sBtn.MouseLeave:Connect(function() Tw(secL, {TextColor3 = T.secHeader}, 0.1) end)

            for _, t in ipairs(itemsInTab) do
                rightOrder += 1
                rightCount += 1
                CreateSearchResultItem(searchRightSF, t, rightOrder)
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  KEYBOARD TOGGLE [Delete] & KEYBINDS LISTENER
-- ══════════════════════════════════════════════
do
    local function MatchBindKey(bKey, inKey)
        if not bKey or not inKey then return false end
        if bKey == inKey or string.lower(tostring(bKey)) == string.lower(tostring(inKey)) then return true end
        if (bKey == "MouseBackButton" or bKey == "MouseButton4" or bKey == "MB4") and
           (inKey == "MouseBackButton" or inKey == "MouseButton4" or inKey == "MB4") then
            return true
        end
        if (bKey == "MouseButton5" or bKey == "MouseForwardButton" or bKey == "MB5") and
           (inKey == "MouseButton5" or inKey == "MouseForwardButton" or inKey == "MB5") then
            return true
        end
        return false
    end

    local function FinishListening(bindKey, shortKey)
        if not listeningTarget then return end
        if listeningTarget.isMenuKey then
            TOGGLE_KEY = bindKey
            if ConfigSystem then ConfigSystem.savedToggleKey = bindKey end
            local sKey = shortKey or FormatKeyName(bindKey)
            if listeningTarget.dotsBtn then
                listeningTarget.dotsBtn.Text = sKey
                listeningTarget.dotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                Tw(listeningTarget.dotsBtn, {TextColor3 = T.accent}, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if listeningTarget.dotsF then
                local s = listeningTarget.dotsF:FindFirstChildOfClass("UIStroke")
                if s then Tw(s, {Color = T.border}, 0.22) end
            end
            listeningTarget = nil
            if Notify then
                Notify("Menu Key", "Set to [" .. sKey .. "]", 2.5, "success")
            end
            SaveConfig()
            return
        end
        local name = listeningTarget.name
        featureBinds[name] = {
            key = bindKey,
            shortKey = shortKey or FormatKeyName(bindKey),
            toggle = listeningTarget.toggle,
            name = name,
        }
        if listeningTarget.dotsBtn then
            listeningTarget.dotsBtn.Text = shortKey or FormatKeyName(bindKey)
            listeningTarget.dotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Tw(listeningTarget.dotsBtn, {TextColor3 = T.accent}, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if listeningTarget.toggle and listeningTarget.toggle.dotsBtn and listeningTarget.toggle.dotsBtn ~= listeningTarget.dotsBtn then
            listeningTarget.toggle.dotsBtn.Text = shortKey or FormatKeyName(bindKey)
            listeningTarget.toggle.dotsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Tw(listeningTarget.toggle.dotsBtn, {TextColor3 = T.accent}, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        if listeningTarget.dotsF then
            local s = listeningTarget.dotsF:FindFirstChildOfClass("UIStroke")
            if s then Tw(s, {Color = T.border}, 0.22) end
        end
        listeningTarget = nil
        if UpdateKeybindsHud then UpdateKeybindsHud() end
        SaveConfig()
    end

    local function TriggerBindByInput(inKey, isDown)
        if not inKey then return end
        for name, bInfo in pairs(featureBinds) do
            if bInfo.toggle and MatchBindKey(bInfo.key, inKey) then
                local mode = bInfo.mode or "Toggle"
                if mode == "Toggle" then
                    if isDown then
                        bInfo.toggle.setToggleState(not bInfo.toggle.isEnabled(), true)
                    end
                elseif mode == "Hold" then
                    bInfo.toggle.setToggleState(isDown, true)
                end
            end
        end
    end

    -- Hardware-level mouse button 4 (VK 0x05) and mouse button 5 (VK 0x06) detection for executors
    local isKeyFunc = iskeydown or (syn and syn.iskeydown) or (crypt and crypt.iskeydown) or iskeypressed
    if isKeyFunc then
        local mb4Held, mb5Held = false, false
        task.spawn(function()
            while true do
                task.wait(0.015)
                if win and win.Parent and (not getgenv or getgenv().NOVA_CURRENT_ID == SCRIPT_ID) then
                    local ok4, d4 = pcall(isKeyFunc, 0x05)
                    local ok5, d5 = pcall(isKeyFunc, 0x06)
                    if listeningTarget then
                        if ok4 and d4 then
                            FinishListening("MouseBackButton", "MB4")
                            task.wait(0.2)
                        elseif ok5 and d5 then
                            FinishListening("MouseButton5", "MB5")
                            task.wait(0.2)
                        end
                    else
                        if ok4 then
                            if d4 and not mb4Held then
                                mb4Held = true
                                if not listeningTarget and MatchBindKey(TOGGLE_KEY, "MouseBackButton") then
                                    if menuOpen then CloseMenu() else OpenMenu() end
                                end
                                TriggerBindByInput("MouseBackButton", true)
                            elseif not d4 and mb4Held then
                                mb4Held = false
                                TriggerBindByInput("MouseBackButton", false)
                            end
                        end
                        if ok5 then
                            if d5 and not mb5Held then
                                mb5Held = true
                                if not listeningTarget and MatchBindKey(TOGGLE_KEY, "MouseButton5") then
                                    if menuOpen then CloseMenu() else OpenMenu() end
                                end
                                TriggerBindByInput("MouseButton5", true)
                            elseif not d5 and mb5Held then
                                mb5Held = false
                                TriggerBindByInput("MouseButton5", false)
                            end
                        end
                    end
                else
                    break
                end
            end
        end)
    end

    table.insert(allConn, UIS.InputBegan:Connect(function(input, gp)
        if not win or not win.Parent or (getgenv and getgenv().NOVA_CURRENT_ID ~= SCRIPT_ID) then
            pcall(function()
                for _, c in ipairs(allConn) do c:Disconnect() end
            end)
            return
        end

        local key = input.KeyCode
        local uType = input.UserInputType
        local kName = (key and key ~= Enum.KeyCode.Unknown and key.Name) or nil

        local isMB4 = (key == Enum.KeyCode.MouseBackButton) or (kName == "MouseBackButton")
            or tostring(uType):find("MouseButton4") or tostring(uType):find("Button4")
            or tostring(key):find("MouseBackButton") or tostring(key):find("Button4")
        local isMB5 = tostring(uType):find("MouseButton5") or tostring(uType):find("Button5")
            or tostring(key):find("MouseForwardButton") or tostring(key):find("Button5")

        -- If currently listening for a key to bind
        if listeningTarget then
            if (os.clock() - (listeningTarget.startTime or 0)) < 0.08 then
                return
            end

            if isMB4 then
                FinishListening("MouseBackButton", "MB4")
                return
            elseif isMB5 then
                FinishListening("MouseButton5", "MB5")
                return
            elseif kName then
                if kName == "Escape" then
                    CancelBinding()
                    return
                elseif kName == "Backspace" or kName == "Delete" then
                    if listeningTarget.isMenuKey then
                        FinishListening(kName, FormatKeyName(kName))
                        return
                    end
                    local name = listeningTarget.name
                    featureBinds[name] = nil
                    if listeningTarget.dotsBtn then
                        listeningTarget.dotsBtn.Text = "..."
                        Tw(listeningTarget.dotsBtn, {TextColor3 = T.textMuted}, 0.15)
                    end
                    if listeningTarget.toggle and listeningTarget.toggle.dotsBtn and listeningTarget.toggle.dotsBtn ~= listeningTarget.dotsBtn then
                        listeningTarget.toggle.dotsBtn.Text = "..."
                        Tw(listeningTarget.toggle.dotsBtn, {TextColor3 = T.textMuted}, 0.15)
                    end
                    if listeningTarget.dotsF then
                        local s = listeningTarget.dotsF:FindFirstChildOfClass("UIStroke")
                        if s then Tw(s, {Color = T.border}, 0.15) end
                    end
                    listeningTarget = nil
                    if UpdateKeybindsHud then UpdateKeybindsHud() end
                    SaveConfig()
                    return
                else
                    FinishListening(kName, FormatKeyName(kName))
                    return
                end
            elseif uType == Enum.UserInputType.MouseButton1 then
                FinishListening("MouseButton1", "MB1")
                return
            elseif uType == Enum.UserInputType.MouseButton2 then
                FinishListening("MouseButton2", "MB2")
                return
            elseif uType == Enum.UserInputType.MouseButton3 then
                FinishListening("MouseButton3", "MB3")
                return
            end
            return
        end

        -- Toggle Menu Key
        local kn = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        local isToggleMatch = MatchBindKey(TOGGLE_KEY, kn)
        if not isToggleMatch and isMB4 and MatchBindKey(TOGGLE_KEY, "MouseBackButton") then
            isToggleMatch = true
        elseif not isToggleMatch and isMB5 and MatchBindKey(TOGGLE_KEY, "MouseButton5") then
            isToggleMatch = true
        elseif not isToggleMatch and uType == Enum.UserInputType.MouseButton1 and MatchBindKey(TOGGLE_KEY, "MouseButton1") then
            isToggleMatch = true
        elseif not isToggleMatch and uType == Enum.UserInputType.MouseButton2 and MatchBindKey(TOGGLE_KEY, "MouseButton2") then
            isToggleMatch = true
        elseif not isToggleMatch and uType == Enum.UserInputType.MouseButton3 and MatchBindKey(TOGGLE_KEY, "MouseButton3") then
            isToggleMatch = true
        end

        if isToggleMatch then
            local focusedTB = UIS:GetFocusedTextBox()
            if focusedTB then
                local isNonChar = (kn == "Delete" or kn == "Insert" or kn == "RightShift" or kn == "RightControl" or kn == "LeftAlt" or kn == "RightAlt" or kn:sub(1,1) == "F" or isMB4 or isMB5)
                if not isNonChar then
                    return
                end
            end
            if menuOpen then
                CloseMenu()
            else
                OpenMenu()
            end
            return
        end

        -- Check if click is inside the menu window (don't trigger game binds if interacting with open menu)
        local isInsideMenu = false
        if menuOpen and win and win.Parent then
            local mPos = UIS:GetMouseLocation()
            local wPos = win.AbsolutePosition
            local wSize = win.AbsoluteSize
            if mPos.X >= wPos.X and mPos.X <= wPos.X + wSize.X and mPos.Y >= wPos.Y and mPos.Y <= wPos.Y + wSize.Y then
                isInsideMenu = true
            end
        end

        -- If typing in chat or game textbox, ignore keyboard binds (unless it's MouseBackButton)
        if gp and input.UserInputType == Enum.UserInputType.Keyboard and not isMB4 then
            return
        end

        -- Check if pressed key matches any bound feature
        local pressedKey = nil
        if isMB4 then
            pressedKey = "MouseBackButton"
        elseif isMB5 then
            pressedKey = "MouseButton5"
        elseif kName then
            pressedKey = kName
        elseif not isInsideMenu then
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                pressedKey = "MouseButton1"
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                pressedKey = "MouseButton2"
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                pressedKey = "MouseButton3"
            end
        end

        if pressedKey then
            TriggerBindByInput(pressedKey, true)
        end
    end))

    table.insert(allConn, UIS.InputEnded:Connect(function(input)
        local key = input.KeyCode
        local uType = input.UserInputType
        local kName = (key and key ~= Enum.KeyCode.Unknown and key.Name) or nil

        local isMB4 = (key == Enum.KeyCode.MouseBackButton) or (kName == "MouseBackButton")
            or tostring(uType):find("MouseButton4") or tostring(uType):find("Button4")
            or tostring(key):find("MouseBackButton") or tostring(key):find("Button4")
        local isMB5 = tostring(uType):find("MouseButton5") or tostring(uType):find("Button5")
            or tostring(key):find("MouseForwardButton") or tostring(key):find("Button5")

        local releasedKey = nil
        if isMB4 then
            releasedKey = "MouseBackButton"
        elseif isMB5 then
            releasedKey = "MouseButton5"
        elseif kName then
            releasedKey = kName
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            releasedKey = "MouseButton1"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            releasedKey = "MouseButton2"
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            releasedKey = "MouseButton3"
        end

        if releasedKey then
            TriggerBindByInput(releasedKey, false)
        end
    end))
end
-- Initial HUD render
if UpdateKeybindsHud then UpdateKeybindsHud() end
if Triggerbot and Triggerbot.UpdateConnection then pcall(Triggerbot.UpdateConnection) end

print("[NOVA] Loaded | [" .. FormatKeyName(TOGGLE_KEY) .. "] to toggle")

task.defer(function()
    -- Smooth injection delay: ensures Roblox finishes viewport, character, and assets loading
    task.wait(0.35)

    if HitEffects then HitEffects.canPlay = true end

    pcall(function()
        local SoundService = game:GetService("SoundService")
        local s = Instance.new("Sound")
        s.Name = "NOVA_InjectSound"
        s.SoundId = "rbxassetid://4590662766"
        s.Volume = 0.55
        s.Parent = SoundService
        if SoundService.PlayLocalSound then
            SoundService:PlayLocalSound(s)
        else
            s:Play()
        end
        task.delay(3, function() pcall(function() s:Destroy() end) end)
    end)

    if Notify then
        Notify("NOVA", "Loaded successfully | [" .. FormatKeyName(TOGGLE_KEY) .. "] to toggle", 4.5, "success")
    end

    if Watermark and Watermark.SetVisible and (Watermark.visible ~= false) then
        Watermark.SetVisible(true, true)
    end

    if OpenMenu then OpenMenu() end
end)
