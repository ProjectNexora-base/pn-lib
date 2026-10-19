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
---@param inventory table[]|nil
local function logVersionCheck(versionCheck, inventory)
    if not versionCheck then return end

    local selfName = GetCurrentResourceName()
    local selfVersion = GetResourceMetadata(selfName, 'version', 0) or '?'

    local pn = versionCheck.pnLib
    if pn then
        local status = pn.ok and 'ok' or 'OUTDATED'
        print(('[pn-lib] self version: %s (installed=%s expected=%s) → %s'):format(
            selfName,
            tostring(pn.installed or selfVersion),
            tostring(pn.expected or '?'),
            status
        ))
    else
        print(('[pn-lib] self version: %s v%s'):format(selfName, selfVersion))
    end

    local outdatedMap = {}
    local outdated = versionCheck.outdated
    if type(outdated) == 'table' then
        for i = 1, #outdated do
            local r = outdated[i]
            if r and r.name then
                outdatedMap[r.name] = r
            end
        end
    end

    inventory = inventory or PnLib.GetResourceInventory()
    print(('[pn-lib] verified %d resource(s):'):format(#inventory))
    for i = 1, #inventory do
        local r = inventory[i]
        local bad = outdatedMap[r.name]
        local ver = r.version or '(no version)'
        if bad then
            print(('  ✗ %s: %s → expected %s'):format(
                tostring(r.name),
                tostring(bad.installed or ver),
                tostring(bad.expected or '?')
            ))
        else
            print(('  ✓ %s: v%s [%s]'):format(
                tostring(r.name),
                tostring(ver),
                tostring(r.state or '?')
            ))
        end
    end

    if type(outdated) == 'table' and #outdated > 0 then
        print(('[pn-lib] %d resource(s) outdated'):format(#outdated))
    elseif versionCheck.summary then
        print(('[pn-lib] %s'):format(tostring(versionCheck.summary)))
    end
end

local function heartbeat()
    local list = PnLib.GetPlayers()
    local inventory = PnLib.GetResourceInventory()
    local selfVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
    local configHash = PnLib.GetConfigHash and PnLib.GetConfigHash() or nil
    local configTableOk = PnLib.IsConfigTableOk and PnLib.IsConfigTableOk() or false
    local payload = {
        players = list,
        serverTime = os.time(),
        resourceVersion = selfVersion,
        resources = inventory,
        configHash = configHash,
        configTableOk = configTableOk,
    }
    -- Full config dump when dirty / first sync (panel mirrors)
    if PnLib.ConfigNeedsFullSync and PnLib.ConfigNeedsFullSync() and PnLib.GetAllConfigEntries then
        payload.configEntries = PnLib.GetAllConfigEntries()
    end
    local res = httpJson('POST', '/presence', payload)
    if not res.ok then
        lastError = res.error
        if GetConvarInt('pn_lib:debug', 0) == 1 then
            print(('[pn-lib] heartbeat failed: %s'):format(tostring(res.error)))
        end
        return
    end
    lastError = nil
    if PnLib.MarkConfigSynced and configHash then
        PnLib.MarkConfigSynced(configHash)
    end
    if res.body and res.body.actions then
        TriggerEvent('pn-lib:server:panelActions', res.body.actions)
    end
    if res.body and res.body.requestConfigFull and type(PnLib.ForceConfigResync) == 'function' then
        PnLib.ForceConfigResync()
    end

    local now = GetGameTimer()
    local forceLog = GetConvarInt('pn_lib:debug', 0) == 1
    if res.body and res.body.versionCheck then
        if forceLog or (now - lastVersionLogAt) >= VERSION_LOG_INTERVAL_MS then
            lastVersionLogAt = now
            logVersionCheck(res.body.versionCheck, inventory)
        end
    end
end

CreateThread(function()
    Wait(2000)
    local selfVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
    print(('[pn-lib] started v%s — verifying resource versions'):format(selfVersion))
    PnLib.PrintResourceInventory()
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
