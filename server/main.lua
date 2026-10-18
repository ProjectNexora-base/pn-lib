local players = {}

---@param src number
local function collectPlayer(src)
    local name = GetPlayerName(src) or ('player-%s'):format(src)
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        identifiers[#identifiers + 1] = GetPlayerIdentifier(src, i)
    end
    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, 'license') or nil
    local discord = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, 'discord') or nil

    local job, gang = nil, nil
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player and player.PlayerData then
            job = player.PlayerData.job and player.PlayerData.job.name or nil
            gang = player.PlayerData.gang and player.PlayerData.gang.name or nil
            name = player.PlayerData.charinfo
                and (('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or '')):gsub('^%s+', '')
                or name
        end
    end

    local ped = GetPlayerPed(src)
    local coords = nil
    if PnLib.Config.presenceIncludeCoords and ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        coords = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
    end

    return {
        source = src,
        name = name,
        license = license,
        discord = discord,
        identifiers = identifiers,
        job = job,
        gang = gang,
        ping = GetPlayerPing(src),
        coords = coords,
        updatedAt = os.time(),
    }
end

function PnLib.GetPlayers()
    local list = {}
    for src in pairs(players) do
        list[#list + 1] = collectPlayer(src)
    end
    return list
end

function PnLib.RefreshPlayer(src)
    if not src or src <= 0 then return end
    players[src] = true
end

AddEventHandler('playerJoining', function()
    local src = source
    players[src] = true
end)

AddEventHandler('playerDropped', function()
    local src = source
    players[src] = nil
    TriggerEvent('pn-lib:server:playerLeft', src)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        players[tonumber(id)] = true
    end
end)

exports('GetPlayers', PnLib.GetPlayers)
exports('RefreshPlayer', PnLib.RefreshPlayer)
