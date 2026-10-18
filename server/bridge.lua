local lastError = nil

local function httpJson(method, path, body)
    local base = PnLib.Config.apiUrl
    local token = PnLib.Config.serverToken
    if base == '' or token == '' then
        return false, 'pn_lib:apiUrl or pn_lib:serverToken missing'
    end

    local url = base:gsub('/$', '') .. path
    local payload = body and json.encode(body) or nil
    local p = promise.new()

    PerformHttpRequest(url, function(status, data, _headers, errorData)
        if status >= 200 and status < 300 then
            local decoded = nil
            if data and data ~= '' then
                local ok, parsed = pcall(json.decode, data)
                if ok then decoded = parsed end
            end
            p:resolve({ ok = true, status = status, body = decoded })
        else
            p:resolve({
                ok = false,
                status = status,
                error = errorData or data or ('HTTP ' .. tostring(status)),
            })
        end
    end, method, payload, {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. token,
        ['X-PN-Lib'] = '1',
    })

    return Citizen.Await(p)
end

local function heartbeat()
    local list = PnLib.GetPlayers()
    local res = httpJson('POST', '/presence', {
        players = list,
        serverTime = os.time(),
        resourceVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0',
    })
    if not res.ok then
        lastError = res.error
        if GetConvarInt('pn_lib:debug', 0) == 1 then
            print(('[pn-lib] heartbeat failed: %s'):format(tostring(res.error)))
        end
        return
    end
    lastError = nil
    if res.body and res.body.actions then
        TriggerEvent('pn-lib:server:panelActions', res.body.actions)
    end
end

CreateThread(function()
    Wait(2000)
    while true do
        if PnLib.Config.apiUrl ~= '' and PnLib.Config.serverToken ~= '' then
            local ok, err = pcall(heartbeat)
            if not ok then
                lastError = err
            end
        end
        Wait(PnLib.Config.heartbeatMs)
    end
end)

exports('BridgeLastError', function()
    return lastError
end)

PnLib.HttpJson = httpJson
