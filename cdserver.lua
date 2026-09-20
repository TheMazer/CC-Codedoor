-- cdserver.lua - Dedicated Gate Server Program for SYNC Mode

-- Configure Package Search Path
local programPath = shell and shell.getRunningProgram() or ""
local baseDir = fs.getDir(programPath)
if baseDir ~= "" then
    package.path = "/" .. baseDir .. "/?.lua;/" .. baseDir .. "/modules/?.lua;" .. package.path
else
    package.path = "modules/?.lua;" .. package.path
end

-- Load Required Modules
local config = require("config")
local hardware = require("hardware")

-- Load Server Configuration
local cfg = config.loadServer()
hardware.setAlarmSoundEnabled(cfg.alarm_sound)

-- Network Modem & Rednet Initialization
local function initRednet()
    if cfg.modem_side and cfg.modem_side ~= "auto" then
        if peripheral.getType(cfg.modem_side) == "modem" then
            rednet.open(cfg.modem_side)
        end
    end
    if not rednet.isOpen() then
        peripheral.find("modem", function(name)
            if not rednet.isOpen() then
                rednet.open(name)
            end
        end)
    end
    if rednet.isOpen() then
        rednet.host(cfg.protocol or "codedoor_sync", cfg.hostname or "GateServer")
        return true
    end
    return false
end

local rednetOk = initRednet()

-- Server State
local gateOpened = config.loadGateState()
local status = ""
local isBusy = false
local queueAction = nil -- queued action to run in actionWorker

-- Apply Saved Redstone Signal on Startup
hardware.setOutput(cfg.redstone_side, gateOpened)

-- UI & Console Setup
term.setPaletteColor(colors.yellow, 0xFFD800)
term.setPaletteColor(colors.lightGray, 0xB2B2B2)
term.setPaletteColor(colors.gray, 0x404040)
term.setPaletteColor(colors.black, 0x1E1E1E)

local parentScreen = term.current()
local w, h = term.getSize()

-- Windows
local statusWin = window.create(parentScreen, 1, 4, w, 1)
local consoleWin = window.create(parentScreen, 1, 5, w, h - 5)

local function logMsg(source, text, textColor)
    local defaultColor = consoleWin.getTextColor()
    textColor = textColor or colors.white

    local timeStr = textutils.formatTime(os.time(), true)
    consoleWin.setTextColor(colors.gray)
    consoleWin.write("[" .. timeStr .. "] ")

    if source == "Server" then
        consoleWin.setTextColor(colors.orange)
    else
        consoleWin.setTextColor(colors.yellow)
    end
    consoleWin.write(source)

    consoleWin.setTextColor(colors.lightGray)
    consoleWin.write(" > ")

    consoleWin.setTextColor(textColor)
    consoleWin.write(text .. "\n")

    consoleWin.setTextColor(defaultColor)
end

local function renderHeader()
    parentScreen.setBackgroundColor(colors.yellow)
    parentScreen.setTextColor(colors.black)
    paintutils.drawFilledBox(1, 1, w, 3, colors.yellow)

    parentScreen.setCursorPos(3, 2)
    parentScreen.write("Gate Controller Server")

    local infoStr = (cfg.hostname or "Server") .. " #" .. tostring(os.getComputerID())
    parentScreen.setCursorPos(w - #infoStr - 1, 2)
    parentScreen.write(infoStr)
end

local function renderFooter()
    parentScreen.setBackgroundColor(colors.gray)
    paintutils.drawFilledBox(1, h, w, h, colors.gray)

    parentScreen.setCursorPos(2, h)
    parentScreen.setTextColor(colors.white)
    parentScreen.write("[O]")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write(" Open  ")

    parentScreen.setTextColor(colors.white)
    parentScreen.write("[C]")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write(" Close  ")

    parentScreen.setTextColor(colors.white)
    parentScreen.write("[Q]")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write(" Stop Server")
end

local function renderStatusLine()
    statusWin.setBackgroundColor(colors.black)
    statusWin.clear()
    statusWin.setCursorPos(2, 1)
    statusWin.setTextColor(colors.gray)
    statusWin.write("Gate Status: ")

    if status and status ~= "" then
        statusWin.setTextColor(colors.orange)
        statusWin.write(status)
    else
        if gateOpened then
            statusWin.setTextColor(colors.lime)
            statusWin.write("Opened")
        else
            statusWin.setTextColor(colors.red)
            statusWin.write("Closed")
        end
    end

    statusWin.setTextColor(colors.gray)
    local rednetStr = rednetOk and "[Network: Online]" or "[Network: Offline]"
    statusWin.setCursorPos(w - #rednetStr - 1, 1)
    statusWin.setTextColor(rednetOk and colors.lime or colors.red)
    statusWin.write(rednetStr)
end

local function broadcastStatus()
    if rednetOk then
        local packet = {
            type = "broadcast",
            event = "status_change",
            opened = gateOpened,
            status = status
        }
        rednet.broadcast(textutils.serializeJSON(packet), cfg.protocol)
    end
    renderStatusLine()
end

-- Gate Action Sequences
local function performOpening(caller)
    if isBusy then return false, "Gate is currently busy" end
    if gateOpened then return false, "Gate is already opened" end

    isBusy = true
    logMsg("Server", "Opening sequence engaged by " .. caller, colors.lime)

    status = "Preparing..."
    broadcastStatus()
    hardware.startAlarm()
    sleep(2)

    status = "M O V I N G"
    broadcastStatus()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)
    sleep(0.1)
    hardware.setOutput(cfg.redstone_side, true)

    sleep(cfg.move_time or 16)
    hardware.stopAlarm()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)

    status = ""
    gateOpened = true
    config.saveGateState(true)
    isBusy = false
    broadcastStatus()

    logMsg("Server", "Gate successfully opened", colors.lime)
    return true, "Gate opened"
