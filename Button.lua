-- # Requested
-- # idk

local insert = table.insert

local maid = {}
maid.__index = maid

function maid.new()
    return setmetatable({tasks = {}, destroyed = false}, maid)
end

function maid:givetask(task)
    if self.destroyed then self:cleantask(task) return end
    insert(self.tasks, task)
    return task
end

function maid:cleantask(task)
    local kind = typeof(task)
    if kind == "RBXScriptConnection" then task:Disconnect()
    elseif kind == "Instance" then task:Destroy()
    elseif kind == "function" then task()
    elseif kind == "table" and type(task.Destroy) == "function" then task:Destroy() end
end

function maid:clean()
    if self.destroyed then return end
    self.destroyed = true
    for _, task in ipairs(self.tasks) do
        self:cleantask(task)
    end
    self.tasks = {}
end

function maid:destroy() self:clean() end

local rootmaid = maid.new()

local shared = odh_shared_plugins

task.spawn(function()
    pcall(function()
        shared.loadfromurl("/aux0on/CrashHandler/refs/heads/main/Prevention.lua")
    end)
end)

local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local inputservice = game:GetService("UserInputService")
local httpservice = game:GetService("HttpService")
local coregui = game:GetService("CoreGui")

local localplayer = players.LocalPlayer

local positionfile = "shiftlock_positions.json"

local function loadpositions()
    local ok, content = pcall(readfile, positionfile)
    if ok and content and content ~= "" then
        local decok, data = pcall(function() return httpservice:JSONDecode(content) end)
        if decok and type(data) == "table" then return data end
    end
    return {}
end

local function saveposition(id, pos)
    local positions = loadpositions()
    positions[id] = {xs = pos.X.Scale, xo = pos.X.Offset, ys = pos.Y.Scale, yo = pos.Y.Offset}
    pcall(function() writefile(positionfile, httpservice:JSONEncode(positions)) end)
end

local macro = shared.CreateTab("Shiftlock", "/UrexampleGD/ok-icon/refs/heads/main/images__2_-removebg-preview")

local about = macro:AddSection("About", "Information")

about:AddParagraph("Shiftlock", "gugu")

pcall(function() shared.Notify("Shiftlock Loaded", 2) end)

local section = macro:AddSection("Shiftlock", "Moveable Shiftlock")

local shiftlockmaid = maid.new()
rootmaid:givetask(shiftlockmaid)

local activebutton = nil
local activemaid = maid.new()
local lastposition = nil
local enabled = false

local function scansomething(root, pattern)
    if not root then return nil end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("GuiButton") then
            local lower = string.lower(desc.Name)
            if string.find(lower, pattern, 1, true) then
                return desc
            end
        end
    end
    return nil
end

local function findbutton()
    local pg = localplayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local topbar = pg:FindFirstChild("GameTopBar")
    if topbar then
        local container = topbar:FindFirstChild("Container")
        if container then
            local btn = container:FindFirstChild("MouseLock")
            if btn and btn:IsA("GuiButton") then return btn end
        end
        local direct = topbar:FindFirstChild("MouseLock", true)
        if direct and direct:IsA("GuiButton") then return direct end
    end

    local byname = scansomething(pg, "mouselock")
    if byname then return byname end

    local bylock = scansomething(pg, "lock")
    if bylock then return bylock end

    local bymouse = scansomething(pg, "mouse")
    if bymouse then return bymouse end

    return nil
end

