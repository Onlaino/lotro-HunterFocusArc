import "Turbine"
import "Turbine.Gameplay"
import "Turbine.UI"
import "Turbine.UI.Lotro"

local PLUGIN_NAME = "Hunter Focus Arc"
local DATA_NAME = "HunterFocusArcSettings"
local BASE_WIDTH = 140
local BASE_HEIGHT = 100
local MIN_SIZE = 50
local MAX_SIZE = 300
local FORMS = {
    arc = "Arc", bow = "Bow", quiver = "Ranger Quiver",
    sigil = "Three Paths Sigil", fan = "Arrow Fan", line = "Focus Line",
    branch = "Lorien Branch"
}
local FORM_ORDER = { "arc", "bow", "quiver", "sigil", "fan", "line", "branch" }
local STYLES = {
    moon = "Moon Silver", sun = "Sun Bronze",
    forest = "Lorien Gold", shadow = "Shadow Obsidian"
}
local STYLE_ORDER = { "moon", "sun", "forest", "shadow" }

local function imageDirectory(form, style)
    if form == "bow" and style == "moon" then
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
    rotation = tonumber(saved.rotation) or 0,
    visible = saved.visible ~= false,
    -- Migrate 1.7.x's single theme setting without changing its appearance.
    form = FORMS[saved.form] and saved.form or
        (saved.theme == "bow" and "bow" or "arc"),
    style = STYLES[saved.style] and saved.style or "moon"
}

if settings.size < MIN_SIZE or settings.size > MAX_SIZE then
    settings.size = 115
end
settings.rotation = math.floor(settings.rotation + 0.5) % 360

local window = Turbine.UI.Window()
local image = Turbine.UI.Control()
image:SetParent(window)
image:SetPosition(0, 0)
image:SetMouseVisible(false)
image:SetSize(BASE_WIDTH, BASE_HEIGHT)

local editMode = false
local dragging = false
local rotating = false
local dragX = 0
local dragY = 0
local rotationStart = 0
local refreshTransform = function() end

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

local function applyRotation()
    -- Rotating the parent avoids SetStretchMode interfering with image rotation.
    window:SetRotation({ x = 0, y = 0, z = settings.rotation })
end

local function clampPosition()
    local width, height = window:GetSize()
    local radians = math.rad(settings.rotation)
    local cosine, sine = math.abs(math.cos(radians)), math.abs(math.sin(radians))
    local halfWidth = (width * cosine + height * sine) / 2
    local halfHeight = (width * sine + height * cosine) / 2
    local screenWidth = Turbine.UI.Display.GetWidth()
    local screenHeight = Turbine.UI.Display.GetHeight()
    local centerX = window:GetLeft() + width / 2
    local centerY = window:GetTop() + height / 2
    if halfWidth * 2 > screenWidth then
        centerX = screenWidth / 2
    else
        centerX = math.max(halfWidth, math.min(screenWidth - halfWidth, centerX))
    end
    if halfHeight * 2 > screenHeight then
        centerY = screenHeight / 2
    else
        centerY = math.max(halfHeight, math.min(screenHeight - halfHeight, centerY))
    end
    window:SetPosition(math.floor(centerX - width / 2 + 0.5),
        math.floor(centerY - height / 2 + 0.5))
end

local function setSize(value)
    value = math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(value + 0.5)))
    if settings.size == value then return end
    settings.size = value
    applySize()
    applyRotation()
    clampPosition()
    refreshTransform()
    save()
end

local function setRotation(value, persist)
    value = math.floor(value + 0.5) % 360
    if settings.rotation == value then return end
    settings.rotation = value
    applyRotation()
    clampPosition()
    refreshTransform()
    if persist ~= false then save() end
end

local function applyEditMode()
    window:SetMouseVisible(editMode)
    if editMode then
        window:SetBackColor(Turbine.UI.Color(0.16, 0.10, 0.24, 0.20))
    else
        window:SetBackColor(Turbine.UI.Color(0, 0, 0, 0))
        dragging = false
        rotating = false
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

