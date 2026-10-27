class_name Track
extends RefCounted
## The rolling track: a ribbon that curves, climbs and dips through space.
## Positions on it are (d, s, h): d = distance along the centre line,
## s = sideways offset (+ = local +X = screen LEFT when looking forward),
## h = height above the floor.
## The floor can be narrow, zig-zag, have holes, split in two lanes, or have
## a gap you must jump over (see floor_ok). Built by LevelGen.

const DS := 0.5                       # sampling step of the centre line

var pos := PackedVector3Array()       # centre line points every DS
var fwd := PackedVector3Array()       # forward direction
var side := PackedVector3Array()      # +s direction (horizontal)
var center := PackedFloat32Array()    # floor centre offset in s
var half_w := PackedFloat32Array()    # floor half width
var rails := PackedByteArray()        # 1 = glowing rails keep you on
var curv := PackedFloat32Array()      # signed curvature (1/m), + = turning toward +s
var voids: Array = []                 # {d0, d1, kind, s0, s1, ...} floor exceptions
var length := 0.0

var _heading := 0.0
var _y := 0.0
var _p := Vector3.ZERO


func _init() -> void:
	_push(0.0, 0.0, 3.5, true)


func _push(dh: float, dy: float, hw: float, rail: bool, c := 0.0) -> void:
	var f := Vector3(sin(_heading), 0.0, cos(_heading))
	var sd := Vector3(cos(_heading), 0.0, -sin(_heading))   # up x fwd = local +X
	pos.append(_p)
	fwd.append(Vector3(f.x, dy / DS, f.z).normalized())
	side.append(sd)
	half_w.append(hw)
	center.append(c)
	rails.append(1 if rail else 0)
	curv.append(dh / DS)


## Extends the centre line by `len` metres: total turn (radians, + = toward +s),
## total rise, and a floor profile func(u) -> [centre, half_width].
func add(len: float, turn: float, rise: float, hw: float, rail: bool, profile := Callable()) -> void:
	var n := maxi(int(round(len / DS)), 1)
	var dh := turn / n
	var dy := rise / n
	for i in n:
		_heading += dh       # turning toward +s (screen left)
		_p += Vector3(sin(_heading), 0.0, cos(_heading)) * DS
		_p.y += dy
		_y += dy
		var c := 0.0
		var w := hw
		if profile.is_valid():
			var cw: Vector2 = profile.call(float(i + 1) / n)
			c = cw.x
			w = cw.y
		_push(dh, dy, w, rail, c)
	length = (pos.size() - 1) * DS


func _idx(d: float) -> int:
	return clampi(int(d / DS), 0, pos.size() - 2)


func _t(d: float) -> float:
	return clampf(d / DS - _idx(d), 0.0, 1.0)


## World position of (d, s, h).
func point(d: float, s := 0.0, h := 0.0) -> Vector3:
	var i := _idx(d)
	var u := _t(d)
	var p := pos[i].lerp(pos[i + 1], u)
	var sd := side[i].lerp(side[i + 1], u).normalized()
	return p + sd * s + Vector3.UP * h


## Transform of the track frame at d (x = +s, y = up, z = forward), with s offset.
func frame(d: float, s := 0.0, h := 0.0) -> Transform3D:
	var i := _idx(d)
	var u := _t(d)
	var f := fwd[i].lerp(fwd[i + 1], u)
	var flat := Vector3(f.x, 0.0, f.z).normalized()
	var sd := Vector3.UP.cross(flat).normalized()
	return Transform3D(Basis(sd, Vector3.UP, flat), point(d, s, h))


func ground_y(d: float) -> float:
	var i := _idx(d)
	return lerpf(pos[i].y, pos[i + 1].y, _t(d))


func slope(d: float) -> float:
	return fwd[_idx(d)].y


func curvature(d: float) -> float:
	return curv[_idx(d) + 1]


func center_at(d: float) -> float:
	var i := _idx(d)
	return lerpf(center[i], center[i + 1], _t(d))


func half_at(d: float) -> float:
	var i := _idx(d)
	return lerpf(half_w[i], half_w[i + 1], _t(d))


func rails_at(d: float) -> bool:
	return rails[_idx(d)] == 1


## Sideways limits of the floor itself (ignoring holes) at d.
func bounds(d: float) -> Vector2:
	var c := center_at(d)
	var w := half_at(d)
	return Vector2(c - w, c + w)


## Is there floor under (d, s) at time t?  `margin` shrinks the floor (ball radius tolerance).
func floor_ok(d: float, s: float, t: float, margin := 0.0) -> bool:
	var b := bounds(d)
	if s < b.x + margin or s > b.y - margin:
		return false
	for v in voids:
		if d < float(v.d0) or d > float(v.d1):
			continue
		match String(v.kind):
			"gap":
				return false
			"hole":
				if s > float(v.s0) - margin and s < float(v.s1) + margin:
					return false
			"platform":
				var pcen := float(v.amp) * sin(TAU * t / float(v.period) + float(v.phase))
				return absf(s - pcen) <= float(v.pw) * 0.5 - margin
	return true


## Floor exceptions overlapping [d0, d1] (for the mesh builder).
func voids_in(d0: float, d1: float) -> Array:
	var out := []
	for v in voids:
		if float(v.d1) >= d0 and float(v.d0) <= d1:
			out.append(v)
	return out
