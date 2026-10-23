---@diagnostic disable: undefined-global
PnLib = PnLib or {}

local SENSITIVE_KEYS = {
    ['pn_lib:serverToken'] = true,
    ['serverToken'] = true,
}

local cache = {} ---@type table<string, table>
local schemas = {} ---@type table<string, table>
local changeHandlers = {} ---@type table<string, function[]>
local tableOk = false
local dirtySinceSync = false
local lastPushedHash = nil

local function cacheKey(namespace, key)
    return ('%s\0%s'):format(namespace, key)
end

local function isSensitive(namespace, key, convar)
    local full = convar or (('%s:%s'):format(namespace, key))
    return SENSITIVE_KEYS[full] == true or SENSITIVE_KEYS[key] == true
end

local function displayValue(entry)
    if isSensitive(entry.namespace, entry.key, entry.convar) then
        return '***'
    end
    return tostring(entry.value)
end

local function coerceValue(value, valueType)
    if valueType == 'number' then
        return tonumber(value) or 0
    end
    if valueType == 'boolean' then
        if value == true or value == 'true' or value == '1' or value == 1 then
            return true
        end
        return false
    end
    if valueType == 'json' then
        if type(value) == 'table' then
            return value
        end
        local ok, parsed = pcall(json.decode, tostring(value))
        if ok then return parsed end
        return value
    end
    return tostring(value == nil and '' or value)
end

local function serializeValue(value, valueType)
    if valueType == 'json' then
        if type(value) == 'string' then return value end
        return json.encode(value)
    end
    if valueType == 'boolean' then
        local b = coerceValue(value, 'boolean')
        return b and 'true' or 'false'
    end
    return tostring(value == nil and '' or value)
end

local function entryToPayload(entry)
    return {
        namespace = entry.namespace,
        key = entry.key,
        value = entry.value,
        valueType = entry.valueType,
        label = entry.label,
        description = entry.description,
        requiresRestart = entry.requiresRestart and true or false,
        convar = entry.convar,
        updatedBy = entry.updatedBy,
        updatedAt = entry.updatedAt,
    }
end

