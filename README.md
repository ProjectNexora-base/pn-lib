# pn-lib

PN Base first-party FiveM resource: player presence heartbeat, panel admin actions, WebRTC signaling bridge.

## Convars (`config.cfg`)

| Convar | Purpose |
|--------|---------|
| `pn_lib:apiUrl` | Base URL, e.g. `https://panel.example/api/bridge` |
| `pn_lib:serverToken` | Bearer token (written at install) |
| `pn_lib:iceServers` | JSON ICE servers for WebRTC |

## Bundle

Included automatically by `scripts/build-qbox-resources-bundle.mjs` into `resources/[standalone]/pn-lib`.
