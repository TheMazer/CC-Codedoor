-- commands.lua - Command Registry and Execution Module
local commands = {}

-- Defining command alias mappings for console input
local commandAliases = {
    ["help"] = {"help", "?", "commands", "list", "man"},
    ["open"] = {"open", "o"},
    ["close"] = {"close", "c"},
    ["clear"] = {"clear", "cls"},
    ["passwd"] = {"passwd", "password", "changepass", "chpass"},
    ["logout"] = {"logout", "logoff", "l"},
    ["exit"] = {"exit", "terminate"},
    ["config"] = {"config", "cfg", "settings", "setting", "set", "get"}
}

-- Checking if an element exists in the given table
local function inTable(tab, val)
    if not tab then return false end
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- Tokenizing the input command line into command name and argument list
local function parseCommandLine(input)
    local tokens = {}
    for word in (input or ""):gmatch("%S+") do
        table.insert(tokens, word)
    end
    local cmd = (tokens[1] or ""):lower()
    local args = {}
    for i = 2, #tokens do
        table.insert(args, tokens[i])
    end
    return cmd, args
end

-- Normalizing configuration key names to canonical identifiers
local function normalizeConfigKey(key)
    if not key then return nil end
    local k = key:lower()
    if k == "mode" then
        return "mode"
    elseif k == "redstone" or k == "side" or k == "redstone_side" then
        return "redstone_side"
    elseif k == "move" or k == "movetime" or k == "move_time" then
        return "move_time"
    elseif k == "alarm" or k == "alarm_sound" or k == "alarmsound" then
        return "alarm_sound"
    elseif k == "timeout" or k == "session_timeout" then
        return "timeout"
    elseif k == "server" or k == "server_name" or k == "sync.server_name" or k == "sync.server" then
        return "sync.server_name"
    elseif k == "proto" or k == "protocol" or k == "sync.protocol" or k == "sync.proto" then
        return "sync.protocol"
    elseif k == "modem" or k == "modem_side" or k == "sync.modem_side" or k == "sync.modem" then
        return "sync.modem_side"
    elseif k == "sync_timeout" or k == "sync.timeout" then
        return "sync.timeout"
    end
    return nil
end

-- Rendering page 1 of the command help manual
local function renderHelpPage1(outputFrame, state)
    local fw, fh = outputFrame.getSize()
    outputFrame.clear()
    outputFrame.setCursorPos(1, 1)

    outputFrame.setTextColor(colors.white)
    outputFrame.write("Gate Commands (1/2)")

    local items = {
        { cmd = "open, o", desc = "Open gate ", state = state.gateOpened and "[OPEN]" or "[READY]", stateColor = state.gateOpened and colors.gray or colors.lime },
        { cmd = "close, c", desc = "Close gate ", state = state.gateOpened and "[READY]" or "[CLOSED]", stateColor = state.gateOpened and colors.lime or colors.gray },
        { cmd = "config", desc = "Settings (cdsettings.json)" },
        { cmd = "passwd", desc = "Change gate password" }
    }

    local maxCmdLen = 0
    for _, item in ipairs(items) do
        if #item.cmd > maxCmdLen then
            maxCmdLen = #item.cmd
        end
    end
    local arrowCol = math.min(fw - 8, maxCmdLen + 4)

    for i, item in ipairs(items) do
        local y = i + 1
        if y < fh - 1 then
            outputFrame.setCursorPos(3, y)
            outputFrame.setTextColor(colors.white)
            outputFrame.write(item.cmd)

            outputFrame.setCursorPos(arrowCol, y)
            outputFrame.setTextColor(colors.gray)
            outputFrame.write(string.char(26) .. " ")

            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(item.desc)

            if item.state then
                outputFrame.setTextColor(item.stateColor)
                outputFrame.write(item.state)
            end
        end
    end

    local hintY = fh - 2
    if hintY > #items + 1 then
        if fw >= 42 then
            outputFrame.setCursorPos(3, hintY)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(string.char(16) .. " Type 'help <cmd>' for command details")
        elseif fw >= 25 then
            outputFrame.setCursorPos(3, hintY)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(string.char(16) .. " 'help <cmd>' for details")
        end
    end

    if fh > 1 then
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(1, fw - 1)))
    end

    outputFrame.setCursorPos(1, fh)
    outputFrame.setTextColor(colors.lightGray)
    if fw >= 38 then
        outputFrame.write("Page 1/2 " .. string.char(175) .. " Type ")
        outputFrame.setTextColor(colors.white)
        outputFrame.write("'help 2'")
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write(" for next page")
    else
        outputFrame.write("[1/2] Type ")
        outputFrame.setTextColor(colors.white)
        outputFrame.write("'help 2'")
    end
