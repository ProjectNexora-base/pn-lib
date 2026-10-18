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

exports('GetResourceInventory', PnLib.GetResourceInventory)
