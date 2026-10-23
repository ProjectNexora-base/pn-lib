# pn-lib

PN Base first-party FiveM resource: player presence heartbeat, **live configuration store**, panel admin actions, WebRTC signaling bridge.

On start it creates/loads MySQL `pn_config`, seeds known convars, prints the config registry and every resource version. Heartbeats sync inventory + config to the panel (~5s). **Never auto-restarts resources.**

## Version

`1.4.0`

## Convars (`config.cfg`)

| Convar | Purpose |
|--------|---------|
| `pn_lib:apiUrl` | Base URL, e.g. `https://panel.example/api/bridge` |
| `pn_lib:serverToken` | Bearer token (written at install) |
| `pn_lib:iceServers` | JSON ICE servers for WebRTC |
| `pn_lib:debug` | `1` = log heartbeats + force version dump each cycle |

## Configuration

- **Game DB**: table `pn_config` (see `sql/pn_config.sql`), created on resource start via oxmysql
- **Panel mirror**: Postgres `server_config_entries` — restore from panel if game table is missing
- **In-game UI**: `/configpn` (ACE `command.configpn`)
- **Panel UI**: Project → Configuration

```
add_ace group.admin command.configpn allow
```

### Convar safety

A config entry only mirrors to a convar when the convar is named `<namespace>:<name>` with the **same namespace** as the entry, and the name does not look like a secret (`token`, `secret`, `password`, `license`, `apikey`, `rcon`, `connection_string`). Core FXServer convars (`sv_*`, `rcon_password`, `mysql_connection_string`, ...) can therefore never be written from the panel, and `pn_lib:serverToken` is only ever read from `config.cfg`. Refusals are logged with `pn_lib:debug 1`.

### Declaring settings from a resource

```lua
exports['pn-lib']:RegisterConfig('my_resource', {
    { key = 'price', label = 'Prix', valueType = 'number', default = 250, min = 0, max = 100000 },
    { key = 'enabled', label = 'Activé', valueType = 'boolean', default = true },
    { key = 'mode', label = 'Mode', valueType = 'string', default = 'easy', options = { 'easy', 'hard' } },
})
```

`min`, `max` and `options` are enforced on every write (panel, `/configpn`, `SetConfig`); a refused write returns `false, reason` and the panel mirror is resynced. A key declared by a resource keeps its type: the panel cannot change it.

### Lua exports (config)

```lua
exports['pn-lib']:RegisterConfig(namespace, schema)
exports['pn-lib']:GetConfig(namespace, key)
exports['pn-lib']:GetConfigEntry(namespace, key)
exports['pn-lib']:GetConfigNamespace(namespace)
exports['pn-lib']:GetAllConfigEntries()
exports['pn-lib']:SetConfig(namespace, key, value)
exports['pn-lib']:DeleteConfig(namespace, key)
exports['pn-lib']:OnConfigChange(namespace, keyOrStar, handler)
exports['pn-lib']:PrintConfig(namespace?)
exports['pn-lib']:GetConfigHash()
exports['pn-lib']:IsConfigTableOk()
```

See also `/pn-lib-exports.md` written at the Ptero server root on install.

### Other exports

```lua
exports['pn-lib']:GetPlayers()
exports['pn-lib']:RefreshPlayer(source)
exports['pn-lib']:GetResourceInventory()
exports['pn-lib']:PrintResourceInventory()
exports['pn-lib']:BridgeLastError()
```

## Bundle

Included automatically by `scripts/build-qbox-resources-bundle.mjs` into `resources/[standalone]/pn-lib`.
