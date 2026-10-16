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
local inputservice = game:GetService("UserInputService")
local runservice = game:GetService("RunService")
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

local tab = shared.CreateTab("Shiftlock", "/UrexampleGD/ok-icon/refs/heads/main/images__2_-removebg-preview")

local about = tab:AddSection("About", "Information")
about:AddParagraph("Made by EXIRL", "Plugin Author")

pcall(function() shared.Notify("Shiftlock Loaded", 2) end)

local section = tab:AddSection("Shiftlock", "Moveable Shiftlock")

local shiftmaid = maid.new()
rootmaid:givetask(shiftmaid)

local activeframe = nil
local dragmaid = maid.new()
local lastpos = nil
local enabled = false

local function getfloat()
    local ok, existing = pcall(function() return coregui:FindFirstChild("@ShiftlockFloat") end)
    if ok and existing then return existing end

    local parent = coregui
    pcall(function()
        if gethui then parent = gethui() end
    end)

    local screen = Instance.new("ScreenGui")
    screen.Name = "@ShiftlockFloat"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 2147483647
    pcall(function() screen.ScreenInsets = Enum.ScreenInsets.None end)
    screen.Parent = parent
    return screen
end

local function findframe()
    local pg = localplayer:FindFirstChild("PlayerGui")
    if not pg then return nil, "no playergui" end

    local topbar = pg:FindFirstChild("GameTopBar")
    if not topbar then return nil, "no gametopbar" end

    local container = topbar:FindFirstChild("Container")
    if not container then return nil, "no topbar container" end

    local mouselock = container:FindFirstChild("MouseLock")
    if not mouselock then return nil, "no mouselock" end

    return mouselock, "ok"
end

local function hookframe()
    local frame, reason = findframe()
    if not frame then return false, reason end

    if frame.AbsoluteSize.X <= 0 or frame.AbsoluteSize.Y <= 0 then
        return false, "size zero"
    end

    dragmaid:clean()
    dragmaid = maid.new()

    local abs = frame.AbsolutePosition
    local size = frame.AbsoluteSize

    frame.Parent = getfloat()
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Size = UDim2.fromOffset(size.X, size.Y)
    frame.Position = UDim2.fromOffset(abs.X, abs.Y)
    frame.ZIndex = 100

    activeframe = frame

    local saved = loadpositions()["_shiftlock"]
    if saved then
        lastpos = UDim2.new(saved.xs or 0, saved.xo or 0, saved.ys or 0, saved.yo or 0)
    else
        lastpos = frame.Position
    end
    frame.Position = lastpos

    local dragging = false
    local dragstart = nil
    local startpos = nil
    local moved = false

    dragmaid:givetask(frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragstart = input.Position
            startpos = frame.Position
        end
    end))

    dragmaid:givetask(inputservice.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragstart
            if not moved and delta.Magnitude > 3 then
                moved = true
            end
            if moved then
                local newpos = UDim2.new(startpos.X.Scale, startpos.X.Offset + delta.X, startpos.Y.Scale, startpos.Y.Offset + delta.Y)
                frame.Position = newpos
                lastpos = newpos
            end
        end
    end))

    dragmaid:givetask(inputservice.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragging then
            dragging = false
            if moved then
                lastpos = frame.Position
                saveposition("_shiftlock", frame.Position)
            end
        end
    end))

    dragmaid:givetask(frame.AncestryChanged:Connect(function()
        if frame.Parent ~= getfloat() and frame.Parent then
            task.defer(function()
                if frame.Parent and frame.Parent ~= getfloat() then
                    local abs2 = frame.AbsolutePosition
                    local size2 = frame.AbsoluteSize
                    frame.Parent = getfloat()
                    frame.AnchorPoint = Vector2.new(0, 0)
                    frame.Size = UDim2.fromOffset(size2.X, size2.Y)
                    frame.Position = lastpos or UDim2.fromOffset(abs2.X, abs2.Y)
                end
            end)
        end
    end))

    dragmaid:givetask(runservice.RenderStepped:Connect(function()
        if frame and frame.Parent and lastpos then
            pcall(function()
                frame.Position = lastpos
            end)
        end
    end))

    return true, "hooked"
end

local function apply(on)
    enabled = on
    activeframe = nil
    lastpos = nil
    dragmaid:clean()
    dragmaid = maid.new()
    shiftmaid:clean()
    shiftmaid = maid.new()
    rootmaid:givetask(shiftmaid)

    if not on then
        return
    end

    shiftmaid:givetask(task.spawn(function()
        local attempts = 0
        local lastreason = ""
        while enabled and attempts < 60 do
            local ok, reason = hookframe()
            if ok then
                pcall(function() shared.Notify("Shiftlock hooked", 2) end)
                return
            end
            lastreason = reason or "?"
            attempts = attempts + 1
            task.wait(0.25)
        end
        if enabled then
            pcall(function() shared.Notify("Shiftlock fail: " .. lastreason, 5) end)
        end
    end))

    shiftmaid:givetask(task.spawn(function()
        while enabled do
            task.wait(1)
            if not enabled then break end
            if not activeframe or not activeframe.Parent then
                activeframe = nil
                local ok = hookframe()
                if not ok then
                    lastpos = nil
                end
            end
        end
    end))
end

section:AddLabel("Shiftlock Options")
section:AddToggle("Moveable Shiftlock", function(state)
    apply(state)
end)
section:AddButton("Reset Shiftlock Position", function()
    local positions = loadpositions()
    positions["_shiftlock"] = nil
    pcall(function() writefile(positionfile, httpservice:JSONEncode(positions)) end)
    lastpos = nil
    if activeframe then
        lastpos = activeframe.Position
    end
    pcall(function() shared.Notify("Shiftlock position reset", 2) end)
end)
