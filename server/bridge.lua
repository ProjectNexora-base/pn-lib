local lastError = nil
local lastVersionLogAt = 0
local VERSION_LOG_INTERVAL_MS = 5 * 60 * 1000

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

---@param versionCheck table|nil
local function logVersionCheck(versionCheck)
    if not versionCheck then return end

    local pn = versionCheck.pnLib
    if pn then
        local status = pn.ok and 'ok' or 'outdated'
        print(('[pn-lib] version check: %s (installed=%s expected=%s)'):format(
            status,
            tostring(pn.installed or '?'),
            tostring(pn.expected or '?')
        ))
    end

    local outdated = versionCheck.outdated
    if type(outdated) == 'table' and #outdated > 0 then
        print(('[pn-lib] %d resource(s) outdated:'):format(#outdated))
        for i = 1, math.min(#outdated, 25) do
            local r = outdated[i]
            print(('  - %s: %s → %s'):format(
                tostring(r.name),
                tostring(r.installed or '?'),
                tostring(r.expected or '?')
            ))
        end
        if #outdated > 25 then
            print(('  … +%d more'):format(#outdated - 25))
        end
    elseif versionCheck.summary then
        print(('[pn-lib] %s'):format(tostring(versionCheck.summary)))
    end
end

local function heartbeat()
    local list = PnLib.GetPlayers()
    local inventory = PnLib.GetResourceInventory()
    local res = httpJson('POST', '/presence', {
        players = list,
        serverTime = os.time(),
        resourceVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0',
        resources = inventory,
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

    local now = GetGameTimer()
    local forceLog = GetConvarInt('pn_lib:debug', 0) == 1
    if res.body and res.body.versionCheck then
        if forceLog or (now - lastVersionLogAt) >= VERSION_LOG_INTERVAL_MS then
            lastVersionLogAt = now
            logVersionCheck(res.body.versionCheck)
        end
    end
end

CreateThread(function()
    Wait(2000)
    print(('[pn-lib] started v%s — resource inventory enabled'):format(
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
    ))
    while true do
        if PnLib.Config.apiUrl ~= '' and PnLib.Config.serverToken ~= '' then
            local ok, err = pcall(heartbeat)
            if not ok then
                lastError = err
            end
        else
            if GetConvarInt('pn_lib:debug', 0) == 1 then
                print('[pn-lib] waiting for pn_lib:apiUrl / pn_lib:serverToken')
            end
        end
        Wait(PnLib.Config.heartbeatMs)
    end
end)

exports('BridgeLastError', function()
    return lastError
end)

PnLib.HttpJson = httpJson
