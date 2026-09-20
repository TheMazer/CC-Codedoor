-- hardware.lua - Speaker, Redstone and Alarm Hardware Abstraction
local hardware = {}

local spkr = peripheral.find("speaker")
local alarming = false
local alarmSoundEnabled = true

function hardware.setAlarmSoundEnabled(enabled)
    alarmSoundEnabled = (enabled == true)
end

function hardware.playNote(instrument, volume, pitch)
    if spkr then
        pcall(spkr.playNote, instrument, volume, pitch)
    end
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
