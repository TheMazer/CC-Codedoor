-- Program Termination Restriction
local oldPullEvent = os.pullEvent
os.pullEvent = os.pullEventRaw

-- Defining Color Palette
term.setPaletteColor(colors.yellow, 0xFFD800)
term.setPaletteColor(colors.lightGray, 0xB2B2B2)
term.setPaletteColor(colors.gray, 0x404040)
term.setPaletteColor(colors.black, 0x1E1E1E)

-- Screem Setup
term.setBackgroundColor(colors.black)
term.clear()
w, h = term.getSize()

-- Program Title
paintutils.drawFilledBox(1, 1, w, 3, colors.yellow)
term.setCursorPos(3, 2)
term.setTextColor(colors.black)
term.setBackgroundColor(colors.yellow)
term.write("Gate Controller")

-- Setting up Main Frame
local frame = window.create(term.current(), 2, 5, w-2, h-7)
local statusBar = window.create(term.current(), 2, h-1, w-2, 1)
statusBar.setBackgroundColor(colors.black)
statusBar.clear()
frame.setBackgroundColor(colors.black)
frame.clear()
term.redirect(frame)

-- Setting up Program
local gateOpened = false
local authorized = false
local password = "1234"
local status = ""

local spkr = peripheral.find("speaker")
local alarming = false

-- Alarm Function
local function alarm()

    while true do
        while alarming do
            term.setPaletteColor(colors.orange, 0xD3562C)
            spkr.playNote("bit", 3, 6)
            spkr.playNote("harp", 3, 6)
            sleep(0.1)
            
            spkr.playNote("bit", 3, 6)
            spkr.playNote("harp", 3, 6)
            sleep(0.1)
            
            spkr.playNote("bit", 3, 6)
            spkr.playNote("harp", 3, 6)
            
            term.setPaletteColor(colors.orange, 0xefb032)
            sleep(0.4)
        end
        sleep(0.1)
    end

end

