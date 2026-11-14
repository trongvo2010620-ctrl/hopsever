if not game:IsLoaded() then game.Loaded:Wait() end

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local placeId = game.PlaceId
local currentJobId = game.JobId

local CONFIG = {
    P1_Min = 7200, P1_Max = 8100,      -- 2h00 -> 2h15 (Ưu tiên 1)
    P2_Min = 8400, P2_Max = 9000,      -- 2h20 -> 2h30 (Ưu tiên 2)
    P3_Min = 5400, P3_Max = 7199,      -- 1h30 -> 1h59 (Mốc thấp hơn dự phòng)
    MaxHopsBeforeFallback = 6,          -- Sau 6 lần hop không có 2h sẽ mở tìm mốc thấp hơn
    WaitCheck = 2.5,
    HopDelay = 1.5,
    StateFile = "kl_hop_state.json"
}

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = dur or 5
        })
    end)
end

local state = { hops = 0, visited = {} }
if isfile and isfile(CONFIG.StateFile) then
    pcall(function()
        state = HttpService:JSONDecode(readfile(CONFIG.StateFile)) or state
    end)
end
state.visited = state.visited or {}
state.visited[currentJobId] = true
state.hops = (state.hops or 0) + 1

local function saveState()
    if writefile then
        pcall(function()
            writefile(CONFIG.StateFile, HttpService:JSONEncode(state))
        end)
    end
end
saveState()

local function getServerTime()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and string.find(obj.Text, "Servertime") then
                local d, h, m, s = string.match(obj.Text, "(%d+):(%d+):(%d+):(%d+)")
                if h and m then
                    local totalSec = (tonumber(d) * 86400) + (tonumber(h) * 3600) + (tonumber(m) * 60) + tonumber(s)
                    return totalSec, tonumber(d), tonumber(h), tonumber(m), tonumber(s)
                end
            end
        end
    end
    local uptime = math.floor(workspace.DistributedGameTime)
    local d = math.floor(uptime / 86400)
    local h = math.floor((uptime % 86400) / 3600)
    local m = math.floor((uptime % 3600) / 60)
    local s = uptime % 60
    return uptime, d, h, m, s
end

local nextCursor = ""
local hopServer

hopServer = function()
    notify("Server Hop", "Lượt #" .. state.hops .. ": Đang tìm server...", 3)
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100%s", tostring(placeId), nextCursor ~= "" and ("&cursor=" .. nextCursor) or "")
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success or not response then
        task.wait(2)
        return hopServer()
    end

    local data = nil
    pcall(function() data = HttpService:JSONDecode(response) end)

    if data and data.data then
        for _, s in ipairs(data.data) do
            if s.id ~= currentJobId and not state.visited[s.id] and s.playing < s.maxPlayers then
                notify("Teleport", "Đang chuyển sang: " .. string.sub(s.id, 1, 8), 3)
                TeleportService:TeleportToPlaceInstance(placeId, s.id, player)
                return
            end
        end

        if data.nextPageCursor and data.nextPageCursor ~= "" then
            nextCursor = data.nextPageCursor
        else
            nextCursor = ""
            state.visited = { [currentJobId] = true }
            saveState()
        end
    end

    task.wait(2)
    hopServer()
end

TeleportService.TeleportInitFailed:Connect(function()
    task.wait(1)
    hopServer()
end)

local function showPromptUI(timeStr, reasonTitle, subMsg)
    local parentTarget = (gethui and gethui()) or CoreGui or player:WaitForChild("PlayerGui")
    local oldGui = parentTarget:FindFirstChild("ServerHopConfirmGui")
    if oldGui then oldGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerHopConfirmGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parentTarget

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 390, 0, 205)
    frame.Position = UDim2.new(0.5, -195, 0.35, -100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(241, 196, 15)
    stroke.Thickness = 2
    stroke.Parent = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 38)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
    titleLabel.Text = "👑 KING LEGACY - " .. reasonTitle
    titleLabel.Parent = frame

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -20, 0, 60)
    messageLabel.Position = UDim2.new(0, 10, 0, 42)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Font = Enum.Font.GothamMedium
    messageLabel.TextSize = 13
    messageLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    messageLabel.TextWrapped = true
    messageLabel.Text = string.format("Thời gian server: %s\n%s\nBạn có muốn TẮT hop server để ở lại không?", timeStr, subMsg or "")
    messageLabel.Parent = frame

    local btnStop = Instance.new("TextButton")
    btnStop.Size = UDim2.new(0, 170, 0, 42)
    btnStop.Position = UDim2.new(0, 15, 0, 135)
    btnStop.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    btnStop.Font = Enum.Font.GothamBold
    btnStop.TextSize = 14
    btnStop.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnStop.Text = "✔ Tắt Hop (Ở lại)"
    btnStop.Parent = frame

    local btnStopCorner = Instance.new("UICorner")
    btnStopCorner.CornerRadius = UDim.new(0, 8)
    btnStopCorner.Parent = btnStop

    local btnContinue = Instance.new("TextButton")
    btnContinue.Size = UDim2.new(0, 170, 0, 42)
    btnContinue.Position = UDim2.new(1, -185, 0, 135)
    btnContinue.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    btnContinue.Font = Enum.Font.GothamBold
    btnContinue.TextSize = 14
    btnContinue.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnContinue.Text = "✖ Tiếp tục Hop"
    btnContinue.Parent = frame

    local btnContinueCorner = Instance.new("UICorner")
    btnContinueCorner.CornerRadius = UDim.new(0, 8)
    btnContinueCorner.Parent = btnContinue

    local clicked = false
    btnStop.MouseButton1Click:Connect(function()
        if clicked then return end
        clicked = true
        state.hops = 0
        saveState()
        notify("Đã Tắt Hop", "Bạn đã chọn ở lại server này.", 5)
        screenGui:Destroy()
    end)

    btnContinue.MouseButton1Click:Connect(function()
        if clicked then return end
        clicked = true
        notify("Tiếp Tục", "Đang tìm server khác...", 3)
        screenGui:Destroy()
        task.wait(0.5)
        hopServer()
    end)
end

task.wait(CONFIG.WaitCheck)
local totalSec, days, hours, mins, secs = getServerTime()
local timeFormatted = string.format("%02dh %02dm %02ds", hours, mins, secs)

local isP1 = (days == 0 and totalSec >= CONFIG.P1_Min and totalSec <= CONFIG.P1_Max)
local isP2 = (days == 0 and totalSec >= CONFIG.P2_Min and totalSec <= CONFIG.P2_Max)
local isP3 = (days == 0 and totalSec >= CONFIG.P3_Min and totalSec <= CONFIG.P3_Max)

if isP1 then
    showPromptUI(timeFormatted, "ĐẠT MỐC ƯU TIÊN 1 (2h - 2h15p)", "Server đúng mốc cao nhất!")
elseif isP2 then
    showPromptUI(timeFormatted, "ĐẠT MỐC ƯU TIÊN 2 (2h20 - 2h30)", "Server đúng mốc phụ!")
elseif isP3 and state.hops >= CONFIG.MaxHopsBeforeFallback then
    showPromptUI(timeFormatted, "MỐC DỰ PHÒNG THẤP HƠN (1h30 - 2h)", "Đã hop " .. state.hops .. " lần không có server 2h.")
else
    local note = (state.hops >= CONFIG.MaxHopsBeforeFallback) and " (Đang tìm cả mốc thấp hơn)" or ""
    notify("Không Đạt Mốc", "Server: " .. timeFormatted .. note .. " -> Hop...", 3)
    task.wait(CONFIG.HopDelay)
    hopServer()
end
