import "Turbine"
import "Turbine.Gameplay"
import "Turbine.UI"
import "Turbine.UI.Lotro"

local PLUGIN_NAME = "Hunter Focus Arc"
local DATA_NAME = "HunterFocusArcSettings"
local BASE_WIDTH = 140
local BASE_HEIGHT = 100
local MIN_SIZE = 80
local MAX_SIZE = 200
local THEMES = {
    moon = { name = "Moon Hunter", images = "HunterFocusArc/Images" },
    bow = { name = "Lunar Bow", images = "HunterFocusArc/Images/Bow" }
}

local function say(message)
    Turbine.Shell.WriteLine("[" .. PLUGIN_NAME .. "] " .. message)
end

local function addCallback(object, event, callback)
    if object[event] == nil then
        object[event] = callback
    elseif type(object[event]) == "table" then
        table.insert(object[event], callback)
    else
        object[event] = { object[event], callback }
    end
end

local function removeCallback(object, event, callback)
    if object[event] == callback then
        object[event] = nil
    elseif type(object[event]) == "table" then
        for i = 1, #object[event] do
            if object[event][i] == callback then
                table.remove(object[event], i)
                break
            end
        end
    end
end

local player = Turbine.Gameplay.LocalPlayer.GetInstance()
if player:GetClass() ~= Turbine.Gameplay.Class.Hunter then
    say("This display is available only for Hunters.")
    return
end

local classAttributes = player:GetClassAttributes()
local saved = Turbine.PluginData.Load(Turbine.DataScope.Character, DATA_NAME) or {}
local settings = {
    x = tonumber(saved.x),
    y = tonumber(saved.y),
    size = tonumber(saved.size) or 115,
    visible = saved.visible ~= false,
    theme = THEMES[saved.theme] and saved.theme or "moon"
}

if settings.size < MIN_SIZE or settings.size > MAX_SIZE then
    settings.size = 115
end

local window = Turbine.UI.Window()
local image = Turbine.UI.Control()
image:SetParent(window)
image:SetPosition(0, 0)
image:SetMouseVisible(false)
image:SetSize(BASE_WIDTH, BASE_HEIGHT)

local editMode = false
local dragging = false
local dragX = 0
local dragY = 0

local function save()
    settings.x = window:GetLeft()
    settings.y = window:GetTop()
    Turbine.PluginData.Save(Turbine.DataScope.Character, DATA_NAME, settings)
end

local function applySize()
    local factor = settings.size / 100
    local width = math.floor(BASE_WIDTH * factor + 0.5)
    local height = math.floor(BASE_HEIGHT * factor + 0.5)
    window:SetSize(width, height)
    image:SetSize(width, height)
end

local function clampPosition()
    local maxX = math.max(0, Turbine.UI.Display.GetWidth() - window:GetWidth())
    local maxY = math.max(0, Turbine.UI.Display.GetHeight() - window:GetHeight())
    local x = math.max(0, math.min(maxX, window:GetLeft()))
    local y = math.max(0, math.min(maxY, window:GetTop()))
    window:SetPosition(x, y)
end

local function applyEditMode()
    window:SetMouseVisible(editMode)
    if editMode then
        window:SetBackColor(Turbine.UI.Color(0.16, 0.10, 0.24, 0.20))
    else
        window:SetBackColor(Turbine.UI.Color(0, 0, 0, 0))
        dragging = false
    end
end

local lastFocus = -1
local function updateFocus(force)
    local focus = tonumber(classAttributes:GetFocus()) or 0
    focus = math.max(0, math.min(9, math.floor(focus + 0.5)))
    if focus == lastFocus and not force then return end
    lastFocus = focus
    local targetWidth, targetHeight = image:GetSize()
    image:SetSize(BASE_WIDTH, BASE_HEIGHT)
    image:SetBackground(THEMES[settings.theme].images .. "/focus_" .. focus .. ".tga")
    image:SetStretchMode(1)
    image:SetSize(targetWidth, targetHeight)
end

local optionsStatus = nil
local function setTheme(theme)
    if not THEMES[theme] then
        say("Themes: moon (Moon Hunter), bow (Lunar Bow).")
        return
    end
    if settings.theme ~= theme then
        settings.theme = theme
        updateFocus(true)
        save()
    end
    if optionsStatus then
        optionsStatus:SetText("Active: " .. THEMES[settings.theme].name)
    end
    say("Theme: " .. THEMES[settings.theme].name)
end

-- The Plugin Manager calls GetOptionsPanel for its Options tab.
local optionsPanel = Turbine.UI.Control()
optionsPanel:SetSize(310, 280)

local optionsTitle = Turbine.UI.Label()
optionsTitle:SetParent(optionsPanel)
optionsTitle:SetPosition(12, 8)
optionsTitle:SetSize(280, 24)
optionsTitle:SetText("Hunter Focus Arc - themes")
optionsTitle:SetFont(Turbine.UI.Lotro.Font.TrajanPro13)
optionsTitle:SetForeColor(Turbine.UI.Color(0.88, 0.89, 0.75))

