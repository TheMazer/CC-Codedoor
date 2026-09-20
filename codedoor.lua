-- codedoor.lua - Main Gate Controller Application

-- Configure Package Search Path
local programPath = shell and shell.getRunningProgram() or ""
local baseDir = fs.getDir(programPath)
if baseDir ~= "" then
    package.path = "/" .. baseDir .. "/?.lua;/" .. baseDir .. "/modules/?.lua;" .. package.path
else
    package.path = "modules/?.lua;" .. package.path
end

-- Load Application Modules
local config = require("config")
local sha256 = (pcall(require, "sha256") and require("sha256")) or dofile(config.getFilePath("modules/sha256.lua"))
local auth = require("auth")
local hardware = require("hardware")
local ui = require("ui")
local session = require("session")
local commands = require("commands")
local sync = require("sync")

-- Load Configuration and Gate State
local cfg = config.load(sha256)
hardware.setAlarmSoundEnabled(cfg.alarm_sound)

local state = {
    gateOpened = config.loadGateState(),
    authorized = not auth.hasPassword(cfg),
    status = ""
}

-- Initialize Network Sync or Local Redstone
if cfg.mode == "SYNC" then
    sync.init(cfg)
    local ok, res = sync.queryStatus()
    if ok and res and res.opened ~= nil then
        state.gateOpened = (res.opened == true)
        state.status = res.status or ""
    end
else
    -- Apply Saved Redstone Signal on Startup in STANDALONE mode
    hardware.setOutput(cfg.redstone_side, state.gateOpened)
end

-- Initialize UI & Link Callbacks
ui.setSoundCallback(hardware.playNote)
ui.init()

local function renderStatusBar()
    ui.renderStatusBar(state.status, state.gateOpened)
end

local function renderSessionTimer()
    ui.renderSessionTimer(state.authorized, cfg.timeout, session.getRemaining())
end

local function renderScreen()
    ui.renderScreen(state.authorized, state.status, state.gateOpened, cfg.timeout, session.getRemaining())
end

local ctx = {
    ui = ui,
    hardware = hardware,
    config = config,
    auth = auth,
    session = session,
    sha256 = sha256,
    sync = sync,
    cfg = cfg,
    state = state,
    renderScreen = renderScreen,
    renderStatusBar = renderStatusBar,
    renderSessionTimer = renderSessionTimer
}

-- Session Timeout Background Worker
local timerWorker = session.createTimerWorker(
    function(remaining)
        renderSessionTimer()
    end,
    function()
        if not auth.hasPassword(cfg) then return end
        ui.cancelInstruction()
        if not session.isCommandRunning() then
            state.authorized = false
            session.stop()
            auth.restrict()
            renderSessionTimer()
            os.queueEvent("key", keys.enter)
        end
    end
)

-- Main Command and Authorization Loop
local function waitingForCommand()
    local frame = ui.getFrame()
    local w, _ = ui.getSize()

    while true do
        if state.authorized then
            frame.setCursorPos(1, 4)
            frame.write(string.rep(" ", w - 2))

            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            frame.write("Command: ")
            frame.setTextColor(colors.white)

            auth.allow()

            local inputCommand = read()

            if auth.hasPassword(cfg) and (session.isExpired() or not state.authorized) then
                session.clearExpired()
                state.authorized = false
                session.stop()
                auth.restrict()
                renderScreen()
            elseif inputCommand and inputCommand ~= "" then
                session.setCommandRunning(true)
                local result = commands.execute(inputCommand, ctx)
                session.setCommandRunning(false)

                if result == "Exit" then
                    auth.restore()
                    return
                elseif auth.hasPassword(cfg) and (result == "Logout" or cfg.timeout == 0 or session.isExpired()) then
                    session.clearExpired()
                    state.authorized = false
                    session.stop()
                    auth.restrict()
                    renderScreen()
                end
            end
        else
            frame.setCursorPos(1, 4)
            frame.write(string.rep(" ", w - 2))

            frame.setCursorPos(1, 4)
            frame.setTextColor(colors.lightGray)
            frame.write("Password: ")
            frame.setTextColor(colors.white)

            auth.restrict()

            local inputPassword = read(utf8.char(7))

            if auth.verify(inputPassword, cfg, sha256) then
                state.authorized = true
                if auth.hasPassword(cfg) then
                    session.start(cfg.timeout)
                end

                frame.clear()
                frame.setCursorPos(1, 1)
                frame.setTextColor(colors.lime)
                frame.write("Access Granted")
                renderStatusBar()
                renderSessionTimer()

                ui.queueInstruction("You can now operate the Gate")
            else
                frame.setCursorPos(1, 4)
                frame.write(string.rep(" ", w - 2))
                frame.setCursorPos(1, 4)

                frame.setTextColor(colors.red)
                frame.write("Access Denied")

                hardware.playNote("bit", 3, 5)
                sleep(0.2)
                hardware.playNote("bit", 3, 1)
                hardware.playNote("pling", 0.5, 1)
                sleep(1)
            end
        end
    end
end

-- Background sync listener worker for SYNC mode
local syncWorker = sync.createListenerWorker(function(opened, status)
    if cfg.mode == "SYNC" then
        state.gateOpened = (opened == true)
        state.status = status or ""
        renderStatusBar()
    end
end)

-- Start Application
renderScreen()
if cfg.mode == "SYNC" then
    parallel.waitForAny(waitingForCommand, ui.instructionWorker, timerWorker, syncWorker)
else
    parallel.waitForAny(waitingForCommand, hardware.alarmWorker, ui.instructionWorker, timerWorker)
end
auth.restore()