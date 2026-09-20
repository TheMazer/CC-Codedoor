-- hardware.lua - Speaker, Redstone and Alarm Hardware Abstraction
local hardware = {}

local alarming = false
local alarmSoundEnabled = true
local remoteSoundCallback = nil

function hardware.setAlarmSoundEnabled(enabled)
    alarmSoundEnabled = (enabled == true)
end

function hardware.setRemoteSoundCallback(callback)
    remoteSoundCallback = callback
end

function hardware.getSpeakers()
    local list = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            local s = peripheral.wrap(name)
            if s and s.playNote then
                table.insert(list, s)
            end
        end
    end
    return list
end

function hardware.hasSpeaker()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            return true
        end
    end
    return false
end

function hardware.playNote(instrument, volume, pitch)
    local spkrs = hardware.getSpeakers()
    local played = false
    for _, s in ipairs(spkrs) do
        if pcall(s.playNote, instrument, volume, pitch) then
            played = true
        end
    end

    if not played and remoteSoundCallback then
        pcall(remoteSoundCallback, instrument, volume, pitch)
    end

    return played
end

function hardware.setOutput(side, state)
    if side and side ~= "" then
        rs.setOutput(side, state == true)
    end
end

function hardware.startAlarm()
    alarming = true
end

function hardware.stopAlarm()
    alarming = false
end

function hardware.isAlarming()
    return alarming
end

function hardware.restorePalette()
    if term.nativePaletteColor then
        term.setPaletteColor(colors.orange, term.nativePaletteColor(colors.orange))
    end
end

function hardware.alarmWorker()
    while true do
        while alarming do
            if alarmSoundEnabled then
                hardware.playNote("bit", 3, 6)
                hardware.playNote("harp", 3, 6)
                sleep(0.1)

                hardware.playNote("bit", 3, 6)
                hardware.playNote("harp", 3, 6)
                sleep(0.1)

                hardware.playNote("bit", 3, 6)
                hardware.playNote("harp", 3, 6)
            else
                sleep(0.2)
            end

            sleep(0.4)
        end
        sleep(0.1)
    end
end

return hardware