end

-- Rendering page 2 of the command help manual
local function renderHelpPage2(outputFrame)
    local fw, fh = outputFrame.getSize()
    outputFrame.clear()
    outputFrame.setCursorPos(1, 1)

    outputFrame.setTextColor(colors.white)
    outputFrame.write("Session & Shell Commands (2/2)")

    local items = {
        { cmd = "logout, l", desc = "Lock console & log off" },
        { cmd = "clear, cls", desc = "Clear terminal output" },
        { cmd = "exit", desc = "Exit controller interface" },
        { cmd = "help, man", desc = "Show command manual" }
    }

    local maxCmdLen = 0
    for _, item in ipairs(items) do
        if #item.cmd > maxCmdLen then
            maxCmdLen = #item.cmd
        end
    end
    local arrowCol = math.min(fw - 8, maxCmdLen + 4)

    for i, item in ipairs(items) do
        local y = i + 1
        if y < fh - 1 then
            outputFrame.setCursorPos(3, y)
            outputFrame.setTextColor(colors.white)
            outputFrame.write(item.cmd)

            outputFrame.setCursorPos(arrowCol, y)
            outputFrame.setTextColor(colors.gray)
            outputFrame.write(string.char(26) .. " ")

            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(item.desc)
        end
    end

    local hintY = fh - 2
    if hintY > #items + 1 then
        if fw >= 42 then
            outputFrame.setCursorPos(3, hintY)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(string.char(16) .. " Run 'config' to inspect cdsettings.json")
        elseif fw >= 25 then
            outputFrame.setCursorPos(3, hintY)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(string.char(16) .. " 'config' for settings")
        end
    end

    if fh > 1 then
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(1, fw - 1)))
    end

    outputFrame.setCursorPos(1, fh)
    outputFrame.setTextColor(colors.lightGray)
    if fw >= 38 then
        outputFrame.write("Page 2/2 " .. string.char(175) .. " Type ")
        outputFrame.setTextColor(colors.white)
        outputFrame.write("'help 1'")
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write(" for first page")
    else
        outputFrame.write("[2/2] Type ")
        outputFrame.setTextColor(colors.white)
        outputFrame.write("'help 1'")
    end
end

