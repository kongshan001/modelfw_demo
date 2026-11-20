extends SceneTree

# Debug sheet for the procedural art: symbols + composed backdrop.
# Run: godot --headless --path godot-slot-defense -s tools/art_sheet.gd
# -> docs/shots/art_sheet.png (not part of the acceptance loop)

const ReelArt := preload("res://src/reel_art.gd")
const OUT := "res://docs/shots/art_sheet.png"


func _initialize() -> void:
	var img := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0c0a14"))
	var syms := ReelArt.build_symbol_textures()
	var order := ["blade", "bow", "shield", "steed", "orb", "crown"]
	for i in order.size():
		var tex: ImageTexture = syms[order[i]]
		var icon := tex.get_image()
		icon.resize(96, 96, Image.INTERPOLATE_NEAREST)
		var cell := Rect2i(24 + i * 104, 24, 96, 96)
		img.fill_rect(Rect2i(cell.position - Vector2i(4, 4), cell.size + Vector2i(8, 8)), Color("#191426"))
		img.blit_rect(icon, Rect2i(0, 0, 96, 96), cell.position)

	var hearts := ReelArt.build_heart_textures()
	var full: Image = hearts["full"].get_image()
	var empty: Image = hearts["empty"].get_image()
	full.resize(64, 56, Image.INTERPOLATE_NEAREST)
	empty.resize(64, 56, Image.INTERPOLATE_NEAREST)
	img.blit_rect(full, Rect2i(0, 0, 64, 56), Vector2i(24, 136))
	img.blit_rect(empty, Rect2i(0, 0, 64, 56), Vector2i(100, 136))
	var coin: Image = ReelArt.build_coin_texture().get_image()
	coin.resize(48, 48, Image.INTERPOLATE_NEAREST)
	img.blit_rect(coin, Rect2i(0, 0, 48, 48), Vector2i(184, 140))

	var bd := ReelArt.build_backdrop()
	var bx := 660
	var by := 60
	_blit_scaled(img, bd["sky"], Rect2i(bx, by, 640, 490))
	_blit_scaled(img, bd["clouds_far"], Rect2i(bx - 6, by + 20, 640, 240))
	_blit_scaled(img, bd["clouds_near"], Rect2i(bx + 8, by + 90, 640, 240))
	_blit_scaled(img, bd["mountains"], Rect2i(bx, by + 250, 640, 240))
	_blit_scaled(img, bd["temple"], Rect2i(bx, by + 130, 640, 360))
	_blit_scaled(img, bd["ruins"], Rect2i(bx, by + 270, 640, 220))
	_blit_scaled(img, bd["ground"], Rect2i(bx, by + 490, 640, 160))
	_blit_scaled(img, bd["fog"], Rect2i(bx, by + 420, 640, 96))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("ART_SHEET_OK ", ProjectSettings.globalize_path(OUT))
	quit(0)


func _blit_scaled(dst: Image, tex: ImageTexture, rect: Rect2i) -> void:
	var src := tex.get_image()
	src.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, rect.size), rect.position)
