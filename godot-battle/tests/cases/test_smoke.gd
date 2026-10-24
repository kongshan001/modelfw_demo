extends RefCounted

func run(t: TestContext) -> void:
    var probe := TestContext.new()
    probe.ok(false, "intentional failure")
    probe.eq(1, 2, "intentional mismatch")
    t.eq(probe.assertions, 2, "TestContext counts assertions")
    t.eq(probe.failures.size(), 2, "TestContext records failures")