-- Rendering targeted command manual entry
local function renderHelpCommand(outputFrame, targetCmd, state)
    local fw, fh = outputFrame.getSize()
    outputFrame.clear()
    outputFrame.setCursorPos(1, 1)

    targetCmd = (targetCmd or ""):lower()

    if targetCmd == "config" or targetCmd == "cfg" or targetCmd == "settings" or targetCmd == "set" or targetCmd == "get" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: config / cfg")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: config [get|set] <key> [val]")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("  " .. string.char(7) .. " config list    " .. string.char(26) .. " View all settings")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("  " .. string.char(7) .. " config get <k> " .. string.char(26) .. " Read setting")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("  " .. string.char(7) .. " config set <k> " .. string.char(26) .. " Change setting")
        outputFrame.setCursorPos(1, 6)
        outputFrame.write("Keys: mode, redstone, move, alarm, timeout,")
        outputFrame.setCursorPos(1, 7)
        outputFrame.write("      server, proto, modem, sync_timeout")
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Tip: 'set <k> <v>' works as shorthand")

    elseif targetCmd == "open" or targetCmd == "o" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: open (alias: o)")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: open")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Initiates gate opening sequence.")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("  " .. string.char(7) .. " STANDALONE: plays alarm & redstone on")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("  " .. string.char(7) .. " SYNC: dispatches request to GateServer")
        outputFrame.setCursorPos(1, 6)
        outputFrame.write("Current Gate State: ")
        if state.gateOpened then
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("OPEN")
        else
            outputFrame.setTextColor(colors.red)
            outputFrame.write("CLOSED")
        end
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(10, fw - 1)))
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Run 'close' to shut the gate")

    elseif targetCmd == "close" or targetCmd == "c" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: close (alias: c)")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: close")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Initiates gate closing sequence.")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("  " .. string.char(7) .. " STANDALONE: plays alarm & redstone off")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("  " .. string.char(7) .. " SYNC: dispatches request to GateServer")
        outputFrame.setCursorPos(1, 6)
        outputFrame.write("Current Gate State: ")
        if state.gateOpened then
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("OPEN")
        else
            outputFrame.setTextColor(colors.red)
            outputFrame.write("CLOSED")
        end
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(10, fw - 1)))
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Run 'open' to open the gate")

    elseif targetCmd == "passwd" or targetCmd == "password" or targetCmd == "changepass" or targetCmd == "chpass" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: passwd")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: passwd")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Starts interactive password modification.")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("  " .. string.char(7) .. " Requires current password if set")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("  " .. string.char(7) .. " Confirm new password to apply")
        outputFrame.setCursorPos(1, 6)
        outputFrame.write("  " .. string.char(7) .. " Empty password disables auth & login")
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(10, fw - 1)))
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Changes save directly to cdsettings.json")

    elseif targetCmd == "logout" or targetCmd == "logoff" or targetCmd == "l" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: logout (alias: l)")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: logout")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Ends the current authorized session and")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("returns to the password entry screen.")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("If no password is set, login is bypassed.")
        outputFrame.setCursorPos(1, fh - 1)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(10, fw - 1)))
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Use 'passwd' to set an access password")

    elseif targetCmd == "clear" or targetCmd == "cls" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: clear (alias: cls)")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: clear")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Clears all command output and resets")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("the terminal display output area.")

    elseif targetCmd == "exit" or targetCmd == "terminate" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: exit")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: exit")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("Terminates gate controller program and")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("returns to CraftOS terminal session.")

    elseif targetCmd == "help" or targetCmd == "man" or targetCmd == "commands" or targetCmd == "list" or targetCmd == "?" then
        outputFrame.setTextColor(colors.white)
        outputFrame.write("Manual: help / man")
        outputFrame.setCursorPos(1, 2)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Usage: help [page | command | -i]")
        outputFrame.setCursorPos(1, 3)
        outputFrame.write("  " .. string.char(7) .. " help 1 / help 2  " .. string.char(26) .. " Jump to page")
        outputFrame.setCursorPos(1, 4)
        outputFrame.write("  " .. string.char(7) .. " help <command>   " .. string.char(26) .. " View command manual")
        outputFrame.setCursorPos(1, 5)
        outputFrame.write("  " .. string.char(7) .. " help -i          " .. string.char(26) .. " Interactive mode")

    else
        ui.drawPromptArrow(colors.red)
        outputFrame.setTextColor(colors.red)
        outputFrame.write("No manual entry for '" .. tostring(targetCmd) .. "'")
        outputFrame.setCursorPos(1, 3)
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write("Type 'help' to view all available commands.")
    end
end

