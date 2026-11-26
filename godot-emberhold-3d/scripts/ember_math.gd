class_name EmberMath
extends RefCounted
## Small deterministic math helpers mirroring the HTML build's JS arithmetic.
## hash2 / mulberry32 reproduce the original 32-bit sequences so that map props
## and AI build-spot tie-breaking stay identical to web-html-tower-defense.

const MASK32 := 0xFFFFFFFF


class Rng:
	var a: int

	func _init(seed: int) -> void:
		a = seed & MASK32

	func next() -> float:
		a = (a + 0x6D2B79F5) & MASK32
		var t: int = a
		t = ((t ^ (t >> 15)) * (1 | t)) & MASK32
		t = ((t + (((t ^ (t >> 7)) * (61 | t)) & MASK32)) & MASK32) ^ t
		t = t ^ (t >> 14)
		return float(t & MASK32) / 4294967296.0


static func imul(a: int, b: int) -> int:
	return (a * b) & MASK32


## JS: h = (x*374761393 + y*668265263 + seed*1442695041) | 0;
##     h = (h ^ (h >>> 13)) * 1274126177 | 0;
##     return ((h ^ (h >>> 16)) >>> 0) / 2^32;
## The second multiply is a JS double multiply (with low-bit rounding), so it is
## reproduced with float64 + ToInt32 instead of 64-bit integer multiplication.
static func hash2(x: int, y: int, seed: int = 0) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed * 1442695041) & MASK32
	var mixed: int = _to_i32(h ^ (h >> 13))
	var prod: float = float(mixed) * 1274126177.0
	var low: int = int(prod) & MASK32
	h = low ^ (low >> 16)
	return float(h & MASK32) / 4294967296.0


static func _to_i32(v: int) -> int:
	v = v & MASK32
	return v - 4294967296 if v >= 2147483648 else v


static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)


static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [int(floor(s / 60.0)), s % 60]


static func cell_name(cx: int, cy: int) -> String:
	var n := cx + 1
	var s := ""
	while n > 0:
		var r := (n - 1) % 26
		s = String.chr(65 + r) + s
		n = int(floor((n - 1) / 26.0))
	return s + str(cy + 1)
