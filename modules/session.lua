-- session.lua - Session and Timeout Management Module
local session = {}

local remaining = nil
local expired = false
local commandRunning = false
local active = false

function session.start(timeoutSeconds)
    if timeoutSeconds and timeoutSeconds > 0 then
        remaining = timeoutSeconds
    else
        remaining = nil
    end
    expired = false
    active = true
end

function session.stop()
    remaining = nil
    expired = false
    active = false
end

function session.isActive()
    return active
end

function session.getRemaining()
    return remaining
end

function session.isExpired()
    return expired
end

function session.clearExpired()
    expired = false
end

function session.isCommandRunning()
    return commandRunning
end

function session.setCommandRunning(isRunning)
    commandRunning = (isRunning == true)
end

function session.createTimerWorker(onTick, onTimeout)
    return function()
        while true do
            if active and remaining and remaining > 0 then
                sleep(1)
                if active and remaining and remaining > 0 then
                    remaining = remaining - 1
                    if onTick then
                        onTick(remaining)
                    end

                    if remaining <= 0 then
                        expired = true
                        if onTimeout then
                            onTimeout()
                        end
                    end
                end
            else
                sleep(0.5)
            end
        end
    end
end

return session
