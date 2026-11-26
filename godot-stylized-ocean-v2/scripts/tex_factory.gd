class_name TexFactory
extends RefCounted

# 程序化可平铺纹理：泡沫噪声 / 细节法线 / 焦散光网。无外部图片素材。
# 值噪声使用整数格点哈希 + 周期环绕，保证四方连续。

static var _cache: Dictionary = {}


static func _hash(ix: int, iy: int, seed_v: int) -> float:
	var n: int = ix * 374761393 + iy * 668265263 + seed_v * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


static func _value_noise(x: float, y: float, period: int, seed_v: int) -> float:
	var xf: float = floor(x)
	var yf: float = floor(y)
	var xi := int(xf)
	var yi := int(yf)
	var tx: float = x - xf
	var ty: float = y - yf
	var sx: float = tx * tx * (3.0 - 2.0 * tx)
	var sy: float = ty * ty * (3.0 - 2.0 * ty)
	var x0 := ((xi % period) + period) % period
	var y0 := ((yi % period) + period) % period
	var x1 := (x0 + 1) % period
	var y1 := (y0 + 1) % period
	var a := _hash(x0, y0, seed_v)
	var b := _hash(x1, y0, seed_v)
	var c := _hash(x0, y1, seed_v)
	var d := _hash(x1, y1, seed_v)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _fbm(u: float, v: float, size: int, base_period: int, octaves: int, seed_v: int) -> float:
	var total := 0.0
	var amp := 0.5
	var norm := 0.0
	var period := base_period
	for o in octaves:
		total += _value_noise(u * period, v * period, period, seed_v + o * 977) * amp
		norm += amp
		amp *= 0.5
		period *= 2
	return total / norm


static func foam_texture() -> ImageTexture:
	if _cache.has("foam"):
		return _cache["foam"]
	var n := 256
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			var u := float(x) / float(n)
			var v := float(y) / float(n)
			var a := _fbm(u, v, n, 8, 4, 11)
			var b := _fbm(u + 0.31, v + 0.71, n, 24, 3, 37)
			var val := clampf(a * 0.72 + b * 0.38, 0.0, 1.0)
			var c := int(val * 255.0)
			var o := (y * n + x) * 4
			data[o] = c
			data[o + 1] = c
			data[o + 2] = c
			data[o + 3] = 255
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	_cache["foam"] = tex
	return tex


static func detail_normal_texture() -> ImageTexture:
	if _cache.has("detail"):
		return _cache["detail"]
	var n := 256
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for y in n:
		for x in n:
			var u := float(x) / float(n)
			var v := float(y) / float(n)
			var h := _fbm(u, v, n, 16, 4, 71)
			h = h * 0.65 + _fbm(u + 0.5, v + 0.2, n, 48, 2, 91) * 0.35
			heights[y * n + x] = h
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var strength := 2.2
	for y in n:
		for x in n:
			var xl := heights[y * n + ((x - 1 + n) % n)]
			var xr := heights[y * n + ((x + 1) % n)]
			var yu := heights[((y - 1 + n) % n) * n + x]
			var yd := heights[((y + 1) % n) * n + x]
			var nx := (xl - xr) * strength
			var ny := (yu - yd) * strength
			var nz := 1.0
			var ln := sqrt(nx * nx + ny * ny + nz * nz)
			nx /= ln
			ny /= ln
			nz /= ln
			var o := (y * n + x) * 4
			data[o] = int((nx * 0.5 + 0.5) * 255.0)
			data[o + 1] = int((ny * 0.5 + 0.5) * 255.0)
			data[o + 2] = int((nz * 0.5 + 0.5) * 255.0)
			data[o + 3] = 255
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	_cache["detail"] = tex
	return tex


static func glow_texture() -> ImageTexture:
	if _cache.has("glow"):
		return _cache["glow"]
	var n := 64
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a: float = pow(clampf(1.0 - r, 0.0, 1.0), 2.2)
			var o := (y * n + x) * 4
			data[o] = 255
			data[o + 1] = 236
			data[o + 2] = 200
			data[o + 3] = int(a * 255.0)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	_cache["glow"] = tex
	return tex


static func shadow_texture() -> ImageTexture:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var n := 64
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a: float = pow(clampf(1.0 - r, 0.0, 1.0), 1.7)
			var o := (y * n + x) * 4
			data[o] = 26
			data[o + 1] = 38
			data[o + 2] = 44
			data[o + 3] = int(a * 255.0)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	_cache["shadow"] = tex
	return tex


static func caustic_texture() -> ImageTexture:
	if _cache.has("caustic"):
		return _cache["caustic"]
	var n := 256
	var vals := PackedFloat32Array()
	vals.resize(n * n)
	var t1 := TAU
	for y in n:
		for x in n:
			var u := float(x) / float(n) * t1
			var v := float(y) / float(n) * t1
			var a1 := sin(u * 3.0 + sin(v * 2.0 + 1.6) * 1.15 + sin(u * 5.0 + v * 3.0) * 0.55)
			a1 *= sin(v * 3.0 + sin(u * 2.0 - 1.6) * 1.05 + cos(u * 3.0 - v * 5.0) * 0.5)
			var u2 := u + 1.7
			var v2 := v + 0.9
			var a2 := sin(u2 * 4.0 + sin(v2 * 3.0 + 0.7) * 1.15 + sin(u2 * 2.0 + v2 * 4.0) * 0.55)
			a2 *= sin(v2 * 4.0 + sin(u2 * 3.0 - 0.7) * 1.05 + cos(u2 * 4.0 - v2 * 2.0) * 0.5)
			var a := absf(a1) * 0.75 + absf(a2) * 0.55
			a = pow(clampf(a, 0.0, 1.0), 2.6)
			vals[y * n + x] = a
	var lo := 1e9
	var hi := -1e9
	for val2 in vals:
		lo = minf(lo, val2)
		hi = maxf(hi, val2)
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for i in n * n:
		var val := (vals[i] - lo) / maxf(hi - lo, 0.0001)
		val = pow(val, 1.4)
		var c := int(clampf(val, 0.0, 1.0) * 255.0)
		var o := i * 4
		data[o] = c
		data[o + 1] = c
		data[o + 2] = c
		data[o + 3] = 255
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	_cache["caustic"] = tex
	return tex
