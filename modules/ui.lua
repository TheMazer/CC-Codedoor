-- ui.lua - UI and Display Rendering Module
local ui = {}

local parentScreen = nil
local frame = nil
local statusBar = nil
local w, h = 0, 0

local playSound = nil
local instructionQueue = nil
local instructionActive = false

local currentStatus = ""
local currentGateOpened = false
local currentNetOnline = true
local currentMode = "STANDALONE"
local currentBlink = false

function ui.setSoundCallback(callback)
    playSound = callback
end

function ui.init()
    -- Defining Color Palette
    term.setPaletteColor(colors.yellow, 0xFFD800)
    term.setPaletteColor(colors.lightGray, 0xB2B2B2)
    term.setPaletteColor(colors.gray, 0x404040)
    term.setPaletteColor(colors.black, 0x1E1E1E)
    term.setPaletteColor(colors.red, 0xFF453A)

    -- Screen Setup
    term.setBackgroundColor(colors.black)
    term.clear()
    w, h = term.getSize()

    -- Setting up Main Frames
    parentScreen = term.current()
    paintutils.drawFilledBox(1, 1, w, 3, colors.yellow)
    parentScreen.setCursorPos(3, 2)
    parentScreen.setTextColor(colors.black)
    parentScreen.setBackgroundColor(colors.yellow)
    if w >= 17 then
        parentScreen.write("Gate Controller")
    elseif w >= 6 then
        parentScreen.write("Gate")
    end

    frame = window.create(parentScreen, 2, 5, math.max(1, w - 2), math.max(1, h - 6))
    statusBar = window.create(parentScreen, 1, h, w, 1)

    statusBar.setBackgroundColor(colors.gray)
    statusBar.clear()
    frame.setBackgroundColor(colors.black)
    frame.clear()

    term.redirect(frame)
end

function ui.getFrame()
    return frame
end

function ui.getStatusBar()
    return statusBar
end

function ui.getParentScreen()
    return parentScreen
end

function ui.getSize()
    return w, h
end

function ui.resize()
    w, h = term.getSize()
    if parentScreen then
        parentScreen.setBackgroundColor(colors.black)
        parentScreen.clear()
        paintutils.drawFilledBox(1, 1, w, 3, colors.yellow)
        parentScreen.setCursorPos(3, 2)
        parentScreen.setTextColor(colors.black)
        parentScreen.setBackgroundColor(colors.yellow)
        if w >= 17 then
            parentScreen.write("Gate Controller")
        elseif w >= 6 then
            parentScreen.write("Gate")
        end
    end
    if frame then
        frame.reposition(2, 5, math.max(1, w - 2), math.max(1, h - 6))
    end
    if statusBar then
        statusBar.reposition(1, h, w, 1)
    end
end

function ui.renderSessionTimer(authorized, timeout, remainingSeconds)
    if not parentScreen then return end

    local cur = term.current()
    local curX, curY = cur.getCursorPos()
    local curBlink = cur.getCursorBlink()
    local curFg = cur.getTextColor()
    local curBg = cur.getBackgroundColor()

    parentScreen.setCursorBlink(false)
    parentScreen.setBackgroundColor(colors.yellow)

    local pW, _ = parentScreen.getSize()
    local timerBoxWidth = 8
    local timerBoxStart = math.max(1, pW - timerBoxWidth)

    if authorized and timeout and timeout > 0 and remainingSeconds then
        local str = tostring(math.max(0, remainingSeconds)) .. "s"
        local x = pW - #str - 1

        if remainingSeconds <= 10 then
            parentScreen.setTextColor(colors.red)
        else
            parentScreen.setTextColor(colors.black)
        end

        parentScreen.setCursorPos(timerBoxStart, 2)
        parentScreen.write(string.rep(" ", timerBoxWidth))

        if x >= 1 then
            parentScreen.setCursorPos(x, 2)
            parentScreen.write(str)
        end
    else
        parentScreen.setCursorPos(timerBoxStart, 2)
        parentScreen.write(string.rep(" ", timerBoxWidth))
    end

    cur.setTextColor(curFg)
    cur.setBackgroundColor(curBg)
    cur.setCursorPos(curX, curY)
    cur.setCursorBlink(curBlink)
end