local function computeHash()
    local parts = {}
    for _, entry in pairs(cache) do
        parts[#parts + 1] = ('%s.%s=%s'):format(entry.namespace, entry.key, entry.value)
    end
    table.sort(parts)
    return tostring(#parts) .. ':' .. table.concat(parts, '|')
end

local function fireChange(namespace, key, entry, oldValue)
    local wild = changeHandlers[namespace .. ':*']
    if wild then
        for i = 1, #wild do
            pcall(wild[i], key, entry and coerceValue(entry.value, entry.valueType) or nil, oldValue)
        end
    end
    local specific = changeHandlers[namespace .. ':' .. key]
    if specific then
        for i = 1, #specific do
            pcall(specific[i], coerceValue(entry.value, entry.valueType), oldValue)
        end
    end
    TriggerEvent('pn-lib:configChanged', namespace, key, entry and entryToPayload(entry) or nil, oldValue)
end

--- Convars that must never be replicated to clients nor written from the panel.
local SENSITIVE_CONVAR_PATTERNS = { 'token', 'secret', 'password', 'passwd', 'license', 'apikey', 'api_key', 'connection_string', 'rcon' }

--- A convar is only applied when it is namespaced like its entry (`<namespace>:<name>`).
--- This keeps core FXServer convars (sv_*, rcon_password, mysql_connection_string, ...) out of reach
--- of panel-provided metadata.
---@param entry table
---@return boolean
local function isConvarAllowed(entry)
    local convar = entry.convar
    if type(convar) ~= 'string' or convar == '' then return false end
    local prefix, name = convar:match('^([%w_%-]+):([%w_%-%.]+)$')
    if not prefix or prefix ~= entry.namespace then return false end
    local lowered = name:lower()
    for i = 1, #SENSITIVE_CONVAR_PATTERNS do
        if lowered:find(SENSITIVE_CONVAR_PATTERNS[i], 1, true) then return false end
    end
    return true
end

local function applyConvar(entry)
    if not entry or not entry.convar or entry.convar == '' then return end
    if entry.requiresRestart then return end
    local val = entry.value
    -- pn_lib:serverToken is server-only: never replicated, always accepted from config.cfg only.
    if entry.convar == 'pn_lib:serverToken' then
        return
    end
    if not isConvarAllowed(entry) then
        if GetConvarInt('pn_lib:debug', 0) == 1 then
            print(('[pn-lib] convar %s refused for %s.%s'):format(tostring(entry.convar), tostring(entry.namespace), tostring(entry.key)))
        end
        return
    end
    SetConvarReplicated(entry.convar, val)
    SetConvar(entry.convar, val)
end

---@param def table
local function upsertMemory(def, fromDb)
    local ns = def.namespace
    local key = def.key
    local ck = cacheKey(ns, key)
    local existing = cache[ck]
    local oldValue = existing and coerceValue(existing.value, existing.valueType) or nil

    local entry = {
        namespace = ns,
        key = key,
        value = serializeValue(def.value, def.valueType or 'string'),
        valueType = def.valueType or 'string',
        label = def.label or (existing and existing.label) or key,
        description = def.description or (existing and existing.description) or nil,
        requiresRestart = def.requiresRestart == true or def.requires_restart == true,
        convar = def.convar or (existing and existing.convar) or nil,
        updatedBy = def.updatedBy or def.updated_by or 'seed',
        updatedAt = def.updatedAt or os.time(),
    }

    if fromDb and existing then
        -- Prefer DB value; keep richer schema metadata if present
        if schemas[ns] and schemas[ns][key] then
            local sch = schemas[ns][key]
            entry.label = entry.label or sch.label
            entry.description = entry.description or sch.description
            if sch.requiresRestart ~= nil then entry.requiresRestart = sch.requiresRestart end
            entry.convar = entry.convar or sch.convar
            entry.valueType = sch.valueType or entry.valueType
        end
    end

    cache[ck] = entry
    dirtySinceSync = true
    applyConvar(entry)
    if existing then
        fireChange(ns, key, entry, oldValue)
    end
    return entry
end

local function persistEntry(entry)
    if not tableOk then return false end
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO pn_config
              (namespace, `key`, value, value_type, label, description, requires_restart, convar, updated_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              value = VALUES(value),
              value_type = VALUES(value_type),
              label = VALUES(label),
              description = VALUES(description),
              requires_restart = VALUES(requires_restart),
              convar = VALUES(convar),
              updated_by = VALUES(updated_by)
        ]], {
            entry.namespace,
            entry.key,
            entry.value,
            entry.valueType,
            entry.label,
            entry.description,
            entry.requiresRestart and 1 or 0,
            entry.convar,
            entry.updatedBy,
        })
    end)
    if not ok then
        print(('[pn-lib] config persist failed: %s'):format(tostring(err)))
        return false
    end
    return true
end

local function deleteMemory(namespace, key)
    local ck = cacheKey(namespace, key)
    local existing = cache[ck]
    if not existing then return end
    local oldValue = coerceValue(existing.value, existing.valueType)
    cache[ck] = nil
    dirtySinceSync = true
    fireChange(namespace, key, nil, oldValue)
end

local function deletePersist(namespace, key)
    if not tableOk then return false end
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM pn_config WHERE namespace = ? AND `key` = ?', { namespace, key })
    end)
    if not ok then
        print(('[pn-lib] config delete failed: %s'):format(tostring(err)))
        return false
    end
    return true
end

