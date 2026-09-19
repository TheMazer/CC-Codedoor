-- auth.lua - Authentication and Termination Control Module
local auth = {}

local oldPullEvent = os.pullEvent

function auth.restrict()
    os.pullEvent = os.pullEventRaw
end

function auth.allow()
    os.pullEvent = oldPullEvent
end

function auth.restore()
    os.pullEvent = oldPullEvent
end

function auth.hasPassword(configData)
    return configData and configData.password_hash and configData.password_hash ~= ""
end

function auth.verify(inputPassword, configData, sha256)
    if not auth.hasPassword(configData) then
        return true
    end

    if not inputPassword or inputPassword == "" then
        return false
    end

    if not sha256 then
        return false
    end

    local salt = configData.salt or ""
    local hashWithSalt = sha256.digest(inputPassword .. salt)
    local hashPlain = sha256.digest(inputPassword)

    return (hashWithSalt:lower() == configData.password_hash:lower()) or
           (hashPlain:lower() == configData.password_hash:lower())
end

return auth
