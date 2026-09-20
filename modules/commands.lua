-- commands.lua - Command Registry and Execution Module
local commands = {}

local commandAliases = {
    ["help"] = {"help", "?", "commands", "list"},
    ["open"] = {"open", "o"},
    ["close"] = {"close", "c"},
    ["clear"] = {"clear", "cls"},
    ["passwd"] = {"passwd", "password", "changepass", "chpass"},
    ["logout"] = {"logout", "logoff", "l"},
    ["exit"] = {"exit", "terminate"}
}

local function inTable(tab, val)
    if not tab then return false end
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function commands.isCommand(aliasCategory, command)
    return inTable(commandAliases[aliasCategory], command)
end

function commands.execute(command, ctx)
    local ui = ctx.ui
    local hardware = ctx.hardware
    local cfg = ctx.config.get()
    local state = ctx.state

    ui.cancelInstruction()
    ctx.renderScreen()

    if not (inTable(commandAliases["clear"], command) or inTable(commandAliases["logout"], command) or inTable(commandAliases["exit"], command)) then
        ui.drawPromptArrow()
    end

    local outputFrame = ui.createOutputFrame()
    term.redirect(outputFrame)

    if inTable(commandAliases["help"], command) then
        outputFrame.setTextColor(colors.white)
        write("help")
        outputFrame.setTextColor(colors.lightGray)
        print("   - List of available commands.")

        if state.gateOpened then
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

    elseif inTable(commandAliases["open"], command) then
        if cfg.mode == "SYNC" then
            if ctx.sync then
                print("Sending open request to server...")
                local ok, res = ctx.sync.requestOpen()
                if ok then
                    print(res and res.message or "Gate opening engaged on server.")
                else
                    outputFrame.setTextColor(colors.red)
                    print("Error: " .. (res and res.message or "Failed to connect to server"))
                    outputFrame.setTextColor(colors.white)
                end
            else
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

    elseif inTable(commandAliases["close"], command) then
        if cfg.mode == "SYNC" then
            if ctx.sync then
                print("Sending close request to server...")
                local ok, res = ctx.sync.requestClose()
                if ok then
                    print(res and res.message or "Gate closing engaged on server.")
                else
                    outputFrame.setTextColor(colors.red)
                    print("Error: " .. (res and res.message or "Failed to connect to server"))
                    outputFrame.setTextColor(colors.white)
                end
            else
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

    elseif inTable(commandAliases["passwd"], command) then
        outputFrame.setTextColor(colors.white)
        print("--- Change Password ---")

        local canProceed = false
        if ctx.auth.hasPassword(cfg) then
            outputFrame.setTextColor(colors.lightGray)
            write("Current password: ")
            outputFrame.setTextColor(colors.white)
            local cur = read(utf8.char(7))

            if ctx.auth.verify(cur, cfg, ctx.sha256) then
                canProceed = true
            else
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
                outputFrame.setTextColor(colors.red)
                print("Passwords do not match.")
            end
        end
        sleep(1.5)

    elseif inTable(commandAliases["logout"], command) then
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

    elseif inTable(commandAliases["exit"], command) then
        return "Exit"
    end

    term.redirect(ui.getFrame())
    return "OK"
end

return commands
