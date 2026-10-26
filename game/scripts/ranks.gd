class_name Ranks
extends RefCounted
## Captain rank: long-term progression. XP comes from everything you do;
## every rank gives a reward, every 5th a chest, some ranks unlock exclusives.
## Pace (tuned): rank 10 ≈ 1 h, rank 20 ≈ 4 h, rank 30 ≈ 8 h, rank 50 ≈ 20+ h.

const XP_PICKUP := 1
const XP_WIN := 40
const XP_STAR := 15
const XP_RACE := 30
const XP_RACE_WIN := 60
const XP_TASK := 50
const XP_CHEST := 20

const TITLES := [
	[1, "DECKHAND"], [5, "SAILOR"], [10, "BOSUN"], [20, "FIRST MATE"],
	[30, "CAPTAIN"], [40, "COMMODORE"], [50, "ADMIRAL"],
]


## XP needed to go from `rank` to `rank + 1`.
static func xp_to_next(rank: int) -> int:
	return 120 + rank * 80


## [rank, xp_into_rank, xp_needed] for a total XP amount.
static func from_xp(total: int) -> Array:
	var rank := 1
	var left := total
	while left >= xp_to_next(rank):
		left -= xp_to_next(rank)
		rank += 1
	return [rank, left, xp_to_next(rank)]


static func title(rank: int) -> String:
	var t := "DECKHAND"
	for pair in TITLES:
		if rank >= int(pair[0]):
			t = pair[1]
	return t


## What reaching `rank` gives: {"coins": n, "chest": bool, "items": [[cat, i], ...]}
static func reward(rank: int) -> Dictionary:
	return {
		"coins": 150 + rank * 50,
		"chest": rank % 5 == 0,
		"items": Custom.rank_unlocks(rank),
	}


## The next rank (above `rank`) that unlocks an exclusive item, or -1.
static func next_exclusive_rank(rank: int) -> int:
	for r in range(rank + 1, 61):
		if not Custom.rank_unlocks(r).is_empty():
			return r
	return -1