-- Running interactive paging navigation mode
local function runInteractiveHelp(outputFrame, state)
    local fw, fh = outputFrame.getSize()
    local curPage = 1
    local function renderCurrent()
        if curPage == 1 then
            renderHelpPage1(outputFrame, state)
        else
            renderHelpPage2(outputFrame)
        end
        outputFrame.setCursorPos(1, fh)
        outputFrame.write(string.rep(" ", fw))
        outputFrame.setCursorPos(1, fh)
        outputFrame.setTextColor(colors.white)
        outputFrame.write("[" .. curPage .. "/2] ")
        outputFrame.setTextColor(colors.lightGray)
        local hint = "Space/Arrows: flip " .. string.char(179) .. " Enter: ready"
        if #hint + 8 > fw then
            hint = "Space: flip " .. string.char(179) .. " Enter: ok"
        end
        if #hint + 8 > fw then
            hint = "Space: flip"
        end
        outputFrame.write(hint)
    end

    renderCurrent()

    local timerId = os.startTimer(15)
    while true do
        local event, p1 = os.pullEvent()
        if event == "term_resize" then
            fw, fh = outputFrame.getSize()
            renderCurrent()
        elseif event == "timer" and p1 == timerId then
            break
        elseif event == "key" then
            if p1 == keys.space or p1 == keys.pageDown or p1 == keys.down or p1 == keys.right then
                curPage = (curPage == 1) and 2 or 1
                renderCurrent()
            elseif p1 == keys.pageUp or p1 == keys.up or p1 == keys.left then
                curPage = 1
                renderCurrent()
            elseif p1 == keys.enter or p1 == keys.q or p1 == keys.escape then
                break
            end
        end
    end
end