--- Built-in seed definitions from config.cfg personalization convars.
local function seedDefaults()
    local defs = {
        { namespace = 'pn', key = 'serverName', convar = 'pn:serverName', label = 'Nom du serveur', valueType = 'string' },
        { namespace = 'qbx', key = 'discordLink', convar = 'qbx:discordLink', label = 'Lien Discord', valueType = 'string' },
        { namespace = 'qbx', key = 'motd', convar = 'qbx:motd', label = 'Message du jour', valueType = 'string' },
        { namespace = 'ox', key = 'primaryColor', convar = 'ox:primaryColor', label = 'Couleur primaire ox', valueType = 'string', requiresRestart = true },
        { namespace = 'ox', key = 'primaryShade', convar = 'ox:primaryShade', label = 'Nuance primaire ox', valueType = 'number', requiresRestart = true },
        { namespace = 'inventory', key = 'slots', convar = 'inventory:slots', label = 'Slots inventaire', valueType = 'number', requiresRestart = true },
        { namespace = 'inventory', key = 'weight', convar = 'inventory:weight', label = 'Poids inventaire', valueType = 'number', requiresRestart = true },
        { namespace = 'pn', key = 'currency', convar = 'pn:currency', label = 'Devise', valueType = 'string' },
        { namespace = 'pn', key = 'startingCash', convar = 'pn:startingCash', label = 'Cash de départ', valueType = 'number', requiresRestart = true },
        { namespace = 'pn', key = 'startingBank', convar = 'pn:startingBank', label = 'Banque de départ', valueType = 'number', requiresRestart = true },
        { namespace = 'pn_lib', key = 'apiUrl', convar = 'pn_lib:apiUrl', label = 'URL bridge panel', valueType = 'string', requiresRestart = true },
        { namespace = 'pn_lib', key = 'iceServers', convar = 'pn_lib:iceServers', label = 'ICE servers WebRTC', valueType = 'json' },
        { namespace = 'pn_lib', key = 'debug', convar = 'pn_lib:debug', label = 'Debug pn-lib', valueType = 'number' },
        { namespace = 'loadscreen', key = 'primaryColor', convar = 'loadscreen:primaryColor', label = 'Loadscreen primaire', valueType = 'string', requiresRestart = true },
        { namespace = 'loadscreen', key = 'shadowColor', convar = 'loadscreen:shadowColor', label = 'Loadscreen ombre', valueType = 'string', requiresRestart = true },
        { namespace = 'loadscreen', key = 'textColor', convar = 'loadscreen:textColor', label = 'Loadscreen texte', valueType = 'string', requiresRestart = true },
        { namespace = 'qbx_chat', key = 'mainColor', convar = 'qbx_chat:mainColor', label = 'Chat couleur principale', valueType = 'string', requiresRestart = true },
        { namespace = 'qbx_chat', key = 'borderColor', convar = 'qbx_chat:borderColor', label = 'Chat bordure', valueType = 'string', requiresRestart = true },
        { namespace = 'qbx_chat', key = 'textColor', convar = 'qbx_chat:textColor', label = 'Chat texte', valueType = 'string', requiresRestart = true },
        { namespace = 'qbx_chat', key = 'faintColor', convar = 'qbx_chat:faintColor', label = 'Chat secondaire', valueType = 'string', requiresRestart = true },
    }

    for i = 1, #defs do
        local d = defs[i]
        local ck = cacheKey(d.namespace, d.key)
        if not cache[ck] then
            local raw = d.convar and GetConvar(d.convar, '') or ''
            local entry = upsertMemory({
                namespace = d.namespace,
                key = d.key,
                value = raw,
                valueType = d.valueType,
                label = d.label,
                requiresRestart = d.requiresRestart,
                convar = d.convar,
                updatedBy = 'seed',
            }, false)
            persistEntry(entry)
        end
        schemas[d.namespace] = schemas[d.namespace] or {}
        schemas[d.namespace][d.key] = d
    end
end

local function loadFromDb()
    local rows = MySQL.query.await('SELECT * FROM pn_config') or {}
    for i = 1, #rows do
        local r = rows[i]
        upsertMemory({
            namespace = r.namespace,
            key = r.key,
            value = r.value,
            valueType = r.value_type,
            label = r.label,
            description = r.description,
            requiresRestart = r.requires_restart == 1 or r.requires_restart == true,
            convar = r.convar,
            updatedBy = r.updated_by,
        }, true)
    end
end

local function ensureTable()
    local sqlPath = GetResourcePath(GetCurrentResourceName()) .. '/sql/pn_config.sql'
    local raw = LoadResourceFile(GetCurrentResourceName(), 'sql/pn_config.sql')
    if not raw or raw == '' then
        print(('[pn-lib] missing sql/pn_config.sql (path=%s)'):format(sqlPath))
        return false
    end
    -- Strip comments / split on semicolon — single statement DDL
    for statement in raw:gmatch('([^;]+);') do
        local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' and not trimmed:match('^%-%-') then
            local ok, err = pcall(function()
                MySQL.query.await(trimmed)
            end)
            if not ok then
                print(('[pn-lib] pn_config DDL failed: %s'):format(tostring(err)))
                return false
            end
        end
    end
    return true
end

function PnLib.GetConfig(namespace, key)
    local entry = cache[cacheKey(namespace, key)]
    if not entry then return nil end
    return coerceValue(entry.value, entry.valueType)
