class_name Themes
extends RefCounted
## Five futuristic worlds. The world changes every 4 levels and then loops.

const LEVELS_PER_WORLD := 4

static var _cache: Array = []


static func all() -> Array:
	if not _cache.is_empty():
		return _cache
	_cache = [
		{
			"name": "Neon Bay",
			"sky_top": Color("0b0630"), "sky_horizon": Color("ff3fa4"), "ground": Color("1a0b3a"),
			"sun": Color("ffb0e0"), "sun_energy": 0.95, "sun_rot": Vector3(-38.0, -30.0, 0.0),
			"fog": Color("5a1a7a"), "fog_density": 0.006, "ambient": 0.9,
			"water_deep": Color("0a0a40"), "water_shallow": Color("2a3ab0"), "grid": Color("00e5ff"),
			"neon": Color("ff2fd0"), "neon2": Color("00e5ff"), "metal": Color("3a3f6a"),
			"walls": [Color("2a1f55"), Color("231a48"), Color("30245e"), Color("1f1640")],
			"rock": Color("1d1840"), "rock_tip": Color("ff2fd0"), "tip_glow": 2.0,
			"wood": Color("2c3160"), "wood_dark": Color("1a1d3c"), "lamp": Color("00e5ff"),
			"floor": Color("120c30"), "deco": "spire", "deco_a": Color("ff2fd0"), "deco_b": Color("2a2f5a"),
			"moon": Color("ffe0f4"), "particles": "motes", "fall": Color("00e5ff"), "fall_glow": 2.0,
		},
		{
			"name": "Cyber Gorge",
			"sky_top": Color("020812"), "sky_horizon": Color("00b3c7"), "ground": Color("01060c"),
			"sun": Color("b8fff4"), "sun_energy": 0.85, "sun_rot": Vector3(-50.0, 25.0, 0.0),
			"fog": Color("05303a"), "fog_density": 0.008, "ambient": 0.8,
			"water_deep": Color("021a24"), "water_shallow": Color("0a6a78"), "grid": Color("00ffc8"),
			"neon": Color("00ffc8"), "neon2": Color("ffd23f"), "metal": Color("2a3a48"),
			"walls": [Color("16222e"), Color("1b2a38"), Color("12202a"), Color("203242")],
			"rock": Color("121c26"), "rock_tip": Color("00ffc8"), "tip_glow": 2.0,
			"wood": Color("243444"), "wood_dark": Color("101a24"), "lamp": Color("ffd23f"),
			"floor": Color("08121a"), "deco": "antenna", "deco_a": Color("00ffc8"), "deco_b": Color("2a3a48"),
			"moon": Color("e0fff8"), "particles": "motes", "fall": Color("00ffc8"), "fall_glow": 2.2,
		},
		{
			"name": "Orbital Dock",
			"sky_top": Color("000005"), "sky_horizon": Color("2a3a8a"), "ground": Color("000000"),
			"sun": Color("dfe6ff"), "sun_energy": 1.1, "sun_rot": Vector3(-30.0, 50.0, 0.0),
			"fog": Color("0a1030"), "fog_density": 0.005, "ambient": 0.75,
			"water_deep": Color("05082a"), "water_shallow": Color("2a4ac8"), "grid": Color("7a8cff"),
			"neon": Color("7a8cff"), "neon2": Color("ff7a2f"), "metal": Color("4e5872"),
			"walls": [Color("3a4258"), Color("454e66"), Color("323a50"), Color("4e5872")],
			"rock": Color("2a3046"), "rock_tip": Color("ff7a2f"), "tip_glow": 2.0,
			"wood": Color("5a6480"), "wood_dark": Color("2a3046"), "lamp": Color("ff7a2f"),
			"floor": Color("0a0e20"), "deco": "dish", "deco_a": Color("7a8cff"), "deco_b": Color("8a94b0"),
			"moon": Color("f4f7ff"), "particles": "stars", "fall": Color("7a8cff"), "fall_glow": 2.0,
		},
		{
			"name": "Cryo Lab",
			"sky_top": Color("2a5a9a"), "sky_horizon": Color("dff4ff"), "ground": Color("9db7d5"),
			"sun": Color("ffffff"), "sun_energy": 1.15, "sun_rot": Vector3(-35.0, 40.0, 0.0),
			"fog": Color("cfe6f8"), "fog_density": 0.008, "ambient": 1.1,
			"water_deep": Color("0b3a6a"), "water_shallow": Color("4ac8ff"), "grid": Color("ffffff"),
			"neon": Color("3ad8ff"), "neon2": Color("ff4fa8"), "metal": Color("c4d8ec"),
			"walls": [Color("e6f0fa"), Color("d0e2f2"), Color("f4f8fc"), Color("c4d8ec")],
			"rock": Color("8aa8c8"), "rock_tip": Color("9ff0ff"), "tip_glow": 1.4,
			"wood": Color("dfe8f2"), "wood_dark": Color("8a9cb2"), "lamp": Color("3ad8ff"),
			"floor": Color("b8cce0"), "deco": "crystal", "deco_a": Color("9ff0ff"), "deco_b": Color("c4d8ec"),
			"moon": Color("ffffff"), "particles": "snow", "fall": Color("e8f8ff"), "fall_glow": 0.8,
		},
		{
			"name": "Plasma Forge",
			"sky_top": Color("120408"), "sky_horizon": Color("ff4a1a"), "ground": Color("1a0606"),
			"sun": Color("ffb080"), "sun_energy": 1.1, "sun_rot": Vector3(-30.0, -60.0, 0.0),
			"fog": Color("5a1a10"), "fog_density": 0.007, "ambient": 0.8,
			"water_deep": Color("10061a"), "water_shallow": Color("4a1a6a"), "grid": Color("ff6a1f"),
			"neon": Color("ff6a1f"), "neon2": Color("ffd23f"), "metal": Color("3a2626"),
			"walls": [Color("2a1a1a"), Color("241515"), Color("33201c"), Color("1e1212")],
			"rock": Color("1f1414"), "rock_tip": Color("ff5a1f"), "tip_glow": 2.4,
			"wood": Color("3a2626"), "wood_dark": Color("1a1010"), "lamp": Color("ffae42"),
			"floor": Color("1a0e0c"), "deco": "spire", "deco_a": Color("ff6a1f"), "deco_b": Color("2a1a1a"),
			"moon": Color("ffe2c4"), "particles": "embers", "fall": Color("ff6a1f"), "fall_glow": 2.6,
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