end

local function performClosing(caller)
    if isBusy then return false, "Gate is currently busy" end
    if not gateOpened then return false, "Gate is already closed" end

    isBusy = true
    logMsg("Server", "Closing sequence engaged by " .. caller, colors.orange)

    status = "Preparing..."
    broadcastStatus()
    hardware.startAlarm()
    sleep(2)

    status = "M O V I N G"
    broadcastStatus()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)
    sleep(0.1)
    hardware.setOutput(cfg.redstone_side, false)

    sleep(cfg.move_time or 16)
    hardware.stopAlarm()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)

    status = ""
    gateOpened = false
    config.saveGateState(false)
    isBusy = false
    broadcastStatus()

    logMsg("Server", "Gate successfully closed", colors.orange)
    return true, "Gate closed"
end

-- Worker: Executes queued gate actions
local function actionWorker()
    while true do
        if queueAction then
            local act = queueAction
            queueAction = nil
            if act.type == "open" then
                performOpening(act.caller)
            elseif act.type == "close" then
                performClosing(act.caller)
            end
        end
        sleep(0.1)
    end
end

-- Worker: Network Request Listener
local function networkWorker()
    while true do
        if rednetOk then
            local sender, msg, msgProto = rednet.receive(cfg.protocol)
            if sender and msg and msgProto == cfg.protocol then
                local ok, data = pcall(textutils.unserializeJSON, msg)
                if ok and type(data) == "table" and data.type == "request" then
                    local reqId = data.reqId
                    local action = data.action
                    local caller = "Client #" .. tostring(sender)

                    if action == "get_status" then
                        rednet.send(sender, textutils.serializeJSON({
                            type = "response",
                            reqId = reqId,
                            success = true,
                            opened = gateOpened,
                            status = status
                        }), cfg.protocol)

                    elseif action == "open" then
                        if isBusy then
                            logMsg(caller, "Request: OPEN -> Rejected (Busy)", colors.red)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = false,
                                message = "Gate is busy (" .. (status ~= "" and status or "moving") .. ")"
                            }), cfg.protocol)
                        elseif gateOpened then
                            logMsg(caller, "Request: OPEN -> Rejected (Already Open)", colors.red)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = false,
                                message = "Gate is already opened"
                            }), cfg.protocol)
                        else
                            logMsg(caller, "Request: OPEN -> Accepted", colors.lime)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = true,
                                message = "Gate opening sequence started"
                            }), cfg.protocol)
                            queueAction = { type = "open", caller = caller }
                        end

                    elseif action == "close" then
                        if isBusy then
                            logMsg(caller, "Request: CLOSE -> Rejected (Busy)", colors.red)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = false,
                                message = "Gate is busy (" .. (status ~= "" and status or "moving") .. ")"
                            }), cfg.protocol)
                        elseif not gateOpened then
                            logMsg(caller, "Request: CLOSE -> Rejected (Already Closed)", colors.red)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = false,
                                message = "Gate is already closed"
                            }), cfg.protocol)
                        else
                            logMsg(caller, "Request: CLOSE -> Accepted", colors.lime)
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = true,
                                message = "Gate closing sequence started"
                            }), cfg.protocol)
                            queueAction = { type = "close", caller = caller }
                        end
                    end
                end
            end
        else
            sleep(1)
        end
    end
end

-- Worker: Keyboard Controls & Scroll
local function inputWorker()
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "key" then
            local key = p1
            if key == keys.q or key == keys.t then
                logMsg("Server", "Shutting down server...", colors.yellow)
                sleep(0.5)
                return
            elseif key == keys.o then
                if isBusy then
                    logMsg("Server", "Cannot open: Gate is busy", colors.red)
                elseif gateOpened then
                    logMsg("Server", "Gate is already opened", colors.red)
                else
                    queueAction = { type = "open", caller = "Console" }
                end
            elseif key == keys.c then
                if isBusy then
                    logMsg("Server", "Cannot close: Gate is busy", colors.red)
                elseif not gateOpened then
                    logMsg("Server", "Gate is already closed", colors.red)
                else
                    queueAction = { type = "close", caller = "Console" }
                end
            end
        elseif event == "mouse_scroll" then
            local dir = p1
            consoleWin.scroll(dir)
        end
    end
end

-- Start Server Application
renderHeader()
renderFooter()
renderStatusLine()

consoleWin.setBackgroundColor(colors.black)
consoleWin.clear()
logMsg("Server", "Gate Server initialized", colors.lime)
logMsg("Server", "Protocol: " .. (cfg.protocol or "codedoor_sync"), colors.lightGray)
logMsg("Server", "Hostname: " .. (cfg.hostname or "GateServer"), colors.lightGray)
if rednetOk then
    logMsg("Server", "Network is listening on wired modem", colors.lime)
else
    logMsg("Server", "Warning: No wired modem found! Check cables.", colors.red)
end

parallel.waitForAny(inputWorker, networkWorker, actionWorker, hardware.alarmWorker)

-- Cleanup on Exit
if rednetOk then
    rednet.unhost(cfg.protocol or "codedoor_sync")
    rednet.close()
end

term.redirect(parentScreen)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Gate Controller Server stopped.")
