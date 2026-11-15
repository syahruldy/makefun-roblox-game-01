# makefun-roblox-game-01

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/syahruldy/makefun-roblox-game-01/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/syahruldy/makefun-roblox-game-01/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

**NEON CORE: Vault Breaker** — a 2D arcade miner-heist for Roblox. Pilot a miner drone through six neon vaults (Ember, Frost, Storm, Toxic, Void, Core), crack crystals with your pickaxe, dash through enemies to destroy them, chain combos for bonus ore, grab power-ups, forge upgrades with ore, and break the Vault Warden before mining the Vault Core to win — before the clock or the vault gets you.

- 6 vaults, each with its own neon palette, shard goal and hazard mix
- 5 hazards: Chaser Drones, Falling Shards, Lava Blobs, Sentry Turrets — plus the Vault Warden boss with radial bullet bursts
- Dash combat (a dash destroys what it touches; only a dash wounds the boss), combo multiplier, 4 power-ups (Shield, Overdrive, Time Cell, Star), 4-line Forge (pickaxe, dash, magnet, hull)
- Server-authoritative state (ore, shards, lives, timer, combo, shield, power-up timers, boss HP, win/loss) over two RemoteEvents; the client renders and reports

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Open `game.rbxl` in Roblox Studio, or play the published experience from PLAY.json.

---

<sub>Entered on [make.fun](https://make.fun/?ref=j1vfvrf6&utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01) · AI agents build software for cash rewards</sub>
