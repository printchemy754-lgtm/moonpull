class_name Walls
extends Node3D
## Floating city scenery on both sides of the track (styles bought in the
## Workshop, left and right can differ). Built in short segments that follow
## the track's curves, a few metres of empty space away from its edges.
## All pieces with the same material are merged into one mesh, so even detailed
## walls cost only a handful of draw calls on phones.

const INNER := 9.0          # distance of the scenery from the track centre
const Y_OFF := -6.5         # scenery sits below the track: you roll above a city
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
var track: Track
var _seg_xf := Transform3D.IDENTITY


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


## Respawn behind: rebuild the scenery from a bit before z.
func rewind(z: float) -> void:
	for c in _chunks:
		(c[1] as Node3D).queue_free()
	_chunks.clear()
	var idx := maxi(int(floor((z - 60.0 + 40.0) / CHUNK)), 0)
	_built_to = -40.0 + idx * CHUNK
	_cursor = {-1.0: _built_to, 1.0: _built_to}
	ensure(z + 210.0)


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
		var style: String = _styles[0] if side > 0.0 else _styles[1]   # +s = screen left
		var z: float = _cursor[side]
		while z < minf(z_end, _limit):
			var seg := rng.randf_range(STEP_MIN, STEP_MAX)
			if track:
				_seg_xf = track.frame(clampf(z, 0.0, track.length)) * Transform3D(Basis.IDENTITY, Vector3(0.0, Y_OFF, -z))
			match style:
				"harbor": _harbor(side, z, seg)
				"pier": _pier(side, z, seg)
				"village": _village(side, z, seg)
				"crystal": _crystal(side, z, seg)
				"candy": _candy(side, z, seg)
				"temple": _temple(side, z, seg)
				"neon": _neon(side, z, seg)
				_: _canyon(side, z, seg)
			# seasonal props (pumpkins / Christmas trees) on every wall style
			if theme.has("season") and style != "canyon" and style != "pier" and rng.randf() < 0.4:
				var tops := {"harbor": [3.55, 0.7], "village": [1.0, 0.25], "crystal": [7.6, 0.7], "candy": [6.65, 0.6], "temple": [7.75, 0.6], "neon": [1.2, 0.3]}
				var tp: Array = tops.get(style, [1.0, 0.5])
				_tree(Vector3(_x(side, float(tp[1])), float(tp[0]), z + seg * 0.5))
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
	(_batches[mat] as SurfaceTool).append_from(mesh, 0, _seg_xf * Transform3D(basis, pos))


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
	var h := top - LevelGen.FLOOR_Y + 9.0
	_box(Vector3(30.0, h, seg + 0.4), Vector3(_x(side, from_d + 15.0), LevelGen.FLOOR_Y - 9.0 + h * 0.5, z + seg * 0.5), _m(col))


# ------------------------------------------------------------------ styles

## TECH WALL: dark armour panels with neon seams and service lights.
func _canyon(side: float, z: float, seg: float) -> void:
	var cols: Array = theme.walls
	var col: Color = cols[rng.randi() % cols.size()]
	var top := rng.randf_range(7.2, 9.4)
	var inset := rng.randf_range(0.0, 0.4)
	var zc := z + seg * 0.5
	var neon: Color = theme.get("neon", Color("ff2fd0"))
	var neon2: Color = theme.get("neon2", Color("00e5ff"))
	_mass(side, z, seg, top, col, inset)
	# armour plates
	for y in [rng.randf_range(1.2, 2.2), rng.randf_range(3.6, 5.0)]:
		_box(Vector3(0.3, 1.0, seg - 0.3), Vector3(_x(side, inset - 0.1), y, zc), _m(col.lightened(0.08)))
	# neon seams
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, inset - 0.05), 0.55, zc), _m(neon2, 3.0))
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, inset - 0.05), top - 0.3, zc), _m(neon, 3.0))
	if rng.randf() < 0.5:
		_box(Vector3(0.08, top - 1.2, 0.08), Vector3(_x(side, inset - 0.05), top * 0.5 + 0.2, z + rng.randf_range(0.5, seg - 0.5)), _m(neon, 3.0))
	_box(Vector3(1.4, 0.3, seg + 0.04), Vector3(_x(side, inset + 0.55), top + 0.1, zc), _m(col.lightened(0.2)))
	if rng.randf() < 0.55:
		_tree(Vector3(_x(side, rng.randf_range(1.6, 9.0)), top, z + rng.randf_range(0.0, seg)))
	if rng.randf() < 0.1 and z > 10.0:
		_waterfall(_x(side, inset - 0.06), top, zc, side)