local appearanceControls = {}
local transformControls = {}
local function onPage(control, page)
    table.insert(page, control)
    return control
end

local appearanceTab = Turbine.UI.Lotro.Button()
appearanceTab:SetParent(optionsPanel)
appearanceTab:SetPosition(12, 7)
appearanceTab:SetSize(140, 26)
appearanceTab:SetText("Appearance")

local transformTab = Turbine.UI.Lotro.Button()
transformTab:SetParent(optionsPanel)
transformTab:SetPosition(157, 7)
transformTab:SetSize(140, 26)
transformTab:SetText("Size / rotation")

local function showOptionPage(page)
    for _, control in ipairs(appearanceControls) do
        control:SetVisible(page == "appearance")
    end
    for _, control in ipairs(transformControls) do
        control:SetVisible(page == "transform")
    end
end
appearanceTab.Click = function() showOptionPage("appearance") end
transformTab.Click = function() showOptionPage("transform") end

formStatus = onPage(Turbine.UI.Label(), appearanceControls)
formStatus:SetParent(optionsPanel)
formStatus:SetPosition(12, 39)
formStatus:SetSize(185, 20)
formStatus:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))

styleStatus = onPage(Turbine.UI.Label(), appearanceControls)
styleStatus:SetParent(optionsPanel)
styleStatus:SetPosition(12, 60)
styleStatus:SetSize(185, 20)
styleStatus:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))

preview = onPage(Turbine.UI.Control(), appearanceControls)
preview:SetParent(optionsPanel)
preview:SetPosition(205, 38)
preview:SetSize(96, 69)
preview:SetMouseVisible(false)
preview:SetStretchMode(1)

local function addHeading(caption, top)
    local label = onPage(Turbine.UI.Label(), appearanceControls)
    label:SetParent(optionsPanel)
    label:SetPosition(12, top)
    label:SetSize(280, 20)
    label:SetText(caption)
    label:SetForeColor(Turbine.UI.Color(0.88, 0.89, 0.75))
end

local function addChoice(value, index, top, target, callback)
    local button = onPage(Turbine.UI.Lotro.Button(), appearanceControls)
    button:SetParent(optionsPanel)
    button:SetPosition(12 + ((index - 1) % 2) * 145,
        top + math.floor((index - 1) / 2) * 25)
    button:SetSize(140, 24)
    button.Click = function()
        callback(value)
    end
    target[value] = button
end

addHeading("Form", 82)
for index, form in ipairs(FORM_ORDER) do
    addChoice(form, index, 101, formButtons,
        function(value) setAppearance(value, settings.style) end)
end
addHeading("Style", 203)
for index, style in ipairs(STYLE_ORDER) do
    addChoice(style, index, 222, styleButtons,
        function(value) setAppearance(settings.form, value) end)
end

local function transformLabel(top, width)
    local label = onPage(Turbine.UI.Label(), transformControls)
    label:SetParent(optionsPanel)
    label:SetPosition(12, top)
    label:SetSize(width or 285, 22)
    label:SetForeColor(Turbine.UI.Color(0.72, 0.92, 0.87))
    return label
end

local sizeStatus = transformLabel(48)
local rotationStatus = transformLabel(130)
local hint = transformLabel(247)
hint:SetText("Drag: move   Right drag: turn   Wheel: size")

local function transformButton(caption, left, top, width, callback)
    local button = onPage(Turbine.UI.Lotro.Button(), transformControls)
    button:SetParent(optionsPanel)
    button:SetPosition(left, top)
    button:SetSize(width, 26)
    button:SetText(caption)
    button.Click = callback
    return button
end