optionsStatus = Turbine.UI.Label()
optionsStatus:SetParent(optionsPanel)
optionsStatus:SetPosition(12, 33)
optionsStatus:SetSize(280, 21)
optionsStatus:SetText("Active: " .. THEMES[settings.theme].name)
optionsStatus:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))

local function addThemeChoice(theme, top)
    local button = Turbine.UI.Lotro.Button()
    button:SetParent(optionsPanel)
    button:SetPosition(12, top + 36)
    button:SetSize(130, 26)
    button:SetText(THEMES[theme].name)
    button.Click = function()
        setTheme(theme)
    end

    local preview = Turbine.UI.Control()
    preview:SetParent(optionsPanel)
    preview:SetPosition(155, top)
    preview:SetSize(BASE_WIDTH, BASE_HEIGHT)
    preview:SetMouseVisible(false)
    preview:SetBackground(THEMES[theme].images .. "/focus_6.tga")
    preview:SetStretchMode(1)
end

addThemeChoice("moon", 56)
addThemeChoice("bow", 165)

plugin.GetOptionsPanel = function()
    return optionsPanel
end

window.MouseDown = function(sender, args)
    if not editMode then return end
    dragging = true
    dragX = args.X
    dragY = args.Y
end

window.MouseMove = function(sender, args)
    if not dragging then return end
    window:SetPosition(window:GetLeft() + args.X - dragX, window:GetTop() + args.Y - dragY)
    clampPosition()
end

window.MouseUp = function()
    if not dragging then return end
    dragging = false
    save()
end

applySize()
if settings.x and settings.y then
    window:SetPosition(settings.x, settings.y)
else
    window:SetPosition(
        math.floor((Turbine.UI.Display.GetWidth() - window:GetWidth()) / 2),
        math.floor((Turbine.UI.Display.GetHeight() - window:GetHeight()) / 2)
    )
end
clampPosition()
window:SetVisible(settings.visible)
applyEditMode()
updateFocus()

local onFocusChanged = function() updateFocus() end
addCallback(classAttributes, "FocusChanged", onFocusChanged)

-- LOTRO exposes the layout toggle as an action, not as a readable UI state.
-- Like other plugins, assume normal mode when the plugin is loaded.
local keyListener = Turbine.UI.Window()
keyListener:SetPosition(-10, -10)
keyListener:SetSize(5, 5)
keyListener:SetMouseVisible(false)
keyListener:SetWantsKeyEvents(true)
keyListener:SetVisible(true)
keyListener.KeyDown = function(sender, args)
    if args.Action == 0x1000007B then
        editMode = not editMode
        applyEditMode()
        if not editMode then save() end
    end
end

local command = Turbine.ShellCommand()
function command:Execute(_, arguments)
    arguments = string.lower(arguments or "")
    local action, value = string.match(arguments, "^%s*(%S*)%s*(%S*)")
    if action == "size" then
        local size = tonumber(value)
        if not size or size < MIN_SIZE or size > MAX_SIZE then
            say("Usage: /hfocus size 80-200")
            return
        end
        settings.size = math.floor(size + 0.5)
        applySize()
        clampPosition()
        save()
        say("Size: " .. settings.size .. "%")
    elseif action == "theme" then
        if value == "next" then
            setTheme(settings.theme == "moon" and "bow" or "moon")
        elseif value == "" then
            say("Current theme: " .. THEMES[settings.theme].name .. ". Use /hfocus theme moon|bow|next")
        else
            setTheme(value)
        end
    elseif action == "themes" then
        say("Themes: moon (Moon Hunter), bow (Lunar Bow).")
    elseif action == "show" or action == "hide" then
        settings.visible = action == "show"
        window:SetVisible(settings.visible)
        save()
    elseif action == "reset" then
        settings.x = nil
        settings.y = nil
        settings.size = 115
        settings.visible = true
        applySize()
        window:SetPosition(
            math.floor((Turbine.UI.Display.GetWidth() - window:GetWidth()) / 2),
            math.floor((Turbine.UI.Display.GetHeight() - window:GetHeight()) / 2)
        )
        window:SetVisible(true)
        save()
        say("Position and size reset.")
    else
        say("Commands: /hfocus theme moon|bow|next, size 80-200, show, hide, reset")
    end
end

Turbine.Shell.AddCommand("hfocus", command)
say("Loaded with " .. THEMES[settings.theme].name .. ". Move in UI layout mode; type /hfocus for commands.")

plugin.Unload = function()
    save()
    removeCallback(classAttributes, "FocusChanged", onFocusChanged)
    keyListener:SetWantsKeyEvents(false)
    keyListener:SetVisible(false)
    Turbine.Shell.RemoveCommand(command)
end


