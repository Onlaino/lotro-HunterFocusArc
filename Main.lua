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
local FORMS = {
    arc = "Arc", bow = "Bow", quiver = "Ranger Quiver",
    sigil = "Three Paths Sigil", fan = "Arrow Fan", line = "Focus Line"
}
local FORM_ORDER = { "arc", "bow", "quiver", "sigil", "fan", "line" }
local STYLES = {
    moon = "Moon Silver", sun = "Sun Bronze",
    forest = "Lorien Gold", shadow = "Shadow Obsidian"
}
local STYLE_ORDER = { "moon", "sun", "forest", "shadow" }

local function imageDirectory(form, style)
    if form == "arc" and style == "moon" then
        return "HunterFocusArc/Images"
    elseif form == "bow" and style == "moon" then
        return "HunterFocusArc/Images/Bow"
    end
    return "HunterFocusArc/Images/Variants/" .. form .. "/" .. style
end

local function imagePath(form, style, focus)
    return imageDirectory(form, style) .. "/focus_" .. focus .. ".tga"
end

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
    -- Migrate 1.7.x's single theme setting without changing its appearance.
    form = FORMS[saved.form] and saved.form or
        (saved.theme == "bow" and "bow" or "arc"),
    style = STYLES[saved.style] and saved.style or "moon"
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
    image:SetBackground(imagePath(settings.form, settings.style, focus))
    image:SetStretchMode(1)
    image:SetSize(targetWidth, targetHeight)
end

local formStatus = nil
local styleStatus = nil
local preview = nil
local formButtons = {}
local styleButtons = {}
local function refreshOptions()
    if not formStatus then return end
    formStatus:SetText("Form: " .. FORMS[settings.form])
    styleStatus:SetText("Style: " .. STYLES[settings.style])
    preview:SetBackground(imagePath(settings.form, settings.style, 6))
    for _, form in ipairs(FORM_ORDER) do
        formButtons[form]:SetText((settings.form == form and "> " or "  ") .. FORMS[form])
    end
    for _, style in ipairs(STYLE_ORDER) do
        styleButtons[style]:SetText((settings.style == style and "> " or "  ") .. STYLES[style])
    end
end

local function setAppearance(form, style)
    if not FORMS[form] or not STYLES[style] then return end
    if settings.form ~= form or settings.style ~= style then
        settings.form = form
        settings.style = style
        updateFocus(true)
        save()
    end
    refreshOptions()
    say("Form: " .. FORMS[settings.form] .. "; style: " .. STYLES[settings.style])
end

local function nextValue(order, current)
    for index, value in ipairs(order) do
        if value == current then
            return order[index % #order + 1]
        end
    end
    return order[1]
end

-- The Plugin Manager calls GetOptionsPanel for its Options tab.
local optionsPanel = Turbine.UI.Control()
optionsPanel:SetSize(310, 280)

local optionsTitle = Turbine.UI.Label()
optionsTitle:SetParent(optionsPanel)
optionsTitle:SetPosition(12, 8)
optionsTitle:SetSize(280, 24)
optionsTitle:SetText("Hunter Focus Arc - appearance")
optionsTitle:SetFont(Turbine.UI.Lotro.Font.TrajanPro13)
optionsTitle:SetForeColor(Turbine.UI.Color(0.88, 0.89, 0.75))

formStatus = Turbine.UI.Label()
formStatus:SetParent(optionsPanel)
formStatus:SetPosition(12, 34)
formStatus:SetSize(185, 20)
formStatus:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))

styleStatus = Turbine.UI.Label()
styleStatus:SetParent(optionsPanel)
styleStatus:SetPosition(12, 56)
styleStatus:SetSize(185, 20)
styleStatus:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))

preview = Turbine.UI.Control()
preview:SetParent(optionsPanel)
preview:SetPosition(205, 34)
preview:SetSize(96, 69)
preview:SetMouseVisible(false)
preview:SetStretchMode(1)

local function addHeading(caption, top)
    local label = Turbine.UI.Label()
    label:SetParent(optionsPanel)
    label:SetPosition(12, top)
    label:SetSize(280, 20)
    label:SetText(caption)
    label:SetForeColor(Turbine.UI.Color(0.88, 0.89, 0.75))
end

local function addChoice(value, index, top, target, callback)
    local button = Turbine.UI.Lotro.Button()
    button:SetParent(optionsPanel)
    button:SetPosition(12 + ((index - 1) % 2) * 145,
        top + math.floor((index - 1) / 2) * 27)
    button:SetSize(140, 26)
    button.Click = function()
        callback(value)
    end
    target[value] = button
end

addHeading("Form", 100)
for index, form in ipairs(FORM_ORDER) do
    addChoice(form, index, 120, formButtons,
        function(value) setAppearance(value, settings.style) end)
end
addHeading("Style", 202)
for index, style in ipairs(STYLE_ORDER) do
    addChoice(style, index, 223, styleButtons,
        function(value) setAppearance(settings.form, value) end)
end
refreshOptions()

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
    elseif action == "form" then
        if value == "next" then
            setAppearance(nextValue(FORM_ORDER, settings.form), settings.style)
        elseif FORMS[value] then
            setAppearance(value, settings.style)
        else
            say("Forms: arc, bow, quiver, sigil, fan, line. Current: " .. settings.form)
        end
    elseif action == "style" then
        if value == "next" then
            setAppearance(settings.form, nextValue(STYLE_ORDER, settings.style))
        elseif STYLES[value] then
            setAppearance(settings.form, value)
        else
            say("Styles: moon, sun, forest, shadow. Current: " .. settings.style)
        end
    elseif action == "theme" then
        -- Old commands remain useful for existing users and macros.
        if value == "moon" then
            setAppearance("arc", "moon")
        elseif value == "bow" then
            setAppearance("bow", "moon")
        elseif value == "next" then
            setAppearance(settings.form == "arc" and "bow" or "arc", "moon")
        else
            say("Use /hfocus form and /hfocus style. Legacy: theme moon|bow|next")
        end
    elseif action == "forms" then
        say("Forms: arc, bow, quiver, sigil, fan, line.")
    elseif action == "styles" or action == "themes" then
        say("Styles: moon, sun, forest, shadow.")
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
        say("Commands: /hfocus form arc|bow|quiver|sigil|fan|line; style moon|sun|forest|shadow; size 80-200, show, hide, reset")
    end
end

Turbine.Shell.AddCommand("hfocus", command)
say("Loaded: " .. FORMS[settings.form] .. " / " .. STYLES[settings.style] .. ". Move in UI layout mode; type /hfocus for commands.")

plugin.Unload = function()
    save()
    removeCallback(classAttributes, "FocusChanged", onFocusChanged)
    keyListener:SetWantsKeyEvents(false)
    keyListener:SetVisible(false)
    Turbine.Shell.RemoveCommand(command)
end


