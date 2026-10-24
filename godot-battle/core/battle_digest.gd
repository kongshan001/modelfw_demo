class_name BattleDigest
extends RefCounted

static func sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return "sha256:" + context.finish().hex_encode()
