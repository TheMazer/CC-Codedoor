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
        if not state.gateOpened then
            print("Gate opening sequence engaged.")
            sleep(0.7)

            print("Sequence in process...")
            state.status = "Preparing..."
            ctx.renderStatusBar()
            hardware.startAlarm()
            sleep(2)

            state.status = "M O V I N G"
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

    elseif inTable(commandAliases["close"], command) then
        if state.gateOpened then
            print("Gate closing sequence engaged.")
            sleep(0.7)

            print("Sequence in process...")
            state.status = "Preparing..."
            ctx.renderStatusBar()
            hardware.startAlarm()
            sleep(2)

            state.status = "M O V I N G"
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

    elseif inTable(commandAliases["passwd"], command) then
        outputFrame.setTextColor(colors.white)
        print("--- Change Password ---")
        outputFrame.setTextColor(colors.lightGray)
        write("Current password: ")
        outputFrame.setTextColor(colors.white)
        local cur = read(utf8.char(7))

        if ctx.auth.verify(cur, cfg, ctx.sha256) then
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
                    cfg.password_hash = ctx.sha256.digest(newP .. (cfg.salt or ""))
                    ctx.config.save(cfg)
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

    elseif inTable(commandAliases["logout"], command) then
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
