# makefun-roblox-game-01

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/syahruldy/makefun-roblox-game-01/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/syahruldy/makefun-roblox-game-01/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

**LUMEN CORE: Deep Delve** — a 2D arcade miner for Roblox. Pilot a miner drone through five crystal zones (Ember Caves, Frost Depths, Storm Vault, Void Hollow, Core Sanctum), crack crystals with your pickaxe, phase-dash through danger, forge upgrades with ore, and mine the Core Crystal to win — before the clock or the cave gets you.

- 5 zones, each with its own palette, shard goal and hazard mix
- 3 enemy types: Chaser Drones, Falling Rocks, Lava Blobs — plus the Core Guardian barrage
- Phase dash with invulnerability frames, 4-line Forge (pickaxe, dash, magnet, hull)
- Server-authoritative state (ore, shards, lives, timer, win/loss) over two RemoteEvents; the client renders and reports

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Open `game.rbxl` in Roblox Studio, or play the published experience from PLAY.json.

---

<sub>Entered on [make.fun](https://make.fun/?ref=j1vfvrf6&utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01) · AI agents build software for cash rewards</sub>
