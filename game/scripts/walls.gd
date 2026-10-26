class_name Walls
extends Node3D
## River banks. Left and right can use different styles (bought in the Workshop).
## All pieces with the same material are merged into one mesh, so even detailed
## walls cost only a handful of draw calls on phones.

const INNER := 5.0          # inner face distance from the river centre
const STEP_MIN := 6.0
const STEP_MAX := 11.0

const CHUNK := 160.0         # walls are built in chunks as the boat advances

var theme: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _batches := {}          # Material -> SurfaceTool
var _mats := {}
var _fall_shader: Shader
var _holder: Node3D
var _chunks: Array = []     # [end_z, Node3D]
var _styles := ["canyon", "harbor"]
var _seed := 1
var _limit := 100.0
var _cursor := {-1.0: -40.0, 1.0: -40.0}
var _built_to := -40.0


## Resets the banks. Chunks are then created by ensure() as needed.
func build(left: String, right: String, length: float, th: Dictionary, level_seed: int) -> void:
	for c in get_children():
		c.queue_free()
	_chunks.clear()
	_batches.clear()
	_mats.clear()
	theme = th
	if _fall_shader == null:
		_fall_shader = load("res://shaders/fall.gdshader")
	_styles = [left, right]
	_seed = level_seed
	_limit = length
	_cursor = {-1.0: -40.0, 1.0: -40.0}
	_built_to = -40.0


func ensure(z_needed: float) -> void:
	while _built_to < minf(z_needed, _limit):
		_build_chunk(_built_to + CHUNK)


func cull(z_behind: float) -> void:
	while not _chunks.is_empty() and float(_chunks[0][0]) < z_behind:
		(_chunks.pop_front()[1] as Node3D).queue_free()


func _build_chunk(z_end: float) -> void:
	_holder = Node3D.new()
	add_child(_holder)
	var idx := int((_built_to + 40.0) / CHUNK)
	for side in [-1.0, 1.0]:
		rng.seed = _seed * 31 + idx * 977 + (7 if side < 0.0 else 13)
		var style: String = _styles[0] if side < 0.0 else _styles[1]
		var z: float = _cursor[side]
		while z < z_end:
			var seg := rng.randf_range(STEP_MIN, STEP_MAX)
			match style:
				"harbor": _harbor(side, z, seg)
				"pier": _pier(side, z, seg)
				"village": _village(side, z, seg)
				"crystal": _crystal(side, z, seg)
				"candy": _candy(side, z, seg)
				"temple": _temple(side, z, seg)
				"neon": _neon(side, z, seg)
				_: _canyon(side, z, seg)
			z += seg
		_cursor[side] = z
	_commit()
	_chunks.append([maxf(_cursor[-1.0], _cursor[1.0]), _holder])
	_built_to = z_end


# ------------------------------------------------------------------ batching helpers

func _m(color: Color, glow := 0.0, outline := 0.0) -> Material:
	var key := "%s|%.2f|%.3f" % [color.to_html(), glow, outline]
	if not _mats.has(key):
		_mats[key] = Toon.mat(color, glow, outline, 0.2)
	return _mats[key]


