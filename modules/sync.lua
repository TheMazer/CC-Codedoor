-- sync.lua - Network Synchronization Module for SYNC Mode
local sync = {}

local protocol = "codedoor_sync"
local serverName = "GateServer"
local modemSide = "auto"
local defaultTimeout = 3
local lastServerId = nil

function sync.init(cfg)
    if cfg and cfg.sync then
        protocol = cfg.sync.protocol or protocol
        serverName = cfg.sync.server_name or serverName
        modemSide = cfg.sync.modem_side or modemSide
        defaultTimeout = cfg.sync.timeout or defaultTimeout
    end

    if rednet.isOpen() then
        return true
    end

    if modemSide and modemSide ~= "auto" then
        if peripheral.getType(modemSide) == "modem" then
            rednet.open(modemSide)
            return rednet.isOpen()
        end
    end

    -- Automatically find and open any modem
    peripheral.find("modem", function(name)
        if not rednet.isOpen() then
            rednet.open(name)
        end
    end)

    return rednet.isOpen()
end

function sync.isAvailable()
    return rednet.isOpen()
end

function sync.findServer(forceRefresh)
    if lastServerId and not forceRefresh then
        return lastServerId
    end

    if not rednet.isOpen() then
        sync.init()
    end

    if not rednet.isOpen() then
        return nil
    end

    local id = nil
    if serverName and serverName ~= "" then
        id = rednet.lookup(protocol, serverName)
    end

    if not id then
        local anyServer = rednet.lookup(protocol)
        if type(anyServer) == "table" then
            id = anyServer[1]
        elseif type(anyServer) == "number" then
            id = anyServer
        end
    end

    if id then
        lastServerId = id
    end
    return id
end

function sync.request(action, payload, timeoutSeconds)
    timeoutSeconds = timeoutSeconds or defaultTimeout

    if not rednet.isOpen() then
        sync.init()
    end
    if not rednet.isOpen() then
        return false, { message = "No modem connected or rednet closed" }
    end

    local serverId = sync.findServer(false)
    if not serverId then
        serverId = sync.findServer(true)
    end
    if not serverId then
        return false, { message = "Gate server not found on network" }
    end

    local reqId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    local packet = {
        type = "request",
        reqId = reqId,
        action = action,
        payload = payload,
        sender = os.getComputerID()
    }

    rednet.send(serverId, textutils.serializeJSON(packet), protocol)

    local timerId = os.startTimer(timeoutSeconds)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" then
            local sender, msg, msgProto = p1, p2, p3
            if sender == serverId and msgProto == protocol then
                local ok, data = pcall(textutils.unserializeJSON, msg)
                if ok and type(data) == "table" then
                    if data.type == "response" and data.reqId == reqId then
                        return data.success == true, data
                    end
                end
            end
        elseif event == "timer" and p1 == timerId then
            lastServerId = nil
            return false, { message = "Server timed out" }
        end
    end
end

function sync.requestOpen()
    return sync.request("open")
end

function sync.requestClose()
    return sync.request("close")
end

function sync.queryStatus()
    return sync.request("get_status")
end

function sync.createListenerWorker(onStateChange)
    return function()
        while true do
            if rednet.isOpen() then
                local sender, msg, msgProto = rednet.receive(protocol)
                if sender and msg and msgProto == protocol then
                    local ok, data = pcall(textutils.unserializeJSON, msg)
                    if ok and type(data) == "table" then
                        if data.type == "broadcast" or data.opened ~= nil then
                            if onStateChange then
                                onStateChange(data.opened, data.status or "")
                            end
                        end
                    end
                end
            else
                sleep(1)
            end
        end
    end
end

return sync
