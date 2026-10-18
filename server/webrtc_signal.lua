--- WebRTC signaling relay between panel and game clients via PN Base API.

RegisterNetEvent('pn-lib:server:signal', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    payload.fromSource = src
    CreateThread(function()
        if not PnLib.HttpJson then return end
        PnLib.HttpJson('POST', '/webrtc/signal', payload)
    end)
end)

--- Panel → game: deliver SDP/ICE to a player
RegisterNetEvent('pn-lib:internal:deliverSignal', function(_token, target, payload)
    -- only triggered from bridge poll responses
end)

AddEventHandler('pn-lib:server:panelActions', function(actions)
    if type(actions) ~= 'table' then return end
    for _, action in ipairs(actions) do
        if action.type == 'webrtc_signal' and action.source and action.payload then
            TriggerClientEvent('pn-lib:client:signal', action.source, action.payload)
        end
    end
end)
