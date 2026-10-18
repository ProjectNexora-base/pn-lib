PnLib = PnLib or {}

PnLib.Config = {
    apiUrl = GetConvar('pn_lib:apiUrl', ''),
    --- Server-only secret; empty on client.
    serverToken = '',
    iceServersJson = GetConvar('pn_lib:iceServers', '[{"urls":"stun:stun.l.google.com:19302"}]'),
    heartbeatMs = 5000,
    presenceIncludeCoords = true,
}

if IsDuplicityVersion() then
    PnLib.Config.serverToken = GetConvar('pn_lib:serverToken', '')
end

