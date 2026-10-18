local frozen = false

RegisterNetEvent('pn-lib:client:freeze', function(state)
    frozen = state == true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, frozen)
end)

RegisterNetEvent('pn-lib:client:teleport', function(coords)
    if type(coords) ~= 'table' then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
end)

CreateThread(function()
    while true do
        if frozen then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
