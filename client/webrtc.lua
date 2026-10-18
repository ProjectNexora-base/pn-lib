--- Client WebRTC helper (NUI). Signaling goes server → panel API.

RegisterNetEvent('pn-lib:client:signal', function(payload)
    SendNUIMessage({
        action = 'webrtc:signal',
        payload = payload,
    })
end)

RegisterNUICallback('webrtc:localSignal', function(data, cb)
    TriggerServerEvent('pn-lib:server:signal', data)
    cb({ ok = true })
end)

RegisterNUICallback('webrtc:ready', function(_data, cb)
    local ice = {}
    local ok, parsed = pcall(json.decode, PnLib.Config.iceServersJson)
    if ok and type(parsed) == 'table' then ice = parsed end
    cb({ iceServers = ice })
end)
