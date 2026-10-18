--- Collect runtime resource inventory for the PN Base panel.

---@return table[]
function PnLib.GetResourceInventory()
    local list = {}
    local n = GetNumResources()
    for i = 0, n - 1 do
        local name = GetResourceByFindIndex(i)
        if name and name ~= '' then
            local version = GetResourceMetadata(name, 'version', 0)
            if not version or version == '' then
                version = nil
            end
            list[#list + 1] = {
                name = name,
                version = version,
                state = GetResourceState(name),
            }
        end
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

--- Print every resource version to the FXServer console (includes pn-lib itself).
---@param inventory table[]|nil
function PnLib.PrintResourceInventory(inventory)
    inventory = inventory or PnLib.GetResourceInventory()
    local selfName = GetCurrentResourceName()
    local selfVersion = GetResourceMetadata(selfName, 'version', 0) or '?'

    print(('[pn-lib] === resource inventory (%d) ==='):format(#inventory))
    print(('[pn-lib] self: %s v%s (state=%s)'):format(
        selfName,
        selfVersion,
        GetResourceState(selfName)
    ))

    for i = 1, #inventory do
        local r = inventory[i]
        local ver = r.version or '(no version)'
        local mark = r.name == selfName and ' ◀' or ''
        print(('  [%s] %s  v%s%s'):format(
            tostring(r.state or '?'),
            tostring(r.name),
            tostring(ver),
            mark
        ))
    end
    print('[pn-lib] === end inventory ===')
end

exports('GetResourceInventory', PnLib.GetResourceInventory)
exports('PrintResourceInventory', PnLib.PrintResourceInventory)
