-- Loading Libraries
local ok, lib = pcall(require, "sha256")
local sha256 = (ok and lib) or (fs.exists("sha256.lua") and dofile("sha256.lua"))
if not sha256 then
    error("Failed to load sha256 library")
end

-- Configuration & State
local CONFIG_FILE = "cdsettings.json"
local STATE_FILE = "gatestate.json"

-- Configuration Management
local config = {
    password_hash = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4", -- default "1234"
    salt = "",
    redstone_side = "bottom",
    move_time = 16,
    alarm_sound = true
}

local function saveConfig(cfg)
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(textutils.serializeJSON(cfg, false))
        file.close()
    end
end

local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local file = fs.open(CONFIG_FILE, "r")
        if file then
            local data = textutils.unserializeJSON(file.readAll())
            file.close()
            if type(data) == "table" then
                for k, v in pairs(data) do
                    config[k] = v
                end
                -- Auto-hash plain text password if provided in config
                if data.password and not data.password_hash then
                    config.password_hash = sha256.digest(tostring(data.password) .. (config.salt or ""))
                    config.password = nil
                    saveConfig(config)
                end
                return config
            end
        end
    end

    saveConfig(config)
    return config
end

loadConfig()

-- Gate State Management
local function saveGateState(opened)
    local file = fs.open(STATE_FILE, "w")
    if file then
        file.write('{\n  "opened": ' .. tostring(opened == true) .. '\n}\n')
        file.close()
    end
end

