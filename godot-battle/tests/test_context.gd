class_name TestContext
extends RefCounted

var failures: Array[String] = []
var assertions: int = 0

func ok(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s — expected=%s actual=%s" % [message, str(expected), str(actual)])

func in_range(value: float, low: float, high: float, message: String) -> void:
	assertions += 1
	if value < low or value > high:
		failures.append("%s — %s not in [%s, %s]" % [message, str(value), str(low), str(high)])

func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > epsilon:
		failures.append("%s — expected≈%s actual=%s" % [message, str(expected), str(actual)])

func has(text: String, needle: String, message: String) -> void:
	assertions += 1
	if not text.contains(needle):
		failures.append("%s — '%s' not found in '%s'" % [message, needle, text])
