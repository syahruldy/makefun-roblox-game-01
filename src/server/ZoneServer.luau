-- NEON CORE: Vault Breaker — zone progression, server side.
-- Owns the vault ladder: which vault is live, what its goal is, when the
-- portal opens, and when the Vault Core and the Warden replace the portal.
-- The game server calls into here; it never touches vault numbers itself.
-- SPDX-License-Identifier: MIT

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ZoneServer = {}

function ZoneServer.getZoneCount()
	return #GameConfig.ZONES
end

function ZoneServer.getZone(zoneIndex)
	return GameConfig.ZONES[zoneIndex]
end

function ZoneServer.isFinalZone(zoneIndex)
	return zoneIndex >= #GameConfig.ZONES
end

-- The shard goal for a zone, or 0 when the zone has no portal.
function ZoneServer.getShardGoal(zoneIndex)
	local zone = GameConfig.ZONES[zoneIndex]
	if zone == nil then
		return 0
	end
	return zone.shardGoal
end

-- True once the player has gathered enough shards to open the portal.
-- The final vault never opens a portal: it opens the Vault Core.
function ZoneServer.isPortalOpen(zoneIndex, shardsInZone)
	if ZoneServer.isFinalZone(zoneIndex) then
		return false
	end
	return shardsInZone >= ZoneServer.getShardGoal(zoneIndex)
end

-- The next vault after this one, or nil past the end of the ladder.
function ZoneServer.getNextZone(zoneIndex)
	if zoneIndex >= #GameConfig.ZONES then
		return nil
	end
	return zoneIndex + 1
end

-- A crystal spawn batch for a vault: positions spread over the arena with a
-- margin from the edges, each with the vault's ore value and hit points.
-- Crystal ids are unique across the whole run so a mined crystal can never
-- be claimed twice.
function ZoneServer.generateCrystalBatch(zoneIndex, firstId, count)
	local zone = GameConfig.ZONES[zoneIndex]
	local batch = {}
	local margin = 40
	local width = GameConfig.ARENA_WIDTH - margin * 2
	local height = GameConfig.ARENA_HEIGHT - margin * 2
	for i = 1, count or GameConfig.CRYSTALS_PER_ZONE do
		batch[i] = {
			id = firstId + i - 1,
			x = margin + math.random(0, width),
			y = margin + math.random(0, height),
			ore = zone.crystalOre,
			hp = zone.crystalHp,
			maxHp = zone.crystalHp,
			zone = zoneIndex,
		}
	end
	return batch
end

-- The Vault Core: one big crystal in the middle of the Core Vault.
function ZoneServer.generateCoreCrystal(nextId)
	return {
		id = nextId,
		x = math.floor(GameConfig.ARENA_WIDTH / 2),
		y = math.floor(GameConfig.ARENA_HEIGHT / 2),
		ore = GameConfig.CORE_CRYSTAL_ORE,
		hp = GameConfig.CORE_CRYSTAL_HP,
		maxHp = GameConfig.CORE_CRYSTAL_HP,
		zone = #GameConfig.ZONES,
		isCore = true,
	}
end

-- The Vault Warden: the boss of the Core Vault. It spawns above the Vault
-- Core so the player meets it on the way in, and its hit points live on
-- the server; the client only draws it and reports dash hits.
function ZoneServer.generateBoss()
	return {
		x = math.floor(GameConfig.ARENA_WIDTH / 2),
		y = 90,
		hp = GameConfig.BOSS_HP,
		maxHp = GameConfig.BOSS_HP,
	}
end

return ZoneServer