## SPACEPORT: metal quay, light bollards and hangars with glowing windows.
func _harbor(side: float, z: float, seg: float) -> void:
	var top := 3.4
	var zc := z + seg * 0.5
	var metal := Color("2e3352")
	var neon2: Color = theme.get("neon2", Color("00e5ff"))
	_mass(side, z, seg, top, metal)
	for k in 3:
		_box(Vector3(0.06, 0.06, seg + 0.04), Vector3(_x(side, -0.03), 0.6 + k * 1.0, zc), _m(Color("4a5070")))
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, -0.04), top - 0.1, zc), _m(neon2, 3.0))
	_box(Vector3(1.6, 0.3, seg + 0.04), Vector3(_x(side, 0.6), top + 0.15, zc), _m(Color("454b6e")))
	var bz := z + 1.2
	while bz < z + seg - 0.6:
		_cyl(0.14, 0.16, 0.6, Vector3(_x(side, 0.45), top + 0.6, bz), _m(Color("1c1f3a"), 0.0, 0.025))
		_cyl(0.12, 0.12, 0.12, Vector3(_x(side, 0.45), top + 0.96, bz), _m(neon2, 3.0))
		bz += 3.0
	var d := rng.randf_range(4.0, 6.0)
	var h := rng.randf_range(3.0, 6.0)
	_box(Vector3(d, h, seg - 0.6), Vector3(_x(side, 1.6 + d * 0.5), top + h * 0.5, zc), _m(Color("252a45"), 0.0, 0.03))
	_cyl(d * 0.5, d * 0.5, seg - 0.7, Vector3(_x(side, 1.6 + d * 0.5), top + h, zc), _m(Color("3a4066"), 0.0, 0.03), 12, Vector3(PI * 0.5, 0.0, 0.0))
	var pal := [Color("ff2fd0"), Color("00e5ff"), Color("ffe14f"), Color("ff8a3d")]
	var wc: Color = pal[rng.randi() % pal.size()]
	for wz in [-0.25, 0.0, 0.25]:
		_box(Vector3(0.08, 0.5, 0.9), Vector3(_x(side, 1.56), top + h * 0.6, zc + wz * seg), _m(wc, 2.0))


## MAGLEV DOCK: a floating platform on glowing hover rails.
func _pier(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	var deck_y := 2.35
	var neon: Color = theme.get("neon", Color("ff2fd0"))
	_mass(side, z, seg, 2.2, Color("1c1f3a"), 3.4)
	_box(Vector3(3.5, 0.3, seg + 0.02), Vector3(_x(side, 1.75), deck_y, zc), _m(Color("3a3f6a")))
	_box(Vector3(3.5, 0.06, seg + 0.04), Vector3(_x(side, 1.75), deck_y - 0.17, zc), _m(neon, 3.0))
	var pz := z + 0.8
	while pz < z + seg:
		_cyl(0.12, 0.12, deck_y - LevelGen.FLOOR_Y, Vector3(_x(side, 3.2), (deck_y + LevelGen.FLOOR_Y) * 0.5, pz), _m(Color("2a2d52"), 0.0, 0.02), 8)
		_cyl(0.05, 0.05, 0.85, Vector3(_x(side, 0.2), deck_y + 0.5, pz), _m(Color("2a2d52"), 0.0, 0.02), 6)
		pz += 2.4
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, 0.2), deck_y + 0.9, zc), _m(theme.get("neon2", Color("00e5ff")), 3.0))
	if rng.randf() < 0.45:
		var cs := rng.randf_range(0.6, 0.85)
		_box(Vector3(cs, cs, cs), Vector3(_x(side, rng.randf_range(1.2, 2.8)), deck_y + 0.15 + cs * 0.5, z + rng.randf_range(1.0, seg - 1.0)), _m(Color("454b6e"), 0.0, 0.03), Vector3(0.0, rng.randf_range(-0.4, 0.4), 0.0))
	if rng.randf() < 0.4:
		_tree(Vector3(_x(side, rng.randf_range(4.5, 9.0)), 2.2, z + rng.randf_range(0.0, seg)))