-- Rendering configuration overview table
local function renderConfigList(outputFrame, cfg)
    local fw, fh = outputFrame.getSize()
    outputFrame.clear()
    outputFrame.setCursorPos(1, 1)

    outputFrame.setTextColor(colors.white)
    outputFrame.write(fw >= 32 and "Configuration (cdsettings.json)" or "Configuration")

    local col1 = 3
    local twoColumn = (fw >= 36)
    local col2 = math.floor(fw / 2) + 3

    -- Defining paired settings rows
    local pairsList = {
        {
            { label = "mode", val = tostring(cfg.mode or "STANDALONE"), valColor = colors.white },
            { label = "alarm", val = tostring(cfg.alarm_sound == true), valColor = cfg.alarm_sound and colors.lime or colors.red }
        },
        {
            { label = "redstone", val = tostring(cfg.redstone_side or "bottom"), valColor = colors.white },
            { label = "timeout", val = (cfg.timeout or 0) .. "s", valColor = colors.white }
        },
        {
            { label = "move_time", val = (cfg.move_time or 16) .. "s", valColor = colors.white },
            { label = "modem", val = tostring(cfg.sync and cfg.sync.modem_side or "auto"), valColor = colors.white }
        },
        {
            { label = "server", val = tostring(cfg.sync and cfg.sync.server_name or "None"), valColor = colors.white },
            { label = "sync.t/o", val = (cfg.sync and cfg.sync.timeout or 3) .. "s", valColor = colors.white }
        },
        {
            { label = "protocol", val = tostring(cfg.sync and cfg.sync.protocol or "None"), valColor = colors.white },
            nil
        }
    }

    for r, row in ipairs(pairsList) do
        local y = r + 1
        if y < fh - 1 then
            local item1 = row[1]
            if item1 then
                outputFrame.setCursorPos(col1, y)
                outputFrame.setTextColor(colors.lightGray)
                outputFrame.write(item1.label .. ": ")
                outputFrame.setTextColor(item1.valColor)
                local maxLen1 = twoColumn and math.max(4, col2 - col1 - #item1.label - 3) or math.max(4, fw - col1 - #item1.label - 2)
                local valStr1 = #item1.val > maxLen1 and item1.val:sub(1, maxLen1) or item1.val
                outputFrame.write(valStr1)
            end

            local item2 = row[2]
            if twoColumn and item2 then
                outputFrame.setCursorPos(col2, y)
                outputFrame.setTextColor(colors.lightGray)
                outputFrame.write(item2.label .. ": ")
                outputFrame.setTextColor(item2.valColor)
                local maxLen2 = math.max(4, fw - col2 - #item2.label - 2)
                local valStr2 = #item2.val > maxLen2 and item2.val:sub(1, maxLen2) or item2.val
                outputFrame.write(valStr2)
            end
        end
    end

    local divY = fh - 1
    local footY = fh
    if fh < 8 then
        divY = math.min(fh - 1, #pairsList + 2)
        footY = divY + 1
    end

    if divY > 1 and divY <= fh then
        outputFrame.setCursorPos(1, divY)
        outputFrame.setTextColor(colors.gray)
        outputFrame.write(string.rep("-", math.max(1, fw - 1)))
    end

    if footY <= fh then
        outputFrame.setCursorPos(1, footY)
        outputFrame.setTextColor(colors.lightGray)
        if fw >= 42 then
            outputFrame.write("Use: ")
            outputFrame.setTextColor(colors.white)
            outputFrame.write("config set <key> <val>")
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write(" " .. string.char(175) .. " ")
            outputFrame.setTextColor(colors.white)
            outputFrame.write("'help config'")
        elseif fw >= 24 then
            outputFrame.write("Set: ")
            outputFrame.setTextColor(colors.white)
            outputFrame.write("cfg set <k> <v>")
        end
    end
end

-- Handling configuration inspect and mutate operations
local function handleConfigCommand(outputFrame, subcmd, key, val, ctx)
    local cfg = ctx.config.get()
    local hardware = ctx.hardware
    local state = ctx.state
    local ui = ctx.ui

    if not subcmd or subcmd == "" or subcmd == "list" or subcmd == "show" then
        renderConfigList(outputFrame, cfg)
        return
    end

    if subcmd == "get" then
        if not key or key == "" then
            outputFrame.setTextColor(colors.white)
            outputFrame.write("Usage: config get <key>")
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("Type 'config' to view all settings.")
            return
        end

        local normKey = normalizeConfigKey(key)
        if not normKey then
            ui.drawPromptArrow(colors.red)
            outputFrame.setTextColor(colors.red)
            outputFrame.write("Unknown setting: '" .. tostring(key) .. "'")
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("Type 'help config' for list of valid keys.")
            return
        end

        local displayVal = nil
        if normKey == "mode" then
            displayVal = cfg.mode
        elseif normKey == "redstone_side" then
            displayVal = cfg.redstone_side
        elseif normKey == "move_time" then
            displayVal = (cfg.move_time or 16) .. "s"
        elseif normKey == "alarm_sound" then
            displayVal = tostring(cfg.alarm_sound == true)
        elseif normKey == "timeout" then
            displayVal = (cfg.timeout or 0) .. "s"
        elseif normKey == "sync.server_name" then
            displayVal = cfg.sync and cfg.sync.server_name or "None"
        elseif normKey == "sync.protocol" then
            displayVal = cfg.sync and cfg.sync.protocol or "None"
        elseif normKey == "sync.modem_side" then
            displayVal = cfg.sync and cfg.sync.modem_side or "auto"
        elseif normKey == "sync.timeout" then
            displayVal = (cfg.sync and cfg.sync.timeout or 3) .. "s"
        end

        outputFrame.setTextColor(colors.white)
        outputFrame.write(normKey .. ": ")
        outputFrame.setTextColor(colors.lightGray)
        outputFrame.write(tostring(displayVal))
        return
    end

    if subcmd == "set" then
        if not key or key == "" then
            outputFrame.setTextColor(colors.white)
            outputFrame.write("Usage: config set <key> <value>")
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("Type 'help config' for list of keys.")
            return
        end

        local normKey = normalizeConfigKey(key)
        if not normKey then
            ui.drawPromptArrow(colors.red)
            outputFrame.setTextColor(colors.red)
            outputFrame.write("Unknown setting: '" .. tostring(key) .. "'")
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("Type 'help config' for list of keys.")
            return
        end

        if not val or val == "" then
            ui.drawPromptArrow(colors.red)
            outputFrame.setTextColor(colors.red)
            outputFrame.write("Error: Missing value for '" .. normKey .. "'")
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("Usage: config set " .. normKey .. " <value>")
            return
        end

        -- Validating and applying setting modifications
        if normKey == "mode" then
            local v = val:upper()
            if v ~= "STANDALONE" and v ~= "SYNC" then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: mode must be STANDALONE or SYNC")
                return
            end
            cfg.mode = v
            ctx.config.save(cfg)
            if ctx.renderStatusBar then ctx.renderStatusBar() end
            if v == "SYNC" and ctx.sync then
                ctx.sync.init(cfg)
            end
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Mode updated to: " .. v)
            outputFrame.setCursorPos(1, 3)
            outputFrame.setTextColor(colors.lightGray)
            outputFrame.write("(Note: Restart recommended for full effect)")

        elseif normKey == "redstone_side" then
            local validSides = { ["bottom"] = true, ["top"] = true, ["left"] = true, ["right"] = true, ["front"] = true, ["back"] = true }
            local v = val:lower()
            if not validSides[v] then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: invalid side '" .. v .. "'")
                outputFrame.setCursorPos(1, 3)
                outputFrame.setTextColor(colors.lightGray)
                outputFrame.write("Valid sides: top, bottom, left, right, front, back")
                return
            end
            if cfg.mode == "STANDALONE" and cfg.redstone_side ~= v then
                hardware.setOutput(cfg.redstone_side, false)
            end
            cfg.redstone_side = v
            if cfg.mode == "STANDALONE" then
                hardware.setOutput(cfg.redstone_side, state.gateOpened)
            end
            ctx.config.save(cfg)
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Redstone side set to: " .. v)

        elseif normKey == "move_time" then
            local num = tonumber(val)
            if not num or num < 1 or num > 300 then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: move_time must be between 1 and 300")
                return
            end
            cfg.move_time = math.floor(num)
            ctx.config.save(cfg)
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Move time set to: " .. cfg.move_time .. "s")

        elseif normKey == "alarm_sound" then
            local v = val:lower()
            local bVal = nil
            if v == "true" or v == "yes" or v == "on" or v == "1" then
                bVal = true
            elseif v == "false" or v == "no" or v == "off" or v == "0" then
                bVal = false
            else
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: alarm_sound must be true/false or on/off")
                return
            end
            cfg.alarm_sound = bVal
            hardware.setAlarmSoundEnabled(bVal)
            ctx.config.save(cfg)
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Alarm sound: " .. (bVal and "ENABLED" or "DISABLED"))

        elseif normKey == "timeout" then
            local num = tonumber(val)
            if not num or num < 0 or num > 86400 then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: timeout must be 0 (disabled) or 1-86400")
                return
            end
            cfg.timeout = math.floor(num)
            ctx.config.save(cfg)
            if ctx.session then
                if cfg.timeout == 0 then
                    ctx.session.stop()
                else
                    ctx.session.start(cfg.timeout)
                end
            end
            if ctx.renderSessionTimer then
                ctx.renderSessionTimer()
            end
            outputFrame.setTextColor(colors.lime)
            if cfg.timeout == 0 then
                outputFrame.write("Session timeout disabled.")
            else
                outputFrame.write("Session timeout set to: " .. cfg.timeout .. "s")
            end

        elseif normKey == "sync.server_name" then
            if val == "" then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: server_name cannot be empty")
                return
            end
            cfg.sync = cfg.sync or {}
            cfg.sync.server_name = val
            ctx.config.save(cfg)
            if ctx.sync then ctx.sync.init(cfg) end
            if ctx.renderStatusBar then ctx.renderStatusBar() end
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Sync server name set to: " .. val)

        elseif normKey == "sync.protocol" then
            if val == "" then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: protocol cannot be empty")
                return
            end
            cfg.sync = cfg.sync or {}
            cfg.sync.protocol = val
            ctx.config.save(cfg)
            if ctx.sync then ctx.sync.init(cfg) end
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Sync protocol set to: " .. val)

        elseif normKey == "sync.modem_side" then
            local validModems = { ["auto"] = true, ["bottom"] = true, ["top"] = true, ["left"] = true, ["right"] = true, ["front"] = true, ["back"] = true }
            local v = val:lower()
            if not validModems[v] then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: modem_side must be auto or valid side")
                return
            end
            cfg.sync = cfg.sync or {}
            cfg.sync.modem_side = v
            ctx.config.save(cfg)
            if ctx.sync then ctx.sync.init(cfg) end
            if ctx.renderStatusBar then ctx.renderStatusBar() end
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Sync modem side set to: " .. v)

        elseif normKey == "sync.timeout" then
            local num = tonumber(val)
            if not num or num < 1 or num > 60 then
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                outputFrame.write("Error: sync.timeout must be between 1 and 60")
                return
            end
            cfg.sync = cfg.sync or {}
            cfg.sync.timeout = math.floor(num)
            ctx.config.save(cfg)
            if ctx.sync then ctx.sync.init(cfg) end
            outputFrame.setTextColor(colors.lime)
            outputFrame.write("Sync timeout set to: " .. cfg.sync.timeout .. "s")
        end
        return
    end

    ui.drawPromptArrow(colors.red)
    outputFrame.setTextColor(colors.red)
    outputFrame.write("Unknown config action: '" .. tostring(subcmd) .. "'")
    outputFrame.setCursorPos(1, 3)
    outputFrame.setTextColor(colors.lightGray)
    outputFrame.write("Usage: config [get|set] <key> [value]")
end

-- Checking if command matches an alias category
function commands.isCommand(aliasCategory, command)
    local cmd = parseCommandLine(command)
    return inTable(commandAliases[aliasCategory], cmd)
end

-- Executing incoming console command line
function commands.execute(command, ctx)
    local ui = ctx.ui
    local hardware = ctx.hardware
    local cfg = ctx.config.get()
    local state = ctx.state

    local cmd, args = parseCommandLine(command)
    if cmd == "" then
        return "OK"
    end

    ui.cancelInstruction()
    ctx.renderScreen()

    if not (inTable(commandAliases["clear"], cmd) or inTable(commandAliases["logout"], cmd) or inTable(commandAliases["exit"], cmd)) then
        ui.drawPromptArrow(colors.white)
    end

    local outputFrame = ui.createOutputFrame()
    term.redirect(outputFrame)

    -- Executing help and manual command
    if inTable(commandAliases["help"], cmd) then
        local firstArg = args[1] and args[1]:lower()

        if firstArg == "-i" or firstArg == "--interactive" then
            runInteractiveHelp(outputFrame, state)
        elseif firstArg == "2" or firstArg == "next" or firstArg == "n" then
            renderHelpPage2(outputFrame)
        elseif firstArg == "1" or firstArg == "prev" or firstArg == "p" or not firstArg then
            renderHelpPage1(outputFrame, state)
        else
            renderHelpCommand(outputFrame, firstArg, state)
        end

    -- Executing configuration management command
    elseif inTable(commandAliases["config"], cmd) then
        local subcmd, key, val

        if cmd == "set" then
            subcmd = "set"
            key = args[1]
            val = args[2]
        elseif cmd == "get" then
            subcmd = "get"
            key = args[1]
        else
            subcmd = args[1] and args[1]:lower()
            key = args[2]
            val = args[3]
        end

        handleConfigCommand(outputFrame, subcmd, key, val, ctx)

    -- Executing gate open sequence
    elseif inTable(commandAliases["open"], cmd) then
        if cfg.mode == "SYNC" then
            if ctx.sync then
                print("Sending open request to server...")
                local ok, res = ctx.sync.requestOpen()
                if ok then
                    print(res and res.message or "Gate opening engaged on server.")
                else
                    ui.drawPromptArrow(colors.red)
                    outputFrame.setTextColor(colors.red)
                    print("Error: " .. (res and res.message or "Failed to connect to server"))
                    outputFrame.setTextColor(colors.white)
                end
            else
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                print("Error: Sync module not available.")
                outputFrame.setTextColor(colors.white)
            end
        else
            if not state.gateOpened then
                print("Gate opening sequence engaged.")
                sleep(0.7)

                print("Sequence in process...")
                state.status = "Preparing..."
                ctx.renderStatusBar()
                hardware.startAlarm()
                sleep(2)

                state.status = "Moving"
                ctx.renderStatusBar()
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

                state.status = ""
                state.gateOpened = true
                ctx.config.saveGateState(true)
                ctx.renderStatusBar()
                print("Gate opened.")
            else
                print("Gate already opened.")
            end
        end

    -- Executing gate close sequence
    elseif inTable(commandAliases["close"], cmd) then
        if cfg.mode == "SYNC" then
            if ctx.sync then
                print("Sending close request to server...")
                local ok, res = ctx.sync.requestClose()
                if ok then
                    print(res and res.message or "Gate closing engaged on server.")
                else
                    ui.drawPromptArrow(colors.red)
                    outputFrame.setTextColor(colors.red)
                    print("Error: " .. (res and res.message or "Failed to connect to server"))
                    outputFrame.setTextColor(colors.white)
                end
            else
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                print("Error: Sync module not available.")
                outputFrame.setTextColor(colors.white)
            end
        else
            if state.gateOpened then
                print("Gate closing sequence engaged.")
                sleep(0.7)

                print("Sequence in process...")
                state.status = "Preparing..."
                ctx.renderStatusBar()
                hardware.startAlarm()
                sleep(2)

                state.status = "Moving"
                ctx.renderStatusBar()
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

                state.status = ""
                state.gateOpened = false
                ctx.config.saveGateState(false)
                ctx.renderStatusBar()
                print("Gate closed.")
            else
                print("Gate already closed.")
            end
        end

    -- Executing password alteration sequence
    elseif inTable(commandAliases["passwd"], cmd) then
        outputFrame.setTextColor(colors.white)
        print("Change Password")

        local canProceed = false
        if ctx.auth.hasPassword(cfg) then
            outputFrame.setTextColor(colors.lightGray)
            write("Current password: ")
            outputFrame.setTextColor(colors.white)
            local cur = read(utf8.char(7))

            if ctx.auth.verify(cur, cfg, ctx.sha256) then
                canProceed = true
            else
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                print("Incorrect current password.")
            end
        else
            canProceed = true
        end

        if canProceed then
            outputFrame.setTextColor(colors.lightGray)
            print("Enter new password (empty to remove):")
            write("New password: ")
            outputFrame.setTextColor(colors.white)
            local newP = read(utf8.char(7))

            outputFrame.setTextColor(colors.lightGray)
            write("Confirm password: ")
            outputFrame.setTextColor(colors.white)
            local confP = read(utf8.char(7))

            if newP == confP then
                if newP == "" then
                    cfg.password_hash = ""
                    ctx.config.save(cfg)
                    if ctx.session then
                        ctx.session.stop()
                    end
                    if ctx.renderSessionTimer then
                        ctx.renderSessionTimer()
                    end
                    outputFrame.setTextColor(colors.lime)
                    print("Password removed! Authorization disabled.")
                else
                    cfg.password_hash = ctx.sha256.digest(newP .. (cfg.salt or ""))
                    ctx.config.save(cfg)
                    if ctx.session and cfg.timeout and cfg.timeout > 0 then
                        ctx.session.start(cfg.timeout)
                    end
                    if ctx.renderSessionTimer then
                        ctx.renderSessionTimer()
                    end
                    outputFrame.setTextColor(colors.lime)
                    print("Password changed successfully!")
                end
            else
                ui.drawPromptArrow(colors.red)
                outputFrame.setTextColor(colors.red)
                print("Passwords do not match.")
            end
        end

    -- Executing terminal clear command
    elseif inTable(commandAliases["clear"], cmd) then
        outputFrame.clear()
        term.redirect(ui.getFrame())
        return "OK"

    -- Executing user logout sequence
    elseif inTable(commandAliases["logout"], cmd) then
        if not ctx.auth.hasPassword(cfg) then
            outputFrame.setTextColor(colors.yellow)
            print("No password set. Authorization is disabled.")
            sleep(1.5)
            term.redirect(ui.getFrame())
            return "OK"
        end

        term.redirect(ui.getFrame())
        ctx.renderScreen()

        ui.getFrame().setCursorPos(1, 4)
        ui.getFrame().setTextColor(colors.lightGray)
        ui.getFrame().write("Logging off...")

        sleep(1.5)
        return "Logout"

    -- Executing application termination sequence
    elseif inTable(commandAliases["exit"], cmd) then
        return "Exit"
    else
        ui.drawPromptArrow(colors.red)
        outputFrame.setTextColor(colors.red)
        print("Unknown command: " .. tostring(cmd))
        outputFrame.setTextColor(colors.lightGray)
        print("Type 'help' for available commands.")
    end

    term.redirect(ui.getFrame())
    return "OK"
end

return commands