transformButton("-10", 12, 77, 68, function() setSize(settings.size - 10) end)
transformButton("-1", 84, 77, 68, function() setSize(settings.size - 1) end)
transformButton("+1", 157, 77, 68, function() setSize(settings.size + 1) end)
transformButton("+10", 229, 77, 68, function() setSize(settings.size + 10) end)
transformButton("-15", 12, 160, 68, function() setRotation(settings.rotation - 15) end)
transformButton("-1", 84, 160, 68, function() setRotation(settings.rotation - 1) end)
transformButton("+1", 157, 160, 68, function() setRotation(settings.rotation + 1) end)
transformButton("+15", 229, 160, 68, function() setRotation(settings.rotation + 15) end)
transformButton("Size 100%", 12, 207, 140, function() setSize(100) end)
transformButton("Angle 0", 157, 207, 140, function() setRotation(0) end)

refreshTransform = function()
    sizeStatus:SetText("Size: " .. settings.size .. "%  (50-300%)")
    rotationStatus:SetText("Rotation: " .. settings.rotation .. " degrees")
end
refreshOptions()
refreshTransform()
showOptionPage("appearance")

plugin.GetOptionsPanel = function()
    return optionsPanel
end

window.MouseDown = function(sender, args)
    if not editMode then return end
    dragX = args.X
    dragY = args.Y
    if args.Button == Turbine.UI.MouseButton.Right then
        rotating = true
        rotationStart = settings.rotation
    else
        dragging = true
    end
end

window.MouseMove = function(sender, args)
    if rotating then
        setRotation(rotationStart + args.X - dragX, false)
        return
    end
    if not dragging then return end
    window:SetPosition(window:GetLeft() + args.X - dragX, window:GetTop() + args.Y - dragY)
    clampPosition()
end

window.MouseUp = function()
    if not dragging and not rotating then return end
    dragging = false
    rotating = false
    save()
end

window.MouseWheel = function(sender, args)
    if not editMode then return end
    local direction = tonumber(args.Direction or args.WheelDelta) or 0
    if direction == 0 then return end
    setSize(settings.size + (direction > 0 and 5 or -5))
    args.Handled = true
end

window.VisibleChanged = function()
    if window:IsVisible() then applyRotation() end
end

applySize()
applyRotation()
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
            say("Usage: /hfocus size 50-300")
            return
        end
        setSize(size)
        say("Size: " .. settings.size .. "%")
    elseif action == "rotate" then
        local angle = tonumber(value)
        if value == "reset" then angle = 0 end
        if not angle then
            say("Usage: /hfocus rotate 0-359 | reset")
            return
        end
        setRotation(angle)
        say("Rotation: " .. settings.rotation .. " degrees")
    elseif action == "form" then
        if value == "next" then
            setAppearance(nextValue(FORM_ORDER, settings.form), settings.style)
        elseif FORMS[value] then
            setAppearance(value, settings.style)
        else
            say("Forms: arc, bow, quiver, sigil, fan, line, branch. Current: " .. settings.form)
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
        say("Forms: arc, bow, quiver, sigil, fan, line, branch.")
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
        settings.rotation = 0
        settings.visible = true
        applySize()
        applyRotation()
        window:SetPosition(
            math.floor((Turbine.UI.Display.GetWidth() - window:GetWidth()) / 2),
            math.floor((Turbine.UI.Display.GetHeight() - window:GetHeight()) / 2)
        )
        refreshTransform()
        window:SetVisible(true)
        save()
        say("Position, size and rotation reset.")
    else
        say("Commands: /hfocus form arc|bow|quiver|sigil|fan|line|branch; style moon|sun|forest|shadow; size 50-300; rotate 0-359; show, hide, reset")
    end
end

Turbine.Shell.AddCommand("hfocus", command)
say("Loaded: " .. FORMS[settings.form] .. " / " .. STYLES[settings.style] .. ". Move, turn or resize in UI layout mode; type /hfocus for commands.")

plugin.Unload = function()
    save()
    removeCallback(classAttributes, "FocusChanged", onFocusChanged)
    keyListener:SetWantsKeyEvents(false)
    keyListener:SetVisible(false)
    Turbine.Shell.RemoveCommand(command)
end