function ui.renderStatusBar(statusText, gateOpened, netOnline, blinkTick, mode)
    if not statusBar then return end

    if statusText ~= nil then currentStatus = statusText end
    if gateOpened ~= nil then currentGateOpened = (gateOpened == true) end
    if netOnline ~= nil then currentNetOnline = (netOnline == true) end
    if blinkTick ~= nil then currentBlink = (blinkTick == true) end
    if mode ~= nil then currentMode = mode end

    local sbW, _ = statusBar.getSize()

    local cur = term.current()
    local curX, curY = cur.getCursorPos()
    local curBlink = cur.getCursorBlink()
    local curFg = cur.getTextColor()
    local curBg = cur.getBackgroundColor()

    statusBar.setCursorPos(1, 1)
    statusBar.setBackgroundColor(colors.gray)
    statusBar.clear()

    -- Segment 1: Gate Status (Background: colors.gray)
    statusBar.setCursorPos(1, 1)
    statusBar.setBackgroundColor(colors.gray)
    statusBar.setTextColor(colors.gray)
    statusBar.write(" ")

    local dotChar = string.char(7)
    local gateDotColor = colors.red
    local gateText = "Closed"
    local gateTextColor = colors.red

    if currentStatus and currentStatus ~= "" then
        gateDotColor = (currentBlink and colors.yellow or colors.orange)
        gateText = currentStatus
        gateTextColor = (currentBlink and colors.yellow or colors.orange)
    elseif currentGateOpened then
        gateDotColor = colors.lime
        gateText = "Open"
        gateTextColor = colors.lime
    else
        gateDotColor = colors.red
        gateText = "Closed"
        gateTextColor = colors.red
    end

    statusBar.setTextColor(gateDotColor)
    statusBar.write(dotChar)

    statusBar.setTextColor(colors.white)
    statusBar.write(sbW >= 32 and " Gate: " or " ")
    statusBar.setTextColor(gateTextColor)
    statusBar.write(gateText .. " ")

    -- Transition 1: Segment 1 (gray) -> Segment 2 (black)
    local curBarX, _ = statusBar.getCursorPos()
    if curBarX < sbW - 5 then
        statusBar.setTextColor(colors.gray)
        statusBar.setBackgroundColor(colors.black)
        statusBar.write(string.char(157))

        -- Segment 2: Network / Mode Status (Background: colors.black)
        statusBar.setBackgroundColor(colors.black)
        statusBar.write(" ")

        local netDotColor = colors.lime
        local netLabel = sbW >= 42 and " Network: " or " "
        local netStatusText = "Online "
        local netStatusColor = colors.lime

        if currentMode == "STANDALONE" then
            netDotColor = colors.lightGray
            netLabel = sbW >= 42 and " Mode: " or " "
            netStatusText = sbW >= 32 and "Standalone " or "Local "
            netStatusColor = colors.lightGray
        elseif not currentNetOnline then
            netDotColor = colors.red
            netLabel = sbW >= 42 and " Network: " or " "
            netStatusText = "Offline "
            netStatusColor = colors.red
        end

        statusBar.setTextColor(netDotColor)
        statusBar.write(dotChar)

        statusBar.setTextColor(colors.white)
        statusBar.write(netLabel)
        statusBar.setTextColor(netStatusColor)
        statusBar.write(netStatusText)

        -- Transition 2: Segment 2 (black) -> Segment 3 (gray)
        statusBar.setTextColor(colors.black)
        statusBar.setBackgroundColor(colors.gray)
        statusBar.write(string.char(157))
    end

    -- Segment 3: System Time / Spacer (Background: colors.gray)
    curBarX, _ = statusBar.getCursorPos()
    local timeStr = textutils.formatTime(os.time(), true)
    local rightStr = " " .. timeStr .. " "
    local remaining = sbW - curBarX + 1

    statusBar.setBackgroundColor(colors.gray)
    if remaining >= #rightStr then
        local fillSpaces = remaining - #rightStr
        statusBar.setTextColor(colors.gray)
        statusBar.write(string.rep(" ", fillSpaces))
        statusBar.setTextColor(colors.lightGray)
        statusBar.write(rightStr)
    elseif remaining > 0 then
        statusBar.setTextColor(colors.gray)
        statusBar.write(string.rep(" ", remaining))
    end

    cur.setTextColor(curFg)
    cur.setBackgroundColor(curBg)
    cur.setCursorPos(curX, curY)
    cur.setCursorBlink(curBlink)
end

function ui.renderScreen(authorized, statusText, gateOpened, timeout, remainingSeconds, netOnline, blinkTick, mode)
    if not frame or not statusBar then return end

    frame.clear()
    local fw, _ = frame.getSize()

    if authorized then
        frame.setCursorPos(1, 1)
        frame.setTextColor(colors.lime)
        frame.write("Access Granted")

        frame.setCursorPos(1, 2)
        frame.setTextColor(colors.white)
        if fw >= 28 then
            frame.write("You can now operate the Gate")
        else
            frame.write("Operate gate below")
        end
    else
        frame.setTextColor(colors.white)
        frame.setCursorPos(1, 1)
        if fw >= 46 then
            frame.write("Authorization is required to operate this gate")
            frame.setCursorPos(1, 2)
            frame.write("To continue, enter the password below")
        elseif fw >= 24 then
            frame.write("Authorization required")
            frame.setCursorPos(1, 2)
            frame.write("Enter password below")
        else
            frame.write("Auth required")
            frame.setCursorPos(1, 2)
            frame.write("Enter password")
        end
    end

    ui.renderStatusBar(statusText, gateOpened, netOnline, blinkTick, mode)
    ui.renderSessionTimer(authorized, timeout, remainingSeconds)
end

function ui.drawPromptArrow(color)
    if not frame then return end
    frame.setCursorPos(1, 6)
    frame.setTextColor(color or colors.white)
    frame.write(string.char(16) .. " ")
end

function ui.createOutputFrame()
    local fw, fh = frame.getSize()
    local outW = math.max(1, fw - 3)
    local outH = math.max(1, fh - 5)
    local outputFrame = window.create(frame, 3, 6, outW, outH)
    outputFrame.clear()
    return outputFrame
end

function ui.queueInstruction(text)
    instructionQueue = text
end

function ui.cancelInstruction()
    instructionActive = false
    instructionQueue = nil
end

function ui.instructionWorker()
    while true do
        if instructionQueue then
            local text = instructionQueue
            instructionQueue = nil
            instructionActive = true

            if playSound then
                playSound("bit", 3, 20)
            end

            for i = 1, #text do
                if not instructionActive then
                    break
                end

                if i == 3 and playSound then
                    playSound("bell", 3, 12)
                end

                local curX, curY = frame.getCursorPos()
                local curBlink = frame.getCursorBlink()
                local curColor = frame.getTextColor()

                local fw, _ = frame.getSize()
                if i <= fw then
                    frame.setCursorBlink(false)
                    frame.setCursorPos(i, 2)
                    frame.setTextColor(colors.white)
                    frame.write(text:sub(i, i))

                    frame.setTextColor(curColor)
                    frame.setCursorPos(curX, curY)
                    frame.setCursorBlink(curBlink)
                end

                sleep(0.04)
            end

            instructionActive = false
        end
        sleep(0.05)
    end
end

return ui
