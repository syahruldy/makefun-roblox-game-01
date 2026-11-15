-- NEON CORE: Vault Breaker — shared balance and content table.
-- One source of truth for every number the game uses: vaults, crystals,
-- enemies, power-ups, the boss, upgrades and the win condition. The server
-- reads it to run the game; the client reads it to draw the game. Nothing
-- else hardcodes a tuning number, so a balance change is a one-line edit
-- here.
-- SPDX-License-Identifier: MIT

local GameConfig = {}

-- The arena is a 640 x 480 pixel GUI space, the same for every vault.
GameConfig.ARENA_WIDTH = 640
GameConfig.ARENA_HEIGHT = 480

-- The whole run: six vaults, one clock.
GameConfig.GAME_TIME_SECONDS = 360
GameConfig.START_LIVES = 3
GameConfig.MAX_LIVES = 5

-- The player drone.
GameConfig.PLAYER_SIZE = 28
GameConfig.PLAYER_SPEED = 260 -- pixels per second
GameConfig.DASH_MULTIPLIER = 3.0
GameConfig.DASH_SECONDS = 0.25
GameConfig.DASH_COOLDOWN_SECONDS = 2.5
GameConfig.DASH_COOLDOWN_PER_LEVEL = 0.4
GameConfig.INVULNERABLE_SECONDS = 1.5

-- Mining: standing on a crystal charges the pickaxe against it.
GameConfig.PICKAXE_DAMAGE_PER_SECOND = 10
GameConfig.PICKAXE_DAMAGE_PER_LEVEL = 5
GameConfig.MAGNET_RADIUS_PIXELS = 6
GameConfig.MAGNET_RADIUS_PER_LEVEL = 18
GameConfig.CRYSTALS_PER_ZONE = 14
GameConfig.CRYSTAL_RESPAWN_SECONDS = 4

-- Dash combat: dashing through an enemy destroys it. The drone is
-- invulnerable while dashing, so a dash is both an escape and a weapon.
GameConfig.DASH_KILL_SCORE = 25

-- Combo: every crystal mined (or enemy dash-killed) without taking a hit
-- raises the combo, and the combo multiplies the ore a crystal pays.
-- One hit resets it to zero.
GameConfig.COMBO_MAX = 5
GameConfig.COMBO_ORE_PER_STEP = 0.25

-- Power-ups: a mined crystal sometimes drops one. The drop rolls on the
-- server so a pickup is always the server's call.
GameConfig.POWERUP_DROP_CHANCE = 0.25
GameConfig.OVERDRIVE_SECONDS = 10 -- 2x mining damage while active
GameConfig.STAR_SECONDS = 6 -- invulnerable + faster while active
GameConfig.STAR_SPEED_MULTIPLIER = 1.4
GameConfig.TIME_BONUS_SECONDS = 20
GameConfig.POWERUP_KINDS = { "shield", "overdrive", "timecell", "star" }

-- Sentry Turrets: stationary, one shot at the player every few seconds.
GameConfig.TURRET_SHOT_SECONDS = 2.2
GameConfig.TURRET_BULLET_SPEED = 130
GameConfig.TURRET_BULLET_SIZE = 10

-- The Vault Warden: the boss of the Core Vault. It chases slowly, fires
-- radial bullet bursts, and only dash combat hurts it. Breaking it pays a
-- bonus and silences its barrage; the run is still won by mining the
-- Vault Core.
GameConfig.BOSS_HP = 100
GameConfig.BOSS_DASH_DAMAGE = 20
GameConfig.BOSS_SCORE = 500
GameConfig.BOSS_SPEED = 45
GameConfig.BOSS_SIZE = 56
GameConfig.BOSS_BURST_SECONDS = 4
GameConfig.BOSS_BURST_COUNT = 8
GameConfig.BOSS_BULLET_SPEED = 110

