-- ui.lua - UI and Display Rendering Module
local ui = {}

local parentScreen = nil
local frame = nil
local statusBar = nil
local w, h = 0, 0

local playSound = nil
local instructionQueue = nil
local instructionActive = false

function ui.setSoundCallback(callback)
    playSound = callback
end

function ui.init()
    -- Defining Color Palette
    term.setPaletteColor(colors.yellow, 0xFFD800)
    term.setPaletteColor(colors.lightGray, 0xB2B2B2)
    term.setPaletteColor(colors.gray, 0x404040)
    term.setPaletteColor(colors.black, 0x1E1E1E)

    -- Screen Setup
    term.setBackgroundColor(colors.black)
    term.clear()
    w, h = term.getSize()

    -- Program Title
    paintutils.drawFilledBox(1, 1, w, 3, colors.yellow)
    term.setCursorPos(3, 2)
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.yellow)
    term.write("Gate Controller")

    -- Setting up Main Frames
    parentScreen = term.current()
    frame = window.create(parentScreen, 2, 5, w - 2, h - 7)
    statusBar = window.create(parentScreen, 2, h - 1, w - 2, 1)

    statusBar.setBackgroundColor(colors.black)
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

function ui.renderSessionTimer(authorized, timeout, remainingSeconds)
    if not parentScreen then return end

    local cur = term.current()
    local curX, curY = cur.getCursorPos()
    local curBlink = cur.getCursorBlink()
    local curFg = cur.getTextColor()
    local curBg = cur.getBackgroundColor()

    parentScreen.setCursorBlink(false)
    parentScreen.setBackgroundColor(colors.yellow)

    if authorized and timeout and timeout > 0 and remainingSeconds then
        local str = tostring(math.max(0, remainingSeconds)) .. "s"
        local x = w - #str - 1

        if remainingSeconds <= 10 then
            parentScreen.setTextColor(colors.red)
        else
            parentScreen.setTextColor(colors.black)
        end

        parentScreen.setCursorPos(w - 8, 2)
        parentScreen.write(string.rep(" ", 8))

        parentScreen.setCursorPos(x, 2)
        parentScreen.write(str)
    else
        parentScreen.setCursorPos(w - 8, 2)
        parentScreen.write(string.rep(" ", 8))
    end

    cur.setTextColor(curFg)
    cur.setBackgroundColor(curBg)
    cur.setCursorPos(curX, curY)
    cur.setCursorBlink(curBlink)
end

function ui.renderStatusBar(statusText, gateOpened)
    if not statusBar then return end

    local cur = term.current()
    local curX, curY = cur.getCursorPos()
    local curBlink = cur.getCursorBlink()
    local curFg = cur.getTextColor()
    local curBg = cur.getBackgroundColor()

    statusBar.setCursorPos(1, 1)
    statusBar.write(string.rep(" ", w - 2))

    statusBar.setCursorPos(1, 1)
    statusBar.setTextColor(colors.gray)
    statusBar.write("Gate Status: ")

    if statusText and statusText ~= "" then
        statusBar.setTextColor(colors.orange)
        statusBar.write(statusText)
    else
        if gateOpened then
            statusBar.setTextColor(colors.lime)
            statusBar.write("Opened")
        else
            statusBar.setTextColor(colors.red)
            statusBar.write("Closed")
        end
    end

    cur.setTextColor(curFg)
    cur.setBackgroundColor(curBg)
    cur.setCursorPos(curX, curY)
    cur.setCursorBlink(curBlink)
end

function ui.renderScreen(authorized, statusText, gateOpened, timeout, remainingSeconds)
    if not frame or not statusBar then return end

    frame.clear()
    statusBar.clear()

    if authorized then
        frame.setCursorPos(1, 1)
        frame.setTextColor(colors.lime)
        frame.write("Access Granted")

        frame.setCursorPos(1, 2)
        frame.setTextColor(colors.white)
        frame.write("You can now operate the Gate")
    else
        frame.setTextColor(colors.white)
        frame.setCursorPos(1, 1)
        frame.write("Authorization is required to operate this gate")
        frame.setCursorPos(1, 2)
        frame.write("To continue, enter the password below")
    end

    ui.renderStatusBar(statusText, gateOpened)
    ui.renderSessionTimer(authorized, timeout, remainingSeconds)
end

function ui.drawPromptArrow()
    if not frame then return end
    frame.setCursorPos(1, 6)
    frame.setTextColor(colors.yellow)
    frame.write("> ")
    frame.setTextColor(colors.white)
end

function ui.createOutputFrame()
    local outputFrame = window.create(frame, 3, 6, w - 5, h - 10)
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

                frame.setCursorBlink(false)
                frame.setCursorPos(i, 2)
                frame.setTextColor(colors.white)
                frame.write(text:sub(i, i))

                frame.setTextColor(curColor)
                frame.setCursorPos(curX, curY)
                frame.setCursorBlink(curBlink)

                sleep(0.04)
            end

            instructionActive = false
        end
        sleep(0.05)
    end
end

return ui
