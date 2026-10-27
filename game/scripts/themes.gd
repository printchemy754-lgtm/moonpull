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
			"name": "Neon Bay",
			"sky_top": Color("070a2a"), "sky_horizon": Color("ff3fa4"), "ground": Color("14062e"),
			"sun": Color("ffc9f0"), "sun_energy": 0.9, "sun_rot": Vector3(-40.0, -30.0, 0.0),
			"fog": Color("5a1a6a"), "fog_density": 0.006, "ambient": 0.9,
			"water_deep": Color("0a0630"), "water_shallow": Color("2a1070"), "grid": Color("ff2fd0"), "edge": Color("00e5ff"),
			"walls": [Color("23264a"), Color("2b2e58"), Color("1e2142"), Color("30345f")],
			"metal": Color("3a3f6a"), "neon": Color("ff2fd0"), "neon2": Color("00e5ff"),
			"rock": Color("2a2d52"), "rock_tip": Color("ff2fd0"), "tip_glow": 2.5,
			"wood": Color("3a3f6a"), "wood_dark": Color("1c1f3a"), "lamp": Color("00e5ff"),
			"floor": Color("14062e"), "deco": "spire", "deco_a": Color("00e5ff"), "deco_b": Color("2a2d52"),
			"moon": Color("fff0ff"), "particles": "motes", "fall": Color("00e5ff"), "fall_glow": 2.0,
		},
		{
			"name": "Cyber Gorge",
			"sky_top": Color("02101c"), "sky_horizon": Color("17d1a0"), "ground": Color("03140f"),
			"sun": Color("b8ffe9"), "sun_energy": 0.9, "sun_rot": Vector3(-50.0, 25.0, 0.0),
			"fog": Color("0c3b3a"), "fog_density": 0.007, "ambient": 0.85,
			"water_deep": Color("021a1f"), "water_shallow": Color("064a4a"), "grid": Color("39ff9f"), "edge": Color("ffe14f"),
			"walls": [Color("1d2f33"), Color("22373b"), Color("18292c"), Color("27403f")],
			"metal": Color("2f4a4c"), "neon": Color("39ff9f"), "neon2": Color("ffe14f"),
			"rock": Color("1f3236"), "rock_tip": Color("39ff9f"), "tip_glow": 2.5,
			"wood": Color("2f4a4c"), "wood_dark": Color("152427"), "lamp": Color("ffe14f"),
			"floor": Color("03140f"), "deco": "antenna", "deco_a": Color("39ff9f"), "deco_b": Color("1f3236"),
			"moon": Color("e9fff6"), "particles": "motes", "fall": Color("39ff9f"), "fall_glow": 2.0,
		},
		{
			"name": "Orbital Dock",
			"sky_top": Color("000006"), "sky_horizon": Color("3a4bff"), "ground": Color("05051a"),
			"sun": Color("c8d2ff"), "sun_energy": 1.0, "sun_rot": Vector3(-55.0, -15.0, 0.0),
			"fog": Color("141a5a"), "fog_density": 0.005, "ambient": 0.9,
			"water_deep": Color("030418"), "water_shallow": Color("10187a"), "grid": Color("5a7bff"), "edge": Color("ff8a3d"),
			"walls": [Color("2a2f45"), Color("343a55"), Color("252a3e"), Color("3c4260")],
			"metal": Color("4a5070"), "neon": Color("5a7bff"), "neon2": Color("ff8a3d"),
			"rock": Color("2a2f45"), "rock_tip": Color("ff8a3d"), "tip_glow": 2.5,
			"wood": Color("4a5070"), "wood_dark": Color("23273a"), "lamp": Color("ff8a3d"),
			"floor": Color("05051a"), "deco": "dish", "deco_a": Color("5a7bff"), "deco_b": Color("4a5070"),
			"moon": Color("ffffff"), "particles": "stars", "fall": Color("5a7bff"), "fall_glow": 2.0,
		},
		{
			"name": "Cryo Lab",
			"sky_top": Color("0a2a55"), "sky_horizon": Color("bff3ff"), "ground": Color("8fb8d8"),
			"sun": Color("ffffff"), "sun_energy": 1.1, "sun_rot": Vector3(-35.0, 40.0, 0.0),
			"fog": Color("9fd0ea"), "fog_density": 0.008, "ambient": 1.05,
			"water_deep": Color("06274a"), "water_shallow": Color("1d7fb0"), "grid": Color("bff3ff"), "edge": Color("ffffff"),
			"walls": [Color("d8e6f2"), Color("c3d6e8"), Color("e8f0f8"), Color("b4cade")],
			"metal": Color("9fb6cc"), "neon": Color("00c8ff"), "neon2": Color("ffffff"),
			"rock": Color("7f9fbf"), "rock_tip": Color("00c8ff"), "tip_glow": 2.2,
			"wood": Color("9fb6cc"), "wood_dark": Color("5d7590"), "lamp": Color("00c8ff"),
			"floor": Color("8fb8d8"), "deco": "spire", "deco_a": Color("00c8ff"), "deco_b": Color("c3d6e8"),
			"moon": Color("ffffff"), "particles": "snow", "fall": Color("bff3ff"), "fall_glow": 1.5,
		},
		{
			"name": "Plasma Forge",
			"sky_top": Color("12040a"), "sky_horizon": Color("ff4d1f"), "ground": Color("1a0606"),
			"sun": Color("ffb380"), "sun_energy": 1.1, "sun_rot": Vector3(-30.0, -60.0, 0.0),
			"fog": Color("5a1a10"), "fog_density": 0.007, "ambient": 0.8,
			"water_deep": Color("12040a"), "water_shallow": Color("4a0f1a"), "grid": Color("ff7a2f"), "edge": Color("ffd23f"),
			"walls": [Color("2e2226"), Color("38282c"), Color("261c20"), Color("402e30")],
			"metal": Color("4a3a3e"), "neon": Color("ff4d1f"), "neon2": Color("ffd23f"),
			"rock": Color("2a1c1e"), "rock_tip": Color("ff4d1f"), "tip_glow": 2.8,
			"wood": Color("4a3a3e"), "wood_dark": Color("221819"), "lamp": Color("ffae42"),
			"floor": Color("1a0606"), "deco": "antenna", "deco_a": Color("ff4d1f"), "deco_b": Color("2a1c1e"),
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
