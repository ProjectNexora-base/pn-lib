# pn-lib

PN Base first-party FiveM resource: player presence heartbeat, panel admin actions, WebRTC signaling bridge.

On start it prints every resource version on the server (including its own). Heartbeats send the inventory to the panel and periodically print a verified OK/outdated list.

## Convars (`config.cfg`)

| Convar | Purpose |
|--------|---------|
| `pn_lib:apiUrl` | Base URL, e.g. `https://panel.example/api/bridge` |
| `pn_lib:serverToken` | Bearer token (written at install) |
| `pn_lib:iceServers` | JSON ICE servers for WebRTC |
| `pn_lib:debug` | `1` = log heartbeats + force version dump each cycle |

## Bundle

Included automatically by `scripts/build-qbox-resources-bundle.mjs` into `resources/[standalone]/pn-lib`.
