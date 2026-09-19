-- config.lua - Configuration & State Management Module
local config = {}

local programPath = shell and shell.getRunningProgram() or ""
local baseDir = fs.getDir(programPath)
if fs.getName(baseDir) == "modules" then
    baseDir = fs.getDir(baseDir)
end

local function getFilePath(filename)
    if baseDir ~= "" and fs.exists(fs.combine(baseDir, filename)) then
        return fs.combine(baseDir, filename)
    elseif fs.exists(filename) then
        return filename
    elseif baseDir ~= "" then
        return fs.combine(baseDir, filename)
    else
        return filename
    end
end

config.baseDir = baseDir
config.getFilePath = getFilePath

local CONFIG_FILE = getFilePath("cdsettings.json")
local STATE_FILE = getFilePath("gatestate.json")
local LEGACY_CONFIG_FILE = getFilePath("cdsettings.cfg")

local settings = {
    password_hash = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4",
    salt = "",
    redstone_side = "bottom",
    move_time = 16,
    alarm_sound = true,
    timeout = 300
}

function config.get()
    return settings
end

function config.save(cfg)
    cfg = cfg or settings
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(textutils.serializeJSON(cfg, false))
        file.close()
    end
end

function config.load(sha256)
    if fs.exists(CONFIG_FILE) then
        local file = fs.open(CONFIG_FILE, "r")
        if file then
            local data = textutils.unserializeJSON(file.readAll())
            file.close()
            if type(data) == "table" then
                for k, v in pairs(data) do
                    settings[k] = v
                end
                if data.password ~= nil then
                    if tostring(data.password) == "" then
                        settings.password_hash = ""
                    elseif sha256 then
                        settings.password_hash = sha256.digest(tostring(data.password) .. (settings.salt or ""))
                    end
                    settings.password = nil
                    config.save(settings)
                end
                return settings
            end
        end
    end

    if fs.exists(LEGACY_CONFIG_FILE) then
        local file = fs.open(LEGACY_CONFIG_FILE, "r")
        if file then
            local rawPass = file.readLine()
            local rawSide = file.readLine()
            local rawTime = file.readLine()
            file.close()

            if rawPass and rawPass ~= "" then
                if #rawPass == 64 and rawPass:match("^%x+$") then
                    settings.password_hash = rawPass:lower()
                elseif sha256 then
                    settings.password_hash = sha256.digest(rawPass .. (settings.salt or ""))
                end
            else
                settings.password_hash = ""
            end
            if rawSide and rawSide ~= "" then
                settings.redstone_side = rawSide
            end
            if rawTime and tonumber(rawTime) then
                settings.move_time = tonumber(rawTime)
            end

            config.save(settings)
            return settings
        end
    end

    config.save(settings)
    return settings
end

function config.loadGateState()
    if fs.exists(STATE_FILE) then
        local file = fs.open(STATE_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()

            local ok, data = pcall(textutils.unserializeJSON, content)
            if ok and type(data) == "table" and data.opened ~= nil then
                return data.opened == true
            end

            local okNbt, dataNbt = pcall(textutils.unserializeJSON, content, { nbt_style = true })
            if okNbt and type(dataNbt) == "table" and dataNbt.opened ~= nil then
                return dataNbt.opened == true
            end

            local okLua, dataLua = pcall(textutils.unserialize, content)
            if okLua and type(dataLua) == "table" and dataLua.opened ~= nil then
                return dataLua.opened == true
            end

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

function config.saveGateState(opened)
    local file = fs.open(STATE_FILE, "w")
    if file then
        file.write('{\n  "opened": ' .. tostring(opened == true) .. '\n}\n')
        file.close()
    end
end

return config