local function dumpgui()
    local pg = localplayer:FindFirstChild("PlayerGui")
    if not pg then
        pcall(function() shared.Notify("PlayerGui missing", 3) end)
        return
    end
    local found = {}
    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("GuiButton") then
            table.insert(found, desc.Name)
        end
    end
    local topbar = pg:FindFirstChild("GameTopBar")
    local topstatus = topbar and "yes" or "no"
    local msg = "TopBar:" .. topstatus .. " Buttons:" .. tostring(#found)
    pcall(function() shared.Notify(msg, 5) end)
end

local function getfloat()
    local existing = coregui:FindFirstChild("@ShiftlockFloat")
    if existing then return existing end
    local screen = Instance.new("ScreenGui")
    screen.Name = "@ShiftlockFloat"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999999
    screen.Parent = coregui
    return screen
end

local function harvest(btn)
    local abs = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return false end
    btn.Parent = getfloat()
    btn.AnchorPoint = Vector2.new(0, 0)
    btn.Size = UDim2.fromOffset(size.X, size.Y)
    btn.Position = UDim2.fromOffset(abs.X, abs.Y)
    return true
end

local function makedraggable(btn)
    activemaid:clean()
    activemaid = maid.new()

    local dragging = false
    local dragstart = nil
    local startpos = nil
    local moved = false
    local wasactive = btn.Active

    activemaid:givetask(btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragstart = input.Position
            startpos = btn.Position
        end
    end))

    activemaid:givetask(inputservice.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragstart
            if not moved and delta.Magnitude > 4 then
                moved = true
                pcall(function() btn.Active = false end)
            end
            if moved then
                btn.Position = UDim2.new(startpos.X.Scale, startpos.X.Offset + delta.X, startpos.Y.Scale, startpos.Y.Offset + delta.Y)
                lastposition = btn.Position
            end
        end
    end))

    activemaid:givetask(inputservice.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if moved then
                    lastposition = btn.Position
                    saveposition("_shiftlock", btn.Position)
                    task.delay(0.1, function()
                        pcall(function() btn.Active = wasactive end)
                    end)
                end
            end
        end
    end))
end

local function watch()
    local attempts = 0
    while enabled and attempts < 300 do
        local btn = findbutton()
        if btn and btn.Visible and btn.AbsoluteSize.X > 0 then
            activebutton = btn
            harvest(btn)
            local saved = loadpositions()["_shiftlock"]
            if saved then
                lastposition = UDim2.new(saved.xs or 0, saved.xo or 0, saved.ys or 0, saved.yo or 0)
                pcall(function() btn.Position = lastposition end)
            else
                lastposition = btn.Position
            end
            makedraggable(btn)
            pcall(function() shared.Notify("Shiftlock hooked", 2) end)
            return
        end
        attempts = attempts + 1
        task.wait(0.1)
    end
    if enabled then
        dumpgui()
        pcall(function() shared.Notify("Shiftlock button not found", 3) end)
    end
end

local function applyshiftlock(on)
    enabled = on
    activebutton = nil
    lastposition = nil
    activemaid:clean()
    activemaid = maid.new()
    shiftlockmaid:clean()
    shiftlockmaid = maid.new()
    rootmaid:givetask(shiftlockmaid)

    if not on then
        return
    end

    shiftlockmaid:givetask(runservice.Heartbeat:Connect(function()
        if not enabled then return end
        if not activebutton or not activebutton.Parent then
            activebutton = nil
            task.spawn(watch)
            return
        end
        local current = findbutton()
        if current and current ~= activebutton then
            activebutton = nil
            task.spawn(watch)
            return
        end
        if lastposition then
            pcall(function() activebutton.Position = lastposition end)
        end
    end))

    task.spawn(watch)
end

section:AddLabel("Shiftlock Options")
section:AddToggle("Moveable Shiftlock", function(state)
    applyshiftlock(state)
end)
section:AddButton("Reset Shiftlock Position", function()
    local positions = loadpositions()
    positions["_shiftlock"] = nil
    pcall(function() writefile(positionfile, httpservice:JSONEncode(positions)) end)
    lastposition = nil
    if activebutton then
        lastposition = activebutton.Position
    end
    pcall(function() shared.Notify("Shiftlock position reset", 2) end)
end)
section:AddButton("Dump Gui Info", function()
    dumpgui()
end)