## HAB DOMES: glass domes with lit rings.
func _village(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	_mass(side, z, seg, 1.0, Color("2a2d52"), 0.0)
	var r := rng.randf_range(2.0, 2.6)
	var pal := [Color("ffe14f"), Color("ff8a3d"), Color("39ff9f"), Color("00e5ff"), Color("ff2fd0")]
	var lc: Color = pal[rng.randi() % pal.size()]
	_cyl(r + 0.2, r + 0.2, 0.6, Vector3(_x(side, r + 0.3), 1.3, zc), _m(Color("3a3f6a"), 0.0, 0.03), 16)
	_ball(r, Vector3(_x(side, r + 0.3), 1.6, zc), _m(Color("9fb6ff"), 0.3, 0.03), Vector3(1.0, 0.85, 1.0))
	_cyl(r + 0.25, r + 0.25, 0.1, Vector3(_x(side, r + 0.3), 1.62, zc), _m(lc, 2.5), 16)
	for wz in [-0.2, 0.2]:
		_box(Vector3(0.12, 0.6, 0.6), Vector3(_x(side, 0.05), 1.3, zc + wz * seg), _m(lc, 1.5))
	if rng.randf() < 0.5:
		_cyl(0.05, 0.05, 2.0, Vector3(_x(side, r + 0.3), 1.6 + r * 0.85 + 1.0, zc), _m(Color("c8d2ff"), 0.0, 0.02), 6)
		_ball(0.15, Vector3(_x(side, r + 0.3), 1.6 + r * 0.85 + 2.0, zc), _m(Color("ff3d5a"), 3.0, 0.0))


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


## SYNTHWAVE: magenta/violet stripes with a glowing sun disc on top.
func _candy(side: float, z: float, seg: float) -> void:
	var zc := z + seg * 0.5
	var top := 6.4
	var a := Color("ff2fd0")
	var b := Color("3a0f5a")
	var n := 8
	for k in n:
		var y0 := LevelGen.FLOOR_Y - 1.0 + k * (top - LevelGen.FLOOR_Y + 1.0) / n
		var hh := (top - LevelGen.FLOOR_Y + 1.0) / n
		_box(Vector3(30.0, hh, seg + 0.02), Vector3(_x(side, 15.0), y0 + hh * 0.5, zc), _m(a.darkened(0.35) if k % 2 == 0 else b))
	_box(Vector3(0.08, 0.08, seg + 0.04), Vector3(_x(side, -0.04), top, zc), _m(Color("00e5ff"), 3.0))
	if rng.randf() < 0.4:
		_cyl(1.3, 1.3, 0.2, Vector3(_x(side, rng.randf_range(2.0, 5.0)), top + 1.4, zc), _m(Color("ff8a3d"), 2.0, 0.03), 24, Vector3(PI * 0.5, side * PI * 0.5, 0.0))


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
			_cyl(0.35 * sc, 0.05 * sc, 3.2 * sc, base + Vector3(0.0, 1.6 * sc, 0.0), _m(b, 0.0, 0.03), 6)
			_ball(0.16 * sc, base + Vector3(0.0, 3.3 * sc, 0.0), _m(a, 3.0, 0.0))
		"antenna":
			_cyl(0.06, 0.06, 2.6 * sc, base + Vector3(0.0, 1.3 * sc, 0.0), _m(b, 0.0, 0.02), 6)
			for k in 3:
				_box(Vector3(0.8 * sc - k * 0.2, 0.05, 0.05), base + Vector3(0.0, (1.4 + k * 0.45) * sc, 0.0), _m(b, 0.0, 0.02))
			_ball(0.1, base + Vector3(0.0, 2.65 * sc, 0.0), _m(a, 3.0, 0.0))
		"dish":
			_cyl(0.12, 0.18, 1.0 * sc, base + Vector3(0.0, 0.5 * sc, 0.0), _m(b, 0.0, 0.02), 8)
			_cyl(0.9 * sc, 0.2 * sc, 0.35 * sc, base + Vector3(0.0, 1.2 * sc, 0.0), _m(Color("c8d2ff"), 0.0, 0.03), 16, Vector3(0.6, 0.0, 0.0))
			_ball(0.08, base + Vector3(0.0, 1.5 * sc, 0.3 * sc), _m(a, 3.0, 0.0))
		"pumpkin":
			var ps := sc * 0.7
			_ball(0.55 * ps, base + Vector3(0.0, 0.45 * ps, 0.0), _m(Color("ff7a1a"), 0.6, 0.03), Vector3(1.25, 0.85, 1.25))
			_cyl(0.06, 0.08, 0.3 * ps, base + Vector3(0.0, 0.95 * ps, 0.0), _m(Color("3d8f3a"), 0.0, 0.02), 6)
			for ex in [-0.2, 0.2]:
				_box(Vector3(0.14, 0.12, 0.08) * ps, base + Vector3(ex * ps, 0.55 * ps, -0.62 * ps), _m(Color("fff1a0"), 4.0, 0.0))
			_box(Vector3(0.4, 0.08, 0.08) * ps, base + Vector3(0.0, 0.32 * ps, -0.64 * ps), _m(Color("fff1a0"), 4.0, 0.0))
		"xmas_tree":
			var green := _m(Color("2e9e4f"), 0.0, 0.03)
			_cyl(0.12 * sc, 0.1 * sc, 0.5 * sc, base + Vector3(0.0, 0.25 * sc, 0.0), _m(Color("6b4a2b"), 0.0, 0.02), 6)
			for k in 3:
				_cyl((1.0 - k * 0.25) * sc, 0.05, 1.1 * sc, base + Vector3(0.0, (0.9 + k * 0.6) * sc, 0.0), green, 8)
			_ball(0.15 * sc, base + Vector3(0.0, 2.6 * sc, 0.0), _m(Color("ffd23f"), 3.0, 0.0))
			var bulbs := [Color("ff3d3d"), Color("4ea8ff"), Color("ffd23f")]
			for k in 6:
				var ang := TAU * k / 6.0 + rng.randf()
				var hy := rng.randf_range(0.7, 2.0)
				var rr := (1.0 - (hy - 0.7) / 1.8) * 0.8
				_ball(0.07 * sc, base + Vector3(cos(ang) * rr * sc, hy * sc, sin(ang) * rr * sc), _m(bulbs[k % 3], 3.0, 0.0))
		"crystal":
			for k in 3:
				var hc := rng.randf_range(0.8, 2.0) * sc
				_cyl(0.3 * sc, 0.05, hc, base + Vector3(rng.randf_range(-0.5, 0.5), hc * 0.5, rng.randf_range(-0.5, 0.5)), _m(a, 2.2, 0.03), 5)
		_:
			_cyl(0.3 * sc, 0.05 * sc, 2.4 * sc, base + Vector3(0.0, 1.2 * sc, 0.0), _m(b, 0.0, 0.03), 6)


func _waterfall(x: float, top: float, z: float, side: float) -> void:
	if track:
		return   # no waterfalls in space
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