-- In Table Check
local function inTable (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- Available Commands Aliases
local commands = {
    ["help"] = {"help", "?", "commands", "list"},
    ["open"] = {"open", "o"},
    ["close"] = {"close", "c"},
    ["clear"] = {"clear", "cls"},
    ["logout"] = {"logout", "logoff", "l"},
    ["exit"] = {"exit", "terminate"}
}

-- Render Status Bar
local function renderStatusBar()
    -- Resetting
    statusBar.setCursorPos(1, 1)
    statusBar.write(string.rep(" ", w-2))

    -- Status Bar
    statusBar.setCursorPos(1, 1)
    statusBar.setTextColor(colors.gray)
    statusBar.write("Gate Status: ")

    if status ~= "" then
        statusBar.setTextColor(colors.orange)
        statusBar.write(status)
    else
        if gateOpened then
            statusBar.setTextColor(colors.lime)
            statusBar.write("Opened")
        else
            statusBar.setTextColor(colors.red)
            statusBar.write("Closed")
        end
    end
end

-- Render Main Information
local function renderScreen()

    -- Clearing up
    frame.clear()
    statusBar.clear()

    if authorized then
        -- Information
        frame.setCursorPos(1, 1)
        frame.setTextColor(colors.lime)
        write("Access Granted")

        frame.setCursorPos(1, 2)
        frame.setTextColor(colors.white)
        print("You can now operate the Gate")
        print()
        print()
    else
        -- Information
        frame.setTextColor(colors.white)
        frame.setCursorPos(1, 1)
        print("Authorization is required to operate this gate")
        print("To continue, enter the password below")
    end

    renderStatusBar()

end

-- Run Command Function
local function runCommand(command)
    renderScreen()

    if not (inTable(commands["clear"], command) or inTable(commands["logout"], command) or inTable(commands["exit"], command)) then
        frame.setTextColor(colors.yellow)
        print()
        write("> ")
        frame.setTextColor(colors.white)
    end

    local outputFrame = window.create(frame, 3, 6, w-5, h-10)
        outputFrame.clear()
        term.redirect(outputFrame)

    if inTable(commands["help"], command) then
        outputFrame.setTextColor(colors.white)
        write("help")
        outputFrame.setTextColor(colors.lightGray)
        print(" - List of available commands.")

        if gateOpened then
            outputFrame.setTextColor(colors.gray)
            write("open")
            print(" - Triggers the gate opening.")

            outputFrame.setTextColor(colors.white)
            write("close")
            outputFrame.setTextColor(colors.lightGray)
            print(" - Triggers the gate closing.")
        else
            outputFrame.setTextColor(colors.white)
            write("open")
            outputFrame.setTextColor(colors.lightGray)
            print(" - Triggers the gate opening.")

            outputFrame.setTextColor(colors.gray)
            write("close")
            print(" - Triggers the gate closing.")
        end

        outputFrame.setTextColor(colors.white)
        write("clear")
        outputFrame.setTextColor(colors.lightGray)
        print(" - Clearing command output.")

        outputFrame.setTextColor(colors.white)
        write("logout")
        outputFrame.setTextColor(colors.lightGray)
        print(" - Logging out.")

        outputFrame.setTextColor(colors.white)
        write("exit")
        outputFrame.setTextColor(colors.lightGray)
        print(" - Terminating gate controller interface.")
    elseif inTable(commands["open"], command) then
        if not gateOpened then
            -- First Stage
            print("Gate opening sequence engaged.")
            sleep(.7)

            -- Preparing & Alarm
            print("Sequence in process...")
            status = "Preparing..."
            renderStatusBar()
            alarming = true
            sleep(2)

            -- Moving
            status = "M O V I N G"
            renderStatusBar()
            spkr.playNote("basedrum", 3, 0) -- F#
            sleep(0.1)
            spkr.playNote("basedrum", 3, 2) -- G#
            sleep(.1)
            rs.setOutput("bottom", true)

            sleep(16)
            alarming = false
            spkr.playNote("basedrum", 3, 0) -- F#
            sleep(0.1)
            spkr.playNote("basedrum", 3, 2) -- G#

            status = ""
            gateOpened = true
            renderStatusBar()
            print("Gate opened.")
        else
            print("Gate already opened.")
        end
    elseif inTable(commands["close"], command) then
        if gateOpened then
            -- First Stage
            print("Gate closing sequence engaged.")
            sleep(.7)

            -- Preparing & Alarm
            print("Sequence in process...")
            status = "Preparing..."
            renderStatusBar()
            alarming = true
            sleep(2)

            -- Moving
            status = "M O V I N G"
            renderStatusBar()
            spkr.playNote("basedrum", 3, 0) -- F#
            sleep(0.1)
            spkr.playNote("basedrum", 3, 2) -- G#
            sleep(.1)
            rs.setOutput("bottom", false)

            sleep(16)
            alarming = false
            spkr.playNote("basedrum", 3, 0) -- F#
            sleep(0.1)
            spkr.playNote("basedrum", 3, 2) -- G#

            status = ""
            gateOpened = false
            renderStatusBar()
            print("Gate closed.")
        else
            print("Gate already closed.")
        end
    elseif inTable(commands["logout"], command) then
        -- print("Logging off...")
        -- sleep(2)
        -- term.redirect(frame)
        -- authorized = false
        -- renderScreen()

        term.redirect(frame)
        renderScreen()

        frame.setCursorPos(1, 4)
        frame.setTextColor(colors.lightGray)
        write("Logging off...")

        sleep(2)
        authorized = false
        renderScreen()
    elseif inTable(commands["exit"], command) then
        return "Exit"
    end

    term.redirect(frame)
end

-- Waiting for Command Function
local function waitingForCommand()
    while true do
        if authorized then
            frame.setCursorPos(1, 4)
            write(string.rep(" ", w-2))
            
            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            write("Command: ")
            frame.setTextColor(colors.white)

            -- Allow Termination
            os.pullEvent = oldPullEvent

            local inputCommand = read()
            if inputCommand and inputCommand ~= "" then
                local output = runCommand(inputCommand)
                if output == "Exit" then
                    return
                end
            end
        else
            frame.setCursorPos(1, 4)
            write(string.rep(" ", w-2))

            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            write("Password: ")
            frame.setTextColor(colors.white)
            inputPassword = read(utf8.char(7))

            -- Restrict Termination
            os.pullEvent = os.pullEventRaw

            if inputPassword == password then
                -- Visual
                frame.setCursorPos(1, 4)
                write(string.rep(" ", w-2))

                frame.setCursorPos(1, 4)
                frame.setTextColor(colors.lime)
                write("Access Granted")

                -- Sound
                spkr.playNote("bit", 3, 20)
                sleep(0.1)
                spkr.playNote("bell", 3, 12)

                -- Visual Pt 2
                sleep(1)
                frame.scroll(1)
                sleep(.2)
                frame.scroll(1)
                sleep(.2)
                frame.scroll(1)
                sleep(.2)
                
                frame.setCursorPos(1, 2)
                frame.setTextColor(colors.white)
                textutils.slowPrint("You can now operate the Gate")
                sleep(.5)
                authorized = true
                
            else
                -- Visual
                frame.setCursorPos(1, 4)
                write(string.rep(" ", w-2))
                frame.setCursorPos(1, 4)

                frame.setTextColor(colors.red)
                write("Access Denied")

                -- Sound
                spkr.playNote("bit", 3, 5)
                sleep(0.2)
                spkr.playNote("bit", 3, 1)
                spkr.playNote("pling", 0.5, 1)
                sleep(1)
            end
        end
    end
end

renderScreen()
parallel.waitForAny(waitingForCommand, alarm)