---@diagnostic disable: undefined-global

local open = false

local function setFocus(state)
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

RegisterNetEvent('pn-lib:client:openConfig', function(payload)
    setFocus(true)
    SendNUIMessage({
        action = 'config:open',
        payload = payload or {},
    })
end)

RegisterNUICallback('config:close', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('config:list', function(_, cb)
    local data = lib.callback.await('pn-lib:config:list', false)
    cb(data or { entries = {}, tableOk = false })
end)

RegisterNUICallback('config:set', function(data, cb)
    local result = lib.callback.await('pn-lib:config:set', false, data)
    cb(result or { ok = false, error = 'no_response' })
end)

RegisterCommand('configpn_close', function()
    if open then
        setFocus(false)
        SendNUIMessage({ action = 'config:close' })
    end
end, false)

RegisterKeyMapping('configpn_close', 'Close PN config panel', 'keyboard', 'ESCAPE')