local function loadGateState()
    if fs.exists(STATE_FILE) then
        local file = fs.open(STATE_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()

            -- 1. Standard JSON unserialize
            local ok, data = pcall(textutils.unserializeJSON, content)
            if ok and type(data) == "table" and data.opened ~= nil then
                return data.opened == true
            end

            -- 2. JSON with nbt_style option
            local okNbt, dataNbt = pcall(textutils.unserializeJSON, content, { nbt_style = true })
            if okNbt and type(dataNbt) == "table" and dataNbt.opened ~= nil then
                return dataNbt.opened == true
            end

            -- 3. Lua table format
            local okLua, dataLua = pcall(textutils.unserialize, content)
            if okLua and type(dataLua) == "table" and dataLua.opened ~= nil then
                return dataLua.opened == true
            end

            -- 4. Robust string pattern matching fallback
            local lower = content:lower()
            if lower:find("opened%s*[:=]%s*true") or (lower:find('"opened"') and lower:find("true")) then
                return true
            end
            if lower:find("opened%s*[:=]%s*false") or (lower:find('"opened"') and lower:find("false")) then
                return false
            end
            if lower:find("true") or lower:find("open") then
                return true
            end
        end
    end
    return false
end

-- Password Verification
local function verifyPassword(inputPassword)
    if not inputPassword or inputPassword == "" then
        return false
    end
    local salt = config.salt or ""
    local hashWithSalt = sha256.digest(inputPassword .. salt)
    local hashPlain = sha256.digest(inputPassword)

    return (hashWithSalt:lower() == config.password_hash:lower()) or
           (hashPlain:lower() == config.password_hash:lower())
end

-- Program Termination Restriction
local oldPullEvent = os.pullEvent
os.pullEvent = os.pullEventRaw

-- Peripheral Setup
local spkr = peripheral.find("speaker")

local function playNote(instrument, volume, pitch)
    if spkr then
        pcall(spkr.playNote, instrument, volume, pitch)
    end
end

-- Defining Color Palette
term.setPaletteColor(colors.yellow, 0xFFD800)
term.setPaletteColor(colors.lightGray, 0xB2B2B2)
term.setPaletteColor(colors.gray, 0x404040)
term.setPaletteColor(colors.black, 0x1E1E1E)

-- Screen Setup
term.setBackgroundColor(colors.black)
term.clear()
local w, h = term.getSize()

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

-- Runtime State
local gateOpened = loadGateState()
local authorized = false
local status = ""
local alarming = false

-- Restore saved redstone output on launch
rs.setOutput(config.redstone_side, gateOpened)

-- Alarm Function
local function alarm()
    while true do
        while alarming do
            term.setPaletteColor(colors.orange, 0xD3562C)
            if config.alarm_sound then
                playNote("bit", 3, 6)
                playNote("harp", 3, 6)
                sleep(0.1)

                playNote("bit", 3, 6)
                playNote("harp", 3, 6)
                sleep(0.1)

                playNote("bit", 3, 6)
                playNote("harp", 3, 6)
            else
                sleep(0.2)
            end

            term.setPaletteColor(colors.orange, 0xefb032)
            sleep(0.4)
        end
        sleep(0.1)
    end
end

-- Instruction Smooth Printing Background Worker
local instructionQueue = nil
local instructionActive = false

local function instructionWorker()
    while true do
        if instructionQueue then
            local text = instructionQueue
            instructionQueue = nil
            instructionActive = true

            playNote("bit", 3, 20)

            for i = 1, #text do
                if not instructionActive then
                    break
                end

                if i == 3 then
                    playNote("bell", 3, 12)
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

-- Table Helper
local function inTable(tab, val)
    if not tab then return false end
    for _, value in ipairs(tab) do
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
    ["passwd"] = {"passwd", "password", "changepass", "chpass"},
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

-- Render Screen
local function renderScreen()
    -- Clearing up
    frame.clear()
    statusBar.clear()

    if authorized then
        -- Information
        frame.setCursorPos(1, 1)
        frame.setTextColor(colors.lime)
        frame.write("Access Granted")

        frame.setCursorPos(1, 2)
        frame.setTextColor(colors.white)
        frame.write("You can now operate the Gate")
    else
        -- Information
        frame.setTextColor(colors.white)
        frame.setCursorPos(1, 1)
        frame.write("Authorization is required to operate this gate")
        frame.setCursorPos(1, 2)
        frame.write("To continue, enter the password below")
    end

    renderStatusBar()
end

-- Run Command Function
local function runCommand(command)
    instructionActive = false
    renderScreen()

    if not (inTable(commands["clear"], command) or inTable(commands["logout"], command) or inTable(commands["exit"], command)) then
        frame.setCursorPos(1, 6)
        frame.setTextColor(colors.yellow)
        frame.write("> ")
        frame.setTextColor(colors.white)
    end

    local outputFrame = window.create(frame, 3, 6, w-5, h-10)
    outputFrame.clear()
    term.redirect(outputFrame)

    if inTable(commands["help"], command) then
        outputFrame.setTextColor(colors.white)
        write("help")
        outputFrame.setTextColor(colors.lightGray)
        print("   - List of available commands.")

        if gateOpened then
            outputFrame.setTextColor(colors.gray)
            write("open")
            outputFrame.setTextColor(colors.lightGray)
            print("   - Triggers the gate opening.")

            outputFrame.setTextColor(colors.white)
            write("close")
            outputFrame.setTextColor(colors.lightGray)
            print("  - Triggers the gate closing.")
        else
            outputFrame.setTextColor(colors.white)
            write("open")
            outputFrame.setTextColor(colors.lightGray)
            print("   - Triggers the gate opening.")

            outputFrame.setTextColor(colors.gray)
            write("close")
            outputFrame.setTextColor(colors.lightGray)
            print("  - Triggers the gate closing.")
        end

        outputFrame.setTextColor(colors.white)
        write("passwd")
        outputFrame.setTextColor(colors.lightGray)
        print(" - Change access password.")

        outputFrame.setTextColor(colors.white)
        write("clear")
        outputFrame.setTextColor(colors.lightGray)
        print("  - Clearing command output.")

        outputFrame.setTextColor(colors.white)
        write("logout")
        outputFrame.setTextColor(colors.lightGray)
        print(" - Logging out.")

        outputFrame.setTextColor(colors.white)
        write("exit")
        outputFrame.setTextColor(colors.lightGray)
        print("   - Terminating gate controller interface.")

    elseif inTable(commands["open"], command) then
        if not gateOpened then
            print("Gate opening sequence engaged.")
            sleep(0.7)

            print("Sequence in process...")
            status = "Preparing..."
            renderStatusBar()
            alarming = true
            sleep(2)

            status = "M O V I N G"
            renderStatusBar()
            playNote("basedrum", 3, 0)
            sleep(0.1)
            playNote("basedrum", 3, 2)
            sleep(0.1)
            rs.setOutput(config.redstone_side, true)

            sleep(config.move_time or 16)
            alarming = false
            playNote("basedrum", 3, 0)
            sleep(0.1)
            playNote("basedrum", 3, 2)

            status = ""
            gateOpened = true
            saveGateState(true)
            renderStatusBar()
            print("Gate opened.")
        else
            print("Gate already opened.")
        end

    elseif inTable(commands["close"], command) then
        if gateOpened then
            print("Gate closing sequence engaged.")
            sleep(0.7)

            print("Sequence in process...")
            status = "Preparing..."
            renderStatusBar()
            alarming = true
            sleep(2)

            status = "M O V I N G"
            renderStatusBar()
            playNote("basedrum", 3, 0)
            sleep(0.1)
            playNote("basedrum", 3, 2)
            sleep(0.1)
            rs.setOutput(config.redstone_side, false)

            sleep(config.move_time or 16)
            alarming = false
            playNote("basedrum", 3, 0)
            sleep(0.1)
            playNote("basedrum", 3, 2)

            status = ""
            gateOpened = false
            saveGateState(false)
            renderStatusBar()
            print("Gate closed.")
        else
            print("Gate already closed.")
        end

    elseif inTable(commands["passwd"], command) then
        outputFrame.setTextColor(colors.white)
        print("--- Change Password ---")
        outputFrame.setTextColor(colors.lightGray)
        write("Current password: ")
        outputFrame.setTextColor(colors.white)
        local cur = read(utf8.char(7))

        if verifyPassword(cur) then
            outputFrame.setTextColor(colors.lightGray)
            write("New password: ")
            outputFrame.setTextColor(colors.white)
            local newP = read(utf8.char(7))

            if newP and #newP > 0 then
                outputFrame.setTextColor(colors.lightGray)
                write("Confirm password: ")
                outputFrame.setTextColor(colors.white)
                local confP = read(utf8.char(7))

                if newP == confP then
                    config.password_hash = sha256.digest(newP .. (config.salt or ""))
                    saveConfig(config)
                    outputFrame.setTextColor(colors.lime)
                    print("Password changed successfully!")
                else
                    outputFrame.setTextColor(colors.red)
                    print("Passwords do not match.")
                end
            else
                outputFrame.setTextColor(colors.red)
                print("Password cannot be empty.")
            end
        else
            outputFrame.setTextColor(colors.red)
            print("Incorrect current password.")
        end
        sleep(1.5)

    elseif inTable(commands["logout"], command) then
        term.redirect(frame)
        renderScreen()

        frame.setCursorPos(1, 4)
        frame.setTextColor(colors.lightGray)
        frame.write("Logging off...")

        sleep(1.5)
        authorized = false
        renderScreen()

    elseif inTable(commands["exit"], command) then
        return "Exit"
    end

    term.redirect(frame)
end

-- Waiting for Command / Password Function
local function waitingForCommand()
    while true do
        if authorized then
            frame.setCursorPos(1, 4)
            frame.write(string.rep(" ", w-2))

            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            frame.write("Command: ")
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
            frame.write(string.rep(" ", w-2))

            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            frame.write("Password: ")
            frame.setTextColor(colors.white)

            -- Restrict Termination
            os.pullEvent = os.pullEventRaw

            local inputPassword = read(utf8.char(7))

            if verifyPassword(inputPassword) then
                authorized = true

                -- Clear frame and show Access Granted
                frame.clear()
                frame.setCursorPos(1, 1)
                frame.setTextColor(colors.lime)
                frame.write("Access Granted")
                renderStatusBar()

                -- Queue smooth instruction typing in separate background worker
                instructionQueue = "You can now operate the Gate"

                -- No sleep here! Immediately proceed to next loop iteration for command input
            else
                frame.setCursorPos(1, 4)
                frame.write(string.rep(" ", w-2))
                frame.setCursorPos(1, 4)

                frame.setTextColor(colors.red)
                frame.write("Access Denied")

                playNote("bit", 3, 5)
                sleep(0.2)
                playNote("bit", 3, 1)
                playNote("pling", 0.5, 1)
                sleep(1)
            end
        end
    end
end

-- Start Program
renderScreen()
parallel.waitForAny(waitingForCommand, alarm, instructionWorker)