end

function PnLib.GetConfigEntry(namespace, key)
    local entry = cache[cacheKey(namespace, key)]
    if not entry then return nil end
    return entryToPayload(entry)
end

function PnLib.GetConfigNamespace(namespace)
    local out = {}
    for _, entry in pairs(cache) do
        if entry.namespace == namespace then
            out[entry.key] = coerceValue(entry.value, entry.valueType)
        end
    end
    return out
end

function PnLib.GetAllConfigEntries()
    local out = {}
    for _, entry in pairs(cache) do
        out[#out + 1] = entryToPayload(entry)
    end
    table.sort(out, function(a, b)
        if a.namespace == b.namespace then return a.key < b.key end
        return a.namespace < b.namespace
    end)
    return out
end

function PnLib.GetConfigHash()
    return computeHash()
end

function PnLib.IsConfigTableOk()
    return tableOk
end

function PnLib.ConfigNeedsFullSync()
    return dirtySinceSync or lastPushedHash == nil
end

function PnLib.MarkConfigSynced(hash)
    lastPushedHash = hash or computeHash()
    dirtySinceSync = false
end

function PnLib.ForceConfigResync()
    lastPushedHash = nil
    dirtySinceSync = true
end

---@param namespace string
---@param key string
---@param value any
---@param updatedBy string|nil
---@return boolean, string|nil
function PnLib.SetConfig(namespace, key, value, updatedBy)
    if type(namespace) ~= 'string' or type(key) ~= 'string' then
        return false, 'invalid namespace/key'
    end
    local existing = cache[cacheKey(namespace, key)]
    local sch = schemas[namespace] and schemas[namespace][key]
    local valueType = (existing and existing.valueType) or (sch and sch.valueType) or 'string'
    local entry = upsertMemory({
        namespace = namespace,
        key = key,
        value = value,
        valueType = valueType,
        label = (existing and existing.label) or (sch and sch.label) or key,
        description = (existing and existing.description) or (sch and sch.description),
        requiresRestart = (existing and existing.requiresRestart) or (sch and sch.requiresRestart) or false,
        convar = (existing and existing.convar) or (sch and sch.convar),
        updatedBy = updatedBy or 'export',
    }, false)
    persistEntry(entry)
    if entry.requiresRestart then
        print(('[pn-lib] config %s.%s updated — resource restart may be required (no auto-restart)'):format(namespace, key))
    end
    return true, entry.requiresRestart and 'requires_restart' or nil
end

function PnLib.DeleteConfig(namespace, key)
    deletePersist(namespace, key)
    deleteMemory(namespace, key)
    return true
end

---@param namespace string
---@param schema table[]|table
function PnLib.RegisterConfig(namespace, schema)
    if type(namespace) ~= 'string' or namespace == '' then
        error('RegisterConfig: namespace required', 2)
    end
    schemas[namespace] = schemas[namespace] or {}
    local list = schema
    if type(schema) == 'table' and schema.key then
        list = { schema }
    end
    if type(list) ~= 'table' then
        error('RegisterConfig: schema must be a table', 2)
    end
    for i = 1, #list do
        local def = list[i]
        if type(def) == 'table' and def.key then
            local key = def.key
            schemas[namespace][key] = {
                namespace = namespace,
                key = key,
                label = def.label or key,
                description = def.description,
                valueType = def.valueType or def.type or 'string',
                requiresRestart = def.requiresRestart == true,
                convar = def.convar,
                default = def.default,
            }
            local ck = cacheKey(namespace, key)
            if not cache[ck] then
                local raw = def.default
                if raw == nil and def.convar then
                    raw = GetConvar(def.convar, '')
                end
                local entry = upsertMemory({
                    namespace = namespace,
                    key = key,
                    value = raw == nil and '' or raw,
                    valueType = schemas[namespace][key].valueType,
                    label = schemas[namespace][key].label,
                    description = schemas[namespace][key].description,
                    requiresRestart = schemas[namespace][key].requiresRestart,
                    convar = schemas[namespace][key].convar,
                    updatedBy = 'seed',
                }, false)
                persistEntry(entry)
            else
                -- Enrich metadata without overwriting value
                local e = cache[ck]
                e.label = schemas[namespace][key].label or e.label
                e.description = schemas[namespace][key].description or e.description
                e.requiresRestart = schemas[namespace][key].requiresRestart
                e.convar = schemas[namespace][key].convar or e.convar
                e.valueType = schemas[namespace][key].valueType or e.valueType
            end
        end
    end
end

---@param namespace string
---@param keyOrStar string
---@param handler function
function PnLib.OnConfigChange(namespace, keyOrStar, handler)
    if type(handler) ~= 'function' then return end
    local id = namespace .. ':' .. (keyOrStar or '*')
    changeHandlers[id] = changeHandlers[id] or {}
    changeHandlers[id][#changeHandlers[id] + 1] = handler
end

function PnLib.PrintConfig(namespace)
    local entries = PnLib.GetAllConfigEntries()
    local count = 0
    print('[pn-lib] === configuration ===')
    for i = 1, #entries do
        local e = entries[i]
        if not namespace or e.namespace == namespace then
            count = count + 1
            local restart = e.requiresRestart and ' [restart required]' or ''
            print(('  %s.%s = %s (%s)%s'):format(
                e.namespace,
                e.key,
                displayValue(e),
                e.valueType,
                restart
            ))
        end
    end
    print(('[pn-lib] %d config key(s)%s'):format(
        count,
        tableOk and '' or ' — table unavailable'
    ))
end

---@param entries table[]
function PnLib.RestoreConfigFromPanel(entries)
    if type(entries) ~= 'table' then return false end
    for i = 1, #entries do
        local e = entries[i]
        if e and e.namespace and e.key then
            PnLib.SetConfig(e.namespace, e.key, e.value, 'panel')
            -- Also refresh metadata from panel payload
            local ck = cacheKey(e.namespace, e.key)
            local mem = cache[ck]
            if mem then
                if e.label then mem.label = e.label end
                if e.description then mem.description = e.description end
                if e.requiresRestart ~= nil then mem.requiresRestart = e.requiresRestart end
                if e.convar then mem.convar = e.convar end
                if e.valueType then mem.valueType = e.valueType end
                persistEntry(mem)
            end
        end
    end
    return true
end

function PnLib.ApplyPanelConfigSet(payload)
    if type(payload) ~= 'table' then return end
    local ns = payload.namespace
    local key = payload.key
    if not ns or not key then return end
    PnLib.SetConfig(ns, key, payload.value, 'panel')
    local ck = cacheKey(ns, key)
    local mem = cache[ck]
    if mem then
        if payload.label then mem.label = payload.label end
        if payload.description ~= nil then mem.description = payload.description end
        if payload.requiresRestart ~= nil then mem.requiresRestart = payload.requiresRestart end
        if payload.convar ~= nil then mem.convar = payload.convar end
        if payload.valueType then mem.valueType = payload.valueType end
        persistEntry(mem)
    end
end

CreateThread(function()
    local waited = 0
    while GetResourceState('oxmysql') ~= 'started' and waited < 60000 do
        Wait(500)
        waited = waited + 500
    end
    if GetResourceState('oxmysql') ~= 'started' then
        print('[pn-lib] oxmysql not started — config store disabled')
        PnLib.PrintConfig()
        return
    end

    do
        local p = promise.new()
        MySQL.ready(function()
            p:resolve(true)
        end)
        Citizen.Await(p)
    end
    tableOk = ensureTable()
    if tableOk then
        loadFromDb()
        seedDefaults()
        print(('[pn-lib] config store ready (%d keys)'):format(#PnLib.GetAllConfigEntries()))
    else
        print('[pn-lib] config table init failed — using in-memory seeds only')
        seedDefaults()
    end
    PnLib.PrintConfig()
end)

exports('RegisterConfig', PnLib.RegisterConfig)
exports('GetConfig', PnLib.GetConfig)
exports('GetConfigEntry', PnLib.GetConfigEntry)
exports('GetConfigNamespace', PnLib.GetConfigNamespace)
exports('GetAllConfigEntries', PnLib.GetAllConfigEntries)
exports('SetConfig', PnLib.SetConfig)
exports('DeleteConfig', PnLib.DeleteConfig)
exports('OnConfigChange', PnLib.OnConfigChange)
exports('PrintConfig', PnLib.PrintConfig)
exports('GetConfigHash', PnLib.GetConfigHash)
exports('IsConfigTableOk', PnLib.IsConfigTableOk)
