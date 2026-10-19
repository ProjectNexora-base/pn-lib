---@param action table
local function runAction(action)
    local typ = action.type
    local src = tonumber(action.source)
    if not typ then return end

    if typ == 'kick' then
        if src then
            DropPlayer(src, action.reason or 'Kicked by PN Base')
        end
        return
    end

    if typ == 'ban' then
        if src then
            local reason = action.reason or 'Banned by PN Base'
            -- Prefer qbx/ox ban if available; always drop the player.
            if GetResourceState('qbx_core') == 'started' then
                pcall(function()
                    exports.qbx_core:ExploitBan(src, reason)
                end)
            end
            DropPlayer(src, reason)
        end
        return
    end

    if typ == 'message' then
        if src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'PN Base',
                description = action.message or '',
                type = 'inform',
            })
        end
        return
    end

    if typ == 'freeze' then
        if src then
            TriggerClientEvent('pn-lib:client:freeze', src, action.frozen == true)
        end
        return
    end

    if typ == 'teleport' and src and action.coords then
        TriggerClientEvent('pn-lib:client:teleport', src, action.coords)
        return
    end

    if typ == 'warn' and src then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Avertissement',
            description = action.message or 'Warning',
            type = 'warning',
        })
        return
    end
end

AddEventHandler('pn-lib:server:panelActions', function(actions)
    if type(actions) ~= 'table' then return end
    for _, action in ipairs(actions) do
        local ok, err = pcall(runAction, action)
        if not ok then
            print(('[pn-lib] action error: %s'):format(tostring(err)))
        end
    end
end)
