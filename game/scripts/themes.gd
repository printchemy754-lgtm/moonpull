class_name Themes
extends RefCounted
## Five worlds. The world changes every 4 levels and then loops.

const LEVELS_PER_WORLD := 4

static var _cache: Array = []


static func all() -> Array:
	if not _cache.is_empty():
		return _cache
	_cache = [
		{
			"name": "Sunset Canyon",
			"sky_top": Color("1b1d4a"), "sky_horizon": Color("f2a07b"), "ground": Color("2a1f3d"),
			"sun": Color("ffd9b8"), "sun_energy": 1.25, "sun_rot": Vector3(-42.0, -35.0, 0.0),
			"fog": Color("e89a86"), "fog_density": 0.006, "ambient": 1.0,
			"water_deep": Color("0e477a"), "water_shallow": Color("38b8d0"),
			"walls": [Color("c98a5e"), Color("b9764f"), Color("d79a6a"), Color("a86a48")],
			"rock": Color("4b4256"), "rock_tip": Color("7a5f73"), "tip_glow": 0.0,
			"wood": Color("9a6340"), "wood_dark": Color("5b3a28"), "lamp": Color("ffcf6b"),
			"floor": Color("d9c08f"), "deco": "pine", "deco_a": Color("2f6b5a"), "deco_b": Color("5b3d2b"),
			"moon": Color("fff3d6"), "particles": "", "fall": Color("bfe9ff"), "fall_glow": 0.2,
		},
		{
			"name": "Moonlit Bay",
			"sky_top": Color("07081f"), "sky_horizon": Color("2b3a7a"), "ground": Color("0b0b20"),
			"sun": Color("9fb4ff"), "sun_energy": 0.7, "sun_rot": Vector3(-55.0, 30.0, 0.0),
			"fog": Color("1d2550"), "fog_density": 0.008, "ambient": 0.8,
			"water_deep": Color("06203f"), "water_shallow": Color("1d6fa0"),
			"walls": [Color("2c3159"), Color("343a69"), Color("262a4d"), Color("3b3f73")],
			"rock": Color("1c1d33"), "rock_tip": Color("8a7cff"), "tip_glow": 1.6,
			"wood": Color("4a3a6a"), "wood_dark": Color("2a2140"), "lamp": Color("9ff0ff"),
			"floor": Color("2a2f55"), "deco": "mushroom", "deco_a": Color("7cf2ff"), "deco_b": Color("3b2f5c"),
			"moon": Color("f4f7ff"), "particles": "fireflies", "fall": Color("8fb8ff"), "fall_glow": 0.6,
		},
		{
			"name": "Jungle Gorge",
			"sky_top": Color("2f6f8f"), "sky_horizon": Color("cfe8b0"), "ground": Color("23402a"),
			"sun": Color("fff1c2"), "sun_energy": 1.3, "sun_rot": Vector3(-50.0, -20.0, 0.0),
			"fog": Color("a9d8a0"), "fog_density": 0.007, "ambient": 1.0,
			"water_deep": Color("0b4a4a"), "water_shallow": Color("2fb59a"),
			"walls": [Color("4f7a3a"), Color("5d8a42"), Color("3f6a32"), Color("6b8f4a")],
			"rock": Color("3b4a3a"), "rock_tip": Color("5f7a4f"), "tip_glow": 0.0,
			"wood": Color("7a5230"), "wood_dark": Color("4a3018"), "lamp": Color("ffd27a"),
			"floor": Color("8a7a50"), "deco": "palm", "deco_a": Color("3f8f3f"), "deco_b": Color("6b4a2b"),
			"moon": Color("fff8e0"), "particles": "", "fall": Color("c8f5ff"), "fall_glow": 0.2,
		},
		{
			"name": "Frost Fjord",
			"sky_top": Color("4a6fa5"), "sky_horizon": Color("e6f2ff"), "ground": Color("9db7d5"),
			"sun": Color("ffffff"), "sun_energy": 1.1, "sun_rot": Vector3(-35.0, 40.0, 0.0),
			"fog": Color("d6e6f5"), "fog_density": 0.009, "ambient": 1.1,
			"water_deep": Color("1b4f7a"), "water_shallow": Color("6ec6e6"),
			"walls": [Color("dfe9f3"), Color("c9d9ea"), Color("eef4fa"), Color("b8cde3")],
			"rock": Color("7f9fbf"), "rock_tip": Color("e8f6ff"), "tip_glow": 0.3,
			"wood": Color("8a99ab"), "wood_dark": Color("5d6b7c"), "lamp": Color("ffe9a8"),
			"floor": Color("cfe0ef"), "deco": "ice", "deco_a": Color("ffffff"), "deco_b": Color("a8d8ff"),
			"moon": Color("ffffff"), "particles": "snow", "fall": Color("e8f8ff"), "fall_glow": 0.3,
		},
		{
			"name": "Ember Isles",
			"sky_top": Color("1a0f1f"), "sky_horizon": Color("ff6a3d"), "ground": Color("2a1010"),
			"sun": Color("ffb380"), "sun_energy": 1.2, "sun_rot": Vector3(-30.0, -60.0, 0.0),
			"fog": Color("7a3020"), "fog_density": 0.007, "ambient": 0.8,
			"water_deep": Color("101a3a"), "water_shallow": Color("3a5f8f"),
			"walls": [Color("3a2a2a"), Color("2e2222"), Color("4a3030"), Color("352626")],
			"rock": Color("1f1818"), "rock_tip": Color("ff5a1f"), "tip_glow": 2.0,
			"wood": Color("5a3a2a"), "wood_dark": Color("2a1a12"), "lamp": Color("ffae42"),
			"floor": Color("3a2a22"), "deco": "crystal", "deco_a": Color("ff7a2f"), "deco_b": Color("2a1a1a"),
			"moon": Color("ffe2c4"), "particles": "embers", "fall": Color("ff7a2f"), "fall_glow": 2.5,
		},
	]
	return _cache


static func world_index(level: int) -> int:
	return int((level - 1) / LEVELS_PER_WORLD) % all().size()


static func for_level(level: int) -> Dictionary:
	return all()[world_index(level)]


## 1-based position of the level inside its world (1..LEVELS_PER_WORLD).
static func step_in_world(level: int) -> int:
	return (level - 1) % LEVELS_PER_WORLD + 1
