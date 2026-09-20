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
-- Top Header: y=1..3
-- Middle Console: y=4..h-2 (height = h - 5)
-- Bottom Status Bar: y=h-1 (height = 1)
-- Bottom Footer: y=h
local consoleWin = window.create(parentScreen, 1, 4, w, h - 5)
local statusWin = window.create(parentScreen, 1, h - 1, w, 1)

-- Console buffer and virtual scrolling state
local consoleLines = {}
local scrollOffset = 0
local consoleHeight = h - 5

local function wrapText(text, maxLen)
    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        if #current == 0 then
            while #word > maxLen do
                table.insert(lines, word:sub(1, maxLen))
                word = word:sub(maxLen + 1)
            end
            current = word
        else
            if #current + 1 + #word <= maxLen then
                current = current .. " " .. word
            else
                table.insert(lines, current)
                while #word > maxLen do
                    table.insert(lines, word:sub(1, maxLen))
                    word = word:sub(maxLen + 1)
                end
                current = word
            end
        end
    end
    if #current > 0 then
        table.insert(lines, current)
    end
    if #lines == 0 then
        table.insert(lines, "")
    end
    return lines
end

local function renderConsole()
    consoleWin.setBackgroundColor(colors.black)
    consoleWin.clear()

    local totalLines = #consoleLines
    local maxOffset = math.max(0, totalLines - consoleHeight)
    if scrollOffset > maxOffset then
        scrollOffset = maxOffset
    elseif scrollOffset < 0 then
        scrollOffset = 0
    end

    local startLine = math.max(1, totalLines - consoleHeight + 1 - scrollOffset)
    local endLine = math.min(totalLines, startLine + consoleHeight - 1)

    local row = 1
    for i = startLine, endLine do
        consoleWin.setCursorPos(1, row)
        local segs = consoleLines[i]
        if segs then
            for _, seg in ipairs(segs) do
                consoleWin.setTextColor(seg.color)
                consoleWin.write(seg.text)
            end
        end
        row = row + 1
    end

    if scrollOffset > 0 then
        local indicator = " [^ +" .. tostring(scrollOffset) .. " ] "
        consoleWin.setCursorPos(w - #indicator, 1)
        consoleWin.setBackgroundColor(colors.gray)
        consoleWin.setTextColor(colors.yellow)
        consoleWin.write(indicator)
        consoleWin.setBackgroundColor(colors.black)
    end
end

local function logMsg(source, text, textColor)
    textColor = textColor or colors.white
    local timeStr = textutils.formatTime(os.time(), true)
    local prefix = "[" .. timeStr .. "] " .. source .. " > "
    local prefixLen = #prefix
    local maxFirstWidth = math.max(10, w - prefixLen)
    local maxContWidth = math.max(10, w - prefixLen)

    local rawLines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        table.insert(rawLines, line)
    end
    if #rawLines == 0 then table.insert(rawLines, text) end

    local newLinesCount = 0
    local isFirstRawLine = true
    for _, rawLine in ipairs(rawLines) do
        if isFirstRawLine then
            local wrapped = wrapText(rawLine, maxFirstWidth)
            if #wrapped == 0 then
                table.insert(consoleLines, {
                    { text = "[" .. timeStr .. "] ", color = colors.gray },
                    { text = source, color = (source == "Server" and colors.orange or colors.yellow) },
                    { text = " > ", color = colors.lightGray }
                })
                newLinesCount = newLinesCount + 1
            else
                table.insert(consoleLines, {
                    { text = "[" .. timeStr .. "] ", color = colors.gray },
                    { text = source, color = (source == "Server" and colors.orange or colors.yellow) },
                    { text = " > ", color = colors.lightGray },
                    { text = wrapped[1], color = textColor }
                })
                newLinesCount = newLinesCount + 1
                for i = 2, #wrapped do
                    table.insert(consoleLines, {
                        { text = string.rep(" ", prefixLen), color = colors.black },
                        { text = wrapped[i], color = textColor }
                    })
                    newLinesCount = newLinesCount + 1
                end
            end
            isFirstRawLine = false
        else
            local wrapped = wrapText(rawLine, maxContWidth)
            for _, wLine in ipairs(wrapped) do
                table.insert(consoleLines, {
                    { text = string.rep(" ", prefixLen), color = colors.black },
                    { text = wLine, color = textColor }
                })
                newLinesCount = newLinesCount + 1
            end
        end
    end

    while #consoleLines > 500 do
        table.remove(consoleLines, 1)
    end

    if scrollOffset > 0 then
        scrollOffset = scrollOffset + newLinesCount
    end

    renderConsole()
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
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("[")
    parentScreen.setTextColor(colors.white)
    parentScreen.write("O")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("] Open  ")

    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("[")
    parentScreen.setTextColor(colors.white)
    parentScreen.write("C")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("] Close  ")

    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("[")
    parentScreen.setTextColor(colors.white)
    parentScreen.write("Q")
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("] Stop Server")

    -- Scroll hint with identical button design: [↑↓] Scroll
    local arrowUp = string.char(24)
    local arrowDown = string.char(25)
    local scrollText = " Scroll"
    local totalLen = 1 + 2 + 1 + #scrollText
    parentScreen.setCursorPos(w - totalLen, h)

    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("[")
    parentScreen.setTextColor(colors.white)
    parentScreen.write(arrowUp .. arrowDown)
    parentScreen.setTextColor(colors.lightGray)
    parentScreen.write("]" .. scrollText)
end

local function renderStatusLine(blinkTick)
    statusWin.setCursorPos(1, 1)
    statusWin.setBackgroundColor(colors.gray)
    statusWin.clear()

    -- Segment 1: Gate Status (Background: colors.gray)
    statusWin.setCursorPos(1, 1)
    statusWin.setBackgroundColor(colors.gray)
    statusWin.setTextColor(colors.gray)
    statusWin.write(" ")

    local dotChar = string.char(7)
    local gateDotColor = colors.red
    local gateText = "Closed"
    local gateTextColor = colors.red

    if status and status ~= "" then
        gateDotColor = (blinkTick and colors.yellow or colors.orange)
        gateText = status
        gateTextColor = (blinkTick and colors.yellow or colors.orange)
    elseif gateOpened then
        gateDotColor = colors.lime
        gateText = "Open"
        gateTextColor = colors.lime
    else
        gateDotColor = colors.red
        gateText = "Closed"
        gateTextColor = colors.red
    end

    statusWin.setTextColor(gateDotColor)
    statusWin.write(dotChar)

    statusWin.setTextColor(colors.white)
    statusWin.write(" Gate: ")
    statusWin.setTextColor(gateTextColor)
    statusWin.write(gateText .. " ")

    -- Transition 1: Segment 1 (gray) -> Segment 2 (black)
    statusWin.setTextColor(colors.gray)
    statusWin.setBackgroundColor(colors.black)
    statusWin.write(string.char(157))

    -- Segment 2: Network Status (Background: colors.black)
    statusWin.setBackgroundColor(colors.black)
    statusWin.write(" ")

    local netDotColor = rednetOk and colors.lime or colors.red
    statusWin.setTextColor(netDotColor)
    statusWin.write(dotChar)

    statusWin.setTextColor(colors.white)
    statusWin.write(" Network: ")
    if rednetOk then
        statusWin.setTextColor(colors.lime)
        statusWin.write("Online ")
    else
        statusWin.setTextColor(colors.red)
        statusWin.write("Offline ")
    end

    -- Transition 2: Segment 2 (black) -> Segment 3 (gray)
    statusWin.setTextColor(colors.black)
    statusWin.setBackgroundColor(colors.gray)
    statusWin.write(string.char(157))

    -- Segment 3: System Time / Spacer (Background: colors.gray)
    local curX, _ = statusWin.getCursorPos()
    local timeStr = textutils.formatTime(os.time(), true)
    local rightStr = " " .. timeStr .. " "
    local remaining = w - curX + 1

    statusWin.setBackgroundColor(colors.gray)
    if remaining >= #rightStr then
        local fillSpaces = remaining - #rightStr
        statusWin.setTextColor(colors.gray)
        statusWin.write(string.rep(" ", fillSpaces))
        statusWin.setTextColor(colors.lightGray)
        statusWin.write(rightStr)
    elseif remaining > 0 then
        statusWin.setTextColor(colors.gray)
        statusWin.write(string.rep(" ", remaining))
    end
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

    status = "Moving"
    broadcastStatus()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)
    sleep(0.1)
    hardware.setOutput(cfg.redstone_side, true)

    local moveTotal = cfg.move_time or 16
    local elapsed = 0
    local blinkTick = false
    while elapsed < moveTotal do
        sleep(0.5)
        elapsed = elapsed + 0.5
        blinkTick = not blinkTick
        renderStatusLine(blinkTick)
    end

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

    status = "Moving"
    broadcastStatus()
    hardware.playNote("basedrum", 3, 0)
    sleep(0.1)
    hardware.playNote("basedrum", 3, 2)
    sleep(0.1)
    hardware.setOutput(cfg.redstone_side, false)

    local moveTotal = cfg.move_time or 16
    local elapsed = 0
    local blinkTick = false
    while elapsed < moveTotal do
        sleep(0.5)
        elapsed = elapsed + 0.5
        blinkTick = not blinkTick
        renderStatusLine(blinkTick)
    end

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
    local clockTimer = 0
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
        sleep(0.5)
        clockTimer = clockTimer + 0.5
        if clockTimer >= 1 then
            clockTimer = 0
            if not isBusy then
                renderStatusLine()
            end
        end
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

                    if action == "play_note" or action == "play_sound" then
                        local p = data.payload
                        if p and p.instrument then
                            hardware.playNote(p.instrument, p.volume or 3, p.pitch or 0)
                        end
                        if reqId then
                            rednet.send(sender, textutils.serializeJSON({
                                type = "response",
                                reqId = reqId,
                                success = true
                            }), cfg.protocol)
                        end

                    elseif action == "get_status" then
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
            rednetOk = initRednet()
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
            elseif key == keys.pageUp then
                local totalLines = #consoleLines
                local maxOffset = math.max(0, totalLines - consoleHeight)
                scrollOffset = math.max(0, math.min(maxOffset, scrollOffset + math.max(1, consoleHeight - 2)))
                renderConsole()
            elseif key == keys.pageDown then
                scrollOffset = math.max(0, scrollOffset - math.max(1, consoleHeight - 2))
                renderConsole()
            elseif key == keys.home then
                local totalLines = #consoleLines
                scrollOffset = math.max(0, totalLines - consoleHeight)
                renderConsole()
            elseif key == keys.endKey then
                scrollOffset = 0
                renderConsole()
            elseif key == keys.up then
                local totalLines = #consoleLines
                local maxOffset = math.max(0, totalLines - consoleHeight)
                scrollOffset = math.max(0, math.min(maxOffset, scrollOffset + 1))
                renderConsole()
            elseif key == keys.down then
                scrollOffset = math.max(0, scrollOffset - 1)
                renderConsole()
            end
        elseif event == "mouse_scroll" then
            local dir = p1
            local totalLines = #consoleLines
            local maxOffset = math.max(0, totalLines - consoleHeight)
            -- dir == -1: wheel up -> scroll up -> increase scrollOffset
            -- dir == 1: wheel down -> scroll down -> decrease scrollOffset
            scrollOffset = math.max(0, math.min(maxOffset, scrollOffset - dir * 2))
            renderConsole()
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
hardware.restorePalette()

term.redirect(parentScreen)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Gate Controller Server stopped.")
