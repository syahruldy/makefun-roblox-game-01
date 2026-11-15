-- LUMEN CORE: Deep Delve — zone progression, server side.
-- Owns the zone ladder: which zone is live, what its goal is, when the
-- portal opens, and when the Core Crystal replaces the portal. The game
-- server calls into here; it never touches zone numbers itself.
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
-- The final zone never opens a portal: it opens the Core Crystal.
function ZoneServer.isPortalOpen(zoneIndex, shardsInZone)
	if ZoneServer.isFinalZone(zoneIndex) then
		return false
	end
	return shardsInZone >= ZoneServer.getShardGoal(zoneIndex)
end

-- The next zone after this one, or nil past the end of the ladder.
function ZoneServer.getNextZone(zoneIndex)
	if zoneIndex >= #GameConfig.ZONES then
		return nil
	end
	return zoneIndex + 1
end

-- A crystal spawn batch for a zone: positions spread over the arena with a
-- margin from the edges, each with the zone's ore value and hit points.
-- Crystal ids are unique across the whole run so a mined crystal can never
-- be claimed twice.
function ZoneServer.generateCrystalBatch(zoneIndex, firstId)
	local zone = GameConfig.ZONES[zoneIndex]
	local batch = {}
	local margin = 40
	local width = GameConfig.ARENA_WIDTH - margin * 2
	local height = GameConfig.ARENA_HEIGHT - margin * 2
	for i = 1, GameConfig.CRYSTALS_PER_ZONE do
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

-- The Core Crystal: one big crystal in the middle of the Sanctum.
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

return ZoneServer