-- Six vaults, each with its own neon palette, goal and danger. The shard
-- goal is how many shards open the portal to the next vault; the Core
-- Vault has no portal, it has the Vault Core and the Warden instead.
GameConfig.ZONES = {
	{
		name = "Ember Vault",
		subtitle = "Vault 1 of 6",
		-- Warm amber vault.
		background = Color3.fromRGB(26, 15, 10),
		arena = Color3.fromRGB(58, 32, 18),
		crystal = Color3.fromRGB(255, 159, 28),
		crystalGlow = Color3.fromRGB(255, 209, 102),
		accent = Color3.fromRGB(255, 159, 28),
		text = Color3.fromRGB(255, 236, 209),
		shardGoal = 8,
		crystalOre = 2,
		crystalHp = 10,
		chasers = 2,
		rocks = 0,
		blobs = 0,
		turrets = 0,
		enemySpeed = 70,
	},
	{
		name = "Frost Vault",
		subtitle = "Vault 2 of 6",
		-- Cold cyan vault.
		background = Color3.fromRGB(8, 20, 32),
		arena = Color3.fromRGB(16, 42, 60),
		crystal = Color3.fromRGB(76, 201, 240),
		crystalGlow = Color3.fromRGB(144, 224, 239),
		accent = Color3.fromRGB(76, 201, 240),
		text = Color3.fromRGB(202, 240, 248),
		shardGoal = 12,
		crystalOre = 3,
		crystalHp = 12,
		chasers = 2,
		rocks = 1,
		blobs = 0,
		turrets = 0,
		enemySpeed = 85,
	},
	{
		name = "Storm Vault",
		subtitle = "Vault 3 of 6",
		-- Electric violet vault.
		background = Color3.fromRGB(20, 10, 32),
		arena = Color3.fromRGB(44, 22, 66),
		crystal = Color3.fromRGB(181, 23, 158),
		crystalGlow = Color3.fromRGB(247, 37, 133),
		accent = Color3.fromRGB(181, 23, 158),
		text = Color3.fromRGB(255, 204, 251),
		shardGoal = 16,
		crystalOre = 4,
		crystalHp = 14,
		chasers = 3,
		rocks = 2,
		blobs = 0,
		turrets = 1,
		enemySpeed = 100,
	},
	{
		name = "Toxic Vault",
		subtitle = "Vault 4 of 6",
		-- Acid green vault.
		background = Color3.fromRGB(8, 26, 12),
		arena = Color3.fromRGB(18, 54, 26),
		crystal = Color3.fromRGB(128, 255, 0),
		crystalGlow = Color3.fromRGB(190, 255, 120),
		accent = Color3.fromRGB(128, 255, 0),
		text = Color3.fromRGB(224, 255, 200),
		shardGoal = 20,
		crystalOre = 5,
		crystalHp = 16,
		chasers = 3,
		rocks = 2,
		blobs = 2,
		turrets = 1,
		enemySpeed = 115,
	},
	{
		name = "Void Vault",
		subtitle = "Vault 5 of 6",
		-- Deep magenta vault.
		background = Color3.fromRGB(24, 6, 18),
		arena = Color3.fromRGB(52, 14, 40),
		crystal = Color3.fromRGB(247, 37, 133),
		crystalGlow = Color3.fromRGB(255, 122, 179),
		accent = Color3.fromRGB(247, 37, 133),
		text = Color3.fromRGB(255, 214, 232),
		shardGoal = 24,
		crystalOre = 6,
		crystalHp = 18,
		chasers = 3,
		rocks = 2,
		blobs = 2,
		turrets = 2,
		enemySpeed = 125,
	},
	{
		name = "Core Vault",
		subtitle = "Final Vault — the Warden waits",
		-- Blazing gold vault.
		background = Color3.fromRGB(28, 20, 4),
		arena = Color3.fromRGB(62, 46, 10),
		crystal = Color3.fromRGB(255, 214, 10),
		crystalGlow = Color3.fromRGB(255, 234, 120),
		accent = Color3.fromRGB(255, 214, 10),
		text = Color3.fromRGB(255, 246, 200),
		shardGoal = 0, -- No portal here: mine the Vault Core to win.
		crystalOre = 8,
		crystalHp = 18,
		chasers = 2,
		rocks = 1,
		blobs = 2,
		turrets = 1,
		enemySpeed = 130,
	},
}

-- The Vault Core: the win condition. It sits in the middle of the Core
-- Vault, takes sustained mining, and the Warden's barrage spawns while
-- the player works on it.
GameConfig.CORE_CRYSTAL_HP = 80
GameConfig.CORE_CRYSTAL_ORE = 60
GameConfig.CORE_GUARDIAN_CHASERS = 2

-- The Forge: four upgrade lines, bought with ore between vaults. Each line
-- lists its per-level costs; the level count is the list length.
GameConfig.UPGRADES = {
	pickaxe = {
		name = "Pickaxe Power",
		description = "+5 mining damage per second",
		costs = { 15, 30, 50 },
	},
	dash = {
		name = "Phase Dash",
		description = "-0.4s dash cooldown",
		costs = { 20, 35, 55 },
	},
	magnet = {
		name = "Ore Magnet",
		description = "+18px mining reach",
		costs = { 15, 25, 40 },
	},
	hull = {
		name = "Reinforced Hull",
		description = "+1 max life, and heals 1",
		costs = { 40, 70 },
	},
}

-- Score: ore kept, shards gathered, dash kills, the boss, time left and
-- lives left all count.
GameConfig.SCORE_PER_SHARD = 10
GameConfig.SCORE_PER_SECOND_LEFT = 5
GameConfig.SCORE_PER_LIFE_LEFT = 100

return GameConfig