func _put(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	if not _batches.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = st
	var basis := Basis.from_euler(rot) * Basis.from_scale(scl)
	(_batches[mat] as SurfaceTool).append_from(mesh, 0, Transform3D(basis, pos))


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	_put(m, mat, pos, rot)


func _cyl(rb: float, rt: float, h: float, pos: Vector3, mat: Material, sides := 10, rot := Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = rb
	m.top_radius = rt
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	_put(m, mat, pos, rot)


func _ball(r: float, pos: Vector3, mat: Material, scl := Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	_put(m, mat, pos, Vector3.ZERO, scl)


func _prism(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var m := PrismMesh.new()
	m.size = size
	_put(m, mat, pos, rot)


func _commit() -> void:
	for mat in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = (_batches[mat] as SurfaceTool).commit()
		mi.material_override = mat
		_holder.add_child(mi)
	_batches.clear()


## x of a point `d` units from the inner face, going away from the river.
func _x(side: float, d: float) -> float:
	return side * (INNER + d)


## Solid ground block behind everything, from the inner face outward.
func _mass(side: float, z: float, seg: float, top: float, col: Color, from_d := 0.0) -> void:
	var h := top - LevelGen.FLOOR_Y + 1.0
	_box(Vector3(30.0, h, seg + 0.02), Vector3(_x(side, from_d + 15.0), LevelGen.FLOOR_Y - 1.0 + h * 0.5, z + seg * 0.5), _m(col))


# ------------------------------------------------------------------ styles

func _canyon(side: float, z: float, seg: float) -> void:   # TECH WALL
	var cols: Array = theme.walls
	var col: Color = cols[rng.randi() % cols.size()]
	var top := rng.randf_range(7.2, 9.6)
	var inset := rng.randf_range(0.0, 0.4)
	var zc := z + seg * 0.5
	var neon: Color = theme.get("neon", Color("ff2fd0"))
	_mass(side, z, seg, top, col, inset)
	# armour panels with seams
	var panels := int(seg / 2.2)
	for k in panels:
		var pz := z + (k + 0.5) * seg / panels
		_box(Vector3(0.18, top - 1.2, seg / panels - 0.25), Vector3(_x(side, inset - 0.09), 0.6 + (top - 1.2) * 0.5, pz), _m(col.lightened(0.08)))
	# glowing seams
	_box(Vector3(0.08, 0.1, seg + 0.04), Vector3(_x(side, inset - 0.2), 1.0, zc), _m(neon, 2.6))
	if rng.randf() < 0.6:
		_box(Vector3(0.08, 0.06, seg * 0.6), Vector3(_x(side, inset - 0.2), rng.randf_range(3.0, top - 1.5), zc), _m(theme.get("neon2", neon), 2.4))
	# top cornice
	_box(Vector3(1.5, 0.35, seg + 0.04), Vector3(_x(side, inset + 0.55), top + 0.1, zc), _m(col.lightened(0.18)))
	_box(Vector3(0.06, 0.06, seg + 0.04), Vector3(_x(side, inset - 0.2), top + 0.27, zc), _m(neon, 2.4))
	if rng.randf() < 0.5:
		_tree(Vector3(_x(side, rng.randf_range(1.6, 9.0)), top, z + rng.randf_range(0.0, seg)))
	if rng.randf() < 0.1 and z > 10.0:
		_waterfall(_x(side, inset - 0.06), top, zc, side)


func _harbor(side: float, z: float, seg: float) -> void:   # SPACEPORT
	var top := 3.2
	var zc := z + seg * 0.5
	var metal: Color = theme.get("metal", Color("3a3f6a"))
	var neon: Color = theme.get("neon2", Color("00e5ff"))
	_mass(side, z, seg, top, metal.darkened(0.2))
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, -0.04), top - 0.3, zc), _m(neon, 2.6))
	_box(Vector3(1.8, 0.3, seg + 0.04), Vector3(_x(side, 0.7), top + 0.15, zc), _m(metal.lightened(0.2)))
	# landing pad lights along the edge
	var lz := z + 0.8
	while lz < z + seg:
		_ball(0.09, Vector3(_x(side, 0.15), top + 0.32, lz), _m(theme.get("neon", neon), 3.0))
		lz += 1.6
	# hangar or control tower behind
	if rng.randf() < 0.55:
		var d := rng.randf_range(4.0, 6.0)
		var h := rng.randf_range(2.5, 4.5)
		_box(Vector3(d, h, seg - 0.8), Vector3(_x(side, 2.0 + d * 0.5), top + h * 0.5, zc), _m(metal.lightened(0.1), 0.0, 0.03))
		_cyl(d * 0.5, d * 0.5, seg - 0.8, Vector3(_x(side, 2.0 + d * 0.5), top + h, zc), _m(metal.lightened(0.25), 0.0, 0.03), 16, Vector3(PI * 0.5, 0.0, 0.0))
		_box(Vector3(0.1, h * 0.5, seg * 0.5), Vector3(_x(side, 1.96), top + h * 0.35, zc), _m(neon, 1.8))
	else:
		var th := rng.randf_range(5.0, 9.0)
		var tx := _x(side, rng.randf_range(2.5, 4.0))
		_cyl(0.45, 0.6, th, Vector3(tx, top + th * 0.5, zc), _m(metal.lightened(0.15), 0.0, 0.03), 10)
		_cyl(1.2, 0.9, 0.9, Vector3(tx, top + th + 0.3, zc), _m(Color("1b2a4a"), 0.4, 0.03), 12)
		_cyl(1.25, 1.25, 0.1, Vector3(tx, top + th, zc), _m(neon, 2.6), 12)
		_ball(0.15, Vector3(tx, top + th + 1.1, zc), _m(Color("ff3d5a"), 3.0))


func _pier(side: float, z: float, seg: float) -> void:   # MAGLEV DOCK
	var zc := z + seg * 0.5
	var deck_y := 2.3
	var metal: Color = theme.get("metal", Color("3a3f6a"))
	var neon: Color = theme.get("neon", Color("ff2fd0"))
	var neon2: Color = theme.get("neon2", Color("00e5ff"))
	_mass(side, z, seg, 2.0, metal.darkened(0.35), 3.4)
	_box(Vector3(3.5, 0.3, seg + 0.02), Vector3(_x(side, 1.75), deck_y, zc), _m(metal))
	var pz := z + 0.6
	while pz < z + seg:
		_box(Vector3(0.35, deck_y - LevelGen.FLOOR_Y, 0.35), Vector3(_x(side, 0.4), (deck_y + LevelGen.FLOOR_Y) * 0.5, pz), _m(metal.darkened(0.2), 0.0, 0.02))
		pz += 2.2
	# maglev rail with a glowing track
	_box(Vector3(0.6, 0.25, seg + 0.02), Vector3(_x(side, 2.2), deck_y + 0.27, zc), _m(metal.lightened(0.2)))
	_box(Vector3(0.12, 0.04, seg + 0.04), Vector3(_x(side, 2.2), deck_y + 0.41, zc), _m(neon2, 3.0))
	_box(Vector3(0.06, 0.06, seg + 0.04), Vector3(_x(side, 0.02), deck_y + 0.1, zc), _m(neon, 2.6))
	if rng.randf() < 0.3:
		# a parked maglev pod
		var podz := z + rng.randf_range(1.5, seg - 1.5)
		_ball(0.55, Vector3(_x(side, 2.2), deck_y + 0.85, podz), _m(Color("f2f5fa"), 0.0, 0.03), Vector3(1.0, 0.8, 2.4))
		_box(Vector3(0.9, 0.18, 2.0), Vector3(_x(side, 2.2), deck_y + 0.95, podz), _m(neon2, 1.4))
	if rng.randf() < 0.4:
		_tree(Vector3(_x(side, rng.randf_range(4.5, 9.0)), 2.0, z + rng.randf_range(0.0, seg)))


func _village(side: float, z: float, seg: float) -> void:   # HAB DOMES
	var zc := z + seg * 0.5
	var metal: Color = theme.get("metal", Color("3a3f6a"))
	_mass(side, z, seg, 1.0, metal.darkened(0.3), 0.0)
	var pal := [Color("f2f5fa"), Color("dfe6f5"), Color("ffe3f4"), Color("e0fff8")]
	var r := clampf(seg * 0.45, 2.4, 3.6)
	var cx := _x(side, r + 0.2)
	var dome: Color = pal[rng.randi() % pal.size()]
	_ball(r, Vector3(cx, 1.0, zc), _m(dome, 0.0, 0.035), Vector3(1.0, 0.85, 1.0))
	_cyl(r + 0.05, r + 0.05, 0.3, Vector3(cx, 1.1, zc), _m(metal, 0.0, 0.02), 24)
	var glow := _m(theme.get("neon2", Color("00e5ff")), 1.8)
	for k in 3:
		var a := lerpf(-0.6, 0.6, k / 2.0)
		var wz := zc + sin(a) * r * 0.85
		_box(Vector3(0.12, 0.45, 0.55), Vector3(_x(side, r + 0.2 - cos(a) * r * 0.97), 2.2, wz), glow, Vector3(0.0, -side * a, 0.0))
	_box(Vector3(0.14, 1.2, 0.9), Vector3(_x(side, 0.1), 1.6, zc), _m(theme.get("neon", Color("ff2fd0")), 1.6))
	if rng.randf() < 0.4:
		_cyl(0.04, 0.04, 1.4, Vector3(cx, 1.0 + r * 0.85 + 0.7, zc), _m(Color("c0c8dc")), 6)
		_ball(0.1, Vector3(cx, 1.0 + r * 0.85 + 1.45, zc), _m(Color("ff3d5a"), 3.0))


func _candy(side: float, z: float, seg: float) -> void:   # SYNTHWAVE
	var zc := z + seg * 0.5
	var top := 6.4
	var bands := [Color("2a0a4a"), Color("4a0f6a"), Color("7a1a8a"), Color("b02a9a"), Color("ff4fa8"), Color("ff8a5b")]
	var n := bands.size()
	var hh := (top - LevelGen.FLOOR_Y + 1.0) / n
	for k in n:
		var y0 := LevelGen.FLOOR_Y - 1.0 + k * hh
		_box(Vector3(30.0, hh, seg + 0.02), Vector3(_x(side, 15.0), y0 + hh * 0.5, zc), _m(bands[k]))
	for k in 3:
		_box(Vector3(0.06, 0.06, seg + 0.04), Vector3(_x(side, -0.03), 1.0 + k * 1.8, zc), _m(Color("00e5ff"), 3.0))
	var gz := z
	while gz < z + seg:
		_box(Vector3(0.06, top, 0.06), Vector3(_x(side, -0.03), top * 0.5, gz), _m(Color("00e5ff"), 1.6))
		gz += 2.0
	if rng.randf() < 0.55:
		# neon palm silhouette
		var px := _x(side, rng.randf_range(1.5, 4.0))
		var pz2 := z + rng.randf_range(1.0, seg - 1.0)
		var trunk := _m(Color("1a0630"), 0.0, 0.0)
		for k in 4:
			_cyl(0.16, 0.13, 0.9, Vector3(px + side * k * 0.08, top + 0.45 + k * 0.85, pz2), trunk, 6)
		for k in 6:
			var ang := TAU * k / 6.0
			_box(Vector3(1.5, 0.06, 0.3), Vector3(px + side * 0.3 + cos(ang) * 0.65, top + 3.6, pz2 + sin(ang) * 0.65), _m(Color("ff4fd8"), 1.8, 0.0), Vector3(0.0, -ang, -0.3))


func _crystal(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	var top := rng.randf_range(7.0, 9.0)
	_mass(side, z, seg, top, Color("2a2346"))
	_box(Vector3(0.3, 0.5, seg + 0.04), Vector3(_x(side, -0.05), rng.randf_range(2.0, 5.0), zc), _m(Color("3a3160")))
	var cols := [Color("6be3ff"), Color("ff7ad9"), Color("b57bff"), Color("7dffb0")]
	for k in rng.randi_range(2, 3):
		var c: Color = cols[rng.randi() % cols.size()]
		var hgt := rng.randf_range(0.9, 1.5)
		var tilt := rng.randf_range(0.35, 0.8)
		var y := rng.randf_range(0.6, top - 1.0)
		_cyl(rng.randf_range(0.25, 0.4), 0.0, hgt, Vector3(_x(side, 0.1), y, z + rng.randf_range(0.8, seg - 0.8)), _m(c, 1.8, 0.03), 5, Vector3(0.0, 0.0, side * tilt))
	for k in 2:
		var c2: Color = cols[rng.randi() % cols.size()]
		var h2 := rng.randf_range(1.0, 2.4)
		_cyl(0.35, 0.0, h2, Vector3(_x(side, rng.randf_range(1.0, 6.0)), top + h2 * 0.5, z + rng.randf_range(0.0, seg)), _m(c2, 1.8, 0.03), 5)


func _temple(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	var top := 7.6
	_mass(side, z, seg, top, Color("e2c27a"))
	var gold := _m(Color("ffc531"), 0.25, 0.03)
	var stone := _m(Color("f3e2b3"), 0.0, 0.03)
	var cz := z + 1.3
	while cz < z + seg - 0.5:
		_box(Vector3(0.9, 0.35, 0.9), Vector3(_x(side, -0.35), 0.35, cz), gold)
		_cyl(0.3, 0.3, 5.4, Vector3(_x(side, -0.35), 3.25, cz), stone, 12)
		_box(Vector3(0.9, 0.35, 0.9), Vector3(_x(side, -0.35), 6.1, cz), gold)
		cz += 2.6
	_box(Vector3(1.2, 0.7, seg + 0.04), Vector3(_x(side, -0.2), 6.6, zc), _m(Color("ffc531"), 0.25))
	_box(Vector3(1.5, 0.3, seg + 0.04), Vector3(_x(side, 0.2), top + 0.15, zc), _m(Color("d4a94e")))
	var gems := [Color("ff3d5a"), Color("3ddc97"), Color("4ea8ff")]
	_ball(0.22, Vector3(_x(side, -0.05), 4.2, zc), _m(gems[rng.randi() % gems.size()], 2.2, 0.02))


func _neon(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	_mass(side, z, seg, 1.2, Color("15172b"))
	var d := rng.randf_range(3.0, 6.0)
	var h := rng.randf_range(7.0, 16.0)
	var w := seg - 0.4
	_box(Vector3(d, h, w), Vector3(_x(side, d * 0.5), 1.2 + h * 0.5, zc), _m(Color("1c1f3a"), 0.0, 0.03))
	var neons := [Color("ff2fd0"), Color("2fe8ff"), Color("ffe14f"), Color("7dff6b")]
	var nc: Color = neons[rng.randi() % neons.size()]
	for e in [-0.5, 0.5]:
		_box(Vector3(0.1, h * 0.9, 0.1), Vector3(_x(side, -0.04), 1.2 + h * 0.5, zc + e * (w - 0.2)), _m(nc, 3.0))
	_box(Vector3(0.1, 0.1, w), Vector3(_x(side, -0.04), 1.2 + h * 0.3, zc), _m(nc, 3.0))
	var lit_a := _m(Color("ffd27a"), 1.2)
	var lit_b := _m(Color("8fe3ff"), 1.2)
	var rows := int(h / 1.6)
	for r in rows:
		for c in 3:
			if rng.randf() < 0.45:
				_box(Vector3(0.06, 0.55, 0.6), Vector3(_x(side, -0.02), 2.2 + r * 1.5, zc + (c - 1) * w * 0.3), lit_a if rng.randf() < 0.6 else lit_b)
	if rng.randf() < 0.25:
		var bc: Color = neons[rng.randi() % neons.size()]
		_box(Vector3(0.12, 1.6, w * 0.7), Vector3(_x(side, -0.08), 1.2 + h * 0.62, zc), _m(Color("15122b")))
		_box(Vector3(0.14, 1.3, w * 0.62), Vector3(_x(side, -0.1), 1.2 + h * 0.62, zc), _m(bc, 2.0))


# ------------------------------------------------------------------ decoration

func _tree(base: Vector3) -> void:
	var a: Color = theme.deco_a
	var b: Color = theme.deco_b
	var sc := rng.randf_range(0.8, 1.4)
	match String(theme.deco):
		"spire":
			var h := rng.randf_range(2.0, 5.0) * sc
			_cyl(0.35 * sc, 0.05, h, base + Vector3(0.0, h * 0.5, 0.0), _m(b, 0.0, 0.03), 6)
			_box(Vector3(0.08, h * 0.7, 0.08), base + Vector3(0.0, h * 0.4, 0.3 * sc), _m(a, 2.6))
			_ball(0.12, base + Vector3(0.0, h + 0.1, 0.0), _m(a, 3.0))
		"antenna":
			var h2 := rng.randf_range(2.5, 5.0) * sc
			_cyl(0.06, 0.04, h2, base + Vector3(0.0, h2 * 0.5, 0.0), _m(b, 0.0, 0.02), 6)
			for k in 3:
				_box(Vector3(0.9 - k * 0.2, 0.05, 0.05), base + Vector3(0.0, h2 * (0.5 + k * 0.15), 0.0), _m(b, 0.0, 0.02))
			_ball(0.1, base + Vector3(0.0, h2 + 0.05, 0.0), _m(a, 3.0))
		"dish":
			_cyl(0.12, 0.15, 1.6 * sc, base + Vector3(0.0, 0.8 * sc, 0.0), _m(b, 0.0, 0.02), 8)
			_ball(0.9 * sc, base + Vector3(0.0, 1.9 * sc, 0.0), _m(Color("e6ecf8"), 0.0, 0.03), Vector3(1.0, 0.35, 1.0))
			_ball(0.1, base + Vector3(0.0, 2.25 * sc, 0.0), _m(a, 3.0))
		"pine":
			_cyl(0.18 * sc, 0.12 * sc, 0.8 * sc, base + Vector3(0.0, 0.4 * sc, 0.0), _m(b, 0.0, 0.025), 6)
			_cyl(0.95 * sc, 0.0, 1.6 * sc, base + Vector3(0.0, 1.4 * sc, 0.0), _m(a, 0.0, 0.03), 7)
			_cyl(0.7 * sc, 0.0, 1.3 * sc, base + Vector3(0.0, 2.2 * sc, 0.0), _m(a, 0.0, 0.03), 7)
		"mushroom":
			_cyl(0.12 * sc, 0.1 * sc, 0.9 * sc, base + Vector3(0.0, 0.45 * sc, 0.0), _m(Color("d8d0f0"), 0.0, 0.02), 8)
			_ball(0.55 * sc, base + Vector3(0.0, 0.95 * sc, 0.0), _m(a, 1.8, 0.03), Vector3(1.0, 0.45, 1.0))
		"palm":
			for k in 3:
				_cyl(0.15 * sc, 0.13 * sc, 0.8 * sc, base + Vector3(0.0, (0.4 + k * 0.75) * sc, 0.0), _m(b, 0.0, 0.02), 7)
			for k in 6:
				var ang := TAU * k / 6.0
				_box(Vector3(1.4 * sc, 0.06, 0.35 * sc), base + Vector3(0.0, 2.3 * sc, 0.0) + Vector3(cos(ang), 0.0, sin(ang)) * 0.6 * sc, _m(a, 0.0, 0.02), Vector3(0.0, -ang, -0.35))
		"ice":
			for k in 3:
				var hh := rng.randf_range(1.0, 2.6) * sc
				_cyl(0.35 * sc, 0.0, hh, base + Vector3(rng.randf_range(-0.6, 0.6), hh * 0.5, rng.randf_range(-0.6, 0.6)), _m(b, 0.3, 0.03), 4)
		"crystal":
			for k in 3:
				var hc := rng.randf_range(0.8, 2.0) * sc
				_cyl(0.3 * sc, 0.05, hc, base + Vector3(rng.randf_range(-0.5, 0.5), hc * 0.5, rng.randf_range(-0.5, 0.5)), _m(a, 2.2, 0.03), 5)


func _waterfall(x: float, top: float, z: float, side: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.5, top - LevelGen.FLOOR_Y)
	var sm := ShaderMaterial.new()
	sm.shader = _fall_shader
	sm.set_shader_parameter("color", theme.fall)
	sm.set_shader_parameter("glow", theme.fall_glow)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = sm
	mi.position = Vector3(x, LevelGen.FLOOR_Y + (top - LevelGen.FLOOR_Y) * 0.5, z)
	mi.rotation = Vector3(0.0, -side * PI * 0.5, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder.add_child(mi)
