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

about:AddParagraph("Shiftlock", "tududu")

pcall(function() shared.Notify("Shiftlock Loaded", 2) end)

local section = macro:AddSection("Shiftlock", "Moveable Shiftlock")

local shiftlockmaid = maid.new()
rootmaid:givetask(shiftlockmaid)

local activebutton = nil
local activemaid = maid.new()
local lastposition = nil
local keepalive = false

local function findshiftlock()
    local pg = localplayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local topbar = pg:FindFirstChild("GameTopBar")
    if not topbar then return nil end
    local container = topbar:FindFirstChild("Container")
    if not container then return nil end
    local btn = container:FindFirstChild("MouseLock")
    if btn and btn:IsA("GuiButton") then
        return btn
    end
    return nil
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

local function startkeepalive()
    if keepalive then return end
    keepalive = true

    shiftlockmaid:givetask(runservice.RenderStepped:Connect(function()
        if not activebutton then return end
        if not lastposition then return end
        if not activebutton.Parent then
            activebutton = nil
            return
        end
        pcall(function()
            activebutton.Position = lastposition
        end)
    end))
end

local function applyshiftlock(on)
    activebutton = nil
    lastposition = nil
    activemaid:clean()
    activemaid = maid.new()

    if not on then
        keepalive = false
        shiftlockmaid:clean()
        shiftlockmaid = maid.new()
        rootmaid:givetask(shiftlockmaid)
        return
    end

    task.spawn(function()
        local attempts = 0
        while attempts < 200 do
            local btn = findshiftlock()
            if btn then
                activebutton = btn
                local saved = loadpositions()["_shiftlock"]
                if saved then
                    lastposition = UDim2.new(saved.xs or 0, saved.xo or 0, saved.ys or 0, saved.yo or 0)
                    pcall(function() btn.Position = lastposition end)
                else
                    lastposition = btn.Position
                end
                makedraggable(btn)
                startkeepalive()
                pcall(function() shared.Notify("Shiftlock button hooked", 2) end)
                return
            end
            attempts = attempts + 1
            task.wait(0.1)
        end
        pcall(function() shared.Notify("Shiftlock button not found", 3) end)
    end)
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
