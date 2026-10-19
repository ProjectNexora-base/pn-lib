# Agent instructions — FiveM resource (PN Base mirror)

## Version bump (required)

**Every commit that changes this resource MUST bump the resource version.**

1. Edit `fxmanifest.lua` and increase `version 'x.y.z'` (semver preferred; at least change the string).
2. Do not push `main` with an unchanged version — CI **version-gate** will fail.
3. Prefer patch bumps (`1.2.3` → `1.2.4`) for fixes; minor/major for features/breaks.

## After push

A successful push to `main` notifies [PN-Base](https://github.com/ProjectNexora-base/PN-Base) to rebuild the Qbox mega-zip + `catalog.json` (versions used by the panel for “À mettre à jour”).
