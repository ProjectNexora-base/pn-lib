---@diagnostic disable: undefined-global

local function isConfigAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'command.configpn') then
        return true
    end
    -- Fallback: qbx admin / god
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player and player.PlayerData and player.PlayerData.metadata then
            local meta = player.PlayerData.metadata
            if meta.isadmin or meta.isgod or meta.admin then
                return true
            end
        end
        local ok2, hasPerm = pcall(function()
            return exports.qbx_core:HasPermission(src, 'admin')
        end)
        if ok2 and hasPerm then return true end
    end
    return false
end

local function openConfig(src)
    if not isConfigAdmin(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'pn-lib',
            description = 'Permission refusée (ACE command.configpn)',
            type = 'error',
        })
        return
    end
    TriggerClientEvent('pn-lib:client:openConfig', src, {
        entries = PnLib.GetAllConfigEntries(),
        tableOk = PnLib.IsConfigTableOk(),
        hash = PnLib.GetConfigHash(),
    })
end

RegisterCommand('configpn', function(src)
    if src == 0 then
        PnLib.PrintConfig()
        return
    end
    openConfig(src)
end, false)

-- Restrict via ACE: players without ace still hit our check above.
-- Document: add_ace group.admin command.configpn allow

lib.callback.register('pn-lib:config:list', function(source)
    if not isConfigAdmin(source) then return nil end
    return {
        entries = PnLib.GetAllConfigEntries(),
        tableOk = PnLib.IsConfigTableOk(),
        hash = PnLib.GetConfigHash(),
    }
end)

lib.callback.register('pn-lib:config:set', function(source, payload)
    if not isConfigAdmin(source) then
        return { ok = false, error = 'forbidden' }
    end
    if type(payload) ~= 'table' or not payload.namespace or not payload.key then
        return { ok = false, error = 'invalid_payload' }
    end
    local ok, flag = PnLib.SetConfig(payload.namespace, payload.key, payload.value, 'game')
    return {
        ok = ok,
        error = (not ok) and tostring(flag) or nil,
        requiresRestart = ok and flag == 'requires_restart',
        entries = PnLib.GetAllConfigEntries(),
        hash = PnLib.GetConfigHash(),
    }
end)

RegisterNetEvent('pn-lib:server:configClose', function()
    -- no-op; client closes NUI
end)
